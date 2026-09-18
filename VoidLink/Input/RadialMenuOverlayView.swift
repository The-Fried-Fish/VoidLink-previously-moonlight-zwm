//
//  RadialMenuOverlayView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/7/1.
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, *)
final class RadialMenuOverlayView: UIView {
    func getNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .right ? .leftStick : .rightStick, action: "focusNavigation"))
        return elements
    }
        
    private enum Metrics {
        static let diameter: CGFloat = PublicUtils.isIPhone ? 200 : (PublicUtils.isTVOS ? 430 : 260)
        static let releaseDistanceEpsilon: CGFloat = 0.015
    }

    private let selectionState = RadialMenuSelectionState()
    private var hostingController: UIHostingController<RadialMenuView>?
    private var themeObserver: NSObjectProtocol?
    private var previousJoystickDistance: CGFloat?
    private var isJoystickReturningToCenter = false
    private var releaseLatchedSelectedIndex: Int?

    static var menuSectors: [RadialMenuSector] = []

    init() {
        super.init(frame: .zero)
        setupView()
        observeThemeChanges()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        observeThemeChanges()
    }

    deinit {
        removeThemeObserver()
    }

    static func presentInKeyWindow() -> RadialMenuOverlayView? {
        guard let window = keyWindow() else { return nil }
        let overlayView = RadialMenuOverlayView()
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        window.addSubview(overlayView)
        NSLayoutConstraint.activate([
            overlayView.widthAnchor.constraint(equalToConstant: Metrics.diameter),
            overlayView.heightAnchor.constraint(equalToConstant: Metrics.diameter),
            overlayView.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: window.centerYAnchor)
        ])
        CATransaction.commit()
        return overlayView
    }

    func updateSelection(xOffset: CGFloat, yOffset: CGFloat) -> RadialMenuItem? {
        guard Thread.isMainThread else {
            return DispatchQueue.main.sync {
                self.updateSelection(xOffset: xOffset, yOffset: yOffset)
            }
        }

        let previousSelectedIndex = selectionState.selectedIndex
        latchSelectionIfNeeded(
            distance: Self.normalizedDistance(xOffset: xOffset, yOffset: yOffset),
            selectedIndex: previousSelectedIndex
        )

        selectionState.updateSelection(xOffset: xOffset, yOffset: yOffset)

        guard previousSelectedIndex != nil, selectionState.selectedIndex == nil else {
            return nil
        }

        let actionSelectedIndex = releaseLatchedSelectedIndex ?? previousSelectedIndex
        resetReleaseLatch()

        guard let actionSelectedIndex,
              Self.menuSectors.indices.contains(actionSelectedIndex) else {
            return nil
        }

        return Self.menuSectors[actionSelectedIndex].item
    }

    func dismiss() {
        removeThemeObserver()
        hostingController?.willMove(toParent: nil)
        hostingController?.view.removeFromSuperview()
        hostingController?.removeFromParent()
        hostingController = nil
        removeFromSuperview()
    }

    private func setupView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
        clipsToBounds = false

        let radialMenuView = makeRadialMenuView()

        let hostingController = UIHostingController(rootView: radialMenuView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        self.hostingController = hostingController
        addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
        
        GamepadNavigationIllustrationHud.updateNavigationElements(self.getNavigationElements())
    }

    private func observeThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(ThemeManager.ThemeDidChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshTheme()
        }
    }

    private func removeThemeObserver() {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
            self.themeObserver = nil
        }
    }

    private func refreshTheme() {
        hostingController?.rootView = makeRadialMenuView()
    }

    private func latchSelectionIfNeeded(distance: CGFloat, selectedIndex: Int?) {
        defer { previousJoystickDistance = distance }

        guard let previousJoystickDistance else {
            return
        }

        if distance + Metrics.releaseDistanceEpsilon < previousJoystickDistance {
            if !isJoystickReturningToCenter {
                releaseLatchedSelectedIndex = selectedIndex
                isJoystickReturningToCenter = true
            }
        } else if distance > previousJoystickDistance + Metrics.releaseDistanceEpsilon {
            resetReleaseLatch(keepingPreviousDistance: true)
        }
    }

    private func resetReleaseLatch(keepingPreviousDistance: Bool = false) {
        if !keepingPreviousDistance {
            previousJoystickDistance = nil
        }
        isJoystickReturningToCenter = false
        releaseLatchedSelectedIndex = nil
    }

    private func makeRadialMenuView() -> RadialMenuView {
        RadialMenuView(
            sectors: Self.menuSectors,
            isTouchSelectionEnabled: false,
            style: RadialMenuStyle.themed(
                for: ThemeManager.userInterfaceStyle(),
                accentColor: ThemeManager.appPrimaryColor
            ),
            selectionState: selectionState
        )
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first
    }

    private static func normalizedDistance(xOffset: CGFloat, yOffset: CGFloat) -> CGFloat {
        let x = max(min(xOffset, 1), -1)
        let y = max(min(yOffset, 1), -1)
        return hypot(x, y)
    }
    
    func navigateByController(forward: Bool) {}
    func navigateByController(downward: Bool) {}
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {}
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {}
}
