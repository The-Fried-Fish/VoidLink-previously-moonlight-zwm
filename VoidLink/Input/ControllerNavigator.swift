//
//  ControllerNavigator.swift
//  VoidLink
//
//  Created by True砖家 on 2026/7/1.
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import Foundation
import GameController
import ObjectiveC
import UIKit

final class ControllerNavigationElement: NSObject {
    var control:ControllerElement
    var action:String
    var isInAction:Bool = false
    init(control: ControllerElement, action: String){
        self.control = control
        self.action = action
    }
}

private var controllerNavigationSelectedIndexPathKey: UInt8 = 0
private var controllerNavigationPersistTokenKey: UInt8 = 0
private var controllerNavigationHighlightGenerationKey: UInt8 = 0
private var controllerMouseCurvePreviewViewKey: UInt8 = 0
private var controllerMouseCurvePreviewDismissWorkItemKey: UInt8 = 0
private let settingsControllerNavigationHighlightedIdentifierKey = "SettingsControllerNavigationHighlightedIdentifier"
private let hostControllerNavigationHighlightedUUIDKey = "HostControllerNavigationHighlightedUUID"
private let settingsExcludedControllerNavigationSectionIdentifiers: Set<String> = [
    "SettingsSectionTouch&Controller",
    "SettingsSectionPencil"
]

@available(iOS 13.0, *)
private final class ControllerMouseCurvePreviewView: UIView {
    var expo: CGFloat = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 1
    }

    override func draw(_ rect: CGRect) {
        let isDark = ThemeManager.userInterfaceStyle() == .dark
        let backgroundColor = isDark
            ? UIColor(white: 0.08, alpha: 0.88)
            : UIColor.white.withAlphaComponent(0.92)
        let axisColor = ThemeManager.textColor.withAlphaComponent(isDark ? 0.62 : 0.48)
        let textColor = ThemeManager.textColor.withAlphaComponent(isDark ? 0.78 : 0.68)
        let curveColor = ThemeManager.appPrimaryColor
        layer.borderColor = ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.32 : 0.22).cgColor

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)

        let footerHeight: CGFloat = 22
        let xLabelHeight: CGFloat = 24
        let plotHorizontalMargin: CGFloat = 34
        let chartRect = bounds.inset(by: UIEdgeInsets(top: 18, left: 0, bottom: footerHeight + xLabelHeight, right: 0))
        let plotSide = min(bounds.width - plotHorizontalMargin * 2, chartRect.height)
        let plotRect = CGRect(
            x: bounds.midX - plotSide / 2,
            y: chartRect.midY - plotSide / 2,
            width: plotSide,
            height: plotSide
        )
        guard plotRect.width > 1, plotRect.height > 1 else { return }

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: textColor
        ]

        ("Cursor Speed".localized as NSString).draw(at: CGPoint(x: plotRect.minX + 8, y: plotRect.minY + 8), withAttributes: textAttributes)
        let xAxisTitle = "Stick Offset".localized as NSString
        let xAxisTitleSize = xAxisTitle.size(withAttributes: textAttributes)
        xAxisTitle.draw(at: CGPoint(x: plotRect.midX - xAxisTitleSize.width / 2, y: plotRect.maxY + 10), withAttributes: textAttributes)

        context.setStrokeColor(axisColor.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: plotRect.minX, y: plotRect.minY))
        context.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        context.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        context.strokePath()

        ("0" as NSString).draw(at: CGPoint(x: plotRect.minX - 10, y: plotRect.maxY - 8), withAttributes: textAttributes)
        ("1" as NSString).draw(at: CGPoint(x: plotRect.minX - 10, y: plotRect.minY - 7), withAttributes: textAttributes)
        ("1" as NSString).draw(at: CGPoint(x: plotRect.maxX - 4, y: plotRect.maxY + 10), withAttributes: textAttributes)

        let guidePath = UIBezierPath()
        guidePath.move(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        guidePath.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.minY))
        context.saveGState()
        context.setLineDash(phase: 0, lengths: [4, 4])
        axisColor.withAlphaComponent(0.35).setStroke()
        guidePath.lineWidth = 1
        guidePath.stroke()
        context.restoreGState()

        let curvePath = UIBezierPath()
        for step in 0...120 {
            let normalizedX = CGFloat(step) / 120
            let speed = abs(PublicUtils.controllerMouseExpoMappedOffset(normalizedX, expo: expo))
            let point = CGPoint(
                x: plotRect.minX + normalizedX * plotRect.width,
                y: plotRect.maxY - min(max(speed, 0), 1) * plotRect.height
            )
            if step == 0 {
                curvePath.move(to: point)
            } else {
                curvePath.addLine(to: point)
            }
        }

        curveColor.setStroke()
        curvePath.lineWidth = 3
        curvePath.lineCapStyle = .round
        curvePath.lineJoinStyle = .round
        curvePath.stroke()

        let footerParagraphStyle = NSMutableParagraphStyle()
        footerParagraphStyle.alignment = .center
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.roundedSystemFont(ofSize: 10, weight: .medium),
            .foregroundColor: textColor.withAlphaComponent(0.76),
            .paragraphStyle: footerParagraphStyle
        ]
        ("Inspired by RC hobby transmitters".localized as NSString).draw(
            in: CGRect(x: 12, y: bounds.maxY - footerHeight + 1, width: bounds.width - 24, height: footerHeight - 2),
            withAttributes: footerAttributes
        )
    }
}

private final class ControllerDrivenUIKitAnimationWakeToken {
    private var wakeView: UIView?
    private var toggled = false

    func wake(attachedTo view: UIView) {
        let container = view.window ?? view
        let wakeView = preparedWakeView(in: container)

        toggled.toggle()
        UIView.animate(
            withDuration: 0.6,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                wakeView.alpha = self.toggled ? 0.002 : 0.001
            }
        )
    }

    private func preparedWakeView(in container: UIView) -> UIView {
        if let wakeView, wakeView.superview === container {
            return wakeView
        }

        wakeView?.removeFromSuperview()

        let wakeView = UIView(frame: CGRect(x: -2, y: -2, width: 1, height: 1))
        wakeView.isUserInteractionEnabled = false
        wakeView.backgroundColor = .black
        wakeView.alpha = 0.001
        container.addSubview(wakeView)
        self.wakeView = wakeView
        return wakeView
    }
}

@available(iOS 13.0, *)
@objc protocol ControllerNavigatorRadialMenuDelegate: AnyObject {
    func controllerNavigatorDidSelect(item: RadialMenuItem)
}

@available(iOS 13.0, *)
@objc protocol ControllerUINavigationDelegate: AnyObject {
    func getNavigationElements() -> [ControllerNavigationElement]
    func navigateByController(forward: Bool)
    func navigateByController(downward: Bool)
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation:ControllerNavigationElement)
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation:ControllerNavigationElement)
    func persistControllerNavigationHighlight()
    func restoreControllerNavigationHighlight()
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch()
}

protocol ControllerNavigationHighlightTargetProviding: AnyObject {
    var controllerNavigationHighlightTargetView: UIView { get }
    func controllerNavigationHighlightDidApply()
    func controllerNavigationHighlightDidClear()
}

extension ControllerNavigationHighlightTargetProviding {
    func controllerNavigationHighlightDidApply() {
    }

    func controllerNavigationHighlightDidClear() {
    }
}

@available(iOS 13.0, *)
protocol ControllerCollectionNavigationDelegate: ControllerUINavigationDelegate where Self: UIViewController {
    var controllerNavigationCollectionView: UICollectionView { get }
    func controllerNavigationCurrentIndexPathForControllerNavigator() -> IndexPath?
    func clearCollectionControllerNavigationHighlightForControllerNavigator()
}

@available(iOS 13.0, *)
final class ControllerNavigator: NSObject {
    typealias Handler = (_ buttonDict: NSDictionary, _ gamepad: GCExtendedGamepad, _ element: GCControllerElement) -> Void

    private static weak var listeningController: GCController?
    static weak var radialMenuDelegate: ControllerNavigatorRadialMenuDelegate?
    @objc static weak var uiNavigationDelegate: ControllerUINavigationDelegate?
    private static weak var previousUINavigationDelegate: ControllerUINavigationDelegate?
    private static var swapABXY = false
    @objc static var radialMenuView: RadialMenuOverlayView?
    @objc static var stickReleasedInRadialMenu: Bool = false
    @objc static var radialMenuButton: ControllerElement = .leftShoulder
    @objc static var radialMenuButtonPool: NSMutableSet {
        let pool:NSMutableSet = NSMutableSet()
        pool.add(ControllerElement.leftTrigger.rawValue)
        pool.add(ControllerElement.rightTrigger.rawValue)
        pool.add(ControllerElement.leftShoulder.rawValue)
        pool.add(ControllerElement.rightShoulder.rawValue)
        pool.add(ControllerElement.select.rawValue)
        pool.add(ControllerElement.start.rawValue)
        pool.add(ControllerElement.special.rawValue)
        pool.add(ControllerElement.paddle1.rawValue)
        pool.add(ControllerElement.paddle2.rawValue)
        pool.add(ControllerElement.paddle3.rawValue)
        pool.add(ControllerElement.paddle4.rawValue)
        return pool
    }
    
    @objc static var radialMenuButtonPosition: ControllerElementPosition {
        var position:ControllerElementPosition = .undefined
        if radialMenuButton.position != .middle && radialMenuButton.position != .undefined {position = radialMenuButton.position}
        else {
            if radialMenuButton == localRadialMenuButton {position = customPositionForLocalRadialMenuButton}
            if radialMenuButton == streamingRadialMenuButton {position = customPositionForStreamingRadialMenuButton}
        }
        return position
    }

    
    @objc static var enabled: Bool = true {
        didSet{
            if enabled {
                if let settingViewVC = uiNavigationDelegate as? SettingsViewController {
                    settingViewVC.highlightViewForControllerNavigator(by: "controllerNavigationStack")
                    GamepadNavigationIllustrationHud.updateHud()
                }
            }
            else {
                stop()
            }
        }
    }
    
    @objc static var localRadialMenuButton: ControllerElement = .leftShoulder
    @objc static var customPositionForLocalRadialMenuButton: ControllerElementPosition = .left
    @objc static var streamingRadialMenuButton: ControllerElement = .leftShoulder
    @objc static var customPositionForStreamingRadialMenuButton: ControllerElementPosition = .left
    @objc static var streamingRadialMenuDelay: TimeInterval = 0
    
    private static var controllerMouseTimer: SafeTimer?
    @objc static var controllerMouseStick: ControllerElement = .rightStick
    @objc static var controllerMouseLeftButton: ControllerElement = .dpadRight
    @objc static var controllerMouseRightButton: ControllerElement = .dpadDown
    @objc static var controllerMouseVelocity: CGFloat = 11.3
    @objc static var controllerMouseExpo: CGFloat = 1.6
    private static var controllerMouseInputX: CGFloat = 0
    private static var controllerMouseInputY: CGFloat = 0
    private static var controllerMouseWheelInputX: CGFloat = 0
    private static var controllerMouseWheelInputY: CGFloat = 0
    private static var controllerMouseFrameRate = 60
    @objc static var controllerMouseEnabled: Bool {
        return radialMenuState == .mouseModeEnabled
    }
    private static var controllerMouseNavigationElements: [ControllerNavigationElement] {
        var elements = [ControllerNavigationElement]()
        elements.append(ControllerNavigationElement(control:ControllerNavigator.controllerMouseStick, action: "moveCursor"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.controllerMouseLeftButton, action: "leftButton"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.controllerMouseRightButton, action: "rightButton"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.controllerMouseStick.position == .left ? .rightStick : .leftStick, action: "verticalHorizontalScroll"))
        return elements
    }
    
    static var settingsFavoriteReorderActive: Bool = false
    static var settingsReadTipPendingToken = 0
    static var settingsReadTipPendingWorkItem: DispatchWorkItem?
    static var settingsReadTipPressedAgain = false
    static var settingsReadTipSuppressNextRelease = false
    
    static var navigationTimer: SafeTimer?
    private static let navigationInitialRepeatDelay: TimeInterval = 0.23
    private static let navigationContinuousRepeatInterval: TimeInterval = 0.177
    private static let controllerDrivenUIKitAnimationWakeToken = ControllerDrivenUIKitAnimationWakeToken()
    @objc static weak var controllerNavigationHighlightedView: UIView?
    private static let installAlertControllerNavigationHook: Void = {
        UIAlertController.installControllerNavigationDelegateHook()
    }()

