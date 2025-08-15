// frontend/src/utils/api.ts
interface ApiRequestOptions extends RequestInit {
  headers?: Record<string, string>;
}

class ApiClient {
  private baseUrl: string;

  constructor() {
    this.baseUrl = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';
  }

  private getAuthHeaders(): Record<string, string> {
    const token = localStorage.getItem('auth_token');
    return token ? { Authorization: `Bearer ${token}` } : {};
  }

  async request(endpoint: string, options: ApiRequestOptions = {}): Promise<Response> {
    const url = `${this.baseUrl}${endpoint}`;
    
    const config: RequestInit = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...this.getAuthHeaders(),
        ...options.headers,
      },
    };

    const response = await fetch(url, config);

    // Handle 401 Unauthorized - redirect to login
    if (response.status === 401) {
      localStorage.removeItem('auth_token');
      window.location.reload();
      throw new Error('Authentication required');
    }

    return response;
  }

  async get(endpoint: string, options?: ApiRequestOptions): Promise<Response> {
    return this.request(endpoint, { ...options, method: 'GET' });
  }

  async post(endpoint: string, data?: any, options?: ApiRequestOptions): Promise<Response> {
    return this.request(endpoint, {
      ...options,
      method: 'POST',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async put(endpoint: string, data?: any, options?: ApiRequestOptions): Promise<Response> {
    return this.request(endpoint, {
      ...options,
      method: 'PUT',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  async delete(endpoint: string, options?: ApiRequestOptions): Promise<Response> {
    return this.request(endpoint, { ...options, method: 'DELETE' });
  }

  // Convenience methods that return JSON
  async getJson<T>(endpoint: string): Promise<T> {
    const response = await this.get(endpoint);
    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }
    return response.json();
  }

  async postJson<T>(endpoint: string, data?: any): Promise<T> {
    const response = await this.post(endpoint, data);
    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }
    return response.json();
  }

  async putJson<T>(endpoint: string, data?: any): Promise<T> {
    const response = await this.put(endpoint, data);
    if (!response.ok) {
      throw new Error(`API request failed: ${response.statusText}`);
    }
    return response.json();
  }
}

export const apiClient = new ApiClient();

// Helper function for backward compatibility
export async function authenticatedFetch(endpoint: string, options: ApiRequestOptions = {}): Promise<Response> {
  return apiClient.request(endpoint, options);
}