# Learner experience redesign — 14 October 2026

## Product direction
The app opens around the learner's next useful action. It is no longer a marketplace shell with an AI tab inserted into it. The primary spaces are Learn (saved journey), Mate (a focused teaching conversation), and Schedule (real tutoring sessions). Profile belongs behind the header avatar; discovery and requests remain reachable when needed.

Students and adults learning for themselves share this shell. Parent child records remain separate: the initial journey reads only the account's own paths (child_id is null). Tutor-facing navigation retains its operational workflow. Existing marketplace code remains recoverable on codex/learner-experience-before-redesign, snapshot 1723a04. Implementation branch: codex/learner-experience-redesign.

## Experience principles
- Reuse onboarding's cream, navy, sky and yellow, with Fredoka headings and Nunito body text.
- One meaningful next action per state; no fabricated mastery, progress, streak, or suggested plan.
- An empty account has a starting point; an unavailable backend has a retry state. Those states must stay distinct.
- Mate is an approachable teacher inside the learning flow. No second hero/title stack, no large menu of modes, no claim of active microphone capture when input is muted.
- Tutorials, games, social features and ranks do not compete with the learner's first decision. Legacy code remains available; no data was deleted.
- Saved progress is labelled as worked-through steps, not inferred independent mastery. Skipped is distinct from completed.

## Data and navigation contracts
- Saved paths: account-owned skulmate_lessons rows, newest first; bounded wait and visible failure.
- Resume: open the existing lesson object, never generate a duplicate plan.
- Create: verified Flutter bearer or website cookie identity; validate child ownership; source deck limited to the verified owner; allowlisted CORS and generation rate limit.
- Generation failure: visible error, no generic fabricated fallback saved as an AI lesson.
- Step save: identity required and failure propagated; require an affected row before reporting success.
- Existing numeric/semantic navigation intents map to contextual tutor discovery, requests, profile, or Mate. Tutor shell remains separate.
- Session and payment implementations are retained; this redesign does not waive earlier migration/reconciliation release gates.

## Reference research
- Duolingo path design: https://duolingo-papers.s3.amazonaws.com/reports/Duolingo_whitepaper_language_read_listen_write_speak_2024.pdf
- Aristotle skill maps: https://www.heyaristotle.com/subjects
- Khan Academy learner priorities: https://blog.khanacademy.org/meet-the-new-khan-academy-classroom-experience/
- Khan Academy structured learning signals: https://blog.khanacademy.org/how-khan-academy-is-building-a-better-ai-tutor-our-most-recent-learnings/

## Remaining product work
This establishes the new learner shell and a truthful saved journey. The broader adaptive engine still needs to connect independently verified practice outcomes and prerequisite skills to recommendations; saved step completion alone is not proof of mastery. Parent learner switching, tutor discovery, schedule detail and profile surfaces should receive subsequent focused interaction passes without expanding the main navigation again. Live payments and physical microphone/speaker testing remain release checks.

## Verification completed 15 October
- Release web preview built and served at http://127.0.0.1:8080, using the local Next backend for learning requests.
- Signed-in live walkthrough created and persisted a five-step Forces/Newton's Laws path. Returning home loaded its real map. Continuing opened the existing saved object without a second creation request.
- Learn, Mate and Schedule destinations render in the authenticated account. Schedule retains Upcoming/Past inside the embedded page. Profile and tutor access stay contextual.
- Recap wording is neutral even for existing plans whose generated titles previously claimed mastery. Future generated recaps are normalized on the server too; school context is included in the planning prompt.
- 12 focused Flutter checks passed (journey empty/error/retry/real status/large text, teaching screen, voice input and practice save/retry). 8 planning/backend checks passed. Focused analysis of the new shell, journey, teaching screen, path service and API configuration found no issues; the reused schedule screen retains pre-existing analyzer findings.
- No live payment, session booking, physical microphone recording or production migration was performed. The saved test path remains in the supplied account for review.

## Repair audit — 15 October, after learner screenshots

The earlier navigation redesign was not end-to-end. A path activity still
opened `GameGenerationScreen`, and returning from that route (including failure
or cancellation) called `completeStep`. Browser document bytes were omitted by
the tutor upload service. OCR used retired model IDs. The deployed database
also lacked `save_skulmate_practice_outcome`; client save UI could not repair it.

The current learning contract is:

1. Learn is the only roadmap. Selecting it opens the current lesson directly.
2. Reading acknowledgements mean read, never demonstrated mastery. Leaving the
   screen does not advance anything.