    static func wakeControllerDrivenUIKitAnimationIfNeeded(attachedTo view: UIView) {
        controllerDrivenUIKitAnimationWakeToken.wake(attachedTo: view)
    }

    @objc static func setRadialMenuDelegate(_ delegate: ControllerNavigatorRadialMenuDelegate?) {
        _ = installAlertControllerNavigationHook
        radialMenuDelegate = delegate
    }

    @objc static func setUINavigationDelegate(_ delegate: ControllerUINavigationDelegate?) {
        _ = installAlertControllerNavigationHook
        if let currentDelegate = uiNavigationDelegate,
           let nextDelegate = delegate,
           currentDelegate !== nextDelegate, !(currentDelegate is UIAlertController) {
            previousUINavigationDelegate = currentDelegate
        }

        uiNavigationDelegate = delegate
        updateUINavigationDelegateState()
    }
    
    @objc static func setStreamFrameVCAsUINavigationDelegate() {
        if let delegate: ControllerUINavigationDelegate? = StreamFrameViewController.sharedInstance() {
            _ = installAlertControllerNavigationHook
            if let currentDelegate = uiNavigationDelegate,
               let nextDelegate = delegate,
               currentDelegate !== nextDelegate, !(currentDelegate is UIAlertController) {
                previousUINavigationDelegate = currentDelegate
            }
            uiNavigationDelegate = delegate
            listenToRadialMenuButton()
            GamepadNavigationIllustrationHud.updateHud()
        }
    }

    @objc static func restorePreviousUINavigationDelegate(ifCurrentDelegateIs delegate: ControllerUINavigationDelegate) {
        guard uiNavigationDelegate === delegate else { return }
        /*
        if previousUINavigationDelegate is StreamFrameViewController {
            ControllerSupport.sharedInstance()?.reinitiatePrimaryController()
            return
        } */
        
        
        uiNavigationDelegate = previousUINavigationDelegate
        // previousUINavigationDelegate = nil
        updateUINavigationDelegateState()
    }

    static func updateUINavigationDelegateState() {
        ControllerUtil.disableSysGestures(ControllerUtil.primaryGCController)
        if uiNavigationDelegate is StreamFrameViewController {
            if radialMenuState == .mouseModeEnabled {
                startControllerMouse()
                // GamepadNavigationIllustrationHud.updateNavigationElements(controllerMouseNavigationElements)
                return
            }
            ControllerSupport.sharedInstance()?.reinitiatePrimaryController()
            GamepadNavigationIllustrationHud.updateHud()
            return;
        }
        
        restartListening()
        GamepadNavigationIllustrationHud.updateHud()
    }

    @objc static func restoreUINavigationHighlight() {
        guard enabled else {return}
        uiNavigationDelegate?.restoreControllerNavigationHighlight()
    }

    @objc static func persistUINavigationHighlight() {
        guard enabled else {return}
        uiNavigationDelegate?.persistControllerNavigationHighlight()
        if previousUINavigationDelegate !== uiNavigationDelegate {
            previousUINavigationDelegate?.persistControllerNavigationHighlight()
        }
    }

    @objc static func restoreSettingsModeSwitchHighlight() {
        guard enabled else {return}
        uiNavigationDelegate?.restoreControllerNavigationHighlightAfterSettingsModeSwitch()
    }
    
