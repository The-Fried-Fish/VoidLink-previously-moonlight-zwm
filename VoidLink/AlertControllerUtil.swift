//
//  AlertControllerUtil.swift
//  VoidLink
//
//  Created by Weimin on 2025/10/6.
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//
import UIKit

@objc class AlertControllerUtil: NSObject {
    private enum AlertTextRole {
        case title
        case message
    }

    private static func makeCountdownMessage(baseMessage: String?, remainingSeconds: Int) -> String {
        let countdownText = "\(remainingSeconds)"
        guard let baseMessage, !baseMessage.isEmpty else {
            return countdownText
        }
        return "\(baseMessage)\n\n\(countdownText)"
    }

    private static func makeCountdownButtonTitle(baseButtonTitle: String, remainingSeconds: Int) -> String {
        "\(baseButtonTitle) (\(remainingSeconds))"
    }

    @available(iOS 13.0, *)
    private static func makeLeftAlignedAttributedText(_ text: String, role: AlertTextRole) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping

        let font: UIFont
        let color: UIColor

        switch role {
        case .title:
            font = .preferredFont(forTextStyle: .headline)
            color = .label
        case .message:
            font = .preferredFont(forTextStyle: .footnote)
            color = .label
        }

        return NSAttributedString(
            string: text,
            attributes: [
                .paragraphStyle: paragraphStyle,
                .font: font,
                .foregroundColor: color
            ]
        )
    }

    private static func applyLeftAlignment(title: String?, message: String?) {
        if #available(iOS 26.0, *) {
            return
        }
        if #available(iOS 13.0, *) {
            if let title, !title.isEmpty {
                    alertController.setValue(makeLeftAlignedAttributedText(title, role: .title), forKey: "attributedTitle")
            }

            if let message, !message.isEmpty {
                alertController.setValue(makeLeftAlignedAttributedText(message, role: .message), forKey: "attributedMessage")
            }
        }
    }

    /// 类方法，直接在任何 UIViewController 上显示倒计时弹窗
    /// - Parameters:
    ///   - viewController: 要显示弹窗的控制器
    ///   - title: 弹窗标题
    ///   - message: 弹窗内容
    ///   - buttonTitle: 按钮文字；非 Mac-as-iPad 环境会在倒计时期间一同显示剩余秒数
    ///   - countdown: 倒计时秒数
    ///   - completion: 点击确认或倒计时结束的回调
    
    @objc public static var actionCancelled:Bool = false
    @objc public static var alertController:UIAlertController = UIAlertController()
    @objc public static var cancelButtonString:String = "Cancel"
    @objc static var completion: (() -> Void)? = nil
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
        let showsCountdownInButton = countdown > 0 &&
            !autoCompletion &&
            !PublicUtils.isRunningOnMacAsiPadApp &&
            !buttonTitle.isEmpty
        let showsCountdownInMessage = countdown > 0 && !autoCompletion && !showsCountdownInButton
        var isAlertDismissed = false
        
        AlertControllerUtil.completion = completion
        
        guard let viewController = viewController else {return}

        alertController = UIAlertController(
            title: title,
            message: showsCountdownInMessage ? makeCountdownMessage(baseMessage: originalMessage, remainingSeconds: remainingSeconds) : message,
            preferredStyle: .alert
        )
        applyLeftAlignment(
            title: title,
            message: showsCountdownInMessage ? makeCountdownMessage(baseMessage: originalMessage, remainingSeconds: remainingSeconds) : message
        )

        let confirmAction = UIAlertAction(
            title: showsCountdownInButton ? makeCountdownButtonTitle(baseButtonTitle: buttonTitle, remainingSeconds: remainingSeconds) : buttonTitle,
            style: .default
        ) { _ in
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
                    applyLeftAlignment(title: title, message: originalMessage)
                    autoCompletion = false
                    completion?()
                    AlertControllerUtil.completion = nil
                    alertController.dismiss(animated: false)
                    return
                }

                if PublicUtils.isRunningOnMacAsiPadApp && buttonTitle != "" {
                    AlertControllerUtil.completion = nil
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
                confirmAction.setValue(buttonTitle, forKey: "title")
                alertController.message = originalMessage
                applyLeftAlignment(title: title, message: originalMessage)
                
                if #available(iOS 13.0, *) {
                    ControllerNavigator.setUINavigationDelegate(alertController)
                }
            } else {
                if !autoCompletion {
                    if showsCountdownInButton {
                        confirmAction.setValue(
                            makeCountdownButtonTitle(baseButtonTitle: buttonTitle, remainingSeconds: remainingSeconds),
                            forKey: "title"
                        )
                    } else {
                        let countdownMessage = makeCountdownMessage(baseMessage: originalMessage, remainingSeconds: remainingSeconds)
                        alertController.message = countdownMessage
                        applyLeftAlignment(title: title, message: countdownMessage)
                    }
                }
            }
        }
        timer.resume()
    }
}
