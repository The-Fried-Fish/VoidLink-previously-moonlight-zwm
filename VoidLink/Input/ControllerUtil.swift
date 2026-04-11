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

@objc enum ControllerButton: Int {
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
    case menu    = 0x0010 // PLAY_FLAG
    case back    = 0x0020 // BACK_FLAG
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
    
    case null = 0xFFFFFF
}


@objc class ControllerUtil: NSObject {
    
    static private let stickMaxOffset:CGFloat = 0x7FFE
    @objc static var navigationActionTriggered:Bool = false
    @objc static private(set) var navigationActionTriggeredPrivate:Bool = false

    @objc static func listen(
        controller: GCController,
        swapABXY: Bool,
        handler: @escaping (_ buttonDict: NSDictionary,
                            _ gamepad: GCExtendedGamepad,
                            _ element: GCControllerElement) -> Void
    ) {
        guard let gamepad = controller.extendedGamepad else { return }
        
        // 内部生成 map
        var tempMap: [NSNumber: GCControllerButtonInput] = [:]
        let swiftMap = buildMapping(for: controller, swapABXY: swapABXY)
        for (button, input) in swiftMap {
            tempMap[NSNumber(value: button.rawValue)] = input
        }
        let buttonDict = tempMap as NSDictionary
        
        // 单一 gamepad.valueChangedHandler
        gamepad.valueChangedHandler = { gamepad, element in
            /*
            navigationActionTriggeredPrivate = (gamepad.dpad.up.isPressed
                                                || gamepad.dpad.down.isPressed
                                                || gamepad.dpad.left.isPressed
                                                || gamepad.dpad.right.isPressed
                                                || gamepad.buttonA.isPressed
                                                || gamepad.buttonB.isPressed
                                                || gamepad.buttonX.isPressed
                                                || gamepad.leftShoulder.isPressed
                                                || gamepad.rightShoulder.isPressed
                                                || gamepad.leftTrigger.value != 0
                                                || gamepad.rightTrigger.value != 0
                                                || gamepad.rightThumbstick.xAxis.value != 0
                                                || gamepad.rightThumbstick.yAxis.value != 0
                                                || gamepad.leftThumbstick.xAxis.value != 0
                                                || gamepad.leftThumbstick.yAxis.value != 0)
            if navigationActionTriggeredPrivate { navigationActionTriggered = true}
            else {
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                    if !navigationActionTriggeredPrivate {
                        navigationActionTriggered = false
                    }
                }
            }
            */
            handler(buttonDict, gamepad, element)
            if #available(iOS 13.0, *) {
                if controller.playerIndex == .index1 {
                    GamepadOverlayStateCenter.shared.publish(snapshot: GamepadOverlaySnapshot(gamepad: gamepad))
                }
            }
        }
    }
    
    
    // MARK: - 构建按钮映射
    private static func buildMapping(for controller: GCController, swapABXY:Bool)
    -> [ControllerButton : GCControllerButtonInput]
    {
        var result: [ControllerButton : GCControllerButtonInput] = [:]
        
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
            
            // Menu / Options / Share
            if #available(iOS 13.0, *) {
                result[.menu] = pad.buttonMenu
                if let options = pad.buttonOptions { result[.back] = options }
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
        return result
    }
    
    @objc static var activeGCControllers:NSMutableSet = NSMutableSet()
    
    @objc static func string(for button: ControllerButton) -> String {
        switch button {
        case .a: return "A"
        case .b: return "B"
        case .x: return "X"
        case .y: return "Y"
            
        case .dpadUp: return SwiftLocalizationHelper.localizedString(forKey: "Up")
        case .dpadDown: return SwiftLocalizationHelper.localizedString(forKey: "Down")
        case .dpadLeft: return SwiftLocalizationHelper.localizedString(forKey: "Left")
        case .dpadRight: return SwiftLocalizationHelper.localizedString(forKey: "Right")
            
        case .leftShoulder: return "LB"
        case .rightShoulder: return "RB"
            
        case .leftStickButton: return "LS"
        case .rightStickButton: return "RS"
            
        case .menu: return "Menu"
        case .back: return "Back"
        case .special: return "Home"
            
        case .paddle1: return SwiftLocalizationHelper.localizedString(forKey: "Paddle1")
        case .paddle2: return SwiftLocalizationHelper.localizedString(forKey: "Paddle2")
        case .paddle3: return SwiftLocalizationHelper.localizedString(forKey: "Paddle3")
        case .paddle4: return SwiftLocalizationHelper.localizedString(forKey: "Paddle4")
        case .touchpadButton: return SwiftLocalizationHelper.localizedString(forKey: "Touch button")
        case .misc: return "Misc"
            
        case .leftTrigger: return "LT"
        case .rightTrigger: return "RT"
            
        case .null: return SwiftLocalizationHelper.localizedString(forKey: "Null")
            
        default: return "UNKNOWN"
        }
    }
    
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

@available(iOS 13.0, *)
struct GamepadOverlaySnapshot: Equatable {
    var pressedButtons: Set<ControllerButton> = []
    var dpadHighlight: Int = 0
    var leftStick: CGPoint = .zero
    var rightStick: CGPoint = .zero
    var leftTrigger: CGFloat = 0
    var rightTrigger: CGFloat = 0

    static let idle = GamepadOverlaySnapshot()

    init() {}

    init(gamepad: GCExtendedGamepad) {
        var pressedButtons = Set<ControllerButton>()

        if gamepad.buttonA.isPressed { pressedButtons.insert(.a) }
        if gamepad.buttonB.isPressed { pressedButtons.insert(.b) }
        if gamepad.buttonX.isPressed { pressedButtons.insert(.x) }
        if gamepad.buttonY.isPressed { pressedButtons.insert(.y) }
        if gamepad.leftShoulder.isPressed { pressedButtons.insert(.leftShoulder) }
        if gamepad.rightShoulder.isPressed { pressedButtons.insert(.rightShoulder) }
        if gamepad.buttonMenu.isPressed { pressedButtons.insert(.menu) }
        if gamepad.buttonOptions?.isPressed == true { pressedButtons.insert(.back) }
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
