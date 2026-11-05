import UIKit

/// Sends native multi-touch gestures delegated by RelativeTouchHandler.
@objc class TrackpadTouchHandler: UIResponder {
    private weak var streamView: StreamView?
    private var gestureSensitivity: CGFloat
    private let sender: TrackpadTouchSender
    // UIKit coordinates and mapping objects are accessed only on the main thread.
    private var pointers: [ObjectIdentifier: NativeTouchPointer] = [:]
    private var normalizationBounds: CGRect?
    private var stoppedUntilReset = false
    private enum MacGestureMode { case magnify, horizontal, vertical }
    private struct MacPairSample {
        let ids: Set<ObjectIdentifier>
        let firstID: ObjectIdentifier
        let midpoint: CGPoint
        let separation: CGVector
        let distance: CGFloat
        let time: TimeInterval

        func rotation(from previous: Self) -> CGFloat {
            guard previous.distance > 0, distance > 0 else { return 0 }
            let direction: CGFloat = firstID == previous.firstID ? 1 : -1
            let x = separation.dx * direction
            let y = separation.dy * direction
            let cross = previous.separation.dx * y - previous.separation.dy * x
            let dot = previous.separation.dx * x + previous.separation.dy * y
            return -atan2(cross, dot)
        }
    }

    private let macPinchSpeedDifference: CGFloat = 25
    private let macDecisionIntervals: Int
    private var macPreviousSample: MacPairSample?
    private var macDecisionStart: MacPairSample?
    private var macIntervalCount = 0
    private var macSeparationTravel: CGFloat = 0
    private var macMidpointTravel: CGFloat = 0
    private var macAxisTravel = CGVector.zero
    private var macGestureMode: MacGestureMode?
    private var macMagnifying = false
    private var macRotating = false
    private var macRotationReady = false
    private var macScrollRemainder = CGVector.zero

    @objc init(view: StreamView, settings: TemporarySettings) {
        streamView = view
        gestureSensitivity = max(0.05, CGFloat(settings.trackpadGestureSensitivity.floatValue))
        macDecisionIntervals = PublicUtils.refreshRate >= 120 ? 4 : 2
        sender = TrackpadTouchSender(interpolateMoves: PublicUtils.refreshRate == 60)
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if LiGetHostMacTrackpadSimulation() {
            resetMacSampling()
            macPreviousSample = macPairSample(with: event)
            return
        }
        enqueue(touches, with: event, eventType: UInt8(LI_TOUCH_EVENT_DOWN))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if LiGetHostMacTrackpadSimulation() {
            handleMacTrackpad(with: event)
            return
        }
        enqueue(touches, with: event, eventType: UInt8(LI_TOUCH_EVENT_MOVE))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if LiGetHostMacTrackpadSimulation() {
            endMacTrackpad(touches, with: event, cancelled: false)
            return
        }
        endTouches(touches, with: event, eventType: UInt8(LI_TOUCH_EVENT_UP))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if LiGetHostMacTrackpadSimulation() {
            endMacTrackpad(touches, with: event, cancelled: true)
            return
        }
        endTouches(touches, with: event, eventType: UInt8(LI_TOUCH_EVENT_CANCEL))
    }

