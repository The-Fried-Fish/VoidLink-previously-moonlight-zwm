//
//  UUIDHelper.swift
//  VoidLink
//
//  Created by True砖家 on 2025/9/30.
//  Copyright © 2025 True砖家@Bilibili. All rights reserved.
//


import Foundation

@objc public class UUIDHelper: NSObject {
    
    @objc public static func newUUID() -> String {
        return UUID().uuidString
    }
}
