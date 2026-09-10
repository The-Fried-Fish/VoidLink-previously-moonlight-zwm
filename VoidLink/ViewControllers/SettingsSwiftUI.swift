//
//  SettingsSwiftUI.swift
//  VoidLink
//
//  Created by True砖家 on 2026/9/5.
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import Combine
import CoreMotion
import GameController
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VideoToolbox

private var settingsSwiftUIStoreAssociationKey: UInt8 = 0
private var settingsSwiftUIHostAssociationKey: UInt8 = 0
private let settingsSectionFoldIdentifiers = SettingsSectionID.allCases.map(\.rawValue)
private let settingsNavigationSelectionKey = "SettingsControllerNavigationHighlightedIdentifier"
private let settingsFavoriteIdentifiersKey = "FavoriteSettingStackIdentifiers"
private let settingsSectionFoldAnimationDuration = 0.2
private let settingsEmergingHighlightPhaseDuration = 0.2
private let settingsBitrateTable: [Double] = [
    500, 1_000, 1_500, 2_000, 2_500, 3_000, 4_000, 5_000, 6_000, 7_000,
    8_000, 9_000, 10_000, 11_000, 12_000, 13_000, 14_000, 15_000, 16_000, 17_000,
    18_000, 19_000, 20_000, 21_000, 22_000, 23_000, 24_000, 25_000, 26_000, 27_000,
    28_000, 29_000, 30_000, 31_000, 32_000, 33_000, 34_000, 35_000, 36_000, 37_000,
    38_000, 39_000, 40_000, 41_000, 42_000, 43_000, 44_000, 45_000, 46_000, 47_000,
    48_000, 49_000, 50_000, 51_000, 52_000, 53_000, 54_000, 55_000, 56_000, 57_000,
    58_000, 59_000, 60_000, 61_000, 62_000, 63_000, 64_000, 65_000, 66_000, 67_000,
    68_000, 69_000, 70_000, 80_000, 90_000, 100_000, 110_000, 120_000, 130_000, 140_000,
    150_000, 160_000, 170_000, 180_000, 200_000, 220_000, 240_000, 260_000, 280_000, 300_000,
    320_000, 340_000, 360_000, 380_000, 400_000, 420_000, 440_000, 460_000, 480_000, 500_000,
    520_000, 540_000, 560_000, 580_000, 600_000, 620_000, 640_000, 660_000, 680_000, 700_000,
    720_000, 740_000, 760_000, 780_000, 800_000
]

private func settingsBitrateIndex(for bitrate: Double) -> Int {
    settingsBitrateTable.firstIndex(where: { bitrate <= $0 }) ?? (settingsBitrateTable.count - 1)
}

@MainActor
private var settingsTitleWidthCache: [String: CGFloat] = [:]

@MainActor
private func settingsTitleWidth(_ title: String) -> CGFloat {
    if let cached = settingsTitleWidthCache[title] { return cached }
    let width = (title as NSString).size(
        withAttributes: [.font: UIFont.systemFont(ofSize: 17)]
    ).width
    settingsTitleWidthCache[title] = width
    return width
}

/// Mirrors SettingsViewController's velocity-factor slider mapping. The item
/// model stores the UI slider position while Settings/OSCProfile store the
/// resulting business multiplier.
///

private var usesSwiftUIScroll: Bool = {
    return PublicUtils.iOS18Available && PublicUtils.isIPhone
}()

private let enablesSectionHitTestCulling = true
private let settingsSectionHitTestScrollTickInterval = PublicUtils.refreshRate >= 110 ? 36 : 22
private let settingsSectionHitTestViewportPadding: CGFloat = 80
private let settingsContinuousInteractionScrollSuppressionDuration: TimeInterval = 0.75

private let settingsNavigationGeometryRestoreDelay: TimeInterval = 0.2
private let settingsInitialSectionHitTestWarmUpDelay: TimeInterval = settingsNavigationGeometryRestoreDelay + 0.02

private func settingsVelocitySliderPosition(for factor: CGFloat) -> Double {
    let value = Double(factor)
    return value < 2 ? value * 100 : (value - 2) * 100 / 5 + 200
}

private func settingsVelocityDisplayPercent(for sliderPosition: Double) -> Double {
    guard sliderPosition > 200 else { return sliderPosition }
    return 200 + Double(Int(sliderPosition) % 200) * 5
}

private func settingsVelocityFactor(for sliderPosition: Double) -> CGFloat {
    CGFloat(settingsVelocityDisplayPercent(for: sliderPosition) / 100)
}

private enum SettingsRenderingBackend: Int {
    case standard = 0
    case metal = 1
}

@available(iOS 13.0, *)
private var settingsSectionFoldAnimation: Animation {
    .timingCurve(
        0.32, 0,
        0.2, 1,
        duration: settingsSectionFoldAnimationDuration
    )
}

private struct SettingsLegacyHelpContent {
    let messageKey: String
    let learnMoreURLKey: String?
}

@available(iOS 14.0, *)
private struct SettingsInfoButtonControl: UIViewRepresentable {
    let isGameProfileSetting: Bool
    let action: () -> Void

    final class Coordinator: NSObject {
        var action: () -> Void
        var isGameProfileSetting: Bool?
        var tintColor: UIColor?

        init(action: @escaping () -> Void) {
            self.action = action
        }

        @objc func tapped() {
            action()
        }
    }

    private var configuredImage: UIImage? {
        if isGameProfileSetting {
            if #available(iOS 18.0, *) {
                return UIImage(
                    systemName: "gamecontroller.circle",
                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.5, weight: .medium)
                )
            }
            return UIImage(named: "gamecontroller.circle.17")?.withRenderingMode(.alwaysTemplate)
        }
        if #available(iOS 18.0, *) {
            return UIImage(
                systemName: "info.circle",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.4, weight: .medium)
            )
        }
        return UIImage(
            systemName: "info.circle",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 16.5, weight: .regular)
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .custom)
        button.adjustsImageWhenHighlighted = false
        button.tintColor = ThemeManager.appPrimaryColor
        button.addTarget(context.coordinator, action: #selector(Coordinator.tapped), for: .touchUpInside)
        button.accessibilityIdentifier = "infoButton"
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        context.coordinator.action = action
        let tintColor = ThemeManager.appPrimaryColor
        if context.coordinator.tintColor != tintColor {
            button.tintColor = tintColor
            context.coordinator.tintColor = tintColor
        }
        if context.coordinator.isGameProfileSetting != isGameProfileSetting {
            button.setImage(configuredImage, for: .normal)
            context.coordinator.isGameProfileSetting = isGameProfileSetting
        }
        if !button.isUserInteractionEnabled {
            button.isUserInteractionEnabled = true
        }
    }
}

/// The persistence domain of a settings stack.  UIKit exposed this as
/// `UIStackView.isGameProfileSetting`; keeping it in the row descriptor makes
/// the visual/help/navigation behavior a property of the template rather than
/// a per-section special case.
enum SettingsPersistenceScope {
    case xcdata
    case gameProfile
}

/// Data equivalent of the static branches in
/// -[SettingsViewController infoButtonTapped:]. Game Profile augmentation is
/// applied by the shared row descriptor, after this ordinary help lookup.
private let settingsLegacyHelpByStackIdentifier: [String: SettingsLegacyHelpContent] = [
    // Video
    "bitrateStack": .init(messageKey: "bitrateStackTip", learnMoreURLKey: nil),
    "hdrStack": .init(messageKey: "hdrStackTip", learnMoreURLKey: nil),
    "yuv444Stack": .init(messageKey: "yuv444StackTip", learnMoreURLKey: nil),
    "framePacingStack": .init(messageKey: "framePacingStackTip", learnMoreURLKey: nil),
    "interpolationLevelStack": .init(messageKey: "frameInterpolationResolutionTip", learnMoreURLKey: nil),
    "streamDimensionScaleStack": .init(messageKey: "streamDimensionScaleStackTip", learnMoreURLKey: nil),
    "asyncFrameDequeueStack": .init(messageKey: "asyncFrameDequeueStackTip", learnMoreURLKey: nil),
    "pipStack": .init(messageKey: "pipStackTip", learnMoreURLKey: nil),

    // Touch Control
    "touchModeStack": .init(messageKey: "touchModeStackTip", learnMoreURLKey: nil),
    "pointerVelocityDividerStack": .init(messageKey: "pointerVelocityDividerStackTip", learnMoreURLKey: "pointerVelocityDividerStackDoc"),
    "pointerVelocityFactorStack": .init(messageKey: "pointerVelocityFactorStackTip", learnMoreURLKey: "pointerVelocityFactorStackDoc"),
    "delayLeftClickStack": .init(messageKey: "delayLeftClickStackTip", learnMoreURLKey: nil),
    "relativeTouchSlideThresholdStack": .init(messageKey: "relativeTouchSlideThresholdStackTip", learnMoreURLKey: "relativeTouchSlideThresholdStackLink"),
    "ctrlDownForPinchStack": .init(messageKey: "ctrlDownForPinchStackTip", learnMoreURLKey: nil),
    "onScreenWidgetStack": .init(messageKey: "onScreenWidgetStackTip", learnMoreURLKey: "onScreenWidgetStackDoc"),

    // Controller
    "controllerNavigationStack": .init(messageKey: "controllerNavigationStackTip", learnMoreURLKey: nil),
    "controllerMouseExpoStack": .init(messageKey: "controllerMouseExpoStackTip", learnMoreURLKey: nil),
    "emulatedControllerTypeStack": .init(messageKey: "emulatedControllerTypeStackTip", learnMoreURLKey: "emulatedControllerTypeStackDoc"),

    // Motion Control
    "gyroModeStack": .init(messageKey: "gyroModeStackTip", learnMoreURLKey: "yourMotionControlSoution"),
    "leftStickMinOffsetStack": .init(messageKey: "physicaStickMinOffsetTip", learnMoreURLKey: nil),
    "rightStickMinOffsetStack": .init(messageKey: "physicaStickMinOffsetTip", learnMoreURLKey: nil),
    "reverseHoldButtonStack": .init(messageKey: "reverseHoldButtonStackTip", learnMoreURLKey: nil),
    "swapYawAndRollStack": .init(messageKey: "swapYawAndRollStackTip", learnMoreURLKey: nil),
    "mapGyroToStack": .init(messageKey: "mapGyroToStackTip", learnMoreURLKey: "yourMotionControlSoution"),

    // Drawing Toolkit
    "pencilTickStack": .init(messageKey: "pencilTickStackTip", learnMoreURLKey: "PencilProPackURL"),
    "pencilModeStack": .init(messageKey: "pencilModeStackTip", learnMoreURLKey: nil),

    // Gestures
    "softKeyboardGestureStack": .init(messageKey: "softKeyboardGestureStackTip", learnMoreURLKey: "softKeyboardGestureStackDoc"),
    "slideToSettingsDistanceStack": .init(messageKey: "slideToSettingsDistanceStackTip", learnMoreURLKey: nil),
    "edgeSlidingSensitivityStack": .init(messageKey: "edgeSlidingSensitivityStackTip", learnMoreURLKey: nil),

    // Peripherals
    "localMousePointerModeStack": .init(messageKey: "localMousePointerModeStackTip", learnMoreURLKey: "localMousePointerModeStackDoc"),
    "externalDisplayModeStack": .init(messageKey: "externalDisplayModeStackTip", learnMoreURLKey: "externalDisplayModeStackDoc"),
    "globeAsEscapeStack": .init(messageKey: "globeAsEscapeStackTip", learnMoreURLKey: nil),

    // Audio
    "redirectMicStack": .init(messageKey: "redirectMicStackTip", learnMoreURLKey: nil),
    "useBuiltinMicStack": .init(messageKey: "useBuiltinMicStackTip", learnMoreURLKey: nil),
    "audioConfigStack": .init(messageKey: "audioConfigStackTip", learnMoreURLKey: nil),

    // Others
    "unlockDisplayOrientationStack": .init(messageKey: "unlockDisplayOrientationStackTip", learnMoreURLKey: nil),
    "optimizeGamesStack": .init(messageKey: "optimizeGamesStackTip", learnMoreURLKey: nil),
    "softKeyboardHeightStack": .init(messageKey: "softKeyboardHeightStackTip", learnMoreURLKey: nil),

    // Experimental
    "renderingBackendStack": .init(messageKey: "renderingBackendStackTip", learnMoreURLKey: nil),
    "performanceGraphStack": .init(messageKey: "performanceGraphStackTip", learnMoreURLKey: nil),
    "sdrPerformanceWorkaroundStack": .init(messageKey: "sdrPerformanceWorkaroundStackTip", learnMoreURLKey: nil),
    "sendDummyEventStack": .init(messageKey: "sendDummyEventStackTip", learnMoreURLKey: nil)
]

// MARK: - Settings identity

/// Stable identity shared by every settings section. The raw value is the
/// existing storyboard/accessibility identifier, so persisted Favorites and
/// Controller Navigation selections remain compatible with UIKit.
enum SettingsItemID: String, Hashable, Identifiable {
    // MARK: Video

    case resolution = "resolutionSelectorStack"
    case customResolution = "customResolutionStack"
    case frameRate = "fpsStack"
    case bitrate = "bitrateStack"
    case codec = "codecStack"
    case hdr = "hdrStack"
    case yuv444 = "yuv444Stack"
    case framePacing = "framePacingStack"
    case interpolationLevel = "interpolationLevelStack"
    case streamDimensionScale = "streamDimensionScaleStack"
    case frameQueueSize = "frameQueueSizeStack"
    case asyncFrameDequeue = "asyncFrameDequeueStack"
    case pictureInPicture = "pipStack"

    // MARK: Touch Control

    case touchMode = "touchModeStack"
    case mousePointerVelocity = "mousePointerVelocityStack"
    case pointerVelocityDivider = "pointerVelocityDividerStack"
    case pointerVelocityFactor = "pointerVelocityFactorStack"
    case delayLeftClick = "delayLeftClickStack"
    case passthroughGestures = "passthroughGesturesStack"
    case pinchGesture = "pinchGestureStack"
    case ctrlDownForPinch = "ctrlDownForPinchStack"
    case scrollSensitivity = "scrollSensitivityStack"
    case pinchSensitivity = "pinchSensitivityStack"
    case onScreenWidget = "onScreenWidgetStack"
    case buttonVisualFeedback = "buttonVisualFeedbackStack"
    case trackTouchPoint = "trackTouchPointStack"

    // MARK: Controller

    case controllerNavigation = "controllerNavigationStack"
    case streamingRadialMenuDelay = "streamingRadialMenuDelayStack"
    case controllerMouseVelocity = "controllerMouseVelocityStack"
    case controllerMouseExpo = "controllerMouseExpoStack"
    case swapABXY = "swapAbaxyStack"
    case hapticEngine = "hapticEngineStack"
    case emulatedControllerType = "emulatedControllerTypeStack"
    case dualSenseTransient = "dualSenseTransientStack"
    case gyroMode = "gyroModeStack"
    case gyroSensitivity = "gyroSensitivityStack"
    case leftStickMinOffset = "leftStickMinOffsetStack"
    case rightStickMinOffset = "rightStickMinOffsetStack"

    // MARK: Motion Control

    case controllerGyroSwitchButton = "controllerGyroSwitchButtonStack"
    case reverseHoldButton = "reverseHoldButtonStack"
    case gyroSource = "gyroSourceStack"
    case swapYawAndRoll = "swapYawAndRollStack"
    case mapGyroTo = "mapGyroToStack"
    case yawPitchToRightStick = "yawPitchToRightStickStack"
    case rollToLeftStick = "rollToLeftStickStack"
    case yawSensitivity = "yawSensitivityStack"
    case pitchSensitivity = "pitchSensitivityStack"
    case rollSensitivity = "rollSensitivityStack"
    case gyroToStickMinOffset = "gyroToStickMinOffsetStack"
    case synthPhysicalInput = "synthPhysicalInputStack"

    // MARK: Drawing Toolkit

    case pencilTick = "pencilTickStack"
    case pencilTickInterval = "pencilTickIntervalStack"
    case pencilTipOffset = "pencilTipOffsetStack"
    case pressureCurve = "pressureCurveStack"
    case doubleTapShortcut = "doubleTapShortcutStack"
    case squeezeShortcut = "squeezeShortcutStack"
    case pencilPausesNativeTouch = "pencilPausesNativeTouchStack"
    case disablePencilSlideGesture = "disablePencilSlideGestureStack"
    case pencilMode = "pencilModeStack"

    // MARK: Gestures

    case softKeyboardGesture = "softKeyboardGestureStack"
    case slideToSettingsScreenEdge = "slideToSettingsScreenEdgeStack"
    case slideToToolboxScreenEdge = "slideToToolboxScreenEdgeStack"
    case slideToSettingsDistance = "slideToSettingsDistanceStack"
    case edgeSlidingSensitivity = "edgeSlidingSensitivityStack"

    // MARK: Peripherals

    case externalDisplayMode = "externalDisplayModeStack"
    case localMousePointerMode = "localMousePointerModeStack"
    case reverseMouseWheelDirection = "reverseMouseWheelDirectionStack"
    case citrixX1Mouse = "citrixX1MouseStack"
    case globeAsEscape = "globeAsEscapeStack"

    // MARK: Audio

    case audioOnPC = "audioOnPcStack"
    case localVolume = "localVolumeStack"
    case redirectMic = "redirectMicStack"
    case useBuiltinMic = "useBuiltinMicStack"
    case micVolume = "micVolumeStack"
    case duckOtherApps = "duckOtherAppStack"
    case muteInBackground = "muteInBackgroundStack"
    case audioConfig = "audioConfigStack"

    // MARK: Others

    case statsOverlay = "statsOverlayStack"
    case unlockDisplayOrientation = "unlockDisplayOrientationStack"
    case backgroundSessionTimer = "backgroundSessionTimerStack"
    case appTheme = "appThemeStack"
    case optimizeGames = "optimizeGamesStack"
    case multiController = "multiControllerStack"

    // MARK: Others - manual additions

    case softKeyboardToolbar = "softKeyboardToolbarStack"
    case softKeyboardHeight = "softKeyboardHeightStack"
    case rememberFoldState = "rememberFoldStateStack"

    // MARK: Experimental

    case touchModeExperimental = "touchModeStack2"
    case relativeTouchSlideThreshold = "relativeTouchSlideThresholdStack"
    case singleTapSensitivity = "singleTapSensitivityStack"
    case leftClickDelay = "leftClickDelayStack"
    case renderingBackend = "renderingBackendStack"
    case fullColorRange = "fullColorRangeStack"
    case performanceGraph = "performanceGraphStack"
    case sendDummyEvent = "sendDummyEventStack"

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .resolution: return "Resolution"
        case .customResolution: return "Custom Resolution"
        case .frameRate: return "Frame Rate"
        case .bitrate: return "Bitrate"
        case .codec: return "Preferred Codec"
        case .hdr: return "HDR"
        case .yuv444: return "YUV 4:4:4"
        case .framePacing: return "Frame Pacing"
        case .interpolationLevel: return "Interpolation Resolution"
        case .streamDimensionScale: return "Scaled Stream Resolution"
        case .frameQueueSize: return "Frames to Buffer"
        case .asyncFrameDequeue: return "Async Frame Dequeue"
        case .pictureInPicture: return "Enable PiP"
        case .touchMode: return "Touch Mode"
        case .mousePointerVelocity: return "Mouse Pointer Velocity"
        case .pointerVelocityDivider: return "Divider Position"
        case .pointerVelocityFactor: return "Touch Pointer Velocity"
        case .delayLeftClick: return "Delay Left Click"
        case .passthroughGestures: return "Passthrough Gestures"
        case .pinchGesture: return "Pinch Gesture"
        case .ctrlDownForPinch: return "Ctrl Down for Pinch"
        case .scrollSensitivity: return "Scroll Sensitivity"
        case .pinchSensitivity: return "Pinch Sensitivity"
        case .onScreenWidget: return "On-Screen Widgets"
        case .buttonVisualFeedback: return "Button Visual Feedback"
        case .trackTouchPoint: return "Touch Point Tracking"
        case .controllerNavigation: return "Controller Navigation"
        case .streamingRadialMenuDelay: return "Streaming Radial Menu Delay"
        case .controllerMouseVelocity: return "Controller Mouse Velocity"
        case .controllerMouseExpo: return "Curve Exponent"
        case .swapABXY: return "Swap A/B X/Y Buttons"
        case .hapticEngine: return "Haptic Engine"
        case .emulatedControllerType: return "Emulated Controller Type"
        case .dualSenseTransient: return "DualSense Haptic Intensity"
        case .gyroMode: return "Gyro Mode"
        case .gyroSensitivity: return "Gyro Sensitivity"
        case .leftStickMinOffset: return "Left Stick Minimum Offset"
        case .rightStickMinOffset: return "Right Stick Minimum Offset"
        case .controllerGyroSwitchButton: return "Switch Gyro by Controller"
        case .reverseHoldButton: return "Reverse Hold Button"
        case .gyroSource: return "Gyro Source"
        case .swapYawAndRoll: return "Swap Yaw & Roll"
        case .mapGyroTo: return "Map Gyro to"
        case .yawPitchToRightStick: return "Yaw&Pitch → Right Stick"
        case .rollToLeftStick: return "Roll → Left Stick"
        case .yawSensitivity: return "Yaw Sensitivity"
        case .pitchSensitivity: return "Pitch Sensitivity"
        case .rollSensitivity: return "Roll Sensitivity"
        case .gyroToStickMinOffset: return "Minimum Offset (Gyro→Stick)"
        case .synthPhysicalInput: return "Blend Physical Stick Input"
        case .pencilTick: return "Stroke Type"
        case .pencilTickInterval: return "Tick Interval"
        case .pencilTipOffset: return "Pencil Tip Offset"
        case .pressureCurve: return "Pressure Curve"
        case .doubleTapShortcut: return "Custom Double Tap Keyboard Shortcut"
        case .squeezeShortcut: return "Custom Squeeze Keyboard Shortcut"
        case .pencilPausesNativeTouch: return "Drawing Pauses Native Touch"
        case .disablePencilSlideGesture: return "Disable Slide Gesture for Pencil"
        case .pencilMode: return "Pencil Mode"
        case .softKeyboardGesture: return "Toggle Local Soft Keyboard"
        case .slideToSettingsScreenEdge: return "Open Settings in Streaming"
        case .slideToToolboxScreenEdge: return "Open Toolbox in Streaming"
        case .slideToSettingsDistance: return "Gesture Sliding Distance"
        case .edgeSlidingSensitivity: return "Edge Trigger Sensitivity"
        case .externalDisplayMode: return "External Display Mode"
        case .localMousePointerMode: return "Local Mouse Cursor"
        case .reverseMouseWheelDirection: return "Physical Mouse Wheel Scroll"
        case .citrixX1Mouse: return "Citrix X1 Mouse"
        case .globeAsEscape: return "Globe Key as Escape"
        case .audioOnPC: return "Play Audio on PC"
        case .localVolume: return "Local Volume"
        case .redirectMic: return "Redirect Mic"
        case .useBuiltinMic: return "Use Built-in Mic"
        case .micVolume: return "Mic Volume"
        case .duckOtherApps: return "Duck Other Apps"
        case .muteInBackground: return "Mute in Background"
        case .audioConfig: return "Audio Configuration"
        case .statsOverlay: return "Statistics Overlay"
        case .unlockDisplayOrientation: return "90° Display Rotation"
        case .backgroundSessionTimer: return "Background Session"
        case .appTheme: return "Theme"
        case .optimizeGames: return "Optimize Game Settings"
        case .multiController: return "Multi-Controller Mode"
        case .softKeyboardToolbar: return "Soft Keyboard Toolbar"
        case .softKeyboardHeight: return "Designate Soft Keyboard Height"
        case .rememberFoldState: return "Remember Menu Fold/Expand"
        case .touchModeExperimental: return "Touch Mode"
        case .relativeTouchSlideThreshold: return "Slide Distance Threshold"
        case .singleTapSensitivity: return "Single Tap Sensitivity"
        case .leftClickDelay: return "Left Click Delay"
        case .renderingBackend: return "Rendering Mode"
        case .fullColorRange: return "Full Color Range"
        case .performanceGraph: return "Performance Graph  "
        case .sendDummyEvent: return "Send Dummy Event"
        }
    }
}

enum SettingsSectionID: String, CaseIterable, Identifiable {
    // MARK: Primary sections

    case video = "SettingsSectionVideo"
    case touchController = "SettingsSectionTouch&Controller"
    case controller = "SettingsSectionController"
    case motionControl = "SettingsSectionMotionControl"
    case pencil = "SettingsSectionPencil"
    case gestures = "SettingsSectionGestures"
    case peripherals = "SettingsSectionPeripherals"
    case audio = "SettingsSectionAudio"

    // MARK: Remaining sections

    case others = "SettingsSectionOthers"
    case experimental = "SettingsSectionExperimental"

    var id: String { rawValue }
}

enum SettingsControlDescriptor {
    case picker(
        value: (SettingsSession) -> Int,
        setValue: (SettingsSession, Int) -> Void,
        options: (SettingsSession) -> [SettingsPickerOption<Int>],
        distribution: SettingsPickerWidthDistribution
    )
    case toggle(
        value: (SettingsSession) -> Bool,
        setValue: (SettingsSession, Bool) -> Void
    )
    case slider(
        value: (SettingsSession) -> Double,
        setValue: (SettingsSession, Double) -> Void,
        range: ClosedRange<Double>,
        valueText: (SettingsSession) -> String
    )
}

enum SettingsContinuousInteractionSource {
    case touch
    case controller
}

struct SettingsContinuousInteractionDescriptor {
    let controllerIdleInterval: TimeInterval
    let onBegan: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)?
    let onChanged: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)?
    let onEnded: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)?
    let onCancelled: ((SettingsSession) -> Void)?
    let cancelsOnScroll: Bool

    init(
        controllerIdleInterval: TimeInterval = 0.5,
        onBegan: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)? = nil,
        onChanged: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)? = nil,
        onEnded: ((SettingsSession, SettingsContinuousInteractionSource) -> Void)? = nil,
        onCancelled: ((SettingsSession) -> Void)? = nil,
        cancelsOnScroll: Bool? = nil
    ) {
        self.controllerIdleInterval = controllerIdleInterval
        self.onBegan = onBegan
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.onCancelled = onCancelled
        self.cancelsOnScroll = cancelsOnScroll ?? (onCancelled != nil)
    }
}

/// Observable state owned by one setting item. The session only coordinates
/// cross-item context; item-local value and UI state live here.
@available(iOS 13.0, *)
final class SettingsItemModel<Value>: ObservableObject, Identifiable {
    let id: SettingsItemID
    var titleKey: String { id.titleKey }
    let control: SettingsControlDescriptor?
    @Published var value: Value
    /// UIKit-equivalent rollback state for picker-backed items.  This belongs
    /// to the item model rather than a view-local `@State`, so an item action
    /// can read the selection that preceded its current value.
    @Published var previousSelectedIndex: Int
    @Published var isHidden: Bool
    @Published var isEnabled: Bool

    init(
        id: SettingsItemID,
        value: Value,
        previousSelectedIndex: Int = UISegmentedControl.noSegment,
        control: SettingsControlDescriptor? = nil,
        isHidden: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.value = value
        self.previousSelectedIndex = previousSelectedIndex
        self.control = control
        self.isHidden = isHidden
        self.isEnabled = isEnabled
    }

}

/// Declarative description consumed by the renderer and runtime navigation.
/// Visibility/enabled values are evaluated from the current session so this
/// object never becomes a second, stale copy of the UI state.
@available(iOS 13.0, *)
struct SettingsItemDescriptor: Identifiable {
    let id: SettingsItemID
    let control: SettingsControlDescriptor
    /// Optional item-owned UIKit picker rollback state.  The renderer passes
    /// this straight into `SettingsPicker`; item actions can read the same
    /// model property without reaching into a rendered UIView.
    let previousSelectedIndex: ((SettingsSession) -> Binding<Int>?)?
    let isVisible: (SettingsSession) -> Bool
    let isEnabled: (SettingsSession) -> Bool
    let dynamicText: ((SettingsSession) -> String)?
    let hasInfo: Bool
    let isGameProfileSetting: Bool
    let onDisabledOptionTapped: ((SettingsSession, Int) -> Void)?
    let continuousInteraction: SettingsContinuousInteractionDescriptor?
    let onValueChanged: ((SettingsSession) -> Void)?
    let onNavigate: ((SettingsSession, Bool) -> Void)?

    init(
        id: SettingsItemID,
        control: SettingsControlDescriptor,
        previousSelectedIndex: ((SettingsSession) -> Binding<Int>?)? = nil,
        isVisible: @escaping (SettingsSession) -> Bool = { _ in true },
        isEnabled: @escaping (SettingsSession) -> Bool = { _ in true },
        dynamicText: ((SettingsSession) -> String)? = nil,
        hasInfo: Bool = false,
        isGameProfileSetting: Bool = false,
        onDisabledOptionTapped: ((SettingsSession, Int) -> Void)? = nil,
        continuousInteraction: SettingsContinuousInteractionDescriptor? = nil,
        onValueChanged: ((SettingsSession) -> Void)? = nil,
        onNavigate: ((SettingsSession, Bool) -> Void)? = nil
    ) {
        self.id = id
        self.control = control
        self.previousSelectedIndex = previousSelectedIndex
        self.isVisible = isVisible
        self.isEnabled = isEnabled
        self.dynamicText = dynamicText
        self.hasInfo = hasInfo
        self.isGameProfileSetting = isGameProfileSetting
        self.onDisabledOptionTapped = onDisabledOptionTapped
        self.continuousInteraction = continuousInteraction
        self.onValueChanged = onValueChanged
        self.onNavigate = onNavigate
    }
}

@available(iOS 13.0, *)
struct SettingsSectionDescriptor: Identifiable {
    let id: SettingsSectionID
    let titleKey: String
    let icon: UIImage?
    let iconPointSize: CGFloat
    let iconWeight: UIImage.SymbolWeight
    let iconSizeConstraint: CGFloat
    let itemsParticipateInControllerNavigation: Bool
    let items: [SettingsItemDescriptor]

    init(
        id: SettingsSectionID,
        titleKey: String,
        icon: UIImage?,
        iconPointSize: CGFloat,
        iconWeight: UIImage.SymbolWeight,
        iconSizeConstraint: CGFloat,
        itemsParticipateInControllerNavigation: Bool = true,
        items: [SettingsItemDescriptor] = []
    ) {
        self.id = id
        self.titleKey = titleKey
        self.icon = icon
        self.iconPointSize = iconPointSize
        self.iconWeight = iconWeight
        self.iconSizeConstraint = iconSizeConstraint
        self.itemsParticipateInControllerNavigation = itemsParticipateInControllerNavigation
        self.items = items
    }
}

@available(iOS 13.0, *)
extension SettingsSession {
    private func pickerItem(
        _ itemKeyPath: KeyPath<SettingsItemRegistry, SettingsItemModel<Int>>,
        idOverride: SettingsItemID? = nil,
        setValue: ((SettingsSession, SettingsItemModel<Int>, Int) -> Void)? = nil,
        options: @escaping (SettingsSession) -> [SettingsPickerOption<Int>],
        distribution: SettingsPickerWidthDistribution,
        previousSelectedIndex: ((SettingsSession) -> Binding<Int>?)? = nil,
        isVisible: @escaping (SettingsSession) -> Bool = { _ in true },
        isEnabled: @escaping (SettingsSession) -> Bool = { _ in true },
        dynamicText: ((SettingsSession) -> String)? = nil,
        hasInfo: Bool = false,
        isGameProfileSetting: Bool = false,
        onDisabledOptionTapped: ((SettingsSession, Int) -> Void)? = nil,
        continuousInteraction: SettingsContinuousInteractionDescriptor? = nil,
        onValueChanged: ((SettingsSession) -> Void)? = nil,
        onNavigate: ((SettingsSession, Bool) -> Void)? = nil
    ) -> SettingsItemDescriptor {
        let item = itemRegistry[keyPath: itemKeyPath]
        let itemPreviousSelectedIndex: (SettingsSession) -> Binding<Int>? = { session in
            Binding(
                get: { session.itemRegistry[keyPath: itemKeyPath].previousSelectedIndex },
                set: { newIndex in
                    session.itemRegistry[keyPath: itemKeyPath].previousSelectedIndex = newIndex
                }
            )
        }
        return SettingsItemDescriptor(
            id: idOverride ?? item.id,
            control: .picker(
                value: { $0.itemRegistry[keyPath: itemKeyPath].value },
                setValue: { session, newValue in
                    let model = session.itemRegistry[keyPath: itemKeyPath]
                    if let setValue {
                        setValue(session, model, newValue)
                    } else {
                        model.value = newValue
                    }
                },
                options: options,
                distribution: distribution
            ),
            previousSelectedIndex: previousSelectedIndex ?? itemPreviousSelectedIndex,
            isVisible: isVisible,
            isEnabled: isEnabled,
            dynamicText: dynamicText,
            hasInfo: hasInfo,
            isGameProfileSetting: isGameProfileSetting,
            onDisabledOptionTapped: onDisabledOptionTapped,
            continuousInteraction: continuousInteraction,
            onValueChanged: onValueChanged,
            onNavigate: onNavigate
        )
    }

