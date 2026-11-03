//
//  PublicUtils.swift
//  VoidLink
//
//  Created by True砖家 on 2026/2/26.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//


import Foundation
import ObjectiveC
import UIKit
import AVFoundation
import GameController
import VideoToolbox

@objc public class PublicUtils: NSObject {
    
    @objc public static let isProductionBuild: Bool = {
        return ["com.voidlink.iOS"
            , "com.voidlinkextreme.iOS"
            , "com.voidlink.tf.debug10.iOS"
        ].contains(Bundle.main.bundleIdentifier)
    }()

    /// True when running in an Apple platform simulator.
    @objc public static let isSimulator: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }()

    /// True when this build runs on Apple TV (tvOS), rather than iOS/iPadOS.
    @objc public static let isTVOS: Bool = {
        #if os(tvOS)
        return true
        #else
        return false
        #endif
    }()
    @objc public static let tvOS26Aavailable: Bool = {
        if !PublicUtils.isTVOS {
            return false
        }
        if #available(tvOS 26.0, *) {
            return true
        }
        else {
            return false
        }
    }()

    @objc public static var isIPhone: Bool = {
        return UIDevice.current.userInterfaceIdiom == .phone
    }()

    @objc public static var isIPad: Bool = {
        return UIDevice.current.userInterfaceIdiom == .pad
    }()

    @objc public static let isFoldableIPhoneUserDefaultsKey = "isFoldableIPhone"

    /// Do not register a default for this key: nil means detection is still needed.
    @MainActor private static var cachedFoldableIPhone: Bool? {
        UserDefaults.standard.object(forKey: isFoldableIPhoneUserDefaultsKey) as? Bool
    }

    /// Loaded from persistent storage, or detected before the main interface is built.
    /// Read on the main thread. Hardware capability remains cached as poses change.
    @MainActor @objc public private(set) static var isFoldableIPhone: Bool = {
        return cachedFoldableIPhone ?? false
    }()
    
    private static let foldableRAMCacheLock = NSLock()
    private static var foldableRAMCacheValue: Bool?

    /// Resolve once on the main actor; subsequent callers only read memory.
    @objc public static var isFoldableRAMCached: Bool {
        foldableRAMCacheLock.lock()
        let cached = foldableRAMCacheValue
        foldableRAMCacheLock.unlock()
        if let cached { return cached }

        if Thread.isMainThread {
            return MainActor.assumeIsolated { initializeFoldableRAMCache() }
        }
        // Do not hold the cache lock while waiting for the main queue. This is
        // a computed getter so Swift's static-let initialization lock cannot
        // deadlock a simultaneous first read on the main thread.
        return DispatchQueue.main.sync {
            MainActor.assumeIsolated { initializeFoldableRAMCache() }
        }
    }

    @MainActor private static func initializeFoldableRAMCache() -> Bool {
        foldableRAMCacheLock.lock()
        defer { foldableRAMCacheLock.unlock() }
        if let cached = foldableRAMCacheValue { return cached }
        let result: Bool
        if #available(iOS 27.0, *) {
            result = isFoldableIPhone
        } else {
            result = false
        }
        foldableRAMCacheValue = result
        return result
    }
    
    /// Mirrors UIKit's hinge states without requiring availability checks at readers.
    @objc(VLHingeStatus) public enum HingeStatus: Int {
        case unknown = 0
        case closed = 1
        case partiallyOpen = 2
        case fullyOpen = 3
    }

    /// Updated on the main thread before hingeStatusDidChangeNotification is posted.
    @MainActor @objc public private(set) static var hingeStatus: HingeStatus = .unknown
    @objc public static let hingeStatusDidChangeNotification = Notification.Name("VoidLinkHingeStatusDidChange")
    @objc public static let windowGeometryDidChangeNotification = Notification.Name("VoidLinkWindowGeometryDidChange")

    @MainActor private static var foldableIPhoneDetectionStarted = false
    @MainActor private static var foldableIPhoneDetectionFinished = cachedFoldableIPhone != nil
    @MainActor private static var foldableIPhoneDetectionCallbacks: [() -> Void] = []
    @MainActor private static var hingeInteractionAssociationKey: UInt8 = 0
    @MainActor private static var foldableIPhoneDetectionTimeout: DispatchWorkItem?

    /// Call once from window setup, before constructing any business UI.
    /// UIKit needs a visible window to report its initial hinge state. While
    /// waiting, show the same background as the launch screen without blocking
    /// the main thread. A stored true or false bypasses this startup wait entirely.
    @MainActor @objc(prepareFoldableIPhoneDetectionInWindow:completion:)
    public static func prepareFoldableIPhoneDetection(in window: UIWindow, completion: @escaping () -> Void) {
        if foldableIPhoneDetectionFinished {
            _ = initializeFoldableRAMCache()
            completion()
            // Foldable devices still observe live poses without gating startup.
            if isFoldableIPhone { installHingeStatusObservation(in: window) }
            return
        }
        foldableIPhoneDetectionCallbacks.append(completion)
        guard !foldableIPhoneDetectionStarted else { return }
        foldableIPhoneDetectionStarted = true
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.1, *), UIDevice.current.userInterfaceIdiom == .phone {
            let launchController = UIViewController()
            launchController.view.backgroundColor = .systemBackground
            window.rootViewController = launchController
            let timeout = DispatchWorkItem {
                // Cache the timeout fallback so ordinary iPhones only wait once.
                NSLog("Foldable iPhone detection timed out; caching false")
                finishFoldableIPhoneDetection(false)
            }
            foldableIPhoneDetectionTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: timeout)
            window.makeKeyAndVisible()
            installHingeStatusObservation(in: window)
            return
        }
        #endif
        #if compiler(>=6.4)
        finishFoldableIPhoneDetection(false)
        #else
        // Xcode 26.6 lacks the hinge API; do not persist a hardware conclusion.
        finishFoldableIPhoneDetection(nil)
        #endif
    }

    /// Each application window owns its listener for its entire lifetime.
    @MainActor private static func installHingeStatusObservation(in window: UIWindow) {
        #if os(iOS) && compiler(>=6.4)
        if #available(iOS 27.1, *), UIDevice.current.userInterfaceIdiom == .phone {
            guard window.windowScene?.session.role == .windowApplication,
                  objc_getAssociatedObject(window, &hingeInteractionAssociationKey) == nil else { return }
            let interaction = UIHingeInteraction { interaction, update in
                guard let window = interaction.view as? UIWindow,
                      window.windowScene != nil, !window.isHidden else { return }
                guard let hinge = update.hinge else {
                    // Losing a hinge hierarchy is not a change in the physical pose.
                    // Keep the last known status after startup has completed.
                    if !foldableIPhoneDetectionFinished {
                        finishFoldableIPhoneDetection(false)
                    }
                    return
                }
                let nextStatus = HingeStatus(rawValue: hinge.status.rawValue) ?? .unknown
                let didChange = hingeStatus != nextStatus
                hingeStatus = nextStatus
                finishFoldableIPhoneDetection(true)
                // Angle updates within the same state do not require UI rebuilds.
                if didChange {
                    NotificationCenter.default.post(name: hingeStatusDidChangeNotification, object: window)
                }
            }
            objc_setAssociatedObject(window, &hingeInteractionAssociationKey, interaction, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            window.addInteraction(interaction)
        }
        #endif
    }

    @MainActor private static func finishFoldableIPhoneDetection(_ result: Bool?) {
        // A late positive sample after a timeout is still a confirmed capability.
        if let result {
            isFoldableIPhone = result
            if cachedFoldableIPhone != result {
                UserDefaults.standard.set(result, forKey: isFoldableIPhoneUserDefaultsKey)
            }
        }
        guard !foldableIPhoneDetectionFinished else { return }
        foldableIPhoneDetectionFinished = true
        foldableIPhoneDetectionTimeout?.cancel()
        foldableIPhoneDetectionTimeout = nil
        _ = initializeFoldableRAMCache()
        let callbacks = foldableIPhoneDetectionCallbacks
        foldableIPhoneDetectionCallbacks.removeAll()
        callbacks.forEach { $0() }
    }

    /// Query after layout: compact size classes alone do not imply a short bar.
    @objc(isCompactNavigationBar:)
    public static func isCompactNavigationBar(_ navigationBar: UINavigationBar?) -> Bool {
        guard isIPhone, let navigationBar else { return false }
        let height = navigationBar.bounds.height
        return height > 0 && height < 43
    }
    
    @objc public static var isRunningOnMacAsiPadApp: Bool = {
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
    }()

    @objc(setControllerUserInteractionEnabled:inViewController:)
    public static func setControllerUserInteractionEnabled(_ enabled: Bool, in viewController: UIViewController?) {
        var enabled = enabled
        enabled = enabled && PublicUtils.isTVOS
        guard let rootViewController = viewController?.viewIfLoaded?.window?.rootViewController as? GCEventViewController else {
            return
        }

        var pendingViewControllers: [UIViewController] = [viewController!, rootViewController]
        var visitedViewControllers = Set<ObjectIdentifier>()
        while let currentViewController = pendingViewControllers.popLast() {
            guard visitedViewControllers.insert(ObjectIdentifier(currentViewController)).inserted else {
                continue
            }
            if let controllerViewController = currentViewController as? GCEventViewController {
                controllerViewController.controllerUserInteractionEnabled = enabled
            }
            if let parentViewController = currentViewController.parent {
                pendingViewControllers.append(parentViewController)
            }
            if let presentingViewController = currentViewController.presentingViewController {
                pendingViewControllers.append(presentingViewController)
            }
        }
        if enabled {
            rootViewController.setNeedsFocusUpdate()
            rootViewController.updateFocusIfNeeded()
        }
        ControllerNavigator.shouldBlockAppControllerNavigator = enabled
    }
    
    @objc public static let iOS26Available: Bool = {
        if #available(iOS 26.0, tvOS 26.0, *) {
            return true
        } else {
            return false
        }
    }()
        
    @objc public static let liquidGlassEnabled: Bool = {
        if #available(iOS 26.0, tvOS 26.0, *) {
            let useLegacyUI = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool
            return useLegacyUI != true
        } else {
            return false
        }
    }()
    
    @objc public static var iOS27_2Available: Bool = {
        if #available(iOS 27.2, *) {return true}
        else {return false}
    }()
    
    @objc public static var iOS27_1Available: Bool = {
        if #available(iOS 27.1, *) {return true}
        else {return false}
    }()
    
    @objc public static var iOS18Available: Bool = {
        if #available(iOS 18.0, tvOS 18.0, *) {return true}
        else {return false}
    }()
    
    @objc public static var iOS17_5Available: Bool = {
        if #available(iOS 17.5, *) {return true}
        else {return false}
    }()
    
    @objc public static var isZhHans: Bool = {
        if Locale.preferredLanguages.first!.hasPrefix("zh-Hans") { return true }
        else { return false }
    }()
        
    @objc public static var sessionStartTimestamp: TimeInterval = 0
    
    @objc public static var touchSectionAvailable: Bool = {
        return !isTVOS
    }()
    
    @objc public static var pencilSectionAvailable: Bool = {
        let availableIds = ["com.voidlink.iOS", "com.voidlinkextreme.iOS", "com.voidlink.tf.debug10.iOS"]
        return availableIds.contains(Bundle.main.bundleIdentifier ?? "") && isIPad
    }()
    
    @objc public static let isGUIWidgetPickerAvailable: Bool = {
        if #available(iOS 13.0, tvOS 13.0, *) {
            return true
        } else {
            return false
        }
    }()
    
    @objc public static let isIAPAddonAvailable: Bool = {
        let availableBundleIds = ["com.voidlink.iOS", "com.voidlinkextreme.iOS", "com.voidlink.tf.debug10.iOS"]
        return availableBundleIds.contains(Bundle.main.bundleIdentifier ?? "")
    }()
    
    @objc public static var appDidEnterBackground: Bool = false
    
    @objc public static func isLandscape() -> Bool {
#if os(tvOS)
        return true
#else
        if #available(iOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.session.role == .windowApplication && $0.activationState == .foregroundActive })
            else {return false}
            return windowScene.interfaceOrientation.isLandscape
        }
        else {return PublicUtils.screenWidth > PublicUtils.screenHeight}
