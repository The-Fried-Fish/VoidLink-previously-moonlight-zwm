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
    @objc public static var pinchZoom:Bool = false // Pinch Gesture: Zoom (touchpad mode only, handled by TouchpadZoomHandler)
    @objc public static var enableHorizontalScroll:Bool = true
    @objc public static var scrollSensitivity:CGFloat = 1.0
    @objc public static var pinchSensitivity:CGFloat = 1.0
    @objc public static var displayLinkRate:CGFloat = 60

    private static var inertialScroller: InertialScroller = InertialScroller(decelerationRate: displayLinkRate > 110 ? 0.96 : 0.9, displayLinkRate: displayLinkRate) {
        if ctrlDown {return}
        LiSendHighResScrollEvent(Int16(inertialScroller.vector.dy*7*scrollSensitivity))
        if TouchPadGestureHandler.enableHorizontalScroll {LiSendHighResHScrollEvent(Int16(-inertialScroller.vector.dx*7*scrollSensitivity))}
    }
    
    private enum TwoFingerIntent { case undecided, scroll, zoom }
    private static var twoFingerIntent: TwoFingerIntent = .undecided
    private static var intentPinchTravel: CGFloat = 0
    private static var intentPanTravel: CGFloat = 0
    private static let intentDecisionTravel: CGFloat = 10
    
    @objc public static func startInertialScroll(){
        resetTwoFingerIntent()
        inertialScroller.timer?.restart()
    }
    
    private static func resetTwoFingerIntent() {
        twoFingerIntent = .undecided
        intentPinchTravel = 0
        intentPanTravel = 0
    }
    
    @objc public static func handleGesture(in view: UIView, with event: UIEvent) {
        handleGesture(in: view, with: event, zoomHandler: nil)
    }
    
    // zoomHandler is only passed in touchpad mode. Without it, the Zoom pinch mode sends no pinch input.
    @objc public static func handleGesture(in view: UIView, with event: UIEvent, zoomHandler: TouchpadZoomHandler?) {
        inertialScroller.timer?.pause()
        
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
        
        let sendHorizontalScroll = abs(midPointDeltaX) > 1.2*abs(midPointDeltaY)
        
        let pinchZoomMode = enablePinch && pinchZoom
        if pinchZoomMode, let zoomHandler = zoomHandler {
            // Decide once per two-finger gesture whether it's a zoom or a scroll, so they don't fight each other.
            if twoFingerIntent == .undecided {
                let screenScale = zoomHandler.zoomScale // distances in the zoomed view shrink by the zoom scale
                intentPinchTravel += abs(currentDistance-previousDistance)*screenScale
                intentPanTravel += hypot(midPointDeltaX, midPointDeltaY)*screenScale
                if intentPinchTravel + intentPanTravel >= intentDecisionTravel {
                    twoFingerIntent = intentPinchTravel > intentPanTravel ? .zoom : .scroll
                }
            }
            if twoFingerIntent != .scroll {
                inertialScroller.vector = .zero
                if twoFingerIntent == .zoom, previousDistance > 0 {
                    zoomHandler.applyPinch(ratio: currentDistance/previousDistance)
                }
                return
            }
        }
        
        inertialScroller.vector = CGVector(dx: sendHorizontalScroll ? midPointDeltaX : 0, dy: midPointDeltaY)
        
        let originalPinchDelta = currentDistance-previousDistance;
        let pinchDelta = (enablePinch && !pinchZoom) ? originalPinchDelta*7*pinchSensitivity : 0;
        LiSendHighResScrollEvent(Int16(pinchDelta + midPointDeltaY*7*scrollSensitivity))
        if enableHorizontalScroll, sendHorizontalScroll {LiSendHighResHScrollEvent(Int16(-midPointDeltaX*7*scrollSensitivity))}
        
        if enablePinch, !pinchZoom, ctrlDownForPinch {
            let midPointDelta = hypot(midPointDeltaX, midPointDeltaY)
            if abs(originalPinchDelta) > midPointDelta*1.3, midPointDelta < 2 {
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_DOWN), 0)
                ctrlDown = true
            } else {
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_UP), 0)
                ctrlDown = false
            }
        }
    }
}
