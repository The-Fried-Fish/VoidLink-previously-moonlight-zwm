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
    func mixOnScreenRightStickAndGyroInput(x: CGFloat, y: CGFloat)
    func mixOnScreenLeftStickAndGyroInput(x: CGFloat, y: CGFloat)
    func gyroMixInputStarted() -> Bool
}

@objc class MotionHandler: NSObject, OnScreenWidgetStickMixedInputDelegate{
    public func mixOnScreenRightStickAndGyroInput(x: CGFloat, y: CGFloat) {
        rightStickTouchInputX = x
        rightStickTouchInputY = y
    }
    
    public func mixOnScreenLeftStickAndGyroInput(x: CGFloat, y: CGFloat) {
        // rollIntegral = 0
        leftStickTouchInputX = x
        leftStickTouchInputY = y
    }
    
    @objc public func mixPhysicalRightStickAndGyroInput(x: CGFloat, y: CGFloat) {
        rightStickPhysicalInputX = synthesizePhysicalStick ? x : 0
        rightStickPhysicalInputY = synthesizePhysicalStick ? y : 0
    }
    
    @objc public func mixPhysicalLeftStickAndGyroInput(x: CGFloat, y: CGFloat) {
        // rollIntegral = 0
        leftStickPhysicalInputX = synthesizePhysicalStick ? x : 0
        leftStickPhysicalInputY = synthesizePhysicalStick ? y : 0
    }

    public func gyroMixInputStarted() -> Bool {
        return motionIsWorking
    }
    
    private static let sharedInstance = MotionHandler()
    
    @objc class func shared(profile: OSCProfile?) -> MotionHandler {
        let sharedInstance = MotionHandler.sharedInstance
        guard let profile = profile else { return sharedInstance }
        sharedInstance.useBuiltinGyro = profile.useBuiltinGyro
        sharedInstance.swapYawAndRoll = profile.swapYawAndRoll
        sharedInstance.mapGyroTo = profile.mapGyroTo
        sharedInstance.synthesizePhysicalStick = profile.synthesizePhysicalStick
        sharedInstance.rollToLeftStick = profile.rollToLeftStick
        sharedInstance.yawPitchToRightStick = profile.yawPitchToRightStick
        sharedInstance.sensitvityYaw = profile.gyroSensitivityYaw
        sharedInstance.sensitvityPitch = profile.gyroSensitivityPitch
        sharedInstance.sensitvityRoll = profile.gyroSensitivityRoll
        sharedInstance.gyroToStickMinOffset =  profile.gyroToStickMinOffset
        sharedInstance.onScreenControls = OnScreenControls.shared()
        return sharedInstance
    }

    @objc public var motionControlStarted: Bool = false
    @objc var useBuiltinGyro: Bool = true
    @objc var swapYawAndRoll: Bool = false
    private var motionIsWorking: Bool = false
    private var accelControlStarted: Bool = false
    private let motionManager = CMMotionManager()
    private weak var activeGCController:GCController?
    private var synthesizePhysicalStick:Bool = false
    private var mapGyroTo:MapGyroTo = .mapGyroToControllerStick
    private var rollToLeftStick:Bool = false
    private var gravityYAngleRef:Double?
    private var previousGravityYAngle:Double?
    private var gravityYUnwrappedAngle:Double = 0
    private var yawPitchToRightStick:Bool = false
    public var sensitvityYaw:CGFloat = 1.0
    public var sensitvityPitch:CGFloat = 1.0
    public var sensitvityRoll:CGFloat = 1.0
    @objc public var widgetYawFactor:CGFloat = 1.0
    @objc public var widgetPitchFactor:CGFloat = 1.0
    @objc public var widgetRollFactor:CGFloat = 1.0
    @objc public var previousWidgetYawFactor:CGFloat = 1.0
    @objc public var previousWidgetPitchFactor:CGFloat = 1.0
    @objc public var previousWidgetRollFactor:CGFloat = 1.0
    public var motionStarter:Any?
    private var windowScene: Any?
    
    @objc public var onScreenControls: OnScreenControls?
    public let stickMaxOffset: CGFloat = 0x7FFE
    private var stickInputScale: CGFloat = 35
    
