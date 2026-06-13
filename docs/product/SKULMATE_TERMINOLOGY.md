# SkulMate terminology & brand voice

**Purpose:** PrepSkul-native language for the SkulMate tab. We learn from Gizmo’s **structure**, not their **words**.  
**Scope:** SkulMate tab first; other PrepSkul sections keep their own labels until redesigned.  
**Bilingual:** EN + FR required at launch for hero, intake, and mode picker.

Related: [SKULMATE_ADAPTIVE_LEARNING_PRD.md](./SKULMATE_ADAPTIVE_LEARNING_PRD.md) · [Gizmo mapping](../design-reference/gizmo/GIZMO_TO_SKULMATE_MAPPING.md)

---

## Design principle

| Gizmo mental model | SkulMate mental model |
|--------------------|------------------------|
| Study anything | **Revise** what you learned (class, notes, exam, curiosity) |
| Flashcard deck | **Game / Pack** (we already generate games) |
| Lesson | **Path** (Google Maps route through a topic) |
| Memorise | **Drill** (active recall) |
| Note | **Sheet** (one-page revise summary) |
| Infinite community flashcards | **Explore subjects** (curriculum-aligned packs, not a clone of “100M flashcards”) |
| Jump back in | **Continue** |
| Gizmo Live | **Blitz** (head-to-head; maps to challenges later) |

---

## Bilingual copy — home & intake

| Element | English | French |
|---------|---------|--------|
| Hero question | What shall we revise today? | Qu'est-ce qu'on révise aujourd'hui ? |
| Intent placeholder | I want to revise… | Je veux réviser… |
| Continue section | Continue | Reprendre |
| View all | View all | Tout voir |
| From your last class | From your last class | Depuis ton dernier cours |
| My library section | My games | Mes jeux |
| Explore discovery | Explore subjects | Explorer les matières |
| Upload chip | Upload | Importer |
| Photo chip | Photo | Photo |
| Paste chip | Paste | Coller |
| YouTube chip | YouTube | YouTube |
| From class chip | From class | Depuis le cours |
| More chip | More | Plus |

---

## Post-upload mode picker (`SkulMateIntentSheet`)

Shown after upload / paste / YouTube / photo / typed topic. **Default selection: Play.**

| Mode ID | EN label | FR label | Subtitle (EN) | Maps to |
|---------|----------|----------|---------------|---------|
| `play` | **Play** | **Jouer** | Turn this into a game | Existing generate → game types |
| `scroll` | **Scroll** | **Défiler** | Swipe through bite-sized revision | Phase D feed UI; MVP can stub |
| `path` | **Path** | **Parcours** | Step-by-step learn route | Lesson planner (Phase A shell, B+ content) |
| `drill` | **Drill** | **Répéter** | Quick recall cards | `gameType: flashcards` |
| `sheet` | **Sheet** | **Fiche** | One-page summary to revise | Summarize branch (new API) |
| `from_class` | **From class** | **Depuis le cours** | Revision from your live session | `/challenge/from-session` |

**Primary CTA follows selection:**

| Selected | EN CTA | FR CTA |
|----------|--------|--------|
| Play | Start playing | Commencer à jouer |
| Scroll | Start scrolling | Commencer à défiler |
| Path | Start path | Commencer le parcours |
| Drill | Start drilling | Commencer à répéter |
| Sheet | Create sheet | Créer la fiche |
| From class | Play class challenge | Jouer le défi du cours |

Footer chat input (optional Phase A.2): **"Tell SkulMate more…"** / **"Dis-en plus à SkulMate…"**

---

## SkulMate sub-navigation (tab shell)

Five tabs inside the SkulMate tab — same **structure** as Gizmo, PrepSkul **labels**:

| Tab | EN | FR | Role |
|-----|----|----|------|
| Home | Home | Accueil | Create + continue |
| Progress | Progress | Progrès | Streak, XP, continue, weak topics |
| + | (FAB) | (FAB) | Same as home create |
| Library | Library | Bibliothèque | All games/packs (was “Decks”) |
| Profile | Profile | Profil | Character, stats, settings |

Do **not** rename main PrepSkul app tabs — only the SkulMate module shell.

---

## Curriculum & discovery language

We are **not** exam-prep only. Exams are a strong wedge, not the whole product.

| Concept | EN | FR | Notes |
|---------|----|----|-------|
| Exam-aligned tag | Exam track | Parcours examen | GCE / WAEC / BEPC when profile has board |
| General learning | Open revise | Révision libre | Notes, YouTube, curiosity |
| Subject pack | Subject pack | Pack matière | Replaces “public deck” / “100M flashcards” |
| Syllabus node | On syllabus | Au programme | Shown on generated content |
| Weak topic | Needs work | À retravailler | Maps reroute UI |
| Reroute | New route | Nouvel itinéraire | Google Maps metaphor |

**Seed curriculum (Phase B):** GCE AL Maths, Chemistry, Biology — first **exam tracks**, then expand to STEAM, BEPC, Probatoire, and general subjects.

---

## What we deliberately avoid copying

- “What shall we **study**?” → we say **revise**
- “Memorise” / “Deck” / “100 million flashcards”
- Purple axolotl / Gizmo brand
- Generic “Chat” as screen title → **SkulMate** or topic name (e.g. “Photosynthesis revision”)

---

## Implementation checklist

- [ ] `SkulMateHomeScreen` uses FR/EN from `LanguageNotifier`
- [ ] `SkulMateIntentSheet` uses mode IDs above (not Gizmo strings)
- [ ] Analytics events: `skulmate_mode_play`, `skulmate_mode_path`, etc.
- [ ] API `outputMode`: `play` | `scroll` | `path` | `drill` | `sheet` | `from_class`
