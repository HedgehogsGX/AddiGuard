import CoreImage
import ImageIO
import UIKit
@preconcurrency import Vision

enum OCRServiceError: LocalizedError {
    case invalidImage
    case noTextFound
    case lowConfidence

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            "无法读取这张图片，请换一张清晰的配料表照片。"
        case .noTextFound:
            "没有识别到文字，请让配料表充满取景框并保持清晰。"
        case .lowConfidence:
            "文字识别置信度过低，请保持配料表平整、清晰并重新拍摄。"
        }
    }
}

enum OCRService {
    private static let minimumConfidence: VNConfidence = 0.25
    private static let maximumCandidateCount = 5

    /// Creates an orientation-normalized thumbnail before Vision sees a selected photo.
    /// A 4K bound preserves substantially more detail in small packaging text without
    /// allowing an unrestricted full-resolution decode.
    static func downsampleImage(from data: Data, maxPixelSize: Int = 4_096) async throws -> UIImage {
        let work = Task.detached(priority: .userInitiated) { () throws -> UIImage in
            try Task.checkCancellation()

            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
                throw OCRServiceError.invalidImage
            }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
                kCGImageSourceShouldCacheImmediately: true,
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw OCRServiceError.invalidImage
            }

            try Task.checkCancellation()
            return UIImage(cgImage: cgImage)
        }

        return try await withTaskCancellationHandler {
            let image = try await work.value
            try Task.checkCancellation()
            return image
        } onCancel: {
            work.cancel()
        }
    }

    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRServiceError.invalidImage }

        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        do {
            let enhancedImage = try await makeEnhancedImage(from: cgImage)
            try Task.checkCancellation()

            var variants = [OCRImageVariant(cgImage: cgImage, pass: .original)]
            if let enhancedImage {
                variants.append(OCRImageVariant(cgImage: enhancedImage, pass: .enhanced))
            }

            let recognizedLines = try await recognizeLines(
                in: variants,
                orientation: orientation
            )
            try Task.checkCancellation()

            let mergedLines = OCRLineMerger.merge(recognizedLines)
            guard !mergedLines.isEmpty else {
                throw OCRServiceError.noTextFound
            }

            guard OCRConfidenceGate.accepts(
                mergedLines: mergedLines,
                sourceLines: recognizedLines,
                minimumConfidence: minimumConfidence
            ) else {
                throw OCRServiceError.lowConfidence
            }

            let text = mergedLines
                .map(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw OCRServiceError.noTextFound
            }
            return text
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private static func makeEnhancedImage(from cgImage: CGImage) async throws -> CGImage? {
        let work = Task.detached(priority: .userInitiated) { () throws -> CGImage? in
            try Task.checkCancellation()

            let input = CIImage(cgImage: cgImage)
            let monochrome = input.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0,
                    kCIInputContrastKey: 1.30,
                    kCIInputBrightnessKey: 0.015,
                ]
            )
            let sharpened = monochrome.applyingFilter(
                "CISharpenLuminance",
                parameters: [kCIInputSharpnessKey: 0.35]
            )
            let context = CIContext(options: [.cacheIntermediates: false])
            let output = context.createCGImage(sharpened, from: input.extent)

            try Task.checkCancellation()
            return output
        }

        return try await withTaskCancellationHandler {
            let output = try await work.value
            try Task.checkCancellation()
            return output
        } onCancel: {
            work.cancel()
        }
    }

    private static func recognizeLines(
        in variants: [OCRImageVariant],
        orientation: CGImagePropertyOrientation
    ) async throws -> [OCRRecognizedLine] {
        try await withThrowingTaskGroup(of: OCRPassResult.self) { group in
            for variant in variants {
                group.addTask(priority: .userInitiated) {
                    do {
                        return OCRPassResult(
                            lines: try await recognizeLines(
                                in: variant,
                                orientation: orientation
                            ),
                            error: nil
                        )
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return OCRPassResult(lines: nil, error: error)
                    }
                }
            }

            var lines: [OCRRecognizedLine] = []
            var firstError: Error?
            for try await result in group {
                if let passLines = result.lines {
                    lines.append(contentsOf: passLines)
                } else if firstError == nil {
                    firstError = result.error
                }
            }

            if lines.isEmpty, let firstError {
                throw firstError
            }
            return lines
        }
    }

    private static func recognizeLines(
        in variant: OCRImageVariant,
        orientation: CGImagePropertyOrientation
    ) async throws -> [OCRRecognizedLine] {
        let requestBox = VisionRequestBox()

        return try await withTaskCancellationHandler {
            try Task.checkCancellation()

            return try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<[OCRRecognizedLine], Error>) in
                let continuationGate = ContinuationGate(continuation)
                let request = VNRecognizeTextRequest { request, error in
                    if let error {
                        continuationGate.resume(with: .failure(error))
                        return
                    }

                    let observations = request.results as? [VNRecognizedTextObservation] ?? []
                    let lines: [OCRRecognizedLine] = observations.enumerated().compactMap {
                        index, observation -> OCRRecognizedLine? in
                        let candidates = observation
                            .topCandidates(maximumCandidateCount)
                            .map { OCRTextCandidate(text: $0.string, confidence: $0.confidence) }
                        guard let selected = OCRCandidateSelector.preferred(from: candidates) else {
                            return nil
                        }

                        let text = selected.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !text.isEmpty else { return nil }

                        return OCRRecognizedLine(
                            text: text,
                            confidence: selected.confidence,
                            boundingBox: observation.boundingBox,
                            pass: variant.pass,
                            observationIndex: index
                        )
                    }
                    continuationGate.resume(with: .success(lines))
                }

                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.automaticallyDetectsLanguage = true
                request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US"]
                request.customWords = OCRCatalogVocabulary.shared.customWords
                requestBox.store(request)

                DispatchQueue.global(qos: .userInitiated).async {
                    do {
                        try VNImageRequestHandler(
                            cgImage: variant.cgImage,
                            orientation: orientation,
                            options: [:]
                        ).perform([request])
                    } catch {
                        continuationGate.resume(with: .failure(error))
                    }
                }
            }
        } onCancel: {
            requestBox.cancel()
        }
    }
}

