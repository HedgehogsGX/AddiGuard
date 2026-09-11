import PhotosUI
import SwiftUI
import UIKit

private enum ScanPhase: Equatable {
    case idle
    case capturing
    case importing
    case recognizingLocally
    case analyzing(AnalysisMode)
    case demo

    var isBusy: Bool { self != .idle }

    var progressLabel: String? {
        switch self {
        case .idle: nil
        case .capturing: "正在拍摄…"
        case .importing: "正在读取照片…"
        case .recognizingLocally: "正在设备上识别配料文字…"
        case .analyzing(let mode): "正在使用\(mode.title)逐项分析配料…"
        case .demo: "正在解析示例配料…"
        }
    }
}

struct ScanHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.recognitionService) private var recognitionService
    @Environment(\.ingredientAnalysisService) private var ingredientAnalysisService
    @Environment(ScanStore.self) private var store
    @Environment(AppTheme.self) private var theme
    @StateObject private var camera = CameraScanner()

    @Binding var path: [UUID]
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var phase: ScanPhase = .idle
    @State private var errorMessage: String?
    @State private var errorAllowsOfflineRecovery = false
    @State private var activeOperationID: UUID?
    @State private var operationTask: Task<Void, Never>?
    @State private var transientRecord: ScanRecord?
    @State private var pendingOfflineText: String?
    @State private var pendingOfflineProductName: String?
    @State private var pendingOfflineShouldSave = true

    private let demoText = "产品名称：清爽柠檬味汽水\n配料：水、果葡糖浆、白砂糖、食品添加剂（二氧化碳、柠檬酸、柠檬酸钠、苯甲酸钠、蔗糖素、安赛蜜）、食用香精。"

    var body: some View {
        @Bindable var store = store

        ZStack {
            theme.canvas.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    hero
                    ScannerCard(
                        camera: camera,
                        phase: phase,
                        analysisMode: $store.analysisMode,
                        consentVersion: $store.onlineAnalysisConsentVersion,
                        isAPIConfigured: ingredientAnalysisService.isAPIConfigured,
                        selectedPhoto: $selectedPhoto,
                        onCapture: capture,
                        onDemo: analyzeDemo,
                        onRequestPermission: camera.requestPermissionAndActivate,
                        onOpenSettings: openCameraSettings,
                        onRetry: retryCamera
                    )
                    flowSummary
                    trustSources
                }
                .frame(maxWidth: 780)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 18)
                .padding(.bottom, 28)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: UUID.self) { id in
            if let transientRecord, transientRecord.id == id {
                ScanResultView(record: transientRecord)
            } else if let record = store.record(id: id) {
                ScanResultView(record: record)
            } else {
                EmptyStateView(
                    symbol: "exclamationmark.triangle",
                    title: "记录不存在",
                    message: "这条扫描记录可能已被删除。"
                )
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            importPhoto(item)
        }
        .onAppear {
            if scenePhase == .active {
                camera.activate()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                camera.activate()
            } else {
                cancelCurrentOperation()
                camera.deactivate()
            }
        }
        .onDisappear {
            cancelCurrentOperation()
            camera.deactivate()
        }
        .alert(currentAlertTitle, isPresented: Binding(
            get: { errorMessage != nil || store.persistenceErrorMessage != nil },
            set: { if !$0 { dismissCurrentError() } }
        )) {
            if errorAllowsOfflineRecovery {
                Button("改用本地结果") {
                    showPendingOfflineResult()
                }
            }
            Button("知道了", role: .cancel) { dismissCurrentError() }
        } message: {
            Text(errorMessage ?? store.persistenceErrorMessage ?? "请稍后重试。")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            BrandMark()

            VStack(alignment: .leading, spacing: 8) {
                Text("让配料表\n一眼就懂")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .tracking(-1.1)
                Text("拍照提取完整配料，匹配添加剂名称，并保留需要人工确认的文字与资料来源。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 16) {
                MetricLabel(
                    value: recognitionMetricValue,
                    label: "文字提取"
                )
                Divider().overlay(.white.opacity(0.2)).frame(height: 28)
                MetricLabel(value: "名称", label: "知识库匹配")
                Divider().overlay(.white.opacity(0.2)).frame(height: 28)
                MetricLabel(value: "资料", label: "核对提示")
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 26)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentDark, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var flowSummary: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("三步核对配料", eyebrow: "HOW IT WORKS")
            HStack(alignment: .top, spacing: 10) {
                FlowStep(number: "01", symbol: "camera.viewfinder", title: "拍配料")
                FlowConnector()
                FlowStep(number: "02", symbol: "text.viewfinder", title: "提文字")
                FlowConnector()
                FlowStep(number: "03", symbol: "doc.text.magnifyingglass", title: "核资料")
            }
        }
        .cardStyle()
    }

    private var trustSources: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("参考资料")
                .font(.subheadline.weight(.semibold))
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(["GB 2760-2024", "WHO/JECFA", "FDA", "EFSA"], id: \.self) { label in
                    if let source = ReferenceSource.matching(label) {
                        NavigationLink {
                            ReferenceDetailView(source: source)
                        } label: {
                            HStack(spacing: 4) {
                                SourcePill(title: label)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("查看\(source.title)")
                    }
                }
            }
            Text("点开可查看资料说明与官方原文。名称匹配结果用于食品安全科普与资料核对辅助，不构成医疗诊断。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
    }

    private func capture() {
        guard camera.state == .ready,
              let operationID = beginOperation(.capturing) else { return }

        camera.capture { result in
            guard activeOperationID == operationID else { return }
            switch result {
            case .success(let image):
                let mode = store.analysisMode
                phase = .recognizingLocally
                operationTask = Task { @MainActor in
                    await recognizeAndSave(
                        image: image,
                        mode: mode,
                        operationID: operationID
                    )
                }
            case .failure(let error):
                failOperation(operationID, error: error)
            }
        }
    }

    private func analyzeDemo() {
        guard let operationID = beginOperation(.demo) else { return }
        let mode = store.analysisMode

        operationTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(650))
                try Task.checkCancellation()
                guard activeOperationID == operationID else { throw CancellationError() }

                phase = .analyzing(mode)
                let result = try await ingredientAnalysisService.analyze(
                    text: demoText,
                    profile: store.profile,
                    using: mode,
                    consentVersion: store.onlineAnalysisConsentVersion
                )
                let record = ScanRecord(productName: "清爽柠檬味汽水（示例）", result: result)
                transientRecord = record
                finishOperation(operationID)
                path.append(record.id)
            } catch is CancellationError {
                finishOperation(operationID)
            } catch {
                failOperation(
                    operationID,
                    error: error,
                    allowsOfflineRecovery: mode == .api,
                    fallbackText: demoText,
                    fallbackProductName: "清爽柠檬味汽水（示例）",
                    fallbackShouldSave: false
                )
            }
        }
    }

    private func importPhoto(_ item: PhotosPickerItem) {
        selectedPhoto = nil
        guard let operationID = beginOperation(.importing) else { return }

        operationTask = Task { @MainActor in
            do {
                guard let data = try await item.loadTransferable(type: Data.self) else {
                    throw OCRServiceError.invalidImage
                }
                try Task.checkCancellation()
                let image = try await OCRService.downsampleImage(from: data)
                try Task.checkCancellation()
                guard activeOperationID == operationID else { throw CancellationError() }

                let mode = store.analysisMode
                phase = .recognizingLocally
                await recognizeAndSave(
                    image: image,
                    mode: mode,
                    operationID: operationID
                )
            } catch is CancellationError {
                finishOperation(operationID)
            } catch {
                failOperation(operationID, error: error)
            }
        }
    }

    @MainActor
    private func recognizeAndSave(
        image: UIImage,
        mode: AnalysisMode,
        operationID: UUID
    ) async {
        var fallbackText: String?
        var fallbackProductName: String?
        do {
            let text = try await recognitionService.recognizeText(in: image)
            try Task.checkCancellation()
            guard activeOperationID == operationID else { throw CancellationError() }

            let productName = ProductNameParser.extract(from: text) ?? "配料表扫描"
            fallbackText = text
            fallbackProductName = productName
            phase = .analyzing(mode)
            let result = try await ingredientAnalysisService.analyze(
                text: text,
                profile: store.profile,
                using: mode,
                consentVersion: store.onlineAnalysisConsentVersion
            )
            try Task.checkCancellation()
            guard activeOperationID == operationID else { throw CancellationError() }

            let record = store.save(result: result, productName: productName)
            transientRecord = record
            finishOperation(operationID)
            path.append(record.id)
        } catch is CancellationError {
            finishOperation(operationID)
        } catch {
            failOperation(
                operationID,
                error: error,
                allowsOfflineRecovery: mode == .api,
                fallbackText: fallbackText,
                fallbackProductName: fallbackProductName
            )
        }
    }

    private func beginOperation(_ newPhase: ScanPhase) -> UUID? {
        guard phase == .idle else { return nil }
        let operationID = UUID()
        activeOperationID = operationID
        phase = newPhase
        return operationID
    }

    private func finishOperation(_ operationID: UUID) {
        guard activeOperationID == operationID else { return }
        activeOperationID = nil
        operationTask = nil
        phase = .idle
    }

    private func failOperation(
        _ operationID: UUID,
        error: Error,
        allowsOfflineRecovery: Bool = false,
        fallbackText: String? = nil,
        fallbackProductName: String? = nil,
        fallbackShouldSave: Bool = true
    ) {
        guard activeOperationID == operationID else { return }
        finishOperation(operationID)
        errorAllowsOfflineRecovery = allowsOfflineRecovery && fallbackText != nil
        pendingOfflineText = fallbackText
        pendingOfflineProductName = fallbackProductName
        pendingOfflineShouldSave = fallbackShouldSave
        errorMessage = error.localizedDescription
    }

    private var currentAlertTitle: String {
        errorMessage == nil ? "本地存储出现问题" : "无法完成分析"
    }

    private var recognitionMetricValue: String {
        "本地"
    }

    private func showPendingOfflineResult() {
        guard let text = pendingOfflineText else {
            dismissCurrentError()
            return
        }
        let productName = pendingOfflineProductName ?? "配料表扫描"
        let result = IngredientAnalyzer.analyze(text: text, profile: store.profile)
        let record = pendingOfflineShouldSave
            ? store.save(result: result, productName: productName)
            : ScanRecord(productName: productName, result: result)
        store.analysisMode = .offline
        transientRecord = record
        dismissCurrentError()
        path.append(record.id)
    }

    private func dismissCurrentError() {
        errorMessage = nil
        errorAllowsOfflineRecovery = false
        pendingOfflineText = nil
        pendingOfflineProductName = nil
        pendingOfflineShouldSave = true
        store.dismissPersistenceError()
    }

    private func cancelCurrentOperation() {
        activeOperationID = nil
        operationTask?.cancel()
        operationTask = nil
        selectedPhoto = nil
        phase = .idle
    }

    private func retryCamera() {
        guard !phase.isBusy else { return }
        camera.retry()
    }

    private func openCameraSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

