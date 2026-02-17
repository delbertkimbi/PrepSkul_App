# Video test run (online sessions)

**Prereqs:** Agora app ID + token API configured. Run app: `flutter run`

---

## 1. Book online session (as student)

1. Sign in as student.
2. Book a session → choose **Online**.
3. ✅ Session appears with Meet link or "Join Meeting".

## 2. Pre-join (AgoraPreJoinScreen)

1. Tutor or student taps **Join Meeting** (or equivalent).
2. ✅ Pre-join screen shows.
3. Grant camera + mic.
4. ✅ Local preview visible (camera on).
5. Toggle camera off/on, mic off/on → ✅ state updates.
6. Tap **Join**.

## 3. In-call (AgoraVideoSessionScreen)

1. ✅ Local video shows (if enabled).
2. Second user joins (another device or simulator).
3. ✅ Remote video shows.
4. Toggle mute → ✅ audio stops for remote.
5. Toggle video → ✅ camera off/on for remote.
6. ✅ Session timer runs.

## 4. End call

1. Tutor or student taps **End call**.
2. ✅ Leaves channel; returns to session detail or list.
3. ✅ Session status = completed.

## 5. Session lifecycle

1. Tutor joins first → ✅ SessionLifecycleService.startSession called.
2. End call → ✅ endSession called; duration recorded.

---

**Pass:** Video connects, both see each other, end updates session. **Fail:** Note step and error.
