# SkulMate redesign: teaching first

Date: 2026-10-05
Status: researched proposal and cleanup inventory. Runtime redesign has not been implemented.
Canonical app checkout: /Users/user/Desktop/PrepSkul/prepskul_app_delbert.
Website/API checkout: /Users/user/Desktop/PrepSkul/PrepSkul_Web.

## Product decision

Build a contextual AI tutor with a shared learning board, interruptible voice, adaptive practice, and memory of demonstrated understanding. Human tutoring is booked and priced by session. The user's October 5 direction supersedes the old deck/game-first navigation and monthly tutor-card estimates.

Read together: ../primar-curriculum.md; ../../../PrepSkul_Web/docs/skulmate/ARISTOTLE_LOOP.md and CONTEXT_ENGINEERING.md. The older adaptive-learning PRD remains historical evidence, not the navigation specification.

## Audit findings

- The app's SkulMateTutorSessionService calls /skulmate/session and /skulmate/session/turn. Neither route exists in the current website checkout at fd7e3f9. This is a release blocker; documentation saying shipped is not deployment evidence. Locate implementations across API branches, reconcile dependencies and migrations, and exercise the actual authenticated endpoint before redesign rollout.
- The codebase contains deck hubs, social challenges, leaderboards, numerous game screens, a Primar shell and tutor-session UI. Their coexistence is not proof they are unused. Trace routes, imports, deep links and stored records before deletion.
- tutor_card.dart explicitly computes perMonth and renders /mo. PricingService already exposes perSession. Audit rate duration and overrides before changing display; an hourly rate cannot silently become a differently sized session.
- SkulMateSessionCache stores serialized turns in preferences. That provides history, not a durable offline request outbox, idempotency or conflict resolution.
- Primar guidance requires ability-based placement, spoken instructions, picturable early-reading vocabulary, supportive correction and offline banked content. It explicitly records unvalidated calibration and a French reading gap.
- Identity policy conflicts: Aristotle notes say a parent account is the student; newer onboarding can describe a child. Introduce an explicit active learner identity independent of payer/account role, and scope every session and memory query to it.
- Existing context docs contain model/provider names and performance claims. Verify availability, credentials, measured quality and latency; do not implement against those names by assumption.

## Proposed experience

Navigation: Learn (default), Journey, Tutors. Profile/settings are reached through the account control. Bookings are visible within Tutors and upcoming sessions on Learn. Messages/receipts remain accessible within the related booking.

Learn opens a calm desk with a short contextual greeting, Resume when relevant, and Talk / Type / Bring a question. Mate asks one diagnostic question and starts useful teaching before extra setup. Onboarding gives initial context, never a fixed ability label.

During a lesson: compact Mate + language/audio state at the top; one shared board in the center; pinned Talk/Type and attachment controls below. History is a secondary sheet. On wide screens, history sits beside the board. Board types include drawing, worked steps, manipulatives, picture choices and a short independent check. Switching surfaces preserves the learner's work and focus.

Teaching cycle: understand goal → probe → identify likely misconception → demonstrate or scaffold → guided attempt → independent transfer → recap and next step. Ask focusing questions when useful; provide direct instruction when needed. Avoid forcing every learner through an arbitrary three-failure threshold. Help is recorded; assisted success alone does not establish mastery.

Example: a learner asks about halves. Mate shows a loaf split in two, asks the learner to select a half, responds to the actual choice, then uses a different object for an independent check. Next session resumes from that evidence. Secondary-school learners see age-appropriate diagrams and language with the same underlying interaction system.

## Visual and motion contract

Keep the established navy, blue, cyan and yellow mascot identity. Sample exact values from the canonical site asset before exporting new assets. Add restrained peach, mint and lavender for semantic surface accents.

Warm paper canvas; solid readable lesson sheet; selective clay depth on primary controls, manipulatives, illustrated subject tiles and rewards. Avoid low-contrast white-on-white controls from the reference images. Text and equations get quiet backgrounds. Reuse the established illustrated tile family; one consistent simple control-icon family. Bundle assets locally.

Mate is a rig/state machine: idle, listening, thinking, explaining, inviting an answer, encouraging, celebrating, reconnecting. Audio playback controls speaking; microphone capture controls listening. Interrupt cancels queued audio and stale responses. One coordinated pose transition, stable hand anchors, no independent continuous limb shakes. Celebration follows learning evidence, once; reduced-motion mode uses static expressions. Silence is not a failure state.

Proposed timing targets: 100–160ms press, 220–350ms surface transitions, infrequent idle motion; validate with users. No moving grain behind reading. Raster texture or painted geometry is the default; optional shader effects must have a static fallback and pause offscreen.

Asset budgets (proposed): small illustrations <=40KB WebP where quality permits; larger scene <=120KB; reuse a single mascot rig rather than many heavy rendered frames. Never replace genuine tutor photos with generated people. Generate decorative assets only after the board composition is agreed.

Accessibility: 48dp touch targets, normal-text contrast >=4.5:1, non-text controls >=3:1, text scaling, captions, replay, keyboard access, reduced motion and visible focus. Voice is optional, and the interface must work with audio muted.

