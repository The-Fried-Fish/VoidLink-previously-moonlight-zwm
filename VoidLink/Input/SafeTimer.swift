//
//  SafeTimer.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/9.
//  Copyright © 2025 True砖家@Bilibili. All rights reserved.
//


class SafeTimer {
    private var timer: DispatchSourceTimer
    private(set) var isRunning = false
    private var interval: TimeInterval = 0
    
    init(interval: TimeInterval = 1.0, queue: DispatchQueue = .global(), handler: @escaping () -> Void) {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler(handler: handler)
        self.interval = interval
        // 注意：这里不调用 resume，保持 suspended，等 start() 时才运行
    }
    
    public func resume() {
        guard !isRunning else { return }
        timer.resume()
        isRunning = true
    }
    
    public func suspend() {
        guard isRunning else { return }
        timer.suspend()
        isRunning = false
    }
    
    func restart() {
        if isRunning {
            timer.suspend()
            isRunning = false
        }
        timer.schedule(deadline: .now(), repeating: self.interval) // 重置时间
        timer.resume()
        isRunning = true
    }
    
    deinit {
        if !timer.isCancelled {
            timer.cancel()
        }
    }
}
