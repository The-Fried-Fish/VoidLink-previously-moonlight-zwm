//
//  AbstractGamepadView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/3/25.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import Combine

@available(iOS 13.0, *)
struct DPadHighlight: OptionSet {
    let rawValue: Int
    
    static let up = DPadHighlight(rawValue: 1 << 0)
    static let down = DPadHighlight(rawValue: 1 << 1)
    static let left = DPadHighlight(rawValue: 1 << 2)
    static let right = DPadHighlight(rawValue: 1 << 3)
    
    static let all: DPadHighlight = [.up, .down, .left, .right]
    static let none: DPadHighlight = []
}

@available(iOS 13.0, *)
enum StickHighlightMode: Equatable {
    case none
    case outerOnly
    case thumbOnly
    case both
}

@available(iOS 13.0, *)
enum TriggerHighlightMode: Equatable {
    case none
    case button
    case pad
}

@available(iOS 13.0, *)
enum DS4TouchHighlightMode: Equatable {
    case none
    case pad
    case button
}

@available(iOS 13.0, *)
enum GamepadType: Equatable {
    case xbox
    case ps
}

@available(iOS 13.0, *)
enum GamepadToggleTarget: Hashable {
    case a, b, x, y
    case select, start, home
    case leftStick, rightStick
    case leftShoulder, rightShoulder
    case leftTrigger, rightTrigger
    case ds4Touchpad

    var widgets: [GamepadWidget] {
        switch self {
        case .a: return [.a]
        case .b: return [.b]
        case .x: return [.x]
        case .y: return [.y]
        case .select: return [.select]
        case .start: return [.start]
        case .home: return [.home]
        case .leftStick: return [.ls, .lswheel, .lsPad]
        case .rightStick: return [.rs, .rsPad, .rsvPad]
        case .leftShoulder: return [.leftShoulder]
        case .rightShoulder: return [.rightShoulder]
        case .leftTrigger: return [.leftTrigger, .ltPad]
        case .rightTrigger: return [.rightTrigger, .rtPad]
        case .ds4Touchpad: return [.ds4Touchpad, .ds4TouchpadButton]
        }
    }
}

@available(iOS 13.0, *)
enum GamepadWidget: Hashable {
    case a, b, x, y
    case select, start, home
    case dPad, up, down, left, right
    case ls, lsPad, lswheel, rs, rsPad, rsvPad
    case leftShoulder, rightShoulder
    case leftTrigger, ltPad, rightTrigger, rtPad
    case ds4Touchpad
    case ds4TouchpadButton

    var cmd: String {
        switch self {
        case .a: return "OSCA"
        case .b: return "OSCB"
        case .x: return "OSCX"
        case .y: return "OSCY"
        case .select: return "OSCSELECT"
        case .start: return "OSCSTART"
        case .home: return "HOME"
        case .dPad: return "DPAD"
        case .up: return "OSCUP"
        case .down: return "OSCDOWN"
        case .left: return "OSCLEFT"
        case .right: return "OSCRIGHT"
        case .ls: return "LS"
        case .lswheel: return "LSWHEEL"
        case .lsPad: return "LSPAD"
        case .rs: return "RS"
        case .rsPad: return "RSPAD"
        case .rsvPad: return "RSVPAD"
        case .leftShoulder: return "LB"
        case .rightShoulder: return "RB"
        case .leftTrigger: return "LT"
        case .ltPad: return "LTPAD"
        case .rightTrigger: return "RT"
        case .rtPad: return "RTPAD"
        case .ds4Touchpad: return "DS4TOUCH"
        case .ds4TouchpadButton: return "DS4TCHBTN"
        }
    }
    
    var description: String {
        switch self {
        case .a: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad A")
        case .b: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad B")
        case .x: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad X")
        case .y: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Y")
        case .select: return SwiftLocalizationHelper.localizedString(forKey: "Select")
        case .start: return SwiftLocalizationHelper.localizedString(forKey: "Start")
        case .home: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Home")
        case .dPad: return SwiftLocalizationHelper.localizedString(forKey: "Dpad")
        case .up: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Up")
        case .down: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Down")
        case .left: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Left")
        case .right: return SwiftLocalizationHelper.localizedString(forKey: "Gamepad Right")
        case .ls: return SwiftLocalizationHelper.localizedString(forKey: "LS/L3 button")
        case .lswheel: return SwiftLocalizationHelper.localizedString(forKey: "Left stick wheel")
        case .lsPad: return SwiftLocalizationHelper.localizedString(forKey: "Left stick pad")
        case .rs: return SwiftLocalizationHelper.localizedString(forKey: "RS/R3 button")
        case .rsPad: return SwiftLocalizationHelper.localizedString(forKey: "Displacement-based right stick pad")
        case .rsvPad: return SwiftLocalizationHelper.localizedString(forKey: "Velocity-based right stick pad")
        case .leftShoulder: return SwiftLocalizationHelper.localizedString(forKey: "LB/L1")
        case .rightShoulder: return SwiftLocalizationHelper.localizedString(forKey: "RB/R1")
        case .leftTrigger: return SwiftLocalizationHelper.localizedString(forKey: "LT/L2 button")
        case .ltPad: return SwiftLocalizationHelper.localizedString(forKey: "Left trigger pad")
        case .rightTrigger: return SwiftLocalizationHelper.localizedString(forKey: "RT/R2 button")
        case .rtPad: return SwiftLocalizationHelper.localizedString(forKey: "Right trigger pad")
        case .ds4Touchpad: return SwiftLocalizationHelper.localizedString(forKey: "DS4 touchpad")
        case .ds4TouchpadButton: return SwiftLocalizationHelper.localizedString(forKey: "DS4 touchpad button")
        }
    }
}


@available(iOS 13.0, *)
struct AbstractGamepadView: View {
    let gamepadType: GamepadType
    var canSelectCommand: ((String) -> Bool)? = nil
    var isCommandSelected: ((String) -> Bool)? = nil
    var onCommandSelected: ((String) -> Void)? = nil
    var onCommandDeselected: ((String) -> Void)? = nil
    var resetToken: Int = 0
    var selectionSyncToken: Int = 0
    var externalDeselectionCommand: String? = nil
    var externalDeselectionToken: Int = 0

    init(
        gamepadType: GamepadType = .xbox,
        canSelectCommand: ((String) -> Bool)? = nil,
        isCommandSelected: ((String) -> Bool)? = nil,
        onCommandSelected: ((String) -> Void)? = nil,
        onCommandDeselected: ((String) -> Void)? = nil,
        resetToken: Int = 0,
        selectionSyncToken: Int = 0,
        externalDeselectionCommand: String? = nil,
        externalDeselectionToken: Int = 0
    ) {
        self.gamepadType = gamepadType
        self.canSelectCommand = canSelectCommand
        self.isCommandSelected = isCommandSelected
        self.onCommandSelected = onCommandSelected
        self.onCommandDeselected = onCommandDeselected
        self.resetToken = resetToken
        self.selectionSyncToken = selectionSyncToken
        self.externalDeselectionCommand = externalDeselectionCommand
        self.externalDeselectionToken = externalDeselectionToken
    }
    
    @SwiftUI.State private var activeButtons: Set<GamepadToggleTarget> = []
    @SwiftUI.State private var dpadHighlight: DPadHighlight = .none
    @SwiftUI.State private var dpadWholePressed = false
    @SwiftUI.State private var leftStickHighlight: StickHighlightMode = .none
    @SwiftUI.State private var rightStickHighlight: StickHighlightMode = .none
    
    @SwiftUI.State private var pendingWidgetOptions: [GamepadWidget] = []
    @SwiftUI.State private var showWidgetPicker = false
    @SwiftUI.State private var pickerSourceIsDPad = false
    
