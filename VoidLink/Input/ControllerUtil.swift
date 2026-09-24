//
//  ControllerUtil.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/19.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


import GameController
import Combine
import CoreGraphics
import Foundation
#if !VOIDLINK_PREVIEW
import Collections
#endif
#if os(iOS) && !VOIDLINK_PREVIEW
import SwiftUI
import UIKit
#endif

@objc enum ControllerElementType: Int {
    case button
    case stick
    case stickAxis
    case touchpad
    case cluster
    case undefined
}

@objc enum ControllerElementPosition: Int {
    case left
    case right
    case middle
    case undefined
}

@objc enum ControllerElement: Int32 {
    // Face buttons
    case a = 0x1000
    case b = 0x2000
    case x = 0x4000
    case y = 0x8000
    
    // DPad
    case dpadUp    = 0x0001
    case dpadDown  = 0x0002
    case dpadLeft  = 0x0004
    case dpadRight = 0x0008
    
    // Shoulder
    case leftShoulder  = 0x0100
    case rightShoulder = 0x0200
    
    // Stick click
    case leftStickButton  = 0x0040
    case rightStickButton = 0x0080
    
    // Menu/Back/Special
    case start    = 0x0010 // PLAY_FLAG
    case select    = 0x0020 // BACK_FLAG
    case special = 0x0400
    
    // Extended buttons (Sunshine only)
    case paddle1  = 0x010000
    case paddle2  = 0x020000
    case paddle3  = 0x040000
    case paddle4  = 0x080000
    case touchpadButton = 0x100000
    case misc     = 0x200000
    
    case leftTrigger  = 0x400000
    case rightTrigger = 0x800000
    
    case leftStick = 0x800010
    case leftStickX = 0x80011
    case leftStickY = 0x800012
    case rightStick = 0x800020
    case rightStickX = 0x800021
    case rightStickY = 0x800022
    
    case dpad = 0x800013
    case abxy = 0x800023

    case null = 0xFFFFFF

    var displayName: String {
        switch self {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"

        case .dpadUp: return "DPadU".localized
        case .dpadDown: return "DPadD".localized
        case .dpadLeft: return "DPadL".localized
        case .dpadRight: return "DPadR".localized

        case .leftShoulder: return "LB"
        case .rightShoulder: return "RB"

        case .leftStickButton: return "LS"
        case .rightStickButton: return "RS"

        case .start: return "Start"
        case .select: return "Select"
        case .special: return "Home"

        case .paddle1: return "Paddle1".localized
        case .paddle2: return "Paddle2".localized
        case .paddle3: return "Paddle3".localized
        case .paddle4: return "Paddle4".localized
        case .touchpadButton: return "TouchBtn".localized
        case .misc: return "Misc"

        case .leftTrigger: return "LT"
        case .rightTrigger: return "RT"

        case .leftStick: return "LStick".localized
        case .leftStickX: return "LStickX".localized
        case .leftStickY: return "LStickY".localized
        case .rightStick: return "RStick".localized
        case .rightStickX: return "RStickX".localized
        case .rightStickY: return "RStickY".localized
            
        case .dpad: return "DPad".localized
        case .abxy: return "ABXY".localized

        case .null: return "Null".localized
        }
    }
    
    var symbol: String {
        switch self {
        case .dpadUp:
            if #available(iOS 15.0, *) {return "dpad.up.filled"}
            else {return ""}
        case .dpadDown:
            if #available(iOS 15.0, *) {return "dpad.down.filled"}
            else {return ""}
        case .dpadLeft:
            if #available(iOS 15.0, *) {return "dpad.left.filled"}
            else {return ""}
        case .dpadRight:
            if #available(iOS 15.0, *) {return "dpad.right.filled"}
            else {return ""}
        case .dpad:
            if #available(iOS 14.0, *) {return "dpad"}
            else {return ""}
        case .a:
            if #available(iOS 15.0, *) {return "circle.grid.cross.down.filled"}
            else {return ""}
        case .b:
            if #available(iOS 15.0, *) {return "circle.grid.cross.right.filled"}
            else {return ""}
        case .x:
            if #available(iOS 15.0, *) {return "circle.grid.cross.left.filled"}
            else {return ""}
        case .y:
            if #available(iOS 15.0, *) {return "circle.grid.cross.up.filled"}
            else {return ""}
        case .abxy:
            if #available(iOS 14.0, *) {return "circle.grid.cross"}
            else {return ""}

        default: return ""
        }
    }
    
    var type: ControllerElementType {
        switch self {
        case .a: return .button
        case .b: return .button
        case .x: return .button
        case .y: return .button

        case .dpadUp: return .button
        case .dpadDown: return .button
        case .dpadLeft: return .button
        case .dpadRight: return .button

        case .leftShoulder: return .button
        case .rightShoulder: return .button

        case .leftStickButton: return .button
        case .rightStickButton: return .button

        case .start: return .button
        case .select: return .button
        case .special: return .button

        case .paddle1: return .button
        case .paddle2: return .button
        case .paddle3: return .button
        case .paddle4: return .button
        case .touchpadButton: return .button
        case .misc: return .button

        case .leftTrigger: return .button
        case .rightTrigger: return .button

        case .leftStick: return .stick
        case .leftStickX: return .stickAxis
        case .leftStickY: return .stickAxis
        case .rightStick: return .stick
        case .rightStickX: return .stickAxis
        case .rightStickY: return .stickAxis
        
        case .dpad: return .cluster
        case .abxy: return .cluster

        case .null: return .undefined
        }
    }
    
    var position: ControllerElementPosition {
        switch self {
        case .a: return .right
        case .b: return .right
        case .x: return .right
        case .y: return .right

        case .dpadUp: return .left
        case .dpadDown: return .left
        case .dpadLeft: return .left
        case .dpadRight: return .left

        case .leftShoulder: return .left
        case .rightShoulder: return .right

        case .leftStickButton: return .left
        case .rightStickButton: return .right

        case .start: return .right
        case .select: return .left
        case .special: return .undefined

        case .paddle1: return .right
        case .paddle2: return .right
        case .paddle3: return .left
        case .paddle4: return .left
        case .touchpadButton: return .middle
        case .misc: return .undefined

        case .leftTrigger: return .left
        case .rightTrigger: return .right

        case .leftStick: return .left
        case .leftStickX: return .left
        case .leftStickY: return .left
        case .rightStick: return .right
        case .rightStickX: return .right
        case .rightStickY: return .right
            
        case .abxy: return .right
        case .dpad: return .left

        case .null: return .undefined
        }
    }
}

@objc enum ControllerEmulation: UInt8 {
    case xbox = 0x01 // LI_CTYPE_XBOX
    case ps = 0x02 // LI_CTYPE_PS
    case psEnhancedHaptic = 0xFE
    case xboxAndPs = 0x00 // LI_CTYPE_UNKNOWN
}

@objc enum ControllerHardware: UInt8 {
    case generic
    case g8PlusMFi
    case razerKishi
}

@objc protocol ControllerUtilDelegate: AnyObject {
    func isStreaming() -> Bool
    func isInAppView() -> Bool
}

