import React, { useState, useRef } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, ActivityIndicator, Alert, Switch } from 'react-native';
import { CameraView, CameraType, useCameraPermissions } from 'expo-camera';
import { useRouter } from 'expo-router';
import { analyzeImage } from '../services/api';
import { MOCK_SCAN_RESULT } from '../services/mockData';
import { ApiResponse } from '../types';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function CameraScreen() {
  const [permission, requestPermission] = useCameraPermissions();
  const [scanning, setScanning] = useState(false);
  const [isMockMode, setIsMockMode] = useState(false);
  const cameraRef = useRef<CameraView>(null);
  const router = useRouter();

  if (!permission) {
    return (
      <View style={[styles.container, { alignItems: 'center', justifyContent: 'center' }]}>
        <ActivityIndicator size="large" color="#4CAF50" />
        <Text style={{ color: 'white', marginTop: 10 }}>Initializing Camera...</Text>
      </View>
    );
  }

  if (!permission.granted) {
    return (
      <View style={styles.container}>
        <Text style={styles.message}>We need your permission to show the camera</Text>
        <TouchableOpacity onPress={requestPermission} style={styles.button}>
          <Text style={styles.buttonText}>Grant Permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  const takePicture = async () => {
    if (scanning) return;
    setScanning(true);

    try {
      let result: ApiResponse;
      if (isMockMode) {
        await new Promise(resolve => setTimeout(resolve, 1500));
        result = MOCK_SCAN_RESULT;
      } else {
        const photo = await cameraRef.current?.takePictureAsync({ quality: 0.7 });
        if (!photo?.uri) throw new Error('Could not capture a photo.');
        result = await analyzeImage(photo.uri);
      }

      router.push({
        pathname: '/result',
        params: { data: JSON.stringify(result) }
      });
    } catch (error) {
      Alert.alert('Scan Failed', error instanceof Error ? error.message : 'Failed to capture or analyze image.');
    } finally {
      setScanning(false);
    }
  };

  return (
    <View style={styles.container}>
      <CameraView 
        style={styles.camera} 
        facing="back"
        ref={cameraRef}
      >
        <SafeAreaView style={styles.overlayContainer}>
          {__DEV__ && (
            <View style={styles.headerControls}>
              <View style={styles.mockToggleContainer}>
                <Text style={styles.mockLabel}>Mock Mode</Text>
                <Switch
                  value={isMockMode}
                  onValueChange={setIsMockMode}
                  trackColor={{ false: "#767577", true: "#81b0ff" }}
                  thumbColor={isMockMode ? "#f5dd4b" : "#f4f3f4"}
                />
              </View>
            </View>
          )}

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
             <TouchableOpacity 
              style={[styles.captureButton, scanning && styles.captureButtonDisabled]}
              onPress={takePicture}
              disabled={scanning}
            >
              {scanning ? (
                <ActivityIndicator color="#fff" size="large" />
              ) : (
                <Text style={styles.captureText}>Snap & Analyze</Text>
              )}
            </TouchableOpacity>
            <Text style={styles.hintText}>Align ingredients within the frame</Text>
          </View>
        </SafeAreaView>
      </CameraView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#000',
    justifyContent: 'center',
  },
  message: {
    textAlign: 'center',
    paddingBottom: 10,
    color: 'white',
  },
  button: {
    alignSelf: 'center',
    backgroundColor: '#4CAF50',
    padding: 15,
    borderRadius: 8,
  },
  buttonText: {
    color: 'white',
    fontWeight: 'bold',
  },
  camera: {
    flex: 1,
  },
  overlayContainer: {
    flex: 1,
  },
  overlayTop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  headerControls: {
    position: 'absolute',
    top: 50,
    right: 20,
    zIndex: 10,
  },
  mockToggleContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(0,0,0,0.6)',
    padding: 8,
    borderRadius: 20,
  },
  mockLabel: {
    color: 'white',
    marginRight: 8,
    fontSize: 12,
    fontWeight: 'bold',
  },
  overlayMiddle: {
    flexDirection: 'row',
    height: 250, 
  },
  overlaySide: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
  },
  scanFrame: {
    width: 300,
    height: 250,
    borderColor: 'transparent', 
    position: 'relative',
  },
  overlayBottom: {
    flex: 1.5,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    paddingTop: 40,
  },
  captureButton: {
    backgroundColor: '#4CAF50',
    paddingVertical: 15,
    paddingHorizontal: 40,
    borderRadius: 30,
    marginBottom: 20,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.3,
    shadowRadius: 4,
  },
  captureButtonDisabled: {
    backgroundColor: '#888',
  },
  captureText: {
    color: '#fff',
    fontSize: 18,
    fontWeight: 'bold',
  },
  hintText: {
    color: '#ddd',
    fontSize: 14,
  },
  corner: {
    position: 'absolute',
    width: 20,
    height: 20,
    borderColor: '#4CAF50',
    borderWidth: 3,
  },
  topLeft: { top: 0, left: 0, borderRightWidth: 0, borderBottomWidth: 0 },
  topRight: { top: 0, right: 0, borderLeftWidth: 0, borderBottomWidth: 0 },
  bottomLeft: { bottom: 0, left: 0, borderRightWidth: 0, borderTopWidth: 0 },
  bottomRight: { bottom: 0, right: 0, borderLeftWidth: 0, borderTopWidth: 0 },
});
