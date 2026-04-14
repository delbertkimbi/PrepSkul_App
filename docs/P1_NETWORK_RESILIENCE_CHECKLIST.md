# P1 Network Resilience Checklist (SkulMate)

Owner: __________  
Date: __________  
Build: __________

## API and Retry Behavior

- [ ] Generation request retries once on transient network failures.
- [ ] Generation request retries once on HTTP 5xx responses.
- [ ] Retry delay is short and does not create duplicate submissions.
- [ ] Timeout errors show actionable user guidance.

## Offline / Intermittent Network UX

- [ ] Upload flow shows friendly network error (no raw stack/HTML).
- [ ] Generate flow exits loading state after any failure.
- [ ] Library can show cached games if server fetch fails.
- [ ] Offline notice is visible when cached fallback is used.

## Error Messaging Quality

- [ ] `failed host lookup` mapped to "check your internet connection".
- [ ] `failed to fetch` / CORS-like web failures mapped to user-safe message.
- [ ] 402 credit/free-limit errors shown as billing guidance, not generic failure.
- [ ] OCR/extraction failures use "couldn't read text" guidance.

## Manual Test Scenarios

- [ ] Disable internet before generation and verify graceful failure.
- [ ] Re-enable internet and verify subsequent retry succeeds.
- [ ] Trigger server 5xx (staging/proxy) and verify one auto-retry.
- [ ] Open Upload tab after offline fetch and verify cached history still visible.

## Sign-off

- [ ] P1 network resilience pass complete.
- [ ] Remaining issues logged as actionable tickets.

