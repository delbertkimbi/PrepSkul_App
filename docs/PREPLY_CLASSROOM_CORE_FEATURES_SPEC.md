# PrepSkul classroom — core features vs Preply Help Center

**Purpose:** Turn Preply’s *documented behavior* into **implementable scope** for PrepSkul: tutor + learner first, responsive on **small and large** screens, no scope explosion. Official articles are **product documentation**, not code to scrape.

---

## Canonical references (living sources)

| Doc | URL | PrepSkul use |
|-----|-----|--------------|
| **Tutor — Classroom features** | https://help.preply.com/en/articles/4182374-preply-classroom-features-for-tutors-a-complete-guide | Tools list, layouts, Notes structure intent, Talk time, screen-share layout modes |
| **Student — Classroom guide** | https://help.preply.com/en/articles/4182666-preply-classroom-a-student-s-guide | Lobby semantics, Chat in session, troubleshooting path (More → help), solo screen-share rules |
| **Video walkthrough** | https://youtu.be/Caxh8qVwC2I?si=mK2fxXRBfM3WN_8w | Narrative sanity-check only; UI may drift — verify against current PrepSkul UI |

Design benchmarks may also include your **screenshots** of Preply Classroom (dock, hover states, white menus): match **hierarchy + affordances**, not logos or fonts.

---

## Personas & principles

1. **Tutor:** Needs teaching loop (materials + talk + clarity + quick help). Must not hunt for mute, sharing, or “where is the board.”
2. **Student / learner:** Needs safe join, visible help when connection fails, and chat without leaving the lesson context when possible.
3. **Responsive:** Same **mental model** on phone and desktop; simplify density on small widths (fewer dock icons → overflow / sheets), never “desktop-only product.”
4. **PrepSkul identity:** Keep **PrepSkul deep blue family** (`AppTheme` / `_kSoftDark` / `#141F36` glass lanes). Reduce **uniform flat slabs**: separate **chrome** (header + floating dock + bars) from **workspace** (board/PDF/card — slightly brighter or lifted surfaces). Incremental tokens, not a full rebrand.

---

## Responsive matrix (PrepSkul target)

Preply mixes **tile hover layout** on web with **Camera menu → Change layout** on the dock; we rely on **explicit controls** everywhere (already true for layouts on our header path).

| Viewport | Video + workspace shell | Dock / secondary actions |
|---------|--------------------------|---------------------------|
| **Wide (≥ `_kClassroomDualPaneMinWidth` ~840px)** | **Video-first by default.** The workspace rail appears only after the tutor opens **Teaching tools** (control bar / More); visibility syncs to the learner via Realtime `TEACHING_LANE` so both sides mirror split vs full-width video. Implements **custom** board + materials surfaces (`CollaborativeWhiteboard`, Supabase broadcast — not Agora Interactive Whiteboard SDK). | Prefer **inline** screen share where width allows (`_kControlBarCompactWidth` logic), **tutor-only** unless `AppConfig.enableLearnerScreenShare`. **Tutor:** **Teaching tools** expands the rail on wide viewports; narrow still uses the slide-over sheet. **Learner:** **Lesson workspace** in More opens the same sheet when the rail is closed. |
| **Narrow (&lt; ~840)** | **Video-first lane** (no squeezed “static board”); tutor opens **More → Teaching tools**; learner opens **More → Lesson workspace** (same sheet, role-titled). | Meet-style bottom sheet on small shortest-side / width. Reactions / screen share (tutor default) / connection help / workspace row as above. Horizontal scroll dock if needed. |
| **Touch** | Hit targets sized in control bar builders; avoid hover-only disclosure. | |

**Permission / honesty note (from student guide):** Preply restricts **some** whiteboard use to desktop for learners. PrepSkul should publish a clear **platform matrix** per feature (web vs native vs screen size) in feature PRs so support copy stays accurate.

---

## Core feature backlog (minimal “Preply-aligned” vs PrepSkul)

Only items we treat as **core** for parity with tutor + student articles (not Lesson Activities, Library, full Lesson Insights AI).

