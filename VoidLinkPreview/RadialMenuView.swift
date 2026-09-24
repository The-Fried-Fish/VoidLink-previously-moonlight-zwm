//
//  RadialMenuView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/6/29.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import Combine
import UIKit

@objc public enum RadialMenuItem:Int {
    case settings
    case favoriteSettings
    case allSettings
    case addHost
    case aboutView
    case hostView
    case gameProfiles
    case disconnect
    case mouse
    case quitApp
    case theme
    case more
    case navigationSettings
    case exit
    case toolbox
    case textInput
}

@objc public enum RadialMenuState:Int {
    case main
    case mouseModeEnabled
    case disconnectAndQuit
    case moreOptions
}

@available(iOS 13.0, tvOS 13.0, *)
struct RadialMenuSector: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbolName: String
    let item: RadialMenuItem

    init(title: String, subtitle: String, symbol: String, item: RadialMenuItem) {
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbol
        self.item = item
    }
}

@available(iOS 13.0, tvOS 13.0, *)
struct RadialMenuStyle: Equatable {
    var ringColor = Color(white: 0.86)
    var selectedRingColor = Color(red: 0.19, green: 0.72, blue: 0.96)
    var ringStrokeColor = Color.white.opacity(0.72)
    var centerFillColor = Color(ThemeManager.hostViewBackgroundColor.withAlphaComponent(0.5))
    var iconColor = Color(white: 0.23)
    var selectedIconColor = Color(white: 0.16)
    var titleColor = Color(white: 0.24)
    var subtitleColor = Color(white: 0.48)
    var shadowColor = Color.black.opacity(0.18)
    var ringWidthRatio: CGFloat = 0.41
    var segmentGapWidth: CGFloat = PublicUtils.isTVOS ? 2 : 1
    var centerIconScale: CGFloat = 0.13
    var segmentIconScale: CGFloat = 0.085

