import axios, { AxiosResponse } from 'axios';

const BASE_URL = 'http://localhost:9000';



interface ApiResponse<T> {
  code: number;
  message: string;
  data?: T;
}

const request = axios.create({
  baseURL: BASE_URL,
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

// Request interceptor
request.interceptors.request.use(
  (config) => {
    return config;
  },
  (error) => {
    return Promise.reject(error);
  }
);

// Response interceptor
request.interceptors.response.use(
  (response: AxiosResponse) => {
    return response.data;
  },
  (error) => {
    return Promise.reject(error);
  }
);

export const whitelistApi = {
  // Save whitelist signature
  saveSignature: async (address: string, signature: string, tokenId: number, deadline: number): Promise<ApiResponse<void>> => {
    const response = await request.post<ApiResponse<void>>('/user', { deadline, tokenId, address, signature });
    return response.data as ApiResponse<void>;
  },

  // Get whitelist signature
  getSignature: async (address: string): Promise<ApiResponse<any>> => {
    const response = await request.get<ApiResponse<any>>(`/user/${address}`);
    return response.data as ApiResponse<any>;
  },

  // Delete whitelist signature
  deleteSignature: async (address: string): Promise<ApiResponse<void>> => {
    const response = await request.delete<ApiResponse<void>>(`/user/${address}`);
    return response.data as ApiResponse<void>;
  },
};

export default request;
