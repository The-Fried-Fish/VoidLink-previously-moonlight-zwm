//
//  OnScreenKey.swift
//  Moonlight-ZWM
//
//  Created by ZWM on 2024/8/4.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

import UIKit

@objc class OnScreenWidgetView: UIView, InstanceProviderDelegate {
    // receiving the OnScreenControls instance from delegate
    @objc func getOnScreenControlsInstance(_ sender: Any) {
        if let controls = sender as? OnScreenControls {
            self.onScreenControls = controls
            print("ClassA received OnScreenControls instance: \(controls)")
        } else {
            print("ClassA received an unknown sender")
        }
    }
    
    @objc static public var editMode: Bool = false
    @objc public var keyLabel: String
    @objc public var keyString: String
    @objc public var timestamp: TimeInterval
    @objc public var pressed: Bool
    @objc public var widthFactor: CGFloat = 1.0
    @objc public var heightFactor: CGFloat = 1.0
    @objc public var borderWidth: CGFloat = 0.0
    @objc public var backgroundAlpha: CGFloat = 0.5
    @objc public var latestTouchLocation: CGPoint
    @objc public var selfViewOnTheRight: Bool = false
    
    private let appWindow: UIView
    
    
    private var touchLockedForMoveEvent: UITouch
    private var touchBegan: Bool = false
    private let stickBallMaxOffset = 18.0
    
    // for LSVPAD, RSVPAD
    @objc public var deltaX: CGFloat
    @objc public var deltaY: CGFloat
    
    // for LSPAD, RSPAD
    @objc public var offSetX: CGFloat
    @objc public var offSetY: CGFloat

    // this is for all stick pads and mouse Pad
    @objc public var sensitivityFactorX: CGFloat = 1.0
    @objc public var sensitivityFactorY: CGFloat = 1.0
    
    // for LSVPAD, RSVPAD, LSPAD, RSPAD
    private let crossMarkColor: CGColor = UIColor(white: 1, alpha: 0.70).cgColor
    private let stickBallColor: CGColor = UIColor(white: 1, alpha: 0.75).cgColor
    private var stickInputScale: CGFloat = 35
    private var l3r3Indicator = CAShapeLayer()
    @objc public var crossMarkLayer = CAShapeLayer()
    @objc public var stickBallLayer = CAShapeLayer()

    // check quick double tap:
    private var quickDoubleTapDetected: Bool
    private var touchTapTimeInterval: TimeInterval
    private var touchTapTimeStamp: TimeInterval
    private let QUICK_TAP_TIME_INTERVAL = 0.2
    @objc public var stickIndicatorOffset: CGFloat = 120
    
    // for all LRUD pads
    private var upIndicator = CAShapeLayer()
    private var downIndicator = CAShapeLayer()
    private var leftIndicator = CAShapeLayer()
    private var rightIndicator = CAShapeLayer()
    
    // for DPAD LRUD pad
    private var lrudIndicatorBall = CAShapeLayer()
    
    // OnScreenControls instance
    private var onScreenControls: OnScreenControls
    
    // key / button label
    private let label: UILabel
    
    // first touch location within the button or pad view (self)
    @objc public var touchBeganLocation: CGPoint = .zero
    
    // for mousePad
    private var mousePointerMoved: Bool
    private var twoTouchesDetected: Bool
    
    private var trackballVelocity: CGPoint = .zero
    private var trackballDecelerationTimer: Timer?
    private let trackballDecelerationRate: CGFloat = 0.90
    private let trackballVelocityThreshold: CGFloat = 0.1
    
