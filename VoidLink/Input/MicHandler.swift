//
//  MicHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/2.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.

import AVFoundation
#if os(tvOS)
import AVKit
#else
import MediaPlayer
#endif

@objc public protocol MicHandlerDelegate: AnyObject {
    @objc optional func micHandlerDidFinishPlayback(_ handler: MicHandler)
    @objc optional func micHandler(_ handler: MicHandler, didFailWithError error: NSError)
}

@objcMembers
public class MicHandler: NSObject {
    private static let instanceLock = NSLock()
    private static weak var activeInstance: MicHandler?
    @objc public static var sharedInstance: MicHandler? {
        instanceLock.lock()
        defer { instanceLock.unlock() }
        return activeInstance
    }


    private var notificationTokens = [NSObjectProtocol]()
#if os(tvOS)
    private var engine = AVAudioEngine()
    private var tvInputObservation: NSKeyValueObservation?
    private var tvDeviceObservation: NSKeyValueObservation?
    private var tvConnectedDevice: AnyObject?
    private var tvPickerCoordinator: AnyObject?
    private var tvPreferredInputUID: String?
    private var tvInputRetry: DispatchWorkItem?
    private var tvRetryCount = 0
    private var tvBluetoothRouteObserved = false
    private var tvInputDiscoveryStarted: UInt64 = 0
    private var tvInterrupted = false
    private var tvPlaybackResetting = false
    private var tvDisposed = false
    private var tvTapInstalled = false
    private let tvCaptureQueue = DispatchQueue(label: "tv.mic.capture")
    private let tvBufferSlots = DispatchSemaphore(value: 4)
    // Converter and generation are confined to tvCaptureQueue.
    private var tvConverter: AVAudioConverter?
    private var tvCaptureGeneration = 0
    // Diagnostic counters are confined to the existing PCM bufferQueue.
    private var tvSentPackets = 0
    private var tvSendFailures = 0
    private var tvPeak: Float = 0
    private var tvReportUptime: UInt64 = 0
    private var tvReportPackets = 0
#else
    private var engine = AVAudioEngine()
    private var iosResumeAfterPlaybackReset = false
    private let iosControlQueue = DispatchQueue(label: "mic.capture.control", qos: .userInitiated)
    private let iosControlQueueKey = DispatchSpecificKey<Bool>()
#endif
    private let playerNode = AVAudioPlayerNode()
    private var audioSink: Any?
    private var micInputFormat: AVAudioFormat!
    private var isRecording = false
    private var useBuiltinMic = false
    private var voiceProcessing = false
    private var micMuted = false // Capture pause; protected by bufferQueue.
    private var softwareMicMuted = false // Send gain only; protected by bufferQueue.
    private var voiceProcessingSendResumeUptime: UInt64 = 0 // Protected by bufferQueue.
    private var resumeCaptureAfterMute = false // Platform capture control queue.
    private var voiceProcessingBeforeMute: Bool?
    // A handler created for playback stays dormant until explicitly unmuted.
    private var playbackSessionBeforeCapture: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
#if !os(tvOS)
    private var iosDisposed = false
    private var voiceProcessingSessionMode: AVAudioSession.Mode?
    private var captureSessionBeforePause: (category: AVAudioSession.Category, mode: AVAudioSession.Mode, options: AVAudioSession.CategoryOptions)?
    private var systemVolumeView: MPVolumeView? // Main thread only.
    private weak var systemVolumeContainerView: UIView? // Main thread only.
    private var systemVolumeRestoreGeneration: Int? // Owns the temporary mount; main thread only.
    private var volumeRestoreGeneration = 0 // Protected by bufferQueue.
    private var volumeRestoreStopped = false // Protected by bufferQueue.
#endif
    
    private var pcm16BufferDeque = Deque<Int16>()
    private var pcm16BufferArray: [Int16] = []
    private let bufferQueue = DispatchQueue(label: "pcm.buffer.queue")
    private var timer: SafeTimer?
    private static var volume: Float = 1.0

    /*
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private var recordedPCM16: [Data] = []
    private var recordedOpusPackets: [Data] = []
    */
    
    private var opusEncoder: OpaquePointer?
    private var opusDecoder: OpaquePointer?
#if !os(tvOS)
    private var iosEncodeErrorReported = false
    private var iosReceivedFirstBuffer = false
#endif
    
    private var sequenceNumber: UInt16 = 0
    private let ssrc: UInt32 = 0x12345678
    
    private var globalTimestamp: TimeInterval = 0


    public weak var delegate: MicHandlerDelegate?

    @objc public convenience init(useBuiltinMic: Bool) {
        self.init(useBuiltinMic: useBuiltinMic, voiceProcessing: false)
    }

    @objc public convenience init(useBuiltinMic: Bool, voiceProcessing: Bool) {
        self.init(useBuiltinMic: useBuiltinMic, voiceProcessing: voiceProcessing, deferCapture: false)
    }

    @objc public init(useBuiltinMic: Bool, voiceProcessing: Bool, deferCapture: Bool) {
        super.init()
#if !os(tvOS)
        iosControlQueue.setSpecific(key: iosControlQueueKey, value: true)
#endif
        
        let token = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleInterruption(notification)
        }
        notificationTokens.append(token)

        self.useBuiltinMic = useBuiltinMic
        self.voiceProcessing = voiceProcessing
        let session = AVAudioSession.sharedInstance()
        if deferCapture {
            playbackSessionBeforeCapture = (session.category, session.mode, session.categoryOptions)
            micMuted = true
        }
#if os(tvOS)
        observeTVInputs()
#else
        observePlaybackReset()
        iosControlQueue.sync {
            guard playbackSessionBeforeCapture == nil else {
                NSLog("[IOSMic] initialized dormant: voiceProcessing=false, capture and sender stopped")
                return
            }
            do {
                try configureSession()
                try configureEngine()
            } catch {
                NSLog("%@", "[IOSMic] initialization failed: \(error)")
                notify(error)
            }
        }
#endif
        Self.instanceLock.lock()
        Self.activeInstance = self
        Self.instanceLock.unlock()
    }
    
    
    /* ----------- Mic permission -------------*/
    /// 请求麦克风权限
    /// - Parameter completion: 可选 block，如果为 nil 且未授权，会弹窗提示跳转系统设置
    @objc static func requestPermission(_ completion: ((Bool) -> Void)? = nil) {
#if os(tvOS)
        guard #available(tvOS 17.0, *) else { completion?(false); return }
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if let completion { completion(granted) }
                else if !granted { showSettingsAlert() }
            }
        }
#else
        let permission = AVAudioSession.sharedInstance().recordPermission
        switch permission {
        case .granted:
            completion?(true)
        case .denied:
            if let callback = completion {
                callback(false)
            } else {
                showSettingsAlert()
            }
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async {
                    if granted {
                        completion?(true)
                    } else {
                        if let callback = completion {
                            callback(false)
                        } else {
                            showSettingsAlert()
                        }
                    }
                }
            }
        @unknown default:
            if let callback = completion {
                callback(false)
            } else {
                showSettingsAlert()
            }
        }
#endif
    }
        
    /// 弹窗提示用户跳转系统设置（英文版）
    private static func showSettingsAlert() {
        guard let topVC = topViewController() else { return }
        let alert = UIAlertController(
            title:  LocalizationHelper.localizedString(forKey: "Microphone Permission") ,
            message: LocalizationHelper.localizedString(forKey: "micPermissionTip"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Go to Settings") , style: .default, handler: { _ in
            openSettings()
        }))
        topVC.present(alert, animated: true, completion: nil)
    }
    
    /// 打开系统设置
    @objc static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    /// 检查麦克风权限状态（返回 Int，OC 可用）
    @objc static func permissionGranted() -> Bool {
#if os(tvOS)
        if #available(tvOS 17.0, *) { return AVAudioApplication.shared.recordPermission == .granted }
        return false
#else
        return AVAudioSession.sharedInstance().recordPermission == AVAudioSession.RecordPermission.granted
#endif
    }
    
    /// 获取最顶层 UIViewController
    private static func topViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return topViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return topViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return topViewController(base: presented)
        }
        return base
    }
    /* ----------------------------------------*/

    
    /* ----------- Audio Session -------------*/
    
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