#endif
    }
    
    @objc public static func disconnectSymbol() -> String {
        if #available(iOS 18.0, tvOS 18.0, *) {
            return "personalhotspot.slash"
        }
        else if #available(iOS 14.0, tvOS 14.0, *) {
            return "rectangle.slash"
        }
        else {
            return "nosign"
        }
    }

    @objc public static func installTextFieldControllerUserInteractionTracking() {
#if os(tvOS)
        UITextField.installControllerUserInteractionTracking()
#endif
    }
    
    @objc public static func controllerMouseSymbol() -> String {
        if #available(iOS 17.0, tvOS 17.0, *) {
            return "pointer.arrow.ipad"
        }
        else if #available(iOS 16.0, tvOS 16.0, *) {
            return "pointer.arrow.ipad"
        }
        else {
            return "paperplane"
        }
    }
    
    @objc public static func disableControllerMouseSymbol() -> String {
        if #available(iOS 17.0, tvOS 17.0, *) {
            return "pointer.arrow.slash.square"
        }
        else if #available(iOS 16.0, tvOS 16.0, *) {
            return "pointer.arrow"
        }
        else {
            return "paperplane"
        }
    }
    
    @objc public static func quitSymbol() -> String {
        if #available(iOS 14.0, tvOS 14.0, *) {
            return "pip.exit"
        }
        else {
            return "arrow.left.square"
        }
    }

    @objc public static func disconnectSymbolSize() -> CGFloat {
        if #available(iOS 26.0, tvOS 26.0, *) {
            return 15
        }
        if #available(iOS 18.0, tvOS 18.0, *) {
            return 19
        }
        else if #available(iOS 14.0, tvOS 14.0, *) {return 17.5}
        else {return 20.7}
    }
    
    @objc public static func disconnectSymbolWeight() -> Int {
        if #available(iOS 26.0, tvOS 26.0, *) {
            return UIImage.SymbolWeight.bold.rawValue
        }
        if #available(iOS 18.0, tvOS 18.0, *) {
            return UIImage.SymbolWeight.semibold.rawValue
        }
        else if #available(iOS 13.0, tvOS 13.0, *) {return UIImage.SymbolWeight.semibold.rawValue}
        else {return 666}
    }

    
    @objc public static func toCGFloat(_ str: String) -> CGFloat {
        return CGFloat(Double(str) ?? 0)
    }
        
    @objc public static func viewIsLandscape(_ view: UIView?) -> Bool {
        guard let view else {return false}
        return view.bounds.width > view.bounds.height
    }
    
    private static let currentScreenLock = NSLock()
    private static var publishedCurrentScreen: UIScreen?

    private static func publishCurrentScreen(_ screen: UIScreen) {
        currentScreenLock.lock()
        publishedCurrentScreen = screen
        currentScreenLock.unlock()
    }

    /// The local application screen, independent of external display scenes.
    /// UI readers resolve it live. Worker threads read the last published screen
    /// without traversing UIKit scenes or synchronously waiting for the main queue.
    @objc public static var currentScreen: UIScreen {
        if Thread.isMainThread, #available(iOS 13.0, tvOS 13.0, *) {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.session.role == .windowApplication && $0.activationState != .unattached }
            let active = scenes.filter { $0.activationState == .foregroundActive }
            let scene = active.first { $0.windows.contains { $0.isKeyWindow } }
                ?? active.first
                ?? scenes.first { $0.activationState == .foregroundInactive }
            if let screen = scene?.screen {
                publishCurrentScreen(screen)
                return screen
            }
        }
        currentScreenLock.lock()
        let screen = publishedCurrentScreen
        currentScreenLock.unlock()
        // Only startup and pre-scene systems need this legacy fallback.
        return screen ?? UIScreen.main
    }

    @objc(refreshCurrentScreenForWindow:)
    public static func refreshCurrentScreen(for window: UIWindow?) {
        guard Thread.isMainThread, let window else { return }
        if #available(iOS 13.0, tvOS 13.0, *) {
            guard let scene = window.windowScene, scene.session.role == .windowApplication else { return }
            publishCurrentScreen(scene.screen)
        } else {
            publishCurrentScreen(window.screen)
        }
        // In a multi-window app, a geometry callback from an inactive window
        // must not displace the foreground key scene's default screen.
        _ = currentScreen
    }

    @objc(changeDefaultSettingsForView:)
    public static func changeDefaultSettings(for view: UIView?) {
        guard GenericUtils.needUpdateDefaultSettings() else {
            NSLog("[Settings startup] changeDefaultSettings skipped by upgrade marker")
            return
        }
        let dataManager = DataManager()
        let settings = dataManager.retrieveSettings()!
        let codec: TemporarySettingsCodecPreference =
            VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC) ? .hevc : .h264
        let maximumFPS = UIScreen.main.maximumFramesPerSecond

        settings.preferredCodec = Int32(codec.rawValue)
        settings.sdrPerformanceWorkaround = true
        settings.framePacingMode = NSNumber(value: FramePacingMode.queue.rawValue)
        if UIDevice.current.userInterfaceIdiom == .phone {
            settings.asyncFrameDequeue = false
            settings.touchMoveEventInterval = 0
        } else if maximumFPS > 110 || maximumFPS < 65 {
            settings.asyncFrameDequeue = false
        }

        if maximumFPS > 110 {
            settings.framerate = 120
        } else if maximumFPS < 65 {
            settings.framerate = 60
        }

        settings.onscreenControls = NSNumber(value: OnScreenControlsLevel.custom.rawValue)
        settings.pencilTickIntervalUs = 1750
        settings.pencilTipOffsetX = 0
        settings.pencilTipOffsetY = 0
        settings.oscLayoutToolFingers = 99
        settings.keyboardToggleFingers = 99
        dataManager.saveDataSynchronously()
    }

    @objc public static func updatePartialSettings() {
        guard GenericUtils.needUpdatePartialSettings() else { return }
        let dataManager = DataManager()
        let settings = dataManager.retrieveSettings()!
        settings.touchMoveEventInterval = 0
        settings.localMousePointerMode = 0

        settings.controllerMouseStick = NSNumber(value: ControllerElement.rightStick.rawValue)
        settings.controllerMouseLeftButton = NSNumber(value: ControllerElement.dpadRight.rawValue)
        settings.controllerMouseRightButton = NSNumber(value: ControllerElement.dpadUp.rawValue)
        settings.controllerMouseExpo = 1.8
        settings.controllerMousePointerVelocity = 15.0

        settings.asyncFrameDequeue = isTVOS || refreshRate > 100.0
        if #unavailable(iOS 14.0, tvOS 14.0) {
            settings.appTheme = NSNumber(value: UIUserInterfaceStyle.dark.rawValue)
        }
        dataManager.saveDataSynchronously()
    }

    /// Prefer the caller's window, including an explicitly external render view.
    @objc(screenForView:)
    public static func screen(for view: UIView?) -> UIScreen {
        if Thread.isMainThread, let window = view?.window {
            if #available(iOS 13.0, tvOS 13.0, *), let scene = window.windowScene {
                return scene.screen
            }
            return window.screen
        }
        return currentScreen
    }

    @objc public static var externalScreen: UIScreen? {
        guard Thread.isMainThread else { return nil }
        if #available(iOS 13.0, tvOS 13.0, *) {
            return UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { scene in
                    guard scene.activationState != .unattached else { return false }
                    if #available(iOS 16.0, tvOS 16.0, *), scene.session.role == .windowExternalDisplayNonInteractive {
                        return true
                    }
                    return scene.session.role == .windowExternalDisplay
                }?.screen
        }
        return UIScreen.screens.first { $0 !== currentScreen }
    }

    @objc public static var screenWidth: CGFloat {
        return currentScreen.bounds.width
    }

    @objc public static var screenHeight: CGFloat {
        return currentScreen.bounds.height
    }

    @objc public static var refreshRate: CGFloat {
        return CGFloat(currentScreen.maximumFramesPerSecond)
    }

    @objc(parentViewControllerForView:)
    static func parentViewController(for view: UIView?) -> UIViewController? {
        var responder: UIResponder? = view
        while let currentResponder = responder {
            if let viewController = currentResponder as? UIViewController {
                return viewController
            }
            responder = currentResponder.next
        }
        return nil
    }

    @objc public static func rootViewController() -> UIViewController? {
        if #available(iOS 13.0, *) {
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first { $0.activationState == .foregroundActive }?
                .windows
                .first { $0.isKeyWindow }?
                .rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    @objc public static func topViewController() -> UIViewController? {
        return topViewController(from: rootViewController())
    }

    private static func topViewController(from rootViewController: UIViewController?) -> UIViewController? {
        if let navigationController = rootViewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        }

        if let tabBarController = rootViewController as? UITabBarController {
            return topViewController(from: tabBarController.selectedViewController)
        }

        if let splitViewController = rootViewController as? UISplitViewController,
           let lastViewController = splitViewController.viewControllers.last {
            return topViewController(from: lastViewController)
        }

        if let presentedViewController = rootViewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        }

        return rootViewController
    }
    
    @objc public static func hasNoPresentedVC(_ vc: UIViewController) -> Bool {
        let hasNoPresentedVC = vc.presentedViewController == nil && vc.view.window != nil
        return hasNoPresentedVC
    }
    
    #if os(iOS)
    @objc(getCurrentOrientationForWindow:)
    public static func getCurrentOrientation(for window: UIWindow?) -> UIInterfaceOrientationMask {
        let size = window?.bounds.size ?? .zero
        return size.width > size.height ? .landscape : [.portrait, .portraitUpsideDown]
    }
    #endif

    public static func runOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }

    @objc public static func controllerMouseExpoMappedOffset(_ offset: CGFloat, expo: CGFloat) -> CGFloat {
        guard offset != 0 else { return 0 }
        let magnitude = pow(abs(offset), expo)
        return offset > 0 ? magnitude : -magnitude
    }

    @objc public static func controllerMouseVelocity(pointerVelocity: CGFloat, frameRate: CGFloat) -> CGFloat {
        guard frameRate > 0 else { return pointerVelocity }
        return pointerVelocity * 60 / frameRate
    }

    @objc public static func controllerMouseMoveVector(stickX: CGFloat, stickY: CGFloat, velocity: CGFloat, expo: CGFloat) -> CGVector {
        let hypot = hypot(stickX, stickY)
        guard hypot > 0 else {return CGVector(dx: 0, dy: 0)}
        let targetHypot = controllerMouseExpoMappedOffset(hypot, expo: expo)
        let targetX = targetHypot * (stickX/hypot)
        let targetY = targetHypot * (stickY/hypot)
        return CGVector(
            dx: targetX * velocity,
            dy: -targetY * velocity
        )
    }

    @objc public static func controllerMouseScrollVector(stickX: CGFloat, stickY: CGFloat, multiplier: CGFloat) -> CGVector {
        return CGVector(dx: multiplier * stickX, dy: multiplier * stickY)
    }
        
    @objc(openUrl:)
    static func openUrl(_ urlString: String) {
        guard let url = URL(string: urlString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
    
    @objc static var onScreenRuntimeStats: String = ""
    
    @objc static var tvOSSoftkeyboardBeingEnteredByController: Bool = false
    @objc static var tvOSSoftkeyboardIsWorking: Bool = false
    // @objc static var controllerMovedFocusOnTvOSSoftKeyboard:Bool = false
}

#if os(tvOS)
private var textFieldControllerUserInteractionTrackingKey: UInt8 = 0
private var willEndStreamTextSession:Bool = false
private var willSendEnterToHost:Bool = false

private extension UITextField {
    
    static func installControllerUserInteractionTracking() {
        _ = controllerUserInteractionTrackingInstalled
    }

    static let controllerUserInteractionTrackingInstalled: Void = {
        guard let originalMethod = class_getInstanceMethod(
            UITextField.self,
            #selector(UIView.didMoveToWindow)
        ), let swizzledMethod = class_getInstanceMethod(
            UITextField.self,
            #selector(UITextField.vl_publicUtilsDidMoveToWindow)
        ) else {
            return
        }

        let originalSelector = #selector(UIView.didMoveToWindow)
        let swizzledSelector = #selector(UITextField.vl_publicUtilsDidMoveToWindow)
        if class_addMethod(
            UITextField.self,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        ) {
            class_replaceMethod(
                UITextField.self,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }()

    @objc func vl_publicUtilsDidMoveToWindow() {
        vl_publicUtilsDidMoveToWindow()
        guard window != nil,
              objc_getAssociatedObject(self, &textFieldControllerUserInteractionTrackingKey) == nil else {
            return
        }

        objc_setAssociatedObject(self, &textFieldControllerUserInteractionTrackingKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        addTarget(self, action: #selector(UITextField.vl_publicUtilsEditingDidBegin), for: .editingDidBegin)
        addTarget(self, action: #selector(UITextField.vl_publicUtilsEditingDidEnd), for: .editingDidEnd)
    }
    
    private func getNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .rightStick : .leftStick, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "execute"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .rightTrigger, action: "holdToEndWithEnter"))
        return elements
    }

    @objc func vl_publicUtilsEditingDidBegin() {
        PublicUtils.tvOSSoftkeyboardIsWorking = true
        // PublicUtils.controllerMovedFocusOnTvOSSoftKeyboard = false
        PublicUtils.setControllerUserInteractionEnabled(true, in: PublicUtils.parentViewController(for: self))

        if self.accessibilityIdentifier == "streamRemoteTextField" {
            if (ControllerUtil.delegate as? MainFrameViewController)?.isStreaming() == true { ControllerNavigator.dimissRadialMenu()
            }
            willEndStreamTextSession = false
            willSendEnterToHost = false
            ControllerUtil.listenPrimaryControllerButton(.a) {pressed in
                PublicUtils.tvOSSoftkeyboardBeingEnteredByController = pressed
                if pressed {
                    willEndStreamTextSession = true
                }
                else {
                    DispatchQueue.main.asyncAfter(deadline: .now()+0.02) {
                        willEndStreamTextSession = !PublicUtils.tvOSSoftkeyboardBeingEnteredByController
                    }
                }
            }
            ControllerUtil.listenPrimaryControllerButton(.leftTrigger) {pressed in
                willSendEnterToHost = pressed
            }
            ControllerUtil.listenPrimaryControllerStick(.leftStick) { offsetVector in
                /*
                 if(!PublicUtils.controllerMovedFocusOnTvOSSoftKeyboard) {
                 PublicUtils.controllerMovedFocusOnTvOSSoftKeyboard = true
                 } */
            }
        }
    }

    @objc func vl_publicUtilsEditingDidEnd() {
        PublicUtils.tvOSSoftkeyboardIsWorking = false
        PublicUtils.setControllerUserInteractionEnabled(false, in: PublicUtils.parentViewController(for: self))
        if self.accessibilityIdentifier == "streamRemoteTextField" {
            ControllerUtil.clearPrimaryControllerButtonHandler(.a)
            ControllerUtil.clearPrimaryControllerButtonHandler(.rightTrigger)
            ControllerUtil.clearPrimaryControllerStickHandler(.leftStick)
            if willEndStreamTextSession {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .VoidLinkTvOSRemotePlayPauseTapped,
                        object: nil
                    )
                }
            }
            if willSendEnterToHost {
                DispatchQueue.main.asyncAfter(deadline: .now()+0.1) {
                    CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: ["ENTER"], delay: 0.05)
                }
            }
        }
        GamepadNavigationIllustrationHud.updateHud(forceDisplay: true)
    }
}
#endif
