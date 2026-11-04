//  RelativeTouchGestureHandler.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/5.
//  Also contributed by seastwood@github
//  Copyright © 2025 True砖家 on Bilibili & seastwood@github. All rights reserved.
//

import UIKit

@objc class RelativeTouchGestureHandler: NSObject {
    // Survives handler rebuilds, but does not carry over to a different stream view.
    private static weak var zoomViewportUsedInStreamView: StreamView?

    static func hasUsedZoomViewport(in streamView: StreamView?) -> Bool {
        guard let streamView else { return false }
        return zoomViewportUsedInStreamView === streamView
    }

    private let touchMode: TouchMode
    private let pinchGestureMode: TrackpadGestureMode
    private let ctrlDownForPinch: Bool
    private let scrollSensitivity: CGFloat
    private let pinchSensitivity: CGFloat
    private let enableHorizontalScroll = true
    private var ctrlDown = false
    private var scrollVector: CGVector = .zero
    private let scrollDeceleration: CGFloat
    private var inertialScrollTimer: SafeTimer?
    private var isInertialScrolling = false

    @objc init(streamView: StreamView, touchMode: TouchMode, settings: TemporarySettings) {
        self.streamView = streamView
        self.touchMode = touchMode
        // Absolute touch is gated by passthroughGestures in its owner; the picker only configures touchpad mode.
        pinchGestureMode = touchMode == .absolute ? .ctrlAndScroll
            : TrackpadGestureMode(rawValue: settings.trackpadGestureMode.intValue) ?? .ctrlAndScroll
        ctrlDownForPinch = settings.ctrlDownForPinch
        scrollSensitivity = CGFloat(settings.scrollSensitivity.doubleValue)
        pinchSensitivity = CGFloat(settings.pinchSensitivity.doubleValue)
        let rate = max(CGFloat(settings.framerate.intValue), 1)
        scrollDeceleration = rate > 110 ? 0.96 : 0.9
        super.init()
        if touchMode == .relative { Self.active = self }
        inertialScrollTimer = SafeTimer(interval: 1 / rate) { [weak self] in
            DispatchQueue.main.async { [weak self] in self?.inertialScrollTick() }
        }
    }

