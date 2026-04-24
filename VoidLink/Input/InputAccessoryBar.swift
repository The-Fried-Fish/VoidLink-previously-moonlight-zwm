//
//  InputAccessoryBar.swift
//  VoidLink
//
//  Created by True砖家 on 2026/4/24
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//

import UIKit
import CoreData

@available(iOS 13.0, *)
@objc
protocol InputAccessoryBarDelegate: AnyObject {
    @objc func inputAccessoryBarDidTapClose(_ bar: InputAccessoryBar)
    // @objc func inputAccessoryBarDidTapAdd(_ bar: InputAccessoryBar)
    // @objc(inputAccessoryBar:didTapItemAtIndex:)
    // optional func inputAccessoryBar(_ bar: InputAccessoryBar, didTapItemAt index: Int)
}

private enum InputAccessoryBarMetrics {
    static let barHeight: CGFloat = 50
    static let horizontalInset: CGFloat = 12
    static let safeAreaExtraInset: CGFloat = 0
    static let interSectionSpacing: CGFloat = 10
    static let itemSpacing: CGFloat = GenericUtils.isIPhone() ? 5 : 9
    static let edgeFadeWidth: CGFloat = 14
    static let sideButtonSize: CGFloat = GenericUtils.isIPhone() ? 38 : 46
    static let pillHeight: CGFloat = GenericUtils.isIPhone() ? 38 : 46
    static let pillHorizontalPadding: CGFloat = 10
    static let pillMinWidth: CGFloat = GenericUtils.isIPhone() ? 38 : 46
    static let borderWidth: CGFloat = 1
    static let highlightedBorderWidth: CGFloat = 1.6
    static let highlightedScale: CGFloat = 0.86
    static let highlightedTranslationY: CGFloat = 0
    static let shadowRadius: CGFloat = 4
    static let shadowYOffset: CGFloat = 2
    static let highlightedShadowRadius: CGFloat = 2.5
    static let highlightedShadowYOffset: CGFloat = 1
    static let pressInDuration: TimeInterval = 0.075
    static let releaseDuration: TimeInterval = 0.18
    static let reorderAnimationDuration: TimeInterval = 0.2
    static let deleteButtonSize: CGFloat = 22
    static let dragScale: CGFloat = 1.06
    static let dragLiftY: CGFloat = -2
    static let editOverlayDimAlpha: CGFloat = 0.001
    static let edgeAutoScrollTriggerInset: CGFloat = 28
    static let edgeAutoScrollStep: CGFloat = 6
}

@available(iOS 13.0, *)
private struct InputAccessoryBarButtonRecord {
    let buttonLabel: String
    let cmdString: String

    var isTapToToggle: Bool {
        cmdString.uppercased().contains("NULL")
    }

    var displayTitle: String {
        buttonLabel.isEmpty ? cmdString : buttonLabel
    }
}

@available(iOS 13.0, *)
private final class InputAccessoryCapsuleButton: UIButton {
    enum Kind {
        case circular(symbolName: String)
        case text(title: String)
    }

    var isPersistentSelection: Bool = false {
        didSet { updateAppearance(animated: false) }
    }

    var isTapToToggleMode: Bool = false {
        didSet {
            if !isTapToToggleMode {
                isToggleLockedDown = false
            }
            updateAppearance(animated: false)
        }
    }

    var cmdString: String = ""

    weak var pressTransformTargetView: UIView?

    private let kind: Kind
    var isPressVisualActive = false
    var isLogicallyPressed = false
    private var isToggleLockedDown = false
    private var shouldReleaseAfterPressIn = false
    private var isPressInAnimationRunning = false
    private var activeAnimator: UIViewPropertyAnimator?

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        adjustsImageWhenHighlighted = false
        titleLabel?.font = UIFont.systemFont(ofSize: 13.5, weight: .semibold)
        titleLabel?.lineBreakMode = .byTruncatingTail
        layer.borderWidth = InputAccessoryBarMetrics.borderWidth
        layer.shadowOpacity = 1
        layer.shadowRadius = InputAccessoryBarMetrics.shadowRadius
        layer.shadowOffset = CGSize(width: 0, height: InputAccessoryBarMetrics.shadowYOffset)
        layer.masksToBounds = false

        switch kind {
        case let .circular(symbolName):
            let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            setImage(UIImage(systemName: symbolName, withConfiguration: configuration), for: .normal)
        case let .text(title):
            setTitle(title, for: .normal)
            contentEdgeInsets = UIEdgeInsets(
                top: 0,
                left: InputAccessoryBarMetrics.pillHorizontalPadding,
                bottom: 0,
                right: InputAccessoryBarMetrics.pillHorizontalPadding
            )
        }