@objc class ControllerUtil: NSObject {
    @objc static weak var delegate: ControllerUtilDelegate?

#if !VOIDLINK_PREVIEW
    @objc static var hasDualSenseController: Bool {
        if #available(iOS 14.5, *) {
            for gcController in GCController.controllers() {
                if gcController.extendedGamepad is GCDualSenseGamepad {return true}
            }
            return false
        }
        else {return false}
    }

    @objc static func hasControllerAccelerometer(_ controller: GCController) -> Bool {
        guard let motion = controller.motion else { return false }

        if #available(iOS 14.0, tvOS 14.0, *) {
            if motion.hasGravityAndUserAcceleration {
                return true
            }
            
            if controller.extendedGamepad is GCDualShockGamepad {
                return true
            }
            
            if #available(iOS 14.5, tvOS 14.5, *) {
                if controller.extendedGamepad is GCDualSenseGamepad {
                    return true
                }
            }
        }

        return false
    }
    
    private struct DualSensePCMChunk {
        let controllerNumber: UInt16
        let flags: UInt8
        let sequenceNumber: UInt32
        let presentationTimeUs: UInt64
        let frameCount: UInt16
        let pcmData: Data
    }

    private final class AuthoredEngineState {
        var engine: OpaquePointer?
        var renderHostAnchorUs: UInt64?
        var renderLocalAnchor = 0.0
        var diagnosticFrameCounter: UInt32 = 0

        init?() {
            var config = AhAuthoredConfig()
            guard ah_authored_config_init(&config, 48_000) == AH_STATUS_OK else {
                return nil
            }
            guard ah_authored_create(&config, &engine) == AH_STATUS_OK, engine != nil else {
                return nil
            }
        }

        deinit {
            ah_authored_destroy(engine)
        }

        func renderDelay(for timestampUs: UInt64, resetTimeline: Bool) -> TimeInterval {
            let now = ProcessInfo.processInfo.systemUptime
            if resetTimeline || renderHostAnchorUs == nil {
                renderHostAnchorUs = timestampUs
                renderLocalAnchor = now + 0.002
            }
            let anchor = renderHostAnchorUs ?? timestampUs
            let hostDelta = timestampUs >= anchor ? Double(timestampUs - anchor) / 1_000_000.0 : 0
            return min(max(renderLocalAnchor + hostDelta - now, 0), 0.025)
        }
    }

    private final class AuthoredIrRenderState {
        var renderHostAnchorUs: UInt64?
        var renderLocalAnchor = 0.0
        var diagnosticFrameCounter: UInt32 = 0

        func renderDelay(for timestampUs: UInt64, resetTimeline: Bool) -> TimeInterval {
            let now = ProcessInfo.processInfo.systemUptime
            if resetTimeline || renderHostAnchorUs == nil {
                renderHostAnchorUs = timestampUs
                renderLocalAnchor = now + 0.002
            }
            let anchor = renderHostAnchorUs ?? timestampUs
            let hostDelta = timestampUs >= anchor ? Double(timestampUs - anchor) / 1_000_000.0 : 0
            return min(max(renderLocalAnchor + hostDelta - now, 0), 0.025)
        }
    }

    private static let dualSenseHapticsLock = NSLock()
    private static let dualSenseHapticsWorker = DispatchQueue(
        label: "com.voidlink.dualsense-authored-haptics",
        qos: .userInteractive
    )
    private static let maxQueuedDualSensePCMChunks = 8
    private static let defaultDualSenseControllerHapticsEQ: [Float] = [0.78, 0.98, 1.59, 0.175, 1.2]
    private static let defaultDeviceDualSenseHapticsEQ: [Float] = [18, 0.98, 1.59, 0.9, 1.2]
    private static let dualSenseControllerAmplitudeScale: Float = 1.15
    private static let dualSenseControllerTransientScale: Float = 1.0
    private static let dualSenseControllerSharpnessScale: Float = 1.15
    private static let dualSenseControllerMirrorMixedHandles = false
    private static var dualSensePCMQueue = Deque<DualSensePCMChunk>()
    private static var dualSenseWorkerScheduled = false
    private static var dualSenseForcedDiscontinuities = Set<UInt16>()
    private static var dualSenseAuthoredEngines = [UInt16: AuthoredEngineState]()
    private static var dualSenseIrRenderStates = [UInt16: AuthoredIrRenderState]()
    private static let authoredHapticsRouteLock = NSLock()
    private static var authoredHapticsPreference = AuthoredHapticsPreference.auto
    private static var authoredHapticsLastRoutedToDualSense = false
    private static var authoredHapticsLastRoute = AuthoredHapticsRoute.off

    private enum AuthoredHapticsPreference: Int {
        case auto = 0
        case device = 1
        case swapped = 2
        case off = 3
    }

    private enum AuthoredHapticsRoute {
        case dualSense
        case device
        case off
    }

#if os(iOS)
    private static var dualSenseHapticsEQOverlayWindow: UIWindow?
    private static weak var dualSenseHapticsEQPreviousKeyWindow: UIWindow?
    private static var didPresentDualSenseHapticsEQ = false
#endif

    fileprivate static func dualSenseHapticsEQSnapshot() -> [Float] {
        defaultDeviceDualSenseHapticsEQ
    }

    fileprivate static func defaultDualSenseHapticsEQSnapshot() -> [Float] {
        defaultDeviceDualSenseHapticsEQ
    }

    private static func dualSenseHapticsEQSnapshot(for route: AuthoredHapticsRoute) -> [Float] {
        switch route {
        case .dualSense:
            return defaultDualSenseControllerHapticsEQ
        case .device, .off:
            return defaultDeviceDualSenseHapticsEQ
        }
    }

    private static func compensatedDualSenseControllerValues(
        _ values: (amplitude: Float, sharpness: Float, transient: Float),
        highBandRatio: Float
    ) -> (amplitude: Float, sharpness: Float, transient: Float) {
        let lowFrequencyTrim = 0.82 + 0.18 * min(max(highBandRatio, 0), 1)
        let amplitude = min(max(
            pow(values.amplitude, 0.50) * dualSenseControllerAmplitudeScale * lowFrequencyTrim,
            0
        ), 1)
        let sharpness = min(max(
            pow(values.sharpness, 0.8) * dualSenseControllerSharpnessScale,
            0
        ), 1)
        let transient = min(max(
            pow(values.transient, 0.9) * dualSenseControllerTransientScale,
            0
        ), 1)
        return (amplitude, sharpness, transient)
    }

    private static func authoredHighBandRatio(for lane: AhAuthoredLaneFrame?) -> Float {
        1 - min(max(lane?.low_band_ratio ?? 1, 0), 1)
    }

    private static func mixedDualSenseControllerHandleValues(
        left: (amplitude: Float, sharpness: Float, transient: Float),
        right: (amplitude: Float, sharpness: Float, transient: Float)
    ) -> (
        left: (amplitude: Float, sharpness: Float, transient: Float),
        right: (amplitude: Float, sharpness: Float, transient: Float)
    ) {
        guard dualSenseControllerMirrorMixedHandles else {
            return (left, right)
        }

        let amplitude = min(max(sqrt(
            (left.amplitude * left.amplitude + right.amplitude * right.amplitude) * 0.5
        ), 0), 1)
        let amplitudeSum = left.amplitude + right.amplitude
        let sharpness = amplitudeSum > 0.000_001
            ? min(max(
                (left.sharpness * left.amplitude + right.sharpness * right.amplitude) / amplitudeSum,
                0
            ), 1)
            : min(max(max(left.sharpness, right.sharpness), 0), 1)
        let transient = min(max(max(left.transient, right.transient), 0), 1)
        let mixed = (amplitude: amplitude, sharpness: sharpness, transient: transient)
        return (mixed, mixed)
    }

    fileprivate static func previewDualSenseHapticsEQ(_ values: [Float]) {
    }

    fileprivate static func saveDualSenseHapticsEQ(_ values: [Float]) {
    }

    private static func refreshAuthoredHapticsPreference() -> AuthoredHapticsPreference {
        let rawValue = Int(DataManager().getSettings().hapticEngine.intValue)
        let preference = AuthoredHapticsPreference(rawValue: rawValue) ?? .auto
        authoredHapticsRouteLock.lock()
        authoredHapticsPreference = preference
        authoredHapticsRouteLock.unlock()
        return preference
    }

    private static func selectAuthoredHapticsRoute(
        controllerNumber: UInt16,
        controllerSupport: ControllerSupport
    ) -> AuthoredHapticsRoute {
        switch refreshAuthoredHapticsPreference() {
        case .off:
            return .off
        case .device:
            return .device
        case .auto, .swapped:
            let hasDualSense = controllerSupport.hasDualSenseController(controllerNumber)
            authoredHapticsRouteLock.lock()
            authoredHapticsLastRoutedToDualSense = hasDualSense
            authoredHapticsRouteLock.unlock()
            return hasDualSense ? .dualSense : .device
        }
    }

    private static func stopAuthoredHapticsRoute(
        _ route: AuthoredHapticsRoute,
        controllerNumber: UInt16,
        controllerSupport: ControllerSupport
    ) {
        switch route {
        case .dualSense:
            controllerSupport.renderDualSenseHaptics(
                controllerNumber,
                leftAmplitude: 0,
                leftSharpness: 0,
                leftTransient: 0,
                rightAmplitude: 0,
                rightSharpness: 0,
                rightTransient: 0,
                delaySeconds: 0
            )
        case .device:
            controllerSupport.renderDeviceDualSenseHaptics(
                controllerNumber,
                leftAmplitude: 0,
                leftSharpness: 0,
                leftTransient: 0,
                rightAmplitude: 0,
                rightSharpness: 0,
                rightTransient: 0,
                delaySeconds: 0
            )
        case .off:
            break
        }
    }

    private static func updateAuthoredHapticsRouteTransition(
        to route: AuthoredHapticsRoute,
        controllerNumber: UInt16,
        controllerSupport: ControllerSupport
    ) {
        authoredHapticsRouteLock.lock()
        let previousRoute = authoredHapticsLastRoute
        authoredHapticsLastRoute = route
        authoredHapticsLastRoutedToDualSense = route == .dualSense
        authoredHapticsRouteLock.unlock()

        if previousRoute != route {
            stopAuthoredHapticsRoute(
                previousRoute,
                controllerNumber: controllerNumber,
                controllerSupport: controllerSupport
            )
        }
    }

