//
//  GameSirG8MFiRumble.m -> GameSirG8MFiRumbler.swift
//  VoidLink
//
//  Created by chrisnch on 2026/08/22
//  Copyright © 2026 chrisnch@github. All rights reserved.
//
//  Modified by True砖家 on 2026/08/25
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import ExternalAccessory
import Foundation
import GameController
import UIKit

@objcMembers
final class GameSirG8MFiRumbler: NSObject, StreamDelegate {
    private static let gameSirG8MFiProtocol = "com.xiaoji.M2boot"
    private static let gameSirManufacturer = "GameSir"
    private static let gameSirG8MFiModel = "G8+ MFi"
    static var repeatInterval: TimeInterval = 0.167253

    private var session: EASession?
    private var inFlightPacket: Data?
    private var inFlightOffset = 0
    private var queuedPacket: Data?
    private var lastSentPacket: Data?
    private var repeatTimer: Timer?
    private var repeatPacket: Data?
    private var appActive: Bool
    private var invalidated = false

    override init() {
        appActive = UIApplication.shared.applicationState == .active
        super.init()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive(_:)),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        assert(Thread.isMainThread || session == nil, "Active GameSir sessions must be closed on the main thread before deallocation")
        if Thread.isMainThread {
            stopAndCloseOnMainThread()
        }
    }

    func canHandleController(_ controller: GCController) -> Bool {
        return GameSirG8MFiRumbler.isTargetController(controller) && connectedAccessory() != nil
    }

    static func isTargetController(_ controller: GCController) -> Bool {
        guard let vendorName = controller.vendorName, !vendorName.isEmpty else {
            return false
        }

        return vendorName.range(of: Self.gameSirManufacturer, options: [.caseInsensitive, .diacriticInsensitive]) != nil &&
            vendorName.range(of: "G8+", options: [.caseInsensitive, .diacriticInsensitive]) != nil &&
            vendorName.range(of: "MFi", options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    @objc(setLowFrequencyMotor:highFrequencyMotor:)
    func setLowFrequencyMotor(_ lowFrequencyMotor: UInt16, highFrequencyMotor: UInt16) {
        objc_sync_enter(self)
        let isInvalidated = invalidated
        objc_sync_exit(self)
        if isInvalidated {
            return
        }

        let packet = packet(lowFrequencyMotor: lowFrequencyMotor, highFrequencyMotor: highFrequencyMotor)
        // NSLog("[G8Rumble] queue request low=%hu high=%hu packet=%@", lowFrequencyMotor, highFrequencyMotor, packet as NSData)
        let shouldRepeat = lowFrequencyMotor != 0 || highFrequencyMotor != 0

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }

            objc_sync_enter(self)
            let isInvalidated = self.invalidated
            objc_sync_exit(self)
            if isInvalidated {
                // NSLog("[G8Rumble] drop packet because rumble handler is invalidated")
                return
            }
            if !self.appActive {
                // NSLog("[G8Rumble] drop packet because app is inactive packet=%@", packet as NSData)
                return
            }

            if shouldRepeat {
                self.stopRepeatTimer(clearPacket: false)
                self.repeatPacket = packet
                self.startRepeatTimer()
            } else {
                self.stopRepeatTimer()
            }

            self.queuePacket(packet)
        }
    }

    func stopAndClose() {
        if Thread.isMainThread {
            stopAndCloseOnMainThread()
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.stopAndCloseOnMainThread()
        }
    }

    func invalidate() {
        objc_sync_enter(self)
        invalidated = true
        objc_sync_exit(self)
        stopAndClose()
    }

    @objc private func applicationWillResignActive(_ notification: Notification) {
        appActive = false
        stopAndCloseOnMainThread()
    }

    @objc private func applicationDidBecomeActive(_ notification: Notification) {
        appActive = true
    }

    private func connectedAccessory() -> EAAccessory? {
        var sawAccessory = false
        for accessory in EAAccessoryManager.shared().connectedAccessories {
            sawAccessory = true
            /*
            NSLog(
                "[G8Rumble] EA accessory name=%@ manufacturer=%@ model=%@ protocols=%@ connected=%d",
                accessory.name,
                accessory.manufacturer,
                accessory.modelNumber,
                accessory.protocolStrings,
                accessory.isConnected
            ) */

            guard accessory.isConnected,
                  accessory.protocolStrings.contains(Self.gameSirG8MFiProtocol),
                  !accessory.manufacturer.isEmpty,
                  !accessory.modelNumber.isEmpty,
                  accessory.manufacturer.caseInsensitiveCompare(Self.gameSirManufacturer) == .orderedSame,
                  accessory.modelNumber.caseInsensitiveCompare(Self.gameSirG8MFiModel) == .orderedSame else {
                continue
            }

            NSLog("[G8Rumble] matched GameSir G8+ MFi accessory name=%@", accessory.name)
            return accessory
        }

        if sawAccessory {
            NSLog("[G8Rumble] no matching GameSir G8+ MFi accessory")
        } else {
            NSLog("[G8Rumble] no connected EA accessories")
        }
        return nil
    }

    private static func convertMotorAmplitude(_ amplitude: UInt16) -> UInt8 {
        return UInt8((UInt32(amplitude) * 255 + 32767) / 65535)
    }

    private func packet(lowFrequencyMotor: UInt16, highFrequencyMotor: UInt16) -> Data {
        return Data([
            0x04,
            Self.convertMotorAmplitude(lowFrequencyMotor),
            0x01,
            Self.convertMotorAmplitude(highFrequencyMotor),
            0x01,
            0x00,
            0x00,
            0x00,
            0x00,
        ])
    }

    private func openSessionIfNeeded() -> Bool {
        if session != nil {
            return true
        }

        guard let accessory = connectedAccessory() else {
            NSLog("[G8Rumble] cannot open session: accessory not found")
            return false
        }

        NSLog("[G8Rumble] opening EASession protocol=%@ accessory=%@", Self.gameSirG8MFiProtocol, accessory.name)
        guard let newSession = EASession(accessory: accessory, forProtocol: Self.gameSirG8MFiProtocol),
              let inputStream = newSession.inputStream,
              let outputStream = newSession.outputStream else {
            NSLog("[G8Rumble] failed to create EASession")
            return false
        }

        session = newSession
        inputStream.delegate = self
        outputStream.delegate = self
        inputStream.schedule(in: .main, forMode: .default)
        outputStream.schedule(in: .main, forMode: .default)
        inputStream.open()
        outputStream.open()
        /*
        NSLog(
            "[G8Rumble] EASession opened inputStatus=%ld outputStatus=%ld",
            inputStream.streamStatus.rawValue,
            outputStream.streamStatus.rawValue
        ) */
        return true
    }

    private func startRepeatTimer() {
        let timer = Timer(timeInterval: Self.repeatInterval, repeats: true) { [weak self] _ in
            self?.repeatCurrentPacket()
        }
        repeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        // NSLog("[G8Rumble] repeat timer started interval=%.3f", Self.repeatInterval)
    }

    private func stopRepeatTimer(clearPacket: Bool = true) {
        guard let timer = repeatTimer else {
            if clearPacket {
                repeatPacket = nil
            }
            return
        }

        timer.invalidate()
        repeatTimer = nil
        if clearPacket {
            repeatPacket = nil
        }
        // NSLog("[G8Rumble] repeat timer stopped")
    }

    private func repeatCurrentPacket() {
        objc_sync_enter(self)
        let isInvalidated = invalidated
        objc_sync_exit(self)
        if isInvalidated || !appActive {
            stopRepeatTimer()
            return
        }

        guard let packet = repeatPacket else {
            stopRepeatTimer()
            return
        }

        queuePacket(packet)
    }

    private func queuePacket(_ packet: Data) {
        queuedPacket = packet
        // NSLog("[G8Rumble] queued packet=%@", packet as NSData)

        if openSessionIfNeeded() {
            flushOutput()
        } else {
            // NSLog("[G8Rumble] packet queued but session is not open packet=%@", packet as NSData)
        }
    }

    private func flushOutput() {
        guard let outputStream = session?.outputStream else {
            return
        }
        guard outputStream.streamStatus == .open, outputStream.hasSpaceAvailable else {
            /*
            NSLog(
                "[G8Rumble] flush skipped status=%ld hasSpace=%d queued=%@ inFlight=%@",
                outputStream.streamStatus.rawValue,
                outputStream.hasSpaceAvailable,
                (queuedPacket as NSData?) ?? NSNull(),
                (inFlightPacket as NSData?) ?? NSNull()
            ) */
            return
        }

        while outputStream.hasSpaceAvailable {
            if inFlightPacket == nil {
                guard let packet = queuedPacket else {
                    return
                }
                inFlightPacket = packet
                queuedPacket = nil
                inFlightOffset = 0
            }

            guard let packet = inFlightPacket else {
                return
            }

            let remainingLength = packet.count - inFlightOffset
            let written = packet.withUnsafeBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return -1
                }
                return outputStream.write(baseAddress.advanced(by: inFlightOffset), maxLength: remainingLength)
            }

            if written <= 0 {
                NSLog(
                    "[G8Rumble] write failed packet=%@ offset=%lu remaining=%lu written=%ld status=%ld error=%@",
                    packet as NSData,
                    UInt(inFlightOffset),
                    UInt(remainingLength),
                    written,
                    outputStream.streamStatus.rawValue,
                    outputStream.streamError as NSError? ?? NSNull()
                )
                return
            }

            /*
            NSLog(
                "[G8Rumble] write packet=%@ offset=%lu remaining=%lu written=%ld status=%ld",
                packet as NSData,
                UInt(inFlightOffset),
                UInt(remainingLength),
                written,
                outputStream.streamStatus.rawValue
            ) */

            inFlightOffset += written
            if inFlightOffset == packet.count {
                // NSLog("[G8Rumble] packet sent %@", packet as NSData)
                lastSentPacket = packet
                inFlightPacket = nil
                inFlightOffset = 0
            }
        }
    }

    private func writeStopPacketBestEffort() {
        guard let outputStream = session?.outputStream else {
            return
        }
        guard outputStream.streamStatus == .open, outputStream.hasSpaceAvailable else {
            return
        }

        queuedPacket = nil
        flushOutput()
        if inFlightPacket != nil {
            return
        }

        let stopPacket = packet(lowFrequencyMotor: 0, highFrequencyMotor: 0)
        var offset = 0
        while offset < stopPacket.count && outputStream.hasSpaceAvailable {
            let written = stopPacket.withUnsafeBytes { rawBuffer -> Int in
                guard let baseAddress = rawBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return -1
                }
                return outputStream.write(baseAddress.advanced(by: offset), maxLength: stopPacket.count - offset)
            }
            if written <= 0 {
                NSLog(
                    "[G8Rumble] stop packet write failed offset=%lu written=%ld status=%ld error=%@",
                    UInt(offset),
                    written,
                    outputStream.streamStatus.rawValue,
                    outputStream.streamError as NSError? ?? NSNull()
                )
                break
            }
            offset += written
        }
        if offset == stopPacket.count {
            lastSentPacket = stopPacket
        }
        NSLog("[G8Rumble] stop packet written=%lu/%lu packet=%@", UInt(offset), UInt(stopPacket.count), stopPacket as NSData)
    }

    private func closeSession() {
        assert(Thread.isMainThread, "GameSir sessions must be closed on the main thread")
        stopRepeatTimer()
        if let session,
           let inputStream = session.inputStream,
           let outputStream = session.outputStream {
            NSLog(
                "[G8Rumble] closing EASession inputStatus=%ld outputStatus=%ld",
                inputStream.streamStatus.rawValue,
                outputStream.streamStatus.rawValue
            )
            inputStream.close()
            outputStream.close()
            inputStream.remove(from: .main, forMode: .default)
            outputStream.remove(from: .main, forMode: .default)
            inputStream.delegate = nil
            outputStream.delegate = nil
        }

        session = nil
        inFlightPacket = nil
        inFlightOffset = 0
        queuedPacket = nil
        lastSentPacket = nil
    }

    private func stopAndCloseOnMainThread() {
        assert(Thread.isMainThread, "GameSir sessions must be stopped on the main thread")
        writeStopPacketBestEffort()
        closeSession()
    }

    func stream(_ stream: Stream, handle eventCode: Stream.Event) {
        guard let session,
              let inputStream = session.inputStream,
              let outputStream = session.outputStream else {
            return
        }
        guard stream === inputStream || stream === outputStream else {
            return
        }

        switch eventCode {
        case .hasBytesAvailable:
            var buffer = [UInt8](repeating: 0, count: 64)
            while inputStream.hasBytesAvailable {
                if inputStream.read(&buffer, maxLength: buffer.count) <= 0 {
                    break
                }
            }
        case .openCompleted, .hasSpaceAvailable:
            if stream === outputStream {
                flushOutput()
            }
        case .errorOccurred, .endEncountered:
            writeStopPacketBestEffort()
            closeSession()
        default:
            break
        }
    }
}
