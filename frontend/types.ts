export type TrafficLight = 'Red' | 'Yellow' | 'Green';

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
  traffic_light: TrafficLight;
  details: Additive;
}

export interface ApiResponse {
  status: string;
  additives_found: number;
  overall_risk_score: number;
  overall_traffic_light: TrafficLight;
  results: ScanResult[];
}
