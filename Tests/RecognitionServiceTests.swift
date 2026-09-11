import XCTest
import UIKit
@testable import AddiGuard

final class RecognitionServiceTests: XCTestCase {
    func testRecognitionAlwaysUsesInjectedLocalOCRAndPreservesText() async throws {
        let calls = LockedCounter()
        let expected = "产品名称：测试饮料\n配料：水、柠檬酸"
        let service = RecognitionService(
            localRecognizer: TextRecognizer { _ in
                calls.increment()
                return expected
            }
        )

        let text = try await service.recognizeText(in: UIImage())

        XCTAssertEqual(text, expected)
        XCTAssertEqual(calls.value, 1)
    }

    func testEmptyLocalOCROutputIsRejected() async {
        let service = RecognitionService(
            localRecognizer: TextRecognizer { _ in "  \n " }
        )

        do {
            _ = try await service.recognizeText(in: UIImage())
            XCTFail("Expected empty OCR to fail")
        } catch RecognitionServiceError.emptyResponse {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationIsPreserved() async {
        let service = RecognitionService(
            localRecognizer: TextRecognizer { _ in throw CancellationError() }
        )

        do {
            _ = try await service.recognizeText(in: UIImage())
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}
