-- Users must be able to read, insert, and update their own profile row.
-- Without these policies, role selection and email-verify onboarding fail with 42501.

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Role is chosen on /role-selection; allow NULL until then.
ALTER TABLE public.profiles ALTER COLUMN user_type DROP NOT NULL;

DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Auto-create a minimal profile when a new auth user is registered.
CREATE OR REPLACE FUNCTION public.handle_new_auth_user_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    phone_number,
    survey_completed,
    is_admin
  )
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(
      NULLIF(TRIM(NEW.raw_user_meta_data->>'full_name'), ''),
      NULLIF(TRIM(split_part(COALESCE(NEW.email, ''), '@', 1)), '')
    ),
    NULLIF(TRIM(NEW.raw_user_meta_data->>'phone_number'), ''),
    false,
    false
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_handle_new_auth_user_profile ON auth.users;

CREATE TRIGGER trg_handle_new_auth_user_profile
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_auth_user_profile();

-- Backfill profiles for existing auth users missing a row.
INSERT INTO public.profiles (id, email, full_name, survey_completed, is_admin)
SELECT
  u.id,
  u.email,
  COALESCE(
    NULLIF(TRIM(u.raw_user_meta_data->>'full_name'), ''),
    NULLIF(TRIM(split_part(COALESCE(u.email, ''), '@', 1)), ''),
    'User'
  ),
  false,
  false
FROM auth.users u
WHERE NOT EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.id = u.id
);
