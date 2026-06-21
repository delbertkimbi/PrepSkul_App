# Google Maps for Learning — Implementation Plan

**Product:** PrepSkul SkulMate  
**Date:** June 2026  
**Status:** Planning — execution starting Phase D + Maps UX  
**Companion docs:** [SKULMATE_ADAPTIVE_LEARNING_PRD.md](./SKULMATE_ADAPTIVE_LEARNING_PRD.md) · [SKULMATE_TERMINOLOGY.md](./SKULMATE_TERMINOLOGY.md) · [PREPSKUL_INVESTOR_PITCH_FAQ.txt](./PREPSKUL_INVESTOR_PITCH_FAQ.txt)

---

## 1. What “Google Maps for learning” means (build spec)

Every feature must answer one of these five questions:

| # | Maps question | SkulMate build target | Learner feels |
|---|---------------|----------------------|---------------|
| 1 | **Where am I?** | Capability estimate per topic (not grade label) | “Here’s what I’m solid on vs shaky” |
| 2 | **Where am I going?** | Goal from onboarding + parent/tutor context | “I’m working toward X” |
| 3 | **What’s next?** | One clear next action (due review, weak topic, continue) | “Do this now” |
| 4 | **Reroute** | Struggle → easier modality, prerequisite, or tutor | “It adapted when I got stuck” |
| 5 | **ETA / progress** | Mastery delta, streak, parent readiness (gated) | “I’m getting closer” |

**Locked product rules (do not break):**
- Never block off-syllabus / open topics in learner UI
- No exam board / syllabus labels in **learner** UI
- Parent view may show exam context only when child profile matches
- Resurfacing is strict, dismissible, capped (no nagging)
- Skip “find tutor” if active tutor exists
- User upload / source content is always primary in AI prompts

---

## 2. Current state audit

### Phase A — SkulMate home & intake ✅ (mostly done)

| ID | Deliverable | Status |
|----|-------------|--------|
| A1 | SkulMateHomeScreen landing | ✅ |
| A2 | Bilingual intent + import grid | ✅ |
| A3 | Continue row with % | ✅ |
| A4 | Intent sheet Play·Scroll·Path·Drill·Sheet | ✅ (Scroll/Sheet coming soon) |
| A5 | Library sub-nav | ✅ |
| A6 | Sub-nav Home·Progress·+·Library·Profile | ✅ |
| A7 | YouTube intake | ✅ (needs Web deploy for transcript route) |
| A8 | Free tier + enrichment flag | ✅ |

**Gap:** Engagement data exists but Scroll/Path modes not wired.

---

### Phase B — Curriculum context ✅ (background only)

| ID | Deliverable | Status |
|----|-------------|--------|
| B0–B3 | Schema, seed nodes, survey→learnerContext, matcher | ✅ |
| B4 | Exam tags on decks (learner UI) | ❌ **Intentionally skipped** — parent/admin only |
| B5 | Past-paper-style toggle | ⬜ Not started |

**Gap:** B5 optional; curriculum is background signal only (correct).

---

### Phase C — Mastery graph & rerouting ✅ (core done)

| ID | Deliverable | Status |
|----|-------------|--------|
| C1 | `skulmate_concept_mastery` + EMA scoring | ✅ migrations 100–101 |
| C2 | Weak topic home nudge | ✅ in-app; ⬜ push notification |
| C3 | Explanation style A/B | ✅ |
| C4 | Parent progress view + digest | ✅ in-app; digest needs deploy + migration 102 |
| C5 | Tutor escalation | ✅ |

**Gaps:**
- Learner Progress tab still XP/streak only — no topic map
- C2 push resurfacing not built
- No “Next stop” card on home (only optional reroute nudge)

---

### Phase D — Feed & lesson ❌ (not started)

| ID | Deliverable | Status |
|----|-------------|--------|
| D1 | Lesson planner API + step UI | ⬜ stub UI only (`SkulMatePathOverviewScreen`) |
| D2 | Vertical swipe feed | ⬜ Scroll mode disabled |
| D3 | Web enrichment polish | ⚠️ partial |
| D4 | Spaced repetition (SM-2 lite) | ⬜ |

---

### Cross-cutting — Level understanding (pitch → product)

| Capability | Status |
|------------|--------|
| Declared level (onboarding / parent_learners) | ✅ |
| Observed level (mastery per topic) | ✅ |
| Human level (tutor session_summary → parent feed) | ✅ partial |
| Placement-lite diagnostics | ⬜ |
| Three-signal narrative in product copy | ⬜ |

