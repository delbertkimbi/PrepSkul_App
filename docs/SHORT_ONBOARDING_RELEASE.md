# Short Mate onboarding release

Run this version from `/Users/user/Desktop/PrepSkul/prepskul_app_release`, branch `codex/short-mate-onboarding`, based on `main` at `bb02275c`.

```sh
flutter run -d chrome
```

First-time learners see the current animated Mate with EN/FR controls and one welcome, then a short information screen with the existing tutor photo, followed by role, name, school country/system, class, subject and goal. Tutor matching follows subject selection; city is requested only for in-person or flexible tutoring. Separate language, greeting, channel and pace pages no longer interrupt setup. The plan choice comes after signup, using the saved answers. Existing lesson voice controls remain available; learning preferences retain their existing balanced defaults.

Drafts now resume by step name. Older numeric drafts retain their answers and restart at the welcome so shortened navigation cannot skip questions. Draft restoration does not wait for text-to-speech initialization. The name field updates Continue immediately.

Validation: 20 focused onboarding, region, mascot mapping and session routing tests pass. Release uses the existing public configuration injector and payments-disabled configuration. Authenticated lessons and payments are outside this onboarding verification.

Build and publish:

```sh
node scripts/inject-env.js
flutter build web --release --no-wasm-dry-run
node scripts/check-release-config.js
firebase deploy --only hosting --project operating-axis-420213 --non-interactive
```

Hosting: https://operating-axis-420213.web.app
Use a private browser window to test a fresh onboarding without an existing account or completed-onboarding flag.

Fonts are bundled, with runtime font fetching disabled. Common bilingual onboarding prompts use bundled Puck audio; dynamic lesson speech still uses existing device/provider behavior. Offline Mate uses a static full-body render of the same Blender model, not a new animated 2D design.
