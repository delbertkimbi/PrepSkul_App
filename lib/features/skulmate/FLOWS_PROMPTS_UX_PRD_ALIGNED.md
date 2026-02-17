# Post-Session Flows, Prompts, UI/UX – PRD-Aligned

Clear distinction between trial and normal (recurring) sessions, with structured prompts, UI/UX, and implementation tied to the emotions and behaviors in the skulMate AI PRD.

---

## 1. Flow Distinction

| Session Type | What Happens After | Primary Goal |
|--------------|--------------------|--------------|
| **Trial** | Feedback immediately (or soon) | Conversion: Will learner continue? Experience? Match with tutor? |
| **Normal (recurring)** | skulMate challenge → Feedback (after session, 24h reminder) | Retention: Reinforce learning, then capture experience |

**Rule:** skulMate challenges are for **normal sessions only**, not trials.

---

## 2. Trial Flow – Feedback (Conversion-Focused)

### Trigger
- Trial session ends → notification: "Your trial session has been completed. How did it go?"
- Feedback reminder (24h) if not submitted

### Emotional Goal
- **Trust:** Learner feels heard; PrepSkul is helping them find the right tutor
- **Closure:** Clear end to trial; next step is either convert or improve match
- **Low friction:** Short, focused form; no cognitive overload

### Prompts (Labels / Copy)

**Screen title**
- "How was your trial?"
- Subtitle: "Your feedback helps us match you with the right tutor."

**Step 1 – Core (required)**
1. **Rating (1–5 stars):** "How was your trial session?"
2. **Would you continue lessons with this tutor?** [Yes / No / Not sure]
3. **What did you like most?** (optional, single line or short text)
4. **Anything we could improve?** (optional, single line or short text)

**Step 2 – Optional (learner/parent)**
- **What did you learn?** (optional)
- **How confident do you feel about the topic?** [1–5]

**Step 3 – Optional (parent)**
- **How did your child respond to the session?** [Engaged / Neutral / Disengaged]
- **Would you book regular sessions with this tutor?** [Yes / No / Not sure]

**Completion copy**
- "Thanks! We’ll use this to improve your experience."
- If `wouldContinueLessons == Yes`: "Ready to book? See your tutor’s availability."
- If `No` or `Not sure`: "We’ll help you find a better match. Check out other tutors."

### UI/UX Principles (PRD)
- **Low friction:** 3–5 taps to complete; optional steps collapsible
- **Immediate feedback:** Success message + clear next action
- **Visible progress:** Step indicator (e.g. 1 of 3)
- **No endless scroll:** Fixed steps, clear endpoint

---

## 3. Normal Session Flow – skulMate + Feedback

### Order of Events
1. Session ends → VA generates summary (when transcription completes)
2. **skulMate challenge** (normal sessions only): "Your 5-Minute Revision Challenge is Ready"
3. **Feedback** (after session or on 24h reminder): experience, tutor quality, learning objectives

### skulMate Challenge (Normal Sessions Only)

**Trigger**
- `individual_sessions.session_summary` exists AND session is **recurring** (not trial)
- Notification: "Your 5-Minute Revision Challenge is Ready"

**Emotional arc (PRD 13.3)**

| Phase | Feeling | Implementation |
|-------|---------|----------------|
| **Start** | Light, approachable | One tap to start; "5 questions, ~3 min"; welcoming copy |
| **Middle** | Increasing challenge | Difficulty ramp; optional timer; focus intensifies |
| **Peak** | Final tension spike | "Boss" question; bonus XP; mild cognitive stress |
| **End** | Achievement + closure | XP gain; level/streak update; clear completion; no infinite feed |

**Emotions from PRD**

