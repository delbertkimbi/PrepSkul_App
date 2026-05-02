# Onsite test run (5–10 min)

**Run the app:** `cd prepskul_app && flutter run` (or your usual command)

---

## 1. Book onsite session (as student/parent)

1. Sign in as student or parent.
2. Find a tutor who offers onsite.
3. Book a session → choose **Onsite** → enter address → complete.
4. ✅ Session appears in Upcoming with address and map.

## 2. Start onsite session (as tutor)

1. Sign in as tutor.
2. Open the session from list or calendar.
3. Tap **Start Session**.
4. ✅ Session starts; no crash.
5. ✅ One-line banner: *"Keep app in background — it helps document your session..."* (dismissible).

## 3. Check-in

1. On session detail, tap **Check In**.
2. Grant location if prompted.
3. ✅ Shows "Checked in and verified" (green) or "Checked in (location not verified)" (orange).
4. ✅ Punctuality: early / on time / late.
5. ✅ Hint appears: *"Add a photo of you and the learner(s) for your records"*.
6. Tap hint → camera opens → take/select photo → upload.
7. ✅ Hint disappears after upload.

## 4. Map & directions

1. ✅ Map loads (Leaflet/flutter_map).
2. Tap **View Map** → opens external maps.
3. Tap **Directions** → opens turn-by-turn.

## 5. Check-out

1. Tap **Check Out**.
2. ✅ Duration shown; session completes.

## 6. Trial onsite (optional)

1. Book trial onsite as student.
2. Tutor approves.
3. Tutor starts trial from sessions list.
4. ✅ Same flow: check-in, map, check-out.

---

**Pass:** All steps complete without crash. **Fail:** Note step and error.
