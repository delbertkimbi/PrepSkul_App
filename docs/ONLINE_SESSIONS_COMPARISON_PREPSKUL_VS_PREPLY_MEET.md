# Online sessions: PrepSkul vs Preply vs Google Meet

Comparison of **PrepSkul** (Agora in-app + optional Google Meet), **Preply Classroom**, and **Google Meet** for online tutoring, rated out of **10** on UI, UX, functionality, and features.

---

## Summary table (out of 10)

| Criteria        | PrepSkul (Agora) | Preply Classroom | Google Meet |
|-----------------|------------------|------------------|-------------|
| **UI**          | 7.5              | 8.5              | 9           |
| **UX**          | 7                | 8.5              | 8           |
| **Functionality** | 7.5            | 9                | 8.5         |
| **Features**    | 6.5              | 9                | 7.5         |
| **Overall**     | **7.1**          | **8.8**          | **8.3**     |

---

## 1. UI (User Interface)

### PrepSkul (Agora) — **7.5/10**
- **Strengths:** Full-screen video, clear main/PIP layout, profile cards when camera off, minimal status bar, bottom control bar (mute, camera, screen share, reactions, leave). Session timer visible. Consistent with app theme (PrepSkul branding).
- **Gaps:** No layout switcher (e.g. grid/side-by-side). Pre-join is functional but not as polished as Preply’s “preview + check if student is there”. No in-call connection-quality indicator in the UI (only in logs/backend).

### Preply Classroom — **8.5/10**
- **Strengths:** Flexible video layouts (hover on tile to change), tool mode for mobile, whiteboard and tools integrated in one view. Clean, education-focused layout. Connection test UI (packet loss, bitrate) before lesson.
- **Gaps:** Still a web-first product; mobile app is good but not always as smooth as native.

### Google Meet — **9/10**
- **Strengths:** Very polished, familiar UI; multiple layouts (tile, sidebar, spotlight); captions, reactions, hand raise; works everywhere (web, mobile, desktop). Accessibility and density options.
- **Gaps:** Generic (not tutoring-specific). No built-in whiteboard or lesson tools; no session timer or lesson context.

---

## 2. UX (User Experience)

### PrepSkul — **7/10**
- **Strengths:** Single app flow: session detail → pre-join (permissions, camera/mic toggles) → in-call. Timer and “end of class” message. Reactions (emoji) and screen sharing. Backend recording (Agora Cloud) and connection-quality monitoring. No need to leave the app for video.
- **Gaps:** No pre-lesson “connection test” step (e.g. packet loss / bitrate) like Preply. No in-call whiteboard or shared lesson materials. Hybrid dialog mentions “chat and whiteboard” but whiteboard not implemented in-app. If Meet link is used instead of Agora, UX splits (open browser/app).

### Preply — **8.5/10**
- **Strengths:** Pre-lesson device check (camera, mic, preview, “is student there?”). Connection test with clear targets (e.g. 0–2% packet loss, min bitrate). Lesson activities and course topics in the same interface. Whiteboard and tools in one place. Consistent flow for tutor and student.
- **Gaps:** Depends on Preply’s stack; less control for your own product.

### Google Meet — **8/10**
- **Strengths:** Very smooth joining and in-call experience; low friction; works in any browser/app. Recording, captions, breakout rooms for group use.
- **Gaps:** No tutoring-specific flow (no timer, no lesson plan, no whiteboard). If you use Meet for PrepSkul, users leave your app and lose a single “lesson room” feel.

---

## 3. Functionality

### PrepSkul — **7.5/10**
- **Strengths:** Agora: 1:1 video, mute/camera, screen share, emoji reactions, adaptive quality (1080p → 720p → 480p), remote network-quality tracking, session timer with auto-end, profile cards when camera off, backend recording (Agora Cloud). Optional Meet link for fallback. Connection quality service (good/fair/poor) and monitoring.
- **Gaps:** No in-app whiteboard or shared doc. No explicit “connection test” before join. Recording is server-side only (no in-UI “record” button for user). Screen share and reactions work but are simpler than Preply’s teaching toolkit.

