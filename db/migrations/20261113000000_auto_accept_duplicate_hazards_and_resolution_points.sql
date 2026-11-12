-- migrate:up

-- =====================================================================
-- 1. Support +1 safety point per approved hazard resolution report
-- =====================================================================
ALTER TABLE public.hazard_resolution_reports
  ADD COLUMN IF NOT EXISTS points_awarded integer NOT NULL DEFAULT 1;

UPDATE public.hazard_resolution_reports
SET points_awarded = 1
WHERE points_awarded IS DISTINCT FROM 1;

CREATE OR REPLACE FUNCTION public.handle_hazard_resolution_points()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  NEW.points_awarded := 1;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.handle_hazard_resolution_points() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_hazard_resolution_reports_set_points ON public.hazard_resolution_reports;
CREATE TRIGGER on_hazard_resolution_reports_set_points
BEFORE INSERT OR UPDATE OF points_awarded ON public.hazard_resolution_reports
FOR EACH ROW
EXECUTE FUNCTION public.handle_hazard_resolution_points();

CREATE INDEX IF NOT EXISTS idx_hazard_resolution_reports_approved_user
  ON public.hazard_resolution_reports (reported_by, verified_at DESC, created_at DESC)
  WHERE status IN ('approved', 'resolved') AND reported_by IS NOT NULL;

-- =====================================================================
-- 2. Partial expression index for fast duplicate hazard location lookup
-- =====================================================================
CREATE INDEX IF NOT EXISTS "idx_ReportTable_duplicate_lookup"
  ON public."ReportTable" (
    lower(trim(hazard_category)),
    ROUND(latitude::numeric, 6),
    ROUND(longitude::numeric, 6)
  )
  WHERE COALESCE(status, 'pending') IN ('pending', 'active')
    AND user_id IS NOT NULL
    AND latitude IS NOT NULL
    AND longitude IS NOT NULL;

-- =====================================================================
-- 3. Allow internal trigger transitions to 'active' or 'resolved'
-- =====================================================================
CREATE OR REPLACE FUNCTION public.enforce_report_table_status_authorization()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF tg_op = 'INSERT' THEN
    IF NEW.status IS NULL THEN
      NEW.status := 'pending';
    ELSIF NEW.status <> 'pending' AND NOT COALESCE(public.verify_admin_access(), false) THEN
      NEW.status := 'pending';
    END IF;
  ELSIF tg_op = 'UPDATE' THEN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      -- Allow internal triggers (duplicate-report quorum -> 'active', resolution quorum -> 'resolved')
      IF pg_trigger_depth() > 1 AND NEW.status IN ('active', 'resolved') THEN
        NULL;
      ELSIF NOT COALESCE(public.verify_admin_access(), false) THEN
        RAISE EXCEPTION 'Only administrators can update report status.';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_report_table_status_authorization() FROM PUBLIC, anon, authenticated;

-- =====================================================================
-- 4. Auto-accept duplicate reports from multiple users at exact location
-- =====================================================================
-- Drop legacy BEFORE trigger if previously applied (RLS INSERT requires status='pending';
-- promotion happens cleanly in SECURITY DEFINER AFTER INSERT trigger below).
DROP TRIGGER IF EXISTS on_report_table_z_auto_accept_duplicate_before ON public."ReportTable";
DROP FUNCTION IF EXISTS public.auto_accept_duplicate_hazard_report_before();

