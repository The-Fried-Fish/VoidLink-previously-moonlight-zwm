//
//  AboutViewController.swift
//  VoidLink
//
//  Created by Weimin on 2025/7/14.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


import SwiftUI

@available(iOS 13.0, *)
@objc class AboutViewController: UIViewController, ControllerUINavigationDelegate {
    func getNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "ok"))
        return elements
    }
    
    func navigateByController(forward: Bool) {}
    func navigateByController(downward: Bool) {}
    func persistControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {}
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {}
    
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        if pressed, navigation.action == "ok" {
            self.dismiss(animated: true)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let hostingVC = UIHostingController(rootView: AboutView( aboutVC: self))
        
        addChild(hostingVC)
        hostingVC.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingVC.view)
        hostingVC.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingVC.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        preferredContentSize = CGSize(width: 530, height: 430)

#if os(tvOS)
        modalPresentationStyle = .fullScreen
#else
        modalPresentationStyle = .formSheet
#endif
    }
    
    override func viewDidAppear(_ animated: Bool) {
        ControllerNavigator.setUINavigationDelegate(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        ControllerNavigator.restorePreviousUINavigationDelegate(ifCurrentDelegateIs: self)
    }
}

func isIPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}