#if !os(tvOS)
        if DispatchQueue.getSpecific(key: iosControlQueueKey) != true {
            iosControlQueue.async { [weak self] in self?.handleInterruption(notification) }
            return
        }
        guard !iosDisposed else { return }
#endif
#if os(tvOS)
        tvInterrupted = type == .began
        if tvInterrupted { stopTVCapture() }
        else if UIApplication.shared.applicationState == .active { scheduleTVInputRefresh() }
#else
        // Capture is already stopped during a user pause. An interruption must not
        // clear the user's pending resume or rebuild an engine in playback mode.
        guard !bufferQueue.sync(execute: { micMuted }) else {
            NSLog("%@", "[IOSMic] interruption while paused: type=\(type.rawValue), resumePending=\(resumeCaptureAfterMute)")
            return
        }
        switch type {
        case .began:
            self.stopTapping(stopEngine: true)
        case .ended:
            do {
                try configureEngine()
            } catch {
                notify(error)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                self.startTapping()
            }
        @unknown default:
            break
        }
#endif
    }

    private func configureOpus(sampleRate: Int32, channels: Int) throws {
        var err: Int32 = 0
        guard let enc = opus_encoder_create(sampleRate, Int32(channels), OPUS_APPLICATION_VOIP, &err), err == OPUS_OK else {
            throw NSError(domain: "Opus", code: Int(err), userInfo: nil)
        }

        opusEncoder = enc

        guard let dec = opus_decoder_create(sampleRate, Int32(channels), &err), err == OPUS_OK else {
            throw NSError(domain: "Opus", code: Int(err), userInfo: nil)
        }
        opusDecoder = dec

        // Optional: But defaults are fine. Only change when needed:
        opus_encoder_ctl_wrapper(enc, Int32(OPUS_SET_BITRATE_REQUEST), opus_int32(64000))      // Set bitrate
        opus_encoder_ctl_wrapper(enc, Int32(OPUS_SET_COMPLEXITY_REQUEST), opus_int32(5))         // Set complexity
        opus_encoder_ctl_wrapper(enc, Int32(OPUS_SET_SIGNAL_REQUEST), OPUS_SIGNAL_VOICE)      // Set signal type
    }

    @objc public func startTapping() {
#if os(tvOS)
        Self.onTVMain {
            guard !self.tvDisposed, Self.permissionGranted() else {
                NSLog("[TVMic] start rejected: disposed or microphone permission unavailable")
                return
            }
            if self.bufferQueue.sync(execute: { self.micMuted }) {
                self.resumeCaptureAfterMute = true
                return
            }
            self.isRecording = true
            self.tvRetryCount = 0
            self.tvBluetoothRouteObserved = Self.hasTVBluetoothRoute(AVAudioSession.sharedInstance())
            self.tvInputDiscoveryStarted = DispatchTime.now().uptimeNanoseconds
            self.refreshTVInput()
            // Pairing must not depend on successful activation of an input-less audio session.
            self.offerTVPairingIfNeeded()
        }
#else
        guard !iosDisposed else { return }
        if DispatchQueue.getSpecific(key: iosControlQueueKey) != true {
            iosControlQueue.sync { self.startTapping() }
            return
        }
        if bufferQueue.sync(execute: { micMuted }) {
            resumeCaptureAfterMute = true
            return
        }
        // A paused microphone has no running capture graph. Recreate it on demand.
        if !engine.isRunning {
            do {
                if audioSink == nil {
                    try configureSession()
                    try configureEngine()
                } else {
                    engine.prepare()
                    try engine.start()
                }
            } catch {
                NSLog("%@", "[IOSMic] capture resume failed: \(error)")
                notify(error)
                return
            }
        }
        // recordedBuffers.removeAll()
        isRecording = true
        self.timer?.start()
        /*
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.stop()
            self.playbackRecorded()
            self.playbackOpus()
        }*/
#endif
    }

    @objc public func stopTapping(stopEngine:Bool) {
#if os(tvOS)
        Self.onTVMain {
            self.resumeCaptureAfterMute = false
            self.isRecording = false
            self.tvInputRetry?.cancel()
            self.tvInputRetry = nil
            self.stopTVCapture()
        }
#else
        if DispatchQueue.getSpecific(key: iosControlQueueKey) != true {
            iosControlQueue.sync { self.stopTapping(stopEngine: stopEngine) }
            return
        }
        iosResumeAfterPlaybackReset = false
        resumeCaptureAfterMute = false
        isRecording = false
        self.timer?.pause()
        // engine.inputNode.removeTap(onBus: 0)
        if(stopEngine){
            playerNode.stop()
            engine.stop()
        }
#endif
    }

    @objc public func setMicMuted(_ muteMic: Bool) {
#if os(tvOS)
        Self.onTVMain { self.applyMicMute(muteMic) }
#else
        iosControlQueue.async { [weak self] in self?.applyMicMute(muteMic) }
#endif
    }

#if !os(tvOS)
    @objc(prepareSystemVolumeRestoreInView:)
    public func prepareSystemVolumeRestore(in view: UIView) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self, weak view] in
                if let view { self?.prepareSystemVolumeRestore(in: view) }
            }
            return
        }
        guard !bufferQueue.sync(execute: { volumeRestoreStopped }) else { return }
        systemVolumeContainerView = view
        if systemVolumeView == nil {
            systemVolumeView = MPVolumeView(frame: CGRect(x: -200, y: -40, width: 160, height: 28))
        }
        // Keep it detached while idle so hardware buttons can show the system HUD.
    }

    private func finishSystemVolumeRestore(generation: Int) {
        // A stale callback must not detach a newer volume write's control.
        guard systemVolumeRestoreGeneration == generation else { return }
        systemVolumeView?.removeFromSuperview()
        systemVolumeRestoreGeneration = nil
    }

    private func restoreSystemVolume(_ volume: Float, generation: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.bufferQueue.sync(execute: {
                !self.volumeRestoreStopped && self.volumeRestoreGeneration == generation
            }), let volumeView = self.systemVolumeView, let container = self.systemVolumeContainerView else { return }
            self.systemVolumeRestoreGeneration = generation
            container.addSubview(volumeView)
            volumeView.layoutIfNeeded()
            // Let the control attach and restarted I/O settle before writing volume.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                guard self.bufferQueue.sync(execute: {
                    !self.volumeRestoreStopped && self.volumeRestoreGeneration == generation
                }) else {
                    self.finishSystemVolumeRestore(generation: generation)
                    return
                }
                guard let slider = volumeView.subviews.compactMap({ $0 as? UISlider }).first else {
                    self.finishSystemVolumeRestore(generation: generation)
                    NSLog("[IOSMic] volume restore skipped: system volume slider unavailable")
                    return
                }
                let session = AVAudioSession.sharedInstance()
                let before = session.outputVolume
                slider.setValue(min(max(volume, 0), 1), animated: false)
                slider.sendActions(for: .valueChanged)
                slider.sendActions(for: .touchUpInside)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self else { return }
                    defer { self.finishSystemVolumeRestore(generation: generation) }
                    guard self.bufferQueue.sync(execute: {
                        !self.volumeRestoreStopped && self.volumeRestoreGeneration == generation
                    }) else { return }
                    NSLog("%@", "[IOSMic] volume restore trial: requested=\(volume), before=\(before), actual=\(session.outputVolume), mode=\(session.mode.rawValue)")
                }
            }
        }
    }