| PRD emotion | Implementation |
|-------------|----------------|
| **Speed** | <200ms feedback; confetti; sound; haptic |
| **Novelty** | Mix MCQ + flashcards; surprise "boss" question |
| **Low friction** | One tap to start; no setup |
| **Achievement** | XP (+10 per correct, +50 completion); visible level |
| **Progression** | Unlock tiers by mastery |
| **Tension** | Timed rounds; "boss" question |
| **Identity** | "Algebra Level 3", "Chemistry Apprentice" |
| **Comeback loop** | Retry = "Improve your score"; failure as progress opportunity |

**Prompts (AI – structure + questions)**

1. **Structure transcript/summary into learning object**
   - Input: `session_summary` + aggregated transcript
   - Output: `{ topic, subtopics, key_points, definitions, examples, formulas }`

2. **Generate questions**
   - Input: Structured learning object
   - Output: 5–8 question objects: `{ type: mcq|flashcard, question, options, correct_answer, explanation, difficulty }`
   - Last question = "boss" (harder, bonus XP)

**UI copy**
- Entry: "Start your 5-Minute Revision Challenge"
- Per question: immediate feedback; "+10 XP" on correct
- Completion: "Challenge complete!" + total XP + level/streak
- Retry: "Try again to improve your score"

### Normal Session Feedback (After skulMate or 24h)

**Trigger**
- Session completed; feedback reminder (24h) or user opens "My Sessions"

**Focus**
- Experience in session
- Tutor quality
- Learning objectives met
- Optional: what went well, what could improve

**Prompts (labels)**
- "How was your session?" (1–5 stars)
- "Did you achieve your learning goals?" [Yes / Partly / No]
- "Would you recommend this tutor?" [Yes / No]
- "What went well?" (optional)
- "What could improve?" (optional)

---

## 4. Prompts Reference (AI + UI)

### Trial feedback (conversion)
- Notification: "Your trial session has been completed. How did it go? Leave feedback to help us match you with the right tutor."
- Screen: "How was your trial?"
- CTA: "Submit feedback"
- Success: "Thanks! We’ll use this to improve your experience."

### Normal – skulMate
- Notification: "Your 5-Minute Revision Challenge is Ready"
- Entry: "Start your 5-Minute Revision Challenge"
- Per answer: "+10 XP" (correct), "+50 XP" (completion)
- Completion: "Challenge complete! You earned X XP."

### Normal – feedback
- Notification: "How was your session? Leave feedback when you’re ready."
- Screen: "Session Feedback"
- Focus: experience, tutor quality, learning objectives

---

## 5. Implementation Checklist

### Backend
- [x] skulMate challenge: gate by session type (recurring only; exclude trial)
- [x] VA: ensure `session_summary` written for both trial and normal
- [x] Notification logic: trial → feedback; normal → skulMate, then feedback

### App (Flutter)
- [x] `SessionFeedbackFlowScreen`: branch by trial vs normal (different steps/labels)
- [x] skulMate entry: show "Start Challenge" only for normal sessions with `session_summary`
- [x] Feedback flow: trial = conversion prompts; normal = experience prompts

### Prompts
- [x] Trial feedback: "Would you continue?", "What did you like?", conversion CTAs
- [x] Normal feedback: "How was your session?", "Learning goals met?", "Recommend tutor?"
- [x] skulMate: structure + question generation prompts (per PRD schema)

### Emotional design (PRD)
- [x] skulMate: confetti, <200ms feedback, XP pop-up, boss question, completion celebration
- [x] Feedback: low friction, clear steps, no endless scroll
- [x] Notifications: conversion-focused for trial; challenge + feedback for normal
- [x] Retry: "Try again to improve your score" on results screen

---

## 6. PRD Emotional Design Summary (Refresh)

**From short-form media:** Speed, novelty, low friction. NOT: endless feed, distraction, passive loops.

**From gaming:** Achievement, progression, tension, identity, comeback loop.

**Emotional arc:** Start (light) → Middle (challenge) → Peak (boss) → End (achievement + closure).

**Safety:** Daily caps, no punishment for streaks, no aggressive loss messaging, no manipulative countdowns. Goal: motivation, not addiction.