    private var yaw:Double = 0
    private var pitch:Double = 0
    private var roll:Double = 0
    private var leftStickMotion:Double = 0

    private var isCalibrating: Bool = false
    private var sumX: Double = 0
    private var sumY: Double = 0
    private var sumZ: Double = 0
    @objc public var gyroBiasX: Double = 0
    @objc public var gyroBiasY: Double = 0
    @objc public var gyroBiasZ: Double = 0
    @objc public var controllerGyroBiasX: Double = 0
    @objc public var controllerGyroBiasY: Double = 0
    @objc public var controllerGyroBiasZ: Double = 0
    @objc public var gyroToStickMinOffset:Double = 0
    private var yawBias:Double = 0
    private var pitchBias:Double = 0
    private var rollBias:Double = 0

    private var rightStickTouchInputX:Double = 0
    private var rightStickTouchInputY:Double = 0
    
    private var leftStickTouchInputX:Double = 0
    private var leftStickTouchInputY:Double = 0
    
    private var rightStickPhysicalInputX:Double = 0
    private var rightStickPhysicalInputY:Double = 0
    public var gyroToStickOffset:CGVector = CGVector(dx: 0, dy: 0)
    
    private var leftStickPhysicalInputX:Double = 0
    private var leftStickPhysicalInputY:Double = 0

    var updateInterval: TimeInterval = 1.0 / 120.0 {
        didSet {
            motionManager.accelerometerUpdateInterval = updateInterval
            motionManager.gyroUpdateInterval = updateInterval
        }
    }
    
    @objc public override init() {
        // _ = OSCProfilesManager.sharedManager(CGRectZero)
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
    
    public func startMotionControlByOnScreenButton(_ sender: OnScreenWidgetView, yawFactor:CGFloat, pitchFactor:CGFloat, rollFactor:CGFloat){
        self.previousWidgetYawFactor = self.widgetYawFactor
        self.previousWidgetPitchFactor = self.widgetPitchFactor
        self.previousWidgetRollFactor = self.widgetRollFactor
        self.widgetYawFactor = yawFactor
        self.widgetPitchFactor = pitchFactor
        self.widgetRollFactor = rollFactor
        print("self.widgetRollFactor \(self.widgetRollFactor)")
        if self.motionStarter == nil {
            self.motionStarter = sender
            if sender.motionControlButtonString != "GYROPAUSE" {self.startMotionUpdate()}
        }
        else if sender.motionControlButtonString == "GYROPAUSE" {
            self.startMotionUpdate()
        }
    }
    
    @objc public func startMotionControlByControllerButton(){
        self.previousWidgetYawFactor = self.widgetYawFactor
        self.previousWidgetPitchFactor = self.widgetPitchFactor
        self.previousWidgetRollFactor = self.widgetRollFactor
        self.widgetYawFactor = 1
        self.widgetPitchFactor = 1
        self.widgetRollFactor = 1
        self.startMotionUpdate()
    }
    
    @objc public func startMotionUpdate() {
        if !motionControlStarted {
            motionControlStarted = true
            resetGravityYOffsetTracking()
            
            // print("startGyroUpdate useBuiltinGyro \(useBuiltinGyro) \(CACurrentMediaTime())")
            
            if useBuiltinGyro {
                if motionManager.isGyroAvailable {
                    motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motionData, _ in
                        guard let self = self, let data = motionData else { return }
                        self.handleMotionData(deviceMotion: data)
                    }
                }
            }
            else {
                if #available(iOS 14.0, *) {
                    if activeGCController == nil {
                        if let controllers = ControllerUtil.activeGCControllers as? Set<GCController> {
                            for controller in controllers {
                                if controller.playerIndex == .index1 {
                                    activeGCController = controller
                                    break
                                }
                            }
                        }
                    }
                if let motion = activeGCController?.motion {
                    if motion.sensorsRequireManualActivation {
                        motion.sensorsActive = true
                    }
                    if motion.sensorsActive {
                        motion.valueChangedHandler = { [weak self] motion in
                            self?.handleMotionData(gcMotion: motion)
                            }
                        }
                    }
                }
            }
        }
        else {return}
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
    private var interruptNoneGyroInput:Bool = false

