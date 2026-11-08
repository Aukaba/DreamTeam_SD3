-- migrate:up

-- ============================================================================
-- 1. SEVERITY POINTS CALCULATION & REPORT TABLE COLUMN / TRIGGER
--    Rule: Each report counts as 1 report.
--          Points by severity_level: Low = 1 pt, Medium = 2 pts, High = 3 pts.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_report_severity_points(p_severity text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_norm text := lower(trim(coalesce(p_severity, 'low')));
BEGIN
  IF v_norm LIKE '%high%' OR v_norm LIKE '%critical%' OR v_norm LIKE '%severe%' THEN
    RETURN 3;
  ELSIF v_norm LIKE '%med%' OR v_norm LIKE '%mod%' THEN
    RETURN 2;
  ELSE
    RETURN 1;
  END IF;
END;
$$;

ALTER TABLE public."ReportTable"
  ADD COLUMN IF NOT EXISTS points_awarded integer NOT NULL DEFAULT 1;

-- Backfill existing rows with their severity-based point values
UPDATE public."ReportTable"
SET points_awarded = public.calculate_report_severity_points(severity_level)
WHERE points_awarded IS DISTINCT FROM public.calculate_report_severity_points(severity_level);

CREATE OR REPLACE FUNCTION public.handle_report_table_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.points_awarded := public.calculate_report_severity_points(NEW.severity_level);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_report_table_set_points ON public."ReportTable";
CREATE TRIGGER on_report_table_set_points
  BEFORE INSERT OR UPDATE OF severity_level ON public."ReportTable"
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_report_table_points();

-- Index for user's own reports lookup ("My Reports") and leaderboard aggregation
CREATE INDEX IF NOT EXISTS idx_report_table_user_created_at
  ON public."ReportTable" (user_id, created_at DESC);

-- ============================================================================
-- 2. LEVEL PROGRESSION FUNCTION
--    Rule: Level 1 requires 20 points.
--          Each level up requires 1/4 (25%) more points than the previous level:
--          Level 1 -> 20 pts, Level 2 -> 25 pts, Level 3 -> 31 pts, etc.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.calculate_user_level_progress(p_total_points integer)
RETURNS TABLE (
  user_level integer,
  current_level_points integer,
  next_level_required_points integer,
  total_points integer
)
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_total integer := GREATEST(COALESCE(p_total_points, 0), 0);
  v_remaining integer := v_total;
  v_level integer := 1;
  v_required integer := 20;
BEGIN
  WHILE v_remaining >= v_required LOOP
    v_remaining := v_remaining - v_required;
    v_level := v_level + 1;
    v_required := v_required + ROUND(v_required / 4.0)::integer;
  END LOOP;

  RETURN QUERY SELECT v_level, v_remaining, v_required, v_total;
END;
$$;

-- ============================================================================
-- 3. LEADERBOARD & GAMIFICATION RPCs (SECURITY DEFINER FOR CROSS-USER RANKING)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_leaderboard(p_timeframe text DEFAULT 'all')
RETURNS TABLE (
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  report_count integer,
  safety_points integer,
  saved_routes_count integer,
  all_time_points integer,
  all_time_reports integer,
  user_level integer,
  current_level_points integer,
  next_level_required_points integer,
  days_active integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_is_weekly boolean := (lower(trim(coalesce(p_timeframe, 'all'))) = 'week');
  v_cutoff timestamptz := CASE
    WHEN v_is_weekly THEN (now() - interval '7 days')
    ELSE '-infinity'::timestamptz
  END;
BEGIN
  RETURN QUERY
  WITH report_Window AS (
    SELECT
      r.user_id,
      COUNT(*)::integer AS r_count,
      COALESCE(SUM(public.calculate_report_severity_points(r.severity_level)), 0)::integer AS r_points
    FROM public."ReportTable" r
    WHERE r.user_id IS NOT NULL
      AND COALESCE(r.created_at, now()) >= v_cutoff
    GROUP BY r.user_id
  ),
  report_all_time AS (
    SELECT
      r.user_id,
      COUNT(*)::integer AS total_r_count,
      COALESCE(SUM(public.calculate_report_severity_points(r.severity_level)), 0)::integer AS total_r_points
    FROM public."ReportTable" r
    WHERE r.user_id IS NOT NULL
    GROUP BY r.user_id
  ),
  routes_window AS (
    SELECT
      sr.user_id,
      COUNT(*)::integer AS sr_count
    FROM public.saved_routes sr
    WHERE sr.user_id IS NOT NULL
      AND COALESCE(sr.created_at, now()) >= v_cutoff
    GROUP BY sr.user_id
  )
  SELECT
    p.id AS user_id,
    COALESCE(
      NULLIF(trim(p.full_name), ''),
      NULLIF(trim(p.username), ''),
      'SafeRoute Member'
    ) AS display_name,
    COALESCE(NULLIF(trim(p.username), ''), 'user') AS username,
    p.avatar_url,
    COALESCE(rw.r_count, 0)::integer AS report_count,
    COALESCE(rw.r_points, 0)::integer AS safety_points,
    COALESCE(rtw.sr_count, 0)::integer AS saved_routes_count,
    COALESCE(rat.total_r_points, 0)::integer AS all_time_points,
    COALESCE(rat.total_r_count, 0)::integer AS all_time_reports,
    lvl.user_level,
    lvl.current_level_points,
    lvl.next_level_required_points,
    GREATEST(
      1,
      (EXTRACT(EPOCH FROM (now() - COALESCE(p.created_at, now()))) / 86400.0)::integer + 1
    )::integer AS days_active
  FROM public.profiles p
  LEFT JOIN report_Window rw ON rw.user_id = p.id
  LEFT JOIN report_all_time rat ON rat.user_id = p.id
  LEFT JOIN routes_window rtw ON rtw.user_id = p.id
  CROSS JOIN LATERAL public.calculate_user_level_progress(COALESCE(rat.total_r_points, 0)) lvl
  WHERE COALESCE(p.role, 'user') <> 'admin'
     OR p.id = (SELECT auth.uid())
  ORDER BY
    COALESCE(rw.r_points, 0) DESC,
    COALESCE(rw.r_count, 0) DESC,
    COALESCE(rtw.sr_count, 0) DESC,
    p.created_at ASC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.calculate_report_severity_points(text) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.calculate_user_level_progress(integer) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text) TO authenticated, anon;

-- migrate:down

DROP FUNCTION IF EXISTS public.get_leaderboard(text);
DROP FUNCTION IF EXISTS public.calculate_user_level_progress(integer);
DROP INDEX IF EXISTS public.idx_report_table_user_created_at;
DROP TRIGGER IF EXISTS on_report_table_set_points ON public."ReportTable";
DROP FUNCTION IF EXISTS public.handle_report_table_points();
ALTER TABLE public."ReportTable" DROP COLUMN IF EXISTS points_awarded;
DROP FUNCTION IF EXISTS public.calculate_report_severity_points(text);

