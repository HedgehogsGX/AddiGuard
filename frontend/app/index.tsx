import React, { useRef, useState } from "react";
import {
  ActivityIndicator,
  Alert,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { CameraView, useCameraPermissions } from "expo-camera";
import { useRouter } from "expo-router";
import { SafeAreaView } from "react-native-safe-area-context";
import { analyzeImage, ScanApiError } from "../services/api";
import { useAnalysis } from "../services/analysisContext";

export default function CameraScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanning, setScanning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const cameraRef = useRef<CameraView>(null);
  const router = useRouter();
  const { setResult, clearResult } = useAnalysis();

  if (!permission) {
    return (
      <View style={styles.center}>
        <ActivityIndicator size="large" color="#4CAF50" />
        <Text style={styles.message}>Initializing Camera...</Text>
      </View>
    );
  }
  if (!permission.granted) {
    return (
      <View style={styles.center}>
        <Text style={styles.message}>
          We need your permission to show the camera
        </Text>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const takePicture = async () => {
    if (scanning || !cameraRef.current) return;
    setScanning(true);
    setError(null);
    clearResult();
    try {
      const photo = await cameraRef.current.takePictureAsync({
        quality: 0.7,
        base64: false,
      });
      if (!photo?.uri) throw new ScanApiError("Could not capture an image.");
      const result = await analyzeImage(photo.uri);
      setResult(result);
      router.push("/result");
    } catch (cause) {
      const message =
        cause instanceof ScanApiError
          ? cause.message
          : "Failed to capture or analyze image.";
      setError(message);
      Alert.alert("Scan Failed", message);
    } finally {
      setScanning(false);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView style={styles.camera} facing="back" ref={cameraRef}>
        <SafeAreaView style={styles.overlayContainer}>
          <View style={styles.overlayMiddle}>
            <View style={styles.overlaySide} />
            <View style={styles.scanFrame}>
              <View style={[styles.corner, styles.topLeft]} />
              <View style={[styles.corner, styles.topRight]} />
              <View style={[styles.corner, styles.bottomLeft]} />
              <View style={[styles.corner, styles.bottomRight]} />
            </View>
            <View style={styles.overlaySide} />
          </View>
          <View style={styles.overlayBottom}>
            {error && <Text style={styles.errorText}>{error}</Text>}
            <TouchableOpacity
              style={[
                styles.captureButton,
                scanning && styles.captureButtonDisabled,
              ]}
              onPress={takePicture}
              disabled={scanning}
            >
              {scanning ? (
                <ActivityIndicator color="#fff" size="large" />
              ) : (
                <Text style={styles.captureText}>Snap & Analyze</Text>
              )}
            </TouchableOpacity>
            <Text style={styles.hintText}>
              Align ingredients within the frame
            </Text>
          </View>
        </SafeAreaView>
      </CameraView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#000" },
  center: {
    flex: 1,
    backgroundColor: "#000",
    alignItems: "center",
    justifyContent: "center",
  },
  message: { textAlign: "center", paddingBottom: 10, color: "white" },
  button: {
    alignSelf: "center",
    backgroundColor: "#4CAF50",
    padding: 15,
    borderRadius: 8,
  },
  buttonText: { color: "white", fontWeight: "bold" },
  camera: { flex: 1 },
  overlayContainer: { flex: 1 },
  overlayMiddle: { flexDirection: "row", height: 250 },
  overlaySide: { flex: 1, backgroundColor: "rgba(0,0,0,0.5)" },
  scanFrame: { width: 300, height: 250, position: "relative" },
  overlayBottom: {
    flex: 1.5,
    backgroundColor: "rgba(0,0,0,0.5)",
    alignItems: "center",
    paddingTop: 40,
  },
  errorText: {
    color: "#ffcdd2",
    textAlign: "center",
    marginHorizontal: 24,
    marginBottom: 12,
  },
  captureButton: {
    backgroundColor: "#4CAF50",
    paddingVertical: 15,
    paddingHorizontal: 40,
    borderRadius: 30,
    marginBottom: 20,
  },
  captureButtonDisabled: { backgroundColor: "#888" },
  captureText: { color: "#fff", fontSize: 18, fontWeight: "bold" },
  hintText: { color: "#ddd", fontSize: 14 },
  corner: {
    position: "absolute",
    width: 20,
    height: 20,
    borderColor: "#4CAF50",
    borderWidth: 3,
  },
  topLeft: { top: 0, left: 0, borderRightWidth: 0, borderBottomWidth: 0 },
  topRight: { top: 0, right: 0, borderLeftWidth: 0, borderBottomWidth: 0 },
  bottomLeft: { bottom: 0, left: 0, borderRightWidth: 0, borderTopWidth: 0 },
  bottomRight: { bottom: 0, right: 0, borderLeftWidth: 0, borderTopWidth: 0 },
});
