/**
 * Agora Recording Service
 * 
 * Handles starting and stopping Agora Cloud Recording in Individual Mode (audio only)
 */

import { AgoraClient, getRecordingStorageConfig } from './agora.client';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

interface StartRecordingParams {
  sessionId: string;
  channelName: string;
  tutorUid: string;
  learnerUid: string;
}

interface RecordingMetadata {
  resourceId: string;
  sid: string;
}

export class RecordingService {
  private agoraClient: AgoraClient;

  constructor() {
    this.agoraClient = new AgoraClient();
  }

  /**
   * Acquire recording resource
   */
  async acquireResource(channelName: string, uid: string): Promise<string> {
    try {
      const response = await this.agoraClient.acquireResource(channelName, uid);
      return response.resourceId;
    } catch (error) {
      console.error('[RecordingService] Failed to acquire resource:', error);
      throw new Error(`Failed to acquire recording resource: ${error}`);
    }
  }

  /**
   * Start recording in Individual Mode (audio only).
   * Requires AGORA_RECORDING_STORAGE_BUCKET, AGORA_RECORDING_STORAGE_ACCESS_KEY, AGORA_RECORDING_STORAGE_SECRET_KEY.
   */
  async startRecording(params: StartRecordingParams): Promise<RecordingMetadata> {
    const { sessionId, channelName, tutorUid, learnerUid } = params;

    const storageConfig = getRecordingStorageConfig(channelName);
    if (!storageConfig) {
      throw new Error(
        'Recording storage not configured. Set AGORA_RECORDING_STORAGE_BUCKET, AGORA_RECORDING_STORAGE_ACCESS_KEY, and AGORA_RECORDING_STORAGE_SECRET_KEY (vendor 1 = AWS S3, region 0 = US).'
      );
    }

    try {
      const resourceId = await this.acquireResource(channelName, tutorUid);
      const subscribeAudioUids = [tutorUid, learnerUid];
      const response = await this.agoraClient.startRecording(
        resourceId,
        channelName,
        tutorUid,
        subscribeAudioUids,
        storageConfig
      );

      const sid = response.sid;

      // Store recording metadata in database
      await this.storeRecordingMetadata(sessionId, resourceId, sid, tutorUid, learnerUid);

      return { resourceId, sid };
    } catch (error) {
      console.error('[RecordingService] Failed to start recording:', error);
      throw error;
    }
  }

  /**
   * Stop recording
   */
  async stopRecording(sessionId: string, resourceId: string, sid: string, channelName: string, uid: string): Promise<void> {
    try {
      await this.agoraClient.stopRecording(resourceId, sid, channelName, uid);

      // Update recording status in database
      await supabase
        .from('session_recordings')
        .update({
          recording_status: 'stopped',
          updated_at: new Date().toISOString(),
        })
        .eq('session_id', sessionId);
    } catch (error) {
      console.error('[RecordingService] Failed to stop recording:', error);
      throw error;
    }
  }

  /**
   * Get recording status
   */
  async getRecordingStatus(resourceId: string, sid: string): Promise<any> {
    try {
      return await this.agoraClient.queryRecordingStatus(resourceId, sid);
    } catch (error) {
      console.error('[RecordingService] Failed to query recording status:', error);
      throw error;
    }
  }

  /**
   * Store recording metadata in database
   */
  private async storeRecordingMetadata(
    sessionId: string,
    resourceId: string,
    sid: string,
    tutorUid: string,
    learnerUid: string
  ): Promise<void> {
    // Upsert session_recordings - CRITICAL for recordings to appear
    const { data, error: recordingError } = await supabase
      .from('session_recordings')
      .upsert({
        session_id: sessionId,
        recording_resource_id: resourceId,
        recording_sid: sid,
        recording_status: 'recording',
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'session_id',
      })
      .select('id');

    if (recordingError) {
      console.error('[RecordingService] FAILED to store recording metadata in session_recordings:', recordingError);
      console.error('[RecordingService] sessionId:', sessionId, 'resourceId:', resourceId, 'sid:', sid);
      console.error('[RecordingService] RLS or schema may be blocking insert - check Supabase policies');
      throw recordingError;
    }
    console.log('[RecordingService] session_recordings upserted successfully:', data?.[0]?.id ?? 'ok');

    // Store participants with Agora UIDs
    const { data: session } = await supabase
      .from('individual_sessions')
      .select('tutor_id, learner_id')
      .eq('id', sessionId)
      .single();

    if (!session) {
      throw new Error(`Session ${sessionId} not found`);
    }

    // Upsert tutor participant
    const { error: tutorError } = await supabase
      .from('session_participants')
      .upsert({
        session_id: sessionId,
        agora_uid: tutorUid,
        user_id: session.tutor_id,
        role: 'tutor',
        joined_at: new Date().toISOString(),
      }, {
        onConflict: 'session_id,agora_uid',
      });

    if (tutorError) {
      console.error('[RecordingService] Failed to store tutor participant:', tutorError);
    }

    // Upsert learner participant
    const { error: learnerError } = await supabase
      .from('session_participants')
      .upsert({
        session_id: sessionId,
        agora_uid: learnerUid,
        user_id: session.learner_id,
        role: 'learner',
        joined_at: new Date().toISOString(),
      }, {
        onConflict: 'session_id,agora_uid',
      });

    if (learnerError) {
      console.error('[RecordingService] Failed to store learner participant:', learnerError);
    }
  }
}
