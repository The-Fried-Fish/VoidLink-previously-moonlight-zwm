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
    // Where the two fingers were (window coordinates, unaffected by zoom) when the gesture started.
    private static var intentTouchIDs: Set<ObjectIdentifier> = []
    private static var intentStartLocations: [ObjectIdentifier: CGPoint] = [:]
    /// Finger travel (points) before a two-finger gesture is classified as zoom or scroll.
    private static let intentDecisionTravel: CGFloat = 12
    
    @objc public static func startInertialScroll(){
        resetTwoFingerIntent()
        inertialScroller.timer?.restart()
    }
    
    private static func resetTwoFingerIntent() {
        twoFingerIntent = .undecided
        intentTouchIDs = []
        intentStartLocations = [:]
    }
    
    /// Classifies a two-finger gesture from each finger's net movement since it started, so frame-to-frame jitter
    /// doesn't count. Scrolling moves both fingers the same way; pinching changes the distance between them much
    /// more than it moves their midpoint. Returns nil until the fingers have moved far enough to tell.
    private static func classifyTwoFingerIntent(_ touch1: UITouch, _ touch2: UITouch) -> TwoFingerIntent? {
        let id1 = ObjectIdentifier(touch1), id2 = ObjectIdentifier(touch2)
        let p1 = touch1.location(in: nil), p2 = touch2.location(in: nil)
        if intentTouchIDs != [id1, id2] {
            // new pair of fingers (or the second finger just landed): start measuring from here
            intentTouchIDs = [id1, id2]
            intentStartLocations = [id1: p1, id2: p2]
            return nil
        }
        guard let s1 = intentStartLocations[id1], let s2 = intentStartLocations[id2] else { return nil }
        
        let v1 = CGVector(dx: p1.x - s1.x, dy: p1.y - s1.y)
        let v2 = CGVector(dx: p2.x - s2.x, dy: p2.y - s2.y)
        let len1 = hypot(v1.dx, v1.dy), len2 = hypot(v2.dx, v2.dy)
        guard max(len1, len2) >= intentDecisionTravel else { return nil }
        
        // Both fingers moving in roughly the same direction: always a scroll.
        if len1 > 4, len2 > 4 {
            let cosine = (v1.dx*v2.dx + v1.dy*v2.dy) / (len1*len2)
            if cosine > 0.3 { return .scroll }
        }
        
        let distanceChange = abs(hypot(p1.x - p2.x, p1.y - p2.y) - hypot(s1.x - s2.x, s1.y - s2.y))
        let midpointTravel = hypot((v1.dx + v2.dx)/2, (v1.dy + v2.dy)/2)
        // A pinch with one finger still gives distanceChange ≈ 2 × midpointTravel; a two-finger pinch much more.
        return distanceChange >= midpointTravel*1.5 ? .zoom : .scroll
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
            if twoFingerIntent == .undecided, let intent = classifyTwoFingerIntent(touch1, touch2) {
                twoFingerIntent = intent
                if intent == .scroll {
                    // the catch-up scroll already includes this frame's movement
                    inertialScroller.vector = CGVector(dx: sendHorizontalScroll ? midPointDeltaX : 0, dy: midPointDeltaY)
                    sendScrollForTravelWhileUndecided(touch1, touch2, zoomScale: zoomHandler.zoomScale)
                    return
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
        
        sendScroll(pinchDelta: currentDistance-previousDistance, midPointDelta: midPointVector)
    }
    
    /// Sends the scroll that was held back while the gesture was being classified, so scrolling starts without a dead zone.
    private static func sendScrollForTravelWhileUndecided(_ touch1: UITouch, _ touch2: UITouch, zoomScale: CGFloat) {
        guard let s1 = intentStartLocations[ObjectIdentifier(touch1)], let s2 = intentStartLocations[ObjectIdentifier(touch2)] else { return }
        let p1 = touch1.location(in: nil), p2 = touch2.location(in: nil)
        // window points -> stream view points, the units used for regular scroll deltas
        let scale = max(zoomScale, 0.0001)
        let travel = CGVector(dx: ((p1.x - s1.x) + (p2.x - s2.x))/2/scale, dy: ((p1.y - s1.y) + (p2.y - s2.y))/2/scale)
        sendScroll(pinchDelta: 0, midPointDelta: travel)
    }
    
    private static func sendScroll(pinchDelta originalPinchDelta: CGFloat, midPointDelta: CGVector) {
        let midPointDeltaX = midPointDelta.dx
        let midPointDeltaY = midPointDelta.dy
        let sendHorizontalScroll = abs(midPointDeltaX) > 1.2*abs(midPointDeltaY)
        
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
