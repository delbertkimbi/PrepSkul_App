# Agora RTC Setup Guide

## Environment Variables Required

To test the Agora video session functionality, you need to set up the following environment variables:

### Flutter App (.env file)

Add these to your `.env` file in the Flutter app root:

```env
# Next.js API URL (for token generation and recording)
NEXTJS_API_URL=https://www.prepskul.com
# Or for local testing:
# NEXTJS_API_URL=http://localhost:3000
```

### Next.js App (.env.local file)

Add these to your `.env.local` file in the `PrepSkul_Web` directory:

```env
# Agora App Configuration
AGORA_APP_ID=your_agora_app_id_here
AGORA_APP_CERTIFICATE=your_agora_app_certificate_here
AGORA_DATA_CENTER=EU

# Agora Cloud Recording Configuration
AGORA_CUSTOMER_ID=your_agora_customer_id_here
AGORA_CUSTOMER_SECRET=your_agora_customer_secret_here

# Supabase Configuration (should already exist)
NEXT_PUBLIC_SUPABASE_URL=your_supabase_url
NEXT_PUBLIC_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## How to Get Agora Credentials

1. **Log in to Agora Console**: https://console.agora.io/

2. **Get App ID and Certificate**:
   - Go to "Projects" → Select your project
   - Copy the "App ID"
   - Go to "Config" → "Primary Certificate" → Copy the certificate

3. **Get Customer ID and Secret (for Cloud Recording)**:
   - Go to "Usage" → "Cloud Recording"
   - You'll need to enable Cloud Recording service
   - Get your Customer ID and Customer Secret from the recording dashboard

## Testing Steps

1. **Install Dependencies**:
   ```bash
   # Flutter
   flutter pub get
   
   # Next.js
   cd ../PrepSkul_Web
   pnpm install
   ```

2. **Set Environment Variables**:
   - Add all variables to `.env` (Flutter) and `.env.local` (Next.js)

3. **Run Database Migration**:
   - Run the migration file: `supabase/migrations/041_add_agora_video_sessions.sql`
   - This adds Agora fields to `individual_sessions` and creates `session_recordings` table

4. **Start Next.js Server** (if testing locally):
   ```bash
   cd ../PrepSkul_Web
   pnpm dev
   ```

5. **Test Video Session**:
   - As a tutor: Start a session → Should navigate to Agora video screen
   - As a student: Click "Join Meeting" on an online session → Should navigate to Agora video screen
   - Both users should see each other's video/audio

## Current Implementation Status

✅ **Completed:**
- Agora RTC SDK integration (Flutter)
- Token generation (Next.js)
- Video session screen with controls
- Recording start/stop services
- Session lifecycle integration
- UI navigation from tutor/student screens

⏳ **Remaining (not needed for basic testing):**
- Recording webhook handler
- Recording download & upload to Supabase
- Audio transcription
- AI summarization

## Troubleshooting

### "Failed to generate token"
- Check that `AGORA_APP_ID` and `AGORA_APP_CERTIFICATE` are set correctly
- Verify Next.js server is running and accessible
- Check browser console/Flutter logs for detailed error

### "Failed to start recording"
- Check that `AGORA_CUSTOMER_ID` and `AGORA_CUSTOMER_SECRET` are set
- Verify Cloud Recording is enabled in your Agora project
- Recording will fail silently (won't block session) if credentials are wrong

### Video not showing
- Check camera/microphone permissions
- Verify Agora engine initialized successfully
- Check connection status indicator in video screen

### Can't join channel
- Verify token generation is working (check Next.js logs)
- Check that session exists and user has access
- Verify Agora App ID matches in both Flutter and Next.js

## Notes

- Recording will start automatically when tutor starts an online session
- Recording will stop automatically when tutor ends the session
- For now, recording files are stored temporarily in Agora Cloud Storage
- Full recording pipeline (download, transcription, summarization) is not yet implemented

