import SwiftUI

struct HistoryView: View {
    @Environment(ScanStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @Binding var selectedTab: AppTab

    @State private var searchText = ""
    @State private var confirmsClear = false

    private var filteredRecords: [ScanRecord] {
        guard !searchText.isEmpty else { return store.records }
        return store.records.filter { record in
            record.productName.localizedCaseInsensitiveContains(searchText) ||
            record.result.additives.contains {
                $0.additive.name.localizedCaseInsensitiveContains(searchText)
            } || record.result.ingredientTokens.contains {
                $0.text.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()
            if store.records.isEmpty {
                VStack(spacing: 8) {
                    EmptyStateView(
                        symbol: "clock.badge.questionmark",
                        title: "还没有扫描记录",
                        message: "完成第一次配料表识别后，名称匹配结果会保存在受保护的本地文件中。"
                    )
                    Button("去扫描配料表") {
                        selectedTab = .scan
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
            } else if filteredRecords.isEmpty {
                VStack(spacing: 14) {
                    ContentUnavailableView.search(text: searchText)
                    Button("清除搜索") { searchText = "" }
                        .buttonStyle(.bordered)
                }
                .padding(24)
            } else {
                List {
                    Section {
                        ForEach(filteredRecords) { record in
                            NavigationLink(value: record) {
                                HistoryRow(record: record)
                            }
                            .listRowBackground(theme.surface)
                            .listRowSeparatorTint(Color.black.opacity(0.06))
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { filteredRecords[$0].id }
                            store.records.removeAll { ids.contains($0.id) }
                        }
                    } header: {
                        Text("本地保存 · 共 \(store.records.count) 次")
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationDestination(for: ScanRecord.self) { ScanResultView(record: $0) }
            }
        }
        .searchable(text: $searchText, prompt: "搜索产品或配料")
        .navigationTitle("扫描记录")
        .toolbar {
            if !store.records.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空", role: .destructive) { confirmsClear = true }
                }
            }
        }
        .confirmationDialog("清空全部扫描记录？", isPresented: $confirmsClear, titleVisibility: .visible) {
            Button("清空记录", role: .destructive) { store.clearHistory() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作无法撤销。")
        }
    }
}

private struct HistoryRow: View {
    let record: ScanRecord

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                rowContent
                Spacer(minLength: 8)
                RiskBadge(risk: record.result.overallRisk)
            }
            VStack(alignment: .leading, spacing: 10) {
                rowContent
                RiskBadge(risk: record.result.overallRisk)
            }
        }
        .padding(.vertical, 6)
    }

    private var rowContent: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(record.result.overallRisk.color.opacity(0.1))
                Image(systemName: record.result.overallRisk.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(record.result.overallRisk.color)
            }
            .frame(width: 54, height: 54)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(record.productName).font(.subheadline.weight(.semibold))
                Text("\(record.result.ingredientTokens.count) 项配料 · \(record.result.additives.count) 个本地匹配 · \(record.createdAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
