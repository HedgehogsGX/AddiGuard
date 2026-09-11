import AVFoundation
import Combine
import UIKit

final class CameraScanner: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    enum State: Equatable {
        case idle
        case permissionRequired
        case requestingPermission
        case starting
        case ready
        case denied
        case unavailable
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    let session = AVCaptureSession()

    private let output = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.addiguard.camera-session")
    private var completion: ((Result<UIImage, Error>) -> Void)?
    private var captureRequestID: Int64?
    private var isConfigured = false
    private var isCaptureInProgress = false
    private var wantsToRun = false
    private var videoRotationAngle: CGFloat = 90

    /// Re-evaluates authorization every time the scan surface becomes active.
    /// This lets the camera recover after the user changes permission in Settings.
    func activate() {
        guard !wantsToRun else { return }
        wantsToRun = true

        guard AVCaptureDevice.default(for: .video) != nil else {
            state = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            beginAuthorizedActivation()
        case .notDetermined:
            wantsToRun = false
            state = .permissionRequired
        case .denied, .restricted:
            state = .denied
        @unknown default:
            state = .unavailable
        }
    }

    func deactivate() {
        wantsToRun = false
        if state == .ready || state == .starting || state == .requestingPermission {
            state = .idle
        }
        if isCaptureInProgress {
            finishCapture(.failure(CancellationError()), requestID: captureRequestID)
        }

        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func retry() {
        deactivate()
        activate()
    }

    func requestPermissionAndActivate() {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined else {
            activate()
            return
        }
        guard !wantsToRun else { return }

        wantsToRun = true
        state = .requestingPermission
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self, self.wantsToRun else { return }
                if granted {
                    self.beginAuthorizedActivation()
                } else {
                    self.state = .denied
                }
            }
        }
    }

    func capture(completion: @escaping (Result<UIImage, Error>) -> Void) {
        guard state == .ready else {
            completion(.failure(CameraError.notReady))
            return
        }
        guard !isCaptureInProgress else {
            completion(.failure(CameraError.captureInProgress))
            return
        }

        isCaptureInProgress = true
        self.completion = completion
        let settings = AVCapturePhotoSettings()
        settings.photoQualityPrioritization = .quality
        let maximumDimensions = output.maxPhotoDimensions
        if maximumDimensions.width > 0, maximumDimensions.height > 0 {
            settings.maxPhotoDimensions = maximumDimensions
        }
        captureRequestID = settings.uniqueID

        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else {
                DispatchQueue.main.async {
                    self.finishCapture(
                        .failure(CameraError.sessionNotRunning),
                        requestID: settings.uniqueID
                    )
                }
                return
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }

    func updateVideoRotationAngle(_ angle: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.videoRotationAngle = angle
            guard let connection = self.output.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }

    private func beginAuthorizedActivation() {
        state = .starting
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                if !self.isConfigured {
                    try self.configureSession()
                    self.isConfigured = true
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                guard self.session.isRunning else {
                    throw CameraError.sessionNotRunning
                }

                DispatchQueue.main.async {
                    guard self.wantsToRun else { return }
                    self.state = .ready
                }
            } catch {
                DispatchQueue.main.async {
                    self.wantsToRun = false
                    self.state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func configureSession() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(for: .video) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        try configureDeviceForLabelCapture(device)
        guard session.canAddInput(input), session.canAddOutput(output) else {
            throw CameraError.configurationFailed
        }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .quality

        if let maximumDimensions = device.activeFormat.supportedMaxPhotoDimensions.max(by: {
            Int64($0.width) * Int64($0.height) < Int64($1.width) * Int64($1.height)
        }) {
            output.maxPhotoDimensions = maximumDimensions
        }

        if let connection = output.connection(with: .video),
           connection.isVideoRotationAngleSupported(videoRotationAngle) {
            connection.videoRotationAngle = videoRotationAngle
        }
    }

    private func configureDeviceForLabelCapture(_ device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isAutoFocusRangeRestrictionSupported {
            device.autoFocusRangeRestriction = .near
        }
        if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
        }
        device.isSubjectAreaChangeMonitoringEnabled = true
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let result: Result<UIImage, Error>
        if let error {
            result = .failure(error)
        } else if let data = photo.fileDataRepresentation(), let image = UIImage(data: data) {
            result = .success(image)
        } else {
            result = .failure(OCRServiceError.invalidImage)
        }

        DispatchQueue.main.async { [weak self] in
            self?.finishCapture(result, requestID: photo.resolvedSettings.uniqueID)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        guard let error else { return }
        DispatchQueue.main.async { [weak self] in
            self?.finishCapture(.failure(error), requestID: resolvedSettings.uniqueID)
        }
    }

    private func finishCapture(
        _ result: Result<UIImage, Error>,
        requestID: Int64?
    ) {
        guard isCaptureInProgress, captureRequestID == requestID else { return }
        let completion = completion
        self.completion = nil
        captureRequestID = nil
        isCaptureInProgress = false
        completion?(result)
    }
}

private enum CameraError: LocalizedError {
    case unavailable
    case configurationFailed
    case notReady
    case sessionNotRunning
    case captureInProgress

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "此设备没有可用相机。"
        case .configurationFailed:
            "相机初始化失败。"
        case .notReady, .sessionNotRunning:
            "相机尚未就绪，请稍后重试。"
        case .captureInProgress:
            "正在拍摄，请等待当前照片处理完成。"
        }
    }
}
