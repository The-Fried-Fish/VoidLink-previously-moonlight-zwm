//
//  AlertControllerUtil.swift
//  VoidLink
//
//  Created by Weimin on 2025/10/6.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
import UIKit

@objc class AlertControllerUtil: NSObject {
    private static func makeCountdownMessage(baseMessage: String?, remainingSeconds: Int) -> String {
        let countdownText = "\(remainingSeconds)"
        guard let baseMessage, !baseMessage.isEmpty else {
            return countdownText
        }
        return "\(baseMessage)\n\n\(countdownText)"
    }

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
    @objc public static var isCountingDown:Bool = false

    @objc class func showAlert(
        in viewController: UIViewController? = nil,
        title: String?,
        message: String?,
        withCancel: Bool,
        buttonTitle: String,
        countdown: Int,
        action: (() -> Void)? = nil,
        completion: (() -> Void)? = nil
    ) {
        var remainingSeconds = countdown
        let originalMessage = message
        var isAlertDismissed = false
        
        guard let viewController = viewController else {return}

        alertController = UIAlertController(
            title: title,
            message: (countdown > 0 && !autoCompletion) ? makeCountdownMessage(baseMessage: originalMessage, remainingSeconds: remainingSeconds) : message,
            preferredStyle: .alert
        )

        let confirmAction = UIAlertAction(title: buttonTitle, style: .default) { _ in
            isAlertDismissed = true
            actionCancelled = false
            completion?()
            cancelButtonString = "Cancel"
        }
        
        let cancelAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: cancelButtonString), style: .cancel) { _ in
            isAlertDismissed = true
            actionCancelled = true
            completion?()
            cancelButtonString = "Cancel"
        }
        
        confirmAction.isEnabled = false
        
        if withCancel {alertController.addAction(cancelAction)}
        if buttonTitle != "" && !autoCompletion {alertController.addAction(confirmAction)}
        
        if(countdown == 0) {
            confirmAction.isEnabled = buttonTitle != ""
        }

        viewController.present(alertController, animated: true, completion: action)
        isCountingDown = !autoCompletion && countdown > 0
        
        if(countdown == 0) {return}

        // 倒计时
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now() + (autoCompletion ? 0.5 : 1.0), repeating: autoCompletion ? 0.1: 1.0, leeway: .milliseconds(50))
        timer.setEventHandler {
            guard !isAlertDismissed else {
                timer.cancel()
                return
            }

            remainingSeconds -= 1

            if remainingSeconds <= 0 {
                isCountingDown = false
                isAlertDismissed = true
                timer.cancel()
                if autoCompletion {
                    alertController.message = originalMessage
                    autoCompletion = false
                    completion?()
                    alertController.dismiss(animated: false)
                    return
                }

                if GenericUtils.isRunningOnMacAsiPadApp && buttonTitle != "" {
                    alertController.dismiss(animated: false) {
                        showAlert(
                            in: viewController,
                            title: title,
                            message: originalMessage,
                            withCancel: withCancel,
                            buttonTitle: buttonTitle,
                            countdown: 0,
                            action: nil,
                            completion: completion
                        )
                    }
                    return
                }

                confirmAction.isEnabled = true
                alertController.message = originalMessage
            } else {
                if !autoCompletion {alertController.message = makeCountdownMessage(baseMessage: originalMessage, remainingSeconds: remainingSeconds)}
            }
        }
        timer.resume()
    }
}
