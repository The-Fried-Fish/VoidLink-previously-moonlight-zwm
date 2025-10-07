//
//  CountdownAlertController.swift
//  VoidLink
//
//  Created by Weimin on 2025/10/6.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
import UIKit

@objc class CountdownAlertController: NSObject {

    /// 类方法，直接在任何 UIViewController 上显示倒计时弹窗
    /// - Parameters:
    ///   - viewController: 要显示弹窗的控制器
    ///   - title: 弹窗标题
    ///   - message: 弹窗内容
    ///   - buttonTitle: 按钮初始文字（倒计时结束后显示）
    ///   - countdown: 倒计时秒数
    ///   - completion: 点击确认或倒计时结束的回调
    
    @objc public static var actionCancelled:Bool = false
    
    @objc class func showAlert(
        in viewController: UIViewController,
        title: String?,
        message: String?,
        withCancel: Bool,
        buttonTitle: String,
        countdown: Int,
        completion: (() -> Void)? = nil
    ) {
        var remainingSeconds = countdown

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: "\(remainingSeconds)", style: .default) { _ in
            actionCancelled = false
            completion?()
        }
        
        let cancelAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: "Cancel"), style: .cancel) { _ in
            actionCancelled = true
            completion?()
        }
        
        confirmAction.isEnabled = false
        
        if withCancel {alert.addAction(cancelAction)}
        alert.addAction(confirmAction)

        viewController.present(alert, animated: true, completion: nil)

        // 倒计时
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(50))
        timer.setEventHandler {
            remainingSeconds -= 1

            if remainingSeconds <= 0 {
                timer.cancel()
                confirmAction.isEnabled = true
                confirmAction.setValue(buttonTitle, forKey: "title")
            } else {
                confirmAction.setValue("\(remainingSeconds)", forKey: "title")
            }
        }
        timer.resume()
    }
}
