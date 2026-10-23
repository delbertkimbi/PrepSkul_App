# PrepSkul: the next working learning experience

## Product contract

Home, Tutors, Mate and Sessions remain the four main destinations. The existing onboarding is the visual source: Fredoka headings, Nunito reading text, cream surfaces, navy hierarchy, sky support and yellow encouragement. Paper depth belongs on controls; lesson content stays quiet. Every secondary route needs a predictable back action.

The core journey is Goal → Learn → Practice → Progress. A learner should always know the current concept, what they have demonstrated and the next action. Onboarding subjects, class, language and goals must prefill the experience; missing optional data must not restart onboarding.

## Build in this order

1. **Reliable entry.** Diagnose the actual failed saved-path request, preserve progress, show a bounded skeleton and retry. Resolve profile photos from the saved avatar and Google metadata. Finish account deletion through a verified server endpoint and confirmation; do not ship an inert button or delete only the profile row.
2. **One complete lesson.** A reusable lesson player hosts short explanations, sourced video, deterministic interactive examples, practice and review. Start with one Forces lesson and one early-reader counting lesson. Mate opens with the current concept and previous attempts already attached. A learner can ask a follow-up and return without losing their place.
3. **Voice-led support.** A prominent Talk to Mate action starts microphone permission only on tap. Provide visible listening, thinking, speaking and stopped states; stop speech immediately on interruption. Keep typing and captions available. Early readers receive one short spoken instruction and large visual choices; older learners can expand detail. No automatic microphone capture.
4. **Grounded media.** Retrieval returns curriculum level, source URL and useful excerpts. Videos need a relevant playable source and text fallback. Generated diagrams must match a structured explanation; use deterministic diagrams for quantities and relationships where accuracy matters. An image URL field alone is not a working visual-generation feature.
5. **Practice that changes teaching.** Store the concept, response, hint usage and verified outcome. Wrong answers trigger a different explanation and a fresh check. Assisted answers do not establish mastery. Review shows evidence of progress and a specific next step, never invented streaks or percentages.
6. **Session booking.** Keep a compact Message action and wide Book a session button fixed above the safe area. Show availability near the profile summary. Let the learner select one or multiple sessions and supported duration; confirm actual slots, price and booking records. The existing monthly recurring flow does not satisfy this requirement.

## Release checks

- Refresh and reopen an existing learner account: saved progress returns; a failed request never becomes an empty new account.
- Complete onboarding once: Home uses the selected subject/class without asking again.
- Use Google sign-in: photo appears on Home and Profile; failed images have a readable fallback.
- At 320px and enlarged text, navigation labels and actions fit; filtering is visible beneath search and keyboard accessible.
- Teach the same concept by voice and text, interrupt speech, ask a follow-up, answer incorrectly, receive a useful correction and resume after reload.
- Demonstrate one accurate interactive visual and one relevant video with source and failure fallback.
- Complete both sample lessons: only verified practice advances mastery; no legacy game detour.
- Book one and multiple sessions using real availability; verify totals, records, duplicate submission protection and Sessions display.
- Confirm deletion on a test account only after reviewing data retention and active booking behavior.

## Verification status — 17 October 2026

Profile/search/navigation fixes are being checked locally. Database inspection confirms the saved-path columns and an owner-scoped read policy exist; this does not reproduce the reported runtime failure. Full signed-in browser verification, account deletion, session-count booking, retrieved videos, generated teaching visuals and the complete voice-led lesson remain acceptance work. Do not label them complete based on screenshots or API fields alone.

### Verified follow-up — 18 October 2026

- The signed-in browser loaded the existing Forces and Newton's Laws path. The reported intermittent failure was not reproduced; authenticated SELECT permission and owner-scoped RLS are present.
- Home now preserves the last successfully loaded nonempty path during refresh and on refresh failure, with an explicit stale-result notice and retry. This is in-memory continuity, not offline persistence across restarts.
- A regression test verifies that a failed refresh retains the lesson and that a successful empty response replaces it rather than retaining deleted content.
- Profile's back action and failed-image fallback were visually checked in the browser. Home now resolves the saved profile name/avatar before sign-in metadata and reloads them after returning from Profile.
- Account deletion, session-count booking and the complete grounded voice-led lesson remain outstanding.

### Custom icons and local Mate practice — 18 October 2026

Implemented an original scalable paper-cut vector family for Home, Tutors, Mate, Sessions, Learn, Practice, Voice and Offline. The footer and Mate's bundled-lesson controls use this family; migration of other screens is still pending.

