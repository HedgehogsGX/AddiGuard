import Foundation

enum AnalysisSource: String, Codable, Hashable, Sendable {
    case local
    case openRouter
}

enum IngredientInsightCategory: String, Codable, Hashable, Sendable {
    case ordinaryFood = "ordinary_food"
    case foodAdditive = "food_additive"
    case allergenOrSource = "allergen_or_source"
    case compoundIngredient = "compound_ingredient"
    case uncertain

    var title: String {
        switch self {
        case .ordinaryFood: "普通食品原料"
        case .foodAdditive: "食品添加剂"
        case .allergenOrSource: "过敏原或其来源"
        case .compoundIngredient: "复合配料"
        case .uncertain: "类别待确认"
        }
    }
}

enum IngredientInsightConfidence: String, Codable, Hashable, Sendable {
    case high
    case medium
    case low

    var title: String {
        switch self {
        case .high: "较高"
        case .medium: "中等"
        case .low: "较低"
        }
    }
}

struct IngredientInsight: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let ingredient: String
    let category: IngredientInsightCategory
    let commonRole: String
    let analysis: String
    let reviewNote: String?
    let confidence: IngredientInsightConfidence
}

struct AnalysisResult: Codable, Hashable {
    let recognizedText: String
    let additives: [DetectedAdditive]
    let safetyScore: Int
    let overallRisk: RiskLevel
    let summary: String
    let ingredientTokens: [IngredientToken]
    let ingredientInsights: [IngredientInsight]
    let analysisSource: AnalysisSource

    init(
        recognizedText: String,
        additives: [DetectedAdditive],
        safetyScore: Int,
        overallRisk: RiskLevel,
        summary: String,
        ingredientTokens: [IngredientToken] = [],
        ingredientInsights: [IngredientInsight] = [],
        analysisSource: AnalysisSource = .local
    ) {
        self.recognizedText = recognizedText
        self.additives = additives
        self.safetyScore = safetyScore
        self.overallRisk = overallRisk
        self.summary = summary
        self.ingredientTokens = ingredientTokens
        self.ingredientInsights = ingredientInsights
        self.analysisSource = analysisSource
    }

    private enum CodingKeys: String, CodingKey {
        case recognizedText
        case additives
        case safetyScore
        case overallRisk
        case summary
        case ingredientTokens
        case ingredientInsights
        case analysisSource
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recognizedText = try container.decode(String.self, forKey: .recognizedText)
        additives = try container.decode([DetectedAdditive].self, forKey: .additives)
        safetyScore = try container.decode(Int.self, forKey: .safetyScore)
        overallRisk = try container.decode(RiskLevel.self, forKey: .overallRisk)
        summary = try container.decode(String.self, forKey: .summary)
        ingredientTokens = try container.decodeIfPresent(
            [IngredientToken].self,
            forKey: .ingredientTokens
        ) ?? []
        ingredientInsights = try container.decodeIfPresent(
            [IngredientInsight].self,
            forKey: .ingredientInsights
        ) ?? []
        analysisSource = try container.decodeIfPresent(
            AnalysisSource.self,
            forKey: .analysisSource
        ) ?? .local
    }

    var highRiskCount: Int { additives.filter { $0.additive.risk == .high }.count }
    var moderateRiskCount: Int { additives.filter { $0.additive.risk == .moderate }.count }
    var lowRiskCount: Int { additives.filter { $0.additive.risk == .low }.count }
    var unratedCount: Int { additives.filter { $0.additive.risk == .unrated }.count }
}

struct ScanRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let createdAt: Date
    let productName: String
    let result: AnalysisResult

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        productName: String,
        result: AnalysisResult
    ) {
        self.id = id
        self.createdAt = createdAt
        self.productName = productName
        self.result = result
    }
}