| # | Tutor/student expectation (from HC) | PrepSkul today | Next incremental step |
|---|--------------------------------------|----------------|-------------------------|
| 1 | **Before join:** preview AV, pick sources | `agora_prejoin_screen.dart` + device readiness | Optional “connection feels OK” cue (reuse `ConnectionQualityService` wording; no faux packet-loss theatre unless truthful). |
| 2 | **Invite link** before student arrives | Partial | Single **Copy / Share session** when alone (`preply-p0-invite-share`). |
| 3 | **Video layout:** Spotlight / side-by-side (grid) | `VideoLayout`; toggle in-call | Optional **dock submenu** mirror Preply (“Change layout”) that calls same state (reuse existing toggle). |
| 4 | **Info / upcoming lessons context** | Profile bits, timer | Lightweight **session info** sheet/tab (`preply-p1-session-header`). |
| 5 | **Network / connection troubleshooting** | `session_connection_help_sheet.dart`, QoE paths | UX polish + **Contrast** so menu rows readable; mirror student “More → Get help” labels where appropriate (`ux-connection-help-contrast`). |
| 6 | **Report issue flag** bottom area | Mostly via banners/support | Dedicated **flag** affordance (`preply-p1-report-flag`). |
| 7 | **Chat during lesson** (side panel) | Chat largely outside RTC shell | **In-call chat** drawer (`preply-p0-chat`). |
| 8 | **Notes / shared teaching report** | Workspace notes surface in indexed stack | Tighten **labels + tutor/learner visibility** vs Preply semantics (teacher notes vs shown-to-student). |
| 9 | **Vocabulary hooks** | Chat → deck | Preserve; extend only when stable. |
|10 | **Screen share** (+ layout modes: corner / sidebar / floating) | Agora share + tiles | Phase 2: **preset layouts** (`preply-p1-screenshare-layouts`). Phase 1: stable stop/start + banner. |
|11 | **Talk time visible** | QoE emits `talk_time_summary` | Minimal **talk-time chip** for tutor (`preply-p0-talktime-ui`). |
|12 | **Whiteboard** interactive | Workspace realtime + gestures | Stability + responsiveness first; fancier drawing later. |

**Recently shipped (this track — do not regress):**

- **Camera publishing:** **`AppConfig.enableSessionCameraPublishing`** (default **`true`**) — pre-join camera + in-call camera control + join `publishCameraTrack` path (`app_config.dart`, `agora_video_session_screen.dart`, `agora_prejoin_screen.dart`). Set to **`false`** only for a deliberate voice-only fallback (e.g. bad web camera regressions).
- When that flag is **false**, pre-join copy + readiness + Android permission gating stay **microphone-only** honest.
- **Learner screen share (start):** **`AppConfig.enableLearnerScreenShare`** (default **`false`**) — dock / More “Share screen” for **starting** capture is **tutor-biased**; receiving the tutor’s share unchanged. Set **`true`** if product allows learners to present (e.g. homework).
- **Join UX:** initial session state **`joining`** + ignore spurious **`disconnected`** while joining; controls active only in **`connected` / `reconnecting`** so the full dock does not look live before the channel is up.
- **Role copy:** learners never see **Teaching tools** in More; **Lesson workspace** + sheet title **Lesson workspace** vs tutor **Teaching tools**.
- Narrow: **workspace behind More** (labels above) instead of draining half the viewport (`_buildClassroomSplitBody`).
- Dock: **Meet-style overflow** sheet on small widths; **⋮** immediately before Leave (divider + Leave); wide bar extras before ⋮ as in matrix.
- **Active mic** uses **glass / white-transparent** capsule style (Meet-like), not green.
- **Offline / stalled reconnect:** `OfflineDialog` (no-network sheet) opens when connectivity drops or when join/reconnect stays stuck long enough (`agora_video_session_screen.dart` + `ConnectivityService`); dismisses automatically when connectivity is verified again so users are not trapped on OK only.
- **Pre-join lobby:** same dialog when offline mid-lobby, **Join** blocked with a connectivity check (`agora_prejoin_screen.dart`); persistent **orange strip** below the status bar while offline so the lobby is never “silent blank.”
- **In-call:** matching **offline strip** under the overlay header while the device reports no connectivity (`agora_video_session_screen.dart`); lobby and call use shared `ClassroomOfflineBanner` (`widgets/classroom_offline_banner.dart`).

---

## “Pixel perfect” framing

Targets:

- **Contrast & spacing** comparable to references (readable labels, anchored leave control, clear active chunk).
- **Behavior** matches Help Center flows (layouts, troubleshooting entry points, tutor tools discoverability).

Non-goals for this phase:

- Cloning Preply’s white menu chrome if it fights PrepSkul dark theme — instead, **readable** dark sheets + PrepSkul tokens.
- Library, Lesson Activities, full Lesson Insights, multi-board complexity.

---

## Cross-links

- Roadmap narrative: [`PREPLY_PARITY_AND_UX_ROADMAP.md`](PREPLY_PARITY_AND_UX_ROADMAP.md)
- Definition of Done + tests: [`CLASSROOM_PREPLY_DOD.md`](CLASSROOM_PREPLY_DOD.md)

---

## Deferred classroom backlog (explicit)

Tracked intentionally — **no implementation** until core classroom foundations (call shell, dependable workspace sync, materials MVP) are stable:

- **Agora Interactive Whiteboard / Fastboard** — separate product decision (tokens, dependency surface).
- **Post-lesson board replay / multi-board archives** — requires persistence schema + UX.
- **YouTube / Google Doc embeds on the workspace canvas** — depends on stable workspace chrome and honest layout contracts.

---

## Maintenance

When Preply HC updates lesson dates (“Last updated”), diff the two URLs above for **behavior** deltas and adjust this matrix in the same PR that changes UX.
