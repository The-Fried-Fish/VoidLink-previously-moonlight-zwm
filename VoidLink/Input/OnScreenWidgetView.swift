//
//  OnScreenWidgetView.swift
//  VoidLink
//
//  Created by True砖家 on 2024/8/4.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

import UIKit
import SVGKit
import ObjectiveC.runtime

@objc class OnScreenWidgetView: UIView {
    @objc(widgetWithCmdString:buttonLabel:shape:profile:)
    class func widget(cmdString: String, buttonLabel: String, shape: String, profile: OSCProfile) -> OnScreenWidgetView {
        return OnScreenWidgetView(cmdString: cmdString, buttonLabel: buttonLabel, shape: shape, profile: profile)
    }

    @objc public static var mapping: [Int16:OnScreenWidgetView] = [:]
    @objc public static var isRestoring: Bool = false
    @objc public static var hasRestoredFromAutoDock: Bool = false
    @objc public static func set(widget:OnScreenWidgetView, for key:Int16) {
        mapping[key] = widget
    }
    @objc public static func widgetFor(key:Int16) -> OnScreenWidgetView? {
        return mapping[key]
    }
    @objc public static func removeWidgetFromMappings(key:Int16) {
        mapping.removeValue(forKey: key)
    }
    @objc public static func clearMappings() {
        mapping.removeAll()
    }
    @objc public static var unfoldedExclusiveFolderSequence:Int16 = -1
    @objc public static var postExclusiveUnfoldedSequences:Set<Int16> = Set()
    @objc public static func setPostExclusiveUnfoldeds(_ sequences:NSSet){
        let sequenceSet:Set<Int16> = sequences as? Set<Int16> ?? Set()
        postExclusiveUnfoldedSequences = Set(sequenceSet)
        // print("postExclusiveUnfoldedSequences \(postExclusiveUnfoldedSequences) \(CACurrentMediaTime())")
    }

    @objc public weak var guidelineDelegate: OnScreenWidgetGuidelineUpdateDelegate?
    @objc protocol OnScreenWidgetGuidelineUpdateDelegate: AnyObject {
        func updateGuidelinesForOnScreenWidget(_ sender: Any)
    }
    
    @objc public var motionHandler: MotionHandler?
    
    @objc public weak var functionalButtonDelegate: OnScreenFunctionalButtonDelegate?
    @objc protocol OnScreenFunctionalButtonDelegate: AnyObject {
        func expandSettingsView()
        func disconnectRemoteSession()
        func disconnectAndQuitApp()
        func enterPip()
        func bringUpToolboxMenu()
        func openWidgetLayoutTool()
        func openWidgetProfileTable(pickProfile: Bool)
        func bringUpSoftKeyboard()
        func alterAbsTouchDragWith(mouseButton:Int32)
        func switchPencilHover()
        func enablePencilHover()
        func disablePencilHover()
        func setAllowSingleTouchEnabled(_ enabled:Bool)
        func replaceBrush(shortcut:String)
        func replaceEraser(shortcut:String)
        func presentPressureCurveVC()
        func toggleTouch(disabled:Bool)
        func toggleGamepadOverlay(overlayEnabled:Bool)
    }
    
    @objc enum WidgetTypeEnum: UInt8 {
        case uninitialized
        case button
        case touchPad
    }
    
    private static let MinAutotapInterval:Int = 50
    
    // private let oscProfileMan: OSCProfilesManager = OSCProfilesManager.sharedManager(CGRectZero)
    @objc public var oscProfile: OSCProfile
    
    @objc public var widgetType: WidgetTypeEnum = WidgetTypeEnum.uninitialized
    
    @objc static public var editMode: Bool = false
    @objc static public var buttonVisualFeedbackEnabled: Bool = true
    @objc public var widgetLabel: String
    private var nonEditableWidgetLabel: String = ""
    @objc public var cmdString: String
    @objc public var sequence: Int16 = -1
    private var buttonString: String = ""
    @objc var functionalButtonString: String = ""
    public var motionControlButtonString: String = ""
    @objc public var touchPadString: String = ""
    // super combo key string set
    @objc public var comboButtonStrings: [String] = []
    private var comboKeyTimeIntervalMs: UInt32 = 0
    
    @objc public var logicallyDown: Bool = false
    @objc public var widthFactor: CGFloat = 1.0
    @objc public var heightFactor: CGFloat = 1.0
    @objc public var componentSizeFactor: CGFloat = 2.88

    @objc public var buttonMode: ButtonMode = .slideToToggle
    @objc private var tapToToggleFlag: Bool = true
    
    @objc public var sizeReference: Int = WidgetSizeReference.longSide.rawValue
    @objc public var baselineDiameter:CGFloat = 0
    private var baselineWidth:CGFloat = 0
    private var baselineHeight:CGFloat = 0
    private var baselineWidthLargeSquare:CGFloat = 0
    private var baselineHeightLargeSquare:CGFloat = 0
    @objc public var denormalizedWidthFactor: CGFloat = 1.0
    @objc public var denormalizedHeightFactor: CGFloat = 1.0
    @objc public var denormalizedComponentSizeFactor: CGFloat = 1.0

    
    @objc public var borderWidth: CGFloat = 0.0
    @objc public var backgroundAlpha: CGFloat = 0.5
    @objc public var componentAlpha: CGFloat = 1
    @objc public var labelAlpha: CGFloat = 0.82
    @objc public var borderAlpha: CGFloat = 0.1
    @objc public var highlightAlpha: CGFloat = 0.77
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
    @objc static var relocatedDuringStreaming: Bool = false

    // for all touchPad or buttons hybrid with touchPads
    @objc public var hasMinStickOffset: Bool = false
    @objc public var hasStickIndicator: Bool = false
    @objc public var hasComponent: Bool = false
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
    @objc public var isFunctionalButton: Bool = false
    @objc public var isTapToToggleException: Bool = false
    @objc public var hasHapticFeedback: Bool = false
    @objc public var isDirectionPad: Bool = false
    @objc public var hasWalkSprintKeys: Bool = false
    @objc public var hasL3R3Indicator: Bool = false
    
    @objc public var isStickWheel: Bool = false
    @objc public var isFolder: Bool = false
    @objc public var hasNonEditableLabel: Bool = false

    // for all stick pads
    @objc public var minStickOffset: CGFloat = 0
    public let stickMaxOffset: CGFloat = 0x7FFE
    public var stickOffsetVector: CGVector = CGVector(dx: 0, dy: 0)
    
    
    // for LSVPAD, RSVPAD
    @objc public var deltaX: CGFloat
    @objc public var deltaY: CGFloat
    
    private let VectorStickFactor = 1.5167
    private var weightedDeltaX: Int = 0
    private var weightedDeltaY: Int = 0

    // for LSPAD, RSPAD
    @objc public var offSetX: CGFloat
    @objc public var offSetY: CGFloat
    private var touchCenteredOffset: Bool = false
    private let crossMarkColor: CGColor = UIColor(white: 1, alpha: 0.70).cgColor
    private let stickBallColor: CGColor = UIColor(white: 1, alpha: 0.75).cgColor
    private var stickInputScale: CGFloat = 35
    @objc public var l3r3Indicator = CAShapeLayer()
    private let stickBallMaxOffset = 18.0
    @objc public var crossMarkLayer = CAShapeLayer()
    
    // LSWHEEL/RSWHEEL
    @objc public var stickWheelLayer = CALayer()
    @objc public var stickWheelLayerSmall = CALayer()
    @objc public var stickWheelAxis = CALayer()
    @objc public var dWheelWalkModeThreshold: CGFloat

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
    private var temporarilyMovable: Bool = false
    private var touchTapTimeInterval: TimeInterval
    private var touchTapTimeStamp: TimeInterval
    private var QUICK_TAP_TIME_INTERVAL = 0.2
    @objc public var stickIndicatorOffset: CGFloat = 120
    
    // for all LRUD pads
    
    @objc public enum WalkSprintKeyActionType: UInt8 {
        case hold
        case toggle
    }
    
    @objc public var keyboardDpadThresholdRef: CGFloat = 300
    @objc public var walkKeyThreshold: CGFloat = 0.08
    @objc public var walkKeyActionType: WalkSprintKeyActionType = .hold
    @objc public var sprintKeyThreshold: CGFloat = 0.6
    @objc public var sprintKeyActionType: WalkSprintKeyActionType = .hold

    @objc public var upIndicator = CAShapeLayer()
    @objc public var downIndicator = CAShapeLayer()
    @objc public var leftIndicator = CAShapeLayer()
    @objc public var rightIndicator = CAShapeLayer()
    @objc public var walkKeyThresholdPreviewLayer = CAShapeLayer()
    @objc public var sprintKeyThresholdPreviewLayer = CAShapeLayer()
    
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
    @objc public var onScreenControls: OnScreenControls?
    
    // key / button label
    private let label: UILabel
    
    // first touch location within the button or pad view (self)
    @objc public var touchBeganLocation: CGPoint = .zero
    
    // for mousePad
    private var touchBegan: Bool = false
    private var directionPadTouchBegan: Bool = false
    private var firstTouchMoved: Bool = false
    private var mousePointerMoved: Bool
    private var twoTouchesDetected: Bool
    private var allSpawnedTouchesCount: Int = 0
    
    // trackball
    private var trackballVelocity: CGPoint = .zero
    private var trackballDecelerationTimer: Timer?
    @objc public var decelerationRateX: CGFloat = 0.5
    @objc public var decelerationRateY: CGFloat = 0.5
    private let trackballVelocityThreshold: CGFloat = 0.1
    
    @objc public var slideThreshold: CGFloat = 6.0
    
    // border & visual effect
    private var minimumBorderAlpha: CGFloat = 0.19
    private var defaultBorderColor: CGColor = UIColor(white: 0.2, alpha: 0.3).cgColor
    // private let voidlinkPurple: CGColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 0.86).cgColor
    private let standardHighlightColor: UIColor = UIColor(
        red: 0.46,
        green: 0.74,
        blue: 0.98,
        alpha: 0.92
    )

    //slide buttons
    private var capturedTouches: NSMutableSet
    let setLock = NSLock()
     
    //controller touch pad
    private var pointerIdPool: Set<UInt32>
    private var pointerIdDict: Dictionary<ObjectIdentifier, UInt32>
    private var activePointerIds: Set<UInt32>
    
    // whole button press down visual effect
    @objc public let buttonDownVisualEffectLayer = CAShapeLayer()
    @objc public var buttonDownVisualEffectStandardWidth: CGFloat
    @objc public var highlightSizeFactor: CGFloat = 1.0
    @objc static public var isTweakingHighlight: Bool = false
    
    // discreteWheels
    private var tickCycle: UInt8 = UIScreen.main.maximumFramesPerSecond > 110 ? 20 : 10
    private var tickFlag: UInt8 = 0

    @objc public var folded: Bool = false
    @objc public var persistedFolded: Bool = false
    @objc public var revealMode: RevealMode = .coexist
    @objc public var bulkMoveEnabled: Bool = false
    @objc public var sequenceSet: Set<Int16> = Set()
    @objc public var parentSequence: Int16 = -1
    static weak var capturer: OnScreenWidgetView?
    
