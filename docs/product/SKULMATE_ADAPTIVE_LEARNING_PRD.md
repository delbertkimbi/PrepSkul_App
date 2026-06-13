# SkulMate Adaptive Learning — Product Requirements Document

**Product:** PrepSkul — SkulMate module  
**Version:** 1.0  
**Date:** June 2026  
**Status:** Approved — Phase A ready for implementation  

**Terminology:** [SKULMATE_TERMINOLOGY.md](./SKULMATE_TERMINOLOGY.md) — PrepSkul-native labels (not Gizmo clone)

**Related docs:**
- [Gizmo home study](../design-reference/gizmo/GIZMO_HOME_STUDY.md)
- [Gizmo → SkulMate mapping](../design-reference/gizmo/GIZMO_TO_SKULMATE_MAPPING.md)
- [Retention notifications](../RETENTION_NOTIFICATIONS_CHECKLIST.md)
- [SkulMate strategy](../../lib/features/skulmate/SKULMATE_STRATEGY_AND_CHARACTERS.md)
- [Post-session flows](../../lib/features/skulmate/FLOWS_PROMPTS_UX_PRD_ALIGNED.md)

---

## 1. Vision & positioning

### One-liner (external)

**PrepSkul is the Google Maps for learning** — it knows where a learner is, where they need to go, and reroutes daily revision when they get stuck.

### One-liner (learner)

Turn your notes, classes, and videos into games and revision paths that match **your level** — exams, school subjects, or anything you’re learning.

**Bilingual hero (launch):**  
- EN: *What shall we revise today?*  
- FR: *Qu'est-ce qu'on révise aujourd'hui ?*

### The Google Maps analogy (product architecture)

Google Maps is not a static road atlas. It continuously answers five questions. SkulMate must do the same for learning:

| Google Maps | SkulMate equivalent |
|-------------|---------------------|
| **Current location** | Estimated mastery per concept (not just class level) |
| **Destination** | Exam goal, syllabus unit, parent-defined target |
| **Best route** | Personalized revision path from uploads + curriculum |
| **Real-time reroute** | Weak-topic detection → easier explanation → prerequisite review |
| **ETA / progress** | Exam readiness signal, streak, topic % complete |
| **Traffic patterns** | Aggregate learner data: which paths work for which profiles |
| **Alternate routes** | Visual vs story vs quiz-first explanation styles |

**What this means in practice:**

```
Learner uploads GCE Chemistry notes on electrolysis
        ↓
System knows: Form 5 · GCE O Level · weak on ionic bonding (from past quizzes)
        ↓
Route A (default): user notes → flashcards → quiz → mastery update
        ↓
Learner fails bonding questions 3× in 7 days
        ↓
REROUTE: prerequisite review (ionic compounds) + simpler visual explanation
        ↓
Still failing? → "Book 30 min with tutor" (human intervention layer)
```

This is why **engagement loops come first** (Phase A): without daily interaction data, the "GPS" has no signal to reroute on.

### Strategic shift

| Era | Center of product | Revenue anchor |
|-----|-------------------|----------------|
| Phase 1 (now) | Tutor marketplace + sessions | Booking / sessions |
| Phase 2 (this PRD) | **AI-native adaptive revision** (SkulMate) | Parent exam-prep subscription |
| Phase 3 | Full learning navigation OS | Schools + platform |

Tutors become **intervention layer**, not the only product. See §8.

---

## 2. Problem statement

### Learner / parent pain

1. **Notes are passive** — PDFs and class notes don’t drive daily recall.
2. **Revision is generic** — same material for all Form 5 students regardless of gaps.
3. **Exam context missing** — content isn’t tied to GCE/WAEC/BEPC outcomes or past-paper patterns.
4. **Motivation drops** — static study vs TikTok/games competition.
5. **Tutors are expensive** — used for repetition AI could handle; scarce for true misconceptions.

### Why now

- LLMs + multimodal ingestion (PDF, image, YouTube) make **notes → interactive content** cheap.
- PrepSkul already has **live sessions**, **SkulMate games**, and **tutor network** — rare combination vs Gizmo/Revyze/Quizlet.

---

## 3. Goals & non-goals

### Goals (12 months)

1. **Daily habit:** median 15+ voluntary revision minutes/day among active SkulMate users.
2. **Exam alignment:** generated content tagged to syllabus + exam board when profile data exists.
3. **Adaptive paths:** weak-topic detection → resurfacing → optional tutor escalation.
4. **Gizmo-class UX:** home = create + resume (see Gizmo study), not library-first.
5. **Measurable outcomes:** quiz accuracy trend + parent-visible progress.

