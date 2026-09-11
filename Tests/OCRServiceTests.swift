import XCTest
@testable import AddiGuard

final class OCRServiceTests: XCTestCase {
    func testCatalogVocabularyIncludesNamesAliasesAndCodes() {
        let words = Set(OCRCatalogVocabulary.shared.customWords)

        XCTAssertTrue(words.contains("安赛蜜"))
        XCTAssertTrue(words.contains("乙酰磺胺酸钾"))
        XCTAssertTrue(words.contains("E950"))
        XCTAssertTrue(words.contains("苯甲酸钠"))
        XCTAssertFalse(words.contains("GB 2760-2024 listed food additive"))
        XCTAssertEqual(OCRCatalogVocabulary.shared.evidence(in: "柠檬酸").additiveCount, 1)
    }

    func testShortLatinAliasesHelpVisionButDoNotInfluenceCandidateScoring() {
        let vocabulary = OCRCatalogVocabulary.shared

        XCTAssertTrue(vocabulary.customWords.contains("TP"))
        XCTAssertEqual(vocabulary.evidence(in: "TP"), .none)
        XCTAssertGreaterThan(vocabulary.evidence(in: "E950").additiveCount, 0)
        XCTAssertGreaterThan(vocabulary.evidence(in: "香精").additiveCount, 0)
    }

    func testCloseCatalogBackedCandidateBeatsTypo() throws {
        let selected = try XCTUnwrap(
            OCRCandidateSelector.preferred(
                from: [
                    OCRTextCandidate(
                        text: "食品添加剂（二氧化炭、安塞蜜）",
                        confidence: 0.91
                    ),
                    OCRTextCandidate(
                        text: "食品添加剂（二氧化碳、安赛蜜）",
                        confidence: 0.86
                    ),
                ]
            )
        )

        XCTAssertEqual(selected.text, "食品添加剂（二氧化碳、安赛蜜）")
    }

    func testCatalogEvidenceDoesNotOverrideLargeConfidenceGap() throws {
        let selected = try XCTUnwrap(
            OCRCandidateSelector.preferred(
                from: [
                    OCRTextCandidate(
                        text: "食品添加剂（二氧化炭、安塞蜜）",
                        confidence: 0.91
                    ),
                    OCRTextCandidate(
                        text: "食品添加剂（二氧化碳、安赛蜜）",
                        confidence: 0.75
                    ),
                ]
            )
        )

        XCTAssertEqual(selected.text, "食品添加剂（二氧化炭、安塞蜜）")
    }

    func testMergeUsesSpatialEvidenceAndKeepsOneBetterLine() {
        let original = OCRRecognizedLine(
            text: "食品添加剂（二氧化炭、安塞蜜）",
            confidence: 0.88,
            boundingBox: CGRect(x: 0.10, y: 0.60, width: 0.72, height: 0.08),
            pass: .original,
            observationIndex: 0
        )
        let enhanced = OCRRecognizedLine(
            text: "食品添加剂（二氧化碳、安赛蜜）",
            confidence: 0.83,
            boundingBox: CGRect(x: 0.11, y: 0.605, width: 0.70, height: 0.078),
            pass: .enhanced,
            observationIndex: 0
        )

        let merged = OCRLineMerger.merge([enhanced, original])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.text, enhanced.text)
    }

    func testMergeDoesNotCollapseDifferentRegions() {
        let left = OCRRecognizedLine(
            text: "柠檬酸",
            confidence: 0.90,
            boundingBox: CGRect(x: 0.10, y: 0.60, width: 0.20, height: 0.08),
            pass: .original,
            observationIndex: 0
        )
        let right = OCRRecognizedLine(
            text: "安赛蜜",
            confidence: 0.88,
            boundingBox: CGRect(x: 0.65, y: 0.60, width: 0.20, height: 0.08),
            pass: .enhanced,
            observationIndex: 0
        )

        let merged = OCRLineMerger.merge([right, left])

        XCTAssertEqual(merged.map(\.text), ["柠檬酸", "安赛蜜"])
    }

    func testConfidenceGateDoesNotLetWeakEnhancedRescueRejectAcceptableOriginalPass() {
        let original = OCRRecognizedLine(
            text: "配料：水、白砂糖",
            confidence: 0.26,
            boundingBox: CGRect(x: 0.10, y: 0.70, width: 0.62, height: 0.08),
            pass: .original,
            observationIndex: 0
        )
        let enhancedRescue = OCRRecognizedLine(
            text: "安赛蜜",
            confidence: 0.18,
            boundingBox: CGRect(x: 0.12, y: 0.50, width: 0.20, height: 0.07),
            pass: .enhanced,
            observationIndex: 0
        )
        let merged = OCRLineMerger.merge([original, enhancedRescue])

        XCTAssertEqual(merged.count, 2)
        XCTAssertTrue(
            OCRConfidenceGate.accepts(
                mergedLines: merged,
                sourceLines: [original, enhancedRescue],
                minimumConfidence: 0.25
            )
        )
    }

    func testConfidenceGateRejectsWhenEveryPassAndMergedOutputAreLow() {
        let original = OCRRecognizedLine(
            text: "配料",
            confidence: 0.20,
            boundingBox: CGRect(x: 0.10, y: 0.70, width: 0.20, height: 0.08),
            pass: .original,
            observationIndex: 0
        )
        let enhancedRescue = OCRRecognizedLine(
            text: "安赛蜜",
            confidence: 0.18,
            boundingBox: CGRect(x: 0.12, y: 0.50, width: 0.20, height: 0.07),
            pass: .enhanced,
            observationIndex: 0
        )
        let merged = OCRLineMerger.merge([original, enhancedRescue])

        XCTAssertEqual(merged.count, 2)
        XCTAssertFalse(
            OCRConfidenceGate.accepts(
                mergedLines: merged,
                sourceLines: [original, enhancedRescue],
                minimumConfidence: 0.25
            )
        )
    }
}