    @SwiftUI.State private var leftTriggerHighlight: TriggerHighlightMode = .none
    @SwiftUI.State private var rightTriggerHighlight: TriggerHighlightMode = .none
    @SwiftUI.State private var ds4TouchHighlight: DS4TouchHighlightMode = .none
    @SwiftUI.State private var lastAppliedResetToken: Int = 0
    @SwiftUI.State private var lastAppliedSelectionSyncToken: Int = 0
    @SwiftUI.State private var lastAppliedExternalDeselectionToken: Int = 0

    static var tappedWidgets: [GamepadWidget] = []
    static var selectedCmd: String = ""
    private struct Layout {
        
        // MARK: - Body
        
        static let aspectRatio: CGFloat = 1.82
        static let bodyCornerRadiusRatio: CGFloat = 0.3
        static let bodyShadowYOffsetRatio: CGFloat = 0.035
        static let innerStrokeInsetRatio: CGFloat = 0.018
        static let radialHighlightEndRadiusRatio: CGFloat = 0.48
        static let innerContentScale: CGFloat = 1.13
        static let ds4TouchpadWidthRatio: CGFloat = 0.2
        static let ds4TouchpadHeightRatio: CGFloat = 0.135
        static let ds4TouchpadCornerRatio: CGFloat = 0.30
        
        // MARK: - Top decoration
        
        static let topTriggerStubHorizontalPaddingRatio: CGFloat = 0.11
        static let topTriggerStubCenterYRatio: CGFloat = -0.236
        static let topTriggerStubCenterXRatio: CGFloat = 0.008
        
        static let topTriggerStubWidthRatio: CGFloat = 0.1062
        static let topTriggerStubHeightRatio: CGFloat = 0.0670
        static let topTriggerStubSpacingRatio: CGFloat = 0.4336
        
        static let shoulderBarWidthRatio: CGFloat = 0.24
        static let shoulderBarHeightRatio: CGFloat = 0.04
        static let shoulderBarInsetFromSideRatio: CGFloat = 0.06
        static let shoulderBarCenterYRatio: CGFloat = -0.49

        // MARK: - Component sizes
        
        static let leftStickSizeRatio: CGFloat = 0.17
        static let rightStickSizeRatio: CGFloat = 0.17
        static let dpadSizeRatio: CGFloat = 0.17
        static let abxySizeRatio: CGFloat = 0.19
        
        /// 顶部 +/- 和右下角 Home 共用直径
        static let smallTopButtonDiameterRatio: CGFloat = 0.053
        
        // MARK: - Constraint groups
        
        /// DPad / 右摇杆 共用水平轴
        static let lowerControlCenterYRatio: CGFloat = 0.16
        
        /// DPad / 右摇杆 关于中线左右对称
        static let lowerControlHalfSpacingRatio: CGFloat = 0.16
        
        /// 顶部 +/- 共用水平轴
        static let topButtonCenterYRatio: CGFloat = -0.24
        
        // MARK: - Left stick / ABXY / Home
        
        static let leftStickCenterXRatio: CGFloat = -0.28
        static let leftStickCenterYRatio: CGFloat = -0.07
        
        /// Home 的垂直轴，ABXY 与它垂直对齐
        static let homeCenterXRatio: CGFloat = 0.3
        
        /// Home 的垂直偏移，允许手调
        static let homeCenterYRatio: CGFloat = 0.267
    }
    
    private func toggle(_ target: GamepadToggleTarget) {
        if activeButtons.contains(target) {
            activeButtons.remove(target)
            for widget in target.widgets {
                onCommandDeselected?(widget.cmd)
            }
        } else {
            activeButtons.insert(target)
            let didAccept = handleTappedWidgets(target.widgets, sourceIsDPad: false)
            if !didAccept {
                activeButtons.remove(target)
            }
        }
    }
    
    @discardableResult
    private func handleTappedWidgets(_ widgets: [GamepadWidget], sourceIsDPad: Bool) -> Bool {
        AbstractGamepadView.tappedWidgets = widgets
        pickerSourceIsDPad = sourceIsDPad
                
        print(AbstractGamepadView.tappedWidgets)
        
        guard !widgets.isEmpty else { return false }
        
        if widgets.count == 1, let widget = widgets.first {
            return applySelectedWidget(widget, sourceIsDPad: sourceIsDPad)
        } else {
            pendingWidgetOptions = widgets
            showWidgetPicker = true
            return true
        }
    }
    
    private func nextStickHighlightMode(
        current: StickHighlightMode,
        selected widget: GamepadWidget,
        outerWidget: GamepadWidget,
        thumbWidgets: [GamepadWidget]
    ) -> StickHighlightMode {
        
        if widget == outerWidget {
            switch current {
            case .thumbOnly, .both:
                return .both
            case .none, .outerOnly:
                return .outerOnly
            }
        }
        
        if thumbWidgets.contains(widget) {
            switch current {
            case .outerOnly:
                // 只有“先按键，再选 pad/thumb”才允许两块都亮
                return .both
            case .none, .thumbOnly, .both:
                // 先选过 pad/thumb，或者已经是 both，再选 pad/thumb，都不升级为 both
                return .thumbOnly
            }
        }
        
        return current
    }

    private func applyStickSelection(_ widget: GamepadWidget) {
        switch widget {
        case .ls, .lsPad, .lswheel:
            leftStickHighlight = nextStickHighlightMode(
                current: leftStickHighlight,
                selected: widget,
                outerWidget: .ls,
                thumbWidgets: [.lsPad, .lswheel]
            )
            
        case .rs, .rsPad, .rsvPad:
            rightStickHighlight = nextStickHighlightMode(
                current: rightStickHighlight,
                selected: widget,
                outerWidget: .rs,
                thumbWidgets: [.rsPad, .rsvPad]
            )
            if widget == .rs,
               isCommandSelected?(GamepadWidget.rsPad.cmd) == true || isCommandSelected?(GamepadWidget.rsvPad.cmd) == true {
                rightStickHighlight = .both
            }
            
        default:
            break
        }
    }

    @discardableResult
    private func applySelectedWidget(_ widget: GamepadWidget, sourceIsDPad: Bool) -> Bool {
        if canSelectCommand?(widget.cmd) == false {
            return false
        }
        AbstractGamepadView.selectedCmd = widget.cmd
        onCommandSelected?(widget.cmd)
        
        if sourceIsDPad {
            applyDPadSelection(widget)
        }
        
        applyStickSelection(widget)
        applyTriggerSelection(widget)
        applyDS4TouchSelection(widget)
        
        print("selectedCmd =", AbstractGamepadView.selectedCmd)
        return true
    }
    
    private func applyTriggerSelection(_ widget: GamepadWidget) {
        switch widget {
        case .leftTrigger:
            leftTriggerHighlight = .button
        case .ltPad:
            leftTriggerHighlight = .pad
        case .rightTrigger:
            rightTriggerHighlight = .button
        case .rtPad:
            rightTriggerHighlight = .pad
        default:
            break
        }
    }
    
    private func selectWidget(_ widget: GamepadWidget) {
        let didSelect = applySelectedWidget(widget, sourceIsDPad: pickerSourceIsDPad)
        if !didSelect {
            AbstractGamepadView.tappedWidgets = []
        }
        pendingWidgetOptions.removeAll()
        showWidgetPicker = false
    }

    private func applyDS4TouchSelection(_ widget: GamepadWidget) {
        switch widget {
        case .ds4Touchpad:
            ds4TouchHighlight = .pad
        case .ds4TouchpadButton:
            ds4TouchHighlight = .button
        default:
            break
        }
    }
    
    private func resetCurrentWidgetPickerSelection() {
        for widget in pendingWidgetOptions {
            onCommandDeselected?(widget.cmd)
        }
        clearHighlights(for: pendingWidgetOptions)
        AbstractGamepadView.tappedWidgets = []
        AbstractGamepadView.selectedCmd = ""
        showWidgetPicker = false
    }