---

## 3. Implementation phases (what we build next)

We organize work into **four execution tracks** that map to the Maps metaphor:

```
Track 1: SCHEDULE   (D4) — when to review → "what's next"
Track 2: FEED       (D2) — passive scroll → "glance while moving"
Track 3: PATH       (D1) — step UI → "turn-by-turn"
Track 4: MAPS UX    (new) — learner-visible navigation layer
```

**Recommended build order:** D4 → Maps UX (home) → D2 → D1 → C2 push → placement-lite

Rationale: spaced repetition creates the **queue** that powers “Next stop” and Scroll feed. Without D4, feed is random flashcards.

---

## 4. Track 1 — D4: Spaced repetition (SM-2 lite)

**Goal:** Every card/concept has `next_review_at`. Home can say “3 due today.”

### 4.1 Schema — migration `103_skulmate_review_schedule.sql`

```sql
-- Per user + game item (or concept key) review state
skulmate_review_items (
  id uuid PK,
  user_id uuid NOT NULL,
  child_id uuid,
  game_id uuid NOT NULL,
  item_index int NOT NULL,          -- index in game items array
  concept_key text,                 -- topic_id or term hash
  ease_factor float DEFAULT 2.5,
  interval_days int DEFAULT 0,
  repetitions int DEFAULT 0,
  next_review_at timestamptz,
  last_quality int,                 -- 0-5 SM-2 response
  last_reviewed_at timestamptz,
  created_at, updated_at,
  UNIQUE (user_id, child_id, game_id, item_index)
)
```

### 4.2 Logic — `PrepSkul_Web/lib/skulmate/spaced-repetition.ts` + Flutter mirror

- SM-2 lite: quality 0–5 from session outcome
  - Again (0–2): reset interval, repeat soon (10 min → same day)
  - Good (3): grow interval 1d → 3d → 7d → …
  - Easy (4–5): larger ease bump
- Map game session results → quality:
  - Flashcard: knew / didn’t know
  - Quiz: correct first try = 4, after hint = 3, wrong = 1

### 4.3 Flutter — `SpacedRepetitionService`

- `recordReview(gameId, itemIndex, quality)`
- `fetchDueQueue(limit: 20, childId?)`
- `dueCountToday()` for home badge
- Seed queue from existing games on first open

### 4.4 Integration points

- `ConceptMasteryService.recordSessionForGame` → also enqueue/update review items
- Home: **“Next stop”** card = top due item OR weak mastery item (priority: due > weak > continue)

### 4.5 Tests

- Jest: SM-2 interval math edge cases
- Flutter: queue ordering, empty state

**Estimate:** 1.5–2 weeks  
**Metrics:** % users with ≥1 due item completed/day; due queue completion rate

---

## 5. Track 4 — Maps UX (learner navigation layer)

**Goal:** Learner *feels* the map without syllabus labels.

### 5.1 M1 — “You are here” (Progress sheet upgrade)

**File:** `skulmate_progress_sheet.dart` + new `LearnerTopicProgressService`

Show (max 5 topics):
- Topic label from open topic id (humanized, no framework tags)
- Mastery bar (color band: solid / building / needs work)
- Last practiced relative time

No exam board. No “GCE” strings.

**Estimate:** 3–4 days

---

### 5.2 M2 — “Next stop” home card

**File:** `skulmate_next_stop_card.dart` on home (above or below Continue)

Priority queue:
1. Due spaced-rep item (Track 1)
2. Weak mastery + linked game (`RerouteSuggestionService` logic, always visible when due — not gated like nudge)
3. Continue in-progress game

Single CTA: “Review [topic]” / “Continue”

Dismissible per item; max 1 prominent card.

**Estimate:** 3–4 days (after D4)

---

### 5.3 M3 — Goal line (destination)

**File:** home hero subtitle from `learner_context_service` + parent_learners goals

Learner-facing examples:
- “Working on: Maths confidence” (from learning_goals)
- “Revision goal: 15 min today” (soft, not exam label)

**Estimate:** 2 days

---

### 5.4 M4 — Session → next stops (tutor loop)

When `individual_sessions.session_summary` exists for learner:
- Parse 1–3 focus phrases (API or simple keyword extract)
- Show on home: “From your last session with [tutor]: review …”
- Link to generate drill or open existing game

**Web:** optional `POST /api/skulmate/session-route`  
**Flutter:** read from `individual_sessions` (parent feed pattern already exists)

