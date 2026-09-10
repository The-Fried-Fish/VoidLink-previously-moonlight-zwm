//
//  SettingsTouchVelocityPreview.swift
//  VoidLink
//
//  Created by True砖家 on 2026/7/30.
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import ObjectiveC
import UIKit

private var touchVelocityPreviewViewKey: UInt8 = 0
private var touchVelocityPreviewDismissWorkItemKey: UInt8 = 0
private let touchVelocityPreviewScreenAspectRatio: CGFloat = 1.3333

@available(iOS 13.0, *)
private final class TouchVelocityPreviewView: UIView {
    static let horizontalScreenInset: CGFloat = 16
    static let topPadding: CGFloat = 7
    static let titleHeight: CGFloat = 22
    static let titleScreenGap: CGFloat = 2
    static let footerGap: CGFloat = 6
    static let footerHeight: CGFloat = 40
    static let bottomPadding: CGFloat = 2
    static let heightExtra = topPadding
        + titleHeight
        + titleScreenGap
        + footerGap
        + footerHeight
        + bottomPadding
        - horizontalScreenInset * 2 / touchVelocityPreviewScreenAspectRatio
    static let preferredWidth: CGFloat = PublicUtils.isIPhone ? 280 : 360
    static let preferredHeight = preferredWidth / touchVelocityPreviewScreenAspectRatio + heightExtra

    var dividerPercent: CGFloat = 50 {
        didSet { setNeedsDisplay() }
    }

