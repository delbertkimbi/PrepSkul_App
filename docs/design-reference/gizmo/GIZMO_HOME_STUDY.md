# Gizmo home & creation UX — study notes

**App:** Gizmo (Save All Ltd) — AI flashcards / adaptive study  
**Purpose:** Inform **SkulMate home** and **content intake** — principles over pixel clone  
**Date:** June 2026  
**Product owner context:** PrepSkul “Google Maps for Learning” — see [SKULMATE_ADAPTIVE_LEARNING_PRD.md](../product/SKULMATE_ADAPTIVE_LEARNING_PRD.md)

---

## Executive summary

Gizmo feels “seamless” because **home = create + resume**, not **browse a library**.

| Gizmo prioritizes | SkulMate today prioritizes |
|-------------------|----------------------------|
| Open-ended study intent | File upload workflow |
| Resume with % progress | Tab: Sessions / My Games / Upload |
| Decks & chats as objects | Game type filters |
| Mode picker after import | Auto game generation |
| Lesson as structured path | Many game screens, no unified “lesson” |

**PrepSkul should adopt Gizmo’s shell** and **beat it** with: live-class revision, game depth, curriculum alignment (GCE/WAEC/BEPC), tutor escalation.

---

## 1. Home screen anatomy

### 1.1 Top zone — emotional entry

- **Mascot** (purple axolotl, meditative pose) — brand + warmth
- **Headline:** “What shall we study?” — question, not command
- **History** (clock) — past threads / sessions
- **Live** (cube + red dot) — social/live quiz layer

**Principle:** Lower cognitive load before any file metaphor.

### 1.2 Hero — chat-style creation hub (~60% of above-the-fold)

```
┌─────────────────────────────────────┐
│  I want to study...            [+]  │
├─────────────────────────────────────┤
│ [Upload][Photo][Deck]               │
│ [YouTube][Paste][More ▾]            │
└─────────────────────────────────────┘
```

- **Text field** captures natural language intent
- **`+` menu** duplicates and extends chips: PDF, PPT, YouTube, Notes, Photo, Record lecture, Quizlet, Deck
- **More** expands without navigation away from home

**Principle:** One surface for all import paths; zero “which tab do I use?”

### 1.3 Middle — continuity (scroll)

#### Jump back in
- Horizontal carousel
- Each card: **circular progress %**, title, sub-label (**Chat** | **Quiz**)
- “View all” for full history

#### My decks
- Vertical cards with **left color accent**
- Metadata: title, **N cards**, **progress pill** (e.g. 50%)
- Overflow menu (⋮)
- Section `+` for new deck

#### Recent chats
- Purple chat bubble icon
- Timestamp (e.g. 7h)
- Treats AI conversation as durable artifact

#### Discovery
- “Search 100 million flashcards” — community corpus

**Principle:** Home answers “continue” before “organize.”

### 1.4 Bottom navigation

| Tab | Icon | Role |
|-----|------|------|
| Home | House (active pill) | Create + resume |
| Progress | Flame | Streak / momentum |
| Add | **Green FAB center** | Global create (same as hero) |
| Decks | Folder/cards | Full library |
| Profile | Mascot + badge | Account |

**Principle:** Library is one tap away, not the default landing experience.

---

## 2. Import modals (bottom sheets)

Pattern: **magic wand icon + title + focused field + dark Continue**

| Modal | Field | Notes |
|-------|-------|-------|
| Import from notes | Paste textarea | Keyboard-forward |
| Quizlet set import | URL `https://quizlet.com/...` | Deep link ingestion |
| Import photos | Thumbnail grid + `+` tile | Multi-image |

Background home stays visible (context preservation).

---

## 3. Post-upload — Chat + mode cards

After PDF/resume/etc.:

1. Screen title: **Chat**
2. File chip top-right (PDF)
3. **Gizmo** avatar + prompt
4. **Three mode cards** (single-select, colored border):
   - **Memorise** (elephant) → Generate flashcards
   - **Note** (scroll) → Generate a note
   - **Step-by-step lesson** (owl) → Structured curriculum from doc
5. **Primary CTA** mirrors selection: “Start memorising” / “Generate note”
6. Footer chat input: **“I want to learn…”**

