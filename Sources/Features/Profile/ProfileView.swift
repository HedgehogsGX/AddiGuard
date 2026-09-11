import SwiftUI

struct ProfileView: View {
    @Environment(\.ingredientAnalysisService) private var ingredientAnalysisService
    @Environment(ScanStore.self) private var store
    @Environment(AppTheme.self) private var theme

    @State private var confirmsClearAllData = false

    var body: some View {
        @Bindable var store = store

        ZStack {
            theme.canvas.ignoresSafeArea()
            Form {
                Section {
                    profileHeader
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                Section {
                    AnalysisModePicker(
                        selection: $store.analysisMode,
                        consentVersion: $store.onlineAnalysisConsentVersion,
                        isAPIConfigured: ingredientAnalysisService.isAPIConfigured
                    )

                    if store.analysisMode == .api, !ingredientAnalysisService.isAPIConfigured {
                        Label("在线 API 尚未配置，暂时无法使用", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else {
                        Label(analysisModeDetail, systemImage: store.analysisMode.symbol)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("分析方式")
                } footer: {
                    Text("图片始终只在设备上进行 Apple Vision OCR。在线模式仅发送本地拆出的配料名称，由 \(OpenRouterConfiguration.displayName) 逐项生成辅助说明；不发送完整 OCR、用户画像或历史。")
                }

                Section {
                    Picker("适用人群", selection: $store.profile.populationGroup) {
                        ForEach(PopulationGroup.allCases) { group in
                            Label(group.title, systemImage: group.symbol).tag(group)
                        }
                    }

                    Toggle("显示过敏核对提醒", isOn: $store.profile.allergySensitive)
                    Toggle("使用更严格的预警", isOn: $store.profile.prefersStricterWarnings)
                } header: {
                    Text("提示偏好")
                } footer: {
                    Text("这些设置只调整科普提示，不构成个体化医疗或食品安全结论。")
                }

                Section("资料核对优先级") {
                    VStack(alignment: .leading, spacing: 18) {
                        RiskLegendRow(risk: .high, detail: "优先核对用量、适用人群与权威资料")
                        RiskLegendRow(risk: .moderate, detail: "建议结合摄入量与食用频率核对")
                        RiskLegendRow(risk: .low, detail: "当前资料中的关注优先级较低，不等于安全结论")
                        RiskLegendRow(risk: .unrated, detail: "证据或识别覆盖不足，暂时无法判断")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                    .staticInformationRow()
                }

                Section {
                    ForEach(ReferenceSource.profileSources) { source in
                        NavigationLink {
                            ReferenceDetailView(source: source)
                        } label: {
                            InformationRow(
                                symbol: source.symbol,
                                title: source.title,
                                detail: source.subtitle
                            )
                        }
                    }
                } header: {
                    Text("参考资料")
                } footer: {
                    Text("点开可查看资料用途、局限与官方原文。当前版本未读取食品类别、添加量、摄入量或 ADI，因此不能判断产品是否合规或安全。")
                }

                Section("隐私") {
                    InformationRow(
                        symbol: store.analysisMode == .offline ? "lock.shield" : "network",
                        title: store.analysisMode == .offline
                            ? "当前使用本地分析"
                            : "当前选择在线辅助分析",
                        detail: analysisPrivacyDetail
                    )

                    InformationRow(
                        symbol: "internaldrive",
                        title: "历史与偏好写入受文件保护的本地存储",
                        detail: "历史不会上传；最多保留 100 条。图片与完整 OCR 不写入历史，仅保存拆出的配料名称和结果"
                    )

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("隐私说明与数据处理", systemImage: "hand.raised")
                    }

                }

                Section {
                    Button("清除全部本地数据", role: .destructive) {
                        confirmsClearAllData = true
                    }
                } header: {
                    Text("本地数据")
                } footer: {
                    Text("删除扫描历史与本地开发凭证，并将提示偏好、在线同意和分析方式恢复为默认值。")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("我的守护档案")
        .confirmationDialog(
            "清除全部本地数据？",
            isPresented: $confirmsClearAllData,
            titleVisibility: .visible
        ) {
            Button("清除历史与个人设置", role: .destructive) {
                store.clearAllLocalData()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会删除扫描历史与本地开发凭证，并将提示偏好、在线同意和分析方式恢复为默认值。此操作无法撤销。")
        }
        .alert(
            "本地存储出现问题",
            isPresented: Binding(
                get: { store.persistenceErrorMessage != nil },
                set: { if !$0 { store.dismissPersistenceError() } }
            )
        ) {
            Button("知道了") { store.dismissPersistenceError() }
        } message: {
            Text(store.persistenceErrorMessage ?? "未知错误")
        }
    }

    private var analysisModeDetail: String {
        switch store.analysisMode {
        case .offline:
            return "Apple Vision 在设备上提取文字，并使用本地知识库分析；图片和文字均不上传。"
        case .api:
            return "图片仍只在设备上提取文字；仅把本地拆出的配料名称发送给 \(OpenRouterConfiguration.displayName) 生成逐项辅助说明。"
        }
    }

    private var analysisPrivacyDetail: String {
        if store.analysisMode == .offline {
            return "图片与 OCR 文字不会离开设备"
        }
        if ingredientAnalysisService.isAPIConfigured {
            return "不上传图片或完整 OCR；仅发送拆出的配料名称，不发送用户画像或历史。AI 说明不改写本地风险结论"
        }
        return "在线接口尚未配置，不会发送配料名称"
    }

    private var profileHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                profileIcon
                profileSummary
            }
            VStack(alignment: .leading, spacing: 14) {
                profileIcon
                profileSummary
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(.vertical, 10)
    }

    private var profileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.accentDark)
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }

    private var profileSummary: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("AddiGuard 用户")
                .font(.title3.bold())
            Text("已完成 \(store.records.count) 次配料分析")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Label("受保护的本地存储", systemImage: "lock.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(theme.accent)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct RiskLegendRow: View {
    let risk: RiskLevel
    let detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle()
                .fill(risk.color)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(risk.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(risk.title)：\(detail)")
    }
}

private struct InformationRow: View {
    let symbol: String
    let title: String
    var detail: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private extension View {
    func staticInformationRow() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