    private func toggleItem(
        _ itemKeyPath: KeyPath<SettingsItemRegistry, SettingsItemModel<Bool>>,
        idOverride: SettingsItemID? = nil,
        setValue: ((SettingsSession, SettingsItemModel<Bool>, Bool) -> Void)? = nil,
        isVisible: @escaping (SettingsSession) -> Bool = { _ in true },
        isEnabled: @escaping (SettingsSession) -> Bool = { _ in true },
        dynamicText: ((SettingsSession) -> String)? = nil,
        hasInfo: Bool = false,
        isGameProfileSetting: Bool = false,
        continuousInteraction: SettingsContinuousInteractionDescriptor? = nil,
        onValueChanged: ((SettingsSession) -> Void)? = nil,
        onNavigate: ((SettingsSession, Bool) -> Void)? = nil
    ) -> SettingsItemDescriptor {
        let item = itemRegistry[keyPath: itemKeyPath]
        return SettingsItemDescriptor(
            id: idOverride ?? item.id,
            control: .toggle(
                value: { $0.itemRegistry[keyPath: itemKeyPath].value },
                setValue: { session, newValue in
                    let model = session.itemRegistry[keyPath: itemKeyPath]
                    if let setValue {
                        setValue(session, model, newValue)
                    } else {
                        model.value = newValue
                    }
                }
            ),
            isVisible: isVisible,
            isEnabled: isEnabled,
            dynamicText: dynamicText,
            hasInfo: hasInfo,
            isGameProfileSetting: isGameProfileSetting,
            continuousInteraction: continuousInteraction,
            onValueChanged: onValueChanged,
            onNavigate: onNavigate
        )
    }

    private func sliderItem(
        _ itemKeyPath: KeyPath<SettingsItemRegistry, SettingsItemModel<Double>>,
        idOverride: SettingsItemID? = nil,
        setValue: ((SettingsSession, SettingsItemModel<Double>, Double) -> Void)? = nil,
        range: ClosedRange<Double>,
        clampedTo clampRange: ClosedRange<Double>? = nil,
        valueText: @escaping (SettingsSession, SettingsItemModel<Double>) -> String,
        isVisible: @escaping (SettingsSession) -> Bool = { _ in true },
        isEnabled: @escaping (SettingsSession) -> Bool = { _ in true },
        dynamicText: ((SettingsSession) -> String)? = nil,
        hasInfo: Bool = false,
        isGameProfileSetting: Bool = false,
        continuousInteraction: SettingsContinuousInteractionDescriptor? = nil,
        onValueChanged: ((SettingsSession) -> Void)? = nil,
        onNavigate: ((SettingsSession, Bool) -> Void)? = nil
    ) -> SettingsItemDescriptor {
        let item = itemRegistry[keyPath: itemKeyPath]
        return SettingsItemDescriptor(
            id: idOverride ?? item.id,
            control: .slider(
                value: { $0.itemRegistry[keyPath: itemKeyPath].value },
                setValue: { session, newValue in
                    let model = session.itemRegistry[keyPath: itemKeyPath]
                    if let setValue {
                        setValue(session, model, newValue)
                    } else if let clampRange {
                        model.value = min(clampRange.upperBound, max(clampRange.lowerBound, newValue))
                    } else {
                        model.value = newValue
                    }
                },
                range: range,
                valueText: { session in valueText(session, session.itemRegistry[keyPath: itemKeyPath]) }
            ),
            isVisible: isVisible,
            isEnabled: isEnabled,
            dynamicText: dynamicText,
            hasInfo: hasInfo,
            isGameProfileSetting: isGameProfileSetting,
            continuousInteraction: continuousInteraction,
            onValueChanged: onValueChanged,
            onNavigate: onNavigate
        )
    }

    private func doubleBackedToggleItem(
        _ itemKeyPath: KeyPath<SettingsItemRegistry, SettingsItemModel<Double>>,
        idOverride: SettingsItemID? = nil,
        isOn: @escaping (Double) -> Bool = { $0 != 0 },
        setValue: @escaping (SettingsSession, SettingsItemModel<Double>, Bool) -> Void,
        isVisible: @escaping (SettingsSession) -> Bool = { _ in true },
        isEnabled: @escaping (SettingsSession) -> Bool = { _ in true },
        dynamicText: ((SettingsSession) -> String)? = nil,
        hasInfo: Bool = false,
        isGameProfileSetting: Bool = false,
        continuousInteraction: SettingsContinuousInteractionDescriptor? = nil,
        onValueChanged: ((SettingsSession) -> Void)? = nil,
        onNavigate: ((SettingsSession, Bool) -> Void)? = nil
    ) -> SettingsItemDescriptor {
        let item = itemRegistry[keyPath: itemKeyPath]
        return SettingsItemDescriptor(
            id: idOverride ?? item.id,
            control: .toggle(
                value: { session in
                    isOn(session.itemRegistry[keyPath: itemKeyPath].value)
                },
                setValue: { session, newValue in
                    setValue(session, session.itemRegistry[keyPath: itemKeyPath], newValue)
                }
            ),
            isVisible: isVisible,
            isEnabled: isEnabled,
            dynamicText: dynamicText,
            hasInfo: hasInfo,
            isGameProfileSetting: isGameProfileSetting,
            continuousInteraction: continuousInteraction,
            onValueChanged: onValueChanged,
            onNavigate: onNavigate
        )
    }
}

extension SettingsItemID {
    static func settingItem(rawValue: String) -> SettingsItemID? {
        SettingsItemID(rawValue: rawValue)
    }
}

@available(iOS 13.0, *)
fileprivate final class SettingsNavigationState: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    let highlightedIDDidChange = PassthroughSubject<String?, Never>()
    private(set) var highlightedID: String?

    init(highlightedID: String? = nil) {
        self.highlightedID = highlightedID
    }

    func setHighlightedID(_ id: String?) {
        guard highlightedID != id else { return }
        // This state is intentionally published after mutation. @Published
        // emits from willSet; the isolated highlight views would therefore
        // render the previous selection and stay exactly one command behind.
        highlightedID = id
        objectWillChange.send()
        highlightedIDDidChange.send(id)
    }
}

private struct SettingsNavigationRowsHiddenKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SettingsNavigationAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]

    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

private let settingsNavigationCoordinateSpaceName = "SettingsNavigationContent"

private func settingsRectApproximatelyEqual(_ lhs: CGRect, _ rhs: CGRect, tolerance: CGFloat = 0.5) -> Bool {
    abs(lhs.origin.x - rhs.origin.x) <= tolerance &&
        abs(lhs.origin.y - rhs.origin.y) <= tolerance &&
        abs(lhs.size.width - rhs.size.width) <= tolerance &&
        abs(lhs.size.height - rhs.size.height) <= tolerance
}

private func settingsRectMapApproximatelyEqual<Key: Hashable>(
    _ lhs: [Key: CGRect],
    _ rhs: [Key: CGRect],
    tolerance: CGFloat = 0.5
) -> Bool {
    guard lhs.count == rhs.count,
          Set(lhs.keys) == Set(rhs.keys) else { return false }
    return lhs.allSatisfy { key, lhsRect in
        guard let rhsRect = rhs[key] else { return false }
        return settingsRectApproximatelyEqual(lhsRect, rhsRect, tolerance: tolerance)
    }
}

@available(iOS 13.0, *)
private extension EnvironmentValues {
    var settingsNavigationRowsHidden: Bool {
        get { self[SettingsNavigationRowsHiddenKey.self] }
        set { self[SettingsNavigationRowsHiddenKey.self] = newValue }
    }
}

@available(iOS 13.0, *)
private struct SettingsNavigationRegistration: ViewModifier {
    let id: String
    let isHidden: Bool
    let registersAnchor: Bool
    @Environment(\.settingsNavigationRowsHidden) private var sectionRowsHidden

    @ViewBuilder
    func body(content: Content) -> some View {
        if registersAnchor && !usesSwiftUIScroll {
            content
                .background(
                    GeometryReader { geometry in
                        Color.clear.preference(
                            key: SettingsNavigationAnchorPreferenceKey.self,
                            value: (isHidden || sectionRowsHidden)
                                ? [:]
                                : [id: geometry.frame(in: .named(settingsNavigationCoordinateSpaceName))]
                        )
                    }
                )
        } else {
            content
        }
    }
}

private let defaultFavoriteSettingIdentifiers = [
    // Video
    "resolutionStack",
    "fpsStack",
    "bitrateStack",
    "codecStack",
    "hdrStack",
    "yuv444Stack",
    "pipStack",

    // Touch Control
    "touchModeStack",
    "pointerVelocityDividerStack",
    "pointerVelocityFactorStack",
    "mousePointerVelocityStack",
    "onScreenWidgetStack",

    // Gestures
    "softKeyboardGestureStack",
    "slideToSettingsScreenEdgeStack",
    "slideToToolboxScreenEdgeStack",
    "slideToSettingsDistanceStack",

    // Others
    "backgroundSessionTimerStack",
    "statsOverlayStack",
    "unlockDisplayOrientationStack"
]

private func migratedFavoriteSettingIdentifiers(_ identifiers: [String]) -> [String] {
    let legacyResolutionID = "resolutionStack"
    let resolutionIDs = [SettingsItemID.resolution.rawValue, SettingsItemID.customResolution.rawValue]
    let hasLegacyResolution = identifiers.contains(legacyResolutionID)
    let hasNewResolution = identifiers.contains { resolutionIDs.contains($0) }
    var source = identifiers

    if hasLegacyResolution && !hasNewResolution,
       let legacyIndex = source.firstIndex(of: legacyResolutionID) {
        source.insert(contentsOf: resolutionIDs, at: legacyIndex + 1)
    } else if hasNewResolution && !hasLegacyResolution,
              let firstNewIndex = source.firstIndex(where: { resolutionIDs.contains($0) }) {
        source.insert(legacyResolutionID, at: firstNewIndex)
    }

    let splitLegacyItems: [(legacy: String, replacements: [String])] = [
        // Motion Control: old UIKit combined stack became two independent rows.
        ("gyroToStickStack", [
            SettingsItemID.yawPitchToRightStick.rawValue,
            SettingsItemID.rollToLeftStick.rawValue
        ]),

        // Motion Control: old UIKit combined stack became two independent rows.
        ("yawPitchSensitivityStack", [
            SettingsItemID.yawSensitivity.rawValue,
            SettingsItemID.pitchSensitivity.rawValue
        ])
    ]
    for split in splitLegacyItems {
        let hasLegacy = source.contains(split.legacy)
        let hasReplacement = source.contains { split.replacements.contains($0) }
        if hasLegacy && !hasReplacement,
           let legacyIndex = source.firstIndex(of: split.legacy) {
            source.insert(contentsOf: split.replacements, at: legacyIndex + 1)
        } else if hasReplacement && !hasLegacy,
                  let replacementIndex = source.firstIndex(where: { split.replacements.contains($0) }) {
            source.insert(split.legacy, at: replacementIndex)
        }
    }

    var result: [String] = []
    for identifier in source where !result.contains(identifier) {
        result.append(identifier)
    }
    return result
}

// MARK: - Settings enum values

// MARK: Video

private enum VideoCodec: Int {
    case h264 = 1
    case hevc = 2
    case av1 = 3
}

// MARK: Motion Control

/// The storyboard stores gyro source as segment indices, while the profile
/// stores the inverse `useBuiltinGyro` Boolean. Keep that mapping named so the
/// catalog never depends on unexplained 0/1 values.
private enum SettingsGyroSource: Int {
    case builtIn
    case controller
}

// MARK: Gestures

/// Stored keyboard-toggle gesture values are finger counts, with 20 standing
/// for Disabled.  Keeping the persisted values here avoids segment indices in
/// the catalog and keeps the iOS picker independent of its visual order.
private enum SettingsSoftKeyboardGesture: Int {
    case threeFingerTap = 3
    case fourFingerTap = 4
    case fiveFingerTap = 5
    case disabled = 20
}

/// UIKit persists the streaming-settings edge as a UIRectEdge bitmask.  The
/// picker only offers the two single-edge cases used by the original UI.
private enum GestureScreenEdge {
    case left
    case right

    var rawValue: Int {
        switch self {
        case .left: return Int(UIRectEdge.left.rawValue)
        case .right: return Int(UIRectEdge.right.rawValue)
        }
    }

    static func from(rawValue: Int) -> GestureScreenEdge {
        rawValue == Int(UIRectEdge.right.rawValue) ? .right : .left
    }

    var opposite: GestureScreenEdge {
        switch self {
        case .left: return .right
        case .right: return .left
        }
    }
}

// MARK: Controller
/*
private func settingsSanitizedControllerEmulationRawValue(_ rawValue: Int) -> Int {
    guard let exactRawValue = UInt8(exactly: rawValue),
          ControllerEmulation(rawValue: exactRawValue) != nil else {
        return Int(ControllerEmulation.xboxAndPs.rawValue)
    }
    return Int(exactRawValue)
}
*/
// MARK: Audio

private func settingsAudioConfigValuesForCurrentOS() -> [Int] {
    var values = [
        AudioConfig.stereo.rawValue,
        AudioConfig.stereoSDL.rawValue
    ]
    if #available(iOS 18.0, tvOS 18.0, *) {
        values.append(contentsOf: [
            AudioConfig.SDL51.rawValue,
            AudioConfig.SDL71.rawValue
        ])
    }
    return values
}

private func settingsSanitizedAudioConfig(_ value: Int) -> Int {
    let values = settingsAudioConfigValuesForCurrentOS()
    return values.contains(value) ? value : AudioConfig.stereo.rawValue
}

private func settingsMaximumMicVolumeForCurrentDevice() -> Double {
    UIDevice.current.userInterfaceIdiom == .pad ? 150 : 120
}

/// The single source of truth for item-local values.  Keeping these values on
/// the item models means adding a row does not require another parallel set of
/// `SettingsSession` properties.
@available(iOS 13.0, *)
final class SettingsItemRegistry: ObservableObject {
    // MARK: Video

    let resolution = SettingsItemModel<Int>(id: .resolution, value: 0)
    let usesCustomResolution = SettingsItemModel<Bool>(id: .customResolution, value: false)
    let frameRate = SettingsItemModel<Int>(id: .frameRate, value: 60)
    let bitrate = SettingsItemModel<Double>(id: .bitrate, value: 0)
    let bitrateSliderPosition = SettingsItemModel<Double>(id: .bitrate, value: 0)
    let codec = SettingsItemModel<Int>(id: .codec, value: VideoCodec.h264.rawValue)
    let hdr = SettingsItemModel<Bool>(id: .hdr, value: false)
    let yuv444 = SettingsItemModel<Bool>(id: .yuv444, value: false)
    let framePacing = SettingsItemModel<Int>(id: .framePacing, value: 0)
    let interpolationLevel = SettingsItemModel<Double>(id: .interpolationLevel, value: 1)
    let streamDimensionScale = SettingsItemModel<Double>(id: .streamDimensionScale, value: 1)
    let frameQueueSize = SettingsItemModel<Double>(id: .frameQueueSize, value: 0)
    let asyncFrameDequeue = SettingsItemModel<Bool>(id: .asyncFrameDequeue, value: false)
    let pictureInPicture = SettingsItemModel<Bool>(id: .pictureInPicture, value: false)
    
    // MARK: Touch Control

    let touchMode = SettingsItemModel<Int>(id: .touchMode, value: 1)
    let mousePointerVelocity = SettingsItemModel<Double>(id: .mousePointerVelocity, value: 100)
    let pointerVelocityDivider = SettingsItemModel<Double>(id: .pointerVelocityDivider, value: 100)
    let pointerVelocityFactor = SettingsItemModel<Double>(id: .pointerVelocityFactor, value: 100)
    let delayLeftClick = SettingsItemModel<Bool>(id: .delayLeftClick, value: true)
    let passthroughGestures = SettingsItemModel<Bool>(id: .passthroughGestures, value: true)
    let pinchGesture = SettingsItemModel<Bool>(id: .pinchGesture, value: true)
    let ctrlDownForPinch = SettingsItemModel<Bool>(id: .ctrlDownForPinch, value: true)
    let scrollSensitivity = SettingsItemModel<Double>(id: .scrollSensitivity, value: 1)
    let pinchSensitivity = SettingsItemModel<Double>(id: .pinchSensitivity, value: 1)
    let onScreenWidget = SettingsItemModel<Int>(id: .onScreenWidget, value: 0)
    let buttonVisualFeedback = SettingsItemModel<Bool>(id: .buttonVisualFeedback, value: true)
    let trackTouchPoint = SettingsItemModel<Bool>(id: .trackTouchPoint, value: false)

    // MARK: Controller
    
    let controllerNavigation = SettingsItemModel<Bool>(id: .controllerNavigation, value: false)
    let streamingRadialMenuDelay = SettingsItemModel<Double>(id: .streamingRadialMenuDelay, value: 0)
    let controllerMouseVelocity = SettingsItemModel<Double>(id: .controllerMouseVelocity, value: 0)
    let controllerMouseExpo = SettingsItemModel<Double>(id: .controllerMouseExpo, value: 1)
    let swapABXY = SettingsItemModel<Bool>(id: .swapABXY, value: false)
    let hapticEngine = SettingsItemModel<Int>(id: .hapticEngine, value: 0)
    let emulatedControllerType = SettingsItemModel<Int>(
        id: .emulatedControllerType,
        value: Int(ControllerEmulation.xbox.rawValue)
    )
    let dualSenseTransient = SettingsItemModel<Double>(id: .dualSenseTransient, value: 1)
    let gyroMode = SettingsItemModel<Int>(id: .gyroMode, value: 0)
    let gyroSensitivity = SettingsItemModel<Double>(id: .gyroSensitivity, value: 100)
    let leftStickMinOffset = SettingsItemModel<Double>(id: .leftStickMinOffset, value: 0)
    let rightStickMinOffset = SettingsItemModel<Double>(id: .rightStickMinOffset, value: 0)
    
    // MARK: Motion Control

    let controllerGyroSwitchButton = SettingsItemModel<Int>(id: .controllerGyroSwitchButton, value: ControllerGyroSwitchMode.disabled.rawValue)
    let reverseHoldButton = SettingsItemModel<Bool>(id: .reverseHoldButton, value: false)
    let gyroSource = SettingsItemModel<Int>(id: .gyroSource, value: SettingsGyroSource.builtIn.rawValue)
    let swapYawAndRoll = SettingsItemModel<Bool>(id: .swapYawAndRoll, value: false)
    let mapGyroTo = SettingsItemModel<Int>(id: .mapGyroTo, value: MapGyroTo.mapGyroToMouse.rawValue)
    let yawPitchToRightStick = SettingsItemModel<Bool>(id: .yawPitchToRightStick, value: false)
    let rollToLeftStick = SettingsItemModel<Bool>(id: .rollToLeftStick, value: false)
    let yawSensitivity = SettingsItemModel<Double>(id: .yawSensitivity, value: 100)
    let pitchSensitivity = SettingsItemModel<Double>(id: .pitchSensitivity, value: 100)
    let rollSensitivity = SettingsItemModel<Double>(id: .rollSensitivity, value: 100)
    let gyroToStickMinOffset = SettingsItemModel<Double>(id: .gyroToStickMinOffset, value: 0)
    let synthPhysicalInput = SettingsItemModel<Bool>(id: .synthPhysicalInput, value: false)
    
    // MARK: Drawing Toolkit

    let pencilTick = SettingsItemModel<Int>(id: .pencilTick, value: PencilTickMode.PencilTickDisabled.rawValue)
    let pencilTickInterval = SettingsItemModel<Double>(id: .pencilTickInterval, value: 1500)
    let pencilTipOffset = SettingsItemModel<Bool>(id: .pencilTipOffset, value: false)
    let pressureCurve = SettingsItemModel<Bool>(id: .pressureCurve, value: false)
    let doubleTapShortcut = SettingsItemModel<Bool>(id: .doubleTapShortcut, value: false)
    let squeezeShortcut = SettingsItemModel<Bool>(id: .squeezeShortcut, value: false)
    let pencilPausesNativeTouch = SettingsItemModel<Bool>(id: .pencilPausesNativeTouch, value: false)
    let disablePencilSlideGesture = SettingsItemModel<Bool>(id: .disablePencilSlideGesture, value: false)
    let pencilMode = SettingsItemModel<Int>(id: .pencilMode, value: PencilAndHoverMode.pencilOnly.rawValue)
    
    // MARK: Gestures

    let softKeyboardGesture = SettingsItemModel<Int>(id: .softKeyboardGesture, value: SettingsSoftKeyboardGesture.disabled.rawValue)
    let slideToSettingsScreenEdge = SettingsItemModel<Int>(id: .slideToSettingsScreenEdge, value: GestureScreenEdge.right.rawValue)
    let slideToToolboxScreenEdge = SettingsItemModel<Int>(id: .slideToToolboxScreenEdge, value: GestureScreenEdge.left.rawValue)
    let slideToSettingsDistance = SettingsItemModel<Double>(id: .slideToSettingsDistance, value: 0.2)
    let edgeSlidingSensitivity = SettingsItemModel<Double>(id: .edgeSlidingSensitivity, value: 15)

    // MARK: Peripherals

    let externalDisplayMode = SettingsItemModel<Int>(id: .externalDisplayMode, value: 0)
    let localMousePointerMode = SettingsItemModel<Int>(id: .localMousePointerMode, value: 0)
    let reverseMouseWheelDirection = SettingsItemModel<Int>(id: .reverseMouseWheelDirection, value: 0)
    let citrixX1Mouse = SettingsItemModel<Bool>(id: .citrixX1Mouse, value: false)
    let globeAsEscape = SettingsItemModel<Bool>(id: .globeAsEscape, value: false)
    
    // MARK: Audio

    let audioOnPC = SettingsItemModel<Bool>(id: .audioOnPC, value: false)
    let localVolume = SettingsItemModel<Double>(id: .localVolume, value: 100)
    let redirectMic = SettingsItemModel<Bool>(id: .redirectMic, value: false)
    let useBuiltinMic = SettingsItemModel<Bool>(id: .useBuiltinMic, value: false)
    let micVolume = SettingsItemModel<Double>(id: .micVolume, value: 100)
    let duckOtherApps = SettingsItemModel<Bool>(id: .duckOtherApps, value: false)
    let muteInBackground = SettingsItemModel<Bool>(id: .muteInBackground, value: false)
    let audioConfig = SettingsItemModel<Int>(id: .audioConfig, value: AudioConfig.stereo.rawValue)

    // MARK: Others

    let statsOverlay = SettingsItemModel<Int>(id: .statsOverlay, value: StatsOverlayLevel.off.rawValue)
    let unlockDisplayOrientation = SettingsItemModel<Int>(id: .unlockDisplayOrientation, value: 1)
    let backgroundSessionTimer = SettingsItemModel<Double>(id: .backgroundSessionTimer, value: 0)
    let appTheme = SettingsItemModel<Int>(id: .appTheme, value: UIUserInterfaceStyle.light.rawValue)
    let optimizeGames = SettingsItemModel<Bool>(id: .optimizeGames, value:true)
    let multiController = SettingsItemModel<Bool>(id: .multiController, value: true)
    let softKeyboardToolbar = SettingsItemModel<Bool>(id: .softKeyboardToolbar, value: true)
    let softKeyboardHeight = SettingsItemModel<Double>(id: .softKeyboardHeight, value: 0)
    let rememberFoldState = SettingsItemModel<Bool>(id: .rememberFoldState, value: true)

    // MARK: Experimental

    let relativeTouchSlideThreshold = SettingsItemModel<Double>(id: .relativeTouchSlideThreshold, value: 0)
    let singleTapSensitivity = SettingsItemModel<Double>(id: .singleTapSensitivity, value: 0)
    let leftClickDelay = SettingsItemModel<Double>(id: .leftClickDelay, value: 0)
    let renderingBackend = SettingsItemModel<Int>(id: .renderingBackend, value: 0)
    let fullColorRange = SettingsItemModel<Bool>(id: .fullColorRange, value: false)
    let enableGraphs = SettingsItemModel<Bool>(id: .performanceGraph, value: false)
    let sendDummyEvent = SettingsItemModel<Bool>(id: .sendDummyEvent, value: false)

    @Published private(set) var revision = 0
    private var cancellables = Set<AnyCancellable>()

    init() {
        [
            // Video
            resolution.objectWillChange,
            usesCustomResolution.objectWillChange,
            frameRate.objectWillChange,
            bitrate.objectWillChange,
            bitrateSliderPosition.objectWillChange,
            codec.objectWillChange,
            hdr.objectWillChange,
            yuv444.objectWillChange,
            framePacing.objectWillChange,
            interpolationLevel.objectWillChange,
            streamDimensionScale.objectWillChange,
            frameQueueSize.objectWillChange,
            asyncFrameDequeue.objectWillChange,
            pictureInPicture.objectWillChange,

            // Touch Control
            touchMode.objectWillChange,
            mousePointerVelocity.objectWillChange,
            pointerVelocityDivider.objectWillChange,
            pointerVelocityFactor.objectWillChange,
            delayLeftClick.objectWillChange,
            passthroughGestures.objectWillChange,
            pinchGesture.objectWillChange,
            ctrlDownForPinch.objectWillChange,
            scrollSensitivity.objectWillChange,
            pinchSensitivity.objectWillChange,
            onScreenWidget.objectWillChange,
            buttonVisualFeedback.objectWillChange,
            trackTouchPoint.objectWillChange,

            // Controller
            controllerNavigation.objectWillChange,
            streamingRadialMenuDelay.objectWillChange,
            controllerMouseVelocity.objectWillChange,
            controllerMouseExpo.objectWillChange,
            swapABXY.objectWillChange,
            hapticEngine.objectWillChange,
            emulatedControllerType.objectWillChange,
            dualSenseTransient.objectWillChange,
            gyroMode.objectWillChange,
            gyroSensitivity.objectWillChange,
            leftStickMinOffset.objectWillChange,
            rightStickMinOffset.objectWillChange,

            // Motion Control
            controllerGyroSwitchButton.objectWillChange,
            reverseHoldButton.objectWillChange,
            gyroSource.objectWillChange,
            swapYawAndRoll.objectWillChange,
            mapGyroTo.objectWillChange,
            yawPitchToRightStick.objectWillChange,
            rollToLeftStick.objectWillChange,
            yawSensitivity.objectWillChange,
            pitchSensitivity.objectWillChange,
            rollSensitivity.objectWillChange,
            gyroToStickMinOffset.objectWillChange,
            synthPhysicalInput.objectWillChange,

            // Drawing Toolkit
            pencilTick.objectWillChange,
            pencilTickInterval.objectWillChange,
            pencilTipOffset.objectWillChange,
            pressureCurve.objectWillChange,
            doubleTapShortcut.objectWillChange,
            squeezeShortcut.objectWillChange,
            pencilPausesNativeTouch.objectWillChange,
            disablePencilSlideGesture.objectWillChange,
            pencilMode.objectWillChange,

            // Gestures
            softKeyboardGesture.objectWillChange,
            slideToSettingsScreenEdge.objectWillChange,
            slideToToolboxScreenEdge.objectWillChange,
            slideToSettingsDistance.objectWillChange,
            edgeSlidingSensitivity.objectWillChange,

            // Peripherals
            externalDisplayMode.objectWillChange,
            localMousePointerMode.objectWillChange,
            reverseMouseWheelDirection.objectWillChange,
            citrixX1Mouse.objectWillChange,
            globeAsEscape.objectWillChange,

            // Audio
            audioOnPC.objectWillChange,
            localVolume.objectWillChange,
            redirectMic.objectWillChange,
            useBuiltinMic.objectWillChange,
            micVolume.objectWillChange,
            duckOtherApps.objectWillChange,
            muteInBackground.objectWillChange,
            audioConfig.objectWillChange,

            // Others
            statsOverlay.objectWillChange,
            unlockDisplayOrientation.objectWillChange,
            backgroundSessionTimer.objectWillChange,
            appTheme.objectWillChange,
            optimizeGames.objectWillChange,
            multiController.objectWillChange,
            softKeyboardToolbar.objectWillChange,
            softKeyboardHeight.objectWillChange,
            rememberFoldState.objectWillChange,

            // Experimental
            relativeTouchSlideThreshold.objectWillChange,
            singleTapSensitivity.objectWillChange,
            leftClickDelay.objectWillChange,
            renderingBackend.objectWillChange,
            fullColorRange.objectWillChange,
            enableGraphs.objectWillChange,
            sendDummyEvent.objectWillChange
        ].forEach { publisher in
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] in self?.revision &+= 1 }
                .store(in: &cancellables)
        }
    }
}

/// Swift counterpart of `controllerNavigationSwitchFlipped:`. The row action
/// owns only the decision to begin setup; this coordinator owns the multi-step
/// controller capture workflow so the catalog and renderer stay generic.
@available(iOS 13.0, *)
private final class ControllerNavigationSetupCoordinator {
    private enum Phase {
        case localRadialButton
        case localRadialButtonSide
        case streamingRadialButton
        case streamingRadialButtonSide
        case mouseStick
        case mouseLeftButton
        case mouseRightButton
        case finished
    }

    private weak var presenter: UIViewController?
    private weak var controller: GCController?
    private let completion: (Bool) -> Void
    private let dataManager = DataManager()
    private var phase: Phase = .localRadialButton
    private var capturedButtons = Set<Int32>()
    private var previouslyPressedButtons = Set<Int32>()
    private var alertController: UIAlertController?
    private var completionDelivered = false

    init(presenter: UIViewController?, completion: @escaping (Bool) -> Void) {
        self.presenter = presenter
        self.completion = completion
    }

    func start() {
        guard let presenter else {
            finish(completed: false)
            return
        }
        guard let controller = GCController.controllers().first(where: { $0.extendedGamepad != nil }) else {
            presentWaitingForController(in: presenter)
            return
        }
        self.controller = controller
        phase = .localRadialButton
        capturedButtons.removeAll()
        previouslyPressedButtons.removeAll()

        let alert = UIAlertController(
            title: "Controller Navigation".localized,
            message: "radialMenuButtonTip".localized,
            preferredStyle: .alert
        )
        alertController = alert
        presenter.present(alert, animated: true) { [weak self] in
            self?.beginListening(to: controller)
        }
    }

    func cancel() {
        cleanupControllerListener()
        alertController?.dismiss(animated: false)
        finish(completed: false)
    }

