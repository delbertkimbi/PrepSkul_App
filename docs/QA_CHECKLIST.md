# PrepSkul QA Checklist

**Purpose:** Ensure seamless onsite sessions, Leaflet maps, and (later) video.  
**Use:** Run through the relevant section before release or when verifying a feature.

---

## 1. Onsite session flow

### 1.1 Booking & address

- [ ] **Book onsite session**
  - [ ] Parent/student can select “Onsite” when tutor offers it.
  - [ ] Address is required; validation blocks submit when empty.
  - [ ] Location description (landmarks, gate code) is optional and saved.
  - [ ] Hybrid: user can choose online or onsite per slot; address required for onsite slots.
- [ ] **Address sources**
  - [ ] Survey address pre-fills when user has completed onboarding survey.
  - [ ] User can edit address; map picker (if used) updates coordinates.
  - [ ] Stored as `onsite_address` / `address` and shown on session details.

### 1.2 Session details (pre-session)

- [ ] **Onsite session shows**
  - [ ] Session type “Onsite” (or “In person”) clearly indicated.
  - [ ] Full address and optional location description.
  - [ ] **Session location map** (Leaflet/flutter_map):
    - [ ] Map loads (no blank or crash).
    - [ ] Marker at session location; popup shows address.
    - [ ] Distance from “you” when location permission granted.
  - [ ] **Actions:** “View Map”, “Directions” open external maps (e.g. Google Maps) correctly.
- [ ] **Tutor view**
  - [ ] Tutor sees same address and map on their session detail / “Start session” screen.
  - [ ] Check-in and Check-out buttons visible for onsite.

### 1.3 Check-in (tutor-centric)

- [ ] **Tutor check-in**
  - [ ] “Check In” triggers location permission if not yet granted.
  - [ ] Proximity check: within ~100 m → “Checked in and verified” (green).
  - [ ] Too far → “Checked in (location not verified)” (orange); message suggests being at the correct address.
  - [ ] Punctuality: early / on time / late shown from scheduled time (e.g. within 5 min = on time).
  - [ ] Check-in time and status persist after refresh.
- [ ] **Student/parent check-in (optional)**
  - [ ] If student/parent has app and taps Check In, same flow works; status stored per user.
  - [ ] No requirement for student to check in (tutor is primary).

### 1.4 During session

- [ ] **Location sharing (parent view)**
  - [ ] For active onsite session, parent can open “location tracking” / map and see tutor (or shared) location when sharing is on.
  - [ ] No blocking popups or “verify location” during session.
- [ ] **Safety (onsite only)**
  - [ ] “Share location” with emergency contact works (if implemented).
  - [ ] “Panic button” shows confirmation; triggers notification/incident (if implemented).

### 1.5 Check-out & completion

- [ ] **Tutor check-out**
  - [ ] “Check Out” available after check-in; records check-out time and duration.
  - [ ] Duration (minutes) shown; session can move to “completed” flow.
- [ ] **Session completion**
  - [ ] Lifecycle: scheduled → in_progress (after start) → completed (after end/check-out).
  - [ ] Onsite-specific: no Meet link; no Fathom; transportation cost (if any) applied correctly.

### 1.6 Edge cases

- [ ] **Location permission denied**
  - [ ] Clear message; check-in still possible but “location not verified”.
- [ ] **No coordinates, address only**
  - [ ] Geocoding used for map and proximity; map shows marker or “Map preview unavailable” with “View Map” fallback.
- [ ] **Offline**
  - [ ] Session list/detail from cache if implemented; check-in may fail with clear message.

---

## 2. Leaflet / maps

### 2.1 In-app map (EmbeddedMapWidget)

- [ ] **Mobile (flutter_map / OSM)**
  - [ ] Map loads with OSM tiles (no API key).
  - [ ] Session location marker visible; tap/ popup shows address.
  - [ ] No crash when coordinates missing: geocoding runs or “Map preview unavailable” shown.
- [ ] **Web (Leaflet iframe)**
  - [ ] Leaflet map loads in iframe; tile layer (e.g. OSM DE) visible.
  - [ ] Marker at session location; popup shows address (sanitized, no XSS).
  - [ ] When “current location” is passed (e.g. from SessionLocationMap), routing iframe shows route from current → session (OSRM/Leaflet Routing Machine).
  - [ ] If coordinates invalid or missing, map uses safe default center (e.g. region) or shows placeholder; no blank/white map or JS error. (Web: default center 4.05, 9.77 used when coords missing.)

### 2.2 External maps

- [ ] **“View Map”**
  - [ ] Opens session location in external maps app (e.g. Google Maps search) with coordinates or address.
- [ ] **“Directions”**
  - [ ] Opens turn-by-turn directions to session location (e.g. Google Maps directions).

### 2.3 Consistency with MAP_LEAFLET_AND_TRANSPORT

- [ ] In-app map uses Leaflet/OSM (no Google Maps API key).
- [ ] Routing (in-app) uses OSRM-compatible flow (e.g. Leaflet Routing Machine) where implemented.
- [ ] Future: tutor transport cost (home → onsite) can use same OSM/Leaflet routing data.

---

## 3. Video experience (online sessions)

*Use when focusing on online flow. Agora = in-app video; Meet = fallback/link.*

### 3.1 Pre-join (AgoraPreJoinScreen)

- [ ] **Permissions**
  - [ ] Camera permission requested; grant/deny handled.
  - [ ] Mic permission requested; grant/deny handled.
- [ ] **Device selection**
  - [ ] Camera (front/back) selector works.
  - [ ] Mic selector works (if shown).
- [ ] **Preview**
  - [ ] Local video preview shows before join (when camera on).
  - [ ] Toggle camera/mic in pre-join reflects in call.
- [ ] **Join**
  - [ ] "Join" opens AgoraVideoSessionScreen (or Meet link if configured).
  - [ ] No crash on join; channel connects.

### 3.2 In-call (AgoraVideoSessionScreen)

- [ ] **Video**
  - [ ] Local video visible when enabled.
  - [ ] Remote video visible when other user joins.
  - [ ] Toggle video (camera on/off) works.
- [ ] **Audio**
  - [ ] Mute/unmute works.
  - [ ] Audio heard from remote user.
- [ ] **UI**
  - [ ] Session timer visible.
  - [ ] End call button works.
- [ ] **End call**
  - [ ] End call → leaves channel → SessionLifecycleService.endSession called.
  - [ ] Session status → completed; end time recorded.

### 3.3 Recording (if Agora Cloud Recording enabled)

- [ ] Recording starts when tutor starts session.
- [ ] No unintended exposure (e.g. pre-join not recorded).
- [ ] Recording stops when session ends.

### 3.4 Fathom / Meet (if used)

- [ ] Meet link opens in browser/app.
- [ ] Fathom joins as attendee (if configured).
- [ ] Post-session: transcript/summary where configured.

---

## 4. Quick smoke (post-deploy)

- [ ] Open app from **tutor share link** → after auth, land on tutor profile (no “Loading tutor…” flash).
- [ ] Create **onsite booking** → session appears with address and map.
- [ ] **Tutor**: start onsite session → check in → check out → session completes.
- [ ] **Map**: session detail with address shows embedded map (mobile + web) and “View Map” / “Directions” work.

---

## References

- `ONSITE_SESSION_TRACKING_IMPROVEMENTS_PLAN.md` – continuous monitoring, selfie, phases.
- `SESSION_TRACKING_AND_ANTI_CHEATING_ANALYSIS.md` – gaps and current state.
- `MAP_LEAFLET_AND_TRANSPORT.md` – Leaflet/OSM choice, future transport cost.
