//
//  AboutViewController.swift
//  VoidLink
//
//  Created by Weimin on 2025/7/14.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//


import SwiftUI

@available(iOS 13.0, *)
@objc class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingVC = UIHostingController(rootView: AboutView())
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

        // 🎯 设置弹窗大小
        preferredContentSize = CGSize(width: 600, height: 450)
        //preferredContentSize = CGSize(width:150, height:120 )

        // ⚠️ 一定要设置以下样式才会生效 preferredContentSize
        modalPresentationStyle = .formSheet
    }
}

func isIPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}
