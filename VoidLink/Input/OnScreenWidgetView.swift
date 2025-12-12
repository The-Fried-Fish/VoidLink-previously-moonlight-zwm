//
//  OnScreenKey.swift
//  VoidLink
//
//  Created by True砖家 on 2024/8/4.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

import UIKit

@objc class OnScreenWidgetView: UIView, OscInstanceReceiverDelegate {
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
    
    @objc public var motionHandler: MotionHandler = MotionHandler.shared
    
    @objc public weak var functionalButtonDelegate: OnScreenFunctionalButtonDelegate?
    @objc protocol OnScreenFunctionalButtonDelegate: AnyObject {
        func expandSettingsView()
        func bringUpToolboxMenu()
        func openWidgetLayoutTool()
        func switchWidgetProfile()
        func bringUpSoftKeyboard()
        func alterAbsTouchDragWith(mouseButton:Int32)
    }
    
    @objc enum WidgetTypeEnum: UInt8 {
        case uninitialized
        case button
        case touchPad
    }
    
    private static let MinAutotapInterval:Int = 50
    
    private let oscProfileMan: OSCProfilesManager = OSCProfilesManager.sharedManager(CGRectZero)
    private var oscProfile: OSCProfile
    
    private let dataMan: DataManager = DataManager()
    private let tempSettings: TemporarySettings
    
    @objc public var widgetType: WidgetTypeEnum = WidgetTypeEnum.uninitialized
    
    @objc static public var editMode: Bool = false
    @objc static public var buttonVisualFeedbackEnabled: Bool = true
    @objc public var widgetLabel: String
    @objc public var cmdString: String
    @objc public var identifier: String = ""
    private var buttonString: String = ""
    private var functionalButtonString: String = ""
    public var motionControlButtonString: String = ""
    @objc public var touchPadString: String = ""
    // super combo key string set
    @objc public var comboButtonStrings: [String] = []
    private var comboKeyTimeIntervalMs: UInt32 = 0
    
    @objc public var logicallyDown: Bool = false
    @objc public var widthFactor: CGFloat = 1.0
    @objc public var heightFactor: CGFloat = 1.0
    
    @objc public var buttonMode: Int = 0
    @objc private var tapToToggleFlag: Bool = true
    
    @objc public var sizeReference: Int = WidgetSizeReference.longSide.rawValue
    @objc public var deNormalizedWidthFactor: CGFloat = 1.0
    @objc public var deNormalizedHeightFactor: CGFloat = 1.0
    
    @objc public var borderWidth: CGFloat = 0.0
    @objc public var backgroundAlpha: CGFloat = 0.5
    @objc public var labelAlpha: CGFloat = 0.82
    @objc public var borderAlpha: CGFloat = 0.19
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
    
    private var inertialScroller:InertialScroller
    @objc public var displayLinkRate:CGFloat = 60;
    
    // for movable buttons during streaming
    @objc public var relocatedDuringStreaming: Bool = false

    // for all touchPad or buttons hybrid with touchPads
    @objc public var hasMinStickOffset: Bool = false
    @objc public var hasStickIndicator: Bool = false
    @objc public var hasSensitivityX: Bool = false
    @objc public var sensitivityXMin: CGFloat = 0
    @objc public var sensitivityXMax: CGFloat = 8
    @objc public var hasSensitivityY: Bool = false
    @objc public var sensitivityYMin: CGFloat = 0
    @objc public var sensitivityYMax: CGFloat = 8
    @objc public var hasSlideThreshold: Bool = false
    @objc public var slideThresholdMin: CGFloat = 0
    @objc public var slideThresholdMax: CGFloat = 20
    @objc public var hasYawFactor: Bool = false
    @objc public var yawFactorMin: CGFloat = 0
    @objc public var yawFactorMax: CGFloat = 1
    @objc public var hasPitchFactor: Bool = false
    @objc public var pitchFactorMin: CGFloat = 0
    @objc public var pitchFactorMax: CGFloat = 1
    @objc public var hasRollFactor: Bool = false
    @objc public var rollFactorMin: CGFloat = 0
    @objc public var rollFactorMax: CGFloat = 1

    @objc public var hasAutoTap: Bool = false
    @objc public var isMousePadWithButtonActions: Bool = false
    @objc public var hasInertia: Bool = false
    @objc public var isFuncationalButton: Bool = false
    @objc public var hasHapticFeedback: Bool = false
    @objc public var isDirectionPad: Bool = false
    @objc public var hasL3R3Indicator: Bool = false

    // for all stick pads
    @objc public var minStickOffset: CGFloat = 0
    public let stickMaxOffset: CGFloat = 0x7FFE
    
    
    // for LSVPAD, RSVPAD
    @objc public var deltaX: CGFloat
    @objc public var deltaY: CGFloat
    
    private let VectorStickFactor = 1.5167
    private var weightedDeltaX: Int = 0
    private var weightedDeltaY: Int = 0

    // for LSPAD, RSPAD
    @objc public var offSetX: CGFloat
    @objc public var offSetY: CGFloat
    private let crossMarkColor: CGColor = UIColor(white: 1, alpha: 0.70).cgColor
    private let stickBallColor: CGColor = UIColor(white: 1, alpha: 0.75).cgColor
    private var stickInputScale: CGFloat = 35
    @objc public var l3r3Indicator = CAShapeLayer()
    private let stickBallMaxOffset = 18.0
    @objc public var crossMarkLayer = CAShapeLayer()
    
    // this is for all stick pads and mouse Pad
    @objc public var sensitivityFactorX: CGFloat = 1.0
    @objc public var sensitivityFactorY: CGFloat = 1.0
    @objc public var yawFactor: CGFloat = 1.0
    @objc public var pitchFactor: CGFloat = 1.0
    @objc public var rollFactor: CGFloat = 1.0
    private var gyroControlPreviousStatus: NSMutableDictionary = NSMutableDictionary()
    
    private var superViewWidth: CGFloat = 0
    private var superViewHeight: CGFloat = 0
    private var absMousePaused: Bool = false

    // check quick double tap:
    private var quickDoubleTapDetected: Bool
    private var touchTapTimeInterval: TimeInterval
    private var touchTapTimeStamp: TimeInterval
    private let QUICK_TAP_TIME_INTERVAL = 0.2
    @objc public var stickIndicatorOffset: CGFloat = 120
    
    // for all LRUD pads
    @objc public var upIndicator = CAShapeLayer()
    @objc public var downIndicator = CAShapeLayer()
    @objc public var leftIndicator = CAShapeLayer()
    @objc public var rightIndicator = CAShapeLayer()
    
    // for DPAD LRUD pad
    @objc public var lrudIndicatorBall = CAShapeLayer()
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
    private var directionPadTouchBegan: Bool = false
    private var firstTouchMoved: Bool = false
    private var mousePointerMoved: Bool
    private var twoTouchesDetected: Bool
    private var allSpawnedTouchesCount: Int = 0
    
    // trackball
    private var trackballVelocity: CGPoint = .zero
    private var trackballDecelerationTimer: Timer?
    @objc public var decelerationRate: CGFloat = 0.93
    private let trackballVelocityThreshold: CGFloat = 0.1
    
    @objc public var slideThreshold: CGFloat = 6.0
    
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
    @objc public var buttonDownVisualEffectStandardWidth: CGFloat
    @objc public var highlightSizeFactor: CGFloat = 1.0
    @objc static public var isTweakingHighlightSize: Bool = false
    
    // discreteWheels
    private var tickCycle: UInt8 = UIScreen.main.maximumFramesPerSecond > 110 ? 20 : 10
    private var tickFlag: UInt8 = 0

    
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
                self.functionalButtonString = Set(self.comboButtonStrings).intersection(Set(CommandManager.functionalButtonCmds)).first ?? ""
                self.motionControlButtonString = Set(self.comboButtonStrings).intersection(Set(CommandManager.motionControlButtonCmds)).first ?? ""

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
        self.buttonDownVisualEffectStandardWidth = 0
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
        self.oscProfile = oscProfileMan.getSelectedProfile()
        self.tempSettings = dataMan.getSettings()
        self.inertialScroller = InertialScroller()
        super.init(frame: .zero)
        