private struct ScannerCard: View {
    @ObservedObject var camera: CameraScanner
    let phase: ScanPhase
    @Binding var analysisMode: AnalysisMode
    @Binding var consentVersion: Int?
    let isAPIConfigured: Bool
    @Binding var selectedPhoto: PhotosPickerItem?
    let onCapture: () -> Void
    let onDemo: () -> Void
    let onRequestPermission: () -> Void
    let onOpenSettings: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            analysisModeControl

            ZStack {
                Color(red: 0.055, green: 0.07, blue: 0.06)

                if camera.state == .ready {
                    CameraPreview(
                        session: camera.session,
                        onRotationAngleChange: camera.updateVideoRotationAngle
                    )
                } else {
                    IngredientLabelPlaceholder()
                }

                LinearGradient(
                    colors: [.black.opacity(0.28), .clear, .black.opacity(0.34)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                ScanFrame()

                VStack {
                    HStack {
                        statusPill
                        Spacer()
                    }
                    Spacer()
                    Text("让配料表完整进入框内")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.4), in: Capsule())
                }
                .padding(16)

                if let progressLabel = phase.progressLabel {
                    Color.black.opacity(0.58)
                    VStack(spacing: 12) {
                        ProgressView().tint(.white).scaleEffect(1.15)
                        Text(progressLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(progressLabel)
                }
            }
            .frame(height: 310)
            .clipped()

            recoveryControls

            HStack(spacing: 24) {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ScannerSecondaryAction(symbol: "photo.on.rectangle", title: "相册")
                }
                .disabled(phase.isBusy || !canRecognize)

                Button(action: onCapture) {
                    ZStack {
                        Circle().fill(Color.black)
                        Circle().stroke(Color.white, lineWidth: 4).padding(7)
                        Circle().fill(Color.white).frame(width: 54, height: 54)
                    }
                    .frame(width: 74, height: 74)
                }
                .buttonStyle(.plain)
                .disabled(phase.isBusy || camera.state != .ready || !canRecognize)
                .opacity(camera.state == .ready && canRecognize ? 1 : 0.42)
                .accessibilityLabel("拍照并匹配")

                Button(action: onDemo) {
                    ScannerSecondaryAction(symbol: "sparkles", title: "示例匹配")
                }
                .buttonStyle(.plain)
                .disabled(phase.isBusy)
                .accessibilityHint("使用内置示例查看效果，不会保存到扫描记录")
            }
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var canRecognize: Bool {
        analysisMode == .offline
            || (isAPIConfigured && consentVersion == OnlineAnalysisConsent.currentVersion)
    }

    private var analysisModeControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("分析方式", systemImage: analysisMode.symbol)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if !isAPIConfigured {
                    Text("API 待配置")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }

            AnalysisModePicker(
                selection: $analysisMode,
                consentVersion: $consentVersion,
                isAPIConfigured: isAPIConfigured,
                isDisabled: phase.isBusy
            )

            Text(analysisModeDescription)
                .font(.caption)
                .foregroundStyle(
                    analysisMode == .api && !isAPIConfigured
                        ? Color.orange
                        : Color.secondary
                )
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var analysisModeDescription: String {
        if analysisMode == .api, !isAPIConfigured {
            return "在线分析尚未配置。现在仍可使用本地离线分析；图片始终在设备上识别。"
        }
        if analysisMode == .offline, !isAPIConfigured {
            return "\(analysisMode.detail) 在线逐项说明将在添加服务信息与凭证后开放。"
        }
        return analysisMode.detail
    }

    @ViewBuilder
    private var recoveryControls: some View {
        switch camera.state {
        case .permissionRequired:
            VStack(spacing: 9) {
                Text("启用相机后，可直接拍摄配料表；文字始终在设备上提取，再按所选方式分析。你也可以继续使用相册或示例。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: onRequestPermission) {
                    Label("启用相机", systemImage: "camera")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

        case .denied:
            VStack(spacing: 9) {
                Text("相机权限未开启。你仍可使用相册，或前往系统设置授权。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: onOpenSettings) {
                    Label("前往设置开启相机", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

        case .failed(let message):
            VStack(spacing: 9) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button(action: onRetry) {
                    Label("重试相机", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)

        default:
            EmptyView()
        }
    }

    private var statusPill: some View {
        let label: String
        let color: Color
        switch camera.state {
        case .ready:
            label = "相机已就绪"; color = .riskLow
        case .denied:
            label = "相机权限未开启"; color = .riskModerate
        case .permissionRequired:
            label = "点击下方按钮启用相机"; color = .white
        case .unavailable:
            label = "相机不可用"; color = .white
        case .failed:
            label = "相机不可用"; color = .riskHigh
        case .starting, .requestingPermission, .idle:
            label = "正在准备相机"; color = .white
        }

        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.black.opacity(0.34), in: Capsule())
    }
}

private struct ScannerSecondaryAction: View {
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 38, height: 38)
                .background(Color.black.opacity(0.055), in: Circle())
            Text(title).font(.caption2.weight(.medium))
        }
        .foregroundStyle(.primary)
        .frame(width: 58)
    }
}

private struct IngredientLabelPlaceholder: View {
    var body: some View {
        ZStack {
            Color(red: 0.20, green: 0.23, blue: 0.19)
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.97, green: 0.94, blue: 0.84))
                .frame(width: 270, height: 190)
                .rotationEffect(.degrees(-3))
                .overlay {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("配料表").font(.headline)
                        Rectangle().frame(height: 2)
                        Text("饮用水、白砂糖、山梨酸钾\n抗坏血酸、柠檬酸、食用盐\n亚硝酸钠、天然香料")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .lineSpacing(5)
                    }
                    .foregroundStyle(.black.opacity(0.76))
                    .padding(28)
                    .rotationEffect(.degrees(-3))
                }
                .shadow(color: .black.opacity(0.25), radius: 14, y: 8)
        }
    }
}