        updateAppearance(animated: false)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        let shouldTrack = super.beginTracking(touch, with: event)
        guard shouldTrack else { return false }
        beginPressSequence()
        return true
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        super.endTracking(touch, with: event)
        completePressSequence()
    }

    override func cancelTracking(with event: UIEvent?) {
        super.cancelTracking(with: event)
        completePressSequence()
    }

    override var isSelected: Bool {
        didSet { updateAppearance(animated: false) }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height * 0.5
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.hasDifferentColorAppearance(comparedTo: traitCollection) == true else {
            return
        }
        updateAppearance(animated: false)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        switch kind {
        case .circular:
            return CGSize(width: InputAccessoryBarMetrics.sideButtonSize, height: InputAccessoryBarMetrics.sideButtonSize)
        case .text:
            let labelSize = super.sizeThatFits(size)
            return CGSize(
                width: max(InputAccessoryBarMetrics.pillMinWidth, labelSize.width),
                height: InputAccessoryBarMetrics.pillHeight
            )
        }
    }

    private func updateAppearance(animated: Bool) {
        let active = isSelected || isPersistentSelection
        let highlighted = isTapToToggleMode ? isToggleLockedDown : isPressVisualActive

        let backgroundColor = active ? Self.selectedBackgroundColor : (highlighted ? Self.highlightedBackgroundColor : Self.normalBackgroundColor)
        let foregroundColor = active ? Self.selectedForegroundColor : Self.normalForegroundColor
        let borderColor = (active ? Self.selectedBorderColor : (highlighted ? Self.highlightedBorderColor : Self.normalBorderColor)).cgColor
        let borderWidth = highlighted ? InputAccessoryBarMetrics.highlightedBorderWidth : InputAccessoryBarMetrics.borderWidth
        let shadowRadius = highlighted ? InputAccessoryBarMetrics.highlightedShadowRadius : InputAccessoryBarMetrics.shadowRadius
        let shadowOffset = CGSize(
            width: 0,
            height: highlighted ? InputAccessoryBarMetrics.highlightedShadowYOffset : InputAccessoryBarMetrics.shadowYOffset
        )
        let targetTransform = highlighted
        ? CGAffineTransform(translationX: 0, y: InputAccessoryBarMetrics.highlightedTranslationY)
            .scaledBy(x: InputAccessoryBarMetrics.highlightedScale, y: InputAccessoryBarMetrics.highlightedScale)
        : .identity
        let transformTargetView = pressTransformTargetView ?? self

        let applyChanges = {
            self.backgroundColor = backgroundColor
            self.tintColor = foregroundColor
            self.setTitleColor(foregroundColor, for: .normal)
            self.layer.borderColor = borderColor
            self.layer.shadowColor = Self.shadowColor.cgColor
            self.layer.borderWidth = borderWidth
            self.layer.shadowRadius = shadowRadius
            self.layer.shadowOffset = shadowOffset
        }

        guard animated, window != nil else {
            activeAnimator?.stopAnimation(true)
            activeAnimator = nil
            applyChanges()
            transformTargetView.transform = targetTransform
            return
        }

        let duration = highlighted ? InputAccessoryBarMetrics.pressInDuration : InputAccessoryBarMetrics.releaseDuration
        activeAnimator?.stopAnimation(true)
        if highlighted {
            UIView.animate(
                withDuration: duration * 0.55,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]
            ) {
                transformTargetView.transform = targetTransform
            }
        } else {
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: [.beginFromCurrentState, .curveEaseOut, .allowUserInteraction]
            ) {
                transformTargetView.transform = targetTransform
            }
        }
        let animator = UIViewPropertyAnimator(
            duration: highlighted ? duration * 0.72 : duration,
            dampingRatio: highlighted ? 1.0 : 0.72,
            animations: applyChanges
        )
        animator.isInterruptible = true
        animator.addCompletion { [weak self] _ in
            guard let self else { return }
            if highlighted {
                self.isPressInAnimationRunning = false
                if self.shouldReleaseAfterPressIn {
                    self.shouldReleaseAfterPressIn = false
                    self.animateReleaseIfNeeded()
                }
            }
            if self.activeAnimator === animator {
                self.activeAnimator = nil
            }
        }
        if highlighted {
            animator.startAnimation(afterDelay: duration * 0.28)
        } else {
            animator.startAnimation()
        }
        activeAnimator = animator
    }

    private func beginPressSequence() {
        if (InputAccessoryBar.isFirstTap && GenericUtils.isFirstTappingInputAccessoryBar()) {
            InputAccessoryBar.isFirstTap = false
            AlertControllerUtil.showAlert(
                in: self.parentViewController!,
                title: SwiftLocalizationHelper.localizedString(forKey: "Soft Keyboard Toolbar"),
                message: SwiftLocalizationHelper.localizedString(forKey:"inputAccessoryBarTip"),
                withCancel: false,
                buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "Got it!"),
                countdown: 6,
                completion: {
                })
            return
        }
        
        isLogicallyPressed = isTapToToggleMode ? !isLogicallyPressed : true
        if isTapToToggleMode {
            activeAnimator?.stopAnimation(true)
            activeAnimator = nil
            isPressInAnimationRunning = false
            shouldReleaseAfterPressIn = false
            isToggleLockedDown.toggle()
            updateAppearance(animated: true)
            return
        }
        shouldReleaseAfterPressIn = false
        isPressVisualActive = true
        isPressInAnimationRunning = true
        updateAppearance(animated: true)
    }

    private func completePressSequence() {
        
        let comboButtons = CommandManager.shared.extractAutoReleaseButtonStrings(from: self.cmdString)
        
        if isTapToToggleMode {
            if isLogicallyPressed {
                if !InputAccessoryBar.isEditingItems {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: comboButtons,pressOnly: true)}
            }
            else {
                CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: comboButtons, releaseOnly: true)
            }
            return
        }
        else {
            isLogicallyPressed = false
            if !InputAccessoryBar.isEditingItems {CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: comboButtons)}
        }
        
        guard isPressVisualActive || isPressInAnimationRunning else { return }
        if isPressInAnimationRunning {
            shouldReleaseAfterPressIn = true
        } else {
            animateReleaseIfNeeded()
        }
    }

    private func animateReleaseIfNeeded() {
        isPressVisualActive = false
        updateAppearance(animated: true)
    }

    private static var normalBackgroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.22, alpha: 0.82)
            : UIColor.white.withAlphaComponent(0.78)
        }
    }

    private static var highlightedBackgroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.3, alpha: 0.92)
            : UIColor.white.withAlphaComponent(1.0)
        }
    }

    private static var selectedBackgroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.systemBlue.withAlphaComponent(0.3)
            : UIColor.systemBlue.withAlphaComponent(0.16)
        }
    }

    private static var normalBorderColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.18)
            : UIColor.white.withAlphaComponent(0.78)
        }
    }

    private static var highlightedBorderColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.28)
            : UIColor.white.withAlphaComponent(1.0)
        }
    }

    private static var selectedBorderColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.systemBlue.withAlphaComponent(0.75)
            : UIColor.systemBlue.withAlphaComponent(0.55)
        }
    }

    private static var normalForegroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.92)
            : UIColor.black.withAlphaComponent(0.66)
        }
    }

    private static var selectedForegroundColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.98)
            : UIColor.systemBlue.withAlphaComponent(0.92)
        }
    }

    private static var shadowColor: UIColor {
        UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
            ? UIColor.black.withAlphaComponent(0.34)
            : UIColor.black.withAlphaComponent(0.08)
        }
    }
}

