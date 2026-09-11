import Foundation

enum ProductNameParser {
    static func extract(from recognizedText: String) -> String? {
        let labels = ["产品名称", "品名"]

        for rawLine in recognizedText.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            for label in labels {
                guard line.hasPrefix(label) else { continue }
                let remainder = line
                    .dropFirst(label.count)
                    .drop { $0 == ":" || $0 == "：" || $0.isWhitespace }
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !remainder.isEmpty {
                    return String(remainder.prefix(40))
                }
            }
        }

        return nil
    }
}

