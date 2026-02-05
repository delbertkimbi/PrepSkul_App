/**
 * Transcription Service
 * 
 * Orchestrates audio download, transcription, and storage
 */

import { WhisperClient, TranscriptSegment } from './whisper.client';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

interface TranscribeAndStoreParams {
  sessionId: string;
  agoraUid: string;
  participantId?: string;
  audioUrl: string;
  fileName: string;
}

export class TranscriptionService {
  private whisperClient: WhisperClient;
  private maxRetries = 3;
  private retryDelay = 1000; // 1 second base delay

  constructor() {
    this.whisperClient = new WhisperClient();
  }

  /**
   * Transcribe audio and store results in database
   */
  async transcribeAndStore(params: TranscribeAndStoreParams): Promise<void> {
    const { sessionId, agoraUid, participantId, audioUrl, fileName } = params;

    let lastError: Error | null = null;

    // Retry logic
    for (let attempt = 1; attempt <= this.maxRetries; attempt++) {
      try {
        console.log(`[TranscriptionService] Attempt ${attempt}/${this.maxRetries} for session ${sessionId}, uid ${agoraUid}`);

        // Download and transcribe audio
        const transcript = await this.whisperClient.transcribeFromUrl(audioUrl, {
          language: 'en', // Adjust based on your needs
        });

        // Format transcript segments
        const formattedSegments = this.formatTranscriptSegments(transcript.segments);

        // Get or create participant if not provided
        let finalParticipantId = participantId;
        if (!finalParticipantId) {
          const { data: participant } = await supabase
            .from('session_participants')
            .select('id')
            .eq('session_id', sessionId)
            .eq('agora_uid', agoraUid)
            .single();

          if (!participant) {
            throw new Error(`Participant not found for session ${sessionId}, uid ${agoraUid}`);
          }

          finalParticipantId = participant.id;
        }

        // Store transcript segments in database (transaction)
        await this.storeTranscript(sessionId, finalParticipantId, agoraUid, formattedSegments);

        console.log(`[TranscriptionService] Successfully transcribed and stored ${formattedSegments.length} segments`);
        return; // Success, exit retry loop
      } catch (error: any) {
        lastError = error;
        console.error(`[TranscriptionService] Attempt ${attempt} failed:`, error);

        if (attempt < this.maxRetries) {
          // Exponential backoff
          const delay = this.retryDelay * Math.pow(2, attempt - 1);
          console.log(`[TranscriptionService] Retrying in ${delay}ms...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }

    // All retries failed
    throw new Error(`Transcription failed after ${this.maxRetries} attempts: ${lastError?.message}`);
  }

  /**
   * Format transcript segments for storage
   */
  private formatTranscriptSegments(segments: TranscriptSegment[]): Array<{
    startTime: number;
    endTime: number;
    text: string;
    confidence?: number;
  }> {
    return segments.map(segment => ({
      startTime: segment.start,
      endTime: segment.end,
      text: segment.text.trim(),
      // Use avg_logprob as confidence indicator (higher is better)
      confidence: segment.avg_logprob ? Math.exp(segment.avg_logprob) : undefined,
    }));
  }

  /**
   * Store transcript segments in database
   */
  private async storeTranscript(
    sessionId: string,
    participantId: string,
    agoraUid: string,
    segments: Array<{
      startTime: number;
      endTime: number;
      text: string;
      confidence?: number;
    }>
  ): Promise<void> {
    if (segments.length === 0) {
      console.warn(`[TranscriptionService] No segments to store for session ${sessionId}`);
      return;
    }

    // Insert segments in batches to avoid overwhelming the database
    const batchSize = 100;
    for (let i = 0; i < segments.length; i += batchSize) {
      const batch = segments.slice(i, i + batchSize);
      
      const transcriptRecords = batch.map(segment => ({
        session_id: sessionId,
        participant_id: participantId,
        agora_uid: agoraUid,
        start_time: segment.startTime,
        end_time: segment.endTime,
        text: segment.text,
        confidence: segment.confidence,
      }));

      const { error } = await supabase
        .from('session_transcripts')
        .insert(transcriptRecords);

      if (error) {
        console.error(`[TranscriptionService] Failed to store transcript batch ${i}-${i + batch.length}:`, error);
        throw error;
      }
    }

    console.log(`[TranscriptionService] Stored ${segments.length} transcript segments`);
  }

  /**
   * Check if transcription already exists for a participant
   */
  async hasTranscription(sessionId: string, agoraUid: string): Promise<boolean> {
    const { data, error } = await supabase
      .from('session_transcripts')
      .select('id')
      .eq('session_id', sessionId)
      .eq('agora_uid', agoraUid)
      .limit(1);

    if (error) {
      console.error('[TranscriptionService] Error checking existing transcription:', error);
      return false;
    }

    return (data?.length || 0) > 0;
  }
}