@available(iOS 13.0, *)
private final class InputAccessoryBarItemView: UIView {
    let button: InputAccessoryCapsuleButton
    let deleteButton = UIButton(type: .system)
    var deleteHandler: (() -> Void)?

    init(title: String) {
        button = InputAccessoryCapsuleButton(kind: .text(title: title))
        super.init(frame: .zero)
        clipsToBounds = false
        button.pressTransformTargetView = self

        deleteButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        deleteButton.tintColor = .systemRed
        deleteButton.backgroundColor = .clear
        deleteButton.alpha = 0
        deleteButton.isHidden = true
        deleteButton.addTarget(self, action: #selector(handleDeleteTap), for: .touchUpInside)

        addSubview(button)
        addSubview(deleteButton)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        button.frame = CGRect(x: 0, y: 0, width: bounds.width, height: InputAccessoryBarMetrics.pillHeight)
        deleteButton.frame = CGRect(
            x: bounds.width - InputAccessoryBarMetrics.deleteButtonSize + 2,
            y: -8,
            width: InputAccessoryBarMetrics.deleteButtonSize,
            height: InputAccessoryBarMetrics.deleteButtonSize
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let buttonSize = button.sizeThatFits(size)
        return CGSize(width: buttonSize.width, height: InputAccessoryBarMetrics.pillHeight)
    }

    override var intrinsicContentSize: CGSize {
        sizeThatFits(CGSize(width: UIView.noIntrinsicMetric, height: InputAccessoryBarMetrics.pillHeight))
    }

    func setEditing(_ isEditing: Bool, animated: Bool) {
        button.isUserInteractionEnabled = !isEditing
        let changes = {
            self.deleteButton.isHidden = false
            self.deleteButton.alpha = isEditing ? 1 : 0
        }

        guard animated, window != nil else {
            changes()
            deleteButton.isHidden = !isEditing
            return
        }

        if isEditing {
            deleteButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
                changes()
                self.deleteButton.transform = .identity
            }
        } else {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseIn]) {
                self.deleteButton.alpha = 0
                self.deleteButton.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            } completion: { _ in
                self.deleteButton.transform = .identity
                self.deleteButton.isHidden = true
            }
        }
    }

    @objc private func handleDeleteTap() {
        deleteHandler?()
    }
}

@available(iOS 13.0, *)
@objc
final class InputAccessoryBar: UIView, UIScrollViewDelegate, WidgetPickerViewControllerDelegate {
    private static weak var detachedOverlayBar: InputAccessoryBar?
    static var isFirstTap = true
    
    @objc weak var delegate: InputAccessoryBarDelegate?