#if os(iOS)
    @available(iOS 14.0, *)
    @objc static func presentDualSenseHapticsEQIfNeeded() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !didPresentDualSenseHapticsEQ,
              dualSenseHapticsEQOverlayWindow == nil,
              let keyWindow = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: { $0.isKeyWindow }),
              let windowScene = keyWindow.windowScene else {
            return
        }

        didPresentDualSenseHapticsEQ = true
        dualSenseHapticsEQPreviousKeyWindow = keyWindow

        let store = DualSenseHapticsEQStore(values: dualSenseHapticsEQSnapshot())
        let rootView = DualSenseHapticsEQView(store: store) {
            closeDualSenseHapticsEQ()
        }
        let hostingController = UIHostingController(rootView: rootView)
        hostingController.view.backgroundColor = .clear

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.frame = windowScene.screen.bounds
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.rootViewController = hostingController
        dualSenseHapticsEQOverlayWindow = overlayWindow
        overlayWindow.makeKeyAndVisible()
    }

    fileprivate static func closeDualSenseHapticsEQ() {
        dualSenseHapticsEQOverlayWindow?.isHidden = true
        dualSenseHapticsEQOverlayWindow?.rootViewController = nil
        dualSenseHapticsEQOverlayWindow = nil
        dualSenseHapticsEQPreviousKeyWindow?.makeKey()
        dualSenseHapticsEQPreviousKeyWindow = nil
    }
