import SwiftUI

/// Keeps online analysis explicit: images always stay on-device, and enabling the
/// configured provider requires fresh consent before ingredient names are sent.
struct AnalysisModePicker: View {
    @Binding var selection: AnalysisMode
    @Binding var consentVersion: Int?
    let isAPIConfigured: Bool
    var isDisabled = false

    @State private var showsUnavailableNotice = false
    @State private var confirmsOnlineMode = false

    var body: some View {
        Picker("分析方式", selection: guardedSelection) {
            ForEach(AnalysisMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .disabled(isDisabled)
        .onAppear {
            if selection == .api,
               (!isAPIConfigured || consentVersion != OnlineAnalysisConsent.currentVersion) {
                selection = .offline
            }
        }
        .onChange(of: isAPIConfigured) { _, isConfigured in
            if !isConfigured, selection == .api {
                selection = .offline
            }
        }
        .alert("在线 API 尚未配置", isPresented: $showsUnavailableNotice) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("配置完成并重新确认后才可启用。当前仍使用本地分析；图片始终只在设备上处理。")
        }
        .confirmationDialog(
            "启用在线辅助分析？",
            isPresented: $confirmsOnlineMode,
            titleVisibility: .visible
        ) {
            Button("同意并启用") {
                consentVersion = OnlineAnalysisConsent.currentVersion
                selection = .api
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("图片始终由设备上的 Apple Vision 提取文字，不会上传。在线模式只把本地拆出的配料名称发送给 OpenRouter 的 \(OpenRouterConfiguration.displayName)，供其逐项生成辅助说明；不会发送完整 OCR、用户画像或历史。模型提供方 Z.ai 与 OpenRouter 路由到的第三方推理服务商，可能按服务条款长期保留并使用这些文本与回复，包括服务或模型改进许可。AI 说明不会改写本地风险结论。")
        }
    }

    private var guardedSelection: Binding<AnalysisMode> {
        Binding(
            get: { selection },
            set: { requestedMode in
                guard requestedMode != selection else { return }
                switch requestedMode {
                case .offline:
                    selection = .offline
                case .api where isAPIConfigured:
                    confirmsOnlineMode = true
                case .api:
                    showsUnavailableNotice = true
                }
            }
        )
    }
}