    @objc static func updateHudForCustomRadialMenuButtonPosition() {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control: .dpadLeft, action: "Left"))
        elements.append(ControllerNavigationElement(control: .dpadRight, action: "Right"))
        elements.append(ControllerNavigationElement(control: .dpadUp, action: "Centered (PlayStation)"))
        GamepadNavigationIllustrationHud.updateNavigationElements(elements, forceDisplay: true)
    }
    
    
    /// Controller Mouse

    @objc static func startControllerMouse() {
        controllerMouseInputX = 0
        controllerMouseInputY = 0
        startControllerMouseTimer(frameRate: controllerMouseFrameRate)
        ControllerUtil.stopListeningPrimaryController()
        listenToControllerMouse()
        DispatchQueue.main.async {
            GamepadNavigationIllustrationHud.updateNavigationElements(controllerMouseNavigationElements)
            DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                GamepadNavigationIllustrationHud.clearHud()
            }
        }
    }
    
    @objc static func configureControllerMouse(with settings: TemporarySettings) {
        // controllerMouseEnabledFlag = false
        controllerMouseStick = ControllerElement(rawValue: settings.controllerMouseStick.int32Value) ?? .rightStick
        controllerMouseLeftButton = ControllerElement(rawValue: settings.controllerMouseLeftButton.int32Value) ?? .dpadRight
        controllerMouseRightButton = ControllerElement(rawValue: settings.controllerMouseRightButton.int32Value) ?? .dpadDown
        controllerMouseExpo = CGFloat(settings.controllerMouseExpo.floatValue)
        controllerMouseFrameRate = max(settings.framerate.intValue, 1)
        controllerMouseVelocity = PublicUtils.controllerMouseVelocity(
            pointerVelocity: CGFloat(settings.controllerMousePointerVelocity.floatValue),
            frameRate: CGFloat(controllerMouseFrameRate)
        )
    }

    private static func startControllerMouseTimer(frameRate: Int) {
        guard radialMenuState == .mouseModeEnabled else {
            return
        }

        controllerMouseTimer = SafeTimer(interval: 1/TimeInterval(frameRate)) {
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.002) {
                guard radialMenuState == .mouseModeEnabled else { return }
                let moveVector = PublicUtils.controllerMouseMoveVector(
                    stickX: controllerMouseInputX,
                    stickY: controllerMouseInputY,
                    velocity: controllerMouseVelocity,
                    expo: controllerMouseExpo
                )
                
                LiSendMouseMoveEvent(clampedInt16(moveVector.dx), clampedInt16(moveVector.dy))

                let scrollVector = PublicUtils.controllerMouseScrollVector(
                    stickX: controllerMouseWheelInputX,
                    stickY: controllerMouseWheelInputY,
                    multiplier: 15
                )
                if abs(scrollVector.dy) > abs(scrollVector.dx) {
                    LiSendHighResScrollEvent(clampedInt16(scrollVector.dy))
                }
                else {
                    LiSendHighResHScrollEvent(clampedInt16(scrollVector.dx))
                }
            }
        }
        
        controllerMouseTimer?.restart()
    }

    private static func stopControllerMouseTimer() {
        controllerMouseInputX = 0
        controllerMouseInputY = 0
        controllerMouseTimer?.clean()
    }

    private static func swappedFaceButtonIfNeeded(_ button: ControllerElement, swapABXY: Bool) -> ControllerElement {
        guard swapABXY else { return button }
        switch button {
        case .a:
            return .b
        case .b:
            return .a
        case .x:
            return .y
        case .y:
            return .x
        default:
            return button
        }
    }

    private static func clampedInt16(_ value: CGFloat) -> Int16 {
        let roundedValue = value.rounded()
        if roundedValue > CGFloat(Int16.max) {
            return Int16.max
        }
        if roundedValue < CGFloat(Int16.min) {
            return Int16.min
        }
        return Int16(roundedValue)
    }
    
    /*
    @objc static func start(swapABXY: Bool = false) {
        Self.swapABXY = swapABXY
        installControllerObserversIfNeeded()
        listenFirstAvailableController()
     
    }

*/
    private static func navigateContinuously(forward: Bool) {
        navigationTimer?.clean()
        uiNavigationDelegate?.navigateByController(forward: forward)
        navigationTimer = SafeTimer(
            interval: navigationContinuousRepeatInterval,
            delay: navigationInitialRepeatDelay
        ) {
            uiNavigationDelegate?.navigateByController(forward: forward)
        }
        navigationTimer?.restart(minimumRunCount: 0)
    }
    
    private static func navigateContinuously(downward: Bool) {
        navigationTimer?.clean()
        uiNavigationDelegate?.navigateByController(downward: downward)
        navigationTimer = SafeTimer(
            interval: navigationContinuousRepeatInterval,
            delay: navigationInitialRepeatDelay
        ) {
            uiNavigationDelegate?.navigateByController(downward: downward)
        }
        navigationTimer?.restart(minimumRunCount: 0)
    }

    @objc static func start() {
        guard let controller = ControllerUtil.primaryGCController, controller.extendedGamepad != nil else { return }
        restartListening()
        GamepadNavigationIllustrationHud.updateHud()
    }

    @objc static func stop() {
        ControllerUtil.stopListeningPrimaryController(stopListenToRadialMenuButton: true)
        radialMenuView?.dismiss()
        radialMenuView = nil
        GamepadNavigationIllustrationHud.clearHud()
        clearNavigationHighlights()
    }

    @objc static func clearNavigationHighlights() {
        PublicUtils.runOnMain {
            if let mainFrameVC = radialMenuDelegate as? MainFrameViewController {
                mainFrameVC.settingsViewController?.clearControllerNavigationHighlightForControllerNavigator()
                mainFrameVC.hostCollectionVC?.clearCollectionControllerNavigationHighlightForControllerNavigator()
            } else {
                (uiNavigationDelegate as? SettingsViewController)?.clearControllerNavigationHighlightForControllerNavigator()
                (uiNavigationDelegate as? ControllerCollectionNavigationDelegate)?.clearCollectionControllerNavigationHighlightForControllerNavigator()
            }

            controllerNavigationHighlightedView = nil
        }
    }
    
    private static func performRadialMenuAction(_ item: RadialMenuItem) {
        radialMenuDelegate?.controllerNavigatorDidSelect(item:item)
        switch item {
        case .gameProfiles, .addHost, .aboutView:
            radialMenuView?.dismiss()
            radialMenuView = nil
        case .disconnect:
            if radialMenuState == .disconnectAndQuit {
                radialMenuView?.dismiss()
                radialMenuView = nil
                StreamFrameViewController.sharedInstance().returnToMainFrame()
                break
            }
            else {
                radialMenuState = .disconnectAndQuit
                updateRadialMenu()
                break
            }
        case .quitApp:
            radialMenuView?.dismiss()
            radialMenuView = nil
            StreamFrameViewController.sharedInstance().disconnectAndQuitApp()
        case .more:
            radialMenuState = .moreOptions
            updateRadialMenu()
        case .mouse:
            if radialMenuState != .mouseModeEnabled {
                radialMenuState = .mouseModeEnabled
                updateRadialMenu()
            }
            else {
                stopControllerMouseTimer()
                radialMenuState = .main
                updateRadialMenu()
            }
        case .theme:
            let targetTheme: UIUserInterfaceStyle = ThemeManager.userInterfaceStyle() == .light ? .dark : .light
            DispatchQueue.main.async {
                ThemeManager.setUserInterfaceStyle(targetTheme)
                if let mainFrameVC = radialMenuDelegate as? MainFrameViewController, let settingsViewVC = mainFrameVC.settingsViewController {
                    settingsViewVC.appThemeSelector.selectedSegmentIndex = targetTheme.rawValue
                }
            }
            let dataMan = DataManager()
            let settings = dataMan.retrieveSettings()
            settings?.appTheme = NSNumber(value: targetTheme.rawValue)
            dataMan.saveData()
        case .navigationSettings:
            DispatchQueue.main.async {
                radialMenuView?.dismiss()
                radialMenuView = nil
                if let mainFrameVC = radialMenuDelegate as? MainFrameViewController {
                    mainFrameVC.expandSettingsView()
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.3) {
                        if let settingViewVC = uiNavigationDelegate as? SettingsViewController {
                            settingViewVC.expandGamepadSection()
                            settingViewVC.highlightViewForControllerNavigator(by: "controllerNavigationStack")
                        }
                    }
                }
            }
        case .exit:
            exit(0)
        case .toolbox:
            DispatchQueue.main.async {
                radialMenuView?.dismiss()
                radialMenuView = nil
                StreamFrameViewController.sharedInstance().bringUpToolboxMenuWithoutWidgetLayoutTool()
            }
        default:
            break
        }
    }
    
    @objc static func updateRadialMenu() {
        controllerMouseInputX = 0
        controllerMouseInputY = 0
        navigationTimer?.clean()
        ControllerUtil.stopListeningPrimaryController()
        if let mainFrameVC = radialMenuDelegate as? MainFrameViewController {
            let streamFrameVC = StreamFrameViewController.sharedInstance()
            let showRadialMenu = mainFrameVC.isStreaming() ? streamFrameVC?.hasNoPresentedVC == true : (mainFrameVC.hasNoPresentedVC || mainFrameVC.presentedViewController is LoadingFrameViewController)
            
            if showRadialMenu {
                radialMenuView?.removeFromSuperview()
                RadialMenuOverlayView.menuSectors.removeAll()
                
                if radialMenuState == .disconnectAndQuit {
                    RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Quit App".localized, subtitle: "", symbol: PublicUtils.quitSymbol(), item: .quitApp))
                    RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Disconnect".localized, subtitle: "", symbol: PublicUtils.disconnectSymbol(), item: .disconnect))
                    radialMenuView = RadialMenuOverlayView.presentInKeyWindow()
                    listenToRadialMenuStick()
                    return
                }
                
                let navigationSettingsItem = RadialMenuSector(title: "Navigation Settings".localized, subtitle: "", symbol:"gear", item: .navigationSettings)
                
                if radialMenuState == .moreOptions {
                    if mainFrameVC.isStreaming() {
                        RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Game Profiles".localized, subtitle: "", symbol:PublicUtils.iOS18Available ? "gamecontroller.circle" : "gamecontroller.fill", item: .gameProfiles))
                        RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "=toolbox".localized, subtitle: "", symbol: "apple.terminal", item: .toolbox))
                    }
                    else {
                        if !mainFrameVC.isInAppView(), !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "About".localized, subtitle: "", symbol: "questionmark.circle", item: .aboutView))}
                        if !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Theme".localized, subtitle: "", symbol: "circle.lefthalf.filled", item: .theme))}
                        if !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.appendIfNotContains(navigationSettingsItem)}
                        if !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Exit".localized, subtitle: "", symbol: "rectangle.portrait.and.arrow.right", item: .exit))}
                    }
                    RadialMenuOverlayView.menuSectors.appendIfNotContains(navigationSettingsItem)
                    
                    radialMenuView = RadialMenuOverlayView.presentInKeyWindow()
                    listenToRadialMenuStick()
                    return
                }
                
                let gameProfileItem = RadialMenuSector(title: "Game Profiles".localized, subtitle: "", symbol:PublicUtils.iOS18Available ? "gamecontroller.circle" : "gamecontroller.fill", item: .gameProfiles)
                
                RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Settings Menu".localized, subtitle: "", symbol: "sidebar.left", item: .settings))
                
                if mainFrameVC.settingsViewExpanded {
                    if mainFrameVC.settingsViewController.currentSettingsMenuMode == .AllSettings {
                        RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Favorite Settings".localized, subtitle: "", symbol: "bookmark", item: .favoriteSettings))
                        RadialMenuOverlayView.menuSectors.appendIfNotContains(gameProfileItem)
                        RadialMenuOverlayView.menuSectors.appendIfNotContains(navigationSettingsItem)
                    }
                    if mainFrameVC.settingsViewController.currentSettingsMenuMode == .FavoriteSettings {
                        RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "All Settings".localized, subtitle: "", symbol: "circle.grid.3x3", item: .allSettings))
                    }
                }
                
                if !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "=more".localized, subtitle: "", symbol: "ellipsis.circle", item: .more))}

                if !mainFrameVC.isStreaming() || radialMenuState == .moreOptions { RadialMenuOverlayView.menuSectors.appendIfNotContains(gameProfileItem)
                }
                
                if mainFrameVC.isInAppView(), !mainFrameVC.isStreaming(), !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Host View".localized, subtitle: "", symbol: PublicUtils.liquidGlassEnabled ? "macwindow.on.rectangle" : "tv", item: .hostView))}
                
                if !mainFrameVC.isInAppView(), !mainFrameVC.isStreaming(), !mainFrameVC.settingsViewExpanded {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Add Host".localized, subtitle: "", symbol: "plus.circle", item: .addHost))}
                
                if mainFrameVC.isStreaming(), !mainFrameVC.settingsExpandedInStreamView {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Controller Mouse".localized, subtitle: "", symbol: radialMenuState == .mouseModeEnabled ? "disableControllerMouse" : "controllerMouse", item: .mouse))}
                if mainFrameVC.isStreaming(), !mainFrameVC.settingsExpandedInStreamView {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Disconnect".localized, subtitle: "", symbol: PublicUtils.disconnectSymbol(), item: .disconnect))}
                // if mainFrameVC.isStreaming(), !mainFrameVC.settingsExpandedInStreamView {RadialMenuOverlayView.menuSectors.append(RadialMenuSector(title: "Quit App".localized, subtitle: "", symbol: PublicUtils.quitSymbol(), item: .quitApp))}
                radialMenuView = RadialMenuOverlayView.presentInKeyWindow()
            }
        }
        listenToRadialMenuStick()
    }
    
    private static func listenToRadialMenuStick() {
        let radialMenuStick: ControllerElement = radialMenuButtonPosition == .right ? .leftStick : .rightStick
        ControllerUtil.listenPrimaryControllerStick(radialMenuStick) { offsetVector in
            GamepadNavigationIllustrationHud.updateActionState(for: radialMenuStick, isInAction: hypot(offsetVector.dx, offsetVector.dy) >= 0.1)
            if let selectedItem = radialMenuView?.updateSelection(
                xOffset: offsetVector.dx,
                yOffset: offsetVector.dy
            ) {
                PublicUtils.runOnMain {
                    stickReleasedInRadialMenu = true
                    performRadialMenuAction(selectedItem)
                }
            }
        }
    }
    
    @objc static var radialMenuButtonPressed: Bool = false
    private static var radialMenuDelayTimer: SafeTimer?
    private static var radialMenuState: RadialMenuState = .main
    private static var radialMenuPressDownTimestamp: TimeInterval = 0.0
    @objc static func listenToRadialMenuButton() {
        guard enabled else {return}
        guard let mainFrameVC = radialMenuDelegate as? MainFrameViewController else {return}
        radialMenuState = .main
        radialMenuButton = mainFrameVC.isStreaming() ? streamingRadialMenuButton : localRadialMenuButton
        ControllerUtil.listenPrimaryControllerButton(radialMenuButton) { pressed in
            GamepadNavigationIllustrationHud.updateActionState(for: radialMenuButton, isInAction: pressed)
            if pressed {
                radialMenuPressDownTimestamp = CACurrentMediaTime()
                radialMenuDelayTimer?.clean()
                radialMenuButtonPressed = true
                let delayRadialMenu = (mainFrameVC.isStreaming() && !mainFrameVC.settingsExpandedInStreamView) || streamingRadialMenuDelay < 0.03
                streamingRadialMenuDelay = max(streamingRadialMenuDelay, 0.032)
                
                if delayRadialMenu {
                    radialMenuDelayTimer = SafeTimer(interval: streamingRadialMenuDelay) {
                        if radialMenuDelayTimer?.remainingMinimumRunCount == 2 {return}
                        if radialMenuButtonPressed {
                            DispatchQueue.main.async {
                                self.updateRadialMenu()
                                radialMenuDelayTimer?.clean()
                            }
                        }
                    }
                    radialMenuDelayTimer?.restart(minimumRunCount: 2)
                }
                else {
                    self.updateRadialMenu()
                }
            }
            else {
                guard CACurrentMediaTime() - radialMenuPressDownTimestamp > 0.035 else {
                    return
                }
                radialMenuButtonPressed = false
                radialMenuDelayTimer?.clean()
                stickReleasedInRadialMenu = false
                if radialMenuView == nil, let vc = uiNavigationDelegate as? StreamFrameViewController, vc.hasNoPresentedVC {
                    ControllerSupport.sharedInstance()?.sendNavigationButtonPress()
                    return
                }
                radialMenuView?.dismiss()
                radialMenuView = nil
                ControllerNavigator.updateUINavigationDelegateState()
            }
        }
    }
    
    private static func listenToNavigationCluster() {
        guard let mainFrameVC = radialMenuDelegate as? MainFrameViewController else {return}
        
        let upNavButton: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .dpadUp : .y
        let downNavButton: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .dpadDown : .a
        let leftNavButton: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .dpadLeft : .x
        let rightNavButton: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .dpadRight : .b

        if let uiNavigationDelegate = uiNavigationDelegate, !mainFrameVC.isStreaming() || mainFrameVC.settingsExpandedInStreamView || uiNavigationDelegate is ToolboxViewController || uiNavigationDelegate is ProfileSelectorViewController {
            let verticalNavigationAxis: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .leftStickY : .rightStickY
            ControllerUtil.listenPrimaryControllerStickAxis(verticalNavigationAxis, threshold: 0.6) {state in
                GamepadNavigationIllustrationHud.updateActionState(for: verticalNavigationAxis, isInAction: state != .orderedSame)
                guard radialMenuView == nil else {return}
                switch state {
                case .orderedAscending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is SettingsViewController {
                            navigateContinuously(downward: true)
                        }
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(downward: true)
                        }
                    }
                case .orderedDescending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is SettingsViewController {
                            navigateContinuously(downward: false)
                        }
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(downward: false)
                        }
                    }
                case .orderedSame:
                    navigationTimer?.clean()
                    if let settingsViewController = uiNavigationDelegate as? SettingsViewController,
                       let store = settingsViewController.swiftUISettingsStore,
                       store.isActive {
                        store.cancelPendingHighlightMoves()
                    }
                }
            }
            ControllerUtil.listenPrimaryControllerButton(upNavButton) {pressed in 
                GamepadNavigationIllustrationHud.updateActionState(for: upNavButton, isInAction: pressed)
                if pressed {
                    uiNavigationDelegate.navigateByController(downward: false)
                }
            }
            ControllerUtil.listenPrimaryControllerButton(downNavButton) {pressed in
                GamepadNavigationIllustrationHud.updateActionState(for: downNavButton, isInAction: pressed)
                if pressed {
                    uiNavigationDelegate.navigateByController(downward: true)
                }
            }
        }
                
        if let uiNavigationDelegate = uiNavigationDelegate, !mainFrameVC.isStreaming() || uiNavigationDelegate is ToolboxViewController || uiNavigationDelegate is ProfileSelectorViewController {
            let horizontalNavigationAxis: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .leftStickX : .rightStickX
            ControllerUtil.listenPrimaryControllerStickAxis(horizontalNavigationAxis, threshold: 0.6) {state in
                GamepadNavigationIllustrationHud.updateActionState(for: horizontalNavigationAxis, isInAction: state != .orderedSame)
                guard radialMenuView == nil else {return}
                switch state {
                case .orderedAscending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(forward: false)
                        }
                    }
                case .orderedDescending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(forward: true)
                        }
                    }
                case .orderedSame:
                    navigationTimer?.clean()
                }
            }
            ControllerUtil.listenPrimaryControllerButton(leftNavButton) {pressed in
                GamepadNavigationIllustrationHud.updateActionState(for: leftNavButton, isInAction: pressed)
                if pressed {
                    uiNavigationDelegate.navigateByController(forward: false)
                }
            }
            ControllerUtil.listenPrimaryControllerButton(rightNavButton) {pressed in
                GamepadNavigationIllustrationHud.updateActionState(for: rightNavButton, isInAction: pressed)
                if pressed {
                    uiNavigationDelegate.navigateByController(forward: true)
                }
            }
        }

    }
    
    @objc static func listenToControllerMouse() {
        guard radialMenuState == .mouseModeEnabled else { return }
        ControllerUtil.listenPrimaryControllerButton(controllerMouseLeftButton){ pressed in
            GamepadNavigationIllustrationHud.updateActionState(for: controllerMouseLeftButton, isInAction: pressed)
            LiSendMouseButtonEvent(CChar(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE), BUTTON_LEFT)
        }
        ControllerUtil.listenPrimaryControllerButton(controllerMouseRightButton){ pressed in
            GamepadNavigationIllustrationHud.updateActionState(for: controllerMouseRightButton, isInAction: pressed)
            LiSendMouseButtonEvent(CChar(pressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE), BUTTON_RIGHT)
        }
        ControllerUtil.listenPrimaryControllerStick(controllerMouseStick){ offsetVector in
            GamepadNavigationIllustrationHud.updateActionState(for: controllerMouseStick, isInAction: hypot(offsetVector.dx, offsetVector.dy) >= 0.1)
            // print("performRadialMenuAction mouse \(offsetVector) \(CACurrentMediaTime())")
            controllerMouseInputX = offsetVector.dx
            controllerMouseInputY = offsetVector.dy
        }
        let wheelStick: ControllerElement = controllerMouseStick == .rightStick ? .leftStick : .rightStick
        ControllerUtil.listenPrimaryControllerStick(wheelStick) { offsetVector in
            GamepadNavigationIllustrationHud.updateActionState(for: wheelStick, isInAction: hypot(offsetVector.dx, offsetVector.dy) >= 0.1)
            controllerMouseWheelInputX = offsetVector.dx
            controllerMouseWheelInputY = offsetVector.dy
        }
    }
    
    @objc static func restartListening() {
        guard enabled else {
            ControllerUtil.stopListeningPrimaryController(stopListenToRadialMenuButton: true)
            GamepadNavigationIllustrationHud.clearHud()
            return
        }
                
        ControllerUtil.stopListeningPrimaryController()
        GamepadNavigationIllustrationHud.resetActionStates()
        
        guard let mainFrameVC = radialMenuDelegate as? MainFrameViewController else {return}
        
        listenToRadialMenuButton()
        listenToRadialMenuStick()
        listenToNavigationCluster()

        /*
        if let uiNavigationDelegate = uiNavigationDelegate, !mainFrameVC.isStreaming() || mainFrameVC.settingsExpandedInStreamView || uiNavigationDelegate is ToolboxViewController || uiNavigationDelegate is ProfileSelectorViewController {
            let verticalNavigationAxis: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .leftStickY : .rightStickY
            ControllerUtil.listenPrimaryControllerStickAxis(verticalNavigationAxis, threshold: 0.6) {state in
                GamepadNavigationIllustrationHud.updateActionState(for: verticalNavigationAxis, isInAction: state != .orderedSame)
                guard radialMenuView == nil else {return}
                switch state {
                case .orderedAscending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is SettingsViewController {
                            navigateContinuously(forward: true)
                        }
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(downward: true)
                        }
                    }
                case .orderedDescending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is SettingsViewController {
                            navigateContinuously(forward: false)
                        }
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(downward: false)
                        }
                    }
                case .orderedSame:
                    navigationTimer?.clean()
                }
            }
        }
        
        if let uiNavigationDelegate = uiNavigationDelegate, !mainFrameVC.isStreaming() || uiNavigationDelegate is ToolboxViewController || uiNavigationDelegate is ProfileSelectorViewController {
            let horizontalNavigationAxis: ControllerElement = ControllerNavigator.radialMenuButtonPosition == .right ? .leftStickX : .rightStickX
            ControllerUtil.listenPrimaryControllerStickAxis(horizontalNavigationAxis, threshold: 0.6) {state in
                GamepadNavigationIllustrationHud.updateActionState(for: horizontalNavigationAxis, isInAction: state != .orderedSame)
                guard radialMenuView == nil else {return}
                switch state {
                case .orderedAscending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(forward: false)
                        }
                    }
                case .orderedDescending:
                    if navigationTimer?.isRunning() != true {
                        if uiNavigationDelegate is ControllerCollectionNavigationDelegate {
                            navigateContinuously(forward: true)
                        }
                    }
                case .orderedSame:
                    navigationTimer?.clean()
                }
            }
        }
         */

        if let uiNavigationDelegate = uiNavigationDelegate, !mainFrameVC.isStreaming() || mainFrameVC.settingsExpandedInStreamView || uiNavigationDelegate is UIAlertController || uiNavigationDelegate is ProfileSelectorViewController || uiNavigationDelegate is ToolboxViewController {
            let navigations = uiNavigationDelegate.getNavigationElements()
            let buttonNavigations = navigations.filter({$0.control.type == .button})
            // let stickNavigations = navigations.filter({$0.control.type == .stick || $0.control.type == .stickAxis})
            
            var listenedControls = Set<ControllerElement>()
            for buttonNavigation in buttonNavigations {
                if buttonNavigation.control == radialMenuButton {continue}
                if listenedControls.contains(buttonNavigation.control) {continue}
                ControllerUtil.listenPrimaryControllerButton(buttonNavigation.control) {pressed in
                    buttonNavigation.isInAction = pressed
                    GamepadNavigationIllustrationHud.updateActionState(for: buttonNavigation.control, isInAction: pressed)
                    uiNavigationDelegate.uiButtonActionForControllerNavigator(pressed: pressed, from: buttonNavigation)
                    // print("buttonElement.control \(buttonElement.control.displayName) \(pressed)")
                    if !pressed {
                        navigationTimer?.clean()
                    }
                }
                listenedControls.insert(buttonNavigation.control)
            }
        }
        
        /*
        ControllerUtil.listenPrimaryControllerStickAxis(.leftStickX, threshold: 0.8) {state in
            guard uiNavigationDelegate != nil, radialMenuView == nil else {return}
            switch state {
            case .orderedAscending:
                if navigationTimer?.isRunning() != true {uiNavigationDelegate?.uiWidgetActionForControllerNavigator(forward: false)}
            case .orderedDescending:
                if navigationTimer?.isRunning() != true {uiNavigationDelegate?.uiWidgetActionForControllerNavigator(forward: true)}
            case .orderedSame:
                navigationTimer?.clean()
            }
        }
        */
    }
    
    
}

