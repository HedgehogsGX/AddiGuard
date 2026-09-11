import SwiftUI

struct AdditiveDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme

    let item: DetectedAdditive

    var body: some View {
        NavigationStack {
            ZStack {
                theme.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        DetailSection(title: "一句话看懂", symbol: "lightbulb") {
                            Text(item.additive.plainLanguageSummary)
                        }
                        DetailSection(title: "这是什么（专业说明）", symbol: "flask") {
                            Text(item.additive.summary)
                        }
                        DetailSection(title: "资料中的关注点", symbol: "waveform.path.ecg") {
                            BulletList(items: item.additive.healthEffects)
                        }
                        DetailSection(title: "核对建议", symbol: "doc.text.magnifyingglass") {
                            Text(item.additive.recommendation)
                        }

                        if let note = item.personalizedNote {
                            Label {
                                Text(note).font(.subheadline.weight(.medium))
                            } icon: {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                            }
                            .foregroundStyle(Color.accentColor)
                            .padding(16)
                            .background(Color.accentColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
                        }

                        if !referenceItems.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("参考资料")
                                    .font(.subheadline.weight(.semibold))
                                Text("点开查看资料说明、适用边界与官方原文")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(referenceItems) { reference in
                                        NavigationLink {
                                            ReferenceDetailView(
                                                source: reference.source,
                                                additive: item.additive
                                            )
                                        } label: {
                                            HStack(spacing: 6) {
                                                SourcePill(title: reference.label)
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(.secondary)
                                            }
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("查看\(reference.source.title)")
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .frame(maxWidth: .infinity)
                    .padding(20)
                }
            }
            .navigationTitle("成分详情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                RiskBadge(risk: item.additive.risk)
                Spacer()
                if let code = item.additive.code {
                    Text(code)
                        .font(.subheadline.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text(item.additive.name)
                .font(.largeTitle.bold())
            Text(item.additive.englishName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(item.additive.function)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08), in: Capsule())
        }
    }

    private var referenceItems: [AdditiveReferenceItem] {
        item.additive.sources.reduce(into: []) { result, label in
            guard let source = ReferenceSource.matching(label),
                  !result.contains(where: { $0.source == source }) else { return }
            result.append(AdditiveReferenceItem(label: label, source: source))
        }
    }
}

private struct AdditiveReferenceItem: Identifiable {
    let label: String
    let source: ReferenceSource

    var id: ReferenceSource { source }
}

private struct DetailSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .font(.headline)
            content
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct BulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 9) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 5, height: 5)
                        .padding(.top, 7)
                    Text(item)
                }
            }
        }
    }
}