    var velocityPercent: CGFloat = 100 {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isOpaque = false
        isUserInteractionEnabled = true
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        layer.borderWidth = 1

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(openUrl))
        addGestureRecognizer(tapGesture)
    }

    @objc private func openUrl() {
        PublicUtils.openUrl("https://www.bilibili.com/video/BV1A1421r7qA")
    }

    override func draw(_ rect: CGRect) {
        let isDark = ThemeManager.userInterfaceStyle() == .dark
        let backgroundColor = isDark
            ? UIColor(white: 0.07, alpha: 0.9)
            : UIColor.white.withAlphaComponent(0.94)
        let borderColor = ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.34 : 0.24)
        let lineColor = ThemeManager.textColor.withAlphaComponent(isDark ? 0.32 : 0.22)
        let passthroughColor = UIColor.systemTeal.withAlphaComponent(isDark ? 0.22 : 0.16)
        let velocityColor = UIColor.systemIndigo.withAlphaComponent(isDark ? 0.20 : 0.13)
        let controlColor = ThemeManager.textColor.withAlphaComponent(isDark ? 0.82 : 0.66)
        let accentColor = ThemeManager.appPrimaryColor
        let secondaryAccentColor = UIColor(red: 0.18, green: 0.82, blue: 0.95, alpha: 1)
        layer.borderColor = borderColor.cgColor

        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(backgroundColor.cgColor)
        context.fill(bounds)

        let titleRect = CGRect(
            x: 12,
            y: Self.topPadding,
            width: bounds.width - 24,
            height: Self.titleHeight
        )
        drawPreviewTitle(in: titleRect, textColor: ThemeManager.textColor)

        let screenTop = titleRect.maxY + Self.titleScreenGap
        let availableScreenHeight = max(bounds.height - screenTop - Self.footerGap - Self.footerHeight - Self.bottomPadding, 1)
        let availableScreenWidth = bounds.width - Self.horizontalScreenInset * 2
        let screenWidth = min(availableScreenWidth, availableScreenHeight * touchVelocityPreviewScreenAspectRatio)
        let screenHeight = screenWidth / touchVelocityPreviewScreenAspectRatio
        let screenRect = CGRect(
            x: bounds.midX - screenWidth / 2,
            y: screenTop,
            width: screenWidth,
            height: screenHeight
        )
        let screenPath = UIBezierPath(roundedRect: screenRect, cornerRadius: 10)
        context.saveGState()
        screenPath.addClip()

        let dividerX = screenRect.minX + min(max(dividerPercent, 0), 100) / 100 * screenRect.width
        context.setFillColor(passthroughColor.cgColor)
        context.fill(CGRect(x: screenRect.minX, y: screenRect.minY, width: dividerX - screenRect.minX, height: screenRect.height))
        context.setFillColor(velocityColor.cgColor)
        context.fill(CGRect(x: dividerX, y: screenRect.minY, width: screenRect.maxX - dividerX, height: screenRect.height))

        drawDirectionWheel(in: screenRect, color: controlColor, accentColor: secondaryAccentColor)
        drawCharacterSelector(in: screenRect, color: controlColor, accentColor: accentColor)
        drawActionButtons(in: screenRect, color: controlColor, accentColor: accentColor)

        context.restoreGState()

        screenPath.lineWidth = 1
        lineColor.setStroke()
        screenPath.stroke()

        context.saveGState()
        context.setLineDash(phase: 0, lengths: [6, 5])
        context.setStrokeColor(accentColor.withAlphaComponent(0.9).cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: dividerX, y: screenRect.minY + 2))
        context.addLine(to: CGPoint(x: dividerX, y: screenRect.maxY - 2))
        context.strokePath()
        context.restoreGState()

        drawRegionLabels(screenRect: screenRect, dividerX: dividerX, textColor: ThemeManager.textColor)
        drawPreviewFooter(in: CGRect(x: 12, y: screenRect.maxY + Self.footerGap, width: bounds.width - 24, height: Self.footerHeight), textColor: ThemeManager.textColor)
    }

    private func drawPreviewTitle(in rect: CGRect, textColor: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14.5, weight: .semibold),
            .foregroundColor: textColor.withAlphaComponent(0.88),
            .paragraphStyle: paragraph
        ]
        ("Enhanced Touch Control for Genshin Game Streaming".localized as NSString).draw(in: rect, withAttributes: attributes)
    }

    private func drawPreviewFooter(in rect: CGRect, textColor: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail

        let firstLineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: textColor.withAlphaComponent(0.82),
            .paragraphStyle: paragraph
        ]
        ("Originally designed & coded by True Zhuanjia with pride".localized as NSString).draw(
            in: CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 20),
            withAttributes: firstLineAttributes
        )

        let secondLine = "Tap to learn more".localized
        let secondLineAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: textColor.withAlphaComponent(0.82),
            .paragraphStyle: paragraph
        ]
        (secondLine as NSString).draw(
            in: CGRect(x: rect.minX, y: rect.minY + 20, width: rect.width, height: 20),
            withAttributes: secondLineAttributes
        )
    }

    private func drawRegionLabels(screenRect: CGRect, dividerX: CGFloat, textColor: UIColor) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: textColor.withAlphaComponent(0.82),
            .paragraphStyle: paragraph
        ]

        let leftRect = CGRect(
            x: screenRect.minX + 8,
            y: screenRect.minY + 10,
            width: max(dividerX - screenRect.minX - 16, 0),
            height: 18
        )
        let rightRect = CGRect(
            x: dividerX + 8,
            y: screenRect.minY + 10,
            width: max(screenRect.maxX - dividerX - 16, 0),
            height: 18
        )

        if leftRect.width >= 72 {
            ("passthrough".localized as NSString).draw(in: leftRect, withAttributes: attributes)
        }
        if rightRect.width >= 80 {
            let velocityText = LocalizationHelper.localizedString(forKey: "%.0f%% velocity", velocityPercent)
            (velocityText as NSString).draw(in: rightRect, withAttributes: attributes)
        }
    }

    private func drawDirectionWheel(in rect: CGRect, color: UIColor, accentColor: UIColor) {
        let base = min(rect.width, rect.height)
        let center = CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY - base * 0.20)
        let radius = base * 0.13
        color.withAlphaComponent(0.18).setStroke()
        let outer = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        outer.lineWidth = 2
        outer.stroke()

        accentColor.withAlphaComponent(0.9).setStroke()
        let arc = UIBezierPath(arcCenter: center, radius: radius * 0.72, startAngle: -.pi * 0.8, endAngle: -.pi * 0.18, clockwise: true)
        arc.lineWidth = 5
        arc.lineCapStyle = .round
        arc.stroke()

        color.withAlphaComponent(0.52).setStroke()
        let hub = UIBezierPath(ovalIn: CGRect(x: center.x - radius * 0.17, y: center.y - radius * 0.17, width: radius * 0.34, height: radius * 0.34))
        hub.lineWidth = 2
        hub.stroke()
    }

    private func drawCharacterSelector(in rect: CGRect, color: UIColor, accentColor: UIColor) {
        let rowWidth = rect.width * 0.14
        let rowHeight = rect.height * 0.07
        let startX = rect.maxX - rowWidth - rect.width * 0.05
        let startY = rect.minY + rect.height * 0.22

        for index in 0..<3 {
            let y = startY + CGFloat(index) * rowHeight * 1.42
            let lineRect = CGRect(x: startX, y: y + rowHeight * 0.36, width: rowWidth * 0.6, height: rowHeight * 0.18)
            let line = UIBezierPath(roundedRect: lineRect, cornerRadius: lineRect.height / 2)
            color.withAlphaComponent(0.34).setFill()
            line.fill()

            let portraitRect = CGRect(x: startX + rowWidth * 0.68, y: y, width: rowHeight, height: rowHeight)
            color.withAlphaComponent(0.38).setStroke()
            let portrait = UIBezierPath(ovalIn: portraitRect)
            portrait.lineWidth = 2
            portrait.stroke()
        }
    }

    private func drawActionButtons(in rect: CGRect, color: UIColor, accentColor: UIColor) {
        let base = rect.width
        let center = CGPoint(x: rect.maxX - base * 0.19, y: rect.maxY - base * 0.16)
        let buttons: [(CGPoint, CGFloat)] = [
            (center, base * 0.055),
            (CGPoint(x: center.x + base * 0.11, y: center.y - base * 0.077), base * 0.05),
            (CGPoint(x: center.x + base * 0.11, y: center.y + base * 0.068), base * 0.05),
            (CGPoint(x: center.x - base * 0.11, y: center.y + base * 0.068), base * 0.05)
        ]

        for (index, button) in buttons.enumerated() {
            let rect = CGRect(x: button.0.x - button.1, y: button.0.y - button.1, width: button.1 * 2, height: button.1 * 2)
            let path = UIBezierPath(ovalIn: rect)
            color.withAlphaComponent(index == 0 ? 0.44 : 0.32).setStroke()
            path.lineWidth = index == 0 ? 3 : 2
            path.stroke()

            let iconRect = rect.insetBy(dx: button.1 * 0.42, dy: button.1 * 0.42)
            let icon = UIBezierPath(ovalIn: iconRect)
            (index == 0 ? accentColor : color).withAlphaComponent(index == 0 ? 0.78 : 0.55).setFill()
            icon.fill()
        }
    }
}

