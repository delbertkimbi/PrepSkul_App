# Adaptive learning continuation — 13 October 2026

## Authoritative handoff

Read the latest completed turn in Codex task “Replace old onboarding flow” (01a12fc4-1c77-7fb1-8d12-a27e7a2283cf), rather than relying on the older October 8 roadmap.

- App working checkout: `/Users/user/Desktop/PrepSkul/prepskul_app_release`, branch `codex/short-mate-onboarding`, starting commit `3d35079`.
- That baseline was published to https://operating-axis-420213.web.app/ by the previous task.
- Backend checkout: `/Users/user/Desktop/PrepSkul/PrepSkul_Web`, branch `codex/learner-context-retrieval`, starting commit `bf9ac01`. Curriculum retrieval changes were saved but not deployed; the previous task reported that the signed-in Vercel account could not access the project serving prepskul.com.
- `prepskul_app` and `prepskul_app_delbert` are older sibling checkouts. Do not merge their context or publish them as this release.
- Keep the current 3D Mate and matching offline artwork, bundled fonts and recorded voice prompts. Flow: introduction, brief information screen, contextual questions, signup, then paywall. No signup phone field.
- Subject headings stay simple. Country, school system, level, technical/commercial/general path and Arts/Science choices shape suggestions and teaching silently.
- Start precise curriculum coverage with Cameroon; retrieve source evidence on demand for the learner's current question. Generated text or a profile match is not proof of official syllabus alignment. Preserve the edition, objective and source provenance.
- A learning map and familiar/parent voice cloning remain deferred, not shipped features.

## Local changes in this continuation

The app no longer silently substitutes a demo session when opening persistent learning fails. It displays its existing retry state. Practice preserves earlier mistakes across a multi-question check, shows save failures and retry, and keys each practice widget by its turn. Revealed flashcards are treated as assisted practice.

The backend uses a transactional progress-save RPC with retry deduplication and concurrent-state checks. Assisted answers do not increase measured independent mastery or clear the independent-check requirement. The outcome route derives the concept and assistance from the owned server turn. Official retrieval candidates retain their provenance in the tutor context instead of being labelled uploads.

Top-up quotes validate both price and credit quantity against the admin plan catalogue. A trusted credit quantity is captured in the private payment attempt. Provider-verified success calls an atomic fulfilment function from both webhook and status polling. Duplicate callbacks do not duplicate credits. App checkout no longer invents a 2% fee absent from the server quote, and top-up completion checks the server ledger before claiming credits were added.

Learning credits now use separate `skulmate_credit_balances` and `skulmate_credit_transactions` tables. Only the service role can mutate them; authenticated learners can read their own records. Atomic deductions cannot overdraw. Tutoring balances use different units and are not modified by learning top-ups. The client legacy converter rejects learning top-ups.

Lesson history now loads the newest 80 turns in chronological order. Failed history/progress reads and message saves raise errors instead of returning an empty or falsely saved lesson. A failed resume lookup cannot create a replacement session. Adaptive display metadata is stored alongside the assistant turn.

These changes are local. Neither migration has been applied to production, and no real payment has been initiated.

## Ordered next steps and acceptance gates

1. Reconcile historical paid learning top-ups before enabling checkout. A read-only live audit found 31 learning top-up invoices, 10 marked paid. Verify provider transactions, prior awards and spending before deciding opening balances for the isolated learning wallet; do not reset or copy shared tutoring balances. The new migration deliberately leaves legacy tutoring tables unchanged. Their client mutation paths remain a separate security issue. Audit invoice mutation and all wallet RPC grants. Test success, decline, timeout, retry, expiry and delayed webhook using a designated sandbox account; verify exactly one award and learning access after reopening the app. Never enable the flag just to bypass the current payment block.
2. Release backend and schemas together with the compatible app. Resolve the previously reported Vercel project access and existing whole-project type errors. Current checks confirm the blocker: the connector lists the team/project but inspect returns 404 and deployments 403; CLI scope lookup also fails. The Vercel owner/team has been requested from the user. Apply reviewed migrations only after compatibility testing. Record exact app/backend/schema revisions.
3. Exercise the actual signed-in learning loop: onboarding context → a specific difficulty → retrieved evidence → explanation/appropriate visual → diagnostic practice → assisted reteach if needed → independent check → saved progress → resume. Test two different Cameroon pathways and a changed subject to catch stale context. Include EN/FR, missing evidence, upload optionality, interrupted connectivity and session errors. Never silently switch to a demo.
4. Complete the adaptive display handoff. The app currently renders practice and boards but drops returned display details. Persisted metadata now makes resume possible, but app parsing/cache/rendering still need implementation and tests. Do not treat the decorative procedural `uniqueImage` SVG as an educational illustration. Use grounded, subject-specific diagrams and evidence-supported timelines. Practice correctness still originates from the client; server-side answer validation is required before treating mastery as independently verified.
5. Build an accuracy evaluation set using Brownian motion, organic chemistry, and demand/supply across the applicable levels and paths. Check factual correctness, source support, diagram relevance, question difficulty and false claims of mastery. Expand curriculum coverage only when these checks pass.
6. Reusable material: store reviewed learning assets with exact scope, provenance, edition and review status. Reuse reviewed material across matching learners without sharing private uploads or learner memory. Keep unsupported regions explicit until authoritative coverage exists.

