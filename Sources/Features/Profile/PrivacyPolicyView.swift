import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(AppTheme.self) private var theme

    var body: some View {
        ZStack {
            theme.canvas.ignoresSafeArea()

            List {
                policySection(
                    title: "处理哪些数据",
                    text: "AddiGuard 会在设备上处理你选择或拍摄的配料表图片、Apple Vision 提取的 OCR 文字、本地拆出的配料名称、分析结果，以及你主动设置的提示偏好。"
                )

                policySection(
                    title: "如何处理",
                    text: "图片始终只由设备上的 Apple Vision 提取文字，不会上传。你可以选择本地分析或在线辅助分析：本地模式不发送任何内容；在线模式需要重新确认，只把本地解析器拆出的配料名称和不透明序号发送给 OpenRouter 的 \(OpenRouterConfiguration.displayName)，由其逐项生成辅助说明。不会发送完整 OCR、产品名、地址、电话、用户画像、扫描历史或本地知识库；如果本地没有拆出配料，应用不会改为上传完整 OCR。"
                )

                policySection(
                    title: "如何保存",
                    text: "最多 100 条扫描结果会写入受系统文件保护且排除备份的本地文件。图片与完整 OCR 只用于当前扫描，不写入历史文件；历史会保存本地拆出的配料名称、分析结果和必要的来源状态。个人提示偏好与分析方式保存在同一受保护文件中，API 凭证不会保存在该文件中。"
                )

                policySection(
                    title: "在线服务说明",
                    text: "在线请求会设置 data_collection=deny，以排除明确声明收集数据的上游提供方，但这不等于零留存保证。OpenRouter、模型提供方 Z.ai，以及 OpenRouter 实际路由到的第三方推理服务商，仍可能依其服务条款长期处理、保留并使用配料文本、回复及请求元数据，包括服务或模型改进许可；模型页面的当前说明与未来政策也可能变化。启用前请基于这一边界重新同意，发布前也必须再次核对 OpenRouter、上游服务和 App Store 的最新隐私要求。"
                )

                policySection(
                    title: "如何删除",
                    text: "你可以删除单条记录、清空扫描历史，或在“我的守护档案”中选择“清除全部本地数据”；后者也会清除在线同意和本地开发凭证。卸载应用会删除受保护文件，但系统可能保留 Keychain 项，因此需要完整清理时请先使用应用内按钮。"
                )

                policySection(
                    title: "重要限制",
                    text: "本地匹配与 AI 辅助说明都可能出错，只用于科普与信息核对。\(OpenRouterConfiguration.displayName) 的文字不会新增、删除或改写本地配料清单，也不会改写本地资料核对优先级。应用没有食品类别、实际添加量、摄入量或完整个体医疗信息，不能据此判断产品是否合规、安全，或替代医生及食品安全专业人员的意见。"
                )

                Section {
                    Text("版本：2026-08-23")
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("App Store 上架前仍需由发布方提供公开可访问的隐私政策与支持网址，并确保其内容与本说明一致。")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("隐私说明")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func policySection(title: String, text: String) -> some View {
        Section(title) {
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        PrivacyPolicyView()
    }
    .environment(AppTheme())
}