    private func macPairSample(with event: UIEvent?) -> MacPairSample? {
        guard let view = streamView, let event else { return nil }
        let captured = OnScreenControls.touchesCapturedByOnScreenControls()
        let touches = (event.touches(for: view) ?? []).filter {
            $0.type == .direct && $0.phase != .ended && $0.phase != .cancelled &&
            captured?.contains($0) != true
        }
        guard touches.count == 2, let first = touches.first,
              let second = touches.first(where: { $0 !== first }) else { return nil }
        let a = first.location(in: view)
        let b = second.location(in: view)
        let firstID = ObjectIdentifier(first)
        let separation = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        return MacPairSample(
            ids: [firstID, ObjectIdentifier(second)],
            firstID: firstID,
            midpoint: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2),
            separation: separation,
            distance: hypot(separation.dx, separation.dy),
            time: event.timestamp
        )
    }

    private func resetMacSampling() {
        macPreviousSample = nil
        macDecisionStart = nil
        macIntervalCount = 0
        macSeparationTravel = 0
        macMidpointTravel = 0
        macAxisTravel = .zero
    }

    private func handleMacTrackpad(with event: UIEvent?) {
        guard let sample = macPairSample(with: event) else {
            resetMacSampling()
            return
        }
        guard let previous = macPreviousSample, previous.ids == sample.ids else {
            resetMacSampling()
            macPreviousSample = sample
            return
        }
        let elapsed = CGFloat(sample.time - previous.time)
        guard elapsed > 0 else { return }
        macPreviousSample = sample

        var outputBaseline = previous
        if macGestureMode == nil {
            let dx = sample.midpoint.x - previous.midpoint.x
            let dy = sample.midpoint.y - previous.midpoint.y
            macSeparationTravel += abs(sample.distance - previous.distance)
            macMidpointTravel += hypot(dx, dy)
            macAxisTravel.dx += abs(dx)
            macAxisTravel.dy += abs(dy)
            macIntervalCount += 1
            let start = macDecisionStart ?? previous
            macDecisionStart = start
            guard macIntervalCount == macDecisionIntervals else {
                if macRotationReady {
                    sendMacRotation(from: previous, to: sample)
                }
                return
            }

            let margin = macPinchSpeedDifference * CGFloat(sample.time - start.time)
            if start.distance > 0 && macSeparationTravel - macMidpointTravel >= margin {
                macGestureMode = .magnify
            } else if macMidpointTravel > 0 {
                macGestureMode = macAxisTravel.dx > macAxisTravel.dy ? .horizontal : .vertical
            }
            outputBaseline = start
            resetMacSampling()
            macPreviousSample = sample
        }

        let previousDistance = outputBaseline.distance
        let separationDelta = sample.distance - previousDistance
        let midpointDelta = CGVector(dx: sample.midpoint.x - outputBaseline.midpoint.x,
                                     dy: sample.midpoint.y - outputBaseline.midpoint.y)
        switch macGestureMode {
        case .magnify:
            if previousDistance > 0, separationDelta != 0 {
                if !macMagnifying {
                    finishMacRotation(phase: UInt8(LI_MAC_MAGNIFY_END))
                    guard !macRotating else { return }
                    macMagnifying = LiSendMacMagnifyEvent(UInt8(LI_MAC_MAGNIFY_BEGIN), 0) == 0
                }
                if macMagnifying {
                    let amount = (separationDelta / previousDistance) * gestureSensitivity * 0.7
                    _ = LiSendMacMagnifyEvent(UInt8(LI_MAC_MAGNIFY_CHANGE), Float(max(amount, -0.99)))
                }
            }
        case .horizontal:
            let amount = macScrollRemainder.dx + midpointDelta.dx * gestureSensitivity * 5.5
            let delta = scrollUnits(amount)
            macScrollRemainder.dx = amount - CGFloat(delta)
            if delta != 0 { LiSendHighResHScrollEvent(delta) }
        case .vertical:
            let amount = macScrollRemainder.dy + midpointDelta.dy * gestureSensitivity * 5.5
            let delta = scrollUnits(amount)
            macScrollRemainder.dy = amount - CGFloat(delta)
            if delta != 0 { LiSendHighResScrollEvent(delta) }
        case nil:
            break
        }

        guard macGestureMode != .magnify || macMagnifying else { return }
        sendMacRotation(from: macRotationReady ? previous : outputBaseline, to: sample)
        macRotationReady = true
    }

    private func sendMacRotation(from previous: MacPairSample, to sample: MacPairSample) {
        guard LiGetHostMacTrackpadRotate() else { return }
        let degrees = sample.rotation(from: previous) * 180 / .pi
        guard degrees != 0 else { return }
        if !macRotating {
            macRotating = LiSendMacRotateEvent(UInt8(LI_MAC_MAGNIFY_BEGIN), 0) == 0
        }
        if macRotating {
            _ = LiSendMacRotateEvent(UInt8(LI_MAC_MAGNIFY_CHANGE), Float(degrees))
        }
    }

    private func endMacTrackpad(_ touches: Set<UITouch>, with event: UIEvent?, cancelled: Bool) {
        resetMacSampling()
        if let view = streamView, (event?.touches(for: view) ?? []).subtracting(touches).contains(where: {
            $0.type == .direct && $0.phase != .ended && $0.phase != .cancelled
        }) {
            return
        }
        finishMacGestures(cancelled: cancelled)
        macGestureMode = nil
        macScrollRemainder = .zero
    }

    private func scrollUnits(_ amount: CGFloat) -> Int16 {
        Int16(min(max(amount.rounded(.towardZero), CGFloat(Int16.min)), CGFloat(Int16.max)))
    }

    private func finishMacGestures(cancelled: Bool) {
        let phase = UInt8(cancelled ? LI_MAC_MAGNIFY_CANCEL : LI_MAC_MAGNIFY_END)
        if macMagnifying, LiSendMacMagnifyEvent(phase, 0) == 0 {
            macMagnifying = false
        }
        finishMacRotation(phase: phase)
        macRotationReady = false
    }

    private func finishMacRotation(phase: UInt8) {
        if macRotating, LiSendMacRotateEvent(phase, 0) == 0 {
            macRotating = false
        }
    }

    private func endTouches(_ touches: Set<UITouch>, with event: UIEvent?, eventType: UInt8) {
        guard !stoppedUntilReset, let streamView else { return }
        let capturedTouches = OnScreenControls.touchesCapturedByOnScreenControls()
        // UITouchUtil includes the contacts ending in this event. Subtract them
        // before counting the valid fingers that remain on the surface.
        let remainingTouches = UITouchUtil.touches(in: streamView, from: event)
            .subtracting(touches).filter {
                $0.type == .direct && $0.phase != .ended && $0.phase != .cancelled &&
                capturedTouches?.contains($0) != true
            }
        let stop = remainingTouches.count == 1
        enqueue(stop ? touches.union(remainingTouches) : touches, with: event, eventType: eventType)
        if stop {
            pointers.removeAll()
            normalizationBounds = nil
            // RelativeTouchHandler keeps its multi-touch latch until every finger
            // lifts, then calls reset. Ignore even newly added fingers until then.
            stoppedUntilReset = true
        }
    }

    private func enqueue(_ touches: Set<UITouch>, with event: UIEvent?, eventType: UInt8) {
        guard !stoppedUntilReset, let streamView else { return }
        let bounds = streamView.bounds
        let beginning = eventType == UInt8(LI_TOUCH_EVENT_DOWN)
        let ending = eventType == UInt8(LI_TOUCH_EVENT_UP) || eventType == UInt8(LI_TOUCH_EVENT_CANCEL)
        let capturedTouches = OnScreenControls.touchesCapturedByOnScreenControls()
        var samples: [ObjectIdentifier: TrackpadTouchSample] = [:]
        let startingGesture = pointers.isEmpty

        // Match the sender's five-contact limit when registering new contacts.
        if beginning && bounds.width > 0 && bounds.height > 0 {
            for touch in touches.sorted(by: { $0.timestamp < $1.timestamp }) where touch.type == .direct {
                let key = ObjectIdentifier(touch)
                guard capturedTouches?.contains(touch) != true,
                      pointers[key] == nil, pointers.count < 5 else { continue }
                if normalizationBounds == nil {
                    // All contacts share a fixed square for this gesture. Its
                    // center is the first accepted contact, even near view edges.
                    let center = touch.location(in: streamView)
                    let side = (PublicUtils.isIPhone ? 393 : 460) / gestureSensitivity
                    normalizationBounds = CGRect(x: center.x - side / 2, y: center.y - side / 2, width: side, height: side)
                }
                pointers[key] = NativeTouchPointer(touch: touch, view: streamView)
            }
        }

        if beginning && startingGesture && pointers.count == 2, let normalizationBounds {
            // Center the pair horizontally, preserving its physical separation
            // up to the square's width. Keep physical movement baselines intact.
            let orderedPointers = pointers.values.sorted {
                $0.initialPoint.x == $1.initialPoint.x
                    ? $0.initialPoint.y < $1.initialPoint.y
                    : $0.initialPoint.x < $1.initialPoint.x
            }
            let first = orderedPointers[0].initialPoint
            let second = orderedPointers[1].initialPoint
            // Preserve the real midpoint's vertical position in the view. Both
            // coordinate systems increase downward: top is 0, bottom is 1.
            let midpointY = (first.y + second.y) / 2
            let normalizedMidpointY = min(max((midpointY - bounds.minY) / bounds.height, 0), 1)
            let initialY = normalizationBounds.minY + normalizedMidpointY * normalizationBounds.height
            let initialDistance = min(hypot(second.x - first.x, second.y - first.y),
                                      normalizationBounds.width)
            for (index, pointer) in orderedPointers.enumerated() {
                pointer.latestRelativePoint = CGPoint(
                    x: normalizationBounds.midX + (index == 0 ? -initialDistance / 2 : initialDistance / 2),
                    y: initialY)
            }
        }

        // A single changed finger still moves both synthetic contacts. Send the
        // pair in the same frame so the host sees the constrained gesture.
        let pairGesture = eventType == UInt8(LI_TOUCH_EVENT_MOVE)
            ? updateTwoFingerGesture(with: event, in: streamView) : nil
        let sampledTouches = pairGesture?.touches ?? touches

        // Read UIKit and OSC state before crossing the asynchronous boundary. In
        // particular, a UITouch can have changed again by the time the worker runs.
        for touch in sampledTouches {
            let key = ObjectIdentifier(touch)
            defer {
                if ending { pointers.removeValue(forKey: key) }
            }
            let captured = capturedTouches?.contains(touch) == true
            if ending && captured { capturedTouches?.remove(touch) }
            guard touch.type == .direct, !captured,
                  bounds.width > 0, bounds.height > 0,
                  let pointer = pointers[key],
                  let normalizationBounds else { continue }
            if !beginning && pairGesture == nil {
                // UP/CANCEL keep the last mapped position instead of adding an
                // unconstrained physical delta at the end of a gesture.
                pointer.update(touch: touch, in: streamView,
                               velocityFactor: ending ? 0 : 0.47)
            }
            let point = pointer.latestRelativePoint
            let pressure = touch.maximumPossibleForce > 0
                ? touch.force / touch.maximumPossibleForce : 0
            samples[ObjectIdentifier(touch)] = TrackpadTouchSample(
                x: Float(min(max((point.x - normalizationBounds.minX) / normalizationBounds.width, 0), 1)),
                y: Float(min(max((point.y - normalizationBounds.minY) / normalizationBounds.height, 0), 1)),
                pressure: Float(min(max(pressure, 0), 1)))
        }
        sender.enqueue(TrackpadTouchBatch(touches: sampledTouches, samples: samples,
                                         eventType: eventType, allowsInterpolation: pairGesture?.pinch != true))
        if pointers.isEmpty { normalizationBounds = nil }
    }

    private func updateTwoFingerGesture(with event: UIEvent?, in view: StreamView) -> (touches: Set<UITouch>, pinch: Bool)? {
        guard pointers.count == 2, let normalizationBounds else { return nil }
        let capturedTouches = OnScreenControls.touchesCapturedByOnScreenControls()
        let touches = UITouchUtil.touches(in: view, from: event).filter {
            pointers[ObjectIdentifier($0)] != nil &&
            ($0.phase == .moved || $0.phase == .stationary) &&
            capturedTouches?.contains($0) != true
        }
        guard touches.count == 2 else { return nil }
        // Initial ordering stays stable even if the physical fingers cross.
        let ordered = touches.sorted {
            let a = pointers[ObjectIdentifier($0)]!.initialPoint
            let b = pointers[ObjectIdentifier($1)]!.initialPoint
            return a.x == b.x ? a.y < b.y : a.x < b.x
        }
        let first = ordered[0], second = ordered[1]
        let distanceDelta = UITouchUtil.distance(between: first, and: second, in: view)
            - UITouchUtil.previousDistance(between: first, and: second, in: view)
        let midpointDelta = UITouchUtil.midPointVector(between: first, and: second, in: view)
        // Both deltas cover the same event interval, so comparing distance change
        // with midpoint travel also compares their speeds without dividing by time.
        let pinch = abs(distanceDelta) > hypot(midpointDelta.dx, midpointDelta.dy) + 0.2
        let midpointX = (pointers[ObjectIdentifier(first)]!.latestRelativePoint.x
            + pointers[ObjectIdentifier(second)]!.latestRelativePoint.x) / 2
        for (index, touch) in ordered.enumerated() {
            let pointer = pointers[ObjectIdentifier(touch)]!
            pointer.update(touch: touch, in: view, velocityFactor: 0)
            var point = pointer.latestRelativePoint
            if pinch {
                // Pinch uses a canvas 1/1.3 as wide as the pan canvas.
                let pinchSide = normalizationBounds.width / 1.75
                let normalizedHalfDelta = distanceDelta / (2 * pinchSide)
                let halfDelta = normalizedHalfDelta * normalizationBounds.width
                // Clamp the accumulated coordinates so reopening responds
                // immediately, even after pinching against the center axis.
                point.x = index == 0
                    ? min(point.x - halfDelta, midpointX)
                    : max(point.x + halfDelta, midpointX)
            } else {
                point.x += midpointDelta.dx
                point.y += midpointDelta.dy
            }
            pointer.latestRelativePoint = point
        }
        return (touches, pinch)
    }

    /// Release remote contacts when replacing the handler or ending the session.
    @objc func reset() {
        finishMacGestures(cancelled: true)
        macGestureMode = nil
        resetMacSampling()
        macScrollRemainder = .zero
        stoppedUntilReset = false
        pointers.removeAll()
        normalizationBounds = nil
        sender.reset()
    }

    deinit {
        if macMagnifying {
            _ = LiSendMacMagnifyEvent(UInt8(LI_MAC_MAGNIFY_CANCEL), 0)
        }
        if macRotating {
            _ = LiSendMacRotateEvent(UInt8(LI_MAC_MAGNIFY_CANCEL), 0)
        }
        sender.reset()
    }
}