## Verification evidence

- Local PostgreSQL 17 regression: duplicate top-up callback produces one 600-credit award in the isolated wallet, leaves tutoring balances unchanged, charges 10 atomically and refuses an overdraft; duplicate practice save produces one attempt; invalid mastery rolls back; client roles cannot execute the privileged save/award functions. Fixtures rolled back.
- 51 backend SkulMate Jest suites passed: 278 tests, including provenance, payment fulfilment, atomic billing, progress persistence and history regressions.
- 20 Flutter onboarding/practice tests passed, including signup before paywall, earlier miss retained, save retry, and empty surface.
- Full backend typecheck still reports existing errors across unrelated application/generated files. No diagnostics were reported in the changed backend files in the inspected run. Do not call the full typecheck clean.
- Read-only live checks returned HTTP 404 for `https://www.prepskul.com/api/skulmate/health`, `/api/skulmate/session`, and `/api/payments/fapshi`, matching the app’s configured API host.
- Backend production build and Flutter web release build passed before the final wallet-isolation/history changes. The app release configuration allowlist check also passed. These earlier artifacts must be rebuilt before publishing the final changes. Latest focused Flutter analysis reports no errors, with existing warnings/info.
- No authenticated live payment or complete adaptive-session test has yet passed in this continuation. No migration, deployment, or historical balance adjustment was performed.

## Website direction — corrected 14 October

The user rejected the added mini-lesson and website changes. Those changes have been reverted: homepage, directory links, counter component and entry helper restored to their prior versions; new preview and handoff test removed. The earlier website strategy is withdrawn. Continue from the original website identity and learn from the Aristotle reference before proposing another experience. Focus on the full UI-to-UX journey, business conversion and working web voice. App adaptive learning and payment changes remain separate and intact. The user supplied https://www.heyaristotle.com/ as the reference. The final phrase remains unclear; do not invent requirements from it.

### Aristotle reference and next implementation

Reviewed the public Aristotle homepage and its real CTA transition into app onboarding on 14 October 2026. The observed opening onboarding question asks whether the visitor is a student or parent. No account was created and no paid flow was tested. Source: https://www.heyaristotle.com/.

Apply the experience principles to PrepSkul: one coherent visual world, deliberate motion, a clear primary invitation, concrete demonstrations of voice and visual teaching, supporting evidence and repeated routes into the same onboarding. Keep PrepSkul's Mate, local identity, EN/FR and human tutoring. Use actual product capabilities for demonstrations. Do not reinstate the rejected standalone mini-lesson.

Implementation order: (1) working, discoverable Mate audio with explicit activation, stop, mute and failure feedback; (2) a cohesive responsive homepage composition and section transitions, built around Mate; (3) demonstrate the actual learning interaction using approved product footage/assets; (4) connect onboarding, signup, access options and paid learning as one journey. Retain the accepted onboarding sequence. Pricing and conversion changes depend on the real entitlement model and existing payment rollout gates.

Voice investigation: the homepage mascot's click handler only animated its pose and never invoked audio. The local browser also had voice disabled in saved preferences. The greeting now uses the existing voice player and shows loading/playing/muted/failure states. A separate explicit tap on the muted state turns voice on. Greeting playback can be stopped and is cancelled on unmount or locale change. Existing player regression tests pass (6); the local English greeting endpoint returned HTTP 200 with WAV audio. This is a greeting fix, not verification of full live voice tutoring.

### 14 October: clean controls, prepared voice and continuous scrolling

User feedback explicitly rejects repeated Listen controls and wasted space inside onboarding questions. Removed question/paywall replay controls and their reserved padding; only intro offers listening and a sound choice. Browser preference and draft now agree, and a Continue gesture unlocks audio for later questions.