    private func presentWaitingForController(in presenter: UIViewController) {
        let alert = UIAlertController(
            title: nil,
            message: "Waiting for controller...".localized,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel) { [weak self] _ in
            self?.finish(completed: false)
        })
        alert.addAction(UIAlertAction(title: "Continue".localized, style: .default) { [weak self] _ in
            self?.start()
        })
        alertController = alert
        presenter.present(alert, animated: true)
    }

    private func beginListening(to controller: GCController) {
        if #available(iOS 14.0, *) {
            controller.physicalInputProfile.allElements.forEach {
                $0.preferredSystemGestureState = .disabled
            }
        }
        ControllerUtil.stopListeningPrimaryController(stopListenToRadialMenuButton: true)
        ControllerUtil.listen(controller: controller, swapABXY: false) { [weak self] elementDict, gamepad, _ in
            DispatchQueue.main.async {
                self?.consume(elementDict: elementDict, gamepad: gamepad)
            }
        }
    }

    private func consume(elementDict: NSDictionary, gamepad: GCExtendedGamepad) {
        guard phase != .finished,
              let settings = dataManager.retrieveSettings() else { return }

        var pressedButtons = Set<Int32>()
        for case let key as NSNumber in elementDict.allKeys {
            guard let button = elementDict[key] as? GCControllerButtonInput else { continue }
            let rawValue = key.int32Value
            if button.isPressed { pressedButtons.insert(rawValue) }
        }
        let newlyPressed = pressedButtons.subtracting(previouslyPressedButtons)
        previouslyPressedButtons = pressedButtons

        switch phase {
        case .localRadialButton:
            guard let rawValue = newlyPressed.first(where: isRadialMenuButton) else { return }
            settings.localRadialMenuButton = NSNumber(value: rawValue)
            capturedButtons.insert(rawValue)
            let position = controllerElementPosition(rawValue)
            if position == .undefined || position == .middle {
                phase = .localRadialButtonSide
                updateMessage("Which side of the controller is this button on?".localized)
                ControllerNavigator.updateHudForCustomRadialMenuButtonPosition()
            } else {
                phase = .streamingRadialButton
                updateMessage("streamingRadialMenuButtonTip".localized)
            }

        case .localRadialButtonSide:
            guard let position = selectedPosition(from: newlyPressed) else { return }
            settings.customLocalRadialMenuButtonPosition = NSNumber(value: position.rawValue)
            phase = .streamingRadialButton
            GamepadNavigationIllustrationHud.clearHud()
            updateMessage("streamingRadialMenuButtonTip".localized)

        case .streamingRadialButton:
            guard let rawValue = newlyPressed.first(where: isRadialMenuButton) else { return }
            settings.streamingRadialMenuButton = NSNumber(value: rawValue)
            capturedButtons.insert(rawValue)
            let localRawValue = settings.localRadialMenuButton?.int32Value ?? ControllerElement.null.rawValue
            if rawValue == localRawValue {
                settings.customStreamingRadialMenuButtonPosition = settings.customLocalRadialMenuButtonPosition
                phase = .mouseStick
                updateMessage(mouseStickMessage)
            } else {
                let position = controllerElementPosition(rawValue)
                if position == .undefined || position == .middle {
                    phase = .streamingRadialButtonSide
                    updateMessage("Which side of the controller is this button on?".localized)
                    ControllerNavigator.updateHudForCustomRadialMenuButtonPosition()
                } else {
                    phase = .mouseStick
                    updateMessage(mouseStickMessage)
                }
            }

        case .streamingRadialButtonSide:
            guard let position = selectedPosition(from: newlyPressed) else { return }
            settings.customStreamingRadialMenuButtonPosition = NSNumber(value: position.rawValue)
            phase = .mouseStick
            GamepadNavigationIllustrationHud.clearHud()
            updateMessage(mouseStickMessage)

        case .mouseStick:
            let leftOffset = hypotf(gamepad.leftThumbstick.xAxis.value, gamepad.leftThumbstick.yAxis.value)
            let rightOffset = hypotf(gamepad.rightThumbstick.xAxis.value, gamepad.rightThumbstick.yAxis.value)
            guard leftOffset > 0.1 || rightOffset > 0.1 else { return }
            let stick: ControllerElement = leftOffset > rightOffset ? .leftStick : .rightStick
            settings.controllerMouseStick = NSNumber(value: stick.rawValue)
            phase = .mouseLeftButton
            updateMessage("Press the button for mouse left button".localized)

        case .mouseLeftButton:
            guard let rawValue = newlyPressed.first(where: { !capturedButtons.contains($0) }) else { return }
            settings.controllerMouseLeftButton = NSNumber(value: rawValue)
            capturedButtons.insert(rawValue)
            phase = .mouseRightButton
            updateMessage("Press the button for mouse right button".localized)

        case .mouseRightButton:
            guard let rawValue = newlyPressed.first(where: { !capturedButtons.contains($0) }) else { return }
            settings.controllerMouseRightButton = NSNumber(value: rawValue)
            capturedButtons.insert(rawValue)
            complete(using: settings)

        case .finished:
            break
        }

    }

    private var mouseStickMessage: String {
        "Move the stick you want to use for mouse control. The other stick will be used for vertical and horizontal scrolling".localized
    }

    private func isRadialMenuButton(_ rawValue: Int32) -> Bool {
        ControllerNavigator.radialMenuButtonPool.contains(NSNumber(value: rawValue))
    }

    private func controllerElementPosition(_ rawValue: Int32) -> ControllerElementPosition {
        guard let element = ControllerElement(rawValue: rawValue) else { return .undefined }
        return ControllerUtil.position(for: element)
    }

    private func selectedPosition(from newlyPressed: Set<Int32>) -> ControllerElementPosition? {
        if newlyPressed.contains(ControllerElement.dpadLeft.rawValue) { return .left }
        if newlyPressed.contains(ControllerElement.dpadRight.rawValue) { return .right }
        if newlyPressed.contains(ControllerElement.dpadUp.rawValue) { return .middle }
        return nil
    }

    private func complete(using settings: Settings) {
        phase = .finished
        guard let localButton = ControllerElement(rawValue: settings.localRadialMenuButton?.int32Value ?? ControllerElement.null.rawValue),
              let streamingButton = ControllerElement(rawValue: settings.streamingRadialMenuButton?.int32Value ?? ControllerElement.null.rawValue) else {
            cancel()
            return
        }
        let localPosition = ControllerElementPosition(
            rawValue: settings.customLocalRadialMenuButtonPosition?.intValue ?? ControllerElementPosition.undefined.rawValue
        ) ?? .undefined
        let streamingPosition = ControllerElementPosition(
            rawValue: settings.customStreamingRadialMenuButtonPosition?.intValue ?? ControllerElementPosition.undefined.rawValue
        ) ?? .undefined
        ControllerNavigator.localRadialMenuButton = localButton
        ControllerNavigator.customPositionForLocalRadialMenuButton = localPosition
        ControllerNavigator.streamingRadialMenuButton = streamingButton
        ControllerNavigator.customPositionForStreamingRadialMenuButton = streamingPosition
        ControllerNavigator.streamingRadialMenuDelay = settings.streamingRadialMenuDelay?.doubleValue ?? 0
        ControllerNavigator.enabled = true
        if let settingsController = presenter as? SettingsViewController {
            ControllerNavigator.setUINavigationDelegate(settingsController)
        }
        dataManager.saveData()
        updateMessage("Finished".localized)
        cleanupControllerListener()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            ControllerNavigator.restartListening()
            self?.alertController?.dismiss(animated: false)
            self?.finish(completed: true)
        }
    }

    private func updateMessage(_ message: String) {
        alertController?.message = message
    }

    private func cleanupControllerListener() {
        controller?.extendedGamepad?.valueChangedHandler = nil
    }

    private func finish(completed: Bool) {
        guard !completionDelivered else { return }
        completionDelivered = true
        completion(completed)
    }
}

@available(iOS 13.0, *)
/// Shared settings-session coordinator. Section-specific state is being
/// migrated behind this object; new section code must not add navigation or
/// persistence responsibilities here.
private final class SettingsWeakSegmentedControl {
    weak var value: UISegmentedControl?

    init(_ value: UISegmentedControl) {
        self.value = value
    }
}

@available(iOS 13.0, *)
private final class SettingsWeakControl {
    weak var value: UIControl?

    init(_ value: UIControl) {
        self.value = value
    }
}

@available(iOS 13.0, *)
private final class SettingsWeakFavoriteLongPressTarget {
    weak var view: UIView?
    var isEnabled: Bool

    init(view: UIView, isEnabled: Bool) {
        self.view = view
        self.isEnabled = isEnabled
    }
}

@available(iOS 13.0, *)
private final class SettingsWeakSectionHitTestTarget {
    weak var view: UIView?

    init(_ view: UIView) {
        self.view = view
    }
}

@available(iOS 13.0, *)
fileprivate final class SettingsSectionInteractionState: ObservableObject {
    @Published fileprivate var allowsHitTesting = true
}

@available(iOS 13.0, *)
final class SettingsSession: NSObject, ObservableObject {
    @Published var isStreaming = false
    @Published private(set) var isGameProfileModified = false
    fileprivate let itemRegistry = SettingsItemRegistry()
    private var itemRegistryCancellable: AnyCancellable?

    fileprivate let navigationState = SettingsNavigationState()
    var highlightedID: String? {
        get { navigationState.highlightedID }
        set { navigationState.setHighlightedID(newValue) }
    }
    @Published private(set) var menuMode: SettingsMenuMode
    @Published private(set) var favoriteSettingIdentifiers: [String]
    @Published var draggedFavoriteID: SettingsItemID?
    @Published private(set) var favoritePromptHighlightedID: SettingsItemID?
    @Published private(set) var emergingHighlightIDs: Set<String> = []
    @Published var themeRevision = 0
    @Published private(set) var contentLeadingInset: CGFloat = 10
    @Published private(set) var contentTrailingInset: CGFloat = 10
    @Published private(set) var contentWidth: CGFloat = 0
    @Published private(set) var sectionFoldStates: [String: Bool]
    @Published private(set) var favoriteLongPressInteractionLockedID: SettingsItemID?
    @Published fileprivate private(set) var showsNavigationHighlight = false
    @Published fileprivate private(set) var registersNavigationAnchors = false
    private weak var navigationScrollView: UIScrollView?
    /// Rendered iOS picker controls, held weakly. These are not business
    /// state: they exist solely to replay UIKit's controller-action path.
    private var pickerControls: [SettingsItemID: SettingsWeakSegmentedControl] = [:]
    private var itemControls: [SettingsItemID: SettingsWeakControl] = [:]
    private var favoriteLongPressTargets: [SettingsItemID: SettingsWeakFavoriteLongPressTarget] = [:]
    private var sectionHitTestTargets: [String: SettingsWeakSectionHitTestTarget] = [:]
    private var sectionInteractionStates: [String: SettingsSectionInteractionState] = [:]
    private var sectionControlInteractionDisabledIDs = Set<String>()
    private var navigationAnchorRects: [String: CGRect] = [:]

    private(set) var customWidth: Int
    private(set) var customHeight: Int
    private var lastPresetResolution: Int
    private var loadedRenderingBackend: Int
    private var loadedUnlockDisplayOrientation: Bool
    private var resolvedThemeStyle: Int
    private var knownVisibleSettingIDs: Set<String> = []
    private var emergingHighlightGenerations: [String: UInt] = [:]
    private var shouldScrollToHighlightedID = true
    private var nextHighlightScrollUsesSwiftUI = false
    private var pendingNavigationAnchorScrollID: String?
    private var scheduledInitialSectionHitTestWarmUp = false
    private var pendingInitialSettingsMenuOffsetY: CGFloat?
    private var pendingInitialSettingsMenuOffsetRetryCount = 0
    private var pendingInitialSettingsMenuOffsetRetryScheduled = false
    fileprivate weak var presentingController: UIViewController?
    private var controllerNavigationSetupCoordinator: ControllerNavigationSetupCoordinator?
    private weak var capturedGyroSwitchController: GCController?
    private var activeContinuousInteractionSources: [SettingsItemID: SettingsContinuousInteractionSource] = [:]
    private var controllerContinuousInteractionEndTasks: [SettingsItemID: DispatchWorkItem] = [:]
    private var continuousInteractionPreviewSuppressedUntil: CFTimeInterval = 0
    private lazy var scrollCancellableInteractionDescriptors: [SettingsItemDescriptor] = {
        allItemDescriptors.filter { $0.continuousInteraction?.cancelsOnScroll == true }
    }()
    private var pencilPurchaseNotificationTokens: [NSObjectProtocol] = []
    private let pendingHighlightMoveLock = NSLock()
    private var pendingHighlightMoveOffset: Int?
    private var pendingHighlightMoveScheduled = false

    init(presentingController: UIViewController) {
        guard let snapshot = DataManager().getSettings() else {
            preconditionFailure("SettingsSession requires an initialized TemporarySettings snapshot")
        }
        let persistedResolution = snapshot.resolutionSelected.intValue
        let supportsHEVC = VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)
        let requestedCodec = (snapshot.value(forKey: "preferredCodec") as? NSNumber)?.intValue ?? 0

        let initialSectionFoldStates = Dictionary(uniqueKeysWithValues: settingsSectionFoldIdentifiers.map { identifier in
            let expanded = snapshot.rememberFoldState
                ? (UserDefaults.standard.object(forKey: identifier) == nil
                    ? true
                    : UserDefaults.standard.bool(forKey: identifier))
                : true
            return (identifier, expanded)
        })
        sectionFoldStates = initialSectionFoldStates

        // MARK: Video

        itemRegistry.resolution.value = persistedResolution == 5 ? 1 : min(max(persistedResolution, 0), 4)
        itemRegistry.usesCustomResolution.value = persistedResolution == 5
        lastPresetResolution = persistedResolution == 5 ? 1 : min(max(persistedResolution, 0), 4)
        customWidth = snapshot.width.intValue
        customHeight = snapshot.height.intValue
        itemRegistry.frameRate.value = [30, 60, 120].contains(snapshot.framerate.intValue) ? snapshot.framerate.intValue : 60
        let bitrateIndex = settingsBitrateIndex(for: Double(snapshot.bitrate.intValue))
        itemRegistry.bitrate.value = settingsBitrateTable[bitrateIndex]
        itemRegistry.bitrateSliderPosition.value = Double(bitrateIndex)
        itemRegistry.codec.value = requestedCodec == 0 ? (supportsHEVC ? VideoCodec.hevc.rawValue : VideoCodec.h264.rawValue) : requestedCodec
        itemRegistry.hdr.value = snapshot.enableHdr
        itemRegistry.yuv444.value = snapshot.enableYUV444
        itemRegistry.framePacing.value = snapshot.framePacingMode.intValue
        itemRegistry.streamDimensionScale.value = min(1, max(0, snapshot.streamDimensionScale.doubleValue))
        itemRegistry.frameQueueSize.value = Double(min(5, max(0, snapshot.frameQueueSize.intValue)))
        itemRegistry.asyncFrameDequeue.value = snapshot.asyncFrameDequeue
        itemRegistry.pictureInPicture.value = snapshot.enablePIP

        // MARK: Touch Control

        itemRegistry.touchMode.value = snapshot.touchMode.intValue
        itemRegistry.mousePointerVelocity.value = settingsVelocitySliderPosition(
            for: CGFloat(snapshot.mousePointerVelocityFactor.doubleValue)
        )
        itemRegistry.pointerVelocityDivider.value = snapshot.pointerVelocityModeDivider.doubleValue * 100
        itemRegistry.pointerVelocityFactor.value = settingsVelocitySliderPosition(
            for: CGFloat(snapshot.touchPointerVelocityFactor.doubleValue)
        )
        itemRegistry.delayLeftClick.value = snapshot.delayLeftClick
        itemRegistry.passthroughGestures.value = snapshot.passthroughGestures
        itemRegistry.pinchGesture.value = snapshot.enablePinch
        itemRegistry.ctrlDownForPinch.value = snapshot.ctrlDownForPinch
        itemRegistry.scrollSensitivity.value = snapshot.scrollSensitivity.doubleValue
        itemRegistry.pinchSensitivity.value = snapshot.pinchSensitivity.doubleValue
        itemRegistry.onScreenWidget.value = snapshot.onscreenControls.intValue
        itemRegistry.buttonVisualFeedback.value = snapshot.buttonVisualFeedback
        itemRegistry.trackTouchPoint.value = snapshot.touchPointTracking

        // MARK: Controller

        itemRegistry.controllerNavigation.value = snapshot.enableControllerNavigation
        itemRegistry.streamingRadialMenuDelay.value = snapshot.streamingRadialMenuDelay.doubleValue
        itemRegistry.controllerMouseVelocity.value = snapshot.controllerMousePointerVelocity.doubleValue
        itemRegistry.controllerMouseExpo.value = snapshot.controllerMouseExpo.doubleValue
        itemRegistry.swapABXY.value = snapshot.swapABXYButtons
        itemRegistry.hapticEngine.value = snapshot.hapticEngine.intValue
        itemRegistry.emulatedControllerType.value = snapshot.emulatedControllerType.intValue
        itemRegistry.gyroMode.value = snapshot.gyroMode.intValue
        itemRegistry.gyroSensitivity.value = snapshot.gyroSensitivity.doubleValue * 100

        // MARK: Drawing Toolkit

        itemRegistry.pencilTick.value = snapshot.pencilTickMode.intValue
        itemRegistry.pencilTickInterval.value = min(4000, max(1500, snapshot.pencilTickIntervalUs.doubleValue))
        itemRegistry.pencilTipOffset.value = abs(snapshot.pencilTipOffsetX.doubleValue) > 0.01
            || abs(snapshot.pencilTipOffsetY.doubleValue) > 0.01

        // MARK: Gestures

        itemRegistry.softKeyboardGesture.value = SettingsSoftKeyboardGesture(rawValue: snapshot.keyboardToggleFingers.intValue)?.rawValue
            ?? SettingsSoftKeyboardGesture.disabled.rawValue
        let slideToSettingsEdge = GestureScreenEdge.from(rawValue: snapshot.slideToSettingsScreenEdge.intValue)
        itemRegistry.slideToSettingsScreenEdge.value = slideToSettingsEdge.rawValue
        // UIKit's Toolbox selector is presentation-only. Its selection is
        // always the opposite edge and never writes a separate setting.
        itemRegistry.slideToToolboxScreenEdge.value = slideToSettingsEdge.opposite.rawValue
        itemRegistry.slideToSettingsDistance.value = min(1, max(0.02, snapshot.slideToSettingsDistance.doubleValue))
        itemRegistry.edgeSlidingSensitivity.value = min(50, max(5, snapshot.edgeSlidingSensitivity.doubleValue))

        // MARK: Peripherals

        itemRegistry.externalDisplayMode.value = snapshot.externalDisplayMode.intValue
        itemRegistry.localMousePointerMode.value = snapshot.localMousePointerMode.intValue
        itemRegistry.reverseMouseWheelDirection.value = snapshot.reverseMouseWheelDirection ? 1 : 0
        itemRegistry.citrixX1Mouse.value = snapshot.btMouseSupport
        itemRegistry.globeAsEscape.value = snapshot.globeAsEscape

        // MARK: Audio

        itemRegistry.audioOnPC.value = snapshot.playAudioOnPC
        itemRegistry.localVolume.value = min(100, max(0, snapshot.localVolume.doubleValue * 100))
        itemRegistry.redirectMic.value = snapshot.redirectMic
        itemRegistry.useBuiltinMic.value = snapshot.useBuiltinMic
        itemRegistry.micVolume.value = min(settingsMaximumMicVolumeForCurrentDevice(), max(0, snapshot.micVolume.doubleValue * 100))
        itemRegistry.duckOtherApps.value = snapshot.duckOtherApps
        itemRegistry.muteInBackground.value = snapshot.muteInBackground
        itemRegistry.audioConfig.value = settingsSanitizedAudioConfig(snapshot.audioConfig.intValue)

        // MARK: Others

        itemRegistry.statsOverlay.value = snapshot.statsOverlayLevel.intValue
        itemRegistry.unlockDisplayOrientation.value = snapshot.unlockDisplayOrientation ? 1 : 0
        itemRegistry.backgroundSessionTimer.value = Double(snapshot.backgroundSessionTimer.intValue)
        itemRegistry.appTheme.value = snapshot.appTheme.intValue
        itemRegistry.optimizeGames.value = snapshot.optimizeGames
        itemRegistry.multiController.value = snapshot.multiController
        itemRegistry.softKeyboardToolbar.value = snapshot.showKeyboardToolbar
        itemRegistry.softKeyboardHeight.value = snapshot.softKeyboardHeight
        itemRegistry.rememberFoldState.value = snapshot.rememberFoldState
        pendingInitialSettingsMenuOffsetY = snapshot.settingsMenuOffset.map { CGFloat(truncating: $0) } ?? 0

        // MARK: Experimental

        itemRegistry.relativeTouchSlideThreshold.value = snapshot.relativeTouchSlideThreshold.doubleValue
        itemRegistry.singleTapSensitivity.value = snapshot.singleTapSensitivity.doubleValue
        itemRegistry.leftClickDelay.value = snapshot.leftClickDelayMs.doubleValue
        itemRegistry.renderingBackend.value = snapshot.renderingBackend.intValue
        itemRegistry.fullColorRange.value = snapshot.fullColorRange
        itemRegistry.enableGraphs.value = snapshot.enableGraphs
        itemRegistry.sendDummyEvent.value = snapshot.sendDummyEvent