#endif

    @objc(enqueueDualSenseHapticsPCMWithControllerNumber:flags:sequenceNumber:presentationTimeUs:frameCount:pcmData:)
    static func enqueueDualSenseHapticsPCM(
        controllerNumber: UInt16,
        flags: UInt8,
        sequenceNumber: UInt32,
        presentationTimeUs: UInt64,
        frameCount: UInt16,
        pcmData: Data
    ) {
        let expectedByteCount = Int(frameCount) * 2 * MemoryLayout<Int16>.size
        guard frameCount <= 480, pcmData.count == expectedByteCount else {
            NSLog("DualSense haptics: rejected malformed PCM chunk for controller %u", controllerNumber)
            return
        }

        let chunk = DualSensePCMChunk(
            controllerNumber: controllerNumber,
            flags: flags,
            sequenceNumber: sequenceNumber,
            presentationTimeUs: presentationTimeUs,
            frameCount: frameCount,
            pcmData: pcmData
        )

        dualSenseHapticsLock.lock()
        if dualSensePCMQueue.count >= maxQueuedDualSensePCMChunks,
           let dropped = dualSensePCMQueue.popFirst() {
            dualSenseForcedDiscontinuities.insert(dropped.controllerNumber)
        }
        dualSensePCMQueue.append(chunk)
        let shouldScheduleWorker = !dualSenseWorkerScheduled
        dualSenseWorkerScheduled = true
        dualSenseHapticsLock.unlock()

        if shouldScheduleWorker {
            dualSenseHapticsWorker.async {
                drainDualSensePCMQueue()
            }
        }
    }

    @objc(enqueueDualSenseHapticsIRV2WithControllerNumber:flags:sourceSequenceNumber:timestampUs:sourceFrameCount:leftRms:leftPeak:leftTransient:leftLowRatio:leftZeroCrossHz:rightRms:rightPeak:rightTransient:rightLowRatio:rightZeroCrossHz:laneCorrelation:)
    static func enqueueDualSenseHapticsIRV2(
        controllerNumber: UInt16,
        flags: UInt8,
        sourceSequenceNumber: UInt32,
        timestampUs: UInt64,
        sourceFrameCount: UInt32,
        leftRms: Float,
        leftPeak: Float,
        leftTransient: Float,
        leftLowRatio: Float,
        leftZeroCrossHz: Float,
        rightRms: Float,
        rightPeak: Float,
        rightTransient: Float,
        rightLowRatio: Float,
        rightZeroCrossHz: Float,
        laneCorrelation: Float
    ) {
        dualSenseHapticsWorker.async {
            processDualSenseIRV2Frame(
                controllerNumber: controllerNumber,
                flags: flags,
                sourceSequenceNumber: sourceSequenceNumber,
                timestampUs: timestampUs,
                sourceFrameCount: sourceFrameCount,
                left: makeAuthoredLaneFrame(
                    rmsAmplitude: leftRms,
                    peakAmplitude: leftPeak,
                    transientStrength: leftTransient,
                    lowBandRatio: leftLowRatio,
                    zeroCrossingRateHz: leftZeroCrossHz
                ),
                right: makeAuthoredLaneFrame(
                    rmsAmplitude: rightRms,
                    peakAmplitude: rightPeak,
                    transientStrength: rightTransient,
                    lowBandRatio: rightLowRatio,
                    zeroCrossingRateHz: rightZeroCrossHz
                ),
                laneCorrelation: laneCorrelation
            )
        }
    }

    @objc static func stopAllDualSenseHaptics() {
        ControllerSupport.sharedInstance()?.cancelScheduledDualSenseHaptics()

        dualSenseHapticsLock.lock()
        dualSensePCMQueue.removeAll(keepingCapacity: true)
        dualSenseForcedDiscontinuities.removeAll(keepingCapacity: true)
        dualSenseHapticsLock.unlock()

        dualSenseHapticsWorker.async {
            let controllerNumbers = Array(
                Set(dualSenseAuthoredEngines.keys).union(dualSenseIrRenderStates.keys)
            )
            dualSenseAuthoredEngines.removeAll(keepingCapacity: false)
            dualSenseIrRenderStates.removeAll(keepingCapacity: false)
            for controllerNumber in controllerNumbers {
                renderDualSenseHaptics(controllerNumber: controllerNumber, left: nil, right: nil, delay: 0)
            }
        }
    }

    private static func makeAuthoredLaneFrame(
        rmsAmplitude: Float,
        peakAmplitude: Float,
        transientStrength: Float,
        lowBandRatio: Float,
        zeroCrossingRateHz: Float
    ) -> AhAuthoredLaneFrame {
        var lane = AhAuthoredLaneFrame()
        lane.rms_amplitude = rmsAmplitude
        lane.peak_amplitude = peakAmplitude
        lane.transient_strength = transientStrength
        lane.low_band_ratio = lowBandRatio
        lane.zero_crossing_rate_hz = zeroCrossingRateHz
        return lane
    }

    private static func processDualSenseIRV2Frame(
        controllerNumber: UInt16,
        flags: UInt8,
        sourceSequenceNumber: UInt32,
        timestampUs: UInt64,
        sourceFrameCount: UInt32,
        left: AhAuthoredLaneFrame,
        right: AhAuthoredLaneFrame,
        laneCorrelation: Float
    ) {
        let isDiscontinuity = (flags & 0x01) != 0
        let isStreamEnd = (flags & 0x04) != 0
        let isSilent = (flags & 0x08) != 0
        let state = dualSenseIrRenderStates[controllerNumber] ?? AuthoredIrRenderState()
        dualSenseIrRenderStates[controllerNumber] = state
        let delay = state.renderDelay(
            for: timestampUs,
            resetTimeline: isDiscontinuity || state.diagnosticFrameCounter == 0
        )
        state.diagnosticFrameCounter &+= 1

        renderDualSenseHaptics(
            controllerNumber: controllerNumber,
            left: isSilent ? nil : left,
            right: isSilent ? nil : right,
            laneCorrelation: laneCorrelation,
            logDiagnostics: state.diagnosticFrameCounter % 100 == 0,
            appliesEQ: false,
            delay: delay
        )

        if isStreamEnd {
            renderDualSenseHaptics(
                controllerNumber: controllerNumber,
                left: nil,
                right: nil,
                appliesEQ: false,
                delay: delay + 0.005
            )
            dualSenseIrRenderStates.removeValue(forKey: controllerNumber)
        }

        _ = sourceSequenceNumber
        _ = sourceFrameCount
    }

    private static func drainDualSensePCMQueue() {
        while true {
            dualSenseHapticsLock.lock()
            guard var chunk = dualSensePCMQueue.popFirst() else {
                dualSenseWorkerScheduled = false
                dualSenseHapticsLock.unlock()
                return
            }
            if dualSenseForcedDiscontinuities.remove(chunk.controllerNumber) != nil {
                chunk = DualSensePCMChunk(
                    controllerNumber: chunk.controllerNumber,
                    flags: chunk.flags | 0x04,
                    sequenceNumber: chunk.sequenceNumber,
                    presentationTimeUs: chunk.presentationTimeUs,
                    frameCount: chunk.frameCount,
                    pcmData: chunk.pcmData
                )
            }
            dualSenseHapticsLock.unlock()
            processDualSensePCMChunk(chunk)
        }
    }

    private static func processDualSensePCMChunk(_ chunk: DualSensePCMChunk) {
        let isStreamStart = (chunk.flags & 0x01) != 0
        let isStreamEnd = (chunk.flags & 0x02) != 0
        let isDiscontinuity = (chunk.flags & 0x04) != 0

        if isStreamStart || dualSenseAuthoredEngines[chunk.controllerNumber] == nil {
            dualSenseAuthoredEngines[chunk.controllerNumber] = AuthoredEngineState()
            NSLog("DualSense haptics: stream started for controller %u", chunk.controllerNumber)
        }
        guard let state = dualSenseAuthoredEngines[chunk.controllerNumber],
              let engine = state.engine else {
            NSLog("DualSense haptics: failed to create authored engine for controller %u", chunk.controllerNumber)
            return
        }

        var inputFlags: UInt32 = 0
        if isStreamStart { inputFlags |= UInt32(AH_AUTHORED_INPUT_STREAM_START) }
        if isDiscontinuity { inputFlags |= UInt32(AH_AUTHORED_INPUT_DISCONTINUITY) }
        if isStreamEnd { inputFlags |= UInt32(AH_AUTHORED_INPUT_STREAM_END) }

        var samples = [Int16](repeating: 0, count: Int(chunk.frameCount) * 2)
        chunk.pcmData.withUnsafeBytes { rawBuffer in
            let bytes = rawBuffer.bindMemory(to: UInt8.self)
            for index in samples.indices {
                let offset = index * 2
                let value = UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
                samples[index] = Int16(bitPattern: value)
            }
        }

        let outputCapacity = ah_authored_get_max_output_frames(
            engine,
            UInt32(chunk.frameCount),
            inputFlags
        )
        var outputFrames = [AhAuthoredHapticFrame](
            repeating: AhAuthoredHapticFrame(),
            count: Int(outputCapacity)
        )
        var outputCount: UInt32 = 0
        let status = samples.withUnsafeBufferPointer { sampleBuffer -> AhStatus in
            var input = AhAuthoredProcessInput()
            input.struct_size = UInt32(MemoryLayout<AhAuthoredProcessInput>.size)
            input.interleaved_pcm = sampleBuffer.baseAddress
            input.frame_count = UInt32(chunk.frameCount)
            input.flags = inputFlags
            input.first_sample_time_us = chunk.presentationTimeUs
            input.sequence_number = chunk.sequenceNumber
            return ah_authored_process_i16(
                engine,
                &input,
                &outputFrames,
                outputCapacity,
                &outputCount
            )
        }

        guard status == AH_STATUS_OK || status == AH_STATUS_OUTPUT_AVAILABLE else {
            NSLog("DualSense haptics: authored conversion failed with status %d", status)
            ah_authored_reset(engine)
            renderDualSenseHaptics(controllerNumber: chunk.controllerNumber, left: nil, right: nil, delay: 0)
            return
        }

        var finalRenderDelay = 0.0
        for index in 0..<Int(outputCount) {
            let frame = outputFrames[index]
            let silent = (frame.flags & UInt32(AH_AUTHORED_FRAME_SILENT)) != 0
            let resetTimeline = isStreamStart || isDiscontinuity ||
                (frame.flags & UInt32(AH_AUTHORED_FRAME_DISCONTINUITY)) != 0
            let delay = state.renderDelay(for: frame.timestamp_us, resetTimeline: resetTimeline && index == 0)
            finalRenderDelay = max(finalRenderDelay, delay)
            state.diagnosticFrameCounter &+= 1
            renderDualSenseHaptics(
                controllerNumber: chunk.controllerNumber,
                left: silent ? nil : frame.lanes.0,
                right: silent ? nil : frame.lanes.1,
                laneCorrelation: frame.lane_correlation,
                logDiagnostics: state.diagnosticFrameCounter % 100 == 0,
                appliesEQ: false,
                delay: delay
            )
        }

        if isStreamEnd {
            renderDualSenseHaptics(
                controllerNumber: chunk.controllerNumber,
                left: nil,
                right: nil,
                delay: finalRenderDelay + 0.005
            )
            dualSenseAuthoredEngines.removeValue(forKey: chunk.controllerNumber)
            NSLog("DualSense haptics: stream ended for controller %u", chunk.controllerNumber)
        }
    }

    @objc static var dualSenseHapticTransient: Float = 1.0
    private static func renderDualSenseHaptics(
        controllerNumber: UInt16,
        left: AhAuthoredLaneFrame?,
        right: AhAuthoredLaneFrame?,
        laneCorrelation: Float = 0,
        logDiagnostics: Bool = false,
        appliesEQ: Bool = true,
        delay: TimeInterval
    ) {
        guard let controllerSupport = ControllerSupport.sharedInstance() else {
            return
        }

        let route = selectAuthoredHapticsRoute(
            controllerNumber: controllerNumber,
            controllerSupport: controllerSupport
        )
        updateAuthoredHapticsRouteTransition(
            to: route,
            controllerNumber: controllerNumber,
            controllerSupport: controllerSupport
        )

        guard route != .off else {
            return
        }

        let eq = appliesEQ ? dualSenseHapticsEQSnapshot(for: route) : [1, 1, 1, 1, 1] as [Float]
        let masterGain = eq[0]
        let lowBandGain = eq[1]
        let highBandGain = eq[2]
        let transientGain = eq[3]
        let sharpnessGain = eq[4]

        func rawIrValues(for lane: AhAuthoredLaneFrame?) -> (amplitude: Float, sharpness: Float, transient: Float) {
            guard let lane else {
                return (0, 0, 0)
            }
            let amplitude = min(max(lane.rms_amplitude, 0), 1)
            let sharpness = min(max(1 - lane.low_band_ratio, 0), 1)
            let transient = min(max(lane.transient_strength, 0), 1)
            return (amplitude, sharpness, transient)
        }

        func renderValues1(for lane: AhAuthoredLaneFrame?) -> (amplitude: Float, sharpness: Float, transient: Float) {
            let lowBandRatio = min(max(lane?.low_band_ratio ?? 1, 0), 1)
            let highBandRatio = 1 - lowBandRatio
            let effectiveLowBandGain = pow(lowBandGain, 1.6)
            let effectiveHighBandGain = pow(highBandGain, 1.6)
            let weightedLowEnergy = lowBandRatio * effectiveLowBandGain * effectiveLowBandGain
            let weightedHighEnergy = highBandRatio * effectiveHighBandGain * effectiveHighBandGain
            let weightedEnergy = weightedLowEnergy + weightedHighEnergy
            let bandGain = weightedEnergy.squareRoot()
            let equalizedHighBandRatio = weightedEnergy > 0.000_001
                ? weightedHighEnergy / weightedEnergy
                : 0

            let zeroCrossingFrequency = min(max((lane?.zero_crossing_rate_hz ?? 0) * 0.5, 0), 400)
            let hasTextureModel = zeroCrossingFrequency >= 40
            let representativeFrequency = hasTextureModel
                ? zeroCrossingFrequency
                : 120 * lowBandRatio + 300 * highBandRatio
            let spectralSharpness = min(max((representativeFrequency - 40) / 360, 0), 1)
            let immediateSharpness = equalizedHighBandRatio.squareRoot()
            let synthesizedSharpness = hasTextureModel
                ? 0.9 * immediateSharpness + 0.1 * spectralSharpness
                : immediateSharpness
            let sourceTransient = min(max(lane?.transient_strength ?? 0, 0), 1)
            let rmsAmplitude = min(max(lane?.rms_amplitude ?? 0, 0), 1)
            let transientBandTrim = 0.55 + 0.35 * lowBandRatio + 0.10 * equalizedHighBandRatio
            let lowContinuousTrim = 0.78 + 0.22 * lowBandRatio
            let highContinuousTrim = 0.62 - 0.30 * equalizedHighBandRatio
            let renderedTransient = min(max(
                pow(sourceTransient, 0.45) * sqrt(masterGain) * transientGain *
                    bandGain * transientBandTrim * 1.35,
                0
            ), 1)
            let continuousShare = 1 - 0.85 * min(
                pow(sourceTransient, 0.55) * transientGain,
                1
            )
            let lowBody = pow(rmsAmplitude, 1.85) *
                (1 - highBandRatio) * effectiveLowBandGain * 0.55
            let highTexture = pow(rmsAmplitude, 0.55) *
                pow(highBandRatio, 1.35) * effectiveHighBandGain * 0.09
            let midBodyTrim = 1 - 0.55 * min(max((representativeFrequency - 90) / 140, 0), 1) *
                (1 - highBandRatio)
            let continuousAmplitude = (lowBody * lowContinuousTrim + highTexture * highContinuousTrim) *
                masterGain * midBodyTrim * continuousShare
            return (
                min(max(continuousAmplitude, 0), 1),
                min(max(synthesizedSharpness * sharpnessGain, 0), 1),
                renderedTransient
            )
        }

        func renderValues2(for lane: AhAuthoredLaneFrame?) -> (amplitude: Float, sharpness: Float, transient: Float) {
            guard let lane else {
                return (0, 0, 0)
            }

            let useBuiltinHaptic = route == .device
            
            let rmsAmplitude = min(max(lane.rms_amplitude, 0), 1)
            
            let lowBandRatio = min(max(lane.low_band_ratio, 0), 1)
            let highBandRatio = 1 - lowBandRatio
            let amplitudeLowBandGain: Float = 1.0
            let amplitudeHighBandGain: Float = 1.0
            let bandGain = lowBandRatio * amplitudeLowBandGain + highBandRatio * amplitudeHighBandGain
            let sourceSharpness = min(max(highBandRatio, 0), 1)
            let sharpnessLowGain: Float = 0.62
            let sharpnessMidGain: Float = 0.82
            let sharpnessHighGain: Float = 1.2
            let sharpnessLowWeight = min(max((0.50 - sourceSharpness) / 0.50, 0), 1)
            let sharpnessHighWeight = min(max((sourceSharpness - 0.50) / 0.50, 0), 1)
            let sharpnessMidWeight = 1 - max(sharpnessLowWeight, sharpnessHighWeight)
            let sharpnessGain = sharpnessLowWeight * sharpnessLowGain +
                sharpnessMidWeight * sharpnessMidGain +
                sharpnessHighWeight * sharpnessHighGain
            let sharpness = min(max(sourceSharpness * sharpnessGain, 0), 1)
            
            let transient = min(max(lane.transient_strength, 0), 1)
            let amplitudeCeiling: Float = 1.0
            let transientGain: Float = useBuiltinHaptic ? 1.03 : 0.343
            let transientCeiling: Float = useBuiltinHaptic ? 1.03 : 0.6
            let transientBottom: Float = useBuiltinHaptic ? 0.14 : 0.0

            return (
                min(rmsAmplitude * bandGain, amplitudeCeiling),
                sharpness,
                min(max(transientBottom, transient * transientGain * 1.6666666667 * dualSenseHapticTransient), transientCeiling)
            )
        }

        var leftValues = appliesEQ ? renderValues1(for: left) : renderValues2(for: left)
        var rightValues = appliesEQ ? renderValues1(for: right) : renderValues2(for: right)

        if appliesEQ {
            let positiveCorrelation = min(max(laneCorrelation, 0), 1)
            let commonHighBandRatio = (
                authoredHighBandRatio(for: left) + authoredHighBandRatio(for: right)
            ) * 0.5
            let dualSenseCenterBlendScale = 0.10 + 0.55 * commonHighBandRatio
            let centerBlendScale: Float = route == .dualSense ? dualSenseCenterBlendScale : 0.85
            let centerBlend = min(max((positiveCorrelation - 0.1) / 0.9, 0), 1) * centerBlendScale
            if centerBlend > 0 {
                let commonAmplitude = sqrt(
                    (leftValues.amplitude * leftValues.amplitude +
                     rightValues.amplitude * rightValues.amplitude) * 0.5
                )
                let amplitudeSum = leftValues.amplitude + rightValues.amplitude
                let commonSharpness = amplitudeSum > 0.000_001
                    ? (leftValues.sharpness * leftValues.amplitude +
                       rightValues.sharpness * rightValues.amplitude) / amplitudeSum
                    : max(leftValues.sharpness, rightValues.sharpness)
                let commonTransient = max(leftValues.transient, rightValues.transient)

                leftValues.amplitude += (commonAmplitude - leftValues.amplitude) * centerBlend
                rightValues.amplitude += (commonAmplitude - rightValues.amplitude) * centerBlend
                leftValues.sharpness += (commonSharpness - leftValues.sharpness) * centerBlend
                rightValues.sharpness += (commonSharpness - rightValues.sharpness) * centerBlend
                leftValues.transient += (commonTransient - leftValues.transient) * centerBlend
                rightValues.transient += (commonTransient - rightValues.transient) * centerBlend
            }
        }
        
        /*
        if logDiagnostics {
            NSLog(
                "DS5 authored: c=%u route=%@ srcL[rms=%.3f high=%.3f hz=%.0f] srcR[rms=%.3f high=%.3f hz=%.0f] corr=%.2f outL[a=%.3f s=%.3f t=%.3f] outR[a=%.3f s=%.3f t=%.3f]",
                controllerNumber,
                route == .dualSense ? "dualsense" : "device",
                Double(left?.rms_amplitude ?? 0),
                Double(1 - min(max(left?.low_band_ratio ?? 1, 0), 1)),
                Double(min(max((left?.zero_crossing_rate_hz ?? 0) * 0.5, 0), 400)),
                Double(right?.rms_amplitude ?? 0),
                Double(1 - min(max(right?.low_band_ratio ?? 1, 0), 1)),
                Double(min(max((right?.zero_crossing_rate_hz ?? 0) * 0.5, 0), 400)),
                Double(laneCorrelation),
                Double(leftValues.amplitude),
                Double(leftValues.sharpness),
                Double(leftValues.transient),
                Double(rightValues.amplitude),
                Double(rightValues.sharpness),
                Double(rightValues.transient)
            )
        }
         */

        switch route {
        case .dualSense:
            if appliesEQ {
                leftValues = compensatedDualSenseControllerValues(
                    leftValues,
                    highBandRatio: authoredHighBandRatio(for: left)
                )
                rightValues = compensatedDualSenseControllerValues(
                    rightValues,
                    highBandRatio: authoredHighBandRatio(for: right)
                )
                let mixedValues = mixedDualSenseControllerHandleValues(left: leftValues, right: rightValues)
                leftValues = mixedValues.left
                rightValues = mixedValues.right
            }
            controllerSupport.renderDualSenseHaptics(
                controllerNumber,
                leftAmplitude: leftValues.amplitude,
                leftSharpness: leftValues.sharpness,
                leftTransient: leftValues.transient,
                rightAmplitude: rightValues.amplitude,
                rightSharpness: rightValues.sharpness,
                rightTransient: rightValues.transient,
                delaySeconds: delay
            )
        case .device:
            controllerSupport.renderDeviceDualSenseHaptics(
                controllerNumber,
                leftAmplitude: leftValues.amplitude,
                leftSharpness: leftValues.sharpness,
                leftTransient: leftValues.transient,
                rightAmplitude: rightValues.amplitude,
                rightSharpness: rightValues.sharpness,
                rightTransient: rightValues.transient,
                delaySeconds: delay
            )
        case .off:
            break
        }
    }