    @objc public func stopMotionUpdate(interruptNoneGyroInput:Bool=false) {
        motionControlStarted = false
        motionIsWorking = false
        resetGravityYOffsetTracking()
        if motionManager.isDeviceMotionActive{
            motionManager.stopDeviceMotionUpdates()
        }
        if #available(iOS 14.0, *) {
            activeGCController?.motion?.sensorsActive = false
        }
        self.clearGyroInput(interruptNonGyroInput:interruptNoneGyroInput)
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

    private func handleMotionData(deviceMotion: CMDeviceMotion? = nil, gcMotion:GCMotion? = nil) {
        var x:Double = 0
        var y:Double = 0
        var z:Double = 0
        // var attitudeRoll:Double = 0
        var gravityYOffset:Double = 0

        if let deviceMotion = deviceMotion {
            x = deviceMotion.rotationRate.x
            y = deviceMotion.rotationRate.y
            z = deviceMotion.rotationRate.z
            // attitudeRoll = deviceMotion.attitude.yaw
            gravityYOffset = updateGravityYOffset(
                gravityX: deviceMotion.gravity.x,
                gravityY: deviceMotion.gravity.y,
            )
        }
        
        if let gcMotion = gcMotion {
            x = gcMotion.rotationRate.x
            y = gcMotion.rotationRate.y
            z = gcMotion.rotationRate.z
            // attitudeRoll = gcMotion.attitude.z
        }
        
            
        var yawSource:Double = 0
        var pitchSource:Double = 0
        var rollSource:Double = 0
        
        /*
        let correctedX:Double = x - gyroBiasX
        let correctedY:Double = y - gyroBiasY
        let correctedZ:Double = z - gyroBiasZ */
        
        if useBuiltinGyro {
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
        }
        else {
            yawBias = swapYawAndRoll ? controllerGyroBiasY : -controllerGyroBiasZ
            pitchBias = -controllerGyroBiasX
            rollBias = swapYawAndRoll ? -controllerGyroBiasZ : controllerGyroBiasY
            yawSource = (swapYawAndRoll ? y : -z) - yawBias
            pitchSource = -x-pitchBias
            rollSource = (swapYawAndRoll ? -z : y) - rollBias
        }
        
        if !motionControlStarted {
            self.clearGyroInput(interruptNonGyroInput: interruptNoneGyroInput)
            // print("Gyro: stopped")
            return
        }
        
        motionIsWorking = true
        
        if mapGyroTo == MapGyroTo.mapGyroToMouse {
            yaw = yawSource*sensitvityYaw*widgetYawFactor*30
            pitch = pitchSource*sensitvityPitch*widgetPitchFactor*30
            LiSendMouseMoveEvent(Int16(yaw),Int16(pitch))
        }
        
        //guard let onScreenControls = onScreenControls else { return }
        
        if mapGyroTo == MapGyroTo.mapGyroToControllerStick {
            if yawPitchToRightStick {
                gyroToStickOffset.dx = gyroInputToStickInput(input:yawSource*sensitvityYaw*widgetYawFactor*10)
                yaw = rightStickTouchInputX + rightStickPhysicalInputX + gyroToStickOffset.dx
                yaw = self.clampStickInput(input: yaw)
                
                gyroToStickOffset.dy = -gyroInputToStickInput(input:pitchSource*sensitvityPitch*widgetPitchFactor*10)
                pitch = rightStickTouchInputY + rightStickPhysicalInputY + gyroToStickOffset.dy
                pitch = self.clampStickInput(input: pitch)
                
                let offsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: yaw, dy: pitch), minOffset: gyroToStickMinOffset)
                
                onScreenControls?.sendRightStickTouchPadEvent(offsetVector.dx, offsetVector.dy)
            }
            if rollToLeftStick {
                roll = gyroInputToStickInput(input:rollSource*sensitvityRoll*widgetRollFactor*0.2)
                                
                leftStickMotion = useBuiltinGyro ? -stickMaxOffset*(gravityYOffset/Double.pi)*3*sensitvityRoll*widgetRollFactor :                 leftStickMotion + roll

                let mixedLeftStickOffsetX = self.clampStickInput(input: leftStickMotion+leftStickTouchInputX+leftStickPhysicalInputX)
                let mixedLeftStickOffsetY = self.clampStickInput(input: leftStickTouchInputY+leftStickPhysicalInputY)

                let offsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: mixedLeftStickOffsetX, dy: mixedLeftStickOffsetY), minOffset: gyroToStickMinOffset)
                
                onScreenControls?.sendLeftStickTouchPadEvent(offsetVector.dx, offsetVector.dy)
            }
        }
}
    
    private func clearGyroInput(interruptNonGyroInput:Bool){
        // guard let onScreenControls = onScreenControls else { return }

        if yawPitchToRightStick{
            onScreenControls?.sendRightStickTouchPadEvent(rightStickPhysicalInputX+rightStickTouchInputX-yawBias, rightStickPhysicalInputY+rightStickTouchInputY-pitchBias)
        }
        if rollToLeftStick{
            leftStickMotion = 0
            onScreenControls?.sendLeftStickTouchPadEvent(leftStickPhysicalInputX+leftStickTouchInputX-rollBias,leftStickPhysicalInputY+leftStickTouchInputY)
        }
        if(interruptNonGyroInput){
            onScreenControls?.clearLeftStickTouchPadFlag()
            onScreenControls?.clearRightStickTouchPadFlag()
        }
    }
    
    private func resetGravityYOffsetTracking() {
        gravityYAngleRef = nil
        previousGravityYAngle = nil
        gravityYUnwrappedAngle = 0
    }
    
    private func updateGravityYOffset(gravityX: Double, gravityY: Double) -> Double {
        let gravityYAngle = atan2(gravityX, -gravityY)
        
        guard let previousGravityYAngle = previousGravityYAngle else {
            gravityYAngleRef = gravityYAngle
            previousGravityYAngle = gravityYAngle
            gravityYUnwrappedAngle = gravityYAngle
            return 0
        }
        
        var delta = gravityYAngle - previousGravityYAngle
        if delta > Double.pi {
            delta -= 2 * Double.pi
        } else if delta < -Double.pi {
            delta += 2 * Double.pi
        }
        
        gravityYUnwrappedAngle += delta
        self.previousGravityYAngle = gravityYAngle
        return -(gravityYUnwrappedAngle - (gravityYAngleRef ?? gravityYUnwrappedAngle))
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

        if useBuiltinGyro {
            motionManager.startGyroUpdates(to: .main) { [weak self] gyroData, _ in
                guard let self = self, self.isCalibrating, let data = gyroData else { return }
                sumX += data.rotationRate.x
                sumY += data.rotationRate.y
                sumZ += data.rotationRate.z
                sampleCount += 1
            }
        }
        else if #available(iOS 14.0, *) {
            if let motion = activeGCController?.motion {
                if motion.sensorsRequireManualActivation {
                    motion.sensorsActive = true
                }
                if motion.sensorsActive {
                    motion.valueChangedHandler = { [weak self] motion in
                        guard let self = self, self.isCalibrating else { return }
                        sumX += motion.rotationRate.x
                        sumY += motion.rotationRate.y
                        sumZ += motion.rotationRate.z
                        sampleCount += 1
                    }
                }
            }
        }

        // 5秒后计算平均值
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            self.motionManager.stopDeviceMotionUpdates()
            if sampleCount > 0 {
                if useBuiltinGyro {
                    gyroBiasX = sumX / Double(sampleCount)
                    gyroBiasY = sumY / Double(sampleCount)
                    gyroBiasZ = sumZ / Double(sampleCount)
                }
                else {
                    controllerGyroBiasX = sumX / Double(sampleCount)
                    controllerGyroBiasY = sumY / Double(sampleCount)
                    controllerGyroBiasZ = sumZ / Double(sampleCount)
                }
            }
            self.isCalibrating = false
            completion()
        }
    }
}
