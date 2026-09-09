import axios from 'axios';
import Constants from 'expo-constants';
import { ApiResponse } from '../types';

// Resolution order:
// 1. EXPO_PUBLIC_API_URL (set in frontend/.env or the shell) for an explicit backend.
// 2. The machine serving the Expo dev bundle, so a physical device on the same
//    network reaches a backend started with `python run.py` without any config.
// 3. localhost, which only works on the iOS simulator / web.
const devHost = Constants.expoConfig?.hostUri?.split(':')[0];
export const API_URL = process.env.EXPO_PUBLIC_API_URL ?? `http://${devHost ?? 'localhost'}:5000/api`;

export const analyzeImage = async (imageUri: string): Promise<ApiResponse> => {
  const formData = new FormData();
  formData.append('image', {
    uri: imageUri,
    name: 'scan.jpg',
    type: 'image/jpeg',
  } as unknown as Blob);

  try {
    const response = await axios.post<ApiResponse>(`${API_URL}/scan`, formData, {
      headers: {
        'Content-Type': 'multipart/form-data',
      },
      timeout: 60000,
    });
    return response.data;
  } catch (error) {
    if (axios.isAxiosError(error)) {
      throw new Error(error.response?.data?.error ?? `Could not reach the backend at ${API_URL}`);
    }
    throw error;
  }
};
