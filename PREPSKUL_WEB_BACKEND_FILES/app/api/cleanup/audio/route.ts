/**
 * Audio Cleanup Endpoint
 * POST /api/cleanup/audio
 * 
 * Triggers cleanup of audio files after transcription
 */

import { NextRequest, NextResponse } from 'next/server';
import { CleanupService } from '@/lib/services/cleanup/cleanup.service';

const cleanupService = new CleanupService();

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { sessionId, agoraUid, audioUrl } = body;

    if (!sessionId || !agoraUid || !audioUrl) {
      return NextResponse.json(
        { error: 'sessionId, agoraUid, and audioUrl are required' },
        { status: 400 }
      );
    }

    // Check if already cleaned up (idempotency)
    const isCleaned = await cleanupService.isCleanedUp(sessionId, agoraUid, audioUrl);
    if (isCleaned) {
      return NextResponse.json({
        message: 'Audio file already cleaned up',
      });
    }

    // Delete audio file
    await cleanupService.deleteAudioFile({
      sessionId,
      agoraUid,
      audioUrl,
    });

    return NextResponse.json({
      message: 'Audio file cleanup initiated',
    });
  } catch (error: any) {
    console.error('[Cleanup] Error:', error);
    return NextResponse.json(
      { error: error.message || 'Failed to cleanup audio file' },
      { status: 500 }
    );
  }
}
