//
//  GenericUtils.swift
//  VoidLink
//
//  Created by True砖家 on 2026/2/26.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//


import Foundation
import GameController
import ObjectiveC
import UIKit

@objc public class GenericUtils: NSObject {
    @objc public static func installSegmentedControlPreviousSelectionTracking() {
        UISegmentedControl.installPreviousSelectionTracking()
    }
    
    @objc public static var hardwareKeyboardAlreadyDetected: Bool = false
    
    @objc public static func isHardwareKeyboardConnected() -> Bool {
        if #available(iOS 14.0, tvOS 14.0, *) {
            hardwareKeyboardAlreadyDetected = GCKeyboard.coalesced != nil
            return GCKeyboard.coalesced != nil
        }
        return false
    }
    
    @objc public static func isFirstHardwareKeyboardOrMouseConnection() -> Bool {
        let key = "hasConnectedHardwareKeyboardOrMouse"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc public static func handleKeyboardOrMouseConnectionTip(in vc: UIViewController?) {
        if PublicUtils.isRunningOnMacAsiPadApp {
            return
        }
        if hardwareKeyboardAlreadyDetected {
            _ = isFirstHardwareKeyboardOrMouseConnection()
            return;
        }
        else if isFirstHardwareKeyboardOrMouseConnection() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Keyboard/Mouse Connected"),
                message: LocalizationHelper.localizedString(forKey:"keyboard&MouseStreamingTip"),
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "This tip won't be shown again"),
                countdown: 11,
                completion: {})
        }
    }

    @objc public static func handleFrameInterpolationPixelFormatTip(in vc: UIViewController?) {
        let key = "hasShownFrameInterpolationPixelFormatTip"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)

        AlertControllerUtil.showAlert(
            in: vc,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: "\n\(LocalizationHelper.localizedString(forKey: "Most devices currently perform frame interpolation using 8-bit YUV 4:2:0 video-range buffers. If HDR or YUV 4:4:4 is enabled, both source and intermediate frames may be processed and rendered in this pixel format, while HDR color characteristics and metadata are preserved."))",
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 5
        )
    }

    @objc public static func handleFrameInterpolationResolutionTip(in vc: UIViewController?) {
        let key = "hasShownFrameInterpolationResolutionTip"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)

        AlertControllerUtil.showAlert(
            in: vc,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: LocalizationHelper.localizedString(forKey: "frameInterpolationResolutionTip"),
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 8
        )
    }

    @objc public static func handleFrameInterpolationAvailabilityTip(in vc: UIViewController?) -> Bool {
        guard #available(iOS 26.0, tvOS 26.0, *) else {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: LocalizationHelper.localizedString(forKey: "This system version does not support frame interpolation."),
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 0
            )
            return false
        }

        guard FrameInterpolator.deviceSupportsInterpolation else {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: LocalizationHelper.localizedString(forKey: "This device does not support frame interpolation."),
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 0
            )
            return false
        }

        return true
    }
    
    @objc public static func handleControllerEmulationTip(in vc: UIViewController?) {
        let key = "hasShownControllerEmulationTip2"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return
        }
        UserDefaults.standard.set(true, forKey: key)
        
        AlertControllerUtil.showAlert(
            in: vc,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: LocalizationHelper.localizedString(forKey: "emulatedControllerTypeStackTip"),
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 7
        )
    }

        
    @objc public static func needUpdateDefaultSettings() -> Bool {
        // let key = "needUpdateDefaultSettings20260226-1"
        let key = "needUpdateDefaultSettings20260408-3"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc public static func needUpdatePartialSettings() -> Bool {
        // let key = "needUpdateDefaultSettings20260226-1"
        // let key = "needUpdatePartialSettings20260620"
        let key = "needUpdatePartialSettings20260801"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc public static func isEnableOswForNativeTouchSwitchFirstFlipping() -> Bool {
        let key = "enableOswForNativeTouchSwitchFlipped"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc public static func isFirstLaunchPressureCurveTool() -> Bool {
        let key = "hasLaunchedPressureCurveTool"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }

    @objc public static func isFirstLaunchGamepadOverlayFeature() -> Bool {
        let key = "hasTouchedGamepadOverlayFeature20260405-2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc public static func isFirstTappingGameProfileSelectorFromMainFrame() -> Bool {
        let key = "hasTappedGameProfileSelectorFromMainFrame-202600801-2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc public static func isFirstTappingFolderInLayoutTool() -> Bool {
        let key = "hasTappedFolderInLayoutTool2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc public static var hasTappedMagnifier = false
    @objc public static func isFirstTappingMagnifier() -> Bool {
        guard !hasTappedMagnifier else { return false }
        hasTappedMagnifier = true
        let key = "hasTappedMagnifier2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleMagnifierTip(in vc: UIViewController?) {
        if isFirstTappingMagnifier() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Magnifier"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "magnifierTip"))\n\n\(LocalizationHelper.localizedString(forKey: "magnifierPersistTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
            )
        }
    }
    
    @objc public static var hasTappedVelocityBasedTouchpad = false
    @objc public static func isFirstTappingVelocityBasedTouchpad() -> Bool {
        guard !hasTappedVelocityBasedTouchpad else { return false }
        hasTappedVelocityBasedTouchpad = true
        let key = "hasTappedVelocityBasedTouchpad6"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleVelocityBasedTouchpadTip(in vc: UIViewController?) {
        if isFirstTappingVelocityBasedTouchpad() {
            AlertControllerUtil.cancelButtonString = LocalizationHelper.localizedString(forKey: "Detailed Tutorial")
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "velocityBasedTouchpadTip"))",
                withCancel: true,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
                completion: {
                    if AlertControllerUtil.actionCancelled {
                        PublicUtils.openUrl(LocalizationHelper.localizedString(forKey: "velocityBasedTouchpadLink"))
                    }
                }
            )
        }
    }
    
    @objc public static var hasTappedSlideAndHoldFolderButton = false
    @objc public static func isFirstTappingSlideAndHoldFolderButton() -> Bool {
        guard !hasTappedSlideAndHoldFolderButton else { return false }
        hasTappedSlideAndHoldFolderButton = true
        let key = "hasTappedSlideAndHoldFolderButton2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleSlideAndHoldFolderButtonTip(in vc: UIViewController?) {
        if isFirstTappingSlideAndHoldFolderButton() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "slideHoldFolderButtonTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
            )
        }
    }
    
    @objc public static var hasTappedGamingLayoutFolderInEditMode: Bool = false
    @objc public static func isFirstTappingGamingLayoutFolderInEditMode() -> Bool {
        guard !hasTappedGamingLayoutFolderInEditMode else { return false }
        hasTappedGamingLayoutFolderInEditMode = true
        let key = "hasTappedGamingLayoutFolderInEditMode"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleGamingLayoutFolderTip(in vc: UIViewController?) {
        if isFirstTappingGamingLayoutFolderInEditMode() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "gamingLayoutFolderTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
            )
        }
    }
    
    @objc public static func isFirstEnteringLayoutTool() -> Bool {
        let key = "hasEnteredLayoutTool1"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleLayoutToolTip(in vc: UIViewController?) {
        if isFirstEnteringLayoutTool() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "layoutToolTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 7,
            )
        }
    }
    
    @objc public static var pencilProPurchaseProcessedWithImportingWidgetTemplates: Bool = false
    @objc public static func handleAddOnProductPurchaseIntent(for product:AddOnProduct) {
        let key = "addOnProduct_\(product.productId())_purchased"
        let defaults = UserDefaults.standard
        let purchased = defaults.bool(forKey: key)
        if !purchased {
            IAPManager.checkPurchaseInfo(product) { info in
                if info.valid {
                    IAPManager.handlePurchaseSuccess(product)
                    defaults.set(true, forKey: key)
                }
            }
        }
    }
    
    @objc public static var hasTappedOnscreenGyroButton = false
    @objc public static func isFirstTappingOnscreenGyroButton() -> Bool {
        guard !hasTappedOnscreenGyroButton else { return false }
        hasTappedOnscreenGyroButton = true
        let key = "hasTappedOnscreenGyroButton"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleGyroButtonTip(in vc: UIViewController?) {
        if isFirstTappingOnscreenGyroButton() {
            AlertControllerUtil.cancelButtonString = LocalizationHelper.localizedString(forKey: "Detailed Tutorial")
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "gyroButtonTip"))",
                withCancel: true,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
                completion: {
                    if AlertControllerUtil.actionCancelled {
                        PublicUtils.openUrl(LocalizationHelper.localizedString(forKey: "yourMotionControlSoution"))
                    }
                }
            )
        }
    }
    
    @objc public static var hasTappedButtonModeSelector = false
    @objc public static func isFirstTappingButtonModeSelector() -> Bool {
        guard !hasTappedButtonModeSelector else { return false }
        hasTappedButtonModeSelector = true
        let key = "hasTappedButtonModeSelector3"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleButtonModeTip(in vc: UIViewController?) {
        if isFirstTappingButtonModeSelector() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "buttonModeTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Tutorial"),
                countdown: 3,
                completion: {
                    PublicUtils.openUrl(LocalizationHelper.localizedString(forKey: "buttonModeLink"))
                }
            )
        }
    }

    
    @objc public static var hasTappedStickWheel = false
    @objc public static func isFirstTappingStickWheel() -> Bool {
        guard !hasTappedStickWheel else { return false }
        hasTappedStickWheel = true
        let key = "hasTappedStickWheel"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleStickWheelTip(in vc: UIViewController?) {
        if isFirstTappingStickWheel() {
            AlertControllerUtil.cancelButtonString = LocalizationHelper.localizedString(forKey: "Detailed Tutorial")
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "stickWheelTip"))",
                withCancel: true,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 5,
                completion: {
                    if AlertControllerUtil.actionCancelled {
                        PublicUtils.openUrl(LocalizationHelper.localizedString(forKey: "stickWheelLink"))
                    }
                }
            )
        }
    }
    
    @objc public static var hasTappedWidgetPanel = false
    @objc public static func isFirstTappingWidgetPanel() -> Bool {
        guard !hasTappedWidgetPanel else { return false }
        hasTappedWidgetPanel = true
        let key = "hasTappedWidgetPanel7"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleWidgetPanelTip(in vc: UIViewController?) {
        if isFirstTappingWidgetPanel() {
            // AlertControllerUtil.cancelButtonString = LocalizationHelper.localizedString(forKey: "Detailed Tutorial")
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "widgetPanelTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 6,
                completion: {
                    if AlertControllerUtil.actionCancelled {
                        PublicUtils.openUrl(LocalizationHelper.localizedString(forKey: "widgetPanelLink"))
                    }
                }
            )
        }
    }
    
    @objc public static var hasChangedTouchMode = false
    @objc public static func isFirstChangingTouchMode() -> Bool {
        guard !hasChangedTouchMode else { return false }
        hasChangedTouchMode = true
        let key = "hasChangedTouchMode5"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleTouchModeChangingTip(in vc: UIViewController?) {
        if isFirstChangingTouchMode() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "touchModeStackTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 6,
                completion: {
                }
            )
        }
    }

    @objc public static func isFirstTappingInputAccessoryBar() -> Bool {
        let key = "isFirstTappingInputAccessoryBar"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc public static func isFirstConnectingGamepad() -> Bool {
        let key = "isFirstConnectingGamepad20260730"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleFirstGamepadConnection(in vc: UIViewController?, handler: @escaping () -> Void) {
        if isFirstConnectingGamepad() {
            DispatchQueue.main.asyncAfter(deadline: .now() + (PublicUtils.isTVOS ? 1.2 : 0)) {
                AlertControllerUtil.showAlert(
                    in: vc,
                    title: "Tips".localized,
                    message: "controllerNavigationTip".localized,
                    withCancel: false,
                    buttonTitle: "Got it!".localized,
                    countdown: 6,
                    completion: {
                        handler()
                    }
                )
            }
        }
    }
    
    @objc public static func isFirstSettingHighBitrate() -> Bool {
        let key = "isFirstSettingHighBitrate123"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleFirstSettingHighBitrate(in vc: UIViewController?, handler: @escaping () -> Void) {
        if isFirstSettingHighBitrate() {
            AlertControllerUtil.cancelButtonString = "Learn More".localized
            AlertControllerUtil.showAlert(
                in: vc,
                title: "Tips".localized,
                message: "highBitrateTip".localized,
                withCancel: true,
                buttonTitle: "Got it!".localized,
                countdown: 6,
                completion: {
                    handler()
                }
            )
        }
    }

    @objc public static func isFirstOpeningNewToolbox() -> Bool {
        let key = "isFirstOpeningNewToolbox6"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    @objc public static func handleFirstOpeningNewToolbox(in vc: UIViewController?, handler: @escaping () -> Void) {
        AlertControllerUtil.showAlert(
            in: vc,
            title: "Tips".localized,
            message: "newToolboxTip".localized,
            withCancel: false,
            buttonTitle: "Got it!".localized,
            countdown: 4,
            completion: {
                handler()
            }
        )
    }
    
    @objc public static func isFirstStreamingOnMac() -> Bool {
        if !PublicUtils.isRunningOnMacAsiPadApp {return false}
        let key = "hasStreamedOnMac"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }

    @objc public static func handleLegacyFramePacingTip(in vc: UIViewController?, with selector: UISegmentedControl, passAlert: Bool = false, uiAction: (() -> Void)? = nil) {
        if passAlert
            || selector.selectedSegmentIndex == FramePacingMode.queue.rawValue
            || selector.selectedSegmentIndex == FramePacingMode.interpolation.rawValue{
            uiAction?()
            return
        }
        if selector.previousSelectedSegmentIndex != FramePacingMode.queue.rawValue
            && selector.previousSelectedSegmentIndex != FramePacingMode.interpolation.rawValue {
            uiAction?()
            return
        }
        AlertControllerUtil.cancelButtonString = "Cancel"
        AlertControllerUtil.showAlert(
            in: vc,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: "\n\(LocalizationHelper.localizedString(forKey: "legacyFramePacingTip"))",
            withCancel: true,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Confirm"),
            countdown: 0,
            completion: {
                if AlertControllerUtil.actionCancelled {selector.selectedSegmentIndex = selector.previousSelectedSegmentIndex}
                uiAction?()
            }
        )
    }
    
    @objc public static func isFirstEnablingEmulatedGyroMode() -> Bool {
        let key = "hasEnabledEmulatedGyroMode20260825"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc public static func handleEmulatedGyroModeTip(in vc: UIViewController?) {
        if isFirstEnablingEmulatedGyroMode() {
            AlertControllerUtil.showAlert(
                in: vc,
                title: LocalizationHelper.localizedString(forKey: "Tips"),
                message: "\n\(LocalizationHelper.localizedString(forKey: "emulatedGyroModeDisablesBuiltinMotionControlTip"))",
                withCancel: false,
                buttonTitle: LocalizationHelper.localizedString(forKey: "This tip won't be shown again"),
                countdown: 7
            )
        }
    }
    
    

    @objc public static func gamepadOverlayFeatureTipTitle() -> String {
        LocalizationHelper.localizedString(forKey: "Gamepad Overlay")
    }

    @objc public static func gamepadOverlayFeatureTipMessage() -> String {
        LocalizationHelper.localizedString(forKey: "gamepadOverlayFeatureTip")
    }

    @objc public static func gamepadOverlayFeatureTipButtonTitle() -> String {
        LocalizationHelper.localizedString(forKey: "Got it!")
    }
    
    @objc public static var pencilInStreaming:Bool = false
    
    @objc public static let menuSeparatorWidth: CGFloat = 0.7
    @objc public static let menuSectionSeparatorWidth: CGFloat = PublicUtils.isIPhone ? 0.65 : 0.5
    
    @objc public static var legacyToolbarHeight: CGFloat {
        return 44
    }
    
    @objc public static var inputAccessoryBarHeight: CGFloat {
        if #available(iOS 13.0, *){
            return PublicUtils.isIPhone ? 46 : 55
        }
        else {return 44}
    }
    
    @objc public static var hostViewNavigationBarHeight: CGFloat {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return PublicUtils.liquidGlassEnabled ? 54 : 44
        case .pad:
            return PublicUtils.liquidGlassEnabled ? 54 : 50
        default:
            return PublicUtils.liquidGlassEnabled ? 54 : 50
        }
    }
    
    @objc public static var settingsMenuNavigationBarHeight: CGFloat {
        // return isIPhone() ? 44 : hostViewNavigationBarHeight
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return PublicUtils.liquidGlassEnabled ? hostViewNavigationBarHeight+5 : hostViewNavigationBarHeight
        case .pad:
            return PublicUtils.liquidGlassEnabled ? hostViewNavigationBarHeight+9 : hostViewNavigationBarHeight
        default:
            return PublicUtils.liquidGlassEnabled ? hostViewNavigationBarHeight+9 : hostViewNavigationBarHeight
        }
    }
    
    @objc public static var dockedNavBarTopAnchorOffset: CGFloat {
        return PublicUtils.liquidGlassEnabled ? 10 : 0
    }
    
    @available(iOS 26.0, *)
    @objc public static func applyOffTintColor(_ view: UIView) {
        let name = String(describing: type(of: view))
        if name.contains("UISwitchModernVisualElement") {
            view.backgroundColor = ThemeManager.liquidGlassSwitchOffTint
            view.layer.cornerRadius = view.bounds.height/2
            view.clipsToBounds = true
        }
        for sub in view.subviews {
            applyOffTintColor(sub)
        }
    }
    
    @objc public static var autoPopSoftKeyboard: Bool = true
    @objc public static var textFieldShouldResignAfterReturn: Bool = false
    
    @objc public static func getAtrributedPlaceHolder(text:String)-> NSAttributedString {
        if #available(iOS 13.0, *) {
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: UIColor.placeholderText
                ])
        } else {
#if os(tvOS)
            let foregroundColor = UIColor(white: 1, alpha: 0.6)
#else
            let foregroundColor = UIColor.lightText
#endif
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: foregroundColor
                ])
        }
    }
    
    static var kScaleLayerKey: UInt8 = 0
    @objc public static func setVerticalScale(view: UIView, show: Bool) {
        // 移除旧的
        if let oldLayer = objc_getAssociatedObject(view, &kScaleLayerKey) as? CALayer {
            oldLayer.removeFromSuperlayer()
            objc_setAssociatedObject(view, &kScaleLayerKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }

        guard show else { return }

        let container = CALayer()
        container.frame = view.bounds
        container.contentsScale = UIScreen.main.scale

        let step: CGFloat = 0.05
        let totalSteps = Int(1.0 / step)

        let path = UIBezierPath()

        for i in 0...totalSteps {
            let value = CGFloat(i) * step
            let y = view.bounds.height * (1.0 - value)

            let isMajor = i % 2 == 0
            let lineLength: CGFloat = isMajor ? 10 : 5

            // 刻度线
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: lineLength, y: y))

            // 数值
            if true {
                let t = CATextLayer()
                t.contentsScale = UIScreen.main.scale
                t.font = UIFont.systemFont(ofSize: 13, weight: .medium)
                t.fontSize = 13
                t.foregroundColor = UIColor.red.cgColor
                t.backgroundColor = ThemeManager.menuBackgroundColor.cgColor
                t.alignmentMode = .left
                t.string = String(format: "%.2f", value)
                t.frame = CGRect(x: lineLength + 2, y: y - 7, width: 30, height: 14)

                container.addSublayer(t)
            }
        }

        let shape = CAShapeLayer()
        shape.path = path.cgPath
        shape.strokeColor = UIColor.red.cgColor
        shape.lineWidth = 1

        container.addSublayer(shape)

        view.layer.addSublayer(container)

        objc_setAssociatedObject(view, &kScaleLayerKey, container, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    
        
    @objc public static var globeAsEscape: Bool = false
}
