/**
 * Agora Cloud Recording API Client
 * 
 * Handles authentication and base requests to Agora Cloud Recording API
 * Documentation: https://docs.agora.io/en/cloud-recording/restfulapi/
 */

const AGORA_RECORDING_API_BASE = 'https://api.agora.io/v1';

interface AgoraApiResponse<T = any> {
  resourceId?: string;
  sid?: string;
  serverResponse?: {
    fileList?: Array<{
      fileName: string;
      trackType: 'audio' | 'video';
      uid: string;
      mixedAllUser: boolean;
      isPlayable: boolean;
      sliceStartTime: number;
    }>;
    uploadingStatus?: string;
  };
  [key: string]: any;
}

export class AgoraClient {
  private customerId: string;
  private customerSecret: string;
  private appId: string;

  constructor() {
    this.customerId = process.env.AGORA_CUSTOMER_ID || '';
    this.customerSecret = process.env.AGORA_CUSTOMER_SECRET || '';
    this.appId = process.env.AGORA_APP_ID || '';

    if (!this.customerId || !this.customerSecret || !this.appId) {
      throw new Error('Missing required Agora credentials: AGORA_CUSTOMER_ID, AGORA_CUSTOMER_SECRET, AGORA_APP_ID');
    }
  }

  /**
   * Generate Basic Auth header for Agora API
   */
  private getAuthHeader(): string {
    const credentials = Buffer.from(`${this.customerId}:${this.customerSecret}`).toString('base64');
    return `Basic ${credentials}`;
  }

  /**
   * Make authenticated request to Agora API
   */
  private async request<T = AgoraApiResponse>(
    method: 'GET' | 'POST' | 'DELETE',
    endpoint: string,
    body?: any
  ): Promise<T> {
    const url = `${AGORA_RECORDING_API_BASE}${endpoint}`;
    const headers: Record<string, string> = {
      'Authorization': this.getAuthHeader(),
      'Content-Type': 'application/json',
    };

    const options: RequestInit = {
      method,
      headers,
    };

    if (body && method !== 'GET') {
      options.body = JSON.stringify(body);
    }

    try {
      const response = await fetch(url, options);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(`Agora API error: ${JSON.stringify(data)}`);
      }

      return data as T;
    } catch (error) {
      console.error(`[AgoraClient] Request failed: ${endpoint}`, error);
      throw error;
    }
  }

  /**
   * Acquire recording resource
   * POST /v1/apps/{appid}/cloud_recording/acquire
   */
  async acquireResource(channelName: string, uid: string): Promise<{ resourceId: string }> {
    const endpoint = `/apps/${this.appId}/cloud_recording/acquire`;
    const body = {
      cname: channelName,
      uid: uid,
      clientRequest: {},
    };

    const response = await this.request<{ resourceId: string }>('POST', endpoint, body);
    return response;
  }

  /**
   * Start recording in Individual Mode (audio only)
   * POST /v1/apps/{appid}/cloud_recording/resourceid/{resourceid}/mode/individual/start
   */
  async startRecording(
    resourceId: string,
    channelName: string,
    uid: string,
    subscribeAudioUids: string[]
  ): Promise<{ sid: string }> {
    const endpoint = `/apps/${this.appId}/cloud_recording/resourceid/${resourceId}/mode/individual/start`;
    const body = {
      cname: channelName,
      uid: uid,
      clientRequest: {
        token: '', // Token not required for cloud recording
        recordingConfig: {
          maxIdleTime: 30,
          streamTypes: 0, // 0 = audio only, 1 = video only, 2 = audio and video
          audioProfile: 1, // 1 = music_high_quality
          subscribeAudioUids: subscribeAudioUids,
          subscribeVideoUids: [], // Empty for audio-only
        },
        storageConfig: {
          vendor: 0, // 0 = Agora Cloud Storage
          region: 0, // 0 = US, adjust as needed
          bucket: '',
          accessKey: '',
          secretKey: '',
          fileNamePrefix: [`${channelName}_${Date.now()}`],
        },
      },
    };

    const response = await this.request<{ sid: string }>('POST', endpoint, body);
    return response;
  }

  /**
   * Stop recording
   * POST /v1/apps/{appid}/cloud_recording/resourceid/{resourceid}/sid/{sid}/mode/individual/stop
   */
  async stopRecording(resourceId: string, sid: string, channelName: string, uid: string): Promise<void> {
    const endpoint = `/apps/${this.appId}/cloud_recording/resourceid/${resourceId}/sid/${sid}/mode/individual/stop`;
    const body = {
      cname: channelName,
      uid: uid,
      clientRequest: {},
    };

    await this.request('POST', endpoint, body);
  }

  /**
   * Query recording status
   * GET /v1/apps/{appid}/cloud_recording/resourceid/{resourceid}/sid/{sid}/mode/individual/query
   */
  async queryRecordingStatus(
    resourceId: string,
    sid: string
  ): Promise<AgoraApiResponse> {
    const endpoint = `/apps/${this.appId}/cloud_recording/resourceid/${resourceId}/sid/${sid}/mode/individual/query`;
    return this.request<AgoraApiResponse>('GET', endpoint);
  }
}
