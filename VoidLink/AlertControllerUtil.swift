//
//  AlertControllerUtil.swift
//  VoidLink
//
//  Created by Weimin on 2025/10/6.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
import UIKit

@objc class AlertControllerUtil: NSObject {

    /// 类方法，直接在任何 UIViewController 上显示倒计时弹窗
    /// - Parameters:
    ///   - viewController: 要显示弹窗的控制器
    ///   - title: 弹窗标题
    ///   - message: 弹窗内容
    ///   - buttonTitle: 按钮初始文字（倒计时结束后显示）
    ///   - countdown: 倒计时秒数
    ///   - completion: 点击确认或倒计时结束的回调
    
    @objc public static var actionCancelled:Bool = false
    @objc public static var alertController:UIAlertController = UIAlertController()
    @objc public static var cancelButtonString:String = "Cancel"
    @objc public static var autoCompletion:Bool = false

    @objc class func showAlert(
        in viewController: UIViewController,
        title: String?,
        message: String?,
        withCancel: Bool,
        buttonTitle: String,
        countdown: Int,
        action: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        var remainingSeconds = countdown

        alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)

        let confirmAction = UIAlertAction(title: "\(remainingSeconds)", style: .default) { _ in
            actionCancelled = false
            completion?()
            cancelButtonString = "Cancel"
        }
        
        let cancelAction = UIAlertAction(title: SwiftLocalizationHelper.localizedString(forKey: cancelButtonString), style: .cancel) { _ in
            actionCancelled = true
            completion?()
            cancelButtonString = "Cancel"
        }
        
        confirmAction.isEnabled = false
        
        if withCancel {alertController.addAction(cancelAction)}
        if buttonTitle != "" && !autoCompletion {alertController.addAction(confirmAction)}
        
        if(countdown == 0) {
            confirmAction.setValue(buttonTitle, forKey: "title")
            confirmAction.isEnabled = buttonTitle != ""
        }

        viewController.present(alertController, animated: true, completion: action)
        
        if(countdown == 0) {return}

        // 倒计时
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: 1.0, leeway: .milliseconds(50))
        timer.setEventHandler {
            remainingSeconds -= 1

            if remainingSeconds <= 0 {
                timer.cancel()
                confirmAction.isEnabled = true
                confirmAction.setValue(buttonTitle, forKey: "title")
                if autoCompletion {
                    autoCompletion = false
                    alertController.dismiss(animated: false)
                    return
                }
            } else {
                confirmAction.setValue("\(remainingSeconds)", forKey: "title")
            }
        }
        timer.resume()
    }
}