        let persistedMenuMode = SettingsMenuMode(rawValue: snapshot.settingsMenuMode.intValue) ?? .AllSettings
        menuMode = persistedMenuMode == .RemoveSettingItem ? .FavoriteSettings : persistedMenuMode
        let savedFavoriteIdentifiers = (UserDefaults.standard.array(forKey: settingsFavoriteIdentifiersKey) as? [String])
            ?? defaultFavoriteSettingIdentifiers
        favoriteSettingIdentifiers = migratedFavoriteSettingIdentifiers(savedFavoriteIdentifiers)
        draggedFavoriteID = nil
        loadedRenderingBackend = snapshot.renderingBackend.intValue
        loadedUnlockDisplayOrientation = snapshot.unlockDisplayOrientation
        let savedInterpolationMaximumDimension = snapshot.interpolationMaximumDimension.intValue
        itemRegistry.interpolationLevel.value = 1
        resolvedThemeStyle = ThemeManager.userInterfaceStyle().rawValue
        self.presentingController = presentingController
        super.init()
        itemRegistryCancellable = itemRegistry.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self else { return }
                // Item values publish before SwiftUI re-renders. Re-evaluate
                // descriptor visibility here so direct declarative bindings
                // (toggle, picker, and slider alike) share emerging highlight
                // handling without per-control setters.
                self.refreshConditionalVisibility()
                self.objectWillChange.send()
            }
        pencilPurchaseNotificationTokens = [
            NotificationCenter.default.addObserver(
                forName: AddOnProduct.PencilProPack.purchaseAbortedNotification(),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.resetPencilProItemsAfterInterruptedPurchase()
            },
            NotificationCenter.default.addObserver(
                forName: AddOnProduct.PencilProPack.purchaseSucceededNotification(),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.itemRegistry.onScreenWidget.value = OnScreenControlsLevel.custom.rawValue
                self.itemRegistry.pencilTick.value = PencilTickMode.ManualTick.rawValue
            }
        ]
        if favoriteSettingIdentifiers != savedFavoriteIdentifiers {
            UserDefaults.standard.set(favoriteSettingIdentifiers, forKey: settingsFavoriteIdentifiersKey)
        }
        itemRegistry.interpolationLevel.value = Double(FrameInterpolator.interpolationLevel(
            for: chosenDimensions,
            savedMaximumDimension: savedInterpolationMaximumDimension
        ))
        sanitizeState()
        localVolumeChanged()
        micVolumeChanged()
        // Match UIKit's settingsViewJustLoaded behavior: establish the initial
        // hidden-state baseline without flashing rows restored from persistence.
        knownVisibleSettingIDs = conditionallyVisibleSettingIDs
    }

    deinit {
        pencilPurchaseNotificationTokens.forEach(NotificationCenter.default.removeObserver)
    }

    var isActive: Bool { presentingController != nil }
    var usesMetal: Bool { itemRegistry.renderingBackend.value == SettingsRenderingBackend.metal.rawValue }
    var isAllSettings: Bool { menuMode == .AllSettings }
    var isRemovingFavorites: Bool { menuMode == .RemoveSettingItem }

    /// Settings may remain mounted beneath ProfileSelector or an alert. Those
    /// controllers own ControllerNavigator at that time, so a SwiftUI rerender
    /// must not replace their HUD with Settings' action hints.
    private var ownsControllerNavigationHUD: Bool {
        guard let settingsController = presentingController as? SettingsViewController else {
            return false
        }
        return ControllerNavigator.uiNavigationDelegate === settingsController
    }

    private func updateControllerNavigationHUDIfOwned() {
        guard ownsControllerNavigationHUD else { return }
        GamepadNavigationIllustrationHud.updateNavigationElements(navigationElements())
    }

    fileprivate func registerNavigationScrollView(_ scrollView: UIScrollView?) {
        navigationScrollView = scrollView
        restoreInitialSettingsMenuOffsetIfNeeded()
        scheduleInitialSectionHitTestWarmUpIfNeeded()
    }

    func stopSettingsScrollViewImmediately() {
        guard let scrollView = navigationScrollView else { return }
        let currentOffset = scrollView.contentOffset
        scrollView.layer.removeAllAnimations()
        scrollView.setContentOffset(currentOffset, animated: false)
    }

    fileprivate func cancelContinuousInteractionsForScrolling(force: Bool = false) {
        guard force ||
              !activeContinuousInteractionSources.isEmpty ||
              !controllerContinuousInteractionEndTasks.isEmpty else { return }
        suppressContinuousInteractionPreviewsForScrolling()
        controllerContinuousInteractionEndTasks.values.forEach { $0.cancel() }
        controllerContinuousInteractionEndTasks.removeAll()
        activeContinuousInteractionSources.removeAll()

        // Run only cached cancellation hooks so scrolling does not rebuild and
        // scan the full catalog at pan start.
        scrollCancellableInteractionDescriptors.forEach { descriptor in
            descriptor.continuousInteraction?.onCancelled?(self)
        }
    }

    fileprivate var hasContinuousInteractionsToCancelForScrolling: Bool {
        !activeContinuousInteractionSources.isEmpty ||
            !controllerContinuousInteractionEndTasks.isEmpty
    }

    fileprivate func suppressContinuousInteractionPreviewsForScrolling() {
        continuousInteractionPreviewSuppressedUntil = CACurrentMediaTime()
            + settingsContinuousInteractionScrollSuppressionDuration
    }

    private func isContinuousInteractionPreviewSuppressedForScrolling(_ item: SettingsItemDescriptor) -> Bool {
        item.continuousInteraction?.cancelsOnScroll == true &&
            CACurrentMediaTime() < continuousInteractionPreviewSuppressedUntil
    }

    fileprivate func userTouchScrollWillBegin() {
        if showsNavigationHighlight {
            // showsNavigationHighlight = false
        }
        cancelContinuousInteractionsForScrolling()
    }

    private func showNavigationHighlightForControllerNavigation() {
        showsNavigationHighlight = true
        guard !usesSwiftUIScroll,
              !registersNavigationAnchors else { return }
        registersNavigationAnchors = true
    }

    private func prepareNavigationAnchorsForMenuOpeningIfNeeded() {
        guard !usesSwiftUIScroll,
              ControllerUtil.primaryGCController != nil,
              !registersNavigationAnchors else { return }
        registersNavigationAnchors = true
    }

    private func scheduleInitialSectionHitTestWarmUpIfNeeded() {
        guard enablesSectionHitTestCulling,
              !scheduledInitialSectionHitTestWarmUp else { return }
        scheduledInitialSectionHitTestWarmUp = true
        DispatchQueue.main.asyncAfter(deadline: .now() + settingsInitialSectionHitTestWarmUpDelay) { [weak self] in
            self?.warmUpSectionHitTestStateForCurrentScrollPosition()
        }
    }

    private func warmUpSectionHitTestStateForCurrentScrollPosition() {
        guard let scrollView = navigationScrollView else { return }
        updateSectionHitTesting(for: scrollView)
        DispatchQueue.main.async { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            self.updateSectionHitTesting(for: scrollView)
        }
    }

    fileprivate func updateNavigationAnchorRects(_ anchors: [String: CGRect]) {
        guard !usesSwiftUIScroll,
              !settingsRectMapApproximatelyEqual(navigationAnchorRects, anchors) else { return }
        navigationAnchorRects = anchors
        restoreInitialSettingsMenuOffsetIfNeeded()
        if let id = pendingNavigationAnchorScrollID,
           navigationAnchorRects[id] != nil {
            pendingNavigationAnchorScrollID = nil
            scrollNavigationTargetIntoView(id)
        }
    }

    private func restoreInitialSettingsMenuOffsetIfNeeded() {
        guard let desiredY = pendingInitialSettingsMenuOffsetY,
              let scrollView = navigationScrollView else { return }

        if desiredY > 1 {
            scrollView.isHidden = true
        }

        let minimumY = -scrollView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let hasScrollableLayout = scrollView.bounds.height > 0 && scrollView.contentSize.height > scrollView.bounds.height
        let layoutCanReachDesiredOffset = maximumY + 2 >= desiredY
        if desiredY > 1,
           (!hasScrollableLayout || !layoutCanReachDesiredOffset),
           pendingInitialSettingsMenuOffsetRetryCount < 8 {
            scheduleInitialSettingsMenuOffsetRestoreRetry()
            return
        }

        let targetY = min(max(desiredY, minimumY), maximumY)
        scrollView.layer.removeAllAnimations()
        scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetY), animated: false)
        scrollView.isHidden = false
        pendingInitialSettingsMenuOffsetY = nil
        pendingInitialSettingsMenuOffsetRetryScheduled = false
        pendingInitialSettingsMenuOffsetRetryCount = 0
    }

    private func scheduleInitialSettingsMenuOffsetRestoreRetry() {
        guard !pendingInitialSettingsMenuOffsetRetryScheduled else { return }
        pendingInitialSettingsMenuOffsetRetryScheduled = true
        pendingInitialSettingsMenuOffsetRetryCount += 1
        DispatchQueue.main.async { [weak self] in
            self?.pendingInitialSettingsMenuOffsetRetryScheduled = false
            self?.restoreInitialSettingsMenuOffsetIfNeeded()
        }
    }

    fileprivate func scrollNavigationTargetIntoView(_ id: String, animated: Bool = true) {
        guard !usesSwiftUIScroll,
              let scrollView = navigationScrollView,
              let targetRect = navigationAnchorRects[id] else { return }

        let minimumY = -scrollView.adjustedContentInset.top
        let maximumY = max(
            minimumY,
            scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        )
        let targetY = min(max(targetRect.midY - scrollView.bounds.height / 2, minimumY), maximumY)
        guard abs(scrollView.contentOffset.y - targetY) > 0.5 else {
            updateSectionHitTesting(for: scrollView)
            return
        }
        cancelContinuousInteractionsForScrolling()
        scrollView.layer.removeAllAnimations()
        let targetOffset = CGPoint(x: scrollView.contentOffset.x, y: targetY)
        guard animated else {
            scrollView.setContentOffset(targetOffset, animated: false)
            updateSectionHitTesting(for: scrollView)
            return
        }

        UIView.animate(
            withDuration: 0.1,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseOut],
            animations: {
                scrollView.contentOffset = targetOffset
            },
            completion: { _ in
                self.updateSectionHitTesting(for: scrollView)
            }
        )
    }

    fileprivate func updateSectionHitTestingForCurrentScrollView() {
        guard let scrollView = navigationScrollView else { return }
        updateSectionHitTesting(for: scrollView)
    }

    var favoriteSettingIDs: [SettingsItemID] {
        var seen = Set<SettingsItemID>()
        return favoriteSettingIdentifiers.compactMap { identifier in
            guard let id = SettingsItemID.settingItem(rawValue: identifier), seen.insert(id).inserted else { return nil }
            return id
        }
    }

    // MARK: - Video

    var resolutionOptions: [SettingsPickerOption<Int>] {
        return [
            .init(value: 0, title: "720p".localized),
            .init(value: 1, title: "1080p".localized),
            .init(value: 2, title: "4K".localized, isEnabled: supportsHEVC),
            .init(value: 3, title: "Safe Area".localized),
            .init(value: 4, title: "FullScr/Window".localized)
        ]
    }

    var frameRateOptions: [SettingsPickerOption<Int>] {
        var options = [
            SettingsPickerOption(value: 30, title: "30 FPS".localized),
            SettingsPickerOption(value: 60, title: "60 FPS".localized)
        ]
        if UIScreen.main.maximumFramesPerSecond > 62 {
            options.append(.init(value: 120, title: "120 FPS".localized))
        }
        return options
    }

    var codecOptions: [SettingsPickerOption<Int>] {
        var options = [SettingsPickerOption(value: VideoCodec.h264.rawValue, title: "H.264".localized)]
        if supportsHEVC { options.append(.init(value: VideoCodec.hevc.rawValue, title: "HEVC".localized)) }
        if supportsAV1 { options.append(.init(value: VideoCodec.av1.rawValue, title: "AV1".localized)) }
        return options
    }

    var framePacingOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: FramePacingMode.off.rawValue, title: "Off".localized, isEnabled: !isStreaming),
            .init(value: FramePacingMode.legacy.rawValue, title: "Legacy".localized, isEnabled: !isStreaming),
            .init(value: FramePacingMode.queue.rawValue, title: "Queue Buffering".localized),
            .init(
                value: FramePacingMode.interpolation.rawValue,
                title: "×2 Interpolation".localized,
                isEnabled: FrameInterpolator.deviceSupportsInterpolation && !(isStreaming && itemRegistry.frameRate.value == 120)
            )
        ]
    }

    var resolutionText: String {
        "\(chosenWidth) × \(chosenHeight)"
    }

    var bitrateText: String {
        String(format: "%.1f Mbps", itemRegistry.bitrate.value / 1000)
    }

    var interpolationText: String {
        let dimensions = interpolationConfiguration.dimensions
        return "   \(dimensions.width) × \(dimensions.height)"
    }

    var streamDimensionText: String {
        let dimensions = FrameInterpolator.scaledStreamDimensions(
            presetDimensions: chosenDimensions,
            interpolationDimensions: interpolationConfiguration.dimensions,
            scale: Float(itemRegistry.streamDimensionScale.value)
        )
        return "   \(dimensions.width) × \(dimensions.height)"
    }

    var queueSizeText: String {
        Int(itemRegistry.frameQueueSize.value) == 0 ? "lowest latency".localized : "\(Int(itemRegistry.frameQueueSize.value))"
    }

    var pipEnabled: Bool {
        if #available(iOS 15.0, *) { return !isStreaming && !usesMetal }
        return false
    }

    var framePacingEnabled: Bool { !usesMetal }

    /// Single declarative source for Video row identity and state rules. The
    /// renderer, navigation registry and Favorite migration can consume this
    /// catalog without maintaining another order or visibility list.

    var videoSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.resolution,
                setValue: { session, model, newValue in
                        guard session.resolutionOptions.first(where: { $0.value == newValue })?.isEnabled == true else { return }
                        model.value = newValue
                        session.lastPresetResolution = newValue
                        session.itemRegistry.usesCustomResolution.value = false
                        session.updateBitrateForCurrentResolutionAndFrameRate()
                },
                options: { $0.resolutionOptions },
                distribution: .proportionalToContent,
                isVisible: { !$0.isStreaming },
                dynamicText: { $0.resolutionText }
            ),
            toggleItem(
                \.usesCustomResolution,
                setValue: { session, _, newValue in
                    session.setCustomResolution(newValue)
                },
                isVisible: { !$0.isStreaming }
            ),
            pickerItem(
                \.frameRate,
                setValue: { session, model, newValue in
                        guard session.frameRateOptions.contains(where: { $0.value == newValue }),
                              !(newValue == 120 && session.itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue) else { return }
                        model.value = newValue
                        session.updateBitrateForCurrentResolutionAndFrameRate()
                },
                options: { $0.frameRateOptions },
                distribution: .equal,
                isVisible: { !$0.isStreaming }
            ),
            sliderItem(
                \.bitrateSliderPosition,
                setValue: { session, _, newValue in
                    session.setBitrateSliderPosition(newValue)
                },
                range: 0...Double(settingsBitrateTable.count - 1),
                valueText: { session, _ in session.bitrateText },
                hasInfo: true,
                onNavigate: { $0.stepBitrate(forward: $1) }
            ),
            pickerItem(
                \.codec,
                setValue: { session, model, newValue in
                        guard session.codecOptions.contains(where: { $0.value == newValue }) else { return }
                        model.value = newValue
                },
                options: { $0.codecOptions },
                distribution: .equal,
                isEnabled: { !$0.isStreaming },
                onValueChanged: { session in session.sanitizeState() }
            ),
            toggleItem(
                \.hdr,
                isEnabled: {
                    !$0.isStreaming &&
                    Utils.hdrSupported() &&
                    $0.itemRegistry.codec.value != VideoCodec.h264.rawValue
                },
                hasInfo: !Utils.hdrSupported()
            ),
            toggleItem(
                \.yuv444,
                isEnabled: {
                    !$0.isStreaming &&
                    $0.itemRegistry.codec.value != VideoCodec.av1.rawValue
                },
                hasInfo: true
            ),
            pickerItem(
                \.framePacing,
                setValue: { session, _, newValue in
                    session.setFramePacing(newValue)
                },
                options: { $0.framePacingOptions },
                distribution: .proportionalToContent,
                isEnabled: { $0.framePacingEnabled },
                hasInfo: true,
                onDisabledOptionTapped: {
                    $0.handleFramePacingDisabledOptionTap($1)
                }
            ),
            sliderItem(
                \.interpolationLevel,
                range: 0...1,
                valueText: { session, _ in session.interpolationText },
                isVisible: {
                    !$0.usesMetal &&
                    $0.itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue
                },
                hasInfo: true,
                continuousInteraction: SettingsContinuousInteractionDescriptor(
                    onBegan: { session, _ in
                        session.handleInterpolationLevelEditingChanged(true)
                    },
                    onEnded: { session, _ in
                        session.handleInterpolationLevelEditingChanged(false)
                    }
                )
            ),
            sliderItem(
                \.streamDimensionScale,
                range: 0...1,
                valueText: { session, _ in session.streamDimensionText },
                isVisible: {
                    !$0.usesMetal && !$0.isStreaming &&
                    $0.itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue
                },
                hasInfo: true
            ),
            sliderItem(
                \.frameQueueSize,
                range: 0...5,
                valueText: { session, _ in session.queueSizeText },
                isVisible: {
                    !$0.usesMetal && !$0.isStreaming &&
                    $0.itemRegistry.framePacing.value == FramePacingMode.queue.rawValue
                }
            ),
            toggleItem(
                \.asyncFrameDequeue,
                isVisible: {
                    !$0.usesMetal &&
                    ($0.itemRegistry.framePacing.value == FramePacingMode.queue.rawValue ||
                     $0.itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue)
                },
                isEnabled: { !$0.isStreaming },
                hasInfo: true
            ),
            toggleItem(
                \.pictureInPicture,
                isVisible: { !$0.isStreaming },
                isEnabled: { $0.pipEnabled },
                hasInfo: true
            )
        ]
    }

    // MARK: - Touch Control

    var touchModeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: TouchMode.RelativeTouch.rawValue, title: "Touchpad".localized),
            .init(value: TouchMode.NativeTouch.rawValue, title: "Native Touch".localized),
            .init(value: TouchMode.AbsoluteTouch.rawValue, title: "Single Point".localized),
            .init(value: TouchMode.TouchDisabled.rawValue, title: "Disabled".localized)
        ]
    }

    var onScreenWidgetOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: 0, title: "Off".localized),
            .init(value: 1, title: "Custom".localized)
        ]
    }

    fileprivate var touchSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.touchMode,
                options: { $0.touchModeOptions },
                distribution: .proportionalToContent,
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { session in
                    GenericUtils.handleTouchModeChangingTip(in: session.presentingController)
                }
            ),
            sliderItem(
                \.mousePointerVelocity,
                range: 0...300,
                clampedTo: 0...300,
                valueText: { _, model in
                    let display = settingsVelocityDisplayPercent(for: model.value)
                    return "\(Int(display))%"
                },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue }
            ),
            sliderItem(
                \.pointerVelocityDivider,
                range: 0...100,
                clampedTo: 0...100,
                valueText: { _, model in
                    let divider = Int(model.value.rounded())
                    return "| \(divider)% | \(100 - divider)% |"
                },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.NativeTouch.rawValue },
                hasInfo: true,
                isGameProfileSetting: true,
                continuousInteraction: SettingsContinuousInteractionDescriptor(
                    onBegan: { session, _ in session.beginTouchPointerVelocityPreview() },
                    onChanged: { session, _ in session.showTouchPointerVelocityPreview() },
                    onEnded: { session, source in session.endTouchPointerVelocityPreview(source: source) },
                    onCancelled: { session in
                        (session.presentingController as? SettingsViewController)?.dismissTouchVelocityPreview()
                    }
                )
            ),
            sliderItem(
                \.pointerVelocityFactor,
                range: 0...300,
                clampedTo: 0...300,
                valueText: { _, model in
                    let display = settingsVelocityDisplayPercent(for: model.value)
                    return "\(Int(display))%"
                },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.NativeTouch.rawValue },
                hasInfo: true,
                isGameProfileSetting: true,
                continuousInteraction: SettingsContinuousInteractionDescriptor(
                    onBegan: { session, _ in session.beginTouchPointerVelocityPreview() },
                    onChanged: { session, _ in session.showTouchPointerVelocityPreview() },
                    onEnded: { session, source in session.endTouchPointerVelocityPreview(source: source) },
                    onCancelled: { session in
                        (session.presentingController as? SettingsViewController)?.dismissTouchVelocityPreview()
                    }
                )
            ),
            toggleItem(
                \.delayLeftClick,
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue },
                hasInfo: true
            ),
            toggleItem(
                \.passthroughGestures,
                isVisible: {$0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue}
            ),
            toggleItem(
                \.pinchGesture,
                // UIKit reveals this row with passthroughGesturesSwitchFlipped:
                // derive the same relationship directly from the source item.
                isVisible: {$0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue || ($0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue
                    && $0.itemRegistry.passthroughGestures.value)}
            ),
            toggleItem(
                \.ctrlDownForPinch,
                isVisible: {($0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue
                             && $0.itemRegistry.pinchGesture.value)
                            || ($0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue
                            && $0.itemRegistry.passthroughGestures.value
                            && $0.itemRegistry.pinchGesture.value)},
                hasInfo: true
            ),
            sliderItem(
                \.scrollSensitivity,
                range: 0...3,
                clampedTo: 0...3,
                valueText: { _, model in "\(Int((model.value * 100).rounded()))%" },
                isVisible: {$0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue || ($0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue
                    && $0.itemRegistry.passthroughGestures.value)}
            ),
            sliderItem(
                \.pinchSensitivity,
                range: 0...3,
                clampedTo: 0...3,
                valueText: { _, model in "\(Int((model.value * 100).rounded()))%" },
                isVisible: {($0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue
                             && $0.itemRegistry.pinchGesture.value)
                            || ($0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue
                            && $0.itemRegistry.passthroughGestures.value
                            && $0.itemRegistry.pinchGesture.value)},
            ),
            pickerItem(
                \.onScreenWidget,
                options: { $0.onScreenWidgetOptions },
                distribution: .equal,
                hasInfo: true,
                onValueChanged: { session in
                    guard session.itemRegistry.onScreenWidget.value == OnScreenControlsLevel.custom.rawValue, !self.isStreaming else { return }
                    session.openCustomOnScreenWidgetEditor()
                }
            ),
            toggleItem(
                \.buttonVisualFeedback,
                isVisible: { _ in true }
            ),
            toggleItem(\.trackTouchPoint)
        ]
    }

    fileprivate func openCustomOnScreenWidgetEditor() {
        guard let presenter = presentingController else { return }
        let edgeSide = GestureScreenEdge.from(rawValue: itemRegistry.slideToSettingsScreenEdge.value) == .left
            ? "left".localized
            : "right".localized
        let distance = Int((itemRegistry.slideToSettingsDistance.value * 100).rounded())
        let message = LocalizationHelper.localizedString(
            forKey: "customOscTip",
            edgeSide,
            "\(distance)%"
        )
        let openedFromStreamingMenu = (presenter.value(forKey: "mainFrameViewController") as? MainFrameViewController)?.settingsExpandedInStreamView == true

        let alert = UIAlertController(
            title: "Edit layout during streaming".localized,
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            alert?.dismiss(animated: true) {
                // Keep the original UIKit behavior: the editor opens only
                // after the instructional alert is confirmed.
                if !openedFromStreamingMenu {
                    self.presentingController?.perform(Selector(("invokeOscLayout")))
                }
            }
        })
        presenter.present(alert, animated: true)
    }

    fileprivate func showTouchPointerVelocityPreview() {
        guard let settingsController = presentingController as? SettingsViewController,
              settingsController.presentedViewController == nil,
              settingsController.view.window != nil else { return }
        settingsController.showTouchVelocityPreview(
            dividerPercent: CGFloat(itemRegistry.pointerVelocityDivider.value),
            velocityPercent: CGFloat(settingsVelocityDisplayPercent(
                for: itemRegistry.pointerVelocityFactor.value
            ))
        )
    }

    fileprivate func beginTouchPointerVelocityPreview() {
        (presentingController as? SettingsViewController)?.cancelTouchVelocityPreviewDismiss()
    }

    fileprivate func endTouchPointerVelocityPreview(source: SettingsContinuousInteractionSource) {
        guard let settingsController = presentingController as? SettingsViewController else { return }
        switch source {
        case .touch:
            settingsController.scheduleTouchVelocityPreviewDismiss()
        case .controller:
            settingsController.dismissTouchVelocityPreview()
        }
    }

    // MARK: - Controller

    private var hapticEngineOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: HapticEnginePreference.HapticEngineAuto.rawValue, title: "Auto".localized),
            .init(
                value: HapticEnginePreference.RumbleDevice.rawValue,
                title: "Built-in".localized,
                isEnabled: UIDevice.current.userInterfaceIdiom == .phone
            ),
            .init(value: HapticEnginePreference.LeftRightSwapped.rawValue, title: "L/R Swapped".localized),
            .init(value: HapticEnginePreference.RumbleOff.rawValue, title: "Disabled".localized)
        ]
    }

    private var emulatedControllerTypeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: Int(ControllerEmulation.xbox.rawValue), title: "Xbox 360".localized),
            .init(value: Int(ControllerEmulation.ps.rawValue), title: "PS".localized),
            .init(value: Int(ControllerEmulation.psEnhancedHaptic.rawValue), title: "PS (Enhanced Haptics)".localized),
            .init(value: Int(ControllerEmulation.xboxAndPs.rawValue), title: "Xbox + PS".localized)
        ]
    }

    private var gyroModeOptions: [SettingsPickerOption<Int>] {
        let supportsControllerGyro: Bool
        if #available(iOS 14.0, *) {
            supportsControllerGyro = true
        } else {
            supportsControllerGyro = false
        }
        return [
            .init(value: GyroMode.GyroModeOff.rawValue, title: "Off".localized),
            .init(value: GyroMode.GyroModeAuto.rawValue, title: "Auto".localized, isEnabled: supportsControllerGyro),
            .init(value: GyroMode.AlwaysDevice.rawValue, title: "Built-in".localized, isEnabled: CMMotionManager().isGyroAvailable),
            .init(value: GyroMode.AlwaysController.rawValue, title: "Controller".localized, isEnabled: supportsControllerGyro)
        ]
    }

    fileprivate var controllerSettingsCatalog: [SettingsItemDescriptor] {
        [
            toggleItem(
                \.controllerNavigation,
                hasInfo: true,
                onValueChanged: { session in
                    session.controllerNavigationValueChanged()
                }
            ),
            sliderItem(
                \.streamingRadialMenuDelay,
                range: 0...3,
                clampedTo: 0...3,
                valueText: { _, model in String(format: "%.1f s", model.value) },
                isVisible: { $0.itemRegistry.controllerNavigation.value }
            ),
            sliderItem(
                \.controllerMouseVelocity,
                range: 0...60,
                clampedTo: 0...60,
                valueText: { _, model in String(format: "%.1f", model.value) },
                isVisible: { $0.itemRegistry.controllerNavigation.value }
            ),
            sliderItem(
                \.controllerMouseExpo,
                range: 1...5,
                clampedTo: 1...5,
                valueText: { _, model in String(format: "%.1f", model.value) },
                isVisible: { $0.itemRegistry.controllerNavigation.value },
                hasInfo: true,
                continuousInteraction: SettingsContinuousInteractionDescriptor(
                    onBegan: { session, _ in
                        (session.presentingController as? SettingsViewController)?
                            .cancelControllerMouseCurvePreviewDismiss()
                    },
                    onChanged: { session, _ in
                        (session.presentingController as? SettingsViewController)?.showControllerMouseCurvePreview(
                            expo: CGFloat(session.itemRegistry.controllerMouseExpo.value)
                        )
                    },
                    onEnded: { session, source in
                        guard let settingsController = session.presentingController as? SettingsViewController else { return }
                        switch source {
                        case .touch:
                            settingsController.scheduleControllerMouseCurvePreviewDismiss()
                        case .controller:
                            settingsController.dismissControllerMouseCurvePreview()
                        }
                    },
                    onCancelled: { session in
                        (session.presentingController as? SettingsViewController)?
                            .dismissControllerMouseCurvePreview()
                    }
                )
            ),
            toggleItem(
                \.swapABXY
            ),
            pickerItem(
                \.hapticEngine,
                options: { $0.hapticEngineOptions },
                distribution: .proportionalToContent
            ),
            pickerItem(
                \.emulatedControllerType,
                options: { $0.emulatedControllerTypeOptions },
                distribution: .proportionalToContent,
                hasInfo: true,
                onValueChanged: { session in
                    GenericUtils.handleControllerEmulationTip(in: session.presentingController)
                }
            ),
            sliderItem(
                \.dualSenseTransient,
                range: 0...2,
                clampedTo: 0...2,
                valueText: { _, model in String(format: "%.2f", model.value) },
                isVisible: {
                    $0.itemRegistry.emulatedControllerType.value == Int(ControllerEmulation.psEnhancedHaptic.rawValue)
                },
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { session in
                    ControllerUtil.dualSenseHapticTransient = Float(session.itemRegistry.dualSenseTransient.value)
                }
            ),
            pickerItem(
                \.gyroMode,
                options: { $0.gyroModeOptions },
                distribution: .proportionalToContent,
                isVisible: {
                    $0.itemRegistry.emulatedControllerType.value != Int(ControllerEmulation.xbox.rawValue)
                },
                hasInfo: true,
                onValueChanged: { session in
                    guard session.itemRegistry.gyroMode.value != 0 else { return }
                    GenericUtils.handleEmulatedGyroModeTip(in: session.presentingController)
                }
            ),
            sliderItem(
                \.gyroSensitivity,
                range: 0...300,
                clampedTo: 0...300,
                valueText: { _, model in "\(Int(model.value.rounded()))%" },
                isVisible: { $0.itemRegistry.emulatedControllerType.value != Int(ControllerEmulation.xbox.rawValue)
                    && $0.itemRegistry.gyroMode.value != GyroMode.GyroModeOff.rawValue }
            ),
            sliderItem(
                \.leftStickMinOffset,
                range: 0...16383,
                clampedTo: 0...16383,
                valueText: { _, model in "\(Int(model.value.rounded()))" },
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { session in session.previewPhysicalStickMinimumOffset(left: true) }
            ),
            sliderItem(
                \.rightStickMinOffset,
                range: 0...16383,
                clampedTo: 0...16383,
                valueText: { _, model in "\(Int(model.value.rounded()))" },
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { session in session.previewPhysicalStickMinimumOffset(left: false) }
            )
        ]
    }

    // MARK: - Motion Control

    private var controllerGyroSwitchOptions: [SettingsPickerOption<Int>] {
        [
            .init(
                value: ControllerGyroSwitchMode.disabled.rawValue,
                title: "Disabled".localized
            ),
            .init(
                value: ControllerGyroSwitchMode.pressToToggle.rawValue,
                title: "Press-toggle".localized
            ),
            .init(
                value: ControllerGyroSwitchMode.holdDown.rawValue,
                title: "Hold down".localized
            )
        ]
    }

    private var gyroSourceOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: SettingsGyroSource.builtIn.rawValue, title: "Built-in".localized),
            .init(value: SettingsGyroSource.controller.rawValue, title: "Controller".localized)
        ]
    }

    private var mapGyroToOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: MapGyroTo.mapGyroToMouse.rawValue, title: "Mouse".localized),
            .init(value: MapGyroTo.mapGyroToControllerStick.rawValue, title: "Controller Stick".localized),
            .init(value: MapGyroTo.driftCorrection.rawValue, title: "Drift Correction".localized)
        ]
    }

    fileprivate var motionSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.controllerGyroSwitchButton,
                options: { $0.controllerGyroSwitchOptions },
                distribution: .equal,
                dynamicText: { $0.controllerGyroSwitchStatusText },
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { $0.controllerGyroSwitchModeChanged() }
            ),
            toggleItem(
                \.reverseHoldButton,
                isVisible: {
                    $0.itemRegistry.controllerGyroSwitchButton.value != ControllerGyroSwitchMode.disabled.rawValue
                },
                hasInfo: true,
                isGameProfileSetting: true
            ),
            pickerItem(
                \.gyroSource,
                options: { $0.gyroSourceOptions },
                distribution: .equal,
                isGameProfileSetting: true
            ),
            toggleItem(
                \.swapYawAndRoll,
                isVisible: { $0.itemRegistry.gyroSource.value == SettingsGyroSource.controller.rawValue },
                hasInfo: true,
                isGameProfileSetting: true
            ),
            pickerItem(
                \.mapGyroTo,
                options: { $0.mapGyroToOptions },
                distribution: .equal,
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { $0.mapGyroToChanged() }
            ),
            toggleItem(
                \.yawPitchToRightStick,
                isVisible: { $0.itemRegistry.mapGyroTo.value == MapGyroTo.mapGyroToControllerStick.rawValue },
                isGameProfileSetting: true
            ),
            toggleItem(
                \.rollToLeftStick,
                isVisible: { $0.itemRegistry.mapGyroTo.value == MapGyroTo.mapGyroToControllerStick.rawValue },
                isGameProfileSetting: true
            ),
            sliderItem(
                \.yawSensitivity,
                setValue: { session, model, newValue in
                    let value = min(300, max(0, newValue))
                    model.value = value
                    session.itemRegistry.pitchSensitivity.value = value
                },
                range: 0...300,
                valueText: { _, model in
                    "\(Int(settingsVelocityDisplayPercent(for: model.value).rounded()))%"
                },
                isVisible: {
                    let mapping = $0.itemRegistry.mapGyroTo.value
                    return mapping == MapGyroTo.mapGyroToMouse.rawValue ||
                        (mapping == MapGyroTo.mapGyroToControllerStick.rawValue && $0.itemRegistry.yawPitchToRightStick.value)
                },
                isGameProfileSetting: true
            ),
            sliderItem(
                \.pitchSensitivity,
                range: 0...300,
                clampedTo: 0...300,
                valueText: { _, model in
                    "\(Int(settingsVelocityDisplayPercent(for: model.value).rounded()))%"
                },
                isVisible: {
                    let mapping = $0.itemRegistry.mapGyroTo.value
                    return mapping == MapGyroTo.mapGyroToMouse.rawValue ||
                        (mapping == MapGyroTo.mapGyroToControllerStick.rawValue && $0.itemRegistry.yawPitchToRightStick.value)
                },
                isGameProfileSetting: true
            ),
            sliderItem(
                \.rollSensitivity,
                range: 0...300,
                clampedTo: 0...300,
                valueText: { _, model in
                    "\(Int(settingsVelocityDisplayPercent(for: model.value).rounded()))%"
                },
                isVisible: {
                    $0.itemRegistry.mapGyroTo.value == MapGyroTo.mapGyroToControllerStick.rawValue &&
                        $0.itemRegistry.rollToLeftStick.value
                },
                isGameProfileSetting: true
            ),
            sliderItem(
                \.gyroToStickMinOffset,
                range: 0...16383,
                clampedTo: 0...16383,
                valueText: { _, model in "\(Int(model.value.rounded()))" },
                isVisible: { $0.itemRegistry.mapGyroTo.value == MapGyroTo.mapGyroToControllerStick.rawValue },
                isGameProfileSetting: true,
                onValueChanged: { $0.previewGyroToStickMinimumOffset() }
            ),
            toggleItem(
                \.synthPhysicalInput,
                isVisible: { $0.itemRegistry.mapGyroTo.value == MapGyroTo.mapGyroToControllerStick.rawValue },
                isGameProfileSetting: true
            )
        ]
    }

    // MARK: - Drawing Toolkit

    private var pencilTickOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: PencilTickMode.PencilTickDisabled.rawValue, title: "Regular".localized),
            .init(value: PencilTickMode.ManualTick.rawValue, title: "HD".localized)
        ]
    }

    private var pencilModeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: PencilAndHoverMode.hoverDisabled.rawValue, title: "Hovering Disabled".localized),
            .init(value: PencilAndHoverMode.pencilOnly.rawValue, title: "Stylus".localized),
            .init(value: PencilAndHoverMode.pencilToMouse.rawValue, title: "Mouse".localized),
            .init(value: PencilAndHoverMode.pencilToTouch.rawValue, title: "Touch".localized)
        ]
    }

    fileprivate var pencilSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.pencilTick,
                options: { $0.pencilTickOptions },
                distribution: .equal,
                hasInfo: true,
                onValueChanged: { $0.pencilTickChanged() }
            ),
            sliderItem(
                \.pencilTickInterval,
                range: 1500...4000,
                clampedTo: 1500...4000,
                valueText: { _, model in "\(Int(model.value.rounded())) μs" },
                isVisible: { $0.itemRegistry.pencilTick.value == PencilTickMode.ManualTick.rawValue }
            ),
            toggleItem(
                \.pencilTipOffset,
                onValueChanged: { $0.pencilTipOffsetChanged() }
            ),
            toggleItem(
                \.pressureCurve,
                isGameProfileSetting: true,
                onValueChanged: { $0.pressureCurveChanged() }
            ),
            toggleItem(
                \.doubleTapShortcut,
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { $0.doubleTapShortcutChanged() }
            ),
            toggleItem(
                \.squeezeShortcut,
                isEnabled: { _ in
                    if #available(iOS 17.5, *) {
                        return true
                    }
                    return false
                },
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { $0.squeezeShortcutChanged() }
            ),
            pickerItem(
                \.pencilMode,
                options: { $0.pencilModeOptions },
                distribution: .proportionalToContent,
                hasInfo: true,
                isGameProfileSetting: true
            ),
            toggleItem(
                \.pencilPausesNativeTouch,
                isGameProfileSetting: true,
                onValueChanged: { $0.pencilProToggleChanged(.pencilPausesNativeTouch) }
            ),
            toggleItem(
                \.disablePencilSlideGesture,
                isGameProfileSetting: true,
                onValueChanged: { $0.pencilProToggleChanged(.disablePencilSlideGesture) }
            )
        ]
    }

    // MARK: - Gestures

    private var softKeyboardGestureOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: SettingsSoftKeyboardGesture.threeFingerTap.rawValue, title: "3 Finger Tap".localized),
            .init(value: SettingsSoftKeyboardGesture.fourFingerTap.rawValue, title: "4 Finger Tap".localized),
            .init(value: SettingsSoftKeyboardGesture.fiveFingerTap.rawValue, title: "5 Finger Tap".localized),
            .init(value: SettingsSoftKeyboardGesture.disabled.rawValue, title: "Disabled".localized)
        ]
    }

    private var streamingEdgeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: GestureScreenEdge.left.rawValue, title: "Slide From Left Edge".localized),
            .init(value: GestureScreenEdge.right.rawValue, title: "Slide From Right Edge".localized)
        ]
    }

    private func gestureSlideDistanceText(_ value: Double) -> String {
        LocalizationHelper.localizedString(forKey: "    %d%% screen width", Int((value * 100).rounded()))
    }

    private func edgeSlidingSensitivityText(_ value: Double) -> String {
        "\(Int(value.rounded()))"
    }

    var gesturesSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.softKeyboardGesture,
                setValue: { _, model, newValue in
                    guard SettingsSoftKeyboardGesture(rawValue: newValue) != nil else { return }
                    model.value = newValue
                },
                options: { $0.softKeyboardGestureOptions },
                distribution: .equal,
                hasInfo: true
            ),
            pickerItem(
                \.slideToSettingsScreenEdge,
                setValue: { session, model, newValue in
                    let edge = GestureScreenEdge.from(rawValue: newValue)
                    model.value = edge.rawValue
                    session.itemRegistry.slideToToolboxScreenEdge.value = edge.opposite.rawValue
                },
                options: { $0.streamingEdgeOptions },
                distribution: .proportionalToContent
            ),
            pickerItem(
                \.slideToToolboxScreenEdge,
                setValue: { _, _, _ in },
                options: { $0.streamingEdgeOptions },
                distribution: .proportionalToContent,
                // This selector is disabled in UIKit as well: it displays the
                // opposite of Open Settings in Streaming and is not editable.
                isEnabled: { _ in false }
            ),
            sliderItem(
                \.slideToSettingsDistance,
                range: 0.02...1,
                clampedTo: 0.02...1,
                valueText: { session, model in session.gestureSlideDistanceText(model.value) },
                hasInfo: true
            ),
            sliderItem(
                \.edgeSlidingSensitivity,
                range: 5...50,
                clampedTo: 5...50,
                valueText: { session, model in session.edgeSlidingSensitivityText(model.value) },
                hasInfo: true
            )
        ]
    }

    // MARK: - Peripherals

    var externalDisplayModeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: ExternalDisplayMode.duplicated.rawValue, title: "Duplicate".localized),
            .init(value: ExternalDisplayMode.extended.rawValue, title: "External Display Only".localized)
        ]
    }

    var localMousePointerModeOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: MousePointerMode.captured.rawValue, title: "Captured".localized),
            .init(value: MousePointerMode.hidden.rawValue, title: "Hidden".localized),
            .init(value: MousePointerMode.visible.rawValue, title: "Visible".localized)
        ]
    }

    var reverseMouseWheelDirectionOptions: [SettingsPickerOption<Int>] {
        [
            .init(value: 0, title: "Align with System".localized),
            .init(value: 1, title: "Reversed".localized)
        ]
    }

    var peripheralSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.externalDisplayMode,
                options: { $0.externalDisplayModeOptions },
                distribution: .equal,
                isVisible: { !$0.isStreaming },
                hasInfo: true
            ),
            pickerItem(
                \.localMousePointerMode,
                options: { $0.localMousePointerModeOptions },
                distribution: .equal,
                hasInfo: true
            ),
            pickerItem(
                \.reverseMouseWheelDirection,
                options: { $0.reverseMouseWheelDirectionOptions },
                distribution: .equal
            ),
            toggleItem(
                \.citrixX1Mouse
            ),
            toggleItem(
                \.globeAsEscape,
                hasInfo: true
            )
        ]
    }

    // MARK: - Audio

    private func volumePercentText(_ value: Double) -> String {
        LocalizationHelper.localizedString(forKey: "  %d%%  ", Int(value.rounded()))
    }

    var audioConfigOptions: [SettingsPickerOption<Int>] {
        var options = [
            SettingsPickerOption(
                value: AudioConfig.stereo.rawValue,
                title: "Stereo".localized
            ),
            SettingsPickerOption(
                value: AudioConfig.stereoSDL.rawValue,
                title: "Stereo(SDL)".localized
            )
        ]
        if #available(iOS 18.0, tvOS 18.0, *) {
            options.append(contentsOf: [
                SettingsPickerOption(
                    value: AudioConfig.SDL51.rawValue,
                    title: "5.1-channel".localized
                ),
                SettingsPickerOption(
                    value: AudioConfig.SDL71.rawValue,
                    title: "7.1-channel".localized
                )
            ])
        }
        return options
    }

    var audioSettingsCatalog: [SettingsItemDescriptor] {
        [
            toggleItem(
                \.audioOnPC,
                isEnabled: { _ in !self.isStreaming },
            ),
            sliderItem(
                \.localVolume,
                range: 0...100,
                clampedTo: 0...100,
                valueText: { session, model in
                    session.volumePercentText(model.value)
                },
                onValueChanged: { session in
                    session.localVolumeChanged()
                }
            ),
            toggleItem(
                \.redirectMic,
                isEnabled: { _ in !self.isStreaming },
                hasInfo: true,
                onValueChanged: { session in
                    session.redirectMicChanged()
                }
            ),
            toggleItem(
                \.useBuiltinMic,
                isVisible: { session in
                    session.itemRegistry.redirectMic.value && !self.isStreaming
                },
                hasInfo: true
            ),
            sliderItem(
                \.micVolume,
                range: 0...settingsMaximumMicVolumeForCurrentDevice(),
                clampedTo: 0...settingsMaximumMicVolumeForCurrentDevice(),
                valueText: { session, model in
                    session.volumePercentText(model.value)
                },
                isVisible: { session in
                    session.itemRegistry.redirectMic.value
                },
                onValueChanged: { session in
                    session.micVolumeChanged()
                }
            ),
            toggleItem(
                \.duckOtherApps,
                isVisible: { _ in !self.isStreaming },
            ),
            toggleItem(
                \.muteInBackground,
                onValueChanged: { session in
                    session.muteInBackgroundChanged()
                }
            ),
            pickerItem(
                \.audioConfig,
                setValue: { _, model, newValue in
                    model.value = settingsSanitizedAudioConfig(newValue)
                },
                options: { $0.audioConfigOptions },
                distribution: .proportionalToContent,
                hasInfo: true
            )
        ]
    }
    
    // MARK: - Others
    
    var statsOverlayOptions: [SettingsPickerOption<Int>] {
        let options = [
            SettingsPickerOption(
                value: StatsOverlayLevel.off.rawValue,
                title: "Off".localized
            ),
            SettingsPickerOption(
                value: StatsOverlayLevel.simplified.rawValue,
                title: "Simplified".localized
            ),
            SettingsPickerOption(
                value: StatsOverlayLevel.detailed.rawValue,
                title: "Detailed".localized
            ),
        ]
        return options
    }

    var unlockDisplayOrientationOptions: [SettingsPickerOption<Int>] {
        let options = [
            SettingsPickerOption(
                value: 0,
                title: "Disabled".localized
            ),
            SettingsPickerOption(
                value: 1,
                title: "Allowed".localized
            ),
        ]
        return options
    }
    
    var appThemeOptions: [SettingsPickerOption<Int>] {
        let options = [
            SettingsPickerOption(
                value: UIUserInterfaceStyle.unspecified.rawValue,
                title: "System".localized
            ),
            SettingsPickerOption(
                value: UIUserInterfaceStyle.light.rawValue,
                title: "Light".localized
            ),
            SettingsPickerOption(
                value: UIUserInterfaceStyle.dark.rawValue,
                title: "Dark".localized
            ),
        ]
        return options
    }

    var OthersSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.statsOverlay,
                options: { $0.statsOverlayOptions },
                distribution: .equal
            ),
            pickerItem(
                \.unlockDisplayOrientation,
                options: { $0.unlockDisplayOrientationOptions },
                distribution: .equal,
                isEnabled: { $0.unlockDisplayOrientationSelectorEnabled }
            ),
            sliderItem(
                \.backgroundSessionTimer,
                range: 0...61,
                valueText: { _, model in
                    let value = Int(model.value)
                    var labelString = LocalizationHelper.localizedString(forKey: "  keep %d min  ", value)
                    if value == 0 { labelString = "  disconnect  ".localized }
                    if value >= 61 { labelString = "  keep alive  ".localized }
                    return labelString
                }
            ),
            pickerItem(
                \.appTheme,
                options: { $0.appThemeOptions },
                distribution: .equal,
                onValueChanged: { session in
                    session.appThemeChanged()
                }
            ),
            toggleItem(
                \.optimizeGames,
                 isVisible: { _ in
                     !self.isStreaming
                 },
                hasInfo: true
            ),
            toggleItem(
                \.multiController,
                 isVisible: { _ in
                     !self.isStreaming
                 },
            ),
            toggleItem(
                \.softKeyboardToolbar
            ),
            doubleBackedToggleItem(
                \.softKeyboardHeight,
                setValue: { session, model, newValue in
                    session.softKeyboardHeightToggleChanged(isOn: newValue, model: model)
                },
                hasInfo: true
            ),
            toggleItem(
                \.rememberFoldState,
                 isVisible: { _ in
                     !self.isStreaming
                 },
                onValueChanged: { session in
                    session.rememberFoldStateChanged()
                }
            )
        ]
    }

    fileprivate var unlockDisplayOrientationSelectorEnabled: Bool {
        let infoDictionary = Bundle.main.infoDictionary
        let requiresFullScreen = (infoDictionary?["UIRequiresFullScreen"] as? NSNumber)?.boolValue ?? true
        return requiresFullScreen || PublicUtils.isIPhone
    }

    fileprivate func softKeyboardHeightToggleChanged(isOn: Bool, model: SettingsItemModel<Double>) {
        guard isOn else {
            model.value = 0
            return
        }
        guard let presenter = presentingController else { return }
        GenericUtils.autoPopSoftKeyboard = false
        GenericUtils.setVerticalScale(view: presenter.view, show: true)

        let alertController = UIAlertController(
            title: "".localized,
            message: "Enter the relative height of the soft keyboard according to the scale (make sure app is in landscape fullscreen mode):".localized,
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = "e.g. 0.45".localized
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = model.value == 0 ? nil : String(format: "%.2f", model.value)
        }
        alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel) { _ in
            GenericUtils.setVerticalScale(view: presenter.view, show: false)
        })
        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default) { _ in
            model.value = PublicUtils.toCGFloat(alertController.textFields?.first?.text ?? "")
            GenericUtils.setVerticalScale(view: presenter.view, show: false)
        })
        presenter.present(alertController, animated: true)
    }

    // MARK: - Experimental

    private var renderingBackendOptions: [SettingsPickerOption<Int>] {
        [
            SettingsPickerOption(
                value: SettingsRenderingBackend.standard.rawValue,
                title: "Standard".localized
            ),
            SettingsPickerOption(
                value: SettingsRenderingBackend.metal.rawValue,
                title: "Metal (Experimental)".localized
            )
        ]
    }

    fileprivate var experimentalSettingsCatalog: [SettingsItemDescriptor] {
        [
            pickerItem(
                \.touchMode,
                idOverride: .touchModeExperimental,
                options: { $0.touchModeOptions },
                distribution: .proportionalToContent,
                hasInfo: true,
                isGameProfileSetting: true,
                onValueChanged: { session in
                    GenericUtils.handleTouchModeChangingTip(in: session.presentingController)
                }
            ),
            sliderItem(
                \.relativeTouchSlideThreshold,
                range: 0...20,
                clampedTo: 0...20,
                valueText: { _, model in String(format: " %.1f ", model.value) },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue },
                hasInfo: true
            ),
            sliderItem(
                \.singleTapSensitivity,
                range: 0...5,
                clampedTo: 0...5,
                valueText: { _, model in String(format: "  %.1f  ", model.value) },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.RelativeTouch.rawValue }
            ),
            sliderItem(
                \.leftClickDelay,
                range: 0...1000,
                clampedTo: 0...1000,
                valueText: { _, model in "  \(Int(model.value.rounded())) ms  " },
                isVisible: { $0.itemRegistry.touchMode.value == TouchMode.AbsoluteTouch.rawValue }
            ),
            pickerItem(
                \.renderingBackend,
                options: { $0.renderingBackendOptions },
                distribution: .equal,
                 isEnabled: { _ in !self.isStreaming },
                hasInfo: true,
                onValueChanged: { session in
                    session.renderingBackendChanged()
                },
            ),
            toggleItem(
                \.fullColorRange,
                 isVisible: { _ in
                     !self.isStreaming
                 },
                isEnabled: { $0.itemRegistry.codec.value != VideoCodec.av1.rawValue }
            ),
            toggleItem(
                \.enableGraphs,
                isVisible: {
                    $0.itemRegistry.framePacing.value != FramePacingMode.off.rawValue &&
                    $0.itemRegistry.framePacing.value != FramePacingMode.legacy.rawValue
                },
                isEnabled: { $0.itemRegistry.framePacing.value == FramePacingMode.queue.rawValue },
                hasInfo: true,
                onValueChanged: { session in
                    session.performanceGraphChanged()
                }
            ),
            toggleItem(
                \.sendDummyEvent,
                 isVisible: { _ in
                     !self.isStreaming
                 },
            )
        ]
    }

    fileprivate func renderingBackendChanged() {
        sanitizeState()
        let selectedBackend = itemRegistry.renderingBackend.value
        guard selectedBackend != loadedRenderingBackend else { return }

        let applyChange = { [weak self] in
            guard let self else { return }
            let dataManager = DataManager()
            let currentSettings = dataManager.retrieveSettings()
            currentSettings?.renderingBackend = NSNumber(value: selectedBackend)
            dataManager.saveData()
            self.loadedRenderingBackend = selectedBackend
            self.persistSettings()
        }

        let revertChange = { [weak self] in
            guard let self else { return }
            self.itemRegistry.renderingBackend.value = self.loadedRenderingBackend
            self.sanitizeState()
        }

        guard selectedBackend == SettingsRenderingBackend.metal.rawValue else {
            applyChange()
            return
        }

        guard let presenter = presentingController else {
            revertChange()
            return
        }

        let alertController = UIAlertController(
            title: "Enable Metal Renderer?".localized,
            message: "metalRenderTip".localized,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Apply".localized, style: .default) { _ in
            applyChange()
        })
        alertController.addAction(UIAlertAction(title: "Learn More".localized, style: .default) { _ in
            revertChange()
            if let url = URL(string: "betterPerformanceLink".localized),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:])
            }
        })
        alertController.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel) { _ in
            revertChange()
        })
        presenter.present(alertController, animated: true)
    }

    fileprivate func performanceGraphChanged() {
        guard itemRegistry.enableGraphs.value,
              let presenter = presentingController else { return }
        let alertController = UIAlertController(
            title: "Tips".localized,
            message: "This is an experimental feature that may cause stuttering or freezing in the stream view.".localized,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK".localized, style: .default))
        presenter.present(alertController, animated: true)
    }



    // MARK: - Shared item interaction runtime

    fileprivate func sliderTouchEditingChanged(_ item: SettingsItemDescriptor, editing: Bool) {
        guard let interaction = item.continuousInteraction else { return }
        controllerContinuousInteractionEndTasks[item.id]?.cancel()
        controllerContinuousInteractionEndTasks[item.id] = nil

        if editing {
            guard activeContinuousInteractionSources[item.id] != .touch else { return }
            activeContinuousInteractionSources[item.id] = .touch
            interaction.onBegan?(self, .touch)
        } else {
            guard activeContinuousInteractionSources[item.id] == .touch else { return }
            activeContinuousInteractionSources[item.id] = nil
            interaction.onEnded?(self, .touch)
        }
    }

    fileprivate func sliderTouchValueChanged(_ item: SettingsItemDescriptor) {
        guard !isContinuousInteractionPreviewSuppressedForScrolling(item) else { return }
        item.continuousInteraction?.onChanged?(self, .touch)
    }

    fileprivate func sliderControllerValueChanged(_ item: SettingsItemDescriptor) {
        guard let interaction = item.continuousInteraction else { return }
        if activeContinuousInteractionSources[item.id] != .controller {
            activeContinuousInteractionSources[item.id] = .controller
            interaction.onBegan?(self, .controller)
        }
        interaction.onChanged?(self, .controller)

        controllerContinuousInteractionEndTasks[item.id]?.cancel()
        let itemID = item.id
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.activeContinuousInteractionSources[itemID] == .controller else { return }
            self.activeContinuousInteractionSources[itemID] = nil
            self.controllerContinuousInteractionEndTasks[itemID] = nil
            interaction.onEnded?(self, .controller)
        }
        controllerContinuousInteractionEndTasks[itemID] = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + interaction.controllerIdleInterval,
            execute: workItem
        )
    }

    // MARK: - Settings catalog root

    /// Unified item catalog consumed by navigation and other cross-section
    /// services. Sections add their items here; consumers must not know which
    /// section an accessibility identifier belongs to.
    lazy var settingsCatalog: [SettingsSectionDescriptor] = makeSettingsCatalog()

    private func makeSettingsCatalog() -> [SettingsSectionDescriptor] {
        var sections = [
            // Video
            SettingsSectionDescriptor(
                id: .video,
                titleKey: "Video",
                icon: UIImage(systemName: "waveform"),
                iconPointSize: 13,
                iconWeight: .bold,
                iconSizeConstraint: -15,
                items: videoSettingsCatalog
            ),

            // Touch Control
            SettingsSectionDescriptor(
                id: .touchController,
                titleKey: "Touch Control",
                icon: UIImage(named: "arcade.stick.console"),
                iconPointSize: 22,
                iconWeight: .regular,
                iconSizeConstraint: -13,
                itemsParticipateInControllerNavigation: false,
                items: touchSettingsCatalog
            ),

            // Controller
            SettingsSectionDescriptor(
                id: .controller,
                titleKey: "Controller",
                icon: UIImage(systemName: "gamecontroller"),
                iconPointSize: 30,
                iconWeight: .bold,
                iconSizeConstraint: -10,
                items: controllerSettingsCatalog
            ),

            // Motion Control
            SettingsSectionDescriptor(
                id: .motionControl,
                titleKey: "Motion Control",
                icon: UIImage(named: "gyroscope"),
                iconPointSize: 23,
                iconWeight: .regular,
                iconSizeConstraint: -18,
                items: motionSettingsCatalog
            ),

            // Drawing Toolkit is inserted here on iPad.

            // Gestures
            SettingsSectionDescriptor(
                id: .gestures,
                titleKey: "Gestures",
                icon: UIImage(systemName: "hand.draw"),
                iconPointSize: 23,
                iconWeight: .bold,
                iconSizeConstraint: -11.3,
                items: gesturesSettingsCatalog
            ),

            // Peripherals
            SettingsSectionDescriptor(
                id: .peripherals,
                titleKey: "Peripherals",
                icon: UIImage(named: "cable.connector.video"),
                iconPointSize: 20,
                iconWeight: .regular,
                iconSizeConstraint: -16.9,
                items: peripheralSettingsCatalog
            ),

            // Audio
            SettingsSectionDescriptor(
                id: .audio,
                titleKey: "Audio",
                icon: UIImage(named: "speaker.wave.2"),
                iconPointSize: 20,
                iconWeight: .regular,
                iconSizeConstraint: -15.7,
                items: audioSettingsCatalog
            ),

            // Others
            SettingsSectionDescriptor(
                id: .others,
                titleKey: "Others",
                icon: UIImage(systemName: "cube"),
                iconPointSize: 19.5,
                iconWeight: .bold,
                iconSizeConstraint: -17,
                items: OthersSettingsCatalog
            ),

            // Experimental
            SettingsSectionDescriptor(
                id: .experimental,
                titleKey: "Experimental",
                icon: UIImage(named: "flask"),
                iconPointSize: 19,
                iconWeight: .regular,
                iconSizeConstraint: -19,
                items: experimentalSettingsCatalog
            )
        ]
        if PublicUtils.pencilSectionAvailable {
            sections.insert(
                SettingsSectionDescriptor(
                    id: .pencil,
                    titleKey: "=drawingToolkit",
                    icon: UIImage(systemName: "pencil.and.outline"),
                    iconPointSize: 19,
                    iconWeight: .heavy,
                    iconSizeConstraint: -16.5,
                    itemsParticipateInControllerNavigation: false,
                    items: pencilSettingsCatalog
                ),
                at: 4
            )
        }
        return sections
    }

    var allItemDescriptors: [SettingsItemDescriptor] {
        settingsCatalog.flatMap(\.items)
    }

    func itemDescriptor(for accessibilityIdentifier: String) -> SettingsItemDescriptor? {
        allItemDescriptors.first { $0.id.rawValue == accessibilityIdentifier }
    }

    /// Cross-section lookup used by favorites and navigation. Keeping this
    /// on the catalog owner prevents any section renderer from knowing where
    /// an item is declared.
    func settingsItem(for id: SettingsItemID) -> SettingsItemDescriptor? {
        allItemDescriptors.first { $0.id == id }
    }

    private var supportsHEVC: Bool { VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) }
    private var supportsAV1: Bool {
        if #available(iOS 16.0, *) { return VTIsHardwareDecodeSupported(kCMVideoCodecType_AV1) }
        return false
    }

    private var chosenWidth: Int {
        if itemRegistry.usesCustomResolution.value { return max(customWidth, 256) }
        let portrait = availableDisplaySize.width < availableDisplaySize.height
        switch itemRegistry.resolution.value {
        case 0: return portrait ? 720 : 1280
        case 1: return portrait ? 1080 : 1920
        case 2: return portrait ? 2160 : 3840
        case 3: return Int(availableSafeAreaSize.width.rounded())
        case 4: return Int(availableDisplaySize.width.rounded())
        default: return max(customWidth, 256)
        }
    }

    private var chosenHeight: Int {
        if itemRegistry.usesCustomResolution.value { return max(customHeight, 256) }
        let portrait = availableDisplaySize.width < availableDisplaySize.height
        switch itemRegistry.resolution.value {
        case 0: return portrait ? 1280 : 720
        case 1: return portrait ? 1920 : 1080
        case 2: return portrait ? 3840 : 2160
        case 3: return Int(availableSafeAreaSize.height.rounded())
        case 4: return Int(availableDisplaySize.height.rounded())
        default: return max(customHeight, 256)
        }
    }

    private var targetScreen: UIScreen {
        if itemRegistry.externalDisplayMode.value == 1, UIScreen.screens.count > 1 {
            return UIScreen.screens.last ?? UIScreen.main
        }
        return presentingController?.view.window?.screen ?? UIScreen.main
    }

    private var availableDisplaySize: CGSize {
        let screen = targetScreen
        let bounds = itemRegistry.externalDisplayMode.value == 1
            ? screen.bounds
            : (presentingController?.view.window?.bounds ?? screen.bounds)
        return CGSize(width: bounds.width * screen.scale, height: bounds.height * screen.scale)
    }

    private var availableSafeAreaSize: CGSize {
        guard itemRegistry.externalDisplayMode.value != 1, let window = presentingController?.view.window else {
            return availableDisplaySize
        }
        let insets = window.safeAreaInsets
        return CGSize(
            width: (window.bounds.width - insets.left - insets.right) * window.screen.scale,
            height: window.bounds.height * window.screen.scale
        )
    }

    private var chosenDimensions: CMVideoDimensions {
        CMVideoDimensions(width: Int32(chosenWidth), height: Int32(chosenHeight))
    }

    private var interpolationConfiguration: InterpolationResolutionConfiguration {
        FrameInterpolator.resolutionConfiguration(for: chosenDimensions, level: Float(itemRegistry.interpolationLevel.value))
    }

    func setCustomResolution(_ enabled: Bool) {
        guard enabled else {
            itemRegistry.usesCustomResolution.value = false
            itemRegistry.resolution.value = lastPresetResolution
            updateBitrateForCurrentResolutionAndFrameRate()
            return
        }

        let alert = UIAlertController(
            title: "Enter Custom Resolution".localized,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField {
            $0.placeholder = "Video Width".localized
            $0.keyboardType = .numberPad
            $0.text = self.customWidth > 0 ? "\(self.customWidth)" : nil
        }
        alert.addTextField {
            $0.placeholder = "Video Height".localized
            $0.keyboardType = .numberPad
            $0.text = self.customHeight > 0 ? "\(self.customHeight)" : nil
        }
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel) { _ in
            self.itemRegistry.usesCustomResolution.value = false
        })
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default) { _ in
            guard let width = Int(alert.textFields?[0].text ?? ""),
                  let height = Int(alert.textFields?[1].text ?? ""),
                  width > 0, height > 0 else {
                self.itemRegistry.usesCustomResolution.value = false
                return
            }
            let maximum = self.supportsHEVC ? 8192 : 4096
            self.customWidth = min(maximum, max(256, width))
            self.customHeight = min(maximum, max(256, height))
            self.itemRegistry.usesCustomResolution.value = true
            self.updateBitrateForCurrentResolutionAndFrameRate()
            self.showCustomResolutionWarning()
        })
        presentingController?.present(alert, animated: true)
    }

    private func showCustomResolutionWarning() {
        let warning = UIAlertController(
            title: "Custom Resolution Selected".localized,
            message: "Custom resolutions are not officially supported by GeForce Experience, so it will not set your host display resolution. You will need to set it manually while in game.\n\nResolutions that are not supported by your client or host PC may cause streaming errors.".localized,
            preferredStyle: .alert
        )
        warning.addAction(UIAlertAction(title: "OK".localized, style: .default))
        presentingController?.present(warning, animated: true)
    }

    func setFramePacing(_ value: Int) {
        guard framePacingEnabled,
              framePacingOptions.first(where: { $0.value == value })?.isEnabled == true else { return }
        let previousValue = itemRegistry.framePacing.value
        if (value == FramePacingMode.off.rawValue || value == FramePacingMode.legacy.rawValue),
           previousValue == FramePacingMode.queue.rawValue || previousValue == FramePacingMode.interpolation.rawValue {
            let alert = UIAlertController(
                title: "Tips".localized,
                message: "\n\("legacyFramePacingTip".localized)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
            alert.addAction(UIAlertAction(title: "Confirm".localized, style: .default) { _ in
                self.applyFramePacing(value)
            })
            presentingController?.present(alert, animated: true)
            return
        }
        applyFramePacing(value)
    }

    private func applyFramePacing(_ value: Int) {
        // UIKit performs the inverse transition here: entering interpolation
        // from 120 FPS first brings FPS down to 60.
        if value == FramePacingMode.interpolation.rawValue && itemRegistry.frameRate.value == 120 {
            itemRegistry.frameRate.value = 60
        }
        itemRegistry.framePacing.value = value
        if value == FramePacingMode.interpolation.rawValue {
            GenericUtils.handleFrameInterpolationPixelFormatTip(in: presentingController)
        }
    }

    func handleFramePacingDisabledOptionTap(_ value: Int) {
        guard value == FramePacingMode.interpolation.rawValue else { return }
        _ = GenericUtils.handleFrameInterpolationAvailabilityTip(in: presentingController)
    }

    func handleInterpolationLevelEditingChanged(_ editing: Bool) {
        guard !editing else { return }
        GenericUtils.handleFrameInterpolationResolutionTip(in: presentingController)
    }

    func setBitrateSliderPosition(_ value: Double) {
        let upperBound = Double(settingsBitrateTable.count - 1)
        let clampedPosition = min(upperBound, max(0, value))
        itemRegistry.bitrateSliderPosition.value = clampedPosition
        itemRegistry.bitrate.value = settingsBitrateTable[Int(clampedPosition)]
    }

    func updateBitrateForCurrentResolutionAndFrameRate() {
        let dimensions = chosenStreamDimensionsForBitrate
        let fps = Double(itemRegistry.frameRate.value)
        let frameRateFactor = (fps <= 60 ? fps : sqrt(fps / 60) * 60) / 30
        let resolutionFactor = defaultBitrateResolutionFactor(
            pixels: Int(dimensions.width) * Int(dimensions.height)
        )
        let defaultBitrate = (resolutionFactor * frameRateFactor).rounded() * 1000
        let bitrate = min(defaultBitrate, 100_000)
        setBitrateSliderPosition(Double(settingsBitrateIndex(for: bitrate)))
    }

    private var chosenStreamDimensionsForBitrate: CMVideoDimensions {
        let presetDimensions = chosenDimensions
        guard itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue else {
            return presetDimensions
        }
        return FrameInterpolator.scaledStreamDimensions(
            presetDimensions: presetDimensions,
            interpolationDimensions: interpolationConfiguration.dimensions,
            scale: Float(itemRegistry.streamDimensionScale.value)
        )
    }

    private func defaultBitrateResolutionFactor(pixels: Int) -> Double {
        let table: [(pixels: Int, factor: Double)] = [
            (640 * 360, 1),
            (854 * 480, 2),
            (1280 * 720, 5),
            (1920 * 1080, 10),
            (2560 * 1440, 20),
            (3840 * 2160, 40)
        ]

        for index in table.indices {
            let entry = table[index]
            if pixels == entry.pixels {
                return entry.factor
            }
            if pixels < entry.pixels {
                guard index > table.startIndex else { return entry.factor }
                let lower = table[table.index(before: index)]
                let pixelRatio = Double(pixels - lower.pixels) / Double(entry.pixels - lower.pixels)
                return pixelRatio * (entry.factor - lower.factor) + lower.factor
            }
        }
        return table.last?.factor ?? 1
    }

    private func stepBitrate(forward: Bool) {
        let upperBound = Double(settingsBitrateTable.count - 1)
        setBitrateSliderPosition(
            stepped(itemRegistry.bitrateSliderPosition.value, in: 0...upperBound, forward: forward, ratio: 0.02)
        )
    }

    func toggleSection(identifier: String) {
        let nextValue = !(sectionFoldStates[identifier] ?? true)
        sectionFoldStates[identifier] = nextValue
        sectionControlInteractionDisabledIDs.remove(identifier)
        setSectionHitTestingEnabled(true, for: identifier)
        UserDefaults.standard.set(nextValue, forKey: identifier)
        normalizeHighlight()
        refreshSectionHitTestingAfterGeometryChange()
    }

    func isSectionExpanded(_ identifier: String) -> Bool {
        sectionFoldStates[identifier] ?? true
    }

    fileprivate func sectionInteractionState(for identifier: String) -> SettingsSectionInteractionState {
        if let state = sectionInteractionStates[identifier] {
            return state
        }
        let state = SettingsSectionInteractionState()
        sectionInteractionStates[identifier] = state
        return state
    }

    fileprivate func registerSectionHitTestTarget(_ view: UIView, for identifier: String) {
        guard enablesSectionHitTestCulling else { return }
        if let target = sectionHitTestTargets[identifier] {
            target.view = view
        } else {
            sectionHitTestTargets[identifier] = SettingsWeakSectionHitTestTarget(view)
        }
    }

    fileprivate func unregisterSectionHitTestTarget(_ view: UIView, for identifier: String) {
        guard sectionHitTestTargets[identifier]?.view === view else { return }
        sectionHitTestTargets[identifier] = nil
        sectionControlInteractionDisabledIDs.remove(identifier)
    }

    fileprivate func updateSectionHitTesting(for scrollView: UIScrollView) {
        guard enablesSectionHitTestCulling,
              isAllSettings,
              scrollView.window != nil else { return }

        sectionHitTestTargets = sectionHitTestTargets.filter { _, target in
            target.view?.window != nil
        }

        let viewport = scrollView
            .convert(scrollView.bounds, to: nil)
            .insetBy(
                dx: 0,
                dy: -settingsSectionHitTestViewportPadding
            )
        var nextDisabledIDs = Set<String>()
        for descriptor in settingsCatalog {
            let identifier = descriptor.id.rawValue
            guard let targetView = sectionHitTestTargets[identifier]?.view,
                  targetView.window != nil else { continue }
            let sectionRect = targetView.convert(targetView.bounds, to: nil)
            if !sectionRect.intersects(viewport) {
                nextDisabledIDs.insert(identifier)
            }
        }

        guard nextDisabledIDs != sectionControlInteractionDisabledIDs else { return }
        applySectionControlInteractionDisabledIDs(nextDisabledIDs)
    }

    private func applySectionControlInteractionDisabledIDs(_ disabledIDs: Set<String>) {
        itemControls = itemControls.filter { _, target in
            target.value?.window != nil
        }
        let newlyDisabled = disabledIDs.subtracting(sectionControlInteractionDisabledIDs)
        let newlyEnabled = sectionControlInteractionDisabledIDs.subtracting(disabledIDs)

        for descriptor in settingsCatalog where newlyDisabled.contains(descriptor.id.rawValue) {
            setControlInteractionEnabled(false, for: descriptor)
            setSectionHitTestingEnabled(false, for: descriptor.id.rawValue)
        }
        for descriptor in settingsCatalog where newlyEnabled.contains(descriptor.id.rawValue) {
            setControlInteractionEnabled(true, for: descriptor)
            setSectionHitTestingEnabled(true, for: descriptor.id.rawValue)
        }
        sectionControlInteractionDisabledIDs = disabledIDs
    }

    private func setSectionHitTestingEnabled(_ enabled: Bool, for identifier: String) {
        let state = sectionInteractionState(for: identifier)
        guard state.allowsHitTesting != enabled else { return }
        state.allowsHitTesting = enabled
    }

    private func setControlInteractionEnabled(_ enabled: Bool, for descriptor: SettingsSectionDescriptor) {
        for item in descriptor.items {
            guard let control = itemControls[item.id]?.value else { continue }
            let shouldEnable = enabled && isItemUserInteractionEnabled(item.id)
            if control.isUserInteractionEnabled != shouldEnable {
                control.isUserInteractionEnabled = shouldEnable
            }
        }
    }

    func isItemUserInteractionEnabled(_ id: SettingsItemID) -> Bool {
        favoriteLongPressInteractionLockedID != id
    }

    func lockFavoriteLongPressInteraction(for id: SettingsItemID) {
        favoriteLongPressInteractionLockedID = id
    }

    func unlockFavoriteLongPressInteraction(for id: SettingsItemID) {
        guard favoriteLongPressInteractionLockedID == id else { return }
        favoriteLongPressInteractionLockedID = nil
    }

    fileprivate func registerFavoriteLongPressTarget(
        _ view: UIView,
        for id: SettingsItemID,
        isEnabled: Bool
    ) {
        if let target = favoriteLongPressTargets[id] {
            target.view = view
            target.isEnabled = isEnabled
        } else {
            favoriteLongPressTargets[id] = SettingsWeakFavoriteLongPressTarget(
                view: view,
                isEnabled: isEnabled
            )
        }
    }

    fileprivate func unregisterFavoriteLongPressTarget(_ view: UIView, for id: SettingsItemID) {
        guard favoriteLongPressTargets[id]?.view === view else { return }
        favoriteLongPressTargets[id] = nil
    }

    fileprivate func favoriteLongPressTarget(
        at point: CGPoint,
        in coordinateView: UIView
    ) -> (id: SettingsItemID, view: UIView)? {
        guard isAllSettings else { return nil }
        pruneFavoriteLongPressTargets()
        for (id, target) in favoriteLongPressTargets {
            guard target.isEnabled,
                  let view = target.view,
                  view.window != nil else { continue }
            let localPoint = coordinateView.convert(point, to: view)
            guard view.bounds.contains(localPoint) else { continue }
            return (id, view)
        }
        return nil
    }

    fileprivate func isExcludedFavoriteControlTouch(_ view: UIView?) -> Bool {
        var current = view
        while let candidate = current {
            if candidate is UIButton || candidate is UISwitch {
                return true
            }
            current = candidate.superview
        }
        return false
    }

    private func pruneFavoriteLongPressTargets() {
        favoriteLongPressTargets = favoriteLongPressTargets.filter { _, target in
            target.view != nil
        }
    }

    func updateStreamingState(_ streaming: Bool, menuIsOpening: Bool) {
        if menuIsOpening {
            // A new menu presentation starts a fresh game-profile edit
            // session. The previous session was already persisted when the
            // menu was dismissed.
            isGameProfileModified = false
        }
        updateConditionalVisibility(suppressEmerging: menuIsOpening) {
            isStreaming = streaming
            let remembersFoldState = DataManager().getSettings()?.rememberFoldState ?? false
            if menuIsOpening, !remembersFoldState {
                settingsSectionFoldIdentifiers.forEach { sectionFoldStates[$0] = true }
            }
            sanitizeState()
        }
        normalizeHighlight()
        if menuIsOpening {
            prepareNavigationAnchorsForMenuOpeningIfNeeded()
        }
    }

    func refreshTheme() {
        let style = ThemeManager.userInterfaceStyle().rawValue
        guard style != resolvedThemeStyle else { return }
        resolvedThemeStyle = style
        themeRevision &+= 1
    }

    func forceRefreshTheme() {
        resolvedThemeStyle = ThemeManager.userInterfaceStyle().rawValue
        themeRevision &+= 1
    }

    func refreshGeometry() {
        themeRevision &+= 1
    }

    func refreshSectionHitTestingAfterGeometryChange() {
        guard enablesSectionHitTestCulling,
              let scrollView = navigationScrollView else { return }
        DispatchQueue.main.async { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            self.updateSectionHitTesting(for: scrollView)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self, weak scrollView] in
            guard let self, let scrollView else { return }
            self.updateSectionHitTesting(for: scrollView)
        }
    }

    func updateContentInsets(
        safeAreaInsets: UIEdgeInsets,
        interfaceOrientation: UIInterfaceOrientation,
        viewBounds: CGRect,
        safeAreaLayoutFrame: CGRect
    ) {
        let leading: CGFloat
        let trailing: CGFloat
        let width: CGFloat
        if UIDevice.current.userInterfaceIdiom == .phone, interfaceOrientation == .landscapeRight {
            // Match SettingsViewController.updateParentStackHorizontalConstraints:
            // parentStack.leading = view.safeAreaLayoutGuide.leading
            // parentStack.width = view.safeAreaLayoutGuide.width - 10
            leading = safeAreaLayoutFrame.minX
            trailing = 0
            width = max(0, safeAreaLayoutFrame.width - 10)
        } else {
            leading = 10
            trailing = 0
            width = max(0, viewBounds.width - 20)
        }

        guard abs(contentLeadingInset - leading) > 0.5 ||
                abs(contentTrailingInset - trailing) > 0.5 ||
                abs(contentWidth - width) > 0.5 else { return }
        contentLeadingInset = leading
        contentTrailingInset = trailing
        contentWidth = width
        restoreInitialSettingsMenuOffsetIfNeeded()
    }

    func reloadFromPersistence() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.reloadFromPersistence() }
            return
        }
        refreshTheme()
        reloadGameProfileSettings()
    }

    /// SwiftUI counterpart of `reloadGameProfileConfigs`. Only items already
    /// present in the SwiftUI catalog are synchronized here. Assigning the
    /// item models directly refreshes declarative visibility without going
    /// through user actions or marking the profile dirty.
    private func reloadGameProfileSettings() {
        let profile = OSCProfilesManager.sharedManager(CGRect.zero).getSelectedProfile()
        let storedTouchMode = Int(profile.touchMode)
        let displayedTouchMode = storedTouchMode == TouchMode.NativeTouchOnly.rawValue
            ? TouchMode.NativeTouch.rawValue
            : storedTouchMode

        // MARK: Touch Control

        itemRegistry.touchMode.value = displayedTouchMode
        itemRegistry.pointerVelocityDivider.value = min(
            100,
            max(0, Double(profile.pointerVelocityModeDivider) * 100)
        )
        itemRegistry.pointerVelocityFactor.value = min(
            300,
            max(0, settingsVelocitySliderPosition(for: profile.touchPointerVelocityFactor))
        )

        // MARK: Controller

        itemRegistry.dualSenseTransient.value = min(2, max(0, Double(profile.dualSenseTransient)))
        itemRegistry.leftStickMinOffset.value = min(16383, max(0, Double(profile.physicalLeftStickMinOffset)))
        itemRegistry.rightStickMinOffset.value = min(16383, max(0, Double(profile.physicalRightStickMinOffset)))

        // MARK: Motion Control

        itemRegistry.controllerGyroSwitchButton.value = Int(profile.controllerGyroSwitchMode)
        itemRegistry.reverseHoldButton.value = profile.reverseGyroHoldButton
        itemRegistry.gyroSource.value = profile.useBuiltinGyro
            ? SettingsGyroSource.builtIn.rawValue
            : SettingsGyroSource.controller.rawValue
        itemRegistry.swapYawAndRoll.value = profile.swapYawAndRoll
        itemRegistry.mapGyroTo.value = profile.mapGyroTo.rawValue
        itemRegistry.yawPitchToRightStick.value = profile.yawPitchToRightStick
        itemRegistry.rollToLeftStick.value = profile.rollToLeftStick
        itemRegistry.yawSensitivity.value = min(300, max(0, settingsVelocitySliderPosition(for: profile.gyroSensitivityYaw)))
        itemRegistry.pitchSensitivity.value = min(300, max(0, settingsVelocitySliderPosition(for: profile.gyroSensitivityPitch)))
        itemRegistry.rollSensitivity.value = min(300, max(0, settingsVelocitySliderPosition(for: profile.gyroSensitivityRoll)))
        itemRegistry.gyroToStickMinOffset.value = min(16383, max(0, profile.gyroToStickMinOffset))
        itemRegistry.synthPhysicalInput.value = profile.synthesizePhysicalStick

        // MARK: Drawing Toolkit

        itemRegistry.pressureCurve.value = profile.pressureCurveEnabled
        itemRegistry.doubleTapShortcut.value = profile.doubleTapShorcutEnabled
        itemRegistry.squeezeShortcut.value = profile.squeezeShorcutEnabled
        itemRegistry.pencilMode.value = profile.pencilAndHoverMode.rawValue
        itemRegistry.pencilPausesNativeTouch.value = profile.pencilPausesNativeTouch
        itemRegistry.disablePencilSlideGesture.value = profile.disablePencilSlideGestures
        ControllerUtil.dualSenseHapticTransient = Float(itemRegistry.dualSenseTransient.value)
        isGameProfileModified = false
        refreshConditionalVisibility()
    }

    /// Persists the complete settings session. The legacy ObjC selector below
    /// remains only as an integration bridge; persistence itself is not
    /// section-specific.
    func persistSettings() {

        if isStreaming,
           let settingsController = presentingController as? SettingsViewController,
           let mainFrameController = settingsController.mainFrameViewController {
            _ = mainFrameController.request(forBitrate: Int(itemRegistry.bitrate.value.rounded()))
        }

        let dataManager = DataManager()

        persistGameProfileSettingsIfNeeded()
        guard let settings = dataManager.retrieveSettings() else { return }
        let interpolationConfiguration = self.interpolationConfiguration
        let backgroundSessionTimerValue = itemRegistry.backgroundSessionTimer.value >= 61
            ? Int(INT16_MAX)
            : Int(itemRegistry.backgroundSessionTimer.value)
        let settingsMenuOffset = itemRegistry.rememberFoldState.value
            ? (navigationScrollView?.contentOffset.y ?? 0)
            : 0

        // MARK: Video

        settings.width = NSNumber(value: isStreaming ? customWidth : chosenWidth)
        settings.height = NSNumber(value: isStreaming ? customHeight : chosenHeight)
        settings.resolutionSelected = NSNumber(value: itemRegistry.usesCustomResolution.value ? 5 : itemRegistry.resolution.value)
        settings.framerate = NSNumber(value: itemRegistry.frameRate.value)
        settings.bitrate = NSNumber(value: Int(itemRegistry.bitrate.value.rounded()))
        settings.preferredCodec = Int32(itemRegistry.codec.value)
        settings.enableHdr = itemRegistry.hdr.value
        settings.enableYUV444 = itemRegistry.yuv444.value
        settings.framePacingMode = NSNumber(value: itemRegistry.framePacing.value)
        settings.interpolationMaximumDimension = NSNumber(value: interpolationConfiguration.maximumDimension)
        settings.interpolationMaximumPixelCount = NSNumber(value: interpolationConfiguration.maximumPixelCount)
        settings.streamDimensionScale = NSNumber(value: itemRegistry.streamDimensionScale.value)
        settings.frameQueueSize = NSNumber(value: Int(itemRegistry.frameQueueSize.value))
        settings.asyncFrameDequeue = itemRegistry.asyncFrameDequeue.value
        settings.enablePIP = itemRegistry.pictureInPicture.value

        // MARK: Touch Control

        settings.touchMode = NSNumber(value: itemRegistry.touchMode.value)
        settings.mousePointerVelocityFactor = NSNumber(value: settingsVelocityFactor(for: itemRegistry.mousePointerVelocity.value))
        settings.pointerVelocityModeDivider = NSNumber(value: itemRegistry.pointerVelocityDivider.value / 100)
        settings.touchPointerVelocityFactor = NSNumber(value: settingsVelocityFactor(for: itemRegistry.pointerVelocityFactor.value))
        settings.delayLeftClick = itemRegistry.delayLeftClick.value
        settings.passthroughGestures = itemRegistry.passthroughGestures.value
        settings.enablePinch = itemRegistry.pinchGesture.value
        settings.ctrlDownForPinch = itemRegistry.ctrlDownForPinch.value
        settings.scrollSensitivity = NSNumber(value: itemRegistry.scrollSensitivity.value)
        settings.pinchSensitivity = NSNumber(value: itemRegistry.pinchSensitivity.value)
        settings.onscreenControls = NSNumber(value: itemRegistry.onScreenWidget.value)
        settings.buttonVisualFeedback = itemRegistry.buttonVisualFeedback.value
        settings.touchPointTracking = itemRegistry.trackTouchPoint.value

        // MARK: Controller

        settings.enableControllerNavigation = itemRegistry.controllerNavigation.value
        settings.streamingRadialMenuDelay = NSNumber(value: itemRegistry.streamingRadialMenuDelay.value)
        settings.controllerMousePointerVelocity = NSNumber(value: itemRegistry.controllerMouseVelocity.value)
        settings.controllerMouseExpo = NSNumber(value: itemRegistry.controllerMouseExpo.value)
        settings.swapABXYButtons = itemRegistry.swapABXY.value
        settings.hapticEngine = NSNumber(value: itemRegistry.hapticEngine.value)
        settings.emulatedControllerType = NSNumber(value: itemRegistry.emulatedControllerType.value)
        settings.gyroMode = NSNumber(value: itemRegistry.gyroMode.value)
        settings.gyroSensitivity = NSNumber(value: itemRegistry.gyroSensitivity.value / 100)

        // MARK: Motion Control

        // Motion Control currently stores its game-profile-owned values in
        // persistGameProfileSettingsIfNeeded().

        // MARK: Drawing Toolkit

        settings.pencilTickMode = NSNumber(value: itemRegistry.pencilTick.value)
        settings.pencilTickIntervalUs = NSNumber(value: itemRegistry.pencilTickInterval.value)

        // MARK: Gestures

        settings.keyboardToggleFingers = NSNumber(value: itemRegistry.softKeyboardGesture.value)
        settings.slideToSettingsScreenEdge = NSNumber(value: itemRegistry.slideToSettingsScreenEdge.value)
        settings.slideToSettingsDistance = NSNumber(value: itemRegistry.slideToSettingsDistance.value)
        settings.edgeSlidingSensitivity = NSNumber(value: itemRegistry.edgeSlidingSensitivity.value)

        // MARK: Peripherals

        settings.externalDisplayMode = NSNumber(value: itemRegistry.externalDisplayMode.value)
        settings.localMousePointerMode = NSNumber(value: itemRegistry.localMousePointerMode.value)
        settings.reverseMouseWheelDirection = itemRegistry.reverseMouseWheelDirection.value == 1
        settings.btMouseSupport = itemRegistry.citrixX1Mouse.value
        settings.globeAsEscape = itemRegistry.globeAsEscape.value

        // MARK: Audio

        settings.playAudioOnPC = itemRegistry.audioOnPC.value
        settings.localVolume = NSNumber(value: itemRegistry.localVolume.value / 100)
        settings.redirectMic = itemRegistry.redirectMic.value && MicHandler.permissionGranted()
        settings.useBuiltinMic = itemRegistry.useBuiltinMic.value
        settings.micVolume = NSNumber(value: itemRegistry.micVolume.value / 100)
        settings.duckOtherApps = itemRegistry.duckOtherApps.value
        settings.muteInBackground = itemRegistry.muteInBackground.value
        settings.audioConfig = NSNumber(value: settingsSanitizedAudioConfig(itemRegistry.audioConfig.value))

        // MARK: Others

        settings.statsOverlayLevel = NSNumber(value: itemRegistry.statsOverlay.value)
        settings.statsOverlayEnabled = itemRegistry.statsOverlay.value != StatsOverlayLevel.off.rawValue
        settings.unlockDisplayOrientation = itemRegistry.unlockDisplayOrientation.value == 1
        settings.backgroundSessionTimer = NSNumber(value: backgroundSessionTimerValue)
        settings.appTheme = NSNumber(value: itemRegistry.appTheme.value)
        settings.optimizeGames = itemRegistry.optimizeGames.value
        settings.multiController = itemRegistry.multiController.value
        settings.showKeyboardToolbar = itemRegistry.softKeyboardToolbar.value
        settings.softKeyboardHeight = Float(itemRegistry.softKeyboardHeight.value)
        settings.rememberFoldState = itemRegistry.rememberFoldState.value
        settings.settingsMenuOffset = NSNumber(value: Double(settingsMenuOffset))

        // MARK: Experimental

        settings.relativeTouchSlideThreshold = NSNumber(value: itemRegistry.relativeTouchSlideThreshold.value)
        settings.singleTapSensitivity = NSNumber(value: itemRegistry.singleTapSensitivity.value)
        settings.leftClickDelayMs = NSNumber(value: itemRegistry.leftClickDelay.value)
        settings.renderingBackend = NSNumber(value: itemRegistry.renderingBackend.value)
        settings.fullColorRange = itemRegistry.fullColorRange.value
        settings.enableGraphs = itemRegistry.enableGraphs.value
        settings.sendDummyEvent = itemRegistry.sendDummyEvent.value

        dataManager.saveData()

        if itemRegistry.bitrate.value >= 50_000 {
            GenericUtils.handleFirstSettingHighBitrate(in: presentingController) {
                if AlertControllerUtil.actionCancelled {
                    PublicUtils.openUrl("awdlTipLink".localized)
                }
            }
        }
    }

    fileprivate func markGameProfileItemChanged(_ item: SettingsItemDescriptor) {
        if item.isGameProfileSetting { isGameProfileModified = true }
    }

    private var settingsExpandedInStreamView: Bool {
        guard let settingsController = presentingController as? SettingsViewController else {
            return false
        }
        return settingsController.mainFrameViewController?.settingsExpandedInStreamView == true
    }

    fileprivate func localVolumeChanged() {
        guard settingsExpandedInStreamView else { return }
        Connection.setVolume(Float(itemRegistry.localVolume.value / 100))
    }

    fileprivate func micVolumeChanged() {
        guard settingsExpandedInStreamView else { return }
        MicHandler.setVolume(Float(itemRegistry.micVolume.value / 100))
    }

    fileprivate func redirectMicChanged() {
        guard itemRegistry.redirectMic.value else { return }
        if !MicHandler.permissionGranted() {
            MicHandler.requestPermission(nil)
        }
    }

    fileprivate func muteInBackgroundChanged() {
        Connection.muteInBackground = itemRegistry.muteInBackground.value
    }
    
    fileprivate func appThemeChanged() {
        ThemeManager.setUserInterfaceStyle(UIUserInterfaceStyle(rawValue: itemRegistry.appTheme.value) ?? .unspecified)
        let dataManager = DataManager()
        let currentSettings = dataManager.retrieveSettings()
        currentSettings?.appTheme = NSNumber(value: itemRegistry.appTheme.value);
        dataManager.saveData()
    }

    fileprivate func rememberFoldStateChanged() {
        MenuSectionView.overridePersistedFoldState = !itemRegistry.rememberFoldState.value
        let dataManager = DataManager()
        let currentSettings = dataManager.retrieveSettings()
        currentSettings?.rememberFoldState = itemRegistry.rememberFoldState.value
        dataManager.saveData()
    }

    /// Persists only the Game Profile-owned item models. This is shared by
    /// normal menu closing and the pre-Profile-Selector save path.
    func persistGameProfileSettingsIfNeeded() {
        guard isGameProfileModified else { return }
        saveModifiedGameProfileItems()
        isGameProfileModified = false
    }

    private func saveModifiedGameProfileItems() {
        let profileManager = OSCProfilesManager.sharedManager(CGRect.zero)
        let profile = profileManager.getSelectedProfile()

        // MARK: Touch Control

        profile.touchMode = Int32(itemRegistry.touchMode.value)
        profile.pointerVelocityModeDivider = CGFloat(itemRegistry.pointerVelocityDivider.value / 100)
        profile.touchPointerVelocityFactor = settingsVelocityFactor(
            for: itemRegistry.pointerVelocityFactor.value
        )

        // MARK: Controller

        profile.dualSenseTransient = CGFloat(itemRegistry.dualSenseTransient.value)
        profile.physicalLeftStickMinOffset = itemRegistry.leftStickMinOffset.value.rounded()
        profile.physicalRightStickMinOffset = itemRegistry.rightStickMinOffset.value.rounded()

        // MARK: Motion Control

        profile.controllerGyroSwitchMode = Int32(itemRegistry.controllerGyroSwitchButton.value)
        profile.reverseGyroHoldButton = itemRegistry.reverseHoldButton.value
        profile.useBuiltinGyro = itemRegistry.gyroSource.value == SettingsGyroSource.builtIn.rawValue
        profile.swapYawAndRoll = itemRegistry.swapYawAndRoll.value
        profile.mapGyroTo = MapGyroTo(rawValue: itemRegistry.mapGyroTo.value) ?? .mapGyroToMouse
        profile.yawPitchToRightStick = itemRegistry.yawPitchToRightStick.value
        profile.rollToLeftStick = itemRegistry.rollToLeftStick.value
        profile.gyroSensitivityYaw = settingsVelocityFactor(for: itemRegistry.yawSensitivity.value)
        profile.gyroSensitivityPitch = settingsVelocityFactor(for: itemRegistry.pitchSensitivity.value)
        profile.gyroSensitivityRoll = settingsVelocityFactor(for: itemRegistry.rollSensitivity.value)
        profile.gyroToStickMinOffset = itemRegistry.gyroToStickMinOffset.value.rounded()
        profile.synthesizePhysicalStick = itemRegistry.synthPhysicalInput.value

        // MARK: Drawing Toolkit

        profile.pressureCurveEnabled = itemRegistry.pressureCurve.value
        profile.doubleTapShorcutEnabled = itemRegistry.doubleTapShortcut.value
        profile.squeezeShorcutEnabled = itemRegistry.squeezeShortcut.value
        profile.pencilAndHoverMode = PencilAndHoverMode(rawValue: itemRegistry.pencilMode.value) ?? .pencilOnly
        profile.pencilPausesNativeTouch = itemRegistry.pencilPausesNativeTouch.value
        profile.disablePencilSlideGestures = itemRegistry.disablePencilSlideGesture.value
        profileManager.replaceSelectedProfile(with: profile, overwriteDefault: true)
    }

    fileprivate func controllerNavigationValueChanged() {
        guard itemRegistry.controllerNavigation.value else {
            controllerNavigationSetupCoordinator?.cancel()
            controllerNavigationSetupCoordinator = nil
            return
        }
        itemRegistry.swapABXY.value = false
        let coordinator = ControllerNavigationSetupCoordinator(
            presenter: presentingController,
            completion: { [weak self] completed in
                guard let self else { return }
                if !completed {
                    self.itemRegistry.controllerNavigation.value = false
                }
                self.controllerNavigationSetupCoordinator = nil
            }
        )
        controllerNavigationSetupCoordinator = coordinator
        coordinator.start()
    }

    fileprivate func previewPhysicalStickMinimumOffset(left: Bool) {
        let leftOffset = left ? Int16(itemRegistry.leftStickMinOffset.value.rounded()) : 0
        let rightOffset = left ? 0 : Int16(itemRegistry.rightStickMinOffset.value.rounded())
        LiSendControllerEvent(0, 0, 0, leftOffset, 0, rightOffset, 0)
        ControllerUtil.gamepadArrivalReported = true
    }

    fileprivate func previewGyroToStickMinimumOffset() {
        let offset = Int16(itemRegistry.gyroToStickMinOffset.value.rounded())
        LiSendControllerEvent(
            0, 0, 0,
            itemRegistry.rollToLeftStick.value ? offset : 0,
            0,
            itemRegistry.yawPitchToRightStick.value ? offset : 0,
            0
        )
        ControllerUtil.gamepadArrivalReported = true
    }

    fileprivate var controllerGyroSwitchStatusText: String {
        let profile = OSCProfilesManager.sharedManager(CGRect.zero).getSelectedProfile()
        let nullButton = ControllerElement.null.rawValue
        let hasHold = profile.controllerGyroSwitchHold != nullButton
        let hasToggle = profile.controllerGyroSwitchToggle != nullButton
        if hasHold && hasToggle {
            return profile.controllerGyroSwitchHold == profile.controllerGyroSwitchToggle
                ? " duplicated ! ".localized
                : " both set ".localized
        }
        return ""
    }

    fileprivate func controllerGyroSwitchModeChanged() {
        let rawMode = itemRegistry.controllerGyroSwitchButton.value
        guard let mode = ControllerGyroSwitchMode(rawValue: rawMode), mode != .disabled else { return }
        presentGyroSwitchCapture(for: mode)
    }

    private func presentGyroSwitchCapture(for mode: ControllerGyroSwitchMode) {
        guard let presenter = presentingController else { return }
        guard let controller = GCController.controllers().first(where: { $0.extendedGamepad != nil }) else {
            let persistedMode = Int(OSCProfilesManager.sharedManager(CGRect.zero).getSelectedProfile().controllerGyroSwitchMode)
            AlertControllerUtil.showAlert(
                in: presenter,
                title: "",
                message: "Waiting for controller...".localized,
                withCancel: true,
                buttonTitle: "Continue".localized,
                countdown: 3,
                action: {},
                completion: { [weak self] in
                    guard let self else { return }
                    if AlertControllerUtil.actionCancelled {
                        self.itemRegistry.controllerGyroSwitchButton.value = persistedMode
                    } else {
                        AlertControllerUtil.alertController.dismiss(animated: false) {
                            self.presentGyroSwitchCapture(for: mode)
                        }
                    }
                }
            )
            return
        }

        let isToggle = mode == .pressToToggle
        let captureMessage = (isToggle
            ? "Press a button for switching gyro on & off with a press.\nYou can have 2 buttons for both press-toggle & hold-down switch."
            : "Press a button for keeping gyro active by holding down.\nYou can have 2 buttons for both press-toggle & hold-down switch.").localized
        let disableButtonTitle = (isToggle
            ? "Disable press-toggle button"
            : "Disable hold-down button").localized
        var switchButtonCaptured = false
        AlertControllerUtil.showAlert(
            in: presenter,
            title: "Gyro button on controller".localized,
            message: captureMessage,
            withCancel: false,
            buttonTitle: disableButtonTitle,
            countdown: 0,
            action: { [weak self, weak controller] in
                guard let self, let controller else { return }
                let confirmAction = AlertControllerUtil.alertController.actions.first
                self.capturedGyroSwitchController = controller
                ControllerUtil.stopListeningPrimaryController(stopListenToRadialMenuButton: true)
                ControllerUtil.listen(controller: controller, swapABXY: false) { [weak self] elementDict, gamepad, _ in
                    var capturedRawValue: Int32?
                    for case let key as NSNumber in elementDict.allKeys {
                        guard let button = elementDict[key] as? GCControllerButtonInput, button.isPressed else { continue }
                        capturedRawValue = key.int32Value
                        break
                    }
                    guard let capturedRawValue else { return }
                    DispatchQueue.main.async {
                        guard let self, !switchButtonCaptured else { return }
                        let currentNavControls = ControllerNavigator.uiNavigationDelegate?.getNavigationElements().map { $0.control }
                        let disableTapped = currentNavControls?.contains(ControllerElement(rawValue: capturedRawValue) ?? .null) == true
                        switchButtonCaptured = !disableTapped
                        self.capturedGyroSwitchController = controller
                        gamepad.valueChangedHandler = nil
                        let manager = OSCProfilesManager.sharedManager(CGRect.zero)
                        let profile = manager.getSelectedProfile()
                        if isToggle {
                            profile.controllerGyroSwitchToggle = capturedRawValue
                        } else {
                            profile.controllerGyroSwitchHold = capturedRawValue
                        }
                        manager.replaceSelectedProfile(with: profile, overwriteDefault: true)
                        AlertControllerUtil.alertController.message = "Finished".localized
                        AlertControllerUtil.alertController.actions.forEach { $0.isEnabled = false }
                        confirmAction?.setValue("OK".localized, forKey: "title")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            AlertControllerUtil.alertController.dismiss(animated: false) {
                                AlertControllerUtil.completion?()
                            }
                        }
                    }
                }
            },
            completion: { [weak self] in
                guard let self else { return }
                let manager = OSCProfilesManager.sharedManager(CGRect.zero)
                let profile = manager.getSelectedProfile()
                if !switchButtonCaptured {
                    if isToggle {
                        profile.controllerGyroSwitchToggle = ControllerElement.null.rawValue
                    } else {
                        profile.controllerGyroSwitchHold = ControllerElement.null.rawValue
                    }
                    manager.replaceSelectedProfile(with: profile, overwriteDefault: true)
                }
                self.normalizeControllerGyroSwitchMode(using: profile)
            }
        )
    }

    private func stopGyroSwitchCapture() {
        capturedGyroSwitchController?.extendedGamepad?.valueChangedHandler = nil
        capturedGyroSwitchController = nil
        ControllerNavigator.restartListening()
    }

    private func normalizeControllerGyroSwitchMode(using profile: OSCProfile) {
        stopGyroSwitchCapture()
        let nullButton = ControllerElement.null.rawValue
        let hasHold = profile.controllerGyroSwitchHold != nullButton
        let hasToggle = profile.controllerGyroSwitchToggle != nullButton
        if hasHold && hasToggle && profile.controllerGyroSwitchHold == profile.controllerGyroSwitchToggle {
            itemRegistry.controllerGyroSwitchButton.value = ControllerGyroSwitchMode.disabled.rawValue
        } else if hasToggle && !hasHold {
            itemRegistry.controllerGyroSwitchButton.value = ControllerGyroSwitchMode.pressToToggle.rawValue
        } else if hasHold && !hasToggle {
            itemRegistry.controllerGyroSwitchButton.value = ControllerGyroSwitchMode.holdDown.rawValue
        } else if !hasHold && !hasToggle {
            itemRegistry.controllerGyroSwitchButton.value = ControllerGyroSwitchMode.disabled.rawValue
        }
        objectWillChange.send()
    }

    fileprivate func mapGyroToChanged() {
        guard itemRegistry.mapGyroTo.value == MapGyroTo.driftCorrection.rawValue,
              let presenter = presentingController else { return }
        
        let profile = OSCProfilesManager.sharedManager(CGRect.zero).getSelectedProfile()
        let previousIndex = itemRegistry.mapGyroTo.previousSelectedIndex
        guard mapGyroToOptions.indices.contains(previousIndex) else {
            // Drift Correction is entered through this picker, whose UIKit
            // bridge records the old segment before publishing the new one.
            // Do not fall back to persisted profile data as a second rollback
            // source when the item has never been presented.
            assertionFailure("Map Gyro to is missing its previous selected index")
            return
        }
        let previousMapping = mapGyroToOptions[previousIndex].value
        
        AlertControllerUtil.showAlert(
            in: presenter,
            title: "Drift Correction".localized,
            message: "Place the device flat on a surface and keep it still, then tap ‘Start’.".localized,
            withCancel: true,
            buttonTitle: "Start".localized,
            countdown: 0,
            completion: {
                if AlertControllerUtil.actionCancelled {
                    self.itemRegistry.mapGyroTo.value = previousMapping
                }
                else {
                    let calibrationProfile = (profile.mutableCopy() as? OSCProfile) ?? profile
                    calibrationProfile.useBuiltinGyro = self.itemRegistry.gyroSource.value == SettingsGyroSource.builtIn.rawValue
                    let motionHandler = MotionHandler.shared(profile: calibrationProfile)
                    motionHandler.calibrateGyroBias(duration: 5) {
                        let dataManager = DataManager()
                        guard let settings = dataManager.retrieveSettings() else { return }
                        let useBuiltin = self.itemRegistry.gyroSource.value == SettingsGyroSource.builtIn.rawValue
                        let prefix = useBuiltin ? "gyroBias" : "controllerGyroBias"
                        settings.setValue(NSNumber(value: useBuiltin ? motionHandler.gyroBiasX : motionHandler.controllerGyroBiasX), forKey: "\(prefix)X")
                        settings.setValue(NSNumber(value: useBuiltin ? motionHandler.gyroBiasY : motionHandler.controllerGyroBiasY), forKey: "\(prefix)Y")
                        settings.setValue(NSNumber(value: useBuiltin ? motionHandler.gyroBiasZ : motionHandler.controllerGyroBiasZ), forKey: "\(prefix)Z")
                        dataManager.saveData()
                    }
                    AlertControllerUtil.alertController.dismiss(animated: true, completion: {
                        AlertControllerUtil.showAlert(in: presenter,
                                                      title: "Drift Correction".localized,
                                                      message: "Calibrating...".localized,
                                                      withCancel: false,
                                                      buttonTitle: "Finished!".localized,
                                                      countdown: 6,
                                                      completion: {
                            self.itemRegistry.mapGyroTo.value = previousMapping
                        })
                    })
                }
            })
    }

    fileprivate func pencilTickChanged() {
        guard itemRegistry.pencilTick.value == PencilTickMode.ManualTick.rawValue else { return }
        requirePencilPro(rollback: { [weak self] in
            self?.itemRegistry.pencilTick.value = PencilTickMode.PencilTickDisabled.rawValue
        })
    }

    fileprivate func pencilTipOffsetChanged() {
        guard itemRegistry.pencilTipOffset.value,
              let presenter = presentingController else { return }
        let calibrationController = PencilTipOffsetCalibrationViewController()
        calibrationController.modalPresentationStyle = .overFullScreen
        presenter.definesPresentationContext = true
        presenter.present(calibrationController, animated: true)
    }

    fileprivate func pressureCurveChanged() {
        guard itemRegistry.pressureCurve.value,
              let presenter = presentingController else { return }
        let curveController = PressureCurveViewController()
        curveController.modalPresentationStyle = .overFullScreen
        presenter.definesPresentationContext = true
        presenter.present(curveController, animated: true)
    }

    fileprivate func doubleTapShortcutChanged() {
        guard itemRegistry.doubleTapShortcut.value else { return }
        requirePencilPro(rollback: { [weak self] in
            self?.itemRegistry.doubleTapShortcut.value = false
        }, onValid: { [weak self] in
            guard let presenter = self?.presentingController else { return }
            PencilHandler.enterDoubleTapShortcuts(in: presenter)
        })
    }

    fileprivate func squeezeShortcutChanged() {
        guard itemRegistry.squeezeShortcut.value else { return }
        requirePencilPro(rollback: { [weak self] in
            self?.itemRegistry.squeezeShortcut.value = false
        }, onValid: { [weak self] in
            guard let presenter = self?.presentingController else { return }
            PencilHandler.enterSqueezeShortcuts(in: presenter)
        })
    }

    fileprivate func pencilProToggleChanged(_ itemID: SettingsItemID) {
        let isOn: Bool
        let rollback: () -> Void
        switch itemID {
        case .pencilPausesNativeTouch:
            isOn = itemRegistry.pencilPausesNativeTouch.value
            rollback = { [weak self] in self?.itemRegistry.pencilPausesNativeTouch.value = false }
        case .disablePencilSlideGesture:
            isOn = itemRegistry.disablePencilSlideGesture.value
            rollback = { [weak self] in self?.itemRegistry.disablePencilSlideGesture.value = false }
        default:
            return
        }
        guard isOn else { return }
        requirePencilPro(rollback: rollback)
    }

    private func resetPencilProItemsAfterInterruptedPurchase() {
        itemRegistry.pencilTick.value = PencilTickMode.PencilTickDisabled.rawValue
        itemRegistry.pressureCurve.value = false
        itemRegistry.doubleTapShortcut.value = false
        itemRegistry.squeezeShortcut.value = false
        itemRegistry.pencilPausesNativeTouch.value = false
        itemRegistry.disablePencilSlideGesture.value = false
        itemRegistry.pencilTipOffset.value = false
    }

    /// Mirrors the UIKit Pencil Pro gate. StoreKit 2 does not exist before
    /// iOS 15, so that path rolls the just-changed model back immediately and
    /// presents the same low-OS explanation instead of waiting for a purchase
    /// notification that cannot succeed.
    private func requirePencilPro(
        rollback: @escaping () -> Void,
        onValid: @escaping () -> Void = {}
    ) {
        guard let presenter = presentingController else {
            rollback()
            return
        }
        guard #available(iOS 15.0, *) else {
            rollback()
            AlertControllerUtil.showAlert(
                in: presenter,
                title: "",
                message: "PencilProPackLowOSVersionTip".localized,
                withCancel: false,
                buttonTitle: "OK".localized,
                countdown: 0
            )
            return
        }
        IAPManager.checkPurchaseInfo(.PencilProPack) { info in
            if info.valid {
                onValid()
            } else {
                IAPManager.inAppPurchaseAction(viewController: presenter, product: .PencilProPack)
            }
        }
    }

    @objc func applyClosingRuntimeEffects() {
        let unlockDisplayOrientation = itemRegistry.unlockDisplayOrientation.value == 1
        if loadedUnlockDisplayOrientation != unlockDisplayOrientation,
           let settingsController = presentingController as? SettingsViewController {
            settingsController.mainFrameViewController?.setNeedsUpdateAllowedOrientation()
            loadedUnlockDisplayOrientation = unlockDisplayOrientation
        }
        
        if ControllerNavigator.radialMenuView?.superview != nil {
            ControllerNavigator.updateRadialMenu()
        }

        if itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue {
            VideoDecoderRenderer.startOrRestartFrameInterpolation()
        } else {
            VideoDecoderRenderer.stopFrameInterpolation()
        }
    }

    private func sanitizeState() {
        if itemRegistry.codec.value == VideoCodec.h264.rawValue || !Utils.hdrSupported() { itemRegistry.hdr.value = false }
        if itemRegistry.codec.value == VideoCodec.av1.rawValue {
            itemRegistry.yuv444.value = false
            itemRegistry.fullColorRange.value = false
        } else {
            itemRegistry.fullColorRange.value = true
        }
        if usesMetal {
            itemRegistry.framePacing.value = FramePacingMode.queue.rawValue
            itemRegistry.pictureInPicture.value = false
        }
        if !pipEnabled { itemRegistry.pictureInPicture.value = false }
        if itemRegistry.frameRate.value == 120 && itemRegistry.framePacing.value == FramePacingMode.interpolation.rawValue {
            itemRegistry.frameRate.value = 60
        }
    }

    private var conditionallyVisibleSettingIDs: Set<String> {
        Set(allItemDescriptors.compactMap { item in
            item.isVisible(self) ? item.id.rawValue : nil
        })
    }

    func isVisible(_ id: SettingsItemID) -> Bool {
        conditionallyVisibleSettingIDs.contains(id.rawValue)
    }

    func isEnabled(_ id: SettingsItemID) -> Bool {
        settingsItem(for: id)?.isEnabled(self) ?? false
    }

    private func favoriteIdentifier(for id: SettingsItemID) -> String? {
        id.rawValue
    }

    func setMenuMode(_ newMode: SettingsMenuMode) {
        menuMode = newMode
        if newMode != .RemoveSettingItem {
            let dataManager = DataManager()
            if let settings = dataManager.retrieveSettings() {
                settings.settingsMenuMode = NSNumber(value: newMode.rawValue)
                dataManager.saveData()
            }
        }
        normalizeHighlight()
        updateControllerNavigationHUDIfOwned()
    }

    func requestAddFavorite(for id: SettingsItemID, anchorRect: CGRect) {
        guard menuMode == .AllSettings,
              let identifier = favoriteIdentifier(for: id),
              let presentingController,
              presentingController.presentedViewController == nil else { return }

        favoritePromptHighlightedID = id
        let actionSheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Add to favorite".localized, style: .default) { [weak self] _ in
            self?.addFavorite(identifier: identifier, showFeedback: true)
            self?.unlockFavoriteLongPressInteraction(for: id)
            self?.favoritePromptHighlightedID = nil
        })
        actionSheet.addAction(UIAlertAction(
            title: UIDevice.current.userInterfaceIdiom == .phone ? "Cancel".localized : "",
            style: .cancel
        ) { [weak self] _ in
            self?.unlockFavoriteLongPressInteraction(for: id)
            self?.favoritePromptHighlightedID = nil
        })
        if let popover = actionSheet.popoverPresentationController {
            popover.sourceView = presentingController.view
            let visibleAnchor = anchorRect.intersection(presentingController.view.bounds)
            popover.sourceRect = visibleAnchor.isNull || visibleAnchor.isEmpty
                ? CGRect(x: presentingController.view.bounds.midX,
                         y: presentingController.view.bounds.midY,
                         width: 1,
                         height: 1)
                : visibleAnchor
        }
        presentingController.present(actionSheet, animated: true)
    }

    func requestAddFavorite(for id: SettingsItemID, globalAnchorRect: CGRect) {
        guard let presentingView = presentingController?.view else { return }
        requestAddFavorite(
            for: id,
            anchorRect: presentingView.convert(globalAnchorRect, from: nil)
        )
    }

    func performFavoriteDoublePress() {
        guard let highlightedID,
              let id = SettingsItemID.settingItem(rawValue: highlightedID),
              let identifier = favoriteIdentifier(for: id) else { return }

        switch menuMode {
        case .AllSettings:
            addFavorite(identifier: identifier, showFeedback: true)
        case .FavoriteSettings:
            removeFavorite(identifier: identifier)
        default:
            break
        }
    }

    func removeFavorite(_ id: SettingsItemID) {
        guard let identifier = favoriteIdentifier(for: id) else { return }
        removeFavorite(identifier: identifier)
    }

    private func addFavorite(identifier: String, showFeedback: Bool) {
        if favoriteSettingIdentifiers.contains(identifier) {
            if showFeedback { showFavoriteFeedback(message: "Setting already in favorites".localized) }
            return
        }
        if identifier == SettingsItemID.resolution.rawValue || identifier == SettingsItemID.customResolution.rawValue,
           !favoriteSettingIdentifiers.contains("resolutionStack") {
            favoriteSettingIdentifiers.append("resolutionStack")
        }
        favoriteSettingIdentifiers.append(identifier)
        saveFavoriteIdentifiers()

        if showFeedback { showFavoriteFeedback(message: "Setting added to favorite".localized) }
    }

    private func showFavoriteFeedback(message: String) {
        guard let presentingController else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak presentingController] in
            guard let presentingController,
                  presentingController.presentedViewController == nil else { return }
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            presentingController.present(alert, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak alert] in
                alert?.dismiss(animated: true)
            }
        }
    }

    private func removeFavorite(identifier: String) {
        let oldVisibleIDs = visibleNavigationIDs
        let removedTargetIndex = highlightedID.flatMap { oldVisibleIDs.firstIndex(of: $0) } ?? 0
        favoriteSettingIdentifiers.removeAll { $0 == identifier }
        if identifier == SettingsItemID.resolution.rawValue || identifier == SettingsItemID.customResolution.rawValue,
           !favoriteSettingIdentifiers.contains(SettingsItemID.resolution.rawValue),
           !favoriteSettingIdentifiers.contains(SettingsItemID.customResolution.rawValue) {
            favoriteSettingIdentifiers.removeAll { $0 == "resolutionStack" }
        }
        saveFavoriteIdentifiers()

        let ids = visibleNavigationIDs
        guard !ids.isEmpty else {
            clearHighlight()
            return
        }
        applyHighlight(ids[min(max(removedTargetIndex - 1, 0), ids.count - 1)])
    }

    func moveHighlightedFavorite(by offset: Int) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.moveHighlightedFavorite(by: offset)
            }
            return
        }
        guard menuMode == .FavoriteSettings,
              let highlightedID,
              let id = SettingsItemID.settingItem(rawValue: highlightedID),
              let identifier = favoriteIdentifier(for: id),
              let sourceIndex = favoriteSettingIdentifiers.firstIndex(of: identifier) else { return }

        let visibleFavoriteIdentifiers = favoriteSettingIDs
            .filter { isVisible($0) }
            .map(\.rawValue)
        guard let visibleIndex = visibleFavoriteIdentifiers.firstIndex(of: identifier) else { return }
        let destinationVisibleIndex = visibleIndex + offset
        guard visibleFavoriteIdentifiers.indices.contains(destinationVisibleIndex),
              let destinationIndex = favoriteSettingIdentifiers.firstIndex(of: visibleFavoriteIdentifiers[destinationVisibleIndex]) else { return }

        favoriteSettingIdentifiers.remove(at: sourceIndex)
        favoriteSettingIdentifiers.insert(identifier, at: destinationIndex)
        saveFavoriteIdentifiers()
        applyHighlight(identifier, scrollIntoView: false)
    }

    func moveDraggedFavorite(over destination: SettingsItemID) {
        guard menuMode == .FavoriteSettings,
              let source = draggedFavoriteID,
              source != destination,
              let sourceIndex = favoriteSettingIdentifiers.firstIndex(of: source.rawValue),
              let destinationIndex = favoriteSettingIdentifiers.firstIndex(of: destination.rawValue) else { return }

        favoriteSettingIdentifiers.remove(at: sourceIndex)
        favoriteSettingIdentifiers.insert(source.rawValue, at: min(destinationIndex, favoriteSettingIdentifiers.count))
        saveFavoriteIdentifiers()
    }

    private func saveFavoriteIdentifiers() {
        let resolutionIDs = [SettingsItemID.resolution.rawValue, SettingsItemID.customResolution.rawValue]
        favoriteSettingIdentifiers.removeAll { $0 == "resolutionStack" }
        if let firstResolutionIndex = favoriteSettingIdentifiers.firstIndex(where: { resolutionIDs.contains($0) }) {
            favoriteSettingIdentifiers.insert("resolutionStack", at: firstResolutionIndex)
        }
        let splitLegacyItems: [(legacy: String, replacements: [String])] = [
            // Motion Control: old UIKit combined stack became two independent rows.
            ("gyroToStickStack", [SettingsItemID.yawPitchToRightStick.rawValue, SettingsItemID.rollToLeftStick.rawValue]),

            // Motion Control: old UIKit combined stack became two independent rows.
            ("yawPitchSensitivityStack", [SettingsItemID.yawSensitivity.rawValue, SettingsItemID.pitchSensitivity.rawValue])
        ]
        for split in splitLegacyItems {
            favoriteSettingIdentifiers.removeAll { $0 == split.legacy }
            if let firstIndex = favoriteSettingIdentifiers.firstIndex(where: { split.replacements.contains($0) }) {
                favoriteSettingIdentifiers.insert(split.legacy, at: firstIndex)
            }
        }
        UserDefaults.standard.set(favoriteSettingIdentifiers, forKey: settingsFavoriteIdentifiersKey)
    }

    private func updateConditionalVisibility(suppressEmerging: Bool = false, _ mutation: () -> Void) {
        let previouslyVisible = knownVisibleSettingIDs
        mutation()
        let currentlyVisible = conditionallyVisibleSettingIDs
        knownVisibleSettingIDs = currentlyVisible
        if suppressEmerging {
            resetEmergingHighlights(toVisibleIDs: currentlyVisible)
            return
        }

        for id in previouslyVisible.subtracting(currentlyVisible) {
            emergingHighlightGenerations[id, default: 0] &+= 1
            emergingHighlightIDs.remove(id)
        }
        for id in currentlyVisible.subtracting(previouslyVisible) {
            highlightEmergingSetting(id)
        }
    }

    private func refreshConditionalVisibility(suppressEmerging: Bool = false) {
        let previouslyVisible = knownVisibleSettingIDs
        let currentlyVisible = conditionallyVisibleSettingIDs
        guard previouslyVisible != currentlyVisible else {
            if suppressEmerging {
                resetEmergingHighlights(toVisibleIDs: currentlyVisible)
            }
            return
        }
        knownVisibleSettingIDs = currentlyVisible
        if suppressEmerging {
            resetEmergingHighlights(toVisibleIDs: currentlyVisible)
            return
        }

        for id in previouslyVisible.subtracting(currentlyVisible) {
            emergingHighlightGenerations[id, default: 0] &+= 1
            emergingHighlightIDs.remove(id)
        }
        for id in currentlyVisible.subtracting(previouslyVisible) {
            highlightEmergingSetting(id)
        }
    }

    private func resetEmergingHighlights(toVisibleIDs visibleIDs: Set<String>) {
        for id in emergingHighlightIDs.union(visibleIDs) {
            emergingHighlightGenerations[id, default: 0] &+= 1
        }
        emergingHighlightIDs.removeAll()
    }

    private func highlightEmergingSetting(_ id: String) {
        emergingHighlightGenerations[id, default: 0] &+= 1
        let generation = emergingHighlightGenerations[id] ?? 0

        // The newly inserted SwiftUI row must first render clear, matching the
        // UIKit order: unhide/layout, then animate its background color.
        DispatchQueue.main.async { [weak self] in
            guard let self,
                  self.knownVisibleSettingIDs.contains(id),
                  self.emergingHighlightGenerations[id] == generation else { return }
            self.emergingHighlightIDs.insert(id)
            DispatchQueue.main.asyncAfter(deadline: .now() + settingsEmergingHighlightPhaseDuration) { [weak self] in
                guard let self,
                      self.emergingHighlightGenerations[id] == generation else { return }
                self.emergingHighlightIDs.remove(id)
            }
        }
    }

    func showInfo(for id: SettingsItemID, isGameProfileSetting: Bool = false) {
        let content = settingsLegacyHelpByStackIdentifier[id.rawValue]
        guard content != nil || isGameProfileSetting else { return }
        var message: String
        if id == .controllerGyroSwitchButton {
            let profile = OSCProfilesManager.sharedManager(CGRect.zero).getSelectedProfile()
            message = LocalizationHelper.localizedString(
                forKey: "controllerGyroSwitchButtonStackTip",
                (ControllerElement(rawValue: profile.controllerGyroSwitchToggle) ?? .null).displayName,
                (ControllerElement(rawValue: profile.controllerGyroSwitchHold) ?? .null).displayName,
            )
        } else if id == .controllerNavigation, let snapshot = DataManager().getSettings() {
            message = LocalizationHelper.localizedString(
                forKey: "controllerNavigationStackTip",
                (ControllerElement(rawValue: snapshot.localRadialMenuButton.int32Value) ?? .null).displayName,
                (ControllerElement(rawValue: snapshot.streamingRadialMenuButton.int32Value) ?? .null).displayName,
                (ControllerElement(rawValue: snapshot.controllerMouseStick.int32Value) ?? .null).displayName,
                (ControllerElement(rawValue: snapshot.controllerMouseLeftButton.int32Value) ?? .null).displayName,
                (ControllerElement(rawValue: snapshot.controllerMouseRightButton.int32Value) ?? .null).displayName
            )
        } else {
            message = content?.messageKey.localized ?? ""
        }
        if isGameProfileSetting {
            // Keep the same dynamic text as `infoButtonTapped:` in the
            // UIKit controller, but use the current item models rather than a
            // stale persisted snapshot while this menu remains open.
            let edgeSide = GestureScreenEdge.from(rawValue: itemRegistry.slideToSettingsScreenEdge.value) == .left
                ? "left".localized
                : "right".localized
            let distance = Int((itemRegistry.slideToSettingsDistance.value * 100).rounded())
            let gameProfileMessage = LocalizationHelper.localizedString(
                forKey: "gameProfileStackTip",
                edgeSide,
                "\(distance)%"
            )
            message = message.isEmpty ? gameProfileMessage : "\(gameProfileMessage)\n\n\(message)"
        }
        let alert = UIAlertController(
            title: "Tips".localized,
            message: message,
            preferredStyle: .alert
        )
        if let urlKey = content?.learnMoreURLKey {
            alert.addAction(UIAlertAction(title: "Learn More".localized, style: .cancel) { _ in
                PublicUtils.openUrl(urlKey.localized)
            })
        }
        alert.addAction(UIAlertAction(title: "OK".localized, style: .default))
        presentingController?.present(alert, animated: true)
    }

    private var allSettingsNavigationIDs: [String] {
        settingsCatalog.flatMap { descriptor -> [String] in
            var ids = ["sectionHeader-\(descriptor.id.rawValue)"]
            guard isSectionExpanded(descriptor.id.rawValue),
                  descriptor.itemsParticipateInControllerNavigation else {
                return ids
            }
            ids.append(
                contentsOf: descriptor.items.compactMap { item in
                    guard item.isVisible(self), item.isEnabled(self) else { return nil }
                    return item.id.rawValue
                }
            )
            return ids
        }
    }

    private var visibleNavigationIDs: [String] {
        guard menuMode != .AllSettings else { return allSettingsNavigationIDs }
        return favoriteSettingIDs.compactMap { id -> String? in
            guard isVisible(id), isEnabled(id) else { return nil }
            return id.rawValue
        }
    }

    private var completeNavigationOrderForHighlightRestoration: [String] {
        guard menuMode == .AllSettings else {
            return favoriteSettingIDs.map(\.rawValue)
        }

        return settingsCatalog.flatMap { descriptor -> [String] in
            var ids = ["sectionHeader-\(descriptor.id.rawValue)"]
            if descriptor.itemsParticipateInControllerNavigation {
                ids.append(contentsOf: descriptor.items.map { $0.id.rawValue })
            }
            return ids
        }
    }

    func moveHighlight(by offset: Int) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.moveHighlight(by: offset)
            }
            return
        }
        showNavigationHighlightForControllerNavigation()
        schedulePendingHighlightMove(by: offset)
    }

    func cancelPendingHighlightMoves() {
        pendingHighlightMoveLock.lock()
        pendingHighlightMoveOffset = nil
        pendingHighlightMoveScheduled = false
        pendingHighlightMoveLock.unlock()
    }

    private func schedulePendingHighlightMove(by offset: Int) {
        pendingHighlightMoveLock.lock()
        pendingHighlightMoveOffset = offset
        guard !pendingHighlightMoveScheduled else {
            pendingHighlightMoveLock.unlock()
            return
        }
        pendingHighlightMoveScheduled = true
        pendingHighlightMoveLock.unlock()

        DispatchQueue.main.async { [weak self] in
            self?.performPendingHighlightMove()
        }
    }

    private func performPendingHighlightMove() {
        pendingHighlightMoveLock.lock()
        let offset = pendingHighlightMoveOffset
        pendingHighlightMoveOffset = nil
        pendingHighlightMoveScheduled = false
        pendingHighlightMoveLock.unlock()

        guard let offset, isActive else { return }
        performHighlightMove(by: offset)
    }

    private func performHighlightMove(by offset: Int) {
        let ids = visibleNavigationIDs
        guard !ids.isEmpty else { return }
        let current = highlightedID.flatMap { ids.firstIndex(of: $0) }
        let index = current.map { ($0 + offset + ids.count) % ids.count } ?? (offset >= 0 ? 0 : ids.count - 1)
        applyHighlight(ids[index])
    }

    func applyHighlight(
        _ id: String?,
        scrollIntoView: Bool = true,
        restoreScrollUsingSwiftUI: Bool = false
    ) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.applyHighlight(
                    id,
                    scrollIntoView: scrollIntoView,
                    restoreScrollUsingSwiftUI: restoreScrollUsingSwiftUI
                )
            }
            return
        }
        if scrollIntoView && !restoreScrollUsingSwiftUI {
            showNavigationHighlightForControllerNavigation()
        } else {
            showsNavigationHighlight = true
        }
        shouldScrollToHighlightedID = scrollIntoView
        nextHighlightScrollUsesSwiftUI = scrollIntoView && restoreScrollUsingSwiftUI
        let previousHighlightedID = highlightedID
        let splitLegacyHighlightTargets = [
            // Video: legacy favorite/highlight ID now maps to the first split row.
            "resolutionStack": SettingsItemID.resolution.rawValue,

            // Motion Control: legacy combined stacks now map to the first split row.
            "gyroToStickStack": SettingsItemID.yawPitchToRightStick.rawValue,
            "yawPitchSensitivityStack": SettingsItemID.yawSensitivity.rawValue
        ]
        let restoredID = id.flatMap { splitLegacyHighlightTargets[$0] ?? $0 }
        highlightedID = restoredID.flatMap { visibleNavigationIDs.contains($0) ? $0 : nil }
            ?? nearestVisibleNavigationIDAbove(restoredID)
            ?? nearestVisibleNavigationIDAbove(id)
            ?? visibleNavigationIDs.first
        if scrollIntoView,
           !usesSwiftUIScroll,
           !restoreScrollUsingSwiftUI,
           let highlightedID,
           navigationAnchorRects[highlightedID] == nil {
            pendingNavigationAnchorScrollID = highlightedID
        }
        if previousHighlightedID == highlightedID {
            if scrollIntoView {
                navigationState.highlightedIDDidChange.send(highlightedID)
            } else {
                shouldScrollToHighlightedID = true
                nextHighlightScrollUsesSwiftUI = false
            }
        }
        ControllerNavigator.controllerNavigationHighlightedView = nil
        updateControllerNavigationHUDIfOwned()
    }

    private func nearestVisibleNavigationIDAbove(_ persistedID: String?) -> String? {
        guard let persistedID else { return nil }
        let legacyOrder = completeNavigationOrderForHighlightRestoration
        guard let index = legacyOrder.firstIndex(of: persistedID) else { return nil }

        let visibleIDs = Set(visibleNavigationIDs)
        if index > legacyOrder.startIndex {
            for candidate in legacyOrder[..<index].reversed() where visibleIDs.contains(candidate) {
                return candidate
            }
        }

        return nil
    }

    private func normalizeHighlight() {
        guard let highlightedID, !visibleNavigationIDs.contains(highlightedID) else { return }
        applyHighlight(highlightedID)
    }

    fileprivate func registerPickerControl(_ control: UISegmentedControl?, for itemID: SettingsItemID) {
        guard let control else {
            pickerControls[itemID] = nil
            registerItemControl(nil, for: itemID)
            return
        }
        pickerControls[itemID] = SettingsWeakSegmentedControl(control)
        registerItemControl(control, for: itemID)
    }

    fileprivate func registerItemControl(_ control: UIControl?, for itemID: SettingsItemID) {
        guard let control else {
            itemControls[itemID] = nil
            return
        }
        itemControls[itemID] = SettingsWeakControl(control)
        if let sectionID = sectionIdentifier(containing: itemID) {
            let shouldEnable = !sectionControlInteractionDisabledIDs.contains(sectionID) &&
                isItemUserInteractionEnabled(itemID)
            if control.isUserInteractionEnabled != shouldEnable {
                control.isUserInteractionEnabled = shouldEnable
            }
        }
    }

    private func sectionIdentifier(containing itemID: SettingsItemID) -> String? {
        settingsCatalog.first { descriptor in
            descriptor.items.contains { $0.id == itemID }
        }?.id.rawValue
    }

    func operateHighlighted(forward: Bool) {
        guard let raw = highlightedID else { return }
        if raw.hasPrefix("sectionHeader-") {
            let identifier = String(raw.dropFirst("sectionHeader-".count))
            toggleSection(identifier: identifier)
            return
        }
        guard let item = itemDescriptor(for: raw) else {
            moveHighlight(by: 1)
            return
        }
        switch item.control {
        case let .picker(value, _, options, _):
            if operatePickerUsingUIKitControl(item, forward: forward) {
                return
            }
            // A rendered UIKit picker is normally available on iOS. Keep a
            // model fallback for a temporarily unavailable view and future
            // non-iOS backends.
            cycle(through: options(self), current: value(self), forward: forward) { newValue in
                applyPickerValue(newValue, for: item)
            }
        case let .toggle(value, setValue):
            setValue(self, !value(self))
            markGameProfileItemChanged(item)
            item.onValueChanged?(self)
        case let .slider(value, setValue, range, _):
            if let onNavigate = item.onNavigate {
                onNavigate(self, forward)
            } else {
                setValue(self, stepped(value(self), in: range, forward: forward, ratio: 0.02))
            }
            markGameProfileItemChanged(item)
            item.onValueChanged?(self)
            sliderControllerValueChanged(item)
        }
    }

    /// UIKit-equivalent iOS controller operation: update the actual segment
    /// and send `.valueChanged`. The existing UISegmentedControl extension
    /// then supplies its canonical previous-selected index to the item model.
    private func operatePickerUsingUIKitControl(_ item: SettingsItemDescriptor, forward: Bool) -> Bool {
        guard case let .picker(value, _, options, _) = item.control,
              let control = pickerControls[item.id]?.value else { return false }

        let pickerOptions = options(self)
        guard !pickerOptions.isEmpty else { return true }
        let currentIndex = pickerOptions.firstIndex { $0.value == value(self) } ?? 0
        for distance in 1...pickerOptions.count {
            let candidate = (currentIndex + (forward ? distance : -distance) + pickerOptions.count) % pickerOptions.count
            guard pickerOptions[candidate].isEnabled else { continue }
            control.selectedSegmentIndex = candidate
            control.sendActions(for: .valueChanged)
            return true
        }
        return true
    }

    /// Shared Picker commit path. UIKit touch/controller events supply the
    /// existing extension's index; the fallback derives it from item state.
    fileprivate func applyPickerValue(
        _ newValue: Int,
        for item: SettingsItemDescriptor,
        previousSelectedIndex: Int? = nil
    ) {
        guard case let .picker(value, setValue, options, _) = item.control else { return }

        let oldValue = value(self)
        let previousIndex = previousSelectedIndex
            ?? options(self).firstIndex(where: { $0.value == oldValue })
        if oldValue != newValue,
           let previousIndex {
            item.previousSelectedIndex?(self)?.wrappedValue = previousIndex
        }

        setValue(self, newValue)
        markGameProfileItemChanged(item)
        item.onValueChanged?(self)
    }

    var highlightedSettingIsSlider: Bool {
        guard let highlightedID,
              let item = itemDescriptor(for: highlightedID) else { return false }
        if case .slider = item.control { return true }
        return false
    }

    private func cycle(through options: [SettingsPickerOption<Int>], current: Int, forward: Bool, apply: (Int) -> Void) {
        let enabled = options.filter(\.isEnabled)
        guard !enabled.isEmpty else { return }
        let currentIndex = enabled.firstIndex { $0.value == current } ?? 0
        let next = (currentIndex + (forward ? 1 : -1) + enabled.count) % enabled.count
        apply(enabled[next].value)
    }

    private func stepped(_ value: Double, in range: ClosedRange<Double>, forward: Bool, ratio: Double) -> Double {
        min(range.upperBound, max(range.lowerBound, value + (forward ? 1 : -1) * (range.upperBound - range.lowerBound) * ratio))
    }

    func performReadTip() {
        guard let highlightedID, let id = SettingsItemID.settingItem(rawValue: highlightedID) else { return }
        showInfo(for: id)
    }

    func persistHighlight() {
        guard let highlightedID else { return }
        let persistedID: String
        if menuMode != .AllSettings,
           let id = SettingsItemID.settingItem(rawValue: highlightedID),
           let favoriteID = favoriteIdentifier(for: id) {
            persistedID = favoriteID
        } else {
            persistedID = highlightedID
        }
        UserDefaults.standard.set(persistedID, forKey: settingsNavigationSelectionKey)
    }

    func restoreHighlight() {
        let persistedID = UserDefaults.standard.string(forKey: settingsNavigationSelectionKey)
        if usesSwiftUIScroll {
            applyHighlight(
                persistedID,
                scrollIntoView: true,
                restoreScrollUsingSwiftUI: true
            )
        } else {
            restoreHighlightUsingNavigationAnchors(persistedID)
        }
    }

    private func restoreHighlightUsingNavigationAnchors(_ persistedID: String?) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.restoreHighlightUsingNavigationAnchors(persistedID)
            }
            return
        }

        prepareNavigationAnchorsForMenuOpeningIfNeeded()
        applyHighlight(persistedID, scrollIntoView: false)

        guard let restoredID = highlightedID else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + settingsNavigationGeometryRestoreDelay) { [weak self] in
            guard let self,
                  !usesSwiftUIScroll,
                  self.highlightedID == restoredID else { return }

            if self.navigationAnchorRects[restoredID] != nil {
                self.scrollNavigationTargetIntoView(restoredID, animated: false)
            } else {
                self.pendingNavigationAnchorScrollID = restoredID
            }
        }
    }

    func clearHighlight() {
        shouldScrollToHighlightedID = true
        showsNavigationHighlight = false
        highlightedID = nil
        pendingNavigationAnchorScrollID = nil
    }

    func consumeHighlightScrollRequest() -> (shouldScroll: Bool, usesSwiftUI: Bool) {
        defer {
            shouldScrollToHighlightedID = true
            nextHighlightScrollUsesSwiftUI = false
        }
        return (shouldScrollToHighlightedID, nextHighlightScrollUsesSwiftUI)
    }

    func navigationElements() -> [ControllerNavigationElement] {
        var elements = [
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "readTip")
        ]
        if menuMode == .AllSettings {
            elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "doublePressToAddFavorite"))
        }
        if menuMode == .FavoriteSettings {
            elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "doublePressToDelete"))
            elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadDown : .y, action: "holdToReorder"))
        }
        elements += [
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButton, action: "radialMenu"),
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .rightStickY : .leftStickY, action: "menuNavigation"),
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .abxy : .dpad, action: "menuNavigation"),
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadLeft : .x, action: "widgetOperationBackward"),
            ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .b, action: "widgetOperationForward")
        ]
        return elements
    }
}

