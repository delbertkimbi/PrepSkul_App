/**
 * Start Agora Cloud Recording
 * POST /api/agora/recording/start
 * 
 * Starts recording in Individual Mode (audio only) for a session
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { RecordingService } from '@/lib/services/agora/recording.service';

/**
 * Generate a numeric Agora UID from a string user ID
 * Agora requires numeric UIDs (32-bit unsigned integer, max 2^32-1)
 * This must match the algorithm used in the token generation endpoint
 */
function generateAgoraUid(userId: string): number {
  let hash = 0;
  for (let i = 0; i < userId.length; i++) {
    const char = userId.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash = hash & hash; // Convert to 32-bit integer
  }
  // Ensure positive number in valid Agora range (1 to 2^32-1)
  // Agora UID 0 means server assigns UID, so we avoid it
  return Math.abs(hash) % 0xFFFFFFFF || 1;
}

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
    console.log('[Recording Start] Incoming request to /api/agora/recording/start');
    console.log('[Recording Start] Request method:', request.method);

    // Get auth token from header
    const authHeader = request.headers.get('authorization');
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    const token = authHeader.replace('Bearer ', '');

    // Verify token and get user
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) {
      console.error('[Recording Start] Auth error or no user:', authError);
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Parse request body
    const body = await request.json();
    const { sessionId } = body;

    console.log('[Recording Start] Parsed body:', body);

    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    // Get session details (individual_sessions first; fallback to trial_sessions for trial sessions)
    let session: { id: string; tutor_id: string; learner_id: string; agora_channel_name: string | null } | null = null;

    console.log('[Recording Start] Looking up session in individual_sessions:', sessionId);
    const individualResult = await supabase
      .from('individual_sessions')
      .select('id, tutor_id, learner_id, agora_channel_name')
      .eq('id', sessionId)
      .single();

    if (individualResult.error) {
      console.error('[Recording Start] individual_sessions query error:', individualResult.error);
    }

    if (individualResult.data) {
      session = individualResult.data;
    } else {
      // Trial session: ensure individual_sessions row exists (client may have sent trial id)
      console.log('[Recording Start] Session not found in individual_sessions, checking trial_sessions:', sessionId);
      const trialResult = await supabase
        .from('trial_sessions')
        .select('id, tutor_id, learner_id, parent_id, scheduled_date, scheduled_time, duration_minutes, location, subject')
        .eq('id', sessionId)
        .single();

      if (trialResult.data) {
        const trial = trialResult.data as {
          id: string;
          tutor_id: string;
          learner_id: string;
          parent_id?: string | null;
          scheduled_date?: string;
          scheduled_time?: string;
          duration_minutes?: number;
          location?: string;
          subject?: string | null;
        };
        const channelName = `session_${sessionId}`;
        const scheduledDate = trial.scheduled_date ?? new Date().toISOString().slice(0, 10);
        const scheduledTime = trial.scheduled_time ?? '00:00';
        const durationMinutes = trial.duration_minutes ?? 60;
        console.log('[Recording Start] Upserting trial session into individual_sessions as in_progress online session');
        const upsertResult = await supabase.from('individual_sessions').upsert(
          {
            id: sessionId,
            tutor_id: trial.tutor_id,
            learner_id: trial.learner_id,
            parent_id: trial.parent_id ?? null,
            recurring_session_id: null,
            status: 'in_progress',
            scheduled_date: scheduledDate,
            scheduled_time: scheduledTime,
            duration_minutes: durationMinutes,
            location: trial.location ?? 'online',
            subject: trial.subject ?? null,
            agora_channel_name: channelName,
          },
          { onConflict: 'id' }
        );
        if (upsertResult.error) {
          console.error('[Recording Start] individual_sessions upsert error for trial session:', upsertResult.error);
        } else {
          console.log('[Recording Start] individual_sessions upsert success for trial session');
        }
        session = {
          id: sessionId,
          tutor_id: trial.tutor_id,
          learner_id: trial.learner_id,
          agora_channel_name: channelName,
        };
      }
    }

    if (!session) {
      console.warn('[Recording Start] Session not found in individual_sessions or trial_sessions for id:', sessionId);
      return NextResponse.json(
        { error: 'Session not found' },
        { status: 404 }
      );
    }

    // Verify user is part of the session
    if (session.tutor_id !== user.id && session.learner_id !== user.id) {
      console.warn('[Recording Start] Forbidden: user not participant in session', {
        userId: user.id,
        sessionTutorId: session.tutor_id,
        sessionLearnerId: session.learner_id,
      });
      return NextResponse.json(
        { error: 'Forbidden: You are not a participant in this session' },
        { status: 403 }
      );
    }

    // Check if recording already exists
    console.log('[Recording Start] Checking existing session_recordings row for session:', sessionId);
    const { data: existingRecording, error: existingRecordingError } = await supabase
      .from('session_recordings')
      .select('recording_resource_id, recording_sid, recording_status')
      .eq('session_id', sessionId)
      .single();

    if (existingRecordingError) {
      console.error('[Recording Start] session_recordings query error:', existingRecordingError);
    }

    if (existingRecording && existingRecording.recording_status === 'recording') {
      console.log('[Recording Start] Recording already in progress for session:', sessionId);
      return NextResponse.json({
        resourceId: existingRecording.recording_resource_id,
        sid: existingRecording.recording_sid,
        message: 'Recording already in progress',
      });
    }

    // Generate channel name if not exists
    const channelName = session.agora_channel_name || `session_${sessionId}`;

    // Generate numeric Agora UIDs from string user IDs
    // These must match the UIDs used when users join the channel via the token endpoint
    const tutorUid = generateAgoraUid(session.tutor_id);
    const learnerUid = generateAgoraUid(session.learner_id);
    
    console.log(`[Recording Start] Tutor: ${session.tutor_id} -> UID: ${tutorUid}`);
    console.log(`[Recording Start] Learner: ${session.learner_id} -> UID: ${learnerUid}`);
    console.log(`[Recording Start] Channel: ${channelName}`);

    // Start recording (RecordingService also upserts into session_recordings)
    console.log('[Recording Start] Calling RecordingService.startRecording...');
    const recordingService = new RecordingService();
    const { resourceId, sid } = await recordingService.startRecording({
      sessionId,
      channelName,
      tutorUid: tutorUid.toString(),
      learnerUid: learnerUid.toString(),
    });
    console.log('[Recording Start] Recording started, resourceId:', resourceId, 'sid:', sid);

    // Update individual_sessions with recording info
    console.log('[Recording Start] Updating individual_sessions with recording metadata for session:', sessionId);
    const updateResult = await supabase
      .from('individual_sessions')
      .update({
        agora_channel_name: channelName,
        recording_resource_id: resourceId,
        recording_sid: sid,
        recording_status: 'recording',
      })
      .eq('id', sessionId);

    if (updateResult.error) {
      console.error('[Recording Start] Failed to update individual_sessions with recording metadata:', updateResult.error);
    } else {
      console.log('[Recording Start] individual_sessions updated with recording metadata for session:', sessionId);
    }

    return NextResponse.json({
      resourceId,
      sid,
      channelName,
    });
  } catch (error: any) {
    console.error('[Recording Start] Error starting recording:', error);
    if (error?.stack) {
      console.error('[Recording Start] Stack trace:', error.stack);
    }
    return NextResponse.json(
      { error: error.message || 'Failed to start recording' },
      { status: 500 }
    );
  }
}
