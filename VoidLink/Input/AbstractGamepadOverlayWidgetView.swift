//
//  AbstractGamepadOverlayWidgetView.swift
//  VoidLink
//
//  Created by True砖家 on 2024/4/6.
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import UIKit
import SwiftUI

@objc
protocol AbstractGamepadOverlayCloseButtonDelegate: AnyObject {
    @objc(toggleGamepadOverlayWithOverlayEnabled:)
    func toggleGamepadOverlay(withOverlayEnabled overlayEnabled: Bool)
}

private enum AbstractGamepadOverlayPersistence {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let overlayCenterXRatio = "AbstractGamepadOverlay.overlay.centerXRatio"
        static let overlayCenterYRatio = "AbstractGamepadOverlay.overlay.centerYRatio"
        static let overlayWidth = "AbstractGamepadOverlay.overlay.width"
    }

    struct PersistedState {
        let centerRatio: CGPoint
        let size: CGSize
    }

    static func loadOverlayState() -> PersistedState? {
        loadState(
            centerXKey: Key.overlayCenterXRatio,
            centerYKey: Key.overlayCenterYRatio,
            widthKey: Key.overlayWidth
        )
    }

    static func saveOverlayState(centerRatio: CGPoint, size: CGSize) {
        saveState(
            centerRatio: centerRatio,
            size: size,
            centerXKey: Key.overlayCenterXRatio,
            centerYKey: Key.overlayCenterYRatio,
            widthKey: Key.overlayWidth
        )
    }

    static func centerRatio(for view: UIView, in superview: UIView) -> CGPoint {
        let safeWidth = max(superview.bounds.width, 1)
        let safeHeight = max(superview.bounds.height, 1)
        return CGPoint(x: view.center.x / safeWidth, y: view.center.y / safeHeight)
    }

    static func center(in superview: UIView, from ratio: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(ratio.x, 0), 1) * superview.bounds.width,
            y: min(max(ratio.y, 0), 1) * superview.bounds.height
        )
    }

    private static func loadState(
        centerXKey: String,
        centerYKey: String,
        widthKey: String
    ) -> PersistedState? {
        guard defaults.object(forKey: centerXKey) != nil,
              defaults.object(forKey: centerYKey) != nil,
              defaults.object(forKey: widthKey) != nil else {
            return nil
        }

        let width = defaults.double(forKey: widthKey)
        guard width > 0 else { return nil }

        return PersistedState(
            centerRatio: CGPoint(
                x: defaults.double(forKey: centerXKey),
                y: defaults.double(forKey: centerYKey)
            ),
            size: CGSize(width: width, height: 0)
        )
    }

    private static func saveState(
        centerRatio: CGPoint,
        size: CGSize,
        centerXKey: String,
        centerYKey: String,
        widthKey: String
    ) {
        defaults.set(centerRatio.x, forKey: centerXKey)
        defaults.set(centerRatio.y, forKey: centerYKey)
        defaults.set(size.width, forKey: widthKey)
    }
}

@available(iOS 13.0, *)
private struct AbstractGamepadOverlayBridgeView: View {
    let usesPlayStationFaceButtons: Bool
    private static let overlayClusterGapAdjustmentRatio: CGFloat = 0.13
    private static let overlayUpperPrimaryClusterVerticalAdjustmentRatio: CGFloat = -0.05
    private static let overlayCenterCompressionRatio: CGFloat = 0
    private static let overlayPanelHorizontalInsetRatio: CGFloat = 0.083
    private static let overlayTriggerStubSpacingAdjustmentRatio: CGFloat = 0.17
    private static let overlayRightShoulderHorizontalOffsetRatio: CGFloat = 0.006
    private static let overlayThumbPurpleStrength: CGFloat = 1.15
    private static let overlayTriggerPurpleStrength: CGFloat = 2.0
    @ObservedObject var stateCenter = GamepadOverlayStateCenter.shared

