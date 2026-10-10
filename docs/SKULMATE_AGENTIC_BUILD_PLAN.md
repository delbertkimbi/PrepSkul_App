# SkulMate agentic learning plan

## Product loop

`ask → understand context → explain → practise → check → remember → recommend next step`

Mate should help a learner make progress before it suggests a tutor. A tutor handoff is a supported next step, not the default answer.

## Context contract

Every Mate request should carry a small, explicit context object:

- learner language, country, education system, class, and subjects
- current goal and preferred pace
- recent weak topics and recent practice attempts
- active lesson, deck, or tutor session
- voice and accessibility preferences

The existing `LearnerContextService` and `LearnerIntelligenceService` are the first implementation. New fields must be optional so older profiles continue to work.

## Agent tools

Expose validated server tools rather than asking the model to infer database operations:

1. `searchCurriculum` — retrieve curriculum-grounded material.
2. `getLearningMemory` — retrieve recent explanations, attempts, and misconceptions.
3. `createPractice` — generate a small exercise at the learner's level.
4. `checkPractice` — explain the result and record a learning signal.
5. `saveLearningSignal` — store mastery, confusion, or preference changes.
6. `recommendNextStep` — return one useful action for the home screen.
7. `findTutor` — match a tutor only when the learner asks or needs human help.

## Retrieval architecture

Start with Supabase Postgres + `pgvector`. Embed curriculum nodes, PrepSkul lessons, practice items, tutor resources, and approved session summaries. Every vector row needs metadata for country, system, level, subject, language, and content type so retrieval is filtered before ranking.

## Model routing

Keep OpenRouter behind the server. Route by task:

- fast model: short explanations and classification
- reasoning model: difficult multi-step tutoring
- vision model: handwritten work and diagrams
- speech model: Mate voice

Never expose the OpenRouter key in Flutter or browser code. Add usage limits, request logging, caching, and a device-voice fallback before enabling remote voice broadly.

## Fine-tuning rule

Do not fine-tune yet. First collect consented, evaluated examples and measure explanation quality, misconception detection, language fit, latency, and cost. Fine-tune only after prompts, retrieval, and tools are stable and a repeated behaviour cannot be solved reliably another way.

## Delivery order

1. Normalize the context contract across app and web.
2. Add learning-event and practice-attempt writes.
3. Add curriculum retrieval with pgvector.
4. Move Mate generation to structured tool calls.
5. Add next-step recommendations and tutor handoff.
6. Add offline packs, caching, and sync conflict handling.
7. Build evaluation sets before model or fine-tune changes.
