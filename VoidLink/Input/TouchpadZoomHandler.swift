//
//  TouchpadZoomHandler.swift
//  VoidLink
//
//  Pinch-to-zoom for touchpad (relative touch) mode.
//
//  While the stream is zoomed in, the cursor is driven with absolute position
//  events (LiSendMousePositionEvent) from a locally tracked cursor position, so
//  the client always knows where the cursor is and can pan the visible area to
//  follow it. Once the zoom returns to 1x, cursor motion goes back to plain
//  relative mouse events.
//
//  With "Open Keyboard Where Cursor Is", the soft keyboard shrinks the usable
//  viewport to the area above it: the view is panned so the cursor stays
//  centered above the keyboard, and the bottom of the video can be scrolled up
//  to the keyboard's top edge.
//
//  All methods must be called on the main thread.
//

import UIKit

@objc class TouchpadZoomHandler: NSObject {

    /// Enabled when the Pinch Gesture setting is "Zoom".
    @objc var pinchZoomEnabled: Bool = false

    @objc static let maximumZoomScale: CGFloat = 6.0

    /// Height of the stream area covered by the soft keyboard (including its accessory bar), 0 when closed.
    private static var keyboardOcclusion: CGFloat = 0
    /// The handler of the current touchpad session, which receives keyboard occlusion changes.
    private static weak var active: TouchpadZoomHandler?

    private weak var streamView: StreamView?

    /// Cursor position in the (unzoomed) streamView coordinate space, only valid while zoomed.
    private var cursorLocation: CGPoint = .zero
    private var cursorLocationInitialized = false
    /// Point kept centered while the keyboard is open before the cursor has been moved (the cursor isn't tracked yet).
    private var keyboardAnchor: CGPoint?
    /// Last content offset set by followCursor; restored if UIKit scrolls the view while the keyboard is open.
    private var appliedContentOffset: CGPoint?

    /// Estimated cursor position (streamView coordinates) while it moves relatively at 1x: the last tracked position
    /// when zooming out, advanced by the relative moves sent since. Zooming in / opening the keyboard starts there.
    /// Assumes host pointer movement of one pixel per relative unit, so it can drift with pointer acceleration.
    /// Kept on the type so it survives the touch handler being recreated when settings change.
    private static var sharedEstimatedCursorLocation: CGPoint?
    private var estimatedCursorLocation: CGPoint? {
        get { TouchpadZoomHandler.sharedEstimatedCursorLocation }
        set { TouchpadZoomHandler.sharedEstimatedCursorLocation = newValue }
    }

    /// Sub-unit remainder carried between relative mouse move events.
    private var relativeRemainder: CGVector = .zero

    @objc init(streamView: StreamView) {
        self.streamView = streamView
        super.init()
        TouchpadZoomHandler.active = self
    }

    private var scrollView: UIScrollView? {
        return streamView?.superview as? UIScrollView
    }

    private var currentZoomScale: CGFloat {
        guard let scrollView = scrollView else { return 1.0 }
        return max(scrollView.zoomScale, 0.0001)
    }

    @objc var zoomScale: CGFloat {
        return currentZoomScale
    }

    /// True while pinch zoom is enabled and the stream is zoomed in.
    @objc var isZoomed: Bool {
        return pinchZoomEnabled && currentZoomScale > 1.001
    }

    /// True while the cursor is driven with absolute positions: zoomed in, or the keyboard is open in Zoom mode.
    private var tracksCursor: Bool {
        return pinchZoomEnabled && (currentZoomScale > 1.001 || TouchpadZoomHandler.keyboardOcclusion > 0)
    }

    /// Insets of the scroll view's visible area that the viewport should keep clear of: the safe area (camera
    /// island / notch, home indicator) and the keyboard when it's open.
    private var viewportInsets: UIEdgeInsets {
        guard let scrollView = scrollView else { return .zero }
        let safeArea = scrollView.superview?.safeAreaInsets ?? scrollView.safeAreaInsets
        return UIEdgeInsets(top: safeArea.top, left: safeArea.left,
                            bottom: max(safeArea.bottom, TouchpadZoomHandler.keyboardOcclusion), right: safeArea.right)
    }

