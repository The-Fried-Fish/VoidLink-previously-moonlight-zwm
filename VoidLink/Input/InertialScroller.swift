//
//  InertialScroller.swift
//  VoidLink
//
//  Created by True砖家 on 2025/12/5.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

class InertialScroller {
    public var decelerationRateX: CGFloat
    public var decelerationRateY: CGFloat

    public lazy var timer: SafeTimer? = {
        SafeTimer(interval: 1/displayLinkRate) { [weak self] in
            guard let self = self, handler != nil else {return}
            self.vector.dx = self.vector.dx * decelerationRateX
            self.vector.dy = self.vector.dy * decelerationRateY
            if abs(self.vector.dx) < self.timerSuspendThreshold && abs(self.vector.dy) < self.timerSuspendThreshold {
                self.timer?.pause()
            }
            (self.handler ?? {})()
        }
    }()
    
    public var vector: CGVector = .zero
    public var displayLinkRate: CGFloat
    public var timerSuspendThreshold: CGFloat = 0.06
    public var handler: (() -> Void)?
    
    init(decelerationRate: CGFloat = 0.93, displayLinkRate: CGFloat = 60, handler: (() -> Void)? = nil) {
        self.decelerationRateX = decelerationRate
        self.decelerationRateY = decelerationRate
        self.displayLinkRate = displayLinkRate
        self.handler = handler
    }
}
