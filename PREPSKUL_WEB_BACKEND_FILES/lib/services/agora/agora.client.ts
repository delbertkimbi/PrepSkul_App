/**
 * Agora Cloud Recording API Client
 * 
 * Handles authentication and base requests to Agora Cloud Recording API
 * Documentation: https://docs.agora.io/en/cloud-recording/restfulapi/
 */

const AGORA_RECORDING_API_BASE = 'https://api.agora.io/v1';

/** Storage config for Cloud Recording - must use third-party storage (Agora does not provide built-in). */
export interface RecordingStorageConfig {
  vendor: number;  // 1 = AWS S3, 11 = S3-compatible (e.g. Supabase Storage)
  region: number;
  bucket: string;
  accessKey: string;
  secretKey: string;
  fileNamePrefix: string[];
  endpoint?: string;  // Required for vendor 11 (Supabase)
}

/** Read recording storage from env. Returns null if not configured. */
export function getRecordingStorageConfig(channelName: string): RecordingStorageConfig | null {
  const bucket = (process.env.AGORA_RECORDING_STORAGE_BUCKET ?? '').trim();
  const accessKey = (process.env.AGORA_RECORDING_STORAGE_ACCESS_KEY ?? '').trim();
  const secretKey = (process.env.AGORA_RECORDING_STORAGE_SECRET_KEY ?? '').trim();
  if (!bucket || !accessKey || !secretKey) return null;
  const vendor = Math.max(0, parseInt(process.env.AGORA_RECORDING_STORAGE_VENDOR ?? '1', 10)) || 1;
  const region = Math.max(0, parseInt(process.env.AGORA_RECORDING_STORAGE_REGION ?? '0', 10));
  const endpoint = (process.env.AGORA_RECORDING_STORAGE_ENDPOINT ?? '').trim() || undefined;
  return { vendor, region, bucket, accessKey, secretKey, fileNamePrefix: [`${channelName}_${Date.now()}`], endpoint };
}

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
    subscribeAudioUids: string[],
    storageConfig: RecordingStorageConfig
  ): Promise<{ sid: string }> {
    const endpoint = `/apps/${this.appId}/cloud_recording/resourceid/${resourceId}/mode/individual/start`;
    const body = {
      cname: channelName,
      uid: uid,
      clientRequest: {
        token: '',
        recordingConfig: {
          maxIdleTime: 30,
          streamTypes: 0,
          subscribeAudioUids: subscribeAudioUids,
          subscribeUidGroup: 0,
        },
        storageConfig: {
          vendor: storageConfig.vendor,
          region: storageConfig.region,
          bucket: storageConfig.bucket,
          accessKey: storageConfig.accessKey,
          secretKey: storageConfig.secretKey,
          fileNamePrefix: storageConfig.fileNamePrefix,
          ...(storageConfig.vendor === 11 && storageConfig.endpoint
            ? { extensionParams: { endpoint: storageConfig.endpoint } }
            : {}),
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
