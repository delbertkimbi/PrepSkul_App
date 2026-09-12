# PrepSkul App — structure & naming

Marketplace product (`main`). Kids product lives on the `primar` branch.

## Top-level

| Path | Role |
| --- | --- |
| `lib/features/` | Product features (keep names; do not nest another `prepskul_app/`) |
| `lib/core/` | Shared config, theme, services, navigation |
| `docs/` | Living setup docs — prefer `ENVIRONMENT_SETUP.md`, `DILIGENCE.md`, `LAUNCH_SCOPE.md` |
| `supabase/migrations/` | Ordered schema migrations (empty placeholder files are junk) |
| `test/` | Unit/widget tests mirroring `lib/features/` |

## Feature names (do not confuse)

| Folder / flag | Meaning |
| --- | --- |
| `features/skulmate/` + `AppConfig.enableSkulMate` | Revision games / decks for students (marketplace) |
| `features/primar/` + `AppConfig.enablePrimar` | Kids foundational learning (parked; `false` on marketplace `main`) |
| `features/sessions/` | Live Agora classroom, PiP, onsite presence |
| `features/booking/` | Trials, recurring/individual sessions, My Sessions |
| `features/group_classes/` | Group class create/join (gated by `GROUP_CLASSES_ENABLED`) |
| `features/tutor/` | Tutor home, requests, session detail / Join |
| `features/messaging/` | Chat |
| `features/payment/` | Fapshi / credits |

Web APIs: `/api/skulmate/*` = games product; `/api/primar/*` and `/primar` = kids product (hidden on www unless enabled).

## Diligence hygiene

Do **not** commit:

- `All mds/` (historical SQL/MD dump)
- `PREPSKUL_WEB_BACKEND_FILES/`
- Nested `prepskul_app/` build trees
- `.env`, key inventory docs, `secrets.txt`
- Chat exports (`cursor_*.md`), screenshots, `flutter_*.log`

Canonical clone: https://github.com/delbertkimbi/PrepSkul_App
