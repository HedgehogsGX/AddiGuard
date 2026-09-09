import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';

export default function Layout() {
  return (
    <>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: {
            backgroundColor: '#4CAF50', // Medical Green
          },
          headerTintColor: '#fff',
          headerTitleStyle: {
            fontWeight: 'bold',
          },
        }}
      >
        <Stack.Screen 
          name="index" 
          options={{ 
            title: 'Scan Ingredients',
            headerShown: false, // Custom overlay header on camera
          }} 
        />
        <Stack.Screen 
          name="result" 
          options={{ 
            title: 'Analysis Result',
            headerBackTitle: 'Scan',
          }} 
        />
      </Stack>
    </>
  );
}