@available(iOS 13.0, *)
extension SettingsViewController: ControllerUINavigationDelegate {
    @objc(showControllerMouseCurvePreviewWithExpo:)
    func showControllerMouseCurvePreview(expo: CGFloat) {
        PublicUtils.runOnMain { [weak self] in
            self?.showControllerMouseCurvePreviewOnMain(expo: expo)
        }
    }

    func cancelControllerMouseCurvePreviewDismiss() {
        PublicUtils.runOnMain { [weak self] in
            self?.controllerMouseCurvePreviewDismissWorkItem?.cancel()
            self?.controllerMouseCurvePreviewDismissWorkItem = nil
        }
    }

    func scheduleControllerMouseCurvePreviewDismiss() {
        PublicUtils.runOnMain { [weak self] in
            self?.scheduleControllerMouseCurvePreviewDismissOnMain()
        }
    }

    func dismissControllerMouseCurvePreview() {
        PublicUtils.runOnMain { [weak self] in
            self?.dismissControllerMouseCurvePreviewOnMain()
        }
    }

    @objc func persistControllerNavigationHighlight() {
        if let store = swiftUISettingsStore, store.isActive {
            store.persistHighlight()
            return
        }
        guard let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
              let identifier = controllerNavigationPersistenceIdentifier(for: highlightedView) else {
            return
        }

        UserDefaults.standard.set(identifier, forKey: settingsControllerNavigationHighlightedIdentifierKey)
    }

