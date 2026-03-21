//
//  PressureCurve.swift
//  VoidLink
//
//  Created by True砖家 on 2026/1/5.
//  Copyright © 2025 True砖家 on Bilibili. All rights reserved.
//

import UIKit

// MARK: - PressureCurve
final class PressureCurve {
    
    var polylinePoints: [CGPoint] = [
        CGPoint(x: 0, y: 0.0),
        CGPoint(x: 1.0, y: 1.0)
    ]

    private var factor: CGFloat = 0.39
    
    private var cachedSegments: [(p0: CGPoint, c1: CGPoint, c2: CGPoint, p1: CGPoint)] = []

    private var curveCutPoints: [CGPoint] {
        guard polylinePoints.count >= 2 else { return polylinePoints }
        var cuts: [CGPoint] = []
        cuts.append(polylinePoints[0]) // 起点
        for i in 0..<(polylinePoints.count - 2) {
            let mid = CGPoint(
                x: (polylinePoints[i+1].x + polylinePoints[i+2].x)/2,
                y: (polylinePoints[i+1].y + polylinePoints[i+2].y)/2
            )
            if i < polylinePoints.count - 3 {
                cuts.append(mid)
            }
        }
        cuts.append(polylinePoints.last!) // 终点
        return cuts
    }
    
    private func curveFactor(for middlePointCount: Int) -> CGFloat {
        guard middlePointCount > 0 else { return 2.0 / 3.0 }
        let n = CGFloat(middlePointCount)
        return 0.30538319 * pow(n, -2.1518917) + 0.36128348
    }

    public func buildCurveSegments() {
        let cuts = curveCutPoints
        var segments: [(CGPoint, CGPoint, CGPoint, CGPoint)] = []
        
        factor = curveFactor(for: polylinePoints.count-2)

        for i in 0..<(cuts.count - 1) {
            let p0 = cuts[i]
            let p1 = cuts[i+1]

            // segment index
            let startIndex = i
            let endIndex = i+1

            let tangentStart: CGPoint
            if startIndex < polylinePoints.count - 1 {
                tangentStart = CGPoint(
                    x: (polylinePoints[startIndex + 1].x - polylinePoints[startIndex].x) * factor,
                    y: (polylinePoints[startIndex + 1].y - polylinePoints[startIndex].y) * factor
                )
            } else {
                tangentStart = .zero
            }

            let tangentEnd: CGPoint
            if endIndex < polylinePoints.count - 1 {
                tangentEnd = CGPoint(
                    x: (polylinePoints[endIndex + 1].x - polylinePoints[endIndex].x) * factor,
                    y: (polylinePoints[endIndex + 1].y - polylinePoints[endIndex].y) * factor
                )
            } else {
                tangentEnd = .zero
            }

            let c1 = CGPoint(x: p0.x + tangentStart.x, y: p0.y + tangentStart.y)
            let c2 = CGPoint(x: p1.x - tangentEnd.x, y: p1.y - tangentEnd.y)

            segments.append((p0: p0, c1: c1, c2: c2, p1: p1))
        }
        
        cachedSegments = segments
    }

    /// 采样  曲线
    func sampleCurve(stepsPerSegment: Int = 50) -> [CGPoint] {
        var points: [CGPoint] = []
        buildCurveSegments()
        for seg in cachedSegments {
            let sampled = sampleCurve(p0: seg.p0, c1: seg.c1, c2: seg.c2, p1: seg.p1, steps: stepsPerSegment)
            if !points.isEmpty { points.removeLast() } // 避免重复点
            points.append(contentsOf: sampled)
        }
        return points
    }

    private func sampleCurve(p0: CGPoint, c1: CGPoint, c2: CGPoint, p1: CGPoint, steps: Int) -> [CGPoint] {
        var result: [CGPoint] = []
        for i in 0...steps {
            let t = CGFloat(i)/CGFloat(steps)
            let mt = 1-t
            let x = mt*mt*mt*p0.x + 3*mt*mt*t*c1.x + 3*mt*t*t*c2.x + t*t*t*p1.x
            let y = mt*mt*mt*p0.y + 3*mt*mt*t*c1.y + 3*mt*t*t*c2.y + t*t*t*p1.y
            result.append(CGPoint(x:x, y:y))
        }
        return result
    }