        // helps widget panel to hide/show stacks
        self.accessWidgetAttributes()
        
        if self.widgetType == WidgetTypeEnum.button {
            if !self.touchPadString.isEmpty {
                self.mouseButtonAction = MouseButtonAction.noClick
                self.buttonMode = ButtonMode.regular.rawValue
            }
            if !self.motionControlButtonString.isEmpty {
                self.buttonMode = ButtonMode.tapToToggle.rawValue
            }
            if !self.functionalButtonString.isEmpty {
                self.buttonMode = ButtonMode.movable.rawValue
            }
        }
        
        self.tweakBorderAlpha(alpha: 0.19) // fix default borderAlpha offset

        setupView()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func accessWidgetAttributes(){
        self.hasMinStickOffset = CommandManager.stickTouchPads.contains(self.touchPadString)
        self.hasStickIndicator = CommandManager.nonVectorStickPads.contains(self.touchPadString) && widgetType == WidgetTypeEnum.touchPad
        self.hasSensitivityX = CommandManager.touchPadCmds.contains(self.touchPadString) && !CommandManager.verticalTouchPads.contains(self.touchPadString)
        self.hasSensitivityY = CommandManager.touchPadCmds.contains(self.touchPadString)
        self.hasSlideThreshold = CommandManager.mousePad.contains(self.touchPadString)
        
        if CommandManager.bidirectionalVerticalTouchPads.contains(self.touchPadString){
            self.sensitivityYMin = -4.0
            self.sensitivityYMax = 4.0
        }

        self.hasYawFactor = self.motionControlButtonString == "GYRO" && (oscProfile.mapGyroTo == MapGyroTo.mapGyroToMouse || oscProfile.yawPitchToRightStick)
        self.hasPitchFactor = self.hasYawFactor
        self.yawFactorMin = 0
        self.yawFactorMax = 1.0
        self.pitchFactorMin = 0
        self.pitchFactorMax = 1.0
        
        self.hasRollFactor = self.motionControlButtonString == "GYRO" && (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick && oscProfile.rollToLeftStick)
        
        self.hasAutoTap = self.widgetType == WidgetTypeEnum.button && self.functionalButtonString == "" && self.motionControlButtonString == ""
        self.isMousePadWithButtonActions = CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && widgetType == WidgetTypeEnum.touchPad
        self.hasInertia = CommandManager.inertialTouchPads.contains(self.touchPadString)
        self.isFuncationalButton = self.functionalButtonString != ""
        self.hasHapticFeedback = !self.comboButtonStrings.isEmpty || CommandManager.directionPads.contains(self.touchPadString)
        self.isDirectionPad = self.widgetType == WidgetTypeEnum.touchPad && CommandManager.directionPads.contains(self.touchPadString)
        self.hasL3R3Indicator = !self.isDirectionPad && self.widgetType == WidgetTypeEnum.touchPad
    }
    