private struct ScanFrame: View {
    var body: some View {
        GeometryReader { proxy in
            let size = CGSize(width: proxy.size.width - 76, height: 180)
            let origin = CGPoint(x: 38, y: (proxy.size.height - size.height) / 2)
            Path { path in
                let length: CGFloat = 25
                let corners = [
                    (CGPoint(x: origin.x, y: origin.y), CGPoint(x: origin.x + length, y: origin.y), CGPoint(x: origin.x, y: origin.y + length)),
                    (CGPoint(x: origin.x + size.width, y: origin.y), CGPoint(x: origin.x + size.width - length, y: origin.y), CGPoint(x: origin.x + size.width, y: origin.y + length)),
                    (CGPoint(x: origin.x, y: origin.y + size.height), CGPoint(x: origin.x + length, y: origin.y + size.height), CGPoint(x: origin.x, y: origin.y + size.height - length)),
                    (CGPoint(x: origin.x + size.width, y: origin.y + size.height), CGPoint(x: origin.x + size.width - length, y: origin.y + size.height), CGPoint(x: origin.x + size.width, y: origin.y + size.height - length))
                ]
                for (corner, horizontal, vertical) in corners {
                    path.move(to: horizontal); path.addLine(to: corner); path.addLine(to: vertical)
                }
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct MetricLabel: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.subheadline.weight(.bold))
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.66))
        }
        .foregroundStyle(.white)
    }
}

private struct FlowStep: View {
    let number: String
    let symbol: String
    let title: String

    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(width: 48, height: 48)
            Text(title).font(.caption.weight(.semibold))
            Text(number).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FlowConnector: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 14, height: 1)
            .padding(.top, 24)
    }
}

#Preview("Scan") {
    NavigationStack { ScanHomeView(path: .constant([])) }
        .environment(ScanStore())
        .environment(AppTheme())
}