    private func clearHighlights(for widgets: [GamepadWidget]) {
        if widgets.contains(.dPad) || widgets.contains(.up) || widgets.contains(.down) || widgets.contains(.left) || widgets.contains(.right) {
            dpadHighlight = .none
        }
        
        if widgets.contains(.ls) || widgets.contains(.lsPad) || widgets.contains(.lswheel) {
            leftStickHighlight = .none
        }
        
        if widgets.contains(.rs) || widgets.contains(.rsPad) || widgets.contains(.rsvPad) {
            rightStickHighlight = .none
        }
        
        if widgets.contains(.leftTrigger) || widgets.contains(.ltPad) {
            leftTriggerHighlight = .none
        }

        if widgets.contains(.rightTrigger) || widgets.contains(.rtPad) {
            rightTriggerHighlight = .none
        }

        if widgets.contains(.ds4Touchpad) || widgets.contains(.ds4TouchpadButton) {
            ds4TouchHighlight = .none
        }
    }
    
    private func toggleDPadSelection(for region: DPadHighlight) {
        _ = region
        
        if dpadWholePressed {
            dpadHighlight = .none
            dpadWholePressed = false
            onCommandDeselected?(GamepadWidget.dPad.cmd)
            return
        }
        
        handleTappedWidgets([.dPad, .up, .down, .left, .right], sourceIsDPad: true)
    }
    
    private func applyDPadSelection(_ widget: GamepadWidget) {
        switch widget {
        case .dPad:
            dpadHighlight = .none
            dpadWholePressed = true
            
        case .up:
            dpadWholePressed = false
            if dpadHighlight.contains(.up) {
                dpadHighlight.remove(.up)
            } else {
                dpadHighlight.insert(.up)
            }
            
        case .down:
            dpadWholePressed = false
            if dpadHighlight.contains(.down) {
                dpadHighlight.remove(.down)
            } else {
                dpadHighlight.insert(.down)
            }
            
        case .left:
            dpadWholePressed = false
            if dpadHighlight.contains(.left) {
                dpadHighlight.remove(.left)
            } else {
                dpadHighlight.insert(.left)
            }
            
        case .right:
            dpadWholePressed = false
            if dpadHighlight.contains(.right) {
                dpadHighlight.remove(.right)
            } else {
                dpadHighlight.insert(.right)
            }
            
        default:
            break
        }
    }
    
    private func makeRect(centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(
            x: centerX - width * 0.5,
            y: centerY - height * 0.5,
            width: width,
            height: height
        )
    }
    
    private func triggerRects(
        containerW: CGFloat,
        containerH: CGFloat,
        w: CGFloat,
        h: CGFloat
    ) -> (left: CGRect, right: CGRect) {
        
        let triggerWidth = w * Layout.topTriggerStubWidthRatio
        let triggerHeight = h * Layout.topTriggerStubHeightRatio
        let triggerSpacing = w * Layout.topTriggerStubSpacingRatio
        
        let padX = w * Layout.topTriggerStubHorizontalPaddingRatio
        let offsetX = h * Layout.topTriggerStubCenterXRatio
        let offsetY = h * Layout.topTriggerStubCenterYRatio
        
        let finalOffsetX = offsetX * 2 - containerW * 0.012
        let finalOffsetY = offsetY * 2
        
        let stackContentWidth = triggerWidth * 2 + triggerSpacing
        let stackFrameWidth = stackContentWidth + padX * 2
        
        let leftCenterXInStack = (containerW - stackFrameWidth) * 0.5 + padX + triggerWidth * 0.5
        let rightCenterXInStack = leftCenterXInStack + triggerWidth + triggerSpacing
        
        let triggerCenterY = containerH * 0.5 + finalOffsetY
        let leftTriggerCenterX = leftCenterXInStack + finalOffsetX
        let rightTriggerCenterX = rightCenterXInStack + finalOffsetX
        
        return (
            makeRect(centerX: leftTriggerCenterX, centerY: triggerCenterY, width: triggerWidth, height: triggerHeight),
            makeRect(centerX: rightTriggerCenterX, centerY: triggerCenterY, width: triggerWidth, height: triggerHeight)
        )
    }
    
    private func handleShoulderTap(
        localPoint: CGPoint,
        side: GamepadToggleTarget,
        shoulderOverlaySize: CGSize,
        shoulderOffsetX: CGFloat,
        shoulderOffsetY: CGFloat,
        containerW: CGFloat,
        containerH: CGFloat,
        triggerRect: CGRect
    ) {
        let overlayOriginX = (containerW - shoulderOverlaySize.width) * 0.5 + shoulderOffsetX - containerW * 0.012
        let overlayOriginY = (containerH - shoulderOverlaySize.height) * 0.5 + shoulderOffsetY
        
        let pointInContainer = CGPoint(
            x: overlayOriginX + localPoint.x,
            y: overlayOriginY + localPoint.y
        )
        
        if pointInContainer.x >= triggerRect.minX && pointInContainer.x <= triggerRect.maxX {
            switch side {
            case .leftShoulder:
                handleTappedWidgets([.leftTrigger, .ltPad], sourceIsDPad: false)
            case .rightShoulder:
                handleTappedWidgets([.rightTrigger, .rtPad], sourceIsDPad: false)
            default:
                toggle(side)
            }
        } else {
            toggle(side)
        }
    }
    
