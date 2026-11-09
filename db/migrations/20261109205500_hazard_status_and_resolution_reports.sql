-- migrate:up

-- ============================================================================
-- 1. HAZARD REPORT STATUS LIFECYCLE ON public."ReportTable"
--    Statuses:
--      - 'pending'  : Needs admin verification (default on user submission; not shown on map)
--      - 'active'   : Verified by admin and shown on the live map
--      - 'resolved' : Hazard is no longer present and is hidden from the live map
--      - 'archived' / 'rejected' : Administrative lifecycle states
-- ============================================================================

ALTER TABLE public."ReportTable"
  ALTER COLUMN status SET DEFAULT 'pending';

ALTER TABLE public."ReportTable"
  DROP CONSTRAINT IF EXISTS "ReportTable_status_check";

ALTER TABLE public."ReportTable"
  ADD CONSTRAINT "ReportTable_status_check"
  CHECK (status IN ('pending', 'active', 'resolved', 'archived', 'rejected'));

ALTER TABLE public."ReportTable"
  ADD COLUMN IF NOT EXISTS verified_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS verified_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS resolved_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS resolution_status text,
  ADD COLUMN IF NOT EXISTS resolution_image_url text,
  ADD COLUMN IF NOT EXISTS resolution_reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS resolution_reported_at timestamp with time zone,
  ADD COLUMN IF NOT EXISTS resolution_count integer DEFAULT 0;

ALTER TABLE public."ReportTable"
  DROP CONSTRAINT IF EXISTS "ReportTable_resolution_status_check";

ALTER TABLE public."ReportTable"
  ADD CONSTRAINT "ReportTable_resolution_status_check"
  CHECK (
    resolution_status IS NULL
    OR resolution_status IN ('pending', 'approved', 'rejected')
  );

CREATE INDEX IF NOT EXISTS "idx_ReportTable_status_created_at"
  ON public."ReportTable" (status, created_at DESC);

CREATE INDEX IF NOT EXISTS "idx_ReportTable_pending_resolutions"
  ON public."ReportTable" (resolution_status, resolution_reported_at DESC)
  WHERE resolution_status = 'pending';

-- Allow admins (in addition to report owners) to update or delete rows in ReportTable.
-- Restrict client inserts and non-admin updates so unreviewed reports cannot be set to 'active'.
DROP POLICY IF EXISTS "Allow anon users to insert hazard reports" ON public."ReportTable";
CREATE POLICY "Allow anon users to insert hazard reports"
  ON public."ReportTable"
  FOR INSERT
  TO anon
  WITH CHECK (
    user_id IS NULL
    AND (status IS NULL OR status = 'pending')
  );

DROP POLICY IF EXISTS "Allow authenticated users to insert hazard reports" ON public."ReportTable";
CREATE POLICY "Allow authenticated users to insert hazard reports"
  ON public."ReportTable"
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (user_id IS NULL OR (SELECT auth.uid()) = user_id)
    AND (
      (status IS NULL OR status = 'pending')
      OR (SELECT public.verify_admin_access())
    )
  );

DROP POLICY IF EXISTS "Allow users to update own hazard reports" ON public."ReportTable";
DROP POLICY IF EXISTS "Allow users or admins to update hazard reports" ON public."ReportTable";
CREATE POLICY "Allow users or admins to update hazard reports"
  ON public."ReportTable"
  FOR UPDATE
  TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR (SELECT public.verify_admin_access())
  )
  WITH CHECK (
    (SELECT public.verify_admin_access())
    OR (
      (SELECT auth.uid()) = user_id
      AND status = 'pending'
    )
  );

DROP POLICY IF EXISTS "Allow users to delete own hazard reports" ON public."ReportTable";
DROP POLICY IF EXISTS "Allow users or admins to delete hazard reports" ON public."ReportTable";
CREATE POLICY "Allow users or admins to delete hazard reports"
  ON public."ReportTable"
  FOR DELETE
  TO authenticated
  USING (
    (SELECT auth.uid()) = user_id
    OR (SELECT public.verify_admin_access())
  );