#endif

    private func applyMicMute(_ muteMic: Bool) {
#if os(tvOS)
        guard !tvDisposed else { return }
#else
        guard !iosDisposed else { return }
#endif
        // Redirect enabled at startup: keep capture, sending and VPIO running.
        // Apply mute at encoding so samples already queued are also silenced.
        if playbackSessionBeforeCapture == nil {
            let changed = bufferQueue.sync { () -> Bool in
                guard softwareMicMuted != muteMic else { return false }
                softwareMicMuted = muteMic
                return true
            }
            if changed { NSLog("[Mic] software mute=%d", muteMic) }
            return
        }
        guard bufferQueue.sync(execute: { micMuted != muteMic }) else { return }
        let resume = muteMic ? isRecording : (resumeCaptureAfterMute || playbackSessionBeforeCapture != nil)
        let startsPlaybackCapture = !muteMic && playbackSessionBeforeCapture != nil
        if !muteMic, playbackSessionBeforeCapture != nil {
            guard Self.permissionGranted() else { return }
            voiceProcessing = true
#if !os(tvOS)
            voiceProcessingSessionMode = .videoChat
            let session = AVAudioSession.sharedInstance()
            let mix: AVAudioSession.CategoryOptions = session.categoryOptions.contains(.duckOthers) ? .duckOthers : .mixWithOthers
            let bluetooth: AVAudioSession.CategoryOptions = useBuiltinMic ? .allowBluetoothA2DP : .allowBluetooth
            captureSessionBeforePause = (.playAndRecord, .videoChat, mix.union(.defaultToSpeaker).union(bluetooth))
#endif
        }
#if !os(tvOS)
        let savedVolume = AVAudioSession.sharedInstance().outputVolume
        let volumeGeneration = bufferQueue.sync { () -> Int in
            volumeRestoreGeneration += 1
            return volumeRestoreGeneration
        }
#endif
        var active = false
        if muteMic, engine.isRunning, #available(iOS 13.0, tvOS 17.0, *) {
            active = engine.inputNode.isVoiceProcessingEnabled
        }
        if muteMic {
            voiceProcessingBeforeMute = active
#if !os(tvOS)
            let session = AVAudioSession.sharedInstance()
            if captureSessionBeforePause == nil {
                captureSessionBeforePause = (session.category, session.mode, session.categoryOptions)
            }
            if active {
                let mode = session.mode
                voiceProcessingSessionMode = mode == .default ? .voiceChat : mode
            }
#endif
        }
        let restoreProcessing = voiceProcessingBeforeMute == true
        bufferQueue.sync {
            micMuted = muteMic
            pcm16BufferDeque.removeAll()
            pcm16BufferArray.removeAll()
            if let encoder = opusEncoder { opus_encoder_ctl_wrapper(encoder, Int32(OPUS_RESET_STATE), 0) }
        }
        if !muteMic {
            if restoreProcessing {
                voiceProcessing = true
#if !os(tvOS)
                voiceProcessingSessionMode = .videoChat
#endif
            }
            voiceProcessingBeforeMute = nil
        }
        // Muting stops both hardware capture and the sender, even without VPIO.
        // Remember the running state separately so lifecycle stops can cancel resume.
#if os(tvOS)
        if muteMic {
            stopTapping(stopEngine: true)
            resumeCaptureAfterMute = resume
            if let previous = playbackSessionBeforeCapture {
                voiceProcessing = false
                do {
                    // stopTVCapture already replaced the engine with an empty graph.
                    try AVAudioSession.sharedInstance().setCategory(previous.category, mode: previous.mode, options: previous.options)
                } catch { notify(error) }
            }
            NSLog("[TVMic] microphone paused: capture stopped, sending stopped")
        } else {
            resumeCaptureAfterMute = false
            if resume { startTapping() }
        }
#else
        logPlaybackResetState("before mic mute=\(muteMic)")
        NSLog("%@", "[IOSMic] mute transition: muted=\(muteMic), resume=\(resume), restoreVoiceProcessing=\(restoreProcessing), savedSession=\(captureSessionBeforePause != nil)")
        do {
            if muteMic {
                stopTapping(stopEngine: true)
                resumeCaptureAfterMute = resume
                resetIOSCaptureGraph()
                // Playback implicitly supports A2DP; explicitly adding the recording
                // option can fail with paramErr (-50). Keep only the duck/mix choice.
                let session = AVAudioSession.sharedInstance()
                let mixOption: AVAudioSession.CategoryOptions =
                    captureSessionBeforePause?.options.contains(.duckOthers) == true ? .duckOthers : .mixWithOthers
                if let previous = playbackSessionBeforeCapture {
                    voiceProcessing = false
                    try session.setCategory(previous.category, mode: previous.mode, options: previous.options)
                } else {
                    try session.setCategory(.playback, mode: .default, options: mixOption)
                }
            } else {
                resumeCaptureAfterMute = false
                if resume {
                    if startsPlaybackCapture {
                        try configureSession()
                        try configureEngine()
                    }
                    startTapping()
                }
            }
            logPlaybackResetState("after mic mute=\(muteMic)")
            if restoreProcessing {
                let volume = min(max(savedVolume, 0), 1)
                // Gentle slider compensation only when disabling active VPIO.
                let targetVolume = muteMic ? volume + (PublicUtils.isIPhone ? 0.181 : 0.41) * volume * (1 - volume) : volume
                restoreSystemVolume(targetVolume, generation: volumeGeneration)
            }
        } catch {
            stopTapping(stopEngine: true)
            // The microphone is still paused if changing the playback session failed.
            // Preserve its running intent so unmuting can restore capture afterward.
            if muteMic { resumeCaptureAfterMute = resume }
            if startsPlaybackCapture, let previous = playbackSessionBeforeCapture {
                resetIOSCaptureGraph()
                bufferQueue.sync { micMuted = true }
                voiceProcessing = false
                do {
                    try AVAudioSession.sharedInstance().setCategory(previous.category, mode: previous.mode, options: previous.options)
                } catch {
                    NSLog("%@", "[IOSMic] playback recovery failed: \(error)")
                }
            }
            NSLog("%@", "[IOSMic] microphone mute reconfiguration failed: \(error)")
            notify(error)
        }
#endif
    }

    private func preferredMicrophoneInput(from inputs: [AVAudioSessionPortDescription]) -> AVAudioSessionPortDescription? {
#if !os(tvOS)
        if useBuiltinMic { return inputs.first(where: { $0.portType == .builtInMic }) }
#else
        // On tvOS this setting forces Continuity, even when a Bluetooth mic is available.
        if useBuiltinMic {
            if #available(tvOS 17.0, *) {
                return inputs.first(where: { $0.uid == tvPreferredInputUID && $0.portType == .continuityMicrophone })
                    ?? inputs.first(where: { $0.portType == .continuityMicrophone })
            }
            return nil
        }
#endif
        if let bluetooth = inputs.first(where: { $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE }) { return bluetooth }
#if os(tvOS)
        if #available(tvOS 17.0, *) {
            return inputs.first(where: { $0.uid == tvPreferredInputUID })
                ?? inputs.first(where: { $0.portType == .continuityMicrophone })
        }