    private var controllerMouseCurvePreviewView: ControllerMouseCurvePreviewView? {
        get {
            objc_getAssociatedObject(self, &controllerMouseCurvePreviewViewKey) as? ControllerMouseCurvePreviewView
        }
        set {
            objc_setAssociatedObject(self, &controllerMouseCurvePreviewViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var controllerMouseCurvePreviewDismissWorkItem: DispatchWorkItem? {
        get {
            objc_getAssociatedObject(self, &controllerMouseCurvePreviewDismissWorkItemKey) as? DispatchWorkItem
        }
        set {
            objc_setAssociatedObject(self, &controllerMouseCurvePreviewDismissWorkItemKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private func showControllerMouseCurvePreviewOnMain(expo: CGFloat) {
        let previewView = controllerMouseCurvePreviewView ?? ControllerMouseCurvePreviewView()
        controllerMouseCurvePreviewView = previewView
        previewView.expo = expo
        previewView.translatesAutoresizingMaskIntoConstraints = false

        if previewView.superview == nil {
            previewView.alpha = 0
            guard let containerView = view.window ?? view else { return }
            containerView.addSubview(previewView)
            let containerSafeArea = containerView.safeAreaLayoutGuide
            let preferredWidth = previewView.widthAnchor.constraint(
                equalTo: containerSafeArea.widthAnchor,
                multiplier: 0.72
            )
            preferredWidth.priority = .defaultHigh
            NSLayoutConstraint.activate([
                previewView.centerXAnchor.constraint(equalTo: containerSafeArea.centerXAnchor),
                previewView.centerYAnchor.constraint(equalTo: containerSafeArea.centerYAnchor),
                previewView.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
                preferredWidth,
                previewView.heightAnchor.constraint(equalToConstant: 190)
            ])
        }

        previewView.superview?.bringSubviewToFront(previewView)
        UIView.animate(withDuration: 0.12) {
            previewView.alpha = 1
        }
    }

    private func scheduleControllerMouseCurvePreviewDismissOnMain() {
        guard controllerMouseCurvePreviewView != nil else { return }
        controllerMouseCurvePreviewDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissControllerMouseCurvePreviewOnMain()
        }
        controllerMouseCurvePreviewDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func dismissControllerMouseCurvePreviewOnMain() {
        controllerMouseCurvePreviewDismissWorkItem?.cancel()
        controllerMouseCurvePreviewDismissWorkItem = nil
        guard let previewView = controllerMouseCurvePreviewView else { return }
        UIView.animate(withDuration: 0.18, animations: {
            previewView.alpha = 0
        }, completion: { [weak self, weak previewView] _ in
            previewView?.removeFromSuperview()
            if self?.controllerMouseCurvePreviewView === previewView {
                self?.controllerMouseCurvePreviewView = nil
            }
        })
    }

    @objc func restoreControllerNavigationHighlight() {
        guard ControllerNavigator.enabled, ControllerUtil.primaryGCController != nil else {return}
        PublicUtils.runOnMain { [weak self] in
            if let store = self?.swiftUISettingsStore, store.isActive {
                store.restoreHighlight()
                return
            }
            self?.restoreControllerNavigationHighlightOnMain()
        }
    }

    @objc func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {
        PublicUtils.runOnMain { [weak self] in
            if let store = self?.swiftUISettingsStore, store.isActive {
                store.restoreHighlight()
                return
            }
            self?.restoreControllerNavigationHighlightAfterSettingsModeSwitchOnMain()
        }
    }
    
    @objc func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        if let store = swiftUISettingsStore, store.isActive {
            if navigation.action == "holdToReorder" {
                handleControllerNavigationReorderHold(pressed: pressed)
                return
            }
            if navigation.action == "readTip" || navigation.action == "doublePressToDelete" || navigation.action == "doublePressToAddFavorite" {
                PublicUtils.runOnMain { [weak self] in
                    self?.handleControllerNavigationReadTip(pressed: pressed)
                }
                return
            }
            guard pressed else {
                guard navigation.action == "widgetOperationBackward" ||
                        navigation.action == "widgetOperationForward" else { return }
                ControllerNavigator.navigationTimer?.clean()
                return
            }
            PublicUtils.runOnMain {
                switch navigation.action {
                case "widgetOperationBackward":
                    self.startSwiftUIContinuousSliderOperation(
                        store: store,
                        forward: false,
                        navigation: navigation
                    )
                case "widgetOperationForward":
                    self.startSwiftUIContinuousSliderOperation(
                        store: store,
                        forward: true,
                        navigation: navigation
                    )
                default: break
                }
            }
            return
        }
        let isHighlightingUIStack = ControllerNavigator.controllerNavigationHighlightedView is UIStackView
        
        if navigation.action == "holdToReorder", isHighlightingUIStack {
            handleControllerNavigationReorderHold(pressed: pressed)
            return
        }

        if isHighlightingUIStack, navigation.action == "readTip" || navigation.action == "doublePressToDelete" || navigation.action == "doublePressToAddFavorite" {
            PublicUtils.runOnMain { [weak self] in
                self?.handleControllerNavigationReadTip(pressed: pressed)
            }
            return
        }

        if pressed {
            switch navigation.action {
            case "widgetOperationBackward":
                self.uiWidgetActionForControllerNavigator(forward: false, from: navigation)
            case "widgetOperationForward":
                self.uiWidgetActionForControllerNavigator(forward: true, from: navigation)
            default:
                break
            }
        }
    }

    /// Mirrors UIKit's UISlider controller path: apply once immediately, then
    /// after 80 ms repeat every 30 ms while the physical button remains down.
    /// The store itself uses the same 2% range step as UISlider.step(...).
    private func startSwiftUIContinuousSliderOperation(
        store: SettingsSession,
        forward: Bool,
        navigation: ControllerNavigationElement
    ) {
        ControllerNavigator.navigationTimer?.clean()
        store.operateHighlighted(forward: forward)
        guard store.highlightedSettingIsSlider else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            guard navigation.isInAction, store.highlightedSettingIsSlider else { return }
            ControllerNavigator.navigationTimer = SafeTimer(interval: 0.03) {
                PublicUtils.runOnMain {
                    guard navigation.isInAction, store.highlightedSettingIsSlider else {
                        ControllerNavigator.navigationTimer?.clean()
                        return
                    }
                    store.operateHighlighted(forward: forward)
                }
            }
            ControllerNavigator.navigationTimer?.restart()
        }
    }
    
    func getNavigationElements() -> [ControllerNavigationElement] {
        if let store = swiftUISettingsStore, store.isActive {
            return store.navigationElements()
        }
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "readTip"))
        if self.currentSettingsMenuMode == .AllSettings {
            elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "doublePressToAddFavorite"))
        }
        if self.currentSettingsMenuMode == .FavoriteSettings {
            elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .a, action: "doublePressToDelete"))
            elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadDown : .y, action: "holdToReorder"))
        }
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButton, action: "radialMenu"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .rightStickY : .leftStickY, action: "menuNavigation"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .abxy : .dpad, action: "menuNavigation"))

        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadLeft : .x, action: "widgetOperationBackward"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .b, action: "widgetOperationForward"))
        return elements
    }
    
    func navigateByController(downward:Bool) {
        guard self.hasNoPresentedVC else {return}
        if let store = swiftUISettingsStore, store.isActive {
            if store.menuMode == .FavoriteSettings,
               ControllerNavigator.settingsFavoriteReorderActive {
                store.moveHighlightedFavorite(by: downward ? 1 : -1)
                return
            }
            store.moveHighlight(by: downward ? 1 : -1)
            return
        }
        if currentSettingsMenuMode == .FavoriteSettings,
           ControllerNavigator.settingsFavoriteReorderActive {
            moveHighlightedFavoriteSettingStack(by: downward ? 1 : -1)
            return
        }

        performControllerNavigationSelectionMove(by: downward ? 1 : -1)
    }
    
    func navigateByController(forward:Bool) {
    }
    
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation:ControllerNavigationElement) {
        guard self.hasNoPresentedVC else {return}
        if let store = swiftUISettingsStore, store.isActive {
            PublicUtils.runOnMain {
                store.operateHighlighted(forward: forward)
            }
            return
        }

        if let highlightedView = ControllerNavigator.controllerNavigationHighlightedView, highlightedView is UIButton {
            if let section = highlightedView.superview as? MenuSectionView {
                ControllerNavigator.wakeControllerDrivenUIKitAnimationIfNeeded(attachedTo: highlightedView)
                DispatchQueue.main.async{
                    section.toggleFold()
                }
            }
        }
        
        if let stack = ControllerNavigator.controllerNavigationHighlightedView as? UIStackView {
            for view in stack.arrangedSubviews {
                if let selector = view as? UISegmentedControl {
                    guard selector.isEnabled else {continue}
                    let updateSelector = {
                        var targetIndex:Int = 0
                        repeat {
                            targetIndex = selector.nextIndex(forward: forward)
                            selector.selectedSegmentIndex = targetIndex
                        } while !selector.isEnabledForSegment(at: targetIndex)
                        selector.sendActions(for: .valueChanged)
                    }
                    ControllerNavigator.wakeControllerDrivenUIKitAnimationIfNeeded(attachedTo: selector)
                    DispatchQueue.main.async(execute: updateSelector)
                }
                if let uiSwitch = view as? UISwitch {
                    guard uiSwitch.isEnabled else {continue}
                    uiSwitch.isOn = !uiSwitch.isOn
                    uiSwitch.sendActions(for: .valueChanged)
                }
                if let slider = view as? UISlider {
                    guard slider.isEnabled else {continue}
                    ControllerNavigator.navigationTimer?.clean()
                    slider.step(forward: forward, visualStepRatio: 0.02)
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.08) {
                        guard navigation.isInAction else { return }
                        ControllerNavigator.navigationTimer = SafeTimer(interval: 0.03) {
                            slider.step(forward: forward, visualStepRatio: 0.02)
                        }
                        ControllerNavigator.navigationTimer?.restart()
                    }
                }
            }
        }
    }

    private func performControllerNavigationSelectionMove(by offset: Int) {
        PublicUtils.runOnMain { [weak self] in
            self?.moveControllerNavigationSelection(by: offset)
        }
    }

    private func restoreControllerNavigationHighlightOnMain() {
        if let persistedIdentifier = UserDefaults.standard.string(forKey: settingsControllerNavigationHighlightedIdentifierKey) {
               highlightViewForControllerNavigator(by: persistedIdentifier)
        }
    }
    
    func highlightViewForControllerNavigator(by identifer: String?){
        if let store = swiftUISettingsStore, store.isActive {
            store.applyHighlight(identifer)
            return
        }
        let targets = controllerNavigationRestorableTargets()
        let selectableTargets = targets.filter { isControllerNavigationSelectableTarget($0) }
        guard !selectableTargets.isEmpty else {
            clearControllerNavigationHighlight()
            return
        }
        
        if let identifer = identifer,
           let target = selectableTargets.first(where: {
               controllerNavigationPersistenceIdentifier(for: $0) == identifer
           }) {
            highlightControllerNavigationView(target)
            return
        }
        
        if let identifer = identifer,
           let target = nearestSelectableControllerNavigationTarget(to: identifer, selectableTargets: selectableTargets) {
            highlightControllerNavigationView(target)
            return
        }

        highlightControllerNavigationView(selectableTargets[0])
    }

    private func restoreControllerNavigationHighlightAfterSettingsModeSwitchOnMain() {
        let targets = controllerNavigationRestorableTargets()
        let selectableTargets = targets.filter { isControllerNavigationSelectableTarget($0) }
        guard !selectableTargets.isEmpty else {
            clearControllerNavigationHighlight()
            return
        }

        if let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
           !isControllerNavigationSectionHeader(highlightedView),
           let highlightedIdentifier = controllerNavigationPersistenceIdentifier(for: highlightedView),
           let target = selectableTargets.first(where: {
               !isControllerNavigationSectionHeader($0) &&
               controllerNavigationPersistenceIdentifier(for: $0) == highlightedIdentifier
           }) {
            highlightControllerNavigationView(target)
            return
        }
        
        if let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
           !isControllerNavigationSectionHeader(highlightedView),
           let highlightedIdentifier = controllerNavigationPersistenceIdentifier(for: highlightedView),
           let target = nearestSelectableControllerNavigationTarget(to: highlightedIdentifier, selectableTargets: selectableTargets) {
            highlightControllerNavigationView(target)
            return
        }

        highlightControllerNavigationView(selectableTargets[0])
    }

    private func controllerNavigationRestorableTargets() -> [UIView] {
        var targets: [UIView] = []
        if currentSettingsMenuMode == .FavoriteSettings || currentSettingsMenuMode == .RemoveSettingItem,
           let parentStack = parentStack {
            targets.append(contentsOf: visibleFavoriteSettingStacks(in: parentStack))
        }
        targets.append(contentsOf: controllerNavigationTargets(skippingDisabledStacks: false))

        var seenIdentifiers = Set<ObjectIdentifier>()
        return targets.filter { target in
            let identifier = ObjectIdentifier(target)
            guard !seenIdentifiers.contains(identifier) else { return false }
            seenIdentifiers.insert(identifier)
            return true
        }
    }
    
    private func nearestSelectableControllerNavigationTarget(to identifier: String, selectableTargets: [UIView]) -> UIView? {
        let orderedTargets = controllerNavigationTargetsIncludingUnavailable()
        guard let persistedIndex = orderedTargets.firstIndex(where: {
            controllerNavigationPersistenceIdentifier(for: $0) == identifier
        }) else {
            return nil
        }
        
        for distance in 1..<orderedTargets.count {
            let forwardIndex = persistedIndex + distance
            if forwardIndex < orderedTargets.count,
               let target = selectableTargets.first(where: { $0 === orderedTargets[forwardIndex] }) {
                return target
            }
            
            let backwardIndex = persistedIndex - distance
            if backwardIndex >= 0,
               let target = selectableTargets.first(where: { $0 === orderedTargets[backwardIndex] }) {
                return target
            }
        }
        
        return nil
    }

    func controllerNavigationPersistenceIdentifier(for view: UIView) -> String? {
        if currentSettingsMenuMode == .FavoriteSettings || currentSettingsMenuMode == .RemoveSettingItem,
           let topLevelStack = topLevelFavoriteSettingStack(containing: view),
           let identifier = topLevelStack.accessibilityIdentifier,
           !identifier.isEmpty {
            return identifier
        }

        var currentView: UIView? = view
        while let viewToCheck = currentView {
            if let identifier = viewToCheck.accessibilityIdentifier,
               !identifier.isEmpty {
                return identifier
            }

            if viewToCheck === parentStack {
                return nil
            }

            currentView = viewToCheck.superview
        }

        return nil
    }

    private func isControllerNavigationSectionHeader(_ view: UIView) -> Bool {
        return view.accessibilityIdentifier?.hasPrefix("sectionHeader") == true
    }

    private func handleControllerNavigationReorderHold(pressed: Bool) {
        if let store = swiftUISettingsStore, store.isActive {
            guard store.menuMode == .FavoriteSettings else {
                ControllerNavigator.settingsFavoriteReorderActive = false
                return
            }
            ControllerNavigator.settingsFavoriteReorderActive = pressed
            return
        }
        guard currentSettingsMenuMode == .FavoriteSettings else {
            ControllerNavigator.settingsFavoriteReorderActive = false
            return
        }

        if pressed {
            ControllerNavigator.settingsFavoriteReorderActive = true
            return
        }

        guard ControllerNavigator.settingsFavoriteReorderActive else { return }
        ControllerNavigator.settingsFavoriteReorderActive = false
        saveFavoriteSettingStackIdentifiers()
    }

    private func handleControllerNavigationReadTip(pressed: Bool) {
        if pressed {
            handleControllerNavigationReadTipPressDown()
        } else {
            handleControllerNavigationReadTipRelease()
        }
    }

    private func handleControllerNavigationReadTipPressDown() {
        if ControllerNavigator.settingsReadTipPendingWorkItem != nil {
            ControllerNavigator.settingsReadTipPressedAgain = true
            ControllerNavigator.settingsReadTipSuppressNextRelease = true
        }
    }

    private func handleControllerNavigationReadTipRelease() {
        if ControllerNavigator.settingsReadTipSuppressNextRelease {
            ControllerNavigator.settingsReadTipSuppressNextRelease = false
            return
        }

        cancelPendingControllerNavigationReadTip()
        ControllerNavigator.settingsReadTipPendingToken += 1
        let token = ControllerNavigator.settingsReadTipPendingToken
        
        let workItem = DispatchWorkItem { [weak self] in
            guard ControllerNavigator.settingsReadTipPendingToken == token else { return }

            if ControllerNavigator.settingsReadTipPressedAgain {
                if let store = self?.swiftUISettingsStore, store.isActive {
                    store.performFavoriteDoublePress()
                } else {
                    switch self?.currentSettingsMenuMode {
                    case .FavoriteSettings:
                        self?.removeHighlightedFavoriteSettingStack()
                    case .AllSettings:
                        if let highlitedStack = ControllerNavigator.controllerNavigationHighlightedView as? UIStackView {
                            self?.addSetting(toFavorite: highlitedStack)
                            DispatchQueue.main.async {
                                if AlertControllerUtil.autoCompletion {return}
                                AlertControllerUtil.autoCompletion = true
                                AlertControllerUtil.showAlert(
                                    in: self,
                                    title: LocalizationHelper.localizedString(forKey: ""),
                                    message: "Setting added to favorite".localized,
                                    withCancel: false,
                                    buttonTitle: "",
                                    countdown: 1,
                                    completion: {
                                })
                            }
                        }
                    default:
                        break
                    }
                }
                
                // print("self?.cancelPendingControllerNavigationReadTip(resetSuppressNextRelease: false)");

            } else {
                self?.performControllerNavigationReadTip()
            }
            

            self?.cancelPendingControllerNavigationReadTip(resetSuppressNextRelease: false)
        }
        ControllerNavigator.settingsReadTipPendingWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
    }

    private func cancelPendingControllerNavigationReadTip(resetSuppressNextRelease: Bool = true) {
        ControllerNavigator.settingsReadTipPendingWorkItem?.cancel()
        ControllerNavigator.settingsReadTipPendingWorkItem = nil
        ControllerNavigator.settingsReadTipPressedAgain = false
        if resetSuppressNextRelease {
            ControllerNavigator.settingsReadTipSuppressNextRelease = false
        }
        ControllerNavigator.settingsReadTipPendingToken += 1
    }

    private func performControllerNavigationReadTip() {
        if let store = swiftUISettingsStore, store.isActive {
            store.performReadTip()
            return
        }
        guard let stack = ControllerNavigator.controllerNavigationHighlightedView as? UIStackView,
              stack.hasInfoTag || stack.isGameProfileSetting else {
            return
        }

        for view in stack.subviews.filter({ $0.accessibilityIdentifier == "infoButton" }) {
            if let button = view as? UIButton {
                button.sendActions(for: .touchUpInside)
            }
        }
    }

    private func removeHighlightedFavoriteSettingStack() {
        guard currentSettingsMenuMode == .FavoriteSettings,
              let parentStack = parentStack,
              let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
              let stack = topLevelFavoriteSettingStack(containing: highlightedView) else {
            return
        }

        let visibleStacksBeforeRemoval = visibleFavoriteSettingStacks(in: parentStack)
        guard let removedVisibleIndex = visibleStacksBeforeRemoval.firstIndex(where: { $0 === stack }) else { return }
        let nextVisibleIndex = max(removedVisibleIndex - 1, 0)

        parentStack.removeArrangedSubview(stack)
        stack.removeFromSuperview()
        saveFavoriteSettingStackIdentifiers()
        parentStack.setNeedsLayout()

        UIView.animate(withDuration: 0.12) {
            parentStack.layoutIfNeeded()
        }

        let visibleStacksAfterRemoval = visibleFavoriteSettingStacks(in: parentStack)
        guard !visibleStacksAfterRemoval.isEmpty else {
            clearControllerNavigationHighlight()
            return
        }

        let targetIndex = min(nextVisibleIndex, visibleStacksAfterRemoval.count - 1)
        highlightControllerNavigationView(visibleStacksAfterRemoval[targetIndex])
    }

    private func visibleFavoriteSettingStacks(in parentStack: UIStackView) -> [UIStackView] {
        return parentStack.arrangedSubviews.compactMap { $0 as? UIStackView }.filter {
            isControllerNavigationVisible($0, within: parentStack)
        }
    }

    private func moveHighlightedFavoriteSettingStack(by offset: Int) {
        PublicUtils.runOnMain { [weak self] in
            self?.moveHighlightedFavoriteSettingStackOnMain(by: offset)
        }
    }

    private func moveHighlightedFavoriteSettingStackOnMain(by offset: Int) {
        guard currentSettingsMenuMode == .FavoriteSettings,
              let parentStack = parentStack,
              let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
              let stack = topLevelFavoriteSettingStack(containing: highlightedView),
              isControllerNavigationVisible(stack, within: parentStack) else {
            return
        }

        let visibleStacks = parentStack.arrangedSubviews.compactMap { $0 as? UIStackView }.filter {
            isControllerNavigationVisible($0, within: parentStack)
        }
        guard let currentVisibleIndex = visibleStacks.firstIndex(where: { $0 === stack }) else { return }

        let targetVisibleIndex = currentVisibleIndex + offset
        guard visibleStacks.indices.contains(targetVisibleIndex) else { return }

        let targetStack = visibleStacks[targetVisibleIndex]
        guard let targetArrangedIndex = parentStack.arrangedSubviews.firstIndex(where: { $0 === targetStack }) else {
            return
        }

        parentStack.removeArrangedSubview(stack)
        parentStack.insertArrangedSubview(stack, at: targetArrangedIndex)
        parentStack.setNeedsLayout()

        UIView.animate(withDuration: 0.12) {
            parentStack.layoutIfNeeded()
        }

        highlightControllerNavigationView(stack)
    }

    private func topLevelFavoriteSettingStack(containing view: UIView) -> UIStackView? {
        guard let parentStack = parentStack else { return nil }

        var currentView: UIView? = view
        while let viewToCheck = currentView, viewToCheck !== parentStack {
            if let stackView = viewToCheck as? UIStackView,
               parentStack.arrangedSubviews.contains(where: { $0 === stackView }) {
                return stackView
            }

            currentView = viewToCheck.superview
        }

        return nil
    }

    private func moveControllerNavigationSelection(by offset: Int) {
        let allTargets = controllerNavigationTargets(skippingDisabledStacks: false)
        let targets = allTargets.filter { isControllerNavigationSelectableTarget($0) }
        guard !targets.isEmpty else {
            clearControllerNavigationHighlight()
            return
        }

        if let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
           let currentIndex = allTargets.firstIndex(where: { $0 === highlightedView }) {
            var nextIndex = currentIndex
            for _ in 0..<allTargets.count {
                nextIndex = (nextIndex + offset + allTargets.count) % allTargets.count
                let candidate = allTargets[nextIndex]
                if isControllerNavigationSelectableTarget(candidate) {
                    highlightControllerNavigationView(candidate)
                    return
                }
            }
        }

        let currentIndex = ControllerNavigator.controllerNavigationHighlightedView.flatMap { highlightedView in
            targets.firstIndex { $0 === highlightedView }
        }

        let nextIndex: Int
        if let currentIndex = currentIndex {
            nextIndex = (currentIndex + offset + targets.count) % targets.count
        } else {
            nextIndex = offset >= 0 ? 0 : targets.count - 1
        }

        highlightControllerNavigationView(targets[nextIndex])
    }

    private func controllerNavigationTargets(skippingDisabledStacks: Bool = true) -> [UIView] {
        guard let parentStack = parentStack else { return [] }

        switch currentSettingsMenuMode {
        case .FavoriteSettings, .RemoveSettingItem:
            return favoriteSettingsControllerNavigationTargets(
                in: parentStack,
                skippingDisabledStacks: skippingDisabledStacks
            )
        case .AllSettings:
            break
        @unknown default:
            break
        }

        var targets: [UIView] = []
        for arrangedSubview in parentStack.arrangedSubviews {
            guard let sectionView = arrangedSubview as? MenuSectionView else { continue }
            guard isControllerNavigationVisible(sectionView, within: parentStack) else { continue }

            if let headerView = sectionView.headerView,
               isControllerNavigationVisible(headerView, within: sectionView) {
                targets.append(headerView)
            }

            guard !shouldSkipControllerNavigationSection(sectionView) else { continue }
            guard let rootStackView = sectionView.rootStackView else { continue }
            guard isControllerNavigationVisible(rootStackView, within: sectionView) else { continue }

            for arrangedRootSubview in rootStackView.arrangedSubviews {
                guard let stackView = arrangedRootSubview as? UIStackView else { continue }
                targets.append(contentsOf: deepestVisibleControllerNavigationStacks(from: stackView, within: rootStackView, skippingDisabledStacks: skippingDisabledStacks))
            }
        }

        return targets
    }
    
    private func controllerNavigationTargetsIncludingUnavailable() -> [UIView] {
        guard let parentStack = parentStack else { return [] }
        
        if currentSettingsMenuMode == .FavoriteSettings || currentSettingsMenuMode == .RemoveSettingItem {
            return parentStack.arrangedSubviews.compactMap { $0 as? UIStackView }
        }
        
        var targets: [UIView] = []
        for arrangedSubview in parentStack.arrangedSubviews {
            guard let sectionView = arrangedSubview as? MenuSectionView else { continue }
            
            if let headerView = sectionView.headerView {
                targets.append(headerView)
            }
            
            guard !shouldSkipControllerNavigationSection(sectionView) else { continue }
            guard let rootStackView = sectionView.rootStackView else { continue }
            
            for arrangedRootSubview in rootStackView.arrangedSubviews {
                guard let stackView = arrangedRootSubview as? UIStackView else { continue }
                targets.append(contentsOf: deepestControllerNavigationStacks(from: stackView))
            }
        }
        
        return targets
    }
    
    private func deepestControllerNavigationStacks(from stackView: UIStackView) -> [UIStackView] {
        let childStackViews = stackView.arrangedSubviews.compactMap { $0 as? UIStackView }
        guard !childStackViews.isEmpty else {
            return [stackView]
        }
        
        return childStackViews.flatMap {
            deepestControllerNavigationStacks(from: $0)
        }
    }

    private func shouldSkipControllerNavigationSection(_ sectionView: MenuSectionView) -> Bool {
        guard let identifier = sectionView.identifier else {
            return false
        }

        return settingsExcludedControllerNavigationSectionIdentifiers.contains(identifier)
    }

    private func favoriteSettingsControllerNavigationTargets(in parentStack: UIStackView, skippingDisabledStacks: Bool) -> [UIView] {
        var targets: [UIView] = []
        for arrangedSubview in parentStack.arrangedSubviews {
            guard let stackView = arrangedSubview as? UIStackView else { continue }
            targets.append(contentsOf: deepestVisibleControllerNavigationStacks(
                from: stackView,
                within: parentStack,
                skippingDisabledStacks: skippingDisabledStacks
            ))
        }

        return targets
    }

    private func deepestVisibleControllerNavigationStacks(from stackView: UIStackView, within rootStackView: UIStackView, skippingDisabledStacks: Bool) -> [UIStackView] {
        guard isControllerNavigationVisible(stackView, within: rootStackView) else { return [] }

        let childStackViews = stackView.arrangedSubviews.compactMap { $0 as? UIStackView }
        let visibleChildStackViews = childStackViews.filter {
            isControllerNavigationVisible($0, within: rootStackView)
        }

        guard !visibleChildStackViews.isEmpty else {
            if skippingDisabledStacks, hasDisabledArrangedSubview(in: stackView) {
                return []
            }
            return [stackView]
        }

        return visibleChildStackViews.flatMap {
            deepestVisibleControllerNavigationStacks(from: $0, within: rootStackView, skippingDisabledStacks: skippingDisabledStacks)
        }
    }

    private func isControllerNavigationSelectableTarget(_ view: UIView) -> Bool {
        if currentSettingsMenuMode == .FavoriteSettings || currentSettingsMenuMode == .RemoveSettingItem {
            return true
        }

        guard let stackView = view as? UIStackView else { return true }
        return !hasDisabledArrangedSubview(in: stackView)
    }

    private func hasDisabledArrangedSubview(in stackView: UIStackView) -> Bool {
        for arrangedSubview in stackView.arrangedSubviews {
            if let control = arrangedSubview as? UIControl, !control.isEnabled {
                return true
            }

            if let nestedStackView = arrangedSubview as? UIStackView,
               hasDisabledArrangedSubview(in: nestedStackView) {
                return true
            }
        }

        return false
    }

    private func isControllerNavigationVisible(_ view: UIView, within ancestor: UIView) -> Bool {
        var currentView: UIView? = view
        while let viewToCheck = currentView {
            if viewToCheck.isHidden || viewToCheck.alpha <= 0.01 {
                return false
            }

            if viewToCheck === ancestor {
                return true
            }

            currentView = viewToCheck.superview
        }

        return false
    }

    private func highlightControllerNavigationView(_ view: UIView) {
        guard ControllerNavigator.controllerNavigationHighlightedView !== view else {
            scrollControllerNavigationViewToVisible(view)
            return
        }
        
        var navigations = self.getNavigationElements()
        let shouldShowReadTip = (view as? UIStackView).map { $0.hasInfoTag || $0.isGameProfileSetting } ?? false
        if !shouldShowReadTip {
            navigations.removeAll { $0.action == "readTip" }
        }
        GamepadNavigationIllustrationHud.updateNavigationElements(navigations)

        clearControllerNavigationHighlight()
        ControllerNavigator.controllerNavigationHighlightedView = view

        let overlayView = UIView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = ThemeManager.appPrimaryColorWithAlpha
        overlayView.layer.cornerRadius = 8
        overlayView.layer.cornerCurve = .continuous
        overlayView.layer.masksToBounds = true
        overlayView.alpha = 0
        view.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        view.bringSubviewToFront(overlayView)
        controllerNavigationHighlightOverlayView = overlayView

        UIView.animate(withDuration: 0.12) {
            overlayView.alpha = 1
        }

        scrollControllerNavigationViewToVisible(view)
    }

    private func clearControllerNavigationHighlight() {
        guard let overlayView = controllerNavigationHighlightOverlayView else {
            ControllerNavigator.controllerNavigationHighlightedView = nil
            return
        }

        UIView.animate(withDuration: 0.08, animations: {
            overlayView.alpha = 0
        }, completion: { _ in
            overlayView.removeFromSuperview()
        })

        ControllerNavigator.controllerNavigationHighlightedView = nil
        controllerNavigationHighlightOverlayView = nil
    }

    fileprivate func clearControllerNavigationHighlightForControllerNavigator() {
        if let store = swiftUISettingsStore, store.isActive {
            store.clearHighlight()
            return
        }
        clearControllerNavigationHighlight()
    }

    private func scrollControllerNavigationViewToVisible(_ view: UIView) {
        guard let scrollView = scrollView,
              let parentStack = parentStack else { return }

        scrollView.layoutIfNeeded()
        parentStack.layoutIfNeeded()

        let targetRectInParentStack = view.convert(view.bounds, to: parentStack)
        let targetRectInContent = targetRectInParentStack.offsetBy(
            dx: parentStack.frame.minX,
            dy: parentStack.frame.minY
        )

        let edgePadding: CGFloat = 72
        let adjustedInset = scrollView.adjustedContentInset
        let visibleMinY = scrollView.contentOffset.y + adjustedInset.top
        let visibleMaxY = scrollView.contentOffset.y + scrollView.bounds.height - adjustedInset.bottom

        var targetOffsetY = scrollView.contentOffset.y
        if targetRectInContent.minY < visibleMinY + edgePadding {
            targetOffsetY = targetRectInContent.minY - edgePadding - adjustedInset.top
        } else if targetRectInContent.maxY > visibleMaxY - edgePadding {
            targetOffsetY = targetRectInContent.maxY + edgePadding + adjustedInset.bottom - scrollView.bounds.height
        }

        let minOffsetY = -adjustedInset.top
        let maxOffsetY = max(minOffsetY, scrollView.contentSize.height - scrollView.bounds.height + adjustedInset.bottom)
        targetOffsetY = min(max(targetOffsetY, minOffsetY), maxOffsetY)

        guard abs(targetOffsetY - scrollView.contentOffset.y) > 0.5 else { return }
        UIView.animate(withDuration: 0.1) {
            scrollView.setContentOffset(CGPoint(x: scrollView.contentOffset.x, y: targetOffsetY), animated: false)
        }
    }
}

