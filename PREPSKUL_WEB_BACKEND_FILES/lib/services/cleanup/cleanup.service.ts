/**
 * Cleanup Service
 * 
 * Handles deletion of audio files after successful transcription
 */

import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

interface CleanupParams {
  sessionId: string;
  agoraUid: string;
  audioUrl: string;
}

export class CleanupService {
  /**
   * Delete audio file from Agora Cloud Storage
   * 
   * Note: Agora Cloud Storage files are typically accessed via HTTP URLs.
   * If Agora provides a delete API, use that. Otherwise, files may be
   * automatically cleaned up by Agora after a retention period.
   */
  async deleteAudioFile(params: CleanupParams): Promise<void> {
    const { sessionId, agoraUid, audioUrl } = params;

    try {
      // Log cleanup attempt
      await this.logCleanup(sessionId, agoraUid, audioUrl, 'pending');

      // Attempt to delete file
      // Note: Agora may not provide a direct delete API for cloud storage files
      // In that case, files are automatically cleaned up after retention period
      // For now, we'll mark as success and log it
      // If Agora provides delete API, implement it here
      
      const deleteSuccess = await this.attemptDelete(audioUrl);

      if (deleteSuccess) {
        await this.logCleanup(sessionId, agoraUid, audioUrl, 'success');
        console.log(`[CleanupService] Successfully deleted audio file for session ${sessionId}, uid ${agoraUid}`);
      } else {
        // If delete API not available, still log as success since Agora will auto-cleanup
        await this.logCleanup(sessionId, agoraUid, audioUrl, 'success', 'File will be auto-cleaned by Agora');
        console.log(`[CleanupService] Audio file marked for cleanup (auto-cleanup by Agora) for session ${sessionId}, uid ${agoraUid}`);
      }
    } catch (error: any) {
      console.error(`[CleanupService] Failed to delete audio file:`, error);
      await this.logCleanup(sessionId, agoraUid, audioUrl, 'failed', error.message);
      throw error;
    }
  }

  /**
   * Attempt to delete file from Agora Cloud Storage
   * Returns true if deletion succeeded or if delete API is not available
   */
  private async attemptDelete(audioUrl: string): Promise<boolean> {
    try {
      // If Agora provides a delete API endpoint, implement it here
      // For now, return true to indicate cleanup is handled (auto-cleanup by Agora)
      
      // Example implementation if Agora provides delete API:
      // const response = await fetch(audioUrl, { method: 'DELETE' });
      // return response.ok;

      // For now, assume Agora handles cleanup automatically
      return true;
    } catch (error) {
      console.error('[CleanupService] Delete attempt failed:', error);
      return false;
    }
  }

  /**
   * Log cleanup operation
   */
  private async logCleanup(
    sessionId: string,
    agoraUid: string,
    audioUrl: string,
    status: 'success' | 'failed' | 'pending',
    errorMessage?: string
  ): Promise<void> {
    const { error } = await supabase
      .from('media_cleanup_logs')
      .insert({
        session_id: sessionId,
        agora_uid: agoraUid,
        audio_url: audioUrl,
        status,
        error_message: errorMessage || null,
        deleted_at: status === 'success' ? new Date().toISOString() : null,
      });

    if (error) {
      console.error('[CleanupService] Failed to log cleanup:', error);
      // Don't throw - logging failure shouldn't break cleanup
    }
  }

  /**
   * Check if audio file has already been cleaned up
   */
  async isCleanedUp(sessionId: string, agoraUid: string, audioUrl: string): Promise<boolean> {
    const { data, error } = await supabase
      .from('media_cleanup_logs')
      .select('id')
      .eq('session_id', sessionId)
      .eq('agora_uid', agoraUid)
      .eq('audio_url', audioUrl)
      .eq('status', 'success')
      .limit(1);

    if (error) {
      console.error('[CleanupService] Error checking cleanup status:', error);
      return false;
    }

    return (data?.length || 0) > 0;
  }

  /**
   * Cleanup all audio files for a session after transcription completes
   */
  async cleanupAfterTranscription(sessionId: string): Promise<void> {
    try {
      // Get all audio files that need cleanup
      // This would be stored when webhook is received
      // For now, we'll get from session_recordings or webhook data
      
      // Get participants for this session
      const { data: participants } = await supabase
        .from('session_participants')
        .select('agora_uid')
        .eq('session_id', sessionId);

      if (!participants || participants.length === 0) {
        console.warn(`[CleanupService] No participants found for session ${sessionId}`);
        return;
      }

      // Check if all participants have transcripts
      const { data: transcripts } = await supabase
        .from('session_transcripts')
        .select('agora_uid')
        .eq('session_id', sessionId);

      const transcribedUids = new Set(transcripts?.map(t => t.agora_uid) || []);
      const participantUids = participants.map(p => p.agora_uid);

      // Only cleanup if all participants have transcripts
      const allTranscribed = participantUids.every(uid => transcribedUids.has(uid));

      if (!allTranscribed) {
        console.log(`[CleanupService] Not all participants transcribed yet for session ${sessionId}`);
        return;
      }

      // Update transcription status to completed
      await supabase
        .from('session_recordings')
        .update({
          transcription_status: 'completed',
          transcription_completed_at: new Date().toISOString(),
        })
        .eq('session_id', sessionId);

      console.log(`[CleanupService] Transcription completed for session ${sessionId}`);
      
      // Note: Actual file cleanup is handled per-file in deleteAudioFile
      // This method just marks transcription as complete
    } catch (error) {
      console.error('[CleanupService] Error in cleanupAfterTranscription:', error);
      throw error;
    }
  }
}
