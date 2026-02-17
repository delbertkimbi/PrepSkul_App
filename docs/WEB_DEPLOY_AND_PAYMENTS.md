# Web deploy and payments (production)

## Build errors fixed

- **`_defaultLat` / `_defaultLon` undefined** in `lib/features/sessions/widgets/web_map_helper.dart`  
  Fixed by defining default map center constants so the Leaflet routing iframe always has valid coordinates.

## Payments on production web

For **production** web, the app needs Supabase and Fapshi credentials at runtime. On web we don’t ship a `.env` file; we inject variables into `index.html` before building.

### 1. Inject env before building

Run the inject script **before** `flutter build web`:

```bash
cd prepskul_app
node scripts/inject-env.js
flutter build web
```

The script reads environment variables and writes them into `web/index.html` as `window.env`. The Flutter app (via `AppConfig` and `WindowEnvHelper` on web) reads from `window.env` when `dotenv` has no value.

### 2. Variables to set (CI or host, e.g. Vercel)

- **Supabase (required)**  
  - `SUPABASE_URL_PROD` or `NEXT_PUBLIC_SUPABASE_URL`  
  - `SUPABASE_ANON_KEY_PROD` or `NEXT_PUBLIC_SUPABASE_ANON_KEY`

- **Fapshi – production payments**  
  - `FAPSHI_COLLECTION_API_USER_LIVE`  
  - `FAPSHI_COLLECTION_API_KEY_LIVE`

- **Fapshi – sandbox (optional)**  
  - `FAPSHI_SANDBOX_API_USER`  
  - `FAPSHI_SANDBOX_API_KEY`

- **Optional**  
  - `ENVIRONMENT` (default `production`)

If these are not set, the script still runs and uses built‑in Supabase defaults so local/dev builds keep working; for production payments you must set the Fapshi live vars in your host/CI.

### 3. Example CI (e.g. GitHub Actions)

```yaml
- name: Inject env for Flutter web
  env:
    SUPABASE_URL_PROD: ${{ secrets.SUPABASE_URL_PROD }}
    SUPABASE_ANON_KEY_PROD: ${{ secrets.SUPABASE_ANON_KEY_PROD }}
    FAPSHI_COLLECTION_API_USER_LIVE: ${{ secrets.FAPSHI_COLLECTION_API_USER_LIVE }}
    FAPSHI_COLLECTION_API_KEY_LIVE: ${{ secrets.FAPSHI_COLLECTION_API_KEY_LIVE }}
  run: node scripts/inject-env.js
- run: flutter build web
```

### 4. Summary

| Step | What to do |
|------|------------|
| **Local / dev** | Optional: run `node scripts/inject-env.js` (uses defaults if env not set). |
| **Production deploy** | Set the env vars in your host/CI, run `node scripts/inject-env.js`, then `flutter build web`. |
| **Payments on web** | Ensure `FAPSHI_COLLECTION_API_USER_LIVE` and `FAPSHI_COLLECTION_API_KEY_LIVE` are set and injected so the app can initiate and confirm payments. |
