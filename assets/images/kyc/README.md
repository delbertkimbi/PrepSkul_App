# KYC bear illustrations

Optional PNG heroes for the identity verification flow. Without them, the app uses the brand bear from `assets/characters/mascots/default.png`.

| File | Screen |
|------|--------|
| `kyc_intro.png` | Wizard intro |
| `kyc_submitted.png` | After submit |
| `kyc_pending.png` | Pending review |
| `kyc_rejected.png` | Resubmit (intro when previously rejected) |

**Prompts:** See [docs/MASCOT_IMAGE_PROMPTS.md](../../docs/MASCOT_IMAGE_PROMPTS.md) — attach your bear reference to each generation.

**Format:** Real PNG. After adding files: `flutter pub get` + full restart.
