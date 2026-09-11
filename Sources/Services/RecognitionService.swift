import Foundation
import SwiftUI
import UIKit

/// Controls how locally extracted ingredient names are analyzed. Image text
/// recognition is always performed on device and is deliberately not configurable.
enum AnalysisMode: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case offline
    case api

    var id: String { rawValue }

    var title: String {
        switch self {
        case .offline: "本地离线"
        case .api: "在线分析"
        }
    }

    var detail: String {
        switch self {
        case .offline:
            "图片仅在设备上识别，配料也只使用本地知识库分析。"
        case .api:
            "图片仍只在设备上识别；仅将拆分后的配料名称发送给 \(OpenRouterConfiguration.displayName) 逐项说明。"
        }
    }

    var symbol: String {
        switch self {
        case .offline: "iphone.and.arrow.forward"
        case .api: "network"
        }
    }
}

enum RecognitionServiceError: LocalizedError, Equatable {
    case apiNotConfigured
    case onlineConsentRequired
    case noIngredientsFound
    case invalidImage
    case invalidEndpoint
    case insecureEndpoint
    case invalidRequest
    case emptyResponse
    case invalidResponse
    case authenticationFailed
    case insufficientCredits
    case requestRejected
    case modelUnavailable
    case responseTruncated
    case payloadTooLarge
    case rateLimited
    case serverUnavailable
    case unexpectedStatus(Int)
    case noConnection
    case timedOut
    case transportFailure

    var errorDescription: String? {
        switch self {
        case .apiNotConfigured:
            "在线分析尚未配置，请先使用本地离线分析。"
        case .onlineConsentRequired:
            "请先阅读在线分析说明并确认后再使用。"
        case .noIngredientsFound:
            "未能从本地识别结果中确定配料列表。请重新拍摄清晰、完整的配料表。"
        case .invalidImage:
            "无法在设备上读取这张图片，请换一张清晰的配料表照片。"
        case .invalidEndpoint:
            "在线分析服务地址无效，请检查 API 配置。"
        case .insecureEndpoint:
            "在线分析服务必须使用安全的 HTTPS 连接。"
        case .invalidRequest:
            "在线分析请求格式无效，请检查服务配置。"
        case .emptyResponse:
            "没有识别到可用文字，请重新拍摄清晰、完整的配料表。"
        case .invalidResponse:
            "在线服务返回了无法验证的逐项分析，请稍后重试。"
        case .authenticationFailed:
            "在线服务认证失败，请检查 API 凭证。"
        case .insufficientCredits:
            "在线服务额度不足，请检查 OpenRouter 账户。"
        case .requestRejected:
            "在线分析请求被服务拒绝，请稍后重试或使用本地离线分析。"
        case .modelUnavailable:
            "\(OpenRouterConfiguration.displayName) 当前不可用，请稍后重试或使用本地离线分析。"
        case .responseTruncated:
            "在线分析结果不完整，请重试或使用本地离线分析。"
        case .payloadTooLarge:
            "配料项目过多或文字过长，请分开扫描。"
        case .rateLimited:
            "在线服务请求过于频繁，请稍后重试。"
        case .serverUnavailable:
            "在线分析服务暂时不可用，请稍后重试或使用本地离线分析。"
        case .unexpectedStatus(let statusCode):
            "在线分析请求失败（状态码 \(statusCode)），请稍后重试。"
        case .noConnection:
            "当前无法连接网络，请检查网络后重试或使用本地离线分析。"
        case .timedOut:
            "在线分析请求超时，请稍后重试或使用本地离线分析。"
        case .transportFailure:
            "在线分析连接失败，请稍后重试或使用本地离线分析。"
        }
    }
}

/// Injectable local OCR operation. Its public surface accepts an image and
/// returns text; no network provider can be attached to this service.
struct TextRecognizer: @unchecked Sendable {
    private let operation: @Sendable (UIImage) async throws -> String

    init(operation: @escaping @Sendable (UIImage) async throws -> String) {
        self.operation = operation
    }

    func recognizeText(in image: UIImage) async throws -> String {
        try await operation(image)
    }

    static let offline = TextRecognizer { image in
        try await OCRService.recognizeText(in: image)
    }
}

struct RecognitionService: @unchecked Sendable {
    private let localRecognizer: TextRecognizer

    init(localRecognizer: TextRecognizer) {
        self.localRecognizer = localRecognizer
    }

    func recognizeText(in image: UIImage) async throws -> String {
        let text = try await localRecognizer.recognizeText(in: image)
        try Task.checkCancellation()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RecognitionServiceError.emptyResponse
        }
        return text
    }

    static let live = RecognitionService(localRecognizer: .offline)
}

private struct RecognitionServiceEnvironmentKey: EnvironmentKey {
    static let defaultValue = RecognitionService.live
}

extension EnvironmentValues {
    var recognitionService: RecognitionService {
        get { self[RecognitionServiceEnvironmentKey.self] }
        set { self[RecognitionServiceEnvironmentKey.self] = newValue }
    }
}
