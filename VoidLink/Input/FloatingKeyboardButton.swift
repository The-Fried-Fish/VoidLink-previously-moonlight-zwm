//
//  FloatingKeyboardButton.swift
//  VoidLink
//
//  A small, semi-transparent on-screen keyboard button, independent of the custom
//  on-screen widgets. Tap to open/close the soft keyboard. Hold it briefly, then drag
//  to move it; the position is remembered.
//

import UIKit

@objc class FloatingKeyboardButton: UIView {

    private static let buttonSize: CGFloat = 48
    private static let positionDefaultsKey = "floatingKeyboardButtonNormalizedCenter"
    private static let defaultNormalizedCenter = CGPoint(x: 0.92, y: 0.72)

    @objc var onTap: (() -> Void)?

    private let iconView = UIImageView()
    private var isDragging = false
    private var dragStartCenter: CGPoint = .zero
    private var dragStartLocation: CGPoint = .zero

    @objc init() {
        let size = FloatingKeyboardButton.buttonSize
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))

        backgroundColor = UIColor(white: 0.1, alpha: 0.45)
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = UIColor(white: 0.9, alpha: 0.25).cgColor
        isExclusiveTouch = true
        layer.zPosition = 1000 // drawn above on-screen widgets

        if #available(iOS 13.0, tvOS 13.0, *) {
            iconView.image = UIImage(systemName: "keyboard",
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
        }
        iconView.tintColor = UIColor(white: 1.0, alpha: 0.85)
        iconView.contentMode = .center
        iconView.frame = bounds
        iconView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(iconView)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.35
        longPress.allowableMovement = 12
        addGestureRecognizer(longPress)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.require(toFail: longPress)
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        flashHighlight()
        onTap?()
    }

    private func flashHighlight() {
        backgroundColor = UIColor(white: 0.9, alpha: 0.45)
        UIView.animate(withDuration: 0.2) {
            self.backgroundColor = UIColor(white: 0.1, alpha: 0.45)
        }
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard let superview = superview else { return }
        let location = recognizer.location(in: superview)
        switch recognizer.state {
        case .began:
            isDragging = true
            dragStartCenter = center
            dragStartLocation = location
            UIView.animate(withDuration: 0.15) {
                self.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
                self.alpha = 0.8
            }
        case .changed:
            center = clampedCenter(CGPoint(x: dragStartCenter.x + location.x - dragStartLocation.x,
                                           y: dragStartCenter.y + location.y - dragStartLocation.y))
        case .ended, .cancelled, .failed:
            isDragging = false
            UIView.animate(withDuration: 0.15) {
                self.transform = .identity
                self.alpha = 1.0
            }
            savePosition()
        default:
            break
        }
    }

    // MARK: - Position

    private func clampedCenter(_ point: CGPoint) -> CGPoint {
        guard let superview = superview else { return point }
        let area = superview.bounds.inset(by: superview.safeAreaInsets)
        let half = FloatingKeyboardButton.buttonSize / 2
        return CGPoint(x: min(max(point.x, area.minX + half), area.maxX - half),
                       y: min(max(point.y, area.minY + half), area.maxY - half))
    }

    private func savePosition() {
        guard let superview = superview, superview.bounds.width > 0, superview.bounds.height > 0 else { return }
        let normalized = [center.x / superview.bounds.width, center.y / superview.bounds.height]
        UserDefaults.standard.set(normalized.map { Double($0) }, forKey: FloatingKeyboardButton.positionDefaultsKey)
    }

    /// Places the button at its saved position; call after adding it to a view and when that view resizes.
    @objc func restorePosition() {
        guard let superview = superview, !isDragging else { return }
        var normalized = FloatingKeyboardButton.defaultNormalizedCenter
        if let saved = UserDefaults.standard.array(forKey: FloatingKeyboardButton.positionDefaultsKey) as? [Double], saved.count == 2 {
            normalized = CGPoint(x: saved[0], y: saved[1])
        }
        center = clampedCenter(CGPoint(x: normalized.x * superview.bounds.width,
                                       y: normalized.y * superview.bounds.height))
    }
}