3. Practice happens inside the Mate session, against persisted assistant turns.
   The client submits each selected answer; the API grades stored answer keys.
4. The atomic outcome function stores the receipt, concept state and assistance
   state together. Retrying the same turn cannot count a second attempt.
5. `/lesson-progress` checks the owned path, current step, child identity, and
   saved independent correct outcome before advancing a practice step. Updates
   use `updated_at` to reject stale concurrent changes. Flashcard reveals and
   assisted results cannot advance independent practice.
6. Only saved success changes the map. Failed material intake remains retryable;
   empty extraction or failed chunk persistence cannot report successful intake.

The additive atomic-outcome migration was applied to the PrepSkul Supabase
project on 15 October. Verified: backend can execute it; authenticated clients
cannot. Payment migrations remain a separate rollout.

Design uses the onboarding Fredoka/Nunito typography, cream background, navy
paper borders and sky selection state. Mate has a purposeful place at the path
introduction and lesson reading/thinking state. Do not add decorative mascots to
every card. Legacy game screens remain preserved in Git and are removed from
the current learner path and Mate's menus.

Remaining acceptance gates must be reported honestly: live browser photo intake,
voice conversation and output quality, lesson-to-practice-to-reload persistence,
and hosted backend deployment. A local build or mocked route test alone is not
proof of these. Historical completed steps created by the former route-close bug
are unverified and must not be presented as independent mastery.

### Latest continuation

Removed the topic AlertDialog. New-path input now lives inline on Learn.
Removed the duplicate path overview: the map opens the actual reading or Mate
lesson. Added a regression test proving that leaving a reading screen does not
acknowledge it. Sessions now carry lesson_id and lesson_step, checked against an
owned current lesson at creation and against the saved receipt at progression.
The session-binding migration is applied and verified. Latest release web build
passes. Browser interaction tools became unavailable during this continuation;
final live UI, photo intake and conversation verification remain open gates.

## Visual foundation — 15 October, latest screenshots

The earlier paper borders and display headings were applied too broadly. Added
`core/design/learner_design.dart`: one signed-in visual contract for typography,
surfaces, borders, text fields, chips, buttons and app bars. Onboarding identity
is retained through the palette and same Mate model, while dense app controls
use readable Nunito at a restrained scale. No hard offset shadows on routine
cards. No repeated outline around a composer field inside its outlined wrapper.

Learn map, Mate, Schedule and tutor discovery now adopt this foundation. Shared
content measure is 840px. Navigation and header are compact with left-aligned
titles. Only the current map action opens the current lesson; upcoming rows
must not misleadingly open a different step. Schedule does not display layout
controls when empty, and its empty state contains an actual booking entry.
Startup uses the exact model-front Mate poster, a gentle breathing transition,
and reduced-motion support. No arbitrary timer hides loading before first frame.

Reference review: heyaristotle.com, help.gizmo.ai (AI Tutor / Magic Import), and
mynkwa.com. These are direction references, not a claim of inspecting private
signed-in competitor screens. Live UI verification remains pending because the
browser interaction tool is not available in this session.

## Four-destination reference — 15 October

User supplied a four-screen reference and explicitly requested four tabs.
The learner shell now uses Home, Tutors, Mate, Sessions. Tutor discovery stays
mounted in the tab; profile and booking requests remain secondary actions.
Home leads with a real saved-lesson continue card and expands the map on demand.
Reference-only numbers, streaks, badges, tutor ratings and bookings are not seeded.

Return experience: a fresh authenticated shell checks a user-scoped last-active
preference. After at least 30 minutes away, Mate's existing celebration clip
welcomes the learner for 2.4 seconds, with an immediate skip button. The welcome
covers the content and navigation; it does not run on tab switches or ordinary
foreground resumes. Lifecycle exits update last-active. First launch does not
pretend to be a return. AliveMate respects reduced motion. No audio is started
by this welcome and no learning progress is changed.

## Pricing and launch cleanup — 15 October

Tutor discovery now displays `calculateFromTutorData()['perSession']`; price
sorting and filter ranges use that same unit. Filters explicitly say price per
session. Tutor details no longer lead with a monthly package or default weekly
frequency. The existing booking frequency/payment total calculations are retained
because those are quotes for an actual schedule, not discovery price labels.
Regression checks distinguish a 3,500 XAF session from a 28,000 XAF monthly total
and confirm that frequency changes do not change the session rate.

