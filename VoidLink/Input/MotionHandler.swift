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

@objc class MotionHandler: NSObject, OscInstanceReceiverDelegate, OnScreenWidgetStickMixedInputDelegate{
    func mixRightStickAndGyroInput(x: CGFloat, y: CGFloat) {
        rightStickTouchInputX = x
        rightStickTouchInputY = y
    }
    
    func mixLeftStickAndGyroInput(x: CGFloat, y: CGFloat) {
        leftStickTouchInputX = x
        leftStickTouchInputY = y
    }
    
    func gyroMixInputStarted() -> Bool {
        return gyroIsWorking
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
        let sharedInstance = MotionHandler.shared
        sharedInstance.oscProfile = sharedInstance.oscProfileMan.getSelectedProfile()
        sharedInstance.sensitvityYaw = sharedInstance.oscProfile.gyroSensitivityYaw
        sharedInstance.sensitvityPitch = sharedInstance.oscProfile.gyroSensitivityPitch
        sharedInstance.sensitvityRoll = sharedInstance.oscProfile.gyroSensitivityRoll
        sharedInstance.gyroToStickMinOffset =  sharedInstance.oscProfile.gyroToStickMinOffset
        return sharedInstance
    }

    private var oscProfileMan: OSCProfilesManager
    private var oscProfile: OSCProfile

    private var gyroControlStarted: Bool = false
    private var gyroIsWorking: Bool = false
    private var accelControlStarted: Bool = false
    private let motionManager = CMMotionManager()
    public var sensitvityYaw:CGFloat = 1.0
    public var sensitvityPitch:CGFloat = 1.0
    public var sensitvityRoll:CGFloat = 1.0
    private var windowScene: Any?
    
    private var onScreenControls: OnScreenControls = OnScreenControls.init()
    public let stickMaxOffset: CGFloat = 0x7FFE
    private var stickInputScale: CGFloat = 35
    
    private var yaw:Double = 0
    private var pitch:Double = 0
    private var roll:Double = 0
    
    private var isCalibrating: Bool = false
    private var sumX: Double = 0
    private var sumY: Double = 0
    private var sumZ: Double = 0
    @objc public var gyroBiasX: Double = 0
    @objc public var gyroBiasY: Double = 0
    @objc public var gyroBiasZ: Double = 0
    @objc public var gyroToStickMinOffset:Double = 0
    private var yawBias:Double = 0
    private var pitchBias:Double = 0
    private var rollBias:Double = 0

    private var rightStickTouchInputX:Double = 0
    private var rightStickTouchInputY:Double = 0
    
    private var leftStickTouchInputX:Double = 0
    private var leftStickTouchInputY:Double = 0

    var updateInterval: TimeInterval = 1.0 / 120.0 {
        didSet {
            motionManager.accelerometerUpdateInterval = updateInterval
            motionManager.gyroUpdateInterval = updateInterval
        }
    }
    
