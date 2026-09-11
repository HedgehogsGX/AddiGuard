import SwiftUI

struct ScanResultView: View {
    @Environment(AppTheme.self) private var theme
    let record: ScanRecord
    private let ingredientTokens: [IngredientToken]

    @State private var selectedAdditive: DetectedAdditive?
    @State private var showsRecognizedText = false

    private var hasRecognizedText: Bool {
        !record.result.recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var emptyStateMessage: String {
        if !ingredientTokens.isEmpty {
            return "本地知识库没有确认添加剂名称；这不代表没有添加剂或产品安全。请逐项核对下方配料。"
        }
        guard hasRecognizedText else {
            return "这条旧版历史没有保存可核对的配料项。请重新扫描配料表。"
        }
        return "没有匹配到知识库名称不代表没有添加剂或产品安全。请核对 OCR 原文，必要时重新拍摄。"
    }

    init(record: ScanRecord) {
        self.record = record
        ingredientTokens = record.result.ingredientTokens.isEmpty
            ? IngredientTextParser.parse(text: record.result.recognizedText)
            : record.result.ingredientTokens
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    ResultHero(record: record)

                    if record.result.additives.isEmpty {
                        EmptyStateView(
                            symbol: "text.magnifyingglass",
                            title: "暂时无法判断",
                            message: emptyStateMessage
                        )
                        .cardStyle()
                    } else {
                        additiveSection
                    }

                    if !ingredientTokens.isEmpty {
                        ingredientCoverageSection
                    }

                    if !record.result.ingredientInsights.isEmpty {
                        onlineInsightSection
                    }

                    if hasRecognizedText {
                        recognizedTextSection
                    }
                    disclaimer
                }
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
        .navigationTitle("匹配结果")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedAdditive) { item in
            AdditiveDetailSheet(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var additiveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                "可能匹配到 \(record.result.additives.count) 种添加剂",
                eyebrow: "INGREDIENT REPORT",
                subtitle: "自动匹配可能有误；请先对照包装原文，再点击查看关注理由。"
            )

            ForEach(record.result.additives) { item in
                Button {
                    selectedAdditive = item
                } label: {
                    AdditiveRow(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .cardStyle()
    }

    private var ingredientCoverageSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                "已拆分 \(ingredientTokens.count) 项配料",
                eyebrow: "FULL LABEL COVERAGE",
                subtitle: "普通配料也会显示；可能匹配和未匹配项保留在这里，避免它们从结果中静默消失。"
            )

            VStack(spacing: 0) {
                ForEach(Array(ingredientTokens.enumerated()), id: \.element.id) { index, token in
                    IngredientTokenRow(token: token)
                    if index < ingredientTokens.count - 1 {
                        Divider().padding(.leading, 43)
                    }
                }
            }

            Label(
                "“未匹配”只表示本地知识库尚未确认其类别，不能据此判断为普通配料或安全。",
                systemImage: "info.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var recognizedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) { showsRecognizedText.toggle() }
            } label: {
                HStack {
                    Label("OCR 识别原文", systemImage: "text.viewfinder")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(showsRecognizedText ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            .accessibilityValue(showsRecognizedText ? "已展开" : "已折叠")

            if showsRecognizedText {
                Text(record.result.recognizedText)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cardStyle()
    }

    private var onlineInsightSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(
                "逐项配料说明",
                eyebrow: "OX ALPHA ASSIST",
                subtitle: "仅解释本地已拆出的配料；不会新增、删除、改名或改变上方本地风险结论。"
            )

            ForEach(Array(record.result.ingredientInsights.enumerated()), id: \.element.id) { index, insight in
                IngredientInsightRow(insight: insight)
                if index < record.result.ingredientInsights.count - 1 {
                    Divider()
                }
            }

            Label(
                "AI 辅助说明可能有误；请以包装原文、监管资料和专业意见为准。",
                systemImage: "sparkles"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .cardStyle()
    }

    private var disclaimer: some View {
        Label {
            Text("这里显示本地 OCR 配料拆分、本地名称匹配及可选的 AI 逐项说明。应用不知道食品类别、实际添加量或摄入量，因此不能判断产品合规或安全，也不能替代医生及食品安全专业人员的意见。")
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }
}

private struct IngredientInsightRow: View {
    let insight: IngredientInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(insight.ingredient)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(insight.category.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.045), in: Capsule())
            }

            LabeledContent("常见作用") {
                Text(insight.commonRole)
                    .multilineTextAlignment(.trailing)
            }
            .font(.subheadline)

            Text(insight.analysis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let note = insight.reviewNote, !note.isEmpty {
                Label(note, systemImage: "exclamationmark.bubble")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("说明可信度：\(insight.confidence.title)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .textSelection(.enabled)
    }
}

private struct ResultHero: View {
    let record: ScanRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(record.productName)
                        .font(.headline)
                    Text(record.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer()
            }

            HStack(spacing: 14) {
                Image(systemName: record.result.overallRisk.symbol)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(record.result.overallRisk.prominentColor)
                    .frame(width: 54, height: 54)
                    .background(.white.opacity(0.94), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("资料核对优先级")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    Text(record.result.overallRisk.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("资料核对优先级：\(record.result.overallRisk.title)")

            Text(record.result.summary)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 0) {
                    metrics
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    metrics
                }
            }
            .padding(14)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(record.result.overallRisk.prominentColor, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    @ViewBuilder
    private var metrics: some View {
        CountMetric(value: record.result.highRiskCount, label: "高关注", color: .riskHigh)
        CountMetric(value: record.result.moderateRiskCount, label: "需核对", color: .riskModerate)
        CountMetric(value: record.result.lowRiskCount, label: "较低关注", color: .riskLow)
        CountMetric(value: record.result.unratedCount, label: "未评级", color: .riskUnrated)
    }
}

private struct CountMetric: View {
    let value: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(.white)
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.88))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) 项")
    }
}

private struct AdditiveRow: View {
    let item: DetectedAdditive

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(item.additive.risk.color.opacity(0.1))
                Image(systemName: item.additive.risk.symbol)
                    .foregroundStyle(item.additive.risk.color)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.additive.name).font(.subheadline.weight(.semibold))
                    if let code = item.additive.code {
                        Text(code).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    }
                }
                Text(item.additive.function)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            RiskBadge(risk: item.additive.risk)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

}

private struct IngredientTokenRow: View {
    let token: IngredientToken

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(token.text)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            Text(statusTitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(color.opacity(0.09), in: Capsule())
        }
        .padding(.vertical, 9)
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch token.kind {
        case .matchedAdditive: "checkmark.shield.fill"
        case .ordinaryIngredient: "leaf.fill"
        case .possibleMatch: "questionmark.diamond.fill"
        case .unresolved: "text.magnifyingglass"
        }
    }

    private var color: Color {
        switch token.kind {
        case .matchedAdditive: .accentColor
        case .ordinaryIngredient: .riskLow
        case .possibleMatch: .riskModerate
        case .unresolved: .riskUnrated
        }
    }

    private var statusTitle: String {
        switch token.kind {
        case .matchedAdditive: "添加剂"
        case .ordinaryIngredient: "普通配料"
        case .possibleMatch: "可能匹配"
        case .unresolved: "未匹配"
        }
    }

    private var detail: String? {
        switch token.kind {
        case .matchedAdditive:
            guard let name = token.matchedAdditiveName, name != token.text else { return nil }
            return "本地名称匹配：\(name)"
        case .ordinaryIngredient:
            return "常见基础食品配料，未作为食品添加剂报告。"
        case .possibleMatch:
            guard let name = token.matchedAdditiveName else {
                return "文字可能存在 OCR 错误，请对照包装确认。"
            }
            return "可能是“\(name)”，请对照包装确认后再参考详情。"
        case .unresolved:
            return "尚未在本地知识库中确认，请检查 OCR 原文。"
        }
    }
}

#Preview("Result") {
    let result = IngredientAnalyzer.analyze(
        text: "配料：亚硝酸钠、山梨酸钾、维生素C、柠檬酸",
        profile: UserProfile(populationGroup: .child)
    )
    NavigationStack {
        ScanResultView(record: ScanRecord(productName: "示例肉制品", result: result))
    }
    .environment(AppTheme())
}
