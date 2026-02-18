# Agora session process (recording → transcript → summary)

End-to-end flow for in-app video sessions: recording, transcription, storage, and what’s missing for summaries.

---

## 1. Overview

| Step | What happens | Where it lives |
|------|----------------|----------------|
| **Start session** | Tutor starts → recording starts | App → Next.js → Agora |
| **During session** | Audio (per participant) recorded in the cloud | Agora Cloud Recording |
| **End session** | Tutor ends → recording stops | App → Next.js → Agora |
| **Files ready** | Agora sends webhook | `POST /api/webhooks/agora/recording` |
| **Transcription** | Per-participant audio → transcript segments | Deepgram → `session_transcripts` |
| **Completion** | All participants done → status `completed` | `session_recordings.transcription_status` |
| **Summary** | VA aggregates transcript, LLM summary, store, notify | `PrepSkul_Web/lib/services/va/va.service.ts` |

---

## 2. App (Flutter)

**Start session (online)**  
- `SessionLifecycleService.startSession(sessionId, isOnline: true)`  
- Updates `individual_sessions`: `status = 'in_progress'`, `tutor_joined_at`, `session_started_at`  
- Creates attendance, starts connection quality monitoring  
- Calls **`AgoraRecordingService.startRecording(sessionId)`**  
  - `POST {apiBase}/agora/recording/start` with `{ sessionId }` and Supabase `Authorization: Bearer <token>`

**End session**  
- `SessionLifecycleService.endSession(sessionId)` (trial-aware dispatcher)  
- If trial: `_endTrialSession` → mark trial completed, stop recording, send completion + feedback reminders to learner/parent  
- If recurring: existing flow (earnings, credits, etc.)  
- Calls **`AgoraRecordingService.stopRecording(sessionId)`**  
  - `POST {apiBase}/agora/recording/stop`  
- Updates duration, earnings, status to `completed`, etc.

Trial sessions use the same recording start/stop pattern and now receive feedback reminders on completion (conversion-focused copy).

---

## 3. Backend (Next.js)

**Recording start** (`POST /api/agora/recording/start`)  
- Validates session and caller is tutor  
- Gets/creates Agora channel name, starts Agora Cloud Recording (e.g. individual mode, audio)  
- Writes **`session_recordings`**: `session_id`, `recording_resource_id`, `recording_sid`, `recording_status`, etc.  
- Updates **`individual_sessions`**: `recording_resource_id`, `recording_sid`, `recording_status`

**Recording stop** (`POST /api/agora/recording/stop`)  
- Stops recording for that `resourceId`/`sid`  
- Updates `session_recordings` and `individual_sessions` recording status

**Webhook** (`POST /api/webhooks/agora/recording`)  
- Event handled: **`recording_file_ready`**  
- Validates payload and idempotency (so the same webhook isn’t processed twice)  
- `WebhookService.processWebhook(payload)` → resolves `sessionId`, list of audio files (per participant) with `fileUrl`, `agoraUid`, optional `participantId`  
- Updates **`session_recordings`**: `recording_status = 'uploaded'`, `transcription_status = 'processing'`, `transcription_started_at`  
- For each audio file:  
  - Skips if **`TranscriptionService.hasTranscription(sessionId, agoraUid)`** (already in `session_transcripts`)  
  - Otherwise **`TranscriptionService.transcribeAndStore({ sessionId, agoraUid, participantId, audioUrl, fileName })`**  
    - Deepgram transcribes from URL  
    - Segments written to **`session_transcripts`**: `session_id`, `participant_id`, `agora_uid`, `start_time`, `end_time`, `text`, `confidence`  
  - Then **CleanupService.deleteAudioFile(...)** (logs to `media_cleanup_logs`; actual delete depends on Agora)  