    /// The clear part of the visible area, in scroll view content coordinates.
    private var usableViewport: CGRect {
        guard let scrollView = scrollView else { return .zero }
        let rect = scrollView.bounds.inset(by: viewportInsets)
        return CGRect(x: rect.minX, y: rect.minY, width: max(rect.width, 1), height: max(rect.height, 1))
    }

    // MARK: - Video area geometry (streamView coordinates)

    private var videoRect: CGRect {
        guard let streamView = streamView else { return .zero }
        let bounds = streamView.bounds
        let videoSize = streamView.getVideoAreaSize()
        return CGRect(x: bounds.midX - videoSize.width / 2,
                      y: bounds.midY - videoSize.height / 2,
                      width: videoSize.width,
                      height: videoSize.height)
    }

    private func clampToVideoRect(_ point: CGPoint) -> CGPoint {
        let rect = videoRect
        return CGPoint(x: min(max(point.x, rect.minX), rect.maxX),
                       y: min(max(point.y, rect.minY), rect.maxY))
    }

    /// Center of the currently visible area (above the keyboard, if open), in streamView coordinates.
    private var visibleCenter: CGPoint {
        guard let streamView = streamView, let scrollView = scrollView else { return .zero }
        let viewport = usableViewport
        return scrollView.convert(CGPoint(x: viewport.midX, y: viewport.midY), to: streamView)
    }

    // MARK: - Cursor output

    /// Moves the cursor by a touch delta measured in screen points (already multiplied by the pointer velocity factor).
    @objc func moveCursor(by delta: CGVector) {
        let zoomScale = currentZoomScale
        // Screen points -> streamView points. This keeps the cursor moving at the
        // same on-screen speed as the finger regardless of the zoom level.
        let streamDelta = CGVector(dx: delta.dx / zoomScale, dy: delta.dy / zoomScale)

        if tracksCursor {
            if !cursorLocationInitialized { beginAbsoluteCursor() }
            cursorLocation = clampToVideoRect(CGPoint(x: cursorLocation.x + streamDelta.dx,
                                                      y: cursorLocation.y + streamDelta.dy))
            sendAbsoluteCursorPosition()
            followCursor()
            return
        }

        relativeRemainder.dx += streamDelta.dx * 1.35
        relativeRemainder.dy += streamDelta.dy * 1.35
        let deltaX = relativeRemainder.dx.rounded(.towardZero)
        let deltaY = relativeRemainder.dy.rounded(.towardZero)
        guard deltaX != 0 || deltaY != 0 else { return }
        relativeRemainder.dx -= deltaX
        relativeRemainder.dy -= deltaY
        LiSendMouseMoveEvent(Int16(clamping: Int(deltaX)), Int16(clamping: Int(deltaY)))
        advanceEstimatedCursor(byHostPixels: CGVector(dx: deltaX, dy: deltaY))
    }

    private func advanceEstimatedCursor(byHostPixels delta: CGVector) {
        guard pinchZoomEnabled, let estimate = estimatedCursorLocation,
              let config = StreamFrameViewController.sharedInstance()?.streamConfig,
              config.width > 0, config.height > 0 else { return }
        let rect = videoRect
        estimatedCursorLocation = clampToVideoRect(CGPoint(x: estimate.x + delta.dx * rect.width / CGFloat(config.width),
                                                           y: estimate.y + delta.dy * rect.height / CGFloat(config.height)))
    }

    /// Places the cursor at the center of the visible area.
    private func beginAbsoluteCursor() {
        cursorLocation = clampToVideoRect(keyboardAnchor ?? estimatedCursorLocation ?? visibleCenter)
        keyboardAnchor = nil
        cursorLocationInitialized = true
        sendAbsoluteCursorPosition()
    }