### Non-goals (this phase)

- Full autonomous AI teacher replacing all human instruction
- Infinite TikTok-style scroll without mastery gates
- 3D worlds / AI avatars / video generation at scale
- Replacing national curricula with unvetted LLM-only content

---

## 4. Target users & paying customer

### Primary payer: **Parents** (Cameroon + Francophone Africa first)

- Already pay for extra lessons, revision, textbooks.
- Buy **confidence + structure + exam improvement**, not “AI.”

### Primary user: **Student / learner** (Form 3–Upper Sixth, university prep)

- Virality, engagement, streaks.

### Secondary: **Tutors**

- AI teaching kit: diagnostics, assigned revision, session-linked challenges.

### Personas

| Persona | Job to be done | SkulMate promise |
|---------|----------------|------------------|
| Parent (Douala) | Child passes GCE A Level Chemistry | Weak topics visible; daily revision plan |
| Student (Bamenda) | Revise without boredom | Games + streak + class-linked challenges |
| Tutor | Less prep, better sessions | Auto quiz from last session; see student gaps |

---

## 5. Product principles

1. **Engagement loops before perfect AI** — no daily use → no adaptation data.
2. **Mastery over dopamine** — gamify, but gate progression on understanding.
3. **Curriculum-grounded generation** — user content first; syllabus + vetted context second; open web third (labeled).
4. **African context by default** — examples (Mobile Money, local transport, markets), exam boards, low-bandwidth paths.
5. **AI-first, human-supported** — tutor escalation on repeated failure or parent request.
6. **Don’t clone Gizmo** — adopt creation UX; differentiate on sessions, games, exams, tutors.

---

## 6. Core user journeys

### 6.1 Home → create (structure from Gizmo, PrepSkul language)

```
Open SkulMate tab
  → Mascot + "What shall we revise today?" / FR hero
  → Type intent OR tap Upload / Photo / Paste / YouTube / From class
  → SkulMateIntentSheet: Play | Scroll | Path | Drill | Sheet | From class
       (default: Play)
  → Generate
  → Land in game / path / sheet / scroll feed
```

See [SKULMATE_TERMINOLOGY.md](./SKULMATE_TERMINOLOGY.md) for all labels.

### 6.2 Home → resume

```
Jump back in carousel
  → Tap card (50% Chemistry Quiz)
  → Continue last session
```

### 6.3 Live class → revision (PrepSkul moat)

```
Recurring session ends → summary available
  → Push: "5-Minute Revision Challenge ready"
  → Play session-linked game
  → Update mastery + streak
```

Ref: `FLOWS_PROMPTS_UX_PRD_ALIGNED.md`, `/api/skulmate/challenge/from-session`

### 6.4 Adaptive reroute (“Google Maps”)

```
Learner fails topic 3× in 7 days
  → Home shows "Reroute: review prerequisites"
  → Easier explanation variant (visual / story / local analogy)
  → If still failing → "Book 30 min with tutor" CTA
```

### 6.5 Parent visibility (Phase 2)

```
Parent app → child SkulMate
  → Streak, minutes, weak topics, exam readiness (rough)
```

---

## 7. Curriculum-aware content pipeline

When user uploads **notes, PDF, YouTube, or session transcript**, the system must work **with that material** while enriching from **exam curriculum** and **safe external context**.

### 7.1 Input sources (supported / planned)

| Source | Status | Code |
|--------|--------|------|
| PDF / DOC | ✅ | `skulmate_upload_screen`, generate API |
| Image / photo scan | ✅ | Image picker + OCR path in API |
| Paste text | ✅ | `text_input_screen.dart` |
| YouTube | ⚠️ Partial | URL ingestion TBD; explain API returns YT recommendations |
| Live session summary | ✅ | `challenge/from-session` |
| Record lecture | 📋 Planned | Audio → transcript → same pipeline |
| Quizlet import | 📋 Planned | Gizmo parity |

### 7.2 Processing pipeline (target architecture)

```
┌─────────────────────────────────────────────────────────────┐
│ 1. INGEST                                                    │
│    Extract text / transcript / OCR from user asset           │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. CONCEPT SEGMENTATION (existing: entity extraction)        │
│    Topics, subtopics, terms, relationships, misconceptions   │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. CURRICULUM MATCH (NEW)                                    │
│    Map concepts → syllabus nodes (GCE/WAEC/BEPC/Probatoire)  │
│    Pull learning objectives + typical exam question patterns │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. LEARNER CONTEXT (NEW + profile)                           │
│    Level, subjects, survey goals, past performance, pace     │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. ADAPTIVE PROMPT ASSEMBLY (NEW)                           │
│    User content (primary) + curriculum snippets +            │
│    optional web enrichment (secondary, cited/disclaimed)     │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. OUTPUT MODE                                               │
│    Lesson steps | Flashcards | Game | Feed cards | Note      │
└───────────────────────────┬─────────────────────────────────┘
                            ▼
┌─────────────────────────────────────────────────────────────┐
│ 7. MASTERY UPDATE                                            │
│    Per-concept accuracy, speed, retries → learner graph      │
└─────────────────────────────────────────────────────────────┘
```

