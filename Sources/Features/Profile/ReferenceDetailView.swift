import SwiftUI

struct ReferenceDetailView: View {
    @Environment(AppTheme.self) private var theme

    let source: ReferenceSource
    var additive: Additive? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if let additive {
                    additiveLookupCard(additive)
                }

                ReferenceTextSection(title: "这份资料是什么", symbol: "info.circle") {
                    Text(source.overview)
                }

                ReferenceTextSection(title: "可以用来核对", symbol: "checkmark.circle") {
                    ReferenceBulletList(items: source.answers)
                }

                ReferenceTextSection(title: "不能单独回答", symbol: "exclamationmark.triangle") {
                    ReferenceBulletList(items: source.limitations)
                }

                officialLinks

                Text("AddiGuard 只把这些来源作为名称匹配与资料核对入口，不会把“被目录收录”或某个机构评级直接等同于一款食品对个人的安全结论。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(20)
        }
        .background(theme.canvas.ignoresSafeArea())
        .navigationTitle("资料详情")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: source.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(source.title)
                    .font(.title2.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text(source.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func additiveLookupCard(_ additive: Additive) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("核对当前添加剂", systemImage: "magnifyingglass")
                .font(.headline)

            Text(additive.name)
                .font(.title3.weight(.semibold))

            HStack(spacing: 8) {
                if let code = additive.code {
                    Text(code)
                        .font(.subheadline.monospaced().weight(.semibold))
                }
                Text(additive.englishName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("打开官方入口后，可优先搜索“\(additive.name)”\(additive.code.map { "或“\($0)”" } ?? "")。同一名称在不同食品类别中的允许范围和用量可能不同。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var officialLinks: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("查看官方原文", systemImage: "arrow.up.right.square")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(source.officialLinks) { link in
                    Link(destination: link.url) {
                        HStack(spacing: 12) {
                            Image(systemName: "safari")
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 22)
                            Text(link.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 13)
                    }
                    .accessibilityHint("在浏览器中打开官方网页")

                    if link.id != source.officialLinks.last?.id {
                        Divider().padding(.leading, 48)
                    }
                }
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

private struct ReferenceTextSection<Content: View>: View {
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

private struct ReferenceBulletList: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 6)
                        .accessibilityHidden(true)
                    Text(item)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
