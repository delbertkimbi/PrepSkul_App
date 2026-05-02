# QA Env Setup (Flutter + Next.js)

Use this guide to control QA-only testing features safely.

## Goal

- Keep QA account quick-switch enabled in dev.
- Keep session join bypass disabled by default.
- Ensure production behavior stays normal.

## 1) Flutter app env (`prepskul_app/.env`)

Add/update:

```env
# QA / DEV TESTING UTILS
QA_QUICK_SWITCH_ENABLED=true
QA_SESSION_JOIN_BYPASS_ENABLED=false

# Optional one-tap QA logins
QA_TUTOR_PHONE=
QA_TUTOR_PASSWORD=
QA_LEARNER_PHONE=
QA_LEARNER_PASSWORD=
QA_OBSERVER_PHONE=
QA_OBSERVER_PASSWORD=
```

Notes:
- `QA_QUICK_SWITCH_ENABLED=true` shows dev login presets.
- `QA_SESSION_JOIN_BYPASS_ENABLED=false` keeps join auth strict.

## 2) Next.js env (`PrepSkul_Web/.env.local`)

Add/update:

```env
# QA / DEV TOKEN BYPASS (SERVER)
QA_SESSION_JOIN_BYPASS_ENABLED=false
```

Notes:
- This controls the API token route bypass.
- Keep this `false` unless explicitly running controlled QA bypass tests.

## 3) Production safety

Production stays safe because:
- Flutter blocks QA bypass in production mode (`isProduction=true`).
- Next.js bypass logic is disabled in production runtime (`NODE_ENV=production`).

## 4) Apply changes (important)

After editing env values:

1. Stop running Flutter app.
2. Restart Flutter app:
   - `flutter run -d chrome`
3. Hard refresh browser:
   - `Cmd + Shift + R`
4. If Next.js env changed, restart/deploy Next.js service.

## 5) Quick validation checklist

- Login page shows `QA Quick Switch (dev)` panel.
- Group class create/list API calls succeed.
- Agora token fetch uses expected API host.
- With bypass disabled, non-participants are denied join.