### 7.3 Curriculum data (to build)

**Initial scope (MVP):**

- Metadata on profile: `exam_board`, `level`, `subjects[]` (from learner/parent survey — partially exists)
- Manual **syllabus topic tags** on generation request (topic string today in `GenerationContext`)
- Static JSON corpus per subject/exam (maintained by ops/education team):

```json
{
  "exam_board": "GCE_AL",
  "subject": "Chemistry",
  "topic_id": "chem_organic_alkanes",
  "title": "Alkanes and alkenes",
  "objectives": ["..."],
  "typical_misconceptions": ["..."],
  "past_paper_patterns": ["define", "mechanism", "compare"]
}
```

**Phase 2:** Supabase tables `curriculum_nodes`, `curriculum_objectives`, `exam_boards`.

**Phase 3:** RAG over past papers + approved textbooks.

### 7.4 External / internet enrichment

**Policy:**

| Source | Priority | UI label |
|--------|----------|----------|
| User upload | Highest | “From your notes” |
| Session transcript | High | “From your class” |
| Curriculum DB | High | “Exam syllabus” |
| LLM parametric knowledge | Medium | “General knowledge” |
| Web search / fetch | **Paid default ON**; free opt-in | “Additional context” |

**Requirements:**

- Never contradict user material without flagging conflict.
- Hallucination guardrails on exam answers — prefer “I’m not sure, check with tutor” for high-stakes factual claims.
- Offline/low-data: skip web; use cached curriculum snippets only.

**API extension (proposed `generate` body):**

```typescript
{
  fileUrl?: string
  text?: string
  topic?: string
  learnerContext?: {
    userId: string
    examBoard?: 'GCE_OL' | 'GCE_AL' | 'WAEC' | 'BEPC' | 'PROBATOIRE' | 'OTHER'
    level?: string           // e.g. "Form 5", "U6"
    subjects?: string[]
    learningGoals?: string
    weakTopics?: string[]    // from mastery graph
    preferredStyle?: 'visual' | 'story' | 'quiz_first' | 'conversational'
  }
  curriculumHints?: {
    forceTopicIds?: string[]
    includePastPaperStyle?: boolean
  }
  enrichment?: {
    allowWeb?: boolean       // default true if paid plan; false on free
    allowModelKnowledge?: boolean  // default true
  }
  outputMode?: 'play' | 'scroll' | 'path' | 'drill' | 'sheet' | 'from_class'
}
```

Mobile already passes `learnerContext` in some flows (`skulmate_service.dart`) — **wire through to API and expand schema**.

### 7.5 Output modes (PrepSkul terminology)

| Mode | Label (EN) | User value | Implementation |
|------|------------|------------|----------------|
| **Play** | Play / Jouer | Fun recall — default | Existing game types |
| **Scroll** | Scroll / Défiler | Swipe revision feed | Phase A shell; full feed Phase D |
| **Path** | Path / Parcours | Step-by-step learn route | Lesson planner + UI |
| **Drill** | Drill / Répéter | Active recall cards | Flashcards + future SM-2 |
| **Sheet** | Sheet / Fiche | One-page summary | Summarize API branch |
| **From class** | From class | Session-linked challenge | `challenge/from-session` |

---

## 8. Tutor layer (not forgotten)

| AI handles daily | Tutor handles premium |
|------------------|----------------------|
| Revision games, streaks | Targeted 30–60 min intervention |
| Weak-topic detection | Misconception diagnosis |
| Spaced resurfacing | Motivation & accountability |
| Content transformation | Exam strategy, marking guidance |

**Escalation triggers (MVP rules):**

- Same concept wrong ≥3 times in 7 days
- Parent taps “Get tutor help” on weak topic
- Pre-exam readiness score below threshold (Phase 2)

Tutor receives: weak topics, failed items, learning style signals, last session summary.

---

## 9. What is built today (baseline inventory)

*As of June 2026 — use for sprint planning “done vs gap”.*

### 9.1 Mobile (`prepskul_app/lib/features/skulmate/`)