// MARK: - Shared settings views

@available(iOS 14.0, *)
private struct SettingsSectionHeaderIcon: UIViewRepresentable {
    let icon: UIImage?
    let pointSize: CGFloat
    let symbolWeight: UIImage.SymbolWeight
    let themeRevision: Int

    final class Coordinator {
        weak var icon: UIImage?
        var pointSize: CGFloat?
        var symbolWeight: UIImage.SymbolWeight?
        var themeRevision: Int?
        var tintColor: UIColor?
    }

    final class ContainerView: UIView {
        let imageView = UIImageView()

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
                imageView.topAnchor.constraint(equalTo: topAnchor),
                imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }

    func makeUIView(context: Context) -> ContainerView {
        ContainerView()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func updateUIView(_ container: ContainerView, context: Context) {
        let tintColor = ThemeManager.sectionLabelTextColor
        if context.coordinator.icon !== icon ||
            context.coordinator.pointSize != pointSize ||
            context.coordinator.symbolWeight != symbolWeight ||
            context.coordinator.themeRevision != themeRevision {
            container.imageView.image = MenuSectionIconPipeline.configuredImage(
                icon,
                pointSize: pointSize,
                symbolWeight: symbolWeight
            )
            context.coordinator.icon = icon
            context.coordinator.pointSize = pointSize
            context.coordinator.symbolWeight = symbolWeight
            context.coordinator.themeRevision = themeRevision
        }
        if context.coordinator.tintColor != tintColor {
            container.imageView.tintColor = tintColor
            context.coordinator.tintColor = tintColor
        }
        let shouldHide = icon == nil
        if container.imageView.isHidden != shouldHide {
            container.imageView.isHidden = shouldHide
        }
    }
}

/// SwiftUI counterpart of MenuSectionView's outer structure.  Every section
/// uses this shell: a 37pt header, then its separate 25pt header-to-content
/// gap, the bottom-anchored drawer and exactly one separator.
@available(iOS 14.0, *)
private struct SettingsSectionShell<Content: View>: View {
    let descriptor: SettingsSectionDescriptor
    @ObservedObject var store: SettingsSession
    let isExpanded: Bool
    let navigationState: SettingsNavigationState
    let showsNavigationHighlight: Bool
    let registersNavigationAnchors: Bool
    let themeRevision: Int
    @ObservedObject var interactionState: SettingsSectionInteractionState
    let toggle: () -> Void
    let content: () -> Content
    private let layout = SettingsSectionLayout()

