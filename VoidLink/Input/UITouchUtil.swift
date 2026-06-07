//
//  UITouchUtil.swift
//  VoidLink
//
//  Created by True砖家 on 2025/11/5.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

import UIKit

@objc class UITouchUtil: NSObject {
    @objc public static func touches(in view: UIView, from event: UIEvent?) -> Set<UITouch> {
        guard let touches = event?.allTouches else { return [] }
        return touches.filter {
            $0.view === view && ($0.type == .direct || $0.type == .pencil)
        }
    }
    
    @objc public static func distance(between touch1: UITouch?, and touch2: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return 0 }
        let p1 = touch1.location(in: view)
        let p2 = touch2.location(in: view)
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
    
    @objc public static func previousDistance(between touch1: UITouch?, and touch2: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return 0 }
        let p1 = touch1.previousLocation(in: view)
        let p2 = touch2.previousLocation(in: view)
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
    
    @objc public static func vector(of touch: UITouch?, in view: UIView?) -> CGVector {
        guard let view = view, let touch = touch else { return CGVectorMake(0,0) }
        let p2 = touch.location(in: view)
        let p1 = touch.previousLocation(in: view)
        return CGVectorMake(p2.x - p1.x, p2.y - p1.y)
    }
    
    @objc public static func midPointVector(between touch1: UITouch?, and touch2: UITouch?, in view: UIView?) -> CGVector {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return CGVector(dx: 0, dy: 0)}
        
        let vector1 = vector(of: touch1, in: view)
        let vector2 = vector(of: touch2, in: view)
        
        let deltaX = (vector1.dx+vector2.dx)/2
        let deltaY = (vector1.dy+vector2.dy)/2

        return CGVector(dx: deltaX, dy: deltaY)
    }
}
