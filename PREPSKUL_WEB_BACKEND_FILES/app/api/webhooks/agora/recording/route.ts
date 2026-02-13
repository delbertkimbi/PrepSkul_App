/**
 * Agora Recording Webhook Handler
 * POST /api/webhooks/agora/recording
 * 
 * Receives webhooks from Agora when recording files are ready
 */

import { NextRequest, NextResponse } from 'next/server';
import { WebhookService } from '@/lib/services/agora/webhook.service';
import { TranscriptionService } from '@/lib/services/transcription/transcription.service';
import { CleanupService } from '@/lib/services/cleanup/cleanup.service';
import { createClient } from '@supabase/supabase-js';

const webhookService = new WebhookService();
const transcriptionService = new TranscriptionService();
const cleanupService = new CleanupService();

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    const payload = await request.json();

    // Validate webhook payload
    if (!webhookService.validateWebhookPayload(payload)) {
      return NextResponse.json(
        { error: 'Invalid webhook payload' },
        { status: 400 }
      );
    }

    const { notifyId, payload: webhookPayload } = payload;
    const { resourceId, sid } = webhookPayload;

    // Check idempotency
    const isProcessed = await webhookService.isWebhookProcessed(notifyId, resourceId, sid);
    if (isProcessed) {
      console.log(`[Webhook] Already processed: notifyId=${notifyId}, resourceId=${resourceId}, sid=${sid}`);
      return NextResponse.json({
        message: 'Webhook already processed',
      });
    }

    // Only process 'recording_file_ready' events
    if (payload.eventType !== 'recording_file_ready') {
      console.log(`[Webhook] Ignoring event type: ${payload.eventType}`);
      return NextResponse.json({
        message: `Event type ${payload.eventType} ignored`,
      });
    }

    // Process webhook and extract audio files
    const { sessionId, audioFiles } = await webhookService.processWebhook(payload);

    // Update recording status
    await webhookService.updateRecordingStatus(sessionId, 'uploaded');

    // Update transcription status to processing
    const { createClient } = await import('@supabase/supabase-js');
    const supabase = createClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL!,
      process.env.SUPABASE_SERVICE_ROLE_KEY!
    );

    await supabase
      .from('session_recordings')
      .update({
        transcription_status: 'processing',
        transcription_started_at: new Date().toISOString(),
      })
      .eq('session_id', sessionId);

    // Enqueue transcription jobs for each audio file
    // Process asynchronously to avoid blocking webhook response
    Promise.all(
      audioFiles.map(async (audioFile) => {
        try {
          // Check if already transcribed (idempotency)
          const hasTranscription = await transcriptionService.hasTranscription(sessionId, audioFile.agoraUid);
          if (hasTranscription) {
            console.log(`[Webhook] Transcription already exists for ${audioFile.agoraUid}`);
            return;
          }

          // Transcribe and store
          await transcriptionService.transcribeAndStore({
            sessionId,
            agoraUid: audioFile.agoraUid,
            participantId: audioFile.participantId,
            audioUrl: audioFile.fileUrl,
            fileName: audioFile.fileName,
          });

          // Trigger cleanup after successful transcription
          try {
            await cleanupService.deleteAudioFile({
              sessionId,
              agoraUid: audioFile.agoraUid,
              audioUrl: audioFile.fileUrl,
            });
          } catch (cleanupError) {
            console.error(`[Webhook] Cleanup failed for ${audioFile.agoraUid}:`, cleanupError);
            // Don't throw - cleanup failure shouldn't break the flow
          }
        } catch (error) {
          console.error(`[Webhook] Transcription failed for ${audioFile.agoraUid}:`, error);
          
          // Update transcription status to failed if all failed
          // For now, we'll let individual failures be handled by retries
          // Don't throw - allow other files to process
        }
      })
    ).then(async () => {
      // After all transcriptions complete, check if we should mark transcription as completed
      try {
        await cleanupService.cleanupAfterTranscription(sessionId);
      } catch (error) {
        console.error('[Webhook] Error in final cleanup check:', error);
      }
    }).catch((error) => {
      console.error('[Webhook] Error processing transcriptions:', error);
    });

    return NextResponse.json({
      message: 'Webhook processed successfully',
      sessionId,
      audioFilesCount: audioFiles.length,
    });
  } catch (error: any) {
    console.error('[Webhook] Error:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to process webhook' },
      { status: 500 }
    );
  }
}

// Handle GET for webhook verification (if Agora requires it)
export async function GET(request: NextRequest) {
  return NextResponse.json({
    message: 'Agora recording webhook endpoint',
  });
}