    private var storedCenter: CGPoint = .zero // location from persisted data
    private var minimumBorderAlpha: CGFloat = 0.19
    private var defaultBorderColor: CGColor = UIColor(white: 0.2, alpha: 0.3).cgColor
    private let moonlightPurple: CGColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.86).cgColor

    // whole button press down visual effect
    private let buttonDownVisualEffectLayer = CAShapeLayer()
    private var buttonDownVisualEffectWidth: CGFloat
    
    @objc init(keyString: String, keyLabel: String) {
        self.keyString = keyString
        self.keyLabel = keyLabel
        self.label = UILabel()
        // self.originalBackgroundColor = UIColor(white: 0.2, alpha: 0.7)
        self.timestamp = 0
        self.pressed = false
        // self.widthFactor = 1.0
        // self.heightFactor = 1.0
        // self.backgroundAlpha = 0.5
        // self.velocityFactor = 1.0

        self.latestTouchLocation = CGPoint(x: 0, y: 0)
        self.deltaX = 0
        self.deltaY = 0
        self.offSetX = 0
        self.offSetY = 0
        self.onScreenControls = OnScreenControls()
        self.appWindow = UIApplication.shared.windows.first!
        self.quickDoubleTapDetected = false
        self.touchTapTimeInterval = 100
        self.touchTapTimeStamp = 100
        self.buttonDownVisualEffectWidth = 0
        self.mousePointerMoved = false
        self.touchLockedForMoveEvent = UITouch()
        self.twoTouchesDetected = false
        self.stickIndicatorOffset = 95
        self.sensitivityFactorX = 1.0
        self.sensitivityFactorY = 1.0
        super.init(frame: .zero)
        
        upIndicator = createLrudDirectionLayer()
        upIndicator.anchorPoint = CGPoint(x: 0.5, y: 1)
        downIndicator = createLrudDirectionLayer()
        downIndicator.anchorPoint = CGPoint(x: 0.5, y: 0)
        leftIndicator = createLrudDirectionLayer()
        leftIndicator.anchorPoint = CGPoint(x: 1, y: 0.5)
        rightIndicator = createLrudDirectionLayer()
        rightIndicator.anchorPoint = CGPoint(x: 0, y: 0.5)

        
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func setLocation(xOffset:CGFloat, yOffset:CGFloat) {
        /*
        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: self.superview!.leadingAnchor, constant: xOffset),
            self.centerYAnchor.constraint(equalTo: self.superview!.topAnchor, constant: yOffset),
        ])
         */
        storedCenter = CGPointMake(xOffset, yOffset)
        center = storedCenter
    }
    
    @objc public func enableRelocationMode(enabled: Bool){
        OnScreenWidgetView.editMode = enabled
    }
    
    @objc public func adjustTransparency(alpha: CGFloat){
        if alpha != 0 {
            self.backgroundAlpha = alpha
        }
        else{
            // self.backgroundAlpha = 0.5
            self.backgroundAlpha = alpha
        }
        self.tweakAlpha()
    }
    
    @objc public func adjustBorder(width: CGFloat){
        self.borderWidth = width
        // self.layer.borderWidth = borderWidth
        // if CommandManager.touchPadCmds.contains(self.keyString) && width == 0 {self.layer.borderWidth = 1}
        setupView()
    }
    
    @objc public func resizeWidgetView(){
        guard let superview = superview else { return }
        
        
        // Deactivate existing constraints if necessary
        NSLayoutConstraint.deactivate(self.constraints)
        
        // To resize the button, we must set this to false temporarily
        translatesAutoresizingMaskIntoConstraints = false
                
        // replace invalid factor values
        if self.widthFactor == 0 {self.widthFactor = 1.0}
        if self.heightFactor == 0 {self.heightFactor = 1.0}
        

        /*
        NSLayoutConstraint.activate([
            self.centerXAnchor.constraint(equalTo: self.superview!.leadingAnchor, constant: storedLocation.x),
            self.centerYAnchor.constraint(equalTo: self.superview!.topAnchor, constant: storedLocation.y)])
         */
        

        // Constraints for resizing
        self.changeAndActivateContraints()
        
        // Trigger layout update
        superview.layoutIfNeeded()
        
        // Re-setup widgetView style
        setupView()
    }
    
    private func tweakAlpha(){
        // setup default border from self.backgroundAlpha
        let realBackgroundAlpha = self.backgroundAlpha - 0.18 // offset to be consistent with legacy onScreen controller layer opacity
        self.backgroundColor = UIColor(white: 0.2, alpha: realBackgroundAlpha) // offset to be consistent with legacy onScreen controller layer opacity
        var borderAlpha = realBackgroundAlpha * 1.01
        if CommandManager.touchPadCmds.contains(self.keyString) {
           minimumBorderAlpha = 0.0
        }
        if borderAlpha < minimumBorderAlpha {
            borderAlpha = minimumBorderAlpha
        }
        defaultBorderColor = UIColor(white: 0.2, alpha: borderAlpha).cgColor
        self.layer.borderColor = defaultBorderColor

        if CommandManager.touchPadCmds.contains(self.keyString){
            self.backgroundColor = UIColor.clear // make touchPad transparent
            self.layer.borderColor = UIColor(white: 0.2, alpha: borderAlpha - 0.15).cgColor // reduced border alpha for touchPad
        }
    }
    
    private func changeAndActivateContraints(){
        if CommandManager.oscButtonMappings.keys.contains(self.keyString) && !CommandManager.oscRectangleButtonCmds.contains(self.keyString){ // we'll make custom osc buttons round & smaller  
           
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: 60 * self.widthFactor),
                self.heightAnchor.constraint(equalToConstant: 60 * self.heightFactor),])
            
            // self.frame = CGRectMake(0, 0, 60*self.widthFactor, 60*self.heightFactor)
            }
        else if CommandManager.touchPadCmds.contains(self.keyString) { // make touchPads larger
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: 170 * self.widthFactor),
                self.heightAnchor.constraint(equalToConstant: 150 * self.heightFactor),])
        }
        else {
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: 70 * self.widthFactor),
                self.heightAnchor.constraint(equalToConstant: 65 * self.heightFactor),])
           }

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10), // set up label size contrain within UIView
            label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),])
    }
    
    private func setupView() {
        label.text = self.keyLabel
        label.font = UIFont.boldSystemFont(ofSize: 19)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.1  // Adjust the scale factor as needed
        
        label.textColor = UIColor(white: 1.0, alpha: 0.82)
        label.textAlignment = .center
        label.shadowColor = .black
        label.shadowOffset = CGSize(width: 1, height: 1)
        label.translatesAutoresizingMaskIntoConstraints = false // enable auto alignment for the label
        
        self.translatesAutoresizingMaskIntoConstraints = true // this is mandatory to prevent unexpected key view location change
        
        self.layer.cornerRadius = 16
        self.layer.borderWidth = self.borderWidth

        self.tweakAlpha()
        
        if CommandManager.oscButtonMappings.keys.contains(self.keyString) && !CommandManager.oscRectangleButtonCmds.contains(self.keyString){ //make oscButtons round and no border
            self.layer.cornerRadius = self.frame.width/2
            // self.layer.borderWidth = self.borderWidth
            label.minimumScaleFactor = 0.15  // Adjust the scale factor for oscButtons
            label.font = UIFont.boldSystemFont(ofSize: 22)
        }
        
        if CommandManager.touchPadCmds.contains(self.keyString){
            if(self.borderWidth < 1) {self.layer.borderWidth = 1}
            else {self.layer.borderWidth = self.borderWidth}
            label.text = "" // make touchPad display no text
            if OnScreenWidgetView.editMode { //display label in edit mode to make the pad more visible
                label.text = self.keyString
            }
        }

        if CommandManager.specialOverlayButtonCmds.contains(self.keyString){
            self.layer.borderWidth = 0
        }

        
        // self.layer.shadowColor = UIColor.clear.cgColor
        // self.layer.shadowRadius = 8
        // self.layer.shadowOpacity = 0.5
        
        addSubview(label)
        
        self.changeAndActivateContraints()
        
        center = storedCenter //anchor the center while resizing self
        
        setupButtonDownVisualEffectLayer();
    }
    
    private func createAndShowl3r3Indicator() -> CAShapeLayer{
        let indicatorFrame = CAShapeLayer();
        let indicatorBorder = CAShapeLayer();
        
        indicatorFrame.frame = CGRectMake(0, 0, 80, 80)
        indicatorFrame.cornerRadius = 9
        indicatorBorder.borderWidth = 7.5
        indicatorBorder.frame = indicatorFrame.bounds.insetBy(dx: -indicatorBorder.borderWidth, dy: -indicatorBorder.borderWidth) // Adjust the inset as needed
        indicatorBorder.borderColor = UIColor.clear.cgColor
        
        indicatorBorder.cornerRadius = indicatorFrame.cornerRadius + indicatorBorder.borderWidth
        indicatorBorder.backgroundColor = UIColor.clear.cgColor
        indicatorBorder.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: indicatorBorder.bounds, cornerRadius: indicatorBorder.cornerRadius)
        indicatorBorder.path = path.cgPath
        indicatorBorder.borderColor = moonlightPurple
        
        self.layer.superlayer?.addSublayer(indicatorBorder)
        indicatorBorder.position = CGPointMake(CGRectGetMinX(self.frame)+touchBeganLocation.x, CGRectGetMinY(self.frame)+touchBeganLocation.y)
        
        return indicatorBorder
    }

    
    //================================================================================================
    //Indicator overlay for on-screen game controller left or right sticks (non-vector mode)
    
    private func handleStickBallReachingBorder(){
        stickBallLayer.lineWidth = 0.6
        // stickBallLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        stickBallLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        // stickBallLayer.shadowColor = stickBallLayer.strokeColor
    }

    private func handleStickBallLeavingBorder(){
        stickBallLayer.lineWidth = 0
        stickBallLayer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        stickBallLayer.shadowOpacity = 0.8
        stickBallLayer.shadowColor = UIColor.black.cgColor
    }
    
    // create stick indicator: the crossMark & stickBall:
    @objc public func showStickIndicator(){
        // tell if the self button is located on the left or right
        // self.selfViewOnTheRight = (self.storedCenter.x > self.appWindow.frame.width*0.5), deprecated
        // let offsetSign = selfViewOnTheRight ? -1 : 1
        let stickMarkerRelativeLocation:CGPoint
        if !OnScreenWidgetView.editMode {
            stickMarkerRelativeLocation = CGPointMake(touchBeganLocation.x, touchBeganLocation.y - self.stickIndicatorOffset)
        }
        else{
            stickMarkerRelativeLocation = CGPointMake(touchBeganLocation.x, touchBeganLocation.y)
        }
        
        self.crossMarkLayer = createAndShowCrossMarkOnTouchPoint(at: stickMarkerRelativeLocation)
        self.stickBallLayer = createAndShowStickBall(at: stickMarkerRelativeLocation)
    }
    
    // cross mark for left & right gamePad
    private func createAndShowCrossMarkOnTouchPoint(at point: CGPoint) -> CAShapeLayer {
        let crossLayer = CAShapeLayer()
        let path = UIBezierPath()
        let crossSize = 26.0
        
        path.move(to: CGPoint(x: point.x - crossSize / 2, y: point.y))
        path.addLine(to: CGPoint(x: point.x + crossSize / 2, y: point.y))
        
        // 竖线
        path.move(to: CGPoint(x: point.x, y: point.y - crossSize / 2))
        path.addLine(to: CGPoint(x: point.x, y: point.y + crossSize / 2))
        
        crossLayer.path = path.cgPath
        crossLayer.strokeColor = crossMarkColor
        crossLayer.lineWidth = 1.2
        crossLayer.fillColor = crossMarkColor
        
        self.layer.superlayer?.addSublayer(crossLayer)
        crossLayer.position = CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame))
        // crossLayer.shadowRadius = 1
        crossLayer.shadowColor = UIColor.black.cgColor
        crossLayer.shadowOffset = CGSize(width: 1, height: 1)
        crossLayer.shadowRadius = 0;
        crossLayer.shadowOpacity = 0.8
        
        return crossLayer
    }
    
    private func createAndShowStickBall(at center: CGPoint) -> CAShapeLayer {
        // Create a circular path using UIBezierPath
        let path = UIBezierPath(arcCenter: center, radius: 8, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        // Create a CAShapeLayer
        let stickBallLayer = CAShapeLayer()
        stickBallLayer.path = path.cgPath  // Assign the circular path to the shape layer
        self.layer.superlayer?.addSublayer(stickBallLayer)
        stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame))
        
        // stickBallLayer.position = CG
        
        // Set the stroke color and width (border of the circle)
        stickBallLayer.strokeColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).cgColor
        //stickBallLayer.
        stickBallLayer.lineWidth = 0
        stickBallLayer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        stickBallLayer.shadowRadius = 0;
        stickBallLayer.shadowOpacity = 0.8
        
        // Set the fill color (inside of the circle)
        stickBallLayer.fillColor = stickBallColor  // Light fill with some transparency
                
        return stickBallLayer
    }
    
    @objc public func updateStickIndicator(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.stickBallLayer.removeAllAnimations()
        if !OnScreenWidgetView.editMode {
            let realOffsetX = touchInputToStickBallCoord(input: offSetX*sensitivityFactorX)
            let realOffsetY = touchInputToStickBallCoord(input: offSetY*sensitivityFactorY)
            self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame) + realOffsetX, CGRectGetMidY(self.crossMarkLayer.frame) + realOffsetY)
            if fabs(realOffsetX) == stickBallMaxOffset || fabs(realOffsetY) == stickBallMaxOffset {
                handleStickBallReachingBorder()
            }
            else{
                handleStickBallLeavingBorder()
            }
        }
        else{
            // illustrate offset distance in edit mode
            // let offsetSign = self.selfViewOnTheRight ? -1 : 1 // dprecated
            // let illlustrationPoint = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMaxY(self.frame)/4)
            self.crossMarkLayer.position = CGPointMake(CGRectGetMidX(self.stickBallLayer.frame), CGRectGetMidY(self.stickBallLayer.frame)-stickIndicatorOffset)
        }
        CATransaction.commit()
    }
    
    private func resetStickBallPositionAndRemoveIndicator(){
        handleStickBallLeavingBorder()
        CATransaction.begin()
        // CATransaction.setDisableActions(true)
        CATransaction.setAnimationDuration(0.15)
        self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame))
        CATransaction.setCompletionBlock {
            DispatchQueue.global().async {
                // 后台执行耗时操作
                usleep(200000)
                DispatchQueue.main.async {
                    if !self.touchBegan {
                        self.crossMarkLayer.removeFromSuperlayer()
                        self.stickBallLayer.removeFromSuperlayer()
                    }
                }
            }
            // 动画结束后执行的代码
        }
        CATransaction.commit()
    }
    
    //================================================================================================
    
    
    
    //=====LRUD(left right up & down buttons) touchPad touch =========================================
    
    private func createAndShowLrudBall(at point: CGPoint) -> CAShapeLayer {
        // Create a circular path using UIBezierPath
        let path = UIBezierPath(arcCenter: point, radius: 10, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        // Create a CAShapeLayer
        let ballLayer = CAShapeLayer()
        ballLayer.path = path.cgPath  // Assign the circular path to the shape layer
        self.layer.superlayer?.addSublayer(ballLayer)
        
        ballLayer.position = CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame))
        
        // Set the stroke color and width (border of the circle)
        ballLayer.strokeColor = stickBallColor
        ballLayer.lineWidth = 0
        ballLayer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        ballLayer.shadowRadius = 0;
        ballLayer.shadowOpacity = 0.8
        
        // Set the fill color (inside of the circle)
        ballLayer.fillColor = stickBallColor  // Light fill with some transparency
        return ballLayer
    }
    
    private func createLrudDirectionLayer() -> CAShapeLayer {
        let indicatorFrame = CAShapeLayer();
        let indicatorBorder = CAShapeLayer();
        
        indicatorFrame.frame = CGRectMake(0, 0, 78.5, 78.5)
        indicatorFrame.cornerRadius = 9
        indicatorBorder.borderWidth = 6
        indicatorBorder.frame = indicatorFrame.bounds.insetBy(dx: -indicatorBorder.borderWidth, dy: -indicatorBorder.borderWidth) // Adjust the inset as needed
        indicatorBorder.borderColor = UIColor.clear.cgColor
        
        indicatorBorder.cornerRadius = indicatorFrame.cornerRadius + indicatorBorder.borderWidth
        indicatorBorder.backgroundColor = UIColor.clear.cgColor
        indicatorBorder.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: indicatorBorder.bounds, cornerRadius: indicatorBorder.cornerRadius)
        indicatorBorder.path = path.cgPath
        indicatorBorder.borderColor = moonlightPurple
        
        return indicatorBorder
    }
    
    private func showLrudDirectionIndicator(with indicatorLayer:CAShapeLayer){
        // Add the border layer below the super layer
        self.layer.superlayer?.insertSublayer(indicatorLayer, below: self.layer)
        
        // show the indicator based on the touchBeganLocation
        indicatorLayer.position = CGPointMake(CGRectGetMinX(self.frame)+touchBeganLocation.x, CGRectGetMinY(self.frame)+touchBeganLocation.y)
    }
    
    private func handleLrudTouchMove(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let triggeringAngle = 67.5
        let radians  = atan2(-offSetY,offSetX)
        let degrees = radians * 180 / .pi
        enum Direction: Int {
            case right = 1
            case up = 2
            case left = 4
            case down = 8
        }
        
        let nearZeroPoint = abs(offSetX)<28 && abs(offSetY)<28
        // NSLog("deltaX: %f, detalY: %f", deltaX, deltaY)
        
        var buttonPressed = 0;
        if abs(degrees) < triggeringAngle {
            // NSLog("button pressed: right")
            buttonPressed = buttonPressed | Direction.right.rawValue
        }
        if 180.0 - abs(degrees) < triggeringAngle {
            // NSLog("button pressed: left")
            buttonPressed = buttonPressed | Direction.left.rawValue
        }
        if abs(90.0 - degrees) < triggeringAngle {
            // NSLog("button pressed: up")
            buttonPressed = buttonPressed | Direction.up.rawValue
        }
        if abs(-90.0 - degrees) < triggeringAngle {
            // NSLog("button pressed: down")
            buttonPressed = buttonPressed | Direction.down.rawValue
        }
        if nearZeroPoint {buttonPressed = 0}
        
        if(buttonPressed & Direction.up.rawValue == Direction.up.rawValue){
            showLrudDirectionIndicator(with: upIndicator)
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_DOWN), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
            case "DPAD": self.onScreenControls.pressDownControllerButton(UP_FLAG)
            default: break
            }
        }
        else{
            self.upIndicator.removeFromSuperlayer()
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD": self.onScreenControls.releaseControllerButton(UP_FLAG)
            default: break
            }
        }
        if(buttonPressed & Direction.down.rawValue == Direction.down.rawValue){
            showLrudDirectionIndicator(with: downIndicator)
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_DOWN), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
            case "DPAD": self.onScreenControls.pressDownControllerButton(DOWN_FLAG)
            default: break
            }
        }
        else{
            self.downIndicator.removeFromSuperlayer()
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD": self.onScreenControls.releaseControllerButton(DOWN_FLAG)
            default: break
            }
        }
        if(buttonPressed & Direction.left.rawValue == Direction.left.rawValue){
            showLrudDirectionIndicator(with: leftIndicator)
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_DOWN), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
            case "DPAD": self.onScreenControls.pressDownControllerButton(LEFT_FLAG)
            default: break
            }
        }
        else{
            self.leftIndicator.removeFromSuperlayer()
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD": self.onScreenControls.releaseControllerButton(LEFT_FLAG)
            default: break
            }
        }
        if(buttonPressed & Direction.right.rawValue == Direction.right.rawValue){
            showLrudDirectionIndicator(with: rightIndicator)
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_DOWN), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
            case "DPAD": self.onScreenControls.pressDownControllerButton(RIGHT_FLAG)
            default: break
            }
        }
        else{
            self.rightIndicator.removeFromSuperlayer()
            switch keyString {
            case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD": self.onScreenControls.releaseControllerButton(RIGHT_FLAG)
            default: break
            }
        }
        
        CATransaction.commit()
    }
    //================================================================================================
    
    
    //===== MOUSEPAD related methods=============================================================
    private func sendLongMouseLeftButtonClickEvent() {
        DispatchQueue.global(qos: .userInitiated).async {
            // Logging the press event
            NSLog("Sending left mouse button press")
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)

            // Wait 200 ms to simulate a real button press
            usleep(UInt32(self.QUICK_TAP_TIME_INTERVAL * 1000000))

            // If quick tap is not detected, release the button
            if !self.quickDoubleTapDetected {
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
                // NSLog("double click: first long click release")
            }
            else{NSLog("Left mouse button release cancelled, keep pressing down, turning into dragging...")}
            // Don't release the button if we're still dragging, this will prevent the dragging from being interrupted.
        }
    }

    private func sendShortMouseLeftButtonClickEvent() {
        DispatchQueue.global(qos: .userInitiated).async {
            NSLog("double click: sending short click")
            usleep(UInt32(50 * 1000))
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)
            usleep(UInt32(50 * 1000))
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
        }
    }
    
    private func sendMouseRightButtonClickEvent() {
        DispatchQueue.global(qos: .userInitiated).async {
            usleep(UInt32(50 * 1000))
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_RIGHT)
            usleep(UInt32(50 * 1000))
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
        }
    }
    
    //mousepad-trackball behavior========================================================
    private func startTrackballMomentum() {
        stopTrackballMomentum()

        trackballDecelerationTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            LiSendMouseMoveEvent(
                Int16(truncatingIfNeeded: Int(self.trackballVelocity.x)),
                Int16(truncatingIfNeeded: Int(self.trackballVelocity.y))
            )

            self.trackballVelocity.x *= self.trackballDecelerationRate
            self.trackballVelocity.y *= self.trackballDecelerationRate

            if abs(self.trackballVelocity.x) < self.trackballVelocityThreshold &&
               abs(self.trackballVelocity.y) < self.trackballVelocityThreshold {
                self.stopTrackballMomentum()
            }
        }
    }

    private func stopTrackballMomentum() {
        trackballDecelerationTimer?.invalidate()
        trackballDecelerationTimer = nil
    }

    
    //==== wholeButtonPress visual effect=============================================
    private func buttonDownVisualEffect() {
        // setupBorderLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // self.layer.borderWidth = 0
        buttonDownVisualEffectLayer.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)) // update position every time we press down the button
        buttonDownVisualEffectLayer.borderWidth = self.buttonDownVisualEffectWidth // this will show the visual effect
        buttonDownVisualEffectLayer.borderColor = moonlightPurple
        CATransaction.commit()
    }
    
    private func buttonUpVisualEffect() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // self.layer.borderWidth = 1
        buttonDownVisualEffectLayer.borderWidth = 0
        buttonDownVisualEffectLayer.borderColor = defaultBorderColor
        CATransaction.commit()
    }
    
    
    private func setupButtonDownVisualEffectLayer() {
        self.buttonDownVisualEffectWidth = 8
        if CommandManager.oscButtonMappings.keys.contains(self.keyString) && !CommandManager.oscRectangleButtonCmds.contains(self.keyString){
            if widthFactor < 1.3 {self.buttonDownVisualEffectWidth = 15.3} // wider visual effect for osc buttons
            else {self.buttonDownVisualEffectWidth = 9}
        }
        
        // Set the frame to be larger than the view to expand outward
        buttonDownVisualEffectLayer.borderWidth = 0 // set this 0 to hide the visual effect first
        buttonDownVisualEffectLayer.frame = self.bounds.insetBy(dx: -self.buttonDownVisualEffectWidth, dy: -self.buttonDownVisualEffectWidth) // Adjust the inset as needed
        buttonDownVisualEffectLayer.cornerRadius = self.layer.cornerRadius + self.buttonDownVisualEffectWidth
        buttonDownVisualEffectLayer.backgroundColor = UIColor.clear.cgColor;
        buttonDownVisualEffectLayer.fillColor = UIColor.clear.cgColor;
        
        // Create a path for the border
        let path = UIBezierPath(roundedRect: buttonDownVisualEffectLayer.bounds, cornerRadius: buttonDownVisualEffectLayer.cornerRadius)
        buttonDownVisualEffectLayer.path = path.cgPath
        
        // Add the border layer below the main view layer
        self.layer.superlayer?.insertSublayer(buttonDownVisualEffectLayer, below: self.layer)
        
        // Retrieve the current frame to account for transformations, this will update the coords for new position CGPointMake
        buttonDownVisualEffectLayer.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame))
    }
    //==========================================================================================================
    
    
    //=========================================send on screen controller stick events
    private func touchInputToStickInput(input: CGFloat) -> CGFloat{
        var target = 0x7FFE * input / stickInputScale
        if target > 0x7FFE {target = 0x7FFE}
        if target < -0x7FFE {target = -0x7FFE}
        return target
    }
    
    private func touchInputToStickBallCoord(input: CGFloat) -> CGFloat {
        if input > stickInputScale {
            return stickBallMaxOffset
        }
        if input < -stickInputScale {
            return -stickBallMaxOffset
        }
        return input * (18/stickInputScale)
    }
    
    private func sendRightStickTouchPadEvent(inputX: CGFloat, inputY: CGFloat){
        let targetX = self.touchInputToStickInput(input: inputX)
        let targetY = -self.touchInputToStickInput(input: inputY)
 // vertical input must be inverted
        self.onScreenControls.sendRightStickTouchPadEvent(targetX, targetY)
    }
    
    private func sendLeftStickTouchPadEvent(inputX: CGFloat, inputY: CGFloat){
        let targetX = self.touchInputToStickInput(input: inputX)
        let targetY = -self.touchInputToStickInput(input: inputY)
        self.onScreenControls.sendLeftStickTouchPadEvent(targetX, targetY)
    }
    //==========================================================================================================
    
    private func sendOscButtonDownEvent(keyString: String){
        let buttonFlag = CommandManager.oscButtonMappings[keyString]
        if buttonFlag != 0 {self.onScreenControls.pressDownControllerButton(buttonFlag!)}
        if keyString == "OSCL2" {
            self.onScreenControls.updateLeftTrigger(0xFF)
        }
        if keyString == "OSCR2" {self.onScreenControls.updateRightTrigger(0xFF)}
    }

    private func sendOscButtonUpEvent(keyString: String){
        let buttonFlag = CommandManager.oscButtonMappings[keyString]
        if buttonFlag != 0 {self.onScreenControls.releaseControllerButton(buttonFlag!)}
        if keyString == "OSCL2" {self.onScreenControls.updateLeftTrigger(0x00)}
        if keyString == "OSCR2" {self.onScreenControls.updateRightTrigger(0x00)}
    }
    
