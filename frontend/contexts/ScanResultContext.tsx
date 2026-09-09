import React, { createContext, useContext, useState } from 'react';
import { ApiResponse } from '../types';

const ScanResultContext = createContext<{
  result: ApiResponse | null;
  setResult: React.Dispatch<React.SetStateAction<ApiResponse | null>>;
} | null>(null);

export function ScanResultProvider({ children }: { children: React.ReactNode }) {
  const [result, setResult] = useState<ApiResponse | null>(null);

  return (
    <ScanResultContext.Provider value={{ result, setResult }}>
      {children}
    </ScanResultContext.Provider>
  );
}

export function useScanResult() {
  const context = useContext(ScanResultContext);
  if (!context) throw new Error('useScanResult must be used within ScanResultProvider');
  return context;
}
