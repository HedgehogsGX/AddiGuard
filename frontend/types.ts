export type TrafficLight = "Red" | "Yellow" | "Green";

export interface AdditiveDetails {
  name: string;
  description: string | null;
  health_risk: string | null;
  usage_limit: string | null;
  toxicity_level: number | null;
  exposure_level: number | null;
  sensitivity_level: number | null;
  cumulative_level: number | null;
}

export interface ScanResult {
  name: string;
  risk_score: number | null;
  traffic_light: TrafficLight | null;
  details: AdditiveDetails;
}

export interface ApiResponse {
  status: "success";
  additives_found: number;
  results: ScanResult[];
}