| Area | Status | Notes |
|------|--------|-------|
| **Feature flag** | ✅ `enableSkulMate = true` | `app_config.dart` |
| **Upload** PDF/image/text | ✅ | `skulmate_upload_screen.dart` |
| **Game generation** | ✅ | `game_generation_screen.dart` |
| **Game types** | ✅ 14+ types | quiz, flashcards, matching, escape room, … |
| **Game library** | ✅ | 3 tabs: Sessions, My Games, Upload |
| **Daily challenge** | ✅ | `daily_challenge_service.dart`, cards |
| **Streaks / XP / levels** | ✅ | `game_stats_service.dart` |
| **Characters** | ✅ | Onboarding + selection |
| **Social** | ✅ Partial | Friends, leaderboards, challenges screens |
| **Session summaries tab** | ✅ | In library |
| **Post-session challenge** | ✅ API exists | Push + play flow in progress |
| **Explain + YouTube refs** | ✅ | `/api/skulmate/explain` |
| **SkulMate home teaser** | ✅ | On main student home |
| **Onboarding** | ✅ | Tab intercept → character |
| **Credits / plans** | ✅ | `skulmate_plans_screen.dart` |
| **Generation context sheet** | ✅ Basic | topic, difficulty, game type |
| **Gizmo-style home** | ❌ | Library-first UX |
| **Intent/mode picker** | ❌ | Auto game type |
| **Lesson overview** | ❌ | — |
| **Mastery graph UI** | ❌ | — |
| **Curriculum tags** | ❌ | — |
| **Feed/swipe revision** | ❌ | — |
| **Local streak push** | ⚠️ Fixed recently | See retention checklist |

### 9.2 Backend (`PrepSkul_Web/app/api/skulmate/`)

| Endpoint | Status |
|----------|--------|
| `POST /generate` | ✅ Multi-model, entity extraction, game types |
| `POST /challenge/from-session` | ✅ |
| `POST /explain` | ✅ |
| Pricing / usage | ✅ |

### 9.3 Platform integration

| Area | Status |
|------|--------|
| Tutor marketplace & sessions | ✅ |
| Notifications (session + engagement crons) | ✅ Partial |
| Group classes | ✅ Flag-enabled in dev |
| Surveys (subjects, goals) | ✅ Data exists — not fed into generate yet |

---

## 10. Roadmap (phased)

### Phase A — **SkulMate tab: home & intake** (4–6 weeks)

**Goal:** 1–2 taps to start revising; creation feels chat-native. **Scope: SkulMate tab only** — other PrepSkul sections unchanged for now.

| ID | Deliverable |
|----|-------------|
| A1 | `SkulMateHomeScreen` replaces library as SkulMate tab landing |
| A2 | Bilingual intent field (EN/FR) + import action grid |
| A3 | **Continue** row with progress % (not “Jump back in” clone) |
| A4 | `SkulMateIntentSheet` — **Play · Scroll · Path · Drill · Sheet · From class** (default **Play**) |
| A5 | Demote Upload to sheet; **Library** sub-nav (not “Decks”) |
| A6 | SkulMate sub-nav: Home · Progress · + · Library · Profile |
| A7 | **YouTube URL intake** — transcript/metadata → same generate pipeline |
| A8 | Free-tier generation limits + paid web enrichment flag |

**Metrics:** taps-to-revise, D1/D7 retention, uploads/WAU, YouTube intake completion rate.

### Phase B — **Curriculum context** (6–8 weeks)

**Goal:** Generated content references correct exam + level.

| ID | Deliverable |
|----|-------------|
| B1 | `curriculum_nodes` seed: **GCE AL Maths, Chemistry, Biology** (+ room for STEAM / non-exam tracks) |
| B2 | Wire survey → `learnerContext` on every generate |
| B3 | API: curriculum matcher + prompt injection |
| B4 | UI: exam board + subject tags on decks |
| B5 | Past-paper-style question option toggle |

**Metrics:** parent NPS on “relevance”; tutor rating of auto-quizzes.

### Phase C — **Mastery graph & rerouting** (8–10 weeks)

**Goal:** Google Maps loop — estimate → adapt → reroute.

| ID | Deliverable |
|----|-------------|
| C1 | `concept_mastery` table (user, topic_id, score, last_seen) |
| C2 | Weak topic home card + push resurfacing |
| C3 | Explanation style A/B (visual vs story vs quiz-first) |
| C4 | Parent progress view |
| C5 | Tutor escalation card + booking deep link |

**Metrics:** weak-topic improvement rate; tutor escalation conversion.

### Phase D — **Feed & lesson** (10–14 weeks)