    init(
        descriptor: SettingsSectionDescriptor,
        store: SettingsSession,
        isExpanded: Bool,
        navigationState: SettingsNavigationState,
        showsNavigationHighlight: Bool,
        registersNavigationAnchors: Bool,
        themeRevision: Int,
        interactionState: SettingsSectionInteractionState,
        toggle: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.descriptor = descriptor
        self.store = store
        self.isExpanded = isExpanded
        self.navigationState = navigationState
        self.showsNavigationHighlight = showsNavigationHighlight
        self.registersNavigationAnchors = registersNavigationAnchors
        self.themeRevision = themeRevision
        self.interactionState = interactionState
        self.toggle = toggle
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                // Keep the verified 08af578a geometry exactly.  The shell is
                // reusable, but this visual contract must not be re-derived.
                HStack(spacing: 0) {
                    SettingsSectionHeaderIcon(
                        icon: descriptor.icon,
                        pointSize: descriptor.iconPointSize,
                        symbolWeight: descriptor.iconWeight,
                        themeRevision: themeRevision
                    )
                    .frame(
                        width: layout.headerHeight + descriptor.iconSizeConstraint,
                        height: layout.headerHeight + descriptor.iconSizeConstraint
                    )
                    .offset(x: -0.25)
                    .frame(width: 41.5)

                    Text(descriptor.titleKey.localized)
                        .font(.system(size: 19.5, weight: .medium))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11.47, weight: .bold))
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .animation(settingsSectionFoldAnimation, value: isExpanded)
                        .frame(width: 29.6, height: 29.6)
                        .padding(.trailing, 5)
                }
                .foregroundColor(Color(ThemeManager.sectionLabelTextColor))
                .frame(height: layout.headerContainerHeight, alignment: .center)
                .contentShape(Rectangle())
                .navigationHighlight(
                    identifier: "sectionHeader-\(descriptor.id.rawValue)",
                    state: navigationState,
                    isEnabled: showsNavigationHighlight
                )
            }
            .buttonStyle(PlainButtonStyle())
            .accessibilityIdentifier("sectionHeader-\(descriptor.id.rawValue)")
            .id("sectionHeader-\(descriptor.id.rawValue)")
            .settingsNavigationMetadata(
                id: "sectionHeader-\(descriptor.id.rawValue)",
                registersAnchor: registersNavigationAnchors
            )

            if isExpanded {
                SettingsSectionDrawer(
                    sectionID: descriptor.id.rawValue,
                    store: store,
                    isExpanded: isExpanded
                ) {
                    content()
                }
                    .transaction { transaction in
                        transaction.animation = nil
                        transaction.disablesAnimations = true
                    }
            }

            Rectangle()
                .fill(Color(ThemeManager.separatorColor))
                .frame(height: GenericUtils.menuSectionSeparatorWidth)
                .padding(.horizontal, 2.5)
        }
        .allowsHitTesting(interactionState.allowsHitTesting)
        .background(SettingsSectionHitTestRegistration(sectionID: descriptor.id.rawValue, store: store))
    }
}

