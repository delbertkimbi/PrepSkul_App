/**
 * Stop Agora Cloud Recording
 * POST /api/agora/recording/stop
 * 
 * Stops recording for a session
 */

import { NextRequest, NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';
import { RecordingService } from '@/lib/services/agora/recording.service';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
);

export async function POST(request: NextRequest) {
  try {
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
      return NextResponse.json(
        { error: 'Unauthorized' },
        { status: 401 }
      );
    }

    // Parse request body
    const body = await request.json();
    const { sessionId } = body;

    if (!sessionId) {
      return NextResponse.json(
        { error: 'sessionId is required' },
        { status: 400 }
      );
    }

    // Get session and recording details
    const { data: session, error: sessionError } = await supabase
      .from('individual_sessions')
      .select('id, tutor_id, learner_id, agora_channel_name, recording_resource_id, recording_sid')
      .eq('id', sessionId)
      .single();

    if (sessionError || !session) {
      return NextResponse.json(
        { error: 'Session not found' },
        { status: 404 }
      );
    }

    // Verify user is part of the session
    if (session.tutor_id !== user.id && session.learner_id !== user.id) {
      return NextResponse.json(
        { error: 'Forbidden: You are not a participant in this session' },
        { status: 403 }
      );
    }

    // Check if recording exists
    if (!session.recording_resource_id || !session.recording_sid) {
      return NextResponse.json(
        { error: 'No active recording found' },
        { status: 404 }
      );
    }

    // Stop recording
    const recordingService = new RecordingService();
    const channelName = session.agora_channel_name || `session_${sessionId}`;
    const uid = session.tutor_id; // Use tutor UID to stop

    await recordingService.stopRecording(
      sessionId,
      session.recording_resource_id,
      session.recording_sid,
      channelName,
      uid
    );

    // Update session recording status
    await supabase
      .from('individual_sessions')
      .update({
        recording_status: 'stopped',
      })
      .eq('id', sessionId);

    return NextResponse.json({
      message: 'Recording stopped successfully',
    });
  } catch (error: any) {
    console.error('[Recording Stop] Error:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to stop recording' },
      { status: 500 }
    );
  }
}