| ID | Deliverable |
|----|-------------|
| D1 | Lesson planner API + step UI |
| D2 | Vertical swipe feed from deck concepts |
| D3 | Web enrichment polish (paid default on; free opt-in) |
| D4 | Spaced repetition scheduler (SM-2 lite) |

---

## 11. Success metrics

### North star

**Weekly active learners with ≥3 self-initiated revision sessions (≥5 min each).**

### Supporting metrics

| Category | Metric |
|----------|--------|
| Engagement | Daily study minutes, streak length, D7/D30 retention |
| Learning | Quiz accuracy delta per topic, retry rate |
| Product | Time to first game, upload completion rate |
| Business | Parent conversion, tutor escalation bookings |
| Quality | % generations with curriculum tag; report rate |

---

## 12. Technical notes

### Stack (unchanged)

- Flutter mobile + web
- Supabase (profiles, games, stats, notifications)
- PrepSkul Web API + OpenRouter LLMs
- FCM + local notifications for retention

### New tables (proposed)

```sql
-- Phase B/C
curriculum_nodes (id, exam_board, subject, topic_id, title, objectives jsonb, ...)
concept_mastery (user_id, topic_id, score, attempts, last_played_at, ...)
skulmate_lessons (id, user_id, source_game_id, steps jsonb, ...)
skulmate_conversations (id, user_id, messages jsonb, ...)  -- optional Phase A2
```

### Privacy & safety

- User uploads stay user-scoped (existing RLS on `skulmate_games`)
- Web enrichment logged; no PII in prompts to third parties
- Parent/child accounts: childId scoping (already in API)

---

## 13. Competitive comparison

| Capability | Gizmo | Revyze | PrepSkul SkulMate (target) |
|------------|-------|--------|----------------------------|
| Notes → cards | ✅ | ✅ | ✅ |
| Gizmo-style home | ✅ | Partial | Phase A |
| Game variety | Low | Medium | **High** |
| Live tutoring | ❌ | ❌ | **✅** |
| Session → revision | ❌ | ❌ | **✅** |
| Exam curriculum | Generic | Generic | **Phase B moat** |
| African context | Limited | Limited | **Explicit goal** |

---

## 14. Product decisions (locked v1.0)

| # | Decision | Resolution |
|---|----------|--------------|
| 1 | **Curriculum seed** | GCE AL Maths, Chemistry, Biology first — **not exam-only**; support open revision, STEAM, class content, curiosity learning |
| 2 | **Web enrichment** | **On by default for paid**; free users opt in manually |
| 3 | **Default after upload** | **Play** — innovate with PrepSkul modes (Play, Scroll, Path, Drill, Sheet, From class); see [SKULMATE_TERMINOLOGY.md](./SKULMATE_TERMINOLOGY.md) |
| 4 | **French UI** | **Yes** — bilingual hero + intake + mode picker at launch |
| 5 | **Curriculum-aware generation pricing** | **Free tier with limits**; paid expands quota + web enrichment default |
| 6 | **YouTube pipeline** | **Phase A** — URL intake in home redesign |
| 7 | **Discovery** | **Explore subjects** / subject packs — PrepSkul terminology; learn Gizmo structure, don’t clone “100M flashcards” |
| 8 | **Scope** | **SkulMate tab first**; tutor home, parent app, etc. follow in later phases |

### Free vs paid (initial)

| Capability | Free | Paid |
|------------|------|------|
| Upload / generate (curriculum-aware) | Limited monthly quota | Higher / unlimited |
| Web enrichment | Opt-in | Default on |
| Game types | Core set | Full set + priority models |
| Path / Scroll / Sheet modes | Included within quota | Included |

*Exact quota numbers — set at launch based on API cost modelling.*

---

## 15. Appendix — document index

| Doc | Path |
|-----|------|
| Gizmo README | `docs/design-reference/gizmo/README.md` |
| Gizmo home study | `docs/design-reference/gizmo/GIZMO_HOME_STUDY.md` |
| Gizmo mapping | `docs/design-reference/gizmo/GIZMO_TO_SKULMATE_MAPPING.md` |
| Screen catalog | `docs/design-reference/gizmo/SCREEN_CATALOG.md` |
| Retention checklist | `docs/RETENTION_NOTIFICATIONS_CHECKLIST.md` |
| SkulMate explanation (legacy) | `docs/SKULMATE_EXPLANATION.md` |

---

## Revision history

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 0.9 | 2026-06-10 | PrepSkul team | Initial build-up PRD + Gizmo + curriculum pipeline |
| 1.0 | 2026-06-11 | PrepSkul team | Locked product decisions; SkulMate terminology; Phase A scope + YouTube |