Mate now exposes two bundled deterministic activities (counting four dots; net force and acceleration for a 2 kg block), each with a goal, exploration, answer feedback and review. Steps persist per account on the device. They do not call an AI service or write mastery outcomes to the server. Offline chat submission retains the draft and explains the connection requirement. Opening local practice ends the live voice session. Microphone preparation no longer runs automatically when Mate opens.

Limits: a web cold start without previously cached app files is not guaranteed; there is no on-device AI, offline speech guarantee, source-video delivery or cross-device local-practice synchronization. These are initial local activities, not completion of the full adaptive lesson framework. The live server can still be unreachable despite an active network connection; existing request error handling remains necessary.

Tutor discovery correction: Request a tutor and All filters are top-right actions. Below search, Subject, Price and Rating each open their own picker and apply to existing tutor results. Replaced “Request a person” wording in discovery, tutor request, dashboard and onboarding copy. The combined filter sheet remains available as All filters.

### 18 October — focused Mate and recovery follow-up
- Mate hides the main footer, removes repeated profile/history/more controls, provides a back action that ends voice, and adds custom learning streak access. Microphone capture remains tap initiated.
- Home caches successful owner-scoped path reads on device; failed requests remain errors and retain cached paths. This mitigates outages but does not establish the original server failure's cause.
- Cached Mate conversations restore before connecting. Automatic connection/error resource choices replace permanent offline buttons. Bundled activities remain limited to Forces and Counting; general offline AI and complete resource downloads/sync are not implemented.
- Tutor search supports subject aliases, published exam fields and single-character misspellings. One compact filter row remains; onboarding subjects are prioritised. Full curriculum/location-aware catalogue selection still needs validation.
- Learning activity is local device evidence, separate from game XP and server mastery.
- Release web build passed; 13 search/navigation/path/local-practice tests passed. Signed-in browser and real microphone verification remain pending because browser automation is disabled.

### 19 October — startup and bounded booking entry
- Web launch now paints inline vector celebration without a 3D model request or welcome copy. Soft chime is best effort under browser autoplay policy; reduced motion suppresses it.
- Returning learner celebration uses vector stars, lasts 1.1 seconds and can be skipped by tap.
- Tutor search/header spacing reduced. Booking profile/learner requests are bounded and failures expose retry instead of an indefinite spinner; recurring booking semantics are unchanged.
- Voice activation allows asynchronous browser startup before reporting failure. Live device microphone/audio validation remains outstanding.
- Release build passed; navigation and Mate widget checks passed. This does not complete the adaptive teaching/media contract or establish the cause of every loading delay.

### 20 October — composer, progress and visual consistency
- Composer defaults to voice; Send appears only with nonblank input. Listening/speaking exposes Stop. Widget regression tests cover the transition.
- Removed redundant Mate title icon. Active 3D mascot follows voice/thinking state. Assistant emphasis is rendered using Nunito rich text; full long explanations remain expandable, with generated boards above them.
- Tutor card CTA uses navy with explicit white label/arrow. Tutor-request and booking-request glyphs are distinct. All custom glyph painters are square-constrained to prevent stretching.
- Progress includes owner-scoped saved lesson counts (completed only), mascot and local learning activity. Historical game streaks are not presented as learning mastery.
- Tutor availability uses brand typography/custom schedule glyph; removed duplicated availability from pricing.
- Local Next server was stopped; restarted and session endpoint returns expected unauthenticated 401. Signed-in teaching and media generation are not verified by this probe.
- Pre-booking messaging remains outstanding: current conversations schema requires exactly one booking/session context. No constraint or access policy was weakened to make the UI appear functional.

### 20 October: menu and Home verification
- Mate header now places the session menu after the learning streak. New session and locally saved past sessions are available from this menu.
- Browser inspection confirmed the saved Forces lesson and Motion Check Quiz returned on Home, with the original 3D mascot. Home's Mate card uses a navy action and tighter spacing.
- The local preview and Next backend had stopped; restarting them restored asset delivery and API reachability. Unauthenticated session requests correctly returned 401. This does not verify authenticated teaching.
- Fixed pending-new-session handling so reconnecting does not restore the old conversation; a failed new-session request also clears the old destination ID.
- Browser use was subsequently disabled in Work settings. Signed-in retry, microphone operation and offline history reopening remain unverified. Full booking and pre-booking messaging acceptance remains outstanding.


### UI consolidation — 22 October 2026