    static func themed(for userInterfaceStyle: UIUserInterfaceStyle, accentColor: UIColor) -> RadialMenuStyle {
        switch userInterfaceStyle {
        case .dark:
            return RadialMenuStyle(
                ringColor: Color(UIColor(red: 44.0 / 255.0, green: 44.0 / 255.0, blue: 46.0 / 255.0, alpha: 0.88)),
                selectedRingColor: Color(accentColor.withAlphaComponent(0.52)),
                ringStrokeColor: Color.white.opacity(0.26),
                // centerFillColor: Color(UIColor(red: 28.0 / 255.0, green: 28.0 / 255.0, blue: 30.0 / 255.0, alpha: 0.96)),
                centerFillColor: Color(ThemeManager.hostViewBackgroundColor.withAlphaComponent(0.5)),
                iconColor: Color(UIColor(white: 0.86, alpha: 1)),
                selectedIconColor: Color.white,
                titleColor: Color(UIColor(white: 0.92, alpha: 1)),
                subtitleColor: Color(UIColor(white: 0.70, alpha: 1)),
                shadowColor: Color(accentColor.withAlphaComponent(0)),
                ringWidthRatio: 0.41,
                // segmentGapWidth: 1,
                centerIconScale: 0.16,
                segmentIconScale: 0.085
            )
        default:
            return RadialMenuStyle(
                selectedRingColor: Color(accentColor.withAlphaComponent(0.86))
            )
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
enum RadialMenuSelectionChangeReason {
    case began
    case moved
    case released
    case unchanged
}

@available(iOS 13.0, tvOS 13.0, *)
final class RadialMenuSelectionState: ObservableObject {
    @Published private(set) var selectedIndex: Int?
    @Published private(set) var hasReceivedJoystickInput = false
    @Published private(set) var lastChangeReason: RadialMenuSelectionChangeReason = .unchanged

    private var itemCount = 0

    func updateSelection(xOffset: CGFloat, yOffset: CGFloat) {
        updateSelection(xOffset: xOffset, yOffset: yOffset, deadZone: 0.1)
    }

    func updateSelection(xOffset: CGFloat, yOffset: CGFloat, deadZone: CGFloat) {
        let x = max(min(xOffset, 1), -1)
        let y = max(min(yOffset, 1), -1)
        let distance = hypot(x, y)
        if distance < deadZone {
            guard !hasReceivedJoystickInput || selectedIndex != nil else {
                lastChangeReason = .unchanged
                return
            }

            hasReceivedJoystickInput = true
            lastChangeReason = selectedIndex == nil ? .unchanged : .released
            selectedIndex = nil
            return
        }

        // Near center, tiny return-to-center offsets have unstable angles. Keep the
        // last high-confidence sector until the stick fully enters the dead zone.
        let selectionUpdateDeadZone = max(deadZone, 0.35)
        guard distance >= selectionUpdateDeadZone else {
            hasReceivedJoystickInput = true
            lastChangeReason = .unchanged
            return
        }

        let nextSelectedIndex = Self.selectedIndex(
            xOffset: x,
            yOffset: y,
            itemCount: itemCount,
            deadZone: deadZone
        )

        guard !hasReceivedJoystickInput || nextSelectedIndex != selectedIndex else {
            lastChangeReason = .unchanged
            return
        }

        let previousSelectedIndex = selectedIndex
        hasReceivedJoystickInput = true
        selectedIndex = nextSelectedIndex
        lastChangeReason = Self.changeReason(from: previousSelectedIndex, to: nextSelectedIndex)
    }

    fileprivate func configureItemCount(_ itemCount: Int) {
        self.itemCount = max(itemCount, 0)
        if let selectedIndex, selectedIndex >= itemCount {
            self.selectedIndex = nil
        }
    }

    static func selectedIndex(xOffset: CGFloat, yOffset: CGFloat, itemCount: Int, deadZone: CGFloat = 0.1) -> Int? {
        guard itemCount > 0 else { return nil }

        let x = max(min(xOffset, 1), -1)
        let y = max(min(yOffset, 1), -1)
        let distance = hypot(x, y)
        guard distance >= deadZone else {
            return nil
        }

        let clockwiseDegreesFromWest = positiveRemainder(atan2(Double(y), -Double(x)) * 180 / .pi, 360)
        let segmentDegrees = 360 / Double(itemCount)
        let centeredDegrees = positiveRemainder(clockwiseDegreesFromWest + segmentDegrees / 2, 360)
        return min(Int(centeredDegrees / segmentDegrees), itemCount - 1)
    }

    private static func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }

    private static func changeReason(from previousIndex: Int?, to nextIndex: Int?) -> RadialMenuSelectionChangeReason {
        switch (previousIndex, nextIndex) {
        case (nil, .some):
            return .began
        case (.some(let previous), .some(let next)) where previous != next:
            return .moved
        case (.some, nil):
            return .released
        default:
            return .unchanged
        }
    }
}

@available(iOS 13.0, tvOS 13.0, *)
struct RadialMenuView: View {
    let sectors: [RadialMenuSector]
    var selectedIndex: Int?
    var isTouchSelectionEnabled: Bool
    var style: RadialMenuStyle

    @ObservedObject private var joystickSelectionState: RadialMenuSelectionState
    @SwiftUI.State private var touchSelectedIndex: Int?

    private var effectiveSelectedIndex: Int? {
        if isTouchSelectionEnabled, let touchSelectedIndex {
            return touchSelectedIndex
        }

        if joystickSelectionState.hasReceivedJoystickInput {
            return joystickSelectionState.selectedIndex
        }

        return selectedIndex
    }

    private var selectedItem: RadialMenuSector? {
        guard let selectedIndex = effectiveSelectedIndex,
              sectors.indices.contains(selectedIndex) else {
            return sectors.first
        }
        return sectors[selectedIndex]
    }

    init(
        sectors: [RadialMenuSector],
        selectedIndex: Int? = nil,
        isTouchSelectionEnabled: Bool = true,
        style: RadialMenuStyle = RadialMenuStyle(),
        selectionState: RadialMenuSelectionState = RadialMenuSelectionState()
    ) {
        self.sectors = sectors
        self.selectedIndex = selectedIndex
        self.isTouchSelectionEnabled = isTouchSelectionEnabled
        self.style = style
        self.joystickSelectionState = selectionState
        self.joystickSelectionState.configureItemCount(sectors.count)
    }

    func updateSelection(xOffset: CGFloat, yOffset: CGFloat) {
        joystickSelectionState.configureItemCount(sectors.count)
        joystickSelectionState.updateSelection(xOffset: xOffset, yOffset: yOffset)
    }

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            let outerRadius = diameter / 2
            let innerRadius = outerRadius * (1 - style.ringWidthRatio)

            ZStack {
                ForEach(sectors.indices, id: \.self) { index in
                    RadialMenuSegmentShape(
                        index: index,
                        count: sectors.count,
                        innerRadiusRatio: 1 - style.ringWidthRatio,
                        gapWidth: style.segmentGapWidth
                    )
                    .fill(index == effectiveSelectedIndex ? style.selectedRingColor : style.ringColor)
                    .overlay(
                        RadialMenuSegmentShape(
                            index: index,
                            count: sectors.count,
                            innerRadiusRatio: 1 - style.ringWidthRatio,
                            gapWidth: style.segmentGapWidth
                        )
                        .stroke(style.ringStrokeColor.opacity(index == effectiveSelectedIndex ? 0.95 : 0.28), lineWidth: index == effectiveSelectedIndex ? 1.6 : 0.8)
                    )
                    .scaleEffect(index == effectiveSelectedIndex ? 1.018 : 1)
                    .animation(.spring(response: 0.24, dampingFraction: 0.78), value: effectiveSelectedIndex)
                }

                Circle()
                    .fill(style.centerFillColor)
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .shadow(color: style.shadowColor, radius: 10, x: 0, y: 3)

                ForEach(sectors.indices, id: \.self) { index in
                    let item = sectors[index]
                    RadialMenuIconView(
                        symbolName: item.symbolName,
                        fallbackSystemName: "circle",
                        size: max(diameter * style.segmentIconScale, 18),
                        weight: .medium,
                        color: index == effectiveSelectedIndex ? style.selectedIconColor : style.iconColor
                    )
                        .scaleEffect(index == effectiveSelectedIndex ? 1.18 : 1)
                        .position(iconPosition(index: index, count: sectors.count, center: center, radius: (outerRadius + innerRadius) / 2))
                        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: effectiveSelectedIndex)
                }

                RadialMenuCenterView(item: selectedItem, style: style, diameter: diameter)
                    .frame(width: innerRadius * 1.72, height: innerRadius * 1.72)
                    .position(center)
                    .animation(.easeInOut(duration: selectedItem?.item == .gameProfiles ? 0 : 0.16), value: effectiveSelectedIndex)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Circle())
            #if !os(tvOS)
            .gesture(touchSelectionGesture(center: center, innerRadius: innerRadius, outerRadius: outerRadius))
            #endif
        }
        .aspectRatio(1, contentMode: .fit)
    }