    deinit {
        inertialScrollTimer?.clean()
        if ctrlDown {
            LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_UP), 0)
        }
    }

    private enum TwoFingerIntent { case undecided, scroll, zoom }
    private var twoFingerIntent: TwoFingerIntent = .undecided
    // Where the two fingers were (window coordinates, unaffected by zoom) when the gesture started.
    private var intentTouchIDs: Set<ObjectIdentifier> = []
    private var intentStartLocations: [ObjectIdentifier: CGPoint] = [:]
    /// Finger travel (points) before a two-finger gesture is classified as zoom or scroll.
    private let intentDecisionTravel: CGFloat = 12

    /// Ends a touch gesture; absolute touch mode does not start scroll inertia.
    @objc func endGesture(startInertialScroll: Bool) {
        releasePinchModifier()
        resetTwoFingerIntent()
        if startInertialScroll {
            isInertialScrolling = true
            inertialScrollTimer?.restart()
        }
    }

    private func releasePinchModifier() {
        guard ctrlDown else { return }
        LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_UP), 0)
        ctrlDown = false
    }

    private func stopInertialScrolling() {
        isInertialScrolling = false
        inertialScrollTimer?.pause()
    }

    private func inertialScrollTick() {
        guard isInertialScrolling else { return }
        scrollVector.dx *= scrollDeceleration
        scrollVector.dy *= scrollDeceleration
        if abs(scrollVector.dx) < 0.06, abs(scrollVector.dy) < 0.06 {
            stopInertialScrolling()
        }
        guard !ctrlDown else { return }
        LiSendHighResScrollEvent(Int16(scrollVector.dy * 7 * scrollSensitivity))
        if enableHorizontalScroll {
            LiSendHighResHScrollEvent(Int16(-scrollVector.dx * 7 * scrollSensitivity))
        }
    }

    private func resetTwoFingerIntent() {
        twoFingerIntent = .undecided
        intentTouchIDs = []
        intentStartLocations = [:]
    }

    /// Classifies a two-finger gesture from each finger's net movement since it started, so frame-to-frame jitter
    /// doesn't count. Scrolling moves both fingers the same way; pinching changes the distance between them much
    /// more than it moves their midpoint. Returns nil until the fingers have moved far enough to tell.
    private func classifyTwoFingerIntent(_ touch1: UITouch, _ touch2: UITouch) -> TwoFingerIntent? {
        let id1 = ObjectIdentifier(touch1), id2 = ObjectIdentifier(touch2)
        let p1 = touch1.location(in: nil), p2 = touch2.location(in: nil)
        if intentTouchIDs != [id1, id2] {
            // new pair of fingers (or the second finger just landed): start measuring from here
            intentTouchIDs = [id1, id2]
            intentStartLocations = [id1: p1, id2: p2]
            return nil
        }
        guard let s1 = intentStartLocations[id1], let s2 = intentStartLocations[id2] else { return nil }

        let v1 = CGVector(dx: p1.x - s1.x, dy: p1.y - s1.y)
        let v2 = CGVector(dx: p2.x - s2.x, dy: p2.y - s2.y)
        let len1 = hypot(v1.dx, v1.dy), len2 = hypot(v2.dx, v2.dy)
        guard max(len1, len2) >= intentDecisionTravel else { return nil }

        // Both fingers moving in roughly the same direction: always a scroll.
        if len1 > 4, len2 > 4 {
            let cosine = (v1.dx*v2.dx + v1.dy*v2.dy) / (len1*len2)
            if cosine > 0.3 { return .scroll }
        }

        let distanceChange = abs(hypot(p1.x - p2.x, p1.y - p2.y) - hypot(s1.x - s2.x, s1.y - s2.y))
        let midpointTravel = hypot((v1.dx + v2.dx)/2, (v1.dy + v2.dy)/2)
        // A pinch with one finger still gives distanceChange ≈ 2 × midpointTravel; a two-finger pinch much more.
        return distanceChange >= midpointTravel*1.5 ? .zoom : .scroll
    }

    @objc func handleGesture(with event: UIEvent) {
        guard let view = streamView else { return }
        stopInertialScrolling()

        let currentTouches = UITouchUtil.touches(in: view, from: event)
        guard currentTouches.count == 2 else { return }

        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_LEFT)
        LiSendMouseButtonEvent(CChar(BUTTON_ACTION_RELEASE), BUTTON_RIGHT)

        guard let touch1 = currentTouches.first else { return }
        var mutable = Array(currentTouches)
        mutable.removeAll { $0 == touch1 }
        guard let touch2 = mutable.first else { return }

        let currentDistance = UITouchUtil.distance(between: touch1, and: touch2, in: view)
        let previousDistance = UITouchUtil.previousDistance(between: touch1, and: touch2, in: view)

        let midPointVector = UITouchUtil.midPointVector(between: touch1, and: touch2, in: view)
        let midPointDeltaX = midPointVector.dx
        let midPointDeltaY = midPointVector.dy

        let sendHorizontalScroll = abs(midPointDeltaX) > 1.2*abs(midPointDeltaY)

        if canZoomViewport {
            Self.zoomViewportUsedInStreamView = view
            // Decide once per two-finger gesture whether it's a zoom or a scroll, so they don't fight each other.
            if twoFingerIntent == .undecided, let intent = classifyTwoFingerIntent(touch1, touch2) {
                twoFingerIntent = intent
                if intent == .scroll {
                    // Keep the existing behavior: start emitting scroll on the next move.
                    scrollVector = CGVector(dx: sendHorizontalScroll ? midPointDeltaX : 0, dy: midPointDeltaY)
                    return
                }
            }
            if twoFingerIntent != .scroll {
                scrollVector = .zero
                if twoFingerIntent == .zoom, previousDistance > 0 {
                    applyPinch(ratio: currentDistance/previousDistance)
                }
                return
            }
        }

        scrollVector = CGVector(dx: sendHorizontalScroll ? midPointDeltaX : 0, dy: midPointDeltaY)

        sendScroll(pinchDelta: currentDistance-previousDistance, midPointDelta: midPointVector)
    }

    private func sendScroll(pinchDelta originalPinchDelta: CGFloat, midPointDelta: CGVector) {
        let midPointDeltaX = midPointDelta.dx
        let midPointDeltaY = midPointDelta.dy
        let sendHorizontalScroll = abs(midPointDeltaX) > 1.2*abs(midPointDeltaY)

        let pinchDelta = (pinchGestureMode == .ctrlAndScroll) ? originalPinchDelta*7*pinchSensitivity : 0;
        LiSendHighResScrollEvent(Int16(pinchDelta + midPointDeltaY*7*scrollSensitivity))
        if enableHorizontalScroll, sendHorizontalScroll {LiSendHighResHScrollEvent(Int16(-midPointDeltaX*7*scrollSensitivity))}

        if pinchGestureMode == .ctrlAndScroll, ctrlDownForPinch {
            let midPointDelta = hypot(midPointDeltaX, midPointDeltaY)
            if abs(originalPinchDelta) > midPointDelta*1.3, midPointDelta < 2 {
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_DOWN), 0)
                ctrlDown = true
            } else {
                LiSendKeyboardEvent(CommandManager.keyboardButtonMappings["CTRL"]!, CChar(KEY_ACTION_UP), 0)
                ctrlDown = false
            }
        }
    }

    // MARK: - Cursor and viewport

    @objc static let maximumZoomScale: CGFloat = PublicUtils.isIPhone ? 3 : 6.0

    /// Height of the stream area covered by the soft keyboard (including its accessory bar), 0 when closed.
    private static var keyboardOcclusion: CGFloat = 0
    /// The handler of the current touchpad session, which receives keyboard occlusion changes.
    private static weak var active: RelativeTouchGestureHandler?

    private weak var streamView: StreamView?

    /// The library's virtual cursor mapped into unzoomed streamView coordinates.
    private var cursorLocation: CGPoint {
        var x: Float = 0
        var y: Float = 0
        LiGetMousePosition(&x, &y)
        let rect = videoRect
        return CGPoint(x: rect.minX + CGFloat(x) * rect.width,
                       y: rect.minY + CGFloat(y) * rect.height)
    }
    private var cursorLocationInitialized = false
    /// Point kept centered while the keyboard is open before the cursor has been moved (the cursor isn't tracked yet).
    private var keyboardAnchor: CGPoint?
    /// Last content offset set by followCursor; restored if UIKit scrolls the view while the keyboard is open.
    private var appliedContentOffset: CGPoint?

    /// Sub-unit remainder carried between relative mouse move events.
    private var relativeRemainder: CGVector = .zero
    /// Fractional input on the absolute reference plane, not a second cursor position.
    private var absoluteRemainder: CGVector = .zero

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

    /// True while viewport zoom is selected in touchpad mode and the stream is zoomed in.
    @objc var isZoomed: Bool {
        return canZoomViewport && currentZoomScale > 1.001
    }

    private var canZoomViewport: Bool {
        touchMode == .relative && pinchGestureMode == .zoomViewport
    }

    /// Keep the keyboard-covered area clear without adding safe-area insets.
    private var viewportInsets: UIEdgeInsets {
        UIEdgeInsets(top: 0, left: 0, bottom: Self.keyboardOcclusion, right: 0)
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

    /// Applies a cursor delta with sensitivity and device/mode velocity multipliers already applied.
    @objc func moveCursor(by delta: CGVector) {
        let streamDelta = CGVector(dx: delta.dx, dy: delta.dy)
        if canZoomViewport {
            Self.zoomViewportUsedInStreamView = streamView
            if !cursorLocationInitialized { beginAbsoluteCursor() }
            let rect = videoRect
            if rect.width > 0, rect.height > 0 {
                let referenceScale = 32766.0 / max(rect.width, rect.height)
                absoluteRemainder.dx += streamDelta.dx * referenceScale
                absoluteRemainder.dy += streamDelta.dy * referenceScale
                let deltaX = Int16(clamping: Int(absoluteRemainder.dx.rounded(.towardZero)))
                let deltaY = Int16(clamping: Int(absoluteRemainder.dy.rounded(.towardZero)))
                if deltaX != 0 || deltaY != 0 {
                    absoluteRemainder.dx -= CGFloat(deltaX)
                    absoluteRemainder.dy -= CGFloat(deltaY)
                    _ = LiSendMouseMoveAsMousePositionEvent(
                        deltaX, deltaY,
                        Int16(clamping: Int((rect.width * referenceScale).rounded())),
                        Int16(clamping: Int((rect.height * referenceScale).rounded())))
                }
            }
            followCursor()
            return
        }

        let relativePointerGain = LiGetHostMacTrackpadSimulation() ? 1.5 : 1.0
        relativeRemainder.dx += streamDelta.dx * relativePointerGain
        relativeRemainder.dy += streamDelta.dy * relativePointerGain
        let deltaX = relativeRemainder.dx.rounded(.towardZero)
        let deltaY = relativeRemainder.dy.rounded(.towardZero)
        guard deltaX != 0 || deltaY != 0 else { return }
        relativeRemainder.dx -= deltaX
        relativeRemainder.dy -= deltaY
        LiSendMouseMoveEvent(Int16(clamping: Int(deltaX)), Int16(clamping: Int(deltaY)))
    }

    /// Keep the library's normalized cursor when entering zoom or rebuilding after rotation.
    /// The visible center may lie outside the video when the portrait stream position is offset.
    private func beginAbsoluteCursor() {
        let location = clampToVideoRect(keyboardAnchor ?? cursorLocation)
        keyboardAnchor = nil
        cursorLocationInitialized = true
        absoluteRemainder = .zero
        sendAbsoluteCursorPosition(location)
    }

    private func sendAbsoluteCursorPosition(_ location: CGPoint) {
        let rect = videoRect
        guard rect.width > 0, rect.height > 0 else { return }
        // Use a reference area finer than screen points so slow movements at high zoom stay smooth.
        let referenceScale = 32766.0 / max(rect.width, rect.height)
        let referenceWidth = (rect.width * referenceScale).rounded()
        let referenceHeight = (rect.height * referenceScale).rounded()
        let x = ((location.x - rect.minX) * referenceScale).rounded()
        let y = ((location.y - rect.minY) * referenceScale).rounded()
        LiSendMousePositionEvent(Int16(clamping: Int(x)), Int16(clamping: Int(y)),
                                 Int16(clamping: Int(referenceWidth)), Int16(clamping: Int(referenceHeight)))
    }

    /// Follow only when the cursor leaves the centered region, which contracts as zoom increases.
    /// Pan just enough to keep it at that region's edge, subject to the video boundaries.
    private func followCursor() {
        guard canZoomViewport, isZoomed || Self.keyboardOcclusion > 0 else { return }
        guard let streamView = streamView, let scrollView = scrollView else { return }
        Self.zoomViewportUsedInStreamView = streamView
        let target = cursorLocationInitialized ? cursorLocation : (keyboardAnchor ?? visibleCenter)
        let insets = viewportInsets
        let viewport = usableViewport
        let baseInsetScale = PublicUtils.isIPhone ? 0.1 : 0.1
        let insetScale = baseInsetScale + (0.5-baseInsetScale) * (scrollView.zoomScale-1)/(RelativeTouchGestureHandler.maximumZoomScale - 1)
        let followRegion = viewport.insetBy(dx: viewport.width * insetScale, dy: viewport.height * insetScale)
        let cursorInContent = streamView.convert(target, to: scrollView)
        let videoInContent = streamView.convert(videoRect, to: scrollView)
        let currentOffset = scrollView.contentOffset

        func axisOffset(target: CGFloat, current: CGFloat, followMin: CGFloat, followMax: CGFloat,
                        minEdge: CGFloat, maxEdge: CGFloat, viewportLength: CGFloat,
                        leadingInset: CGFloat) -> CGFloat {
            let overflow = target - min(max(target, followMin), followMax)
            let leading = minEdge - leadingInset
            let trailing = maxEdge - viewportLength - leadingInset
            // Cover the viewport when possible; otherwise keep the entire video visible.
            return min(max(current + overflow, min(leading, trailing)), max(leading, trailing))
        }

        let offset = CGPoint(
            x: axisOffset(target: cursorInContent.x, current: currentOffset.x,
                          followMin: followRegion.minX, followMax: followRegion.maxX,
                          minEdge: videoInContent.minX, maxEdge: videoInContent.maxX,
                          viewportLength: viewport.width, leadingInset: insets.left),
            y: axisOffset(target: cursorInContent.y, current: currentOffset.y,
                          followMin: followRegion.minY, followMax: followRegion.maxY,
                          minEdge: videoInContent.minY, maxEdge: videoInContent.maxY,
                          viewportLength: viewport.height, leadingInset: insets.top))
        appliedContentOffset = offset
        scrollView.contentOffset = offset
    }

    /// Called from the scroll view delegate. The hidden text field that receives keyboard input lives inside the
    /// scroll view, and UIKit scrolls text fields into view while typing; undo that while the keyboard is open.
    @objc static func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard keyboardOcclusion > 0, let handler = active, handler.canZoomViewport,
              handler.scrollView === scrollView, let offset = handler.appliedContentOffset else { return }
        if abs(scrollView.contentOffset.x - offset.x) > 0.5 || abs(scrollView.contentOffset.y - offset.y) > 0.5 {
            scrollView.contentOffset = offset
        }
    }

    // MARK: - Pinch

    /// Applies a pinch step. `ratio` is the current finger distance divided by the previous one.
    @objc func applyPinch(ratio: CGFloat) {
        guard canZoomViewport, let streamView = streamView, let scrollView = scrollView,
              ratio.isFinite, ratio > 0 else { return }

        let oldScale = currentZoomScale
        let sensitivity = max(pinchSensitivity, 0.05)
        let maxScale = min(RelativeTouchGestureHandler.maximumZoomScale, scrollView.maximumZoomScale)
        var newScale = oldScale * pow(ratio, sensitivity)
        newScale = min(max(newScale, 1.0), maxScale)
        guard abs(newScale - oldScale) > 0.0001 else { return }

        if newScale <= 1.001 {
            endZoom()
            return
        }

        // Initialize the library cursor before choosing the zoom anchor.
        if !cursorLocationInitialized {
            beginAbsoluteCursor()
        }

        let anchor = cursorLocation
        let previousOffset = scrollView.contentOffset
        let before = streamView.convert(anchor, to: scrollView)
        let positionInViewport = CGPoint(x: before.x - scrollView.bounds.minX,
                                        y: before.y - scrollView.bounds.minY)
        scrollView.zoomScale = newScale
        let after = streamView.convert(anchor, to: scrollView)
        var offset = CGPoint(x: after.x - positionInViewport.x,
                             y: after.y - positionInViewport.y)
        if newScale < oldScale && Self.keyboardOcclusion == 0 {
            // Return continuously to the configured 1x position. Clamping to the video edges here
            // can jump on the first shrinking step, since zooming in preserves the cursor anchor.
            let restingOffset = StreamFrameViewController.sharedInstance()?.restingStreamViewOffset() ?? .zero
            let remainingZoom = (newScale - 1) / (oldScale - 1)
            offset = CGPoint(x: restingOffset.x + (previousOffset.x - restingOffset.x) * remainingZoom,
                             y: restingOffset.y + (previousOffset.y - restingOffset.y) * remainingZoom)
        }
        let insets = scrollView.contentInset
        offset.x = min(max(offset.x, -insets.left),
                       max(scrollView.contentSize.width - scrollView.bounds.width + insets.right, -insets.left))
        offset.y = min(max(offset.y, -insets.top),
                       max(scrollView.contentSize.height - scrollView.bounds.height + insets.bottom, -insets.top))
        // Update this first so keyboard scroll protection accepts the anchored offset.
        appliedContentOffset = offset
        scrollView.contentOffset = offset
    }

    /// Returns the viewport to 1x. Cursor output continues to follow the selected pinch mode.
    @objc func endZoom() {
        let keyboardOpen = RelativeTouchGestureHandler.keyboardOcclusion > 0
        if !keyboardOpen {
            cursorLocationInitialized = false
            keyboardAnchor = nil
            relativeRemainder = .zero
            absoluteRemainder = .zero
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
        let anchor = cursorLocation
        RelativeTouchGestureHandler.keyboardOcclusion = newHeight
        guard canZoomViewport, scrollView != nil else { return }

        if newHeight > 0 {
            if !cursorLocationInitialized && keyboardAnchor == nil { keyboardAnchor = anchor }
            followCursor()
        } else {
            keyboardAnchor = nil
            if isZoomed { followCursor() } else { endZoom() }
        }
    }
}
