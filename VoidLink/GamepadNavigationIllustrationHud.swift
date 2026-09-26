//
//  GamepadNavigationIllustrationHud.swift
//  VoidLink
//
//  Created by True Zhuanjia on 2026/7/14.
//  Copyright 2026 True Zhuanjia @ Bilibili. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
@objcMembers
final class GamepadNavigationIllustrationHud: UIView {
    private enum KeyContent {
        case text(String)
        case symbol(String)
    }

    private struct Hint {
        let control: ControllerElement
        let keyContent: KeyContent
        let titles: [String]
        let isInAction: Bool
    }

    private let containerView = UIView()
    private let contentStackView = UIStackView()
    private var themeObserver: NSObjectProtocol?
    private var windowConstraints: [NSLayoutConstraint] = []
    private var trailingConstraint: NSLayoutConstraint?
    private static let keyBorderViewTag = 4101
    private static let keyContentViewTag = 4102
    private static var currentHud: GamepadNavigationIllustrationHud?
    private static var activeControls = Set<ControllerElement>()
    private static var actionStateMinimumEndTimes: [ControllerElement: CFTimeInterval] = [:]
    private static var pendingActionStateWorkItems: [ControllerElement: DispatchWorkItem] = [:]
    private static var pendingClearHudWorkItem: DispatchWorkItem?
    private static var presentationSuspendedForTvOSSystemTextInput = false
    private static let minimumActionStateDuration: CFTimeInterval = 0.09
    private static let hudScale: CGFloat = PublicUtils.isIPhone ? 0.74 : (PublicUtils.isTVOS ? 1.3 : 1)
    private static let hudWidth: CGFloat = {
        return 235 * hudScale}()
    private static let edgeMargin: CGFloat = PublicUtils.isIPhone ? 5 : 24
    private var hints: [Hint] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        observeThemeChanges()
        updateTheme()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        observeThemeChanges()
        updateTheme()
    }

    deinit {
        NSLayoutConstraint.deactivate(windowConstraints)
        containerView.removeFromSuperview()
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        if let window {
            updateTrailingOffset(for: window)
        }
    }

    @discardableResult
    static func showInKeyWindow() -> GamepadNavigationIllustrationHud? {
        guard !presentationSuspendedForTvOSSystemTextInput,
              let window = keyWindow(),
              ControllerUtil.primaryGCController != nil else {
            return nil
        }
        
        let hud = currentHud ?? GamepadNavigationIllustrationHud()
        currentHud = hud
        hud.attach(to: window)
        
        if let mainFrameVC = ControllerNavigator.radialMenuDelegate as? MainFrameViewController, ControllerNavigator.radialMenuView == nil {
            DispatchQueue.main.asyncAfter(deadline: .now()+3) {
                let streamFrameVC = StreamFrameViewController.sharedInstance()
                if ControllerNavigator.radialMenuView == nil, mainFrameVC.isStreaming(), !mainFrameVC.settingsExpandedInStreamView, streamFrameVC?.hasNoPresentedVC == true, !ControllerNavigator.controllerMouseEnabled {
                    requestHudDetachKeepingMinimumActionDuration()
                }
            }
        }
        
        return hud
    }

    static func updateCurrentTheme() {
        currentHud?.updateTheme()
    }


    @objc static func updateNavigationElements(_ elements: [ControllerNavigationElement], forceDisplay: Bool = false) {
        guard !presentationSuspendedForTvOSSystemTextInput else { return }
        if !forceDisplay {
            guard ControllerNavigator.enabled, ControllerUtil.primaryGCController != nil else {return}
            guard !ControllerNavigator.stickReleasedInRadialMenu else {return}
        }
        PublicUtils.runOnMain {
            let hud = showInKeyWindow()
            hud?.updateHints(with: elements)
        }
    }
    
    @objc static func updateHud(forceDisplay: Bool = false) {
        let elements = ControllerNavigator.uiNavigationDelegate?.getNavigationElements() ?? []
        /*
        for element in elements {
            print("element \(element.action)")
        } */
        
        updateNavigationElements(elements, forceDisplay: forceDisplay)
    }

    static func updateActionState(for control: ControllerElement, isInAction: Bool) {
        PublicUtils.runOnMain {
            if isInAction {
                pendingClearHudWorkItem?.cancel()
                pendingClearHudWorkItem = nil
                pendingActionStateWorkItems[control]?.cancel()
                pendingActionStateWorkItems[control] = nil
                actionStateMinimumEndTimes[control] = CACurrentMediaTime() + minimumActionStateDuration

                let didChange = activeControls.insert(control).inserted
                guard didChange else { return }
                currentHud?.refreshActionStates()
            } else {
                requestActionStateEnd(for: control)
            }
        }
    }

    static func resetActionStates() {
        PublicUtils.runOnMain {
            guard !activeControls.isEmpty else { return }
            Array(activeControls).forEach { requestActionStateEnd(for: $0) }
        }
    }

    static func clearHud() {
        PublicUtils.runOnMain {
            if ControllerNavigator.controllerMouseEnabled {
                finishHudDetach()
                return
            }
            requestHudDetachKeepingMinimumActionDuration()
        }
    }

    @objc static func setTvOSSystemTextInputActive(_ active: Bool) {
#if os(tvOS)
        PublicUtils.runOnMain {
            presentationSuspendedForTvOSSystemTextInput = active
            if active {
                finishHudDetach()
            } else {
                updateHud()
            }
        }
#endif
    }
    
    func updateTheme() {
        let isDark = ThemeManager.userInterfaceStyle() == .dark

        backgroundColor = isDark
            ? UIColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 0.62)
            : (PublicUtils.isIPhone ? UIColor.white.withAlphaComponent(0.75) : UIColor.white.withAlphaComponent(0.6))
        layer.borderColor = (isDark ? UIColor.white.withAlphaComponent(0.10) : UIColor.black.withAlphaComponent(0.06)).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = isDark ? 0.34 : 0.12
        layer.shadowRadius = isDark ? 18 : 16
        layer.shadowOffset = CGSize(width: 0, height: 8)

        for (index, row) in contentStackView.arrangedSubviews.enumerated() {
            guard hints.indices.contains(index),
                  let rowStack = row as? UIStackView,
                  let keyView = rowStack.arrangedSubviews.first,
                  let titleView = rowStack.arrangedSubviews.last else {
                continue
            }

            let isInAction = hints[index].isInAction
            let keyBorderView = keyView.viewWithTag(Self.keyBorderViewTag) ?? keyView
            let keyContentView = keyView.viewWithTag(Self.keyContentViewTag) ?? keyView
            let keyBackgroundColor = isInAction
                ? ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.2 : 0.13)
                : ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.09 : 0.05)
            keyView.backgroundColor = .clear
            keyBorderView.layer.borderColor = ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.69 : 0.6).cgColor
            keyContentView.backgroundColor = keyBackgroundColor
            keyView.transform = .identity
            for subview in keyContentView.subviews {
                if let keyLabel = subview as? UILabel {
                    keyLabel.textColor = isInAction ? ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 1 : 1) : ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.83 : 0.83)
                } else if let imageView = subview as? UIImageView {
                    imageView.tintColor = isInAction ? ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 1 : 1) : ThemeManager.appPrimaryColor.withAlphaComponent(isDark ? 0.83 : 0.83)
                }
            }
            updateTitleColors(in: titleView, color: ThemeManager.textColor.withAlphaComponent(isDark ? 0.69 : 0.6))
        }
    }

    private func setupView() {
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isUserInteractionEnabled = false
        // transform = CGAffineTransform(scaleX: Self.hudScale, y: Self.hudScale)
        layer.cornerRadius = 18 * GamepadNavigationIllustrationHud.hudScale
        layer.cornerCurve = .continuous
        layer.borderWidth = 1 * GamepadNavigationIllustrationHud.hudScale

        contentStackView.axis = .vertical
        contentStackView.alignment = .leading
        contentStackView.spacing = 6 * GamepadNavigationIllustrationHud.hudScale
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12 * GamepadNavigationIllustrationHud.hudScale),
            contentStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12 * GamepadNavigationIllustrationHud.hudScale),
            contentStackView.topAnchor.constraint(equalTo: topAnchor, constant: 10 * GamepadNavigationIllustrationHud.hudScale),
            contentStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10 * GamepadNavigationIllustrationHud.hudScale)
        ])

        reloadHintRows()
    }

    private func updateHints(with elements: [ControllerNavigationElement]) {
        let nextHints = hints(for: elements)
        hints = nextHints.isEmpty ? [] : nextHints
        guard !hints.isEmpty else {return}
        reloadHintRows()
        updateTheme()
        isHidden = hints.isEmpty
    }

    private func refreshActionStates() {
        hints = hints.map { hint in
            Hint(
                control: hint.control,
                keyContent: hint.keyContent,
                titles: hint.titles,
                isInAction: Self.isControlActive(hint.control)
            )
        }
        updateTheme()
    }

    private func reloadHintRows() {
        contentStackView.arrangedSubviews.forEach { row in
            contentStackView.removeArrangedSubview(row)
            row.removeFromSuperview()
        }

        hints.forEach { contentStackView.addArrangedSubview(makeRow(for: $0)) }
    }

    private func hints(for navigationElements: [ControllerNavigationElement]) -> [Hint] {
        var groupedElements: [ControllerElement: [ControllerNavigationElement]] = [:]
        var orderedControls: [ControllerElement] = []

        for navigationElement in navigationElements {
            if groupedElements[navigationElement.control] == nil {
                orderedControls.append(navigationElement.control)
                groupedElements[navigationElement.control] = []
            }
            groupedElements[navigationElement.control]?.append(navigationElement)
        }

        return orderedControls.flatMap { control -> [Hint] in
            guard let elements = groupedElements[control] else { return [] }
            if elements.count == 2 {
                return [hint(for: elements)]
            }

            return elements.map { hint(for: [$0]) }
        }
    }

    private func hint(for navigationElements: [ControllerNavigationElement]) -> Hint {
        let control = navigationElements.first?.control ?? .null
        return Hint(
            control: control,
            keyContent: keyContent(for: control),
            titles: navigationElements.map { $0.action.localized },
            isInAction: navigationElements.contains(where: { $0.isInAction }) || Self.isControlActive(control)
        )
    }

    private func keyContent(for control: ControllerElement) -> KeyContent {
        let symbol = control.symbol
        return symbol.isEmpty ? .text(control.displayName) : .symbol(symbol)
    }

    private func attach(to window: UIWindow) {
        if containerView.superview !== window {
            NSLayoutConstraint.deactivate(windowConstraints)
            windowConstraints.removeAll()
            removeFromSuperview()
            containerView.removeFromSuperview()
            window.addSubview(containerView)
            containerView.addSubview(self)

            let trailingConstraint = containerView.trailingAnchor.constraint(equalTo: window.safeAreaLayoutGuide.trailingAnchor)
            self.trailingConstraint = trailingConstraint
            windowConstraints = [
                containerView.widthAnchor.constraint(equalToConstant: Self.hudWidth * 1),
                containerView.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 1),
                trailingConstraint,
                containerView.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -Self.edgeMargin),

                widthAnchor.constraint(equalToConstant: Self.hudWidth),
                centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
            ]
            NSLayoutConstraint.activate(windowConstraints)
        }

        updateTrailingOffset(for: window)
        window.bringSubviewToFront(containerView)
    }

    private func detachFromWindow() {
        NSLayoutConstraint.deactivate(windowConstraints)
        windowConstraints.removeAll()
        trailingConstraint = nil
        removeFromSuperview()
        containerView.removeFromSuperview()
    }

    private func updateTrailingOffset(for window: UIWindow) {
        let horizontalMargin = Self.edgeMargin + (PublicUtils.isIPhone ? 0 : window.safeAreaInsets.bottom)
        trailingConstraint?.constant = -horizontalMargin
    }

    private func makeRow(for hint: Hint) -> UIStackView {
        let keyView = makeKeyView(for: hint.keyContent)
        let titleView = makeTitleView(for: hint.titles)

        let rowStackView = UIStackView(arrangedSubviews: [keyView, titleView])
        rowStackView.axis = .horizontal
        rowStackView.alignment = .center
        rowStackView.spacing = 8 * GamepadNavigationIllustrationHud.hudScale
        return rowStackView
    }

    private func makeTitleView(for titles: [String]) -> UIView {
        if titles.count == 2 {
            let stackView = UIStackView(arrangedSubviews: titles.map { makeTitleLabel(text: $0, isMergedTitle: true) })
            stackView.axis = .vertical
            stackView.alignment = .leading
            stackView.spacing = 1 * GamepadNavigationIllustrationHud.hudScale
            stackView.setContentCompressionResistancePriority(.required, for: .horizontal)
            return stackView
        }

        return makeTitleLabel(text: titles.first ?? "", isMergedTitle: false)
    }

    private func makeTitleLabel(text: String, isMergedTitle: Bool) -> UILabel {
        let titleLabel = UILabel()
        titleLabel.text = text
        titleLabel.font = UIFont.roundedSystemFont(ofSize: (isMergedTitle ? 12.5 : 14) * GamepadNavigationIllustrationHud.hudScale, weight: .medium)
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = isMergedTitle ? 0.55 : 0.2
        titleLabel.numberOfLines = 1
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        return titleLabel
    }

    private func updateTitleColors(in view: UIView, color: UIColor) {
        if let label = view as? UILabel {
            label.textColor = color
            return
        }

        view.subviews.forEach { updateTitleColors(in: $0, color: color) }
    }

    private func makeKeyView(for content: KeyContent) -> UIView {
        let keyContainerView = UIView()
        keyContainerView.translatesAutoresizingMaskIntoConstraints = false
        keyContainerView.backgroundColor = .clear

        NSLayoutConstraint.activate([
            keyContainerView.widthAnchor.constraint(equalToConstant: 50 * GamepadNavigationIllustrationHud.hudScale),
            keyContainerView.heightAnchor.constraint(equalToConstant: (PublicUtils.isIPhone ? 38 : 42) * GamepadNavigationIllustrationHud.hudScale)
        ])

        let borderView = UIView()
        borderView.tag = Self.keyBorderViewTag
        borderView.translatesAutoresizingMaskIntoConstraints = false
        borderView.isUserInteractionEnabled = false
        borderView.backgroundColor = .clear
        borderView.layer.cornerRadius = 13 * GamepadNavigationIllustrationHud.hudScale
        borderView.layer.cornerCurve = .continuous
        borderView.layer.borderWidth = 1 * GamepadNavigationIllustrationHud.hudScale
        borderView.layer.masksToBounds = true
        keyContainerView.addSubview(borderView)

        let keyView = UIView()
        keyView.tag = Self.keyContentViewTag
        keyView.translatesAutoresizingMaskIntoConstraints = false
        keyView.layer.cornerRadius = 12 * GamepadNavigationIllustrationHud.hudScale
        keyView.layer.cornerCurve = .continuous
        keyView.layer.masksToBounds = true
        keyContainerView.addSubview(keyView)

        NSLayoutConstraint.activate([
            borderView.leadingAnchor.constraint(equalTo: keyContainerView.leadingAnchor),
            borderView.trailingAnchor.constraint(equalTo: keyContainerView.trailingAnchor),
            borderView.topAnchor.constraint(equalTo: keyContainerView.topAnchor),
            borderView.bottomAnchor.constraint(equalTo: keyContainerView.bottomAnchor),

            keyView.leadingAnchor.constraint(equalTo: keyContainerView.leadingAnchor, constant: 1),
            keyView.trailingAnchor.constraint(equalTo: keyContainerView.trailingAnchor, constant: -1),
            keyView.topAnchor.constraint(equalTo: keyContainerView.topAnchor, constant: 1),
            keyView.bottomAnchor.constraint(equalTo: keyContainerView.bottomAnchor, constant: -1)
        ])

        switch content {
        case .text(let text):
            let keyLabel = InsetLabel()
            keyLabel.contentInsets = UIEdgeInsets(top: 0, left: 6*GamepadNavigationIllustrationHud.hudScale, bottom: 0, right: 6*GamepadNavigationIllustrationHud.hudScale)
            keyLabel.translatesAutoresizingMaskIntoConstraints = false
            keyLabel.text = text
            keyLabel.textAlignment = .center
            keyLabel.font = UIFont.roundedSystemFont(ofSize: 12 * GamepadNavigationIllustrationHud.hudScale, weight: PublicUtils.isIPhone ? .semibold : .medium)
            keyLabel.adjustsFontSizeToFitWidth = true
            keyLabel.minimumScaleFactor = 0.2
            keyLabel.numberOfLines = 1
            keyLabel.lineBreakMode = .byClipping
            keyView.addSubview(keyLabel)
            NSLayoutConstraint.activate([
                keyLabel.leadingAnchor.constraint(equalTo: keyView.leadingAnchor),
                keyLabel.trailingAnchor.constraint(equalTo: keyView.trailingAnchor),
                keyLabel.topAnchor.constraint(equalTo: keyView.topAnchor),
                keyLabel.bottomAnchor.constraint(equalTo: keyView.bottomAnchor)
            ])
        case .symbol(let symbolName):
            let imageView = UIImageView(image: UIImage(systemName: symbolName))
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.contentMode = .scaleAspectFit
            imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18 * GamepadNavigationIllustrationHud.hudScale, weight: .medium)
            keyView.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: keyView.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: keyView.centerYAnchor),
                imageView.widthAnchor.constraint(lessThanOrEqualTo: keyView.widthAnchor, multiplier: 0.58),
                imageView.heightAnchor.constraint(lessThanOrEqualTo: keyView.heightAnchor, multiplier: 0.58)
            ])
        }

        return keyContainerView
    }

    private func observeThemeChanges() {
        themeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(ThemeManager.ThemeDidChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTheme()
        }
    }

    private static func keyWindow() -> UIWindow? {
            let sceneWindows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
            return sceneWindows.first(where: { $0.isKeyWindow })
                ?? sceneWindows.first
                ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })
                ?? UIApplication.shared.windows.first
    }

    private static func isControlActive(_ control: ControllerElement) -> Bool {
        !activeControls(forHintControl: control).isDisjoint(with: activeControls)
    }

    private static func requestActionStateEnd(for control: ControllerElement) {
        pendingActionStateWorkItems[control]?.cancel()

        let now = CACurrentMediaTime()
        let remainingDuration = max((actionStateMinimumEndTimes[control] ?? now) - now, 0)
        guard remainingDuration > 0 else {
            finishActionStateEnd(for: control)
            return
        }

        let workItem = DispatchWorkItem {
            finishActionStateEnd(for: control)
        }
        pendingActionStateWorkItems[control] = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDuration, execute: workItem)
    }

    private static func finishActionStateEnd(for control: ControllerElement) {
        pendingActionStateWorkItems[control]?.cancel()
        pendingActionStateWorkItems[control] = nil
        actionStateMinimumEndTimes[control] = nil

        guard activeControls.remove(control) != nil else { return }
        currentHud?.refreshActionStates()
    }

    private static func requestHudDetachKeepingMinimumActionDuration() {
        pendingClearHudWorkItem?.cancel()

        let remainingDuration = maximumRemainingActionStateDuration()
        guard remainingDuration > 0 else {
            finishHudDetach()
            return
        }

        let workItem = DispatchWorkItem {
            finishHudDetach()
        }
        pendingClearHudWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + remainingDuration, execute: workItem)
    }

    static func finishHudDetach() {
        pendingClearHudWorkItem?.cancel()
        pendingClearHudWorkItem = nil
        pendingActionStateWorkItems.values.forEach { $0.cancel() }
        pendingActionStateWorkItems.removeAll()
        actionStateMinimumEndTimes.removeAll()
        activeControls.removeAll()
        currentHud?.detachFromWindow()
        currentHud = nil
    }

    private static func maximumRemainingActionStateDuration() -> CFTimeInterval {
        let now = CACurrentMediaTime()
        return activeControls.reduce(0) { partialResult, control in
            max(partialResult, max((actionStateMinimumEndTimes[control] ?? now) - now, 0))
        }
    }

    private static func activeControls(forHintControl control: ControllerElement) -> Set<ControllerElement> {
        switch control {
        case .leftStick, .leftStickX, .leftStickY:
            return [.leftStick, .leftStickX, .leftStickY]
        case .rightStick, .rightStickX, .rightStickY:
            return [.rightStick, .rightStickX, .rightStickY]
        case .dpad:
            return [.dpad, .dpadUp, .dpadDown, .dpadLeft, .dpadRight]
        case .abxy:
            return [.abxy, .a, .b, .x, .y]
        default:
            return [control]
        }
    }
}

final class InsetLabel: UILabel {
    var contentInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: 4)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }
}
