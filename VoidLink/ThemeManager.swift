//
//  ThemeManager.swift
//  VoidLink
//
//  Created by True砖家 on 2026/3/6.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//


import UIKit

@objcMembers
class ThemeManager: NSObject {

    static let ThemeDidChangeNotification = "ThemeDidChangeNotification"

    private static var _privateUserInterfaceStyle: UIUserInterfaceStyle = .unspecified
    private static var _userInterfaceStyle: UIUserInterfaceStyle = .unspecified

    @objc class func setPublicUIStyle() -> UIColor {
        if #available(iOS 13.0, *) {
            let traitCollection = UIScreen.main.traitCollection
            if _privateUserInterfaceStyle == .unspecified {
                _userInterfaceStyle = traitCollection.userInterfaceStyle
            } else {
                _userInterfaceStyle = _privateUserInterfaceStyle
            }
        }
        return UIColor.clear
    }

    @objc class func userInterfaceStyle() -> UIUserInterfaceStyle {
        _ = setPublicUIStyle()
        return _userInterfaceStyle
    }

    @objc class func setUserInterfaceStyle(_ style: UIUserInterfaceStyle) {
        _privateUserInterfaceStyle = style

        if _userInterfaceStyle == style {
            return
        }

        _ = setPublicUIStyle()

        NotificationCenter.default.post(
            name: Notification.Name(ThemeDidChangeNotification),
            object: nil
        )
    }

    @objc class func menuBackgroundColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor(
                red: 242.0/255.0,
                green: 242.0/255.0,
                blue: 247.0/255.0,
                alpha: 1
            )

        default:
            if #available(iOS 13.0, *) {
                let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
                return UIColor.secondarySystemBackground.resolvedColor(with: darkTraits)
            } else {
                return UIColor(
                    red: 28.0/255.0,
                    green: 28.0/255.0,
                    blue: 30.0/255.0,
                    alpha: 1
                )
            }
        }
    }
    
    @objc class func hostViewBackgroundColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor(
                red: 242.0/255.0,
                green: 242.0/255.0,
                blue: 247.0/255.0,
                alpha: 1
            )

        default:
            if #available(iOS 13.0, *) {
                let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
                return UIColor.systemGroupedBackground.resolvedColor(with: darkTraits)
            } else {
                return UIColor.black
            }
        }
    }
    
    @objc class func offlineHostIconBackgroundColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor(
                red: 242.0/255.0,
                green: 242.0/255.0,
                blue: 247.0/255.0,
                alpha: 1
            )

        default:
            return UIColor(
                red: 17.0/255.0,
                green: 17.0/255.0,
                blue: 19.0/255.0,
                alpha: 1
            )
        }
    }

    @objc class func widgetBackgroundColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor.white
        default:
            if #available(iOS 13.0, *) {
                // return UIColor.secondarySystemBackground
                let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
                return UIColor.secondarySystemGroupedBackground.resolvedColor(with: darkTraits)
            } else {
                return UIColor(
                    red: 44.0/255.0,
                    green: 44.0/255.0,
                    blue: 46.0/255.0,
                    alpha: 1
                )
            }
        }
    }

    @objc class func separatorColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            if #available(iOS 13.0, *) {
                let lightTraits = UITraitCollection(userInterfaceStyle: .light)
                return UIColor.separator.resolvedColor(with: lightTraits)
            } else {
                return UIColor(
                    red: 214.0/255.0,
                    green: 214.0/255.0,
                    blue: 218.0/255.0,
                    alpha: 1
                )
            }
        default:
            if #available(iOS 13.0, *) {
                let darkTraits = UITraitCollection(userInterfaceStyle: .dark)
                return UIColor.separator.resolvedColor(with: darkTraits)
            } else {return UIColor(white: 0.28, alpha: 1)}
        }
    }
    
    @objc class func hostCardSeparatorColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor(white: 0.1, alpha: 0.28)
        default:
            return UIColor(white: 0.28, alpha: 1)
        }
    }

    @objc class func textColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            return UIColor.black
        default:
            return UIColor.white
        }
    }
    
    @objc class func sectionLabelTextColor() -> UIColor {
        _ = setPublicUIStyle()

        switch userInterfaceStyle() {
        case .light:
            if #available(iOS 13.0, *) {
                let traits = UITraitCollection(userInterfaceStyle: .light)
                return UIColor.label.resolvedColor(with: traits)
            } else {
                return UIColor.black
            }
        default:
            if #available(iOS 13.0, *) {
                let traits = UITraitCollection(userInterfaceStyle: .dark)
                return UIColor.label.resolvedColor(with: traits)
            } else {
                return UIColor.black
            }
        }
    }

    @objc class func appPrimaryColor() -> UIColor {
        return UIColor(
            red: 0.0,
            green: 0.48,
            blue: 1.0,
            alpha: 1.0
        ) // #0A84FF
    }

    @objc class func appSecondaryColor() -> UIColor {

        let originalColor = appPrimaryColor()
        let grayColor = UIColor.gray
        let mixRatio: CGFloat = 0.3

        var r1: CGFloat = 0
        var g1: CGFloat = 0
        var b1: CGFloat = 0
        var a1: CGFloat = 0

        var r2: CGFloat = 0
        var g2: CGFloat = 0
        var b2: CGFloat = 0
        var a2: CGFloat = 0

        originalColor.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        grayColor.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        let r = r1 * (1 - mixRatio) + r2 * mixRatio
        let g = g1 * (1 - mixRatio) + g2 * mixRatio
        let b = b1 * (1 - mixRatio) + b2 * mixRatio
        let a = a1 * (1 - mixRatio) + a2 * mixRatio

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }

    @objc class func appPrimaryColorWithAlpha() -> UIColor {
        return appPrimaryColor().withAlphaComponent(0.24)
    }

    @objc class func textTintColorWithAlpha() -> UIColor {
        return appPrimaryColor().withAlphaComponent(0.24)
    }

    @objc class func textColorGray() -> UIColor {
        return UIColor(
            red: 0.55,
            green: 0.55,
            blue: 0.6,
            alpha: 0.95
        )
    }

    @objc class func lowProfileGray() -> UIColor {
        return UIColor(
            red: 0.65,
            green: 0.65,
            blue: 0.65,
            alpha: 0.4
        )
    }
}