Prepared 28 exact catalogue prompts (EN/FR) under the website's public audio folder; the player resolves exact text to these recordings. Custom speech allows the server's synthesis time instead of aborting at 4.5 seconds. The first HTTP check caught locale middleware redirecting WAV files; the matcher now exempts audio extensions. Both English and French clip URLs returned 200 audio/wav, and sample recordings contain non-silent audio. Regression coverage checks catalogue/text/file consistency and routing, plus existing playback/cancellation behavior.

The homepage feature cards now form a native-scroll story: one persistent Mate scene, changing pose/illustration, six editorial beats and a subtle hero-photo transform. Mobile uses a compact reading flow; reduced motion removes the sticky pacing. Verified desktop/phone rendering. No synthetic practice or second learning product was added.

App microphone changes are local: listening starts from a web user gesture, reports failed activation instead of claiming to record, accepts short final utterances, and stops retrying after persistent recognition errors. Focused analysis has no issues. Practice widget tests passed (3) and the updated home smoke test passed (1); the latter had stale copy assertions. Real spoken input through an authenticated tutor session remains unverified. Full speech interruption during tutor playback remains a separate limitation: recognition currently pauses while output is playing.

With user-provided sign-in, inspected Aristotle's family entry, learner dashboard, subject map, resume route, session focus/time setup and saved-session review. The live connection remained on “Aristotle is joining you”; cancelled that attempt. No completed agent conversation, payment, or account changes were performed. Do not describe the live teaching agent as tested. Keep the map deferred for PrepSkul; the useful immediate pattern is a clear next action and continuous session context.

Final checks for this slice: backend/website production build passed; 9 voice playback and audio-route regression tests passed; four recognizer tests passed (failed start, unavailable recognition, supported locale with a short answer, permission denial and retry). Three practice-widget tests and one home smoke test passed. Standard English/French recording URLs returned 200 audio/wav after the middleware fix. Whole-repository TypeScript still has existing errors, with none found in the changed website files in the inspected run. The app now derives recording state from recognition events, selects an available language locale and keeps microphone recovery text near the composer. App and database changes remain local.

### Website refinement: connected roadmap and testimonials

Implemented the user’s requested connected lesson roadmap using existing icons: six numbered stops, two per row on large screens in a winding sequence, one vertical sequence on phones. Connectors follow measured icon positions and resize with layout. Removed feature dividers and the previous sticky mascot stage. Added the matching online/home/group photographs inside the mode cards, retaining the direct section heading without a new kicker. The original card-colour treatment remains on a looping family-quote slider, advancing every 6.5 seconds with swipe, arrows, indicators and pause/resume. It pauses for hover/focus/manual interaction and page invisibility; reduced motion disables automatic advance. Added restrained scroll entrances.

Verified desktop and 390px phone layouts, connected stop order, actual automatic advancement and manual Next, and no horizontal overflow at 390px. Existing whole-repository TypeScript diagnostics remain; none were reported for the changed components in the inspected run. These refinements are local.

### 14 October final site and app polish
- Homepage hero retained. Marketing pages use warmer EN/FR wording; attributed quotes retained.
- Single connected desktop roadmap (two cards per row), one card per row on mobile. Header mascot removed. Existing pose assets framed to exclude neighbouring sprite fragments. Desktop markers smaller outlined circles and higher-contrast path; mobile numbering retained.
- Family carousel one quote at all widths, dots only, automatic movement respects reduced motion and interaction.
- Web onboarding education emojis removed, subject preview uses selected subject, question choices no longer wait for audio. Sound selection at intro only; repeated replay buttons removed in app questions/ready/paywall as well.
- New Charon speaker: 28 bundled web clips and 26 bundled app clips; manifests point to versioned files. App clip WAVs validated. API speech also defaults to Charon/Gemini with provider fallbacks.
- Verification: 20 focused website checks passed; 24 focused Flutter checks passed, then 9 onboarding checks rerun after control cleanup passed. Focused Flutter analysis: no issues. Website production build passed before latest marker styling. Payment production migration/reconciliation and deployment blockers above remain; no real transaction was made.
- Final app launch: Flutter debug web-server running on http://127.0.0.1:8080; initial sign-in rendered. Phone sign-in disabled in config and auth selection to match email/Google scope. Refreshed build compiled and served successfully. No sign-in, payment or live tutoring transaction performed during this launch.
