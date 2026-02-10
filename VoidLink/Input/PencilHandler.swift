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
    private var streamAspectRatio: Float
    private var tickInterval: TimeInterval
    private var manualTick: Bool
    private var pencilTickEnabled: Bool
    private var pressureCurveEnabled: Bool = false
    private var manualHoverFlag: Bool = false
    private var autoHoverFlag: Bool = false
    private(set) var pencilProEnabled: Bool = false
    private var isFirstMove: Bool = false
    private var moveEventIndex: Int64 = 0
    private var initialMoveEventIndexLimit: Int64
    private var touchBeganForce: Float = 0
    @objc static private(set) var isDrawing: Bool = false
    @objc static private(set) var pencilPausesNativeTouch: Bool = false

    // static private let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
    static private var selectedProfile:OSCProfile?

    private var pressureLUT = PressureCurveLUT(curve: PressureCurve())

    @objc init(streamView: UIView, settings: TemporarySettings) {
        self.streamView = streamView
        streamAspectRatio = settings.width.floatValue/settings.height.floatValue
        tickInterval = TimeInterval(settings.pencilTickIntervalUs.floatValue/1000000)
        manualTick = settings.pencilTickMode.intValue == PencilTickMode.ManualTick.rawValue
        pencilTickEnabled = settings.pencilTickMode.intValue != PencilTickMode.PencilTickDisabled.rawValue
        initialMoveEventIndexLimit = UIScreen.main.maximumFramesPerSecond > 60 ? 4 : 2
        super.init()
        setupPressureLUT()
        PencilHandler.shared = self
    }
    
    public func setupPressureLUT(){
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        PencilHandler.selectedProfile = oscProfileMan.getSelectedProfile()
        guard let selectedProfile = PencilHandler.selectedProfile else {return}
        
        if selectedProfile.eraserShortcut != "" {
            doubleTapShorcuts.append(selectedProfile.eraserShortcut)
        }
        if selectedProfile.brushShortcut != "" {
            doubleTapShorcuts.append(selectedProfile.brushShortcut)
        }
        
        PencilHandler.squeezeStartShortcut = selectedProfile.squeezeStartShortcut
        PencilHandler.squeezeEndShortcut = selectedProfile.squeezeEndShortcut

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
        
        let persistedCurvePoints = PressureCurve.importCurvePoints(selectedProfile.pressureCurvePoints)
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
        PencilHandler.isDrawing = true
        // isFirstMove = true
        moveEventIndex = 0
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
        moveEventIndex += 1
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
            let point = touch.preciseLocation(in: streamView)
            let azimuth = touch.azimuthAngle(in: streamView)
            let altitude = touch.altitudeAngle
            let location = self.adjustCoordinatesForVideoArea(point: point)
            let videoSize = self.getVideoAreaSize()
            let normalizedLocation = CGPoint(x: location.x/videoSize.width, y: location.y/videoSize.height)
            let force = Float(touch.force/touch.maximumPossibleForce)/sin(Float(altitude))
            var targetForce = pressureCurveEnabled ? self.pressureLUT.value(at: force) : force

            let eventType:UInt8
            
            switch touch.phase {
            case .began:
                eventType = UInt8(LI_TOUCH_EVENT_DOWN)
                touchBeganForce = targetForce
            case .moved:
                eventType = UInt8(manualHoverFlag ? LI_TOUCH_EVENT_HOVER : LI_TOUCH_EVENT_MOVE)
                targetForce = moveEventIndex < initialMoveEventIndexLimit ? touchBeganForce : targetForce
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
            
            let sendableForce = targetForce
            DispatchQueue.global().asyncAfter(deadline: dispatchMoment + tickMoment + delay) {
                LiSendPenEvent(eventType, UInt8(LI_TOOL_TYPE_PEN), 0, Float(normalizedLocation.x), Float(normalizedLocation.y), sendableForce, 0, 0, self.getRotation(fromAzimuthAngle: Float(azimuth)), self.getTilt(fromAltitudeAngle: Float(altitude)))
                if eventType == UInt8(LI_TOUCH_EVENT_UP) {
                    PencilHandler.isDrawing = false
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
        interaction.delegate = self
        view.addInteraction(interaction)
        pencilInteraction = interaction
    }

    @available(iOS 12.1, *)
    func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
        if !pencilProEnabled {return}
        if doubleTapShorcuts.isEmpty {return}
        let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: doubleTapShorcuts[shorcutIndex])
        CommandManager.shared.sendAutoReleaseComboCommand(cmdString: keyStrings, delay: 0.1)
        shorcutIndex = (shorcutIndex + 1) % doubleTapShorcuts.count
    }
    
    @available(iOS 17.5, *)
    func pencilInteraction(
        _ interaction: UIPencilInteraction,
        didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze
    ) {
        if !pencilProEnabled {return}
        let keepPressedUntilRelease = PencilHandler.squeezeEndShortcut == "NULL"
        let squeezePressKeyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: PencilHandler.squeezeStartShortcut)
        let squeezeReleaseKeyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: PencilHandler.squeezeEndShortcut)
        
        guard let squeezePressKeyStrings = squeezePressKeyStrings else {return}
        guard squeezePressKeyStrings.count>0 else {return}

        switch squeeze.phase {
        case .began:
            if keepPressedUntilRelease {CommandManager.shared.sendAutoReleaseComboCommand(cmdString: squeezePressKeyStrings, delay: 0.1, pressOnly: true)}
            else {CommandManager.shared.sendAutoReleaseComboCommand(cmdString: squeezePressKeyStrings, delay: 0.1)}
            break
        case .ended, .cancelled:
            if keepPressedUntilRelease {CommandManager.shared.sendAutoReleaseComboCommand(cmdString: squeezePressKeyStrings, releaseOnly: true)}
            else {CommandManager.shared.sendAutoReleaseComboCommand(cmdString: squeezeReleaseKeyStrings, delay: 0.1)}
            break
        default:
            break
        }
    }

    @objc static private(set) var eraserShortcut:String = ""
    @objc static private(set) var brushShortcut:String = ""
    private var doubleTapShorcuts: Array<String> = []
    private var shorcutIndex: Int = 0
    
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

    @objc static public func enterDoubleTapShortcuts(in viewController: UIViewController){
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        selectedProfile = oscProfileMan.getSelectedProfile()
        guard let selectedProfile = selectedProfile else {return}
        
        let alert = UIAlertController(title: SwiftLocalizationHelper.localizedString(forKey: "Eraser Shortcut"),
                                      message: SwiftLocalizationHelper.localizedString(forKey: "Enter eraser keyboard shortcut:"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = SwiftLocalizationHelper.localizedString(forKey:"Example: e, ctrl+e, alt+e ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile.eraserShortcut
        }

        let okAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                eraserShortcut = comboButtons
            }
            enterBrushShortcut(in: viewController)
        }
        
        let learnMoreAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: SwiftLocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
        })

    }
    
    @objc static public func enterBrushShortcut(in viewController: UIViewController){
                
        let alert = UIAlertController(title: SwiftLocalizationHelper.localizedString(forKey: "Brush Shortcut"),
                                      message: SwiftLocalizationHelper.localizedString(forKey: "Enter brush keyboard shortcut:"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = SwiftLocalizationHelper.localizedString(forKey:"Example: b, ctrl+b, alt+b ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile?.brushShortcut
        }

        let okAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
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
        
        let learnMoreAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: SwiftLocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
             
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
            
        })

    }
    
    @objc static private(set) var squeezeStartShortcut:String = ""
    @objc static private(set) var squeezeEndShortcut:String = ""
    
    @objc static public func enterSqueezeShortcuts(in viewController: UIViewController){
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        selectedProfile = oscProfileMan.getSelectedProfile()
        guard let selectedProfile = selectedProfile else {return}
        
        let alert = UIAlertController(title: SwiftLocalizationHelper.localizedString(forKey: "Squeeze Shortcut"),
                                      message: SwiftLocalizationHelper.localizedString(forKey: "enterSqueezePressShort"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = SwiftLocalizationHelper.localizedString(forKey:"Example: e, ctrl+e, alt+e ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile.squeezeStartShortcut
        }

        let okAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
            let comboButtons = alert.textFields?[0].text ?? ""
            let keyStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: comboButtons)
            if keyStrings?.count ?? 0 > 0 || comboButtons == "" {
                squeezeStartShortcut = comboButtons
            }
            enterSqueezeEndShortcut(in: viewController)
        }
        
        let learnMoreAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: SwiftLocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
        
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
        })
    }

    @objc static public func enterSqueezeEndShortcut(in viewController: UIViewController){
                
        let alert = UIAlertController(title: SwiftLocalizationHelper.localizedString(forKey: "Squeeze Shortcut"),
                                      message: SwiftLocalizationHelper.localizedString(forKey: "enterSqueezeReleaseShort"),
                                      preferredStyle: .alert)
        
        alert.addTextField { textField in
            textField.placeholder = SwiftLocalizationHelper.localizedString(forKey:"Example: b, ctrl+b, alt+b ...")
            textField.keyboardType = .asciiCapable
            textField.autocorrectionType = .no
            textField.spellCheckingType = .no
            textField.text = selectedProfile?.squeezeEndShortcut
        }

        let okAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "OK"), style: .default) { _ in
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
        
        let learnMoreAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Learn More"), style: .default) { _ in
            if let url = URL(string: SwiftLocalizationHelper.localizedString(forKey: "pencilKeyboardCmdURL")) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }
             
        alert.addAction(learnMoreAction)
        alert.addAction(okAction)

        viewController.present(alert, animated: true, completion: {
            
        })
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