@available(iOS 14.0, *)
private struct SettingsSectionDrawer<Content: View>: View {
    let sectionID: String
    weak var store: SettingsSession?
    let isExpanded: Bool
    let content: Content

    init(
        sectionID: String,
        store: SettingsSession?,
        isExpanded: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.sectionID = sectionID
        self.store = store
        self.isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.settingsNavigationRowsHidden, !isExpanded)
            .accessibility(hidden: !isExpanded)
    }
}

@available(iOS 14.0, *)
private struct SettingsSectionHitTestRegistration: UIViewRepresentable {
    let sectionID: String
    weak var store: SettingsSession?

    func makeCoordinator() -> Coordinator {
        Coordinator(sectionID: sectionID, store: store)
    }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.isUserInteractionEnabled = false
        view.onDidMoveToWindow = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.register(view)
        }
        return view
    }

    func updateUIView(_ view: AttachmentView, context: Context) {
        context.coordinator.sectionID = sectionID
        context.coordinator.store = store
        context.coordinator.register(view)
    }

    static func dismantleUIView(_ view: AttachmentView, coordinator: Coordinator) {
        coordinator.unregister(view)
    }

    final class AttachmentView: UIView {
        var onDidMoveToWindow: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onDidMoveToWindow?()
        }
    }

    final class Coordinator {
        var sectionID: String
        weak var store: SettingsSession?
        private weak var registeredView: UIView?
        private var registeredSectionID: String?

        init(sectionID: String, store: SettingsSession?) {
            self.sectionID = sectionID
            self.store = store
        }

        func register(_ view: UIView?) {
            guard let view, view.window != nil else { return }
            if registeredView === view,
               registeredSectionID == sectionID {
                return
            }
            if let registeredView, let registeredSectionID {
                store?.unregisterSectionHitTestTarget(
                    registeredView,
                    for: registeredSectionID
                )
            }
            registeredView = view
            registeredSectionID = sectionID
            store?.registerSectionHitTestTarget(view, for: sectionID)
        }

        func unregister(_ view: UIView) {
            if registeredView === view {
                store?.unregisterSectionHitTestTarget(
                    view,
                    for: registeredSectionID ?? sectionID
                )
                registeredView = nil
                registeredSectionID = nil
            }
        }
    }
}