#endif
    
    static private let stickMaxOffset:CGFloat = 0x7FFE
    @objc static var navigationActionTriggered:Bool = false
    @objc static private(set) var navigationActionTriggeredPrivate:Bool = false
    
    @objc static func listen(
        controller: GCController,
        swapABXY: Bool,
        handler: @escaping (_ elementDict: NSDictionary,
                            _ gamepad: GCExtendedGamepad,
                            _ element: GCControllerElement) -> Void
    ) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // 内部生成 map
        var tempMap: [NSNumber: GCControllerElement] = [:]
        let swiftMap = buildMapping(for: controller, swapABXY: swapABXY)
        for (button, input) in swiftMap {
            tempMap[NSNumber(value: button.rawValue)] = input
        }
        let elementDict = tempMap as NSDictionary
        
        // 单一 gamepad.valueChangedHandler
                
        gamepad.valueChangedHandler = { gamepad, element in
            handler(elementDict, gamepad, element)
#if !os(tvOS)
            if #available(iOS 13.0, *) {
                // print("controller.playerIndex \(controller.playerIndex)")
                if controller.playerIndex == .index1 {
                    GamepadOverlayStateCenter.shared.publish(snapshot: GamepadOverlaySnapshot(gamepad: gamepad))
                }
            }
#endif
        }
    }
    
    // MARK: - 构建按钮映射
    static func buildMapping(for controller: GCController, swapABXY:Bool)
    -> [ControllerElement : GCControllerElement]
    {
        var result: [ControllerElement : GCControllerElement] = [:]
        ControllerUtil.swapABXY = swapABXY
        
        if let pad = controller.extendedGamepad {
            // Face buttons
            if swapABXY {
                result[.a] = pad.buttonB
                result[.b] = pad.buttonA
                result[.x] = pad.buttonY
                result[.y] = pad.buttonX
            }
            else{
                result[.a] = pad.buttonA
                result[.b] = pad.buttonB
                result[.x] = pad.buttonX
                result[.y] = pad.buttonY
            }
            
            // Shoulders & triggers
            result[.leftShoulder]  = pad.leftShoulder
            result[.rightShoulder] = pad.rightShoulder
            result[.leftTrigger]   = pad.leftTrigger
            result[.rightTrigger]  = pad.rightTrigger

            // Stick buttons
            if #available(iOS 12.1, *) {
                result[.leftStickButton]  = pad.leftThumbstickButton
                result[.rightStickButton] = pad.rightThumbstickButton
            }
            
            // DPad
            result[.dpadUp]    = pad.dpad.up
            result[.dpadDown]  = pad.dpad.down
            result[.dpadLeft]  = pad.dpad.left
            result[.dpadRight] = pad.dpad.right
            
            // Sticks
            result[.leftStick] = pad.leftThumbstick
            result[.leftStickX] = pad.leftThumbstick.xAxis
            result[.leftStickY] = pad.leftThumbstick.yAxis
            result[.rightStick] = pad.rightThumbstick
            result[.rightStickX] = pad.rightThumbstick.xAxis
            result[.rightStickY] = pad.rightThumbstick.yAxis
            

            // Menu / Options / Share
            if #available(iOS 13.0, *) {
                result[.start] = pad.buttonMenu
                if let options = pad.buttonOptions { result[.select] = options }
            }
            
            if #available(iOS 14.0, tvOS 14.0, *) {
                if let home = pad.buttonHome {
                    result[.special] = home
                }
                
                if let controller = pad.controller {
                    let profile = controller.physicalInputProfile
                    if let paddle1 = profile.buttons[GCInputXboxPaddleOne] {
                        result[.paddle1] = paddle1
                    }
                    if let paddle2 = profile.buttons[GCInputXboxPaddleTwo] {
                        result[.paddle2] = paddle2
                    }
                    if let paddle3 = profile.buttons[GCInputXboxPaddleThree] {
                        result[.paddle3] = paddle3
                    }
                    if let paddle4 = profile.buttons[GCInputXboxPaddleFour] {
                        result[.paddle4] = paddle4
                    }
                    if let touchpadBtn = profile.buttons[GCInputDualShockTouchpadButton] {
                        result[.touchpadButton] = touchpadBtn
                    }
                    if #available(iOS 15.0, tvOS 15.0, *) {
                        if let share = profile.buttons[GCInputButtonShare] {
                            result[.misc] = share
                        }
                    }
                }
            }
        }
        
        if controller === primaryGCController {ControllerUtil.primaryControllerElementMap = result}
        
        return result
    }
    
    @objc static var activeStreamingGCControllers:NSMutableSet = NSMutableSet()
    
    @objc static var swapABXY:Bool = false
    
    @objc static var gamepadArrivalReported: Bool = false
    
    @objc static func string(for element: ControllerElement) -> String {
        return element.displayName
    }
    
    @objc static func position(for element: ControllerElement) -> ControllerElementPosition {
        return element.position
    }


    // MARK: - primary controller section
    
    private static var connectObserver: NSObjectProtocol?
    private static var disconnectObserver: NSObjectProtocol?
    
    @objc static weak var primaryGCController: GCController?
    static var primaryControllerElementMap: [ControllerElement : GCControllerElement]?
    private static var primaryControllerAxisStates: [ControllerElement : ComparisonResult] = [:]

    @objc static func installControllerObserversIfNeeded() {
        guard connectObserver == nil, disconnectObserver == nil else { return }
        
        if GCController.controllers().first(where: { $0.extendedGamepad != nil }) != nil {
            preparePrimaryController()
        }
        
        connectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect,
            object: nil,
            queue: .main
        ) { notification in
            guard (notification.object as? GCController)?.extendedGamepad != nil else { return }
            preparePrimaryController()
        }

        disconnectObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidDisconnect,
            object: nil,
            queue: .main
        ) { notification in
            preparePrimaryController()
        }
    }

    @objc static func removeControllerObservers() {
        if let connectObserver {
            NotificationCenter.default.removeObserver(connectObserver)
            self.connectObserver = nil
        }

        if let disconnectObserver {
            NotificationCenter.default.removeObserver(disconnectObserver)
            self.disconnectObserver = nil
        }
    }
    
    @objc static func disableSysGestures(_ controller: GCController?){
        if let controller = controller {
            if #available(iOS 14.0, *) {
                for element in controller.physicalInputProfile.allElements {
                    element.preferredSystemGestureState = .disabled
                }
            }
        }
    }

    private static func preparePrimaryController() {
        guard let controller = GCController.controllers().first(where: { $0.extendedGamepad != nil }) else {
            stopListeningPrimaryController()
            ControllerUtil.primaryGCController = nil
            if #available(iOS 13.0, *) {
                ControllerNavigator.stop()
            }
            return
        }
        
        if PublicUtils.isTVOS {
            guard GCController.controllers().count == 1
                    || GCController.controllers().count == 2 else { return }
        }
        else {
            guard GCController.controllers().count == 1 else { return }
        }
        
        if let mainFrameVC = delegate as? MainFrameViewController {
            let vc = mainFrameVC.isStreaming() ? StreamFrameViewController.sharedInstance() : mainFrameVC
            GenericUtils.handleFirstGamepadConnection(in: vc, with: controller) {
                setGCControllerToPrimary(controller)
                return
            }
        }
        
        setGCControllerToPrimary(controller)
    }
    
    static func setGCControllerToPrimary(_ controller: GCController) {
        primaryGCController = controller
        _ = buildMapping(for: controller, swapABXY: false)
        disableSysGestures(controller)
        
        if #available(iOS 13.0, *) {
            if ControllerNavigator.enabled {
                ControllerNavigator.start()
                GamepadNavigationIllustrationHud.updateNavigationElements(ControllerNavigator.uiNavigationDelegate?.getNavigationElements() ?? [])
                ControllerNavigator.restoreUINavigationHighlight()
            }
        }
    }

    @objc static func stopListeningPrimaryController(stopListenToRadialMenuButton: Bool = false) {
        guard let primaryControllerButtonMap = primaryControllerElementMap else { return }
        for gcElement in primaryControllerButtonMap.values {
            if let gcButton = gcElement as? GCControllerButtonInput {
                if #available(iOS 13.0, *) {
                    if !stopListenToRadialMenuButton, gcButton === primaryControllerButtonMap[ControllerNavigator.radialMenuButton] as? GCControllerButtonInput {continue}
                }
                gcButton.pressedChangedHandler = nil
            }
            if let gcStick = gcElement as? GCControllerDirectionPad {
                gcStick.valueChangedHandler = nil
            }
            if let gcAxis = gcElement as? GCControllerAxisInput {
                gcAxis.valueChangedHandler = nil
            }
        }
        primaryControllerAxisStates.removeAll()
        primaryGCController?.extendedGamepad?.valueChangedHandler = nil
    }
    
    @objc static func listenPrimaryControllerButton(_ button: ControllerElement, ignoreSwapABXY: Bool = true, handler: @escaping (_ pressed: Bool) -> Void){
        if var elementMap = ControllerUtil.primaryControllerElementMap {
            if ignoreSwapABXY {
                elementMap[.a] = ControllerUtil.primaryGCController?.extendedGamepad?.buttonA
                elementMap[.b] = ControllerUtil.primaryGCController?.extendedGamepad?.buttonB
                elementMap[.x] = ControllerUtil.primaryGCController?.extendedGamepad?.buttonX
                elementMap[.y] = ControllerUtil.primaryGCController?.extendedGamepad?.buttonY
            }
            if let gcButton = elementMap[button] as? GCControllerButtonInput {
                gcButton.pressedChangedHandler = { _, _, pressed in
                    handler(pressed)
                }
            }
        }
    }
    
    @objc static func listenPrimaryControllerStick(_ stick: ControllerElement, handler: @escaping (_ offsetVector: CGVector) -> Void){
        if let elementMap = ControllerUtil.primaryControllerElementMap {
            if let gcStick = elementMap[stick] as? GCControllerDirectionPad {
                gcStick.valueChangedHandler = { _, xValue, yValue in
                    handler(CGVector(dx: CGFloat(xValue), dy: CGFloat(yValue)))
                }
            }
        }
    }

    @objc static func listenPrimaryControllerStickAxis(_ stickAxis: ControllerElement, threshold: CGFloat, handler: @escaping (_ state: ComparisonResult) -> Void) {
        guard threshold > 0 else { return }
        guard let elementMap = ControllerUtil.primaryControllerElementMap,
              let gcAxis = elementMap[stickAxis] as? GCControllerAxisInput else { return }

        primaryControllerAxisStates[stickAxis] = stickAxisState(for: CGFloat(gcAxis.value), threshold: threshold)
        gcAxis.valueChangedHandler = { _, value in
            let newState = stickAxisState(for: CGFloat(value), threshold: threshold)
            let previousState = primaryControllerAxisStates[stickAxis] ?? .orderedSame
            guard newState != previousState else { return }

            primaryControllerAxisStates[stickAxis] = newState
            handler(newState)
        }
    }

    private static func stickAxisState(for value: CGFloat, threshold: CGFloat) -> ComparisonResult {
        if value > threshold {
            return .orderedDescending
        }

        if value < -threshold {
            return .orderedAscending
        }

        return .orderedSame
    }

    
    

    // MARK: - adaptive triggers

    // Adaptive trigger fixes
    // Pull request originally submitted by sirius128@github to VoidLink on 2026/9/14
    // Copyright © 2026 sirius128@github
    // Licensed under GPL-3.0

    private enum AdaptiveTriggerMode {
        case unsupported, off, feedback, positionalFeedback, weapon, slopeFeedback, vibration, positionalVibration
    }

    private struct AdaptiveTriggerEffect {
        var mode: AdaptiveTriggerMode = .unsupported
        var startPosition: Float = 0
        var endPosition: Float = 0
        var startStrength: Float = 0
        var endStrength: Float = 0
        var frequency: Float = 0
        var positionalStrength = Array(repeating: Float(0), count: 10)
    }

    private static func clamp01(_ value: Float) -> Float { max(0, min(1, value)) }
    private static func stepPosition(_ step: Int, count: Int) -> Float {
        clamp01(Float(step) / Float(count - 1))
    }
    private static func byteScale(_ value: UInt8) -> Float { stepPosition(Int(value), count: 256) }
    private static func zonePosition(_ zone: Int) -> Float { stepPosition(zone, count: 10) }

    private static func zoneMask(_ bytes: [UInt8]) -> UInt16 {
        (UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)) & 0x03ff
    }
    private static func firstZone(_ mask: UInt16) -> Int? {
        mask == 0 ? nil : mask.trailingZeroBitCount
    }
    private static func lastZone(_ mask: UInt16) -> Int? {
        mask == 0 ? nil : 15 - mask.leadingZeroBitCount
    }
    private static func setSpan(_ effect: inout AdaptiveTriggerEffect, first: Int?, last: Int?, count: Int) {
        let start = max(0, min(first ?? 0, count - 2))
        let end = max(start + 1, min(last ?? (start + 1), count - 1))
        effect.startPosition = stepPosition(start, count: count)
        effect.endPosition = stepPosition(end, count: count)
    }

    private static func decodeZoned(_ bytes: [UInt8], mode: AdaptiveTriggerMode) -> AdaptiveTriggerEffect {
        var effect = AdaptiveTriggerEffect(mode: mode)
        let mask = zoneMask(bytes)
        let packed = UInt32(bytes[2]) | (UInt32(bytes[3]) << 8) |
            (UInt32(bytes[4]) << 16) | (UInt32(bytes[5]) << 24)
        for zone in 0..<10 where mask & (1 << zone) != 0 {
            let strength = clamp01(Float(((packed >> (3 * zone)) & 7) + 1) / 8)
            effect.positionalStrength[zone] = strength
            effect.startStrength = max(effect.startStrength, strength)
        }
        effect.startPosition = zonePosition(firstZone(mask) ?? 0)
        return effect
    }

    private static func decode(type: UInt8, bytes: [UInt8]) -> AdaptiveTriggerEffect {
        var effect = AdaptiveTriggerEffect()
        switch type {
        case 0x00, 0x05:
            effect.mode = .off
        case 0x01, 0x11:
            effect.mode = .feedback
            effect.startPosition = byteScale(bytes[0])
            effect.startStrength = type == 0x01 ? byteScale(bytes[1]) : clamp01(Float(bytes[1]) / 10)
        case 0x02, 0x12:
            effect.mode = .weapon
            setSpan(&effect, first: Int(bytes[0]), last: Int(bytes[1]), count: 256)
            effect.startStrength = type == 0x02 ? byteScale(bytes[2]) : clamp01(Float(bytes[2]) / 10)
        case 0x06:
            effect.mode = .vibration
            effect.frequency = clamp01(Float(bytes[0]) / 255)
            effect.startStrength = byteScale(bytes[1])
            effect.startPosition = byteScale(bytes[2])
        case 0x21:
            effect = decodeZoned(bytes, mode: .positionalFeedback)
        case 0x26:
            effect = decodeZoned(bytes, mode: .positionalVibration)
            effect.frequency = clamp01(Float(bytes[8]) / 255)
        case 0x25:
            effect.mode = .weapon
            setSpan(&effect, first: firstZone(zoneMask(bytes)), last: lastZone(zoneMask(bytes)), count: 10)
            effect.startStrength = Float((bytes[2] & 7) + 1) / 8
        case 0x22:
            effect.mode = .slopeFeedback
            setSpan(&effect, first: firstZone(zoneMask(bytes)), last: lastZone(zoneMask(bytes)), count: 10)
            effect.startStrength = Float((bytes[2] & 7) + 1) / 8
            effect.endStrength = Float(((bytes[2] >> 3) & 7) + 1) / 8
        case 0x23, 0x27:
            effect.mode = .vibration
            effect.startPosition = zonePosition(firstZone(zoneMask(bytes)) ?? 0)
            effect.startStrength = type == 0x23 ? 0.5 :
                clamp01(Float(max(bytes[2] & 7, (bytes[2] >> 3) & 7)) / 7)
            effect.frequency = clamp01(Float(bytes[3]) / 255)
        default:
            effect.mode = .off
        }

        switch effect.mode {
        case .vibration, .positionalVibration:
            if effect.frequency <= 0 || max(effect.startStrength, effect.endStrength) <= 0 { effect.mode = .off }
        case .feedback, .positionalFeedback, .weapon, .slopeFeedback:
            if max(effect.startStrength, effect.endStrength) <= 0 { effect.mode = .off }
        default:
            break
        }
        return effect
    }

    @available(iOS 14.5, tvOS 14.5, *)
    @objc static func applyAdaptiveTrigger(_ trigger: GCDualSenseAdaptiveTrigger, type: UInt8, payload: Data) {
        let bytes = Array(payload)
        guard bytes.count >= 10 else { trigger.setModeOff(); return }

        var effect = decode(type: type, bytes: bytes)
        if #available(iOS 15.4, tvOS 15.4, *) {
        } else {
            switch effect.mode {
            case .positionalFeedback: effect.mode = .feedback
            case .positionalVibration: effect.mode = .vibration
            case .slopeFeedback:
                effect.startStrength = max(effect.startStrength, effect.endStrength)
                effect.mode = .weapon
            default: break
            }
        }

        switch effect.mode {
        case .off, .unsupported:
            trigger.setModeOff()
        case .feedback:
            trigger.setModeFeedbackWithStartPosition(effect.startPosition, resistiveStrength: effect.startStrength)
        case .weapon:
            trigger.setModeWeaponWithStartPosition(effect.startPosition, endPosition: effect.endPosition,
                                                   resistiveStrength: effect.startStrength)
        case .vibration:
            trigger.setModeVibrationWithStartPosition(effect.startPosition, amplitude: effect.startStrength,
                                                      frequency: effect.frequency)
        case .positionalFeedback:
            if #available(iOS 15.4, tvOS 15.4, *) {
                let values = GCDualSenseAdaptiveTrigger.PositionalResistiveStrengths(values: (
                    effect.positionalStrength[0], effect.positionalStrength[1], effect.positionalStrength[2],
                    effect.positionalStrength[3], effect.positionalStrength[4], effect.positionalStrength[5],
                    effect.positionalStrength[6], effect.positionalStrength[7], effect.positionalStrength[8],
                    effect.positionalStrength[9]
                ))
                trigger.setModeFeedback(resistiveStrengths: values)
            }
        case .positionalVibration:
            if #available(iOS 15.4, tvOS 15.4, *) {
                let values = GCDualSenseAdaptiveTrigger.PositionalAmplitudes(values: (
                    effect.positionalStrength[0], effect.positionalStrength[1], effect.positionalStrength[2],
                    effect.positionalStrength[3], effect.positionalStrength[4], effect.positionalStrength[5],
                    effect.positionalStrength[6], effect.positionalStrength[7], effect.positionalStrength[8],
                    effect.positionalStrength[9]
                ))
                trigger.setModeVibration(amplitudes: values, frequency: effect.frequency)
            }
        case .slopeFeedback:
            if #available(iOS 15.4, tvOS 15.4, *) {
                trigger.setModeSlopeFeedback(startPosition: effect.startPosition, endPosition: effect.endPosition,
                                             startStrength: effect.startStrength, endStrength: effect.endStrength)
            }
        }
    }

    // MARK: - input processing

    @objc static func compensated(offsetVector: CGVector, minOffset: CGFloat, circulate:Bool=false) -> CGVector{
        let vectorHypot = hypot(offsetVector.dx, offsetVector.dy)
        guard vectorHypot > 0 else {return CGVector(dx: 0, dy: 0)}
        let targetHypot = minOffset + (stickMaxOffset-minOffset)*(vectorHypot/stickMaxOffset)
        var compensatedX = targetHypot * (offsetVector.dx/vectorHypot)
        var compensatedY = targetHypot * (offsetVector.dy/vectorHypot)
        
        if circulate {
            return circulated(offsetVector: CGVector(dx: compensatedX, dy: compensatedY))
        }
        else {
            compensatedX = max(min(compensatedX, stickMaxOffset),-stickMaxOffset)
            compensatedY = max(min(compensatedY, stickMaxOffset),-stickMaxOffset)
            return CGVector(dx: compensatedX, dy: compensatedY)
        }
    }
    
    @objc static func circulated(offsetVector: CGVector) -> CGVector{
        let vectorHypot = hypot(offsetVector.dx, offsetVector.dy)
        guard vectorHypot > 0 else {return CGVector(dx: 0, dy: 0)}
        let targetHypot = min(vectorHypot, stickMaxOffset)
        let circulatedX = targetHypot*(offsetVector.dx/vectorHypot)
        let circulatedY = targetHypot*(offsetVector.dy/vectorHypot)
        return CGVector(dx: circulatedX, dy: circulatedY)
    }
}