CREATE OR REPLACE FUNCTION public.promote_matching_pending_hazard_reports_after()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category text;
  v_lat numeric;
  v_lng numeric;
  v_distinct_users integer;
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.status, 'pending') NOT IN ('pending', 'active')
     OR NEW.latitude IS NULL
     OR NEW.longitude IS NULL
     OR NULLIF(TRIM(NEW.hazard_category), '') IS NULL THEN
    RETURN NEW;
  END IF;

  v_category := lower(trim(NEW.hazard_category));
  v_lat := ROUND(NEW.latitude::numeric, 6);
  v_lng := ROUND(NEW.longitude::numeric, 6);

  -- Serialize concurrent reports for the same hazard + exact coordinates
  PERFORM pg_advisory_xact_lock(
    hashtext(v_category || ':' || v_lat::text || ':' || v_lng::text)
  );

  SELECT COUNT(DISTINCT r.user_id) FILTER (WHERE r.user_id IS NOT NULL)
  INTO v_distinct_users
  FROM public."ReportTable" r
  WHERE r.user_id IS NOT NULL
    AND COALESCE(r.status, 'pending') IN ('pending', 'active')
    AND r.latitude IS NOT NULL
    AND r.longitude IS NOT NULL
    AND lower(trim(r.hazard_category)) = v_category
    AND ROUND(r.latitude::numeric, 6) = v_lat
    AND ROUND(r.longitude::numeric, 6) = v_lng;

  -- Promote all matching pending reports (including NEW) once >= 2 distinct users
  -- report the same hazard at the exact location (or if an admin set status = 'active').
  IF COALESCE(NEW.status, 'pending') = 'active'
     OR (NEW.user_id IS NOT NULL AND COALESCE(v_distinct_users, 0) >= 2) THEN
    UPDATE public."ReportTable"
    SET status = 'active',
        verified_at = COALESCE(verified_at, timezone('utc'::text, now()))
    WHERE COALESCE(status, 'pending') = 'pending'
      AND user_id IS NOT NULL
      AND latitude IS NOT NULL
      AND longitude IS NOT NULL
      AND lower(trim(hazard_category)) = v_category
      AND ROUND(latitude::numeric, 6) = v_lat
      AND ROUND(longitude::numeric, 6) = v_lng;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.promote_matching_pending_hazard_reports_after() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS on_report_table_z_auto_accept_duplicate_after ON public."ReportTable";
CREATE TRIGGER on_report_table_z_auto_accept_duplicate_after
AFTER INSERT OR UPDATE OF status ON public."ReportTable"
FOR EACH ROW
EXECUTE FUNCTION public.promote_matching_pending_hazard_reports_after();