#endif
        return nil
    }

    private func configureSession() throws {
#if os(tvOS)
        let session = AVAudioSession.sharedInstance()
        guard #available(tvOS 17.0, *) else { return }
        // ArInit configures the session before capture. Recover if that attempt failed
        // or the playback backend subsequently replaced its category/options.
        // tvOS has no built-in mic. Do not activate input I/O until the system reports an input.
        // Input selection itself requires an active session (Apple QA1799).
        tvBluetoothRouteObserved = tvBluetoothRouteObserved || Self.hasTVBluetoothRoute(session)
        let continuityConnected = (tvConnectedDevice as? AVContinuityDevice).map {
            $0.isConnected && $0.audioSessionInputs.contains { $0.portType == .continuityMicrophone }
        } ?? false
        // A2DP output can appear before HFP input. Activate to let the system publish
        // the input route instead of waiting on isInputAvailable in a circular dependency.
        if useBuiltinMic {
            // Pair the phone first; Bluetooth input must not trigger capture activation.
            guard preferredMicrophoneInput(from: session.availableInputs ?? []) != nil || continuityConnected else { return }
        } else {
            guard session.isInputAvailable || tvBluetoothRouteObserved || continuityConnected else { return }
        }
        let bluetoothOption: AVAudioSession.CategoryOptions = useBuiltinMic ? .allowBluetoothA2DP : .allowBluetoothHFP
        let options = bluetoothOption.union(.mixWithOthers)
        if session.category != .playAndRecord || !session.categoryOptions.contains(options)
            || (useBuiltinMic && session.categoryOptions.contains(.allowBluetoothHFP)) {
            NSLog("%@", "[TVMic] restoring microphone session: category=\(session.category.rawValue), options=\(session.categoryOptions.rawValue)")
            try session.setCategory(.playAndRecord, mode: .default, options: options)
        }
        do {
            try session.setActive(true)
        } catch {
            NSLog("%@", "[TVMic] audio session activation failed: \(error)")
            throw error
        }
        let preferred = preferredMicrophoneInput(from: session.availableInputs ?? [])
        if let input = preferred {
            if session.preferredInput?.uid != input.uid {
                try session.setPreferredInput(input)
                NSLog("%@", "[TVMic] selected microphone: \(input.portType.rawValue)")
            }
        }
#else
        let session = AVAudioSession.sharedInstance()
        // Restore input-capable category/options before selecting a microphone or
        // querying capture formats. The shared session stays active throughout.
        if !bufferQueue.sync(execute: { micMuted }), let previous = captureSessionBeforePause {
            let mode = voiceProcessing ? (voiceProcessingSessionMode ?? previous.mode) : previous.mode
            // Playback cannot supply microphone input. Always restore a recording
            // category even if another audio owner changed it before the pause.
            try session.setCategory(.playAndRecord, mode: mode, options: previous.options)
            try session.setActive(true)
            NSLog("%@", "[IOSMic] capture session restored: category=\(session.category.rawValue), mode=\(session.mode.rawValue), inputAvailable=\(session.isInputAvailable)")
            captureSessionBeforePause = nil
        }
        /*
        let bluetoothAudioOption = self.useBuiltinMic ? AVAudioSession.CategoryOptions.allowBluetoothA2DP : AVAudioSession.CategoryOptions.allowBluetooth
        try session.setCategory(.playAndRecord, mode: .default, options: [.mixWithOthers, .defaultToSpeaker, bluetoothAudioOption])
        
        if #available(iOS 13.0, *) {
            try session.setAllowHapticsAndSystemSoundsDuringRecording(true)
        } */
        // AVAudioSession Initiailized in Connection.m -> ArInit
        
        if let input = preferredMicrophoneInput(from: session.availableInputs ?? []) {
            try session.setPreferredInput(input)
            NSLog("%@", "[IOSMic] selected microphone: \(input.portType.rawValue)")
        }
        // try session.setActive(true)
        NSLog("%@", "[IOSMic] session: builtinRequested=\(useBuiltinMic), category=\(session.category.rawValue), options=\(session.categoryOptions.rawValue), available=\(session.availableInputs?.map { $0.portType.rawValue } ?? []), preferred=\(session.preferredInput?.portType.rawValue ?? "none"), inputs=\(session.currentRoute.inputs.map { $0.portType.rawValue }), outputs=\(session.currentRoute.outputs.map { $0.portType.rawValue })")
#endif
    }

    private func sendOpusFrameFromDequeBuffer() {
        bufferQueue.sync {
            guard !micMuted else { return }
            if pcm16BufferDeque.count >= 960 {
                let chunk = softwareMicMuted ? [Int16](repeating: 0, count: 960) : Array(pcm16BufferDeque.prefix(960))
                var packet = [UInt8](repeating: 0, count: 4000)
                guard let enc = self.opusEncoder else {return}
                let outBytes = opus_encode(enc, chunk, 960, &packet, Int32(packet.count))
#if !os(tvOS)
                guard outBytes > 0 else {
                    if !iosEncodeErrorReported {
                        iosEncodeErrorReported = true
                        NSLog("%@", "[IOSMic] Opus encoding failed: code=\(outBytes), sampleRate=\(micInputFormat.sampleRate), channels=\(micInputFormat.channelCount)")
                    }
                    pcm16BufferDeque.removeFirst(960)
                    return
                }
#endif
#if os(tvOS)
                if DispatchTime.now().uptimeNanoseconds >= voiceProcessingSendResumeUptime {
                    let result = sendMicrophoneOpusData(packet, outBytes)
                    reportTVSend(result, opusLength: outBytes)
                }
#else
                if DispatchTime.now().uptimeNanoseconds >= voiceProcessingSendResumeUptime {
                    sendMicrophoneOpusData(packet, outBytes)
                }
#endif
                let removeCount = min(960, pcm16BufferDeque.count)
                if removeCount > 0 {
                    pcm16BufferDeque.removeFirst(removeCount)
                }
            }
        }
    }
    
    private func sendOpusFrameFromArrayBuffer() {
        bufferQueue.sync {
            guard !micMuted else { return }
            if pcm16BufferArray.count >= 960 {
                let chunk = softwareMicMuted ? [Int16](repeating: 0, count: 960) : Array(pcm16BufferArray.prefix(960))
                var packet = [UInt8](repeating: 0, count: 4000)
                guard let enc = self.opusEncoder else {return}
                let outBytes = opus_encode(enc, chunk, 960, &packet, Int32(packet.count))
                if DispatchTime.now().uptimeNanoseconds >= voiceProcessingSendResumeUptime {
                    sendMicrophoneOpusData(packet, outBytes)
                }
                let removeCount = min(960, pcm16BufferArray.count)
                if removeCount > 0 {
                    pcm16BufferArray.removeFirst(removeCount)
                }
            }
        }
    }

    @objc public static func setVolume(_ linearVolume: Float) {
        let clamped = max(0.0, min(1.5, linearVolume))
        let exponent: Float = 1.7
        MicHandler.volume = powf(clamped, exponent)
    }
    
    private func configureEngine() throws {
        guard !bufferQueue.sync(execute: { micMuted }) else { return }
#if os(tvOS)
        if #available(tvOS 17.0, *) { try configureTVEngine() }
#else
        let input = engine.inputNode
        try configureVoiceProcessing(input)
        micInputFormat = input.inputFormat(forBus: 0)
        let sourceFormat = input.outputFormat(forBus: 0)
        var captureConverter: AVAudioConverter?
        if !useBuiltinMic || voiceProcessing, #available(iOS 13.0, *) {
            guard sourceFormat.sampleRate > 0, sourceFormat.channelCount > 0,
                  let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false),
                  let converter = AVAudioConverter(from: sourceFormat, to: target) else {
                throw NSError(domain: "IOSMic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone capture format is unavailable"])
            }
            micInputFormat = target
            captureConverter = converter
            NSLog("%@", "[IOSMic] normalized capture: source=\(sourceFormat), target=48000Hz mono")
        }
        
        try self.configureOpus(sampleRate: Int32(micInputFormat.sampleRate), channels: Int(micInputFormat.channelCount))

        if #available(iOS 13.0, tvOS 13.0, *) {
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.02)
            let captureFormat = captureConverter == nil ? micInputFormat! : sourceFormat
            let converter = captureConverter
            iosReceivedFirstBuffer = false
            
            let sinkNode = AVAudioSinkNode { timestamp, frameCount, audioBufferList -> OSStatus in
                
                guard self.isRecording else { return noErr}

                if let converter {
                    guard let source = AVAudioPCMBuffer(pcmFormat: captureFormat, frameCapacity: frameCount) else { return noErr }
                    source.frameLength = frameCount
                    let inputBuffers = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: audioBufferList))
                    let copiedBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
                    for index in 0..<min(inputBuffers.count, copiedBuffers.count) {
                        if let from = inputBuffers[index].mData, let to = copiedBuffers[index].mData {
                            memcpy(to, from, Int(min(inputBuffers[index].mDataByteSize, copiedBuffers[index].mDataByteSize)))
                        }
                    }
                    self.appendConvertedSamples(source, using: converter)
                    return noErr
                }
                
                let abl = audioBufferList.pointee.mBuffers
                guard let data = abl.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                let samples = UnsafeBufferPointer(start: data, count: Int(frameCount))
                
                self.appendFloatSamples(samples)
                
                return noErr
            }
            
            audioSink = sinkNode
            engine.attach(audioSink! as! AVAudioNode)
            engine.connect(engine.inputNode, to: audioSink as! AVAudioNode, format: captureFormat)
            
            configureDequeTimer()
        }
        else{
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: micInputFormat)
            input.installTap(onBus: 0, bufferSize: 5760, format: micInputFormat) { [weak self] buffer, _ in
                guard let self = self, self.isRecording else { return }
                
                // ===============================
                // 把 buffer 转成 PCM16 并保存
                let frameLength = Int(buffer.frameLength)
                let channels = Int(buffer.format.channelCount)
                var pcm16InterleavedBuffer = [Int16](repeating: 0, count: frameLength * channels)

                if let floatPtrs = buffer.floatChannelData {
                    for ch in 0..<channels {
                        let floatPtr = floatPtrs[ch]
                        for i in 0..<frameLength {
                            let f = floatPtr[i] * MicHandler.volume
                            // 把 float 转到 Int16 范围：假设 float 在 -1…+1 之间
                            // 乘以 Int16.max (32767)，再做裁剪
                            let scaled = f * Float(Int16.max)
                            let clipped: Float
                            if scaled > Float(Int16.max) {
                                clipped = Float(Int16.max)
                            } else if scaled < Float(Int16.min) {
                                clipped = Float(Int16.min)
                            } else {
                                clipped = scaled
                            }
                            pcm16InterleavedBuffer[i * channels + ch] = Int16(clipped)
                        }
                    }
                }

                // 现在 pcm16InterleavedBuffer 里就是转换后的 Int16 数据
                self.bufferQueue.sync {
                    guard !self.micMuted else { return }
                    self.pcm16BufferArray.append(contentsOf: pcm16InterleavedBuffer)
                }
            }
            
            // 开定时器，每 20ms 触发一次
            self.timer = SafeTimer(interval:0.02, delay: 0.05) {
                self.sendOpusFrameFromArrayBuffer()
            }
        }
        
        engine.prepare()
        try engine.start()
        NSLog("%@", "[IOSMic] engine started: sampleRate=\(micInputFormat.sampleRate), channels=\(micInputFormat.channelCount), inputs=\(AVAudioSession.sharedInstance().currentRoute.inputs.map { $0.portType.rawValue })")