    var body: some View {
        AbstractGamepadView(
            gamepadType: usesPlayStationFaceButtons ? GamepadType.ps : GamepadType.xbox,
            metricsProfile: GamepadMetricsProfile.overlay,
            clusterGapAdjustmentRatio: Self.overlayClusterGapAdjustmentRatio,
            upperPrimaryClusterVerticalAdjustmentRatio: Self.overlayUpperPrimaryClusterVerticalAdjustmentRatio,
            centerCompressionRatio: Self.overlayCenterCompressionRatio,
            panelHorizontalInsetRatio: Self.overlayPanelHorizontalInsetRatio,
            triggerStubSpacingAdjustmentRatio: Self.overlayTriggerStubSpacingAdjustmentRatio,
            rightShoulderHorizontalOffsetRatio: Self.overlayRightShoulderHorizontalOffsetRatio,
            thumbPurpleStrength: Self.overlayThumbPurpleStrength,
            triggerPurpleStrength: Self.overlayTriggerPurpleStrength,
            liveSnapshot: stateCenter.snapshot
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .allowsHitTesting(false)
        .background(Color.clear)
    }
}

@available(iOS 13.0, *)
@objc
final class AbstractGamepadOverlayView: UIView {
    private enum CloseButtonMetrics {
        static let size: CGFloat = 40
        static let topInset: CGFloat = -10
        static let trailingInset: CGFloat = 0
        static let symbolPointSize: CGFloat = 16
        static let hideDelay: TimeInterval = 3
    }

    private enum OverlayMaskMetrics {
        static let widthRatio: CGFloat = 0.85
        static let heightRatio: CGFloat = 1.03
        static let cornerRadiusRatio: CGFloat = 0.326
        static let verticalOffsetRatio: CGFloat = -0.006
        
        static let topRectWidthRatio: CGFloat = 0.6
        static let topRectHeightRatio: CGFloat = 0.15
        static let topRectCornerRadiusRatio: CGFloat = 0.22
        static let topRectVerticalOffsetRatio: CGFloat = -0.5
    }

    private var hostingControllerBox: AnyObject?
    private weak var hostedView: UIView?
    private let visualMaskLayer = CAShapeLayer()
    private let usesPlayStationFaceButtons: Bool
    private let baseRenderWidth: CGFloat = 420
    private let baseAspectRatio: CGFloat = 1.82
    private let initialDisplayWidth: CGFloat
    private var pinchBaseWidth: CGFloat = 0
    private var panStartCenter: CGPoint = .zero
    private var activeGestureCount = 0
    private var didRestorePersistedState = false
    private var hideCloseButtonWorkItem: DispatchWorkItem?
    private let minWidth: CGFloat = 70
    private let maxWidth: CGFloat = 520
    private let doubleTapWidths: [CGFloat] = [GenericUtils.isIPhone() ? 90 : 130, GenericUtils.isIPhone() ? 165 : 200]
    private lazy var closeButton: UIButton = makeCloseButton()
    @objc weak var closeButtonDelegate: AbstractGamepadOverlayCloseButtonDelegate?

    @objc init(frame: CGRect, usesPlayStationFaceButtons: Bool) {
        self.usesPlayStationFaceButtons = usesPlayStationFaceButtons
        self.initialDisplayWidth = frame.width > 0 ? frame.width : baseRenderWidth
        super.init(frame: CGRect(origin: frame.origin, size: CGSize(width: baseRenderWidth, height: baseRenderWidth / baseAspectRatio)))
        setupHostedViewIfNeeded()
    }

    override init(frame: CGRect) {
        self.usesPlayStationFaceButtons = false
        self.initialDisplayWidth = frame.width > 0 ? frame.width : baseRenderWidth
        super.init(frame: CGRect(origin: frame.origin, size: CGSize(width: baseRenderWidth, height: baseRenderWidth / baseAspectRatio)))
        setupHostedViewIfNeeded()
    }

    required init?(coder: NSCoder) {
        self.usesPlayStationFaceButtons = false
        self.initialDisplayWidth = baseRenderWidth
        super.init(coder: coder)
        setupHostedViewIfNeeded()
    }

    private func setupHostedViewIfNeeded() {
        guard hostedView == nil else { return }

        let hostingController = UIHostingController(rootView: AbstractGamepadOverlayBridgeView(usesPlayStationFaceButtons: usesPlayStationFaceButtons))
        hostingController.view.backgroundColor = .clear
        hostingController.view.isUserInteractionEnabled = false
        hostingController.view.translatesAutoresizingMaskIntoConstraints = true
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hostingController.view.frame = bounds

        hostingControllerBox = hostingController
        hostedView = hostingController.view
        backgroundColor = .clear
        clipsToBounds = false
        isMultipleTouchEnabled = true
        applyScale(forTargetWidth: initialDisplayWidth)

        addSubview(hostingController.view)
        addSubview(closeButton)
        installGesturesIfNeeded()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostedView?.frame = bounds
        layoutCloseButton()
        updateVisualMask()
        restorePersistedStateIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        didRestorePersistedState = false
        restorePersistedStateIfNeeded()
    }

