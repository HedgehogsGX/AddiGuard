import axios from 'axios';
import { ApiResponse } from '../types';

// Replace with your local IP address for physical device testing
// For emulator: 'http://10.0.2.2:5000/api' (Android) or 'http://localhost:5000/api' (iOS)
const API_URL = 'http://localhost:5000/api'; 

export const analyzeImage = async (imageUri: string): Promise<ApiResponse> => {
  const formData = new FormData();
  
  // Append image file
  // @ts-ignore: React Native FormData requires specific object structure
  formData.append('image', {
    uri: imageUri,
    name: 'scan.jpg',
    type: 'image/jpeg',
  });

  try {
    const response = await axios.post<ApiResponse>(`${API_URL}/scan`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 10000, // 10s timeout
    });
    return response.data;
  } catch (error) {
    console.error('API Scan Error:', error);
    throw error;
  }
};