    private let closeButton = InputAccessoryCapsuleButton(kind: .circular(symbolName: "xmark"))
    private let addButton = InputAccessoryCapsuleButton(kind: .circular(symbolName: "plus"))
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let scrollMaskLayer = CAGradientLayer()
    private var itemViews: [InputAccessoryBarItemView] = []
    private var selectedIndexes = IndexSet()
    private weak var mirroredBar: InputAccessoryBar?
    private var isDetachedOverlayBar = false
    private var buttonRecords: [InputAccessoryBarButtonRecord] = []
    static var isEditingItems = false
    private weak var outsideTapShield: UIControl?
    private weak var draggedItemView: InputAccessoryBarItemView?
    private weak var armedItemView: InputAccessoryBarItemView?
    private weak var dragSnapshotView: UIView?
    private var dragTouchOffsetX: CGFloat = 0
    private lazy var dragPanGestureRecognizer: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragPan(_:)))
        gesture.isEnabled = false
        return gesture
    }()

    @objc var itemTitles: [String] = [] {
        didSet { rebuildItemButtons() }
    }

    @objc override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
        loadPersistedButtons()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
        loadPersistedButtons()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, !isDetachedOverlayBar {
            Self.dismissDetachedOverlayBarIfNeeded()
        }
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: InputAccessoryBarMetrics.barHeight)
    }

    @objc(setItemsWithTitles:)
    func setItems(titles: [String]) {
        itemTitles = titles
    }

    @objc(setSelectedItemIndexes:)
    func setSelectedItemIndexes(_ indexes: NSIndexSet) {
        selectedIndexes = indexes as IndexSet
        syncSelectionState()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let boundsHeight = bounds.height > 0 ? bounds.height : InputAccessoryBarMetrics.barHeight
        let sideSize = InputAccessoryBarMetrics.sideButtonSize
        let sideY = round((boundsHeight - sideSize) * 0.5)
        let leadingInset = max(
            InputAccessoryBarMetrics.horizontalInset,
            safeAreaInsets.left + InputAccessoryBarMetrics.safeAreaExtraInset
        )
        let trailingInset = max(
            InputAccessoryBarMetrics.horizontalInset,
            safeAreaInsets.right + InputAccessoryBarMetrics.safeAreaExtraInset
        )
        let closeX = leadingInset

        closeButton.frame = CGRect(x: closeX, y: sideY, width: sideSize, height: sideSize)

        let contentStartX = closeButton.frame.maxX + InputAccessoryBarMetrics.interSectionSpacing
        let maxAddX = bounds.width - trailingInset - sideSize
        let contentWidth = measuredStackWidth()
        let idealAddX = contentStartX + contentWidth + InputAccessoryBarMetrics.interSectionSpacing
        let addX = min(maxAddX, idealAddX)
        addButton.frame = CGRect(x: addX, y: sideY, width: sideSize, height: sideSize)

        let scrollWidth = max(0, addButton.frame.minX - InputAccessoryBarMetrics.interSectionSpacing - contentStartX)
        scrollView.frame = CGRect(x: contentStartX, y: 0, width: scrollWidth, height: boundsHeight)
        stackView.frame = CGRect(
            x: 0,
            y: round((boundsHeight - InputAccessoryBarMetrics.pillHeight) * 0.5),
            width: contentWidth,
            height: InputAccessoryBarMetrics.pillHeight
        )
        scrollView.contentSize = CGSize(width: max(contentWidth, scrollWidth), height: boundsHeight)
        updateScrollMask()
    }

    private func setupView() {
        backgroundColor = .clear
        autoresizingMask = [.flexibleWidth]

        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = !InputAccessoryBar.isEditingItems
        if #available(iOS 13.4, *) {
            scrollView.automaticallyAdjustsScrollIndicatorInsets = false
        }
        scrollView.delegate = self
        scrollMaskLayer.startPoint = CGPoint(x: 0, y: 0.5)
        scrollMaskLayer.endPoint = CGPoint(x: 1, y: 0.5)
        scrollView.layer.mask = InputAccessoryBar.isEditingItems ? nil : scrollMaskLayer

        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.spacing = InputAccessoryBarMetrics.itemSpacing

        closeButton.addTarget(self, action: #selector(handleCloseTap), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(handleAddTap), for: .touchUpInside)

        addSubview(closeButton)
        addSubview(scrollView)
        addSubview(addButton)
        scrollView.addSubview(stackView)
        scrollView.addGestureRecognizer(dragPanGestureRecognizer)
    }

    private func rebuildItemButtons() {
        itemViews.forEach { itemView in
            stackView.removeArrangedSubview(itemView)
            itemView.removeFromSuperview()
        }
        itemViews.removeAll()

        for (index, title) in itemTitles.enumerated() {
            let itemView = InputAccessoryBarItemView(title: title)
            itemView.tag = index
            itemView.button.tag = index
            if buttonRecords.indices.contains(index) {
                itemView.button.cmdString = buttonRecords[index].cmdString
                itemView.button.isTapToToggleMode = buttonRecords[index].isTapToToggle
            } else {
                itemView.button.cmdString = ""
                itemView.button.isTapToToggleMode = false
            }
            itemView.button.addTarget(self, action: #selector(handleItemTap(_:)), for: .touchUpInside)
            itemView.deleteHandler = { [weak self, weak itemView] in
                guard let self, let itemView else { return }
                self.handleDeleteTap(for: itemView)
            }

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleItemLongPress(_:)))
            longPress.minimumPressDuration = 1
            longPress.cancelsTouchesInView = false
            longPress.delaysTouchesBegan = false
            longPress.delaysTouchesEnded = false
            itemView.addGestureRecognizer(longPress)

            stackView.addArrangedSubview(itemView)
            itemViews.append(itemView)
        }

        syncSelectionState()
        setNeedsLayout()
    }

    private func syncSelectionState() {
        for itemView in itemViews {
            itemView.button.isSelected = selectedIndexes.contains(itemView.button.tag)
            itemView.setEditing(InputAccessoryBar.isEditingItems, animated: false)
        }
    }

    private func measuredStackWidth() -> CGFloat {
        itemViews.enumerated().reduce(0) { partialResult, pair in
            let buttonWidth = pair.element.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: InputAccessoryBarMetrics.pillHeight)).width
            let spacing = pair.offset == 0 ? CGFloat(0) : InputAccessoryBarMetrics.itemSpacing
            return partialResult + spacing + buttonWidth
        }
    }

    private func updateScrollMask() {
        if InputAccessoryBar.isEditingItems {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            scrollView.clipsToBounds = false
            scrollView.layer.mask = nil
            CATransaction.commit()
            return
        }

        let bounds = scrollView.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            scrollView.clipsToBounds = true
            scrollView.layer.mask = scrollMaskLayer
            scrollMaskLayer.frame = .zero
            CATransaction.commit()
            return
        }

        let contentWidth = scrollView.contentSize.width
        let visibleWidth = bounds.width
        let offsetX = scrollView.contentOffset.x
        let hasLeftOverflow = offsetX > 0.5
        let hasRightOverflow = offsetX + visibleWidth < contentWidth - 0.5
        let fadeWidth = min(InputAccessoryBarMetrics.edgeFadeWidth, bounds.width * 0.5)
        let fadeFraction = max(0, min(0.5, fadeWidth / bounds.width))

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrollView.clipsToBounds = true
        scrollView.layer.mask = scrollMaskLayer
        scrollMaskLayer.frame = bounds
        if hasLeftOverflow && hasRightOverflow {
            scrollMaskLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.clear.cgColor,
            ]
            scrollMaskLayer.locations = [
                0,
                NSNumber(value: Double(fadeFraction)),
                NSNumber(value: Double(1 - fadeFraction)),
                1,
            ]
        }
        else if hasLeftOverflow {
            scrollMaskLayer.colors = [
                UIColor.clear.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
            ]
            scrollMaskLayer.locations = [
                0,
                NSNumber(value: Double(fadeFraction)),
                1,
                1,
            ]
        }
        else if hasRightOverflow {
            scrollMaskLayer.colors = [
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.black.cgColor,
                UIColor.clear.cgColor,
            ]
            scrollMaskLayer.locations = [
                0,
                0,
                NSNumber(value: Double(1 - fadeFraction)),
                1,
            ]
        }
        else {
            scrollMaskLayer.colors = [
                UIColor.black.cgColor,
                UIColor.black.cgColor,
            ]
            scrollMaskLayer.locations = [
                0,
                1,
            ]
        }
        CATransaction.commit()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateScrollMask()
    }

    @objc func releasePressedKeys() {
        for item in itemViews {
            if item.button.isTapToToggleMode, item.button.isLogicallyPressed {
                let comboButtons = CommandManager.shared.extractAutoReleaseButtonStrings(from: item.button.cmdString)
                CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: comboButtons, releaseOnly: true)
            }
        }
    }
    
    @objc private func handleCloseTap() {
        self.releasePressedKeys()
        
        if InputAccessoryBar.isEditingItems {
            endEditingMode(saveChanges: true)
        }
        if isDetachedOverlayBar {
            Self.dismissDetachedOverlayBarIfNeeded()
            return
        }
        delegate?.inputAccessoryBarDidTapClose(self)
    }

    @objc private func handleAddTap() {
        endEditingMode(saveChanges: true)
        guard let parentViewController = self.parentViewController else {
            return
        }

        let payloadTargetBar = Self.presentDetachedOverlayBarCopy(from: self, in: parentViewController) ?? self

        let pickerViewController = WidgetPickerViewController()
        pickerViewController.delegate = payloadTargetBar
        pickerViewController.keyboardPickerMode = .shortcutPicker
        pickerViewController.shortcutPickerNeedAlias = true
        pickerViewController.shortcutPickerNeedButtonMode = true
        pickerViewController.tabIdentifiers = ["keyboard"]
        pickerViewController.initialTabIdentifier = "keyboard"

        parentViewController.view.endEditing(true)
        pickerViewController.presentAsOverlay(in: parentViewController)
    }

    @objc private func handleItemTap(_ sender: UIButton) {
        guard !InputAccessoryBar.isEditingItems else { return }
    }

    @objc private func handleItemLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let itemView = gesture.view as? InputAccessoryBarItemView else { return }

        switch gesture.state {
        case .began:
            enterEditingModeIfNeeded()
            armedItemView = itemView
            dragPanGestureRecognizer.isEnabled = true
        case .ended, .cancelled, .failed:
            armedItemView = nil
        default:
            break
        }
    }

    @objc private func handleDragPan(_ gesture: UIPanGestureRecognizer) {
        guard InputAccessoryBar.isEditingItems else { return }

        switch gesture.state {
        case .began:
            guard let itemView = armedItemView ?? itemView(at: gesture.location(in: stackView)),
                  let itemIndex = itemViews.firstIndex(of: itemView) else {
                resetDragPanRecognizer()
                return
            }
            beginDragging(itemView, at: itemIndex)
            if let dragSnapshotView {
                let locationInSelf = gesture.location(in: self)
                dragTouchOffsetX = locationInSelf.x - dragSnapshotView.center.x
            }
            armedItemView = nil
        case .changed:
            guard let draggedItemView else { return }
            updateDragging(draggedItemView, gesture: gesture)
        case .ended, .cancelled, .failed:
            guard let draggedItemView else {
                resetDragPanRecognizer()
                return
            }
            endDragging(draggedItemView)
            resetDragPanRecognizer()
        default:
            break
        }
    }

    @discardableResult
    private static func presentDetachedOverlayBarCopy(from sourceBar: InputAccessoryBar, in parentViewController: UIViewController) -> InputAccessoryBar? {
        dismissDetachedOverlayBarIfNeeded()

        let detachedBar = InputAccessoryBar(frame: .zero)
        detachedBar.translatesAutoresizingMaskIntoConstraints = false
        detachedBar.isDetachedOverlayBar = true
        detachedBar.buttonRecords = sourceBar.buttonRecords
        detachedBar.itemTitles = sourceBar.itemTitles
        detachedBar.selectedIndexes = sourceBar.selectedIndexes
        detachedBar.syncSelectionState()
        detachedBar.mirroredBar = sourceBar
        sourceBar.mirroredBar = detachedBar

        parentViewController.view.addSubview(detachedBar)
        NSLayoutConstraint.activate([
            detachedBar.leadingAnchor.constraint(equalTo: parentViewController.view.leadingAnchor),
            detachedBar.trailingAnchor.constraint(equalTo: parentViewController.view.trailingAnchor),
            detachedBar.bottomAnchor.constraint(equalTo: parentViewController.view.safeAreaLayoutGuide.bottomAnchor),
            detachedBar.heightAnchor.constraint(equalToConstant: InputAccessoryBarMetrics.barHeight),
        ])
        detachedOverlayBar = detachedBar
        return detachedBar
    }
    
    func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary) {
        applyCreatedWidgetPayload(payload)
        mirroredBar?.applyCreatedWidgetPayload(payload)
    }

    private static func dismissDetachedOverlayBarIfNeeded() {
        let hostViewController = detachedOverlayBar?.parentViewController
        detachedOverlayBar?.mirroredBar?.mirroredBar = nil
        detachedOverlayBar?.mirroredBar = nil
        detachedOverlayBar?.removeFromSuperview()
        detachedOverlayBar = nil
        if let hostViewController {
            hostViewController.setNeedsUpdateOfScreenEdgesDeferringSystemGestures()
            hostViewController.setNeedsUpdateOfHomeIndicatorAutoHidden()
        }
    }

    private func applyCreatedWidgetPayload(_ payload: NSDictionary) {
        let buttonLabel = (payload["buttonLabel"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cmdString = (payload["cmdString"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var displayTitle = buttonLabel.isEmpty ? cmdString : buttonLabel

        guard !displayTitle.isEmpty else { return }
        guard !buttonRecords.contains(where: { $0.buttonLabel == buttonLabel && $0.cmdString == cmdString }) else { return }

        let record = InputAccessoryBarButtonRecord(buttonLabel: buttonLabel, cmdString: cmdString)
        buttonRecords.append(record)
        refreshItemTitlesFromRecords()
        persistButtonRecords()
    }

    private func loadPersistedButtons() {
        let persistedRecords = Self.fetchPersistedButtonRecords()
        if persistedRecords.isEmpty {
            buttonRecords = Self.defaultButtonRecords
            refreshItemTitlesFromRecords()
            persistButtonRecords()
        } else {
            buttonRecords = persistedRecords
            refreshItemTitlesFromRecords()
        }
    }

    private func refreshItemTitlesFromRecords() {
        itemTitles = buttonRecords.map(\.displayTitle)
    }

    private func enterEditingModeIfNeeded() {
        guard !InputAccessoryBar.isEditingItems else { return }
        InputAccessoryBar.isEditingItems = true
        setNeedsLayout()
        layoutIfNeeded()
        updateScrollMask()
        installOutsideTapShield()
        itemViews.forEach { $0.setEditing(true, animated: true) }
    }

    private func endEditingMode(saveChanges: Bool) {
        guard InputAccessoryBar.isEditingItems else { return }
        InputAccessoryBar.isEditingItems = false
        setNeedsLayout()
        layoutIfNeeded()
        updateScrollMask()
        armedItemView = nil
        dragPanGestureRecognizer.isEnabled = false
        dragSnapshotView?.removeFromSuperview()
        dragSnapshotView = nil
        draggedItemView?.alpha = 1
        draggedItemView?.transform = .identity
        draggedItemView?.layer.zPosition = 0
        draggedItemView = nil
        outsideTapShield?.removeFromSuperview()
        outsideTapShield = nil
        itemViews.forEach { $0.setEditing(false, animated: true) }
        if saveChanges {
            persistButtonRecords()
            mirroredBar?.reloadRecordsFromPersistence()
        }
    }

    private func reloadRecordsFromPersistence() {
        buttonRecords = Self.fetchPersistedButtonRecords()
        refreshItemTitlesFromRecords()
    }

    private func installOutsideTapShield() {
        guard outsideTapShield == nil,
              let parentViewController = self.parentViewController else { return }

        let shield = UIControl(frame: parentViewController.view.bounds)
        shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        shield.backgroundColor = UIColor.black.withAlphaComponent(InputAccessoryBarMetrics.editOverlayDimAlpha)
        shield.addTarget(self, action: #selector(handleOutsideTapShield), for: .touchUpInside)
        parentViewController.view.addSubview(shield)
        if superview === parentViewController.view {
            parentViewController.view.bringSubviewToFront(shield)
            parentViewController.view.bringSubviewToFront(self)
        }
        outsideTapShield = shield
    }

    @objc private func handleOutsideTapShield() {
        endEditingMode(saveChanges: true)
    }

    private func beginDragging(_ itemView: InputAccessoryBarItemView, at index: Int) {
        guard itemViews.indices.contains(index) else { return }
        draggedItemView = itemView
        itemView.deleteButton.isHidden = true
        itemView.deleteButton.alpha = 0
        itemView.layoutIfNeeded()
        layoutIfNeeded()
        let snapshot = itemView.snapshotView(afterScreenUpdates: true) ?? UIView(frame: itemView.bounds)
        let snapshotFrame = convert(itemView.frame, from: stackView)
        snapshot.frame = snapshotFrame
        snapshot.layer.zPosition = 10
        addSubview(snapshot)
        dragSnapshotView = snapshot
        dragTouchOffsetX = 0

        itemView.alpha = 0
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseOut]) {
            snapshot.transform = CGAffineTransform(translationX: 0, y: InputAccessoryBarMetrics.dragLiftY)
                .scaledBy(x: InputAccessoryBarMetrics.dragScale, y: InputAccessoryBarMetrics.dragScale)
        }
    }

    private func updateDragging(_ itemView: InputAccessoryBarItemView, gesture: UIPanGestureRecognizer) {
        guard draggedItemView === itemView,
              let dragSnapshotView else { return }

        autoScrollIfNeeded(for: gesture.location(in: scrollView))

        _ = gesture.location(in: scrollView)
        let locationInSelf = gesture.location(in: self)
        dragSnapshotView.center = CGPoint(
            x: locationInSelf.x - dragTouchOffsetX,
            y: bounds.midY + InputAccessoryBarMetrics.dragLiftY
        )

        let dragLocationX = convert(dragSnapshotView.center, to: stackView).x
        let targetIndex = targetReorderIndex(for: dragLocationX, excluding: itemView)
        guard let currentIndex = itemViews.firstIndex(of: itemView),
              targetIndex != currentIndex else { return }

        reorderItem(from: currentIndex, to: targetIndex)
    }

    private func endDragging(_ itemView: InputAccessoryBarItemView) {
        guard draggedItemView === itemView else { return }
        let finalFrame = convert(itemView.frame, from: stackView)
        let snapshot = dragSnapshotView
        draggedItemView = nil
        dragSnapshotView = nil
        dragTouchOffsetX = 0

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            snapshot?.transform = .identity
            snapshot?.frame = finalFrame
            self.layoutIfNeeded()
        } completion: { _ in
            itemView.alpha = 1
            itemView.transform = .identity
            itemView.layer.zPosition = 0
            snapshot?.removeFromSuperview()
            itemView.setEditing(InputAccessoryBar.isEditingItems, animated: false)
        }
    }

    private func itemView(at point: CGPoint) -> InputAccessoryBarItemView? {
        itemViews.first { $0.frame.insetBy(dx: -8, dy: -8).contains(point) }
    }

    private func resetDragPanRecognizer() {
        dragPanGestureRecognizer.isEnabled = false
        dragPanGestureRecognizer.isEnabled = true
    }

    private func targetReorderIndex(for dragLocationX: CGFloat, excluding draggedItemView: InputAccessoryBarItemView) -> Int {
        let remainingItemViews = itemViews.filter { $0 !== draggedItemView }
        for (index, itemView) in remainingItemViews.enumerated() {
            if dragLocationX < itemView.frame.midX {
                return index
            }
        }
        return remainingItemViews.count
    }

    private func reorderItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard sourceIndex != destinationIndex,
              buttonRecords.indices.contains(sourceIndex),
              destinationIndex >= 0,
              destinationIndex < buttonRecords.count,
              itemViews.indices.contains(sourceIndex) else { return }

        let movedRecord = buttonRecords.remove(at: sourceIndex)
        buttonRecords.insert(movedRecord, at: destinationIndex)

        let movedView = itemViews.remove(at: sourceIndex)
        itemViews.insert(movedView, at: destinationIndex)

        stackView.removeArrangedSubview(movedView)
        stackView.insertArrangedSubview(movedView, at: destinationIndex)
        reindexItemViews()

        UIView.animate(withDuration: InputAccessoryBarMetrics.reorderAnimationDuration, delay: 0, options: [.curveEaseInOut]) {
            self.stackView.layoutIfNeeded()
            self.layoutIfNeeded()
        }
    }

    private func reindexItemViews() {
        for (index, itemView) in itemViews.enumerated() {
            itemView.tag = index
            itemView.button.tag = index
        }
    }

    private func autoScrollIfNeeded(for locationInScrollView: CGPoint) {
        guard scrollView.contentSize.width > scrollView.bounds.width else { return }

        var newOffsetX = scrollView.contentOffset.x
        let maxOffsetX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
        if locationInScrollView.x < InputAccessoryBarMetrics.edgeAutoScrollTriggerInset {
            newOffsetX -= InputAccessoryBarMetrics.edgeAutoScrollStep
        } else if locationInScrollView.x > scrollView.bounds.width - InputAccessoryBarMetrics.edgeAutoScrollTriggerInset {
            newOffsetX += InputAccessoryBarMetrics.edgeAutoScrollStep
        }

        let clampedOffsetX = min(max(0, newOffsetX), maxOffsetX)
        guard clampedOffsetX != scrollView.contentOffset.x else { return }
        scrollView.contentOffset.x = clampedOffsetX
    }

    private func handleDeleteTap(for itemView: InputAccessoryBarItemView) {
        guard let index = itemViews.firstIndex(of: itemView),
              buttonRecords.indices.contains(index) else { return }

        buttonRecords.remove(at: index)
        refreshItemTitlesFromRecords()
        persistButtonRecords()
        mirroredBar?.reloadRecordsFromPersistence()

        if buttonRecords.isEmpty {
            endEditingMode(saveChanges: false)
        }
    }

    private func persistButtonRecords() {
        guard let context = Self.managedObjectContext else { return }

        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "InputAccessoryBarButton")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            _ = try? context.execute(deleteRequest)

            for (index, record) in buttonRecords.enumerated() {
                guard let entity = NSEntityDescription.entity(forEntityName: "InputAccessoryBarButton", in: context) else {
                    continue
                }
                let object = NSManagedObject(entity: entity, insertInto: context)
                object.setValue(record.buttonLabel, forKey: "buttonLabel")
                object.setValue(record.cmdString, forKey: "cmdString")
                object.setValue(index, forKey: "index")
            }

            if context.hasChanges {
                try? context.save()
            }
        }
    }

    private static func fetchPersistedButtonRecords() -> [InputAccessoryBarButtonRecord] {
        guard let context = managedObjectContext else { return [] }

        var records: [InputAccessoryBarButtonRecord] = []
        context.performAndWait {
            let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "InputAccessoryBarButton")
            let sortDescriptor = NSSortDescriptor(key: "index", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            guard let objects = try? context.fetch(fetchRequest) else { return }
            records = objects.compactMap { object in
                let buttonLabel = (object.value(forKey: "buttonLabel") as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let cmdString = (object.value(forKey: "cmdString") as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !buttonLabel.isEmpty || !cmdString.isEmpty else { return nil }
                return InputAccessoryBarButtonRecord(buttonLabel: buttonLabel, cmdString: cmdString)
            }
        }
        return records
    }

    private static var managedObjectContext: NSManagedObjectContext? {
        (UIApplication.shared.delegate as? AppDelegate)?.managedObjectContext
    }

    private static var defaultButtonRecords: [InputAccessoryBarButtonRecord] {
        [
            InputAccessoryBarButtonRecord(buttonLabel: "Win", cmdString: "WIN"),
            InputAccessoryBarButtonRecord(buttonLabel: "Esc", cmdString: "ESC"),
            InputAccessoryBarButtonRecord(buttonLabel: "Ctrl", cmdString: "CTRL+Null"),
            InputAccessoryBarButtonRecord(buttonLabel: "Alt", cmdString: "ALT+Null"),
            InputAccessoryBarButtonRecord(buttonLabel: "Shift", cmdString: "SHIFT+Null"),
            InputAccessoryBarButtonRecord(buttonLabel: "Tab", cmdString: "TAB+Null"),
            InputAccessoryBarButtonRecord(buttonLabel: "Del", cmdString: "DEL"),
        ]
    }
}
