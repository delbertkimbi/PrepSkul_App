# Video Session UI Structure

How the Agora video session screen is laid out in different scenarios, for **web** and **mobile**. The same Flutter code runs on both; layout adapts to **screen size and orientation**, not platform.

---

## 1. Global structure (all states)

The screen is always:

```
┌─────────────────────────────────────────────────────────┐
│  SafeArea                                                │
│  ┌─────────────────────────────────────────────────────┐│
│  │  MAIN VIDEO AREA (full size)                        ││
│  │  - Content depends on: alone / with peer / sharing  ││
│  │  - Can be: 1 big view, or 2 panels (side-by-side)   ││
│  ├─────────────────────────────────────────────────────┤│
│  │  [Optional] Local PIP (spotlight only, when with    ││
│  │             peer + camera on) – draggable overlay    ││
│  ├─────────────────────────────────────────────────────┤│
│  │  [Optional] Profile cards overlay (only when        ││
│  │             spotlight + remote left)                ││
│  ├─────────────────────────────────────────────────────┤│
│  │  State messages, reactions, status bar, control bar ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

- **Main video area**: One widget that switches content by state (see below).
- **Layout mode**: Either **spotlight** (one main + optional PIP) or **side-by-side** (two equal panels). User can toggle with the grid icon in the status bar **only when a remote user is in the call**.
- **Web vs mobile**: Same structure. Only difference is actual pixel size and, in side-by-side, **orientation** (portrait → panels stacked top/bottom; landscape → left/right).

---

## 2. When you are **alone** (just joined or peer left)

**Who sees this:** Tutor or learner, after joining, before the other joins — or after the other has left.

**Layout:** Always **spotlight** (side-by-side is hidden when there is no remote user).

| What you see | Description |
|--------------|-------------|
| **Main area** | **You only.** If camera on → your video (full screen). If camera off → your profile card (avatar + name) on soft dark background. |
| **PIP** | **Not shown** (PIP only appears when `_remoteUID != null` and not left). |
| **Status bar** | Timer (if session has time), connection quality, layout toggle **hidden** (no remote). |
| **Control bar** | Mic, camera, reactions, share screen, leave. |

**Web / mobile:** Same. One full-screen region showing either your video or your profile.

---

## 3. When you are **with the tutor** (1:1, no screen share)

**Who sees this:** Both tutor and learner, once both are in the call and nobody is sharing screen.

**Layout:** Default **spotlight**. User can switch to **side-by-side** via the grid icon in the status bar.

### 3a. Spotlight mode (default)

| What you see | Description |
|--------------|-------------|
| **Main area** | **Remote only** (tutor sees learner, learner sees tutor). If remote camera off or “screen off” detected → remote **profile card** instead of video. |
| **PIP** | **Your** local video (small, draggable, e.g. 160×120), only if **your camera is on**. Position: bottom-right by default, above control bar. Same on web and mobile. |
| **Overlay** | If remote left while in spotlight: both profile cards (yours + remote) can show in overlay. |

So: **main = other person**, **PIP = you** (when camera on).

### 3b. Side-by-side mode (after tapping grid)

| Screen | Layout |
|--------|--------|
| **Portrait** (height > width) | **Column:** top = remote, bottom = you. |
| **Landscape** (width ≥ height) | **Row:** left = remote, right = you. |

- **Remote panel:** Remote video, or remote profile card if they have camera off / screen off.
- **Local panel:** Your video if camera on, else your profile card.
- **PIP:** **Not shown** in side-by-side; your feed is in the local panel.

**Web:** Resize the browser to portrait/landscape to get the same Column/Row behavior.  
**Mobile:** Rotate device for portrait (top/bottom) vs landscape (left/right).

---

## 4. When **someone is sharing their screen**

**Who sees this:** Both participants. Either **you** are sharing or **the other** is.

**Layout:** **Spotlight only.** When `_isScreenSharing || _remoteIsScreenSharing` is true, the main area shows **only the screen-share stream** (full screen). There is no side-by-side grid option that shows screen share in one panel and camera in the other in the current implementation.

### 4a. You are sharing your screen

| Who | Main area | PIP / extra |
|-----|-----------|-------------|
| **You (sharer)** | Your **screen share** (full screen). | PIP **not** shown (screen-share takes over; your camera could be off or secondary depending on product). |
| **Other (tutor or learner)** | Your **screen share** (full screen). | Same single full-screen view. |

So both see one full-screen region: the shared screen.

### 4b. Other is sharing their screen

| Who | Main area | PIP / extra |
|-----|-----------|-------------|
| **You** | **Their** screen share (full screen). | If your camera is on and layout stayed spotlight, PIP logic would still try to show your camera PIP — but in the current code, when **any** screen share is active, main area is **only** the screen-share stream and PIP is still shown only when `_remoteUID != null` and not left and **not** when you’re in the “screen share full screen” branch. So effectively: main = their screen, and your PIP can still show you. |
| **Them (sharer)** | Their own **screen share** (full screen). | Same as 4a. |

**If sharer leaves:** Main area falls back to waiting placeholder (“Waiting for Tutor/Learner…”); no more screen share.

**Web / mobile:** Same: one full-screen screen-share view when sharing is active; no grid layout for screen share.

---

## 5. Summary table (what each entity sees)

| Scenario | You (tutor or learner) | Other (tutor or learner) |
|----------|------------------------|---------------------------|
| **Alone** | Main = you (video or profile). No PIP. | N/A |
| **With peer, spotlight** | Main = remote. PIP = you (if camera on). | Main = you. PIP = them (if camera on). |
| **With peer, side-by-side** | Two panels: remote | you (portrait: top/bottom; landscape: left/right). No PIP. | Same. |
| **You sharing screen** | Main = your screen share (full). | Main = your screen share (full). |
| **They sharing screen** | Main = their screen share (full). Optional PIP = you. | Main = their screen share (full). Optional PIP = them. |

---

## 6. Web vs mobile (implementation)

- **Same UI code** for web and mobile: one `AgoraVideoSessionScreen` and one layout state machine.
- **Responsive behavior** is only:
  - **Side-by-side:** `MediaQuery.size`: portrait → `Column`, landscape → `Row`. Works for both a phone and a browser window.
  - **PIP:** Width ≤ 400 → 160×120; wider screens → 200×150. Draggable; same logic on web and mobile.
- **No separate “web layout” vs “mobile layout”** (e.g. no `kIsWeb` branch that changes grid or screen-share layout). So **grids and screen-share structure are the same** on web and mobile; only size/orientation change the look.

---

## 7. Responsive behavior (web vs mobile)

- **PIP size:** On narrow screens (width ≤ 400) the local PIP is 160×120; on wider screens (e.g. web/tablet) it is 200×150 for better visibility. Same logic on web and mobile.
- **Side-by-side:** Portrait uses a vertical split (top/bottom), landscape uses horizontal (left/right). No different grid or layout for web vs mobile.

## 8. Possible improvements (for discussion)

- **Screen share + camera:** Option to show screen share in one panel and camera in another (e.g. side-by-side while sharing), instead of full-screen only.
- **Web:** Different default or max PIP size on large screens.
- **Mobile:** In portrait, consider a different default for “who is main” (e.g. self big, remote small) for readability.

If you want, we can next change the actual code (e.g. add a “screen share + side-by-side” mode or adjust PIP size for web).
