//
//  ControllerUtil.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/19.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


import GameController

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
    case touchpad = 0x100000
    case misc     = 0x200000
    
    case leftTrigger, rightTrigger
}


@objc class ControllerUtil: NSObject {
        
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
            handler(buttonDict, gamepad, element)
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
                        result[.touchpad] = touchpadBtn
                    }
                    if #available(iOS 15.0, tvOS 15.0, *) {
                        if let share = profile.buttons[GCInputButtonShare] {
                            result[.misc] = share
                        }
                    }
                }
            }
        }
        
        /*
        if let micro = controller.microGamepad {
            if #available(iOS 13.0, *) {
                result[.menu] = micro.buttonMenu
                result[.a] = micro.buttonA
                result[.x] = micro.buttonX
                result[.dpadUp] = micro.dpad.up
                result[.dpadDown] = micro.dpad.down
                result[.dpadLeft] = micro.dpad.left
                result[.dpadRight] = micro.dpad.right
                result[.menu] = micro.buttonMenu
            }
        }*/
        
        return result
    }
    
    
}
