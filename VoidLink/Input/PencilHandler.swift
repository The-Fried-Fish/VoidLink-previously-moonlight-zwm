//
//  PencilHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/17.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


import UIKit

@objc class PencilHandler: UIResponder {

    /// 用来处理所有 touch 事件的宿主视图
    weak var streamView: UIView?
    // private var tickTimer: SafeTimer
    private var streamAspectRatio: Float
    private var tickInterval: TimeInterval
    private var manualTick: Bool
    private var manualhoverFlag: Bool = false
    private var autoHoverFlag: Bool = false

    @objc init(streamView: UIView, settings: TemporarySettings) {
        self.streamView = streamView
        streamAspectRatio = settings.width.floatValue/settings.height.floatValue
        tickInterval = TimeInterval(settings.pencilTickIntervalUs.floatValue/1000000)
        manualTick = settings.pencilTickMode.intValue == PencilTickMode.ManualTick.rawValue
        super.init()
    }

    // MARK: - Touch Events

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: coalesced)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: coalesced)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: coalesced)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchesEnded(touches, with: event)
    }

    // MARK: - Core Logic
    
    func getVideoAreaSize()-> CGSize {
        guard let streamView = streamView else { return CGSize(width: 0, height: 0) }
        if streamView.bounds.size.width > streamView.bounds.size.height * CGFloat(streamAspectRatio) {
            return CGSizeMake(streamView.bounds.size.height * CGFloat(streamAspectRatio), streamView.bounds.size.height);
        } else {
            return CGSizeMake(streamView.bounds.size.width, streamView.bounds.size.width / CGFloat(streamAspectRatio));
        }
    }
    
    func adjustCoordinatesForVideoArea(point: CGPoint) -> CGPoint {
        guard let streamView = streamView else { return CGPoint(x: 0, y: 0) }

        var x = point.x - streamView.bounds.origin.x
        var y = point.y - streamView.bounds.origin.y

        if x < streamView.bounds.width / 2 {
            x -= 1
        } else {
            x += 1
        }

        if y < streamView.bounds.height / 2 {
            y -= 1
        } else {
            y += 1
        }

        let videoSize = getVideoAreaSize() // 返回 CGSize
        let videoOrigin = CGPoint(
            x: streamView.bounds.width / 2 - videoSize.width / 2,
            y: streamView.bounds.height / 2 - videoSize.height / 2
        )

        let confinedX = min(max(x, videoOrigin.x), videoOrigin.x + videoSize.width) - videoOrigin.x
        let confinedY = min(max(y, videoOrigin.y), videoOrigin.y + videoSize.height) - videoOrigin.y

        return CGPoint(x: confinedX, y: confinedY)
    }

    
    func getRotation(fromAzimuthAngle azimuthAngle: Float) -> UInt16 {
        // iOS 的 azimuthAngle 为 0 表示指向西
        // VoidLink 期望 0 表示指向北
        // 所以顺时针旋转 90 度来转换
        var rotationAngle = (azimuthAngle - .pi / 2) * (180.0 / .pi)  // 弧度转角度
        if rotationAngle < 0 {
            rotationAngle += 360
        }
        return UInt16(rotationAngle)
    }
    
    func getTilt(fromAltitudeAngle altitudeAngle: Float) -> UInt8 {
        // iOS 的 altitudeAngle 为 0 表示笔与触摸面平行
        // VoidLink 期望 tilt 为 0 表示笔垂直触摸面
        // 所以 tilt = 90 - altitude
        let altitudeDegs = abs(Int16(altitudeAngle * (180.0 / .pi)))
        return UInt8(90 - min(90, Int(altitudeDegs)))
    }

    private func sendStylusEvent(touchBatch: [UITouch], with event: UIEvent? = nil) -> DispatchTime {
        guard let streamView = streamView, touchBatch.count>0 else { return .now() }
        
        var tickMoment: TimeInterval = 0
        var previousTimeStamp: TimeInterval = 0
        let dispatchMoment: DispatchTime = .now()
        var delay:TimeInterval = 0

        for touch in touchBatch {
            if previousTimeStamp == 0 {previousTimeStamp = touch.timestamp}
            tickMoment += (manualTick ? tickInterval : touch.timestamp - previousTimeStamp)
            
            let point = touch.location(in: streamView)
            let azimuth = touch.azimuthAngle(in: streamView)
            let altitude = touch.altitudeAngle
            let location = self.adjustCoordinatesForVideoArea(point: point)
            let videoSize = self.getVideoAreaSize()
            let normalizedLocation = CGPoint(x: location.x/videoSize.width, y: location.y/videoSize.height)
            let force = Float(touch.force/touch.maximumPossibleForce)/sin(Float(altitude))
            
            let eventType:UInt8
            
            switch touch.phase {
            case .began:
                eventType = UInt8(LI_TOUCH_EVENT_DOWN)
            case .moved:
                eventType = UInt8(manualhoverFlag ? LI_TOUCH_EVENT_HOVER : LI_TOUCH_EVENT_MOVE)
            case .ended:
                eventType = UInt8(LI_TOUCH_EVENT_UP)
            case .cancelled:
                eventType = UInt8(LI_TOUCH_EVENT_UP)
            default:
                eventType = UInt8(LI_TOUCH_EVENT_MOVE)
            }

            delay = manualTick ? 0.0086 : 0.017
            delay = eventType == UInt8(LI_TOUCH_EVENT_UP) ? delay : 0
            
            DispatchQueue.global().asyncAfter(deadline: dispatchMoment + tickMoment + delay) {
                LiSendPenEvent(eventType, UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), force, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
            }
        }
        
        return dispatchMoment + tickMoment + delay
    }
    
    @objc public func switchPencilHoever(){
        manualhoverFlag = !manualhoverFlag
    }
    
    @objc public func enablePencilHover(){
        manualhoverFlag = true
    }
    
    @objc public func disablePencilHover(){
        manualhoverFlag = false
    }

    private func attachHoverLeave(normalizedLocation:CGPoint){
        DispatchQueue.global().asyncAfter(deadline: .now()+0.0086) {
            LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, 0, 0)
            DispatchQueue.global().asyncAfter(deadline: .now()+0.0086) {
                // LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER_LEAVE), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, 0, 0)
            }
        }
    }
    
    private func preTouchHoverActionAt(normalizedLocation:CGPoint){
        DispatchQueue.global().asyncAfter(deadline: .now()+0.0086) {
            LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, 0, 0)
            DispatchQueue.global().asyncAfter(deadline: .now()+0.0086) {
                LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER_LEAVE), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, 0, 0)
            }
        }
    }

}
