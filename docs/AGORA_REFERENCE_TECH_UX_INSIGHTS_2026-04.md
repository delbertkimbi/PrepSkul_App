# Agora Reference: Technical + UX Insights (Apr 2026)

This document captures actionable insights from:

- Agora case study collection shared by leadership (Hallo, PandaTree, Noon, Preply).
- Official Agora docs and recent release notes relevant to PrepSkul's classroom stack (Flutter/Web RTC and Signaling).

Use this as a product + engineering reference while executing the group classes roadmap.

## 1) What winning education products are doing

### Cross-case patterns that appear repeatedly

- Real-time engagement is the core product value, not a side feature.
  - The strongest outcomes come from "speak/do together now" experiences, not static content.
- Reliability and global consistency are business features.
  - Teams switched providers when QoE was unstable across countries.
- Social and collaborative loops drive retention.
  - Live rooms, breakout/group learning, peer challenges, and post-session re-engagement improve usage.
- Parent/admin visibility increases trust and conversion.
  - Parent hubs, progress review, and session recordings reduce support burden and increase confidence.
- Pricing + efficiency matter as much as features.
  - Successful teams explicitly balanced quality, scale, and per-minute economics.

### Specific learnings from the case studies

- Hallo:
  - Prioritized global reach and consistent latency for distributed learners.
  - Built around frequent speaking practice and easy access to native speakers.
- PandaTree:
  - Combined live tutoring with interactive curriculum assets.
  - Used recording + analytics to improve support and reliability.
- Noon:
  - Treated motivation and social learning as the main problem to solve.
  - Used live classrooms + quizzes + gamification; saw major NPS gain after improving stability.
- Preply:
  - Measured lesson success rate as a core north-star metric.
  - Improved outcomes with high-quality AV plus audio-only fallback for weak networks.

## 2) Recent Agora updates we should account for

Below are notable updates from official release notes/content retrieved during this review.

### Video Calling (Flutter)

- v6.4.0 (Aug 29, 2024):
  - Compatibility changes in extension callbacks (context-aware callback variants).
  - New 1:1 video scenario optimization and voice AI tuner.
  - Rendering/hardware decode and stability improvements.
- v6.3.x highlights:
  - Better weak-network fallback behavior and many stability fixes.
  - iOS privacy manifest support and camera/center-stage capabilities.

### Video Calling (Web)

- v4.22.2 (Oct 29, 2024):
  - Better screen-share audio controls via `createScreenVideoTrack` + configurable audio init.
- v4.22.0 (Aug 16, 2024):
  - Bundle/service modularization for app-size optimization.
  - AV1 codec option (beta) and quality/transmission efficiency improvements.
- v4.21.0 (Jun 3, 2024):
  - Channel preload support to reduce join delay.
  - Adaptive quality improvements under bandwidth and Safari constraints.

### Signaling (Flutter)

- v2.2.5 (Sep 25, 2025):
  - Connection-state reason reporting improvements.
  - Better presence snapshot behavior and reconnection robustness.
  - Android 15 16KB page support.
- Integration note:
  - Keep shared runtime libs (`libaosl.so`/related framework artifacts) in sync when Video + Signaling are used together.

## 3) What this means for PrepSkul now

### Product and UX decisions to keep

- Keep paid enrollment gate before join (already aligned with premium classroom model).
- Prioritize "fast path to first successful class":
  - Tutor create -> publish -> learner discover -> enroll/pay -> join in minimal taps.
- Keep role-specific empty states and guided copy (tutor vs learner).
- Add stronger post-session loops:
  - Summary + parent/admin copies + next-step CTAs + game/revision hooks.
- Improve resilience UX:
  - Audio-only fallback and explicit reconnect states for weak networks.

### Technical priorities (near term)

- Web join/token stability remains a release blocker:
  - API host normalization, CORS hardening, and deterministic token preflight behavior.
- Standardize RTC feature flags by platform:
  - Enable only proven stable features first (screen share audio, fallback modes, reconnect policies).
- Improve observability:
  - Track first-frame time, join success, reconnect count, freeze ratio, and paid-user join success.
- Keep compatibility hygiene:
  - Pin tested SDK versions and document upgrade playbook before moving major versions.

## 4) Implementation checklist mapped to current roadmap

### Sprint 1 blockers

- `sprint-1-web-join-stability`
  - Run 3/3 prejoin token tests on web with paid and unpaid roles.
  - Record status-0/CORS incidence and verify zero regression.
- `group-19-uat-matrix`
  - Execute 1:1, 1:3, 1:5 flows with evidence for create/enroll/pay/join.

### Sprint 2 conversion and trust

- `sprint-2-admin-approval-workflow` + `sprint-2-admin-request-interface`
  - Admin review UX should clearly show flyer, learning outcomes, schedule, tutor credibility.
- `sprint-2-flyer-upload-fallback`
  - Ensure fallback image parity on list and detail surfaces across web/mobile.
- `sprint-2-summary-admin-delivery` + `sprint-2-admin-email-notifications`
  - Ship recipient-matrix summaries with delivery telemetry and retries.

### Sprint 3 engagement and discovery

- `sprint-3-discovery-and-targeting`
  - Relevance-based feed plus rich detail page (`sprint-3-group-session-detail-page`).
- `sprint-3-notification-orchestration` + `sprint-3-reminder-cadence`
  - Event-driven reminders with dedupe, opt-out, and conversion tracking.

### Sprint 4 monetization and retention loops

- `sprint-4-finance-split-ledger` + `sprint-4-finance-ops-dashboard`
  - Keep 10% platform fee transparent and reconcilable per enrollment.
- `sprint-4-recording-to-skulmate-loop` + notification tasks
  - Convert session output into repeat engagement loop.

## 5) Suggested PrepSkul QoE KPIs (track weekly)

- Session join success rate (paid learners).
- First remote frame time (P50/P95).
- Reconnect rate per session.
- Mid-session drop rate.
- Support tickets per 100 sessions (AV-related).
- Lesson completion rate and repeat booking rate.
- NPS/CSAT split by role (learner, tutor, parent).

## 6) Source references used for this brief

- Agora case study collection PDF provided by leadership:
  - "Discover Why Brands Trust Agora to Power Their Real-Time Voice and Video Experiences".
- Agora docs home:
  - https://docs.agora.io/en/
- Agora Video Calling release notes hub:
  - https://docs.agora.io/en/video-calling/overview/release-notes
- Agora Video Calling release notes (Flutter):
  - https://docs.agora.io/en/video-calling/overview/release-notes_flutter.md
- Agora Video Calling release notes (Web):
  - https://docs.agora.io/en/video-calling/overview/release-notes_web.md
- Agora Signaling release notes (Flutter):
  - https://docs.agora.io/en/signaling/overview/release-notes_flutter.md
- Agora blog summary on Video SDK v4.5:
  - https://www.agora.io/en/blog/everything-you-need-to-know-about-agora-video-sdk-v4-5/

## 7) Practical next step

Before changing SDK versions, run one controlled "release candidate" pass:

- Freeze current versions.
- Run full UAT matrix (1:1, 1:3, 1:5).
- Capture QoE KPI baseline.
- Upgrade one dependency path at a time (web or flutter first), then rerun the same matrix.

This keeps technical progress aligned with business outcomes (join success, retention, and revenue reliability).