- After all files are processed, **`CleanupService.cleanupAfterTranscription(sessionId)`**  
  - When every participant has rows in `session_transcripts`, sets **`session_recordings.transcription_status = 'completed'`** and **`transcription_completed_at`**  
  - Triggers **PrepSkul VA** (`va.service.processSession`): idempotent; aggregates transcript, generates summary via OpenRouter, stores to `individual_sessions.session_summary`, sends `session_summary_ready` notifications to tutor/learner/parent (with dedupe). Feature flag: `PREPSKUL_VA_ENABLED` (default true).

---

## 4. Data (Supabase)

- **`individual_sessions`**  
  One row per scheduled session. Holds `recording_resource_id`, `recording_sid`, `recording_status`, `recording_file_url`, and columns for **`transcript_url`** and **`session_summary`**.  
  **`session_summary`** is populated by PrepSkul VA after transcription completes (when enabled).

- **`session_recordings`**  
  One row per session recording: `session_id`, Agora ids, `recording_status`, `audio_file_url` / `video_file_url`, `transcription_status`, `transcription_started_at`, `transcription_completed_at`. No `summary` written here by the webhook.

- **`session_participants`**  
  Maps `session_id` + `agora_uid` to `user_id`, `role`, etc. Used by the webhook to resolve participants and by transcription to attach segments to the right participant.

- **`session_transcripts`**  
  Segment-level transcript: `session_id`, `participant_id`, `agora_uid`, `start_time`, `end_time`, `text`, `confidence`. This is the only “analysis” output today.

- **`media_cleanup_logs`**  
  Audit of cleanup attempts per session/agora_uid/audio_url.

---

## 5. What’s missing for “summaries for each user”

- **Sessions** – Yes. `individual_sessions` (and trial/recurring as needed) are the source of truth for “this session happened.”
- **Transcripts** – Yes. After the webhook runs, you have full segment-level transcript in `session_transcripts` for that session (and you can derive a single combined transcript for the session).
- **Per-user summaries** – Not implemented. The schema has one **`session_summary`** per session (on `individual_sessions`), not per user. So the intended design is likely: one session summary, then show it to tutor, learner, and parent (same content, different delivery if needed).
- **How to add it (Agora-only)**  
  1. After **all** transcriptions for a session are done (e.g. when `transcription_status` is set to `completed` in `cleanupAfterTranscription`), trigger a “post-transcription” job.  
  2. In that job: read all segments from `session_transcripts` for that `session_id`, order by time, concatenate into one transcript (optionally with speaker labels from `agora_uid`/participant).  
  3. Call an LLM (e.g. OpenRouter or your existing skulMate/Ticha stack) with a prompt like “Summarize this tutoring session: …” and get a short summary.  
  4. Write the result to **`individual_sessions.session_summary`** (and optionally to a `session_summaries`-style table if you want to mirror the old Fathom shape).  
  5. Optionally send in-app notifications to tutor, learner, and parent that “Session summary is ready” (same pattern as FathomSummaryService, but triggered from this Agora pipeline).

OpenRouter is not used for Agora today; it’s used for skulMate/Ticha. You can use it for this summary step, or any other LLM provider you prefer.

---

## 6. Post-session flows

- **Trial:** Immediately after trial ends → completion + feedback reminder (~24h). No skulMate challenge.
- **Normal:** After transcription → VA summary → `session_summary_ready` → skulMate challenge available. Feedback reminder ~24h.
- See [POST_SESSION_FLOWS_AND_PROMPTS.md](../skulmate/POST_SESSION_FLOWS_AND_PROMPTS.md) for structured prompts, UI/UX, and PRD-aligned emotions.

---

## 7. One-paragraph summary

Tutor starts the session in the app → Agora recording starts via Next.js; when they end, recording stops. Agora sends `recording_file_ready` to the webhook; the backend transcribes each participant’s audio with Deepgram and stores segments in `session_transcripts`, then marks `session_recordings.transcription_status` as `completed` when everyone is done. PrepSkul VA aggregates the transcript, generates a summary via OpenRouter, writes to `individual_sessions.session_summary`, and sends `session_summary_ready` notifications. Trial sessions skip skulMate challenge; normal sessions get skulMate challenge plus retention feedback.
