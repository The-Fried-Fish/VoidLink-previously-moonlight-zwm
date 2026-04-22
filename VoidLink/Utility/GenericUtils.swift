//
//  GenericUtils.swift
//  VoidLink
//
//  Created by True砖家 on 2026/2/26.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//


import Foundation

@objc public class GenericUtils: NSObject {
        
    @objc static func needUpdateDefaultSettings() -> Bool {
        // let key = "needUpdateDefaultSettings20260226-1"
        let key = "needUpdateDefaultSettings20260408-3"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc static func isEnableOswForNativeTouchSwitchFirstFlipping() -> Bool {
        let key = "enableOswForNativeTouchSwitchFlipped"
        guard !UserDefaults.standard.bool(forKey: key) else {
            return false
        }
        UserDefaults.standard.set(true, forKey: key)
        return true
    }
    
    @objc static func isFirstLaunchPressureCurveTool() -> Bool {
        let key = "hasLaunchedPressureCurveTool"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)
        
        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }

    @objc static func isFirstLaunchGamepadOverlayFeature() -> Bool {
        let key = "hasTouchedGamepadOverlayFeature20260405-2"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)

        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }
    
    @objc static func isFirstTappingGameProfileSelectorFromMainFrame() -> Bool {
        let key = "hasTappedGameProfileSelectorFromMainFrame-6"
        let defaults = UserDefaults.standard
        let launchedBefore = defaults.bool(forKey: key)

        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }

    @objc static func gamepadOverlayFeatureTipTitle() -> String {
        SwiftLocalizationHelper.localizedString(forKey: "Gamepad Overlay")
    }

    @objc static func gamepadOverlayFeatureTipMessage() -> String {
        SwiftLocalizationHelper.localizedString(forKey: "gamepadOverlayFeatureTip")
    }

    @objc static func gamepadOverlayFeatureTipButtonTitle() -> String {
        SwiftLocalizationHelper.localizedString(forKey: "Got it!")
    }
    
    @objc static func isIPhone() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }

    @objc static func isIPad() -> Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
        
    @objc static let liquidGlassEnabled: Bool = {
        if #available(iOS 26.0, tvOS 26.0, *) {
            let useLegacyUI = Bundle.main.object(forInfoDictionaryKey: "UIDesignRequiresCompatibility") as? Bool
            return useLegacyUI != true
        } else {
            return false
        }
    }()

    @objc static let menuSeparatorWidth: CGFloat = 0.7
    @objc static let menuSectionSeparatorWidth: CGFloat = 0.7
    
    @objc static var legacyToolbarHeight: CGFloat {
        return 44
    }
    
    @objc static var hostViewNavigationBarHeight: CGFloat {
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return liquidGlassEnabled ? 54 : 44
        case .pad:
            return liquidGlassEnabled ? 54 : 50
        default:
            return liquidGlassEnabled ? 54 : 50
        }
    }
    
    @objc static var settingsMenuNavigationBarHeight: CGFloat {
        // return isIPhone() ? 44 : hostViewNavigationBarHeight
        switch UIDevice.current.userInterfaceIdiom {
        case .phone:
            return liquidGlassEnabled ? hostViewNavigationBarHeight+5 : hostViewNavigationBarHeight
        case .pad:
            return liquidGlassEnabled ? hostViewNavigationBarHeight+9 : hostViewNavigationBarHeight
        default:
            return liquidGlassEnabled ? hostViewNavigationBarHeight+9 : hostViewNavigationBarHeight
        }
    }
    
    @objc static var dockedNavBarTopAnchorOffset: CGFloat {
        return liquidGlassEnabled ? 10 : 0
    }
    
    @available(iOS 26.0, *)
    @objc static func applyOffTintColor(_ view: UIView) {
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
    
    @objc static var autoPopSoftKeyboard: Bool = true
    @objc static var textFieldShouldResignAfterReturn: Bool = false
    
    @objc static func getAtrributedPlaceHolder(text:String)-> NSAttributedString {
        if #available(iOS 13.0, *) {
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: UIColor.placeholderText
                ])
        } else {
            return NSAttributedString(
                string: text,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 15),
                    .foregroundColor: UIColor.lightText
                ])
        }
    }
    
    static var kScaleLayerKey: UInt8 = 0
    @objc static func setVerticalScale(view: UIView, show: Bool) {
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

    @objc static func toCGFloat(_ str: String) -> CGFloat {
        return CGFloat(Double(str) ?? 0)
    }
    
    @objc static func isLandscape() -> Bool {
        if #available(iOS 13.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else {return false}
            return windowScene.interfaceOrientation.isLandscape
        }
        else {return GenericUtils.screenWidth > GenericUtils.screenHeight}
    }
    
    @objc static func viewIsLandscape(_ view: UIView?) -> Bool {
        guard let view else {return false}
        return view.bounds.width > view.bounds.height
    }
    
    @objc static var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    @objc static var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    @objc static var iOS18Available: Bool {
        if #available(iOS 18.0, *) {return true}
        else {return false}
    }
}