#endif
    }
    
    // Configure before querying formats or starting I/O on either platform.
    private func configureVoiceProcessing(_ input: AVAudioInputNode) throws {
        let enabled = bufferQueue.sync { !micMuted && voiceProcessing }
#if !os(tvOS)
        let session = AVAudioSession.sharedInstance()
        // Restore the working capture mode before enabling VPIO. Never force default
        // while VPIO is enabled, as that can interfere with echo cancellation.
        if enabled, let mode = voiceProcessingSessionMode, session.mode != mode {
            try session.setMode(mode)
        }
#endif
        if #available(iOS 13.0, tvOS 17.0, *), input.isVoiceProcessingEnabled != enabled {
            try input.setVoiceProcessingEnabled(enabled)
            bufferQueue.sync {
                // Only a successful off -> on transition suppresses packets for 100ms.
                // Both senders still encode and consume PCM normally during this window.
                voiceProcessingSendResumeUptime = enabled
                    ? DispatchTime.now().uptimeNanoseconds + 100_000_000 : 0
            }
        }
#if !os(tvOS)
        // Chat mode without VPIO lowers playback level. Leave it only after VPIO
        // is disabled, and only for a pipeline participating in the mute transition.
        if !enabled, voiceProcessingSessionMode != nil, session.mode != .default {
            try session.setMode(.default)
        }
#endif
    }

#if !os(tvOS)
    private func resetIOSCaptureGraph() {
        timer?.clean()
        timer = nil
        if let sink = audioSink as? AVAudioNode {
            engine.disconnectNodeInput(sink)
            engine.detach(sink)
        }
        audioSink = nil
        if engine.attachedNodes.contains(playerNode) { engine.detach(playerNode) }
        engine = AVAudioEngine()
        bufferQueue.sync {
            pcm16BufferDeque.removeAll()
            pcm16BufferArray.removeAll()
            if let encoder = opusEncoder { opus_encoder_destroy(encoder) }
            if let decoder = opusDecoder { opus_decoder_destroy(decoder) }
            opusEncoder = nil
            opusDecoder = nil
        }
    }

    private func observePlaybackReset() {
        notificationTokens.append(NotificationCenter.default.addObserver(forName: Notification.Name("VoidLinkAudioPlaybackWillReset"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.iosControlQueue.sync {
                guard #available(iOS 13.0, *), self.isRecording, self.engine.isRunning, self.engine.inputNode.isVoiceProcessingEnabled else { return }
                self.logPlaybackResetState("before capture rebuild")
                self.stopTapping(stopEngine: true)
                self.iosResumeAfterPlaybackReset = true
                self.resetIOSCaptureGraph()
            }
        })
        notificationTokens.append(NotificationCenter.default.addObserver(forName: Notification.Name("VoidLinkAudioPlaybackDidReset"), object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.iosControlQueue.async {
                guard !self.iosDisposed, self.iosResumeAfterPlaybackReset else { return }
                self.iosResumeAfterPlaybackReset = false
                do {
                    try self.configureSession()
                    try self.configureEngine()
                    self.startTapping()
                    self.logPlaybackResetState("after capture rebuild")
                } catch {
                    self.stopTapping(stopEngine: true)
                    NSLog("%@", "[IOSMic] capture rebuild failed: \(error)")
                    self.notify(error)
                }
            }
        })
    }

    private func logPlaybackResetState(_ stage: String) {
        let session = AVAudioSession.sharedInstance()
        var processing = false
        // Reading a lazy inputNode while paused in playback can initialize input I/O
        // before the recording session is restored. Inspect only a running graph.
        if engine.isRunning, #available(iOS 13.0, *) { processing = engine.inputNode.isVoiceProcessingEnabled }
        NSLog("%@", "[IOSMic] \(stage): voiceProcessing=\(processing), engineRunning=\(engine.isRunning), recording=\(isRecording), sending=\(timer?.isRunning() ?? false), category=\(session.category.rawValue), options=\(session.categoryOptions.rawValue), mode=\(session.mode.rawValue), outputVolume=\(session.outputVolume), outputs=\(session.currentRoute.outputs.map { $0.portType.rawValue })")
    }
#endif

    private func appendConvertedSamples(_ buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) {
        let target = converter.outputFormat
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * target.sampleRate / buffer.format.sampleRate) + 64)
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, state in
            if supplied { state.pointee = .noDataNow; return nil }
            supplied = true
            state.pointee = .haveData
            return buffer
        }
