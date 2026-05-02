# 🎮 SkulMate Feature - Complete Explanation

## What is SkulMate?

**SkulMate** is an AI-powered educational game generation feature that:
- Converts study materials (PDFs, images, text) into interactive games
- Creates 4 types of games: Quiz, Flashcards, Matching, Fill-in-the-Blank
- Helps students learn through gamification (like Duolingo)
- Features Cameroonian characters for motivation

---

## How SkulMate Works

### 1. **Upload Content**
- Students/parents upload:
  - PDF documents (notes, textbooks)
  - Images (photos of notes, whiteboards)
  - Text (paste study material)

### 2. **AI Game Generation**
- Content is sent to Next.js API (`/api/skulmate/generate`)
- API uses OpenRouter AI to:
  - Extract key concepts from content
  - Generate questions and answers
  - Create game items based on game type
  - Determine difficulty level

### 3. **Game Types**
- **Quiz**: Multiple choice questions
- **Flashcards**: Question/answer pairs
- **Matching**: Match terms with definitions
- **Fill-in-the-Blank**: Complete sentences

### 4. **Play & Learn**
- Students play games
- Track scores and progress
- Character provides motivation
- Results saved for review

### 5. **Game Library**
- View all generated games
- Replay games
- Track performance over time

---

## Why It's Currently Disabled

### Current Status: `enableSkulMate = false`

**Location:** `lib/core/config/app_config.dart` (line 54)

```dart
static const bool enableSkulMate = false; // ← Disabled until RLS issues are resolved
```

### The "RLS Issues" Explained

**RLS = Row Level Security** (Supabase database security)

The issue is NOT actually with RLS policies - they're correctly configured! The real issues are:

#### 1. **Migration Not Applied** ⚠️
- Migration `030_skulmate_games.sql` needs to be run in Supabase
- This creates the database tables:
  - `skulmate_games` (game metadata)
  - `skulmate_game_data` (game content)
  - `skulmate_game_sessions` (play history)

#### 2. **Feature Flag Disabled** ⚠️
- The code has `enableSkulMate = false`
- Even if migrations are run, the feature won't work until this is `true`

#### 3. **API Dependency** ⚠️
- Requires Next.js API to be deployed at `https://www.prepskul.com/api`
- Requires OpenRouter API key configured
- API uses service role key (bypasses RLS) - so RLS isn't the issue!

---

## What Needs to Be Done to Enable SkulMate

### Step 1: Run Database Migrations

Go to **Supabase Dashboard → SQL Editor** and run:

1. **Migration 030**: `030_skulmate_games.sql`
   - Creates game tables
   - Sets up RLS policies
   - Creates indexes

2. **Migration 032**: `032_add_skulmate_character.sql`
   - Adds character selection to profiles

### Step 2: Enable Feature Flag

**File:** `lib/core/config/app_config.dart`

```dart
// Change this:
static const bool enableSkulMate = false;

// To this:
static const bool enableSkulMate = true;
```

### Step 3: Verify API Setup

**Check:**
- ✅ Next.js API deployed at `https://www.prepskul.com/api`
- ✅ OpenRouter API key set in Vercel environment variables
- ✅ API endpoint `/api/skulmate/generate` is accessible

### Step 4: Test

1. Upload a PDF/image/text
2. Generate a game
3. Play the game
4. Check game library

---

## Current Architecture

### Flutter App (Client)
```
User uploads file
    ↓
SkulMateService.generateGame()
    ↓
HTTP POST to Next.js API
    ↓
API processes & saves to Supabase
    ↓
Returns game data
    ↓
Flutter displays game
```

### Next.js API (Server)
```
Receives file/content
    ↓
Extracts text (PDF/image processing)
    ↓
Calls OpenRouter AI
    ↓
Generates game content
    ↓
Saves to Supabase (using service role - bypasses RLS)
    ↓
Returns game to Flutter
```

### Supabase Database
```
Tables:
- skulmate_games (metadata)
- skulmate_game_data (content)
- skulmate_game_sessions (history)

RLS Policies:
- Users can only see their own games
- API uses service role (bypasses RLS)
```

---

## Why It Was Disabled

The comment says "RLS issues" but actually:

1. **Migrations weren't run** - Tables don't exist yet
2. **Feature flag was set to false** - Safety measure
3. **API might not have been ready** - OpenRouter key needed

**The RLS policies are actually correct!** The API uses service role key to bypass RLS when saving games, which is the right approach.

---

## How to Enable It Now

### Quick Enable (If Migrations Are Run)

1. **Enable feature flag:**
   ```dart
   // In app_config.dart
   static const bool enableSkulMate = true;
   ```

2. **Verify migrations are applied:**
   - Check Supabase → Table Editor
   - Look for `skulmate_games`, `skulmate_game_data`, `skulmate_game_sessions`

3. **Test:**
   - Navigate to SkulMate upload screen
   - Upload a test file
   - Generate a game

### If Migrations Aren't Run

1. **Run migrations first:**
   - Copy `030_skulmate_games.sql` to Supabase SQL Editor
   - Run it
   - Copy `032_add_skulmate_character.sql` to Supabase SQL Editor
   - Run it

2. **Then enable feature flag**

---

## Features That Work (Code Complete)

✅ **Game Generation**
- PDF/image/text upload
- AI-powered content extraction
- 4 game types
- Difficulty levels

✅ **Game Play**
- All game types functional
- Score tracking
- Time tracking
- Results screen

✅ **Character System**
- 6 Cameroonian characters
- Age-appropriate selection
- Motivational phrases
- Cross-device sync

✅ **Game Library**
- View all games
- Game history
- Performance tracking
- Favorites

---

## Optional Enhancements (Not Required)

- Character images (games work without)
- Sound effects (games work without)
- Advanced animations

---

## Summary

**SkulMate is fully coded and ready**, but disabled because:
1. Feature flag is `false` (safety measure)
2. Migrations may not be applied (need to check)
3. API needs to be verified (should be working)

**To enable:**
1. Run migrations (if not done)
2. Set `enableSkulMate = true`
3. Test the flow

**The "RLS issues" mentioned are likely outdated** - the API uses service role key which bypasses RLS, and the RLS policies are correctly configured for client-side access.

---

**Want me to enable it now?** I can:
1. Check if migrations are needed
2. Enable the feature flag
3. Test the flow
