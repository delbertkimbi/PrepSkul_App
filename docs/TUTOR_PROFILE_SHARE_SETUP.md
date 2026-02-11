# Tutor Profile Share – What Works and What You Need To Do

## Best experience checklist (deep linking + share)

| Item | Status / Action |
|------|------------------|
| **Next.js middleware** | `/tutor/*` must skip locale redirect so the request hits `app/tutor/[id]/page.tsx`. Done: middleware skips locale for `pathname.startsWith('/tutor/')`. |
| **iOS Universal Links** | App must claim `www.prepskul.com` so taps on shared links can open the app. Done: `Runner.entitlements` includes `applinks:www.prepskul.com`. |
| **Android App Links** | App must claim `https://www.prepskul.com/tutor` so taps open the app. Done: intent-filter for `www.prepskul.com` with `pathPrefix="/tutor"`. |
| **AASA (iOS)** | Served at `https://www.prepskul.com/.well-known/apple-app-site-association`. Replace `TEAM_ID` with your Apple Team ID. |
| **assetlinks.json (Android)** | Served at `https://www.prepskul.com/.well-known/assetlinks.json`. Replace `YOUR_SHA256_FINGERPRINT` with your app’s SHA256 cert fingerprint. |
| **Deploy Next.js at www** | The same app (PrepSkul_Web) that contains `app/tutor/[id]` must be deployed at `https://www.prepskul.com`. |
| **Flutter deep link** | No change needed: `_handleDeepLink` uses `uri.path`, so `https://www.prepskul.com/tutor/xxx` is handled as `/tutor/xxx` and opens the tutor profile. |

---

## Why you see the site logo instead of the tutor photo

If the preview shows **PrepSkul logo** and **"Find Trusted Home and Online Tutors in Cameroon"**, the crawler is **not** getting the tutor page — it is getting the **default site metadata** from the root layout. That usually means:

1. **The tutor route is not live at www.prepskul.com**  
   Deploy **PrepSkul_Web** (the Next.js app that contains `app/tutor/[id]/page.tsx`) so that **www.prepskul.com** serves it. The domain must point to this deployment; otherwise `/tutor/xxx` may 404 or hit another app and fall back to the default metadata.

2. **WhatsApp (or another app) cached the old preview**  
   After deploying, delete the old shared message and share the link again in a **new chat**, or wait for the cache to expire, so the crawler re-fetches the URL.

**Quick check after deploy:**  
In a terminal, run (use a real tutor id from your DB):

```bash
curl -s -A "WhatsApp/2.0" "https://www.prepskul.com/tutor/YOUR_TUTOR_ID" | grep -o 'og:title[^>]*\|og:image[^>]*'
```

You should see tutor-specific `og:title` and `og:image` (tutor name and avatar URL). If you see the default "Find Trusted Home..." title, the tutor page is still not being served for that URL.

---

## Does everything work now?

### Flutter app (mobile + web)

- **Share action:** Always uses the URL `https://www.prepskul.com/tutor/[id]`. No env vars or config needed. Works the same locally and in production.
- **No code or config changes** are required in the Flutter app for share to work in production.

### Next.js (www.prepskul.com)

- **Production:** Works as long as:
  1. Next.js is deployed at **https://www.prepskul.com** (or your main marketing site domain).
  2. The route **/tutor/[id]** is live (it is in `PrepSkul_Web/app/tutor/[id]/page.tsx`).
  3. Supabase is reachable from the Next.js server (same as today).
- **Locally:** If you run Next.js on `http://localhost:3000`:
  - Opening `http://localhost:3000/tutor/xyz` in a browser **redirects you** to `https://app.prepskul.com/tutor/xyz` (by design).
  - Rich preview (OG tags) is only used by **crawlers**. To test it locally you can:
    - Use `curl -A "WhatsApp/2.0" http://localhost:3000/tutor/[real-tutor-id]` and check that the HTML contains `<meta property="og:image"` etc., or
    - Deploy to production and share a link in WhatsApp to verify the preview.

### Summary

| Environment | Share from app | Rich preview (WhatsApp etc.) | Tap link → app / web |
|-------------|----------------|------------------------------|-----------------------|
| **Production** (app + Next.js deployed) | Yes | Yes (if Next.js is at www.prepskul.com) | Yes (redirect + deep link) |
| **Local** (Flutter + Next.js on localhost) | Yes (share text is always www URL) | Preview uses **production** www; local Next.js redirects browsers to app | Tap goes to www → prod redirect |

So: **production works end-to-end** once Next.js is deployed at www. **Locally**, share works; preview is only visible when the shared URL is opened by a crawler (e.g. production www); opening the tutor URL in a normal browser on localhost just redirects to the app.

---

## What you need to do for production

1. **Deploy Next.js** at **https://www.prepskul.com** (you likely already do).
2. **Optional env on Next.js (Vercel/host):**
   - `NEXT_PUBLIC_SITE_URL=https://www.prepskul.com` – only if your Next.js site is served from a different base URL.
   - `NEXT_PUBLIC_APP_URL=https://app.prepskul.com` – used for redirecting desktop users to Flutter Web; default is already this.
3. **Deep linking (so “Open in app” works from shared links):**
   - **iOS:** In `PrepSkul_Web/public/.well-known/apple-app-site-association`, replace `TEAM_ID` with your Apple Team ID. Ensure the Next.js site is served over HTTPS at the domain you use for Universal Links (e.g. www.prepskul.com).
   - **Android:** In `PrepSkul_Web/public/.well-known/assetlinks.json`, replace `YOUR_SHA256_FINGERPRINT` with your app’s SHA256 fingerprint. Ensure the file is served as `https://www.prepskul.com/.well-known/assetlinks.json` (or your chosen domain).
   - If AASA/assetlinks are not set or wrong, tapping the shared link still works: it opens in the browser and Next.js redirects to **app.prepskul.com/tutor/[id]** (Flutter Web). Only the “open directly in app” behavior depends on AASA/assetlinks.

---

## Will this affect the app or other features (web or app)?

**No impact on other features.** Only the following are involved:

| Area | What changed | Impact |
|------|----------------|--------|
| **Share tutor profile** | Shared URL is now **www.prepskul.com/tutor/[id]** instead of app.prepskul.com/tutor/[id]. | Only affects the link that is pasted when users tap “Share”. |
| **Opening a shared link** | Crawlers (WhatsApp, etc.) hit Next.js and get OG meta. Humans are redirected: mobile app → `prepskul://tutor/[id]`, desktop → app.prepskul.com/tutor/[id]. | Same as before for the user: they still end up in the app or Flutter Web; only the first URL they hit is now www. |
| **Deep links / notifications** | Unchanged. The app still handles `/tutor/[id]` and `prepskul://tutor/[id]` as before. | No impact. |
| **Flutter Web (app.prepskul.com)** | No code changes. It still serves `/tutor/[id]` when users land there (from redirect or direct). | No impact. |
| **Booking, sessions, auth, messaging, etc.** | Not touched. | No impact. |

So: **only “Share tutor profile” and the way shared links are served and redirected** use the new flow. The rest of the app and all other features behave the same.