    @objc init(cmdString: String, buttonLabel: String, shape:String, profile:OSCProfile) {

        self.cmdString = cmdString
        self.touchPadString = ""
        
        if !self.cmdString.contains("+"){
            // 安全解包并处理 `comboKeyStrings`
            if var comboStrings = CommandManager.shared.extractCmdStrings(from: self.cmdString) {
                
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
                case "LSPAD", "LSVPAD", "LSWHEEL":
                    self.comboButtonStrings = ["OSCL3"]
                case "RSPAD", "RSVPAD", "RSWHEEL":
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
        self.oscProfile = profile
        self.inertialScroller = InertialScroller()
        dWheelWalkModeThreshold = stickMaxOffset*0.2
        // self.motionHandler = MotionHandler.shared(profile: profile)
        super.init(frame: .zero)
        
        // helps widget panel to hide/show stacks
        self.accessWidgetAttributes()
        
        if self.widgetType == WidgetTypeEnum.button {
            if !self.touchPadString.isEmpty {
                self.mouseButtonAction = MouseButtonAction.noClick
                self.buttonMode = .regular
            }
            if !self.motionControlButtonString.isEmpty {
                self.buttonMode = .tapToToggle
            }
            if self.cmdString.contains("BRUSH"){
                self.functionalButtonString = "BRUSH"
            }
            if self.cmdString.contains("ERASER"){
                self.functionalButtonString = "ERASER"
            }
            if self.isFunctionalButton {
                self.buttonMode = .movable
                if self.functionalButtonString == "PENCILHOVER" {self.buttonMode = .regular}
            }
        }
        
        if self.widgetType == WidgetTypeEnum.touchPad {
            if self.isStickWheel {
                self.widthFactor = 2
                self.heightFactor = 2.6
                self.backgroundAlpha = 1
                self.componentAlpha = self.backgroundAlpha
                self.borderAlpha = 0.05
                self.sensitivityFactorX = 0.42
                self.sensitivityFactorY = 0.42
                self.componentSizeFactor = 2.8
            }
            if self.isDirectionPad {
                self.widthFactor = 2
                self.heightFactor = 2
                self.sensitivityFactorX = 0
                self.sensitivityFactorY = 0
            }
        }
                
        self.tweakBorderAlpha(alpha: self.borderAlpha) // fix default borderAlpha offset
        
        self.onScreenControls = OnScreenControls.shared()

        setupView()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc public func accessWidgetAttributes(){
        self.hasMinStickOffset = (CommandManager.stickTouchPads.contains(self.touchPadString)
                                  || CommandManager.stickWheels.contains(self.touchPadString))
        self.hasStickIndicator = CommandManager.nonVectorStickPads.contains(self.touchPadString) && widgetType == WidgetTypeEnum.touchPad
        self.hasSensitivityX = CommandManager.touchPadCmds.contains(self.touchPadString) && !CommandManager.verticalTouchPads.contains(self.touchPadString)
        self.hasSensitivityY = CommandManager.touchPadCmds.contains(self.touchPadString) && !CommandManager.stickWheels.contains(self.touchPadString)
        self.hasSlideThreshold = CommandManager.mousePads.contains(self.touchPadString)
        
        if CommandManager.bidirectionalVerticalTouchPads.contains(self.touchPadString){
            self.sensitivityYMin = -4.0
            self.sensitivityYMax = 4.0
        }
        
        if CommandManager.mousePads.contains(self.touchPadString){
            self.sensitivityXMin = 0
            self.sensitivityXMax = 16.0
            self.sensitivityYMin = 0
            self.sensitivityYMax = 16.0
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
        self.isFunctionalButton = self.functionalButtonString != "" || self.cmdString.contains("+")
        self.isTapToToggleException = (self.functionalButtonString == "NOSINGLETOUCH"
                                       || self.functionalButtonString == "PENCILHOVER"
                                       || self.functionalButtonString == "ABSTCHDRAG"
                                    )
        self.hasHapticFeedback = !self.comboButtonStrings.isEmpty || CommandManager.directionPads.contains(self.touchPadString)
        self.isDirectionPad = self.widgetType == WidgetTypeEnum.touchPad && CommandManager.directionPads.contains(self.touchPadString)
        self.hasWalkSprintKeys = self.isDirectionPad && (self.touchPadString == "WASDPAD"
                                                         || self.touchPadString == "ARROWPAD")
        self.isStickWheel = self.widgetType == WidgetTypeEnum.touchPad && CommandManager.stickWheels.contains(self.touchPadString)
        self.isFolder = self.cmdString == "FOLDER"
        
        self.hasComponent = self.isStickWheel
        self.hasL3R3Indicator = !self.isStickWheel && !self.isDirectionPad && self.widgetType == WidgetTypeEnum.touchPad
        
        /*
        self.hasTrackPoint = (CommandManager.vectorTouchPads.contains(self.touchPadString)
                              || self.isStickWheel
                              || (self.widgetType == WidgetTypeEnum.button
                                  && (buttonMode == .slideAndHold || buttonMode == .slideToToggle)))*/
        self.hasTrackPoint = true
        self.hasNonEditableLabel = (self.cmdString == "DISABLETOUCH"
                                    || self.cmdString == "GAMEPADOVERLAY")
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
    
    @objc public func setupInertialScroller(fps: Int) {
        if self.hasInertia {
            self.inertialScroller = InertialScroller(decelerationRate: self.decelerationRateX, displayLinkRate: CGFloat(fps))
            self.inertialScroller.decelerationRateY = self.decelerationRateY
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
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        self.backgroundAlpha = alpha
        if self.hasComponent {
            self.componentAlpha = self.backgroundAlpha
            self.tweakAlpha(tweakBorderAlpha: false)
            if self.isStickWheel {self.setupStickWheelLayers()}
        }
        else{
            self.tweakAlpha(tweakBorderAlpha: tweakBorderAlpha)
        }
        
        CATransaction.commit()
    }
    
    @objc public func adjustBorder(width: CGFloat){
        self.borderWidth = width
        self.layer.borderWidth = borderWidth
        // if CommandManager.touchPadCmds.contains(self.keyString) && width == 0 {self.layer.borderWidth = 1}
        if self.shape == "round" {
            //setup round buttons
            self.layer.cornerRadius = self.frame.width/2
            // self.layer.borderWidth = self.borderWidth
            label.minimumScaleFactor = 0.15  // Adjust the scale factor for oscButtons
        }
    }
    
    @objc public func resizeWidgetView(){
        guard let superview = superview else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
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
        updateMovementThresholdPreview()
        
        CATransaction.commit()
    }
    
    @objc public func resizeComponent(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if widgetType == WidgetTypeEnum.touchPad, CommandManager.stickWheels.contains(touchPadString) {
            setupStickWheelLayers()
        }
        CATransaction.commit()
    }
    
    @objc public func tweakLabelAlpha(alpha:CGFloat){
        labelAlpha = alpha
        // label.textColor = UIColor(white: 1.0, alpha: labelAlpha)
        self.setupAtrributedText()
    }
    
    @objc public func tweakBorderAlpha(alpha:CGFloat){
        borderAlpha = alpha
        defaultBorderColor = UIColor(white: borderAlpha>0 ? 0.1 : 0.9, alpha: abs(borderAlpha)).cgColor
        self.layer.borderColor = defaultBorderColor
    }
    
    @objc public func tweakHighlightAlpha(alpha:CGFloat){
        highlightAlpha = alpha
        self.buttonDownVisualEffectLayer.borderColor = standardHighlightColor.withAlphaComponent(highlightAlpha).cgColor
        self.l3r3Indicator.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.lrudIndicatorBall.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.upIndicator.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.downIndicator.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.leftIndicator.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.rightIndicator.borderColor = self.buttonDownVisualEffectLayer.borderColor
        self.walkKeyThresholdPreviewLayer.strokeColor = self.buttonDownVisualEffectLayer.borderColor
        self.sprintKeyThresholdPreviewLayer.strokeColor = self.buttonDownVisualEffectLayer.borderColor
    }

    private func tweakAlpha(tweakBorderAlpha:Bool, tweakLabelAlpha:Bool = true){
        // setup default border from self.backgroundAlpha
        let realBackgroundAlpha = abs(self.backgroundAlpha) - 0.18 // offset to be consistent with legacy onScreen controller layer opacity
        self.backgroundColor = UIColor(white:self.backgroundAlpha>0 ? 0.1 : 0.9, alpha: realBackgroundAlpha) // offset to be consistent with legacy onScreen controller layer opacity
        
        if tweakBorderAlpha {
            borderAlpha = realBackgroundAlpha * 1.01
            defaultBorderColor = UIColor(white: self.backgroundAlpha>0 ? 0.1 : 0.9, alpha: abs(borderAlpha)).cgColor
            self.layer.borderColor = defaultBorderColor
        }
        
        if tweakLabelAlpha {self.tweakLabelAlpha(alpha: backgroundAlpha > 0 ? 0.4 : -0.4)}
        
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
    
    private func getBaselineLenths(){
        let longSideLen = max(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        let shortSideLen = min(UIScreen.main.bounds.width, UIScreen.main.bounds.height)
        
        baselineDiameter = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 60 : 60*shortSideLen/longSideLen
        
        baselineWidth = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 70 : 70*shortSideLen/longSideLen
        baselineHeight = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 65 : 65*shortSideLen/longSideLen
        
        baselineWidthLargeSquare = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 170 : 170*shortSideLen/longSideLen
        baselineHeightLargeSquare = self.sizeReference == WidgetSizeReference.longSide.rawValue ? 150 : 150*shortSideLen/longSideLen
    }
    
    private func getDiameter(lengthFactor:CGFloat) -> CGFloat {
        self.getBaselineLenths()
        let isNormalizedSizeFactor = lengthFactor > 10;
        return isNormalizedSizeFactor ? denormalizeSize(sizeFactor:lengthFactor) : CGFloat(Int(baselineDiameter * lengthFactor / 2) * 2)
    }
    
    private func getRecSize(widthFactor:CGFloat, heightFactor:CGFloat) -> CGSize {
        let isNormalizedSizeFactor = widthFactor > 10;
        let isNormalizedHeightFactor = heightFactor > 10;
        
        self.getBaselineLenths()

        let width = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:widthFactor) :  CGFloat(Int(baselineWidth * widthFactor / 2) * 2)
        let height = isNormalizedHeightFactor ? denormalizeSize(sizeFactor:heightFactor) :  CGFloat(Int(baselineHeight * heightFactor / 2) * 2)
                
        return CGSize(width:width, height: height)
    }
    
    private func getLargeRecSize(widthFactor:CGFloat, heightFactor:CGFloat) -> CGSize {
        let isNormalizedSizeFactor = self.widthFactor > 10;
        let isNormalizedHeightFactor = self.heightFactor > 10;
    
        self.getBaselineLenths()
        
        let width = isNormalizedSizeFactor ? denormalizeSize(sizeFactor:self.widthFactor) :  CGFloat(Int(baselineWidthLargeSquare * self.widthFactor / 2) * 2)
        let height = isNormalizedHeightFactor ? denormalizeSize(sizeFactor:self.heightFactor) :  CGFloat(Int(baselineHeightLargeSquare * self.heightFactor / 2) * 2)

        return CGSize(width:width, height: height)
    }
    

    private func changeAndActivateContraints(){

        if self.shape == "round"{ // we'll make custom osc buttons round & smaller
            let diameter = getDiameter(lengthFactor: self.widthFactor)
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: diameter),
                self.heightAnchor.constraint(equalToConstant: diameter),])
            // 实时调整大小时isNormalized 为 false。加载数据时 isNormalized 为 true
            // baselineDiameter 仅在 实时调整大小时生效，从存储恢复时总是会恢复denormalizeSize()尺寸
            self.denormalizedWidthFactor = diameter/baselineDiameter;
            self.denormalizedHeightFactor = diameter/baselineDiameter;
            //此处的 deNormalized 用于slider显示值
        }
        if self.shape == "square" {
            let widgetSize = getRecSize(widthFactor: self.widthFactor, heightFactor: self.heightFactor)
            autoDockOriginalBoundsSize = widgetSize
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant: widgetSize.width),
                self.heightAnchor.constraint(equalToConstant: widgetSize.height),])
            self.denormalizedWidthFactor = widgetSize.width/baselineWidth;
            self.denormalizedHeightFactor = widgetSize.height/baselineHeight;
        }
        if self.shape == "largeSquare" { // override all shape strings
            let widgetSize = getLargeRecSize(widthFactor: self.widthFactor, heightFactor: self.heightFactor)
            NSLayoutConstraint.activate([
                self.widthAnchor.constraint(equalToConstant:widgetSize.width),
                self.heightAnchor.constraint(equalToConstant:widgetSize.height),])
            self.denormalizedWidthFactor = widgetSize.width/baselineWidthLargeSquare;
            self.denormalizedHeightFactor = widgetSize.height/baselineHeightLargeSquare;
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
    
    func containsNonLatin(_ text: String) -> Bool {
        for scalar in text.unicodeScalars {
            if !(0x0000...0x024F).contains(scalar.value) {
                return true
            }
        }
        return false
    }
    
    @objc func setupAtrributedText(){
        var text = self.widgetLabel.contains("#") ? "\(self.widgetLabel.split(separator: "#").first ?? "")" : SwiftLocalizationHelper.localizedString(forKey: self.widgetLabel)
        
        if !OnScreenWidgetView.editMode, self.widgetType == .touchPad {
            text = ""
        }
        
        if self.hasNonEditableLabel {
            
            switch cmdString {
            case "DISABLETOUCH":
                self.nonEditableWidgetLabel = SwiftLocalizationHelper.localizedString(forKey: touchDisabledFLag ? "=EnableTouch" : "=DisableTouch" )
            case "GAMEPADOVERLAY":
                self.nonEditableWidgetLabel = SwiftLocalizationHelper.localizedString(forKey: OnScreenWidgetView.gamepadOverlayFLag ? "=GamepadOverlayOn" : "=GamepadOverlayOff" )
            default:
                nonEditableWidgetLabel = ""
            }

            text = self.nonEditableWidgetLabel
        }
                
        let attr = NSAttributedString(
            string: self.folded ? "[\(text)]" : text,
            attributes: [
                .foregroundColor: UIColor(white:labelAlpha>0 ? 1.0 : 0, alpha: abs(labelAlpha)),     // 填充色
                .strokeColor: (labelAlpha>0 ? UIColor.black : UIColor.white).withAlphaComponent(abs(labelAlpha)*0.43),          // 描边色
                .strokeWidth: widgetType == .touchPad ? 7 : (containsNonLatin(text) ? -1 : -4)                   // 负值 = 同时填充
            ]
        )
        label.attributedText = attr
        label.textAlignment = .center
    }
    
    private func setupView() {
        // label.text = self.widgetLabel
        // label.font = UIFont.boldSystemFont(ofSize: 19)
        // label.font = UIFont.systemFont(ofSize: 19, weight: .medium, design: .rounded)
        
        let baseFont = UIFont.boldSystemFont(ofSize: self.shape == "round" ? 22 : 19)
        if #available(iOS 13.0, *) {
            if let desc = baseFont.fontDescriptor.withDesign(.rounded) {
                label.font = UIFont(descriptor: desc, size: 0)
            } else {
                label.font = baseFont
            }
        } else {
            label.font = baseFont
        }
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.1  // Adjust the scale factor as needed
        label.textAlignment = .center

        // label.textColor = UIColor(white: 1.0, alpha: labelAlpha)
        // label.shadowColor = .black
        // label.shadowOffset = CGSize(width: 0, height: 0)
        
        self.setupAtrributedText()
                
        label.translatesAutoresizingMaskIntoConstraints = false // enable auto alignment for the label
        label.isHidden = shouldHideStandardLabel()
        
        self.translatesAutoresizingMaskIntoConstraints = true // this is mandatory to prevent unexpected key view location change
        
        self.setSquareWidgetCornerRadius()
        self.layer.borderWidth = self.borderWidth
        
        self.tweakAlpha(tweakBorderAlpha: false, tweakLabelAlpha: false)
        
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
            // if(self.borderWidth < 1) {self.layer.borderWidth = 1}
            // else {self.layer.borderWidth = self.borderWidth}
            self.layer.borderWidth = self.borderWidth
            if OnScreenWidgetView.editMode { //display label in edit mode to make the pad more visible
                // label.text = self.widgetLabel
                if CommandManager.stickWheels.contains(self.touchPadString) {label.isHidden = true}
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
        }
        if self.shape == "square" || self.shape == "largeSquare" {
            //just do nothing here
        }
        
        
        // self.layer.shadowColor = UIColor.clear.cgColor
        // self.layer.shadowRadius = 8
        // self.layer.shadowOpacity = 0.5
        
        addSubview(label)
        _ = installCustomContentIfNeeded()
        
        if(OnScreenWidgetView.editMode) {self.changeAndActivateContraints()}
        
        center = storedCenter //anchor the center while resizing self
        
        hideAllHighlightLayersOfAllWidgets(selfIncluded: false)
        if widgetType == WidgetTypeEnum.button {setupButtonDownVisualEffectLayer()}
        if CommandManager.directionPads.contains(touchPadString) {setupLrudDirectionIndicatorlayers()}
        if CommandManager.stickTouchPads.contains(touchPadString) {setupL3R3Indicator()}
        if CommandManager.verticalTouchPads.contains(touchPadString) {setupL3R3Indicator()}
        if CommandManager.mousePadWithButtonActions.contains(self.touchPadString) {setupL3R3Indicator()}
        if self.hasTrackPoint {setupTrackPoint()}
        if self.hasStickIndicator {
            if self.crossMarkLayer.superlayer == nil {self.crossMarkLayer = createCrossMark()}
            if self.lrudIndicatorBall.superlayer == nil {self.lrudIndicatorBall = createStickBall()}
        }
        if self.isStickWheel {
            self.setupStickWheelLayers()
        }
        if self.isFolder {
            QUICK_TAP_TIME_INTERVAL = 0.15
        }
    }

    @objc func shouldHideStandardLabel() -> Bool {
        false
    }

    @discardableResult
    @objc func installCustomContentIfNeeded() -> Bool {
        false
    }

    @objc func handleQuickDoubleTapAction() -> Bool {
        false
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
        l3r3Indicator.borderColor = standardHighlightColor.cgColor
        self.l3r3Indicator.position = CGPointMake(self.bounds.width/2, self.bounds.height/2)
        if !OnScreenWidgetView.isTweakingHighlight {l3r3Indicator.isHidden = true}
        
        if l3r3Indicator.superlayer == nil {
            self.layer.addSublayer(l3r3Indicator)
        }
        
        CATransaction.commit()
    }
    
    @objc var hasTrackPoint: Bool = false
    @objc static var trackPointEnabled: Bool = false
    private var trackPoint:CAShapeLayer = CAShapeLayer()
    @objc public func setupTrackPoint() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        // 1. 创建圆形路径
        
        
        trackPoint.removeFromSuperlayer()
        trackPoint = GraphicUtils.makeTouchTrackpoint(in: self)
        
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
    /// stickWheel
    private func
    setupStickWheelLayers(){
        
        let diameter = self.getDiameter(lengthFactor: self.componentSizeFactor)
        self.denormalizedComponentSizeFactor = diameter/baselineDiameter
        
        // let tintColor = UIColor(red: 0.5, green: 0.5, blue: 1.0, alpha: 1)
        let tintColor = UIColor(
            red: 0x48 / 255.0,
            green: 0xF5 / 255.0,
            blue: 0xFF / 255.0,
            alpha: componentAlpha
        )

        let axisdiameter = self.getDiameter(lengthFactor: UIDevice.current.userInterfaceIdiom == .phone ? 0.35 : 0.5)
        let axisSize = CGSize(width: axisdiameter, height: axisdiameter)
        self.stickWheelAxis.removeFromSuperlayer()
        self.stickWheelAxis = GraphicUtils.makeSVGLayer(from: "StickWheelAxis", in: self.layer, targetSize: axisSize)
        self.layer.insertSublayer(self.stickWheelAxis, at: 0)
        // GraphicUtils.changeColor(layer: self.stickWheelAxis, color: .white.withAlphaComponent(1))
        self.stickWheelAxis.isHidden = false

        self.stickWheelLayer.removeFromSuperlayer()
        self.stickWheelLayer = GraphicUtils.makeSVGLayer(from: "StickWheel", in: self.layer, targetSize: CGSize(width: diameter, height: diameter))
        self.layer.insertSublayer(self.stickWheelLayer, at: 0)
        GraphicUtils.changeColor(layer: self.stickWheelLayer, color: tintColor)
        self.stickWheelLayer.setAffineTransform(.identity)
        self.stickWheelLayer.isHidden = !OnScreenWidgetView.editMode
        
        
        let smallWheelSize = CGSize(width: diameter*0.56766, height: diameter*0.56766)
        self.stickWheelLayerSmall.removeFromSuperlayer()
        self.stickWheelLayerSmall = GraphicUtils.makeSVGLayer(from: "StickWheelSmall", in: self.layer, targetSize: smallWheelSize)
        self.layer.insertSublayer(self.stickWheelLayerSmall, below: stickWheelLayer)
        GraphicUtils.changeColor(layer: self.stickWheelLayerSmall, color: tintColor)
        self.stickWheelLayerSmall.setAffineTransform(.identity)
        self.stickWheelLayerSmall.isHidden = !OnScreenWidgetView.editMode
        
    }
    
    private func setHiddenForStickWheelLayer(hidden:Bool){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.stickWheelLayer.isHidden = hidden;
        self.stickWheelLayerSmall.isHidden = hidden;
        CATransaction.commit()
    }
    
    private func handleStickWheelMove(touch:UITouch){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        let isInWalkMode = hypot(stickOffsetVector.dx, stickOffsetVector.dy) < dWheelWalkModeThreshold
        
        let angle = atan2(offSetY, offSetX) + .pi/2
        let transform = CGAffineTransform(rotationAngle: angle)
        if isInWalkMode {
            self.stickWheelLayerSmall.setAffineTransform(transform)
        }
        else {
            self.stickWheelLayer.setAffineTransform(transform)
        }
        
        if touch.phase == .began {
            self.stickWheelLayer.isHidden = isInWalkMode
            self.stickWheelLayerSmall.isHidden = !isInWalkMode
        }
        else if self.stickWheelLayer.isHidden != isInWalkMode {
            self.stickWheelLayer.isHidden = isInWalkMode
            self.stickWheelLayerSmall.isHidden = !isInWalkMode
        }
        
        CATransaction.commit()
        
        switch self.touchPadString {
        case "LSWHEEL":
            DispatchQueue.global(qos: .userInteractive).async {
                self.weightedDeltaX = 1
                self.sendLeftStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY, circulate: true)
            }
        case "RSWHEEL":
            DispatchQueue.global(qos: .userInteractive).async {
                self.weightedDeltaX = 1
                self.sendRightStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY, circulate: true)
            }
        default:
            break
        }
    }
    
    
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
        if !OnScreenWidgetView.isTweakingHighlight {lrudIndicatorBall.isHidden = true}
        
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
        directionLayer.borderColor = standardHighlightColor.cgColor
        directionLayer.position = CGPoint(x: self.bounds.width/2, y: self.bounds.height/2)
        if directionLayer.superlayer == nil {
            self.layer.insertSublayer(directionLayer, below: lrudIndicatorBall)
        }
    }
    
    private func showLrudDirectionIndicator(with indicatorLayer:CAShapeLayer){
        // show the indicator based on the touchBeganLocation
        indicatorLayer.position = touchCenteredOffset ? touchBeganLocation : CGPoint(x: self.bounds.midX, y: self.bounds.midY)

        if indicatorLayer.isHidden {
            indicatorLayer.isHidden = false
            if vibrationOn {
                vibrationGenerator.prepare()
                vibrationGenerator.impactOccurred()
            }
        }
    }

    private var previousWalkMode:Bool = false
    private var previousSprintMode:Bool = false
    private func handleLrudTouchMove(){
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        
        
        if self.hasWalkSprintKeys {
            let dist = hypot(self.offSetX, self.offSetY)
            let isInWalkMode = dist < self.walkKeyThreshold * keyboardDpadThresholdRef * 0.5
            let isInSprintMode = dist > self.sprintKeyThreshold * keyboardDpadThresholdRef * 0.5
            
            if (isInSprintMode != previousSprintMode || directionPadTouchBegan)
                , self.comboButtonStrings.count>0 {
                switch sprintKeyActionType {
                case .hold:
                    if isInSprintMode {sendComboButtonsDownEvent(comboStrings: [comboButtonStrings[0]])}
                    else {sendComboButtonsUpEvent(comboStrings: [comboButtonStrings[0]])}
                case .toggle :
                    if directionPadTouchBegan {break}
                    sendComboButtonsDownEvent(comboStrings: [comboButtonStrings[0]])
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.025) {
                        self.sendComboButtonsUpEvent(comboStrings: [self.comboButtonStrings[0]])
                    }
                }
                
                if !directionPadTouchBegan, isInSprintMode, vibrationOn {
                    vibrationGenerator.prepare()
                    vibrationGenerator.impactOccurred()
                }
            }
            
            if (isInWalkMode != previousWalkMode || directionPadTouchBegan)
                , self.comboButtonStrings.count>1 {
                switch walkKeyActionType {
                case .hold:
                    if isInWalkMode {sendComboButtonsDownEvent(comboStrings: [comboButtonStrings[1]])}
                    else {sendComboButtonsUpEvent(comboStrings: [comboButtonStrings[1]])}
                case .toggle :
                    if directionPadTouchBegan {break}
                    sendComboButtonsDownEvent(comboStrings: [comboButtonStrings[1]])
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.025) {
                        self.sendComboButtonsUpEvent(comboStrings: [self.comboButtonStrings[1]])
                    }
                }
                
                if !directionPadTouchBegan, isInWalkMode, vibrationOn {
                    vibrationGenerator.prepare()
                    vibrationGenerator.impactOccurred()
                }
            }
            
            previousWalkMode = isInWalkMode
            previousSprintMode = isInSprintMode
        }
        
        
        let radians  = atan2(-offSetY,offSetX)
        let degrees = radians * 180 / .pi
        
        let nearZeroPoint = sensitivityFactorX == 0 || sensitivityFactorY == 0 ? false : abs(offSetX) < 16/sensitivityFactorX && abs(offSetY) < 16/sensitivityFactorY
        // NSLog("deltaX: %f, detalY: %f", deltaX, deltaY)
        
        if self.stickWheelAxis.isHidden {
            self.stickWheelAxis.isHidden = false
        }
        
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
                case "DPAD": self.onScreenControls?.pressDownControllerButton(UP_FLAG)
                default: break
                }
            }
            else{
                self.upIndicator.isHidden = true
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls?.releaseControllerButton(UP_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.down.rawValue == Direction.down.rawValue){
                showLrudDirectionIndicator(with: downIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls?.pressDownControllerButton(DOWN_FLAG)
                default: break
                }
            }
            else{
                self.downIndicator.isHidden = true
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls?.releaseControllerButton(DOWN_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.left.rawValue == Direction.left.rawValue){
                showLrudDirectionIndicator(with: leftIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls?.pressDownControllerButton(LEFT_FLAG)
                default: break
                }
            }
            else{
                self.leftIndicator.isHidden = true
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls?.releaseControllerButton(LEFT_FLAG)
                default: break
                }
            }
            if(pressedButtonMask & Direction.right.rawValue == Direction.right.rawValue){
                showLrudDirectionIndicator(with: rightIndicator)
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_DOWN), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_DOWN), 0)
                case "DPAD": self.onScreenControls?.pressDownControllerButton(RIGHT_FLAG)
                default: break
                }
            }
            else{
                self.rightIndicator.isHidden = true
                switch touchPadString {
                case "WASDPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_UP), 0)
                case "ARROWPAD": LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                case "DPAD": self.onScreenControls?.releaseControllerButton(RIGHT_FLAG)
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
    
    
    private func handleFingerUpOrSlideout(leaveFunctionalButtonAlone: Bool = false, event: UIEvent? = nil) {
        if autoTapInterval < OnScreenWidgetView.MinAutotapInterval {
            handleButtonUp(leaveFunctionalButtonAlone:leaveFunctionalButtonAlone, event:event)
        }
        else{
            self.autoTapTimer?.pause()
            self.handleButtonUp(leaveFunctionalButtonAlone: leaveFunctionalButtonAlone)
        }
    }
    
    private func handleButtonDown() {
        if !self.isUserInteractionEnabled {return}

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
            if !OnScreenWidgetView.isTweakingHighlight {buttonDownVisualEffectLayer.isHidden = true}
            CATransaction.commit()
        }
    }
    
    private func handleButtonUp(leaveFunctionalButtonAlone:Bool = false, event: UIEvent? = nil) {
        if !self.isUserInteractionEnabled {return}
        if !OnScreenWidgetView.editMode {self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)}
        
        if !OnScreenWidgetView.editMode && !self.motionControlButtonString.isEmpty{
            self.handleMotionControlButtonUp()
        }
        
        self.buttonUpVisualEffect()

        if !OnScreenWidgetView.editMode && !self.functionalButtonString.isEmpty{
            // print("handleFingerUpOrSlideout leaveFunctionalButtonAlone, \(leaveFunctionalButtonAlone) \(CACurrentMediaTime())")
            if !leaveFunctionalButtonAlone {self.handleFunctionalButtonUp(event:event)}
        }
        
        // legacy keyboard button combo connected by "+"
        if !OnScreenWidgetView.editMode && self.cmdString.contains("+") && !self.cmdString.contains("-"){
            if buttonMode == .movable, moveableButtonLongPressed() {return}
            self.buttonDownVisualEffect()
            var autoReleaseComboButtons = CommandManager.shared.extractAutoReleaseButtonStrings(from: self.cmdString)!
            autoReleaseComboButtons.removeAll{
                Set(CommandManager.pencilProButtonCmds).contains($0)
            }
            CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: autoReleaseComboButtons) // send multi-key command
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.buttonUpVisualEffect()
            }
        }
    }
    
    @objc public func setupLrudDirectionIndicatorlayers() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // self.setupLrudBall()
        
        setupLrudDirectionLayer(directionLayer: upIndicator)
        let offset = upIndicator.borderWidth/(2*upIndicator.bounds.width)
        upIndicator.anchorPoint = CGPoint(x: 0.5, y: 1-offset)
        setupLrudDirectionLayer(directionLayer: downIndicator)
        downIndicator.anchorPoint = CGPoint(x: 0.5, y: 0+offset)
        setupLrudDirectionLayer(directionLayer: leftIndicator)
        leftIndicator.anchorPoint = CGPoint(x: 1-offset, y: 0.5)
        setupLrudDirectionLayer(directionLayer: rightIndicator)
        rightIndicator.anchorPoint = CGPoint(x: 0+offset, y: 0.5)
                
        if !OnScreenWidgetView.isTweakingHighlight {
            leftIndicator.isHidden = true
            rightIndicator.isHidden = true
            upIndicator.isHidden = true
            downIndicator.isHidden = true
        }
        
        if !touchCenteredOffset {
            let axisdiameter = self.getDiameter(lengthFactor: UIDevice.current.userInterfaceIdiom == .phone ? 0.27 : 0.35)
            let axisSize = CGSize(width: axisdiameter, height: axisdiameter)
            self.stickWheelAxis.removeFromSuperlayer()
            self.stickWheelAxis = GraphicUtils.makeSVGLayer(from: "StickWheelAxis-0.75", in: self.layer, targetSize: axisSize)
            GraphicUtils.changeColor(layer: self.stickWheelAxis, color: UIColor(white: 1, alpha: 0.5))
            self.layer.addSublayer(self.stickWheelAxis)
            self.stickWheelAxis.isHidden = false
        }

        setupMovementThresholdPreviewLayersIfNeeded()
        updateMovementThresholdPreview()
        
        CATransaction.commit()
    }

    private func setupMovementThresholdPreviewLayersIfNeeded() {
        for previewLayer in [sprintKeyThresholdPreviewLayer, walkKeyThresholdPreviewLayer] {
            previewLayer.fillColor = UIColor.clear.cgColor
            previewLayer.strokeColor = standardHighlightColor.cgColor
            previewLayer.lineWidth = 3
            previewLayer.lineDashPattern = [8, 6]
            previewLayer.isHidden = true
            if previewLayer.superlayer == nil {
                layer.insertSublayer(previewLayer, below: lrudIndicatorBall)
            }
        }
    }

    private func updateMovementThresholdPreview(layer: CAShapeLayer, threshold: CGFloat) {
        let clampedThreshold = max(0, min(1, threshold))
        let diameter: CGFloat = keyboardDpadThresholdRef * clampedThreshold
        let radius = max(diameter / 2, 1)
        layer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        layer.path = UIBezierPath(
            arcCenter: .zero,
            radius: radius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        ).cgPath
    }

    @objc public func updateMovementThresholdPreview() {
        guard isDirectionPad, touchPadString == "WASDPAD" || touchPadString == "ARROWPAD" else {
            walkKeyThresholdPreviewLayer.isHidden = true
            sprintKeyThresholdPreviewLayer.isHidden = true
            return
        }

        setupMovementThresholdPreviewLayersIfNeeded()
        updateMovementThresholdPreview(layer: sprintKeyThresholdPreviewLayer, threshold: sprintKeyThreshold)
        if self.comboButtonStrings.count>1 {updateMovementThresholdPreview(layer: walkKeyThresholdPreviewLayer, threshold: walkKeyThreshold)}

        let shouldShow = OnScreenWidgetView.editMode
        sprintKeyThresholdPreviewLayer.isHidden = !shouldShow
        walkKeyThresholdPreviewLayer.isHidden = !(shouldShow && self.comboButtonStrings.count>1)
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
            widget.walkKeyThresholdPreviewLayer.isHidden = true
            widget.sprintKeyThresholdPreviewLayer.isHidden = true
        }
    }
    
    @objc public func setupButtonDownVisualEffectLayer() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.buttonDownVisualEffectStandardWidth = 8
        if self.shape == "round" {
            if denormalizedWidthFactor < 1.3 {self.buttonDownVisualEffectStandardWidth = 15.3} // wider visual effect for osc buttons
            else {self.buttonDownVisualEffectStandardWidth = 9}
        }
        
        if self.motionControlButtonString != "" {self.buttonDownVisualEffectStandardWidth = 3}
        
        // Set the frame to be larger than the view to expand outward
        buttonDownVisualEffectLayer.borderWidth = CGFloat(Int(self.buttonDownVisualEffectStandardWidth * self.highlightSizeFactor / 2) * 2) // set this 0 to hide the visual effect first
        buttonDownVisualEffectLayer.borderColor = standardHighlightColor.cgColor
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
        if !OnScreenWidgetView.isTweakingHighlight {buttonDownVisualEffectLayer.isHidden = true}
        
        CATransaction.commit()
    }
    //==========================================================================================================
    
    
    //=========================================send on screen controller stick/trigger events
    private func weightedTouchInputToStickOffset(input: CGFloat) -> CGFloat{
        let target = stickMaxOffset * input / stickInputScale
        // return fmax(fmin(target, stickMaxOffset),-stickMaxOffset)
        return target
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
    
    private func sendRightStickTouchPadEvent(weightedTouchX: CGFloat, weightedTouchY: CGFloat, circulate: Bool=false){
        let targetX = self.weightedTouchInputToStickOffset(input: weightedTouchX)
        let targetY = -self.weightedTouchInputToStickOffset(input: weightedTouchY)
        
        let mixRightStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.yawPitchToRightStick)
        if !mixRightStickInputToGyro || (self.motionHandler?.gyroMixInputStarted() != true) {
            
            stickOffsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: targetX, dy: targetY), minOffset: minStickOffset, circulate: circulate)
            self.onScreenControls?.sendRightStickTouchPadEvent(stickOffsetVector.dx, stickOffsetVector.dy)
        }
        self.motionHandler?.mixOnScreenRightStickAndGyroInput(x: targetX, y: targetY)
    }
    
    private func sendLeftStickTouchPadEvent(weightedTouchX:CGFloat, weightedTouchY:CGFloat, circulate:Bool=false){
        let targetX = self.weightedTouchInputToStickOffset(input: weightedTouchX)
        let targetY = -self.weightedTouchInputToStickOffset(input: weightedTouchY)
        
        let mixLeftStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.rollToLeftStick)
        if !mixLeftStickInputToGyro || (self.motionHandler?.gyroMixInputStarted() != true) {
            
            stickOffsetVector = ControllerUtil.compensated(offsetVector: CGVector(dx: targetX, dy: targetY), minOffset: minStickOffset, circulate: circulate)
            self.onScreenControls?.sendLeftStickTouchPadEvent(stickOffsetVector.dx, stickOffsetVector.dy)
        }
        self.motionHandler?.mixOnScreenLeftStickAndGyroInput(x: targetX, y: targetY)
    }
     
    private func sendLeftTriggerTouchPadEvent(inputY: CGFloat){
        self.onScreenControls?.updateLeftTrigger(UInt8(max(min(inputY,255),0)))
    }
    
    private func sendRightTriggerTouchPadEvent(inputY: CGFloat){
        self.onScreenControls?.updateRightTrigger(UInt8(max(min(inputY,255),0)))
    }

    //==========================================================================================================
    
    private func sendOscButtonDownEvent(oscString: String){
        let buttonFlag = CommandManager.oscButtonMappings[oscString]
        if buttonFlag != 0 {self.onScreenControls?.pressDownControllerButton(buttonFlag!)}
        else {switch oscString {
        case "OSCL2", "L2", "LT":
            self.onScreenControls?.updateLeftTrigger(0xFF)
        case "OSCR2", "R2", "RT":
            self.onScreenControls?.updateRightTrigger(0xFF)
        default:break
        }}
    }
    
    private func sendOscButtonUpEvent(oscString: String){
        let buttonFlag = CommandManager.oscButtonMappings[oscString]
        if buttonFlag != 0 {self.onScreenControls?.releaseControllerButton(buttonFlag!)}
        else {switch oscString {
        case "OSCL2", "L2", "LT":
            self.onScreenControls?.updateLeftTrigger(0x00)
        case "OSCR2", "R2", "RT":
            self.onScreenControls?.updateRightTrigger(0x00)
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
        
        guard let touch = touches.first else {return}
        // get touchBeganLocation
        
        if touches.count == 1 { // to make sure touchBegan location captured properly, don't use event.alltouches.count here
            let currentTime = CACurrentMediaTime()
            touchTapTimeInterval = currentTime - touchTapTimeStamp
            touchTapTimeStamp = currentTime
            quickDoubleTapDetected = touchTapTimeInterval < QUICK_TAP_TIME_INTERVAL
            if quickDoubleTapDetected, handleQuickDoubleTapAction() {
                quickDoubleTapDetected = false
                return
            }
            if quickDoubleTapDetected, self.isFolder, self.buttonMode == .slideAndHold {
                self.temporarilyMovable = true
            }
            
            if OnScreenWidgetView.editMode {
                self.touchBeganLocation = touch.location(in: superview)
                self.highlightBorder(highlighted: true)
            }
            else {
                if widgetType == WidgetTypeEnum.button, self.buttonMode == .movable {self.touchBeganLocation = touch.location(in: superview)}
                else {self.touchBeganLocation = touch.location(in: self)}
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
                case "LSWHEEL","RSWHEEL":
                    self.getVector(touch: touch)
                    self.handleStickWheelMove(touch: touch)
                    if quickDoubleTapDetected {
                        self.showl3r3Indicator()
                        self.sendComboButtonsDownEvent(comboStrings: self.comboButtonStrings)}
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
                    if allSpawnedTouchesCount == 1 {
                        // showLrudBall(at: touchBeganLocation)
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        self.stickWheelAxis.position = touchCenteredOffset ? touchBeganLocation : CGPoint(x: self.bounds.midX, y: self.bounds.midY)
                        self.stickWheelAxis.isHidden = false
                        CATransaction.commit()
                        self.getVector(touch: touch)
                        self.handleLrudTouchMove()
                    }
                    if quickDoubleTapDetected && self.touchPadString == "DPAD" {
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
                switch self.buttonMode {
                case .tapToToggle:
                    if(self.tapToToggleFlag) {self.handleTapDownOrSlidein()}
                    else {self.handleFingerUpOrSlideout()}
                    self.tapToToggleFlag = !self.tapToToggleFlag
                case .slideToToggle where !self.isFolder:
                    self.handleButtonSliding(touches: touches)
                case .slideAndHold where !self.isFolder:
                    self.handleButtonSliding(touches: touches)
                default:
                    self.handleTapDownOrSlidein()
                    setLock.lock()
                    self.capturedTouches.union(touches)
                    setLock.unlock()
                }
            }
            
            if self.widgetType == WidgetTypeEnum.button && (self.buttonMode == .movable || self.temporarilyMovable) {
                movableButtonReleased = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    OnScreenWidgetView.updateStreamViewGuidelines(for: self)
                }
            }
        }
        // here is in edit mode:
        else{
            self.handleButtonDown()
            NotificationCenter.default.post(name: Notification.Name("OnScreenWidgetViewSelected"),object: self) // inform layout tool controller to fetch button size factors. self will be passed as the object of the notification
        }
        
        if self.hasTrackPoint, OnScreenWidgetView.trackPointEnabled {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if let touch = touches.first {
                trackPoint.isHidden = false
                trackPoint.position = touch.location(in: self)
            }
            CATransaction.commit()
        }
    }
    
    private func moveByTouch(touch: UITouch){
        let currentLocation: CGPoint
        if OnScreenWidgetView.editMode {
            // self.layer.borderColor = voidlinkPurple
            OnScreenWidgetView.capturer = nil
            currentLocation = touch.location(in: superview)
            forEachWidget { (widget) in
                if widget == self {
                    widget.highlightBorder(highlighted: true, color: standardHighlightColor.cgColor)
                }
                else if widget.isFolder {
                    if isLocation(currentLocation, in: widget), !self.sequenceSet.contains(widget.sequence), !widget.isHidden {
                        // self.layer.borderColor = UIColor.systemYellow.cgColor
                        widget.highlightBorder(highlighted: true)
                        OnScreenWidgetView.capturer = widget
                        return
                    }
                    else {widget.highlightBorder(highlighted: false)}
                }
            }
        }
        else {
            currentLocation = touch.location(in: superview)
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

        if firstTouchMoved {
            center = CGPoint(x: outOfBoundsX ? center.x : center.x+offsetX, y: outOfBoundsY ? center.y : center.y+offsetY)
            storedCenter = center
        }
        
        latestTouchLocation = currentLocation
        
        relocatedDuringStreaming = true
        // center = currentLocation;
        //NSLog("x coord: %f, y coord: %f", self.frame.origin.x, self.frame.origin.y)
        
        if isFolder, bulkMoveEnabled, firstTouchMoved {
            self.moveSubWidgetsInBatch(by: CGVector(dx: offsetX, dy: offsetY))
        }
        
        if OnScreenWidgetView.editMode {
            guidelineDelegate?.updateGuidelinesForOnScreenWidget(self)
        }
        else {
            if self.widgetType == .button {superview?.bringSubviewToFront(self)}
            OnScreenWidgetView.updateStreamViewGuidelines(for: self)
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

    private func handleFingerUpAfterSliding(touches: Set<UITouch>, event: UIEvent? = nil) {
        func processWidget(_ widget: OnScreenWidgetView , with touch: UITouch) {
            setLock.lock()
            let captured = widget.capturedTouches.contains(touch)
            setLock.unlock()
            if !captured || widget.buttonMode == .regular {return}
            // let needReleaseButton =  (isLocation(touch.location(in: superview), in: widget) // for slideToToggle & movable+slidable buttons
            //                           || widget.buttonMode == .slideAndHold) // for slideAndHold buttons
            widget.handleFingerUpOrSlideout(event: event)
            setLock.lock()
            widget.capturedTouches.remove(touch)
            setLock.unlock()
        }
        
        // only called by self
        for touch in touches {
            var exclusiveFolders: Set<OnScreenWidgetView> = Set()
            self.forEachWidget(){ widget in // self included here.
                guard widget.revealMode != .exclusive || !isLocation(touch.location(in: superview), in: widget) else {
                    exclusiveFolders.insert(widget)
                    return
                }
                processWidget(widget, with: touch)
            }
            for folder in exclusiveFolders {
                processWidget(folder, with: touch)
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
    
    private func isLocation(_ location:CGPoint, in widget:OnScreenWidgetView) -> Bool{
        let locationInWidget = widget.convert(location, from: self.superview)
        return widget.bounds.contains(locationInWidget)
    }

    private func handleButtonSliding(touches: Set<UITouch>) {
        for touch in touches {
            let locationInSuperView = touch.location(in: self.superview)
            self.forEachWidget{ widget in
                if widget.widgetType != WidgetTypeEnum.button {return}
                let isSlidableButton = (widget.buttonMode == .slideToToggle
                                        || widget.buttonMode == .slideAndHold
                                        || (widget.buttonMode == .movable && widget != self)
                )
                if isLocation(locationInSuperView, in: widget){
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
                    if(widget.buttonMode == .slideToToggle || widget.buttonMode == .movable){
                        widget.handleFingerUpOrSlideout(leaveFunctionalButtonAlone: widget.isFunctionalButton)
                        setLock.lock()
                        widget.capturedTouches.remove(touch)
                        setLock.unlock()
                    }
                    if(widget.buttonMode == .slideAndHold){
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
                if self.buttonMode == .slideToToggle || self.buttonMode == .slideAndHold  {self.handleButtonSliding(touches: touches)}
            }

            if (self.buttonMode == .movable || self.temporarilyMovable) && self.moveableButtonLongPressed() {
                if let touch = touches.first {
                    self.moveByTouch(touch: touch)
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
        
        if self.hasTrackPoint, OnScreenWidgetView.trackPointEnabled {
            if let touch = touches.first {
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                if trackPoint.isHidden {
                    trackPoint.isHidden = false
                }
                trackPoint.position = touch.location(in: self)
                CATransaction.commit()
            }
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
        
        touchCenteredOffset = (!self.isStickWheel
                             && !(self.isDirectionPad && sensitivityFactorX==0 && sensitivityFactorY==0))
        self.offSetX = touchCenteredOffset ? currentTouchLocation.x - self.touchBeganLocation.x : currentTouchLocation.x - self.bounds.midX
        self.offSetY = touchCenteredOffset ? currentTouchLocation.y - self.touchBeganLocation.y : currentTouchLocation.y - self.bounds.midY
    }
    
    private func updateTouchLocation(touch: UITouch){
        let currentTouchLocation: CGPoint = (touch.location(in: self))
        if weightedDeltaX != 0 || weightedDeltaY != 0 {
            self.latestTouchLocation = currentTouchLocation
        }
    }
    
    private func handleTouchPadMoveEvent (_ touches: Set<UITouch>, with event: UIEvent?){
        guard let touch = touches.first else { return }
        if touches.count == 1{ // don't use event.alltouches.count here, it will counts all touches
            self.getVector(touch: touch)
            switch self.touchPadString{
            case "MOUSEPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX * 1.7 * self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY * 1.7 * self.sensitivityFactorY)
                    if self.firstTouchMoved {LiSendMouseMoveEvent(Int16(self.weightedDeltaX), Int16(self.weightedDeltaY))}
                    self.updateTouchLocation(touch: touch)
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
                    self.updateTouchLocation(touch: touch)
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
                self.updateTouchLocation(touch: touch)
                break
            case "LSWHEEL", "RSWHEEL":
                self.handleStickWheelMove(touch: touch)
            case "LSPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = 1
                    self.sendLeftStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
                self.updateTouchLocation(touch: touch)
            case "RSPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = 1
                    self.sendRightStickTouchPadEvent(weightedTouchX: self.offSetX * self.sensitivityFactorX, weightedTouchY: self.offSetY * self.sensitivityFactorY)
                }
                if widgetType == WidgetTypeEnum.touchPad {updateStickIndicator()}
                self.updateTouchLocation(touch: touch)
            case "LSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX*self.VectorStickFactor*self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY*self.VectorStickFactor*self.sensitivityFactorY)
                    if self.firstTouchMoved {
                        self.sendLeftStickTouchPadEvent(weightedTouchX: CGFloat(self.weightedDeltaX), weightedTouchY: CGFloat(self.weightedDeltaY))
                    }
                    self.updateTouchLocation(touch: touch)
                }
            case "RSVPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaX = Int(self.deltaX*self.VectorStickFactor*self.sensitivityFactorX)
                    self.weightedDeltaY = Int(self.deltaY*self.VectorStickFactor*self.sensitivityFactorY)
                    if self.firstTouchMoved {
                        self.sendRightStickTouchPadEvent(weightedTouchX: CGFloat(self.weightedDeltaX), weightedTouchY: CGFloat(self.weightedDeltaY))
                    }
                    self.updateTouchLocation(touch: touch)
                }
            case "LTPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaY = 1
                    self.sendLeftTriggerTouchPadEvent(inputY: -self.offSetY*4.5*self.sensitivityFactorY)
                    self.updateTouchLocation(touch: touch)
                }
            case "RTPAD":
                DispatchQueue.global(qos: .userInteractive).async {
                    self.weightedDeltaY = 1
                    self.sendRightTriggerTouchPadEvent(inputY: -self.offSetY*4.5*self.sensitivityFactorY)
                    self.updateTouchLocation(touch: touch)
                }
            case "DPAD", "WASDPAD", "ARROWPAD":
                self.weightedDeltaX = 1
                handleLrudTouchMove()
                self.updateTouchLocation(touch: touch)
            case "MOUSEWHEEL","WHEEL":
                self.weightedDeltaY = Int(self.deltaY*7.5*self.sensitivityFactorY)
                if firstTouchMoved {LiSendHighResScrollEvent(Int16(self.weightedDeltaY))}
                self.updateTouchLocation(touch: touch)
            case "DISCRETEWHEEL", "DSWHEEL":
                let currentLocation = touch.location(in: self)
                tickFlag = (tickFlag+1)%UInt8(CGFloat(tickCycle)/abs(sensitivityFactorY))
                var delta = self.deltaY
                self.weightedDeltaY = 1
                if delta==0 {self.weightedDeltaY = 0}
                if delta==0 {delta=self.touchBeganLocation.y-currentLocation.y}
                delta = delta * CGFloat(copysign(1.0, sensitivityFactorY))
                if tickFlag == 1, delta != 0 {LiSendScrollEvent(delta > 0 ? -3 : 3)}
                // self.latestTouchLocation = currentLocation
                self.updateTouchLocation(touch: touch)
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
            self.motionHandler?.startGyroByOnScreenButton(self, yawFactor: yawFactor, pitchFactor: pitchFactor, rollFactor: rollFactor)
        case "GYROPAUSE":
            self.motionHandler?.stopGyroUpdate(interruptNoneGyroInput:false)
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
            if let gyroStarter = motionHandler?.gyroStarter as? OnScreenWidgetView, self === gyroStarter {
                self.forEachWidget{ widget in
                    if widget.motionControlButtonString != "GYRO" || widget === self {return}
                    if(widget.buttonMode == .tapToToggle && widget.logicallyDown) {
                        widget.buttonUpVisualEffect()
                        widget.tapToToggleFlag = !widget.tapToToggleFlag
                    }
                }
                self.motionHandler?.stopGyroUpdate(interruptNoneGyroInput: false, resetLeftStick: true)
                self.motionHandler?.gyroStarter = nil
            }
            else {
                if self.motionHandler?.gyroStarter != nil {
                    if let gyroStarter = motionHandler?.gyroStarter as? OnScreenWidgetView {
                        self.motionHandler?.startGyroByOnScreenButton(self, yawFactor: gyroStarter.yawFactor, pitchFactor: gyroStarter.pitchFactor, rollFactor: gyroStarter.rollFactor)
                    }
                }
            }
        case "GYROPAUSE":
            if self.motionHandler?.gyroStarter != nil {
                self.motionHandler?.startGyroByOnScreenButton(self, yawFactor: motionHandler?.widgetYawFactor ?? 0, pitchFactor: motionHandler?.widgetPitchFactor ?? 0, rollFactor: motionHandler?.widgetRollFactor ?? 0)
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
        if autoDockIsDocked {return}
        switch self.functionalButtonString {
        case "FOLDER":
            if self.buttonMode != .slideAndHold {break}
            self.folded = false
            OnScreenWidgetView.set(folded: false, for: self)
        case "ABSTCHDRAG":
            let mouseButton = CommandManager.mouseButtonMappings[Set(self.comboButtonStrings).intersection(CommandManager.mouseButtonMappings.keys).first ?? "MLEFT"] ?? BUTTON_LEFT
            print("mouseButton \(mouseButton)");
            self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:mouseButton)
        case "PENCILHOVER":
            if !self.isPencilProEnabled() {break}
            self.functionalButtonDelegate?.enablePencilHover()
        case "NOSINGLETOUCH":
            if !self.isPencilProEnabled() {break}
            self.functionalButtonDelegate?.setAllowSingleTouchEnabled(false)
        default:
            break
        }
    }
    
    private var movableButtonReleased:Bool = true
    private func moveableButtonLongPressed() -> Bool{
        return !movableButtonReleased && CACurrentMediaTime() - self.touchTapTimeStamp > 0.3
    }
    
    private var singleTouchEnabled:Bool = true
    
    private func handleFunctionalButtonUp(event: UIEvent? = nil){
        // print("handleFunctionalButtonUp \(self.widgetLabel), event Empty: \(String(describing: event)), \(CACurrentMediaTime())")
        if autoDockIsDocked {return}
        if buttonMode == .movable {
            if moveableButtonLongPressed() && !UITouchUtil.touches(in: self, from: event).isEmpty {return}
            switch self.functionalButtonString {
            // case "FOLDER":
            //    self.folded = !self.folded
            //    OnScreenWidgetView.set(folded: self.folded, for: self)
            case "NOSINGLETOUCH":
                if !self.isPencilProEnabled() {break}
                singleTouchEnabled = !singleTouchEnabled
                self.functionalButtonDelegate?.setAllowSingleTouchEnabled(singleTouchEnabled)
                return
            default:
                break
            }
        }
        switch self.functionalButtonString {
        case "FOLDER":
            self.folded = !self.folded
            OnScreenWidgetView.set(folded: self.folded, for: self)
        case "SETTINGS":
            temporaryDisableFolderButtonAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.expandSettingsView()
            }
        case "DISCONNECT":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.disconnectRemoteSession()
            }
        case "QUITAPP":
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.disconnectAndQuitApp()
            }
        case "TOOLBOX":
            self.functionalButtonDelegate?.bringUpToolboxMenu()
        case "PIP":
            self.functionalButtonDelegate?.enterPip()
        case "WIDGETTOOL":
            temporaryDisableFolderButtonAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.openWidgetLayoutTool()
            }
        case "PROFILES","WIDGETPROFILES":
            temporaryDisableFolderButtonAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.openWidgetProfileTable(pickProfile: false)
            }
        case "PICKPROFILE","PICKPRFL":
            temporaryDisableFolderButtonAnimation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.functionalButtonDelegate?.openWidgetProfileTable(pickProfile: true)
            }
        case "SOFTKEYBOARD":
            self.functionalButtonDelegate?.bringUpSoftKeyboard()
        case "ABSTCHDRAG":
            self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:BUTTON_LEFT)
        case "PENCILHOVER":
            if !self.isPencilProEnabled() {break}
            self.functionalButtonDelegate?.disablePencilHover()
        case "NOSINGLETOUCH":
            if !self.isPencilProEnabled() {break}
            self.functionalButtonDelegate?.setAllowSingleTouchEnabled(true)
        case "BRUSH":
            if !self.isPencilProEnabled() {break}
            var brushShortcut = self.cmdString.replacingOccurrences(of: "BRUSH+", with: "")
            brushShortcut = brushShortcut.replacingOccurrences(of: "BRUSH", with: "")
            self.functionalButtonDelegate?.replaceBrush(shortcut: brushShortcut)
        case "ERASER":
            if !self.isPencilProEnabled() {break}
            var eraserShortcut = self.cmdString.replacingOccurrences(of: "ERASER+", with: "")
            eraserShortcut = eraserShortcut.replacingOccurrences(of: "ERASER", with: "")
            self.functionalButtonDelegate?.replaceEraser(shortcut: eraserShortcut)
        case "PRESSURECURVE":
            if ["com.voidlink.iOS"
                , "com.voidlinkextreme.iOS"
                , "com.voidlink.tf.debug10.iOS"
            ].contains(Bundle.main.bundleIdentifier) && GenericUtils.isIPad() {
                self.functionalButtonDelegate?.presentPressureCurveVC()
            }
        case "DISABLETOUCH":
            self.handleTouchDisableButtonUp()
        case "GAMEPADOVERLAY":
            self.gamepadOverlayButtonUp()
        default:
            break
        }
    }
    
    private var touchDisabledFLag:Bool = false
    private func handleTouchDisableButtonUp(){
        touchDisabledFLag = !touchDisabledFLag
        self.setupAtrributedText()
        self.functionalButtonDelegate?.toggleTouch(disabled: touchDisabledFLag)
    }
    
    @objc static var gamepadOverlayFLag:Bool = false
    private func gamepadOverlayButtonUp(){
        self.relocatedDuringStreaming = true
        OnScreenWidgetView.gamepadOverlayFLag = !OnScreenWidgetView.gamepadOverlayFLag
        self.setupAtrributedText()
        if #available(iOS 13.0, *) {
            self.functionalButtonDelegate?.toggleGamepadOverlay(overlayEnabled: OnScreenWidgetView.gamepadOverlayFLag)
        }
    }

    private func temporaryDisableFolderButtonAnimation(){
        OnScreenWidgetView.enableFolderAnimation = false
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + 0.17) {
            OnScreenWidgetView.enableFolderAnimation = true
        }
    }
    
    private func clearRightStickTouchPadFlag(){
        let mixRightStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.yawPitchToRightStick)
        if !mixRightStickInputToGyro || self.motionHandler?.gyroMixInputStarted() != true {
            self.onScreenControls?.clearRightStickTouchPadFlag()
        }
        self.motionHandler?.mixOnScreenRightStickAndGyroInput(x: 0, y: 0)
    }
    
    private func clearLeftStickTouchPadFlag(){
        let mixLeftStickInputToGyro = (oscProfile.mapGyroTo == MapGyroTo.mapGyroToControllerStick
                                       && oscProfile.rollToLeftStick)
        if !mixLeftStickInputToGyro || self.motionHandler?.gyroMixInputStarted() != true {
            self.onScreenControls?.clearLeftStickTouchPadFlag()
        }
        self.motionHandler?.mixOnScreenLeftStickAndGyroInput(x: 0, y: 0)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }
    
    private func inertiaEnabled() -> Bool {
        return self.decelerationRateX > 0.50001 || self.decelerationRateY > 0.50001
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
            case "LSWHEEL":
                self.clearLeftStickTouchPadFlag()
                self.setHiddenForStickWheelLayer(hidden: true)
            case "RSWHEEL":
                self.clearRightStickTouchPadFlag()
                self.setHiddenForStickWheelLayer(hidden: true)
            case "LSPAD":
                self.clearLeftStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
            case "RSPAD":
                self.clearRightStickTouchPadFlag()
                if widgetType == WidgetTypeEnum.touchPad {self.resetStickBallPositionAndHideIndicator()}
            case "LSVPAD":
                if self.inertiaEnabled() {
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
                if self.inertiaEnabled() {
                    if(!firstTouchMoved) {self.inertialScroller.vector = CGVector(dx: 0, dy: 0)}
                    if self.inertialScroller.handler == nil {
                        var synthesizedDeltaX:CGFloat = 0
                        var synthesizedDeltaY:CGFloat = 0
                        self.inertialScroller.handler = { [self] in
                            let weightedScrollerVector = CGVector(dx: self.inertialScroller.vector.dx*self.VectorStickFactor*self.sensitivityFactorX, dy: self.inertialScroller.vector.dy*self.VectorStickFactor*self.sensitivityFactorY)

                            if ((self.motionHandler?.gyroMixInputStarted()) == true) {
                                let normailizedGyroVector = CGVector(dx: self.stickOffsetToWeightedTouchInput(offset: self.motionHandler?.gyroToStickOffset.dx ?? 0), dy: -self.stickOffsetToWeightedTouchInput(offset: self.motionHandler?.gyroToStickOffset.dy ?? 0))
                                
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
                if allSpawnedTouchesCount == 1, self.inertiaEnabled() {
                    if(mousePointerMoved){
                        self.startTrackballMomentum()
                        mousePointerMoved = false //reset flag
                    }
                    else{
                        self.stopTrackballMomentum()
                    }
                }
            case "LTPAD":
                self.onScreenControls?.updateLeftTrigger(0x00)
            case "RTPAD":
                self.onScreenControls?.updateRightTrigger(0x00)
            case "WASDPAD":
                self.stickWheelAxis.isHidden = touchCenteredOffset
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["W"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["A"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["S"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["D"]!,Int8(KEY_ACTION_UP), 0)
            case "ARROWPAD":
                self.stickWheelAxis.isHidden = touchCenteredOffset
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["LEFT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["RIGHT_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["UP_ARROW"]!,Int8(KEY_ACTION_UP), 0)
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["DOWN_ARROW"]!,Int8(KEY_ACTION_UP), 0)
            case "DPAD":
                self.stickWheelAxis.isHidden = touchCenteredOffset
                self.onScreenControls?.releaseControllerButton(LEFT_FLAG)
                self.onScreenControls?.releaseControllerButton(RIGHT_FLAG)
                self.onScreenControls?.releaseControllerButton(UP_FLAG)
                self.onScreenControls?.releaseControllerButton(DOWN_FLAG)
            case "DS4TOUCH":
                self.handleControllerTouchesUp(touches: touches)
            default:
                break
            }
            if self.widgetType == .touchPad {
                self.handleButtonUp()
            }
        }
                
        if !OnScreenWidgetView.isTweakingHighlight {
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
            // print("self.comboButtonStrings \(self.comboButtonStrings),\(CACurrentMediaTime())")
            if self.buttonMode == .slideToToggle || self.buttonMode == .slideAndHold {
                self.handleFingerUpAfterSliding(touches: touches, event: event)
                setLock.lock()
                self.capturedTouches.minus(touches)
                setLock.unlock()
            }
        }
        
        if !OnScreenWidgetView.editMode && (self.buttonMode != .tapToToggle
            && self.buttonMode != .slideToToggle
            && self.buttonMode != .slideAndHold
            && self == touches.first?.view) {self.handleFingerUpOrSlideout(event:event)}
        
        if !OnScreenWidgetView.editMode && (self.buttonMode == .movable || self.temporarilyMovable) {
            movableButtonReleased = true
            OnScreenWidgetView.removeStreamViewGuidelines()
            for sequence in self.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence]
                if widget?.isHidden == true {widget?.center = self.center}
            }
        }
        
        if self.hasTrackPoint, OnScreenWidgetView.trackPointEnabled {
            trackPoint.isHidden = true
        }
        
        self.temporarilyMovable = false

        CATransaction.commit()
        
        if OnScreenWidgetView.editMode {
            storedCenter = center // Update initial center for next movement
            if center != layoutChanges.last {
                layoutChanges.append(center)
            }
            
            if OnScreenWidgetView.capturer != nil {
                if firstTouchMoved {undoRelocation()}
                if let capturer = OnScreenWidgetView.capturer {
                    capturer.highlightBorder(highlighted: false)
                    OnScreenWidgetView.putWidget(self, into: capturer)
                }
            }
            OnScreenWidgetView.capturer = nil

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
            
            self.highlightBorder(highlighted: false)
            
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
    
    static private func setBorder(highlighted:Bool, in color:CGColor, for widget:OnScreenWidgetView){
        let highlighted = highlighted || widget == OnScreenWidgetView.capturer
        if highlighted {
            widget.layer.borderWidth = 3
            widget.layer.borderColor = color
        }
        else {
            widget.layer.borderWidth = widget.borderWidth
            widget.layer.borderColor = widget.defaultBorderColor
        }
    }
    
    private func highlightBorder(highlighted:Bool, color:CGColor? = nil) {
        if self.isFolder {
            OnScreenWidgetView.setBorder(highlighted: highlighted, in: UIColor.systemYellow.cgColor, for: self)
            self.forEachWidget{ widget in
                if self.sequenceSet.contains(widget.sequence) {
                    OnScreenWidgetView.setBorder(highlighted: highlighted, in: UIColor.systemYellow.cgColor, for: widget)
                }
            }
            return
        }
        
        OnScreenWidgetView.setBorder(highlighted: highlighted, in: color ?? standardHighlightColor.cgColor, for: self)
    }
    
    private func isPencilProEnabled() -> Bool {
        if !(PencilHandler.shared?.pencilProEnabled ?? false) {
            IAPManager.shared.purchase(AddOnProduct.PencilProPack)
            return false
        }
        return true
    }
    
    // MARK: - Auto Dock
    private static let autoDockExposedEdgeLength: CGFloat = GenericUtils.isIPhone() ? 90 : 90
    private static let autoDockExposedThickness: CGFloat = 22
    private static let autoDockVerticalInset: CGFloat = 12
    @objc var autoDockIdleDuration: TimeInterval = 0
    @objc var storedAutoDockIdleDuration: TimeInterval = 0
    private static let autoDockInitialAlpha: CGFloat = 0.8
    @objc var autoDockSettledAlpha: CGFloat = 0.2
    private static let autoDockSettledAlphaDelay: TimeInterval = 2
    private static let autoDockReturnDamping: CGFloat = 0.9
    private static let autoDockGoDamping: CGFloat = 0.82
    private typealias TouchesIMP = @convention(c) (AnyObject, Selector, Set<UITouch>, UIEvent?) -> Void
    private static var autoDockOriginalTouchesBeganIMP: TouchesIMP?
    private static var autoDockOriginalTouchesMovedIMP: TouchesIMP?
    private static var autoDockOriginalTouchesEndedIMP: TouchesIMP?
    private static var autoDockOriginalTouchesCancelledIMP: TouchesIMP?
    private static let autoDockSwizzlingInstalled: Void = {
        let cls: AnyClass = OnScreenWidgetView.self
        func swizzle(_ originalSelector: Selector, _ swizzledSelector: Selector) -> TouchesIMP? {
            guard let originalMethod = class_getInstanceMethod(cls, originalSelector),
                  let swizzledMethod = class_getInstanceMethod(cls, swizzledSelector) else { return nil }
            let originalIMP = unsafeBitCast(method_getImplementation(originalMethod), to: TouchesIMP.self)
            method_exchangeImplementations(originalMethod, swizzledMethod)
            return originalIMP
        }
        autoDockOriginalTouchesBeganIMP = swizzle(#selector(OnScreenWidgetView.touchesBegan(_:with:)), #selector(OnScreenWidgetView.vl_autoDock_touchesBegan(_:with:)))
        autoDockOriginalTouchesMovedIMP = swizzle(#selector(OnScreenWidgetView.touchesMoved(_:with:)), #selector(OnScreenWidgetView.vl_autoDock_touchesMoved(_:with:)))
        autoDockOriginalTouchesEndedIMP = swizzle(#selector(OnScreenWidgetView.touchesEnded(_:with:)), #selector(OnScreenWidgetView.vl_autoDock_touchesEnded(_:with:)))
        autoDockOriginalTouchesCancelledIMP = swizzle(#selector(OnScreenWidgetView.touchesCancelled(_:with:)), #selector(OnScreenWidgetView.vl_autoDock_touchesCancelled(_:with:)))
    }()
    
    private var autoDockTimer: Timer?
    // private var autoDockStoredCenter: CGPoint?
    private var autoDockDockedCenter: CGPoint?
    private var autoDockDockedToBottomEdge: Bool = false
    private var autoDockDistance: CGFloat = 3
    @objc var autoDockIsDocked: Bool = false
    @objc var autoDockEnabled: Bool = false
    private var autoDockSettledAlphaTimer: Timer?
    private var autoDockOriginalBoundsSize: CGSize = .zero
    
    private static func installAutoDockIfNeeded() {
        _ = autoDockSwizzlingInstalled
    }
    
    @objc private func vl_autoDock_touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard autoDockEnabled else {
            OnScreenWidgetView.autoDockOriginalTouchesBeganIMP?(self, #selector(OnScreenWidgetView.touchesBegan(_:with:)), touches, event)
            return
        }
        if autoDockIsDocked {
            autoDockRestoreWidget(animated: true)
            return
        }
        autoDockStopCountdown()
        OnScreenWidgetView.autoDockOriginalTouchesBeganIMP?(self, #selector(OnScreenWidgetView.touchesBegan(_:with:)), touches, event)
    }
    
    @objc private func vl_autoDock_touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard autoDockEnabled else {
            OnScreenWidgetView.autoDockOriginalTouchesMovedIMP?(self, #selector(OnScreenWidgetView.touchesMoved(_:with:)), touches, event)
            return
        }
        if autoDockIsDocked {
            return
        }
        autoDockStopCountdown()
        OnScreenWidgetView.autoDockOriginalTouchesMovedIMP?(self, #selector(OnScreenWidgetView.touchesMoved(_:with:)), touches, event)
    }
    
    @objc private func vl_autoDock_touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        OnScreenWidgetView.autoDockOriginalTouchesEndedIMP?(self, #selector(OnScreenWidgetView.touchesEnded(_:with:)), touches, event)
        guard autoDockEnabled else { return }
        if OnScreenWidgetView.hasRestoredFromAutoDock {
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.02){
                OnScreenWidgetView.hasRestoredFromAutoDock = false
            }
        }
        autoDockRestartCountdownIfNeeded()
    }
    
    @objc private func vl_autoDock_touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        OnScreenWidgetView.autoDockOriginalTouchesCancelledIMP?(self, #selector(OnScreenWidgetView.touchesCancelled(_:with:)), touches, event)
        guard autoDockEnabled else { return }
        autoDockRestartCountdownIfNeeded()
    }
    
    @objc public func setAutoDock(enabled: Bool) {
        autoDockEnabled = enabled
        if enabled {
            OnScreenWidgetView.installAutoDockIfNeeded()
            autoDockRestartCountdownIfNeeded()
        }
        else {
            autoDockStopCountdown()
            autoDockStopSettledAlphaTimer()
            if autoDockIsDocked {
                autoDockRestoreWidget(animated: false)
            }
            autoDockRestoreOriginalSize()
            label.alpha = 1
            autoDockRestoreOriginalAlpha()
        }
    }
    
    @objc public func restartAutoDockCountdown() {
        guard autoDockEnabled else { return }
        autoDockRestartCountdownIfNeeded()
    }
    
    @objc public func cancelAutoDockCountdown() {
        autoDockStopCountdown()
    }
    
    @objc public func triggerAutoDockNow() {
        guard autoDockEnabled else { return }
        autoDockStopCountdown()
        autoDockWidgetToNearestEdge()
    }
    
    @objc public func restoreFromAutoDock(animated: Bool) {
        guard autoDockEnabled else { return }
        autoDockRestoreWidget(animated: animated)
    }
    
    @objc func autoDockStopCountdown() {
        autoDockTimer?.invalidate()
        autoDockTimer = nil
    }
    
    private func autoDockStopSettledAlphaTimer() {
        autoDockSettledAlphaTimer?.invalidate()
        autoDockSettledAlphaTimer = nil
    }
    
    private func autoDockRestoreOriginalAlpha() {
        alpha = widgetType == WidgetTypeEnum.touchPad ? 1 : 1
    }
    
    private func autoDockApplyTemporarySize() {
        // autoDockOriginalBoundsSize = bounds.size
        var adjustedFrame = frame
        if autoDockDockedToBottomEdge {
            adjustedFrame.size.width = OnScreenWidgetView.autoDockExposedEdgeLength
        }
        else {
            adjustedFrame.size.height = OnScreenWidgetView.autoDockExposedEdgeLength
        }
        frame = adjustedFrame.integral
        if shape == "round" {
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        }
        else {
            setSquareWidgetCornerRadius()
        }
    }
    
    private func autoDockRestoreOriginalSize() {
        guard autoDockOriginalBoundsSize != .zero else { return }
        var adjustedFrame = frame
        adjustedFrame.size = autoDockOriginalBoundsSize
        frame = adjustedFrame.integral
        if let hostView = superview {
            if autoDockDockedToBottomEdge {
                frame.origin.y = hostView.bounds.height - frame.height
            }
            else {
                frame.origin.x = hostView.bounds.width - frame.width
            }
        }
        if shape == "round" {
            layer.cornerRadius = min(bounds.width, bounds.height) / 2
        }
        else {
            setSquareWidgetCornerRadius()
        }
    }
    
    private func autoDockRestartCountdownIfNeeded() {
        autoDockStopCountdown()
        autoDockStopSettledAlphaTimer()
        guard !OnScreenWidgetView.editMode,
              autoDockEnabled,
              superview != nil,
              window != nil,
              !isHidden,
              // alpha > 0.01,
              !autoDockIsDocked else {
            return
        }
        autoDockTimer = Timer.scheduledTimer(withTimeInterval: autoDockIdleDuration, repeats: false) { [weak self] _ in
            self?.autoDockWidgetToNearestEdge()
        }
    }
    
    private func autoDockWidgetToNearestEdge() {
        guard autoDockEnabled else {return}
        
        autoDockIdleDuration = storedAutoDockIdleDuration
        
        if !folded {
            restartAutoDockCountdown()
            return
        }
        // if hasUnfoldedSubfolders() {return}
        
        self.isUserInteractionEnabled = false
        guard let hostView = superview,
              !OnScreenWidgetView.editMode,
              autoDockEnabled,
              !autoDockIsDocked,
              !isHidden else {
            return
        }
        hostView.layoutIfNeeded()
        layoutIfNeeded()
        
        // autoDockStoredCenter = storedCenter
        let rightDistance = hostView.bounds.width - frame.maxX
        let bottomDistance = hostView.bounds.height - frame.maxY
        autoDockDistance = min(rightDistance, bottomDistance)
        autoDockDockedToBottomEdge = bottomDistance < rightDistance
        
        let targetFrame = autoDockTargetFrame(in: hostView.bounds)
        autoDockDockedCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        
        self.autoDockIsDocked = true
        UIView.animate(
            withDuration: 0.62,
            delay: 0,
            usingSpringWithDamping: OnScreenWidgetView.autoDockGoDamping,
            initialSpringVelocity: 0.35,
            options: [.allowUserInteraction, .curveEaseOut]
        ) {
            self.frame = targetFrame
            self.transform = CGAffineTransform(scaleX: 0.985, y: 0.985)
        } completion: { _ in
            UIView.animate(withDuration: 0.1, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                self.autoDockApplyTemporarySize()
                self.transform = .identity
                self.label.alpha = 0
                self.alpha = OnScreenWidgetView.autoDockInitialAlpha
            } completion: { _ in
                self.isUserInteractionEnabled = true
                self.autoDockStopSettledAlphaTimer()
                self.autoDockSettledAlphaTimer = Timer.scheduledTimer(withTimeInterval: OnScreenWidgetView.autoDockSettledAlphaDelay, repeats: false) { [weak self] _ in
                    guard let self, self.autoDockIsDocked else { return }
                    UIView.animate(withDuration: 0.17, delay: 0, options: [.allowUserInteraction, .curveEaseOut]) {
                        self.isUserInteractionEnabled = true
                        self.alpha = self.autoDockSettledAlpha
                    }
                }
            }
        }
    }
    
    private func autoDockRestoreWidget(animated: Bool) {
        guard autoDockIsDocked else {
            restartAutoDockCountdown()
            return
        }
        let restoreCenter = storedCenter
        OnScreenWidgetView.hasRestoredFromAutoDock = true
        autoDockStopCountdown()
        autoDockStopSettledAlphaTimer()
        autoDockRestoreOriginalSize()
        label.alpha = 1
        autoDockRestoreOriginalAlpha()
        
        let animations = {
            self.center = restoreCenter
            self.transform = .identity
        }
        
        let completion: (Bool) -> Void = { _ in
            self.autoDockDockedCenter = nil
            self.autoDockRestartCountdownIfNeeded()
        }
        
        if animated {
            UIView.animate(
                withDuration: autoDockDistance/(175/0.38),
                delay: 0,
                usingSpringWithDamping: OnScreenWidgetView.autoDockReturnDamping,
                initialSpringVelocity: 0.22,
                options: [.allowUserInteraction, .curveEaseOut],
                animations: animations,
                completion: {_ in
                    self.autoDockIsDocked = false
                    self.restartAutoDockCountdown()
                }
            )
        }
        else {
            animations()
            completion(true)
        }
    }
    
    private func autoDockTargetFrame(in bounds: CGRect) -> CGRect {
        var targetFrame = frame
        if autoDockDockedToBottomEdge {
            targetFrame.origin.x = min(
                max(targetFrame.origin.x, OnScreenWidgetView.autoDockVerticalInset),
                bounds.width - targetFrame.width - OnScreenWidgetView.autoDockVerticalInset
            )
            targetFrame.origin.y = bounds.height - OnScreenWidgetView.autoDockExposedThickness
        }
        else {
            targetFrame.origin.y = min(
                max(targetFrame.origin.y, OnScreenWidgetView.autoDockVerticalInset),
                bounds.height - targetFrame.height - OnScreenWidgetView.autoDockVerticalInset
            )
            targetFrame.origin.x = bounds.width - OnScreenWidgetView.autoDockExposedThickness
        }
        return targetFrame.integral
    }
    /// ================================================================================================================

    
    @objc func getAvailableSequence() -> Int16 {
        var sequence:Int16 = 0
        self.forEachWidget(){ widget in
            sequence = max(sequence, widget.sequence)
        }
        return sequence+1
    }
    
    @objc func moveSubWidgetsInBatch(by vector:CGVector) {
        guard isFolder else {return}
        for sequence in self.sequenceSet {
            guard let widget = OnScreenWidgetView.mapping[sequence] else {return}
            widget.storedCenter = CGPoint(x: widget.storedCenter.x+vector.dx, y: widget.storedCenter.y+vector.dy)
            if !widget.isHidden {
                widget.center = CGPoint(x: widget.center.x+vector.dx, y: widget.center.y+vector.dy)
            }
            widget.relocatedDuringStreaming = true
        }
    }
    
    @objc static var enableFolderAnimation:Bool = true
    private static func setCollection(hidden:Bool, for folder:OnScreenWidgetView, exception:OnScreenWidgetView? = nil, recursive:Bool = false) {
        guard folder.isFolder else {return}
        // guard folder.folded != hidden else { return }
        folder.folded = hidden
        folder.setupAtrributedText()
        if hidden {
            for sequence in folder.sequenceSet {
                guard let widget = OnScreenWidgetView.mapping[sequence], widget != exception else {continue}
                DispatchQueue.main.async {
                    widget.isUserInteractionEnabled = false
                    if ((folder.buttonMode != .slideAndHold && widget.widgetType == .touchPad)
                        || abs(widget.backgroundAlpha) < 0.1){
                        widget.highlightBorder(highlighted: true, color: UIColor.systemBlue.cgColor)
                    }
                    let duration = OnScreenWidgetView.enableFolderAnimation ? (folder.buttonMode == .slideAndHold ? 0.05 : 0.15) : 0
                    UIView.animate(withDuration: duration, animations: {
                        widget.center = folder.center
                    },completion: { finished in
                        widget.isUserInteractionEnabled = !hidden
                        widget.center = folder.folded ? folder.storedCenter : widget.storedCenter
                        widget.isHidden = folder.folded
                        if ((folder.buttonMode != .slideAndHold && widget.widgetType == .touchPad)
                            || abs(widget.backgroundAlpha) < 0.1){
                            widget.highlightBorder(highlighted: false)
                        }
                    })
                }
            }
        }
        else{
            for sequence in folder.sequenceSet {
                guard let widget = OnScreenWidgetView.mapping[sequence], widget != exception else {continue}
                DispatchQueue.main.async {
                    widget.isUserInteractionEnabled = false
                    widget.capturedTouches.removeAllObjects()
                    widget.center = folder.storedCenter
                    widget.isHidden = false
                    if ((folder.buttonMode != .slideAndHold && widget.widgetType == .touchPad)
                        || abs(widget.backgroundAlpha) < 0.1){
                        widget.highlightBorder(highlighted: true, color: UIColor.systemBlue.cgColor)
                    }
                    UIView.animate(withDuration: OnScreenWidgetView.enableFolderAnimation ? (folder.buttonMode == .slideAndHold ? 0.05 : 0.15) : 0, animations: {
                        widget.center = widget.storedCenter
                    },completion: { finished in
                        widget.capturedTouches.removeAllObjects()
                        widget.isUserInteractionEnabled = !folder.folded
                        widget.center = folder.folded ? folder.storedCenter : widget.storedCenter
                        widget.isHidden = folder.folded
                        if ((folder.buttonMode != .slideAndHold && widget.widgetType == .touchPad)
                            || abs(widget.backgroundAlpha) < 0.1){
                            widget.highlightBorder(highlighted: false)
                        }
                        if widget.hasNonEditableLabel {widget.setupAtrributedText()}
                    })
                }
            }
        }
        if recursive {
            for sequence in folder.sequenceSet {
                guard let widget = OnScreenWidgetView.mapping[sequence] else {continue}
                guard widget.isFolder, widget != exception else {continue}
                OnScreenWidgetView.setCollection(hidden: hidden, for: widget, exception: exception, recursive: true)
            }
        }
    }
    
    @objc static func set(folded:Bool, for folder:OnScreenWidgetView) { // folder综合逻辑
        guard folder.isFolder else {return}
        setCollection(hidden: folded, for: folder)
        if !folded, folder.revealMode == .exclusive {
            OnScreenWidgetView.unfoldedExclusiveFolderSequence = folder.sequence
            if(!isRestoring) {OnScreenWidgetView.postExclusiveUnfoldedSequences.removeAll()}
            let currentRootFolder = OnScreenWidgetView.getRootFolder(of: folder) ?? folder
            var offshootRootFolders:Set<OnScreenWidgetView> = Set()
            folder.forEachWidget{ widget in
                guard folder != widget else {return}
                let rootFolder = getRootFolder(of: widget)
                guard let rootFolder = rootFolder else {return}
                offshootRootFolders.insert(rootFolder)
            }
            
            offshootRootFolders.remove(currentRootFolder)
            for folder in offshootRootFolders {
                print("offshootRootFolder \(CACurrentMediaTime()) \(folder.label.text ?? "")")
            }
            
            guard !folder.sequenceSet.isEmpty else {return}
            for folder in offshootRootFolders {
                setCollection(hidden: true, for: folder, recursive: true)
            }
            
            guard currentRootFolder != folder else {return}
            setCollection(hidden: true, for:currentRootFolder, exception: folder, recursive: true)
        }
        if folded, folder.revealMode == .exclusive {
            OnScreenWidgetView.unfoldedExclusiveFolderSequence = -1
        }
        if folder.revealMode == .coexist {
            if folded {
                OnScreenWidgetView.postExclusiveUnfoldedSequences.remove(folder.sequence)
            }
            else {OnScreenWidgetView.postExclusiveUnfoldedSequences.insert(folder.sequence)}
        }
    }
    
    private static func getRootFolder(of widget:OnScreenWidgetView) -> OnScreenWidgetView?{
        var widgetRef:OnScreenWidgetView? = widget
        var parentFolder:OnScreenWidgetView? = OnScreenWidgetView.mapping[widgetRef?.parentSequence ?? -1]
        repeat {
            widgetRef = parentFolder
            parentFolder = OnScreenWidgetView.mapping[widgetRef?.parentSequence ?? -1]
        } while parentFolder != nil
        return widgetRef
    }
    
    private static func getParentFolders(of widget: OnScreenWidgetView) -> Set<OnScreenWidgetView> {
        var parents = Set<OnScreenWidgetView>()
        var current = widget
        while let parent = OnScreenWidgetView.mapping[current.parentSequence] {
            parents.insert(parent)
            current = parent
        }
        return parents
    }
    
    private func hasUnfoldedSubfolders() -> Bool {
        for sequence in self.sequenceSet {
            guard let widget = OnScreenWidgetView.mapping[sequence] else {continue}
            if !widget.isFolder {continue}
            if !widget.folded {return true}
        }
        return false
    }

    private static func putWidget(_ widget:OnScreenWidgetView, into folder:OnScreenWidgetView){
        guard !OnScreenWidgetView.getParentFolders(of: folder).contains(widget), !folder.isHidden else { return }
        let parentFolder = OnScreenWidgetView.mapping[widget.parentSequence]
        if parentFolder != nil {
            parentFolder?.sequenceSet.remove(widget.sequence)
        }
        widget.parentSequence = folder.sequence
        folder.sequenceSet.insert(widget.sequence)
        widget.isHidden = folder.folded
        /*
        if folder.buttonMode == .slideAndHold, widget.isFunctionalButton {
            widget.buttonMode = .slideToToggle
        } */
    }
    
    @objc static func setFree(widget:OnScreenWidgetView){
        let parentFolder = OnScreenWidgetView.mapping[widget.parentSequence]
        if parentFolder != nil {
            parentFolder?.sequenceSet.remove(widget.sequence)
        }
        widget.parentSequence = -1
        if widget.isFolder {
            for sequence in widget.sequenceSet {
                guard let subWidget = OnScreenWidgetView.mapping[sequence] else {continue}
                subWidget.parentSequence = -1
            }
            widget.sequenceSet.removeAll()
        }
    }
    
    @objc static func restoreFoldedStates(){
        isRestoring = true
        var unfoldedExclusiveFolder: OnScreenWidgetView?
        if unfoldedExclusiveFolderSequence != -1 {
            unfoldedExclusiveFolder = OnScreenWidgetView.mapping[unfoldedExclusiveFolderSequence]
        }
        
        for widget in OnScreenWidgetView.mapping.values {
            OnScreenWidgetView.setCollection(hidden: widget.folded, for: widget, exception: unfoldedExclusiveFolder)
        }
        
        if(unfoldedExclusiveFolder != nil){
            OnScreenWidgetView.set(folded: false, for: unfoldedExclusiveFolder!)
            if OnScreenWidgetView.mapping[unfoldedExclusiveFolder!.parentSequence]?.buttonMode == .slideAndHold {
                unfoldedExclusiveFolder?.isHidden = true
            }
        }
        
        // print("postExclusiveUnfoldedSequences \(postExclusiveUnfoldedSequences) stamp \(CACurrentMediaTime())")
        for sequence in postExclusiveUnfoldedSequences {
            guard let folder = OnScreenWidgetView.mapping[sequence] else { continue }
            OnScreenWidgetView.set(folded: false, for: folder)
        }
        
        isRestoring = false
    }
    
    @objc static func getMaxSequence() -> Int16{
        return OnScreenWidgetView.mapping.keys.max() ?? -1
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        OnScreenWidgetView.installAutoDockIfNeeded()
        if superview == nil {
            autoDockStopCountdown()
            autoDockStopSettledAlphaTimer()
            autoDockRestoreOriginalSize()
            autoDockIsDocked = false
            label.alpha = 1
            autoDockRestoreOriginalAlpha()
            if self.motionControlButtonString == "GYRO" {
                self.motionHandler?.stopGyroUpdate(interruptNoneGyroInput: true)
                self.motionHandler?.gyroStarter = nil
            }
            if self.motionControlButtonString == "ACCEL" {}
            if self.motionControlButtonString == "MOTION" {}
            
            if self.widgetType == WidgetTypeEnum.button && !OnScreenWidgetView.editMode {
                self.sendComboButtonsUpEvent(comboStrings: self.comboButtonStrings)
                self.functionalButtonDelegate?.alterAbsTouchDragWith(mouseButton:BUTTON_LEFT)
            }
            buttonDownVisualEffectLayer.removeFromSuperlayer()
            trackPoint.removeFromSuperlayer()
            crossMarkLayer.removeFromSuperlayer()
            lrudIndicatorBall.removeFromSuperlayer()
            l3r3Indicator.removeFromSuperlayer()
            upIndicator.removeFromSuperlayer()
            downIndicator.removeFromSuperlayer()
            leftIndicator.removeFromSuperlayer()
            rightIndicator.removeFromSuperlayer()
            lrudIndicatorBall.removeFromSuperlayer()
            stickWheelAxis.removeFromSuperlayer()
            stickWheelLayer.removeFromSuperlayer()
            stickWheelLayerSmall.removeFromSuperlayer()
            self.inertialScroller.timer?.clean()
            self.clearLeftStickTouchPadFlag()
            self.clearRightStickTouchPadFlag()
            self.autoTapTimer?.clean()
            self.onScreenControls = nil
        }
        else{
            self.superViewWidth = (superview?.bounds.size.width)!
            self.superViewHeight = (superview?.bounds.size.height)!
            autoDockRestartCountdownIfNeeded()
        }
    }
    
    private static var horizontalGuideline: UIView = {
        let v = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: UIScreen.main.bounds.width * 2,
                height: 2
            )
        )
        v.backgroundColor = .blue
        v.isHidden = true
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOffset = .zero
        v.layer.shadowOpacity = 0.5
        v.layer.shadowRadius = 2
        return v
    }()
    private static var verticalGuideline: UIView = {
        let v = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 2,
                height: UIScreen.main.bounds.height * 2
            )
        )
        v.backgroundColor = .blue
        v.isHidden = true
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOffset = .zero
        v.layer.shadowOpacity = 0.5
        v.layer.shadowRadius = 2
        return v
    }()
    
    private static func updateStreamViewGuidelines(for widget:OnScreenWidgetView){
        if !widget.moveableButtonLongPressed() {return}
        if horizontalGuideline.superview == nil {
            widget.addSubview(horizontalGuideline)
            widget.addSubview(verticalGuideline)
            horizontalGuideline.isHidden = false
            verticalGuideline.isHidden = false
        }
        horizontalGuideline.center = CGPoint(x: widget.bounds.midX, y: widget.bounds.midY)
        verticalGuideline.center = CGPoint(x: widget.bounds.midX, y: widget.bounds.midY)
        
        var horizontallyAligned = false
        var verticallyAligned = false
        widget.forEachWidget{ otherWidget in
            guard otherWidget != widget else {return}
            if widget.isFolder, widget.bulkMoveEnabled, widget.sequenceSet.contains(otherWidget.sequence) {return}
            verticallyAligned = verticallyAligned ? verticallyAligned : widget.center.x > otherWidget.center.x-1 && widget.center.x < otherWidget.center.x+1
            horizontallyAligned = horizontallyAligned ? horizontallyAligned : widget.center.y > otherWidget.center.y-1 && widget.center.y < otherWidget.center.y+1
        }
        horizontalGuideline.backgroundColor = horizontallyAligned ? .yellow : .blue
        verticalGuideline.backgroundColor = verticallyAligned ? .yellow : .blue
    }
    
    private static func removeStreamViewGuidelines(){
        horizontalGuideline.removeFromSuperview()
        verticalGuideline.removeFromSuperview()
    }
    
    deinit {
        print("onScreenWidgetView deinit \(self.widgetLabel) \(CACurrentMediaTime())")
    }
}