@available(iOS 13.0, *)
extension ControllerCollectionNavigationDelegate {
    var controllerNavigationSelectedIndexPath: IndexPath? {
        get {
            objc_getAssociatedObject(self, &controllerNavigationSelectedIndexPathKey) as? IndexPath
        }
        set {
            objc_setAssociatedObject(self, &controllerNavigationSelectedIndexPathKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var controllerNavigationPersistToken: Int {
        get {
            objc_getAssociatedObject(self, &controllerNavigationPersistTokenKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &controllerNavigationPersistTokenKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var controllerNavigationHighlightGeneration: Int {
        get {
            objc_getAssociatedObject(self, &controllerNavigationHighlightGenerationKey) as? Int ?? 0
        }
        set {
            objc_setAssociatedObject(self, &controllerNavigationHighlightGenerationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    var controllerNavigationCollectionView: UICollectionView {
        guard let collectionViewController = self as? UICollectionViewController else {
            assertionFailure("ControllerCollectionNavigationDelegate adopters must provide controllerNavigationCollectionView")
            return UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
        }

        return collectionViewController.collectionView
    }

    func applyControllerNavigationHighlight(to cell: UICollectionViewCell, highlighted: Bool) {
        if self is ProfileSelectorViewController {
            return
        }
        clearControllerNavigationHighlightBorder(in: cell)
        guard highlighted else { return }
        let highlightedView = controllerNavigationHighlightTargetView(for: cell)
        let isDarkTheme = ThemeManager.userInterfaceStyle() == .dark
        if self is ToolboxViewController {
            highlightedView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(isDarkTheme ? 0.8 : 0.97).cgColor
            highlightedView.layer.borderWidth = 3
        }
        else {
            highlightedView.layer.borderColor = ThemeManager.appPrimaryColor.withAlphaComponent(isDarkTheme ? 0.85 : 0.93).cgColor
            highlightedView.layer.borderWidth = (self is HostCollectionViewController) ? 3 : 5
        }
        (cell as? ControllerNavigationHighlightTargetProviding)?.controllerNavigationHighlightDidApply()
    }

    private func clearControllerNavigationHighlightBorder(in cell: UICollectionViewCell) {
        if let highlightProvider = cell as? ControllerNavigationHighlightTargetProviding {
            let targetView = highlightProvider.controllerNavigationHighlightTargetView
            targetView.layer.borderWidth = 0
            targetView.layer.borderColor = nil
            highlightProvider.controllerNavigationHighlightDidClear()
            return
        }

        for view in [cell, cell.contentView] + cell.contentView.subviews + cell.subviews {
            view.layer.borderWidth = 0
            view.layer.borderColor = nil
        }
    }

    private func controllerNavigationHighlightTargetView(for cell: UICollectionViewCell) -> UIView {
        if let highlightProvider = cell as? ControllerNavigationHighlightTargetProviding {
            return highlightProvider.controllerNavigationHighlightTargetView
        }

        if let contentView = controllerNavigationContentView(in: cell) {
            return contentView
        }

        return cell.contentView
    }

    private func controllerNavigationContentView(in cell: UICollectionViewCell) -> UIView? {
        let contentSubviews = cell.contentView.subviews.filter {
            !$0.isHidden && $0.alpha > 0.01 && !$0.bounds.isEmpty
        }
        if let contentSubview = contentSubviews.first {
            return contentSubview
        }

        let cellSubviews = cell.subviews.filter {
            $0 !== cell.contentView && !$0.isHidden && $0.alpha > 0.01 && !$0.bounds.isEmpty
        }
        return cellSubviews.first
    }
}

@available(iOS 13.0, *)
extension UICollectionViewController: ControllerCollectionNavigationDelegate {
    @objc func persistControllerNavigationHighlight() {
        controllerNavigationPersistCollectionHighlight()
    }

    @objc func restoreControllerNavigationHighlight() {
        controllerNavigationRestoreCollectionHighlight()
    }

    @objc func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {
    }

    @objc func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {
    }

    @objc func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        controllerNavigationPerformDefaultButtonAction(pressed: pressed, from: navigation)
    }

    @objc func getNavigationElements() -> [ControllerNavigationElement] {
        controllerNavigationDefaultNavigationElements()
    }

    @objc func navigateByController(forward: Bool) {
        controllerNavigationNavigateCollection(forward: forward)
    }

    @objc func navigateByController(downward: Bool) {
        controllerNavigationNavigateCollection(downward: downward)
    }
}

@available(iOS 13.0, *)
extension ControllerCollectionNavigationDelegate {
    func controllerNavigationPersistCollectionHighlight() {
        if let hostCollectionVC = self as? HostCollectionViewController {
            persistHostControllerNavigationHighlight(in: hostCollectionVC)
            return
        }

        if self is MainFrameViewController {
            persistAppControllerNavigationHighlight()
        }
    }

    func controllerNavigationRestoreCollectionHighlight() {
        guard ControllerNavigator.enabled, ControllerUtil.primaryGCController != nil else {return}

        PublicUtils.runOnMain { [weak self] in
            guard let self else { return }

            if let hostCollectionVC = self as? HostCollectionViewController {
                self.restoreHostControllerNavigationHighlight(in: hostCollectionVC)
                return
            }

            if let mainFrameVC = self as? MainFrameViewController {
                self.restoreAppControllerNavigationHighlight(in: mainFrameVC)
            }
        }
    }

    private func currentControllerNavigationCell() -> UICollectionViewCell? {
        guard let selectedIndexPath = controllerNavigationSelectedIndexPath,
              selectedIndexPath.section < controllerNavigationCollectionView.numberOfSections,
              selectedIndexPath.item >= 0,
              selectedIndexPath.item < controllerNavigationCollectionView.numberOfItems(inSection: selectedIndexPath.section) else {
            return nil
        }

        return controllerNavigationCollectionView.cellForItem(at: selectedIndexPath)
    }

    private func currentControllerNavigationContentView() -> UIView? {
        guard let cell = currentControllerNavigationCell() else { return nil }
        return controllerNavigationContentView(in: cell)
    }

    func controllerNavigationPerformDefaultButtonAction(pressed: Bool, from navigation: ControllerNavigationElement) {
        PublicUtils.runOnMain { [weak self] in
            guard let self else { return }

            if pressed {
                if self is HostCollectionViewController {
                    guard let hostCardView = self.currentControllerNavigationContentView() as? HostCardView else { return }
                    
                    switch navigation.action {
                    case "launchPairWake":
                        hostCardView.launchButtonTapped()
                        hostCardView.pairButtonTapped()
                        hostCardView.wakeupButtonTapped()
                    case "applications":
                        hostCardView.appButtonTapped()
                    default:
                        break
                    }
                }
                if let mainFrameVC = self as? MainFrameViewController {
                    let appView = self.currentControllerNavigationContentView() as? UIAppView
                    switch navigation.action {
                    case "launch":
                        mainFrameVC.forceLaunchApp(appView?.app)
                    case "quitApp":
                        PublicUtils.runOnMain {
                            mainFrameVC.quitApp(appView?.app)
                        }
                    default:
                        break
                    }
                }
            }
        }
    }
    
    func controllerNavigationDefaultNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButton, action: "radialMenu"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .rightStick : .leftStick, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .abxy : .dpad, action: "focusNavigation"))
        if self is HostCollectionViewController {elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "applications"))}
        if self is HostCollectionViewController {elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .x, action: "launchPairWake"))}
        if self is MainFrameViewController {elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "launch"))}
        if self is MainFrameViewController {elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .b, action: "quitApp"))}
        return elements
    }
    
    func controllerNavigationNavigateCollection(forward: Bool) {
        guard hasNoPresentedVC else { return }
        performControllerNavigationSelectionMove(horizontalOffset: forward ? 1 : -1)
        scheduleControllerNavigationHighlightPersistenceWhenStickSettles()
    }

    func controllerNavigationNavigateCollection(downward: Bool) {
        guard hasNoPresentedVC else { return }
        performControllerNavigationSelectionMove(verticalOffset: downward ? 1 : -1)
        scheduleControllerNavigationHighlightPersistenceWhenStickSettles()
    }

    func uiWidgetActionForControllerNavigator(forward: Bool) {
    }

    private func scheduleControllerNavigationHighlightPersistenceWhenStickSettles() {
        controllerNavigationPersistToken += 1
        let token = controllerNavigationPersistToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.persistControllerNavigationHighlightIfStickSettled(token: token)
        }
    }

    private func persistControllerNavigationHighlightIfStickSettled(token: Int) {
        guard controllerNavigationPersistToken == token else { return }

        if ControllerNavigator.navigationTimer?.isRunning() == true {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                self?.persistControllerNavigationHighlightIfStickSettled(token: token)
            }
            return
        }

        persistControllerNavigationHighlight()
    }

    private func persistHostControllerNavigationHighlight(in hostCollectionVC: HostCollectionViewController) {
        guard let selectedIndexPath = controllerNavigationSelectedIndexPath,
              selectedIndexPath.section == 0,
              selectedIndexPath.item >= 0,
              selectedIndexPath.item < hostCollectionVC.items.count,
              let host = hostCollectionVC.items[selectedIndexPath.item] as? TemporaryHost else {
            return
        }

        let uuid = host.uuid
        guard !uuid.isEmpty else { return }
        UserDefaults.standard.set(uuid, forKey: hostControllerNavigationHighlightedUUIDKey)
    }

    private func restoreHostControllerNavigationHighlight(in hostCollectionVC: HostCollectionViewController) {
        guard let uuid = UserDefaults.standard.string(forKey: hostControllerNavigationHighlightedUUIDKey),
              !uuid.isEmpty else {
            restoreFirstControllerNavigationItemIfNeeded()
            return
        }

        for index in 0..<hostCollectionVC.items.count {
            guard let host = hostCollectionVC.items[index] as? TemporaryHost,
                  host.uuid == uuid else {
                continue
            }

            controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: index, section: 0))
            return
        }

        restoreFirstControllerNavigationItemIfNeeded()
    }

    private func persistAppControllerNavigationHighlight() {
        guard let appView = currentControllerNavigationContentView() as? UIAppView,
              let appID = appView.app.id,
              !appID.isEmpty,
              let host = appView.app.host else {
            return
        }
        host.controllerNavigationHighlightedAppID = appID
        DataManager().update(host)
    }

    private func restoreAppControllerNavigationHighlight(in mainFrameVC: MainFrameViewController) {
        guard let appID = mainFrameVC.sortedAppList.first?.host?.controllerNavigationHighlightedAppID,
              !appID.isEmpty else {
            restoreFirstControllerNavigationItemIfNeeded()
            return
        }
        
        for (index, app) in mainFrameVC.sortedAppList.enumerated() where app.id == appID {
            controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: index, section: 0))
            return
        }

        restoreFirstControllerNavigationItemIfNeeded()
    }

    private func restoreFirstControllerNavigationItemIfNeeded() {
        guard controllerNavigationCollectionView.numberOfSections > 0,
              controllerNavigationCollectionView.numberOfItems(inSection: 0) > 0 else {
            clearCollectionControllerNavigationHighlight()
            return
        }

        controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: 0, section: 0))
    }

    private func performControllerNavigationSelectionMove(horizontalOffset: Int) {
        PublicUtils.runOnMain { [weak self] in
            self?.moveControllerNavigationSelection(horizontalOffset: horizontalOffset)
        }
    }

    private func performControllerNavigationSelectionMove(verticalOffset: Int) {
        PublicUtils.runOnMain { [weak self] in
            self?.moveControllerNavigationSelection(verticalOffset: verticalOffset)
        }
    }

    private func moveControllerNavigationSelection(horizontalOffset: Int) {
        let itemCount = controllerNavigationCollectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            clearCollectionControllerNavigationHighlight()
            return
        }

        guard let currentIndexPath = currentControllerNavigationIndexPath() else {
            controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: horizontalOffset >= 0 ? 0 : itemCount - 1, section: 0))
            return
        }

        let nextItem = (currentIndexPath.item + horizontalOffset + itemCount) % itemCount
        controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: nextItem, section: currentIndexPath.section))
    }

    private func moveControllerNavigationSelection(verticalOffset: Int) {
        let itemCount = controllerNavigationCollectionView.numberOfItems(inSection: 0)
        guard itemCount > 0 else {
            clearCollectionControllerNavigationHighlight()
            return
        }

        guard let currentIndexPath = currentControllerNavigationIndexPath(),
              let currentAttributes = layoutAttributesForItem(at: currentIndexPath) else {
            controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: verticalOffset >= 0 ? 0 : itemCount - 1, section: 0))
            return
        }

        let currentCenter = currentAttributes.center
        let candidates = (0..<itemCount).compactMap { item -> (indexPath: IndexPath, attributes: UICollectionViewLayoutAttributes)? in
            let indexPath = IndexPath(item: item, section: 0)
            guard indexPath != currentIndexPath,
                  let attributes = layoutAttributesForItem(at: indexPath) else {
                return nil
            }

            let isTargetDirection = verticalOffset > 0
                ? attributes.center.y > currentCenter.y + 1
                : attributes.center.y < currentCenter.y - 1
            guard isTargetDirection else { return nil }

            return (indexPath, attributes)
        }

        let nextIndexPath = candidates.min { lhs, rhs in
            let lhsVerticalDistance = abs(lhs.attributes.center.y - currentCenter.y)
            let rhsVerticalDistance = abs(rhs.attributes.center.y - currentCenter.y)
            if abs(lhsVerticalDistance - rhsVerticalDistance) > 0.5 {
                return lhsVerticalDistance < rhsVerticalDistance
            }

            let lhsHorizontalDistance = abs(lhs.attributes.center.x - currentCenter.x)
            let rhsHorizontalDistance = abs(rhs.attributes.center.x - currentCenter.x)
            if abs(lhsHorizontalDistance - rhsHorizontalDistance) > 0.5 {
                return lhsHorizontalDistance < rhsHorizontalDistance
            }

            return verticalOffset > 0
                ? lhs.indexPath.item < rhs.indexPath.item
                : lhs.indexPath.item > rhs.indexPath.item
        }?.indexPath

        if let nextIndexPath {
            controllerNavigationHighlightItemForControllerNavigator(at: nextIndexPath)
        }
    }

    private func currentControllerNavigationIndexPath() -> IndexPath? {
        if let selectedIndexPath = controllerNavigationSelectedIndexPath,
           selectedIndexPath.section < controllerNavigationCollectionView.numberOfSections,
           selectedIndexPath.item < controllerNavigationCollectionView.numberOfItems(inSection: selectedIndexPath.section) {
            return selectedIndexPath
        }

        if let highlightedView = ControllerNavigator.controllerNavigationHighlightedView,
           let highlightedCell = collectionViewCell(containing: highlightedView),
           let indexPath = controllerNavigationCollectionView.indexPath(for: highlightedCell) {
            return indexPath
        }

        return nil
    }

    func controllerNavigationCurrentIndexPathForControllerNavigator() -> IndexPath? {
        currentControllerNavigationIndexPath()
    }

    func controllerNavigationHighlightItemForControllerNavigator(at indexPath: IndexPath) {
        PublicUtils.runOnMain { [weak self] in
            guard let self else { return }

            let collectionView = self.controllerNavigationCollectionView
            guard indexPath.section < collectionView.numberOfSections,
                  indexPath.item >= 0,
                  indexPath.item < collectionView.numberOfItems(inSection: indexPath.section) else {
                self.clearCollectionControllerNavigationHighlight()
                return
            }

            collectionView.layoutIfNeeded()

            let previousIndexPath = self.controllerNavigationSelectedIndexPath
            self.controllerNavigationHighlightGeneration += 1
            let highlightGeneration = self.controllerNavigationHighlightGeneration
            self.controllerNavigationSelectedIndexPath = indexPath

            if let previousIndexPath,
               previousIndexPath != indexPath,
               let previousCell = collectionView.cellForItem(at: previousIndexPath) {
                self.applyControllerNavigationHighlight(to: previousCell, highlighted: false)
            }

            collectionView.scrollToItem(at: indexPath, at: [.centeredHorizontally, .centeredVertically], animated: true)
            self.applyControllerNavigationHighlightWhenCellIsReady(at: indexPath, generation: highlightGeneration, remainingAttempts: 8)
        }
    }

    private func applyControllerNavigationHighlightWhenCellIsReady(at indexPath: IndexPath, generation: Int, remainingAttempts: Int) {
        guard controllerNavigationSelectedIndexPath == indexPath,
              controllerNavigationHighlightGeneration == generation else { return }

        let collectionView = controllerNavigationCollectionView
        collectionView.layoutIfNeeded()

        if let cell = collectionView.cellForItem(at: indexPath) {
            applyControllerNavigationHighlight(to: cell, highlighted: true)
            ControllerNavigator.controllerNavigationHighlightedView = controllerNavigationHighlightTargetView(for: cell)
            return
        }

        guard remainingAttempts > 0 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.applyControllerNavigationHighlightWhenCellIsReady(at: indexPath, generation: generation, remainingAttempts: remainingAttempts - 1)
        }
    }

    private func clearCollectionControllerNavigationHighlight() {
        PublicUtils.runOnMain { [weak self] in
            guard let self else { return }

            if let selectedIndexPath = self.controllerNavigationSelectedIndexPath,
               let cell = self.controllerNavigationCollectionView.cellForItem(at: selectedIndexPath) {
                self.applyControllerNavigationHighlight(to: cell, highlighted: false)
            }

            self.controllerNavigationHighlightGeneration += 1
            self.controllerNavigationSelectedIndexPath = nil
            ControllerNavigator.controllerNavigationHighlightedView = nil
        }
    }

    func clearCollectionControllerNavigationHighlightForControllerNavigator() {
        clearCollectionControllerNavigationHighlight()
    }

    func invalidateCollectionControllerNavigationHighlightForControllerNavigator() {
        controllerNavigationHighlightGeneration += 1
        controllerNavigationSelectedIndexPath = nil
        ControllerNavigator.controllerNavigationHighlightedView = nil
    }

    private func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        controllerNavigationCollectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath)
    }

    private func collectionViewCell(containing view: UIView) -> UICollectionViewCell? {
        var currentView: UIView? = view
        while let viewToCheck = currentView {
            if let cell = viewToCheck as? UICollectionViewCell {
                return cell
            }

            currentView = viewToCheck.superview
        }

        return nil
    }
}