**Principle:** Structured paths + conversational escape hatch — reduces “what now?” after upload.

### PrepSkul extension (beyond Gizmo)

SkulMate adds two mode cards Gizmo lacks, plus a **curriculum layer** under every mode:

| SkulMate mode | Output | Curriculum hook |
|---------------|--------|-----------------|
| Memorise | Flashcards | Cards tagged to syllabus node (e.g. GCE AL Chem — electrolysis) |
| Note | Summary | Objectives aligned to exam board learning outcomes |
| Lesson | Step path | Steps sequenced per curriculum progression |
| **Play game** | Quiz / matching / etc. | Questions in past-paper style when enabled |
| **From session** | Session challenge | Topics from live class summary |

**Generation stack** (user material first, then enrichment):

1. Extract concepts from upload (PDF, YouTube transcript, pasted notes, session summary)
2. Match to curriculum nodes (GCE/WAEC/BEPC)
3. Inject learner context (level, weak topics, preferred style)
4. Optionally add LLM / web context — always labeled, never overriding user notes silently
5. Render chosen mode

Full API contract: [SKULMATE_ADAPTIVE_LEARNING_PRD.md §7](../../product/SKULMATE_ADAPTIVE_LEARNING_PRD.md).

---

## 4. Lesson overview

- Title from content (editable ✏️)
- **Step 1…N** cards with chevron
- **“N more”** collapse for long curricula
- **Regenerate** (magic wand)
- **Start lesson (8 steps)** full-width CTA

**Principle:** Sell **learning journey**, not flashcard deck.

---

## 5. What makes it feel seamless (design system)

| Element | Gizmo choice | SkulMate implication |
|---------|--------------|----------------------|
| Corners | Large radius (24–32px) | Match `SkulMateSurfaceStyles` soft cards |
| Density | Generous whitespace | Reduce filter bars on home |
| Color | White base, purple accent, green primary CTA | Keep PrepSkul blue + character colors |
| Typography | Bold question, regular metadata | Poppins already aligned |
| Progress | Rings + pills everywhere | Add to deck cards, daily challenge |
| Motion | (assumed) subtle sheet transitions | Bottom sheets for import + intent |

---

## 6. What PrepSkul should NOT copy blindly

| Gizmo | Why skip or adapt |
|-------|-------------------|
| Generic “study anything” | Anchor **GCE / WAEC / BEPC / Probatoire** where profile allows |
| Chat-only tutor | Add **Play game** + **Session revision** modes |
| 100M flashcards search | **Local exam packs** + tutor marketplace first |
| Entertainment-first scroll | Optimize for **mastery minutes**, not infinite feed |
| No human tutor | **Escalate to PrepSkul tutor** on repeated failure |

---

## 7. SkulMate home wireframe (target)

See [GIZMO_TO_SKULMATE_MAPPING.md](./GIZMO_TO_SKULMATE_MAPPING.md) for component-level mapping.

High-level:

```
[History]                    [Live / Friends]
        🦎 skulMate mascot
     What shall we revise today?

┌ I want to study...        [+] ┐
│ [Upload][Photo][Paste][YT][Session] │
└─────────────────────────────────────┘

Jump back in                    View all
[ 50% Chem Quiz ] [ Chat Photo… ] [ 🔥 Daily ]

From your last class            View all
[ Tutor session → 5-min challenge ]

My decks                          [+]
▌ Form 5 Maths · 12 cards · 8%
▌ Biology · 2 cards · 50%

     Home   🔥    [+]    Decks   Profile
```

---

## 8. Open questions (for product)

1. Should **“I want to study…”** default to **topic-only** generation without upload when user types? (Gizmo does)
2. Is **Live** equivalent to SkulMate **friend challenges** or new real-time feature?
3. Parent view: same home or **child switcher** at top?
4. French/English copy on hero for Cameroon market?

---

## References

- Screenshots: see [README.md](./README.md) — re-add PNGs to this folder when available
- PrepSkul current library: `lib/features/skulmate/screens/game_library_screen.dart`
- PrepSkul upload: `lib/features/skulmate/screens/skulmate_upload_screen.dart`