    var tangentPoints: [CGPoint] { polylinePoints }
    
    func value(at x: CGFloat) -> CGFloat {
        
        guard let firstPoint = polylinePoints.first else { return 0 }
        if x < firstPoint.x {return 0}
        
        let xClamped = min(max(x, 0), 1)
        let segments = cachedSegments

        for seg in segments {
            if xClamped >= seg.p0.x && xClamped <= seg.p1.x {
                let t = solveT(forX: xClamped,
                               p0: seg.p0.x,
                               c1: seg.c1.x,
                               c2: seg.c2.x,
                               p1: seg.p1.x)
                return cubic(p0: seg.p0.y,
                              c1: seg.c1.y,
                              c2: seg.c2.y,
                              p1: seg.p1.y,
                              t: t)
            }
        }

        return segments.last?.p1.y ?? 0
    }

    private func solveT(
        forX x: CGFloat,
        p0: CGFloat,
        c1: CGFloat,
        c2: CGFloat,
        p1: CGFloat,
        iterations: Int = 18
    ) -> CGFloat {

        var low: CGFloat = 0
        var high: CGFloat = 1
        var t: CGFloat = 0.5

        for _ in 0..<iterations {
            t = (low + high) * 0.5
            let xt = cubic(p0: p0, c1: c1, c2: c2, p1: p1, t: t)

            if xt < x {
                low = t
            } else {
                high = t
            }
        }

        return t
    }

    @inline(__always)
    private func cubic(
        p0: CGFloat,
        c1: CGFloat,
        c2: CGFloat,
        p1: CGFloat,
        t: CGFloat
    ) -> CGFloat {

        let mt = 1 - t
        return mt*mt*mt*p0
             + 3*mt*mt*t*c1
             + 3*mt*t*t*c2
             + t*t*t*p1
    }
    
    static func exportCurvePoints(_ curve: PressureCurve) -> [NSNumber] {
        var arr: [NSNumber] = []
        for p in curve.polylinePoints {
            arr.append(NSNumber(value: Float(p.x)))
            arr.append(NSNumber(value: Float(p.y)))
        }
        return arr
    }

    static func importCurvePoints(_ numbers: [NSNumber]) -> [CGPoint] {
        var pts: [CGPoint] = []
        let count = numbers.count / 2

        for i in 0..<count {
            let x = CGFloat(numbers[i*2].floatValue)
            let y = CGFloat(numbers[i*2 + 1].floatValue)
            pts.append(CGPoint(x: x, y: y))
        }
        return pts
    }

    static func generateLinearCurvePoints(from pressures: [CGFloat]) -> [CGPoint] {
        guard !pressures.isEmpty else { return [] }

        let samples = pressures.map { min(max($0, 0), 1) }
        let maxPressure = samples.max() ?? 0

        if maxPressure < 1 {
            let platformX = maxPressure

            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: platformX, y: 1),
                CGPoint(x: platformX, y: 1),
                CGPoint(x: 1, y: 1)
            ]
        } else {
            return [
                CGPoint(x: 0, y: 0),
                CGPoint(x: 1, y: 1)
            ]
        }
    }

}

// MARK: - PressureCurveView
final class PressureCurveView: UIView {

    let curve = PressureCurve()
    
    private var draggingIndex: Int? = nil
    private var latestDraggingIndex: Int? = nil
    private var newPointGenerated: Bool = false
    private var draggingPointPreviousLocation: CGPoint? = nil
    private let hitRadius: CGFloat = 35
    