extension MainFrameViewController {
    func forceLaunchApp(_ app: TemporaryApp?){
        guard let app = app else { return }
        if let currentRunningApp = self.findRunningApp(app.host) {
            if currentRunningApp !== app {
                self.quitRunningAppAndStart(app)
            }
            else {
                self.launch(currentRunningApp)
            }
        }
        else {
            self.launch(app)
        }
    }
}

private var alertControllerNavigationHookInstalledKey: UInt8 = 0

@available(iOS 13.0, *)
extension UIAlertController: ControllerUINavigationDelegate {
    static func installControllerNavigationDelegateHook() {
        guard objc_getAssociatedObject(self, &alertControllerNavigationHookInstalledKey) == nil else { return }
        objc_setAssociatedObject(self, &alertControllerNavigationHookInstalledKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        swizzleAlertLifecycleMethod(
            originalSelector: #selector(UIViewController.viewDidAppear(_:)),
            swizzledSelector: #selector(UIAlertController.vl_controllerNavigationViewDidAppear(_:))
        )
        swizzleAlertLifecycleMethod(
            originalSelector: #selector(UIViewController.viewDidDisappear(_:)),
            swizzledSelector: #selector(UIAlertController.vl_controllerNavigationViewDidDisappear(_:))
        )
    }

    private static func swizzleAlertLifecycleMethod(originalSelector: Selector, swizzledSelector: Selector) {
        guard let originalMethod = class_getInstanceMethod(UIAlertController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIAlertController.self, swizzledSelector) else {
            return
        }

        let didAddMethod = class_addMethod(
            UIAlertController.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            class_replaceMethod(
                UIAlertController.self,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }

    @objc private func vl_controllerNavigationViewDidAppear(_ animated: Bool) {
        vl_controllerNavigationViewDidAppear(animated)
        ControllerNavigator.setUINavigationDelegate(self)
    }

    @objc private func vl_controllerNavigationViewDidDisappear(_ animated: Bool) {
        vl_controllerNavigationViewDidDisappear(animated)
        ControllerNavigator.restorePreviousUINavigationDelegate(ifCurrentDelegateIs: self)
    }

    func getNavigationElements() -> [ControllerNavigationElement] {
        let enabledActions = actions.filter { $0.isEnabled }
        guard let firstAction = enabledActions.first else { return [] }

        guard enabledActions.count > 1, let lastAction = enabledActions.last else {
            guard let title = firstAction.title, !title.isEmpty else { return [] }
            return [ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: title)]
        }

        
        
        
        var elements: [ControllerNavigationElement] = []
        
        if ControllerNavigator.radialMenuButtonPosition == .left {
            elements.append(ControllerNavigationElement(control: firstAction.style == .default ? .dpadRight : .dpadUp, action: firstAction.title ?? ""))
            if firstAction.style != lastAction.style {
                elements.append(ControllerNavigationElement(control: lastAction.style == .cancel ? .dpadUp : .dpadRight, action: lastAction.title ?? ""))
            }
        }
        else {
            elements.append(ControllerNavigationElement(control: firstAction.style == .default ? .a : .b, action: firstAction.title ?? ""))
            if firstAction.style != lastAction.style {
                elements.append(ControllerNavigationElement(control: lastAction.style == .cancel ? .b : .a, action: lastAction.title ?? ""))
            }
        }
        
        return elements
    }
    
    func navigateByController(forward: Bool) {}
    func navigateByController(downward: Bool) {}
    func persistControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {}
    
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {}
    
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        guard pressed,
              let action = actions.first(where: { $0.title == navigation.action && $0.isEnabled }) else {
            return
        }

        performControllerNavigationAction(action)
    }

    private func performControllerNavigationAction(_ action: UIAlertAction) {
        let selector = NSSelectorFromString("_invokeHandlersForAction:")
        if responds(to: selector) {
            self.perform(selector, with: action)
            dismiss(animated: true)
            return
        }
    }
}

@available(iOS 13.0, *)
extension StreamFrameViewController: ControllerUINavigationDelegate {
    func getNavigationElements() -> [ControllerNavigationElement] {
        var elements = [ControllerNavigationElement]()
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButton, action: "radialMenu"))
        return elements
    }
    
    func navigateByController(forward: Bool) {}
    func navigateByController(downward: Bool) {}
    func persistControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {}
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {}
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {}
}
