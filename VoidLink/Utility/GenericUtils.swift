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
        let key = "needUpdateDefaultSettings20260226-2"
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
}
