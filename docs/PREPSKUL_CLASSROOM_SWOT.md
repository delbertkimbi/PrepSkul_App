# PrepSkul Classroom SWOT Analysis

Date: 2026-04-19  
Scope: Live classroom product evolution (Flutter + Agora + Supabase + Next.js)

## Strengths

- Existing live call path is already functional (join, preview, publish, basic screenshare).
- Current platform stack is suitable for classroom scale:
  - Flutter for mobile-first velocity.
  - Agora for real-time media.
  - Supabase for auth/data/policies.
  - Next.js API layer for token and orchestration endpoints.
- Engineering already has in-product telemetry/logging patterns to build on.
- `session_participants` foundation enables scalable participant authorization.

## Weaknesses

- Core session UI still behaves like a 1:1 call experience.
- RTC event handling is too close to widget state, producing flicker under instability.
- Network adaptation logic exists in fragments, not as a single policy engine.
- Reconnection and degraded-network UX states are not consistently represented.
- Classroom pedagogy tools are early/basic compared to mature competitors.

## Opportunities

- Build a classroom system optimized for real-world weak networks in African regions.
- Differentiate on tutor workflow and learning outcomes, not only call quality.
- Use QoE telemetry to iterate faster than competitors.
- Introduce lightweight classroom features with high impact:
  - active speaker spotlight,
  - hand raise,
  - resilient stage/share behavior.
- Convert multi-learner booking demand into actual multi-participant live sessions.

## Threats

- If quality remains unstable, trust drops quickly and retention suffers.
- Group sessions amplify all instability and UX flaws versus 1:1.
- Competing products already set high user expectations for smooth reconnect behavior.
- Bandwidth costs and device diversity can degrade performance if policies are not adaptive.

## Strategic Interpretation

- PrepSkul is close to a strong classroom product but is currently at risk of being perceived as a raw call interface.
- The biggest near-term leverage is architectural control of state transitions and quality adaptation.
- The biggest medium-term leverage is tutor-first classroom UX that improves teaching outcomes.

## Strategic Priorities

1. Stabilize session orchestration and UI state projection.
2. Add adaptive media policy with dual-stream control and hysteresis.
3. Expand classroom UX with clear session states and teaching controls.
4. Instrument QoE deeply, then optimize based on data.

## SWOT-Driven Action Summary

- Use strengths to ship fast: leverage existing Agora integration and API stack.
- Fix weaknesses at architecture level before feature expansion.
- Capture opportunities through region-aware resilience and pedagogy-focused UX.
- Reduce threats with strict quality gates and reconnection UX polish before broad rollout.