    var body: some View {
        GeometryReader { geo in
            let containerW = geo.size.width
            let containerH = geo.size.height
            let contentScale = Layout.innerContentScale
            
            let w = containerW * contentScale
            let h = containerH * contentScale
            
            let cornerRadius = h * Layout.bodyCornerRadiusRatio
            
            // 尺寸
            let leftStickSize = w * Layout.leftStickSizeRatio
            let rightStickSize = w * Layout.rightStickSizeRatio
            let dpadSize = w * Layout.dpadSizeRatio
            let abxySize = w * Layout.abxySizeRatio
            let smallTopButtonDiameter = w * Layout.smallTopButtonDiameterRatio
            
            // 位置约束
            let sharedLowerControlCenterY = h * Layout.lowerControlCenterYRatio
            let lowerControlHalfSpacing = w * Layout.lowerControlHalfSpacingRatio
            
            let dpadCenterX = -lowerControlHalfSpacing
            let rightStickCenterX = lowerControlHalfSpacing
            
            let sharedTopButtonCenterY = h * Layout.topButtonCenterYRatio
            let minusButtonCenterX = dpadCenterX
            let plusButtonCenterX = rightStickCenterX
            let ds4TouchpadCenterX = (dpadCenterX + rightStickCenterX) * 0.5
            let ds4TouchpadWidth = w * Layout.ds4TouchpadWidthRatio
            let ds4TouchpadHeight = h * Layout.ds4TouchpadHeightRatio
            let ds4TouchpadCenterY = (-containerH * 0.5) + (ds4TouchpadHeight * 0.5)
            
            let leftStickCenterX = w * Layout.leftStickCenterXRatio
            let leftStickCenterY = h * Layout.leftStickCenterYRatio
            
            let homeCenterX = w * Layout.homeCenterXRatio
            let homeCenterY = h * Layout.homeCenterYRatio
            
            // ABXY：与 Home 垂直对齐；与左摇杆同一水平轴
            let abxyCenterX = homeCenterX
            let abxyCenterY = leftStickCenterY
            
            let shoulderBarWidth = w * Layout.shoulderBarWidthRatio
            let shoulderBarHeight = h * Layout.shoulderBarHeightRatio
            let shoulderBarCenterY = h * Layout.shoulderBarCenterYRatio
            
            let shoulderHalfX = (w * 0.5) - (w * Layout.shoulderBarInsetFromSideRatio) - (shoulderBarWidth * 0.5)
            let leftShoulderX = -shoulderHalfX
            let rightShoulderX = shoulderHalfX
            
            let triggerRects = triggerRects(
                containerW: containerW,
                containerH: containerH,
                w: w,
                h: h
            )
            
            let triggerStubWidth = w * Layout.topTriggerStubWidthRatio
            let triggerStubHeight = h * Layout.topTriggerStubHeightRatio
            let triggerStubSpacing = w * Layout.topTriggerStubSpacingRatio
            
            let shoulderHitWidth = shoulderBarWidth * 1.25
            let shoulderHitHeight = max(28, shoulderBarHeight * 5.5)
            
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.12))
                    .blur(radius: 18)
                    .offset(y: h * Layout.bodyShadowYOffsetRatio)
                
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.25, green: 0.86, blue: 0.90),
                                Color(red: 0.17, green: 0.76, blue: 0.82)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.22), lineWidth: 1.2)
                    )
                
                RoundedRectangle(cornerRadius: cornerRadius * 0.88, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 2)
                    .padding(w * Layout.innerStrokeInsetRatio)
                
                ZStack {
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.14),
                            Color.clear
                        ]),
                        center: .top,
                        startRadius: 10,
                        endRadius: w * Layout.radialHighlightEndRadiusRatio
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    )
                    
                    // 保持你原来的 trigger 布局，不改位置
                    HStack(spacing: triggerStubSpacing) {
                        TopTriggerStub(
                            width: triggerStubWidth,
                            height: triggerStubHeight,
                            highlightMode: leftTriggerHighlight
                        )
                        
                        TopTriggerStub(
                            width: triggerStubWidth,
                            height: triggerStubHeight,
                            highlightMode: rightTriggerHighlight
                        )
                    }
                    .padding(.horizontal, w * Layout.topTriggerStubHorizontalPaddingRatio)
                    .offset(y: h * Layout.topTriggerStubCenterYRatio)
                    .offset(x: h * Layout.topTriggerStubCenterXRatio)
                    .padding(.horizontal, w * Layout.topTriggerStubHorizontalPaddingRatio)
                    .offset(y: h * Layout.topTriggerStubCenterYRatio)
                    .offset(x: h * Layout.topTriggerStubCenterXRatio)
                    .zIndex(0)
                    
                    // 肩键：如果触点落在对应 trigger frame，就优先切换 trigger
                    ShoulderButtonBarButton(
                        isHighlighted: activeButtons.contains(.leftShoulder),
                        width: shoulderBarWidth,
                        height: shoulderBarHeight
                    ) { localPoint in
                        handleShoulderTap(
                            localPoint: localPoint,
                            side: .leftShoulder,
                            shoulderOverlaySize: CGSize(width: shoulderHitWidth, height: shoulderHitHeight),
                            shoulderOffsetX: leftShoulderX * 1.005,
                            shoulderOffsetY: shoulderBarCenterY * 0.902,
                            containerW: containerW,
                            containerH: containerH,
                            triggerRect: triggerRects.left
                        )
                    }
                    .offset(x: leftShoulderX * 1.005, y: shoulderBarCenterY * 0.902)
                    
                    ShoulderButtonBarButton(
                        isHighlighted: activeButtons.contains(.rightShoulder),
                        width: shoulderBarWidth,
                        height: shoulderBarHeight,
                        flipped: true
                    ) { localPoint in
                        handleShoulderTap(
                            localPoint: localPoint,
                            side: .rightShoulder,
                            shoulderOverlaySize: CGSize(width: shoulderHitWidth, height: shoulderHitHeight),
                            shoulderOffsetX: rightShoulderX * 1.065,
                            shoulderOffsetY: shoulderBarCenterY * 0.902,
                            containerW: containerW,
                            containerH: containerH,
                            triggerRect: triggerRects.right
                        )
                    }
                    .offset(x: rightShoulderX * 1.065, y: shoulderBarCenterY * 0.902)
                    
                    SmallRoundIconButton(
                        symbol: "−",
                        diameter: smallTopButtonDiameter,
                        isHighlighted: activeButtons.contains(.select)
                    )
                    .offset(x: minusButtonCenterX, y: sharedTopButtonCenterY)
                    .onTapGesture {
                        toggle(.select)
                    }
                    
                    SmallRoundIconButton(
                        symbol: "+",
                        diameter: smallTopButtonDiameter,
                        isHighlighted: activeButtons.contains(.start)
                    )
                    .offset(x: plusButtonCenterX, y: sharedTopButtonCenterY)
                    .onTapGesture {
                        toggle(.start)
                    }

                    if gamepadType == .ps {
                        DS4TouchpadView(
                            width: ds4TouchpadWidth,
                            height: ds4TouchpadHeight,
                            highlightMode: ds4TouchHighlight
                        )
                        .offset(x: ds4TouchpadCenterX, y: ds4TouchpadCenterY)
                        .onTapGesture {
                            handleTappedWidgets([.ds4Touchpad, .ds4TouchpadButton], sourceIsDPad: false)
                        }
                    }
                    
                    StickView(highlightMode: leftStickHighlight)
                        .frame(width: leftStickSize, height: leftStickSize)
                        .offset(x: leftStickCenterX, y: leftStickCenterY)
                        .onTapGesture {
                            handleTappedWidgets([.ls, .lswheel, .lsPad], sourceIsDPad: false)
                        }
                    
                    DPadXboxStyleView(
                        highlight: dpadHighlight,
                        wholePressed: dpadWholePressed
                    ) { tappedRegion in
                        toggleDPadSelection(for: tappedRegion)
                    }
                    .frame(width: dpadSize, height: dpadSize)
                    .offset(x: dpadCenterX, y: sharedLowerControlCenterY)
                    
                    ABXYClusterView(
                        gamepadType: gamepadType,
                        highlightedButtons: activeButtons,
                        onTap: { target in
                            toggle(target)
                        }
                    )
                    .frame(width: abxySize, height: abxySize)
                    .offset(x: abxyCenterX, y: abxyCenterY)
                    
                    StickView(highlightMode: rightStickHighlight)
                        .frame(width: rightStickSize, height: rightStickSize)
                        .offset(x: rightStickCenterX, y: sharedLowerControlCenterY)
                        .onTapGesture {
                            handleTappedWidgets([.rs, .rsPad, .rsvPad], sourceIsDPad: false)
                        }
                    
                    HomeButtonView(
                        diameter: smallTopButtonDiameter,
                        isHighlighted: activeButtons.contains(.home)
                    )
                    .offset(x: homeCenterX, y: homeCenterY)
                    .onTapGesture {
                        toggle(.home)
                    }
                }
                .frame(width: containerW, height: containerH)
                .offset(x: -containerW * 0.012)
            }
            .frame(width: containerW, height: containerH)
        }
        .aspectRatio(Layout.aspectRatio, contentMode: .fit)
        .overlay(
            Group {
                if showWidgetPicker {
                    GamepadWidgetPickerOverlay(
                        widgets: pendingWidgetOptions,
                        onSelect: { widget in
                            selectWidget(widget)
                        },
                        onReset: {
                            resetCurrentWidgetPickerSelection()
                        },
                        onCancel: {
                            showWidgetPicker = false
                        }
                    )
                    .zIndex(999)
                }
            }
        )
        .onReceive(Just(resetToken)) { token in
            guard token != lastAppliedResetToken else { return }
            lastAppliedResetToken = token
            resetAllSelections()
        }
        .onReceive(Just(selectionSyncToken)) { token in
            guard token != lastAppliedSelectionSyncToken else { return }
            lastAppliedSelectionSyncToken = token
            synchronizeSelectionHighlights()
        }
        .onReceive(Just(externalDeselectionToken)) { token in
            guard token != lastAppliedExternalDeselectionToken else { return }
            lastAppliedExternalDeselectionToken = token
            if let command = externalDeselectionCommand, !command.isEmpty {
                deselectCommand(command)
            }
        }
        .onAppear {
            synchronizeSelectionHighlights()
        }
    }

    private func resetAllSelections() {
        activeButtons.removeAll()
        dpadHighlight = .none
        dpadWholePressed = false
        leftStickHighlight = .none
        rightStickHighlight = .none
        pendingWidgetOptions.removeAll()
        showWidgetPicker = false
        pickerSourceIsDPad = false
        leftTriggerHighlight = .none
        rightTriggerHighlight = .none
        ds4TouchHighlight = .none
        AbstractGamepadView.tappedWidgets = []
        AbstractGamepadView.selectedCmd = ""
    }

    private func synchronizeSelectionHighlights() {
        resetAllSelections()

        guard let isCommandSelected = isCommandSelected else { return }

        if isCommandSelected(GamepadWidget.a.cmd) { activeButtons.insert(.a) }
        if isCommandSelected(GamepadWidget.b.cmd) { activeButtons.insert(.b) }
        if isCommandSelected(GamepadWidget.x.cmd) { activeButtons.insert(.x) }
        if isCommandSelected(GamepadWidget.y.cmd) { activeButtons.insert(.y) }
        if isCommandSelected(GamepadWidget.select.cmd) { activeButtons.insert(.select) }
        if isCommandSelected(GamepadWidget.start.cmd) { activeButtons.insert(.start) }
        if isCommandSelected(GamepadWidget.home.cmd) { activeButtons.insert(.home) }
        if isCommandSelected(GamepadWidget.leftShoulder.cmd) { activeButtons.insert(.leftShoulder) }
        if isCommandSelected(GamepadWidget.rightShoulder.cmd) { activeButtons.insert(.rightShoulder) }

        if isCommandSelected(GamepadWidget.dPad.cmd) {
            dpadWholePressed = true
        } else {
            if isCommandSelected(GamepadWidget.up.cmd) { dpadHighlight.insert(.up) }
            if isCommandSelected(GamepadWidget.down.cmd) { dpadHighlight.insert(.down) }
            if isCommandSelected(GamepadWidget.left.cmd) { dpadHighlight.insert(.left) }
            if isCommandSelected(GamepadWidget.right.cmd) { dpadHighlight.insert(.right) }
        }

        if isCommandSelected(GamepadWidget.ls.cmd) {
            leftStickHighlight = .outerOnly
        }
        if isCommandSelected(GamepadWidget.lsPad.cmd) || isCommandSelected(GamepadWidget.lswheel.cmd) {
            leftStickHighlight = leftStickHighlight == .outerOnly ? .both : .thumbOnly
        }

        if isCommandSelected(GamepadWidget.rs.cmd) {
            rightStickHighlight = .outerOnly
        }
        if isCommandSelected(GamepadWidget.rsPad.cmd) || isCommandSelected(GamepadWidget.rsvPad.cmd) {
            rightStickHighlight = rightStickHighlight == .outerOnly ? .both : .thumbOnly
        }

        if isCommandSelected(GamepadWidget.leftTrigger.cmd) {
            leftTriggerHighlight = .button
        } else if isCommandSelected(GamepadWidget.ltPad.cmd) {
            leftTriggerHighlight = .pad
        }

        if isCommandSelected(GamepadWidget.rightTrigger.cmd) {
            rightTriggerHighlight = .button
        } else if isCommandSelected(GamepadWidget.rtPad.cmd) {
            rightTriggerHighlight = .pad
        }

        if isCommandSelected(GamepadWidget.ds4TouchpadButton.cmd) {
            ds4TouchHighlight = .button
        } else if isCommandSelected(GamepadWidget.ds4Touchpad.cmd) {
            ds4TouchHighlight = .pad
        }
    }

    private func deselectCommand(_ command: String) {
        switch command {
        case GamepadWidget.a.cmd: activeButtons.remove(.a)
        case GamepadWidget.b.cmd: activeButtons.remove(.b)
        case GamepadWidget.x.cmd: activeButtons.remove(.x)
        case GamepadWidget.y.cmd: activeButtons.remove(.y)
        case GamepadWidget.select.cmd: activeButtons.remove(.select)
        case GamepadWidget.start.cmd: activeButtons.remove(.start)
        case GamepadWidget.home.cmd: activeButtons.remove(.home)
        case GamepadWidget.leftShoulder.cmd: activeButtons.remove(.leftShoulder)
        case GamepadWidget.rightShoulder.cmd: activeButtons.remove(.rightShoulder)
        case GamepadWidget.dPad.cmd:
            dpadWholePressed = false
            dpadHighlight = .none
        case GamepadWidget.up.cmd:
            dpadHighlight.remove(.up)
        case GamepadWidget.down.cmd:
            dpadHighlight.remove(.down)
        case GamepadWidget.left.cmd:
            dpadHighlight.remove(.left)
        case GamepadWidget.right.cmd:
            dpadHighlight.remove(.right)
        case GamepadWidget.ls.cmd:
            if leftStickHighlight == .both {
                leftStickHighlight = .thumbOnly
            } else if leftStickHighlight == .outerOnly {
                leftStickHighlight = .none
            }
        case GamepadWidget.lsPad.cmd, GamepadWidget.lswheel.cmd:
            if leftStickHighlight == .both {
                leftStickHighlight = .outerOnly
            } else if leftStickHighlight == .thumbOnly {
                leftStickHighlight = .none
            }
        case GamepadWidget.rs.cmd:
            if rightStickHighlight == .both {
                rightStickHighlight = .thumbOnly
            } else if rightStickHighlight == .outerOnly {
                rightStickHighlight = .none
            }
        case GamepadWidget.rsPad.cmd, GamepadWidget.rsvPad.cmd:
            if rightStickHighlight == .both {
                rightStickHighlight = .outerOnly
            } else if rightStickHighlight == .thumbOnly {
                rightStickHighlight = .none
            }
        case GamepadWidget.leftTrigger.cmd:
            leftTriggerHighlight = .none
        case GamepadWidget.ltPad.cmd:
            leftTriggerHighlight = .none
        case GamepadWidget.rightTrigger.cmd:
            rightTriggerHighlight = .none
        case GamepadWidget.rtPad.cmd:
            rightTriggerHighlight = .none
        case GamepadWidget.ds4Touchpad.cmd:
            ds4TouchHighlight = .none
        case GamepadWidget.ds4TouchpadButton.cmd:
            ds4TouchHighlight = .none
        default:
            break
        }

        if command == GamepadWidget.up.cmd || command == GamepadWidget.down.cmd || command == GamepadWidget.left.cmd || command == GamepadWidget.right.cmd {
            dpadWholePressed = false
        }

        if AbstractGamepadView.selectedCmd == command {
            AbstractGamepadView.selectedCmd = ""
        }
    }
}

