import { Stack } from "expo-router";
import { StatusBar } from "expo-status-bar";
import { AnalysisProvider } from "../services/analysisContext";

export default function Layout() {
  return (
    <AnalysisProvider>
      <StatusBar style="light" />
      <Stack
        screenOptions={{
          headerStyle: { backgroundColor: "#4CAF50" },
          headerTintColor: "#fff",
          headerTitleStyle: { fontWeight: "bold" },
        }}
      >
        <Stack.Screen
          name="index"
          options={{ title: "Scan Ingredients", headerShown: false }}
        />
        <Stack.Screen
          name="result"
          options={{ title: "Analysis Result", headerBackTitle: "Scan" }}
        />
      </Stack>
    </AnalysisProvider>
  );
}
