import Foundation
import Observation
import OSLog

@MainActor
@Observable
final class ScanStore {
    private enum LegacyKeys {
        static let records = "addiguard.scan-records"
        static let profile = "addiguard.user-profile"
    }

    private static let maximumSavedRecords = 100

    @ObservationIgnored private let persistence = ScanPersistence()
    @ObservationIgnored private var persistenceRevision = 0
    @ObservationIgnored private var isRestoring = true
    @ObservationIgnored private let logger = Logger(
        subsystem: "com.addiguard.app",
        category: "ScanStore"
    )

    var records: [ScanRecord] = [] {
        didSet { schedulePersistence() }
    }
    var profile = UserProfile() {
        didSet { schedulePersistence() }
    }
    var analysisMode: AnalysisMode = .offline {
        didSet { schedulePersistence() }
    }
    var onlineAnalysisConsentVersion: Int? {
        didSet { schedulePersistence() }
    }
    private(set) var persistenceErrorMessage: String?

    init() {
        do {
            if let state = try ScanPersistence.load() {
                records = Array(
                    state.records.prefix(Self.maximumSavedRecords).map(Self.redactedForPersistence)
                )
                profile = state.profile
                analysisMode = state.analysisMode
                onlineAnalysisConsentVersion = state.onlineAnalysisConsentVersion
            } else {
                restoreLegacyUserDefaultsIfNeeded()
            }
        } catch {
            persistenceErrorMessage = "本地数据读取失败，旧文件已保留。"
            logger.error("Failed to load local state: \(error.localizedDescription, privacy: .public)")
        }
        isRestoring = false
    }

    @discardableResult
    func analyzeAndSave(text: String, productName: String = "配料表扫描") -> ScanRecord {
        let result = IngredientAnalyzer.analyze(text: text, profile: profile)
        return save(result: result, productName: productName)
    }

    /// Returns the transient full result for immediate navigation, while history
    /// receives a redacted copy from the moment it enters the store.
    @discardableResult
    func save(result: AnalysisResult, productName: String = "配料表扫描") -> ScanRecord {
        let record = ScanRecord(productName: productName, result: result)
        records.insert(Self.redactedForPersistence(record), at: 0)
        if records.count > Self.maximumSavedRecords {
            records.removeLast(records.count - Self.maximumSavedRecords)
        }
        return record
    }

    func record(id: UUID) -> ScanRecord? {
        records.first { $0.id == id }
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
    }

    func clearHistory() {
        records.removeAll()
    }