    enum PressureTestStage: UInt8 {
        case drawingStage
        case curveStage
    }
    public var testStage: PressureTestStage = .curveStage
    private var pressures:[CGFloat] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
    }

    required init?(coder: NSCoder) { fatalError() }

    public var showGraph: Bool = false {
        didSet { setNeedsDisplay() } // 改变开关立即刷新
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        ctx.saveGState()
        
        // 缩放和平移
        let scale: CGFloat = 0.95
        let dx = (bounds.width - bounds.width * scale) / 2
        let dy = (bounds.height - bounds.height * scale) / 2
        ctx.translateBy(x: dx, y: dy)
        ctx.scaleBy(x: scale, y: scale)
        
        if showGraph {
            drawGrid(ctx)
            drawCurve(ctx)
            drawTangents(ctx)
        }
        
        ctx.restoreGState()
    }

    private func drawGrid(_ ctx: CGContext) {
        ctx.setStrokeColor(UIColor.darkGray.cgColor)
        ctx.setLineWidth(1)
        for i in 0...4 {
            let t = CGFloat(i)/4
            let x = bounds.width*t
            let y = bounds.height*t
            ctx.move(to: CGPoint(x:x, y:0))
            ctx.addLine(to: CGPoint(x:x, y:bounds.height))
            ctx.move(to: CGPoint(x:0, y:y))
            ctx.addLine(to: CGPoint(x:bounds.width, y:y))
        }
        ctx.strokePath()
    }

    private func drawCurve(_ ctx: CGContext) {
        ctx.setStrokeColor(UIColor.systemBlue.cgColor)
        ctx.setLineWidth(6)
        let points = curve.sampleCurve(stepsPerSegment: 60)
        for (i,p) in points.enumerated() {
            let mapped = map(p)
            if i==0 { ctx.move(to:mapped) } else { ctx.addLine(to:mapped) }
        }
        ctx.strokePath()
    }

    private func drawTangents(_ ctx: CGContext) {
        let pts = curve.tangentPoints
        ctx.setStrokeColor(UIColor.systemPurple.cgColor)
        ctx.setLineWidth(2)
        for i in 0..<pts.count {
            let p = map(pts[i])
            if i==0 { ctx.move(to:p) } else { ctx.addLine(to:p) }
        }
        ctx.strokePath()

        for p in pts {
            let c = map(p)
            let r: CGFloat = 16
            ctx.setFillColor(UIColor.systemPurple.cgColor)
            ctx.fill(CGRect(x:c.x-r/2, y:c.y-r/2, width:r, height:r))
        }
    }

    private func map(_ p: CGPoint) -> CGPoint {
        CGPoint(x:p.x*bounds.width, y:(1-p.y)*bounds.height)
    }
    
    private func unmap(_ p: CGPoint) -> CGPoint {
        CGPoint(
            x: p.x / bounds.width,
            y: 1 - (p.y / bounds.height)
        )
    }

    private func hitTestPoint(_ location: CGPoint) -> Int? {
        let pts = curve.tangentPoints
        for (i, p) in pts.enumerated() {
            let c = map(p)
            let dx = c.x - location.x
            let dy = c.y - location.y
            if dx*dx + dy*dy <= hitRadius*hitRadius {
                return i
            }
        }
        return nil
    }
    
    func undoLastMove() {
        if newPointGenerated {
            guard let latestDraggingIndex = latestDraggingIndex else { return }
            self.latestDraggingIndex = nil
            curve.polylinePoints.remove(at: latestDraggingIndex )
            setNeedsDisplay()
        }
        else {
            guard let latestDraggingIndex = latestDraggingIndex else { return }
            self.latestDraggingIndex = nil
            guard let draggingPointPreviousLocation = draggingPointPreviousLocation else { return }
            curve.polylinePoints[latestDraggingIndex] = draggingPointPreviousLocation
            setNeedsDisplay()
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if testStage == .drawingStage {
            return
        }
        
        draggingIndex = hitTestPoint(location)
        if draggingIndex == nil {
            guard
                let touch = touches.first
            else { return }
            newPointGenerated = true
            let location = touch.location(in: self)
            var point = unmap(location)

            point.x = min(max(point.x, 0), 1)
            point.y = min(max(point.y, 0), 1)
            var insertIdx:Int = -1
            
            for (idx, polylinePoint) in curve.polylinePoints.enumerated() {
                if point.x <= polylinePoint.x {
                    insertIdx = idx
                    break
                }
            }
            if insertIdx >= 0 {
                curve.polylinePoints.insert(point, at: insertIdx)
                draggingIndex = insertIdx
            }
            latestDraggingIndex = draggingIndex
            setNeedsDisplay()
        }
        else {
            guard let draggingIndex = draggingIndex else { return }
            latestDraggingIndex = draggingIndex
            draggingPointPreviousLocation = curve.polylinePoints[draggingIndex]
            newPointGenerated = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if testStage == .drawingStage {
            let altitude = touches.first!.altitudeAngle
            let force = (touches.first!.force/touches.first!.maximumPossibleForce)/sin(altitude)
            pressures.append(force)
            return
        }
        
        guard
            let touch = touches.first,
            let idx = draggingIndex
        else { return }

        let location = touch.location(in: self)
        var point = unmap(location)
        
        if draggingIndex == 0 {
            let nextPoint = curve.polylinePoints[idx+1]
            point.x = min(max(point.x, 0), nextPoint.x)
            // point.x = 0
            point.y = min(max(point.y, 0), 1)
        }
        else if draggingIndex == curve.polylinePoints.count-1 {
            point.x = 1
            point.y = min(max(point.y, 0), 1)
        }
        else {
            let nextPoint = curve.polylinePoints[idx+1]
            let previousPoint = curve.polylinePoints[idx-1]
            point.x = min(max(point.x, previousPoint.x), nextPoint.x)
            point.y = min(max(point.y, 0), 1)
        }
        
        // print("currenPoint \(point)")
        
        curve.polylinePoints[idx] = point
        setNeedsDisplay()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if testStage == .drawingStage {
            if pressures.isEmpty { return }
            curve.polylinePoints = PressureCurve.generateLinearCurvePoints(from: pressures)
            testStage = .curveStage
            showGraph = true
            let parentVC = parentViewController as! PressureCurveViewController
            parentVC.setupNavigationBar()
            // parentVC.showCurveStageTips()
        }
        draggingIndex = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        draggingIndex = nil
    }

}

final class PressureCurveLUT {
    static let levels = 2048
    public let table: [Float]

    init(curve: PressureCurve) {
        curve.buildCurveSegments()
        
        var t = [Float](repeating: 0, count: Self.levels)

        let maxIndex = Float(Self.levels - 1)

        for i in 0..<Self.levels {
            let x = CGFloat(Float(i) / maxIndex)
            let y = curve.value(at: x)
            t[i] = Float(y)
        }

        self.table = t
    }
    
    @inline(__always)
    func value(at x: Float) -> Float {
        let clamped = min(max(x, 0), 1)
        let index = Int((clamped * Float(Self.levels - 1)).rounded())
        return table[index]
    }
}

extension UIView {
    var parentViewController: UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController {
                return vc
            }
            responder = r.next
        }
        return nil
    }
}

