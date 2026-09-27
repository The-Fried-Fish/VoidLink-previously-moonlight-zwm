//
//  CursorInertia.swift
//  VoidLink
//
//  Trackpad-style cursor inertia for touchpad (relative touch) mode.
//  The finger velocity at lift-off keeps the cursor coasting, slowing down
//  according to the deceleration setting. Touching the screen stops it.
//
//  All methods must be called on the main thread.
//

import UIKit

@objc class CursorInertia: NSObject {

    private struct Sample {
        let delta: CGVector
        let timestamp: TimeInterval
    }

    /// Only movement within this window before lift-off contributes to the release velocity.
    private static let velocitySampleWindow: TimeInterval = 0.08
    /// If the finger rested longer than this before lifting, no coasting happens (like a real trackpad).
    private static let maximumRestBeforeRelease: TimeInterval = 0.05
    private static let minimumStartSpeed: CGFloat = 120 // points per second
    private static let stopSpeed: CGFloat = 15 // points per second

    /// Fraction of velocity kept per 1/60 s.
    private let retentionPer60HzFrame: CGFloat
    private let handler: (CGVector) -> Void

    private var samples: [Sample] = []
    private var velocity: CGVector = .zero
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0

    /// - Parameters:
    ///   - deceleration: 1 (long coast) ... 10 (short coast).
    ///   - handler: receives the cursor delta to apply on each frame, in the same units as `recordMove`.
    @objc init(deceleration: CGFloat, handler: @escaping (CGVector) -> Void) {
        let clamped = min(max(deceleration, 1), 10)
        self.retentionPer60HzFrame = 0.985 - (clamped - 1) * (0.135 / 9)
        self.handler = handler
        super.init()
    }

    deinit {
        displayLink?.invalidate()
    }

    @objc var isCoasting: Bool { displayLink != nil }

    /// Records a cursor movement while the finger is on the screen.
    @objc func recordMove(_ delta: CGVector, timestamp: TimeInterval) {
        samples.append(Sample(delta: delta, timestamp: timestamp))
        let cutoff = timestamp - CursorInertia.velocitySampleWindow
        samples.removeAll { $0.timestamp < cutoff }
    }

    /// Called when the finger lifts. Starts coasting if it was moving fast enough.
    @objc func liftOff(at timestamp: TimeInterval) {
        defer { samples.removeAll() }
        guard let last = samples.last, let first = samples.first,
              timestamp - last.timestamp <= CursorInertia.maximumRestBeforeRelease else { return }

        // The first sample's delta covers the time before its timestamp, so span from one frame earlier.
        let span = max(last.timestamp - first.timestamp, 0) + (1.0 / 60.0)
        let total = samples.reduce(CGVector.zero) { CGVector(dx: $0.dx + $1.delta.dx, dy: $0.dy + $1.delta.dy) }
        let releaseVelocity = CGVector(dx: total.dx / CGFloat(span), dy: total.dy / CGFloat(span))
        guard hypot(releaseVelocity.dx, releaseVelocity.dy) >= CursorInertia.minimumStartSpeed else { return }

        velocity = releaseVelocity
        startDisplayLink()
    }

    /// Stops any coasting immediately and forgets in-progress samples.
    @objc func stop() {
        samples.removeAll()
        velocity = .zero
        displayLink?.invalidate()
        displayLink = nil
    }

    private func startDisplayLink() {
        displayLink?.invalidate()
        let link = CADisplayLink(target: CursorInertiaDisplayLinkProxy(owner: self), selector: #selector(CursorInertiaDisplayLinkProxy.tick(_:)))
        if #available(iOS 15.0, tvOS 15.0, *) {
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
        lastFrameTimestamp = CACurrentMediaTime()
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    fileprivate func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        let dt = CGFloat(min(max(now - lastFrameTimestamp, 1.0 / 240.0), 1.0 / 20.0))
        lastFrameTimestamp = now

        handler(CGVector(dx: velocity.dx * dt, dy: velocity.dy * dt))

        let decay = pow(retentionPer60HzFrame, dt * 60)
        velocity.dx *= decay
        velocity.dy *= decay
        if hypot(velocity.dx, velocity.dy) < CursorInertia.stopSpeed { stop() }
    }
}

/// CADisplayLink retains its target; the proxy keeps that from retaining CursorInertia.
private class CursorInertiaDisplayLinkProxy: NSObject {
    weak var owner: CursorInertia?

    init(owner: CursorInertia) {
        self.owner = owner
    }

    @objc func tick(_ link: CADisplayLink) {
        guard let owner = owner else {
            link.invalidate()
            return
        }
        owner.tick(link)
    }
}