#if os(iOS) && !VOIDLINK_PREVIEW
@available(iOS 14.0, *)
private final class DualSenseHapticsEQStore: ObservableObject {
    let originalValues: [Double]
    @Published private(set) var values: [Double]

    init(values: [Float]) {
        let doubles = values.map(Double.init)
        originalValues = doubles
        self.values = doubles
    }

    func binding(for index: Int) -> Binding<Double> {
        Binding(
            get: { self.values[index] },
            set: { self.updateValue($0, at: index) }
        )
    }

    func reset() {
        values = ControllerUtil.defaultDualSenseHapticsEQSnapshot().map(Double.init)
        preview()
    }

    func save() {
        ControllerUtil.saveDualSenseHapticsEQ(values.map(Float.init))
    }

    func cancel() {
        ControllerUtil.previewDualSenseHapticsEQ(originalValues.map(Float.init))
    }

    private func updateValue(_ value: Double, at index: Int) {
        values[index] = value
        preview()
    }

    private func preview() {
        ControllerUtil.previewDualSenseHapticsEQ(values.map(Float.init))
    }
}

@available(iOS 14.0, *)
private struct DualSenseHapticsEQView: View {
    private struct Parameter: Identifiable {
        let id: Int
        let title: String
        let range: ClosedRange<Double>
        let step: Double
        let usesMultiplier: Bool
    }

