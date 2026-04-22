//
//  UIStackExtension.swift
//  VoidLink
//
//  Created by Weimin on 2026/4/17.
//  Copyright © 2026 Moonlight Game Streaming Project. All rights reserved.
//

import UIKit
import ObjectiveC

private var isGameProfileSettingKey: UInt8 = 0
private var hasInfoTagKey: UInt8 = 0
private var hasDynamicLabelKey: UInt8 = 0

extension UIStackView {

    @objc var isGameProfileSetting: Bool {
        get {
            return objc_getAssociatedObject(self, &isGameProfileSettingKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &isGameProfileSettingKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc var hasInfoTag: Bool {
        get {
            return objc_getAssociatedObject(self, &hasInfoTagKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &hasInfoTagKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    @objc var hasDynamicLabel: Bool {
        get {
            return objc_getAssociatedObject(self, &hasDynamicLabelKey) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self,
                                     &hasDynamicLabelKey,
                                     newValue,
                                     .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