-- =====================================================================
-- 5. Update get_leaderboard to award report points + resolution points
-- =====================================================================
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
  WITH report_window AS (
    SELECT
      r.user_id,
      COUNT(*)::integer AS r_count,
      COALESCE(
        SUM(COALESCE(r.points_awarded, public.calculate_report_severity_points(r.severity_level))),
        0
      )::integer AS r_points
    FROM public."ReportTable" r
    WHERE r.user_id IS NOT NULL
      AND COALESCE(r.status, 'pending') IN ('active', 'resolved')
      AND COALESCE(r.created_at, now()) >= v_cutoff
    GROUP BY r.user_id
  ),
  report_all_time AS (
    SELECT
      r.user_id,
      COUNT(*)::integer AS total_r_count,
      COALESCE(
        SUM(COALESCE(r.points_awarded, public.calculate_report_severity_points(r.severity_level))),
        0
      )::integer AS total_r_points
    FROM public."ReportTable" r
    WHERE r.user_id IS NOT NULL
      AND COALESCE(r.status, 'pending') IN ('active', 'resolved')
    GROUP BY r.user_id
  ),
  resolution_window AS (
    SELECT
      rr.reported_by AS user_id,
      COALESCE(SUM(COALESCE(rr.points_awarded, 1)), 0)::integer AS res_points
    FROM public.hazard_resolution_reports rr
    WHERE rr.reported_by IS NOT NULL
      AND COALESCE(rr.status, 'pending') IN ('approved', 'resolved')
      AND COALESCE(rr.verified_at, rr.updated_at, rr.created_at, now()) >= v_cutoff
    GROUP BY rr.reported_by
  ),
  resolution_all_time AS (
    SELECT
      rr.reported_by AS user_id,
      COALESCE(SUM(COALESCE(rr.points_awarded, 1)), 0)::integer AS total_res_points
    FROM public.hazard_resolution_reports rr
    WHERE rr.reported_by IS NOT NULL
      AND COALESCE(rr.status, 'pending') IN ('approved', 'resolved')
    GROUP BY rr.reported_by
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
    (COALESCE(rw.r_points, 0) + COALESCE(resw.res_points, 0))::integer AS safety_points,
    COALESCE(rtw.sr_count, 0)::integer AS saved_routes_count,
    (COALESCE(rat.total_r_points, 0) + COALESCE(resat.total_res_points, 0))::integer AS all_time_points,
    COALESCE(rat.total_r_count, 0)::integer AS all_time_reports,
    lvl.user_level,
    lvl.current_level_points,
    lvl.next_level_required_points,
    GREATEST(
      1,
      (EXTRACT(EPOCH FROM (now() - COALESCE(p.created_at, now()))) / 86400.0)::integer + 1
    )::integer AS days_active
  FROM public.profiles p
  LEFT JOIN report_window rw ON rw.user_id = p.id
  LEFT JOIN report_all_time rat ON rat.user_id = p.id
  LEFT JOIN resolution_window resw ON resw.user_id = p.id
  LEFT JOIN resolution_all_time resat ON resat.user_id = p.id
  LEFT JOIN routes_window rtw ON rtw.user_id = p.id
  CROSS JOIN LATERAL public.calculate_user_level_progress(
    COALESCE(rat.total_r_points, 0) + COALESCE(resat.total_res_points, 0)
  ) lvl
  WHERE COALESCE(p.role, 'user') <> 'admin'
     OR p.id = (SELECT auth.uid())
  ORDER BY
    (COALESCE(rw.r_points, 0) + COALESCE(resw.res_points, 0)) DESC,
    COALESCE(rw.r_count, 0) DESC,
    COALESCE(rtw.sr_count, 0) DESC,
    p.created_at ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_leaderboard(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text) TO authenticated;

NOTIFY pgrst, 'reload schema';

-- migrate:down

DROP TRIGGER IF EXISTS on_report_table_z_auto_accept_duplicate_after ON public."ReportTable";
DROP FUNCTION IF EXISTS public.promote_matching_pending_hazard_reports_after();

DROP TRIGGER IF EXISTS on_report_table_z_auto_accept_duplicate_before ON public."ReportTable";
DROP FUNCTION IF EXISTS public.auto_accept_duplicate_hazard_report_before();

DROP INDEX IF EXISTS public."idx_ReportTable_duplicate_lookup";
DROP INDEX IF EXISTS public.idx_hazard_resolution_reports_approved_user;

DROP TRIGGER IF EXISTS on_hazard_resolution_reports_set_points ON public.hazard_resolution_reports;
DROP FUNCTION IF EXISTS public.handle_hazard_resolution_points();

ALTER TABLE public.hazard_resolution_reports
  DROP COLUMN IF EXISTS points_awarded;

CREATE OR REPLACE FUNCTION public.enforce_report_table_status_authorization()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF tg_op = 'INSERT' THEN
    IF NEW.status IS NULL THEN
      NEW.status := 'pending';
    ELSIF NEW.status <> 'pending' AND NOT COALESCE(public.verify_admin_access(), false) THEN
      NEW.status := 'pending';
    END IF;
  ELSIF tg_op = 'UPDATE' THEN
    IF NEW.status IS DISTINCT FROM OLD.status THEN
      IF pg_trigger_depth() > 1 AND NEW.status = 'resolved' THEN
        NULL;
      ELSIF NOT COALESCE(public.verify_admin_access(), false) THEN
        RAISE EXCEPTION 'Only administrators can update report status.';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.enforce_report_table_status_authorization() FROM PUBLIC, anon, authenticated;

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
      AND COALESCE(r.status, 'pending') IN ('active', 'resolved')
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
      AND COALESCE(r.status, 'pending') IN ('active', 'resolved')
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

REVOKE ALL ON FUNCTION public.get_leaderboard(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text) TO authenticated;

NOTIFY pgrst, 'reload schema';
