//
//  PublicExtensions.swift
//  VoidLink
//
//  Created by True砖家 on 2026/6/30.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//

import UIKit

extension UIViewController {
    var hasNoPresentedVC: Bool {
        let hasNoPresentedVC = self.presentedViewController == nil && self.view.window != nil
        // let presentedVC = self.presentedViewController
        return hasNoPresentedVC
    }
}

public extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

public extension CGPoint {
    var isValid: Bool {
        x.isFinite && y.isFinite
    }
}

public extension CGVector {
    var isNotZero: Bool {
        dx != 0 && dx != 0
    }
}

public extension Array where Element: Equatable {
    @discardableResult
    mutating func appendIfNotContains(_ newElement: Element) -> Bool {
        guard !contains(newElement) else { return false }
        append(newElement)
        return true
    }
}

public extension String {
    var localized: String {
        LocalizationHelper.localizedString(forKey: self)
    }
    
    var localizedProfileName: String {
        let parts = self.components(separatedBy: " - Restored")
        let isRestored = self.contains(" - Restored")
        let localized = isRestored ? "\(parts.first?.localized ?? "") - \("Restored".localized)" : self.localized
        return localized
    }
}

public extension UIFont {
    static func roundedSystemFont(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        if #available(iOS 13.0, *) {
            if let roundedDescriptor = font.fontDescriptor.withDesign(.rounded) {
                return UIFont(descriptor: roundedDescriptor, size: size)
            }
        }

        return font
    }
}

#if !os(tvOS)
public extension UISlider {
    func step(forward: Bool, visualStepRatio: Float) {
        let range = self.maximumValue - self.minimumValue
        guard range > 0 else { return }

        let step = range * visualStepRatio
        let nextValue = self.value + (forward ? step : -step)

        let clampedValue = min(max(nextValue, self.minimumValue), self.maximumValue)
        DispatchQueue.main.async {
            self.setValue(clampedValue, animated: false)
            self.sendActions(for: .valueChanged)
        }
    }
}
#endif

private var previousSelectedSegmentIndexKey: UInt8 = 0
private var lastKnownSelectedSegmentIndexKey: UInt8 = 0
public extension UISegmentedControl {
    @objc static func installPreviousSelectionTracking() {
        _ = enablePreviousSelectionTracking
    }

    private static let enablePreviousSelectionTracking: Void = {
        guard
            let originalSetter = class_getInstanceMethod(
                UISegmentedControl.self,
                #selector(setter: UISegmentedControl.selectedSegmentIndex)
            ),
            let swizzledSetter = class_getInstanceMethod(
                UISegmentedControl.self,
                #selector(UISegmentedControl.vl_setSelectedSegmentIndex(_:))
            ),
            let originalSendAction = class_getInstanceMethod(
                UISegmentedControl.self,
                #selector(UISegmentedControl.sendAction(_:to:for:))
            ),
            let swizzledSendAction = class_getInstanceMethod(
                UISegmentedControl.self,
                #selector(UISegmentedControl.vl_sendAction(_:to:for:))
            )
        else {
            return
        }

        swizzleMethod(
            on: UISegmentedControl.self,
            originalMethod: originalSetter,
            originalSelector: #selector(setter: UISegmentedControl.selectedSegmentIndex),
            swizzledMethod: swizzledSetter,
            swizzledSelector: #selector(UISegmentedControl.vl_setSelectedSegmentIndex(_:))
        )
        swizzleMethod(
            on: UISegmentedControl.self,
            originalMethod: originalSendAction,
            originalSelector: #selector(UISegmentedControl.sendAction(_:to:for:)),
            swizzledMethod: swizzledSendAction,
            swizzledSelector: #selector(UISegmentedControl.vl_sendAction(_:to:for:))
        )
    }()

    @objc var previousSelectedSegmentIndex: Int {
        Self.installPreviousSelectionTracking()
        initializeLastKnownIndexIfNeeded()
        return (objc_getAssociatedObject(self, &previousSelectedSegmentIndexKey) as? NSNumber)?.intValue
            ?? selectedSegmentIndex
    }

    @objc func resetPreviousSelectedSegmentIndex() {
        Self.installPreviousSelectionTracking()
        storePreviousSelectedSegmentIndex(selectedSegmentIndex)
        storeLastKnownSelectedSegmentIndex(selectedSegmentIndex)
    }

    @objc private func vl_setSelectedSegmentIndex(_ newValue: Int) {
        Self.installPreviousSelectionTracking()
        initializeLastKnownIndexIfNeeded()

        let currentValue = selectedSegmentIndex
        if currentValue != newValue {
            storePreviousSelectedSegmentIndex(currentValue)
            storeLastKnownSelectedSegmentIndex(newValue)
        }

        vl_setSelectedSegmentIndex(newValue)
    }

    @objc private func vl_sendAction(_ action: Selector, to target: Any?, for event: UIEvent?) {
        Self.installPreviousSelectionTracking()
        updatePreviousSelectedSegmentIndexIfNeeded()
        vl_sendAction(action, to: target, for: event)
    }

    private func initializeLastKnownIndexIfNeeded() {
        guard objc_getAssociatedObject(self, &lastKnownSelectedSegmentIndexKey) == nil else {
            return
        }
        storeLastKnownSelectedSegmentIndex(selectedSegmentIndex)
    }

    private func updatePreviousSelectedSegmentIndexIfNeeded() {
        initializeLastKnownIndexIfNeeded()

        let currentValue = selectedSegmentIndex
        let lastKnownValue = (objc_getAssociatedObject(self, &lastKnownSelectedSegmentIndexKey) as? NSNumber)?.intValue
            ?? UISegmentedControl.noSegment

        guard currentValue != lastKnownValue else {
            return
        }

        storePreviousSelectedSegmentIndex(lastKnownValue)
        storeLastKnownSelectedSegmentIndex(currentValue)
    }

    private func storePreviousSelectedSegmentIndex(_ value: Int) {
        guard canStorePreviousSelectedSegmentIndex(value) else {
            return
        }

        objc_setAssociatedObject(
            self,
            &previousSelectedSegmentIndexKey,
            NSNumber(value: value),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private func canStorePreviousSelectedSegmentIndex(_ value: Int) -> Bool {
        guard value != UISegmentedControl.noSegment else {
            return true
        }
        guard value >= 0 && value < numberOfSegments else {
            return false
        }
        return isEnabledForSegment(at: value)
    }

    private func storeLastKnownSelectedSegmentIndex(_ value: Int) {
        objc_setAssociatedObject(
            self,
            &lastKnownSelectedSegmentIndexKey,
            NSNumber(value: value),
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }

    private static func swizzleMethod(
        on cls: AnyClass,
        originalMethod: Method,
        originalSelector: Selector,
        swizzledMethod: Method,
        swizzledSelector: Selector
    ) {
        let didAddMethod = class_addMethod(
            cls,
            originalSelector,
            method_getImplementation(swizzledMethod),
            method_getTypeEncoding(swizzledMethod)
        )

        if didAddMethod {
            class_replaceMethod(
                cls,
                swizzledSelector,
                method_getImplementation(originalMethod),
                method_getTypeEncoding(originalMethod)
            )
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod)
        }
    }
    
    func nextIndex(forward: Bool) -> Int {
        var targetIndex = forward ? self.selectedSegmentIndex + 1 : self.selectedSegmentIndex - 1
        targetIndex = forward ? (targetIndex == self.numberOfSegments ? 0 : targetIndex) : (targetIndex == -1 ? self.numberOfSegments-1 : targetIndex)
        return targetIndex
    }
}