struct OCRTextCandidate: Equatable {
    let text: String
    let confidence: VNConfidence
}

enum OCRCandidateSelector {
    /// Vision already orders candidates by confidence. An alternate candidate only wins
    /// when it adds exact local-catalog evidence and remains close to the first candidate.
    static func preferred(
        from candidates: [OCRTextCandidate],
        vocabulary: OCRCatalogVocabulary = .shared
    ) -> OCRTextCandidate? {
        guard let primary = candidates.first else { return nil }

        let primaryEvidence = vocabulary.evidence(in: primary.text)
        var bestCandidate = primary
        var bestEvidence = primaryEvidence
        let confidenceFloor = max(VNConfidence(0.20), primary.confidence - 0.10)

        for candidate in candidates.dropFirst() where candidate.confidence >= confidenceFloor {
            let evidence = vocabulary.evidence(in: candidate.text)
            guard evidence.isStronger(than: bestEvidence) else { continue }
            bestCandidate = candidate
            bestEvidence = evidence
        }

        return bestEvidence.isStronger(than: primaryEvidence) ? bestCandidate : primary
    }
}

struct OCRCatalogEvidence: Equatable {
    let additiveCount: Int
    let totalMatchedLength: Int
    let longestMatchedLength: Int

    static let none = OCRCatalogEvidence(
        additiveCount: 0,
        totalMatchedLength: 0,
        longestMatchedLength: 0
    )

    func isStronger(than other: OCRCatalogEvidence) -> Bool {
        if additiveCount != other.additiveCount {
            return additiveCount > other.additiveCount
        }
        if totalMatchedLength != other.totalMatchedLength {
            return totalMatchedLength > other.totalMatchedLength
        }
        return longestMatchedLength > other.longestMatchedLength
    }
}

