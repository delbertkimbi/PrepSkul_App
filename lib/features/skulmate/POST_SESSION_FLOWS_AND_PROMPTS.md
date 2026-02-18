# Post-Session Flows, Prompts, and PRD-Aligned Design

Clear separation of trial vs normal session flows, structured prompts, and emotional design from the skulMate PRD.

---

## 1. Flow Clarification

### Trial Session (Post-Session)

| When | What | Purpose |
|------|------|---------|
| Immediately after trial ends | Completion notification + "Trial completed" | Acknowledge session end |
| ~24 hours later | **Feedback reminder** | Conversion-focused feedback |
| No skulMate challenge | — | Trial is a tryout; challenge comes after commitment |

**Focus:** Conversion. Feedback asks: Will the learner/parent love continuing with this tutor? Session experience? Fit?

### Normal (Recurring) Session (Post-Session)

| When | What | Purpose |
|------|------|---------|
| Immediately after session ends | Completion + "Session Summary Ready" | Acknowledge end, prepare for revision |
| When summary ready | **skulMate challenge** notification: "Your 5-Minute Revision Challenge is Ready" | Revision reinforcement |
| ~24 hours later | **Feedback reminder** | Session experience, tutor fit, what to improve |

**Focus:** Revision (challenge) + retention feedback.

---

## 2. Trial Feedback – Conversion-Focused Prompts

### Goal
Learn whether learner/parent will continue with this tutor. Capture experience, fit, and conversion signals.

### Structured Prompts (UI Copy + Questions)

**Screen title:** "How Was Your Trial?"

**Step 1 – Rating (required)**
- **Prompt:** "Overall, how was your trial session with [Tutor Name]?"
- **Options:** 1–5 stars
- **Conversion signal:** High rating correlates with conversion

**Step 2 – Experience (required for trial)**
- **Q1:** "Would you love to continue learning with this tutor?"
  - Options: Yes, definitely / Maybe / No
- **Q2:** "What stood out most about the session?"
  - Short text or preset: Teaching style / Pace / Explanations / Engagement / Other
- **Q3 (learner):** "Did you feel comfortable and engaged?"
  - 1–5 scale
- **Q3 (parent):** "How did your child respond to the tutor?"
  - 1–5 scale

**Step 3 – Optional Details**
- **Q4:** "Anything else we should know?" (optional text)
- **Q5:** "What could make the next session even better?" (optional)

### Emotional Design (Trial Feedback)

- **Low friction:** 3 steps max, minimal required fields
- **Warm tone:** "We’d love to hear" / "Your feedback helps us match you better"
- **Conversion framing:** Questions framed around fit and continuation
- **No pressure:** Optional fields clearly marked

---

## 3. Normal Session Feedback – Retention-Focused Prompts

### Goal
Session experience, tutor effectiveness, what to improve. Supports retention and tutor improvement.

### Structured Prompts

**Screen title:** "Session Feedback"

**Step 1 – Rating (required)**
- **Prompt:** "How was today’s session?"
- **Options:** 1–5 stars

**Step 2 – Experience**
- **Q1:** "What went well?"
- **Q2:** "What could improve?"
- **Q3:** "Would you recommend this tutor?" (Yes/No)
- **Q4 (learner):** "Did you achieve what you hoped?" (Yes/Maybe/No)

**Step 3 – Optional**
- **Q5:** "Anything else?" (optional text)

---

## 4. skulMate Challenge – AI Prompts (Normal Sessions Only)

### 4.1 Structure Content Prompt

**Input:** Session summary (prose) + aggregated transcript

**System prompt:**
```
You are PrepSkul's content structuring assistant. Convert session content into a structured learning object for revision.

Output valid JSON only:
{
  "topic": "string",
  "subtopics": ["string"],
  "key_points": ["string"],
  "definitions": [{"term": "string", "definition": "string"}],
  "examples": ["string"],
  "formulas": ["string"]
}

Rules:
- Extract only what was explicitly covered in the session
- Keep key_points concise (1 sentence each)
- definitions: formal definitions of terms taught
- examples: concrete examples from the session
- If a section has no content, use empty array []
- Be accurate; do not invent content
```

### 4.2 Question Generation Prompt

**Input:** Structured learning object (JSON)