- Mate's session menu opens a right-hand drawer with new-session and on-device history actions. The original 3D mascot remains, with an arrival wave and state-driven expression. Microphone capture still requires a tap.
- Home separates the current lesson, learning path and new journey. New journeys navigate to a fresh Mate route. Cached progress and retry remain visible after a failed refresh.
- Shared navy paper-depth actions now cover tutor contact/booking, booking navigation and call joining. New message, price and rating glyphs extend the existing icon family. Request cards use quiet white surfaces and the Requests route has normal back navigation.
- Subject choices broaden the core curriculum and keep learner preferences first. Tutor chat input is bounded to five lines with a labelled send action.
- An original short bell chime replaces the previous generic startup sound; browser autoplay restrictions still apply.
- Applied migration `202610210001_tutor_inquiry_conversations`: learners can open an approved tutor inquiry without booking first. It checks identity, tutor visibility and blocked conversations, and reuses a conversation to avoid duplicates. Transactional database checks left no test records. Signed-in end-to-end messaging remains unverified.
- Home/Mate widget checks passed including failed refresh, path state and 320px enlarged text. Browser inspection is blocked by the browser security policy; these source changes must not be described as visually accepted.
- Remaining acceptance includes one/multiple real-slot booking (the current recurring flow remains), full live teaching/media and voice consistency on a real device, full offline synchronization, and account-deletion verification. This UI pass does not establish those features as complete.

Build verification: release web build passed (98.3 seconds); 15 targeted Home, Mate, voice-state and tutor-search tests passed. Preview and chime asset returned HTTP 200; unauthenticated Mate session endpoint returned expected HTTP 401. Revision: `learner-ui-20261022`. Live visual and microphone acceptance remain blocked/unverified.


### Booking availability correction — 22 October 2026

Removed fabricated fallback times and the assumption that missing availability means every weekday is open. Trial booking now clears stale selections while loading, rejects out-of-order responses, has a bounded 12-second load and retry state, and rechecks the preview when duration changes. Canonical AM/PM parsing fixes the previous early-return bug (`7:00 PM` was treated as `07:00`).

Database inspection confirmed that client-side SELECT queries cannot see other learners' sessions under existing RLS. Added `public.tutor_busy_windows` as an invoker wrapper around an authenticated, search-path-pinned private function; it returns only occupied minute ranges for an approved visible tutor, including duration and adjacent-day overlap. Applied the generated migration SQL remotely and retained its local migration file. No booking records or messages were created. Authenticated execution and anonymous rejection passed in a rolled-back transaction; four targeted Dart tests passed. Security advisors returned existing project findings; none named the new functions.

Remaining: this is availability preview, not a reservation or atomic booking confirmation. Recurring patterns currently use the existing 60-minute convention. One/multiple selected sessions, supported tutor-specific durations, server-validated pricing, idempotent atomic creation and end-to-end Sessions display remain unfinished. Browser acceptance remains blocked by the previously reported browser security policy.

Booking availability release build passed (103.1 seconds), revision `booking-availability-20261022`.


### Mate voice and review pass — 23 October 2026

- Connected `TTSService.speakAndWait` to authenticated cloud speech after bundled prompts, before device fallback. Cancellation closes the pending request and stops audio. The server now keeps a single configured model identity and adds playful, clear delivery instructions. Device voice remains a fallback and cannot be claimed to sound identical offline.
- Verified a real Gemini/Charon speech request: 320,640 PCM bytes in 8,872 ms. Saved a WAV audition in `docs/product/previews/mate-voice-preview.wav`. Initial 9-second request timed out; server/client speech bounds are now 20/23 seconds. This is not low-latency streaming voice.
- Activated original Blender listening, success and try-again clips in the active Mate header. Other mood-based clips remain. This does not mean every existing mascot animation is now used.
- Added pinned TimelineTile 2.0.0 for connected lesson nodes. Completed steps reopen a separate Mate review session without a progress callback; future nodes remain locked. Skipped steps no longer count as completed in the lesson model.
- Shortened pedagogy instructions, added class/topic-aware practice guidance and explicit distinction between generated practice and verified official exam questions. This is not a sourced question-bank implementation.
- 13 targeted Flutter tests passed, then the expanded seven-test Home suite passed including completed-lesson review. Eleven backend adaptive tutor tests passed. Static analysis of changed Mate files has no errors. Signed-in browser/audio playback and full classroom/message UI acceptance remain unverified.

Outstanding user scope: full class-specific sourced assessments, richer generated lesson-path content, completion/unlock evidence across all lesson types, streaming classroom experience, the remaining message/call/loading design consolidation, and full offline voice/content continuity. Do not mark the whole request complete.

Release build passed (139.1 seconds), preview revision `mate-learning-20261023`.