    @ObservedObject var store: DualSenseHapticsEQStore
    let onClose: () -> Void

    private let parameters = [
        Parameter(id: 0, title: "Master Gain", range: 0...1, step: 0.01, usesMultiplier: false),
        Parameter(id: 1, title: "Low Band (<200 Hz)", range: 0...2, step: 0.01, usesMultiplier: true),
        Parameter(id: 2, title: "High Band (>200 Hz)", range: 0...2, step: 0.01, usesMultiplier: true),
        Parameter(id: 3, title: "Transient Gain", range: 0...1, step: 0.01, usesMultiplier: false),
        Parameter(id: 4, title: "Sharpness", range: 0...2, step: 0.01, usesMultiplier: true),
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.28)
                    .edgesIgnoringSafeArea(.all)
                    .contentShape(Rectangle())
                    .onTapGesture { cancelAndClose() }

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        Text("DualSense Haptic EQ")
                            .font(.system(size: 19, weight: .bold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.76))

                        Spacer()

                        Button(action: store.reset) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color.black.opacity(0.62))
                                .frame(width: 34, height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.white.opacity(0.9))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibility(label: Text("Reset EQ"))
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(parameters) { parameter in
                                parameterRow(parameter)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        actionButton(title: "Cancel", isPrimary: false) {
                            cancelAndClose()
                        }
                        actionButton(title: "Save", isPrimary: true) {
                            store.save()
                            onClose()
                        }
                    }
                }
                .padding(UIDevice.current.userInterfaceIdiom == .phone ? 12 : 18)
                .frame(maxWidth: UIDevice.current.userInterfaceIdiom == .phone ? 380 : 460)
                .frame(maxHeight: max(280, geometry.size.height - 28))
                .background(
                    RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .phone ? 22 : 28, style: .continuous)
                        .fill(Color(red: 0.94, green: 0.97, blue: 0.98).opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: UIDevice.current.userInterfaceIdiom == .phone ? 22 : 28, style: .continuous)
                                .stroke(Color.white.opacity(0.96), lineWidth: 1.1)
                        )
                )
                .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
                .padding(.horizontal, 14)
            }
        }
    }

    private func parameterRow(_ parameter: Parameter) -> some View {
        HStack(spacing: 10) {
            Text(parameter.title)
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.64))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 132, alignment: .leading)

            Slider(
                value: store.binding(for: parameter.id),
                in: parameter.range,
                step: parameter.step
            )
            .accentColor(Color(red: 0.18, green: 0.61, blue: 0.67))
            .environment(\.colorScheme, .light)

            Text(formattedValue(store.values[parameter.id], multiplier: parameter.usesMultiplier))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(Color(red: 0.14, green: 0.46, blue: 0.52))
                .frame(width: 48, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.94), lineWidth: 1)
        )
    }

    private func actionButton(title: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(isPrimary ? .white : Color.black.opacity(0.66))
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(isPrimary
                            ? Color(red: 0.16, green: 0.53, blue: 0.59)
                            : Color.white.opacity(0.82))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(isPrimary ? 0.22 : 0.76), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedValue(_ value: Double, multiplier: Bool) -> String {
        String(format: multiplier ? "x%.2f" : "%.2f", value)
    }

    private func cancelAndClose() {
        store.cancel()
        onClose()
    }
}
#endif