private nonisolated struct TrackpadTouchSample: Sendable {
    let x: Float
    let y: Float
    let pressure: Float
}

// Keep the original touch instances alive until the asynchronous traversal ends.
// The worker only uses their identity; every UIKit property is read on MainActor.
private nonisolated struct TrackpadTouchBatch: @unchecked Sendable {
    let touches: Set<UITouch>
    let samples: [ObjectIdentifier: TrackpadTouchSample]
    let eventType: UInt8
    let allowsInterpolation: Bool
}

private nonisolated final class TrackpadTouchSender: @unchecked Sendable {
    // Serialize on a global executor so DOWN/MOVE/UP and ID reuse cannot race.
    private let queue = DispatchQueue(label: "com.voidlink.trackpad-touch",
                                      qos: .userInteractive,
                                      target: .global(qos: .userInteractive))
    // Accessed exclusively on queue.
    private let pointerIDPool: Set<UInt32> = Set(0..<5)
    private var pointerIDs: [ObjectIdentifier: UInt32] = [:]
    private var latestSamples: [ObjectIdentifier: TrackpadTouchSample] = [:]
    private typealias Contact = (id: UInt32, type: UInt8, sample: TrackpadTouchSample)
    private let interpolateMoves: Bool
    private var pendingMove: [Contact]?
    private var moveRevision: UInt64 = 0

    init(interpolateMoves: Bool) {
        self.interpolateMoves = interpolateMoves
    }

    func enqueue(_ batch: TrackpadTouchBatch) {
        queue.async { [self] in
            // Complete the previous segment before accepting a new frame or
            // changing contact lifetimes, including when events arrive early.
            flushPendingMove()
            var contacts: [Contact] = []
            var previousSamples: [UInt32: TrackpadTouchSample] = [:]
            var endedTouches: [ObjectIdentifier] = []
            let ending = batch.eventType == UInt8(LI_TOUCH_EVENT_UP)
                || batch.eventType == UInt8(LI_TOUCH_EVENT_CANCEL)

            for touch in batch.touches {
                let key = ObjectIdentifier(touch)
                if batch.eventType == UInt8(LI_TOUCH_EVENT_DOWN) {
                    guard batch.samples[key] != nil, pointerIDs[key] == nil,
                          let id = pointerIDPool.subtracting(pointerIDs.values).min() else { continue }
                    pointerIDs[key] = id
                }
                // Never assign an ID on MOVE/UP: a sixth finger stays ignored
                // even if another finger frees a slot during the same gesture.
                guard let id = pointerIDs[key],
                      let sample = batch.samples[key] ?? (ending ? latestSamples[key] : nil) else { continue }
                previousSamples[id] = latestSamples[key]
                latestSamples[key] = sample
                contacts.append((id, batch.eventType, sample))
                if ending { endedTouches.append(key) }
            }

            if interpolateMoves && batch.allowsInterpolation && batch.eventType == UInt8(LI_TOUCH_EVENT_MOVE) && !contacts.isEmpty {
                let midpointContacts = contacts.map { contact -> Contact in
                    guard let previous = previousSamples[contact.id] else { return contact }
                    return (contact.id, contact.type, TrackpadTouchSample(
                        x: (previous.x + contact.sample.x) / 2,
                        y: (previous.y + contact.sample.y) / 2,
                        pressure: (previous.pressure + contact.sample.pressure) / 2))
                }
                // Buffer the real target: emit the actual segment midpoint now,
                send(midpointContacts)
                pendingMove = contacts
                let revision = moveRevision
                queue.asyncAfter(deadline: .now() + .nanoseconds(8_333_333)) { [self] in
                    guard moveRevision == revision else { return }
                    flushPendingMove()
                }
            } else {
                send(contacts)
            }
            // Reuse an ID only after its final event has been enqueued in common-c.
            for key in endedTouches {
                pointerIDs.removeValue(forKey: key)
                latestSamples.removeValue(forKey: key)
            }
        }
    }

    private func flushPendingMove() {
        moveRevision &+= 1
        guard let contacts = pendingMove else { return }
        pendingMove = nil
        send(contacts)
    }

    func reset() {
        queue.async { [self] in
            moveRevision &+= 1
            pendingMove = nil
            let contacts = pointerIDs.compactMap { key, id in
                latestSamples[key].map { (id: id, type: UInt8(LI_TOUCH_EVENT_CANCEL), sample: $0) }
            }
            send(contacts)
            pointerIDs.removeAll()
            latestSamples.removeAll()
        }
    }

    private func send(_ contacts: [Contact]) {
        guard !contacts.isEmpty else { return }
        let features = LiGetHostFeatureFlags()
        if features & UInt32(LI_FF_TOUCHPAD_FRAME_EVENTS) != 0 {
            let types = contacts.map(\.type)
            let ids = contacts.map(\.id)
            let x = contacts.map { $0.sample.x }
            let y = contacts.map { $0.sample.y }
            let pressure = contacts.map { $0.sample.pressure }
            // Physical size is unknown; coordinates use the gesture's square
            // reference area, independent of the video's aspect ratio or letterbox.
            _ = LiSendTouchpadFrameEvent(UInt8(contacts.count), types, ids, x, y, pressure,
                                        UInt16(LI_ROT_UNKNOWN), 0, 0, 0)
        } else if features & UInt32(LI_FF_TOUCHPAD_EVENTS) != 0 {
            for contact in contacts {
                _ = LiSendTouchpadEvent(contact.type, contact.id,
                                       contact.sample.x, contact.sample.y, contact.sample.pressure,
                                       0, 0, UInt16(LI_ROT_UNKNOWN), 0, 0, 0)
            }
        }
    }
}
