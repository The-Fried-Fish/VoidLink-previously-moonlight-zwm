//
//  MicHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/28.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

import Foundation
import CoreMotion

@objc public protocol OnScreenWidgetStickMixedInputDelegate: AnyObject {
    func mixRightStickAndGyroInput(x: CGFloat, y: CGFloat)
    func mixLeftStickAndGyroInput(x: CGFloat, y: CGFloat)
    func gyroMixInputStarted() -> Bool
}

@objc class MotionHandler: NSObject, OscInstanceProviderDelegate, OnScreenWidgetStickMixedInputDelegate{
    func mixRightStickAndGyroInput(x: CGFloat, y: CGFloat) {
        rightStickTouchInputX = x
        rightStickTouchInputY = y
    }
    
    func mixLeftStickAndGyroInput(x: CGFloat, y: CGFloat) {
        leftStickTouchInputX = x
        leftStickTouchInputY = y
    }
    
    func gyroMixInputStarted() -> Bool {
        return gyroControlStarted
    }
    
    func getOnScreenControlsInstance(_ sender: Any!) {
        if let controls = sender as? OnScreenControls {
            self.onScreenControls = controls
            print("ClassA received OnScreenControls instance: \(controls)")
        } else {
            print("ClassA received an unknown sender")
        }
    }
    
    static let shared = MotionHandler()
    
    @objc class func sharedInstance() -> MotionHandler {
        return MotionHandler.shared
    }
 
    private var gyroControlStarted: Bool = false
    private var accelControlStarted: Bool = false
    private let motionManager = CMMotionManager()
    public var sensitvityYaw:CGFloat = 1.0
    public var sensitvityPitch:CGFloat = 1.0
    public var sensitvityRoll:CGFloat = 1.0
    private var windowScene: Any?
    
    private var onScreenControls: OnScreenControls = OnScreenControls.init()
    public let stickMaxOffset: CGFloat = 0x7FFE
    private var stickInputScale: CGFloat = 35
    
    var yaw:Double = 0
    var pitch:Double = 0
    var roll:Double = 0
    
    var rightStickTouchInputX:Double = 0
    var rightStickTouchInputY:Double = 0
    
    var leftStickTouchInputX:Double = 0
    var leftStickTouchInputY:Double = 0

    var updateInterval: TimeInterval = 1.0 / 120.0 {
        didSet {
            motionManager.accelerometerUpdateInterval = updateInterval
            motionManager.gyroUpdateInterval = updateInterval
        }
    }
    
    @objc public override init() {
        super.init()
        if #available(iOS 13.0, *) {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            self.windowScene = scene
        } else {
            // Fallback on earlier versions
        }
        motionManager.accelerometerUpdateInterval = updateInterval
        motionManager.gyroUpdateInterval = updateInterval
    }
    
    /// 启动传感器数据更新
    @objc public func startGyroUpdate() {
        gyroControlStarted = true
        if motionManager.isGyroAvailable {
            motionManager.startGyroUpdates(to: .main) { [weak self] gyroData, _ in
                guard let self = self, let data = gyroData else { return }
                self.handleGyroData(x: data.rotationRate.x,
                                    y: data.rotationRate.y,
                                    z: data.rotationRate.z)
            }
        }
    }

    @objc public func startAccelUpdate() {
        accelControlStarted = true
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] accelData, _ in
                guard let self = self, let data = accelData else { return }
                self.handleAccelerometerData(x: data.acceleration.x,
                                            y: data.acceleration.y,
                                            z: data.acceleration.z)
            }
        }
    }
    
    /// 停止更新
    @objc public func stopGyroUpdate() {
        gyroControlStarted = false
        if motionManager.isGyroActive{
            motionManager.stopGyroUpdates()
        }
        self.onScreenControls.clearLeftStickTouchPadFlag()
        self.onScreenControls.clearRightStickTouchPadFlag()
    }
    
    @objc public func stopAccelUpdate() {
        accelControlStarted = false
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        self.onScreenControls.clearLeftStickTouchPadFlag()
        self.onScreenControls.clearRightStickTouchPadFlag()
    }

    // MARK: - 私有方法处理数据
    private func handleAccelerometerData(x: Double, y: Double, z: Double) {
        // 在这里处理加速度数据，比如计算方向、存储或驱动逻辑
        //print("加速度计: x=\(x), y=\(y), z=\(z)")
    }

    private func handleGyroData(x: Double, y: Double, z: Double) {
        
        var yawSource:Double = 0
        var pitchSource:Double = 0
        var rollSource:Double = 0
        
        if #available(iOS 13.0, *) {
            let orientation = (windowScene as! UIWindowScene).interfaceOrientation
            print("界面方向变化: \(orientation)")
            switch orientation {
            case .landscapeLeft:
                yawSource = x
                pitchSource = -y
                rollSource = -z
            case .landscapeRight:
                yawSource = -x
                pitchSource = y
                rollSource = -z
            case .portrait:
                yawSource = -y
                pitchSource = -x
                rollSource = -z
            case .portraitUpsideDown:
                yawSource = y
                pitchSource = x
                rollSource = -z
            default:
                yawSource = x
                pitchSource = -y
                rollSource = -z
            }
        } else {
            yawSource = x
            pitchSource = -y
            rollSource = z
        }
        
        if !gyroControlStarted {
            self.onScreenControls.clearLeftStickTouchPadFlag()
            self.onScreenControls.clearRightStickTouchPadFlag()
            print("Gyro: stopped")
            return
        }
        
        if true {
            yaw = rightStickTouchInputX + gyroInputToStickInput(input:yawSource*sensitvityYaw*10)
            yaw = self.clampStickInput(input: yaw)
            pitch = rightStickTouchInputY - gyroInputToStickInput(input:pitchSource*sensitvityPitch*10)
            pitch = self.clampStickInput(input: pitch)
            self.onScreenControls.sendRightStickTouchPadEvent(yaw, pitch)
        }
             
        if true {
            roll = leftStickTouchInputX + gyroInputToStickInput(input:rollSource*sensitvityRoll*10)
            roll = self.clampStickInput(input: roll)
            self.onScreenControls.sendLeftStickTouchPadEvent(roll, leftStickTouchInputY)
        }
        
        if false {
            yaw = yawSource*sensitvityYaw*30
            pitch = pitchSource*sensitvityPitch*30
            LiSendMouseMoveEvent(Int16(yaw),Int16(pitch))
        }
        
        if false {
            roll = rollSource*sensitvityPitch*100
            LiSendMouseMoveEvent(Int16(roll),0)
        }
    }
    
    private func clampStickInput(input: CGFloat) -> CGFloat{
        return fmax(fmin(input, stickMaxOffset),-stickMaxOffset)
    }
    
    private func gyroInputToStickInput(input: CGFloat) -> CGFloat{
        return self.clampStickInput(input: stickMaxOffset * input / 8)
    }
}
