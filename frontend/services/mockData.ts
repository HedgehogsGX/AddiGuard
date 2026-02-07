import { ApiResponse } from '../types';

export const MOCK_SCAN_RESULT: ApiResponse = {
  status: 'success',
  additives_found: 3,
  results: [
    {
      name: 'Sodium Nitrite',
      risk_score: 0.95,
      traffic_light: 'Red',
      details: {
        id: 1,
        name: 'Sodium Nitrite',
        description: 'Preservative used in cured meats to prevent botulism and maintain pink color.',
        toxicity_level: 9,
        exposure_level: 8,
        sensitivity_level: 7,
        cumulative_level: 9,
        health_risk: 'Linked to colorectal cancer; Classified as a probable carcinogen by WHO.',
        usage_limit: 'Strictly limited in meats (max 200ppm).'
      }
    },
    {
      name: 'Sodium Benzoate',
      risk_score: 0.55,
      traffic_light: 'Yellow',
      details: {
        id: 2,
        name: 'Sodium Benzoate',
        description: 'Common preservative in acidic foods like sodas and pickles.',
        toxicity_level: 6,
        exposure_level: 7,
        sensitivity_level: 5,
        cumulative_level: 4,
        health_risk: 'May cause hyperactivity in children; can form benzene (carcinogen) if mixed with Vitamin C.',
        usage_limit: '0.1% by weight in foods.'
      }
    },
    {
      name: 'Vitamin C',
      risk_score: 0.1,
      traffic_light: 'Green',
      details: {
        id: 3,
        name: 'Vitamin C',
        description: 'Ascorbic Acid, used as an antioxidant and nutrient supplement.',
        toxicity_level: 1,
        exposure_level: 1,
        sensitivity_level: 1,
        cumulative_level: 1,
        health_risk: 'Generally safe; beneficial for immune system.',
        usage_limit: 'None (GRAS).'
      }
    }
  ]
};
