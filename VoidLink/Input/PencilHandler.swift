//
//  PencilHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/17.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//


import UIKit

@objc class PencilHandler: UIResponder, UIPencilInteractionDelegate {
    @objc static var shared: PencilHandler?
    
    /// 用来处理所有 touch 事件的宿主视图
    weak var streamView: UIView?
    // private var tickTimer: SafeTimer
    private var pencilInteraction: Any?
    @objc var streamAspectRatio: Float
    private var tickInterval: TimeInterval
    private var manualTick: Bool
    private var pencilTickEnabled: Bool
    private var pressureCurveEnabled: Bool = false
    private var manualHoverFlag: Bool = false
    @objc static var hoverSupported: Bool = false
    // @objc static private(set) var autoHoverTermination: Bool = false
    @objc static private(set) var hoverMode: PencilHoverMode = .HoverPencil
    private(set) var pencilProEnabled: Bool = false
    private var isFirstMove: Bool = false
    private var strokeSampleIndex: Int32 = 0
    private var initialMoveEventIndexLimit: Int64
    private var touchBeganForce: Float = 0
    @objc static private(set) var isDrawing: Bool = false
    @objc static private(set) var pencilPausesNativeTouch: Bool = false

    // static private let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
    static private var selectedProfile:OSCProfile?

    private var strokeLUT = PressureCurveLUT(curve: PressureCurve())
    // private var initialTouchLUT = PressureCurveLUT(curve: PressureCurve())
    private var phase1StrokeSampleIndexEnd:Int32 = 0
    private var phase2StrokeSampleIndexEnd:Int32 = 0
    private var phase2EqualizationStrength:Float = 0
    
    enum StrokePhase: UInt8, CaseIterable {
        case phase1
        case phase2
        case phase3
    }
    
    private func getStrokePhase(sampleIndex:Int32) -> StrokePhase {
        if sampleIndex > phase2StrokeSampleIndexEnd {
            return .phase3
        }
        if sampleIndex > phase1StrokeSampleIndexEnd {
            return .phase2
        }
        return .phase1
    }

    @objc init(streamView: UIView, settings: TemporarySettings) {
        self.streamView = streamView
        streamAspectRatio = settings.width.floatValue/settings.height.floatValue
        tickInterval = TimeInterval(settings.pencilTickIntervalUs.floatValue/1000000)
        manualTick = settings.pencilTickMode.intValue == PencilTickMode.ManualTick.rawValue
        pencilTickEnabled = settings.pencilTickMode.intValue != PencilTickMode.PencilTickDisabled.rawValue
        // initialMoveEventIndexLimit = UIScreen.main.maximumFramesPerSecond > 60 ? 4 : 2
        initialMoveEventIndexLimit = 0
        super.init()
        setupPressureLUT()
        PencilHandler.shared = self
    }
    
    @objc public func setupPressureLUT(profile:OSCProfile? = nil){
        var selectedProfile:OSCProfile
        if profile == nil {
            let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
            selectedProfile = oscProfileMan.getSelectedProfile()
        }
        else{
            selectedProfile = profile!
        }
        
        doubleTapShorcuts.removeAll()
        if selectedProfile.doubleTapShorcutEnabled {
            if selectedProfile.eraserShortcut != "" {
                doubleTapShorcuts.append(selectedProfile.eraserShortcut)
            }
            if selectedProfile.brushShortcut != "" {
                doubleTapShorcuts.append(selectedProfile.brushShortcut)
            }
        }
        
        PencilHandler.squeezeStartShortcut = ""
        PencilHandler.squeezeEndShortcut = ""
        if selectedProfile.squeezeShorcutEnabled {
            PencilHandler.squeezeStartShortcut = selectedProfile.squeezeStartShortcut
            PencilHandler.squeezeEndShortcut = selectedProfile.squeezeEndShortcut
            print("squeezeShorcutEnabled \(CACurrentMediaTime())")
        }
        
        // PencilHandler.autoHoverTermination = selectedProfile.autoPencilHoverTermination
        PencilHandler.hoverMode = selectedProfile.pencilHoverMode
        
        pressureCurveEnabled = selectedProfile.pressureCurveEnabled
        
        if #available(iOS 15.0, *) {
            IAPManager.checkPurchaseInfo(.PencilProPack) { info in
                self.pressureCurveEnabled = self.pressureCurveEnabled && info.valid
                self.pencilTickEnabled = self.pencilTickEnabled && info.valid
                self.pencilProEnabled = info.valid
                PencilHandler.pencilPausesNativeTouch = selectedProfile.pencilPausesNativeTouch && info.valid
                if info.valid {
                    self.setupPencilInteraction(view: self.streamView)
                }
            }
        }
        
