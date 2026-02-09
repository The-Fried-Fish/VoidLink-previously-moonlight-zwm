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
    private let hitRadius: CGFloat = 22
    
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
        ctx.setLineWidth(5)
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
        ctx.setLineWidth(2.5)
        for i in 0..<pts.count {
            let p = map(pts[i])
            if i==0 { ctx.move(to:p) } else { ctx.addLine(to:p) }
        }
        ctx.strokePath()

        for p in pts {
            let c = map(p)
            let r: CGFloat = 4
            ctx.setFillColor(UIColor.systemPurple.cgColor)
            ctx.fill(CGRect(x:c.x-r, y:c.y-r, width:r*2, height:r*2))
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
            setNeedsDisplay()
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
            point.x = 0
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
class PressureCurveViewController: UIViewController {
    
    private var navBar = UINavigationBar()
    
    private var container = UIView()
    private var curveView = PressureCurveView()
        
    private var minPressure: CGFloat = 0
    private var maxPressure: CGFloat = 1
    private var isFirstLaunch: Bool = {
        let key = "hasLaunchedPressureCurveTool"
        let defaults = UserDefaults.standard

        var launchedBefore = defaults.bool(forKey: key)

        if !launchedBefore {
            defaults.set(true, forKey: key)
            return true
        }
        return false
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    
        self.view.isOpaque = false
        self.view.backgroundColor = UIColor.clear // 半透明遮罩
        
        let curveWidth: CGFloat = 400
        let curveHeight: CGFloat = 400
        curveView = PressureCurveView(frame: CGRect(x: 0, y: 0, width: curveWidth, height: curveHeight))
        curveView.center = self.view.center
        curveView.backgroundColor = .white
        curveView.layer.cornerRadius = 0
        curveView.layer.masksToBounds = true
        
        container = UIView(frame: CGRect(x: 0, y: 0, width: curveWidth+10, height: curveHeight+50))
        container.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY-20)
        container.backgroundColor = .white
        container.layer.cornerRadius = 12
        container.layer.masksToBounds = true
        container.layer.borderWidth = 2
        container.layer.borderColor = ThemeManager.separatorColor().cgColor
        container.addSubview(curveView)
        self.loadPersistedCurve()
        self.curveView.showGraph = true
        
        self.setupNavigationBar()
        
        self.view.addSubview(container)
        
        curveView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            curveView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            curveView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            curveView.widthAnchor.constraint(equalToConstant: curveWidth),
            curveView.heightAnchor.constraint(equalToConstant: curveHeight)
        ])
        
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
        let persistedCurvePoints = PressureCurve.importCurvePoints(oscProfileMan.getSelectedProfile().pressureCurvePoints)
        curveView.curve.polylinePoints = persistedCurvePoints
        curveView.setNeedsDisplay()
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
            appearance.configureWithTransparentBackground() // 透明背景
            appearance.shadowColor = nil // 去掉底部细线
            appearance.backgroundColor = .clear // 可以额外设置完全透明
            
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
            navBar.heightAnchor.constraint(equalToConstant: 42) // 导航栏标准高度
        ])

        
        if curveView.testStage == .curveStage {
            let resetButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Reset"), style: .plain, target: self, action: #selector(resetTapped))
            let rangeTestButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Pressure-range-test"), style: .plain, target: self, action: #selector(pressureRangeTest))
            let saveButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Save"), style: .plain, target: self, action: #selector(saveTapped))
            let quitButton = UIBarButtonItem(title: SwiftLocalizationHelper.localizedString(forKey: "Exit"), style: .plain, target: self, action: #selector(exitTapped))
            navItem.leftBarButtonItems = [resetButton, rangeTestButton]
            navItem.rightBarButtonItems = [quitButton, saveButton]
        }
        
        if curveView.testStage == .drawingStage {
            navItem = UINavigationItem(title: SwiftLocalizationHelper.localizedString(forKey: "Pressure Range Test"))
        }

        // 4. 将 UINavigationItem 添加到导航栏
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
    
    @objc private func persistCurve() {
        let oscProfileMan = OSCProfilesManager.sharedManager(CGRectZero)
        let selectedProfile = oscProfileMan.getSelectedProfile()
        selectedProfile.pressureCurvePoints = PressureCurve.exportCurvePoints(curveView.curve)
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
        IAPManager.checkPurchaseInfo(.PencilProPack) { info in
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
}
