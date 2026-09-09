import axios, { AxiosError } from "axios";
import { ApiResponse, ScanResult, TrafficLight } from "../types";

const API_URL = (
  process.env.EXPO_PUBLIC_API_URL || "http://localhost:5000/api"
).replace(/\/$/, "");

function isTrafficLight(value: unknown): value is TrafficLight {
  return value === "Red" || value === "Yellow" || value === "Green";
}

function isNullableText(value: unknown): value is string | null {
  return value === null || typeof value === "string";
}

function isNullableLevel(value: unknown): value is number | null {
  return (
    value === null ||
    (typeof value === "number" &&
      Number.isInteger(value) &&
      value >= 1 &&
      value <= 10)
  );
}

function isValidResponse(value: unknown): value is ApiResponse {
  if (!value || typeof value !== "object") return false;
  const response = value as Record<string, unknown>;
  if (
    response.status !== "success" ||
    !Number.isInteger(response.additives_found) ||
    !Array.isArray(response.results) ||
    response.additives_found !== response.results.length
  )
    return false;
  return response.results.every((item): item is ScanResult => {
    if (!item || typeof item !== "object") return false;
    const result = item as ScanResult;
    if (
      typeof result.name !== "string" ||
      !result.name.trim() ||
      (result.risk_score !== null &&
        (typeof result.risk_score !== "number" ||
          !Number.isFinite(result.risk_score) ||
          result.risk_score < 0 ||
          result.risk_score > 1))
    )
      return false;
    if (result.traffic_light !== null && !isTrafficLight(result.traffic_light))
      return false;
    if ((result.risk_score === null) !== (result.traffic_light === null))
      return false;
    if (
      result.risk_score !== null &&
      ((result.risk_score > 0.7 && result.traffic_light !== "Red") ||
        (result.risk_score >= 0.4 &&
          result.risk_score <= 0.7 &&
          result.traffic_light !== "Yellow") ||
        (result.risk_score < 0.4 && result.traffic_light !== "Green"))
    )
      return false;
    if (!result.details || typeof result.details !== "object") return false;
    const details = result.details;
    return (
      typeof details.name === "string" &&
      details.name.trim().length > 0 &&
      isNullableText(details.description) &&
      isNullableText(details.health_risk) &&
      isNullableText(details.usage_limit) &&
      isNullableLevel(details.toxicity_level) &&
      isNullableLevel(details.exposure_level) &&
      isNullableLevel(details.sensitivity_level) &&
      isNullableLevel(details.cumulative_level)
    );
  });
}

export class ScanApiError extends Error {}

export const analyzeImage = async (imageUri: string): Promise<ApiResponse> => {
  const formData = new FormData();
  if (typeof document !== "undefined") {
    const blob = await fetch(imageUri).then((response) => {
      if (!response.ok)
        throw new ScanApiError("Could not read the captured image.");
      return response.blob();
    });
    formData.append(
      "image",
      blob,
      "scan." + (blob.type.split("/")[1] || "jpg"),
    );
  } else {
    formData.append("image", {
      uri: imageUri,
      name: "scan.jpg",
      type: "image/jpeg",
    } as unknown as Blob);
  }

  try {
    const response = await axios.post(`${API_URL}/scan`, formData, {
      timeout: 65000,
    });
    if (!isValidResponse(response.data))
      throw new ScanApiError("The server returned invalid analysis data.");
    return response.data;
  } catch (error) {
    if (error instanceof ScanApiError) throw error;
    const axiosError = error as AxiosError<{ error?: string }>;
    const message = axiosError.response?.data?.error;
    throw new ScanApiError(
      typeof message === "string" ? message : "Scan failed. Please try again.",
    );
  }
};