### Preply — **9/10**
- **Strengths:** Video + whiteboard + screen share + lesson activities + course topics in one product. Multiple boards, drawing tools, text, uploads, undo/redo. Connection test before lesson. Layout options. Tool mode for mobile. Classroom links to invite. Strong “all-in-one lesson” functionality.
- **Gaps:** Tied to Preply; no self-host or deep customization.

### Google Meet — **8.5/10**
- **Strengths:** Very reliable video/audio, screen share, captions, recording, reactions, hand raise, breakout rooms. Works at scale and across devices.
- **Gaps:** No whiteboard, no lesson/curriculum tools, no session timer. You’d add those in your own app (e.g. PrepSkul) around the Meet link.

---

## 4. Features

### PrepSkul — **6.5/10**
- **Present:** In-app video (Agora), pre-join (permissions + camera/mic), mute/camera/screen share, emoji reactions, session timer, auto-end, profile cards, Agora Cloud Recording, connection quality monitoring, optional Meet link.
- **Missing vs Preply:** No in-app whiteboard, no shared lesson materials/activities, no pre-lesson connection test UI, no multiple video layouts, no “tool mode” for mobile. Whiteboard/chat mentioned in hybrid dialog but not built for video.

### Preply — **9/10**
- **Present:** Video, multiple layouts, interactive whiteboard (multiple boards, drawing, shapes, text, laser, uploads, save by lesson), screen share, lesson activities and course topics, connection test, device preview, classroom links, tool mode for app. Strong feature set for teaching.
- **Missing:** Nothing critical for standard 1:1 tutoring; more advanced (e.g. multi-student layouts) could be better.

### Google Meet — **7.5/10**
- **Present:** Video, layouts, captions, recording, reactions, hand raise, screen share, breakout rooms, integration with Calendar/Drive.
- **Missing:** No whiteboard, no lesson/education-specific features; it’s a general-purpose meeting product.

---

## Where PrepSkul wins

- **Single app:** Video lives inside PrepSkul (Agora); no mandatory switch to browser/Meet.
- **Session context:** Timer, “end of class” message, and session lifecycle (start/end, payments) are integrated.
- **Technical control:** Adaptive bitrate, quality monitoring, and Agora recording are under your control.
- **Reactions and screen share:** Enough for basic engagement without leaving the app.

---

## Where PrepSkul should improve to match Preply

1. **Pre-lesson connection test** — A simple step (e.g. “Test your connection”) with packet loss / bitrate or a clear “Good / Fair / Poor” so users fix issues before the lesson.
2. **In-app whiteboard** — Even a simple shared drawing/annotation layer would close the biggest feature gap vs Preply.
3. **Layout options** — At least two layouts (e.g. “large remote” vs “side by side”) to match Preply/Meet.
4. **Connection quality in UI** — Show “Connection: Good/Fair/Poor” or an icon in the status bar using existing ConnectionQualityService.
5. **Lesson materials** — Optional “lesson plan” or “materials” tab in the session (links or simple content) so the lesson feels structured like Preply Classroom.

---

## Conclusion

- **PrepSkul (Agora)** is solid for 1:1 video (UI, UX, functionality around **7–7.5**), with the main advantage of keeping everything in-app and session-aware. It loses points on **features** (**6.5**) because of no whiteboard, no connection test UI, and simpler layouts.
- **Preply Classroom** scores highest (**~8.8**) by combining video, whiteboard, lesson tools, and connection test in one education-focused product.
- **Google Meet** is the strongest **generic** option (**~8.3**) for pure video/audio and reliability but lacks tutoring-specific features; using it as a fallback in PrepSkul is reasonable.

Focusing on **connection test UI**, **in-call quality indicator**, **layout options**, and (medium-term) an **in-app whiteboard** would bring PrepSkul’s scores and perceived quality close to Preply’s for online tutoring.
