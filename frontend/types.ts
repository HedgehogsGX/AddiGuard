export type TrafficLight = 'Red' | 'Yellow' | 'Green' | 'Unrated';

export interface Additive {
  id: number;
  name: string;
  e_number: string | null;
  aliases: string[];
  description: string | null;
  toxicity_level: number | null;
  exposure_level: number | null;
  sensitivity_level: number | null;
  cumulative_level: number | null;
  health_risk: string | null;
  usage_limit: string | null;
}

export interface ScanResult {
  name: string;
  matched_text: string;
  risk_score: number | null;
  traffic_light: TrafficLight;
  details: Additive;
}

export interface ApiResponse {
  status: string;
  additives_found: number;
  overall_risk_score: number | null;
  overall_traffic_light: TrafficLight;
  results: ScanResult[];
}
