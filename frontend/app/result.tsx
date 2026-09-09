import React, { useState } from 'react';
import { StyleSheet, Text, View, FlatList, TouchableOpacity, Modal, ScrollView, Dimensions } from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { ApiResponse, ScanResult } from '../types';
import { SafeAreaView } from 'react-native-safe-area-context';
import { Ionicons } from '@expo/vector-icons';

const { height: SCREEN_HEIGHT } = Dimensions.get('window');

export default function ResultScreen() {
  const params = useLocalSearchParams();
  const router = useRouter();
  const [selectedItem, setSelectedItem] = useState<ScanResult | null>(null);
  
  let data: ApiResponse | null = null;
  
  try {
    if (params.data) {
      data = JSON.parse(params.data as string);
    }
  } catch (e) {
    console.error("Failed to parse results", e);
  }

  const results = data?.results || [];
  const totalRiskScore = results.length > 0 
    ? Math.max(...results.map(r => r.risk_score)) 
    : 0;

  const getTrafficColor = (score: number) => {
    if (score > 0.7) return '#E53935'; // Red
    if (score >= 0.4) return '#FFB300'; // Yellow
    return '#4CAF50'; // Green
  };

  const getTrafficLabel = (score: number) => {
    if (score > 0.7) return 'HIGH RISK';
    if (score >= 0.4) return 'MEDIUM RISK';
    return 'LOW RISK';
  };

  const overallColor = getTrafficColor(totalRiskScore);

  const renderItem = ({ item }: { item: ScanResult }) => {
    const isHighRisk = item.risk_score > 0.7;
    const badgeColor = getTrafficColor(item.risk_score);

    return (
      <TouchableOpacity 
        style={styles.card} 
        onPress={() => setSelectedItem(item)}
        activeOpacity={0.7}
      >
        <View style={[styles.badgeContainer, { backgroundColor: badgeColor }]}>
           <Ionicons 
            name={isHighRisk ? "warning" : "checkmark-circle"} 
            size={24} 
            color="white" 
          />
        </View>
        <View style={styles.cardContent}>
          <View style={styles.cardHeader}>
            <Text style={styles.additiveName}>{item.name}</Text>
            {isHighRisk && <Ionicons name="alert-circle" size={20} color="#E53935" />}
          </View>
          <Text style={styles.riskScore}>Risk Level: {item.traffic_light}</Text>
          <Text style={styles.description} numberOfLines={2}>{item.details.description}</Text>
        </View>
        <Ionicons name="chevron-forward" size={20} color="#ccc" style={{ alignSelf: 'center' }} />
      </TouchableOpacity>
    );
  };

  return (
    <View style={styles.container}>
      <SafeAreaView style={styles.safeArea} edges={['top']}>
        {/* Header Summary */}
        <View style={[styles.header, { backgroundColor: overallColor }]}>
           <TouchableOpacity 
            style={styles.backButton} 
            onPress={() => router.back()}
          >
            <Ionicons name="arrow-back" size={24} color="white" />
          </TouchableOpacity>
          
          <Text style={styles.headerTitle}>Analysis Report</Text>
          
          <View style={styles.scoreContainer}>
            <Text style={styles.headerScore}>{totalRiskScore.toFixed(2)}</Text>
            <Text style={styles.headerScoreLabel}>/ 1.0</Text>
          </View>
          <Text style={styles.headerLabel}>{getTrafficLabel(totalRiskScore)}</Text>
        </View>

        <View style={styles.listContainer}>
          <Text style={styles.listTitle}>Detected Additives ({results.length})</Text>
          {results.length === 0 ? (
            <View style={styles.emptyState}>
              <Ionicons name="scan-outline" size={64} color="#ccc" />
              <Text style={styles.emptyText}>No additives detected.</Text>
              <TouchableOpacity style={styles.rescanButton} onPress={() => router.back()}>
                <Text style={styles.rescanText}>Scan Again</Text>
              </TouchableOpacity>
            </View>
          ) : (
            <FlatList
              data={results}
              renderItem={renderItem}
              keyExtractor={(item, index) => `${item.name}-${index}`}
              contentContainerStyle={styles.listContent}
              showsVerticalScrollIndicator={false}
            />
          )}
        </View>
      </SafeAreaView>

      {/* Detail Modal (Bottom Sheet Style) */}
      <Modal
        visible={selectedItem !== null}
        animationType="slide"
        transparent={true}
        onRequestClose={() => setSelectedItem(null)}
      >
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <View style={styles.modalHandle} />
              <TouchableOpacity 
                style={styles.closeButton} 
                onPress={() => setSelectedItem(null)}
              >
                <Ionicons name="close-circle" size={30} color="#ddd" />
              </TouchableOpacity>
            </View>
            
            {selectedItem && (
              <ScrollView contentContainerStyle={styles.modalScroll}>
                <Text style={styles.modalTitle}>{selectedItem.name}</Text>
                
                <View style={[styles.riskBadge, { backgroundColor: getTrafficColor(selectedItem.risk_score) }]}>
                  <Text style={styles.riskBadgeText}>{selectedItem.traffic_light} Risk</Text>
                </View>

                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>Description</Text>
                  <Text style={styles.sectionText}>{selectedItem.details.description}</Text>
                </View>

                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>⚠️ Health Impact</Text>
                  <Text style={styles.sectionText}>{selectedItem.details.health_risk || 'No significant health risks reported.'}</Text>
                </View>

                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>⚖️ Usage Limits</Text>
                  <Text style={styles.sectionText}>{selectedItem.details.usage_limit || 'No specific limits.'}</Text>
                </View>

                <View style={styles.section}>
                  <Text style={styles.sectionTitle}>Risk Factors</Text>
                  <View style={styles.factorRow}>
                    <Text style={styles.factorLabel}>Toxicity:</Text>
                    <Text style={styles.factorValue}>{selectedItem.details.toxicity_level}/10</Text>
                  </View>
                  <View style={styles.factorRow}>
                    <Text style={styles.factorLabel}>Exposure:</Text>
                    <Text style={styles.factorValue}>{selectedItem.details.exposure_level}/10</Text>
                  </View>
                </View>
              </ScrollView>
            )}
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F2F4F8',
  },
  safeArea: {
    flex: 1,
  },
  header: {
    padding: 24,
    alignItems: 'center',
    borderBottomLeftRadius: 30,
    borderBottomRightRadius: 30,
    marginBottom: 20,
    shadowColor: "#000",
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.1,
    shadowRadius: 10,
    elevation: 5,
  },
  backButton: {
    position: 'absolute',
    top: 20,
    left: 20,
    padding: 8,
  },
  headerTitle: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 14,
    fontWeight: '600',
    marginTop: 10,
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  scoreContainer: {
    flexDirection: 'row',
    alignItems: 'baseline',
    marginTop: 10,
  },
  headerScore: {
    color: 'white',
    fontSize: 56,
    fontWeight: '800',
  },
  headerScoreLabel: {
    color: 'rgba(255,255,255,0.8)',
    fontSize: 20,
    marginLeft: 4,
  },
  headerLabel: {
    color: 'white',
    fontSize: 24,
    fontWeight: 'bold',
    marginTop: 4,
    letterSpacing: 0.5,
  },
  listContainer: {
    flex: 1,
    paddingHorizontal: 20,
  },
  listTitle: {
    fontSize: 18,
    fontWeight: '700',
    color: '#333',
    marginBottom: 16,
  },
  listContent: {
    paddingBottom: 40,
  },
  card: {
    backgroundColor: 'white',
    borderRadius: 16,
    marginBottom: 16,
    padding: 16,
    flexDirection: 'row',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 3,
  },
  badgeContainer: {
    width: 48,
    height: 48,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 16,
  },
  cardContent: {
    flex: 1,
    marginRight: 8,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  additiveName: {
    fontSize: 16,
    fontWeight: '700',
    color: '#1A1A1A',
    flex: 1,
  },
  riskScore: {
    fontSize: 12,
    fontWeight: '600',
    color: '#666',
    marginBottom: 4,
  },
  description: {
    fontSize: 13,
    color: '#888',
    lineHeight: 18,
  },
  emptyState: {
    alignItems: 'center',
    marginTop: 60,
  },
  emptyText: {
    fontSize: 16,
    color: '#888',
    marginTop: 16,
    marginBottom: 24,
  },
  rescanButton: {
    backgroundColor: '#4CAF50',
    paddingVertical: 14,
    paddingHorizontal: 32,
    borderRadius: 24,
    shadowColor: '#4CAF50',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 8,
  },
  rescanText: {
    color: 'white',
    fontWeight: 'bold',
    fontSize: 16,
  },
  // Modal Styles
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: 'white',
    borderTopLeftRadius: 30,
    borderTopRightRadius: 30,
    height: SCREEN_HEIGHT * 0.75,
    padding: 24,
  },
  modalHeader: {
    alignItems: 'center',
    marginBottom: 24,
  },
  modalHandle: {
    width: 40,
    height: 5,
    backgroundColor: '#E0E0E0',
    borderRadius: 3,
    marginBottom: 10,
  },
  closeButton: {
    position: 'absolute',
    right: 0,
    top: 0,
  },
  modalScroll: {
    paddingBottom: 40,
  },
  modalTitle: {
    fontSize: 28,
    fontWeight: '800',
    color: '#1A1A1A',
    marginBottom: 12,
  },
  riskBadge: {
    alignSelf: 'flex-start',
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 8,
    marginBottom: 24,
  },
  riskBadgeText: {
    color: 'white',
    fontWeight: '700',
    fontSize: 14,
  },
  section: {
    marginBottom: 24,
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#1A1A1A',
    marginBottom: 8,
  },
  sectionText: {
    fontSize: 15,
    color: '#555',
    lineHeight: 24,
  },
  factorRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginBottom: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#F0F0F0',
    paddingBottom: 8,
  },
  factorLabel: {
    fontSize: 14,
    color: '#666',
  },
  factorValue: {
    fontSize: 14,
    fontWeight: '600',
    color: '#333',
  },
});