// MARK: - ViewController
class PressureCurveViewController: UIViewController, UIGestureRecognizerDelegate {
    
    private var navBar = UINavigationBar()
    private var saveButton: UIBarButtonItem = UIBarButtonItem()
    
    private var container = UIView()
    private var curveView = PressureCurveView()
    // private var initialTouchCurvePoints: [CGPoint] = []
    private var strokePressureCurvePoints: [CGPoint] = []

    private var phase1StrokeSampleIndexEnd: Int32 = 0
    private var phase2StrokeSampleIndexEnd: Int32 = 0
        
    private var minPressure: CGFloat = 0
    private var maxPressure: CGFloat = 1
    private var isFirstLaunch: Bool = GenericUtils.isFirstLaunchPressureCurveTool()
    
    // private var curvePhaseButton: UIBarButtonItem = UIBarButtonItem()
    private let hookFilterLabel = UILabel()
    private let hookFilterSlider = UISlider()
    private let strokeEqualizationDepthLabel = UILabel()
    private let strokeEqualizationDepthSlider = UISlider()
    private let strokeEqualizationStrengthLabel = UILabel()
    private let strokeEqualizationStrengthSlider = UISlider()

    enum PressureCurvePhase: UInt8, CaseIterable {
        case initialTouch
        case stroke
        func next() -> PressureCurvePhase {
            let all = Self.allCases
            let index = all.firstIndex(of: self)!
            let nextIndex = (index + 1) % all.count
            return all[nextIndex]
        }
    }
    
    private(set) var curvePhase: PressureCurvePhase = .initialTouch

    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.view.isOpaque = false
        self.view.backgroundColor = UIColor.clear // 半透明遮罩
        
        let curveWidth: CGFloat = 530
        let curveHeight: CGFloat = 530
        curveView = PressureCurveView(frame: CGRect(x: 0, y: 0, width: curveWidth, height: curveHeight))
        curveView.center = CGPoint(x: self.view.center.x, y: self.view.center.y)
        curveView.backgroundColor = .white
        curveView.layer.cornerRadius = 0
        curveView.layer.masksToBounds = true
        