The boot loader is separate from the return greeting: larger matching Mate
poster, PrepSkul wordmark, honest loading status, short inline progress rail,
reduced-motion fallback, and removal only after Flutter's first frame. It is not
an idle tiny mascot centered on a blank page. The return greeting still uses the
3D celebration clip after meaningful absence. Mate's empty lesson now uses a
compact mascot-and-speech-card composition. Tutor bios are one line, subject
chips use text, and the secondary Home help card uses sky rather than another
competing navy feature card. Home greeting can use the signed-in learner name.

## Reference composition pass

Rebuilt discovery cards around a 52px avatar, name/rating, right-aligned session
price, three subject pills and a compact footer. Removed bio paragraphs and
ornamental subject glyphs from these cards. Preserved profile navigation,
offline handling, match sorting and account-specific ordering. No synthetic
availability indicators or review counts are shown.

Home resume action now has the reference's yellow treatment and larger animated
Mate. Sessions defaults to the compact week calendar when embedded; layout-mode
chips stay off this tab. Choosing a day updates the selected day's session list
rather than retaining the prior focus. Standalone scheduling retains its other
view modes. Existing join/reschedule eligibility logic is retained.

Home's upcoming-session section now reads the owned individual-session service
and opens the Sessions tab. It shows subject/tutor and localized date/time only
when a real row exists; otherwise it offers the schedule without claiming an
invented booking or an empty schedule. Pull-to-refresh reloads both paths and
upcoming sessions. Trial-session aggregation remains in the full Sessions page.

## 2026-10-16: reference typography and startup correction
- Shared learner typography now uses locally bundled Plus Jakarta Sans. Home/Mate explicit onboarding font overrides were replaced with learner styles.
- Home greeting lives in the shell header; removed duplicate heading and greeting mascot. Reduced card title and spacing.
- HTML startup now loads the real 06_celebrate model animation, with an inspected full-body cheerful poster. Starts on model load, respects reduced motion and visibility, and never delays Flutter first frame. Return overlay also has a cheerful loading fallback.
- Focused widget/return tests: 10 passed; phone golden rendered and inspected. Focused analyzer clean. Browser interaction tooling unavailable: live animation and signed-in visual validation remain outstanding. Intermittent path request failure remains unresolved.

## 2026-10-17 navigation and loading
- Extracted LearnerBottomBar with four matching CustomPainter vector icons, including Mate antenna/face. Equal-width tap regions, selected semantics, reduced-motion transitions, safe area and 600px maximum desktop width.
- Home uses a static card skeleton rather than an indefinite circular spinner. All plan loaders time out after ten seconds and retain the retry/error distinction.
- Seven focused navigation/loading/map tests passed, including 320px at 1.5 text scaling and a never-resolving request. Focused analyzer clean.
- Prior in-progress repairs retained: flattened tutor name resolution, sticky profile actions, board duplicate suppression, image URL plumbing and early-reader prompt guidance. True session-count booking, complete adaptive media rendering, video retrieval, and live signed-in verification remain unfinished.

## 2026-10-17 design correction and delivery gap
The canonical type pair is the actual Next.js onboarding implementation: Fredoka display, Nunito body (components/onboard/learner-onboard.tsx), not typography inferred from generated mockups. Shared learner typography is restored accordingly. Tutor discovery uses portrait/name/rating, subject tags, optional real bio, and a separate per-session price/profile footer with a shallow paper shadow.

The user's accepted learning direction is Goal → Learn → Practice → Progress. Discover/Learn/Practice/Review are reusable states, not twelve compulsory screens. The current path/session/outcome work is infrastructure, not delivery of this whole promise. Outstanding: one contextual lesson player with configurable reading/video/interactive/practice blocks; actual verified video retrieval; accurate visual generation/rendering; robust voice turn-taking; age-aware presentation; true one-or-many-session booking. Keep completion and mastery grounded in saved receipts. Mascot stays small/absent during focused reading and practice.

### Tutor footer, auth, and onboarding continuity
- Footer now has a compact message action and expanding Book a session button. Existing chat eligibility is retained. Schedule preview is also shown before credentials/reviews.
- Existing phone/password login restored by enablePhoneSignIn. SMS OTP remains disabled; this is not a claim that new phone registration is functional.
- Home reads the saved learner context with an eight-second bound and prefills the subject/class. Manual topic remains editable. Suppresses the duplicate empty-path card while the editor is open.
- Eight focused Home/name tests pass. The Book a session entry still opens the recurring flow; the true session-based backend migration remains outstanding and was explicitly reported.