struct OCRCatalogVocabulary {
    static let shared = OCRCatalogVocabulary(additives: AdditiveCatalog.all)

    let customWords: [String]
    private let terms: [OCRVocabularyTerm]

    init(additives: [Additive]) {
        var customWords: [String] = []
        var terms: [OCRVocabularyTerm] = []
        var customWordKeys = Set<String>()
        var evidenceTermKeys = Set<String>()

        for additive in additives {
            // Reviewed English names are already represented by aliases. Omitting the
            // generic supplemental `englishName` avoids teaching Vision the repeated
            // placeholder "GB 2760-2024 listed food additive".
            let candidates = [additive.name]
                + (additive.code.map { [$0] } ?? [])
                + additive.aliases

            for rawValue in candidates {
                let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = normalizeOCRText(value)
                guard normalized.count >= 2 else { continue }

                if value.count <= 64, customWordKeys.insert(normalized).inserted {
                    customWords.append(value)
                }

                if isEligibleCatalogEvidenceTerm(normalized),
                   evidenceTermKeys.insert(normalized).inserted {
                    terms.append(
                        OCRVocabularyTerm(
                            additiveID: additive.id,
                            normalizedText: normalized
                        )
                    )
                }
            }
        }

        self.customWords = customWords
        self.terms = terms.sorted {
            if $0.normalizedText.count == $1.normalizedText.count {
                return $0.normalizedText < $1.normalizedText
            }
            return $0.normalizedText.count > $1.normalizedText.count
        }
    }

    func evidence(in text: String) -> OCRCatalogEvidence {
        let normalizedText = normalizeOCRText(text)
        guard !normalizedText.isEmpty else { return .none }

        var matchedAdditiveIDs = Set<String>()
        var totalMatchedLength = 0
        var longestMatchedLength = 0

        for term in terms
        where !matchedAdditiveIDs.contains(term.additiveID)
            && normalizedText.contains(term.normalizedText) {
            matchedAdditiveIDs.insert(term.additiveID)
            totalMatchedLength += term.normalizedText.count
            longestMatchedLength = max(longestMatchedLength, term.normalizedText.count)
        }

        return OCRCatalogEvidence(
            additiveCount: matchedAdditiveIDs.count,
            totalMatchedLength: totalMatchedLength,
            longestMatchedLength: longestMatchedLength
        )
    }
}

private struct OCRVocabularyTerm {
    let additiveID: String
    let normalizedText: String
}

enum OCRPass: Int {
    case original
    case enhanced
}

struct OCRRecognizedLine: Equatable {
    let text: String
    let confidence: VNConfidence
    let boundingBox: CGRect
    let pass: OCRPass
    let observationIndex: Int
    let catalogEvidence: OCRCatalogEvidence

    init(
        text: String,
        confidence: VNConfidence,
        boundingBox: CGRect,
        pass: OCRPass,
        observationIndex: Int,
        vocabulary: OCRCatalogVocabulary = .shared
    ) {
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.pass = pass
        self.observationIndex = observationIndex
        self.catalogEvidence = vocabulary.evidence(in: text)
    }
}

enum OCRConfidenceGate {
    /// Keep the second pass non-degrading: merged rescue lines may enrich the output,
    /// but they cannot make a pass that was independently acceptable fail as a whole.
    static func accepts(
        mergedLines: [OCRRecognizedLine],
        sourceLines: [OCRRecognizedLine],
        minimumConfidence: VNConfidence
    ) -> Bool {
        guard !mergedLines.isEmpty else { return false }

        if averageConfidence(of: mergedLines) >= minimumConfidence {
            return true
        }

        return [OCRPass.original, .enhanced].contains { pass in
            let passLines = sourceLines.filter { $0.pass == pass }
            guard !passLines.isEmpty else { return false }
            return averageConfidence(of: passLines) >= minimumConfidence
        }
    }