    private func installGesturesIfNeeded() {
        guard gestureRecognizers?.isEmpty != false else { return }
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.cancelsTouchesInView = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.cancelsTouchesInView = true
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.cancelsTouchesInView = true
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        doubleTap.cancelsTouchesInView = true
        singleTap.delegate = self
        pan.delegate = self
        pinch.delegate = self
        doubleTap.delegate = self
        pan.require(toFail: doubleTap)
        singleTap.require(toFail: pan)
        addGestureRecognizer(pan)
        addGestureRecognizer(singleTap)
        addGestureRecognizer(pinch)
        addGestureRecognizer(doubleTap)
    }

    @objc private func handleSingleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        registerUserInteraction()
        presentFirstTouchTipIfNeeded()
        scheduleCloseButtonHideIfNeeded()
    }

    @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        guard let superview else { return }
        switch recognizer.state {
        case .began:
            registerUserInteraction()
            presentFirstTouchTipIfNeeded()
            beginGestureSession()
            panStartCenter = center
        case .changed, .ended:
            registerUserInteraction()
            let translation = recognizer.translation(in: superview)
            center = CGPoint(x: panStartCenter.x + translation.x, y: panStartCenter.y + translation.y)
            if recognizer.state == .ended {
                endGestureSession()
            }
        case .cancelled, .failed:
            endGestureSession()
        default:
            break
        }
    }

    @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        switch recognizer.state {
        case .began:
            registerUserInteraction()
            presentFirstTouchTipIfNeeded()
            beginGestureSession()
            pinchBaseWidth = frame.width
        case .changed, .ended:
            registerUserInteraction()
            let nextWidth = max(minWidth, min(maxWidth, pinchBaseWidth * recognizer.scale))
            applyScale(forTargetWidth: nextWidth)
            if recognizer.state == .ended {
                endGestureSession()
            }
        case .cancelled, .failed:
            endGestureSession()
        default:
            break
        }
    }

    @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        registerUserInteraction()
        presentFirstTouchTipIfNeeded()
        applyScale(forTargetWidth: nextDoubleTapWidth())
        persistState()
        scheduleCloseButtonHideIfNeeded()
    }

    private func updateVisualMask() {
        guard bounds.width > 1, bounds.height > 1 else {
            visualMaskLayer.path = nil
            hostedView?.layer.mask = nil
            return
        }

        let maskWidth = bounds.width * OverlayMaskMetrics.widthRatio
        let maskHeight = bounds.height * OverlayMaskMetrics.heightRatio
        let maskRect = CGRect(
            x: (bounds.width - maskWidth) * 0.5,
            y: (bounds.height - maskHeight) * 0.5 + bounds.height * OverlayMaskMetrics.verticalOffsetRatio,
            width: maskWidth,
            height: maskHeight
        )
        let maskCornerRadius = min(maskRect.width, maskRect.height) * OverlayMaskMetrics.cornerRadiusRatio
        let topRectWidth = bounds.width * OverlayMaskMetrics.topRectWidthRatio
        let topRectHeight = bounds.height * OverlayMaskMetrics.topRectHeightRatio
        let topRect = CGRect(
            x: (bounds.width - topRectWidth) * 0.5,
            y: (bounds.height - topRectHeight) * 0.5 + bounds.height * OverlayMaskMetrics.topRectVerticalOffsetRatio,
            width: topRectWidth,
            height: topRectHeight
        )
        let topRectCornerRadius = min(topRect.width, topRect.height) * OverlayMaskMetrics.topRectCornerRadiusRatio

        visualMaskLayer.frame = bounds
        let path = UIBezierPath(
            roundedRect: maskRect,
            byRoundingCorners: .allCorners,
            cornerRadii: CGSize(width: maskCornerRadius, height: maskCornerRadius)
        )
        path.append(
            UIBezierPath(
                roundedRect: topRect,
                byRoundingCorners: .allCorners,
                cornerRadii: CGSize(width: topRectCornerRadius, height: topRectCornerRadius)
            )
        )
        visualMaskLayer.path = path.cgPath
        hostedView?.layer.mask = visualMaskLayer
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.contains(point)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        registerUserInteraction()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        registerUserInteraction()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        scheduleCloseButtonHideIfNeeded()
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        scheduleCloseButtonHideIfNeeded()
    }

    private func restorePersistedStateIfNeeded() {
        guard !didRestorePersistedState,
              let superview,
              bounds.width > 0,
              bounds.height > 0,
              superview.bounds.width > 0,
              superview.bounds.height > 0 else { return }
        defer { didRestorePersistedState = true }

        guard let state = AbstractGamepadOverlayPersistence.loadOverlayState() else { return }
        applyScale(forTargetWidth: state.size.width)
        center = AbstractGamepadOverlayPersistence.center(in: superview, from: state.centerRatio)
    }

    private func beginGestureSession() {
        activeGestureCount += 1
    }

    @objc func registerUserInteraction() {
        showCloseButton()
        cancelPendingCloseButtonHide()
    }

    private func presentFirstTouchTipIfNeeded() {
        guard GenericUtils.isFirstLaunchGamepadOverlayFeature() else { return }
        guard let presentingViewController = nearestViewController() else { return }

        AlertControllerUtil.showAlert(
            in: presentingViewController,
            title: GenericUtils.gamepadOverlayFeatureTipTitle(),
            message: GenericUtils.gamepadOverlayFeatureTipMessage(),
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "This tip won't be shown again"),
            countdown: 6
            )
    }

    private func nearestViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let current = responder {
            if let viewController = current as? UIViewController {
                return viewController
            }
            responder = current.next
        }
        return nil
    }

    private func endGestureSession() {
        activeGestureCount = max(0, activeGestureCount - 1)
        guard activeGestureCount == 0 else { return }
        persistState()
        scheduleCloseButtonHideIfNeeded()
    }

    private func persistState() {
        guard let superview,
              superview.bounds.width > 0,
              superview.bounds.height > 0 else { return }
        AbstractGamepadOverlayPersistence.saveOverlayState(
            centerRatio: AbstractGamepadOverlayPersistence.centerRatio(for: self, in: superview),
            size: frame.size
        )
    }

    private func nextDoubleTapWidth() -> CGFloat {
        let currentWidth = frame.width
        return abs(currentWidth - doubleTapWidths[0]) <= abs(currentWidth - doubleTapWidths[1])
            ? doubleTapWidths[1]
            : doubleTapWidths[0]
    }

    private func applyScale(forTargetWidth targetWidth: CGFloat) {
        let clampedWidth = max(minWidth, min(maxWidth, targetWidth))
        let targetScale = clampedWidth / baseRenderWidth
        transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
    }

    private func makeCloseButton() -> UIButton {
        let button = UIButton(type: .system)
        button.tintColor = UIColor.black.withAlphaComponent(0.66)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.78)
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        button.layer.shadowColor = UIColor.black.withAlphaComponent(0.05).cgColor
        button.layer.shadowOpacity = 1
        button.layer.shadowRadius = 4
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.alpha = 0
        button.isHidden = true
        button.adjustsImageWhenHighlighted = false
        button.addTarget(self, action: #selector(handleCloseButtonTap), for: .touchUpInside)

        let configuration = UIImage.SymbolConfiguration(pointSize: CloseButtonMetrics.symbolPointSize, weight: .bold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: configuration), for: .normal)
        return button
    }

    private func layoutCloseButton() {
        let size = CGFloat(Int(CloseButtonMetrics.size/2))*2
        closeButton.frame = CGRect(
            x: bounds.width - CloseButtonMetrics.trailingInset - size,
            y: CloseButtonMetrics.topInset,
            width: size,
            height: size
        )
        closeButton.layer.cornerRadius = size * 0.5
    }

    private func showCloseButton() {
        closeButton.isHidden = false
        guard closeButton.alpha < 1 else { return }
        UIView.animate(withDuration: 0.18) {
            self.closeButton.alpha = 1
        }
    }

    private func hideCloseButton() {
        guard !closeButton.isHidden else { return }
        UIView.animate(
            withDuration: 0.18,
            animations: {
                self.closeButton.alpha = 0
            },
            completion: { _ in
                self.closeButton.isHidden = true
            }
        )
    }

    private func cancelPendingCloseButtonHide() {
        hideCloseButtonWorkItem?.cancel()
        hideCloseButtonWorkItem = nil
    }

    @objc func scheduleCloseButtonHideIfNeeded() {
        guard activeGestureCount == 0 else { return }
        cancelPendingCloseButtonHide()
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideCloseButton()
            self?.hideCloseButtonWorkItem = nil
        }
        hideCloseButtonWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + CloseButtonMetrics.hideDelay, execute: workItem)
    }

    @objc private func handleCloseButtonTap() {
        cancelPendingCloseButtonHide()
        closeButtonDelegate?.toggleGamepadOverlay(withOverlayEnabled: false)
    }
}

@available(iOS 13.0, *)
extension AbstractGamepadOverlayView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
        || (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let touchedView = touch.view else { return true }
        return touchedView !== closeButton && !touchedView.isDescendant(of: closeButton)
    }
}
