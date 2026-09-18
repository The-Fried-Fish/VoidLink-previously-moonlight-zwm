//
//  OrientationHelper.swift
//  VoidLink
//
//  Created by True砖家 on 2024/7/12.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//


// this is just a test code in swift, methods here not being called by anyone yet.
import Foundation

import UIKit
  
@objc class OrientationHelper: NSObject {
    @objc static func updateOrientationToLandscape() {
#if os(tvOS)
        return
#else
        if #available(iOS 16.0, *) {
            // 调用此方法会使视图控制器重新评估其支持的方向集。
            UIApplication.shared.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            
            // 遍历并更新导航控制器的方向
            if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController {
                navigationController.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            
            // 尝试更新窗口场景的几何形状为横屏
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .landscape)
                scene.requestGeometryUpdate(geometryPreferences) { (receivedError: Error?) in
                    if let error = receivedError {
                        // 处理错误
                        print("Error updating window scene geometry: \(error)")
                    } else {
                        // 没有错误，执行后续操作
                        print("Window scene geometry updated successfully.")
                    }
                }
            } else {
                // 早于 iOS 16.0 的版本的回退逻辑
                print("iOS version is less than 16.0, falling back to earlier behavior.")
            }
        }
#endif
    }
}
