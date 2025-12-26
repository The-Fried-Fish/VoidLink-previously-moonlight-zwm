//
//  GraphicUtils.swift
//  VoidLink
//
//  Created by True砖家 on 2025/12/24.
//  Copyright © 2025 True砖家@Bilibili. All rights reserved.
//


import Foundation
import SVGKit

@objc public class GraphicUtils: NSObject {
    @objc public class func makeCenteredSVGLayer(
        from file: String,
        in container: CALayer,
        targetSize: CGSize
    ) -> CALayer {

        guard let svg = SVGKImage(named: file) else {
            fatalError("Failed to load SVG \(file)")
        }

        return _makeCenteredSVGLayer(
            from: svg,
            in: container,
            targetSize: targetSize
        )
    }
    
    public class func makeCenteredSVGLayer(
        from svg: SVGKImage,
        in container: CALayer,
        targetSize: CGSize
    ) -> CALayer {
        return _makeCenteredSVGLayer(
            from: svg,
            in: container,
            targetSize: targetSize
        )
    }

    @objc public class func _makeCenteredSVGLayer(
        from svg: SVGKImage,
        in container: CALayer,
        targetSize: CGSize,
        getWrapperLayer: Bool = true
    ) -> CALayer {
        
        let svgLayer = svg.caLayerTree!

        svgLayer.transform = CATransform3DIdentity

        var unionRect = CGRect.null
        func accumulateBounds(_ layer: CALayer) {
            unionRect = unionRect.union(layer.frame)
            layer.sublayers?.forEach { accumulateBounds($0) }
        }
        accumulateBounds(svgLayer)

        svgLayer.setAffineTransform(
            CGAffineTransform(
                translationX: -unionRect.origin.x,
                y: -unionRect.origin.y
            )
        )

        let wrapper = CALayer()
        wrapper.bounds = CGRect(origin: .zero, size: unionRect.size)
        wrapper.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        wrapper.position = CGPoint(
            x: container.bounds.midX,
            y: container.bounds.midY
        )
        
        let scale = min(
            targetSize.width / unionRect.width,
            targetSize.height / unionRect.height
        )

        wrapper.setAffineTransform(
            CGAffineTransform(scaleX: scale, y: scale)
        )

        wrapper.addSublayer(svgLayer)
        
        if !getWrapperLayer {
            return wrapper
        }
        
        let wrappedLayer = CALayer()
        wrappedLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        wrappedLayer.bounds = CGRect(x: 0, y: 0, width: container.bounds.size.width, height: container.bounds.size.height)
        wrappedLayer.position = CGPoint(x: container.bounds.midX, y: container.bounds.midY)
        wrappedLayer.insertSublayer(wrapper, at: 0)

        return wrappedLayer
    }
    
    @objc public class func changeColor(layer: CALayer, color: UIColor) {
        if let shape = layer as? CAShapeLayer {
            shape.fillColor = color.cgColor
            shape.strokeColor = color.cgColor
        }
        layer.sublayers?.forEach { changeColor(layer: $0, color: color) }
    }
}