#if os(tvOS)
        let logPrefix = "[TVMic]"
#else
        let logPrefix = "[IOSMic]"
#endif
        guard status != .error, error == nil, let data = output.floatChannelData?[0] else {
            NSLog("%@", "\(logPrefix) PCM conversion failed: \(String(describing: error))")
            return
        }
        let samples = UnsafeBufferPointer(start: data, count: Int(output.frameLength))
#if !os(tvOS)
        if !iosReceivedFirstBuffer, !samples.isEmpty {
            iosReceivedFirstBuffer = true
            NSLog("%@", "[IOSMic] first external samples: inputFrames=\(buffer.frameLength), outputFrames=\(output.frameLength), peak=\(samples.reduce(Float(0)) { max($0, abs($1)) })")
        }
#endif
        appendFloatSamples(samples)
    }

    /// Both platforms feed the verified PCM16 Deque and the same sender.
    private func appendFloatSamples(_ samples: UnsafeBufferPointer<Float>) {
        // 转 float32 -> int16
        var chunk = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            let clamped = max(min(samples[i] * MicHandler.volume, 1.0), -1.0)
            chunk[i] = Int16(clamped * Float(Int16.max))
        }

        // 追加到缓冲区
        self.bufferQueue.sync {
            guard !self.micMuted else { return }
            self.pcm16BufferDeque.append(contentsOf: chunk)
#if os(tvOS)
            if let largest = chunk.map({ abs(Float($0)) / Float(Int16.max) }).max() {
                self.tvPeak = max(self.tvPeak, largest)
            }
#endif
        }
    }

    private func configureDequeTimer() {
        // 开定时器，每 20ms 触发一次
        self.timer = SafeTimer(interval:0.02, delay: 0.05) {
            self.sendOpusFrameFromDequeBuffer()
        }
    }

    @objc public func clean() {
#if !os(tvOS)
        if DispatchQueue.getSpecific(key: iosControlQueueKey) != true {
            iosControlQueue.sync { self.clean() }
            return
        }
#endif
        Self.instanceLock.lock()
        if Self.activeInstance === self { Self.activeInstance = nil }
        Self.instanceLock.unlock()
#if !os(tvOS)
        resumeCaptureAfterMute = false
        iosDisposed = true
        iosResumeAfterPlaybackReset = false
        bufferQueue.sync {
            volumeRestoreStopped = true
            volumeRestoreGeneration += 1
        }
        DispatchQueue.main.async {
            self.systemVolumeView?.removeFromSuperview()
            self.systemVolumeView = nil
            self.systemVolumeContainerView = nil
            self.systemVolumeRestoreGeneration = nil
        }
#endif
#if os(tvOS)
        Self.onTVMain {
            self.resumeCaptureAfterMute = false
            self.tvDisposed = true
            self.isRecording = false
            self.tvInputRetry?.cancel()
            self.tvInputRetry = nil
            self.stopTVCapture()
            self.tvInputObservation = nil
            self.tvDeviceObservation = nil
            self.tvConnectedDevice = nil
            if #available(tvOS 17.0, *), let coordinator = self.tvPickerCoordinator as? TVMicDevicePickerCoordinator {
                coordinator.picker?.dismiss(animated: false)
            }
            self.tvPickerCoordinator = nil
        }
#endif
        for token in notificationTokens {
            NotificationCenter.default.removeObserver(token)
        }
        notificationTokens.removeAll()
        self.timer?.clean()
    }
    
    private func notify(_ error: Error) {
        if Thread.isMainThread { delegate?.micHandler?(self, didFailWithError: error as NSError) }
        else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.delegate?.micHandler?(self, didFailWithError: error as NSError)
            }
        }
    }

    // ===============================
    // 🔹 新增播放 Opus 数据方法
    /*
    private func playbackOpus() {
        guard let dec = opusDecoder else { return }

        let channels = Int(micInputFormat.channelCount)

        for (index, packet) in recordedOpusPackets.enumerated() {
            let maxFrames = 5760 // 最大 120ms
            let pcmBuf = UnsafeMutablePointer<Int16>.allocate(capacity: maxFrames * channels)
            defer { pcmBuf.deallocate() }

            let frameCount = opus_decode(dec,
                                         [UInt8](packet),
                                         Int32(packet.count),
                                         pcmBuf,
                                         Int32(maxFrames),
                                         0)
            if frameCount < 0 {
                print("Opus decode error: \(frameCount)")
                continue
            }

            // 构造源格式 AVAudioPCMBuffer (PCM16)
            let sourceFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                             sampleRate: micInputFormat.sampleRate,
                                             channels: micInputFormat.channelCount,
                                             interleaved: true)!

            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat,
                                                      frameCapacity: AVAudioFrameCount(frameCount)) else { continue }
            sourceBuffer.frameLength = AVAudioFrameCount(frameCount)

            // 填充 PCM16 数据到 sourceBuffer
            let srcPointer = sourceBuffer.int16ChannelData![0]
            for i in 0..<Int(frameCount * Int32(channels)) {
                srcPointer[i] = pcmBuf[i]
            }

            // 准备目标 buffer (Float32)
            guard let floatBuffer = AVAudioPCMBuffer(pcmFormat: micInputFormat,
                                                     frameCapacity: AVAudioFrameCount(frameCount)) else { continue }

            // 🔹 使用 AVAudioConverter 转换
            let converter = AVAudioConverter(from: sourceFormat, to: micInputFormat)!
            var error: NSError? = nil
            let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }

            converter.convert(to: floatBuffer, error: &error, withInputFrom: inputBlock)
            if let error = error {
                print("AVAudioConverter error: \(error)")
                continue
            }

            // 播放
            if index == recordedOpusPackets.count - 1 {
                playerNode.scheduleBuffer(floatBuffer, at: nil, options: []) { [weak self] in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.playerNode.stop()
                        self.engine.stop()
                    }
                }
            } else {
                playerNode.scheduleBuffer(floatBuffer, at: nil, options: [], completionHandler: nil)
            }
        }

        // 启动 engine
        if !engine.isRunning {
            do { try engine.start() } catch { print(error) }
        }

        if !playerNode.isPlaying {
            playerNode.play()
        }
    }

    // ===============================
    // 🔹 改动 2：播放 PCM16 数据
    private func playbackRecorded() {
        do {
            try configureEngine()
        } catch {
            notify(error)
        }

        let channels = Int(micInputFormat.channelCount)

        for (index, pcmData) in recordedPCM16.enumerated() {
            let frameCount = pcmData.count / (MemoryLayout<Int16>.size * channels)
            guard let buf = AVAudioPCMBuffer(pcmFormat: micInputFormat, frameCapacity: AVAudioFrameCount(frameCount)) else { continue }
            buf.frameLength = buf.frameCapacity

            // PCM16 -> Float32
            pcmData.withUnsafeBytes { rawBuf in
                let pcmPtr = rawBuf.bindMemory(to: Int16.self).baseAddress!
                for i in 0..<frameCount {
                    for ch in 0..<channels {
                        buf.floatChannelData?[ch][i] = Float(pcmPtr[i * channels + ch]) / Float(Int16.max)
                    }
                }
            }

            // 只在最后一个 buffer 设置 completionHandler
            if index == recordedPCM16.count - 1 {
                playerNode.scheduleBuffer(buf, at: nil, options: []) { [weak self] in
                    guard let self = self else { return }
                    // 🔹 回到主线程安全停止
                    DispatchQueue.main.async {
                        self.playerNode.stop()
                        self.engine.stop()
                    }
                }
            } else {
                playerNode.scheduleBuffer(buf, at: nil, options: [], completionHandler: nil)
            }
        }

        playerNode.play()
    }

    private func deepCopy(_ buffer: AVAudioPCMBuffer, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: buffer.frameLength) else { return nil }
        out.frameLength = buffer.frameLength
        let channels = Int(format.channelCount)
        for ch in 0..<channels {
            if let src = buffer.floatChannelData?[ch], let dst = out.floatChannelData?[ch] {
                dst.update(from: src, count: Int(buffer.frameLength))
            }
        }
        return out
    }

    private func merge(buffers: [AVAudioPCMBuffer], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let total = buffers.reduce(0) { $0 + $1.frameLength }
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total) else { return nil }
        out.frameLength = total

        var writePos: AVAudioFrameCount = 0
        let channels = Int(format.channelCount)

        for b in buffers {
            let frames = Int(b.frameLength)
            for ch in 0..<channels {
                if let src = b.floatChannelData?[ch], let dst = out.floatChannelData?[ch] {
                    dst.advanced(by: Int(writePos)).update(from: src, count: frames)
                }
            }
            writePos += b.frameLength
        }
        return out
    }

     */
}