//==============================================================================
    private func sendComboButtonsDownEvent(comboStrings: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for comboString in comboStrings {
                if CommandManager.oscButtonMappings.keys.contains(comboString) {
                    self.sendOscButtonDownEvent(keyString: comboString)
                }
                if CommandManager.keyboardButtonMappings.keys.contains(comboString) {
                    LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[comboString]!,Int8(KEY_ACTION_DOWN), 0)
                }
                if CommandManager.mouseButtonMappings.keys.contains(comboString) {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), Int32(CommandManager.mouseButtonMappings[comboString]!))
                }
                usleep(10000) // delay 10ms
            }
        }
    }

    private func sendComboButtonsUpEvent(comboStrings: [String]) {
        DispatchQueue.global(qos: .userInitiated).async {
            for comboString in comboStrings {
                if CommandManager.oscButtonMappings.keys.contains(comboString) {
                    self.sendOscButtonUpEvent(keyString: comboString)
                }
                if CommandManager.keyboardButtonMappings.keys.contains(comboString) {
                    LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[comboString]!,Int8(KEY_ACTION_UP), 0)
                }
                if CommandManager.mouseButtonMappings.keys.contains(comboString) {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), Int32(CommandManager.mouseButtonMappings[comboString]!))
                }
                usleep(10000) //delay 10ms
            }
        }
    }
    
