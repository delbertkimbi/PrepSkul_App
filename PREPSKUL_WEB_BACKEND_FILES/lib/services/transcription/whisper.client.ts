/**
 * OpenAI Whisper API Client
 * 
 * Handles transcription requests to OpenAI Whisper API
 */

const OPENAI_API_BASE = 'https://api.openai.com/v1';

export interface TranscriptSegment {
  id: number;
  seek: number;
  start: number;
  end: number;
  text: string;
  tokens: number[];
  temperature: number;
  avg_logprob: number;
  compression_ratio: number;
  no_speech_prob: number;
}

export interface WhisperResponse {
  task: string;
  language: string;
  duration: number;
  text: string;
  segments: TranscriptSegment[];
}

export class WhisperClient {
  private apiKey: string;

  constructor() {
    this.apiKey = process.env.OPENAI_API_KEY || '';
    if (!this.apiKey) {
      throw new Error('OPENAI_API_KEY environment variable is required');
    }
  }

  /**
   * Transcribe audio file
   * 
   * @param audioFile - Audio file as Buffer or File
   * @param options - Transcription options
   * @returns Transcript with segments and timestamps
   */
  async transcribe(
    audioFile: Buffer | File,
    options: {
      language?: string;
      prompt?: string;
      responseFormat?: 'json' | 'text' | 'srt' | 'verbose_json' | 'vtt';
      temperature?: number;
    } = {}
  ): Promise<WhisperResponse> {
    const formData = new FormData();
    
    // Handle both Buffer and File types
    if (audioFile instanceof File) {
      formData.append('file', audioFile);
    } else {
      // Convert Buffer to Blob
      const blob = new Blob([audioFile], { type: 'audio/mpeg' });
      formData.append('file', blob, 'audio.mp3');
    }

    formData.append('model', 'whisper-1');
    
    if (options.language) {
      formData.append('language', options.language);
    }
    
    if (options.prompt) {
      formData.append('prompt', options.prompt);
    }
    
    formData.append('response_format', options.responseFormat || 'verbose_json');
    
    if (options.temperature !== undefined) {
      formData.append('temperature', options.temperature.toString());
    }

    try {
      const response = await fetch(`${OPENAI_API_BASE}/audio/transcriptions`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.apiKey}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const error = await response.json().catch(() => ({ error: 'Unknown error' }));
        throw new Error(`OpenAI API error: ${JSON.stringify(error)}`);
      }

      const data = await response.json();
      
      // Ensure segments array exists
      if (!data.segments) {
        data.segments = [];
      }

      return data as WhisperResponse;
    } catch (error) {
      console.error('[WhisperClient] Transcription failed:', error);
      throw error;
    }
  }

  /**
   * Transcribe audio from URL
   * Downloads the audio first, then transcribes
   */
  async transcribeFromUrl(
    audioUrl: string,
    options: {
      language?: string;
      prompt?: string;
      temperature?: number;
    } = {}
  ): Promise<WhisperResponse> {
    try {
      // Download audio file
      const response = await fetch(audioUrl);
      if (!response.ok) {
        throw new Error(`Failed to download audio: ${response.statusText}`);
      }

      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);

      // Transcribe
      return await this.transcribe(buffer, options);
    } catch (error) {
      console.error('[WhisperClient] Failed to transcribe from URL:', error);
      throw error;
    }
  }
}