    private static func averageConfidence(
        of lines: [OCRRecognizedLine]
    ) -> VNConfidence {
        guard !lines.isEmpty else { return .zero }
        return lines.reduce(VNConfidence.zero) { $0 + $1.confidence }
            / VNConfidence(lines.count)
    }
}

enum OCRLineMerger {
    static func merge(_ lines: [OCRRecognizedLine]) -> [OCRRecognizedLine] {
        let passOrderedLines = lines.sorted {
            if $0.pass.rawValue == $1.pass.rawValue {
                return $0.observationIndex < $1.observationIndex
            }
            return $0.pass.rawValue < $1.pass.rawValue
        }

        var merged: [OCRRecognizedLine] = []
        for line in passOrderedLines {
            guard shouldRetainUnmatched(line) else { continue }

            if let duplicateIndex = bestDuplicateIndex(for: line, in: merged) {
                merged[duplicateIndex] = preferredLine(merged[duplicateIndex], line)
            } else {
                merged.append(line)
            }
        }

        return linesInReadingOrder(merged)
    }

    private static func shouldRetainUnmatched(_ line: OCRRecognizedLine) -> Bool {
        guard !normalizeOCRText(line.text).isEmpty else { return false }
        if line.pass == .original {
            return true
        }
        return line.confidence >= 0.25
            || (line.catalogEvidence.additiveCount > 0 && line.confidence >= 0.18)
    }