    private func sendAbsoluteCursorPosition() {
        let rect = videoRect
        guard rect.width > 0, rect.height > 0 else { return }
        // Use a reference area finer than screen points so slow movements at high zoom stay smooth.
        let referenceScale = min(4.0, 32767.0 / max(rect.width, rect.height))
        let referenceWidth = (rect.width * referenceScale).rounded()
        let referenceHeight = (rect.height * referenceScale).rounded()
        let x = ((cursorLocation.x - rect.minX) * referenceScale).rounded()
        let y = ((cursorLocation.y - rect.minY) * referenceScale).rounded()
        LiSendMousePositionEvent(Int16(clamping: Int(x)), Int16(clamping: Int(y)),
                                 Int16(clamping: Int(referenceWidth)), Int16(clamping: Int(referenceHeight)))
    }

    /// Pans the visible area so the cursor sits at the center of the usable viewport, stopping when an edge of the
    /// video reaches the edge of the usable viewport (just clear of the camera island, home indicator or keyboard).
    private func followCursor() {
        guard let streamView = streamView, let scrollView = scrollView else { return }
        let target = cursorLocationInitialized ? cursorLocation : (keyboardAnchor ?? visibleCenter)
        let insets = viewportInsets
        let viewport = usableViewport
        let cursorInContent = streamView.convert(target, to: scrollView)
        let videoInContent = streamView.convert(videoRect, to: scrollView)

        // Where the video sits in its spare room while it's smaller than the usable viewport: 0 = leading edge at the
        // viewport's leading edge, 1 = trailing edge at the trailing edge. Taken from the 1x layout (videoRect is the
        // unzoomed geometry) and the resting offset (Portrait Stream Position), so the zoomed position matches 1x
        // exactly and slides continuously into cursor following once the room runs out. Centered above the keyboard.
        let restingOffset = StreamFrameViewController.sharedInstance()?.restingStreamViewOffset() ?? .zero
        func roomFraction(videoMin1x: CGFloat, videoLength1x: CGFloat, leadingInset: CGFloat, viewport: CGFloat, resting: CGFloat) -> CGFloat {
            if TouchpadZoomHandler.keyboardOcclusion > 0 { return 0.5 }
            let room1x = viewport - videoLength1x
            guard room1x > 0.5 else { return 0.5 }
            return min(max((videoMin1x - leadingInset - resting) / room1x, 0), 1)
        }
        let fractionX = roomFraction(videoMin1x: videoRect.minX, videoLength1x: videoRect.width,
                                     leadingInset: insets.left, viewport: viewport.width, resting: restingOffset.x)
        let fractionY = roomFraction(videoMin1x: videoRect.minY, videoLength1x: videoRect.height,
                                     leadingInset: insets.top, viewport: viewport.height, resting: restingOffset.y)

        // Returns the content offset along one axis. `leadingInset` is the distance from the scroll view's
        // visible edge to the usable viewport's edge.
        func axisOffset(target: CGFloat, leadingInset: CGFloat, viewport: CGFloat, minEdge: CGFloat, maxEdge: CGFloat, roomFraction: CGFloat) -> CGFloat {
            let lower = minEdge - leadingInset
            let upper = maxEdge - viewport - leadingInset
            if upper < lower { // video smaller than viewport: place it in the spare room
                let room = viewport - (maxEdge - minEdge)
                return lower - roomFraction * room
            }
            return min(max(target - viewport / 2 - leadingInset, lower), upper)
        }

        let offset = CGPoint(
            x: axisOffset(target: cursorInContent.x, leadingInset: insets.left, viewport: viewport.width,
                          minEdge: videoInContent.minX, maxEdge: videoInContent.maxX, roomFraction: fractionX),
            y: axisOffset(target: cursorInContent.y, leadingInset: insets.top, viewport: viewport.height,
                          minEdge: videoInContent.minY, maxEdge: videoInContent.maxY, roomFraction: fractionY))
        appliedContentOffset = offset
        scrollView.contentOffset = offset
    }

