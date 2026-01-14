//
//  PencilHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/17.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


import UIKit

@objc class PencilHandler: UIResponder {
    @objc static var sharedInstance: PencilHandler?
    
    /// 用来处理所有 touch 事件的宿主视图
    weak var streamView: UIView?
    // private var tickTimer: SafeTimer
    private var streamAspectRatio: Float
    private var tickInterval: TimeInterval
    private var manualTick: Bool
    private var pencilTickEnabled: Bool
    private var pressureCurveEnabled: Bool = false
    private var manualHoverFlag: Bool = false
    private var autoHoverFlag: Bool = false

    private var pressureLUT = PressureCurveLUT(curve: PressureCurve())

    @objc init(streamView: UIView, settings: TemporarySettings) {
        self.streamView = streamView
        streamAspectRatio = settings.width.floatValue/settings.height.floatValue
        tickInterval = TimeInterval(settings.pencilTickIntervalUs.floatValue/1000000)
        manualTick = settings.pencilTickMode.intValue == PencilTickMode.ManualTick.rawValue
        pencilTickEnabled = settings.pencilTickMode.intValue != PencilTickMode.PencilTickDisabled.rawValue
        super.init()
        setupPressureLUT()
        PencilHandler.sharedInstance = self
    }
    
    public func setupPressureLUT(){
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        let oscProfile = oscProfileMan.getSelectedProfile()
        pressureCurveEnabled = oscProfile.pressureCurveEnabled
        
        if #available(iOS 15.0, *) {
            IAPManager.checkPurchaseInfo(.PencilProPack) { info in
                self.pressureCurveEnabled = self.pressureCurveEnabled && info.valid
                self.pencilTickEnabled = self.pencilTickEnabled && info.valid
            }
        }
        
        let persistedCurvePoints = PressureCurve.importCurvePoints(oscProfile.pressureCurvePoints)
        let curve = PressureCurve()
        curve.polylinePoints = persistedCurvePoints
        curve.buildCurveSegments()
        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.pressureLUT = PressureCurveLUT(curve: curve)
        }
    }

    // MARK: - Touch Events

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: pencilTickEnabled ? coalesced : [touch])
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: pencilTickEnabled ? coalesced : [touch])
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        for touch in touches {
            let coalesced = event.coalescedTouches(for: touch) ?? []
            _ = self.sendStylusEvent(touchBatch: pencilTickEnabled ? coalesced : [touch])
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
        var rotationAngle = (azimuthAngle - .pi / 2) * (180.0 / .pi)  // 弧度转角度
        if rotationAngle < 0 {
            rotationAngle += 360
        }
        return UInt16(rotationAngle)
    }
    
    func getTilt(fromAltitudeAngle altitudeAngle: Float) -> UInt8 {
        let altitudeDegs = abs(Int16(altitudeAngle * (180.0 / .pi)))
        return UInt8(90 - min(90, Int(altitudeDegs)))
    }

    private func sendStylusEvent(touchBatch: [UITouch], with event: UIEvent? = nil) -> DispatchTime {
        guard let streamView = streamView, touchBatch.count>0 else { return .now() }
        
        var tickMoment: TimeInterval = 0
        var previousTimeStamp: TimeInterval = 0
        var delay:TimeInterval = 0
        var dispatchMoment: DispatchTime = .now()

        for touch in touchBatch {
            let point = touch.location(in: streamView)
            let azimuth = touch.azimuthAngle(in: streamView)
            let altitude = touch.altitudeAngle
            let location = self.adjustCoordinatesForVideoArea(point: point)
            let videoSize = self.getVideoAreaSize()
            let normalizedLocation = CGPoint(x: location.x/videoSize.width, y: location.y/videoSize.height)
            let force = Float(touch.force/touch.maximumPossibleForce)/sin(Float(altitude))
            let targetForce = pressureCurveEnabled ? self.pressureLUT.value(at: force) : force

            let eventType:UInt8
            
            switch touch.phase {
            case .began:
                eventType = UInt8(LI_TOUCH_EVENT_DOWN)
            case .moved:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER : LI_TOUCH_EVENT_MOVE)
            case .ended:
                eventType = UInt8(LI_TOUCH_EVENT_UP)
            case .cancelled:
                eventType = UInt8(LI_TOUCH_EVENT_UP)
            default:
                eventType = UInt8(LI_TOUCH_EVENT_MOVE)
            }

            delay = manualTick ? 0.0086 : 0.017
            delay = eventType == UInt8(LI_TOUCH_EVENT_UP) ? delay : 0
            
            if previousTimeStamp == 0 {
                previousTimeStamp = touch.timestamp
                tickMoment = 0
                dispatchMoment = .now()
            }
            else {
                tickMoment += (manualTick ? tickInterval : touch.timestamp - previousTimeStamp)
            }
            
            DispatchQueue.global().asyncAfter(deadline: dispatchMoment + tickMoment + delay) {
                LiSendPenEvent(eventType, UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), targetForce, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
            }
        }
        
        return dispatchMoment + tickMoment + delay
    }
    
    @objc public func switchPencilHoever(){
        manualHoverFlag = !manualHoverFlag
    }
    
    @objc public func enablePencilHover(){
        manualHoverFlag = true
    }
    
    @objc public func disablePencilHover(){
        manualHoverFlag = false
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