//==============================================================================

    
    // Touch event handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchBegan = true
        super.touchesBegan(touches, with: event)
        self.isMultipleTouchEnabled = self.keyString == "MOUSEPAD" // only enable multi-touch in mousePad mode

        if !OnScreenWidgetView.editMode && self.keyString == "TRACKBALL" {
            stopTrackballMomentum()
        }
        
        if touches.count == 1 { // to make sure touchBegan location captured properly, don't use event.alltouches.count here
            let currentTime = CACurrentMediaTime()
            touchTapTimeInterval = currentTime - touchTapTimeStamp
            touchTapTimeStamp = currentTime
            quickDoubleTapDetected = touchTapTimeInterval < QUICK_TAP_TIME_INTERVAL
            
            let touch = touches.first
            if OnScreenWidgetView.editMode {self.touchBeganLocation = touch!.location(in: superview)}
            else {self.touchBeganLocation = touch!.location(in: self)}
            self.latestTouchLocation = touchBeganLocation
        }
                
        let allCapturedTouchesCount = event?.allTouches?.filter({ $0.view == self }).count // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        if allCapturedTouchesCount == 2 {
            self.twoTouchesDetected = true
        }
        
        self.pressed = true

        if !OnScreenWidgetView.editMode {

            if CommandManager.touchPadCmds.contains(self.keyString) && touches.count == 1{ // don't use event?.allTouches?.count here, it will counts all touches including the ones captured by other UIViews
                switch self.keyString {
                case "LSPAD":
                    self.crossMarkLayer.removeFromSuperlayer()
                    self.stickBallLayer.removeFromSuperlayer()
                    self.l3r3Indicator.removeFromSuperlayer()
                    self.showStickIndicator()
                    if quickDoubleTapDetected {
                        self.l3r3Indicator = self.createAndShowl3r3Indicator()
                        self.onScreenControls.pressDownControllerButton(LS_CLK_FLAG)}
                    break
                case "RSPAD":
                    self.crossMarkLayer.removeFromSuperlayer()
                    self.stickBallLayer.removeFromSuperlayer()
                    self.l3r3Indicator.removeFromSuperlayer()
                    self.showStickIndicator()
                    if quickDoubleTapDetected {
                        self.l3r3Indicator = self.createAndShowl3r3Indicator()
                        self.onScreenControls.pressDownControllerButton(RS_CLK_FLAG)}
                    break
                case "LSVPAD":
                    if quickDoubleTapDetected {
                        self.l3r3Indicator = self.createAndShowl3r3Indicator()
                        self.onScreenControls.pressDownControllerButton(LS_CLK_FLAG)}
                    break
                case "RSVPAD":
                    if quickDoubleTapDetected {
                        self.l3r3Indicator = self.createAndShowl3r3Indicator()
                        self.onScreenControls.pressDownControllerButton(RS_CLK_FLAG)}
                    break
                case "DPAD", "WASDPAD", "ARROWPAD":
                    self.lrudIndicatorBall = createAndShowLrudBall(at: touchBeganLocation)
                    break
                default:
                    break
                }
            }
            
            if !self.keyString.contains("+") && !self.keyString.contains("-") {
                // if there's no "+" in the keystring, treat it as a regular button:
                if CommandManager.oscButtonMappings.keys.contains(self.keyString) {
                    self.sendOscButtonDownEvent(keyString: self.keyString)
                }
                if CommandManager.keyboardButtonMappings.keys.contains(self.keyString) {
                    LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[self.keyString]!,Int8(KEY_ACTION_DOWN), 0)
                }
                if CommandManager.mouseButtonMappings.keys.contains(self.keyString) {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), Int32(CommandManager.mouseButtonMappings[self.keyString]!))
                }
            }
            
            // if the command(keystring contains "-", it's a multi-type super combo button
            if self.keyString.contains("-"){
                let comboStrings = CommandManager.shared.extractKeyStringsFromComboKeys(from: self.keyString)!
                self.sendComboButtonsDownEvent(comboStrings: comboStrings)
            }
            
            // if the command(keystring contains "+", it's a multi-key command or a quick triggering key, rather than a physical button
            if self.keyString.contains("+") && !self.keyString.contains("-"){
                let keyboardCmdStrings = CommandManager.shared.extractKeyStringsFromComboCommand(from: self.keyString)!
                CommandManager.shared.sendKeyComboCommand(keyboardCmdStrings: keyboardCmdStrings) // send multi-key command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { // reset shadow color immediately 50ms later
                    self.buttonUpVisualEffect()
                }
            }
            
            if !CommandManager.touchPadCmds.contains(self.keyString) {
                self.buttonDownVisualEffect()
            }
        }
        // here is in edit mode:
        else{
            NotificationCenter.default.post(name: Notification.Name("OnScreenWidgetViewSelected"),object: self) // inform layout tool controller to fetch button size factors. self will be passed as the object of the notification
        }
        
    }
    
    private func moveByTouch(touch: UITouch){
        let currentLocation: CGPoint
        if OnScreenWidgetView.editMode {currentLocation = touch.location(in: superview)}
        else {currentLocation = touch.location(in: self)}
        
        let offsetX = currentLocation.x - latestTouchLocation.x
        let offsetY = currentLocation.y - latestTouchLocation.y
        center = CGPoint(x: center.x + offsetX, y: center.y + offsetY)
        latestTouchLocation = currentLocation
        // center = currentLocation;
        //NSLog("x coord: %f, y coord: %f", self.frame.origin.x, self.frame.origin.y)
        storedCenter = center // Update initial center for next movement
        if OnScreenWidgetView.editMode {
            NotificationCenter.default.post(name: Notification.Name("OnScreenWidgetMovedByTouch"), object:self) // inform the layoutOnScreenControl to update guideLines for this widget view
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        if !OnScreenWidgetView.editMode {
            if CommandManager.touchPadCmds.contains(self.keyString){
                handleTouchPadMoveEvent(touches, with: event)
            }
            
            if CommandManager.specialOverlayButtonCmds.contains(self.keyString){
                if let touch = touches.first {
                    NSLog("touchTapTimeStamp %f", self.touchTapTimeStamp)
                    if CACurrentMediaTime() - self.touchTapTimeStamp > 0.3 { // temporarily relocate special buttons
                        self.moveByTouch(touch: touch)
                        self.buttonUpVisualEffect()
                    }
                }
            }
        }
        
        // Move the widgetView based on touch movement in relocation mode
        if OnScreenWidgetView.editMode {
            if let touch = touches.first {
                self.moveByTouch(touch: touch)
                }
            if CommandManager.nonVectorStickPads.contains(self.keyString) {
                self.stickBallLayer.removeFromSuperlayer()
                self.crossMarkLayer.removeFromSuperlayer()
            }
        }
    }
    
    private func handleTouchPadMoveEvent (_ touches: Set<UITouch>, with event: UIEvent?){
        if touches.count == 1{ // don't use event.alltouches.count here, it will counts all touches
            self.mousePointerMoved = true
            let currentTouchLocation: CGPoint = (touches.first?.location(in: self))!
            self.deltaX = currentTouchLocation.x - self.latestTouchLocation.x
            self.deltaY = currentTouchLocation.y - self.latestTouchLocation.y
            self.offSetX = currentTouchLocation.x - self.touchBeganLocation.x
            self.offSetY = currentTouchLocation.y - self.touchBeganLocation.y
            self.latestTouchLocation = currentTouchLocation
            
            switch self.keyString{
            case "MOUSEPAD":
                LiSendMouseMoveEvent(Int16(truncatingIfNeeded: Int(deltaX * 1.7 * sensitivityFactorX)), Int16(truncatingIfNeeded: Int(deltaY * 1.7 * sensitivityFactorY)))
                break
            case "TRACKBALL":
                let dx = deltaX * 1.7 * sensitivityFactorX
                let dy = deltaY * 1.7 * sensitivityFactorY
                LiSendMouseMoveEvent(Int16(truncatingIfNeeded: Int(dx)), Int16(truncatingIfNeeded: Int(dy)))
                self.trackballVelocity = CGPoint(x: dx, y: dy)
                stopTrackballMomentum()
                break
            case "LSPAD":
                self.sendLeftStickTouchPadEvent(inputX: offSetX * sensitivityFactorX, inputY: offSetY*sensitivityFactorY)
                updateStickIndicator()
            case "RSPAD":
                self.sendRightStickTouchPadEvent(inputX: offSetX * sensitivityFactorX, inputY: offSetY * sensitivityFactorY);
                updateStickIndicator()
            case "LSVPAD":
                self.sendLeftStickTouchPadEvent(inputX: deltaX*1.5167*sensitivityFactorX, inputY: deltaY*1.5167*sensitivityFactorY)
            case "RSVPAD":
                self.sendRightStickTouchPadEvent(inputX: deltaX*1.5167*sensitivityFactorX, inputY: deltaY*1.5167*sensitivityFactorY);
            case "DPAD", "WASDPAD", "ARROWPAD":
                handleLrudTouchMove()
            default:
                break
            }

        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchBegan = false
        super.touchesEnded(touches, with: event)

        if self.keyString != "MOUSEPAD" {quickDoubleTapDetected = false} //do not reset this flag here in mousePad mode
        
        let allCapturedTouchesCount = event?.allTouches?.filter({ $0.view == self }).count // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        
        // deal with MOUSPAD first
        if !OnScreenWidgetView.editMode && self.keyString == "MOUSEPAD" && allCapturedTouchesCount == 1 && !twoTouchesDetected {
            if !mousePointerMoved && !quickDoubleTapDetected {self.sendLongMouseLeftButtonClickEvent()} // deal with single tap(click)
            if quickDoubleTapDetected { //deal with quick double tap
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT) //must release the button anyway, because the button is likely being held down since the long click turned into a dragging event.
                if !mousePointerMoved {self.sendShortMouseLeftButtonClickEvent()}
                quickDoubleTapDetected = false
            }
            mousePointerMoved = false // reset this flag
        }
        
        if !OnScreenWidgetView.editMode && self.keyString == "TRACKBALL" && allCapturedTouchesCount == 1 && !twoTouchesDetected {
            self.startTrackballMomentum()
        }
        
        if !OnScreenWidgetView.editMode && self.keyString == "MOUSEPAD" && twoTouchesDetected && touches.count == allCapturedTouchesCount { // need to enable multi-touch first
            // touches.count == allCapturedTouchesCount means allfingers are lifting
            self.sendMouseRightButtonClickEvent()
            twoTouchesDetected = false
        }
        
        // then other types of pads
        if !OnScreenWidgetView.editMode && CommandManager.touchPadCmds.contains(self.keyString) {
            switch self.keyString{
            case "LSPAD":
                self.onScreenControls.clearLeftStickTouchPadFlag()
                self.resetStickBallPositionAndRemoveIndicator()
            case "RSPAD":
                self.onScreenControls.clearRightStickTouchPadFlag()
                self.resetStickBallPositionAndRemoveIndicator()
            case "LSVPAD":
                self.onScreenControls.clearLeftStickTouchPadFlag()
            case "RSVPAD":
                self.onScreenControls.clearRightStickTouchPadFlag()
            case "WASDPAD":
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD":
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD":
                self.onScreenControls.releaseControllerButton(LEFT_FLAG)
                self.onScreenControls.releaseControllerButton(RIGHT_FLAG)
                self.onScreenControls.releaseControllerButton(UP_FLAG)
                self.onScreenControls.releaseControllerButton(DOWN_FLAG)
            default:
                break
            }
        }
        self.l3r3Indicator.removeFromSuperlayer()
        self.upIndicator.removeFromSuperlayer()
        self.downIndicator.removeFromSuperlayer()
        self.leftIndicator.removeFromSuperlayer()
        self.rightIndicator.removeFromSuperlayer()
        self.lrudIndicatorBall.removeFromSuperlayer()
                                
        if !OnScreenWidgetView.editMode && !self.keyString.contains("+") && !self.keyString.contains("-") { // if the command(keystring contains "+", it's a multi-key command rather than a single key button
            if CommandManager.oscButtonMappings.keys.contains(self.keyString) {
                sendOscButtonUpEvent(keyString: self.keyString)
            }
            if CommandManager.keyboardButtonMappings.keys.contains(self.keyString) {
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[self.keyString]!,Int8(KEY_ACTION_UP), 0)
            }
            if CommandManager.mouseButtonMappings.keys.contains(self.keyString){
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), Int32(CommandManager.mouseButtonMappings[self.keyString]!))
            }
        }
        
        // if the command(keystring contains "-", it's a multi-type super combo button
        if !OnScreenWidgetView.editMode && self.keyString.contains("-"){
            let comboStrings = CommandManager.shared.extractKeyStringsFromComboKeys(from: self.keyString)!
            self.sendComboButtonsUpEvent(comboStrings: comboStrings)
        }
        
        if !OnScreenWidgetView.editMode && CommandManager.specialOverlayButtonCmds.contains(self.keyString){
            if CACurrentMediaTime() - self.touchTapTimeStamp < 0.3 {
                switch self.keyString {
                case "SETTINGS":
                    NotificationCenter.default.post(name: Notification.Name("SettingsOverlayButtonPressedNotification"), object:nil) // inform layout tool controller to fetch button size factors. self will be passed as the object of the notification
                default:
                    break
                }
            }
        }
        
        self.buttonUpVisualEffect()
        
        
        if OnScreenWidgetView.editMode {
            guard let superview = superview else { return }
            
            // Deactivate existing constraints if necessary
            NSLayoutConstraint.deactivate(self.constraints)
            
            // Add new constraints based on the current center position
            translatesAutoresizingMaskIntoConstraints = true
            
            // Create new constraints
            let newLeadingConstraint = self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: self.frame.origin.x)
            let newTopConstraint = self.topAnchor.constraint(equalTo: superview.topAnchor, constant: self.frame.origin.y)
            
            // Activate the new location constraints
            NSLayoutConstraint.activate([newLeadingConstraint, newTopConstraint])
            
            // Trigger layout update
            superview.layoutIfNeeded()
            
            setupView(); //re-setup widgetView style
            
            if CommandManager.nonVectorStickPads.contains(self.keyString) {
                self.crossMarkLayer.removeFromSuperlayer()
                self.stickBallLayer.removeFromSuperlayer()
                self.showStickIndicator()
                self.updateStickIndicator()
            }
        }
    }
}

