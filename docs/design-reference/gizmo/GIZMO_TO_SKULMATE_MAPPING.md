# Gizmo → SkulMate component mapping

Maps Gizmo UX patterns to **existing PrepSkul code** and **planned work** from [SKULMATE_ADAPTIVE_LEARNING_PRD.md](../product/SKULMATE_ADAPTIVE_LEARNING_PRD.md).

---

## Home screen

| Gizmo element | Adopt? | SkulMate implementation |
|---------------|--------|-------------------------|
| Mascot + question headline | ✅ Adapt | Reuse `SkulMateMascotMediaWidget` + **"What shall we revise today?"** / FR |
| History pill | ✅ Adapt | Recent generations → `SkulMateHistoryScreen` |
| Live pill | ⚠️ Phase 2 | Map to **Blitz** / `ChallengesScreen` |
| Chat input “I want to study…” | ✅ Yes | **`I want to revise…`** — `SkulMateStudyIntentField` |
| Action chip grid | ✅ Yes | Extract from `skulmate_upload_screen.dart` + **From class** |
| + dropdown sources | ✅ Yes | Same sources + **From class** (PrepSkul-only) |
| Jump back in carousel | ✅ Yes | Rename **Continue** — `SkulMateContinueRow` |
| My decks list | ✅ Adapt | **My games** / Library — `GameModel` + progress % |
| Recent chats | ✅ Phase 2 | SkulMate threads, not “Chat” branding |
| Search community decks | ❌ Adapt | **Explore subjects** — exam + STEAM packs |
| 5-tab bottom nav | ✅ Adapt | Home · Progress · + · **Library** · Profile |

### Deprecate / demote

| Current | Change |
|---------|--------|
| `GameLibraryScreen` 3 tabs as landing | **Home** replaces default; tabs move to Decks sub-area |
| `SkulMateUploadScreen` as primary | Becomes sheet/modal from home chips |
| Filter chips (Quiz/Flashcards…) on landing | Move to Decks library only |

---

## Post-import flow

| Gizmo mode | SkulMate mode | Backend |
|------------|---------------|---------|
| Memorise | **Drill** | `/api/skulmate/generate` `gameType: flashcards` |
| Note | **Sheet** | `/api/skulmate/summarize` or intent branch |
| Step-by-step lesson | **Path** | `/api/skulmate/lesson/plan` |
| — | **Play** (default) | Existing auto game pipeline |
| — | **Scroll** | Feed cards (Phase A shell) |
| — | **From class** | `/api/skulmate/challenge/from-session` |

**New UI:** `SkulMateIntentSheet` — PrepSkul labels per [SKULMATE_TERMINOLOGY.md](../../product/SKULMATE_TERMINOLOGY.md).

**Reference:** Gizmo chat screen with mode cards — we adopt layout, not copy.

---

## Curriculum & adaptive layer (PrepSkul advantage)

**PrepSkul adds beneath intake** (Gizmo does not expose this in home UI):

```
Upload / YouTube / notes / session
        ↓
Concept extraction (existing entity pipeline in generate route)
        ↓
Curriculum matcher (NEW) — GCE/WAEC/BEPC syllabus nodes
        ↓
Learner profile (survey: subjects, level, exam, location)
        ↓
Adaptive prompt assembly (NEW)
  • User material = primary source
  • Curriculum DB = exam alignment
  • LLM knowledge + optional web = supplementary (labeled)
        ↓
Mode output: lesson | deck | game | feed cards
        ↓
Mastery update → reroute if stuck (Google Maps loop)
```

See PRD §6 (journeys) and §7 (curriculum pipeline) for API contract.

---

## File-level map (existing)

| Concern | File |
|---------|------|
| Library (current home) | `screens/game_library_screen.dart` |
| Upload | `screens/skulmate_upload_screen.dart` |
| Generation | `screens/game_generation_screen.dart` |
| Optional context | `widgets/generation_context_sheet.dart` |
| Daily challenge | `widgets/daily_challenge_card.dart` |
| Home teaser (main app) | `widgets/skulmate_home_teaser.dart` |
| API client | `services/skulmate_service.dart` |
| Generate API | `PrepSkul_Web/app/api/skulmate/generate/route.ts` |
| Session challenge | `PrepSkul_Web/app/api/skulmate/challenge/from-session/route.ts` |
| Explain + YouTube | `PrepSkul_Web/app/api/skulmate/explain/route.ts` |

---

## New files (planned)

| Component | Path (proposed) |
|-----------|-----------------|
| SkulMate home | `screens/skulmate_home_screen.dart` |
| Study intent field | `widgets/skulmate_study_intent_field.dart` |
| Action chips | `widgets/skulmate_import_action_grid.dart` |
| Jump back in row | `widgets/skulmate_continue_row.dart` |
| Intent/mode sheet | `widgets/skulmate_intent_sheet.dart` |
| Lesson overview | `screens/skulmate_path_overview_screen.dart` |
| Curriculum service | `services/curriculum_context_service.dart` |
| Mastery (client) | `services/mastery_tracking_service.dart` |

---

## Visual differentiation (stay PrepSkul)

| Gizmo | SkulMate |
|-------|----------|
| Purple axolotl | Cameroon **character system** |
| Generic decks | **Session-linked games** + **exam track** tags |
| Chat-only AI | AI + **130+ tutors** escalation |
| Flashcard-first | **Play** + game variety (quiz, matching, escape room…) |
| “Study” / “Memorise” | **Revise** / **Drill** / **Path** |

---

## Success metrics (home redesign)

| Metric | Baseline | Target (8 weeks post-launch) |
|--------|----------|------------------------------|
| Taps to start studying from SkulMate tab | ~3+ (tab → upload → generate) | **1–2** |
| D7 SkulMate retention | TBD | +15% vs library layout |
| Uploads per WAU | TBD | +20% |
| Session → revision completion | TBD | 40% of eligible sessions |
