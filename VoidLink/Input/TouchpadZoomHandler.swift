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
//  All methods must be called on the main thread.
//

import UIKit

@objc class TouchpadZoomHandler: NSObject {

    /// Enabled when the Pinch Gesture setting is "Zoom".
    @objc var pinchZoomEnabled: Bool = false

    @objc static let maximumZoomScale: CGFloat = 6.0

    private weak var streamView: StreamView?

    /// Cursor position in the (unzoomed) streamView coordinate space, only valid while zoomed.
    private var cursorLocation: CGPoint = .zero
    private var cursorLocationInitialized = false

    /// Sub-unit remainder carried between relative mouse move events.
    private var relativeRemainder: CGVector = .zero

    @objc init(streamView: StreamView) {
        self.streamView = streamView
        super.init()
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

    /// Center of the currently visible area, in streamView coordinates.
    private var visibleCenter: CGPoint {
        guard let streamView = streamView, let scrollView = scrollView else { return .zero }
        let center = CGPoint(x: scrollView.bounds.midX, y: scrollView.bounds.midY)
        return scrollView.convert(center, to: streamView)
    }

    // MARK: - Cursor output

    /// Moves the cursor by a touch delta measured in screen points (already multiplied by the pointer velocity factor).
    @objc func moveCursor(by delta: CGVector) {
        let zoomScale = currentZoomScale
        // Screen points -> streamView points. This keeps the cursor moving at the
        // same on-screen speed as the finger regardless of the zoom level.
        let streamDelta = CGVector(dx: delta.dx / zoomScale, dy: delta.dy / zoomScale)

        if isZoomed {
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
    }

    /// Places the cursor at the center of the visible area.
    private func beginAbsoluteCursor() {
        cursorLocation = clampToVideoRect(visibleCenter)
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

    /// Pans the visible area so the cursor sits at its center, stopping at the edges of the video.
    private func followCursor() {
        guard let streamView = streamView, let scrollView = scrollView else { return }
        let viewportSize = scrollView.bounds.size
        let cursorInContent = streamView.convert(cursorLocation, to: scrollView)
        let videoInContent = streamView.convert(videoRect, to: scrollView)

        func axisOffset(target: CGFloat, viewport: CGFloat, minEdge: CGFloat, maxEdge: CGFloat) -> CGFloat {
            let lower = minEdge
            let upper = maxEdge - viewport
            if upper < lower { return (minEdge + maxEdge) / 2 - viewport / 2 } // video smaller than viewport: center it
            return min(max(target - viewport / 2, lower), upper)
        }

        let offset = CGPoint(
            x: axisOffset(target: cursorInContent.x, viewport: viewportSize.width,
                          minEdge: videoInContent.minX, maxEdge: videoInContent.maxX),
            y: axisOffset(target: cursorInContent.y, viewport: viewportSize.height,
                          minEdge: videoInContent.minY, maxEdge: videoInContent.maxY))
        scrollView.contentOffset = offset
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
        if oldScale <= 1.001 || !cursorLocationInitialized {
            beginAbsoluteCursor()
        }

        scrollView.zoomScale = newScale
        followCursor()
    }

    /// Returns to 1x and hands the cursor back to relative movement.
    @objc func endZoom() {
        cursorLocationInitialized = false
        relativeRemainder = .zero
        guard let scrollView = scrollView else { return }
        scrollView.zoomScale = 1.0
        scrollView.contentOffset = .zero
        StreamFrameViewController.sharedInstance()?.updateMagnifierViewportMetrics()
    }
}
