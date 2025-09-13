//
//  OnScreenKey.swift
//  VoidLink
//
//  Created by True砖家 on 2024/8/4.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
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
    
    @objc public weak var guidelineDelegate: OnScreenWidgetGuidelineUpdateDelegate?
    
    @objc protocol OnScreenWidgetGuidelineUpdateDelegate: AnyObject {
        func updateGuidelinesForOnScreenWidget(_ sender: Any)
    }
    
    @objc enum WidgetTypeEnum: UInt8 {
        case uninitialized
        case button
        case touchPad
    }
    
    @objc public var widgetType: WidgetTypeEnum = WidgetTypeEnum.uninitialized
    
    @objc static public var editMode: Bool = false
    @objc static public var buttonVisualFeedbackEnabled: Bool = true
    @objc public var widgetLabel: String
    @objc public var cmdString: String
    private var buttonString: String = ""
    private var touchPadString: String = ""
    // super combo key string set
    private var comboButtonStrings: [String] = []
    private var comboKeyTimeIntervalMs: UInt32 = 0
    
    @objc public var pressed: Bool
    @objc public var widthFactor: CGFloat = 1.0
    @objc public var heightFactor: CGFloat = 1.0
    @objc public var slideMode: Int = 0
    
    @objc public var sizeReference: Int = WidgetSizeReference.longSide.rawValue
    @objc public var deNormalizedWidthFactor: CGFloat = 1.0
    @objc public var deNormalizedHeightFactor: CGFloat = 1.0
    
    @objc public var borderWidth: CGFloat = 0.0
    @objc public var backgroundAlpha: CGFloat = 0.5
    @objc public var vibrationStyle: Int = 6
    @objc public var latestTouchLocation: CGPoint
    @objc public var selfViewOnTheRight: Bool = false
    @objc public var shape: String = "default"
    @objc public var storedCenter: CGPoint = .zero // location from persisted data
    @objc public var initialCenter: CGPoint = .zero // location from persisted data
    @objc public var layoutChanges: [CGPoint] = []
    @objc public var mouseButtonAction: MouseButtonAction = .hovering;
    
    //autoTapTimer
    @objc public var autoTapInterval: Int = 49;
    private var autoTapTimer: SafeTimer?
    
    private let appWindow: UIView
    
    private var vibrationGenerator = UIImpactFeedbackGenerator(style: .light)
    private var vibrationOn: Bool = false
    
    // for all touchPad or buttons hybrid with touchPads
    @objc public var hasStickIndicator: Bool = false
    @objc public var hasSensitivityTweak: Bool = false
    
    // for all stick pads
    @objc public var minStickOffset: CGFloat = 0
    public let stickMaxOffset: CGFloat = 0x7FFE
    
    
    // for LSVPAD, RSVPAD
    @objc public var deltaX: CGFloat
    @objc public var deltaY: CGFloat
    
    // for LSPAD, RSPAD
    @objc public var offSetX: CGFloat
    @objc public var offSetY: CGFloat
    private let crossMarkColor: CGColor = UIColor(white: 1, alpha: 0.70).cgColor
    private let stickBallColor: CGColor = UIColor(white: 1, alpha: 0.75).cgColor
    private var stickInputScale: CGFloat = 35
    private var l3r3Indicator = CAShapeLayer()
    private let stickBallMaxOffset = 18.0
    @objc public var crossMarkLayer = CAShapeLayer()
    @objc public var stickBallLayer = CAShapeLayer()
    
    // this is for all stick pads and mouse Pad
    @objc public var sensitivityFactorX: CGFloat = 1.0
    @objc public var sensitivityFactorY: CGFloat = 1.0
    
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
    private let triggeringAngle = 67.5
    private enum Direction: Int {
        case right = 1
        case up = 2
        case left = 4
        case down = 8
        case initialStatus = 16
    }
    private var previousButtonMask = Direction.initialStatus.rawValue
    
    // OnScreenControls instance
    private var onScreenControls: OnScreenControls
    
    // key / button label
    private let label: UILabel
    
    // first touch location within the button or pad view (self)
    @objc public var touchBeganLocation: CGPoint = .zero
    
    // for mousePad
    private var touchLockedForMoveEvent: UITouch
    private var touchBegan: Bool = false
    private var firstTouchMoved: Bool = false
    private var mousePointerMoved: Bool
    private var twoTouchesDetected: Bool
    
    // trackball
    private var trackballVelocity: CGPoint = .zero
    private var trackballDecelerationTimer: Timer?
    @objc public var trackballDecelerationRate: CGFloat = 0.93
    private let trackballVelocityThreshold: CGFloat = 0.1
    
    
    // border & visual effect
    private var minimumBorderAlpha: CGFloat = 0.19
    private var defaultBorderColor: CGColor = UIColor(white: 0.2, alpha: 0.3).cgColor
    private let voidlinkPurple: CGColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.86).cgColor
    
    //slide buttons
    private var capturedTouches: NSMutableSet
    private let noTouch: UITouch = UITouch()
    let setLock = NSLock()
    
    //controller touch pad
    private var pointerIdPool: Set<UInt32>
    private var pointerIdDict: Dictionary<ObjectIdentifier, UInt32>
    private var activePointerIds: Set<UInt32>
    
    // whole button press down visual effect
    @objc public let buttonDownVisualEffectLayer = CAShapeLayer()
    private var buttonDownVisualEffectWidth: CGFloat
    
    
    @objc init(cmdString: String, buttonLabel: String, shape:String) {
        
        self.cmdString = cmdString
        self.touchPadString = ""
        
        if !self.cmdString.contains("+"){
            // 安全解包并处理 `comboKeyStrings`
            if var comboStrings = CommandManager.shared.extractSinglCmdStringsFromComboKeys(from: self.cmdString) {
                
                // extract timeInterval
                if let lastString = comboStrings.last, lastString.contains("MS") {
                    // 移除 "MS" 后的部分并转换为整数
                    let timeIntervalString = lastString.replacingOccurrences(of: "MS", with: "")
                    // 安全地将字符串转换为整数
                    if let timeInterval = UInt32(timeIntervalString) {
                        self.comboKeyTimeIntervalMs = timeInterval
                    } else {print("无法将时间字符串转换为整数")}
                    comboStrings.removeLast()
                }
                
                if CommandManager.touchPadCmds.contains(comboStrings.first ?? "") {self.widgetType = WidgetTypeEnum.touchPad}
                else {self.widgetType = WidgetTypeEnum.button}
                
                let touchPadString = Set(comboStrings).intersection(Set(CommandManager.touchPadCmds)).first ?? ""
                self.comboButtonStrings = comboStrings.filter{$0 != touchPadString}
                self.touchPadString = touchPadString
                self.buttonString = self.comboButtonStrings.first ?? ""
                
                //  let stickAndMouseTouchpads = ["LSPAD", "RSPAD", "LSVPAD", "RSVPAD", "MOUSEPAD"]
                let nonVectorStickPads = ["LSPAD", "RSPAD"]
                // if CommandManager.touchPadCmds.contains(self.touchPadString) {self.hasSensitivityTweak = true}
                self.hasSensitivityTweak = CommandManager.touchPadCmds.contains(self.touchPadString)
                
                // if nonVectorStickPads.contains(self.touchPadString) && widgetType == WidgetTypeEnum.touchPad {self.hasStickIndicator = true}
                self.hasStickIndicator = nonVectorStickPads.contains(self.touchPadString) && widgetType == WidgetTypeEnum.touchPad
                
                switch self.cmdString {
                case "LSPAD", "LSVPAD":
                    self.comboButtonStrings = ["OSCL3"]
                case "RSPAD", "RSVPAD":
                    self.comboButtonStrings = ["OSCR3"]
                case "DS4TOUCH":
                    self.comboButtonStrings = ["DS4TCHBTN"]
                default: break
                }
            }
            else {print("无法从 keyString 提取 comboKeyStrings")}
        }
        else {
            self.widgetType = WidgetTypeEnum.button // legacy combo button connected by "+"
        }
        
        
        print("widgetType: \(self.widgetType)")
        print("touchPadString: \(self.touchPadString)")
        for comboButtonString in comboButtonStrings {
            print("comboButtonString: \(comboButtonString)")
        }
        
        self.widgetLabel = buttonLabel
        self.shape = shape
        self.label = UILabel()
        // self.originalBackgroundColor = UIColor(white: 0.2, alpha: 0.7)
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
        self.capturedTouches = NSMutableSet()
        self.pointerIdDict = [:]
        self.pointerIdPool = []
        for i in 0...10 { // iPadOS supports up to 11 finger touches
            self.pointerIdPool.insert(UInt32(i))
        }
        self.activePointerIds = []
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
    
    // ======================================================================================================
    @objc public func setupAutoTapTimer() {
        if self.widgetType == WidgetTypeEnum.button {
            self.autoTapTimer = SafeTimer(interval:0.001 * Double(autoTapInterval)) {
                self.handleButtonDown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                    self.handleButtonUp()
                }
            }
        }
    }
    
    @objc public func setVibration(style: Int) {
        if #available(iOS 13.0, *) {
            vibrationOn = style < UIImpactFeedbackGenerator.FeedbackStyle.rigid.rawValue + 1
        } else {
            vibrationOn = style < UIImpactFeedbackGenerator.FeedbackStyle.heavy.rawValue + 1
        };
        vibrationStyle = style;
        if #available(iOS 13.0, *) {
            print("rigid value \(UIImpactFeedbackGenerator.FeedbackStyle.rigid.rawValue)")
        } else {
            // Fallback on earlier versions
        };
        if vibrationOn {
            vibrationGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle(rawValue: style) ?? UIImpactFeedbackGenerator.FeedbackStyle.light)
        }
    }
    
    @objc public func setLocation(position: CGPoint) {
        /*
         NSLayoutConstraint.activate([
         self.centerXAnchor.constraint(equalTo: self.superview!.leadingAnchor, constant: xOffset),
         self.centerYAnchor.constraint(equalTo: self.superview!.topAnchor, constant: yOffset),
         ])
         */
        storedCenter = position
        center = storedCenter
        initialCenter = storedCenter;
        layoutChanges.append(initialCenter)
    }
    
    @objc public func enableRelocationMode(enabled: Bool){
        OnScreenWidgetView.editMode = enabled
    }
    
    @objc public func undoRelocation(){
        guard layoutChanges.count>1 else {return}
        UIView.animate(withDuration: 0.2) {
            self.center = self.layoutChanges[self.layoutChanges.count-2]
        }
        storedCenter = center
        layoutChanges.removeLast()
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
        if widgetType == WidgetTypeEnum.touchPad {
            minimumBorderAlpha = 0.0
        }
        if borderAlpha < minimumBorderAlpha {
            borderAlpha = minimumBorderAlpha
        }
        defaultBorderColor = UIColor(white: 0.2, alpha: borderAlpha).cgColor
        self.layer.borderColor = defaultBorderColor
        
        if widgetType == WidgetTypeEnum.touchPad {
            self.backgroundColor = UIColor.clear // make touchPad transparent
            self.layer.borderColor = UIColor(white: 0.2, alpha: borderAlpha - 0.15).cgColor // reduced border alpha for touchPad
        }
    }
    
    func nearestEven(_ value: CGFloat) -> CGFloat {
        let rounded = round(value)
        if Int(rounded) % 2 == 0 {
            return rounded
        } else {
            let lowerEven = rounded - 1
            let upperEven = rounded + 1
            return abs(value - lowerEven) <= abs(value - upperEven) ? lowerEven : upperEven
        }
    }
    
    // 仅在加载控件时调用
    private func denormalizeSize(sizeFactor:CGFloat) -> CGFloat {
        let longSideLen = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let shortSideLen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        
        var referenceLen = UIScreen.main.bounds.width
        if(self.sizeReference == WidgetSizeReference.longSide.rawValue) {referenceLen = longSideLen}
        if(self.sizeReference == WidgetSizeReference.shortSide.rawValue) {referenceLen = shortSideLen}
        
        // return CGFloat(Int(sizeFactor/10000*screenWidthInPoints/2)*2);
        // print("referenceLen \(referenceLen), \(CACurrentMediaTime())")
        return nearestEven(sizeFactor/10000*referenceLen);
    }

    private func changeAndActivateContraints(){
        let isNormalizedSizeFactor = self.widthFactor > 6;
        let isNormalizedHeightFactor = self.heightFactor > 6;
        
        let longSideLen = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let shortSideLen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        
        let baselineDiameter:CGFloat = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 60 : 60*shortSideLen/longSideLen
        print("baselineDiameter \(baselineDiameter), \(CACurrentMediaTime())")
        
        let baselineWidth:CGFloat = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 70 : 70*shortSideLen/longSideLen
        let baselineHeight:CGFloat = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 65 : 65*shortSideLen/longSideLen
        let baselineWidthLargeSquare:CGFloat = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 170 : 170*shortSideLen/longSideLen
        let baselineHeightLargeSquare:CGFloat = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 150 : 150*shortSideLen/longSideLen

        if self.shape == "round"{ // we'll make custom osc buttons round & smaller
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor) : CGFloat(Int(baselineDiameter * self.widthFactor / 2) * 2)),
                self.heightAnchor.constraint(equalToConstant: isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor) : CGFloat(Int(baselineDiameter * self.widthFactor / 2) * 2)),])
            // 实时调整大小时isNormalized 为 false。加载数据时 isNormalized 为 true
            // baselineDiameter 仅在 实时调整大小时生效，从存储恢复时总是会恢复denormalizeSize()尺寸
            self.deNormalizedWidthFactor = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor)/baselineDiameter : self.widthFactor;
            self.deNormalizedHeightFactor = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor)/baselineDiameter : self.widthFactor;
            //此处的 deNormalized 用于slider显示值
        }
        if self.shape == "square" {
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor) :  CGFloat(Int(baselineWidth * self.widthFactor / 2) * 2)),
                self.heightAnchor.constraint(equalToConstant: isNormalizedHeightFactor ? denormalizeSize(sizeFactor:self.heightFactor) :  CGFloat(Int(baselineHeight * self.heightFactor / 2) * 2)),])
            self.deNormalizedWidthFactor = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor)/baselineWidth : self.widthFactor;
            self.deNormalizedHeightFactor = isNormalizedHeightFactor ? denormalizeSize(sizeFactor:self.heightFactor)/baselineHeight : self.heightFactor;
        }
        if self.shape == "largeSquare" { // override all shape strings
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant:isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor) :  CGFloat(Int(baselineWidthLargeSquare * self.widthFactor / 2) * 2)),
                self.heightAnchor.constraint(equalToConstant:isNormalizedHeightFactor ? denormalizeSize(sizeFactor:self.heightFactor) :  CGFloat(Int(baselineHeightLargeSquare * self.heightFactor / 2) * 2)),])
            self.deNormalizedWidthFactor = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor)/baselineWidthLargeSquare : self.widthFactor;
            self.deNormalizedHeightFactor = isNormalizedHeightFactor ? denormalizeSize(sizeFactor:self.heightFactor)/150 : self.heightFactor;
        }
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 10), // set up label size contrain within UIView
            label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -10),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),])
        
        if self.shape != "round"{
            let shortSideLen = min(self.layer.bounds.size.width, self.layer.bounds.size.height)
            self.layer.cornerRadius = shortSideLen/2 < 16 ? shortSideLen/3.2 : 16
        }
    }
    
    private func setupView() {
        label.text = self.widgetLabel
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
        
        if self.shape == "default" || self.shape.isEmpty {
            if CommandManager.oscButtonMappings.keys.contains(self.buttonString) && !CommandManager.oscRectangleButtonCmds.contains(self.buttonString){ //make oscButtons round
                self.shape = "round"
            }
            else {
                self.shape = "square"
            }
        }
        
        if self.widgetType == WidgetTypeEnum.touchPad {
            self.shape = "largeSquare" // override shape from user input
            if(self.borderWidth < 1) {self.layer.borderWidth = 1}
            else {self.layer.borderWidth = self.borderWidth}
            if OnScreenWidgetView.editMode { //display label in edit mode to make the pad more visible
                label.text = self.widgetLabel
            }
            else{
                label.isHidden = self.widgetLabel.uppercased() == self.touchPadString // allow touchPad label to be display if it's different from touchPad cmdString
            }
        }
        
        if CommandManager.specialOverlayButtonCmds.contains(self.cmdString){
            self.layer.borderWidth = 0
        }
        
        if self.shape == "round" {
            //setup round buttons
            self.layer.cornerRadius = self.frame.width/2
            // self.layer.borderWidth = self.borderWidth
            label.minimumScaleFactor = 0.15  // Adjust the scale factor for oscButtons
            label.font = UIFont.boldSystemFont(ofSize: 22)
        }
        if self.shape == "square" || self.shape == "largeSquare" {
            //just do nothing here
        }
        
        
        // self.layer.shadowColor = UIColor.clear.cgColor
        // self.layer.shadowRadius = 8
        // self.layer.shadowOpacity = 0.5
        
        addSubview(label)
        
        if(OnScreenWidgetView.editMode) {self.changeAndActivateContraints()}
        
        center = storedCenter //anchor the center while resizing self
        
        setupButtonDownVisualEffectLayer();
        if CommandManager.directionPads.contains(touchPadString) {setupLrudDirectionIndicatorlayers()}
        if CommandManager.stickTouchPads.contains(touchPadString) {self.l3r3Indicator = createl3r3Indicator()}
        if self.hasStickIndicator {
            if self.crossMarkLayer.superlayer == nil {self.crossMarkLayer = createCrossMark()}
            if self.stickBallLayer.superlayer == nil {self.stickBallLayer = createStickBall()}
        }
    }
    
    private func createl3r3Indicator() -> CAShapeLayer{
        let indicatorFrame = CAShapeLayer();
        let indicatorBorder = CAShapeLayer();
        
        indicatorFrame.frame = CGRectMake(0, 0, 75, 75)
        indicatorFrame.cornerRadius = 9
        indicatorBorder.borderWidth = 7
        indicatorBorder.frame = indicatorFrame.bounds.insetBy(dx: -indicatorBorder.borderWidth, dy: -indicatorBorder.borderWidth) // Adjust the inset as needed
        indicatorBorder.borderColor = UIColor.clear.cgColor
        
        indicatorBorder.cornerRadius = indicatorFrame.cornerRadius + indicatorBorder.borderWidth
        indicatorBorder.backgroundColor = UIColor.clear.cgColor
        indicatorBorder.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: indicatorBorder.bounds, cornerRadius: indicatorBorder.cornerRadius)
        indicatorBorder.path = path.cgPath
        indicatorBorder.borderColor = UIColor.clear.cgColor
        
        self.layer.superlayer?.addSublayer(indicatorBorder)
        
        return indicatorBorder
    }
    
    private func showl3r3Indicator(){
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            self.l3r3Indicator.borderColor = voidlinkPurple
            self.l3r3Indicator.position = CGPointMake(CGRectGetMinX(self.frame)+touchBeganLocation.x, CGRectGetMinY(self.frame)+touchBeganLocation.y)
            
            CATransaction.commit()
        }
        
        if vibrationOn {
            vibrationGenerator.prepare()
            vibrationGenerator.impactOccurred()
        }
    }
    
    
    //================================================================================================
    //Indicator overlay for on-screen game controller left or right sticks (non-vector mode)
    
    private func handleStickBallReachingBorder(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stickBallLayer.lineWidth = 0.6
        // stickBallLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        stickBallLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        // stickBallLayer.shadowColor = stickBallLayer.strokeColor
        CATransaction.commit()
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
        
        showStickBall(at: stickMarkerRelativeLocation)
        showCrossMarkOnTouchPoint(at: stickMarkerRelativeLocation)
    }
    
    // cross mark for left & right gamePad
    private func createCrossMark() -> CAShapeLayer {
        let crossLayer = CAShapeLayer()
        
        crossLayer.strokeColor = crossMarkColor
        crossLayer.lineWidth = 1.2
        crossLayer.fillColor = crossMarkColor
        
        self.layer.superlayer?.addSublayer(crossLayer)
        crossLayer.shadowColor = UIColor.black.cgColor
        crossLayer.shadowOffset = CGSize(width: 1, height: 1)
        crossLayer.shadowRadius = 0;
        crossLayer.shadowOpacity = 0.8
        
        crossLayer.isHidden = true
        
        return crossLayer
    }
    
    private func showCrossMarkOnTouchPoint(at point: CGPoint) {
        let path = UIBezierPath()
        let crossSize = 26.0
        
        path.move(to: CGPoint(x: point.x - crossSize / 2, y: point.y))
        path.addLine(to: CGPoint(x: point.x + crossSize / 2, y: point.y))
        
        // 竖线
        path.move(to: CGPoint(x: point.x, y: point.y - crossSize / 2))
        path.addLine(to: CGPoint(x: point.x, y: point.y + crossSize / 2))
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        self.crossMarkLayer.path = path.cgPath
        self.crossMarkLayer.position = CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame))
        self.crossMarkLayer.isHidden = false
        
        CATransaction.commit()
    }
    
    
    private func createStickBall() -> CAShapeLayer {
        // Create a CAShapeLayer
        let stickBallLayer = CAShapeLayer()
        self.layer.superlayer?.addSublayer(stickBallLayer)
        
        // Set the stroke color and width (border of the circle)
        stickBallLayer.strokeColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1.0).cgColor
        //stickBallLayer.
        stickBallLayer.lineWidth = 0
        stickBallLayer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        stickBallLayer.shadowRadius = 0;
        stickBallLayer.shadowOpacity = 0.8
        
        // Set the fill color (inside of the circle)
        stickBallLayer.fillColor = stickBallColor  // Light fill with some transparency
        
        stickBallLayer.isHidden = true
        
        return stickBallLayer
    }
    
    private func showStickBall(at center: CGPoint) {
        let path = UIBezierPath(arcCenter: center, radius: 8, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Create a CAShapeLayer
        self.stickBallLayer.path = path.cgPath  // Assign the circular path to the shape layer
        self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame))
        self.stickBallLayer.isHidden = false
        
        CATransaction.commit()
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
            self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame)-stickIndicatorOffset)
        }
        CATransaction.commit()
    }
    
    private func resetStickBallPositionAndHideIndicator(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handleStickBallLeavingBorder()
        CATransaction.commit()
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame))
        CATransaction.setCompletionBlock {
            // 动画结束后执行的代码
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !self.touchBegan {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.crossMarkLayer.isHidden = true
                    self.stickBallLayer.isHidden = true
                    CATransaction.commit()
                }
            }
        }
        CATransaction.commit()
    }
    
    //================================================================================================
    
    
    
    //=====LRUD(left right up & down buttons) touchPad touch =========================================
    
    private func showLrudBall(at point: CGPoint) {
        // Create a circular path using UIBezierPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let path = UIBezierPath(arcCenter: point, radius: 10, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        // Create a CAShapeLayer
        lrudIndicatorBall.path = path.cgPath  // Assign the circular path to the shape layer
        
        lrudIndicatorBall.position = CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame))
        lrudIndicatorBall.isHidden = false;
        
        CATransaction.commit()
    }
    
    private func createLrudBall() -> CAShapeLayer {
        // Create a circular path using UIBezierPath
        let path = UIBezierPath(arcCenter: CGPoint(x: 0, y: 0), radius: 10, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        // Create a CAShapeLayer
        let ballLayer = CAShapeLayer()
        ballLayer.path = path.cgPath  // Assign the circular path to the shape layer
        self.layer.superlayer?.addSublayer(ballLayer)
        
        // Set the stroke color and width (border of the circle)
        ballLayer.strokeColor = stickBallColor
        ballLayer.lineWidth = 0
        ballLayer.shadowOffset = CGSize(width: 0.5, height: 0.5)
        ballLayer.shadowRadius = 0;
        ballLayer.shadowOpacity = 0.8
        ballLayer.name = "lrudBall"
        ballLayer.isHidden = true
        
        // Set the fill color (inside of the circle)
        ballLayer.fillColor = stickBallColor  // Light fill with some transparency
        return ballLayer
    }
    
    private func createLrudDirectionLayer() -> CAShapeLayer {
        let indicatorFrame = CAShapeLayer();
        let indicatorBorder = CAShapeLayer();
        
        indicatorFrame.frame = CGRectMake(0, 0, 75, 75)
        indicatorFrame.cornerRadius = 9
        indicatorBorder.borderWidth = 6
        indicatorBorder.frame = indicatorFrame.bounds.insetBy(dx: -indicatorBorder.borderWidth, dy: -indicatorBorder.borderWidth) // Adjust the inset as needed
        indicatorBorder.borderColor = UIColor.clear.cgColor
        
        indicatorBorder.cornerRadius = indicatorFrame.cornerRadius + indicatorBorder.borderWidth
        indicatorBorder.backgroundColor = UIColor.clear.cgColor
        indicatorBorder.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: indicatorBorder.bounds, cornerRadius: indicatorBorder.cornerRadius)
        indicatorBorder.path = path.cgPath
        indicatorBorder.borderColor = voidlinkPurple
        
        return indicatorBorder
    }
    
    private func showLrudDirectionIndicator(with indicatorLayer:CAShapeLayer){
        // Add the border layer below the super layer
        indicatorLayer.borderColor = voidlinkPurple
        
        // show the indicator based on the touchBeganLocation
        indicatorLayer.position = CGPointMake(CGRectGetMinX(self.frame)+touchBeganLocation.x, CGRectGetMinY(self.frame)+touchBeganLocation.y)
        
        if vibrationOn {
            vibrationGenerator.prepare()
            vibrationGenerator.impactOccurred()
        }
    }
    
    private func handleLrudTouchMove(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let radians  = atan2(-offSetY,offSetX)
        let degrees = radians * 180 / .pi
        let nearZeroPoint = abs(offSetX) < 16/sensitivityFactorX && abs(offSetY) < 16/sensitivityFactorY
        // NSLog("deltaX: %f, detalY: %f", deltaX, deltaY)
        
        
        var pressedButtonMask = 0;
        if abs(degrees) < triggeringAngle {
            // NSLog("button pressed: right")
            pressedButtonMask = pressedButtonMask | Direction.right.rawValue
        }
        if 180.0 - abs(degrees) < triggeringAngle {
            // NSLog("button pressed: left")
            pressedButtonMask = pressedButtonMask | Direction.left.rawValue
        }
        if abs(90.0 - degrees) < triggeringAngle {
            // NSLog("button pressed: up")
            pressedButtonMask = pressedButtonMask | Direction.up.rawValue
        }
        if abs(-90.0 - degrees) < triggeringAngle {
            // NSLog("button pressed: down")
            pressedButtonMask = pressedButtonMask | Direction.down.rawValue
        }
        if nearZeroPoint {pressedButtonMask = 0}
        
        if pressedButtonMask != previousButtonMask {
            if(pressedButtonMask & Direction.up.rawValue == Direction.up.rawValue) {
                showLrudDirectionIndicator(with: upIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls.pressDownControllerButton(UP_FLAG)
                default: break
                }
            }
            else{
                //self.upIndicator.removeFromSuperlayer()
                self.upIndicator.borderColor = UIColor.clear.cgColor
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls.releaseControllerButton(UP_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.down.rawValue == Direction.down.rawValue){
                showLrudDirectionIndicator(with: downIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls.pressDownControllerButton(DOWN_FLAG)
                default: break
                }
            }
            else{
                // self.downIndicator.removeFromSuperlayer()
                self.downIndicator.borderColor = UIColor.clear.cgColor
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls.releaseControllerButton(DOWN_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.left.rawValue == Direction.left.rawValue){
                showLrudDirectionIndicator(with: leftIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls.pressDownControllerButton(LEFT_FLAG)
                default: break
                }
            }
            else{
                // self.leftIndicator.removeFromSuperlayer()
                self.leftIndicator.borderColor = UIColor.clear.cgColor
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls.releaseControllerButton(LEFT_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.right.rawValue == Direction.right.rawValue){
                showLrudDirectionIndicator(with: rightIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls.pressDownControllerButton(RIGHT_FLAG)
                default: break
                }
            }
            else{
                // self.rightIndicator.removeFromSuperlayer()
                self.rightIndicator.borderColor = UIColor.clear.cgColor
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls.releaseControllerButton(RIGHT_FLAG)
                default: break
                }
            }
        }
        
        previousButtonMask = pressedButtonMask
        
        CATransaction.commit()
    }
    //================================================================================================
    
    
    //===== MOUSEPAD related methods=============================================================
    private func sendLongMouseLeftButtonClickEvent() {
        DispatchQueue.global(qos: .userInteractive).async {
            // Logging the press event
            NSLog("Sending left mouse button press")
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)
            
            // Wait 200 ms to simulate a real button press
            DispatchQueue.global().asyncAfter(deadline: .now() + self.QUICK_TAP_TIME_INTERVAL) {
                // If quick tap is not detected, release the button
                if !self.quickDoubleTapDetected {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
                    // NSLog("double click: first long click release")
                }
                else{NSLog("Left mouse button release cancelled, keep pressing down, turning into dragging...")}
                // Don't release the button if we're still dragging, this will prevent the dragging from being interrupted.
            }
        }
    }
    
    private func sendShortMouseLeftButtonClickEvent() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
            }
        }
    }
    
    private func sendMouseRightButtonClickEvent() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_RIGHT)
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
            }
        }
    }
    
    //mousepad-trackball behavior========================================================
    private func startTrackballMomentum() {
        stopTrackballMomentum()
        
        trackballDecelerationTimer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
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
    
    
    //==== Button actions =============================================
    
    //==== Button widget tap down=============================================
    private func handleTapDownOrSlidein() {
        if autoTapInterval < 50 {
            handleButtonDown()
        }
        else{
            self.autoTapTimer?.restart()
        }
    }
    
    private func handleFingerUpOrSlideout() {
        if autoTapInterval < 50 {
            handleButtonUp()
        }
        else{
            self.autoTapTimer?.suspend()
            self.handleButtonUp()
        }
    }
    
    private func handleButtonDown() {
        if !OnScreenWidgetView.editMode {self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // self.layer.borderWidth = 0
            buttonDownVisualEffectLayer.position = CGPointMake(CGRectGetMidX(self.frame), CGRectGetMidY(self.frame)) // update position every time we press down the button
            buttonDownVisualEffectLayer.borderWidth = self.buttonDownVisualEffectWidth // this will show the visual effect
            buttonDownVisualEffectLayer.borderColor = voidlinkPurple
            CATransaction.commit()
        }
        if vibrationOn {
            vibrationGenerator.prepare()
            vibrationGenerator.impactOccurred()
            // print("vibrationInstance: \(vibrationGenerator)")
        }
    }
    
    private func handleButtonUp() {
        if !OnScreenWidgetView.editMode {self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)}
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            // self.layer.borderWidth = 1
            buttonDownVisualEffectLayer.borderWidth = 0
            buttonDownVisualEffectLayer.borderColor = defaultBorderColor
            CATransaction.commit()
        }
    }
    
    private func setupLrudDirectionIndicatorlayers() {
        self.layer.superlayer?.insertSublayer(leftIndicator, below: self.layer);
        self.layer.superlayer?.insertSublayer(rightIndicator, below: self.layer);
        self.layer.superlayer?.insertSublayer(upIndicator, below: self.layer);
        self.layer.superlayer?.insertSublayer(downIndicator, below: self.layer);
        leftIndicator.borderColor = UIColor.clear.cgColor
        rightIndicator.borderColor = UIColor.clear.cgColor
        upIndicator.borderColor = UIColor.clear.cgColor
        downIndicator.borderColor = UIColor.clear.cgColor
        self.lrudIndicatorBall = self.createLrudBall()
    }
    
    private func setupButtonDownVisualEffectLayer() {
        self.buttonDownVisualEffectWidth = 8
        if self.shape == "round" {
            if deNormalizedWidthFactor < 1.3 {self.buttonDownVisualEffectWidth = 15.3} // wider visual effect for osc buttons
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
        var target = stickMaxOffset * input / stickInputScale
        if target > stickMaxOffset {target = stickMaxOffset}
        if target < -stickMaxOffset {target = -stickMaxOffset}
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
        var targetX = self.touchInputToStickInput(input: inputX)
        var targetY = -self.touchInputToStickInput(input: inputY)
        // vertical input must be inverted
        targetX = (targetX >= 0 ? 1.0 : -1.0) * self.minStickOffset + (self.stickMaxOffset - self.minStickOffset) * (targetX/self.stickMaxOffset)
        targetY = (targetY >= 0 ? 1.0 : -1.0) * self.minStickOffset + (self.stickMaxOffset - self.minStickOffset) * (targetY/self.stickMaxOffset)
        self.onScreenControls.sendRightStickTouchPadEvent(targetX, targetY)
    }
    
    private func sendLeftStickTouchPadEvent(inputX: CGFloat, inputY: CGFloat){
        var targetX = self.touchInputToStickInput(input: inputX)
        var targetY = -self.touchInputToStickInput(input: inputY)
        targetX = (targetX >= 0 ? 1.0 : -1.0) * self.minStickOffset + (self.stickMaxOffset - self.minStickOffset) * (targetX/self.stickMaxOffset)
        targetY = (targetY >= 0 ? 1.0 : -1.0) * self.minStickOffset + (self.stickMaxOffset - self.minStickOffset) * (targetY/self.stickMaxOffset)
        self.onScreenControls.sendLeftStickTouchPadEvent(targetX, targetY)
    }
    //==========================================================================================================
    
    private func sendOscButtonDownEvent(oscString: String){
        let buttonFlag = CommandManager.oscButtonMappings[oscString]
        if buttonFlag != 0 {self.onScreenControls.pressDownControllerButton(buttonFlag!)}
        else {switch oscString {
        case "OSCL2", "L2", "LT":
            self.onScreenControls.updateLeftTrigger(0xFF)
        case "OSCR2", "R2", "RT":
            self.onScreenControls.updateRightTrigger(0xFF)
        default:break
        }}
    }
    
    private func sendOscButtonUpEvent(oscString: String){
        let buttonFlag = CommandManager.oscButtonMappings[oscString]
        if buttonFlag != 0 {self.onScreenControls.releaseControllerButton(buttonFlag!)}
        else {switch oscString {
        case "OSCL2", "L2", "LT":
            self.onScreenControls.updateLeftTrigger(0x00)
        case "OSCR2", "R2", "RT":
            self.onScreenControls.updateRightTrigger(0x00)
        default:break
        }}
    }
    
    //==============================================================================
    private func sendComboButtonsDownEvent(comboStrings: [String]) {
        DispatchQueue.global(qos: .userInteractive).async {
            for comboString in comboStrings {
                if CommandManager.oscButtonMappings.keys.contains(comboString) {
                    self.sendOscButtonDownEvent(oscString: comboString)
                }
                if CommandManager.keyboardButtonMappings.keys.contains(comboString) {
                    LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[comboString]!,Int8(KEY_ACTION_DOWN), 0)
                }
                if CommandManager.mouseButtonMappings.keys.contains(comboString) {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), Int32(CommandManager.mouseButtonMappings[comboString]!))
                }
                if comboString != comboStrings.last {
                    usleep(self.comboKeyTimeIntervalMs*1000) // delay xxx ms
                }
            }
        }
    }
    
    private func sendComboButtonsUpEvent(comboStrings: [String]) {
        DispatchQueue.global(qos: .userInteractive).async {
            for comboString in comboStrings {
                if CommandManager.oscButtonMappings.keys.contains(comboString) {
                    self.sendOscButtonUpEvent(oscString: comboString)
                }
                if CommandManager.keyboardButtonMappings.keys.contains(comboString) {
                    LiSendKeyboardEvent(CommandManager.keyboardButtonMappings[comboString]!,Int8(KEY_ACTION_UP), 0)
                }
                if CommandManager.mouseButtonMappings.keys.contains(comboString) {
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), Int32(CommandManager.mouseButtonMappings[comboString]!))
                }
                if comboString != comboStrings.last {
                    usleep(self.comboKeyTimeIntervalMs*1000) // delay xxx ms
                }
            }
        }
    }
    
    //==============================================================================
    // Touch event handling
    
    private func getAllSpawnedTouchesCount(with event: UIEvent?)->Int{
        return event?.allTouches?.filter({ $0.view == self }).count ?? 0
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchBegan = true
        self.firstTouchMoved = false
        super.touchesBegan(touches, with: event)
        self.isMultipleTouchEnabled = self.widgetType == WidgetTypeEnum.button || self.touchPadString == "MOUSEPAD";

        if !OnScreenWidgetView.editMode && self.touchPadString == "TRACKBALL" {
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
                
        let allSpawnedTouchesCount = self.getAllSpawnedTouchesCount(with: event) // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        if allSpawnedTouchesCount == 2 {
            self.twoTouchesDetected = true
        }
        
        self.pressed = true

        if !OnScreenWidgetView.editMode {
            if self.widgetType == WidgetTypeEnum.touchPad && touches.count == 1{ // don't use event?.allTouches?.count here, it will counts all touches including the ones captured by other UIViews
                switch self.touchPadString {
                case "LSPAD":
                    self.showStickIndicator()
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "RSPAD":
                    self.showStickIndicator()
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "LSVPAD":
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "RSVPAD":
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "DPAD", "WASDPAD", "ARROWPAD", "MOUSEWHEEL", "WHEEL":
                    if allSpawnedTouchesCount == 1 {showLrudBall(at: touchBeganLocation)}
                    if quickDoubleTapDetected {
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)
                        DispatchQueue.global(qos: .userInteractive).async {
                            usleep(100000)
                            self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)
                        }
                    }
                case "DS4TOUCH":
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)
                    }
                default:
                    break
                }
                
                if self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "MOUSEPAD" && allSpawnedTouchesCount == 1 && !twoTouchesDetected {
                    switch mouseButtonAction{
                    case .leftButtonDown:
                        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)
                    case .middleButtonDown:
                        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_MIDDLE)
                    case .rightButtonDown:
                        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_RIGHT)
                    case .hovering,.noClick:
                        break
                    default:
                        break
                    }
                }
            }
            
            if self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "DS4TOUCH" {
                self.handleControllerTouchesDown(touches: touches)
            }
                        
            // this will also deal with button events
            if self.widgetType == WidgetTypeEnum.button && !self.comboButtonStrings.isEmpty {
                self.handleTapDownOrSlidein()
                setLock.lock()
                self.capturedTouches.union(touches)
                setLock.unlock()
                //self.handleButtonSliding(touches: touches)
            }
            
            // legacy keyboard button combo connected by "+"
            if self.cmdString.contains("+") && !self.cmdString.contains("-"){
                let keyboardCmdStrings = CommandManager.shared.extractKeyStringsFromComboCommand(from: self.cmdString)!
                CommandManager.shared.sendKeyComboCommand(keyboardCmdStrings: keyboardCmdStrings) // send multi-key command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { // reset shadow color immediately 50ms later
                    self.handleButtonUp()
                }
            }
        }
        // here is in edit mode:
        else{
            self.handleButtonDown()
            NotificationCenter.default.post(name: Notification.Name("OnScreenWidgetViewSelected"),object: self) // inform layout tool controller to fetch button size factors. self will be passed as the object of the notification
        }
    }
    
    private func moveByTouch(touch: UITouch){
        let currentLocation: CGPoint
        if OnScreenWidgetView.editMode {currentLocation = touch.location(in: superview)}
        else {currentLocation = touch.location(in: self)}
        
        if !firstTouchMoved {
            // First move event
            self.latestTouchLocation = currentLocation
            self.firstTouchMoved = true
        }
                
        let offsetX = currentLocation.x - latestTouchLocation.x;
        let offsetY = currentLocation.y - latestTouchLocation.y;
        
        let outOfBoundsX = center.x+offsetX >= (self.superview?.bounds.width)! || center.x+offsetX < 0
        let outOfBoundsY = center.y+offsetY >= (self.superview?.bounds.height)! || center.y+offsetY < 0

        center = CGPoint(x: outOfBoundsX ? center.x : center.x+offsetX, y: outOfBoundsY ? center.y : center.y+offsetY)
        
        latestTouchLocation = currentLocation
        // center = currentLocation;
        //NSLog("x coord: %f, y coord: %f", self.frame.origin.x, self.frame.origin.y)
        if OnScreenWidgetView.editMode {
            guidelineDelegate?.updateGuidelinesForOnScreenWidget(self)
        }
    }
    
    private func handleControllerTouchesDown(touches: Set<UITouch>) {
        for touch in touches{
            let availablePointerIds = pointerIdPool.subtracting(activePointerIds)
            if let pointerId = availablePointerIds.first {
                pointerIdDict[ObjectIdentifier(touch)] = pointerId
                let coordX = touch.location(in: self).x/self.bounds.width
                let coordY = touch.location(in: self).y/self.bounds.height
                LiSendControllerTouchEvent(0, UInt8(LI_TOUCH_EVENT_DOWN), pointerId, Float(coordX), Float(coordY), 1)
                activePointerIds.insert(pointerId)
            }
        }
    }
    
    private func handleControllerTouchesMove(touches: Set<UITouch>) {
        for touch in touches{
            if let pointerId = pointerIdDict[ObjectIdentifier(touch)] {
                let coordX = touch.location(in: self).x/self.bounds.width
                let coordY = touch.location(in: self).y/self.bounds.height
                LiSendControllerTouchEvent(0, UInt8(LI_TOUCH_EVENT_MOVE), pointerId, Float(coordX), Float(coordY), 1)
            }
        }
    }

    private func handleControllerTouchesUp(touches: Set<UITouch>) {
        for touch in touches{
            if let pointerId = pointerIdDict[ObjectIdentifier(touch)] {
                let coordX = touch.location(in: self).x/self.bounds.width
                let coordY = touch.location(in: self).y/self.bounds.height
                LiSendControllerTouchEvent(0, UInt8(LI_TOUCH_EVENT_UP), pointerId, Float(coordX), Float(coordY), 1)
                activePointerIds.remove(pointerId)
                pointerIdDict.removeValue(forKey: ObjectIdentifier(touch))
            }
        }
    }

    
    private func handleFingerUpAfterSliding(touches: Set<UITouch>) {
        for touch in touches {
            for subview in self.superview?.subviews ?? [] {
                if let widget = subview as? OnScreenWidgetView{
                    setLock.lock()
                    let captured = widget.capturedTouches.contains(touch)
                    setLock.unlock()
                    if !captured || widget.slideMode == ButtonSlideMode.disabled.rawValue {continue}
                    widget.handleFingerUpOrSlideout()
                    setLock.lock()
                    widget.capturedTouches.remove(touch)
                    setLock.unlock()
                }
            }
        }
    }

    private func handleButtonSliding(touches: Set<UITouch>) {
        for touch in touches {
            let locationInSuperView = touch.location(in: self.superview)
            for subview in self.superview?.subviews ?? [] {
                if let widget = subview as? OnScreenWidgetView{
                    if widget.widgetType != WidgetTypeEnum.button {continue}
                    let pointInSubview = widget.convert(locationInSuperView, from: self.superview)
                    if widget.bounds.contains(pointInSubview){
                        setLock.lock()
                        let captured = widget.capturedTouches.contains(touch)
                        setLock.unlock()
                        if captured || widget.slideMode == ButtonSlideMode.disabled.rawValue {continue}
                        setLock.lock()
                        widget.capturedTouches.add(touch)
                        setLock.unlock()
                        widget.handleTapDownOrSlidein()
                        // print("UIButton: \(widget.buttonLabel) in, \(widget.touchPadString), \(CACurrentMediaTime())")
                    }
                    else{
                        setLock.lock()
                        let captured = widget.capturedTouches.contains(touch)
                        setLock.unlock()
                        if !captured || widget.slideMode == ButtonSlideMode.disabled.rawValue {continue}
                        // print("UIButton: \(widget.buttonLabel) out test, \(widget.touchPadString), \(CACurrentMediaTime())")
                        if(widget.slideMode == ButtonSlideMode.toggle.rawValue){
                            widget.handleFingerUpOrSlideout()
                            setLock.lock()
                            widget.capturedTouches.remove(touch)
                            setLock.unlock()
                        }
                        if(widget.slideMode == ButtonSlideMode.slideAndHold.rawValue){
                            // do nothing here
                        }
                    }
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if !OnScreenWidgetView.editMode {
            
            if !self.touchPadString.isEmpty{
                handleTouchPadMoveEvent(touches, with: event)
            }
            
            if self.widgetType == WidgetTypeEnum.button {
                if self.slideMode != ButtonSlideMode.disabled.rawValue {self.handleButtonSliding(touches: touches)}
            }
            
            if CommandManager.specialOverlayButtonCmds.contains(self.cmdString){
                if let touch = touches.first {
                    NSLog("touchTapTimeStamp %f", self.touchTapTimeStamp)
                    if CACurrentMediaTime() - self.touchTapTimeStamp > 0.3 { // temporarily relocate special buttons
                        self.moveByTouch(touch: touch)
                        self.handleButtonUp()
                    }
                }
            }
        }
        
        // Move the widgetView based on touch movement in relocation mode
        if OnScreenWidgetView.editMode {
            if let touch = touches.first {
                self.moveByTouch(touch: touch)
                }
            self.stickBallLayer.removeFromSuperlayer()
            self.crossMarkLayer.removeFromSuperlayer()
        }
    }
    
    private func updateTouchLocation (touch: UITouch) {
        self.mousePointerMoved = true
        let currentTouchLocation: CGPoint = (touch.location(in: self))
        
        if !firstTouchMoved {
            // First move event
            self.latestTouchLocation = currentTouchLocation
            self.firstTouchMoved = true
        }
        
        self.deltaX = currentTouchLocation.x - self.latestTouchLocation.x
        self.deltaY = currentTouchLocation.y - self.latestTouchLocation.y
        self.offSetX = currentTouchLocation.x - self.touchBeganLocation.x
        self.offSetY = currentTouchLocation.y - self.touchBeganLocation.y
        self.latestTouchLocation = currentTouchLocation
    }
    
    private func handleTouchPadMoveEvent (_ touches: Set<UITouch>, with event: UIEvent?){
        if touches.count == 1{ // don't use event.alltouches.count here, it will counts all touches
            switch self.touchPadString{
            case "MOUSEPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    if self.getAllSpawnedTouchesCount(with: event) == 1 {
                        self.updateTouchLocation(touch: touches.first!)
                        LiSendMouseMoveEvent(Int16(truncatingIfNeeded: Int(self.deltaX * 1.7 * self.sensitivityFactorX)), Int16(truncatingIfNeeded: Int(self.deltaY * 1.7 * self.sensitivityFactorY)))
                    }
                }
                break
            case "TRACKBALL":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.updateTouchLocation(touch: touches.first!)
                    LiSendMouseMoveEvent(Int16(truncatingIfNeeded: Int(self.deltaX * 1.7 * self.sensitivityFactorX)), Int16(truncatingIfNeeded: Int(self.deltaY * 1.7 * self.sensitivityFactorY)))
                    self.trackballVelocity = CGPoint(x: self.deltaX * 1.7 * self.sensitivityFactorX, y: self.deltaY * 1.7 * self.sensitivityFactorY)
                    self.stopTrackballMomentum()
                }
                break
            case "LSPAD":
                self.updateTouchLocation(touch: touches.first!)
                DispatchQueue.global(qos: .userInteractive).async {
                    self.sendLeftStickTouchPadEvent(inputX: self.offSetX * self.sensitivityFactorX, inputY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
            case "RSPAD":
                self.updateTouchLocation(touch: touches.first!)
                DispatchQueue.global(qos: .userInteractive).async {
                    self.sendRightStickTouchPadEvent(inputX: self.offSetX * self.sensitivityFactorX, inputY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
            case "LSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.updateTouchLocation(touch: touches.first!)
                    self.sendLeftStickTouchPadEvent(inputX: self.deltaX*1.5167*self.sensitivityFactorX, inputY: self.deltaY*1.5167*self.sensitivityFactorY)
                }
            case "RSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.updateTouchLocation(touch: touches.first!)
                    self.sendRightStickTouchPadEvent(inputX: self.deltaX*1.5167*self.sensitivityFactorX, inputY: self.deltaY*1.5167*self.sensitivityFactorY)
                }
            case "DPAD", "WASDPAD", "ARROWPAD":
                self.updateTouchLocation(touch: touches.first!)
                handleLrudTouchMove()
            case "MOUSEWHEEL","WHEEL":
                self.updateTouchLocation(touch: touches.first!)
                LiSendHighResScrollEvent(Int16(self.deltaY*7.5*self.sensitivityFactorY))
            default:
                break
            }
        }
        if self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "DS4TOUCH" {
            self.handleControllerTouchesMove(touches: touches)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchBegan = false
        super.touchesEnded(touches, with: event)
                
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // for checking stationary touch points

        if self.touchPadString != "MOUSEPAD" {quickDoubleTapDetected = false} //do not reset this flag here in mousePad mode
        
        let allCapturedTouchesCount = event?.allTouches?.filter({ $0.view == self }).count // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        
        
        // deal with pure MOUSPAD first
        if !OnScreenWidgetView.editMode && self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "MOUSEPAD" && allCapturedTouchesCount == 1 && !twoTouchesDetected {
            
                switch mouseButtonAction{
                case .leftButtonDown:
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
                case .middleButtonDown:
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_MIDDLE)
                case .rightButtonDown:
                    LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
                case .hovering:
                    if !mousePointerMoved && !quickDoubleTapDetected {self.sendLongMouseLeftButtonClickEvent()} // deal with single tap(click)
                    if quickDoubleTapDetected { //deal with quick double tap
                        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT) //must release the button anyway, because the button is likely being held down since the long click turned into a dragging event.
                        if !mousePointerMoved {self.sendShortMouseLeftButtonClickEvent()}
                        quickDoubleTapDetected = false
                    }
                    mousePointerMoved = false // reset this flag
                case .noClick:
                    break
                default:
                    break
                }
        }
        
        if !OnScreenWidgetView.editMode && self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "TRACKBALL" && allCapturedTouchesCount == 1 && !twoTouchesDetected {
            if(mousePointerMoved){
                self.startTrackballMomentum()
                mousePointerMoved = false //reset flag
            }
            else{
                self.stopTrackballMomentum()
            }
        }
        
        if !OnScreenWidgetView.editMode && self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "MOUSEPAD" && twoTouchesDetected && touches.count == allCapturedTouchesCount { // need to enable multi-touch first
            // touches.count == allCapturedTouchesCount means allfingers are lifting
            if(self.mouseButtonAction == MouseButtonAction.hovering) {self.sendMouseRightButtonClickEvent()}
            twoTouchesDetected = false
        }
        
        // then other types of pads or buttons with touchPad function
        if !OnScreenWidgetView.editMode && !self.touchPadString.isEmpty {
            switch self.touchPadString{
            case "LSPAD":
                self.onScreenControls.clearLeftStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
            case "RSPAD":
                self.onScreenControls.clearRightStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
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
            case "DS4TOUCH":
                self.handleControllerTouchesUp(touches: touches)
            default:
                break
            }
        }
        
        if CommandManager.stickTouchPads.contains(touchPadString){
            self.l3r3Indicator.borderColor = UIColor.clear.cgColor
        }
        
        if CommandManager.directionPads.contains(touchPadString){
            self.upIndicator.borderColor = UIColor.clear.cgColor
            self.downIndicator.borderColor = UIColor.clear.cgColor
            self.leftIndicator.borderColor = UIColor.clear.cgColor
            self.rightIndicator.borderColor = UIColor.clear.cgColor
            self.lrudIndicatorBall.isHidden = true
        }
                                
        if !OnScreenWidgetView.editMode && !self.cmdString.contains("+") && !self.comboButtonStrings.isEmpty { // if the command(keystring contains "+", it's a legacy multi-key command
            self.handleFingerUpAfterSliding(touches: touches)
            setLock.lock()
            self.capturedTouches.minus(touches)
            setLock.unlock()
        }
        
        if !OnScreenWidgetView.editMode && CommandManager.specialOverlayButtonCmds.contains(self.cmdString){
            if CACurrentMediaTime() - self.touchTapTimeStamp < 0.3 {
                switch self.cmdString {
                case "SETTINGS":
                    NotificationCenter.default.post(name: Notification.Name("SettingsOverlayButtonPressedNotification"), object:nil) // inform layout tool controller to fetch button size factors. self will be passed as the object of the notification
                default:
                    break
                }
            }
        }
        
        CATransaction.commit()
        
        if OnScreenWidgetView.editMode {
            storedCenter = center // Update initial center for next movement
            if center != layoutChanges.last {
                layoutChanges.append(center)
            }

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
            
            if self.widgetType == WidgetTypeEnum.touchPad{
                switch self.touchPadString{
                case "LSPAD", "RSPAD":
                    self.showStickIndicator()
                    self.updateStickIndicator()
                default: break
                }
            }
        }
        
        self.handleFingerUpOrSlideout()
    }
}

