import { ApiResponse } from '../types';

export const MOCK_SCAN_RESULT: ApiResponse = {
  status: 'success',
  additives_found: 4,
  overall_risk_score: 0.83,
  overall_traffic_light: 'Red',
  results: [
    {
      name: 'Sodium Nitrite',
      matched_text: 'e250',
      risk_score: 0.83,
      traffic_light: 'Red',
      details: {
        id: 1,
        name: 'Sodium Nitrite',
        e_number: 'E250',
        aliases: ['sodium nitrite'],
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
      matched_text: 'sodium benzoate',
      risk_score: 0.59,
      traffic_light: 'Yellow',
      details: {
        id: 2,
        name: 'Sodium Benzoate',
        e_number: 'E211',
        aliases: ['sodium benzoate'],
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
      matched_text: 'ascorbic acid',
      risk_score: 0.1,
      traffic_light: 'Green',
      details: {
        id: 3,
        name: 'Vitamin C',
        e_number: 'E300',
        aliases: ['ascorbic acid', 'vitamin c'],
        description: 'Ascorbic Acid, used as an antioxidant and nutrient supplement.',
        toxicity_level: 1,
        exposure_level: 1,
        sensitivity_level: 1,
        cumulative_level: 1,
        health_risk: 'Generally safe; beneficial for immune system.',
        usage_limit: 'None (GRAS).'
      }
    },
    {
      name: 'Citric acid',
      matched_text: 'e330',
      risk_score: null,
      traffic_light: 'Unrated',
      details: {
        id: 6,
        name: 'Citric acid',
        e_number: 'E330',
        aliases: ['citric acid'],
        description: null,
        toxicity_level: null,
        exposure_level: null,
        sensitivity_level: null,
        cumulative_level: null,
        health_risk: null,
        usage_limit: null,
      },
    }
  ]
};
