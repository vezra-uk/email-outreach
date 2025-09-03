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

  private normalizeUrl(endpoint: string): string {
    // Universal fix: Always remove trailing slashes to prevent 307 redirects
    // Remove leading slash if present
    let cleanEndpoint = endpoint.startsWith('/') ? endpoint.slice(1) : endpoint;
    
    // Remove trailing slash if present
    if (cleanEndpoint.endsWith('/')) {
      cleanEndpoint = cleanEndpoint.slice(0, -1);
    }
    
    return `${this.baseUrl}/${cleanEndpoint}`;
  }

  async request(endpoint: string, options: ApiRequestOptions = {}): Promise<Response> {
    const url = this.normalizeUrl(endpoint);
    
    const config: RequestInit = {
      ...options,
      headers: {
        'Content-Type': 'application/json',
        ...this.getAuthHeaders(),
        ...options.headers,
      },
      // Enable automatic redirect handling
      redirect: 'follow'
    };

    try {
      const response = await fetch(url, config);

      // Handle 401 Unauthorized - redirect to login
      if (response.status === 401) {
        localStorage.removeItem('auth_token');
        window.location.reload();
        throw new Error('Authentication required');
      }

      // Handle other 3xx redirects that fetch might not handle automatically
      if (response.status >= 300 && response.status < 400) {
        const location = response.headers.get('location');
        if (location) {
          // Retry with the redirect URL
          const redirectUrl = location.startsWith('http') ? location : `${this.baseUrl}${location}`;
          return fetch(redirectUrl, config);
        }
      }

      return response;
    } catch (error) {
      // Log the error for debugging but don't retry since we have universal normalization
      console.error('API request failed:', { url, error });
      throw error;
    }
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

  async patch(endpoint: string, data?: any, options?: ApiRequestOptions): Promise<Response> {
    return this.request(endpoint, {
      ...options,
      method: 'PATCH',
      body: data ? JSON.stringify(data) : undefined,
    });
  }

  // Convenience methods that return JSON
  async getJson<T>(endpoint: string): Promise<T> {
    const response = await this.get(endpoint);
    if (!response.ok) {
      let errorMessage = `API request failed: ${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.detail) {
          errorMessage += ` - ${errorData.detail}`;
        }
      } catch {
        // If we can't parse the error response, use the default message
      }
      throw new Error(errorMessage);
    }
    return response.json();
  }

  async postJson<T>(endpoint: string, data?: any): Promise<T> {
    const response = await this.post(endpoint, data);
    if (!response.ok) {
      let errorMessage = `API request failed: ${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.detail) {
          errorMessage += ` - ${JSON.stringify(errorData.detail)}`;
        }
      } catch {
        // If we can't parse the error response, use the default message
      }
      throw new Error(errorMessage);
    }
    return response.json();
  }

  async putJson<T>(endpoint: string, data?: any): Promise<T> {
    const response = await this.put(endpoint, data);
    if (!response.ok) {
      let errorMessage = `API request failed: ${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.detail) {
          errorMessage += ` - ${JSON.stringify(errorData.detail)}`;
        }
      } catch {
        // If we can't parse the error response, use the default message
      }
      throw new Error(errorMessage);
    }
    return response.json();
  }

  async patchJson<T>(endpoint: string, data?: any): Promise<T> {
    const response = await this.patch(endpoint, data);
    if (!response.ok) {
      let errorMessage = `API request failed: ${response.status} ${response.statusText}`;
      try {
        const errorData = await response.json();
        if (errorData.detail) {
          errorMessage += ` - ${JSON.stringify(errorData.detail)}`;
        }
      } catch {
        // If we can't parse the error response, use the default message
      }
      throw new Error(errorMessage);
    }
    return response.json();
  }
}

export const apiClient = new ApiClient();

// Helper function for backward compatibility
export async function authenticatedFetch(endpoint: string, options: ApiRequestOptions = {}): Promise<Response> {
  return apiClient.request(endpoint, options);
}