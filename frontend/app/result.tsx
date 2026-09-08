import React, { useState } from "react";
import {
  FlatList,
  Modal,
  ScrollView,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
} from "react-native";
import { useRouter } from "expo-router";
import { Ionicons } from "@expo/vector-icons";
import { SafeAreaView } from "react-native-safe-area-context";
import { ScanResult, TrafficLight } from "../types";
import { useAnalysis } from "../services/analysisContext";

const colors: Record<TrafficLight, string> = {
  Red: "#E53935",
  Yellow: "#FFB300",
  Green: "#4CAF50",
};
const assessedColor = "#607D8B";

function riskColor(result: ScanResult) {
  return result.traffic_light ? colors[result.traffic_light] : assessedColor;
}

function riskLabel(result: ScanResult) {
  return result.traffic_light ? `${result.traffic_light} risk` : "Not assessed";
}

function display(value: string | number | null) {
  return value === null ? "Not provided by API" : String(value);
}

export default function ResultScreen() {
  const router = useRouter();
  const { result } = useAnalysis();
  const [selectedItem, setSelectedItem] = useState<ScanResult | null>(null);
  const results = result?.results ?? [];

  if (!result) {
    return (
      <SafeAreaView style={styles.emptyPage}>
        <Ionicons name="scan-outline" size={64} color="#90A4AE" />
        <Text style={styles.emptyTitle}>No analysis available</Text>
        <Text style={styles.emptyText}>
          Capture an ingredient label to see results.
        </Text>
        <TouchableOpacity
          style={styles.rescanButton}
          onPress={() => router.replace("/")}
        >
          <Text style={styles.rescanText}>Scan Again</Text>
        </TouchableOpacity>
      </SafeAreaView>
    );
  }

  return (
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={["top"]}>
        <View style={styles.header}>
          <TouchableOpacity
            style={styles.backButton}
            onPress={() => router.replace("/")}
          >
            <Ionicons name="arrow-back" size={24} color="#263238" />
          </TouchableOpacity>
          <Text style={styles.headerTitle}>Analysis Report</Text>
          <Text style={styles.headerSubtitle}>
            {results.length
              ? `${results.length} ingredient${results.length === 1 ? "" : "s"} detected`
              : "No additives identified"}
          </Text>
        </View>
        <View style={styles.listContainer}>
          {results.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons
                name="checkmark-circle-outline"
                size={64}
                color="#90A4AE"
              />
              <Text style={styles.emptyTitle}>No additives detected</Text>
              <Text style={styles.emptyText}>
                This is not a safety assessment.
              </Text>
            </View>
          ) : (
            <FlatList
              data={results}
              keyExtractor={(item, index) => `${item.name}-${index}`}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.card}
                  onPress={() => setSelectedItem(item)}
                >
                  <View
                    style={[
                      styles.badgeContainer,
                      { backgroundColor: riskColor(item) },
                    ]}
                  >
                    <Ionicons
                      name={
                        item.traffic_light === "Red"
                          ? "warning"
                          : "information-circle"
                      }
                      size={24}
                      color="white"
                    />
                  </View>
                  <View style={styles.cardContent}>
                    <Text style={styles.additiveName}>{item.name}</Text>
                    <Text
                      style={[styles.riskScore, { color: riskColor(item) }]}
                    >
                      {riskLabel(item)}
                      {item.risk_score === null
                        ? ""
                        : ` · ${item.risk_score.toFixed(2)}`}
                    </Text>
                    <Text style={styles.description} numberOfLines={2}>
                      {display(item.details.description)}
                    </Text>
                  </View>
                  <Ionicons name="chevron-forward" size={20} color="#90A4AE" />
                </TouchableOpacity>
              )}
              contentContainerStyle={styles.listContent}
            />
          )}
        </View>
      </SafeAreaView>
      <Modal
        visible={selectedItem !== null}
        animationType="slide"
        transparent
        onRequestClose={() => setSelectedItem(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <TouchableOpacity
              style={styles.closeButton}
              onPress={() => setSelectedItem(null)}
            >
              <Ionicons name="close-circle" size={30} color="#90A4AE" />
            </TouchableOpacity>
            {selectedItem && (
              <ScrollView contentContainerStyle={styles.modalScroll}>
                <Text style={styles.modalTitle}>{selectedItem.name}</Text>
                <View
                  style={[
                    styles.riskBadge,
                    { backgroundColor: riskColor(selectedItem) },
                  ]}
                >
                  <Text style={styles.riskBadgeText}>
                    {riskLabel(selectedItem)}
                  </Text>
                </View>
                <Detail
                  title="Description"
                  value={selectedItem.details.description}
                />
                <Detail
                  title="Health impact"
                  value={selectedItem.details.health_risk}
                />
                <Detail
                  title="Usage limits"
                  value={selectedItem.details.usage_limit}
                />
                <Text style={styles.sectionTitle}>Risk factors</Text>
                <Factor
                  label="Toxicity"
                  value={selectedItem.details.toxicity_level}
                />
                <Factor
                  label="Exposure"
                  value={selectedItem.details.exposure_level}
                />
                <Factor
                  label="Sensitivity"
                  value={selectedItem.details.sensitivity_level}
                />
                <Factor
                  label="Cumulative"
                  value={selectedItem.details.cumulative_level}
                />
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

function Detail({ title, value }: { title: string; value: string | null }) {
  return (
    <View style={styles.section}>
      <Text style={styles.sectionTitle}>{title}</Text>
      <Text style={styles.sectionText}>{display(value)}</Text>
    </View>
  );
}

function Factor({ label, value }: { label: string; value: number | null }) {
  return (
    <View style={styles.factorRow}>
      <Text style={styles.factorLabel}>{label}</Text>
      <Text style={styles.factorValue}>
        {value === null ? "Not provided by API" : `${value}/10`}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: "#F2F4F8" },
  safeArea: { flex: 1 },
  header: {
    padding: 24,
    alignItems: "center",
    backgroundColor: "#E8F5E9",
    borderBottomLeftRadius: 24,
    borderBottomRightRadius: 24,
  },
  backButton: { position: "absolute", top: 20, left: 20, padding: 8 },
  headerTitle: { color: "#263238", fontSize: 24, fontWeight: "700" },
  headerSubtitle: { color: "#546E7A", marginTop: 8 },
  listContainer: { flex: 1, paddingHorizontal: 20, paddingTop: 20 },
  listContent: { paddingBottom: 40 },
  card: {
    backgroundColor: "white",
    borderRadius: 14,
    marginBottom: 14,
    padding: 16,
    flexDirection: "row",
    alignItems: "center",
    elevation: 2,
  },
  badgeContainer: {
    width: 46,
    height: 46,
    borderRadius: 12,
    justifyContent: "center",
    alignItems: "center",
    marginRight: 14,
  },
  cardContent: { flex: 1, marginRight: 8 },
  additiveName: {
    fontSize: 17,
    fontWeight: "700",
    color: "#263238",
    marginBottom: 5,
  },
  riskScore: {
    fontSize: 13,
    fontWeight: "700",
    textTransform: "capitalize",
    marginBottom: 5,
  },
  description: { color: "#546E7A", fontSize: 14 },
  emptyPage: {
    flex: 1,
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
    backgroundColor: "#F2F4F8",
  },
  emptyState: { alignItems: "center", justifyContent: "center", padding: 28 },
  emptyTitle: {
    fontSize: 20,
    fontWeight: "700",
    color: "#37474F",
    marginTop: 14,
    textAlign: "center",
  },
  emptyText: { color: "#607D8B", textAlign: "center", marginTop: 8 },
  rescanButton: {
    marginTop: 22,
    backgroundColor: "#4CAF50",
    borderRadius: 22,
    paddingVertical: 12,
    paddingHorizontal: 26,
  },
  rescanText: { color: "#fff", fontWeight: "700" },
  modalOverlay: {
    flex: 1,
    justifyContent: "flex-end",
    backgroundColor: "rgba(0,0,0,0.4)",
  },
  modalContent: {
    maxHeight: "85%",
    backgroundColor: "#fff",
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
  },
  closeButton: { alignSelf: "flex-end", padding: 14 },
  modalScroll: { padding: 22, paddingTop: 0 },
  modalTitle: {
    fontSize: 27,
    color: "#263238",
    fontWeight: "700",
    marginBottom: 12,
  },
  riskBadge: {
    alignSelf: "flex-start",
    borderRadius: 15,
    paddingHorizontal: 14,
    paddingVertical: 7,
    marginBottom: 20,
  },
  riskBadgeText: {
    color: "#fff",
    fontWeight: "700",
    textTransform: "capitalize",
  },
  section: { marginBottom: 18 },
  sectionTitle: {
    color: "#37474F",
    fontWeight: "700",
    fontSize: 16,
    marginBottom: 6,
  },
  sectionText: { color: "#546E7A", lineHeight: 21 },
  factorRow: {
    flexDirection: "row",
    justifyContent: "space-between",
    borderBottomWidth: 1,
    borderBottomColor: "#ECEFF1",
    paddingVertical: 9,
  },
  factorLabel: { color: "#607D8B" },
  factorValue: { color: "#37474F", fontWeight: "600" },
});