**Estimate:** 1 week

**Track 4 total:** ~2 weeks (parallel with D4 tail)

---

## 6. Track 2 — D2: Vertical scroll feed

**Goal:** Unlock **Scroll** intent mode → TikTok-style revision without infinite junk.

### 6.1 `SkulMateScrollFeedScreen`

- `PageView` vertical, one card per screen
- Card types: flashcard flip, micro-quiz (1 question), “got it” / “again”
- Queue from `SpacedRepetitionService.fetchDueQueue` + weak topics
- **Mastery gate:** after N cards, offer “play full game” or exit
- No infinite scroll — session ends when queue empty or user taps done

### 6.2 Wire intake

- `skulmate_intent_sheet.dart` — remove Scroll from `isComingSoonMode`
- `skulmate_intake_coordinator.dart` — Scroll → generate flashcards (preset) → open feed

### 6.3 API (optional)

- Reuse existing game items client-side first (MVP)
- Later: `POST /api/skulmate/feed-pack` for mixed modality pack

**Estimate:** 2 weeks (after D4)  
**Metrics:** Scroll sessions/week; cards reviewed per session; accuracy on due items

---

## 7. Track 3 — D1: Path (lesson planner)

**Goal:** **Path** mode = ordered steps through a topic (turn-by-turn).

### 7.1 Schema — migration `104_skulmate_lessons.sql`

```sql
skulmate_lessons (
  id uuid PK,
  user_id uuid,
  child_id uuid,
  source_game_id uuid,
  topic text,
  steps jsonb,           -- [{ type, title, payload, status }]
  current_step int,
  created_at, updated_at
)
```

Step types: `overview` | `concepts` | `drill` | `quiz` | `recap`

### 7.2 API — `POST /api/skulmate/lesson-plan`

Input: source text / gameId / topic + learnerContext  
Output: 4–6 steps with generated content refs (reuse generate pipeline chunks)

### 7.3 Flutter

- Replace `SkulMatePathOverviewScreen` stub with real stepper
- Each step launches existing game modes or inline sheet
- Progress persisted in `skulmate_lessons`

**Estimate:** 3–4 weeks  
**Metrics:** path completion rate; step drop-off; mastery delta on path topic

---

## 8. Phase C polish (parallel / later)

| ID | Task | Est. |
|----|------|------|
| C2b | Push notification for due review (not weak nudge) — weekly cap | 1 week |
| C4b | Deploy parent weekly digest cron + migration 102 | 2 days |
| C4c | YouTube transcript route deploy | 1 day |
| B5 | Past-paper-style question toggle (admin/parent opt-in) | 1 week |

---

## 9. Phase E — Placement-lite (level understanding)

**Goal:** Credibly answer “how do you know their level?” in product, not just pitch.

### 9.1 P1 — Friction diagnostic (onboarding add-on, skippable)

3 questions (already in FAQ):
- What breaks first in [subject]?
- Confidence 1–5 reading / maths / science
- What feels too hard for your class?

Store on `parent_learners` or `profiles.survey_data`. Feed `learnerContext`.

### 9.2 P2 — Micro placement (optional, 2 min)

- 3 adaptive maths items OR 60s reading passage + 2 questions
- Result: `placement_band` enum (foundational / on_track / advanced) per subject
- **Never shown as label to learner** — only adjusts generation difficulty

### 9.3 P3 — Confidence display

Parent view only: “Our estimate vs enrolled class” when placement contradicts class_level.

**Estimate:** 2–3 weeks (after core loop stable)  
**Metrics:** placement completion rate; correlation placement band vs mastery after 2 weeks

---

## 10. Sprint calendar (12-week view)

| Weeks | Focus | Ships |
|-------|--------|-------|
| **1–2** | D4 spaced repetition | migration 103, SM-2 service, review on game complete |
| **2–3** | Maps UX M1 + M2 | Progress topic bars, Next stop card |
| **3–4** | D2 Scroll feed MVP | Scroll mode live, feed screen |
| **4–5** | Maps UX M3 + M4 | Goal line, session→next stops |
| **5–8** | D1 Path planner | migration 104, lesson API, step UI |
| **8–9** | C2b push + digest deploy | retention cron live |
| **9–11** | P1–P2 placement-lite | onboarding diagnostic |
| **11–12** | Polish + metrics | analytics events, ops dashboard |

Adjust if classroom/tutoring fires need priority — Maps work is SkulMate-tab scoped.