**System prompt:**
```
You are PrepSkul's question generator. Create 5–8 mastery-driven micro-questions from the structured learning object.

Output valid JSON array:
[
  {
    "type": "mcq",
    "question": "string",
    "options": ["string"],
    "correct_answer": "string",
    "explanation": "string",
    "difficulty": 1
  },
  {
    "type": "flashcard",
    "term": "string",
    "definition": "string",
    "difficulty": 1
  }
]

Rules:
- Mix MCQ (3–5) and flashcards (2–3)
- difficulty: 1=easy, 2=medium, 3=hard
- Questions must be answerable only from the learning object
- No trick questions; focus on reinforcement
- Explanation must teach, not just state the answer
- options: exactly 4 for MCQ, correct_answer must be one of them
```

---

## 5. PRD Emotions & Behaviors (Refreshed)

### From Short-Form Media (Borrow)

| Emotion | Design Principle | UI/UX Implementation |
|---------|------------------|------------------------|
| **Speed** | Sub-200ms feedback | Instant correct/incorrect, sound, haptic |
| **Novelty** | Vary format, surprise | MCQ + flashcard mix, occasional "boss" question |
| **Low Friction** | One tap to start | Single "Start Challenge" button, no setup |

### From Gaming (Borrow)

| Emotion | Design Principle | UI/UX Implementation |
|---------|------------------|------------------------|
| **Achievement** | XP, level, mastery | +10 XP per correct, +50 completion, level label |
| **Progression** | Unlock tiers | Show "Algebra Level 2" style identity |
| **Tension** | Mild cognitive stress | Timed rounds, final "boss" question |
| **Identity** | Subject-level rank | "Chemistry Apprentice" / "Algebra Level 3" |
| **Comeback** | Retry = progress | "Try again to beat your score" framing |

### What We Do NOT Borrow

- Infinite feed
- Algorithmic distraction
- Passive consumption
- Aggressive loss messaging
- Punishment for missing streaks

### Emotional Arc of a skulMate Session

| Phase | Feeling | Implementation |
|-------|---------|----------------|
| **Start** | Light, approachable | Welcome copy, "5 min" promise, one tap |
| **Middle** | Increasing challenge | Difficulty ramp, optional timer |
| **Peak** | Final tension spike | Last question = "boss" (bonus XP) |
| **End** | Achievement + closure | Confetti, XP total, level up, clear "Done" |

### Emotional Safety

- Daily challenge caps
- No punishment for missed streaks
- No aggressive loss messaging
- No manipulative countdown loops

---

## 6. UI/UX Implementation Checklist

### Trial Feedback Screen

- [ ] Detect trial vs normal; show trial-specific copy and questions
- [ ] Conversion-focused prompts (would love to continue? child response?)
- [ ] 3 steps max, minimal required fields
- [ ] Warm, non-pressuring tone

### Normal Feedback Screen

- [ ] Same flow as today, retention-focused
- [ ] Optional integration with skulMate completion (e.g. "You completed your challenge! Now tell us about the session.")

### skulMate Challenge (Normal Sessions Only)

- [ ] Entry only for sessions with `session_summary` and `recurring_session_id` (not trial)
- [ ] Notification: "Your 5-Minute Revision Challenge is Ready"
- [ ] One-tap start, no setup
- [ ] Emotional arc: Start light → Middle ramp → Peak boss → End celebration
- [ ] Immediate feedback: confetti, sound, haptic, +10 XP pop
- [ ] Celebration screen: XP, level, streak, clear completion

### Shared UX

- [ ] Sub-200ms feedback on interactions
- [ ] Progress bar / step indicator
- [ ] Clear completion state (no endless scroll)

---

## 7. Implementation Notes

### Session Type Detection

- **Trial:** `trial_sessions.id` or `individual_sessions` with no `recurring_session_id` and linked to trial
- **Normal:** `individual_sessions` with `recurring_session_id` not null

### skulMate Trigger

- Only for **normal** sessions
- Require `session_summary` or sufficient transcript
- Lazy generation on first "Start Challenge" (or proactive when summary ready)

### Feedback Routing

- Trial: conversion-focused prompts, no challenge
- Normal: retention-focused prompts; challenge available before or alongside feedback