-- Enforce that non-admins cannot insert active reports or alter report status
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
    IF NEW.status IS DISTINCT FROM OLD.status AND NOT COALESCE(public.verify_admin_access(), false) THEN
      RAISE EXCEPTION 'Only administrators can update report status.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.enforce_report_table_status_authorization() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS on_report_table_enforce_status_auth ON public."ReportTable";
CREATE TRIGGER on_report_table_enforce_status_auth
  BEFORE INSERT OR UPDATE OF status ON public."ReportTable"
  FOR EACH ROW
  EXECUTE FUNCTION public.enforce_report_table_status_authorization();

-- Automatically stamp verified_at / resolved_at when ReportTable.status changes by an admin
CREATE OR REPLACE FUNCTION public.handle_report_table_status_timestamps()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'active' AND COALESCE(OLD.status, '') <> 'active' THEN
    NEW.verified_at := COALESCE(NEW.verified_at, timezone('utc'::text, now()));
    NEW.verified_by := COALESCE(NEW.verified_by, auth.uid());
  ELSIF NEW.status = 'resolved' AND COALESCE(OLD.status, '') <> 'resolved' THEN
    NEW.resolved_at := COALESCE(NEW.resolved_at, timezone('utc'::text, now()));
    NEW.resolution_status := COALESCE(NEW.resolution_status, 'approved');
  END IF;
  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.handle_report_table_status_timestamps() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS on_report_table_status_timestamps ON public."ReportTable";
CREATE TRIGGER on_report_table_status_timestamps
  BEFORE UPDATE OF status ON public."ReportTable"
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_report_table_status_timestamps();

-- ============================================================================
-- 2. UPDATE ALERT SYNC SO ONLY 'active' REPORTS PUBLISH ACTIVE ALERTS
-- ============================================================================

CREATE OR REPLACE FUNCTION public.sync_alert_from_hazard_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_category_raw text;
  v_category_lower text;
  v_severity text;
  v_alert_type text;
  v_title text;
  v_raw_addr text;
  v_short_addr text;
  v_location_label text;
  v_body text;
  v_has_valid_coords boolean;
BEGIN
  v_has_valid_coords := (
    new.latitude IS NOT NULL
    AND new.longitude IS NOT NULL
    AND new.latitude BETWEEN -90.0 AND 90.0
    AND new.longitude BETWEEN -180.0 AND 180.0
  );

  IF NOT v_has_valid_coords THEN
    IF tg_op = 'UPDATE' THEN
      UPDATE public.alerts
      SET is_active = false,
          updated_at = timezone('utc'::text, now())
      WHERE report_id = new."reportID";
    END IF;
    RETURN new;
  END IF;

  v_category_raw := coalesce(nullif(trim(new.hazard_category), ''), 'Hazard');
  v_category_lower := lower(v_category_raw);

  v_severity := CASE
    WHEN lower(coalesce(new.severity_level, '')) LIKE '%high%'
      OR lower(coalesce(new.severity_level, '')) LIKE '%critical%' THEN 'High'
    WHEN lower(coalesce(new.severity_level, '')) LIKE '%low%' THEN 'Low'
    ELSE 'Medium'
  END;

  IF v_severity = 'High'
     OR v_category_lower LIKE '%flood%'
     OR v_category_lower LIKE '%fire%'
     OR v_category_lower LIKE '%accident%'
     OR v_category_lower LIKE '%streetlight%'
     OR v_category_lower LIKE '%lighting%' THEN
    v_alert_type := 'hazard';
  ELSE
    v_alert_type := 'community';
  END IF;

  v_title := coalesce(nullif(trim(new.detected_hazard), ''), initcap(v_category_raw));

  v_raw_addr := coalesce(nullif(trim(new.location_address), ''), '');
  IF v_raw_addr = '' OR lower(v_raw_addr) = 'current location' THEN
    v_location_label := 'Reported nearby';
  ELSE
    v_short_addr := trim(
      concat_ws(
        ', ',
        nullif(trim(split_part(v_raw_addr, ',', 1)), ''),
        nullif(trim(split_part(v_raw_addr, ',', 2)), '')
      )
    );
    IF v_short_addr = '' THEN
      v_short_addr := left(v_raw_addr, 72);
    ELSE
      v_short_addr := left(v_short_addr, 72);
    END IF;

    IF lower(v_short_addr) LIKE 'near %' THEN
      v_location_label := v_short_addr;
    ELSE
      v_location_label := 'Near ' || v_short_addr;
    END IF;
  END IF;

  IF nullif(trim(new.description), '') IS NOT NULL THEN
    v_body := left(trim(new.description), 280);
  ELSIF v_alert_type = 'hazard' THEN
    v_body := 'A user reported ' || lower(v_category_raw) || ' ' || lower(v_location_label) || ' (' || v_severity || ' severity).';
  ELSE
    v_body := 'Community report: ' || lower(v_category_raw) || ' ' || lower(v_location_label) || '. Use alternative routes if needed.';
  END IF;

  INSERT INTO public.alerts (
    alert_type,
    title,
    body,
    location_label,
    latitude,
    longitude,
    severity_level,
    report_id,
    target_user_id,
    is_active,
    created_at,
    updated_at
  )
  VALUES (
    v_alert_type,
    v_title,
    v_body,
    v_location_label,
    new.latitude,
    new.longitude,
    v_severity,
    new."reportID",
    null,
    coalesce(new.status, 'pending') = 'active',
    coalesce(new.created_at, timezone('utc'::text, now())),
    timezone('utc'::text, now())
  )
  ON CONFLICT (report_id) DO UPDATE SET
    alert_type = excluded.alert_type,
    title = excluded.title,
    body = excluded.body,
    location_label = excluded.location_label,
    latitude = excluded.latitude,
    longitude = excluded.longitude,
    severity_level = excluded.severity_level,
    is_active = excluded.is_active,
    updated_at = timezone('utc'::text, now());

  RETURN new;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_alert_from_hazard_report() FROM public, anon, authenticated;

