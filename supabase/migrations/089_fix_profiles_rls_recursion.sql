-- Fix 088: inline EXISTS on tutor_profiles caused infinite RLS recursion
-- (profiles policy → tutor_profiles policy → profiles → …).
-- Use a SECURITY DEFINER helper so the tutor check bypasses RLS on tutor_profiles.

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