/* -------------------------------------------------------*/

#if os(tvOS)
private extension MicHandler {
    static func onTVMain(_ action: @escaping () -> Void) {
        if Thread.isMainThread { action() }
        else { DispatchQueue.main.sync(execute: action) }
    }

    func observeTVInputs() {
        let session = AVAudioSession.sharedInstance()
        // Rebuild capture after playback I/O is recreated, preserving the requested
        // voiceProcessing value and querying the new capture format afterward.
        notificationTokens.append(NotificationCenter.default.addObserver(forName: Notification.Name("VoidLinkAudioPlaybackWillReset"), object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.tvDisposed else { return }
            self.tvPlaybackResetting = true
            self.tvInputRetry?.cancel()
            self.tvInputRetry = nil
            self.stopTVCapture()
        })
        notificationTokens.append(NotificationCenter.default.addObserver(forName: Notification.Name("VoidLinkAudioPlaybackDidReset"), object: nil, queue: .main) { [weak self] _ in
            guard let self, !self.tvDisposed else { return }
            self.tvPlaybackResetting = false
            self.refreshTVInput()
        })
        tvInputObservation = session.observe(\.isInputAvailable, options: [.new]) { [weak self] _, _ in
            DispatchQueue.main.async { self?.scheduleTVInputRefresh() }
        }
        notificationTokens.append(NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            let session = AVAudioSession.sharedInstance()
            let reason = (note.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt).flatMap(AVAudioSession.RouteChangeReason.init(rawValue:))
            if reason == .oldDeviceUnavailable && !Self.hasTVBluetoothRoute(session) {
                self.tvBluetoothRouteObserved = false
                self.tvInputDiscoveryStarted = DispatchTime.now().uptimeNanoseconds
                self.tvRetryCount = 0
            } else if Self.hasTVBluetoothRoute(session) {
                self.tvBluetoothRouteObserved = true
            }
            self.scheduleTVInputRefresh()
        })
        for name in [UIApplication.didBecomeActiveNotification] {
            notificationTokens.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.scheduleTVInputRefresh()
            })
        }
        notificationTokens.append(NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] note in
            guard let self, let changed = note.object as? AVAudioEngine, changed === self.engine else { return }
            self.scheduleTVInputRefresh()
        })
    }

    func scheduleTVInputRefresh(delay: TimeInterval = 0.2) {
        guard isRecording, !tvDisposed else { return }
        tvInputRetry?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshTVInput() }
        tvInputRetry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func refreshTVInput() {
        guard #available(tvOS 17.0, *), isRecording, !tvDisposed, !tvInterrupted, !tvPlaybackResetting else { return }
        let session = AVAudioSession.sharedInstance()
        if engine.isRunning, session.isInputAvailable,
           let preferred = preferredMicrophoneInput(from: session.availableInputs ?? []),
           session.currentRoute.inputs.contains(where: { $0.uid == preferred.uid }) {
            return
        }
        stopTVCapture()
        do {
            try configureSession()
            if let device = tvConnectedDevice as? AVContinuityDevice, !device.isConnected {
                tvConnectedDevice = nil
                tvPreferredInputUID = nil
                tvDeviceObservation = nil
                NSLog("[TVMic] Continuity microphone disconnected")
            }
            let session = AVAudioSession.sharedInstance()
            let preferred = preferredMicrophoneInput(from: session.availableInputs ?? [])
            guard session.isInputAvailable, preferred != nil else {
                // NSLog("[TVMic] waiting for microphone input")
                // Give Bluetooth discovery time to publish its port after enabling HFP.
                // Only offer Continuity pairing once no Bluetooth/Continuity input is available.
                offerTVPairingIfNeeded()
                retryTVInput()
                return
            }
            try configureEngine()
            tvRetryCount = 0
            timer?.start()
        } catch {
            stopTVCapture()
            NSLog("%@", "[TVMic] capture setup failed: \(error)")
            notify(error)
            offerTVPairingIfNeeded()
            retryTVInput()
        }
    }

    static func isTVBluetoothInput(_ type: AVAudioSession.Port) -> Bool {
        type == .bluetoothHFP || type == .bluetoothLE
    }

    static func hasTVBluetoothRoute(_ session: AVAudioSession) -> Bool {
        let inputs = (session.availableInputs ?? []) + session.currentRoute.inputs
        return inputs.contains { isTVBluetoothInput($0.portType) }
            || session.currentRoute.outputs.contains {
                $0.portType == .bluetoothA2DP || isTVBluetoothInput($0.portType)
            }
    }

    // A connected Bluetooth output is evidence that input discovery is still pending,
    // not proof of a microphone. Keep that case separate from "no Bluetooth device".
    static func shouldOfferTVPairing(hasBluetoothRoute: Bool, hasContinuityInput: Bool, discoveryElapsed: TimeInterval) -> Bool {
        !hasBluetoothRoute && !hasContinuityInput && discoveryElapsed >= 2
    }

    /// Device discovery is independent of activation, but waits for Bluetooth discovery.
    func offerTVPairingIfNeeded() {
        guard #available(tvOS 17.0, *), isRecording, !tvDisposed, !tvPlaybackResetting else { return }
        let session = AVAudioSession.sharedInstance()
        tvBluetoothRouteObserved = tvBluetoothRouteObserved || Self.hasTVBluetoothRoute(session)
        let inputs = session.availableInputs ?? []
        if useBuiltinMic {
            if preferredMicrophoneInput(from: inputs) == nil { presentTVDevicePicker() }
            return
        }
        let elapsed = tvInputDiscoveryStarted == 0 ? 0 : Double(DispatchTime.now().uptimeNanoseconds - tvInputDiscoveryStarted) / 1_000_000_000
        guard Self.shouldOfferTVPairing(hasBluetoothRoute: tvBluetoothRouteObserved,
                                        hasContinuityInput: inputs.contains { $0.portType == .continuityMicrophone },
                                        discoveryElapsed: elapsed) else { return }
        presentTVDevicePicker()
    }

    func retryTVInput() {
        guard isRecording, !tvDisposed else { return }
        guard tvRetryCount < 10 else {
            let session = AVAudioSession.sharedInstance()
            NSLog("%@", "[TVMic] input discovery timed out; continuityRequired=\(useBuiltinMic), bluetoothRoute=\(tvBluetoothRouteObserved), inputs=\(session.availableInputs?.map { $0.portType.rawValue } ?? []), outputs=\(session.currentRoute.outputs.map { $0.portType.rawValue })")
            return
        }
        tvRetryCount += 1
        scheduleTVInputRefresh(delay: 0.5)
    }

    func presentTVDevicePicker() {
        guard #available(tvOS 17.0, *), !tvDisposed, tvPickerCoordinator == nil else { return }
        guard AVContinuityDevicePickerViewController.isSupported else {
            NSLog("[TVMic] Continuity device picker unsupported")
            return
        }
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let root = scenes.filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        guard let root, let controller = Self.topViewController(base: root), !(controller is UIAlertController) else {
            NSLog("[TVMic] device picker deferred: no foreground presenter")
            return
        }
        NSLog("[TVMic] presenting Continuity device picker")
        let coordinator = TVMicDevicePickerCoordinator()
        let picker = AVContinuityDevicePickerViewController()
        coordinator.didConnect = { [weak self] device in
            guard let self, !self.tvDisposed else { return }
            self.tvConnectedDevice = device
            self.tvPreferredInputUID = device.audioSessionInputs.first(where: { $0.portType == .continuityMicrophone })?.uid
            self.tvDeviceObservation = device.observe(\.isConnected, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async { self?.scheduleTVInputRefresh() }
            }
            NSLog("%@", "[TVMic] device connected=\(device.isConnected), audioPorts=\(device.audioSessionInputs.map { $0.portType.rawValue })")
            self.tvRetryCount = 0
            self.tvPickerCoordinator = nil
            self.scheduleTVInputRefresh()
        }
        coordinator.didCancel = { [weak self] in self?.tvPickerCoordinator = nil }
        // AVKit holds its delegate weakly. Retain it until connection or cancellation,
        // including after the picker UI finishes presenting.
        picker.delegate = coordinator
        picker.modalPresentationStyle = .fullScreen
        coordinator.picker = picker
        tvPickerCoordinator = coordinator
        controller.present(picker, animated: true)
    }

    @available(tvOS 17.0, *)
    func configureTVEngine() throws {
        let session = AVAudioSession.sharedInstance()
        // Match the successful reconnect: playback must run before enabling VPIO.
        // A failure uses the existing input retry path instead of reversing the order.
        try Connection.resumeSysAudioPlaybackBeforeMic()
        let input = engine.inputNode
        // NSLog("%@", "[TVMic] before voiceProcessing: requested=\(voiceProcessing), category=\(session.category.rawValue), mode=\(session.mode.rawValue), options=\(session.categoryOptions.rawValue), outputVolume=\(session.outputVolume)")
        // Connection.logSysAudioPlaybackLatency()
        try configureVoiceProcessing(input)
        // Match the validated iOS capture path. This is a preference; log the
        // actual duration after engine start because the route may override it.
        try session.setPreferredIOBufferDuration(0.02)
        let hardware = input.inputFormat(forBus: 0)
        let source = input.outputFormat(forBus: 0)
        guard hardware.sampleRate > 0, hardware.channelCount > 0, source.sampleRate > 0, source.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: source, to: target) else {
            throw NSError(domain: "TVMic", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone input format is unavailable"])
        }
        micInputFormat = target
        // The encoder and sender below are the same implementations used by iOS.
        try configureOpus(sampleRate: 48000, channels: 1)
        let generation = tvCaptureQueue.sync { () -> Int in
            tvConverter = converter
            return tvCaptureGeneration
        }
        input.installTap(onBus: 0, bufferSize: 960, format: source) { [weak self] buffer, _ in
            guard let self, self.tvBufferSlots.wait(timeout: .now()) == .success else { return }
            guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
                self.tvBufferSlots.signal()
                return
            }
            copy.frameLength = buffer.frameLength
            let src = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
            let dst = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
            for index in 0..<src.count {
                if let sourceData = src[index].mData, let targetData = dst[index].mData {
                    memcpy(targetData, sourceData, Int(src[index].mDataByteSize))
                }
            }
            let slots = self.tvBufferSlots
            self.tvCaptureQueue.async { [weak self] in
                defer { slots.signal() }
                guard let self, self.tvCaptureGeneration == generation else { return }
                self.bufferTVSamples(copy)
            }
        }
        tvTapInstalled = true
        configureDequeTimer()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            NSLog("%@", "[TVMic] capture engine start failed: \(error)")
            throw error
        }
        NSLog("%@", "[TVMic] capture started; source=\(source), target=48000Hz mono, voiceProcessing=\(input.isVoiceProcessingEnabled), muted=\(AVAudioApplication.shared.isInputMuted)")
        // NSLog("%@", "[TVMic] latency: preferredIO=\(session.preferredIOBufferDuration), actualIO=\(session.ioBufferDuration), input=\(session.inputLatency), output=\(session.outputLatency), captureOutputNode=\(engine.outputNode.presentationLatency), outputs=\(session.currentRoute.outputs.map { $0.portType.rawValue })")
        // Connection.logSysAudioPlaybackLatency()
        // let captureEngine = engine
        // DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            // guard let self, !self.tvDisposed, self.isRecording, self.engine === captureEngine, captureEngine.isRunning else { return }
            // NSLog("%@", "[TVMic] settled capture: voiceProcessing=\(captureEngine.inputNode.isVoiceProcessingEnabled), category=\(session.category.rawValue), mode=\(session.mode.rawValue), options=\(session.categoryOptions.rawValue), outputVolume=\(session.outputVolume)")
            // Connection.logSysAudioPlaybackLatency()
        // }
    }

    // Called only on tvCaptureQueue; the same converter routine feeds iOS's sink.
    func bufferTVSamples(_ buffer: AVAudioPCMBuffer) {
        guard let converter = tvConverter else { return }
        appendConvertedSamples(buffer, using: converter)
    }

    func stopTVCapture() {
        // Timer callbacks use bufferQueue synchronously; stop them before draining queues.
        timer?.clean()
        timer = nil
        if tvTapInstalled { engine.inputNode.removeTap(onBus: 0); tvTapInstalled = false }
        engine.stop()
        engine = AVAudioEngine()
        tvCaptureQueue.sync { tvCaptureGeneration += 1; tvConverter = nil }
        bufferQueue.sync {
            pcm16BufferDeque.removeAll()
            if let opusEncoder { opus_encoder_destroy(opusEncoder) }
            if let opusDecoder { opus_decoder_destroy(opusDecoder) }
            opusEncoder = nil
            opusDecoder = nil
            tvSentPackets = 0
            tvSendFailures = 0
            tvPeak = 0
            tvReportUptime = 0
            tvReportPackets = 0
        }
    }

    func reportTVSend(_ result: Int32, opusLength: Int32) {
        if result > 0 { tvSentPackets += 1 }
        else {
            tvSendFailures += 1
            if tvSendFailures == 1 { NSLog("%@", "[TVMic] send failed: result=\(result), opusBytes=\(opusLength)") }
        }
        if result > 0 && (tvSentPackets == 1 || tvSentPackets % 250 == 0) {
            let now = DispatchTime.now().uptimeNanoseconds
            let elapsed = tvReportUptime == 0 ? 0 : Double(now - tvReportUptime) / 1_000_000_000
            let rate = elapsed > 0 ? Double(tvSentPackets - tvReportPackets) / elapsed : 0
            // NSLog("%@", "[TVMic] sent=\(tvSentPackets), packetsPerSec=\(String(format: "%.1f", rate)), queuedMs=\(pcm16BufferDeque.count / 48), peak=\(tvPeak), sendFailures=\(tvSendFailures)")
            tvReportUptime = now
            tvReportPackets = tvSentPackets
            tvPeak = 0
        }
    }
}

@available(tvOS 17.0, *)
private final class TVMicDevicePickerCoordinator: NSObject, AVContinuityDevicePickerViewControllerDelegate {
    weak var picker: AVContinuityDevicePickerViewController?
    var didConnect: ((AVContinuityDevice) -> Void)?
    var didCancel: (() -> Void)?
    func continuityDevicePicker(_ pickerViewController: AVContinuityDevicePickerViewController, didConnect device: AVContinuityDevice) { didConnect?(device) }
    func continuityDevicePickerDidCancel(_ pickerViewController: AVContinuityDevicePickerViewController) { didCancel?() }
}
#endif