@available(iOS 14.0, *)
private struct SettingsSectionLayout {
    let headerHeight: CGFloat = 37
    let headerVerticalSpacing: CGFloat = 24
    let rowSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 10 : 12
    // MenuSectionView.rootStackViewSpacing between sibling sections.
    let sectionSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 10 : 12
    let controlSpacing: CGFloat = 5
    let switchSpacing: CGFloat = 20
    let switchColumnWidth: CGFloat = 130
    let pickerHeight: CGFloat = 32

    // This is deliberately retained as the verified shared header container
    // from 08af578a; do not replace it with padding around a 37pt HStack.
    var headerContainerHeight: CGFloat { headerHeight + headerVerticalSpacing }
}

private enum SettingsItemDecorationMetrics {
    static let infoTrailing: CGFloat = 4
    static let dynamicTrailing: CGFloat = 5
    static let dynamicLeading: CGFloat = 5
    static let dynamicToInfoSpacing: CGFloat = 5
    static let dynamicWidth: CGFloat = 150
    static let dynamicMinimumWidth: CGFloat = 75
    static let infoPointSize: CGFloat = 13.5
    // UISystemButton's intrinsic width for the 13.5-point symbol is close to
    // this value. It is used only for the legacy overlap test.
    static let estimatedInfoWidth: CGFloat = 16
}

@available(iOS 14.0, *)
private struct SettingsRootView: View {
    @ObservedObject var store: SettingsSession

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { scrollProxy in
                let contentWidth = store.contentWidth > 0
                    ? store.contentWidth
                    : max(0, viewport.size.width - store.contentLeadingInset - store.contentTrailingInset)
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        if store.isAllSettings {
                            ForEach(store.settingsCatalog) { descriptor in
                                SettingsSectionShell(
                                    descriptor: descriptor,
                                    store: store,
                                    isExpanded: store.isSectionExpanded(descriptor.id.rawValue),
                                    navigationState: store.navigationState,
                                    showsNavigationHighlight: store.showsNavigationHighlight,
                                    registersNavigationAnchors: store.registersNavigationAnchors,
                                    themeRevision: store.themeRevision,
                                    interactionState: store.sectionInteractionState(for: descriptor.id.rawValue),
                                    toggle: { store.toggleSection(identifier: descriptor.id.rawValue) }
                                ) {
                                    if !descriptor.items.isEmpty {
                                        SettingsCatalogSectionItemsView(
                                            items: descriptor.items,
                                            store: store,
                                            participatesInControllerNavigation: descriptor.itemsParticipateInControllerNavigation
                                        )
                                    }
                                }
                            }
                        } else {
                            SettingsFavoriteItemsView(store: store)
                        }
                    }
                    // A vertical SwiftUI ScrollView still adopts an oversized
                    // child's intrinsic width. Pin the catalog to the viewport so
                    // long localized labels/segmented controls compress inside the
                    // menu instead of creating a horizontal content range.
                    .frame(width: contentWidth, alignment: .leading)
                    .padding(.leading, store.contentLeadingInset)
                    .padding(.trailing, store.contentTrailingInset)
                    .padding(.top, GenericUtils.settingsMenuNavigationBarHeight)
                    .padding(.bottom, 20)
                    .coordinateSpace(name: settingsNavigationCoordinateSpaceName)
                    .background(
                        SettingsScrollViewResolver(
                            store: store,
                            onResolve: { scrollView in
                                store.registerNavigationScrollView(scrollView)
                            },
                            onWillBeginDragging: {
                                store.userTouchScrollWillBegin()
                            }
                        )
                    )
                }
                .ignoresSafeArea(.container, edges: .horizontal)
                .onReceive(store.navigationState.highlightedIDDidChange) { id in
                    let scrollRequest = store.consumeHighlightScrollRequest()
                    guard let id, scrollRequest.shouldScroll else { return }
                    if usesSwiftUIScroll || scrollRequest.usesSwiftUI {
                        withAnimation(.easeOut(duration: 0.1)) {
                            scrollProxy.scrollTo(id, anchor: .center)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            store.updateSectionHitTestingForCurrentScrollView()
                        }
                    } else {
                        store.scrollNavigationTargetIntoView(id)
                    }
                }
                .settingsNavigationAnchorPreferenceHandler(store: store)
                .background(Color(ThemeManager.menuBackgroundColor).ignoresSafeArea())
                .environment(\.colorScheme, ThemeManager.userInterfaceStyle() == .light ? .light : .dark)
            }
        }
    }
}

@available(iOS 14.0, *)
private struct SettingsCatalogSectionItemsView: View {
    let items: [SettingsItemDescriptor]
    @ObservedObject var store: SettingsSession
    let participatesInControllerNavigation: Bool
    private let layout = SettingsSectionLayout()

    var body: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(items) { item in
                if item.isVisible(store) {
                    SettingsCatalogItemView(
                        item: item,
                        store: store,
                        participatesInControllerNavigation: participatesInControllerNavigation
                    )
                }
            }
        }
        .padding(.horizontal, 5)
        .padding(.bottom, 40)
    }
}

@available(iOS 14.0, *)
private struct SettingsCatalogItemView: View {
    let item: SettingsItemDescriptor
    @ObservedObject var store: SettingsSession
    var suppressInfo: Bool = false
    var participatesInControllerNavigation: Bool = true
    private let layout = SettingsSectionLayout()

    @ViewBuilder
    var body: some View {
        let isEnabled = item.isEnabled(store)
        let isUserInteractionEnabled = store.isItemUserInteractionEnabled(item.id)
        let showsInfo = (item.hasInfo || item.isGameProfileSetting) && !suppressInfo
        switch item.control {
        case let .picker(value, _, options, distribution):
            VStack(alignment: .leading, spacing: layout.controlSpacing) {
                itemTitleLine(
                    dynamicText: item.dynamicText?(store),
                    showsInfo: showsInfo
                ) {
                    Text(item.id.titleKey.localized)
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                SettingsPicker(
                    selection: Binding(get: { value(store) }, set: { newValue in
                        store.applyPickerValue(newValue, for: item)
                    }),
                    previousSelectedIndex: item.previousSelectedIndex?(store),
                    options: options(store),
                    isEnabled: isEnabled,
                    isUserInteractionEnabled: isUserInteractionEnabled,
                    widthDistribution: distribution,
                    onDisabledOptionTapped: item.onDisabledOptionTapped.map { callback in
                        { callback(store, $0) }
                    },
                    onSelectionChanging: { previousIndex, newValue in
                        store.applyPickerValue(
                            newValue,
                            for: item,
                            previousSelectedIndex: previousIndex
                        )
                    },
                    onControlResolved: { control in
                        store.registerPickerControl(control, for: item.id)
                    }
                )
                .frame(maxWidth: .infinity)
                .frame(height: layout.pickerHeight)
            }
            .settingRow(
                id: item.id,
                store: store,
                enabled: isEnabled,
                userInteractionEnabled: isUserInteractionEnabled,
                participatesInControllerNavigation: participatesInControllerNavigation
            )
        case let .slider(value, setValue, range, valueText):
            VStack(alignment: .leading, spacing: layout.controlSpacing) {
                itemTitleLine(
                    dynamicText: valueText(store),
                    showsInfo: showsInfo
                ) {
                    Text(item.id.titleKey.localized)
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                SettingsSlider(
                    value: Binding(get: { value(store) }, set: { newValue in
                        setValue(store, newValue)
                        store.markGameProfileItemChanged(item)
                        item.onValueChanged?(store)
                        store.sliderTouchValueChanged(item)
                    }),
                    in: range,
                    isEnabled: isEnabled,
                    isUserInteractionEnabled: isUserInteractionEnabled,
                    onEditingChanged: { editing in
                        store.sliderTouchEditingChanged(item, editing: editing)
                    },
                    onControlResolved: { control in
                        store.registerItemControl(control, for: item.id)
                    }
                )
            }
            .settingRow(
                id: item.id,
                store: store,
                enabled: isEnabled,
                userInteractionEnabled: isUserInteractionEnabled,
                participatesInControllerNavigation: participatesInControllerNavigation
            )
        case let .toggle(value, setValue):
            itemTitleLine(
                dynamicText: item.dynamicText?(store),
                showsInfo: showsInfo
            ) {
                HStack(spacing: layout.switchSpacing) {
                    Text(item.id.titleKey.localized)
                        .font(.system(size: 17))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Spacer(minLength: 0)
                    SettingsToggle(isOn: Binding(get: { value(store) }, set: { newValue in
                        setValue(store, newValue)
                        store.markGameProfileItemChanged(item)
                        item.onValueChanged?(store)
                    }),
                    isEnabled: isEnabled,
                    isUserInteractionEnabled: isUserInteractionEnabled,
                    onControlResolved: { control in
                        store.registerItemControl(control, for: item.id)
                    })
                        .frame(width: layout.switchColumnWidth, alignment: .leading)
                }
            }
            .settingRow(
                id: item.id,
                store: store,
                enabled: isEnabled,
                userInteractionEnabled: isUserInteractionEnabled,
                participatesInControllerNavigation: participatesInControllerNavigation
            )
        }
    }

    @ViewBuilder
    private func itemTitleLine<Content: View>(
        dynamicText: String?,
        showsInfo: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let hasDynamicText = dynamicText?.isEmpty == false
        let base = content().frame(maxWidth: .infinity, alignment: .leading)

        if showsInfo || hasDynamicText {
            let dynamicWidth = hasDynamicText ? availableDynamicLabelWidth() : nil
            base
                .padding(.trailing, reservedTrailingWidth(dynamicText: dynamicText, dynamicWidth: dynamicWidth))
                .overlay(
                    HStack(alignment: .center, spacing: SettingsItemDecorationMetrics.dynamicToInfoSpacing) {
                        if let dynamicText,
                           !dynamicText.isEmpty,
                           let dynamicWidth {
                            Text(dynamicText)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(Color(ThemeManager.appPrimaryColor))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                                .frame(width: dynamicWidth)
                                .clipped()
                        }
                        if showsInfo {
                            SettingsInfoButtonControl(
                                isGameProfileSetting: item.isGameProfileSetting,
                                action: { store.showInfo(for: item.id, isGameProfileSetting: item.isGameProfileSetting) }
                            )
                            .frame(width: 24, height: 24)
                        }
                    }
                    .padding(
                        .trailing,
                        showsInfo ? SettingsItemDecorationMetrics.infoTrailing
                                : SettingsItemDecorationMetrics.dynamicTrailing
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                )
        } else {
            base
        }
    }

    private func availableDynamicLabelWidth() -> CGFloat? {
        let titleWidth = settingsTitleWidth(item.id.titleKey.localized)
        let showsInfo = (item.hasInfo || item.isGameProfileSetting) && !suppressInfo
        let trailingWidth = showsInfo
            ? SettingsItemDecorationMetrics.dynamicToInfoSpacing
                + SettingsItemDecorationMetrics.estimatedInfoWidth
                + SettingsItemDecorationMetrics.infoTrailing
            : SettingsItemDecorationMetrics.dynamicTrailing
        let availableWidth = max(0, store.contentWidth - 10)
            - titleWidth
            - SettingsItemDecorationMetrics.dynamicLeading
            - trailingWidth
        guard availableWidth >= SettingsItemDecorationMetrics.dynamicMinimumWidth else { return nil }
        return min(SettingsItemDecorationMetrics.dynamicWidth, availableWidth)
    }

    private func reservedTrailingWidth(dynamicText: String?, dynamicWidth: CGFloat?) -> CGFloat {
        guard dynamicText?.isEmpty == false, let dynamicWidth else { return 0 }
        let showsInfo = (item.hasInfo || item.isGameProfileSetting) && !suppressInfo
        let trailingWidth = showsInfo
            ? SettingsItemDecorationMetrics.dynamicToInfoSpacing
                + SettingsItemDecorationMetrics.estimatedInfoWidth
                + SettingsItemDecorationMetrics.infoTrailing
            : SettingsItemDecorationMetrics.dynamicTrailing
        return SettingsItemDecorationMetrics.dynamicLeading + dynamicWidth + trailingWidth
    }
}

@available(iOS 14.0, *)
private struct SettingsFavoriteItemsView: View {
    @ObservedObject var store: SettingsSession
    private let layout = SettingsSectionLayout()

    var body: some View {
        VStack(spacing: layout.rowSpacing) {
            ForEach(store.favoriteSettingIDs, id: \.self) { id in
                if store.isVisible(id) {
                    favoriteRow(id)
                }
            }
            Rectangle()
                .fill(Color(ThemeManager.separatorColor))
                .frame(height: GenericUtils.menuSectionSeparatorWidth)
                .padding(.horizontal, 2.5)
        }
        .padding(.horizontal, 5)
        .padding(.top, 10)
        .padding(.bottom, 40)
    }

    @ViewBuilder
    private func favoriteRow(_ id: SettingsItemID) -> some View {
        ZStack(alignment: .topTrailing) {
            if let item = store.settingsItem(for: id) {
                SettingsCatalogItemView(
                    item: item,
                    store: store,
                    suppressInfo: store.isRemovingFavorites
                )
            }

            if store.isRemovingFavorites {
                Button(action: { store.removeFavorite(id) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, 4)
            }
        }
        .accessibilityIdentifier(id.rawValue)
        .modifier(SettingsFavoriteDragModifier(id: id, store: store, enabled: !store.isRemovingFavorites))
    }
}

@available(iOS 14.0, *)
private struct SettingsFavoriteDragModifier: ViewModifier {
    let id: SettingsItemID
    let store: SettingsSession
    let enabled: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if enabled {
            content
                .onDrag {
                    store.draggedFavoriteID = id
                    return NSItemProvider(object: id.rawValue as NSString)
                }
                .onDrop(
                    of: [UTType.text.identifier],
                    delegate: SettingsFavoriteDropDelegate(destination: id, store: store)
                )
        } else {
            content
        }
    }
}

@available(iOS 14.0, *)
private struct SettingsFavoriteDropDelegate: DropDelegate {
    let destination: SettingsItemID
    let store: SettingsSession

    func dropEntered(info: DropInfo) {
        withAnimation(.easeInOut(duration: 0.12)) {
            store.moveDraggedFavorite(over: destination)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        store.draggedFavoriteID = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

@available(iOS 14.0, *)
private struct SettingsEmergingHighlightBackground: UIViewRepresentable {
    let isHighlighted: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.layer.cornerRadius = 6
        view.layer.masksToBounds = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        let targetColor = isHighlighted ? ThemeManager.appPrimaryColorWithAlpha : UIColor.clear
        guard view.backgroundColor != targetColor else { return }

        UIView.animate(
            withDuration: settingsEmergingHighlightPhaseDuration,
            delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction],
            animations: {
                view.backgroundColor = targetColor
            }
        )
    }
}

@available(iOS 13.0, *)
private struct SettingsNavigationHighlightBackground: View {
    @ObservedObject var state: SettingsNavigationState
    let identifier: String

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                state.highlightedID == identifier
                    ? Color(ThemeManager.appPrimaryColorWithAlpha)
                    : .clear
            )
            .allowsHitTesting(false)
    }
}

@available(iOS 13.0, *)
private struct SettingsFavoritePromptHighlightBackground: View {
    let isHighlighted: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(isHighlighted ? Color(ThemeManager.appPrimaryColorWithAlpha) : .clear)
            .allowsHitTesting(false)
    }
}

@available(iOS 14.0, *)
private struct SettingsScrollViewResolver: UIViewRepresentable {
    weak var store: SettingsSession?
    let onResolve: (UIScrollView?) -> Void
    let onWillBeginDragging: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            store: store,
            onResolve: onResolve,
            onWillBeginDragging: onWillBeginDragging
        )
    }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.isUserInteractionEnabled = false
        view.onDidMoveToWindow = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.resolve(from: view)
        }
        return view
    }

    func updateUIView(_ view: AttachmentView, context: Context) {
        context.coordinator.store = store
        context.coordinator.onResolve = onResolve
        context.coordinator.onWillBeginDragging = onWillBeginDragging
        context.coordinator.resolveIfNeeded(from: view)
    }

    static func dismantleUIView(_ view: AttachmentView, coordinator: Coordinator) {
        coordinator.detach()
        coordinator.onResolve(nil)
    }

    final class AttachmentView: UIView {
        var onDidMoveToWindow: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onDidMoveToWindow?()
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate, UIScrollViewDelegate {
        weak var store: SettingsSession?
        var onResolve: (UIScrollView?) -> Void
        var onWillBeginDragging: () -> Void
        private weak var resolvedScrollView: UIScrollView?
        private weak var resolvedWindow: UIWindow?
        private weak var originalScrollDelegate: UIScrollViewDelegate?
        private weak var favoriteLongPressInstallView: UIView?
        private weak var scrollPanRecognizer: UIPanGestureRecognizer?
        private var activeFavoriteLongPressID: SettingsItemID?
        private var scrollDidScrollTick = 0
        private var retryScheduled = false
        private var retryCount = 0
        private lazy var favoriteLongPressRecognizer: UILongPressGestureRecognizer = {
            let recognizer = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleFavoriteLongPress(_:))
            )
            recognizer.minimumPressDuration = 0.5
            recognizer.allowableMovement = 10
            recognizer.cancelsTouchesInView = false
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
            recognizer.delegate = self
            return recognizer
        }()

        init(
            store: SettingsSession?,
            onResolve: @escaping (UIScrollView?) -> Void,
            onWillBeginDragging: @escaping () -> Void
        ) {
            self.store = store
            self.onResolve = onResolve
            self.onWillBeginDragging = onWillBeginDragging
        }

        func resolveIfNeeded(from attachmentView: UIView?) {
            guard let attachmentView else { return }
            if let resolvedScrollView,
               resolvedScrollView.window === attachmentView.window,
               resolvedWindow === attachmentView.window {
                return
            }
            resolve(from: attachmentView)
        }

        func resolve(from attachmentView: UIView?) {
            guard let attachmentView else { return }
            var ancestor = attachmentView.superview
            while let view = ancestor {
                if let scrollView = view as? UIScrollView {
                    guard resolvedScrollView !== scrollView else { return }
                    detach()
                    resolvedScrollView = scrollView
                    scrollView.alwaysBounceHorizontal = false
                    scrollView.showsHorizontalScrollIndicator = false
                    scrollView.isDirectionalLockEnabled = true
                    scrollView.panGestureRecognizer.addTarget(
                        self,
                        action: #selector(handleScrollPan(_:))
                    )
                    originalScrollDelegate = scrollView.delegate
                    scrollView.delegate = self
                    scrollPanRecognizer = scrollView.panGestureRecognizer
                    installFavoriteLongPressRecognizer(for: scrollView)
                    resolvedWindow = attachmentView.window
                    retryCount = 0
                    onResolve(scrollView)
                    return
                }
                ancestor = view.superview
            }

            guard attachmentView.window != nil, !retryScheduled, retryCount < 3 else { return }
            retryScheduled = true
            retryCount += 1
            DispatchQueue.main.async { [weak self, weak attachmentView] in
                self?.retryScheduled = false
                self?.resolve(from: attachmentView)
            }
        }

        func detach() {
            resolvedScrollView?.panGestureRecognizer.removeTarget(
                self,
                action: #selector(handleScrollPan(_:))
            )
            if resolvedScrollView?.delegate === self {
                resolvedScrollView?.delegate = originalScrollDelegate
            }
            originalScrollDelegate = nil
            favoriteLongPressInstallView?.removeGestureRecognizer(favoriteLongPressRecognizer)
            favoriteLongPressInstallView = nil
            scrollPanRecognizer = nil
            resolvedScrollView = nil
            resolvedWindow = nil
            scrollDidScrollTick = 0
        }

        @objc private func handleScrollPan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .began else { return }
            onWillBeginDragging()
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // print("didscroll \(CACurrentMediaTime())")
            originalScrollDelegate?.scrollViewDidScroll?(scrollView)
            guard enablesSectionHitTestCulling else { return }
            scrollDidScrollTick += 1
            let scrollIsActive = scrollView.isDragging || scrollView.isDecelerating
            guard scrollDidScrollTick % settingsSectionHitTestScrollTickInterval == 0 else { return }
            if scrollIsActive {
                // store?.updateSectionHitTesting(for: scrollView)
                /*
                store?.suppressContinuousInteractionPreviewsForScrolling()
                store?.cancelContinuousInteractionsForScrolling(force: true)
                */
                store?.suppressContinuousInteractionPreviewsForScrolling()
                if store?.hasContinuousInteractionsToCancelForScrolling == true {
                    store?.cancelContinuousInteractionsForScrolling()
                }
            }
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            originalScrollDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
            if !decelerate {
                scrollViewDidStop(scrollView)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            originalScrollDelegate?.scrollViewDidEndDecelerating?(scrollView)
            scrollViewDidStop(scrollView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            originalScrollDelegate?.scrollViewDidEndScrollingAnimation?(scrollView)
            // scrollViewDidStop(scrollView)
        }

        private func scrollViewDidStop(_ scrollView: UIScrollView) {
            store?.updateSectionHitTesting(for: scrollView)
        }

        override func responds(to selector: Selector!) -> Bool {
            if super.responds(to: selector) { return true }
            return originalScrollDelegate?.responds(to: selector) == true
        }

        override func forwardingTarget(for selector: Selector!) -> Any? {
            if originalScrollDelegate?.responds(to: selector) == true {
                return originalScrollDelegate
            }
            return super.forwardingTarget(for: selector)
        }

        private func installFavoriteLongPressRecognizer(for scrollView: UIScrollView) {
            let target = scrollView.superview ?? scrollView
            guard favoriteLongPressInstallView !== target else { return }
            favoriteLongPressInstallView?.removeGestureRecognizer(favoriteLongPressRecognizer)
            target.addGestureRecognizer(favoriteLongPressRecognizer)
            favoriteLongPressInstallView = target
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === favoriteLongPressRecognizer,
               otherGestureRecognizer === scrollPanRecognizer {
                return false
            }
            return true
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === favoriteLongPressRecognizer,
                  store?.isAllSettings == true,
                  store?.isExcludedFavoriteControlTouch(touch.view) == false else {
                activeFavoriteLongPressID = nil
                return false
            }
            activeFavoriteLongPressID = nil
            return true
        }

        @objc private func handleFavoriteLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard let store else { return }
            switch recognizer.state {
            case .began:
                guard let coordinateView = favoriteLongPressInstallView,
                      let target = store.favoriteLongPressTarget(
                        at: recognizer.location(in: coordinateView),
                        in: coordinateView
                      ) else { return }
                activeFavoriteLongPressID = target.id
                store.lockFavoriteLongPressInteraction(for: target.id)
                store.requestAddFavorite(
                    for: target.id,
                    globalAnchorRect: target.view.convert(target.view.bounds, to: nil)
                )
            case .ended, .cancelled, .failed:
                guard let id = activeFavoriteLongPressID else { return }
                store.unlockFavoriteLongPressInteraction(for: id)
                activeFavoriteLongPressID = nil
            default:
                break
            }
        }
    }
}


@available(iOS 14.0, *)
private struct SettingsFavoriteLongPressModifier: ViewModifier {
    let id: SettingsItemID
    @ObservedObject var store: SettingsSession
    @Environment(\.settingsNavigationRowsHidden) private var sectionRowsHidden

    @ViewBuilder
    func body(content: Content) -> some View {
        if store.isAllSettings {
            content
                .background(
                    SettingsFavoriteLongPressTarget(
                        id: id,
                        store: store,
                        isEnabled: !sectionRowsHidden
                    )
                )
        } else {
            content
        }
    }
}

/// The row already owns its SettingsItemID. Keep favorite long-press local to
/// that row instead of asking a global gesture to infer identity from geometry.
@available(iOS 14.0, *)
private struct SettingsFavoriteLongPressTarget: UIViewRepresentable {
    let id: SettingsItemID
    @ObservedObject var store: SettingsSession
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(id: id, store: store)
    }

    func makeUIView(context: Context) -> AttachmentView {
        let view = AttachmentView()
        view.isUserInteractionEnabled = false
        view.onDidMoveToWindow = { [weak coordinator = context.coordinator, weak view] in
            coordinator?.register(view)
        }
        return view
    }

    func updateUIView(_ view: AttachmentView, context: Context) {
        context.coordinator.id = id
        context.coordinator.store = store
        context.coordinator.isEnabled = isEnabled
        context.coordinator.register(view)
    }

    static func dismantleUIView(_ view: AttachmentView, coordinator: Coordinator) {
        coordinator.unregister(view)
    }

    final class AttachmentView: UIView {
        var onDidMoveToWindow: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            onDidMoveToWindow?()
        }
    }

    final class Coordinator {
        var id: SettingsItemID
        weak var store: SettingsSession?
        var isEnabled = true
        private weak var registeredView: UIView?
        private weak var registeredWindow: UIWindow?
        private var registeredID: SettingsItemID?
        private var registeredEnabled = true

        init(id: SettingsItemID, store: SettingsSession) {
            self.id = id
            self.store = store
        }

        func register(_ view: UIView?) {
            guard let view, view.window != nil else { return }
            if registeredView === view,
               registeredWindow === view.window,
               registeredID == id,
               registeredEnabled == isEnabled {
                return
            }
            if let registeredView, let registeredID, registeredID != id {
                store?.unregisterFavoriteLongPressTarget(registeredView, for: registeredID)
            }
            registeredView = view
            registeredWindow = view.window
            registeredID = id
            registeredEnabled = isEnabled
            store?.registerFavoriteLongPressTarget(view, for: id, isEnabled: isEnabled)
        }

        func unregister(_ view: UIView) {
            if registeredView === view {
                store?.unregisterFavoriteLongPressTarget(view, for: registeredID ?? id)
                registeredView = nil
                registeredWindow = nil
                registeredID = nil
            }
        }
    }
}

@available(iOS 14.0, *)
private extension View {
    @ViewBuilder
    func settingsNavigationAnchorPreferenceHandler(store: SettingsSession) -> some View {
        if !usesSwiftUIScroll && store.registersNavigationAnchors {
            onPreferenceChange(SettingsNavigationAnchorPreferenceKey.self) { anchors in
                store.updateNavigationAnchorRects(anchors)
            }
        } else {
            self
        }
    }

    func settingsNavigationMetadata(
        id: String,
        isHidden: Bool = false,
        isEnabled: Bool = true,
        registersAnchor: Bool = true
    ) -> some View {
        modifier(SettingsNavigationRegistration(
            id: id,
            isHidden: isHidden || !isEnabled,
            registersAnchor: registersAnchor
        ))
    }

    @ViewBuilder
    func navigationHighlight(
        identifier: String,
        state: SettingsNavigationState,
        isEnabled: Bool = true
    ) -> some View {
        if isEnabled && state.highlightedID != nil {
            background(SettingsNavigationHighlightBackground(state: state, identifier: identifier))
        } else {
            self
        }
    }

    @ViewBuilder
    func favoritePromptHighlight(id: SettingsItemID, store: SettingsSession) -> some View {
        if store.favoritePromptHighlightedID == id {
            background(SettingsFavoritePromptHighlightBackground(isHighlighted: true))
        } else {
            self
        }
    }

    @ViewBuilder
    func emergingHighlight(_ highlighted: Bool) -> some View {
        background(SettingsEmergingHighlightBackground(isHighlighted: highlighted))
            .cornerRadius(6)
    }

    @ViewBuilder
    func settingsInteractionState(enabled: Bool, userInteractionEnabled: Bool) -> some View {
        if enabled && userInteractionEnabled {
            self
        } else {
            opacity(enabled ? 1 : 0.46)
                .disabled(!enabled)
                .allowsHitTesting(userInteractionEnabled)
        }
    }

    func settingRow(
        identifier: String,
        store: SettingsSession,
        enabled: Bool,
        userInteractionEnabled: Bool = true,
        participatesInControllerNavigation: Bool = true
    ) -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .settingsInteractionState(
                enabled: enabled,
                userInteractionEnabled: userInteractionEnabled
            )
            .emergingHighlight(store.emergingHighlightIDs.contains(identifier))
            .navigationHighlight(
                identifier: identifier,
                state: store.navigationState,
                isEnabled: store.showsNavigationHighlight
            )
            .accessibilityIdentifier(identifier)
            .id(identifier)
            .settingsNavigationMetadata(
                id: identifier,
                isEnabled: enabled && participatesInControllerNavigation,
                registersAnchor: store.registersNavigationAnchors
            )
    }

    func settingRow(
        id: SettingsItemID,
        store: SettingsSession,
        enabled: Bool,
        userInteractionEnabled: Bool = true,
        participatesInControllerNavigation: Bool = true
    ) -> some View {
        settingRow(
            identifier: id.rawValue,
            store: store,
            enabled: enabled,
            userInteractionEnabled: userInteractionEnabled,
            participatesInControllerNavigation: participatesInControllerNavigation
        )
            .favoritePromptHighlight(id: id, store: store)
            .modifier(SettingsFavoriteLongPressModifier(id: id, store: store))
    }
}

// MARK: - UIKit shell hosting only

@available(iOS 13.0, *)
extension SettingsViewController {
    var swiftUISettingsStore: SettingsSession? {
        get { objc_getAssociatedObject(self, &settingsSwiftUIStoreAssociationKey) as? SettingsSession }
        set { objc_setAssociatedObject(self, &settingsSwiftUIStoreAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    private var swiftUISettingsHost: UIViewController? {
        get { objc_getAssociatedObject(self, &settingsSwiftUIHostAssociationKey) as? UIViewController }
        set { objc_setAssociatedObject(self, &settingsSwiftUIHostAssociationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    @available(iOS 14.0, *)
    @objc func installSwiftUISettingsIfNeeded() {
        guard swiftUISettingsHost == nil else { return }

        view.subviews.forEach { $0.removeFromSuperview() }
        let store = SettingsSession(presentingController: self)
        let host = UIHostingController(rootView: SettingsRootView(store: store))
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = ThemeManager.menuBackgroundColor
        host.view.clipsToBounds = true
        addChild(host)
        view.addSubview(host.view)

        if let scrollView = view as? UIScrollView {
            scrollView.isScrollEnabled = false
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: scrollView.frameLayoutGuide.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: scrollView.frameLayoutGuide.bottomAnchor)
            ])
        } else {
            NSLayoutConstraint.activate([
                host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                host.view.topAnchor.constraint(equalTo: view.topAnchor),
                host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        host.didMove(toParent: self)
        swiftUISettingsStore = store
        swiftUISettingsHost = host
        updateSwiftUIContentInsets()
    }

    @objc func refreshSwiftUISettings() {
        swiftUISettingsStore?.refreshTheme()
        swiftUISettingsHost?.view.backgroundColor = ThemeManager.menuBackgroundColor
        updateSwiftUIContentInsets()
    }

    @objc func refreshSwiftUISettingsTheme() {
        swiftUISettingsStore?.forceRefreshTheme()
        swiftUISettingsHost?.view.backgroundColor = ThemeManager.menuBackgroundColor
        updateSwiftUIContentInsets()
    }

    @objc func reloadSwiftUISettings() {
        swiftUISettingsStore?.reloadFromPersistence()
    }

    @objc func refreshSwiftUISettingsGeometry() {
        swiftUISettingsStore?.refreshGeometry()
        updateSwiftUIContentInsets()
        swiftUISettingsStore?.refreshSectionHitTestingAfterGeometryChange()
    }

    @objc func stopSwiftUISettingsScrollViewImmediately() {
        swiftUISettingsStore?.stopSettingsScrollViewImmediately()
    }

    @objc func persistSwiftUISettings() {
        swiftUISettingsStore?.persistSettings()
    }

    @objc func persistSwiftUIGameProfileSettings() {
        swiftUISettingsStore?.persistGameProfileSettingsIfNeeded()
    }

    @objc func applySwiftUIClosingEffects() {
        swiftUISettingsStore?.applyClosingRuntimeEffects()
    }

    @objc func updateSwiftUISettingsStreamingState(_ expandedInStream: Bool, menuIsOpening: Bool) {
        swiftUISettingsStore?.updateStreamingState(expandedInStream, menuIsOpening: menuIsOpening)
    }

    @objc func setSwiftUISettingsMenuMode(_ rawValue: Int) {
        guard let mode = SettingsMenuMode(rawValue: rawValue) else { return }
        swiftUISettingsStore?.setMenuMode(mode)
    }

    @objc func swiftUISettingsMenuModeRawValue() -> Int {
        swiftUISettingsStore?.menuMode.rawValue ?? SettingsMenuMode.AllSettings.rawValue
    }

    @objc var usesSwiftUISettings: Bool { swiftUISettingsStore != nil }

    private func updateSwiftUIContentInsets() {
        view.layoutIfNeeded()
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .unknown
        swiftUISettingsStore?.updateContentInsets(
            safeAreaInsets: view.safeAreaInsets,
            interfaceOrientation: orientation,
            viewBounds: view.bounds,
            safeAreaLayoutFrame: view.safeAreaLayoutGuide.layoutFrame
        )
    }
}
