/**
 * Agora Webhook Service
 * 
 * Handles parsing and processing Agora recording webhooks
 */

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

interface AudioFile {
  fileName: string;
  trackType: 'audio' | 'video';
  uid: string;
  mixedAllUser: boolean;
  isPlayable: boolean;
  sliceStartTime: number;
  fileUrl?: string;
}

interface WebhookPayload {
  eventType: string;
  notifyId: string;
  payload: {
    resourceId: string;
    sid: string;
    serverResponse?: {
      fileList?: AudioFile[];
      uploadingStatus?: string;
    };
  };
  timestamp: number;
}

export class WebhookService {
  /**
   * Validate webhook payload structure
   */
  validateWebhookPayload(payload: any): payload is WebhookPayload {
    return (
      payload &&
      typeof payload.eventType === 'string' &&
      typeof payload.notifyId === 'string' &&
      payload.payload &&
      typeof payload.payload.resourceId === 'string' &&
      typeof payload.payload.sid === 'string'
    );
  }

  /**
   * Extract audio files from webhook payload
   */
  extractAudioFiles(payload: WebhookPayload): AudioFile[] {
    const fileList = payload.payload.serverResponse?.fileList || [];
    // Filter for audio files only
    return fileList.filter(file => file.trackType === 'audio');
  }

  /**
   * Map Agora UID to session participant
   */
  async mapAgoraUidToParticipant(
    sessionId: string,
    agoraUid: string
  ): Promise<{ participantId: string; userId: string; role: string } | null> {
    const { data: participant, error } = await supabase
      .from('session_participants')
      .select('id, user_id, role')
      .eq('session_id', sessionId)
      .eq('agora_uid', agoraUid)
      .single();

    if (error || !participant) {
      console.error(`[WebhookService] Participant not found for session ${sessionId}, uid ${agoraUid}`);
      return null;
    }

    return {
      participantId: participant.id,
      userId: participant.user_id,
      role: participant.role,
    };
  }

  /**
   * Check if webhook has already been processed (idempotency)
   */
  async isWebhookProcessed(notifyId: string, resourceId: string, sid: string): Promise<boolean> {
    // Check if we've already processed this webhook by checking recording status
    // If transcription is already processing or completed, webhook was processed
    const { data: recording } = await supabase
      .from('session_recordings')
      .select('transcription_status')
      .eq('recording_resource_id', resourceId)
      .eq('recording_sid', sid)
      .single();

    if (recording) {
      // If transcription is processing or completed, webhook was already processed
      if (recording.transcription_status === 'processing' || recording.transcription_status === 'completed') {
        return true;
      }
    }

    // Additional check: store webhook notifyId to prevent duplicates
    // For now, we'll rely on transcription_status check
    // In production, you might want to store webhook IDs in a separate table
    return false;
  }

  /**
   * Process webhook and extract audio file URLs
   */
  async processWebhook(payload: WebhookPayload): Promise<{
    sessionId: string;
    audioFiles: Array<{
      agoraUid: string;
      fileUrl: string;
      fileName: string;
      participantId?: string;
    }>;
  }> {
    const { resourceId, sid } = payload.payload;

    // Find session by resourceId and sid
    const { data: recording, error: recordingError } = await supabase
      .from('session_recordings')
      .select('session_id')
      .eq('recording_resource_id', resourceId)
      .eq('recording_sid', sid)
      .single();

    if (recordingError || !recording) {
      throw new Error(`Recording not found for resourceId: ${resourceId}, sid: ${sid}`);
    }

    const sessionId = recording.session_id;

    // Extract audio files
    const audioFiles = this.extractAudioFiles(payload);

    // Map UIDs to participants and get file URLs
    const mappedFiles = await Promise.all(
      audioFiles.map(async (file) => {
        const participant = await this.mapAgoraUidToParticipant(sessionId, file.uid);
        
        // Construct file URL (Agora provides fileList but URLs may need to be constructed)
        // The actual URL format depends on Agora's storage configuration
        // For now, we'll use fileName and construct URL if needed
        const fileUrl = file.fileUrl || `https://agora-cloud-storage/${file.fileName}`;

        return {
          agoraUid: file.uid,
          fileUrl,
          fileName: file.fileName,
          participantId: participant?.participantId,
        };
      })
    );

    return {
      sessionId,
      audioFiles: mappedFiles,
    };
  }

  /**
   * Update recording status after webhook received
   */
  async updateRecordingStatus(
    sessionId: string,
    status: 'uploaded' | 'failed'
  ): Promise<void> {
    await supabase
      .from('session_recordings')
      .update({
        recording_status: status,
        updated_at: new Date().toISOString(),
      })
      .eq('session_id', sessionId);
  }
}