    func clearAllLocalData() {
        isRestoring = true
        records = []
        profile = UserProfile()
        analysisMode = .offline
        onlineAnalysisConsentVersion = nil
        isRestoring = false
        persistenceErrorMessage = nil

        persistenceRevision += 1
        let revision = persistenceRevision
        Task {
            do {
                try await persistence.delete(revision: revision)
                Self.removeLegacyUserDefaults()
                OpenRouterConfiguration.clearLocalDevelopmentCredential()
                guard revision == persistenceRevision else { return }
            } catch {
                guard revision == persistenceRevision else { return }
                persistenceErrorMessage = "无法清除本地数据，请稍后重试。"
                logger.error("Failed to clear local state: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func dismissPersistenceError() {
        persistenceErrorMessage = nil
    }

    private func restoreLegacyUserDefaultsIfNeeded() {
        let decoder = JSONDecoder()
        var migratedRecords: [ScanRecord] = []
        var migratedProfile = UserProfile()
        var foundLegacyData = false

        if let data = UserDefaults.standard.data(forKey: LegacyKeys.records) {
            foundLegacyData = true
            do {
                migratedRecords = try decoder.decode([ScanRecord].self, from: data)
            } catch {
                persistenceErrorMessage = "旧版扫描记录无法迁移，原数据仍保留。"
                logger.error("Failed to decode legacy records: \(error.localizedDescription, privacy: .public)")
                return
            }
        }

        if let data = UserDefaults.standard.data(forKey: LegacyKeys.profile) {
            foundLegacyData = true
            do {
                migratedProfile = try decoder.decode(UserProfile.self, from: data)
            } catch {
                persistenceErrorMessage = "旧版个人设置无法迁移，原数据仍保留。"
                logger.error("Failed to decode legacy profile: \(error.localizedDescription, privacy: .public)")
                return
            }
        }

        guard foundLegacyData else { return }
        records = Array(
            migratedRecords.prefix(Self.maximumSavedRecords).map(Self.redactedForPersistence)
        )
        profile = migratedProfile

        do {
            try ScanPersistence.saveImmediately(makePersistedState())
            Self.removeLegacyUserDefaults()
        } catch {
            persistenceErrorMessage = "旧版数据迁移失败，原数据仍保留。"
            logger.error("Failed to migrate legacy state: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func schedulePersistence() {
        guard !isRestoring else { return }
        persistenceRevision += 1
        let revision = persistenceRevision
        let state = makePersistedState()

        Task {
            do {
                try await persistence.save(state, revision: revision)
                guard revision == persistenceRevision else { return }
                persistenceErrorMessage = nil
            } catch {
                guard revision == persistenceRevision else { return }
                persistenceErrorMessage = "本地数据保存失败，请检查设备存储空间。"
                logger.error("Failed to persist local state: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func makePersistedState() -> PersistedScanState {
        PersistedScanState(
            version: PersistedScanState.currentVersion,
            records: records.prefix(Self.maximumSavedRecords).map(Self.redactedForPersistence),
            profile: profile,
            analysisMode: analysisMode,
            onlineAnalysisConsentVersion: onlineAnalysisConsentVersion
        )
    }

    private static func redactedForPersistence(_ record: ScanRecord) -> ScanRecord {
        let result = AnalysisResult(
            recognizedText: "",
            additives: record.result.additives,
            safetyScore: record.result.safetyScore,
            overallRisk: record.result.overallRisk,
            summary: record.result.summary,
            ingredientTokens: Array(record.result.ingredientTokens.prefix(100)).map {
                IngredientToken(
                    id: sanitizePlainText($0.id, maximumLength: 80),
                    text: sanitizePlainText($0.text, maximumLength: 160),
                    kind: $0.kind,
                    matchedAdditiveID: $0.matchedAdditiveID.map {
                        sanitizePlainText($0, maximumLength: 80)
                    },
                    matchedAdditiveName: $0.matchedAdditiveName.map {
                        sanitizePlainText($0, maximumLength: 100)
                    },
                    matchedViaReviewedCorrection: $0.matchedViaReviewedCorrection
                )
            },
            ingredientInsights: Array(record.result.ingredientInsights.prefix(100)).map {
                IngredientInsight(
                    id: sanitizePlainText($0.id, maximumLength: 80),
                    ingredient: sanitizePlainText($0.ingredient, maximumLength: 160),
                    category: $0.category,
                    commonRole: sanitizePlainText($0.commonRole, maximumLength: 100),
                    analysis: sanitizePlainText($0.analysis, maximumLength: 400),
                    reviewNote: $0.reviewNote.map {
                        sanitizePlainText($0, maximumLength: 300)
                    },
                    confidence: $0.confidence
                )
            },
            analysisSource: record.result.analysisSource
        )
        return ScanRecord(
            id: record.id,
            createdAt: record.createdAt,
            productName: record.productName,
            result: result
        )
    }

    private static func sanitizePlainText(_ value: String, maximumLength: Int) -> String {
        let scalars = value.unicodeScalars.filter {
            !CharacterSet.controlCharacters.contains($0)
        }
        return String(String.UnicodeScalarView(scalars).prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func removeLegacyUserDefaults() {
        UserDefaults.standard.removeObject(forKey: LegacyKeys.records)
        UserDefaults.standard.removeObject(forKey: LegacyKeys.profile)
    }
}

struct PersistedScanState: Codable, @unchecked Sendable {
    static let currentVersion = 2

    let version: Int
    let records: [ScanRecord]
    let profile: UserProfile
    let analysisMode: AnalysisMode
    let onlineAnalysisConsentVersion: Int?

    init(
        version: Int,
        records: [ScanRecord],
        profile: UserProfile,
        analysisMode: AnalysisMode,
        onlineAnalysisConsentVersion: Int? = nil
    ) {
        self.version = version
        self.records = records
        self.profile = profile
        self.analysisMode = analysisMode
        self.onlineAnalysisConsentVersion = onlineAnalysisConsentVersion
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case records
        case profile
        case analysisMode
        case onlineAnalysisConsentVersion
        case recognitionMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == 1 || version == Self.currentVersion else {
            throw PersistenceError.unsupportedVersion(version)
        }
        self.version = version
        records = try container.decode([ScanRecord].self, forKey: .records)
        profile = try container.decode(UserProfile.self, forKey: .profile)
        if version == 1 {
            // Version 1 consent covered uploading an image for remote OCR. That
            // is a different purpose, so it must never carry into text analysis.
            analysisMode = .offline
            onlineAnalysisConsentVersion = nil
        } else {
            let decodedConsent = try container.decodeIfPresent(
                Int.self,
                forKey: .onlineAnalysisConsentVersion
            )
            let decodedMode = try container.decodeIfPresent(
                AnalysisMode.self,
                forKey: .analysisMode
            ) ?? .offline
            onlineAnalysisConsentVersion = decodedConsent
            analysisMode = decodedMode == .api
                && decodedConsent != OnlineAnalysisConsent.currentVersion
                ? .offline
                : decodedMode
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Self.currentVersion, forKey: .version)
        try container.encode(records, forKey: .records)
        try container.encode(profile, forKey: .profile)
        try container.encode(analysisMode, forKey: .analysisMode)
        try container.encodeIfPresent(
            onlineAnalysisConsentVersion,
            forKey: .onlineAnalysisConsentVersion
        )
    }
}

private actor ScanPersistence {
    private var latestRevision = 0

    func save(_ state: PersistedScanState, revision: Int) throws {
        guard revision >= latestRevision else { return }
        latestRevision = revision
        try Self.saveImmediately(state)
    }

    func delete(revision: Int) throws {
        guard revision >= latestRevision else { return }
        latestRevision = revision
        let fileURL = try Self.fileURL()
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    nonisolated static func load() throws -> PersistedScanState? {
        let fileURL = try fileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(PersistedScanState.self, from: Data(contentsOf: fileURL))
    }

    nonisolated static func saveImmediately(_ state: PersistedScanState) throws {
        let fileURL = try fileURL()
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    nonisolated private static func fileURL() throws -> URL {
        guard let baseURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw PersistenceError.missingApplicationSupportDirectory
        }

        let directoryURL = baseURL.appendingPathComponent("AddiGuard", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directoryURL.path) {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var mutableDirectoryURL = directoryURL
        try mutableDirectoryURL.setResourceValues(resourceValues)
        return directoryURL.appendingPathComponent("scan-data-v1.json")
    }
}

private enum PersistenceError: LocalizedError {
    case missingApplicationSupportDirectory
    case unsupportedVersion(Int)

    var errorDescription: String? {
        switch self {
        case .missingApplicationSupportDirectory:
            "找不到应用数据目录"
        case .unsupportedVersion(let version):
            "不支持的本地数据版本：\(version)"
        }
    }
}