@available(iOS 13.0, *)
struct GamepadWidgetPickerOverlay: View {
    let widgets: [GamepadWidget]
    let onSelect: (GamepadWidget) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }
    
    var body: some View {
        let cardSpacing: CGFloat = isPhone ? 8 : 14
        let titleFontSize: CGFloat = isPhone ? 15 : 18
        let optionSpacing: CGFloat = isPhone ? 6 : 10
        let optionHeight: CGFloat = isPhone ? 34 : 44
        let optionHorizontalPadding: CGFloat = isPhone ? 9 : 14
        let optionTitleFontSize: CGFloat = isPhone ? 12 : 15
        let optionCodeFontSize: CGFloat = isPhone ? 10 : 12
        let actionButtonHeight: CGFloat = isPhone ? 32 : 42
        let actionButtonFontSize: CGFloat = isPhone ? 12 : 15
        let cardPadding: CGFloat = isPhone ? 10 : 18
        let cardMaxWidth: CGFloat = isPhone ? 250 : 320
        let cardCornerRadius: CGFloat = isPhone ? 18 : 22
        let horizontalInset: CGFloat = isPhone ? 12 : 24
        let topInset: CGFloat = isPhone ? 8 : 0

        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 0) {
                VStack(spacing: cardSpacing) {
                    Text(SwiftLocalizationHelper.localizedString(forKey: "Select Control"))
                        .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    VStack(spacing: optionSpacing) {
                        ForEach(widgets, id: \.self) { widget in
                            Button(action: {
                                onSelect(widget)
                            }) {
                                HStack(spacing: isPhone ? 8 : 12) {
                                    Text(widget.description)
                                        .font(.system(size: optionTitleFontSize, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.6)
                                    
                                    Spacer()
                                    
                                    Text(widget.cmd)
                                        .font(.system(size: optionCodeFontSize, weight: .bold, design: .rounded))
                                        .foregroundColor(Color.white.opacity(0.72))
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, optionHorizontalPadding)
                                .frame(height: optionHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.10))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    HStack(spacing: isPhone ? 8 : 12) {
                        Button(action: {
                            onCancel()
                        }) {
                            Text(SwiftLocalizationHelper.localizedString(forKey: "Cancel"))
                                .font(.system(size: actionButtonFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .frame(height: actionButtonHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: {
                            onReset()
                        }) {
                            Text(SwiftLocalizationHelper.localizedString(forKey: "Reset"))
                                .font(.system(size: actionButtonFontSize, weight: .bold, design: .rounded))
                                .foregroundColor(Color.white.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .frame(height: actionButtonHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.black.opacity(0.16))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(cardPadding)
                .frame(maxWidth: cardMaxWidth)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.15, green: 0.46, blue: 0.50),
                                    Color(red: 0.11, green: 0.34, blue: 0.39)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                        )
                )
                .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
                .padding(.top, topInset)
                .padding(.horizontal, horizontalInset)

                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - 顶部小突起

@available(iOS 13.0, *)
struct TopTriggerStub: View {
    var width: CGFloat
    var height: CGFloat
    var highlightMode: TriggerHighlightMode = .none
    
    private var isHighlighted: Bool {
        highlightMode != .none
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isHighlighted ? [
                        highlightMode == .pad ? GamepadPadHighlightStyle.fillTop : GamepadButtonHighlightStyle.fillTop,
                        highlightMode == .pad ? GamepadPadHighlightStyle.fillBottom : GamepadButtonHighlightStyle.fillBottom
                    ] : [
                        Color.white.opacity(0.97),
                        Color(red: 0.86, green: 0.86, blue: 0.88)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
                    .stroke(
                        highlightMode == .pad ? GamepadPadHighlightStyle.stroke : (isHighlighted ? GamepadButtonHighlightStyle.stroke : Color.black.opacity(0.08)),
                        lineWidth: isHighlighted ? 1.4 : 1
                    )
            )
            .overlay(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(isHighlighted ? 0.18 : 0.28),
                        Color.clear
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(
                    RoundedRectangle(cornerRadius: height * 0.32, style: .continuous)
                )
            )
            .shadow(color: Color.black.opacity(0.10), radius: 2, x: 0, y: 1)
    }
}
// MARK: - 顶部 +/- 小按钮

@available(iOS 13.0, *)
struct SmallRoundIconButton: View {
    var symbol: String
    var diameter: CGFloat = 35
    var isHighlighted: Bool = false
    
    var body: some View {
        Circle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isHighlighted ? [
                        Color(red: 1.00, green: 0.92, blue: 0.50),
                        Color(red: 0.95, green: 0.73, blue: 0.22)
                    ] : [
                        Color(red: 0.23, green: 0.82, blue: 0.86),
                        Color(red: 0.16, green: 0.68, blue: 0.74)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Circle()
                    .stroke(
                        isHighlighted ? Color.orange.opacity(0.7) : Color.black.opacity(0.16),
                        lineWidth: isHighlighted ? 1.5 : 1
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isHighlighted ? 0.28 : 0.18), lineWidth: 1)
                    .padding(2)
            )
            .overlay(
                Text(symbol)
                    .font(.system(size: diameter * 0.65, weight: .bold, design: .rounded))
                    .foregroundColor(isHighlighted ? Color.white.opacity(0.95) : Color.white.opacity(0.65))
                    .offset(x: diameter * 0.013)
                    .offset(y: diameter * -0.042)
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: Color.black.opacity(0.12), radius: 3, x: 0, y: 2)
    }
}

@available(iOS 13.0, *)
struct DS4TouchpadView: View {
    private enum Ratio {
        static let corner: CGFloat = 0.30
        static let insetStroke: CGFloat = 0.06
        static let dotInsetX: CGFloat = 0.07
        static let dotInsetY: CGFloat = 0.10
        static let dotColumns: Int = 20
        static let dotRows: Int = 8
        static let dotSizeFactor: CGFloat = 0.28
    }

    var width: CGFloat
    var height: CGFloat
    var highlightMode: DS4TouchHighlightMode = .none
    
    private var isHighlighted: Bool {
        highlightMode != .none
    }
    
    private var fillTop: Color {
        highlightMode == .pad ? GamepadPadHighlightStyle.fillTop : GamepadButtonHighlightStyle.fillTop
    }
    
    private var fillBottom: Color {
        highlightMode == .pad ? GamepadPadHighlightStyle.fillBottom : GamepadButtonHighlightStyle.fillBottom
    }
    
    private var strokeColor: Color {
        highlightMode == .pad ? GamepadPadHighlightStyle.stroke : GamepadButtonHighlightStyle.stroke
    }

    private var dotColor: Color {
        if isHighlighted {
            return Color.white.opacity(0.28)
        }
        return Color.black.opacity(0.18)
    }

    private var recessedShadowOpacity: Double {
        isHighlighted ? 0.0 : 0.28
    }

    private var recessedShadowColor: Color {
        Color(red: 0.16, green: 0.45, blue: 0.54).opacity(recessedShadowOpacity * 0.9)
    }

    private var recessedHighlightColor: Color {
        Color.white.opacity(isHighlighted ? 0.0 : 0.10)
    }
    
    var body: some View {
        let cornerRadius = height * Ratio.corner
        let shape = DS4TouchpadShape(bottomCornerRadius: cornerRadius)
        
        shape
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isHighlighted ? [
                        fillTop,
                        fillBottom
                    ] : [
                        Color.clear,
                        Color.clear
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .contentShape(shape)
            .overlay(
                shape
                    .stroke(
                        isHighlighted ? strokeColor : Color.black.opacity(0.16),
                        lineWidth: isHighlighted ? 1.6 : 1
                    )
            )
            .overlay(
                DS4TouchpadShape(bottomCornerRadius: cornerRadius * 0.88)
                    .stroke(Color.white.opacity(isHighlighted ? 0.18 : 0.08), lineWidth: 1)
                    .padding(height * Ratio.insetStroke)
            )
            .overlay(
                dotPattern
                    .padding(.horizontal, width * Ratio.dotInsetX)
                    .padding(.vertical, height * Ratio.dotInsetY)
                    .clipShape(
                        DS4TouchpadShape(bottomCornerRadius: cornerRadius * 0.86)
                    )
            )
            .overlay(
                shape
                    .stroke(recessedShadowColor, lineWidth: 1.2)
                    .offset(y: 0.8)
                    .opacity(isHighlighted ? 0.0 : 0.9)
            )
            .overlay(
                shape
                    .stroke(recessedHighlightColor, lineWidth: 0.8)
                    .offset(y: -0.4)
                    .opacity(isHighlighted ? 0.0 : 1.0)
            )
            .shadow(color: Color(red: 0.14, green: 0.36, blue: 0.42).opacity(isHighlighted ? 0.10 : 0.010), radius: isHighlighted ? 3 : 0.6, x: 0, y: isHighlighted ? 2 : 0.2)
    }

    private var dotPattern: some View {
        GeometryReader { geo in
            DS4TouchpadDotGridShape(
                columns: Ratio.dotColumns,
                rows: Ratio.dotRows,
                dotSizeFactor: Ratio.dotSizeFactor
            )
            .fill(dotColor)
        }
    }
}

@available(iOS 13.0, *)
struct DS4TouchpadDotGridShape: Shape {
    let columns: Int
    let rows: Int
    let dotSizeFactor: CGFloat

    func path(in rect: CGRect) -> Path {
        guard columns > 0, rows > 0, rect.width > 0, rect.height > 0 else {
            return Path()
        }

        let cellWidth = rect.width / CGFloat(columns)
        let cellHeight = rect.height / CGFloat(rows)
        let dotDiameter = min(cellWidth, cellHeight) * dotSizeFactor
        let radius = dotDiameter * 0.5

        var path = Path()

        for row in 0..<rows {
            for column in 0..<columns {
                let center = CGPoint(
                    x: cellWidth * (CGFloat(column) + 0.5),
                    y: cellHeight * (CGFloat(row) + 0.5)
                )
                let dotRect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: dotDiameter,
                    height: dotDiameter
                )
                path.addEllipse(in: dotRect)
            }
        }

        return path
    }
}

@available(iOS 13.0, *)
struct DS4TouchpadShape: Shape {
    let bottomCornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let radius = min(bottomCornerRadius, rect.width * 0.5, rect.height)
        
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addArc(
            center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(0),
            endAngle: .degrees(90),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addArc(
            center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
            radius: radius,
            startAngle: .degrees(90),
            endAngle: .degrees(180),
            clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 摇杆
@available(iOS 13.0, *)
private enum GamepadPadHighlightStyle {
    static let fillTop = Color(red: 0.82, green: 0.84, blue: 1.00).opacity(0.92)
    static let fillBottom = Color(red: 0.56, green: 0.60, blue: 0.94).opacity(0.84)
    static let stroke = Color(red: 0.38, green: 0.42, blue: 0.82).opacity(0.90)
}

@available(iOS 13.0, *)
private enum GamepadButtonHighlightStyle {
    static let fillTop = Color(red: 1.00, green: 0.96, blue: 0.72)
    static let fillBottom = Color(red: 0.95, green: 0.78, blue: 0.34)
    static let stroke = Color.orange.opacity(0.75)
}


@available(iOS 13.0, *)
struct StickView: View {
    
    private struct Ratio {
        static let base: CGFloat = 0.66
        static let shell: CGFloat = 0.60
        static let thumb: CGFloat = 0.45
        static let shadowOffsetX: CGFloat = 0
        static let shadowOffsetY: CGFloat = 0
    }
    
    var highlightMode: StickHighlightMode = .none
    
    private var outerHighlighted: Bool {
        highlightMode == .outerOnly || highlightMode == .both
    }

    private var thumbHighlighted: Bool {
        highlightMode == .thumbOnly || highlightMode == .both
    }
    
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.18))
                    .frame(width: s * Ratio.base, height: s * Ratio.base)
                    .offset(
                        x: s * Ratio.shadowOffsetX,
                        y: s * Ratio.shadowOffsetY
                    )
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: outerHighlighted ? [
                                GamepadButtonHighlightStyle.fillTop,
                                GamepadButtonHighlightStyle.fillBottom
                            ] : [
                                Color.white.opacity(0.98),
                                Color(red: 0.88, green: 0.88, blue: 0.90)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: s * Ratio.shell, height: s * Ratio.shell)
                    .overlay(
                        Circle()
                            .stroke(
                                outerHighlighted ? GamepadButtonHighlightStyle.stroke : Color.black.opacity(0.10),
                                lineWidth: outerHighlighted ? 1.5 : 1
                            )
                    )
                
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: thumbHighlighted ? [
                                GamepadPadHighlightStyle.fillTop,
                                GamepadPadHighlightStyle.fillBottom
                            ] : [
                                Color(red: 0.95, green: 0.95, blue: 0.96),
                                Color(red: 0.86, green: 0.86, blue: 0.88)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: s * Ratio.thumb, height: s * Ratio.thumb)
                    .overlay(
                        Circle()
                            .stroke(
                                thumbHighlighted ? GamepadPadHighlightStyle.stroke : Color.black.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}// MARK: - 十字键

@available(iOS 13.0, *)
struct DPadXboxStyleView: View {
    var highlight: DPadHighlight = .none
    var wholePressed: Bool = false
    var onTapRegion: ((DPadHighlight) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let arm = s * 0.78
            let thickness = s * 0.30
            
            ZStack {
                DPadCrossShape()
                    .fill(Color.black.opacity(0.25))
                    .frame(width: arm, height: arm)
                    .offset(x: -2, y: 3)
                    .blur(radius: 1)
                
                DPadCrossShape()
                    .fill(Color.black.opacity(0.90))
                    .frame(width: arm, height: arm)
                
                DPadCrossBaseView(
                    arm: arm,
                    highlight: highlight,
                    wholePressed: wholePressed
                )
                
                Group {
                    Text("▴").offset(y: -thickness * 0.95)
                    Text("▾").offset(y: thickness * 0.95)
                    Text("◂").offset(x: -thickness * 0.95)
                    Text("▸").offset(x: thickness * 0.95)
                }
                .font(.system(size: s * 0.14, weight: .bold))
                .foregroundColor(
                    highlight == .none
                    ? Color.black.opacity(0.12)
                    : Color.black.opacity(0.22)
                )
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let region = resolveDPadRegion(
                            point: value.location,
                            size: geo.size
                        )
                        onTapRegion?(region)
                    }
            )
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private func resolveDPadRegion(point: CGPoint, size: CGSize) -> DPadHighlight {
        let s = min(size.width, size.height)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = point.x - center.x
        let dy = point.y - center.y
        
        let centerHalf: CGFloat = s * 0.15
        if abs(dx) <= centerHalf && abs(dy) <= centerHalf {
            return .all
        }
        
        if abs(dx) > abs(dy) {
            return dx < 0 ? .left : .right
        } else {
            return dy < 0 ? .up : .down
        }
    }
}

@available(iOS 13.0.0, *)
struct DPadCrossBaseView: View {
    let arm: CGFloat
    let highlight: DPadHighlight
    let wholePressed: Bool
    
    var body: some View {
        ZStack {
            dpadSegment(.up)
            dpadSegment(.down)
            dpadSegment(.left)
            dpadSegment(.right)
            centerSquare
        }
        .frame(width: arm - 2, height: arm - 1)
    }
    
    @ViewBuilder
    private func dpadSegment(_ dir: DPadHighlight) -> some View {
        let isOn = wholePressed || highlight.contains(dir)
        let usePadHighlight = wholePressed
        
        DPadSegmentShape(direction: dir)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isOn ? [
                        usePadHighlight ? GamepadPadHighlightStyle.fillTop : GamepadButtonHighlightStyle.fillTop,
                        usePadHighlight ? GamepadPadHighlightStyle.fillBottom : GamepadButtonHighlightStyle.fillBottom
                    ] : [
                        Color.white.opacity(0.98),
                        Color(red: 0.88, green: 0.88, blue: 0.90)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                DPadSegmentShape(direction: dir)
                    .stroke(
                        isOn ? (usePadHighlight ? GamepadPadHighlightStyle.stroke : GamepadButtonHighlightStyle.stroke) : Color.clear,
                        lineWidth: 1
                    )
            )
    }
    
    private var centerSquare: some View {
        let isOn = wholePressed
        
        return RoundedRectangle(cornerRadius: arm * 0.04, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isOn ? [
                        GamepadPadHighlightStyle.fillTop,
                        GamepadPadHighlightStyle.fillBottom
                    ] : [
                        Color.white.opacity(0.98),
                        Color(red: 0.87, green: 0.87, blue: 0.89)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: arm * 0.33, height: arm * 0.33)
            .overlay(
                RoundedRectangle(cornerRadius: arm * 0.04, style: .continuous)
                    .stroke(isOn ? GamepadPadHighlightStyle.stroke : Color.black.opacity(0.05), lineWidth: 1)
            )
    }
}

@available(iOS 13.0.0, *)
struct DPadCrossShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let half = w * 0.5
        let thickness = w * 0.33
        let tHalf = thickness * 0.5
        let radius = w * 0.06
        
        func rr(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Path {
            Path(
                roundedRect: CGRect(x: x, y: y, width: width, height: height),
                cornerRadius: radius
            )
        }
        
        var p = Path()
        p.addPath(rr(half - tHalf, 0, thickness, h))
        p.addPath(rr(0, half - tHalf, w, thickness))
        return p
    }
}

@available(iOS 13.0.0, *)
struct DPadSegmentShape: Shape {
    let direction: DPadHighlight
    
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let thickness = w * 0.33
        let halfT = thickness / 2
        let cx = w / 2
        let cy = h / 2
        let r = w * 0.06
        
        var p = Path()
        
        switch direction {
        case .up:
            p.addRoundedRect(
                in: CGRect(x: cx - halfT, y: 0, width: thickness, height: cy),
                cornerSize: CGSize(width: r, height: r)
            )
        case .down:
            p.addRoundedRect(
                in: CGRect(x: cx - halfT, y: cy, width: thickness, height: cy),
                cornerSize: CGSize(width: r, height: r)
            )
        case .left:
            p.addRoundedRect(
                in: CGRect(x: 0, y: cy - halfT, width: cx, height: thickness),
                cornerSize: CGSize(width: r, height: r)
            )
        case .right:
            p.addRoundedRect(
                in: CGRect(x: cx, y: cy - halfT, width: cx, height: thickness),
                cornerSize: CGSize(width: r, height: r)
            )
        default:
            break
        }
        
        return p
    }
}

// MARK: - ABXY

@available(iOS 13.0, *)
struct ABXYClusterView: View {
    let gamepadType: GamepadType
    let highlightedButtons: Set<GamepadToggleTarget>
    let onTap: (GamepadToggleTarget) -> Void
    
    var body: some View {
        GeometryReader { geo in
            let s = min(geo.size.width, geo.size.height)
            let offset = s * 0.3
            let size = s * 0.31
            
            ZStack {
                LetterButton(title: leftButtonTitle, size: size, isHighlighted: highlightedButtons.contains(.x))
                    .frame(width: size, height: size)
                    .offset(x: -offset, y: 0)
                    .onTapGesture { onTap(.x) }
                
                LetterButton(title: topButtonTitle, size: size, isHighlighted: highlightedButtons.contains(.y))
                    .frame(width: size, height: size)
                    .offset(x: 0, y: -offset)
                    .onTapGesture { onTap(.y) }
                
                LetterButton(title: rightButtonTitle, size: size, isHighlighted: highlightedButtons.contains(.b))
                    .frame(width: size, height: size)
                    .offset(x: offset, y: 0)
                    .onTapGesture { onTap(.b) }
                
                LetterButton(title: bottomButtonTitle, size: size, isHighlighted: highlightedButtons.contains(.a))
                    .frame(width: size, height: size)
                    .offset(x: 0, y: offset)
                    .onTapGesture { onTap(.a) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private var leftButtonTitle: String {
        gamepadType == .ps ? "□" : "X"
    }

    private var topButtonTitle: String {
        gamepadType == .ps ? "△" : "Y"
    }

    private var rightButtonTitle: String {
        gamepadType == .ps ? "○" : "B"
    }

    private var bottomButtonTitle: String {
        gamepadType == .ps ? "×" : "A"
    }
}

@available(iOS 13.0, *)
struct LetterButton: View {
    var title: String
    var size: CGFloat
    var isHighlighted: Bool = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.20))
                .offset(x: -1, y: 3)
                .blur(radius: 1)
            
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: isHighlighted ? [
                            Color(red: 1.00, green: 0.96, blue: 0.74),
                            Color(red: 0.95, green: 0.78, blue: 0.32)
                        ] : [
                            Color.white.opacity(0.98),
                            Color(red: 0.88, green: 0.88, blue: 0.90)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isHighlighted ? Color.orange.opacity(0.75) : Color.black.opacity(0.12),
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                )
            
            Text(title)
                .font(.system(size: size * 0.53, weight: .medium, design: .rounded))
                .foregroundColor(isHighlighted ? Color.black.opacity(0.58) : Color.black.opacity(0.28))
        }
    }
}

// MARK: - Home Button

@available(iOS 13.0, *)
struct HomeButtonView: View {
    var diameter: CGFloat
    var isHighlighted: Bool = false
    
    private var innerInset: CGFloat { diameter * 0.06 }
    private var shadowOffsetY: CGFloat { diameter * 0.05 }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.18))
                .offset(y: shadowOffsetY)
                .blur(radius: 1)
            
            Circle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: isHighlighted ? [
                            Color(red: 1.00, green: 0.92, blue: 0.52),
                            Color(red: 0.96, green: 0.74, blue: 0.24)
                        ] : [
                            Color(red: 0.25, green: 0.86, blue: 0.90),
                            Color(red: 0.18, green: 0.72, blue: 0.78)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            isHighlighted ? Color.orange.opacity(0.75) : Color.black.opacity(0.16),
                            lineWidth: isHighlighted ? 1.5 : 1
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isHighlighted ? 0.28 : 0.22), lineWidth: 1)
                        .padding(innerInset)
                )
            
            Image(systemName: "house")
                .font(.system(size: diameter * 0.45, weight: .bold))
                .foregroundColor(.white.opacity(isHighlighted ? 1.0 : 0.9))
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - 肩键
@available(iOS 13.0, *)
struct ShoulderButtonBarButton: View {
    var isHighlighted: Bool
    var width: CGFloat
    var height: CGFloat
    var flipped: Bool = false
    var action: (CGPoint) -> Void
    
    var body: some View {
        ZStack {
            ShoulderButtonBar(isHighlighted: isHighlighted)
                .scaleEffect(x: flipped ? -1 : 1, y: 1)
                .frame(width: width, height: height)
            
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            action(value.location)
                        }
                )
        }
        .frame(width: width * 1.25, height: max(28, height * 5.5))
    }
}

@available(iOS 13.0, *)
struct ShoulderButtonBar: View {
    var isHighlighted: Bool = false
    
    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let lineWidth = h * 1.16
            
            let shape = ShoulderCenterLineShape(
                startY: 4.5,
                controlX: 0.27,
                controlY: 0.35,
                endY: 0.45,
                horizontalTail: 0
            )
            
            ZStack {
                shape
                    .stroke(
                        Color.black.opacity(0.10),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(y: h * 0.07)
                    .blur(radius: 1)
                
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: isHighlighted ? [
                                Color(red: 1.00, green: 0.95, blue: 0.65),
                                Color(red: 0.95, green: 0.77, blue: 0.28)
                            ] : [
                                .white.opacity(0.22),
                                Color(red: 0.86, green: 0.86, blue: 0.88)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(
                            lineWidth: lineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                
                shape
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                isHighlighted ? .white.opacity(0.34) : .white.opacity(0.56)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(
                            lineWidth: lineWidth * 0.675,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .offset(y: -h * 0.05)
            }
        }
    }
}

@available(iOS 13.0, *)
struct ShoulderCenterLineShape: Shape {
    
    let startY: CGFloat
    let controlX: CGFloat
    let controlY: CGFloat
    let endY: CGFloat
    let horizontalTail: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        
        let left = w * 0.08
        let right = w * 0.94
        
        let start = CGPoint(x: left, y: h * startY)
        let control = CGPoint(x: w * controlX, y: h * controlY)

        let flattenStartX = right - w * 0.06
        let flattenStart = CGPoint(x: flattenStartX, y: h * endY)

        let end = CGPoint(x: right, y: h * endY)
        let tailEnd = CGPoint(x: right + w * horizontalTail, y: h * endY)

        var p = Path()
        p.move(to: start)

        p.addQuadCurve(
            to: flattenStart,
            control: control
        )

        p.addQuadCurve(
            to: end,
            control: CGPoint(x: right - w * 0.02, y: h * endY)
        )

        p.addLine(to: tailEnd)
        return p
    }
}

// MARK: - Preview
@available(iOS 13.0, *)
struct XboxAbstractPadView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color(red: 0.93, green: 0.93, blue: 0.94)
                .edgesIgnoringSafeArea(.all)
            
            AbstractGamepadView(gamepadType: .ps)
                .frame(width: 500, height: 330)
                .padding(20)
        }
        .previewLayout(.sizeThatFits)
    }
}