#if !os(tvOS)
    private func touchSelectionGesture(center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                guard isTouchSelectionEnabled else { return }
                touchSelectedIndex = index(for: value.location, center: center, innerRadius: innerRadius, outerRadius: outerRadius)
            }
            .onEnded { _ in
                guard isTouchSelectionEnabled else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    touchSelectedIndex = nil
                }
            }
    }
#endif

    private func index(for location: CGPoint, center: CGPoint, innerRadius: CGFloat, outerRadius: CGFloat) -> Int? {
        guard !sectors.isEmpty else { return nil }

        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = hypot(dx, dy)
        guard distance >= innerRadius * 0.72, distance <= outerRadius * 1.08 else {
            return nil
        }

        let clockwiseDegreesFromWest = positiveRemainder(atan2(Double(-dy), Double(-dx)) * 180 / Double.pi, 360)
        let segmentDegrees = 360 / Double(sectors.count)
        let centeredDegrees = positiveRemainder(clockwiseDegreesFromWest + segmentDegrees / 2, 360)
        return min(Int(centeredDegrees / segmentDegrees), sectors.count - 1)
    }

    private func iconPosition(index: Int, count: Int, center: CGPoint, radius: CGFloat) -> CGPoint {
        guard count > 0 else { return center }
        let segmentDegrees = 360 / Double(count)
        let angleDegrees = 180 + Double(index) * segmentDegrees
        let radians = angleDegrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }

    private func positiveRemainder(_ value: Double, _ divisor: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: divisor)
        return remainder >= 0 ? remainder : remainder + divisor
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct RadialMenuCenterView: View {
    let item: RadialMenuSector?
    let style: RadialMenuStyle
    let diameter: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            RadialMenuIconView(
                symbolName: item?.symbolName ?? "circle.grid.cross",
                fallbackSystemName: "circle.grid.cross",
                size: centerIconSize,
                weight: .medium,
                color: style.iconColor
            )
                .id(item?.id)
                .transition(.opacity)
                .frame(width: centerIconSize * 1.35, height: centerIconSize * 1.2)
                .padding(.bottom, centerIconTitleSpacing)

            Text(item?.title ?? "")
                .font(.system(size: max(diameter * 0.047, 13), weight: .semibold))
                .foregroundColor(style.titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .padding(.bottom, item?.subtitle.isEmpty == false ? centerTextSpacing : 0)

            if item?.subtitle.isEmpty == false {
                Text(item?.subtitle ?? "")
                    .font(.system(size: max(diameter * 0.032, 10), weight: .regular))
                    .foregroundColor(style.subtitleColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, diameter * 0.035)
    }

    private var centerIconSize: CGFloat {
        max(diameter * style.centerIconScale, 28)
    }

    private var centerTextSpacing: CGFloat {
        max(diameter * 0.013, 3.3)
    }

    private var centerIconTitleSpacing: CGFloat {
        if #available(iOS 14.0, *) {
            return centerTextSpacing
        }

        return 3.6
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct RadialMenuIconView: View {
    let symbolName: String
    let fallbackSystemName: String
    let size: CGFloat
    let weight: Font.Weight
    let color: Color

    var body: some View {
        Group {
            if UIImage(systemName: symbolName) != nil {
                Image(systemName: symbolName)
                    .font(.system(size: size, weight: weight))
            } else if let assetImage = RadialMenuIconImageRenderer.templateImage(named: symbolName, pointSize: size) {
                Image(uiImage: assetImage)
                    .renderingMode(.template)
            } else {
                Image(systemName: fallbackSystemName)
                    .font(.system(size: size, weight: weight))
            }
        }
        .foregroundColor(color)
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private enum RadialMenuIconImageRenderer {
    private static let cache = NSCache<NSString, UIImage>()
    private static let assetCanvasScale: CGFloat = 1.05
    private static let assetVisualScale: CGFloat = 1

    static func templateImage(named name: String, pointSize: CGFloat) -> UIImage? {
        let scale = UIScreen.main.scale
        let normalizedPointSize = max(ceil(pointSize * 2) / 2, 1)
        let cacheKey = "\(name)-\(normalizedPointSize)-\(scale)-\(assetCanvasScale)-\(assetVisualScale)" as NSString

        if let cachedImage = cache.object(forKey: cacheKey) {
            return cachedImage
        }

        guard let sourceImage = UIImage(named: name) else {
            return nil
        }

        let canvasSize = CGSize(
            width: normalizedPointSize * assetCanvasScale,
            height: normalizedPointSize * assetCanvasScale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let renderedImage = UIGraphicsImageRenderer(size: canvasSize, format: format).image { _ in
            let drawBounds = scaledRect(
                CGRect(origin: .zero, size: canvasSize),
                by: assetVisualScale
            )
            sourceImage.draw(in: aspectFitRect(for: sourceImage.size, in: drawBounds))
        }.withRenderingMode(.alwaysTemplate)

        cache.setObject(renderedImage, forKey: cacheKey)
        return renderedImage
    }

    private static func scaledRect(_ rect: CGRect, by scale: CGFloat) -> CGRect {
        let width = rect.width * scale
        let height = rect.height * scale
        return CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - height / 2,
            width: width,
            height: height
        )
    }

    private static func aspectFitRect(for sourceSize: CGSize, in bounds: CGRect) -> CGRect {
        guard sourceSize.width > 0, sourceSize.height > 0 else {
            return bounds
        }

        let scale = min(bounds.width / sourceSize.width, bounds.height / sourceSize.height)
        let width = sourceSize.width * scale
        let height = sourceSize.height * scale
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }
}

@available(iOS 13.0, tvOS 13.0, *)
private struct RadialMenuSegmentShape: Shape {
    let index: Int
    let count: Int
    let innerRadiusRatio: CGFloat
    let gapWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        guard count > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let segmentDegrees = 360 / Double(count)
        let centerDegrees = 180 + Double(index) * segmentDegrees
        let startBoundaryDegrees = centerDegrees - segmentDegrees / 2
        let endBoundaryDegrees = centerDegrees + segmentDegrees / 2
        let halfGap = min(gapWidth / 2, max(innerRadius - 1, 0))

        var path = Path()
        let outerStart = offsetBoundaryPoint(center: center, radius: outerRadius, boundaryDegrees: startBoundaryDegrees, inwardSign: 1, halfGap: halfGap)
        let innerStart = offsetBoundaryPoint(center: center, radius: innerRadius, boundaryDegrees: startBoundaryDegrees, inwardSign: 1, halfGap: halfGap)
        let outerEnd = offsetBoundaryPoint(center: center, radius: outerRadius, boundaryDegrees: endBoundaryDegrees, inwardSign: -1, halfGap: halfGap)
        let innerEnd = offsetBoundaryPoint(center: center, radius: innerRadius, boundaryDegrees: endBoundaryDegrees, inwardSign: -1, halfGap: halfGap)
        let outerStartDegrees = degrees(from: center, to: outerStart)
        let outerEndDegrees = unwrappedEndDegrees(start: outerStartDegrees, end: degrees(from: center, to: outerEnd))
        let innerStartDegrees = degrees(from: center, to: innerStart)
        let innerEndDegrees = unwrappedEndDegrees(start: innerStartDegrees, end: degrees(from: center, to: innerEnd))

        path.move(to: outerStart)

        let outerSteps = max(Int((outerEndDegrees - outerStartDegrees) / 4), 6)
        for step in 1...outerSteps {
            let progress = Double(step) / Double(outerSteps)
            let degrees = outerStartDegrees + (outerEndDegrees - outerStartDegrees) * progress
            path.addLine(to: point(center: center, radius: outerRadius, degrees: degrees))
        }

        path.addLine(to: innerEnd)

        let innerSteps = max(Int((innerEndDegrees - innerStartDegrees) / 4), 6)
        for step in 0...innerSteps {
            let progress = Double(step) / Double(innerSteps)
            let degrees = innerEndDegrees - (innerEndDegrees - innerStartDegrees) * progress
            path.addLine(to: point(center: center, radius: innerRadius, degrees: degrees))
        }

        path.addLine(to: outerStart)
        path.closeSubpath()
        return path
    }

    private func offsetBoundaryPoint(
        center: CGPoint,
        radius: CGFloat,
        boundaryDegrees: Double,
        inwardSign: CGFloat,
        halfGap: CGFloat
    ) -> CGPoint {
        let radians = boundaryDegrees * .pi / 180
        let radialX = CGFloat(cos(radians))
        let radialY = CGFloat(sin(radians))
        let tangentX = -radialY
        let tangentY = radialX
        let radialDistance = sqrt(max(radius * radius - halfGap * halfGap, 0))

        return CGPoint(
            x: center.x + radialX * radialDistance + tangentX * halfGap * inwardSign,
            y: center.y + radialY * radialDistance + tangentY * halfGap * inwardSign
        )
    }

    private func point(center: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(
            x: center.x + CGFloat(cos(radians)) * radius,
            y: center.y + CGFloat(sin(radians)) * radius
        )
    }

    private func degrees(from center: CGPoint, to point: CGPoint) -> Double {
        atan2(point.y - center.y, point.x - center.x) * 180 / .pi
    }

    private func unwrappedEndDegrees(start: Double, end: Double) -> Double {
        end < start ? end + 360 : end
    }
}

#if !os(tvOS)
@available(iOS 13.0, tvOS 13.0, *)
struct RadialMenuDemoView: View {
    @SwiftUI.State private var itemCount = 8
    @SwiftUI.State private var isTouchSelectionEnabled = true

    static let menuItems = [
        RadialMenuSector(title: "Settings Menu".localized, subtitle: "", symbol: "sidebar.left", item: .settings),
        RadialMenuSector(title: "Host View".localized, subtitle: "", symbol: PublicUtils.liquidGlassEnabled ? "macwindow.on.rectangle" : "tv", item: .hostView),
        RadialMenuSector(title: "Game Profiles".localized, subtitle: "", symbol: "gamecontroller.circle", item: .gameProfiles),
        RadialMenuSector(title: "Exit/Disconnect".localized, subtitle: "", symbol: "personalhotspot.slash", item: .gameProfiles),
    ]

    private var visibleItems: [RadialMenuSector] {
        Array(Self.menuItems.prefix(itemCount))
    }

    var body: some View {
        VStack(spacing: 28) {
            RadialMenuView(
                sectors: visibleItems,
                selectedIndex: isTouchSelectionEnabled ? nil : 2,
                isTouchSelectionEnabled: isTouchSelectionEnabled
            )
            .frame(width: 320, height: 320)
            .padding(.top, 24)

            VStack(spacing: 16) {
                Stepper("Segments: \(itemCount)", value: $itemCount, in: 3...RadialMenuDemoView.menuItems.count)
                    .frame(maxWidth: 320)

                Toggle("Touch selection", isOn: $isTouchSelectionEnabled)
                    .frame(maxWidth: 320)
            }
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.97))
    }
}

@available(iOS 13.0, tvOS 13.0, *)
struct RadialMenuView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RadialMenuDemoView()
                .previewLayout(.sizeThatFits)

            RadialMenuView(
                sectors: Array(RadialMenuDemoView.menuItems.prefix(6)),
                selectedIndex: 1,
                isTouchSelectionEnabled: false
            )
            .frame(width: 300, height: 300)
            .padding(36)
            .previewLayout(.sizeThatFits)
        }
    }
}
#endif
