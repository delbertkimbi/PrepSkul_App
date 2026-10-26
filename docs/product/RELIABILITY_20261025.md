# Reliability check, 25 October 2026

Implemented:
- Explicit service worker caches app shell and all bundled fonts. Same-origin static assets are cached as visited; API/private responses are excluded. CanvasKit loads locally.
- Messaging hydrates up to four conversations concurrently and fetches per-conversation details concurrently. Unread counts use a count query. Active cache ownership is checked when accessing it. Realtime enum comparisons are corrected.
- Mate opening and session history requests time out after 20 seconds. Opening no longer automatically retries a session-creating POST.
- MCQ choices have letter badges, selected state and textual correctness feedback.
- Mate escalation displays real tutor directory entries for the learner's first saved subject. This is not yet conversation-topic ranking or a guarantee of tutor suitability.
- Delete account link below logout opens optional feedback/support and a confirmed, prepared email request. The user must send it. No deletion or automatic notification is claimed.

Verified:
- Web release build.
- Nine onboarding tests, three practice tests, three service-worker tests.

Still required before promising end-to-end readiness:
- Live fresh-account signup/verification/profile persistence, payments and first lesson walkthrough.
- Browser offline reload visual verification, including first installation and cache updates.
- Live messaging and account-switch verification against the database.
- Server-side deletion intake, durable admin queue/email delivery and acknowledgement.
- Conversation-specific tutor ranking with level, location and budget constraints.
- Approved voice backend deployment and regeneration of older bundled recordings.
- Pixel installation: wireless connection dropped during APK transfer; installation failed.

The database connector reported unavailable during this pass. No database changes were applied.

## October 26 continuation

- The local preview's Mate API on port 3000 was not running. Restarted it and verified the session endpoint responds with HTTP 401 for an unauthenticated request. This proves reachability, not authenticated lesson generation.
- Added `scripts/run-preview.sh` to start the backend alongside the Flutter preview.
- Session opening now coalesces concurrent requests. Authentication and missing-lesson failures have distinct messages. Typed/voice input is retained while reconnecting, with immediate thinking feedback.
- Busy Mate uses the existing thinking animation; the learning summary selects encouragement, celebration or graduation according to the streak.
- Local reminders now use learning activity rather than legacy game statistics. They use the saved visit time. Remote push/email reminders and production scheduler delivery have not been verified.
- Eight practice/voice-input tests passed. Targeted analysis reported no errors and three existing style infos.

Higgsfield implementation boundary: use the assessment's deterministic interactive teaching board first. Generated images/video should be optional reviewed assets, never a dependency for opening or completing a lesson. CLI/MCP generation spends account credits; web Unlimited/free allowances must not be assumed to apply. No paid generation or subscription was initiated.