## Backend and low-bandwidth design

Preserve useful session, retrieval, curriculum, payment and auth infrastructure after verification. Build a typed turn envelope containing sessionId, learnerId, turnId, sequence, language, teaching move, spoken text, board operations, evidence and next action. Server derives account identity from auth; clients cannot authorize learner access by supplying an ID.

One bounded orchestrator chooses from validated tools: retrieve curriculum, inspect upload, update board, request practice, record evidence, suggest tutor. Validate schemas and pedagogy before rendering. Treat uploads as untrusted source material. Record source/provenance and uncertainty. The agent never charges or books without a reviewable learner confirmation.

Persist learner context separately from raw conversation: selected language, curriculum, custom country/subject, goals, accessibility/voice preferences, mastery evidence and assistance ledger. Version schemas. Check actual deployed migrations across both repositories before adding new ones; similar numeric prefixes must not be assumed compatible. Never silently discard required learner fields.

Good connection: stream small text/board events and optional chunked speech. Weak connection: shorter turns, compressed mono audio, bounded timeouts, cached phrases and no generated illustration per turn. Offline: clearly labeled downloaded lessons with deterministic practice; do not imply a live AI response. Save attempts locally and reconcile later.

Use a durable outbox with idempotency keys, sequence checks, retry backoff, resumable sessions, account-scoped cache cleanup and capped storage. Cancel stale speech on a new turn. Resume from last acknowledged event after disconnect. Provider failures need a friendly retry/continue-text state, never raw URLs or exception traces.

English/French are initial verified paths. Language switching changes speech and explanations together; do not claim untested language support. Localized content needs review, especially foundational phonics. Track STT confidence and let learners correct what was heard.

## Human sessions and pricing

Card: verified price + currency + explicit session duration; available format/language; next slot; Book session. If duration/rate is missing, say price to be confirmed rather than inventing a quote.

Booking: learner → goal/context → duration → availability → server quote → review/pay → confirmed session. Quote carries currency, price basis, duration, quantity, fees, discounts and expiry. Card and checkout must use the same service. Support multiple sessions as an explicit quantity, with a clear total. Preserve historical monthly purchases, entitlements and receipts; remove monthly assumptions only from new booking paths. Never reprice an existing booking.

## Cleanup ledger and order

KEEP / ADAPT: auth, verified payment/booking records, learner profiles, uploads, useful board/practice components, curriculum progressions, existing illustration assets, tested voice/cache utilities.
REPLACE: legacy home carousel and tutor-count progress as learner landing; chat-bubble-first lesson presentation; monthly estimates; duplicate mascot controllers; raw exception UI.
RETIRE FROM PRIMARY NAV: deck creation, game catalog, leaderboards, social challenges, wallet-first entry and repeated Super promotions. Practice remains available inside teaching when it helps.
DELETE AFTER DEPENDENCY AUDIT: unreachable old screens, duplicate renderers/services, obsolete bundled media and abandoned flags. Each deletion must list callers, route/deep-link replacement, data compatibility and rollback commit. Never delete user learning history or financial records as UI cleanup.

Milestones:
1. Reconcile app/API branches, route reachability, migration state and active learner identity. Capture known-good source revisions and deployment mapping.
2. Build one complete lesson slice: context → voice/text question → board → learner attempt → adaptive explanation → independent check → saved recap → resume after reconnect.
3. Apply the paper/clay token system, mascot state machine and consistent icons to that slice; review phone and desktop layouts.
4. Replace learner shell and integrate session-priced tutoring. Preserve tutor operational tools and booked-session access.
5. Remove legacy entry points and then proven-unused files in small reviewable commits. Update docs and release manifest together.
6. Expand subjects only after the slice meets learning, latency, accessibility and persistence checks.

Acceptance before rollout: complete a first lesson without upload; show adaptation to an actual answer; interrupt audio without overlap; retain name/language/custom answers after sign-in; switch learners without memory leakage; reconnect without duplicate turn/charge; continue downloaded practice offline; consistent session quote across card/checkout/receipt; no raw errors; reduced motion; small-screen/text-scale review. Proposed network exercise: 400kbps, 500ms RTT, temporary disconnect. Measure time to first useful response and bytes per lesson before claiming low-bandwidth readiness.

## Research and limits

Aristotle public product describes interruptible voice, shared board, practice and session memory: https://www.heyaristotle.com/ . Public claims are design references, not independent evidence of outcomes or an inspected logged-in experience.
Paper Shaders: https://shaders.paper.design/ . Web/React shader tooling is inspiration; the Flutter app should not be migrated to React to use it.
Expo motion case study: https://expo.dev/blog/making-ai-feel-human-in-a-mobile-app-with-expo-reanimated-and-skia . Translate interaction principles to Flutter; do not import framework choices blindly.
UI/UX Pro Max: initial system recommendation was an unsuitable marketing feature grid; rejected. Targeted claymorphism result supported selective tactile surfaces subject to accessibility checks.

This audit does not establish that the current backend, migrations or offline behavior work in production. No runtime code has been deleted by this planning pass.