    // ======================================================================================================
    @objc public func setupAutoTapTimer() {
        if self.widgetType == WidgetTypeEnum.button, autoTapInterval >= OnScreenWidgetView.MinAutotapInterval {
            self.autoTapTimer = SafeTimer(interval:0.001 * Double(autoTapInterval)) {
                // print("timer instance \(Unmanaged.passUnretained(self.autoTapTimer!).toOpaque()), \(CACurrentMediaTime())")
                self.handleButtonDown()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                    self.handleButtonUp()
                }
            }
        }
    }
    
    @objc public func setupInertialScroller() {
        if self.hasInertia {
            self.inertialScroller = InertialScroller(decelerationRate: self.decelerationRate, displayLinkRate: CGFloat(self.tempSettings.framerate.intValue))
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
    
    @objc public func adjustTransparency(alpha: CGFloat, tweakBorderAlpha:Bool){
        self.backgroundAlpha = alpha
        self.tweakAlpha(tweakBorderAlpha: tweakBorderAlpha)
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
    
    @objc public func tweakLabelAlpha(alpha:CGFloat){
        labelAlpha = alpha
        label.textColor = UIColor(white: 1.0, alpha: labelAlpha)
    }
    
    @objc public func tweakBorderAlpha(alpha:CGFloat){
        borderAlpha = alpha
        defaultBorderColor = UIColor(white: 0.2, alpha: borderAlpha).cgColor
        self.layer.borderColor = defaultBorderColor
    }
    
    private func tweakAlpha(tweakBorderAlpha:Bool){
        // setup default border from self.backgroundAlpha
        let realBackgroundAlpha = self.backgroundAlpha - 0.18 // offset to be consistent with legacy onScreen controller layer opacity
        self.backgroundColor = UIColor(white: 0.2, alpha: realBackgroundAlpha) // offset to be consistent with legacy onScreen controller layer opacity
        
        if tweakBorderAlpha {
            borderAlpha = realBackgroundAlpha * 1.01
            defaultBorderColor = UIColor(white: 0.2, alpha: borderAlpha).cgColor
            self.layer.borderColor = defaultBorderColor
        }
        
        if widgetType == WidgetTypeEnum.touchPad {
            self.backgroundColor = UIColor.clear // make touchPad transparent
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
            self.setSquareWidgetCornerRadius()
        }
    }
    
    private func setSquareWidgetCornerRadius(){
        let shortSideLen = min(self.layer.bounds.size.width, self.layer.bounds.size.height)
        self.layer.cornerRadius = shortSideLen/2 < 16 ? shortSideLen/3.2 : 16
    }
    
    private func setupView() {
        label.text = self.widgetLabel
        label.font = UIFont.boldSystemFont(ofSize: 19)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.1  // Adjust the scale factor as needed
        
        label.textColor = UIColor(white: 1.0, alpha: labelAlpha)
        label.textAlignment = .center
        label.shadowColor = .black
        label.shadowOffset = CGSize(width: 1, height: 1)
        label.translatesAutoresizingMaskIntoConstraints = false // enable auto alignment for the label
        
        self.translatesAutoresizingMaskIntoConstraints = true // this is mandatory to prevent unexpected key view location change
        
        self.setSquareWidgetCornerRadius()
        self.layer.borderWidth = self.borderWidth
        
        self.tweakAlpha(tweakBorderAlpha: false)
        
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
        
        if !self.functionalButtonString.isEmpty{
            self.layer.borderWidth = self.borderWidth
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
        
        hideAllHighlightLayersOfAllWidgets(selfIncluded: false)
        if widgetType == WidgetTypeEnum.button {setupButtonDownVisualEffectLayer()}
        if CommandManager.directionPads.contains(touchPadString) {setupLrudDirectionIndicatorlayers()}
        if CommandManager.stickTouchPads.contains(touchPadString) {setupL3R3Indicator()}
        if CommandManager.verticalTouchPads.contains(touchPadString) {setupL3R3Indicator()}
        if CommandManager.mousePadWithButtonActions.contains(self.touchPadString) {setupL3R3Indicator()}
        if self.hasStickIndicator {
            if self.crossMarkLayer.superlayer == nil {self.crossMarkLayer = createCrossMark()}
            if self.lrudIndicatorBall.superlayer == nil {self.lrudIndicatorBall = createStickBall()}
        }
    }
    
    @objc public func setupL3R3Indicator() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let indicatorFrame = CAShapeLayer();
        // l3r3Indicator = CAShapeLayer();
        
        indicatorFrame.frame = CGRectMake(0, 0, 75*highlightSizeFactor, 75*highlightSizeFactor)
        indicatorFrame.cornerRadius = 9 * highlightSizeFactor
        l3r3Indicator.borderWidth = 7 * min(highlightSizeFactor,1.0)
        l3r3Indicator.frame = indicatorFrame.bounds.insetBy(dx: -l3r3Indicator.borderWidth, dy: -l3r3Indicator.borderWidth) // Adjust the inset as needed
        l3r3Indicator.borderColor = UIColor.clear.cgColor
        
        l3r3Indicator.cornerRadius = indicatorFrame.cornerRadius + l3r3Indicator.borderWidth
        l3r3Indicator.backgroundColor = UIColor.clear.cgColor
        l3r3Indicator.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: l3r3Indicator.bounds, cornerRadius: l3r3Indicator.cornerRadius)
        
        l3r3Indicator.path = path.cgPath
        l3r3Indicator.borderColor = voidlinkPurple
        self.l3r3Indicator.position = CGPointMake(self.bounds.width/2, self.bounds.height/2)
        if !OnScreenWidgetView.isTweakingHighlightSize {l3r3Indicator.isHidden = true}
        
        if l3r3Indicator.superlayer == nil {
            self.layer.addSublayer(l3r3Indicator)
        }
        
        CATransaction.commit()
    }
    
    private func showl3r3Indicator(){
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            self.l3r3Indicator.position = CGPointMake(touchBeganLocation.x, touchBeganLocation.y)
            self.l3r3Indicator.isHidden = false

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
        lrudIndicatorBall.lineWidth = 0.6
        // stickBallLayer.shadowOffset = CGSize(width: 0.0, height: 0.0)
        lrudIndicatorBall.shadowOffset = CGSize(width: 0.0, height: 0.0)
        // stickBallLayer.shadowColor = stickBallLayer.strokeColor
        CATransaction.commit()
    }
    
    private func handleStickBallLeavingBorder(){
        lrudIndicatorBall.lineWidth = 0
        lrudIndicatorBall.shadowOffset = CGSize(width: 0.5, height: 0.5)
        lrudIndicatorBall.shadowOpacity = 0.8
        lrudIndicatorBall.shadowColor = UIColor.black.cgColor
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
        
        getStickBallReady(at: stickMarkerRelativeLocation)
        showCrossMark(at: stickMarkerRelativeLocation)
    }
    
    // cross mark for left & right gamePad
    private func createCrossMark() -> CAShapeLayer {
        let crossLayer = CAShapeLayer()
                
        crossLayer.strokeColor = crossMarkColor
        crossLayer.lineWidth = 1.2
        crossLayer.fillColor = crossMarkColor
        
        let path = UIBezierPath()
        let crossSize = 26.0

        path.move(to: CGPoint(x: 0 - crossSize / 2, y: 0))
        path.addLine(to: CGPoint(x: 0 + crossSize / 2, y: 0))
        
        // 竖线
        path.move(to: CGPoint(x: 0, y: 0 - crossSize / 2))
        path.addLine(to: CGPoint(x: 0, y: 0 + crossSize / 2))

        crossLayer.path = path.cgPath
        
        self.layer.addSublayer(crossLayer)
        crossLayer.shadowColor = UIColor.black.cgColor
        crossLayer.shadowOffset = CGSize(width: 1, height: 1)
        crossLayer.shadowRadius = 0;
        crossLayer.shadowOpacity = 0.8
        crossLayer.isHidden = true
        
        return crossLayer
    }
    
    private func showCrossMark(at point: CGPoint) {

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // self.crossMarkLayer.position = CGPointMake(CGRectGetMinX(self.frame), CGRectGetMinY(self.frame))
        self.crossMarkLayer.position = point
        self.crossMarkLayer.isHidden = false
        
        CATransaction.commit()
    }
    
    private func createStickBall() -> CAShapeLayer {
        // Create a CAShapeLayer
        let stickBallLayer = CAShapeLayer()
        let path = UIBezierPath(arcCenter: CGPoint.zero, radius: 8, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        stickBallLayer.path = path.cgPath  // Assign the circular path to the shape layer

        self.layer.addSublayer(stickBallLayer)
        
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
    
    private func getStickBallReady(at point: CGPoint) {
        // let path = UIBezierPath(arcCenter: center, radius: 8, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Create a CAShapeLayer
        // self.stickBallLayer.path = path.cgPath  // Assign the circular path to the shape layer
        // self.stickBallLayer.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame))
        self.lrudIndicatorBall.position = point
        self.lrudIndicatorBall.isHidden = true
        
        CATransaction.commit()
    }
    
    
    @objc public func updateStickIndicator(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.lrudIndicatorBall.removeAllAnimations()
        if !OnScreenWidgetView.editMode {
            if self.firstTouchMoved {
                if self.lrudIndicatorBall.isHidden {self.lrudIndicatorBall.isHidden = false}
                let realOffsetX = touchInputToStickBallCoord(input: offSetX*sensitivityFactorX)
                let realOffsetY = touchInputToStickBallCoord(input: offSetY*sensitivityFactorY)
                self.lrudIndicatorBall.position = CGPointMake(touchBeganLocation.x + realOffsetX, touchBeganLocation.y + realOffsetY - self.stickIndicatorOffset)
            }
            /*
            if fabs(realOffsetX) == stickBallMaxOffset || fabs(realOffsetY) == stickBallMaxOffset {handleStickBallReachingBorder()}
            else{handleStickBallLeavingBorder()}*/
        }
        else{
            if self.lrudIndicatorBall.isHidden {self.lrudIndicatorBall.isHidden = false}
            self.lrudIndicatorBall.position = CGPointMake(CGRectGetMidX(self.crossMarkLayer.frame), CGRectGetMidY(self.crossMarkLayer.frame)-stickIndicatorOffset)
        }
        CATransaction.commit()
    }
    
    private func resetStickBallPositionAndHideIndicator(){
        /*
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        handleStickBallLeavingBorder()
        CATransaction.commit()*/
        
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        self.lrudIndicatorBall.position = CGPointMake(touchBeganLocation.x, touchBeganLocation.y - self.stickIndicatorOffset)
        CATransaction.setCompletionBlock {
            // 动画结束后执行的代码
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !self.touchBegan {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    self.crossMarkLayer.isHidden = true
                    self.lrudIndicatorBall.isHidden = true
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
        
        lrudIndicatorBall.position = point
        lrudIndicatorBall.isHidden = false;
        
        CATransaction.commit()
    }
    
    private func setupLrudBall() {
        // Create a circular path using UIBezierPath
        let path = UIBezierPath(arcCenter: CGPoint.zero, radius: 10*min(highlightSizeFactor,1.0), startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        
        // Create a CAShapeLayer
        lrudIndicatorBall.path = path.cgPath  // Assign the circular path to the shape layer
        if lrudIndicatorBall.superlayer == nil {
            self.layer.addSublayer(lrudIndicatorBall)
        }
        
        lrudIndicatorBall.position = CGPoint(x: self.bounds.width/2, y: self.bounds.height/2,)

        // Set the stroke color and width (border of the circle)
        lrudIndicatorBall.strokeColor = stickBallColor
        lrudIndicatorBall.lineWidth = 0
        lrudIndicatorBall.shadowOffset = CGSize(width: 0.5, height: 0.5)
        lrudIndicatorBall.shadowRadius = 0;
        lrudIndicatorBall.shadowOpacity = 0.8
        lrudIndicatorBall.name = "lrudBall"
        if !OnScreenWidgetView.isTweakingHighlightSize {lrudIndicatorBall.isHidden = true}
        
        // Set the fill color (inside of the circle)
        lrudIndicatorBall.fillColor = stickBallColor  // Light fill with some transparency
    }
    
    private func setupLrudDirectionLayer(directionLayer:CAShapeLayer) {
        let indicatorFrame = CAShapeLayer();
        indicatorFrame.frame = CGRectMake(0, 0, 75*highlightSizeFactor, 75*highlightSizeFactor)
        indicatorFrame.cornerRadius = 9 * highlightSizeFactor
        directionLayer.borderWidth = 6 * min(1.0, highlightSizeFactor)
        directionLayer.frame = indicatorFrame.bounds.insetBy(dx: -directionLayer.borderWidth, dy: -directionLayer.borderWidth) // Adjust the inset as needed
        directionLayer.cornerRadius = indicatorFrame.cornerRadius + directionLayer.borderWidth
        directionLayer.backgroundColor = UIColor.clear.cgColor
        directionLayer.fillColor = UIColor.clear.cgColor
        let path = UIBezierPath(roundedRect: directionLayer.bounds, cornerRadius: directionLayer.cornerRadius)
        directionLayer.path = path.cgPath
        directionLayer.borderColor = voidlinkPurple
        directionLayer.position = CGPoint(x: self.bounds.width/2, y: self.bounds.height/2)
        if directionLayer.superlayer == nil {
            self.layer.insertSublayer(directionLayer, below: lrudIndicatorBall)
        }
    }
    
    private func showLrudDirectionIndicator(with indicatorLayer:CAShapeLayer){
        // show the indicator based on the touchBeganLocation
        indicatorLayer.position = touchBeganLocation

        if indicatorLayer.isHidden {
            indicatorLayer.isHidden = false
            if vibrationOn {
                vibrationGenerator.prepare()
                vibrationGenerator.impactOccurred()
            }
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
        
        if pressedButtonMask != previousButtonMask || directionPadTouchBegan {
            directionPadTouchBegan = false
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
                self.upIndicator.isHidden = true
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
                self.downIndicator.isHidden = true
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
                self.leftIndicator.isHidden = true
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
                self.rightIndicator.isHidden = true
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
        // stopTrackballMomentum()
        
        if self.inertialScroller.handler == nil {
            self.inertialScroller.handler = {
                LiSendMouseMoveEvent(
                    Int16(self.inertialScroller.vector.dx*1.7),
                    Int16(self.inertialScroller.vector.dy*1.7)
                )
            }
        }
        
        self.inertialScroller.timer?.restart()
    }
    
    private func stopTrackballMomentum() {
        self.inertialScroller.timer?.pause()
    }
    
    
    //==== Button actions =============================================
    
    //==== Button widget tap down=============================================
    private func handleTapDownOrSlidein() {
        if autoTapInterval < OnScreenWidgetView.MinAutotapInterval {
            handleButtonDown()
        }
        else{
            self.autoTapTimer?.restart()
        }
    }
    
    private func handleFingerUpOrSlideout() {
        if autoTapInterval < OnScreenWidgetView.MinAutotapInterval {
            handleButtonUp()
        }
        else{
            self.autoTapTimer?.pause()
            self.handleButtonUp()
        }
    }
    
    private func handleButtonDown() {
        
        if !OnScreenWidgetView.editMode, !self.functionalButtonString.isEmpty {self.handleFunctionalButtonDown()}
                        
        if !OnScreenWidgetView.editMode {self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
        
        if !OnScreenWidgetView.editMode, !self.motionControlButtonString.isEmpty {self.handleMotionControlButtonDown()}
        
        self.buttonDownVisualEffect()
        
        if vibrationOn {
            vibrationGenerator.prepare()
            vibrationGenerator.impactOccurred()
        }
    }
    
    private func buttonDownVisualEffect(){
        logicallyDown = true
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if widgetType == WidgetTypeEnum.button {buttonDownVisualEffectLayer.isHidden = false}
            CATransaction.commit()
        }
    }
    
    private func buttonUpVisualEffect(){
        logicallyDown = false
        if OnScreenWidgetView.buttonVisualFeedbackEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if !OnScreenWidgetView.isTweakingHighlightSize {buttonDownVisualEffectLayer.isHidden = true}
            CATransaction.commit()
        }
    }
    
    private func handleButtonUp() {
        if !OnScreenWidgetView.editMode {self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)}
        
        if !OnScreenWidgetView.editMode && !self.motionControlButtonString.isEmpty{
            self.handleMotionControlButtonUp()
        }
        
        self.buttonUpVisualEffect()

        if !OnScreenWidgetView.editMode && !self.functionalButtonString.isEmpty{
            self.handleFunctionalButtonUp()
        }
    }
    
    @objc public func setupLrudDirectionIndicatorlayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        self.setupLrudBall()
        
        setupLrudDirectionLayer(directionLayer: upIndicator)
        upIndicator.anchorPoint = CGPoint(x: 0.5, y: 1)
        setupLrudDirectionLayer(directionLayer: downIndicator)
        downIndicator.anchorPoint = CGPoint(x: 0.5, y: 0)
        setupLrudDirectionLayer(directionLayer: leftIndicator)
        leftIndicator.anchorPoint = CGPoint(x: 1, y: 0.5)
        setupLrudDirectionLayer(directionLayer: rightIndicator)
        rightIndicator.anchorPoint = CGPoint(x: 0, y: 0.5)
                
        if !OnScreenWidgetView.isTweakingHighlightSize {
            leftIndicator.isHidden = true
            rightIndicator.isHidden = true
            upIndicator.isHidden = true
            downIndicator.isHidden = true
        }
        
        CATransaction.commit()
    }
    
    @objc public func hideAllHighlightLayersOfAllWidgets(selfIncluded:Bool) {
        self.forEachWidget(){ widget in
            if !selfIncluded && widget == self {return}
            widget.buttonDownVisualEffectLayer.isHidden = true;
            widget.l3r3Indicator.isHidden = true
            widget.lrudIndicatorBall.isHidden = true
            widget.upIndicator.isHidden = true
            widget.downIndicator.isHidden = true
            widget.leftIndicator.isHidden = true
            widget.rightIndicator.isHidden = true
        }
    }
    
    @objc public func setupButtonDownVisualEffectLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.buttonDownVisualEffectStandardWidth = 8
        if self.shape == "round" {
            if deNormalizedWidthFactor < 1.3 {self.buttonDownVisualEffectStandardWidth = 15.3} // wider visual effect for osc buttons
            else {self.buttonDownVisualEffectStandardWidth = 9}
        }
        
        if self.motionControlButtonString != "" {self.buttonDownVisualEffectStandardWidth = 3}
        
        // Set the frame to be larger than the view to expand outward
        buttonDownVisualEffectLayer.borderWidth = self.buttonDownVisualEffectStandardWidth * self.highlightSizeFactor // set this 0 to hide the visual effect first
        buttonDownVisualEffectLayer.borderColor = voidlinkPurple
        buttonDownVisualEffectLayer.frame = self.bounds.insetBy(dx: -buttonDownVisualEffectLayer.borderWidth, dy: -buttonDownVisualEffectLayer.borderWidth) // Adjust the inset as needed
        buttonDownVisualEffectLayer.cornerRadius = self.layer.cornerRadius + buttonDownVisualEffectLayer.borderWidth
        buttonDownVisualEffectLayer.backgroundColor = UIColor.clear.cgColor;
        buttonDownVisualEffectLayer.fillColor = UIColor.clear.cgColor;
        
        // Create a path for the border
        let path = UIBezierPath( roundedRect: buttonDownVisualEffectLayer.bounds, cornerRadius: buttonDownVisualEffectLayer.cornerRadius)
        buttonDownVisualEffectLayer.path = path.cgPath
        
        if buttonDownVisualEffectLayer.superlayer == nil {
            self.layer.insertSublayer(buttonDownVisualEffectLayer, below: self.layer)
        }

        buttonDownVisualEffectLayer.position = CGPointMake(self.bounds.midX, self.bounds.midY)
        if !OnScreenWidgetView.isTweakingHighlightSize {buttonDownVisualEffectLayer.isHidden = true}
        
        CATransaction.commit()
    }
    //==========================================================================================================
    
    
    //=========================================send on screen controller stick/trigger events
    private func weightedTouchInputToStickOffset(input: CGFloat) -> CGFloat{
        let target = stickMaxOffset * input / stickInputScale
        return fmax(fmin(target, stickMaxOffset),-stickMaxOffset)
    }
    
    private func stickOffsetToWeightedTouchInput(offset: CGFloat) -> CGFloat {
        return offset * stickInputScale / stickMaxOffset
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
    
    private func sendRightStickTouchPadEvent(weightedTouchX: CGFloat, weightedTouchY: CGFloat){
        let targetX = self.weightedTouchInputToStickOffset(input: weightedTouchX)
        let targetY = -self.weightedTouchInputToStickOffset(input: weightedTouchY)
        
        let mixRightStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.yawPitchToRightStick)
        if !mixRightStickInputToGyro || (self.motionHandler.gyroMixInputStarted() != true) {
            
            let offsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: targetX, dy: targetY), withMinOffset: minStickOffset)
            self.onScreenControls.sendRightStickTouchPadEvent(offsetVector.dx, offsetVector.dy)
        }
        self.motionHandler.mixOnScreenRightStickAndGyroInput(x: targetX, y: targetY)
    }
    
    private func sendLeftStickTouchPadEvent(weightedTouchX: CGFloat, weightedTouchY: CGFloat){
        let targetX = self.weightedTouchInputToStickOffset(input: weightedTouchX)
        let targetY = -self.weightedTouchInputToStickOffset(input: weightedTouchY)
        
        let mixLeftStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.rollToLeftStick)
        if !mixLeftStickInputToGyro || (self.motionHandler.gyroMixInputStarted() != true) {
            
            let offsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: targetX, dy: targetY), withMinOffset: minStickOffset)
            self.onScreenControls.sendLeftStickTouchPadEvent(offsetVector.dx, offsetVector.dy)
        }
        self.motionHandler.mixOnScreenLeftStickAndGyroInput(x: targetX, y: targetY)
    }
     
    private func sendLeftTriggerTouchPadEvent(inputY: CGFloat){
        self.onScreenControls.updateLeftTrigger(UInt8(max(min(inputY,255),0)))
    }
    
    private func sendRightTriggerTouchPadEvent(inputY: CGFloat){
        self.onScreenControls.updateRightTrigger(UInt8(max(min(inputY,255),0)))
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
                if CommandManager.mouseButtonMappings.keys.contains(comboString), self.functionalButtonString != "ABSTCHDRAG" {
                    let button = Int32(CommandManager.mouseButtonMappings[comboString]!)
                    if abs(button) == 0xFF {
                        LiSendScrollEvent(button>0 ? 3 : -3)
                    }
                    else {LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), button)}
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
        return UITouchUtil.touches(in: self, from: event).count
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        self.touchBegan = true
        self.directionPadTouchBegan = true
        self.firstTouchMoved = false
        self.tickFlag = 0
        super.touchesBegan(touches, with: event)
        self.isMultipleTouchEnabled = self.widgetType == WidgetTypeEnum.button || CommandManager.mousePadWithButtonActions.contains(self.touchPadString);

        if !OnScreenWidgetView.editMode && self.touchPadString == "TRACKBALL" {
            stopTrackballMomentum()
        }
        
        if touches.count == 1 { // to make sure touchBegan location captured properly, don't use event.alltouches.count here
            let currentTime = CACurrentMediaTime()
            touchTapTimeInterval = currentTime - touchTapTimeStamp
            touchTapTimeStamp = currentTime
            quickDoubleTapDetected = touchTapTimeInterval < QUICK_TAP_TIME_INTERVAL
            
            let touch = touches.first
            // get touchBeganLocation
            
            if OnScreenWidgetView.editMode {self.touchBeganLocation = touch!.location(in: superview)}
            else {
                if widgetType == WidgetTypeEnum.button, self.buttonMode == ButtonMode.movable.rawValue {self.touchBeganLocation = touch!.location(in: superview)}
                else {self.touchBeganLocation = touch!.location(in: self)}
            }
            self.latestTouchLocation = touchBeganLocation
        }
                
        allSpawnedTouchesCount = self.getAllSpawnedTouchesCount(with: event) // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        if allSpawnedTouchesCount == 2 {
            self.twoTouchesDetected = true
        }
        
        if !OnScreenWidgetView.editMode {
            if self.widgetType == WidgetTypeEnum.touchPad && touches.count == 1{ // don't use event?.allTouches?.count here, it will counts all touches including the ones captured by other UIViews
                switch self.touchPadString {
                case "LSPAD","RSPAD":
                    self.showStickIndicator()
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "LSVPAD":
                    self.clearLeftStickTouchPadFlag()
                    self.inertialScroller.timer?.pause()
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "RSVPAD":
                    self.clearRightStickTouchPadFlag()
                    self.inertialScroller.timer?.pause()
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "DS4TOUCH":
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
                case "DPAD", "WASDPAD", "ARROWPAD":
                    if allSpawnedTouchesCount == 1 {showLrudBall(at: touchBeganLocation)}
                    if quickDoubleTapDetected {
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)
                        DispatchQueue.global(qos: .userInteractive).async {
                            usleep(100000)
                            self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)
                        }
                    }
                case "LTPAD", "RTPAD","MOUSEWHEEL", "WHEEL", "DISCRETEWHEEL", "DSWHEEL":
                    if quickDoubleTapDetected && !self.comboButtonStrings.isEmpty {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)
                    }
                default:
                    break
                }
                
                if self.widgetType == WidgetTypeEnum.touchPad && CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && allSpawnedTouchesCount == 1 && !twoTouchesDetected {
                    self.handleMousePadButtonActionDown()
                }
            }
            
            if self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "DS4TOUCH" {
                self.handleControllerTouchesDown(touches: touches)
            }
                        
            // this will also deal with button events
            if self.widgetType == WidgetTypeEnum.button && !self.comboButtonStrings.isEmpty {
                if self.buttonMode != ButtonMode.tapToToggle.rawValue {
                    self.handleTapDownOrSlidein()
                    setLock.lock()
                    self.capturedTouches.union(touches)
                    setLock.unlock()
                }
                else{
                    if(self.tapToToggleFlag) {self.handleTapDownOrSlidein()}
                    else {self.handleFingerUpOrSlideout()}
                    self.tapToToggleFlag = !self.tapToToggleFlag
                }
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
        else {
            if self.buttonMode == ButtonMode.movable.rawValue {currentLocation = touch.location(in: superview)}
            else {return}
        }
        
        if !firstTouchMoved, !self.isAdjacentPoints(currentLocation, from: latestTouchLocation, tolerance: 1) {
            // First move event
            self.latestTouchLocation = currentLocation
            self.firstTouchMoved = true
        }
                
        let offsetX = currentLocation.x - latestTouchLocation.x;
        let offsetY = currentLocation.y - latestTouchLocation.y;
        
        let outOfBoundsX = center.x+offsetX >= (self.superview?.bounds.width)! || center.x+offsetX < 0
        let outOfBoundsY = center.y+offsetY >= (self.superview?.bounds.height)! || center.y+offsetY < 0

        if firstTouchMoved {center = CGPoint(x: outOfBoundsX ? center.x : center.x+offsetX, y: outOfBoundsY ? center.y : center.y+offsetY)}
        
        latestTouchLocation = currentLocation
        
        relocatedDuringStreaming = true
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
            self.forEachWidget(){ widget in
                setLock.lock()
                let captured = widget.capturedTouches.contains(touch)
                setLock.unlock()
                if !captured || widget.buttonMode == ButtonMode.regular.rawValue {return}
                widget.handleFingerUpOrSlideout()
                setLock.lock()
                widget.capturedTouches.remove(touch)
                setLock.unlock()
            }
        }
    }
    
    private func forEachWidget(_ action: (OnScreenWidgetView) -> Void) {
        // 遍历 superview 的 subviews，如果 superview 为 nil，则遍历空数组
        for subview in self.superview?.subviews ?? [] {
            if let widget = subview as? OnScreenWidgetView {
                action(widget)
            }
        }
    }

    private func handleButtonSliding(touches: Set<UITouch>) {
        for touch in touches {
            let locationInSuperView = touch.location(in: self.superview)
            self.forEachWidget{ widget in
                if widget.widgetType != WidgetTypeEnum.button {return}
                let isSlidableButton = widget.buttonMode == ButtonMode.slideToToggle.rawValue || widget.buttonMode == ButtonMode.slideAndHold.rawValue
                let pointInSubview = widget.convert(locationInSuperView, from: self.superview)
                if widget.bounds.contains(pointInSubview){
                    setLock.lock()
                    let captured = widget.capturedTouches.contains(touch)
                    setLock.unlock()
                    if captured || !isSlidableButton
                        {return}
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
                    if !captured || !isSlidableButton {return}
                    // print("UIButton: \(widget.buttonLabel) out test, \(widget.touchPadString), \(CACurrentMediaTime())")
                    if(widget.buttonMode == ButtonMode.slideToToggle.rawValue){
                        widget.handleFingerUpOrSlideout()
                        setLock.lock()
                        widget.capturedTouches.remove(touch)
                        setLock.unlock()
                    }
                    if(widget.buttonMode == ButtonMode.slideAndHold.rawValue){
                        // do nothing here
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
                if self.buttonMode == ButtonMode.slideToToggle.rawValue || self.buttonMode == ButtonMode.slideAndHold.rawValue  {self.handleButtonSliding(touches: touches)}
            }
            
            if self.buttonMode == ButtonMode.movable.rawValue{
                if let touch = touches.first {
                    NSLog("touchTapTimeStamp %f", self.touchTapTimeStamp)
                    if CACurrentMediaTime() - self.touchTapTimeStamp > 0.3 { // temporarily relocate special buttons
                        self.moveByTouch(touch: touch)
                    }
                }
            }
        }
        
        // Move the widgetView based on touch movement in relocation mode
        if OnScreenWidgetView.editMode {
            if let touch = touches.first {
                self.moveByTouch(touch: touch)
                }
            self.lrudIndicatorBall.removeFromSuperlayer()
            self.crossMarkLayer.removeFromSuperlayer()
        }
    }
    
    func isAdjacentPoints(_ currentPoint: CGPoint, from originalPoint: CGPoint, tolerance: CGFloat) -> Bool {
        let distance = hypot(originalPoint.x - currentPoint.x, originalPoint.y - currentPoint.y)
        let threshold = hypot(tolerance, tolerance)
        return distance <= threshold
    }
    
    private func getVector (touch: UITouch) {
        let currentTouchLocation: CGPoint = (touch.location(in: self))
        
        if !self.mousePointerMoved, !self.isAdjacentPoints(currentTouchLocation, from: latestTouchLocation, tolerance: 2.0){
            self.mousePointerMoved = true
        }
        
        if !firstTouchMoved, !self.isAdjacentPoints(currentTouchLocation, from: touchBeganLocation, tolerance: slideThreshold) {
            // First move event
            self.latestTouchLocation = currentTouchLocation
            self.firstTouchMoved = true
        }
        
        self.deltaX = currentTouchLocation.x - self.latestTouchLocation.x
        self.deltaY = currentTouchLocation.y - self.latestTouchLocation.y
        
        if self.hasInertia && firstTouchMoved {
            self.inertialScroller.vector = UITouchUtil.vector(of: touch, in: self)
        }
        
        self.offSetX = currentTouchLocation.x - self.touchBeganLocation.x
        self.offSetY = currentTouchLocation.y - self.touchBeganLocation.y
    }
    
    private func updateTouchLocation(touch: UITouch){
        let currentTouchLocation: CGPoint = (touch.location(in: self))
        if weightedDeltaX != 0 || weightedDeltaY != 0 {
            self.latestTouchLocation = currentTouchLocation
        }
    }
    
    private func handleTouchPadMoveEvent (_ touches: Set<UITouch>, with event: UIEvent?){
        if touches.count == 1{ // don't use event.alltouches.count here, it will counts all touches
            self.getVector(touch: touches.first!)
            switch self.touchPadString{
            case "MOUSEPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX * 1.7 * self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY * 1.7 * self.sensitivityFactorY)
                    if self.firstTouchMoved {LiSendMouseMoveEvent(Int16(self.weightedDeltaX), Int16(self.weightedDeltaY))}
                    self.updateTouchLocation(touch: touches.first!)
                }
                break
            case "TRACKBALL":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX * 1.7 * self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY * 1.7 * self.sensitivityFactorY)
                    if self.firstTouchMoved {
                        LiSendMouseMoveEvent(Int16(self.weightedDeltaX), Int16(self.weightedDeltaY))
                        self.trackballVelocity = CGPoint(x: self.weightedDeltaX, y: self.weightedDeltaY)
                        self.stopTrackballMomentum()
                    }
                    self.updateTouchLocation(touch: touches.first!)
                }
                break
            case "ABSMOUSE":
                self.weightedDeltaX = Int(self.deltaX * 1.7 * self.sensitivityFactorX)
                self.weightedDeltaY = Int(self.deltaY * 1.7 * self.sensitivityFactorY)
                if self.firstTouchMoved {
                    if !self.absMousePaused {
                        let reachedEdgeMask = LiSendMouseMoveAsMousePositionEvent(Int16(truncatingIfNeeded: self.weightedDeltaX), Int16(truncatingIfNeeded: self.weightedDeltaY), Int16(self.superViewWidth), Int16(self.superViewHeight))
                        if reachedEdgeMask>0 {
                            self.handleMousePadButtonActionUp()
                            self.absMousePaused = true
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.05) {
                                LiSendMousePositionEvent(Int16(self.superViewWidth)/2, Int16(self.superViewHeight)/2, Int16(self.superViewWidth), Int16(self.superViewHeight))
                                self.handleMousePadButtonActionDown()
                                self.absMousePaused = false
                            }
                        }
                    }
                }
                self.updateTouchLocation(touch: touches.first!)
                break
            case "LSPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = 1
                    self.sendLeftStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
                self.updateTouchLocation(touch: touches.first!)
            case "RSPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = 1
                    self.sendRightStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
                self.updateTouchLocation(touch: touches.first!)
            case "LSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX*self.VectorStickFactor*self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY*self.VectorStickFactor*self.sensitivityFactorY)
                    if self.firstTouchMoved {
                        self.sendLeftStickTouchPadEvent(weightedTouchX: CGFloat(self.weightedDeltaX), weightedTouchY: CGFloat(self.weightedDeltaY))
                    }
                    self.updateTouchLocation(touch: touches.first!)
                }
            case "RSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX*self.VectorStickFactor*self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY*self.VectorStickFactor*self.sensitivityFactorY)
                    if self.firstTouchMoved {
                        self.sendRightStickTouchPadEvent(weightedTouchX: CGFloat(self.weightedDeltaX), weightedTouchY: CGFloat(self.weightedDeltaY))
                    }
                    self.updateTouchLocation(touch: touches.first!)
                }
            case "LTPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaY = 1
                    self.sendLeftTriggerTouchPadEvent(inputY: -self.offSetY*4.5*self.sensitivityFactorY)
                    self.updateTouchLocation(touch: touches.first!)
                }
            case "RTPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaY = 1
                    self.sendRightTriggerTouchPadEvent(inputY: -self.offSetY*4.5*self.sensitivityFactorY)
                    self.updateTouchLocation(touch: touches.first!)
                }
            case "DPAD", "WASDPAD", "ARROWPAD":
                self.weightedDeltaX = 1
                handleLrudTouchMove()
                self.updateTouchLocation(touch: touches.first!)
            case "MOUSEWHEEL","WHEEL":
                self.weightedDeltaY = Int(self.deltaY*7.5*self.sensitivityFactorY)
                if firstTouchMoved {LiSendHighResScrollEvent(Int16(self.weightedDeltaY))}
                self.updateTouchLocation(touch: touches.first!)
            case "DISCRETEWHEEL", "DSWHEEL":
                let currentLocation = touches.first!.location(in: self)
                tickFlag = (tickFlag+1)%UInt8(CGFloat(tickCycle)/abs(sensitivityFactorY))
                var delta = self.deltaY
                self.weightedDeltaY = 1
                if delta==0 {self.weightedDeltaY = 0}
                if delta==0 {delta=self.touchBeganLocation.y-currentLocation.y}
                delta = delta * CGFloat(copysign(1.0, sensitivityFactorY))
                if tickFlag == 1, delta != 0 {LiSendScrollEvent(delta > 0 ? -3 : 3)}
                // self.latestTouchLocation = currentLocation
                self.updateTouchLocation(touch: touches.first!)
            default:
                break
            }
        }
        if self.widgetType == WidgetTypeEnum.touchPad && self.touchPadString == "DS4TOUCH" {
            self.handleControllerTouchesMove(touches: touches)
        }
    }
    
    private func handleMousePadButtonActionUp(){
        switch self.mouseButtonAction{
        case .leftButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
        case .middleButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_MIDDLE)
        case .rightButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
        case .hovering:
            if !self.mousePointerMoved && !self.quickDoubleTapDetected {self.sendLongMouseLeftButtonClickEvent()} // deal with single tap(click)
            if self.quickDoubleTapDetected { //deal with quick double tap
                LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT) //must release the button anyway, because the button is likely being held down since the long click turned into a dragging event.
                if !self.mousePointerMoved {self.sendShortMouseLeftButtonClickEvent()}
                self.quickDoubleTapDetected = false
            }
            self.mousePointerMoved = false // reset this flag
        case .noClick:
            // quickDoubleTapDetected = false
            break
        default:
            break
        }
    }
    
    private func handleMousePadButtonActionDown(){
        switch mouseButtonAction{
        case .leftButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_LEFT)
        case .middleButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_MIDDLE)
        case .rightButtonDown:
            LiSendMouseButtonEvent(CChar(BUTTON_ACTION_PRESS), BUTTON_RIGHT)
        case .noClick:
            if quickDoubleTapDetected && !self.comboButtonStrings.isEmpty {
                self.showl3r3Indicator()
                self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)
            }
        case .hovering:
            break
        default:
            break
        }
    }
    
    private func handleMotionControlButtonDown(){
        switch self.motionControlButtonString {
        case "GYRO":
            self.motionHandler.startGyroByOnScreenButton(self, yawFactor: yawFactor, pitchFactor: pitchFactor, rollFactor: rollFactor)
        case "GYROPAUSE":
            self.motionHandler.stopGyroUpdate(interruptNoneGyroInput:false)
            break
        case "ACCEL":
            break
        case "MOTION":
            break
        default:
            break
        }
    }
    
    private func handleMotionControlButtonUp(){
        switch self.motionControlButtonString {
        case "GYRO":
            if let gyroStarter = motionHandler.gyroStarter as? OnScreenWidgetView, self === gyroStarter {
                self.forEachWidget{ widget in
                    if widget.motionControlButtonString != "GYRO" || widget === self {return}
                    if(widget.buttonMode == ButtonMode.tapToToggle.rawValue && widget.logicallyDown) {
                        widget.buttonUpVisualEffect()
                        widget.tapToToggleFlag = !widget.tapToToggleFlag
                    }
                }
                self.motionHandler.stopGyroUpdate(interruptNoneGyroInput: false, resetLeftStick: true)
                self.motionHandler.gyroStarter = nil
            }
            else {
                if self.motionHandler.gyroStarter != nil {
                    if let gyroStarter = motionHandler.gyroStarter as? OnScreenWidgetView {
                        self.motionHandler.startGyroByOnScreenButton(self, yawFactor: gyroStarter.yawFactor, pitchFactor: gyroStarter.pitchFactor, rollFactor: gyroStarter.rollFactor)
                    }
                }
            }
        case "GYROPAUSE":
            if self.motionHandler.gyroStarter != nil {
                self.motionHandler.startGyroByOnScreenButton(self, yawFactor: motionHandler.widgetYawFactor, pitchFactor: motionHandler.widgetPitchFactor, rollFactor: motionHandler.widgetRollFactor)
            }
        case "ACCEL":
            break
        case "MOTION":
            break
        default:
            break
        }
    }
    
    private func handleFunctionalButtonDown(){
        switch self.functionalButtonString {
        case "ABSTCHDRAG":
            let mouseButton = CommandManager.mouseButtonMappings[Set(self.comboButtonStrings).intersection(CommandManager.mouseButtonMappings.keys).first ?? "MLEFT"] ?? BUTTON_LEFT
            print("mouseButton \(mouseButton)");
            self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:mouseButton)
        default:
            break
        }
    }
    
    private func handleFunctionalButtonUp(){
        let longPressed = CACurrentMediaTime() - self.touchTapTimeStamp > 0.3
        if longPressed, buttonMode == ButtonMode.movable.rawValue {return}
        switch self.functionalButtonString {
        case "SETTINGS":
            self.functionalButtonDelegate?.expandSettingsView()
        case "TOOLBOX":
            self.functionalButtonDelegate?.bringUpToolboxMenu()
        case "WIDGETTOOL":
            self.functionalButtonDelegate?.openWidgetLayoutTool()
        case "PROFILES","WIDGETPROFILES":
            self.functionalButtonDelegate?.switchWidgetProfile()
        case "SOFTKEYBOARD":
            self.functionalButtonDelegate?.bringUpSoftKeyboard()
        case "ABSTCHDRAG":
            self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:BUTTON_LEFT)
        default:
            break
        }
    }

    
    private func clearRightStickTouchPadFlag(){
        let mixRightStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.yawPitchToRightStick)
        if !mixRightStickInputToGyro || self.motionHandler.gyroMixInputStarted() != true {
            self.onScreenControls.clearRightStickTouchPadFlag()
        }
        self.motionHandler.mixOnScreenRightStickAndGyroInput(x: 0, y: 0)
    }
    
    private func clearLeftStickTouchPadFlag(){
        let mixLeftStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.rollToLeftStick)
        if !mixLeftStickInputToGyro || self.motionHandler.gyroMixInputStarted() != true {
            self.onScreenControls.clearLeftStickTouchPadFlag()
        }
        self.motionHandler.mixOnScreenLeftStickAndGyroInput(x: 0, y: 0)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.touchBegan = false
        super.touchesEnded(touches, with: event)
                
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        

        if !(CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && self.mouseButtonAction != .noClick) {quickDoubleTapDetected = false} //do not reset this flag here in mousePad mode with button actions

        self.allSpawnedTouchesCount = self.getAllSpawnedTouchesCount(with: event) // this will counts all valid touches within the self widgetView, and excludes touches in other widgetViews
        
        
        // deal with pure MOUSPAD first
        if !OnScreenWidgetView.editMode && self.widgetType == WidgetTypeEnum.touchPad && CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && allSpawnedTouchesCount == 1 && !twoTouchesDetected {
            self.handleMousePadButtonActionUp()
        }
                
        if !OnScreenWidgetView.editMode && self.widgetType == WidgetTypeEnum.touchPad && CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && twoTouchesDetected && touches.count == allSpawnedTouchesCount { // need to enable multi-touch first
            // touches.count == allCapturedTouchesCount means allfingers are lifting
            if(self.mouseButtonAction == MouseButtonAction.hovering) {self.sendMouseRightButtonClickEvent()}
            twoTouchesDetected = false
            firstTouchMoved = false
        }
        
        // then other types of pads or buttons with touchPad function
        if !OnScreenWidgetView.editMode && !self.touchPadString.isEmpty {
            switch self.touchPadString{
            case "LSPAD":
                self.clearLeftStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
            case "RSPAD":
                self.clearRightStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
            case "LSVPAD":
                if self.decelerationRate > 0.50001 {
                    if(!firstTouchMoved) {self.inertialScroller.vector = CGVector(dx: 0, dy: 0)}
                    if self.inertialScroller.handler == nil {
                        self.inertialScroller.handler = {
                            let weightedDeltaX = self.inertialScroller.vector.dx*self.VectorStickFactor*self.sensitivityFactorX
                            let weightedDeltaY = self.inertialScroller.vector.dy*self.VectorStickFactor*self.sensitivityFactorY
                            self.sendLeftStickTouchPadEvent(weightedTouchX: weightedDeltaX, weightedTouchY: weightedDeltaY)
                        }
                    }
                    self.inertialScroller.timer?.restart()
                }
                else {self.clearLeftStickTouchPadFlag()}
            case "RSVPAD":
                if self.decelerationRate > 0.50001 {
                    if(!firstTouchMoved) {self.inertialScroller.vector = CGVector(dx: 0, dy: 0)}
                    if self.inertialScroller.handler == nil {
                        var synthesizedDeltaX:CGFloat = 0
                        var synthesizedDeltaY:CGFloat = 0
                        self.inertialScroller.handler = { [self] in
                            let weightedScrollerVector = CGVector(dx: self.inertialScroller.vector.dx*self.VectorStickFactor*self.sensitivityFactorX, dy: self.inertialScroller.vector.dy*self.VectorStickFactor*self.sensitivityFactorY)

                            if self.motionHandler.gyroMixInputStarted() {
                                let normailizedGyroVector = CGVector(dx: self.stickOffsetToWeightedTouchInput(offset: self.motionHandler.gyroToStickOffset.dx), dy: -self.stickOffsetToWeightedTouchInput(offset: self.motionHandler.gyroToStickOffset.dy))
                                
                                let xConvergent = normailizedGyroVector.dx.sign != weightedScrollerVector.dx.sign && abs(normailizedGyroVector.dx) <= abs(weightedScrollerVector.dx)
                                let yConvergent = normailizedGyroVector.dy.sign != weightedScrollerVector.dy.sign && abs(normailizedGyroVector.dy) <= abs(weightedScrollerVector.dy)
                                
                                synthesizedDeltaX = xConvergent ? normailizedGyroVector.dx + weightedScrollerVector.dx : weightedScrollerVector.dx
                                synthesizedDeltaY = yConvergent ? normailizedGyroVector.dy + weightedScrollerVector.dy : weightedScrollerVector.dy

                                self.inertialScroller.vector.dx = synthesizedDeltaX/(self.VectorStickFactor*self.sensitivityFactorX)
                                self.inertialScroller.vector.dy = synthesizedDeltaY/(self.VectorStickFactor*self.sensitivityFactorY)
                            }
                            self.sendRightStickTouchPadEvent(weightedTouchX: weightedScrollerVector.dx, weightedTouchY: weightedScrollerVector.dy)
                        }
                    }
                    self.inertialScroller.timer?.restart()
                }
                else {self.clearRightStickTouchPadFlag()}
            case "TRACKBALL":
                if allSpawnedTouchesCount == 1, self.decelerationRate > 0 {
                    if(mousePointerMoved){
                        self.startTrackballMomentum()
                        mousePointerMoved = false //reset flag
                    }
                    else{
                        self.stopTrackballMomentum()
                    }
                }
            case "LTPAD":
                self.onScreenControls.updateLeftTrigger(0x00)
            case "RTPAD":
                self.onScreenControls.updateRightTrigger(0x00)
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
        
        if !OnScreenWidgetView.isTweakingHighlightSize {
            if CommandManager.stickTouchPads.contains(touchPadString){
                self.l3r3Indicator.isHidden = true
            }
            
            if CommandManager.directionPads.contains(touchPadString){
                self.upIndicator.isHidden = true
                self.downIndicator.isHidden = true
                self.leftIndicator.isHidden = true
                self.rightIndicator.isHidden = true
                self.lrudIndicatorBall.isHidden = true
            }
            
            if CommandManager.verticalTouchPads.contains(touchPadString){
                self.l3r3Indicator.isHidden = true
            }
            
            if CommandManager.mousePadWithButtonActions.contains(self.touchPadString) && self.mouseButtonAction == .noClick {
                self.l3r3Indicator.isHidden = true
            }
        }
                                
        if !OnScreenWidgetView.editMode && !self.cmdString.contains("+") && !self.comboButtonStrings.isEmpty { // if the command(keystring contains "+", it's a legacy multi-key command
            if self.buttonMode == ButtonMode.slideToToggle.rawValue || self.buttonMode == ButtonMode.slideAndHold.rawValue {
                self.handleFingerUpAfterSliding(touches: touches)
                setLock.lock()
                self.capturedTouches.minus(touches)
                setLock.unlock()
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
        
        if self.buttonMode != ButtonMode.tapToToggle.rawValue {self.handleFingerUpOrSlideout()}
    }
    
    @objc public func setAutoTapIntervalByText(str: String){
        self.autoTapInterval = self.parseTimeToMilliseconds(str)
    }
    
    private func parseTimeToMilliseconds(_ input: String) -> Int {
        // 最大值：24小时对应的毫秒数
        let maxMilliseconds = 24 * 60 * 60 * 1000
        
        // 去除前后空白
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let pattern = #"^(\d+)(ms|s|m)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return 0
        }
        
        let valueRange = Range(match.range(at: 1), in: trimmed)!
        let valueString = String(trimmed[valueRange])
        guard let value = Int(valueString) else { return 0 }
        
        var unit = "ms"
        if let unitRange = Range(match.range(at: 2), in: trimmed) {
            unit = String(trimmed[unitRange])
        }
        
        var milliseconds: Int
        switch unit {
        case "ms":
            milliseconds = value
        case "s":
            milliseconds = value * 1000
        case "m":
            milliseconds = value * 60 * 1000
        default:
            return 0
        }
        
        // 小于 50 ms 的情况返回 0
        if milliseconds < 50 {
            return 0
        }
        
        // 限制最大值
        if milliseconds > maxMilliseconds {
            milliseconds = maxMilliseconds
        }
        
        return milliseconds
    }

    @objc public func getAutoTapIntervalStr() -> String {
        // 边界限制：小于50ms的当作0，超过24小时的限制为24小时
        let maxMilliseconds = 24 * 60 * 60 * 1000
        if autoTapInterval < 50 {
            return ""
        }
        let ms = min(autoTapInterval, maxMilliseconds)
        
        if ms % (60 * 1000) == 0 {
            // 整分钟
            return "\(ms / (60 * 1000))m"
        } else if ms % 1000 == 0 {
            // 整秒
            return "\(ms / 1000)s"
        } else {
            // 毫秒
            return "\(ms)ms"
        }
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            if self.motionControlButtonString == "GYRO" {
                self.motionHandler.stopGyroUpdate(interruptNoneGyroInput: true)
                self.motionHandler.gyroStarter = nil
            }
            if self.motionControlButtonString == "ACCEL" {}
            if self.motionControlButtonString == "MOTION" {}
            
            if self.widgetType == WidgetTypeEnum.button && !OnScreenWidgetView.editMode {
                self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)
                self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:BUTTON_LEFT)
            }
            buttonDownVisualEffectLayer.removeFromSuperlayer()
            
            crossMarkLayer.removeFromSuperlayer()
            lrudIndicatorBall.removeFromSuperlayer()
            l3r3Indicator.removeFromSuperlayer()
            upIndicator.removeFromSuperlayer()
            downIndicator.removeFromSuperlayer()
            leftIndicator.removeFromSuperlayer()
            rightIndicator.removeFromSuperlayer()
            lrudIndicatorBall.removeFromSuperlayer()
            self.inertialScroller.timer?.clean()
            self.clearLeftStickTouchPadFlag()
            self.clearRightStickTouchPadFlag()
            self.autoTapTimer?.clean()
        }
        else{
            self.superViewWidth = (superview?.bounds.size.width)!
            self.superViewHeight = (superview?.bounds.size.height)!
        }
    }
}

