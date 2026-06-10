-- Allow authenticated users to read display fields for approved tutors (discovery).
-- Without this, tutor_profiles loads but profiles join / batch fetch returns empty under RLS.
--
-- NOTE: Do not inline EXISTS on tutor_profiles here — that causes infinite RLS recursion
-- when tutor_profiles policies reference profiles. See 089_fix_profiles_rls_recursion.sql.

DROP POLICY IF EXISTS "Authenticated can view approved tutor display profiles"
  ON public.profiles;

CREATE OR REPLACE FUNCTION public.is_public_approved_tutor(profile_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.tutor_profiles tp
    WHERE tp.user_id = profile_id
      AND tp.status = 'approved'
      AND COALESCE(tp.is_hidden, false) = false
  );
$$;

REVOKE ALL ON FUNCTION public.is_public_approved_tutor(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_public_approved_tutor(uuid) TO authenticated;

CREATE POLICY "Authenticated can view approved tutor display profiles"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (public.is_public_approved_tutor(id));