-- ============================================================================
-- 3. USER-REPORTED HAZARD RESOLUTION SUBMISSIONS (public.hazard_resolution_reports)
--    Stores camera proof and full hazard context when a user reports that an
--    active hazard has already been resolved, pending admin verification.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.hazard_resolution_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  report_id text NOT NULL REFERENCES public."ReportTable"("reportID") ON DELETE CASCADE,
  reported_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  hazard_category text NOT NULL,
  detected_hazard text NOT NULL,
  hazard_description text,
  severity_level text,
  location_address text,
  latitude double precision,
  longitude double precision,
  original_image_url text,
  resolution_image_url text NOT NULL,
  resolution_note text,
  status text NOT NULL DEFAULT 'pending',
  verified_by uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  verified_at timestamp with time zone,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  updated_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT hazard_resolution_reports_status_check CHECK (
    status IN ('pending', 'approved', 'rejected')
  ),
  CONSTRAINT hazard_resolution_reports_coords_check CHECK (
    (latitude IS NULL AND longitude IS NULL)
    OR (
      latitude BETWEEN -90.0 AND 90.0
      AND longitude BETWEEN -180.0 AND 180.0
    )
  )
);

CREATE INDEX IF NOT EXISTS idx_hazard_resolution_reports_report_id
  ON public.hazard_resolution_reports (report_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hazard_resolution_reports_reported_by
  ON public.hazard_resolution_reports (reported_by, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_hazard_resolution_reports_status_created
  ON public.hazard_resolution_reports (status, created_at DESC);

-- Idempotency constraint: allow multiple users to submit resolution reports for the same hazard,
-- while preventing the same user from submitting duplicate pending reports for the same hazard
DROP INDEX IF EXISTS public.idx_hazard_resolution_reports_unique_pending;
CREATE UNIQUE INDEX IF NOT EXISTS idx_hazard_resolution_reports_unique_pending
  ON public.hazard_resolution_reports (
    report_id,
    reported_by
  )
  WHERE status = 'pending' AND reported_by IS NOT NULL;

DROP TRIGGER IF EXISTS on_hazard_resolution_reports_updated ON public.hazard_resolution_reports;
CREATE TRIGGER on_hazard_resolution_reports_updated
  BEFORE UPDATE ON public.hazard_resolution_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- Enforce that resolution submissions only target currently 'active' hazards
CREATE OR REPLACE FUNCTION public.validate_hazard_resolution_submission()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_report_status text;
BEGIN
  SELECT status INTO v_report_status
  FROM public."ReportTable"
  WHERE "reportID" = NEW.report_id;

  IF v_report_status IS NULL THEN
    RAISE EXCEPTION 'Target hazard report % does not exist.', NEW.report_id;
  END IF;

  IF v_report_status <> 'active' THEN
    RAISE EXCEPTION 'Resolution reports can only be submitted for active hazards (current status: %).', v_report_status;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.validate_hazard_resolution_submission() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS on_hazard_resolution_reports_validate ON public.hazard_resolution_reports;
CREATE TRIGGER on_hazard_resolution_reports_validate
  BEFORE INSERT ON public.hazard_resolution_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_hazard_resolution_submission();

-- Recompute resolution summary on ReportTable from all remaining resolution submissions
CREATE OR REPLACE FUNCTION public.recompute_report_table_resolution_state(p_report_id text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending RECORD;
  v_approved RECORD;
  v_rejected RECORD;
  v_pending_count integer := 0;
BEGIN
  SELECT COUNT(*) INTO v_pending_count
  FROM public.hazard_resolution_reports
  WHERE report_id = p_report_id AND status = 'pending';

  -- 1. If any pending resolution report remains, show pending
  SELECT resolution_image_url, reported_by, created_at
  INTO v_pending
  FROM public.hazard_resolution_reports
  WHERE report_id = p_report_id AND status = 'pending'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    UPDATE public."ReportTable"
    SET resolution_status = 'pending',
        resolution_image_url = v_pending.resolution_image_url,
        resolution_reported_by = v_pending.reported_by,
        resolution_reported_at = v_pending.created_at,
        resolution_count = v_pending_count
    WHERE "reportID" = p_report_id;
    RETURN;
  END IF;

  -- 2. Else if an approved resolution report exists, show approved
  SELECT resolution_image_url, reported_by, created_at
  INTO v_approved
  FROM public.hazard_resolution_reports
  WHERE report_id = p_report_id AND status = 'approved'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    UPDATE public."ReportTable"
    SET resolution_status = 'approved',
        resolution_image_url = v_approved.resolution_image_url,
        resolution_reported_by = v_approved.reported_by,
        resolution_reported_at = v_approved.created_at,
        resolution_count = 0
    WHERE "reportID" = p_report_id;
    RETURN;
  END IF;

  -- 3. Else if a rejected resolution report exists, show rejected
  SELECT resolution_image_url, reported_by, created_at
  INTO v_rejected
  FROM public.hazard_resolution_reports
  WHERE report_id = p_report_id AND status = 'rejected'
  ORDER BY created_at DESC
  LIMIT 1;

  IF FOUND THEN
    UPDATE public."ReportTable"
    SET resolution_status = 'rejected',
        resolution_image_url = v_rejected.resolution_image_url,
        resolution_reported_by = v_rejected.reported_by,
        resolution_reported_at = v_rejected.created_at,
        resolution_count = 0
    WHERE "reportID" = p_report_id;
    RETURN;
  END IF;

  -- 4. No resolution records remain
  UPDATE public."ReportTable"
  SET resolution_status = NULL,
      resolution_image_url = NULL,
      resolution_reported_by = NULL,
      resolution_reported_at = NULL,
      resolution_count = 0
  WHERE "reportID" = p_report_id;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.recompute_report_table_resolution_state(text) FROM public, anon, authenticated;

-- Synchronize resolution submission, approval, rejection, and deletion with public."ReportTable"
CREATE OR REPLACE FUNCTION public.sync_report_table_from_resolution_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pending_count integer;
  v_distinct_reporters integer;
BEGIN
  IF pg_trigger_depth() > 1 THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  IF tg_op = 'INSERT' THEN
    -- Count pending resolution reports and distinct reporters
    SELECT
      COUNT(*),
      COUNT(DISTINCT COALESCE(reported_by, id))
    INTO
      v_pending_count,
      v_distinct_reporters
    FROM public.hazard_resolution_reports
    WHERE report_id = NEW.report_id
      AND status = 'pending';

    -- When multiple people (>= 2) report resolution on the same hazard,
    -- the system automatically marks the hazard resolved!
    IF v_distinct_reporters >= 2 OR v_pending_count >= 2 THEN
      -- 1. Update parent hazard to resolved in ReportTable
      UPDATE public."ReportTable"
      SET status = 'resolved',
          resolution_status = 'approved',
          resolved_at = timezone('utc'::text, now()),
          resolution_image_url = NEW.resolution_image_url,
          resolution_reported_by = NEW.reported_by,
          resolution_reported_at = NEW.created_at,
          resolution_count = v_pending_count
      WHERE "reportID" = NEW.report_id
        AND status = 'active';

      -- 2. Mark all pending resolution reports for this hazard as approved
      UPDATE public.hazard_resolution_reports
      SET status = 'approved',
          verified_at = timezone('utc'::text, now()),
          updated_at = timezone('utc'::text, now())
      WHERE report_id = NEW.report_id
        AND status = 'pending';
    ELSE
      PERFORM public.recompute_report_table_resolution_state(NEW.report_id);
    END IF;

  ELSIF tg_op = 'UPDATE' THEN
    IF NEW.status = 'approved' AND COALESCE(OLD.status, '') <> 'approved' THEN
      -- Only transition linked hazard from 'active' to 'resolved' (Comment 5)
      UPDATE public."ReportTable"
      SET status = 'resolved',
          resolution_status = 'approved',
          resolved_at = COALESCE(NEW.verified_at, timezone('utc'::text, now()))
      WHERE "reportID" = NEW.report_id
        AND status = 'active';
    END IF;
    PERFORM public.recompute_report_table_resolution_state(NEW.report_id);
  ELSIF tg_op = 'DELETE' THEN
    PERFORM public.recompute_report_table_resolution_state(OLD.report_id);
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.sync_report_table_from_resolution_report() FROM public, anon, authenticated;

DROP TRIGGER IF EXISTS on_hazard_resolution_report_sync ON public.hazard_resolution_reports;
CREATE TRIGGER on_hazard_resolution_report_sync
  AFTER INSERT OR UPDATE OR DELETE ON public.hazard_resolution_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_report_table_from_resolution_report();

-- Drop opposing trigger on ReportTable to prevent unreviewed proofs from auto-approving and avoid deadlocks (Comment 6, 8)
DROP TRIGGER IF EXISTS on_report_table_resolved_sync_resolutions ON public."ReportTable";
DROP FUNCTION IF EXISTS public.sync_resolution_reports_on_report_resolved();

ALTER TABLE public.hazard_resolution_reports ENABLE ROW LEVEL SECURITY;

-- Comment 2: Remove public SELECT access and restrict to reporter or admin
DROP POLICY IF EXISTS "Allow public read access to hazard resolution reports" ON public.hazard_resolution_reports;
DROP POLICY IF EXISTS "Allow reporters or admins to view hazard resolution reports" ON public.hazard_resolution_reports;
CREATE POLICY "Allow reporters or admins to view hazard resolution reports"
  ON public.hazard_resolution_reports
  FOR SELECT
  TO authenticated
  USING (
    (SELECT auth.uid()) = reported_by
    OR (SELECT public.verify_admin_access())
  );

-- Comment 4: Enforce target hazard is active before accepting resolution submission
DROP POLICY IF EXISTS "Allow anon users to insert pending hazard resolution reports" ON public.hazard_resolution_reports;
CREATE POLICY "Allow anon users to insert pending hazard resolution reports"
  ON public.hazard_resolution_reports
  FOR INSERT
  TO anon
  WITH CHECK (
    reported_by IS NULL
    AND status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public."ReportTable" r
      WHERE r."reportID" = report_id
        AND r.status = 'active'
    )
  );

DROP POLICY IF EXISTS "Allow authenticated users to insert pending hazard resolution reports" ON public.hazard_resolution_reports;
CREATE POLICY "Allow authenticated users to insert pending hazard resolution reports"
  ON public.hazard_resolution_reports
  FOR INSERT
  TO authenticated
  WITH CHECK (
    (reported_by IS NULL OR (SELECT auth.uid()) = reported_by)
    AND status = 'pending'
    AND EXISTS (
      SELECT 1 FROM public."ReportTable" r
      WHERE r."reportID" = report_id
        AND r.status = 'active'
    )
  );

DROP POLICY IF EXISTS "Allow admins to update hazard resolution reports" ON public.hazard_resolution_reports;
CREATE POLICY "Allow admins to update hazard resolution reports"
  ON public.hazard_resolution_reports
  FOR UPDATE
  TO authenticated
  USING ((SELECT public.verify_admin_access()))
  WITH CHECK ((SELECT public.verify_admin_access()));

DROP POLICY IF EXISTS "Allow reporters or admins to delete hazard resolution reports" ON public.hazard_resolution_reports;
CREATE POLICY "Allow reporters or admins to delete hazard resolution reports"
  ON public.hazard_resolution_reports
  FOR DELETE
  TO authenticated
  USING (
    (SELECT auth.uid()) = reported_by
    OR (SELECT public.verify_admin_access())
  );

-- Grants: DO NOT grant SELECT to anon or public (Comment 2)
REVOKE ALL ON public.hazard_resolution_reports FROM anon, authenticated, public;
GRANT INSERT ON public.hazard_resolution_reports TO anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.hazard_resolution_reports TO authenticated;

-- ============================================================================
-- 4. UPDATE LEADERBOARD RPC SO ONLY ACCEPTED REPORTS ('active', 'resolved')
--    ARE COUNTED TOWARD USER REPORTS, POINTS, AND LEVEL PROGRESSION
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

GRANT EXECUTE ON FUNCTION public.get_leaderboard(text) TO authenticated, anon;

NOTIFY pgrst, 'reload schema';

-- migrate:down

DROP TRIGGER IF EXISTS on_report_table_resolved_sync_resolutions ON public."ReportTable";
DROP FUNCTION IF EXISTS public.sync_resolution_reports_on_report_resolved();

DROP TRIGGER IF EXISTS on_hazard_resolution_report_sync ON public.hazard_resolution_reports;
DROP FUNCTION IF EXISTS public.sync_report_table_from_resolution_report();

DROP TRIGGER IF EXISTS on_hazard_resolution_reports_validate ON public.hazard_resolution_reports;
DROP FUNCTION IF EXISTS public.validate_hazard_resolution_submission();

DROP FUNCTION IF EXISTS public.recompute_report_table_resolution_state(text);

DROP INDEX IF EXISTS public.idx_hazard_resolution_reports_unique_pending;
DROP TRIGGER IF EXISTS on_hazard_resolution_reports_updated ON public.hazard_resolution_reports;
DROP TABLE IF EXISTS public.hazard_resolution_reports;

DROP TRIGGER IF EXISTS on_report_table_enforce_status_auth ON public."ReportTable";
DROP FUNCTION IF EXISTS public.enforce_report_table_status_authorization();

DROP TRIGGER IF EXISTS on_report_table_status_timestamps ON public."ReportTable";
DROP FUNCTION IF EXISTS public.handle_report_table_status_timestamps();

DROP INDEX IF EXISTS public."idx_ReportTable_pending_resolutions";
DROP INDEX IF EXISTS public."idx_ReportTable_status_created_at";

-- Comment 13: Migrate pending and rejected rows to 'archived' so rolled back clients safely exclude them
UPDATE public."ReportTable"
SET status = 'archived'
WHERE status IN ('pending', 'rejected');

ALTER TABLE public."ReportTable"
  DROP CONSTRAINT IF EXISTS "ReportTable_resolution_status_check";

ALTER TABLE public."ReportTable"
  DROP COLUMN IF EXISTS resolution_count,
  DROP COLUMN IF EXISTS resolution_reported_at,
  DROP COLUMN IF EXISTS resolution_reported_by,
  DROP COLUMN IF EXISTS resolution_image_url,
  DROP COLUMN IF EXISTS resolution_status,
  DROP COLUMN IF EXISTS resolved_at,
  DROP COLUMN IF EXISTS verified_at,
  DROP COLUMN IF EXISTS verified_by;

ALTER TABLE public."ReportTable"
  ALTER COLUMN status SET DEFAULT 'active';

ALTER TABLE public."ReportTable"
  DROP CONSTRAINT IF EXISTS "ReportTable_status_check";

ALTER TABLE public."ReportTable"
  ADD CONSTRAINT "ReportTable_status_check"
  CHECK (status IN ('active', 'resolved', 'archived'));
