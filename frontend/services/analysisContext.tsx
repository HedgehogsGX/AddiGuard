import React, { createContext, useContext, useState } from "react";
import { ApiResponse } from "../types";

type AnalysisContextValue = {
  result: ApiResponse | null;
  setResult: (result: ApiResponse) => void;
  clearResult: () => void;
};

const AnalysisContext = createContext<AnalysisContextValue | undefined>(
  undefined,
);

export function AnalysisProvider({ children }: { children: React.ReactNode }) {
  const [result, setResult] = useState<ApiResponse | null>(null);
  return (
    <AnalysisContext.Provider
      value={{ result, setResult, clearResult: () => setResult(null) }}
    >
      {children}
    </AnalysisContext.Provider>
  );
}

export function useAnalysis() {
  const context = useContext(AnalysisContext);
  if (!context)
    throw new Error("useAnalysis must be used inside AnalysisProvider");
  return context;
}
