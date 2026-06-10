-- Auto-confirm phone-alias auth users so password login never requires an inbox step.
-- Phone signup uses emails like p237653301997@phone.prepskul.local (no real inbox).

CREATE OR REPLACE FUNCTION public.auto_confirm_phone_alias_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.email ~ '^p[0-9]+@phone\.prepskul\.local$' THEN
    NEW.email_confirmed_at := COALESCE(NEW.email_confirmed_at, NOW());
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_auto_confirm_phone_alias_auth_user ON auth.users;

CREATE TRIGGER trg_auto_confirm_phone_alias_auth_user
  BEFORE INSERT OR UPDATE OF email ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.auto_confirm_phone_alias_auth_user();

-- Callable from the mobile app when legacy rows were created before the trigger existed.
CREATE OR REPLACE FUNCTION public.confirm_phone_alias_auth(p_email text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_email !~ '^p[0-9]+@phone\.prepskul\.local$' THEN
    RAISE EXCEPTION 'Invalid phone alias email';
  END IF;

  UPDATE auth.users
  SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
  WHERE email = p_email;
END;
$$;

REVOKE ALL ON FUNCTION public.confirm_phone_alias_auth(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.confirm_phone_alias_auth(text) TO anon, authenticated, service_role;

-- Backfill existing unconfirmed phone-alias accounts.
UPDATE auth.users
SET email_confirmed_at = COALESCE(email_confirmed_at, NOW())
WHERE email ~ '^p[0-9]+@phone\.prepskul\.local$'
  AND email_confirmed_at IS NULL;
