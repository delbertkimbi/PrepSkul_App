# GC-202 Dependency Freeze Manifest (2026-04-27)

Purpose: lock release-candidate dependencies for the 2-week stabilization window so reliability work is measured against a stable baseline.

## Freeze scope

- Flutter app: `prepskul_app`
- Web/API app: `PrepSkul_Web`

No dependency upgrades during this window unless explicitly approved by EM with rollback plan.

## Canonical lockfiles and checksums

- `prepskul_app/pubspec.lock`
  - SHA256: `a7452847eeea3b89d70d77148fedc93f77fcde55ff113be0600428ba23f8101d`
- `PrepSkul_Web/pnpm-lock.yaml`
  - SHA256: `2c026aea7a3725c51b548c4b8ac16a9f249060dcec751e98f26b29135a78b09b`
- `PrepSkul_Web/package.json`
  - SHA256: `5bb5aaf53d9594cfcaf0c0c42a763b5b0f45395f2f76b8a085e55b64e6d67b8e`
- `prepskul_app/pubspec.yaml`
  - SHA256: `d6127db8c691cddb9d3e985359cc489dde91c49bac1bb2fecec175c0c94d22fe`

## Key runtime dependency pins (baseline)

### Flutter app (`pubspec.lock` resolved versions)

- `agora_rtc_engine`: `6.5.3`
- `supabase_flutter`: `2.10.3`
- `supabase`: `2.10.0`
- `postgrest`: `2.5.0`
- `http`: `1.5.0`
- `firebase_core`: `3.15.2`
- `firebase_messaging`: `15.2.10`
- `google_sign_in`: `6.3.0`
- `flutter_local_notifications`: `16.3.3`
- `flutter`: `>=3.35.0` (lockfile SDK metadata)
- `dart`: `>=3.9.0 <4.0.0` (lockfile SDK metadata)

### Web/API app (`pnpm-lock.yaml` resolved versions)

- `next`: `15.5.9`
- `react`: `19.2.0`
- `react-dom`: `19.2.0`
- `agora-token`: `2.0.5`
- `@supabase/supabase-js`: `2.84.0`
- `@supabase/ssr`: `0.7.0`
- `firebase-admin`: `13.6.0`
- `typescript`: `5.9.3`
- `jest`: `29.7.0`

## Freeze rules (must follow)

1. Do not run dependency upgrade commands:
   - Flutter: `flutter pub upgrade`, `dart pub upgrade`
   - Web: `pnpm up`, `npm update`, `npm install <pkg>@latest`
2. Do not edit lockfiles unless approved by EM and linked to incident ticket.
3. Reliability fixes must be code-level (CORS, host normalization, diagnostics, tests), not version-churn workarounds.
4. If lockfile drift occurs, stop and reconcile before merging.

## Verification commands

Run before PR merge and before release-candidate cut:

```bash
shasum -a 256 prepskul_app/pubspec.lock PrepSkul_Web/pnpm-lock.yaml PrepSkul_Web/package.json prepskul_app/pubspec.yaml
```

Expected hashes must match this manifest exactly unless an approved change record exists.

## Allowed exception process

If a dependency change is unavoidable:

- Create change note with:
  - reason
  - impacted flows
  - rollback plan
  - re-test matrix
- Obtain EM approval before merge.
- Re-run GC-201 baseline suite and attach delta evidence.

## Owner and status

- Owner: EM/Tech Lead
- Task: `gc-202`
- Status: Freeze manifest established, ready for enforcement in subsequent tasks.