@available(iOS 13.0, *)
extension SettingsViewController {
    private var touchVelocityPreviewView: TouchVelocityPreviewView? {
        get {
            objc_getAssociatedObject(self, &touchVelocityPreviewViewKey) as? TouchVelocityPreviewView
        }
        set {
            objc_setAssociatedObject(self, &touchVelocityPreviewViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var touchVelocityPreviewDismissWorkItem: DispatchWorkItem? {
        get {
            objc_getAssociatedObject(self, &touchVelocityPreviewDismissWorkItemKey) as? DispatchWorkItem
        }
        set {
            objc_setAssociatedObject(self, &touchVelocityPreviewDismissWorkItemKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    @objc(showTouchVelocityPreviewWithDividerPercent:velocityPercent:)
    func showTouchVelocityPreview(dividerPercent: CGFloat, velocityPercent: CGFloat) {
        PublicUtils.runOnMain { [weak self] in
            self?.showTouchVelocityPreviewOnMain(dividerPercent: dividerPercent, velocityPercent: velocityPercent)
        }
    }

    private func showTouchVelocityPreviewOnMain(dividerPercent: CGFloat, velocityPercent: CGFloat) {
        let previewView = touchVelocityPreviewView ?? TouchVelocityPreviewView()
        touchVelocityPreviewView = previewView
        previewView.dividerPercent = dividerPercent
        previewView.velocityPercent = velocityPercent
        previewView.translatesAutoresizingMaskIntoConstraints = false

        if previewView.superview == nil {
            previewView.alpha = 0
            guard let containerView = view.window ?? view else { return }
            containerView.addSubview(previewView)
            let containerSafeArea = containerView.safeAreaLayoutGuide
            let constraints = [
                previewView.centerXAnchor.constraint(equalTo: containerSafeArea.centerXAnchor),
                previewView.centerYAnchor.constraint(equalTo: containerSafeArea.centerYAnchor),
                previewView.widthAnchor.constraint(equalToConstant: TouchVelocityPreviewView.preferredWidth),
                previewView.heightAnchor.constraint(equalToConstant: TouchVelocityPreviewView.preferredHeight)
            ]
            NSLayoutConstraint.activate(constraints)
        }

        previewView.superview?.bringSubviewToFront(previewView)
        UIView.animate(withDuration: 0.12) {
            previewView.alpha = 1
        }

    }

    @objc(cancelTouchVelocityPreviewDismiss)
    func cancelTouchVelocityPreviewDismiss() {
        PublicUtils.runOnMain { [weak self] in
            self?.touchVelocityPreviewDismissWorkItem?.cancel()
            self?.touchVelocityPreviewDismissWorkItem = nil
        }
    }

    @objc(scheduleTouchVelocityPreviewDismiss)
    func scheduleTouchVelocityPreviewDismiss() {
        PublicUtils.runOnMain { [weak self] in
            self?.scheduleTouchVelocityPreviewDismissOnMain()
        }
    }

    @objc(dismissTouchVelocityPreview)
    func dismissTouchVelocityPreview() {
        PublicUtils.runOnMain { [weak self] in
            self?.dismissTouchVelocityPreviewOnMain()
        }
    }

    private func dismissTouchVelocityPreviewOnMain() {
        touchVelocityPreviewDismissWorkItem?.cancel()
        touchVelocityPreviewDismissWorkItem = nil
        guard let previewView = touchVelocityPreviewView else { return }
        UIView.animate(withDuration: 0.18, animations: {
            previewView.alpha = 0
        }, completion: { [weak self, weak previewView] _ in
            previewView?.removeFromSuperview()
            if self?.touchVelocityPreviewView === previewView {
                self?.touchVelocityPreviewView = nil
            }
        })
    }

    private func scheduleTouchVelocityPreviewDismissOnMain() {
        guard touchVelocityPreviewView != nil else { return }
        touchVelocityPreviewDismissWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.dismissTouchVelocityPreviewOnMain()
        }
        touchVelocityPreviewDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
}