    private static func bestDuplicateIndex(
        for candidate: OCRRecognizedLine,
        in lines: [OCRRecognizedLine]
    ) -> Int? {
        lines.indices
            .filter { lines[$0].pass != candidate.pass }
            .compactMap { index -> (Int, CGFloat)? in
                guard duplicateGeometryScore(lines[index], candidate) > 0 else { return nil }
                return (index, duplicateGeometryScore(lines[index], candidate))
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    private static func duplicateGeometryScore(
        _ lhs: OCRRecognizedLine,
        _ rhs: OCRRecognizedLine
    ) -> CGFloat {
        let lhsBox = lhs.boundingBox.standardized
        let rhsBox = rhs.boundingBox.standardized
        guard !lhsBox.isEmpty, !rhsBox.isEmpty else { return 0 }

        let intersection = lhsBox.intersection(rhsBox)
        let minimumArea = min(lhsBox.width * lhsBox.height, rhsBox.width * rhsBox.height)
        let overlap = intersection.isNull || minimumArea == 0
            ? 0
            : (intersection.width * intersection.height) / minimumArea
        let widthSimilarity = min(lhsBox.width, rhsBox.width) / max(lhsBox.width, rhsBox.width)
        let heightSimilarity = min(lhsBox.height, rhsBox.height) / max(lhsBox.height, rhsBox.height)

        let lhsText = normalizeOCRText(lhs.text)
        let rhsText = normalizeOCRText(rhs.text)
        let maximumTextLength = max(lhsText.count, rhsText.count)
        let lengthSimilarity = maximumTextLength == 0
            ? 0
            : CGFloat(min(lhsText.count, rhsText.count)) / CGFloat(maximumTextLength)

        let centerXDistance = abs(lhsBox.midX - rhsBox.midX)
        let centerYDistance = abs(lhsBox.midY - rhsBox.midY)
        let centersAreClose = centerXDistance <= max(lhsBox.width, rhsBox.width) * 0.16
            && centerYDistance <= max(lhsBox.height, rhsBox.height) * 0.65

        if lhsText == rhsText, overlap >= 0.25 || centersAreClose {
            return overlap + widthSimilarity + heightSimilarity + 1
        }

        guard overlap >= 0.55,
              widthSimilarity >= 0.55,
              heightSimilarity >= 0.50,
              lengthSimilarity >= 0.50
        else {
            return 0
        }

        return overlap + widthSimilarity + heightSimilarity + lengthSimilarity
    }

    private static func preferredLine(
        _ lhs: OCRRecognizedLine,
        _ rhs: OCRRecognizedLine
    ) -> OCRRecognizedLine {
        if rhs.catalogEvidence.isStronger(than: lhs.catalogEvidence),
           rhs.confidence >= lhs.confidence - 0.10 {
            return rhs
        }
        if lhs.catalogEvidence.isStronger(than: rhs.catalogEvidence),
           lhs.confidence >= rhs.confidence - 0.10 {
            return lhs
        }

        if abs(lhs.confidence - rhs.confidence) <= 0.02 {
            let lhsLength = normalizeOCRText(lhs.text).count
            let rhsLength = normalizeOCRText(rhs.text).count
            if rhsLength > lhsLength, rhsLength <= Int(Double(max(lhsLength, 1)) * 1.35) {
                return rhs
            }
            if lhs.pass != rhs.pass {
                return lhs.pass == .original ? lhs : rhs
            }
        }

        return rhs.confidence > lhs.confidence ? rhs : lhs
    }

    private static func linesInReadingOrder(
        _ lines: [OCRRecognizedLine]
    ) -> [OCRRecognizedLine] {
        let verticallySorted = lines.sorted {
            if $0.boundingBox.midY == $1.boundingBox.midY {
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            return $0.boundingBox.midY > $1.boundingBox.midY
        }

        var rows: [[OCRRecognizedLine]] = []
        for line in verticallySorted {
            let rowIndex = rows.firstIndex { row in
                let rowCenter = row.map(\.boundingBox.midY).reduce(0, +) / CGFloat(row.count)
                let rowHeight = row.map(\.boundingBox.height).reduce(0, +) / CGFloat(row.count)
                return abs(line.boundingBox.midY - rowCenter)
                    <= max(line.boundingBox.height, rowHeight) * 0.45
            }

            if let rowIndex {
                rows[rowIndex].append(line)
            } else {
                rows.append([line])
            }
        }

        return rows.flatMap { row in
            row.sorted {
                if $0.boundingBox.minX == $1.boundingBox.minX {
                    return $0.observationIndex < $1.observationIndex
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
        }
    }
}

private struct OCRImageVariant: @unchecked Sendable {
    let cgImage: CGImage
    let pass: OCRPass
}

private struct OCRPassResult: @unchecked Sendable {
    let lines: [OCRRecognizedLine]?
    let error: Error?
}

private func normalizeOCRText(_ value: String) -> String {
    value
        .folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "zh_CN")
        )
        .filter { $0.isLetter || $0.isNumber }
        .lowercased()
}

/// Short Latin abbreviations are common in unrelated packaging copy. They still help
/// Vision's lexicon through `customWords`, but do not justify choosing a lower-confidence
/// candidate unless they are an E/INS numeric code. Two-character Chinese aliases remain
/// useful because they carry much more lexical information in this domain.
private func isEligibleCatalogEvidenceTerm(_ value: String) -> Bool {
    if value.unicodeScalars.contains(where: { scalar in
        (0x3400...0x9FFF).contains(scalar.value)
            || (0xF900...0xFAFF).contains(scalar.value)
    }) {
        return value.count >= 2
    }

    let numericSuffix: Substring
    if value.hasPrefix("ins") {
        numericSuffix = value.dropFirst(3)
    } else if value.hasPrefix("e") {
        numericSuffix = value.dropFirst()
    } else {
        return value.count >= 4
    }
    return numericSuffix.first?.isNumber == true
}

private final class VisionRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var request: VNRequest?
    private var isCancelled = false

    func store(_ request: VNRequest) {
        lock.lock()
        if isCancelled {
            lock.unlock()
            request.cancel()
        } else {
            self.request = request
            lock.unlock()
        }
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let request = request
        lock.unlock()
        request?.cancel()
    }
}

private final class ContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func resume(with result: Result<Value, Error>) {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return
        }
        self.continuation = nil
        lock.unlock()
        continuation.resume(with: result)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
