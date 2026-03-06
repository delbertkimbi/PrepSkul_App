# skulMate Strategy, Engagement & Character Specs

## 1. Streaks & Push Notifications — Current Status

### What Exists Today

| Feature | Status | Location |
|---------|--------|----------|
| **Per-game streak** (correct answers in a row) | ✅ In-game only | `flashcard_game_screen.dart` — resets on wrong answer |
| **Daily / long-term streak** | ✅ Implemented | `GameStatsService`, streak badge on library/upload, celebration on results |
| **Session reminders** (24h, 1h, 15min) | ✅ For tutoring sessions | `NotificationHelperService`, session flows |
| **skulMate study reminders** | ❌ Not implemented | No "come back to study" notifications |
| **Parent reminders** (e.g. "tell your kid to study") | ❌ Not implemented | No parent-specific skulMate nudges |
| **Challenge / social notifications** | ❌ Not implemented | No "your friend just played X" type messages |

### Duolingo-Style Engagement Gaps

1. **Adaptive reminders** — Notifications sent ~24h after last app visit, timing adapted to when the user tends to be free  
2. **Global study streaks** — Daily streak across the whole app, not just within a single game  
3. **Streak loss nudges** — Gentle "don’t lose your streak" reminders  
4. **Social notifications** — e.g. "Etonge just completed a Chemistry quiz — can you beat their score?"  
5. **Parent nudges** — e.g. "Mbiya hasn’t studied today — remind them to open skulMate" or "Upload notes for a quick revision game"

---

## 2. Conclusions & Plan

### Priority Stack (in order)

#### Tier 1 — Engagement (Duolingo-style)

1. **Daily study streaks**
   - Track last study date per user
   - Streak count, streak freeze option
   - UI: streak badge, celebration when maintaining/breaking records

2. **Smart push reminders**
   - 24h after last visit (or adapted to usage)
   - Student: "Ready to keep your streak? 🎮"
   - Parent: "Remind [child] to revise with skulMate today"
   - Optional: "Your 5-Minute Revision Challenge is ready" (from `POST_SESSION_FLOWS_AND_PROMPTS.md`)

3. **Social / challenge notifications**
   - When a friend completes a challenge: "Etonge just played Biology — try it"
   - When a challenge is shared with you

#### Tier 2 — Content & Learning

4. **STEAM focus**
   - Game prompts tied to subjects (Math, Science, etc.)
   - Exam tags: GCE O/L, A/L, FSLC
   - Avoid generic games; keep subject/field clarity

5. **Storytelling**
   - Narrative around characters (e.g. "Mbiya’s study journey")
   - Character-led quests / mini-stories
   - Progress arcs and small narrative beats

#### Tier 3 — Social & Depth

6. **Friend challenges**
   - Challenge friends to the same game
   - Leaderboards by subject or topic

7. **Adaptive review**
   - Spaced repetition for weak items
   - “Review weak topics” mode

---

## 3. Character Specifications for Image Generation

### Asset Paths (where to place files)

All character images go in:

```
prepskul_app/assets/characters/
```

### Exact filenames (required)

| Character | Filename | ID |
|-----------|----------|-----|
| Mbiya | `elementary_male.png` | `elementary_male` |
| Nchia | `elementary_female.png` | `elementary_female` |
| Etonge | `middle_male.png` | `middle_male` |
| Aseh | `middle_female.png` | `middle_female` |
| Achu | `high_male.png` | `high_male` |
| Nde | `high_female.png` | `high_female` |

### Brand Colors (from `app_theme.dart`)

- **Primary (deep blue):** `#1B2C4F`
- **Sky blue:** `#0EA5E9`
- **Soft yellow:** `#EAB308`
- **Accent green:** `#10B981`
- **Accent purple:** `#6366F1`

### Image Specs

- Format: PNG
- Size: 512×512px or larger (square)
- Background: Transparent recommended
- Style: Friendly, age-appropriate, consistent across all 6

---

## 4. Character Descriptions for Prompts

Use these when prompting an image model (e.g. DALL·E, Midjourney, or similar):

### Mbiya (Elementary Male, 5–10)

> Friendly Cameroonian boy, 5–10 years old, cartoon style, warm brown skin, short dark hair, bright curious eyes, soft smile. Casual school-ready clothes (light blue or white shirt). Transparent or simple background. Accents: deep blue (#1B2C4F), sky blue (#0EA5E9). Happy, eager to learn. No text. Square 512×512.

### Nchia (Elementary Female, 5–10)

> Friendly Cameroonian girl, 5–10 years old, cartoon style, warm brown skin, natural hair (twists or braids), cheerful expression. Casual school-ready clothes (light purple or cream top). Transparent or simple background. Accents: deep blue (#1B2C4F), soft yellow (#EAB308). Curious, ready to explore. No text. Square 512×512.

### Etonge (Middle School Male, 11–14)

> Confident Cameroonian teen boy, 11–14 years old, cartoon style, warm brown skin, neat short hair, determined look. Casual modern clothes (navy or deep blue shirt). Transparent or simple background. Accents: deep blue (#1B2C4F), sky blue (#0EA5E9). Motivated, ready for challenges. No text. Square 512×512.

### Aseh (Middle School Female, 11–14)

> Determined Cameroonian teen girl, 11–14 years old, cartoon style, warm brown skin, styled natural hair. Casual modern clothes (white or soft blue top). Transparent or simple background. Accents: deep blue (#1B2C4F), accent purple (#6366F1). Resilient, never-give-up energy. No text. Square 512×512.

### Achu (High School Male, 15–18)

> Focused Cameroonian young man, 15–18 years old, cartoon style, warm brown skin, short neat hair, composed expression. Smart-casual (collared shirt in deep blue or white). Transparent or simple background. Accents: deep blue (#1B2C4F), sky blue (#0EA5E9). Mature, preparing for success. No text. Square 512×512.

### Nde (High School Female, 15–18)

> Ambitious Cameroonian young woman, 15–18 years old, cartoon style, warm brown skin, natural or styled hair. Smart-casual (blouse or blazer in deep blue or cream). Transparent or simple background. Accents: deep blue (#1B2C4F), accent purple (#6366F1). Confident, reaching for excellence. No text. Square 512×512.

---

## 5. Style Guidance for Image Generation

**Recommended styles:**

- Flat or semi-flat cartoon
- Clean lines, minimal noise
- Duolingo-inspired mascot feel (approachable, simple shapes)
- Consistent lighting and color palette across all 6 characters

**Avoid:**

- Photo-realistic
- Busy backgrounds
- Text or labels in the image
- Harsh shadows or aggressive gradients

**Optional keywords to add to prompts:**

- `soft lighting`
- `rounded shapes`
- `educational app mascot`
- `Cameroonian, African`

---

## 6. After You Generate & Upload

1. Save each file with the exact filename (e.g. `elementary_male.png`).
2. Place them in `prepskul_app/assets/characters/`.
3. Add the folder to `pubspec.yaml` under `assets`:

```yaml
flutter:
  assets:
    - assets/characters/
```

4. Run the app; the character selection screen and game screens will load the new images automatically via `assetPath` in the model.