        let strokePressureCurvePoints = PressureCurve.importCurvePoints(selectedProfile.pressureCurvePoints)
        let strokePressureCurve = PressureCurve()
        strokePressureCurve.polylinePoints = strokePressureCurvePoints
        strokePressureCurve.buildCurveSegments()
        
        // let initialTouchPressureCurvePoints = PressureCurve.importCurvePoints(selectedProfile.initialTouchPressureCurvePoints)
        // let initialTouchPressureCurve = PressureCurve()
        // initialTouchPressureCurve.polylinePoints = initialTouchPressureCurvePoints
        // initialTouchPressureCurve.buildCurveSegments()
        
        phase1StrokeSampleIndexEnd = selectedProfile.phase1StrokeSampleIndexEnd
        phase2StrokeSampleIndexEnd = selectedProfile.phase2StrokeSampleIndexEnd
        phase2EqualizationStrength = Float(selectedProfile.strokeEqualizationStrength)

        DispatchQueue.main.asyncAfter(deadline: .now()) {
            self.strokeLUT = PressureCurveLUT(curve: strokePressureCurve)
            // self.initialTouchLUT = PressureCurveLUT(curve: initialTouchPressureCurve)
        }
    }

    // MARK: - Touch Events

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let event = event else { return }
        previousForce = 0
        previousTargetForce = 0
        PencilHandler.isDrawing = true
        // isFirstMove = true
        strokeSampleIndex = 0
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

    var previousForce: Float = 0
    var previousTargetForce: Float = 0
    var phase2IndexCount: Int32 = 0
    private func sendStylusEvent(touchBatch: [UITouch], with event: UIEvent? = nil) -> DispatchTime {
        guard let streamView = streamView, touchBatch.count>0 else { return .now() }
        
        var tickMoment: TimeInterval = 0
        var previousTimeStamp: TimeInterval = 0
        var delay:TimeInterval = 0
        var dispatchMoment: DispatchTime = .now()
        
        phase2IndexCount = phase2StrokeSampleIndexEnd - phase1StrokeSampleIndexEnd

        for touch in touchBatch {
            let point = touch.preciseLocation(in: streamView)
            let azimuth = touch.azimuthAngle(in: streamView)
            let altitude = touch.altitudeAngle
            let location = self.adjustCoordinatesForVideoArea(point: point)
            let videoSize = self.getVideoAreaSize()
            let normalizedLocation = CGPoint(x: location.x/videoSize.width, y: location.y/videoSize.height)
            var force = Float(touch.force/touch.maximumPossibleForce)/sin(Float(altitude))
            force  = (self.pencilTickEnabled && force == 0) ? previousForce : force
            
            self.strokeSampleIndex += 1

            var targetForce:Float
            var equalizationStep:Float = 0
            var equalizedForce:Float = 0
            if(phase2IndexCount>0){
                equalizationStep = (phase2EqualizationStrength-1)/Float(phase2IndexCount-1)
            }

            
            let strokePhase = getStrokePhase(sampleIndex: self.strokeSampleIndex)
            let forceMapping = pressureCurveEnabled ? self.strokeLUT.value(at: force) : force
            switch strokePhase {
            case .phase1:
                targetForce = pencilTickEnabled ? 0 : forceMapping
            case .phase2:
                targetForce = forceMapping
                targetForce = max(targetForce,previousTargetForce)
                equalizedForce = targetForce*(phase2EqualizationStrength - equalizationStep*Float(strokeSampleIndex-phase1StrokeSampleIndexEnd-1))
            case .phase3:
                targetForce = forceMapping
            }
            targetForce = pencilTickEnabled ? targetForce : force
            
            previousForce = force
            previousTargetForce = targetForce
            
            let eventType:UInt8
            
            switch touch.phase {
            case .began:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER : LI_TOUCH_EVENT_DOWN)
            case .moved:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER : LI_TOUCH_EVENT_MOVE)
            case .ended:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER_LEAVE : LI_TOUCH_EVENT_UP)
                targetForce = 0
                previousForce = 0
                previousTargetForce = 0
            case .cancelled:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER_LEAVE : LI_TOUCH_EVENT_UP)
                targetForce = 0
                previousForce = 0
                previousTargetForce = 0
            default:
                eventType = UInt8(LI_TOUCH_EVENT_HOVER)
            }

            delay = manualTick ? 0.0086 : 0.0086
            delay = eventType == UInt8(LI_TOUCH_EVENT_UP) ? delay : 0
            
            if previousTimeStamp == 0 {
                previousTimeStamp = touch.timestamp
                tickMoment = 0
                dispatchMoment = .now()
            }
            else {
                tickMoment += (manualTick ? tickInterval : touch.timestamp - previousTimeStamp)
            }
            
            let sendableForce = strokePhase == .phase2 ? equalizedForce : targetForce

            DispatchQueue.global().asyncAfter(deadline: dispatchMoment + tickMoment + delay) {
                /*
                if PencilHandler.autoHoverEnabled, eventType == UInt8(LI_TOUCH_EVENT_DOWN) {
                    LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER_LEAVE), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
                }
                */
                
                if strokePhase != .phase1 || !self.pencilTickEnabled {LiSendPenEvent(eventType, UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), sendableForce, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))}
                else {
                    LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
                }
                
                if eventType == UInt8(LI_TOUCH_EVENT_UP) {
                    PencilHandler.isDrawing = false
                    if PencilHandler.hoverMode == .HoverDisabled || !PencilHandler.hoverSupported {
                        LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.0086){
                            if !PencilHandler.isDrawing {
                                LiSendPenEvent(UInt8(LI_TOUCH_EVENT_HOVER_LEAVE), UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), 0, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
                            }
                        }
                    }
                }
            }
        }
        
        return dispatchMoment + tickMoment + delay
    }
    
    @objc public func switchPencilHover(){
        manualHoverFlag = !manualHoverFlag
    }
    
    @objc public func enablePencilHover(){
        manualHoverFlag = true
    }
    
    @objc public func disablePencilHover(){
        manualHoverFlag = false
    }
    
    @available(iOS 12.1, *)
    private func setupPencilInteraction(view:UIView?) {
        let interaction = UIPencilInteraction()
        guard let view else { return }
        if pencilInteraction != nil {return}
        interaction.delegate = self
        view.addInteraction(interaction)
        pencilInteraction = interaction
    }

    @available(iOS 12.1, *)
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        if !pencilProEnabled {return}
        if doubleTapShorcuts.isEmpty {return}
        let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: doubleTapShorcuts[shortcutIndex])
        print("pencilInteractionDidTap \(CACurrentMediaTime())")
        CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: keyStrings, delay: 0.1)
        shortcutIndex = (shortcutIndex + 1) % doubleTapShorcuts.count
    }
    
    @available(iOS 17.5, *)
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        if !pencilProEnabled {return}
        if PencilHandler.squeezeStartShortcut == "", PencilHandler.squeezeEndShortcut == "" {return}
        
        let keepPressedUntilRelease = PencilHandler.squeezeEndShortcut.uppercased() == "NULL"
        let squeezePressKeyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: PencilHandler.squeezeStartShortcut)
        let squeezeReleaseKeyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: PencilHandler.squeezeEndShortcut)
        
        guard let squeezePressKeyStrings = squeezePressKeyStrings else {return}
        guard squeezePressKeyStrings.count>0 else {return}

        switch squeeze.phase {
        case .began:
            if keepPressedUntilRelease {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: squeezePressKeyStrings, delay: 0.1, pressOnly: true)}
            else {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: squeezePressKeyStrings, delay: 0.1)}
            break
        case .ended, .cancelled:
            if keepPressedUntilRelease {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: squeezePressKeyStrings, releaseOnly: true)}
            else {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: squeezeReleaseKeyStrings, delay: 0.1)}
            break
        default:
            break
        }
    }

    @objc static private(set) var eraserShortcut:String = ""
    @objc static private(set) var brushShortcut:String = ""
    private var doubleTapShorcuts: Array<String> = []
    private var shortcutIndex: Int = 0
    
    @objc func replaceBrush(with shortcut:String){
        if let i = doubleTapShorcuts.indices.last {
            doubleTapShorcuts[i] = shortcut
        }
    }
    
    @objc func replaceEraser(with shortcut:String){
        if let i = doubleTapShorcuts.indices.first {
            doubleTapShorcuts[i] = shortcut
        }
    }
    
    @available(iOS 13.0, *)
    func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary) {
        let params = payload.mutableCopy() as? NSMutableDictionary ?? NSMutableDictionary()
        let pickerAction = ((params["pickerAction"] as? String) ?? "").lowercased()
        params.removeObject(forKey: "pickerAction")
        
        if pickerAction == "create" {
            
        }
    }

    @objc static public func enterDoubleTapShortcuts(in viewController: UIViewController){
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = (viewController as! any WidgetPickerViewControllerDelegate)
            pickerViewController.keyboardPickerMode = .shortcutPicker
            pickerViewController.tabIdentifiers = ["keyboard", "shortcuts"]
            pickerViewController.initialTabIdentifier = "keyboard"
            pickerViewController.shortcutIdentifier = "eraser"
            pickerViewController.shortcutPickerTipText = LocalizationHelper.localizedString(forKey: "Select eraser shortcut keys")
            pickerViewController.presentOverFullScreen(from: viewController)
            return
        }

        /*
        let alert = UIAlertController(title: LocalizationHelper.localizedString(forKey: "Eraser Shortcut"),
                                      message: LocalizationHelper.localizedString(forKey: "Enter eraser keyboard shortcut:"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = LocalizationHelper.localizedString(forKey:"Example: e, ctrl+e, alt+e ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile.eraserShortcut
        }

        let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                eraserShortcut = comboButtons
            }
            enterBrushShortcut(in: viewController)
        }
        
        let learnMoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
        })

        */
    }
    
    @available(iOS 13.0, *)
    @objc static public func enterBrushShortcut(in viewController: UIViewController){
        let pickerViewController = WidgetPickerViewController()
        pickerViewController.delegate = (viewController as! any WidgetPickerViewControllerDelegate)
        pickerViewController.keyboardPickerMode = .shortcutPicker
        pickerViewController.tabIdentifiers = ["keyboard", "shortcuts"]
        pickerViewController.initialTabIdentifier = "keyboard"
        pickerViewController.shortcutIdentifier = "brush"
        pickerViewController.shortcutPickerTipText = LocalizationHelper.localizedString(forKey: "Select brush shortcut keys")
        pickerViewController.presentOverFullScreen(from: viewController)
        return
        
        /*
        let alert = UIAlertController(title: LocalizationHelper.localizedString(forKey: "Brush Shortcut"),
                                      message: LocalizationHelper.localizedString(forKey: "Enter brush keyboard shortcut:"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = LocalizationHelper.localizedString(forKey:"Example: b, ctrl+b, alt+b ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile?.brushShortcut
        }

        let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                brushShortcut = comboButtons
            }
            
            if selectedProfile?.brushShortcut != brushShortcut
                || selectedProfile?.eraserShortcut != eraserShortcut {
                guard let selectedProfile = selectedProfile else {return}
                let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
                selectedProfile.brushShortcut = brushShortcut
                selectedProfile.eraserShortcut = eraserShortcut
                oscProfileMan.replaceSelectedProfile(with: selectedProfile, overwriteDefault: true)
            }
        }
        
        let learnMoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
             
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
            
        })
         */
    }
    
    @objc static private(set) var squeezeStartShortcut:String = ""
    @objc static private(set) var squeezeEndShortcut:String = ""
    
    @objc static public func enterSqueezeShortcuts(in viewController: UIViewController){
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = (viewController as! any WidgetPickerViewControllerDelegate)
            pickerViewController.keyboardPickerMode = .shortcutPicker
            pickerViewController.tabIdentifiers = ["keyboard", "shortcuts"]
            pickerViewController.initialTabIdentifier = "keyboard"
            pickerViewController.shortcutIdentifier = "squeezePress"
            pickerViewController.shortcutPickerTipText = LocalizationHelper.localizedString(forKey: "squeezePressShortcutPickerTip")
            pickerViewController.presentOverFullScreen(from: viewController)
        }
        /*
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        selectedProfile = oscProfileMan.getSelectedProfile()
        guard let selectedProfile = selectedProfile else {return}
        
        let alert = UIAlertController(title: LocalizationHelper.localizedString(forKey: "Squeeze Shortcut"),
                                      message: LocalizationHelper.localizedString(forKey: "enterSqueezePressShort"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = LocalizationHelper.localizedString(forKey:"Example: e, ctrl+e, alt+e ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile.squeezeStartShortcut
        }

        let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                squeezeStartShortcut = comboButtons
            }
            enterSqueezeEndShortcut(in: viewController)
        }
        
        let learnMoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
        })
        */
    }

    @objc static public func enterSqueezeEndShortcut(in viewController: UIViewController){
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = (viewController as! any WidgetPickerViewControllerDelegate)
            pickerViewController.keyboardPickerMode = .shortcutPicker
            pickerViewController.tabIdentifiers = ["keyboard", "shortcuts"]
            pickerViewController.initialTabIdentifier = "keyboard"
            pickerViewController.shortcutIdentifier = "squeezeRelease"
            pickerViewController.shortcutPickerTipText = LocalizationHelper.localizedString(forKey: "squeezeReleaseShortcutPickerTip")
            pickerViewController.presentOverFullScreen(from: viewController)
        }
        
        /*
        let alert = UIAlertController(title: LocalizationHelper.localizedString(forKey: "Squeeze Shortcut"),
                                      message: LocalizationHelper.localizedString(forKey: "enterSqueezeReleaseShort"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = LocalizationHelper.localizedString(forKey:"Example: b, ctrl+b, alt+b ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile?.squeezeEndShortcut
        }

        let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                squeezeEndShortcut = comboButtons
            }
            
            if selectedProfile?.squeezeEndShortcut != squeezeEndShortcut
                || selectedProfile?.squeezeStartShortcut != squeezeStartShortcut {
                guard let selectedProfile = selectedProfile else {return}
                let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
                selectedProfile.squeezeEndShortcut = squeezeEndShortcut
                selectedProfile.squeezeStartShortcut = squeezeStartShortcut
                oscProfileMan.replaceSelectedProfile(with: selectedProfile, overwriteDefault: true)
            }
        }
        
        let learnMoreAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
             
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
            
        })
         */
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
