/**
 * Transcription Process Endpoint
 * POST /api/transcription/process
 * 
 * Manually trigger transcription for an audio file
 * (Alternative to webhook-triggered transcription)
 */

import { NextRequest, NextResponse } from 'next/server';
import { TranscriptionService } from '@/lib/services/transcription/transcription.service';
import { createClient } from '@supabase/supabase-js';

const transcriptionService = new TranscriptionService();
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { sessionId, agoraUid, audioUrl, fileName, participantId } = body;

    if (!sessionId || !agoraUid || !audioUrl) {
      return NextResponse.json(
        { error: 'sessionId, agoraUid, and audioUrl are required' },
        { status: 400 }
      );
    }

    // Check if already transcribed (idempotency)
    const hasTranscription = await transcriptionService.hasTranscription(sessionId, agoraUid);
    if (hasTranscription) {
      return NextResponse.json({
        message: 'Transcription already exists',
        sessionId,
        agoraUid,
      });
    }

    // Update transcription status to processing
    await supabase
      .from('session_recordings')
      .update({
        transcription_status: 'processing',
        transcription_started_at: new Date().toISOString(),
      })
      .eq('session_id', sessionId);

    // Transcribe and store
    await transcriptionService.transcribeAndStore({
      sessionId,
      agoraUid,
      participantId,
      audioUrl,
      fileName: fileName || 'audio.mp3',
    });

    return NextResponse.json({
      message: 'Transcription completed successfully',
      sessionId,
      agoraUid,
    });
  } catch (error: any) {
    console.error('[Transcription Process] Error:', error);
    
    // Update transcription status to failed
    const body = await request.json().catch(() => ({}));
    if (body.sessionId) {
      await supabase
        .from('session_recordings')
        .update({
          transcription_status: 'failed',
        })
        .eq('session_id', body.sessionId);
    }

    return NextResponse.json(
      { error: error.message || 'Failed to process transcription' },
      { status: 500 }
    );
  }
}