        container = UIView(frame: CGRect(x: 0, y: 0, width: curveWidth+10, height: curveHeight+152))
        container.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY+6.5)
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.layer.borderWidth = 0.5
        container.layer.borderColor = UIColor.black.withAlphaComponent(0.15).cgColor
        container.addSubview(curveView)
        
        self.setupNavigationBar()
        self.setupBottomSliders()
        self.loadPersistedCurve()
        self.curveView.showGraph = true
        
                
        self.view.addSubview(container)
        
        curveView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            curveView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            curveView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor,constant: -25),
            curveView.widthAnchor.constraint(equalToConstant: curveWidth),
            curveView.heightAnchor.constraint(equalToConstant: curveHeight)
        ])
        
        self.displayCurve()
        
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pencilProPurchaseAborted(_:)),
            name: AddOnProduct.PencilProPack.purchaseAbortedNotification(),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(persistCurve),
            name: AddOnProduct.PencilProPack.purchaseSucceededNotification(),
            object: nil
        )
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.delegate = self
        view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        /*
        AlertControllerUtil.cancelButtonString = SwiftLocalizationHelper.localizedString(forKey: "No")
        AlertControllerUtil.showAlert(
            in: self,
            title: SwiftLocalizationHelper.localizedString(forKey: "Pen Pressure Curve"),
            message: SwiftLocalizationHelper.localizedString(forKey:"Reset the pen pressure curve by starting from the pen pressure test?"),
            withCancel: true,
            buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "Yes"),
            countdown: 0,
            action: {},
            completion: {
                if AlertControllerUtil.actionCancelled {
                    self.curveView.showGraph = true
                    self.curveView.testStage = .curveStage
                    self.curveView.setNeedsDisplay()
                    self.setupNavigationBar()
                    self.showCurveStageTips()
                }
                else {
                    self.pressureRangeTest()
                }
            }
        ) */
        if isFirstLaunch {
            showCurveStageTips()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
    }
        
    private func loadPersistedCurve() {
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        let oscProfile = oscProfileMan.getSelectedProfile()
        // initialTouchCurvePoints = PressureCurve.importCurvePoints(oscProfile.initialTouchPressureCurvePoints)
        strokePressureCurvePoints = PressureCurve.importCurvePoints(oscProfile.pressureCurvePoints)
        displayCurve()
        
        hookFilterSlider.value = Float(oscProfile.phase1StrokeSampleIndexEnd)
        strokeEqualizationDepthSlider.value = Float(oscProfile.phase2StrokeSampleIndexEnd)
        strokeEqualizationStrengthSlider.value = Float(oscProfile.strokeEqualizationStrength)
        
        strokeEqualizationDepthSliderMoved(strokeEqualizationDepthSlider)
        hookFilterDepthSliderMoved(hookFilterSlider)
        strokeEqualizationStrengthSliderMoved(strokeEqualizationStrengthSlider)
    }
    
    private func displayCurve() {
        switch curvePhase {
        case .initialTouch:
            break
            // curveView.curve.polylinePoints = initialTouchCurvePoints
        case .stroke:
            curveView.curve.polylinePoints = strokePressureCurvePoints
        }
        curveView.setNeedsDisplay()
    }
    
    private func setupBottomSliders() {
        
        hookFilterLabel.translatesAutoresizingMaskIntoConstraints = false
        hookFilterSlider.translatesAutoresizingMaskIntoConstraints = false
        strokeEqualizationDepthLabel.translatesAutoresizingMaskIntoConstraints = false
        strokeEqualizationDepthSlider.translatesAutoresizingMaskIntoConstraints = false
        strokeEqualizationStrengthLabel.translatesAutoresizingMaskIntoConstraints = false
        strokeEqualizationStrengthSlider.translatesAutoresizingMaskIntoConstraints = false

        let traits = UITraitCollection(userInterfaceStyle: .light)
        
        hookFilterLabel.font = UIFont.systemFont(ofSize: 14)
        hookFilterLabel.textColor = .black
        if GenericUtils.liquidGlassEnabled {
            if #available(iOS 13.0, *) {hookFilterSlider.maximumTrackTintColor = .tertiarySystemFill.resolvedColor(with: traits)}
        }
        hookFilterSlider.minimumValue = 1
        hookFilterSlider.maximumValue = 20
        hookFilterSlider.addTarget(self, action: #selector(hookFilterDepthSliderMoved(_:)), for: .valueChanged)
        
        strokeEqualizationDepthLabel.font = UIFont.systemFont(ofSize: 14)
        strokeEqualizationDepthLabel.textColor = .black
        if GenericUtils.liquidGlassEnabled {
            if #available(iOS 13.0, *) {strokeEqualizationDepthSlider.maximumTrackTintColor = .tertiarySystemFill.resolvedColor(with: traits)}
        }
        strokeEqualizationDepthSlider.minimumValue = 1
        strokeEqualizationDepthSlider.maximumValue = 80
        strokeEqualizationDepthSlider.addTarget(self, action: #selector(strokeEqualizationDepthSliderMoved(_:)), for: .valueChanged)
        
        strokeEqualizationStrengthLabel.font = UIFont.systemFont(ofSize: 14)
        strokeEqualizationStrengthLabel.textColor = .black
        if GenericUtils.liquidGlassEnabled {
            if #available(iOS 13.0, *) {strokeEqualizationStrengthSlider.maximumTrackTintColor = .tertiarySystemFill.resolvedColor(with: traits)}
        }
        strokeEqualizationStrengthSlider.minimumValue = 0.1
        strokeEqualizationStrengthSlider.maximumValue = 3.5
        strokeEqualizationStrengthSlider.addTarget(self, action: #selector(strokeEqualizationStrengthSliderMoved(_:)), for: .valueChanged)
                
        container.addSubview(hookFilterLabel)
        container.addSubview(hookFilterSlider)
        container.addSubview(strokeEqualizationDepthLabel)
        container.addSubview(strokeEqualizationDepthSlider)
        container.addSubview(strokeEqualizationStrengthLabel)
        container.addSubview(strokeEqualizationStrengthSlider)

        NSLayoutConstraint.activate([

            // Slider
            hookFilterLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            hookFilterLabel.widthAnchor.constraint(equalToConstant: 260),
            hookFilterSlider.leadingAnchor.constraint(equalTo: hookFilterLabel.trailingAnchor, constant: 12),
            hookFilterSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            hookFilterSlider.topAnchor.constraint(equalTo: curveView.bottomAnchor, constant: 0),
            hookFilterLabel.centerYAnchor.constraint(equalTo: hookFilterSlider.centerYAnchor, constant:0),
            
            strokeEqualizationDepthLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            strokeEqualizationDepthLabel.widthAnchor.constraint(equalToConstant: 260),
            strokeEqualizationDepthSlider.leadingAnchor.constraint(equalTo: strokeEqualizationDepthLabel.trailingAnchor, constant: 12),
            strokeEqualizationDepthSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            strokeEqualizationDepthSlider.topAnchor.constraint(equalTo: hookFilterSlider.bottomAnchor, constant: 0),
            strokeEqualizationDepthLabel.centerYAnchor.constraint(equalTo: strokeEqualizationDepthSlider.centerYAnchor, constant:0),
            
            strokeEqualizationStrengthLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            strokeEqualizationStrengthLabel.widthAnchor.constraint(equalToConstant: 260),
            strokeEqualizationStrengthSlider.leadingAnchor.constraint(equalTo: strokeEqualizationStrengthLabel.trailingAnchor, constant: 12),
            strokeEqualizationStrengthSlider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            strokeEqualizationStrengthSlider.topAnchor.constraint(equalTo: strokeEqualizationDepthSlider.bottomAnchor, constant: 0),
            strokeEqualizationStrengthLabel.centerYAnchor.constraint(equalTo: strokeEqualizationStrengthSlider.centerYAnchor, constant:0),
        ])
    }
    
    @objc func hookFilterDepthSliderMoved(_ sender: UISlider) {
        phase1StrokeSampleIndexEnd = Int32(sender.value.rounded())
        hookFilterLabel.text = "\(SwiftLocalizationHelper.localizedString(forKey: "Stroke start hook filtering depth: "))\(String(format: "%d", Int32(sender.value)))";
        if sender.value > strokeEqualizationDepthSlider.value {
            strokeEqualizationDepthSlider.value = sender.value
            strokeEqualizationDepthSliderMoved(strokeEqualizationDepthSlider)
        }
    }
    
    @objc func strokeEqualizationDepthSliderMoved(_ sender: UISlider) {
        sender.value = max(sender.value, hookFilterSlider.value)
        phase2StrokeSampleIndexEnd = Int32(sender.value.rounded())
        strokeEqualizationDepthLabel.text = "\(SwiftLocalizationHelper.localizedString(forKey: "Stroke start equalization depth: "))\(String(format: "%d", Int32(sender.value)))";
    }
    
    @objc func strokeEqualizationStrengthSliderMoved(_ sender: UISlider) {
        // sender.value = sender.value
        strokeEqualizationStrengthLabel.text = "\(SwiftLocalizationHelper.localizedString(forKey: "Stroke start force scaling: "))\(String(format: "%.2f", sender.value))";
    }

    
    public func setupNavigationBar() {
        // 1. 创建 UINavigationBar
        navBar.removeFromSuperview()
        navBar = UINavigationBar()
        navBar.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(navBar)
        
        var navItem = UINavigationItem()
        
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            // appearance.configureWithTransparentBackground() // 透明背景
            appearance.shadowColor = nil // 去掉底部细线
            appearance.backgroundColor = .white // 可以额外设置完全透明
            
            navBar.standardAppearance = appearance
            navBar.scrollEdgeAppearance = appearance
        } else {
            navBar.setBackgroundImage(UIImage(), for: .default)
            navBar.shadowImage = UIImage() // 去掉底部线
            navBar.isTranslucent = true
            navBar.backgroundColor = .clear
        }
        
        // 2. 添加约束 (顶部，左右)
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: container.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            navBar.heightAnchor.constraint(equalToConstant: 50) // 导航栏标准高度
        ])
        
        if curveView.testStage == .curveStage {
            let resetButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Reset"), style: .plain, target: self, action: #selector(resetTapped))
            let undoButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Undo"), style: .plain, target: self, action: #selector(undoTapped))
            let rangeTestButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Pressure-range-test"), style: .plain, target: self, action: #selector(pressureRangeTest))
            // curvePhaseButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Initial-touch-curve"), style: .plain, target: self, action: #selector(curvePhaseButtonTapped))
            curvePhase = .stroke
            saveButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Save"), style: .plain, target: self, action: #selector(saveTapped))
            // let quitButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Exit"), style: .plain, target: self, action: #selector(exitTapped))
            navItem.leftBarButtonItems = [resetButton, undoButton, rangeTestButton,]
            navItem.rightBarButtonItems = [saveButton]
        }
                
        
        if curveView.testStage == .drawingStage {
            navItem = UINavigationItem(title: SwiftLocalizationHelper.localizedString(forKey: "Pressure Range Test"))
        }
        
        if #available(iOS 26.0, *) {
            if let buttons = navItem.leftBarButtonItems {
                for button in buttons {
                    button.hidesSharedBackground = true
                    button.tintColor = .tintColor
                }
            }
            if let buttons = navItem.rightBarButtonItems {
                for button in buttons {
                    button.hidesSharedBackground = true
                    button.tintColor = .tintColor
                }
            }
        }

        navBar.items = [navItem]
    }
    
    public func showCurveStageTips() {
        AlertControllerUtil.showAlert(
            in: self,
            title: SwiftLocalizationHelper.localizedString(forKey: "Pen Pressure Curve"),
            message: SwiftLocalizationHelper.localizedString(forKey:"Adjust the pressure curve by adding or dragging the purple squares."),
            withCancel: false,
            buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "This tip won't be shown again"),
            countdown: 6
            )
    }

    @objc private func resetTapped() {
        curveView.curve.polylinePoints = [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)]
        DispatchQueue.main.async {
            self.curveView.setNeedsDisplay()
        }
    }
    
    @objc private func undoTapped() {
        DispatchQueue.main.async {
            self.curveView.undoLastMove()
        }
    }
    
    @objc private func pencilProPurchaseAborted(_ notification: Notification) {
        guard let interruption = notification.object as? PurchaseInterruption else { return }
        if interruption != .learnMore {
            resetTapped()
        }
        if interruption == .lowOSVersion {
            AlertControllerUtil.showAlert(
                in: self,
                title: "",
                message: SwiftLocalizationHelper.localizedString(forKey:"PencilProPackLowOSVersionTip"),
                withCancel: false,
                buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "OK"),
                countdown: 0)
        }
    }
    
    @objc private func pressureRangeTest() {
        AlertControllerUtil.showAlert(
            in: self,
            title: SwiftLocalizationHelper.localizedString(forKey: "Pressure Range Test"),
            message: SwiftLocalizationHelper.localizedString(forKey:"pressureRangeTestTip"),
            withCancel: true,
            buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "OK"),
            countdown: 0,
            completion:{
                if AlertControllerUtil.actionCancelled { return }
                self.resetTapped()
                self.curveView.showGraph = false
                self.curveView.testStage = .drawingStage
                self.curveView.setNeedsDisplay()
                self.setupNavigationBar()
            })
    }
    
    /*
    @objc private func curvePhaseButtonTapped() {
        switch curvePhase {
        case .initialTouch:
            // initialTouchCurvePoints = curveView.curve.polylinePoints
            curvePhaseButton.title = SwiftLocalizationHelper.localizedString(forKey:"Initial-touch-curve")
        case .stroke:
            strokeCurvePoints = curveView.curve.polylinePoints
            curvePhaseButton.title = SwiftLocalizationHelper.localizedString(forKey:"Stroke-curve")
        }
        curvePhase = curvePhase.next()
        displayCurve()
    } */
    
    @objc private func persistCurve() {
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        let selectedProfile = oscProfileMan.getSelectedProfile()
        
        switch curvePhase {
        case .initialTouch:
            break
            // initialTouchCurvePoints = curveView.curve.polylinePoints
        case .stroke:
            strokePressureCurvePoints = curveView.curve.polylinePoints
        }
        
        curveView.curve.polylinePoints = strokePressureCurvePoints
        selectedProfile.pressureCurvePoints = PressureCurve.exportCurvePoints(curveView.curve)
        // curveView.curve.polylinePoints = initialTouchCurvePoints
        // selectedProfile.initialTouchPressureCurvePoints = PressureCurve.exportCurvePoints(curveView.curve)
        
        displayCurve()
        
        selectedProfile.phase1StrokeSampleIndexEnd = Int32(hookFilterSlider.value)
        selectedProfile.phase2StrokeSampleIndexEnd = Int32(strokeEqualizationDepthSlider.value)
        selectedProfile.strokeEqualizationStrength = CGFloat(strokeEqualizationStrengthSlider.value)

        oscProfileMan.replaceSelectedProfile(with: selectedProfile, overwriteDefault: true)
        
        DispatchQueue.main.async {
            if self.isFirstLaunch {
                AlertControllerUtil.showAlert(
                    in: self,
                    title: SwiftLocalizationHelper.localizedString(forKey: "Pen Pressure Curve"),
                    message: SwiftLocalizationHelper.localizedString(forKey:"firstPressureCurvePersistTip"),
                    withCancel: false,
                    buttonTitle: SwiftLocalizationHelper.localizedString(forKey: "This tip won't be shown again"),
                    countdown: 11,
                    completion: {
                        PencilHandler.shared?.setupPressureLUT()
                    })
                self.isFirstLaunch = false
            }
            else{
                AlertControllerUtil.autoCompletion = true
                AlertControllerUtil.showAlert(
                    in: self,
                    title: SwiftLocalizationHelper.localizedString(forKey: ""),
                    message: SwiftLocalizationHelper.localizedString(forKey:"Pressure curve saved"),
                    withCancel: false,
                    buttonTitle: "",
                    countdown: 1,
                    completion: {
                        PencilHandler.shared?.setupPressureLUT()
                    })
            }
        }
    }

    @objc private func saveTapped() {
        saveButton.isEnabled = false
        IAPManager.checkPurchaseInfo(.PencilProPack) { info in
            self.saveButton.isEnabled = true
            if info.valid {
                self.persistCurve()
            }
            else{
                IAPManager.inAppPurchaseAction(viewController: self, product: .PencilProPack)
            }
        }
    }

    @objc private func exitTapped() {
        self.dismiss(animated: true)
    }
    
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldReceive touch: UITouch
    ) -> Bool {
        return touch.view == view
    }
    
    @objc private func dismissSelf(){
        dismiss(animated: true, completion: nil)
    }
}
