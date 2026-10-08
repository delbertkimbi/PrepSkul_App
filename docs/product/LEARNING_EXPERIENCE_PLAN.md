# PrepSkul: a personal learning journey

Planning draft · 8 October 2026 · Product owner review required before implementation

## 1. The promise

**Bring what you want to understand. Find your next step. Get the right help. See what you can do independently.**

PrepSkul should maintain a useful understanding of the learner across homework, self-study, tutor sessions, school lessons, examination preparation and personal projects. Mate helps carry that context forward. The learner chooses the destination and can change direction.

The map makes relationships visible: where the learner has evidence of understanding, what remains uncertain, what supports their goal, and which people or resources can help. The learning workspace makes the next action easy. Both use the same underlying learning record.

This is a proposed direction, not a description of features already delivered. The research is desk research, not an exhaustive market study or proof of efficacy. See [research and sources](RESEARCH.md) and [engineering plan](ENGINEERING_AND_DELIVERY.md).

### Working interpretation of Muse and dots

Pending confirmation of the intended products, this plan uses Meta Muse and OpenAI dots as references for persistent goals, context across sessions, proactive preparation and visible user controls. Their official descriptions support those interaction patterns, not educational effectiveness. [Muse](https://about.fb.com/news/2026/09/introducing-muse-personal-ai-agent/), [dots](https://openai.com/index/introducing-dots/).

The educational adaptation: Mate can prepare materials and suggest routes while the learner is away. The learner still performs the thinking, practice and independent demonstrations needed to learn. A finished worksheet produced by an agent is not evidence that the learner understands it.

## 2. Who we serve first

Long-term relevance should include school learners, university students, vocational learners and adults changing careers. Start with a small, teachable domain and a clearly defined cohort.

**Recommended initial pilot:** secondary learners working on foundational mathematics, through a small network of participating tutors in Cameroon. Choose the exact grade and curriculum with those tutors. Use one coherent concept sequence, such as fractions → ratios → introductory algebra. Do not assume that a topic has the same placement or examination requirements in both educational subsystems.

Cameroon's official MINESEC catalogue separates anglophone and francophone syllabuses. This makes curriculum identity a product requirement, not a translation setting. [MINESEC](https://www.minesec.gov.cm/web/index.php/en/systeme-educatif-en/progammes-d-etudes-en).

### Jobs the app must handle

| Situation | Learner need | Successful outcome |
|---|---|---|
| Stuck on tonight's homework | Understand the obstruction quickly | Explain the method and solve a different example |
| Examination approaching | Prioritise within limited time | A realistic route with explicit coverage and gaps |
| Returning after a break | Restart without shame | A short refresher and achievable next step |
| After a tutor session | Retain and apply what was taught | Review linked to the session, followed by independent practice |
| Learning in another language | Understand meaning and terminology | Clear explanation plus the terms needed in class/exams |
| Intermittent internet/shared phone | Continue reliably | Downloaded activity, saved work, clear sync state |
| Advanced in one area, struggling elsewhere | Avoid a single reductive level | Different evidence and routes for different concepts |
| Curious about a project | Connect school concepts to an objective | A route connecting skills to a tangible project |

## 3. One coherent product with three views

### Today: the practical starting point

The default home answers: **What do I want to work on now?**

1. A compact goal line: “Preparing for your algebra assessment.” Edit or switch it.
2. One main action: continue a specific activity, start a due review, or bring a question.
3. “Bring a question” accepts text, voice, a photo or a document. Permission is requested at use.
4. A short route preview: current step, next step, destination.
5. Human help and saved materials are available without scrolling through a feed.
6. An optional “Prepared for you” card explains what Mate prepared and why. It never claims unseen work is completed learning.

For a new learner, do not invent progress. Offer a small example, a question, or an optional starting-point check. Ask only the context needed for the next useful action; collect more context progressively.

### Journey: the map

A persistent map gives orientation and exploration. Start with a legible 2D/2.5D clay-inspired map; assess a full 3D world later using measured usability and device performance.

- **Wide view:** goals and subject areas. Only show areas relevant to selected curricula and interests.
- **Topic view:** concept clusters and their relationships.
- **Route view:** current concept, supporting prerequisites, alternative routes and checkpoints.
- **Activity view:** opens the learning workspace; the map stops animating in the background.

Coordinates represent educational relationships, not geographic proximity. “Nearby help” means help relevant to the current concept. Never imply that a child is physically near another user.

### Learn: the focused workspace

A session has a durable identity and survives navigation, interruption and reconnects.

- Task or question stays visible.
- Whiteboard/work area supports worked steps, diagrams and annotations.
- Mate offers a hint, explanation, example or diagnostic question as appropriate.
- Voice controls and transcript stay consistent across task types.
- A visible “Try it yourself” phase distinguishes supported work from an independent check.
- A clear exit saves progress and explains the next step.

Suggested top-level navigation: **Today · Journey · Library · Help**, with profile/settings outside the main four. “Learn” is entered from any relevant place; it is not another disconnected home. Prototype the labels with learners before fixing them.

## 4. The map's visual and interaction contract

### Give every object meaning

| Map element | Meaning | Tap/action |
|---|---|---|
| You are here | Current learning focus | Return to active task |
| Destination | Chosen goal with scope/deadline | Edit the goal or inspect coverage |
| Concept landmark | A specific teachable capability | See evidence, examples and next activities |
| Solid route | Recommended sequence | See why it was suggested |
| Alternative branch | Another suitable approach | Compare time, format and help options |
| Checkpoint | Independent demonstration | Start a short assessment |
| Review marker | Knowledge due for retrieval | Start review; postpone without penalty |
| Tutor marker | Relevant available/bookable help | See actual availability, price and scope |
| Study circle | Moderated learning room | Preview topic, rules and membership |
| Saved resource | Material linked to the concept | Open/download with source information |

Use status text and icons as well as colour. Suggested learning statuses: **Not checked · Exploring · Practising · Demonstrated · Review due**. “Demonstrated” shows when and how; it is not permanent certainty. Separate task completion from knowledge evidence.

Keep node positions stable when evidence changes. Update the route overlay, not the whole world layout. Provide search, zoom buttons, recenter and a **List view** with the same destinations/actions. Preserve view position when returning from a session. A map must work without pinch, drag, colour recognition, sound or animation. W3C requires alternatives for dragging interactions; the design target is comfortable 48dp controls, beyond the web minimum. [W3C](https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/).

### Keep the beauty useful

Retain PrepSkul blue, navy, warm paper and restrained yellow accents. Use soft clay landmarks and Mate around a crisp, readable interface. Flat reading surfaces, clear mathematical notation, generous gutters and consistent control shapes take precedence over decorative texture.

Use a calmer density and less decoration for older learners without changing core navigation. Full keyboard access, large text, reduced motion and an equivalent list route are first-release requirements. Do not build an explorable city before proving that learners can find their next useful action.

### Changes to earlier map proposals

Keep: semantic districts, visible routes, contextual human help, a personal home and a living companion.

Revise: “fog of knowledge” becomes honest “not yet checked” status; unknown knowledge is not failure. Avoid compulsory locked islands, exact mastery percentages unsupported by evidence, public weakness markers and fabricated presence counts. World growth can celebrate completed goals without making decoration the measure of learning.

Defer: free-roaming avatars, a multiplayer city, decorative buildings for every content type and broad geographic expansion. These add asset, moderation and rendering costs before the learning loop is validated.

## 5. Routing from the current situation to a goal

A learner has several contextual starting points, not one universal level.

**Inputs:** goal, curriculum/version, concept evidence, recent errors, assistance used, language, available time, device/network constraints, accessibility needs, deadline and stated preferences. Self-reported confidence is useful but separate from demonstrated performance.

**Proposed routing process:**

1. Clarify the request and any uncertain OCR/transcription. Let the learner correct it.
2. Link it to candidate concepts and curriculum outcomes; preserve uncertainty.
3. Inspect prerequisite evidence. Ask a small diagnostic only when it changes the next action.
4. Offer one recommended next step and a reason, with a practical alternative.
5. Teach or practise using a suitable representation.
6. Check understanding independently on a new item.
7. Record the evidence and update the route.
8. Schedule a later retrieval opportunity where useful.

Start with transparent rules and teacher-reviewed prerequisites. Evaluate more sophisticated probabilistic models only after collecting reliable evidence. An embedding similarity score is not a prerequisite relationship or a mastery probability.

### Worked example

A learner says: “I don't understand simultaneous equations. My test is Friday.”

- Mate confirms the curriculum and asks the learner to show the first step on a simple problem.
- The response suggests difficulty rearranging a linear equation. Mate offers a short supporting exercise and explains why.
- If that difficulty is confirmed, the route becomes rearrangement → substitution example → independent problem → later mixed check.
- If it is not confirmed, the learner goes directly to the simultaneous-equations example.
- If time is short, the app offers a shorter route with explicit omissions. It does not promise the same learning in less time.
- If repeated attempts remain unclear, a tutor handoff includes the problem, attempted steps and learner-approved context.
- After the tutor session, a short review resumes the same route.

### Across different instances

Maintain separate active goals: tomorrow's homework, an exam in six weeks, a coding project. Shared concept evidence can inform multiple routes while the goal-specific deadline and teaching requirements remain distinct. Changing schools or curriculum creates a reviewed mapping; it must not blindly transfer every completion badge.

Switching from phone to laptop resumes the session. Switching from Mate to a tutor carries a concise consented summary. Switching language preserves mathematical meaning and the original terminology. Switching to offline mode preserves downloaded tasks, not a false promise of live AI or human availability.

## 6. What personalisation should learn

Store facts with origin, confidence and expiry:

- Learner-declared: goals, preferred language, interests, available time.
- Educator-confirmed: curriculum, accommodations when appropriately shared, assignment scope.
- Observed: independently solved items, recurring mistakes, useful prior explanations.
- Inferred: possible misconceptions or formats worth trying. These are editable hypotheses.

Offer **What Mate remembers**: inspect, correct, forget, pause memory and choose sharing scope. A parent account with several children must never mix their learning records.

Adapt representations to the task and observed response: diagrams, explanation, manipulation, examples, practice and speech. Do not assign permanent “visual/auditory learner” identities. EEF finds insufficient evidence for matching teaching to fixed learning-style categories. [EEF](https://educationendowmentfoundation.org.uk/education-evidence/teaching-learning-toolkit/learning-styles).

Use retrieval, spaced review, worked examples and opportunities to explain. These have a stronger instructional basis than merely increasing screen time. Apply and evaluate them in this product rather than claiming the app inherits published effects. [IES practice guide](https://ies.ed.gov/ncee/wwc/PracticeGuide/1).

## 7. Mate: behaviour, voice and embodiment

Mate's visible behaviour should explain what the system is doing. One state controller should drive animation, transcript labels and voice controls.

| Event | Behaviour | Exit condition |
|---|---|---|
| Welcome | Brief wave, then settled attention | Greeting ends or learner acts |
| Listening | Attentive pose, clear mic indicator | Capture stops/cancels |
| Processing | Thinking pose with meaningful status | Response, timeout or cancellation |
| Speaking | Speech-associated face/body motion | Actual playback completion/interruption |
| Explaining | Small purposeful gesture/pointing | Explanation segment ends |
| Reading | Eyes/book align with content | Reading activity changes |
| Independent practice | Quiet study pose | Learner asks for help/submits |
| Correct reasoning | Brief specific encouragement | Returns to the activity |
| Error | Supportive expression and useful next action | Learner retries or changes approach |
| Offline/failure | Calm neutral pose and recovery text | Connection/retry succeeds |

Do not punish mistakes with shaming reactions. Do not celebrate correctness before verification. Never wait for an animation to finish before accepting input. Keep book, hands and props exclusive to relevant clips; check rig attachment and all transitions automatically and visually. Reuse the real Blender asset, with one renderer per active learning area, stable camera bounds and no loading-state pose flash.

Proposed performance targets: local tap feedback within 100ms, state transition visible within 150ms, short gesture crossfades around 150–250ms, continuous ambient motion minimal. These are targets to test on representative devices, not results already achieved.

### Voice experience

Use a clear, warm, youthful adult male default for Mate, selected through listening tests with intended learners. Keep selectable voice and speed, captions, text input and replay. Evaluate intelligibility for local names, mathematical notation, English/French terminology and code-switching; a voice's marketing description is insufficient.

Provide clear states: mic off, listening, processing, speaking, interrupted, reconnecting. Stop audio immediately on user interruption. Do not restart recording after the learner turns the microphone off. Handle headphones, phone calls, backgrounding, unavailable voices and denied permission.

**Future paid familiar voices:** voluntary enrolment by the voice owner, verification, explicit allowed use, consent record, withdrawal/deletion, child/guardian procedures, disclosure that the voice is synthetic, and provider review. A learner cannot upload someone else's voice and self-authorise cloning. Start with licensed stock voices; validate consent operations and demand before investing in cloning. This is a proposed feature, not an available subscription benefit.

## 8. People and genuine live help

A help request is attached to a concept/problem, preferred language and session intent. Offer:

1. Mate now, with clear AI identity.
2. A relevant verified tutor: confirmed availability or a booking option.
3. A moderated study circle where age and institutional rules permit it.

The handoff contains the learner's question, attempted reasoning, assistance already used and the requested outcome. The learner previews what will be shared. Tutors can amend a summary; the learner's independent check remains separate evidence.

A presence heartbeat is not a promise that a tutor accepts work. Availability expires; show stale or unavailable status honestly. Show prices, duration, cancellation terms and payment state before commitment. Keep request, accepted, joined, completed and cancelled states distinct.

Peer help begins with closed cohorts, moderator tools, reporting/blocking, age-appropriate membership and limits on private contact. No public location tracking or public “weak student” labels. Reward useful explanation only after validation; avoid paying or ranking peers purely by answer volume.

## 9. Local relevance that can travel

A **curriculum pack** should specify country/system, authority, level, subject, language, version/effective dates, outcomes, concept mappings, assessment conventions, source rights and reviewer. Original source and review history travel with it.

An English/French interface does not imply complete English/French curriculum coverage. Label coverage per pack and topic. Cameroon starts with independently reviewed pathways for each supported subsystem. Future countries add packs and operational support after local review; there is no universal grade-to-grade conversion.

Use local contexts when they clarify a concept, while offering alternatives so learners are not stereotyped by region. Let learners choose explanation language separately from examination terminology. Test accent recognition with consented local samples; never treat recognition failure as low ability.

Make data cost visible before downloads; support text-first tasks, compressed audio, resumable assets, downloaded lessons and queued progress. Kolibri shows the importance of designing learning access around offline use. Flutter documents repository-based local/remote data patterns that can support this direction. [Kolibri](https://learningequality.org/kolibri/about-kolibri/), [Flutter](https://docs.flutter.dev/app-architecture/design-patterns/offline-first).

## 10. Proactive assistance with clear boundaries

Mate can prepare a review, propose a revised route, identify a missing prerequisite or draft questions for a tutor. The learner can inspect why, dismiss it and control notifications.

Automatically permitted within a chosen learning goal: read authorised learning records, prepare private drafts, update a provisional recommendation and queue a suggested review.

Require confirmation: share learning records, book or pay a tutor, send messages to other people, enrol a voice, create external calendar commitments or change a major goal/deadline. Guardian/organisation policies may add requirements. Background work has a budget, expiry, cancel control and activity record.

The first release should use a few bounded workflows with explicit inputs/outputs. Add specialised agents only where evaluations show a benefit over simpler code. Keep grading decisions, permissions and payment authority outside free-form model text.

## 11. Business and trust

Proposed tiers to validate, not published prices:

- Free: useful question intake, limited guided learning, saved progress and core accessibility.
- Paid individual/family: expanded tutoring usage, richer planning and download capacity with transparent limits.
- Human tutoring: separately priced sessions with clear settlement/refund rules.
- Institutions: curriculum/cohort tools and agreed data governance.
- Familiar voices: later, only when consent and provider costs are understood.

Track cost per completed useful learning session, not only per message. Model inference, transcription, speech, moderation, storage and tutor operations must be included. Personal records should remain exportable/deletable when a subscription ends. Do not sell learner weaknesses as advertising segments.

## 12. Validate before scaling

Primary outcome: can the learner later solve or explain an appropriate new task with less assistance?

Measure immediate independent checks, delayed retention, transfer tasks, time to useful help, successful tutor handoff and return after an error. Also measure frustration, excessive hints, answer dependence, incorrect explanations, data cost, voice misunderstandings and accessibility failures.

Proposed discovery round: 12–18 learners across the chosen curricula/languages and connectivity situations, 6–8 tutors/teachers and 4–6 guardians. These are recruitment targets, not a statistically representative study. Include low-spec/shared-device users and accessibility needs.

Compare prototypes: (A) Today + list route, (B) Today + semantic map, (C) map-first. Ask learners to bring a question, find their next step, explain why it was recommended, seek human help and resume after interruption. Observe unaided completion and confusion. Keep the map only if it helps orientation without materially slowing those tasks.

Then run a small consented pilot with educator-reviewed content and pre-specified measures. Use appropriate comparison groups and an educator/statistician to design any efficacy study. Do not advertise learning gains from usage counts or a few successful demos.

## 13. First vertical slice

Build one end-to-end journey before expanding:

**Bring a maths question → confirm concept → brief starting-point check → explain/practise → independent check → updated route → later review → optional tutor handoff.**

This slice includes real authentication, per-learner isolation, offline saved work, voice interruption, honest loading states, a small accessible map and a useful no-tutor-available fallback. It excludes the full social world and voice cloning.

The review questions for the next design session are: Which first cohort and curriculum? Which concept sequence? What tutor supply can we reliably provide? Which devices/languages should define the test matrix? Is the map primarily orientation or the default home? The recommended starting answer is orientation, with Today as home.
