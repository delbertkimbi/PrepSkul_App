# Preply Classroom parity — reference sources, PrepSkul status, UX roadmap

This document distills **official Preply Help Center** guidance (not scraped proprietary code—product behavior and UX patterns only) and maps them to **PrepSkul’s current classroom stack**. Use it to prioritize work without scope creep.

## Primary references (canonical)

| Audience | Article | Purpose |
|----------|---------|---------|
| Tutors | [Preply Classroom features — complete guide](https://help.preply.com/en/articles/4182374-preply-classroom-features-for-tutors-a-complete-guide) | Layouts, tools, chat/notes/vocab, screen share, talk time, lesson activities |
| Students | [Preply Classroom — student’s guide](https://help.preply.com/en/articles/4182666-preply-classroom-a-student-s-guide) | Lobby, join flows, chat, screen share rules, troubleshooting / fallback |
| Video | [YouTube walkthrough](https://youtu.be/Caxh8qVwC2I?si=mK2fxXRBfM3WN_8w) | Supplementary narrative (verify timestamps against current product) |

**Visual references:** Your uploaded Classroom screenshots (layouts, bottom bar, Tools menu, waiting room, screen-share banner) are valid **design benchmarks**; PrepSkul should converge on **behavior + hierarchy**, not pixel-clone Preply’s branding.

---

## What PrepSkul already covers (high level)

Aligned with our implementation and `docs/CLASSROOM_PREPLY_DOD.md`:

- **Video layouts:** Spotlight, side-by-side, gallery (`VideoLayout` in `agora_video_session_screen.dart`); layout toggle in header region.
- **Pre-join / readiness:** Device probe + checklist (`agora_prejoin_screen.dart`).
- **Collaborative workspace:** Whiteboard + PDF/notes scaffold + Realtime packets (`workspace_sync_state.dart`, `ClassroomWorkspaceIndexedStack`).
- **Tutor-led scroll sync:** `SCROLL_TO` for PDF/notes surfaces (tutor publishes; learner follows).
- **Screen sharing:** Agora path + web PiP / source conflicts addressed; recovery when streams unhealthy.
- **Chat → vocabulary:** Long-press / deck hook from messaging layer.
- **Talk time (analytics):** QoE emission (`talk_time_summary`) — see gap below for **visible UI**.
- **Connection help & recovery:** Connection sheet + recovery banner + optional backup URL + WhatsApp support.
- **Audio tuning:** Tutoring audio profiles + optional audio-only fallback if camera never encodes.

---

## Gaps vs Preply (core-first)

Prioritized for **tutor + learner** outcomes, not feature count.

### P0 — Teaching loop & trust

| Preply pattern | PrepSkul gap | Direction |
|----------------|--------------|-----------|
| **Chat in-session** as a first-class panel | Chat is largely outside the call shell | Add **in-call chat sheet/drawer** (reuse `ChatScreen` or thin adapter) without blocking video. |
| **Talk time visible** to participants | Telemetry exists; UI does not surface stats | **Tutor-facing** strip or post-lesson summary chip; optional learner view (policy). |
| **“Waiting for …” + share link** clarity | Partially covered by session UX | Align copy/actions with student guide: **single obvious “invite / share”** when alone (deep link or copy session URL). |

### P1 — Classroom polish & parity

| Preply pattern | PrepSkul gap | Direction |
|----------------|--------------|-----------|
| **Tools rail** labels (Whiteboard, Notes, …) | We have surfaces but not Preply’s full IA | Keep **core trio**: Board / PDF / Notes; defer Library / Lesson Activities until product owns content. |
| **Screen share layouts** (corner / sidebar / floating) | Mostly single-stage + tiles | Introduce **presenter layout presets** (even if v1 is only “tiles top-right vs sidebar”). |
| **Report an issue** (flag) | Support via recovery banner | Add **non-blocking flag** control that routes to same support path + optional QoE payload. |
| **Info / student context panel** | Profile fragments exist | Lightweight **session header**: student name, lesson time, link to “connection” / notes. |

### P2 — Visual system (your note on deep blue)

- **Issue:** Flat `#0F1A2E`-style surfaces everywhere read heavy; Preply uses **dark chrome + light workspace** contrast.
- **Direction (incremental):** Introduce **two tiers** — `chrome` (header/control dock) vs `workspace` (slightly lifted `#141F36` / card surfaces already partially used as `_kGlassFill`). **Do not** blow up the palette; evolve tokens in `AppTheme` / session constants.

### Responsive strategy (not “desktop only”)

| Breakpoint intent | Behavior |
|-------------------|----------|
| **Wide (≥ ~840px)** | **Dual-pane**: video lane + workspace (`_kClassroomDualPaneMinWidth`). |
| **Narrow (&lt; ~840px)** | **Video-first lane** (full teaching stage for video/UI); collaborative workspace opens from **More → Teaching tools** (Meet-style overflow + sheet), not a permanent half-screen “empty board”. Control bar stays reachable (horizontal scroll + compact overflow). See core spec § matrix. |
| **Touch** | Larger hit targets on mic / share / Leave; avoid hover-only disclosure (Preply uses hover on tile—we use explicit layout / menu paths). |

**Core spec:** [`PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md`](PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md) maps Help Center items → files and responsive behavior.

Implementation order (unchanged): **(1)** shell + safe padding, **(2)** in-call chat sheet, **(3)** talk-time chip (+ invite link when alone).

---

## Out of scope (for now)

- Full **Lesson Activities** timeline with timed phases (Preply product)—requires content + backend ownership.
- **Lesson Insights / AI summaries**—separate VA product track.
- **Full Library** catalog—depends on content licensing; our PDF/workspace path is the teaching substrate.

---

## Cross-links

- **Help Center → actionable matrix:** [`PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md`](PREPLY_CLASSROOM_CORE_FEATURES_SPEC.md)
- Engineering DoD + CI bundle: `docs/CLASSROOM_PREPLY_DOD.md`
- Teaching architecture: state-sync workspace before pixel-only screen share (same doc, roadmap section)

---

## Review cadence

Re-read tutor + student guides when adding **new** classroom surfaces so copy and permissions stay honest (e.g. whiteboard desktop-only on Preply—document our platform matrix in each feature PR).
