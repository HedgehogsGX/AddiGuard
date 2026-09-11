import CryptoKit
import Foundation
import OSLog
import Security

struct OpenRouterConfiguration: Equatable, Sendable {
    static let defaultModel = "z-ai/glm-5.3-flash"
    /// 面向用户展示的模型名称，供界面与隐私说明统一引用。
    static let displayName = "GLM-5.3 Flash"
    static let defaultEndpoint = URL(
        string: "https://openrouter.ai/api/v1/chat/completions"
    )!

    let apiKey: String
    let model: String
    let endpoint: URL
    let credentialSource: CredentialSource
    let credentialFingerprint: String

    enum CredentialSource: String, Equatable, Sendable {
        case direct
        case launchEnvironment
        case keychain
    }

    init?(
        apiKey: String,
        model: String = Self.defaultModel,
        endpoint: URL = Self.defaultEndpoint,
        credentialSource: CredentialSource = .direct
    ) {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty,
              !trimmedKey.contains("$("),
              !trimmedModel.isEmpty
        else {
            return nil
        }

        self.apiKey = trimmedKey
        self.model = trimmedModel
        self.endpoint = endpoint
        self.credentialSource = credentialSource
        self.credentialFingerprint = Self.fingerprint(for: trimmedKey)
    }

    private static func fingerprint(for apiKey: String) -> String {
        var input = Data("AddiGuard/OpenRouter/key-fingerprint/v1\u{0}".utf8)
        input.append(contentsOf: apiKey.utf8)
        return SHA256.hash(data: input)
            .prefix(12)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Xcode passes the ignored local build setting only to Debug launches. The
    /// value is persisted in this device's Keychain so later local launches work
    /// without ever packaging the credential in the application bundle.
    static func localDevelopment(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        loadStoredKey: (() -> String?)? = nil,
        saveStoredKey: ((String) -> Bool)? = nil
    ) -> OpenRouterConfiguration? {
#if DEBUG
        let loadStoredKey = loadStoredKey ?? OpenRouterKeychain.load
        let saveStoredKey = saveStoredKey ?? OpenRouterKeychain.save

        if let launchKey = environment["OPENROUTER_API_KEY"] {
            guard let configuration = OpenRouterConfiguration(
                apiKey: launchKey,
                credentialSource: .launchEnvironment
            ) else {
                OpenRouterDiagnostics.configurationRejected()
                return nil
            }

            let persisted = saveStoredKey(configuration.apiKey)
            OpenRouterDiagnostics.configurationLoaded(
                configuration,
                keychainPersistenceSucceeded: persisted
            )
            return configuration
        }

        guard let storedKey = loadStoredKey(),
              let configuration = OpenRouterConfiguration(
                apiKey: storedKey,
                credentialSource: .keychain
              ) else {
            OpenRouterDiagnostics.configurationUnavailable()
            return nil
        }
        OpenRouterDiagnostics.configurationLoaded(
            configuration,
            keychainPersistenceSucceeded: nil
        )
        return configuration
#else
        return nil
#endif
    }

    static func clearLocalDevelopmentCredential() {
        OpenRouterKeychain.delete()
    }
}

private enum OpenRouterKeychain {
    private static let service = "com.addiguard.app.openrouter"
    // Version the slot so a credential silently cached by an older build can
    // never be mistaken for the key supplied by the current Debug scheme.
    private static let account = "local-development-api-key-v2"

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ apiKey: String) -> Bool {
        guard let data = apiKey.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        let status = SecItemUpdate(
            query as CFDictionary,
            attributes as CFDictionary
        )
        if status == errSecSuccess {
            return true
        }
        guard status == errSecItemNotFound else { return false }

        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum OpenRouterDiagnostics {
    private static let logger = Logger(
        subsystem: "com.addiguard.app",
        category: "OpenRouter"
    )

    static func configurationRejected() {
        logger.error(
            "OPENROUTER_API_KEY was present but invalid; refusing Keychain fallback"
        )
    }

    static func configurationUnavailable() {
        logger.notice("OpenRouter credential is unavailable")
    }

    static func configurationLoaded(
        _ configuration: OpenRouterConfiguration,
        keychainPersistenceSucceeded: Bool?
    ) {
        let persistence = keychainPersistenceSucceeded.map { String($0) }
            ?? "not-requested"
#if DEBUG
        logger.info(
            "Configured source=\(configuration.credentialSource.rawValue, privacy: .public) fingerprint=\(configuration.credentialFingerprint, privacy: .private) model=\(configuration.model, privacy: .public) host=\(configuration.endpoint.host ?? "unknown", privacy: .public) keychain_persisted=\(persistence, privacy: .public)"
        )
#endif
    }

    static func requestSucceeded(
        statusCode: Int,
        generationID: String?,
        model: String?,
        finishReason: String?,
        promptTokens: Int?,
        completionTokens: Int?,
        cost: Double?
    ) {
#if DEBUG
        logger.info(
            "Request succeeded status=\(statusCode, privacy: .public) generation=\(generationID ?? "unknown", privacy: .private) model=\(model ?? "unknown", privacy: .public) finish=\(finishReason ?? "unknown", privacy: .public) prompt_tokens=\(promptTokens ?? -1, privacy: .public) completion_tokens=\(completionTokens ?? -1, privacy: .public) cost=\(cost ?? -1, privacy: .public)"
        )
#endif
    }
}
