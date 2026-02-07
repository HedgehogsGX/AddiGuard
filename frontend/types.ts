export interface Additive {
  id: number;
  name: string;
  description: string;
  toxicity_level: number;
  exposure_level: number;
  sensitivity_level: number;
  cumulative_level: number;
  health_risk: string;
  usage_limit: string;
}

export interface ScanResult {
  name: string;
  risk_score: number;
  traffic_light: 'Red' | 'Yellow' | 'Green';
  details: Additive;
}

export interface ApiResponse {
  status: string;
  additives_found: number;
  results: ScanResult[];
  error?: string;
}
