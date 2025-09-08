//
//  MicHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/2.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.

import AVFoundation

@objc public protocol MicHandlerDelegate: AnyObject {
    @objc optional func micHandlerDidFinishPlayback(_ handler: MicHandler)
    @objc optional func micHandler(_ handler: MicHandler, didFailWithError error: NSError)
}

@objcMembers
public class MicHandler: NSObject {

    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var audioSink: Any?
    private var micInputFormat: AVAudioFormat!
    private var isRecording = false
    
    private var pcm16Buffer: [Int16] = []
    private let bufferQueue = DispatchQueue(label: "pcm.buffer.queue")
    private var timer: DispatchSourceTimer?

    /*
    private var recordedBuffers: [AVAudioPCMBuffer] = []
    private var recordedPCM16: [Data] = []
    private var recordedOpusPackets: [Data] = []
    */
    
    private var opusEncoder: OpaquePointer?
    private var opusDecoder: OpaquePointer?
    
    private var sequenceNumber: UInt16 = 0
    private let ssrc: UInt32 = 0x12345678
    
    private var globalTimestamp: TimeInterval = 0


    public weak var delegate: MicHandlerDelegate?

    public override init() {
        super.init()
        do {
            try configureSession()
            try configureEngine()
        } catch {
            notify(error)
        }
    }
    
    
    /* ----------- Mic permission -------------*/
    /// 请求麦克风权限
    /// - Parameter completion: 可选 block，如果为 nil 且未授权，会弹窗提示跳转系统设置
    @objc static func requestPermission(_ completion: ((Bool) -> Void)? = nil) {
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
    }
    
    /// 配置音频会话
    @objc static func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setActive(true)
    }
    
    /// 弹窗提示用户跳转系统设置（英文版）
    private static func showSettingsAlert() {
        guard let topVC = topViewController() else { return }
        let alert = UIAlertController(
            title:  SwiftLocalizationHelper.localizedString(forKey: "Microphone Permission") ,
            message: SwiftLocalizationHelper.localizedString(forKey: "micPermissionTip"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Cancel"), style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Go to Settings") , style: .default, handler: { _ in
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
        return AVAudioSession.sharedInstance().recordPermission == AVAudioSession.RecordPermission.granted
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
        opus_encoder_ctl_wrapper(enc, Int32(OPUS_SET_SIGNAL_REQUEST), OPUS_SIGNAL_MUSIC)      // Set signal type
    }

    @objc public func startTapping() {
        // recordedBuffers.removeAll()
        isRecording = true
        /*
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self else { return }
            self.isRecording = false
            self.stop()
            self.playbackRecorded()
            self.playbackOpus()
        }*/
    }

    @objc public func stopTapping(stopEngine:Bool) {
        isRecording = false
        // engine.inputNode.removeTap(onBus: 0)
        if(stopEngine){
            playerNode.stop()
            engine.stop()
        }
    }

    private func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .videoRecording, options: [.mixWithOthers, .defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
    }
    
    private func sendOpusFrame() {
        bufferQueue.sync {
            if pcm16Buffer.count >= 960 {
                let chunk = Array(pcm16Buffer.prefix(960))
                var packet = [UInt8](repeating: 0, count: 4000)
                guard let enc = self.opusEncoder else {return}
                let outBytes = opus_encode(enc, chunk, 960, &packet, Int32(packet.count))
                sendMicrophoneData(packet, outBytes)
                pcm16Buffer.removeFirst(960)
            }
        }
    }

    private func configureEngine() throws {
        let input = engine.inputNode
        micInputFormat = input.inputFormat(forBus: 0)
        
        try self.configureOpus(sampleRate: Int32(micInputFormat.sampleRate), channels: Int(micInputFormat.channelCount))

        
        let pcm16Format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: micInputFormat.sampleRate, channels: micInputFormat.channelCount, interleaved: true)

        let converter = AVAudioConverter(from: micInputFormat, to: pcm16Format!)
        
        if #available(iOS 13.0, tvOS 13.0, *) {
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(0.02)
            
            let sinkNode = AVAudioSinkNode { timestamp, frameCount, audioBufferList -> OSStatus in
                // 访问 AudioBufferList 数据
                // print("sink interval: \((CACurrentMediaTime()-self.globalTimestamp)*1000)，frameCount: \(frameCount)")
                // self.globalTimestamp = CACurrentMediaTime()
                
                guard self.isRecording else { return noErr}
                
                let abl = audioBufferList.pointee.mBuffers
                guard let data = abl.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                let samples = UnsafeBufferPointer(start: data, count: Int(frameCount))
                
                // 转 float32 -> int16
                var chunk = [Int16](repeating: 0, count: samples.count)
                for i in 0..<samples.count {
                    let clamped = max(min(samples[i], 1.0), -1.0)
                    chunk[i] = Int16(clamped * Float(Int16.max))
                }

                // 追加到缓冲区
                self.pcm16Buffer.append(contentsOf: chunk)
                
                return noErr
            }
            
            audioSink = sinkNode
            engine.attach(audioSink! as! AVAudioNode)
            engine.connect(engine.inputNode, to: audioSink as! AVAudioNode, format: micInputFormat)
            
            // 开定时器，每 20ms 触发一次
            self.timer = DispatchSource.makeTimerSource(queue: .global())
            self.timer?.schedule(deadline: .now()+0.1, repeating: 0.02)
            self.timer?.setEventHandler { [weak self] in
                self?.sendOpusFrame()
            }
            self.timer?.resume()

        }
        else{
            engine.attach(playerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: micInputFormat)

            input.installTap(onBus: 0, bufferSize: 5760, format: micInputFormat) { [weak self] buffer, _ in
                guard let self = self, self.isRecording else { return }
                
                DispatchQueue.global().async {
                    let pcm16Buffer = AVAudioPCMBuffer(pcmFormat: pcm16Format!, frameCapacity: buffer.frameCapacity)
                    try? converter?.convert(to: pcm16Buffer!, from: buffer)
                    // 处理转换后的 outputBuffer
                    
                    // ===============================
                    // 🔹 改动 1：把 buffer 转成 PCM16 并保存
                    let frameLength = Int(buffer.frameLength)
                    let channels = Int(buffer.format.channelCount)
                    var pcm16InterleavedBuffer = [Int16](repeating: 0, count: frameLength * channels)
                    
                    for ch in 0..<channels {
                        if let pcm16Data = pcm16Buffer?.int16ChannelData?[ch] {
                            for i in 0..<frameLength {
                                pcm16InterleavedBuffer[i * channels + ch] = pcm16Data[i]
                            }
                        }
                    }
                    // 🔹 新增：Opus 编码并存入缓存
                    if let enc = self.opusEncoder {
                        var packet = [UInt8](repeating: 0, count: 8000)
                        let outBytes = opus_encode(enc, pcm16InterleavedBuffer, Int32(frameLength), &packet, Int32(packet.count))
                        sendMicrophoneData(packet, outBytes)
                    }
                }
            }
        }

        engine.prepare()
        try engine.start()
    }
    
    private func notify(_ error: Error) {
        delegate?.micHandler?(self, didFailWithError: error as NSError)
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
