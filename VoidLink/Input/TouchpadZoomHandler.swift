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

    /// True while the magnifier widget (or a restored profile) has positioned the stream. Following the cursor
    /// then keeps that position reachable instead of snapping back to the video edges (see magnifierExtension).
    private var positionedByMagnifier: Bool {
        return StreamFrameViewController.sharedInstance()?.streamViewPositionedByMagnifier ?? false
    }

    /// How far (screen points, per axis) the magnifier had moved the view beyond the range cursor following allows.
    /// The follow range is widened by this on that side, so the view doesn't jump when zoom/following starts and
    /// the magnifier's position is kept, while following otherwise works as usual.
    private var magnifierExtension: CGVector?

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
            captureMagnifierExtensionIfNeeded()
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
    }

    /// Places the cursor at the center of the visible area.
    private func beginAbsoluteCursor() {
        cursorLocation = clampToVideoRect(keyboardAnchor ?? visibleCenter)
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

    private struct AxisRange {
        var lower: CGFloat
        var upper: CGFloat
        func clamp(_ value: CGFloat) -> CGFloat { min(max(value, lower), upper) }
    }

    /// Content offsets that keep the video's edges at or beyond the usable viewport's edges (just clear of the camera
    /// island, home indicator or keyboard), per axis, before any magnifier extension.
    private func followRanges() -> (x: AxisRange, y: AxisRange)? {
        guard let streamView = streamView, let scrollView = scrollView else { return nil }
        let insets = viewportInsets
        let viewport = usableViewport
        let video = streamView.convert(videoRect, to: scrollView)

        // `leadingInset` is the distance from the scroll view's visible edge to the usable viewport's edge.
        func axis(leadingInset: CGFloat, viewport: CGFloat, minEdge: CGFloat, maxEdge: CGFloat) -> AxisRange {
            let lower = minEdge - leadingInset
            let upper = maxEdge - viewport - leadingInset
            if upper < lower { // video smaller than the viewport: center it
                let centered = (minEdge + maxEdge) / 2 - viewport / 2 - leadingInset
                return AxisRange(lower: centered, upper: centered)
            }
            return AxisRange(lower: lower, upper: upper)
        }
        return (axis(leadingInset: insets.left, viewport: viewport.width, minEdge: video.minX, maxEdge: video.maxX),
                axis(leadingInset: insets.top, viewport: viewport.height, minEdge: video.minY, maxEdge: video.maxY))
    }

    /// Records how far the magnifier's current position lies outside the follow range. Call before changing the
    /// zoom or viewport. Recaptured if the magnifier moved the view since the last follow.
    private func captureMagnifierExtensionIfNeeded() {
        guard positionedByMagnifier else {
            magnifierExtension = nil
            return
        }
        guard let scrollView = scrollView, let ranges = followRanges() else { return }
        let current = scrollView.contentOffset
        if magnifierExtension != nil, let applied = appliedContentOffset,
           abs(applied.x - current.x) <= 0.5, abs(applied.y - current.y) <= 0.5 {
            return // the view is where we left it
        }
        magnifierExtension = CGVector(dx: current.x - ranges.x.clamp(current.x),
                                      dy: current.y - ranges.y.clamp(current.y))
    }

    /// Pans the visible area so `target` (default: the cursor) sits at the center of the usable viewport, stopping
    /// when an edge of the video reaches the edge of the usable viewport, widened by any magnifier extension.
    private func followCursor(target explicitTarget: CGPoint? = nil) {
        guard let streamView = streamView, let scrollView = scrollView, var ranges = followRanges() else { return }
        let target = explicitTarget ?? (cursorLocationInitialized ? cursorLocation : (keyboardAnchor ?? visibleCenter))
        if !positionedByMagnifier { magnifierExtension = nil }
        if let ext = magnifierExtension {
            ranges.x.lower += min(0, ext.dx); ranges.x.upper += max(0, ext.dx)
            ranges.y.lower += min(0, ext.dy); ranges.y.upper += max(0, ext.dy)
        }

        let insets = viewportInsets
        let viewport = usableViewport
        let targetInContent = streamView.convert(target, to: scrollView)
        let offset = CGPoint(x: ranges.x.clamp(targetInContent.x - viewport.width / 2 - insets.left),
                             y: ranges.y.clamp(targetInContent.y - viewport.height / 2 - insets.top))
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

        let sensitivity = max(TouchPadGestureHandler.pinchSensitivity, 0.05)
        let positioned = positionedByMagnifier
        let oldScale = currentZoomScale
        // The magnifier may have zoomed below 1x or beyond our maximum; don't snap its zoom level.
        let minScale = positioned ? min(1.0, max(oldScale, scrollView.minimumZoomScale)) : 1.0
        var maxScale = min(TouchpadZoomHandler.maximumZoomScale, scrollView.maximumZoomScale)
        if positioned { maxScale = max(maxScale, oldScale) }
        var newScale = oldScale * pow(ratio, sensitivity)
        newScale = min(max(newScale, minScale), maxScale)
        guard abs(newScale - oldScale) > 0.0001 else { return }

        if newScale <= 1.001 {
            if positioned && oldScale <= 1.001 {
                // below 1x (magnifier-shrunk stream): nothing to follow, zoom around the visible center
                cursorLocationInitialized = false
                StreamFrameViewController.sharedInstance()?.zoomMagnifierStreamView(byScaleRatio: newScale / oldScale)
            } else {
                endZoom()
            }
            return
        }

        // Zooming in from 1x: put the cursor at the center of the visible area.
        if !cursorLocationInitialized {
            beginAbsoluteCursor()
        }
        captureMagnifierExtensionIfNeeded()

        scrollView.zoomScale = newScale
        followCursor()
    }

    /// Returns to 1x and hands the cursor back to relative movement.
    /// While the keyboard is open, the cursor stays tracked so the view keeps following it above the keyboard.
    @objc func endZoom() {
        let keyboardOpen = TouchpadZoomHandler.keyboardOcclusion > 0
        let positioned = positionedByMagnifier
        if positioned { captureMagnifierExtensionIfNeeded() }
        let centerBeforeZoomOut = visibleCenter
        if !keyboardOpen {
            cursorLocationInitialized = false
            keyboardAnchor = nil
            relativeRemainder = .zero
        }
        guard let scrollView = scrollView else { return }
        scrollView.zoomScale = 1.0
        appliedContentOffset = .zero
        scrollView.contentOffset = .zero
        StreamFrameViewController.sharedInstance()?.updateMagnifierViewportMetrics()
        if keyboardOpen {
            followCursor()
        } else if positioned {
            // keep the magnifier's position instead of resetting: zoom out around the center, within its extension
            followCursor(target: centerBeforeZoomOut)
        }
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
        let anchor = cursorLocationInitialized ? cursorLocation : visibleCenter
        if pinchZoomEnabled { captureMagnifierExtensionIfNeeded() }
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