    @objc public override init() {
        self.oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        self.oscProfile = oscProfileMan.getSelectedProfile()
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
    private var needInterruption:Bool = false

    @objc public func stopGyroUpdate(interruption:Bool=false) {
        gyroControlStarted = false
        gyroIsWorking = false
        needInterruption = interruption
        if motionManager.isGyroActive{
            motionManager.stopGyroUpdates()
        }
        self.clearGyroInput(interruption: needInterruption)
    }
    
    @objc public func stopAccelUpdate() {
        accelControlStarted = false
        if motionManager.isAccelerometerActive {
            motionManager.stopAccelerometerUpdates()
        }
        // self.onScreenControls.clearLeftStickTouchPadFlag()
        // self.onScreenControls.clearRightStickTouchPadFlag()
    }

    // MARK: - 私有方法处理数据
    private func handleAccelerometerData(x: Double, y: Double, z: Double) {
        // 在这里处理加速度数据，比如计算方向、存储或驱动逻辑
    }

    private func handleGyroData(x: Double, y: Double, z: Double) {
        
        var yawSource:Double = 0
        var pitchSource:Double = 0
        var rollSource:Double = 0
        
        /*
        let correctedX:Double = x - gyroBiasX
        let correctedY:Double = y - gyroBiasY
        let correctedZ:Double = z - gyroBiasZ */
        
        if #available(iOS 13.0, *) {
            let orientation = (windowScene as! UIWindowScene).interfaceOrientation
            switch orientation {
            case .landscapeLeft:
                yawBias = gyroBiasX
                pitchBias = -gyroBiasY
                rollBias = -gyroBiasZ
                yawSource = x-yawBias
                pitchSource = -y-pitchBias
                rollSource = -z-rollBias
            case .landscapeRight:
                yawBias = -gyroBiasX
                pitchBias = gyroBiasY
                rollBias = -gyroBiasZ
                yawSource = -x-yawBias
                pitchSource = y-pitchBias
                rollSource = -z-rollBias
            case .portrait:
                yawBias = -gyroBiasY
                pitchBias = -gyroBiasX
                rollBias = -gyroBiasZ
                yawSource = -y-yawBias
                pitchSource = -x-pitchBias
                rollSource = -z-rollBias
            case .portraitUpsideDown:
                yawBias = gyroBiasY
                pitchBias = gyroBiasX
                rollBias = -gyroBiasZ
                yawSource = y-yawBias
                pitchSource = x-pitchBias
                rollSource = -z-rollBias
            default:
                yawBias = gyroBiasX
                pitchBias = -gyroBiasY
                rollBias = -gyroBiasZ
                yawSource = x-yawBias
                pitchSource = -y-pitchBias
                rollSource = -z-rollBias
            }
        } else {
            let orientation = UIApplication.shared.statusBarOrientation
            if orientation.isLandscape {
                yawBias = gyroBiasX
                pitchBias = -gyroBiasY
                rollBias = -gyroBiasZ
                yawSource = x-yawBias
                pitchSource = -y-pitchBias
                rollSource = -z-rollBias
            } else if orientation.isPortrait {
                yawBias = -gyroBiasY
                pitchBias = -gyroBiasX
                rollBias = -gyroBiasZ
                yawSource = -y-yawBias
                pitchSource = -x-pitchBias
                rollSource = -z-rollBias
            }
        }
        
        if !gyroControlStarted {
            self.clearGyroInput(interruption: needInterruption)
            print("Gyro: stopped")
            return
        }
        
        gyroIsWorking = true
        
        if oscProfile.mapGyroTo == MapGyroTo.mapGyroToMouse {
            yaw = yawSource*sensitvityYaw*30
            pitch = pitchSource*sensitvityPitch*30
            LiSendMouseMoveEvent(Int16(yaw),Int16(pitch))
        }
                
        if oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick {
            if oscProfile.yawPitchToRightStick {
                yaw = rightStickTouchInputX + gyroInputToStickInput(input:yawSource*sensitvityYaw*10)
                yaw = self.clampStickInput(input: yaw)
                yaw = (yaw >= 0 ? 1.0 : -1.0) * gyroToStickMinOffset + (self.stickMaxOffset - gyroToStickMinOffset) * (yaw/self.stickMaxOffset)
                
                pitch = rightStickTouchInputY - gyroInputToStickInput(input:pitchSource*sensitvityPitch*10)
                pitch = self.clampStickInput(input: pitch)
                pitch = (pitch >= 0 ? 1.0 : -1.0) * gyroToStickMinOffset + (self.stickMaxOffset - gyroToStickMinOffset) * (pitch/self.stickMaxOffset)

                self.onScreenControls.sendRightStickTouchPadEvent(yaw, pitch)
            }
            if oscProfile.rollToLeftStick {
                roll = leftStickTouchInputX + gyroInputToStickInput(input:rollSource*sensitvityRoll*10)
                roll = self.clampStickInput(input: roll)
                roll = (roll >= 0 ? 1.0 : -1.0) * gyroToStickMinOffset + (self.stickMaxOffset - gyroToStickMinOffset) * (roll/self.stickMaxOffset)
                
                self.onScreenControls.sendLeftStickTouchPadEvent(roll, leftStickTouchInputY)
            }
        }
}
    
    private func clearGyroInput(interruption:Bool){
        if oscProfile.yawPitchToRightStick{
            self.onScreenControls.sendRightStickTouchPadEvent(rightStickTouchInputX-yawBias, rightStickTouchInputY-pitchBias)
        }
        if oscProfile.rollToLeftStick{
            self.onScreenControls.sendLeftStickTouchPadEvent(leftStickTouchInputX-rollBias, leftStickTouchInputY)
        }
        if(interruption){
            self.onScreenControls.clearLeftStickTouchPadFlag()
            self.onScreenControls.clearRightStickTouchPadFlag()
        }
    }
    
    private func clampStickInput(input: CGFloat) -> CGFloat{
        return fmax(fmin(input, stickMaxOffset),-stickMaxOffset)
    }
    
    private func gyroInputToStickInput(input: CGFloat) -> CGFloat{
        return self.clampStickInput(input: stickMaxOffset * input / 8)
    }
    
    @objc public func calibrateGyroBias(duration: TimeInterval = 5.0, completion: @escaping () -> Void) {
        guard motionManager.isGyroAvailable else { return }

        isCalibrating = true
        var sumX = 0.0, sumY = 0.0, sumZ = 0.0
        var sampleCount = 0

        motionManager.startGyroUpdates(to: .main) { [weak self] gyroData, _ in
            guard let self = self, self.isCalibrating, let data = gyroData else { return }
            sumX += data.rotationRate.x
            sumY += data.rotationRate.y
            sumZ += data.rotationRate.z
            sampleCount += 1
        }

        // 5秒后计算平均值
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            self.motionManager.stopGyroUpdates()
            if sampleCount > 0 {
                gyroBiasX = sumX / Double(sampleCount)
                gyroBiasY = sumY / Double(sampleCount)
                gyroBiasZ = sumZ / Double(sampleCount)
            }
            self.isCalibrating = false
            completion()
        }
    }
}
