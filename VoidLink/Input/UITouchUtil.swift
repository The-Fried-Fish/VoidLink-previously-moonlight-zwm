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
        guard (event?.allTouches) != nil else { return [] }
        return event?.allTouches?.filter({ $0.view == view }) ?? []
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
    
    @objc public static func vector(from touch1: UITouch?, to touch2: UITouch?, in view: UIView?) -> CGVector {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return CGVectorMake(0,0) }
        let p1 = touch1.location(in: view)
        let p2 = touch2.location(in: view)
        return CGVectorMake(p2.x - p1.x, p2.y - p1.y)
    }
    
    @objc public static func vector(of touch: UITouch?, in view: UIView?) -> CGVector {
        guard let view = view, let touch = touch else { return CGVectorMake(0,0) }
        let p2 = touch.location(in: view)
        let p1 = touch.previousLocation(in: view)
        return CGVectorMake(p2.x - p1.x, p2.y - p1.y)
    }
    
    @objc public static func preciseVector(of touch: UITouch?, in view: UIView?) -> CGVector {
        guard let view = view, let touch = touch else { return CGVectorMake(0,0) }
        let p2 = touch.preciseLocation(in: view)
        let p1 = touch.precisePreviousLocation(in: view)
        return CGVectorMake(p2.x - p1.x, p2.y - p1.y)
    }

    @objc public static func getDeltaX(from touch: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch = touch else { return 0 }
        return touch.location(in: view).x - touch.previousLocation(in: view).x
    }
    
    @objc public static func getDeltaY(from touch: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch = touch else { return 0 }
        return touch.location(in: view).y - touch.previousLocation(in: view).y
    }
    
    @objc public static func midPointDeltaX(between touch1: UITouch?, and touch2: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return 0 }
        return (touch1.location(in: view).x+touch2.location(in: view).x)/2 - (touch1.previousLocation(in: view).x+touch2.previousLocation(in: view).x)/2
    }
    
    @objc public static func midPointDeltaY(between touch1: UITouch?, and touch2: UITouch?, in view: UIView?) -> CGFloat {
        guard let view = view, let touch1 = touch1, let touch2 = touch2 else { return 0 }
        return (touch1.location(in: view).y+touch2.location(in: view).y)/2 - (touch1.previousLocation(in: view).y+touch2.previousLocation(in: view).y)/2
    }

}