#if !os(tvOS)
// MARK: - realtime overlay

@available(iOS 13.0, *)
struct GamepadOverlaySnapshot: Equatable {
    var pressedButtons: Set<ControllerElement> = []
    var dpadHighlight: Int = 0
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero
    var leftTrigger: CGFloat = 0
    var rightTrigger: CGFloat = 0

    static let idle = GamepadOverlaySnapshot()

    init() {}

    init(gamepad: GCExtendedGamepad) {
        var pressedButtons = Set<ControllerElement>()

        if gamepad.buttonA.isPressed { pressedButtons.insert(.a) }
        if gamepad.buttonB.isPressed { pressedButtons.insert(.b) }
        if gamepad.buttonX.isPressed { pressedButtons.insert(.x) }
        if gamepad.buttonY.isPressed { pressedButtons.insert(.y) }
        if gamepad.leftShoulder.isPressed { pressedButtons.insert(.leftShoulder) }
        if gamepad.rightShoulder.isPressed { pressedButtons.insert(.rightShoulder) }
        if gamepad.buttonMenu.isPressed { pressedButtons.insert(.start) }
        if gamepad.buttonOptions?.isPressed == true { pressedButtons.insert(.select) }
        if #available(iOS 14.0, *), gamepad.buttonHome?.isPressed == true { pressedButtons.insert(.special) }
        if gamepad.leftThumbstickButton?.isPressed == true { pressedButtons.insert(.leftStickButton) }
        if gamepad.rightThumbstickButton?.isPressed == true { pressedButtons.insert(.rightStickButton) }

        var dpadHighlight = 0
        if gamepad.dpad.up.isPressed { dpadHighlight |= DPadHighlight.up.rawValue }
        if gamepad.dpad.down.isPressed { dpadHighlight |= DPadHighlight.down.rawValue }
        if gamepad.dpad.left.isPressed { dpadHighlight |= DPadHighlight.left.rawValue }
        if gamepad.dpad.right.isPressed { dpadHighlight |= DPadHighlight.right.rawValue }

        self.pressedButtons = pressedButtons
        self.dpadHighlight = dpadHighlight
        self.leftStick = CGPoint(
            x: CGFloat(max(-1, min(1, gamepad.leftThumbstick.xAxis.value))),
            y: CGFloat(max(-1, min(1, gamepad.leftThumbstick.yAxis.value)))
        )
        self.rightStick = CGPoint(
            x: CGFloat(max(-1, min(1, gamepad.rightThumbstick.xAxis.value))),
            y: CGFloat(max(-1, min(1, gamepad.rightThumbstick.yAxis.value)))
        )
        self.leftTrigger = CGFloat(max(0, min(1, gamepad.leftTrigger.value)))
        self.rightTrigger = CGFloat(max(0, min(1, gamepad.rightTrigger.value)))
    }
}

@available(iOS 13.0, *)
@objc(GamepadOverlayStateCenter)
final class GamepadOverlayStateCenter: NSObject, ObservableObject {
    static let shared = GamepadOverlayStateCenter()

    @Published private(set) var snapshot: GamepadOverlaySnapshot = .idle

    func publish(snapshot: GamepadOverlaySnapshot) {
        DispatchQueue.main.async {
            self.snapshot = snapshot
        }
    }

    @objc static func clearSharedState() {
        shared.publish(snapshot: .idle)
    }
}
#endif