---

## 11. Analytics events (add as you ship)

| Event | When |
|-------|------|
| `skulmate_next_stop_shown` | Home card rendered |
| `skulmate_next_stop_tapped` | User starts action |
| `skulmate_review_due_completed` | SM-2 item reviewed |
| `skulmate_scroll_session_end` | Feed session ends |
| `skulmate_path_step_complete` | Path step done |
| `skulmate_placement_completed` | Diagnostic finished |

---

## 12. Success metrics (Maps loop health)

| Metric | Target (90 days post D4) |
|--------|--------------------------|
| WAU with ≥1 voluntary revision session (≥5 min) | North star — baseline +20% |
| % sessions from Next stop / due queue | >30% |
| Weak topic mastery delta (30 days) | Positive trend on resurfaced topics |
| Scroll sessions / WAU | >0.5 |
| Path completion (of started paths) | >40% |
| Parent progress opens / month | Growing with digest |
| Tutor escalation → booking | Track; don’t optimize to spam |

---

## 13. File map (where work lands)

| Area | New / major files |
|------|-------------------|
| DB | `103_skulmate_review_schedule.sql`, `104_skulmate_lessons.sql` |
| Web | `lib/skulmate/spaced-repetition.ts`, `app/api/skulmate/lesson-plan/route.ts` |
| Flutter services | `spaced_repetition_service.dart`, `learner_topic_progress_service.dart`, `next_stop_service.dart` |
| Flutter UI | `skulmate_scroll_feed_screen.dart`, `skulmate_next_stop_card.dart`, path stepper |
| Tests | `__tests__/skulmate/spaced-repetition.test.ts` |

---

## 14. Immediate next step (start here)

**Sprint 1 ticket list (copy to Linear/issues):**

1. [ ] Write migration `103_skulmate_review_schedule.sql`
2. [ ] Implement `spaced-repetition.ts` + Jest tests
3. [ ] Implement `SpacedRepetitionService` (Flutter)
4. [ ] Hook `recordReview` into flashcard + quiz game completion
5. [ ] Add `dueCountToday()` to home top bar or progress tab
6. [ ] Build `SkulMateNextStopCard` (depends on queue)
7. [ ] Upgrade `SkulMateProgressSheet` with topic mastery bars (M1)

**Do not start D2 Scroll until #1–4 are done** — feed needs a queue.

---

## 15. Out of scope (this plan)

- Full psychometric assessment battery
- Learner-facing exam board tags
- Infinite TikTok scroll without mastery gates
- Autonomous AI teacher / open chat
- Replacing national curricula

---

## 16. Alignment checklist (Maps loop ↔ build)

| Loop step | Phase | Todo IDs | Learner-visible when done |
|-----------|-------|----------|---------------------------|
| Play / intake → session data | A ✅ | — | Continue row |
| Mastery graph (estimate) | C1 ✅ | — | Backend + parent view |
| Weak topic? → reroute nudge | C2 ✅ | `c2-push` | Home nudge |
| Adapt explain style | C3 ✅ | — | Quiz "Learn more" |
| Replay weak deck | C2 ✅ | `maps-m2` | Next stop card |
| Parent progress | C4 ✅ | `c4-digest-deploy` | Parent screen |
| **Spaced rep queue** | D4 | `d4-*` | Due count, queue |
| **Scroll feed** | D2 | `d2-*` | Scroll mode |
| **Where am I? (learner)** | Maps M1 | `maps-m1` | Progress topics |
| **What's next?** | Maps M2 | `maps-m2` | Next stop card |
| **Destination** | Maps M3 | `maps-m3` | Goal line |
| **Session → route** | Maps M4 | `maps-m4` | Post-tutor stops |
| Turn-by-turn path | D1 | `d1-*` | Path mode |

---

## 17. Definition of Done (every task)

Each todo is **done** only when ALL apply:

1. **Function** — Accepts real user/game data; handles empty/error states without crash
2. **UX** — EN + FR copy via `SkulMateCopy`; matches `AppTheme`; no exam labels in learner UI
3. **Tests** — Jest (Web logic) and/or Flutter analyze clean; unit tests for non-trivial math/policy
4. **Product rules** — No syllabus nagging; resurfacing gated; active tutor suppresses find-tutor
5. **Maps question** — Task documents which of the 5 Maps questions it answers

---

*Last updated: June 2026 — revise sprint calendar after Sprint 1 retrospective.*
