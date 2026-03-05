# Fapshi Keys in Production – What To Do

The Flutter web app (on Firebase Hosting) needs Fapshi API keys at runtime. They are **injected into the app at build time** so you never commit them to Git.

**In short:** Set the two env vars (in your terminal or in CI), run **`node scripts/inject-env.js`**, then **`flutter build web`**, then **`firebase deploy --only hosting`**. Order matters: inject → build → deploy.

---

## Option A: Build on your computer, then deploy (simplest)

Use this if you run `flutter build web` and `firebase deploy` from your own machine.

### Step 1: Have the keys in `.env` (recommended)

The inject script **reads your project `.env` file** automatically. Ensure your `.env` contains (with your real values; do not commit `.env`):

```env
FAPSHI_SANDBOX_API_USER=your_sandbox_api_user_here
FAPSHI_SANDBOX_API_KEY=your_sandbox_api_key_here
```

For **live** payments, also add `FAPSHI_COLLECTION_API_USER_LIVE` and `FAPSHI_COLLECTION_API_KEY_LIVE`.  
You can skip manually setting env vars in the terminal; the script loads `.env` for you.

### Step 2: Run these two commands in order

In the project root (e.g. `PrepSkul_App`), in the **same** terminal where you set the env vars (if you used the PowerShell method):

1. **Inject the keys into `web/index.html`:**
   ```powershell
   node scripts/inject-env.js
   ```
   You should see: `✅ Environment variables injected into index.html` and a list that includes the Fapshi variables.

2. **Build the web app:**
   ```powershell
   flutter build web
   ```

### Step 3: Deploy to Firebase Hosting

```powershell
firebase deploy --only hosting
```

(Use `firebase deploy --only hosting --project YOUR_PROJECT_ID` if you need to specify the project.)

After this, the live site will have the Fapshi keys and payments can work.

**Quick copy-paste (Option A)** – with `.env` in place, run in project root:

```powershell
node scripts/inject-env.js
flutter build web
firebase deploy --only hosting
```

---

## Option B: Build in CI (e.g. GitHub Actions)

Use this if your web app is built by a CI pipeline, not on your computer.

### Step 1: Add the keys as secrets in your CI

- **GitHub Actions:** Repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.  
  Create secrets with these **exact** names:
  - `FAPSHI_SANDBOX_API_USER`
  - `FAPSHI_SANDBOX_API_KEY`
  - (For live later: `FAPSHI_COLLECTION_API_USER_LIVE`, `FAPSHI_COLLECTION_API_KEY_LIVE`)

- **Other CI:** In your CI’s “Secrets” or “Environment variables” UI, create variables with the same names and mark them as secret.

### Step 2: Run inject then build in your workflow

In the job that builds the Flutter web app, do these in order:

1. **Export the secrets as environment variables** (example for GitHub Actions):
   ```yaml
   env:
     FAPSHI_SANDBOX_API_USER: ${{ secrets.FAPSHI_SANDBOX_API_USER }}
     FAPSHI_SANDBOX_API_KEY: ${{ secrets.FAPSHI_SANDBOX_API_KEY }}
   ```
   (Or the equivalent in your CI: make the secret values available as `FAPSHI_SANDBOX_API_USER` and `FAPSHI_SANDBOX_API_KEY` in the environment.)

2. **Inject env into `index.html`, then build:**
   ```bash
   node scripts/inject-env.js
   flutter build web
   ```

3. Deploy the `build/web` folder (e.g. to Firebase Hosting) the same way you do now.

---

## Summary checklist

| Step | What to do |
|------|------------|
| 1 | Put Fapshi keys in `.env` (local build) or in CI secrets (CI build). **Never commit real keys to Git.** |
| 2 | Run **`node scripts/inject-env.js`** (in an environment where those variables are set). |
| 3 | Run **`flutter build web`** (so the injected `index.html` is used). |
| 4 | Deploy **`build/web`** to Firebase Hosting (e.g. `firebase deploy --only hosting`). |

Order matters: **inject first, then build, then deploy.**

---

## Where the keys are *not* set

- **Firebase Hosting** has no “Environment variables” for static files. The app gets the keys from the **built** `index.html`, which was produced when you ran the inject script before building.
- **Vercel** env vars are for the Next.js backend. The Flutter app does not read them; it only reads what’s in `window.env` in the built `index.html`.

So: you set the keys in **your build environment** (your `.env` or CI secrets), then the inject script puts them into the build that you deploy.