    /// Called from the scroll view delegate. The hidden text field that receives keyboard input lives inside the
    /// scroll view, and UIKit scrolls text fields into view while typing; undo that while the keyboard is open.
    @objc static func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard keyboardOcclusion > 0, let handler = active, handler.pinchZoomEnabled,
              handler.scrollView === scrollView, let offset = handler.appliedContentOffset else { return }
        if abs(scrollView.contentOffset.x - offset.x) > 0.5 || abs(scrollView.contentOffset.y - offset.y) > 0.5 {
            scrollView.contentOffset = offset
        }
    }

    // MARK: - Pinch

    /// Applies a pinch step. `ratio` is the current finger distance divided by the previous one.
    @objc func applyPinch(ratio: CGFloat) {
        guard pinchZoomEnabled, let scrollView = scrollView, ratio.isFinite, ratio > 0 else { return }

        let oldScale = currentZoomScale
        let sensitivity = max(TouchPadGestureHandler.pinchSensitivity, 0.05)
        let maxScale = min(TouchpadZoomHandler.maximumZoomScale, scrollView.maximumZoomScale)
        var newScale = oldScale * pow(ratio, sensitivity)
        newScale = min(max(newScale, 1.0), maxScale)
        guard abs(newScale - oldScale) > 0.0001 else { return }

        if newScale <= 1.001 {
            endZoom()
            return
        }

        // Zooming in from 1x: put the cursor at the center of the visible area.
        if !cursorLocationInitialized {
            beginAbsoluteCursor()
        }

        scrollView.zoomScale = newScale
        followCursor()
    }

    /// Returns to 1x and hands the cursor back to relative movement.
    /// While the keyboard is open, the cursor stays tracked so the view keeps following it above the keyboard.
    @objc func endZoom() {
        let keyboardOpen = TouchpadZoomHandler.keyboardOcclusion > 0
        if !keyboardOpen {
            if cursorLocationInitialized { estimatedCursorLocation = cursorLocation }
            cursorLocationInitialized = false
            keyboardAnchor = nil
            relativeRemainder = .zero
        }
        guard let scrollView = scrollView else { return }
        scrollView.zoomScale = 1.0
        // back to the resting position (portrait stream position, if set)
        let restingOffset = StreamFrameViewController.sharedInstance()?.restingStreamViewOffset() ?? .zero
        appliedContentOffset = restingOffset
        scrollView.contentOffset = restingOffset
        StreamFrameViewController.sharedInstance()?.updateMagnifierViewportMetrics()
        if keyboardOpen { followCursor() }
    }

    // MARK: - Keyboard

    /// Called by StreamView when the soft keyboard opens, changes height, or closes (height 0).
    @objc static func updateKeyboardOcclusion(_ height: CGFloat) {
        let newHeight = max(height, 0)
        guard abs(newHeight - keyboardOcclusion) > 0.5 else { return }
        guard let handler = active else {
            keyboardOcclusion = newHeight
            return
        }
        handler.keyboardOcclusionChanged(to: newHeight)
    }

    private func keyboardOcclusionChanged(to newHeight: CGFloat) {
        // Measured before the viewport shrinks, so it's what the user was looking at.
        let anchor = cursorLocationInitialized ? cursorLocation : (estimatedCursorLocation ?? visibleCenter)
        TouchpadZoomHandler.keyboardOcclusion = newHeight
        guard pinchZoomEnabled, scrollView != nil else { return }

        if newHeight > 0 {
            if !cursorLocationInitialized && keyboardAnchor == nil { keyboardAnchor = anchor }
            followCursor()
        } else {
            keyboardAnchor = nil
            if isZoomed { followCursor() } else { endZoom() }
        }
    }
}
