# Higgsfield assessment for Mate — 26 October 2026

Decision: suitable for an optional visual-content pilot, not yet a replacement for live Mate speech or interactive teaching. No provider installation, media submission, cloning or production integration was performed.

Reviewed upstream files:
- https://github.com/higgsfield-ai/skills
- https://github.com/higgsfield-ai/skills/blob/main/higgsfield-generate/SKILL.md
- https://github.com/higgsfield-ai/skills/blob/main/higgsfield-soul-id/SKILL.md
- https://github.com/higgsfield-ai/skills/blob/main/higgsfield-video-explainer/SKILL.md

Verified from source: coding-agent skills wrap the Higgsfield CLI. Generation runs as jobs. The explainer pipeline produces separate narration and video blocks and assembles them. Soul trains reusable visual identities from reference photographs. The reviewed files do not establish a live streaming teaching interface, guaranteed generation latency, or an end-to-end voice-cloning API. MIT licensing of the skills does not make hosted inference free or establish permission to embed/resell all service capabilities.

Proposed learning experience:
1. Keep the original 3D Mate and approved voice as defaults. Store language, pace and selected supported voice separately from presenter appearance.
2. Teach with an immediate deterministic board (graphs, number lines, manipulatives, labeled diagrams). Learner actions should change the model immediately.
3. Generate or retrieve a short illustrative scene in the background only when useful. Keep equations and exact labels in the app renderer.
4. Pause at a meaningful point for prediction, then show the outcome, explain a misconception, and ask a fresh transfer question.
5. Review correctness before promoting generated scenes into a reusable curriculum cache. Cache approved assets by concept, class, language, style and voice version for offline use.
6. Add consenting adult tutor presenters only after verifying identity rights and deletion/revocation controls. Do not infer a right to clone someone from a photo or name.

Pilot: Newton's second law. Mate asks the learner to predict how the same push moves an empty versus loaded trolley. A deterministic mass/force slider demonstrates the relationship immediately. A reviewed optional animation provides context. A new quantitative problem tests transfer. No video job blocks answering or progress.

Before production integration:
- Confirm supported server API/authentication, commercial embedding rights and quotas.
- Measure actual time-to-image/video and cost per completed learning segment on the target network.
- Verify selected voices and whether the approved voice can be retained; reference audio is not proof of voice cloning support.
- Benchmark pedagogical correctness and quiz-transfer performance rather than visual polish alone.
- Add job cancellation, bounded retry, budget controls, transcript accessibility and offline fallback.
