# Gizmo reference screen catalog

Captured June 2026 (28 screenshots). Assets live in [`screenshots/`](./screenshots/). Use with [GIZMO_HOME_STUDY.md](./GIZMO_HOME_STUDY.md) and [GIZMO_TO_SKULMATE_MAPPING.md](./GIZMO_TO_SKULMATE_MAPPING.md).

## Phase A — Home & intake (build first)

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `01-home-hero-mascot-input.png` | Home | Mascot + **"What shall we study?"** + chat input + 6 action chips + Jump back in | `SkulMateHomeScreen` |
| `02-home-more-menu-expanded.png` | More ▾ menu | Record lecture, Quizlet | `SkulMateImportActionGrid` |
| `03-home-plus-dropdown-sources.png` | + dropdown | PDF, PPT, YouTube, Notes, Photo, Record, Quizlet, Deck | Same grid + **From session** |
| `04-home-alternate-grid-layout.png` | Alt home layout | Large source tiles + "Search 100M flashcards" | Optional second layout |
| `05-home-alternate-see-more-options.png` | Alt home (4 tiles) | Upload / Paste / YouTube / Photo + "See more options" | Collapsed chip row variant |

## Post-upload & modes

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `06-chat-mode-cards-lesson-selected.png` | Resume Analysis chat | Memorise / Note / **Step-by-step lesson** cards + dynamic CTA + "I want to learn…" | `SkulMateIntentSheet` |
| `07-lesson-step-list.png` | Lesson overview | Step 1…N, "4 more", Regenerate, **Start lesson (8 steps)** | `SkulMateLessonOverviewScreen` |

## Import modals

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `08-import-notes-modal.png` | Paste notes sheet | Magic wand, textarea, Continue | Reuse `skulmate_upload_screen` as sheet |
| `09-import-quizlet-modal.png` | Quizlet URL | URL field + Continue | Phase B import |
| `10-import-photos-empty.png` | Photo import (empty) | + tile grid + Continue | Image picker flow |
| `11-import-photos-with-thumbnail.png` | Photo import (selected) | Thumbnail + add more + Continue | Multi-image OCR path |

## Progress tab

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `12-progress-streak-calendar.png` | Progress (streak hero) | 1-day streak, calendar, "10 questions to get Gold" | Extend streak UI + daily challenge |
| `13-progress-jump-back-in-leaderboard.png` | Progress (full) | XP bar, Jump back in, Deck progress, Friends leaderboard | Progress sub-nav tab |

## Deck detail & study

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `14-deck-web-design-cards.png` | Deck · Cards tab | Q/A cards, Challenge a friend, **Study deck** CTA | Game library card view |
| `15-deck-mbb-consulting-cards.png` | Deck · Cards (alt) | Fill-blank, T/F, ordering cards | Rich card types from generate API |
| `16-deck-study-mode-picker.png` | Study mode sheet | Memorise / AI Tutor / **Gizmo Live** → Start learning | Intent sheet + **Play game** for SkulMate |

## Discovery & social (Phase B+)

| File | Screen | Key UX takeaway | SkulMate target |
|------|--------|-----------------|-----------------|
| `17-decks-public-discovery.png` | Public decks | Level · Subject · School filters, "Popular at [school]" | **Exam packs** (GCE/WAEC) not 100M flashcards |
| `18-gizmo-live-lobby.png` | Gizmo Live | Game code + QR + invite | Map to friend challenges / live quiz |
| `19-profile-feed-social.png` | Profile · Feed | School context, People you may know, Decks in school | Parent/social layer later |
| `20-profile-study-groups-live-modal.png` | Live menu | Study groups + Gizmo Live | Group classes + challenges |
| `21-invite-friends.png` | Invite friends | WhatsApp, TikTok, contacts, Super Hearts reward | Viral loop (optional) |
| `22-profile-leaderboards-friend-streaks.png` | Profile · Feed | School + friends leaderboard, friend streaks | Existing leaderboard screens |
| `23-profile-feed-alt-user.png` | Profile · Feed (alt) | Super Hearts referral banner | Engagement monetization ref |

## Bottom navigation (all home/progress shots)

**Home · Progress (🔥) · Green + · Decks · Profile** — library is one tab away, not the landing experience.

## SkulMate equivalents (current code)

| Gizmo pattern | PrepSkul today | Target widget / screen |
|---------------|----------------|------------------------|
| Home hero input | `SkulMateUploadScreen` (separate tab) | `SkulMateHomeScreen` |
| Jump back in | Partial: `DailyChallengeCard`, game list | `SkulMateJumpBackInRow` |
| My decks | `GameLibraryScreen` My Games tab | `SkulMateDeckListSection` |
| Post-upload modes | Auto game type in `game_generation_screen.dart` | `SkulMateIntentSheet` |
| Lesson steps | Not built | `SkulMateLessonOverviewScreen` |
| Progress tab | XP/streak scattered | SkulMate sub-nav Progress tab |
| Public decks | Not built | Exam pack library (Phase B) |
| Gizmo Live | Partial: `ChallengesScreen` | Live quiz Phase B |

## Originals

Raw UUID filenames preserved in [`screenshots/_originals/`](./screenshots/_originals/) (28 files). Five near-duplicates kept in originals only (alternate home grid, duplicate progress/public decks).
