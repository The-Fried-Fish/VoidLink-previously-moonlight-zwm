//
//  SafeTimer.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/9.
//  Copyright © 2025 True砖家@Bilibili. All rights reserved.
//

import Foundation
import QuartzCore

@objc(SafeTimer)
final class SafeTimer: NSObject {
    private var timer: DispatchSourceTimer?
    private let timerQueue: DispatchQueue       // 私有串行队列
    private let userHandler: () -> Void
    private let interval: TimeInterval
    private let delay: TimeInterval

    private var shouldRunHandler: Bool = false  // 控制逻辑上的暂停/恢复
    private var isCleaned: Bool = false         // 是否已经 clean

    @objc init(interval: TimeInterval = 1.0,
         delay: TimeInterval = 0,
         queueLabel: String = "com.example.safetimer",
         handler: @escaping () -> Void) {
        
        self.interval = interval
        self.delay = delay
        self.userHandler = handler
        self.timerQueue = DispatchQueue(label: queueLabel)
        
        super.init()

        let t = DispatchSource.makeTimerSource(queue: timerQueue)
        t.schedule(deadline: .now() + delay, repeating: interval)

        t.setEventHandler { [weak self] in
            guard let self = self, !self.isCleaned else { return }
            if !self.shouldRunHandler { return }
            self.userHandler()
        }

        t.resume()  // timer 一开始就 resume，避免 suspend/resume 的计数问题
        self.timer = t
    }

    deinit {
        clean()
    }

    /// 开始逻辑上的计时
    @objc func start() {
        timerQueue.async { [weak self] in
            guard let self = self, !self.isCleaned else { return }
            self.shouldRunHandler = true
        }
    }

    /// 暂停逻辑上的计时
    @objc func pause() {
        timerQueue.async { [weak self] in
            guard let self = self, !self.isCleaned else { return }
            self.shouldRunHandler = false
        }
    }

    /// 重置下一次触发时间，并开始执行 handler
    @objc func restart() {
        timerQueue.async { [weak self] in
            guard let self = self, let t = self.timer, !self.isCleaned else { return }
            t.schedule(deadline: .now() + self.delay, repeating: self.interval)
            self.shouldRunHandler = true
        }
    }
    
    @objc func isRunning() -> Bool {
        return shouldRunHandler;
    }

    /// 彻底清理 timer，返回后保证 handler 不再执行
    @objc func clean() {
        if isCleaned { return }
        // 同步在 timerQueue 执行，保证已排队事件全部处理完（或跳过）
        timerQueue.sync {
            self.isCleaned = true
            self.shouldRunHandler = false

            if let t = self.timer {
                t.setEventHandler {}  // 清空 handler
                t.cancel()            // 取消 timer
                self.timer = nil
            }
        }
    }
}
