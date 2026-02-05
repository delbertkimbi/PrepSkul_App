# Agora Recording Transcription Pipeline

This document describes the implementation of the Agora Cloud Recording transcription pipeline for PrepSkul video sessions.

## Overview

The pipeline records audio-only sessions using Agora Cloud Recording in Individual Mode, transcribes each participant's audio separately using OpenAI Whisper API, stores timestamped transcripts in Supabase, and automatically deletes raw audio files after successful transcription.

## Architecture

```
Flutter App → Start Session
    ↓
Next.js Backend → Acquire Resource → Start Recording (Individual Mode, Audio Only)
    ↓
Agora Cloud Recording → Session Ends → Upload Audio Files
    ↓
Agora Webhook → Next.js Backend
    ↓
Extract Audio URLs & UIDs → Enqueue Transcription Jobs
    ↓
Download Audio → Transcribe with Whisper API → Store Transcripts in Supabase
    ↓
Delete Audio Files → Log Cleanup
```

## Database Schema

### New Tables

1. **session_participants** - Maps Agora UIDs to session participants
2. **session_transcripts** - Stores timestamped transcript segments
3. **media_cleanup_logs** - Audit log for audio file deletions

### Updated Tables

- **session_recordings** - Added `transcription_status`, `transcription_started_at`, `transcription_completed_at`

See migration file: `supabase/migrations/058_add_agora_transcription_tables.sql`

## File Structure

```
PrepSkul_Web/
├── app/
│   ├── api/
│   │   ├── agora/
│   │   │   └── recording/
│   │   │       ├── start/route.ts
│   │   │       └── stop/route.ts
│   │   ├── webhooks/
│   │   │   └── agora/
│   │   │       └── recording/route.ts
│   │   ├── transcription/
│   │   │   └── process/route.ts
│   │   └── cleanup/
│   │       └── audio/route.ts
│   └── lib/
│       └── services/
│           ├── agora/
│           │   ├── agora.client.ts
│           │   ├── recording.service.ts
│           │   └── webhook.service.ts
│           ├── transcription/
│           │   ├── whisper.client.ts
│           │   └── transcription.service.ts
│           └── cleanup/
│               └── cleanup.service.ts
```

## Environment Variables

Add these to your `.env.local` file:

```env
# Agora Cloud Recording
AGORA_CUSTOMER_ID=your_customer_id
AGORA_CUSTOMER_SECRET=your_customer_secret
AGORA_APP_ID=your_app_id

# OpenAI Whisper API
OPENAI_API_KEY=sk-...

# Supabase (should already exist)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
```

## API Endpoints

### Start Recording
```
POST /api/agora/recording/start
Authorization: Bearer <supabase_token>
Body: { sessionId: string }
```

### Stop Recording
```
POST /api/agora/recording/stop
Authorization: Bearer <supabase_token>
Body: { sessionId: string }
```

### Webhook (Agora → Backend)
```
POST /api/webhooks/agora/recording
Body: <Agora webhook payload>
```

### Process Transcription (Manual)
```
POST /api/transcription/process
Body: {
  sessionId: string,
  agoraUid: string,
  audioUrl: string,
  fileName?: string,
  participantId?: string
}
```

### Cleanup Audio
```
POST /api/cleanup/audio
Body: {
  sessionId: string,
  agoraUid: string,
  audioUrl: string
}
```

## Setup Instructions

1. **Run Database Migration**
   ```bash
   # In PrepSkul_App directory
   supabase migration up
   # Or apply migration manually via Supabase dashboard
   ```

2. **Install Dependencies** (if not already installed)
   ```bash
   cd PrepSkul_Web
   npm install @supabase/supabase-js
   ```

3. **Configure Agora Webhook**
   - Go to Agora Console → Cloud Recording → Webhooks
   - Set webhook URL to: `https://your-domain.com/api/webhooks/agora/recording`
   - Enable events: `recording_file_ready`

4. **Set Environment Variables**
   - Add all required environment variables to `.env.local`
   - For production, add to Vercel environment variables

## Cost Analysis

**OpenAI Whisper API:** $0.006 per minute
- Per 61-minute session: ~$0.37
- 100 sessions/month: ~$37/month
- 500 sessions/month: ~$185/month

**Cost Optimization Options:**
- Self-hosted Whisper (free, requires GPU)
- Deepgram free tier (12,000 minutes/month)
- Google Cloud Speech-to-Text free tier (60 minutes/month)

## Features

- ✅ Audio-only recording (Individual Mode)
- ✅ Separate transcription per participant
- ✅ Timestamped transcript segments
- ✅ Automatic cleanup after transcription
- ✅ Idempotent webhook handling
- ✅ Retry logic for transcription failures
- ✅ Audit logging for cleanup operations

## Error Handling

- **Transcription failures:** Retry up to 3 times with exponential backoff
- **Cleanup failures:** Logged but don't block flow
- **Webhook duplicates:** Checked via transcription status
- **Partial success:** One participant transcribed, other pending is acceptable

## Testing

1. Start a session → Verify recording starts
2. End session → Verify webhook received
3. Check `session_transcripts` table for transcripts
4. Check `media_cleanup_logs` for cleanup records
5. Verify audio files are deleted (or marked for auto-cleanup)

## Troubleshooting

### Recording not starting
- Check Agora credentials (AGORA_CUSTOMER_ID, AGORA_CUSTOMER_SECRET, AGORA_APP_ID)
- Verify session exists and user has access
- Check Agora Console for errors

### Webhook not received
- Verify webhook URL is configured in Agora Console
- Check server logs for webhook requests
- Verify webhook endpoint is accessible

### Transcription failing
- Check OPENAI_API_KEY is set correctly
- Verify audio URL is accessible
- Check OpenAI API quota/limits
- Review error logs for specific failures

### Cleanup not working
- Check `media_cleanup_logs` table for errors
- Verify cleanup endpoint is called after transcription
- Note: Agora may auto-cleanup files after retention period

## Notes

- **No AI Analysis:** Only transcription, no summarization or analysis
- **Audio Only:** Recording configured for audio tracks only
- **Temporary Storage:** Audio files stored temporarily in Agora Cloud Storage
- **Extensible:** Architecture allows adding AI analysis later
