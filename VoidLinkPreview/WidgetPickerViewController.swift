//
//  WidgetPickerViewController.swift
//  VoidLink
//
//  Created by True砖家 on 2026/4/2.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, *)
@objc public protocol WidgetPickerViewControllerDelegate: AnyObject {
    func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary)
    @objc optional func widgetPickerViewControllerDidCancel(_ controller: WidgetPickerViewController)
}

@available(iOS 13.0, *)
@objcMembers
public final class WidgetPickerViewController: UIViewController {
    private static var overlayWindow: UIWindow?
    private static weak var originalAppWindow: UIWindow?
    private static weak var originalHostViewController: UIViewController?

    public weak var delegate: WidgetPickerViewControllerDelegate?
    public var isEditMode: Bool = false
    public var initialCmdString: String?
    public var initialButtonLabel: String?
    public var initialShape: String?
    public var tabIdentifiers: [String] = []
    public var initialTabIdentifier: String?
    public var keyboardPickerMode: VirtualKeyboardMode = .picker
    var shortcutPickerNeedAlias: Bool = false
    var shortcutPickerNeedButtonMode: Bool = false
    public var shortcutPickerTipText: String?
    @objc public var shortcutIdentifier: String?
    public var usesOverlayPresentation: Bool = false

    private let presentationState = WidgetPickerPresentationState()
    private var hostingViewController: UIHostingController<WidgetPickerView>?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = usesOverlayPresentation ? .clear : .systemBackground

        let rootView = WidgetPickerView(
            isEditMode: isEditMode,
            initialCmdString: initialCmdString,
            initialButtonLabel: initialButtonLabel,
            initialShape: initialShape,
            availableTabs: resolvedTabs(),
            preferredInitialTab: resolvedInitialTab(),
            keyboardPickerMode: keyboardPickerMode,
            shortcutPickerNeedAlias: shortcutPickerNeedAlias,
            shortcutPickerNeedButtonMode: shortcutPickerNeedButtonMode,
            shortcutPickerTipText: shortcutPickerTipText,
            shortcutIdentififier: shortcutIdentifier,
            presentationState: presentationState,
            onWidgetCreated: { [weak self] payload in
                guard let self else { return }
                self.delegate?.widgetPickerViewController(self, didCreateWidget: payload as NSDictionary)
                self.closeSelf(animated: true)
            },
            onCloseRequested: { [weak self] in
                self?.closeSelf(animated: true)
            }
        )
        let hostingViewController = UIHostingController(rootView: rootView)
        self.hostingViewController = hostingViewController

        addChild(hostingViewController)
        hostingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingViewController.view)
        hostingViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        preferredContentSize = CGSize(width: 1120, height: 760)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentationState.hasHostAppeared = true
    }

    private func resolvedTabs() -> [WidgetPickerTab] {
        let tabs = tabIdentifiers.compactMap(WidgetPickerTab.init(identifier:))
        return tabs.isEmpty ? WidgetPickerTab.allCases : tabs
    }

    private func resolvedInitialTab() -> WidgetPickerTab? {
        guard let initialTabIdentifier else { return nil }
        return WidgetPickerTab(identifier: initialTabIdentifier)
    }

    public func presentAsOverlay(in parentViewController: UIViewController, animated: Bool = true) {
        guard parent == nil else { return }
        guard let originalAppWindow = parentViewController.view.window,
              let windowScene = originalAppWindow.windowScene else { return }

        usesOverlayPresentation = true
        Self.originalAppWindow = originalAppWindow
        Self.originalHostViewController = parentViewController
        let overlayHostViewController = UIViewController()
        overlayHostViewController.view.backgroundColor = .clear

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.frame = windowScene.screen.bounds
        overlayWindow.windowLevel = .alert + 1
        overlayWindow.backgroundColor = .clear
        overlayWindow.rootViewController = overlayHostViewController
        overlayWindow.makeKeyAndVisible()
        Self.overlayWindow = overlayWindow

        loadViewIfNeeded()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = animated ? 0 : 1

        overlayHostViewController.addChild(self)
        overlayHostViewController.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: overlayHostViewController.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: overlayHostViewController.view.bottomAnchor),
            view.leadingAnchor.constraint(equalTo: overlayHostViewController.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: overlayHostViewController.view.trailingAnchor),
        ])
        didMove(toParent: overlayHostViewController)

        guard animated else { return }
        UIView.animate(withDuration: 0.18) {
            self.view.alpha = 1
        }
    }

    private func closeSelf(animated: Bool) {
        if presentingViewController != nil {
            dismiss(animated: animated)
            return
        }

        guard parent != nil else {
            Self.destroyOverlayWindowAndRestoreAppWindow()
            return
        }

        let removeOverlay = {
            self.willMove(toParent: nil)
            self.view.removeFromSuperview()
            self.removeFromParent()
            Self.destroyOverlayWindowAndRestoreAppWindow()
        }

        guard animated else {
            removeOverlay()
            return
        }

        UIView.animate(
            withDuration: 0.18,
            animations: {
                self.view.alpha = 0
            },
            completion: { _ in
                removeOverlay()
            }
        )
    }

    private static func destroyOverlayWindowAndRestoreAppWindow() {
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil
        originalAppWindow?.makeKeyAndVisible()
        refreshSystemGestureDeferral()
        originalAppWindow = nil
        originalHostViewController = nil
    }

    private static func refreshSystemGestureDeferral() {
        guard let hostViewController = originalHostViewController else { return }
        if #available(iOS 11.0, *) {
            hostViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            hostViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }
}
