//
//  TouchPadGestureHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/5.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

import UIKit

@objc class TouchPadGestureHandler: NSObject {
    
    @objc public static var ctrlDown:Bool = false
    @objc public static var enablePinch:Bool = true
    @objc public static var ctrlDownForPinch:Bool = true
    @objc public static var enableHorizontalScroll:Bool = true
    @objc public static var scrollSensitivity:CGFloat = 1.0
    @objc public static var pinchSensitivity:CGFloat = 1.0
    @objc public static func handleGesture(in view: UIView, with event: UIEvent) {
        let currentTouches = UITouchUtil.touches(in: view, from: event)
        guard currentTouches.count == 2 else { return }
        
        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
        
        guard let touch1 = currentTouches.first else { return }
        var mutable = Array(currentTouches)
        mutable.removeAll { $0 == touch1 }
        guard let touch2 = mutable.first else { return }
        
        let currentDistance = UITouchUtil.distance(between: touch1, and: touch2, in: view)
        let previousDistance = UITouchUtil.previousDistance(between: touch1, and: touch2, in: view)
        
        let midPointVector = UITouchUtil.midPointVector(between: touch1, and: touch2, in: view)
        let midPointDeltaX = midPointVector.dx
        let midPointDeltaY = midPointVector.dy
        
        let originalPinchDelta = currentDistance-previousDistance;
        let pinchDelta = enablePinch ? originalPinchDelta*7*pinchSensitivity : 0;
        LiSendHighResScrollEvent(Int16(pinchDelta + midPointDeltaY*7*scrollSensitivity))
        if enableHorizontalScroll {LiSendHighResHScrollEvent(Int16(-midPointDeltaX*7*scrollSensitivity))}
        
        if !enablePinch || !ctrlDownForPinch {return};
        
        if abs(originalPinchDelta) > abs(midPointDeltaY)*1.3, abs(originalPinchDelta) > abs(midPointDeltaX)*1.3 {
            LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_DOWN), 0)
            ctrlDown = true
        } else {
            LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_UP), 0)
            ctrlDown = false
        }
    }
}
