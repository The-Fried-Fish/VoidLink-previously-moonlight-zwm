import SwiftUI
import UIKit

let usesSwiftUISettingsPicker = false

@available(iOS 14.0, tvOS 14.0, *)
extension View {
    @ViewBuilder
    func settingsTint(_ color: Color) -> some View {
        if #available(iOS 15.0, *) { tint(color) } else { accentColor(color) }
    }
}

/// A selectable option used by the settings picker abstraction.
struct SettingsPickerOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var isEnabled = true

    var id: Value { value }
}

enum SettingsPickerWidthDistribution: Equatable {
    case equal
    case proportionalToContent
}

/// Settings-facing picker abstraction. iOS renders a UISegmentedControl;
/// the tvOS picker implementation intentionally remains deferred.
@available(iOS 14.0, *)
struct SettingsPicker<Value: Hashable>: View {
    @Binding var selection: Value
    /// The UIKit extension's `previousSelectedSegmentIndex`, surfaced to an
    /// owner that needs rollback state for an item action.
    var previousSelectedIndex: Binding<Int>?
    let options: [SettingsPickerOption<Value>]
    var isEnabled = true
    var isUserInteractionEnabled = true
    var widthDistribution: SettingsPickerWidthDistribution = .equal
    var onDisabledOptionTapped: ((Value) -> Void)?
    /// Runs before a user-originated value is committed.
    var onSelectionChanging: ((Int, Value) -> Void)?
    /// Gives an iOS owner the backing control when it must reproduce UIKit's
    /// selected-index + `sendActions(for: .valueChanged)` behavior.
    var onControlResolved: ((UISegmentedControl?) -> Void)?

    init(
        selection: Binding<Value>,
        previousSelectedIndex: Binding<Int>? = nil,
        options: [SettingsPickerOption<Value>],
        isEnabled: Bool = true,
        isUserInteractionEnabled: Bool = true,
        widthDistribution: SettingsPickerWidthDistribution = .equal,
        onDisabledOptionTapped: ((Value) -> Void)? = nil,
        onSelectionChanging: ((Int, Value) -> Void)? = nil,
        onControlResolved: ((UISegmentedControl?) -> Void)? = nil
    ) {
        _selection = selection
        self.previousSelectedIndex = previousSelectedIndex
        self.options = options
        self.isEnabled = isEnabled
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.widthDistribution = widthDistribution
        self.onDisabledOptionTapped = onDisabledOptionTapped
        self.onSelectionChanging = onSelectionChanging
        self.onControlResolved = onControlResolved
    }

    var body: some View {
        if usesSwiftUISettingsPicker {
            SettingsSwiftUISegmentedPicker(
                selection: $selection,
                previousSelectedIndex: previousSelectedIndex,
                options: options,
                isEnabled: isEnabled,
                isUserInteractionEnabled: isUserInteractionEnabled,
                onDisabledOptionTapped: onDisabledOptionTapped,
                onSelectionChanging: onSelectionChanging
            )
            .onAppear {
                onControlResolved?(nil)
            }
        } else {
            SettingsIOSSegmentedPicker(
                selection: $selection,
                previousSelectedIndex: previousSelectedIndex,
                options: options,
                isEnabled: isEnabled,
                isUserInteractionEnabled: isUserInteractionEnabled,
                widthDistribution: widthDistribution,
                onDisabledOptionTapped: onDisabledOptionTapped,
                onSelectionChanging: onSelectionChanging,
                onControlResolved: onControlResolved,
                selectedTintColor: ThemeManager.appSecondaryColor,
                interfaceStyle: ThemeManager.userInterfaceStyle()
            )
        }
    }
}

/// Settings-facing slider abstraction. iOS/iPadOS uses UISlider so scroll-time
/// interaction culling can toggle the backing UIControl without rebuilding
/// SwiftUI body. tvOS keeps a read-only system ProgressView.
@available(iOS 14.0, tvOS 14.0, *)
struct SettingsSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var isEnabled: Bool
    var isUserInteractionEnabled: Bool
    var onEditingChanged: (Bool) -> Void
    var onControlResolved: ((UIControl?) -> Void)?

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        isEnabled: Bool = true,
        isUserInteractionEnabled: Bool = true,
        onEditingChanged: @escaping (Bool) -> Void = { _ in },
        onControlResolved: ((UIControl?) -> Void)? = nil
    ) {
        _value = value
        self.range = range
        self.isEnabled = isEnabled
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.onEditingChanged = onEditingChanged
        self.onControlResolved = onControlResolved
    }

    var body: some View {
#if os(tvOS)
        ProgressView(
            value: min(max(value, range.lowerBound), range.upperBound) - range.lowerBound,
            total: max(range.upperBound - range.lowerBound, .leastNonzeroMagnitude)
        )
        .progressViewStyle(LinearProgressViewStyle())
        .accentColor(Color(ThemeManager.appSecondaryColor))
        .disabled(!isEnabled)
        .allowsHitTesting(isUserInteractionEnabled)
#else
        SettingsIOSSlider(
            value: $value,
            in: range,
            isEnabled: isEnabled,
            isUserInteractionEnabled: isUserInteractionEnabled,
            onEditingChanged: onEditingChanged,
            onControlResolved: onControlResolved
        )
#endif
    }
}

#if !os(tvOS)
@available(iOS 14.0, *)
private struct SettingsIOSSlider: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let isEnabled: Bool
    let isUserInteractionEnabled: Bool
    let onEditingChanged: (Bool) -> Void
    let onControlResolved: ((UIControl?) -> Void)?

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        isEnabled: Bool,
        isUserInteractionEnabled: Bool,
        onEditingChanged: @escaping (Bool) -> Void,
        onControlResolved: ((UIControl?) -> Void)?
    ) {
        _value = value
        self.range = range
        self.isEnabled = isEnabled
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.onEditingChanged = onEditingChanged
        self.onControlResolved = onControlResolved
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.isContinuous = true
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingBegan(_:)),
            for: .touchDown
        )
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingEnded(_:)),
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        updateUIView(slider, context: context)
        onControlResolved?(slider)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.parent = self
        let minimumValue = Float(range.lowerBound)
        let maximumValue = Float(range.upperBound)
        if slider.minimumValue != minimumValue {
            slider.minimumValue = minimumValue
        }
        if slider.maximumValue != maximumValue {
            slider.maximumValue = maximumValue
        }
        let clampedValue = Float(min(max(value, range.lowerBound), range.upperBound))
        if !slider.isTracking && abs(slider.value - clampedValue) > .ulpOfOne {
            slider.value = clampedValue
        }
        if slider.isEnabled != isEnabled {
            slider.isEnabled = isEnabled
        }
        if slider.isUserInteractionEnabled != isUserInteractionEnabled {
            slider.isUserInteractionEnabled = isUserInteractionEnabled
        }
        if slider.minimumTrackTintColor != ThemeManager.appSecondaryColor {
            slider.minimumTrackTintColor = ThemeManager.appSecondaryColor
        }
    }

    static func dismantleUIView(_ slider: UISlider, coordinator: Coordinator) {
        coordinator.parent.onControlResolved?(nil)
    }

    final class Coordinator: NSObject {
        var parent: SettingsIOSSlider

        init(parent: SettingsIOSSlider) {
            self.parent = parent
        }

        @objc func valueChanged(_ slider: UISlider) {
            guard parent.isEnabled, parent.isUserInteractionEnabled else { return }
            parent.value = Double(slider.value)
        }

        @objc func editingBegan(_ slider: UISlider) {
            guard parent.isEnabled, parent.isUserInteractionEnabled else { return }
            parent.onEditingChanged(true)
        }

        @objc func editingEnded(_ slider: UISlider) {
            guard parent.isEnabled, parent.isUserInteractionEnabled else { return }
            parent.onEditingChanged(false)
        }
    }
}
#endif

@available(iOS 14.0, tvOS 14.0, *)
private struct SettingsSwiftUISegmentedPicker<Value: Hashable>: View {
    @Binding var selection: Value
    let previousSelectedIndex: Binding<Int>?
    let options: [SettingsPickerOption<Value>]
    let isEnabled: Bool
    let isUserInteractionEnabled: Bool
    let onDisabledOptionTapped: ((Value) -> Void)?
    let onSelectionChanging: ((Int, Value) -> Void)?

    var body: some View {
        Picker(
            "",
            selection: Binding(
                get: { selection },
                set: { newValue in
                    guard isEnabled, isUserInteractionEnabled else { return }
                    let previousIndex = selectedIndex
                    guard option(for: newValue)?.isEnabled == true else {
                        onDisabledOptionTapped?(newValue)
                        return
                    }

                    if let onSelectionChanging {
                        onSelectionChanging(previousIndex, newValue)
                    } else {
                        publishPreviousSelectedIndex(previousIndex)
                        selection = newValue
                    }
                }
            )
        ) {
            ForEach(options) { option in
                Text(option.title)
                    .tag(option.value)
                    .opacity(option.isEnabled ? 1 : 0.46)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .settingsTint(Color(ThemeManager.appSecondaryColor))
        .labelsHidden()
        .disabled(!isEnabled)
        .allowsHitTesting(isUserInteractionEnabled)
    }

    private var selectedIndex: Int {
        options.firstIndex { $0.value == selection } ?? UISegmentedControl.noSegment
    }

    private func option(for value: Value) -> SettingsPickerOption<Value>? {
        options.first { $0.value == value }
    }

    private func publishPreviousSelectedIndex(_ index: Int) {
        guard index != UISegmentedControl.noSegment else { return }
        previousSelectedIndex?.wrappedValue = index
    }
}

/// Settings-facing toggle abstraction. iOS keeps the system UISwitch visuals,
/// while the tap target is driven by a UIButton just like SettingsInfoButtonControl.
/// This avoids SwiftUI Toggle gesture arbitration with the settings ScrollView and
/// favorite long-press recognizer.
@available(iOS 14.0, tvOS 14.0, *)
struct SettingsToggle: View {
    @Binding var isOn: Bool
    var isEnabled = true
    var isUserInteractionEnabled = true
    var onControlResolved: ((UIControl?) -> Void)?

    init(
        isOn: Binding<Bool>,
        isEnabled: Bool = true,
        isUserInteractionEnabled: Bool = true,
        onControlResolved: ((UIControl?) -> Void)? = nil
    ) {
        _isOn = isOn
        self.isEnabled = isEnabled
        self.isUserInteractionEnabled = isUserInteractionEnabled
        self.onControlResolved = onControlResolved
    }

    var body: some View {
#if os(tvOS)
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .disabled(!isEnabled)
            .allowsHitTesting(isUserInteractionEnabled)
#else
        SettingsIOSButtonSwitch(
            isOn: $isOn,
            isEnabled: isEnabled,
            isUserInteractionEnabled: isUserInteractionEnabled,
            onControlResolved: onControlResolved
        )
#endif
    }
}

#if !os(tvOS)
@available(iOS 14.0, *)
private struct SettingsIOSButtonSwitch: UIViewRepresentable {
    @Binding var isOn: Bool
    let isEnabled: Bool
    let isUserInteractionEnabled: Bool
    let onControlResolved: ((UIControl?) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> SwitchContainerView {
        let view = SwitchContainerView()
        view.button.addTarget(
            context.coordinator,
            action: #selector(Coordinator.tapped(_:)),
            for: .touchUpInside
        )
        view.button.adjustsImageWhenHighlighted = false
        view.button.accessibilityIdentifier = "settingsSwitchTapTarget"
        updateUIView(view, context: context)
        onControlResolved?(view.button)
        return view
    }

    func updateUIView(_ view: SwitchContainerView, context: Context) {
        context.coordinator.parent = self
        if view.uiSwitch.isOn != isOn {
            view.uiSwitch.setOn(isOn, animated: false)
        }
        if view.uiSwitch.isEnabled != isEnabled {
            view.uiSwitch.isEnabled = isEnabled
        }
        if view.uiSwitch.isUserInteractionEnabled {
            view.uiSwitch.isUserInteractionEnabled = false
        }
        if view.button.isEnabled != isEnabled {
            view.button.isEnabled = isEnabled
        }
        if view.button.isUserInteractionEnabled != isUserInteractionEnabled {
            view.button.isUserInteractionEnabled = isUserInteractionEnabled
        }
    }

    static func dismantleUIView(_ view: SwitchContainerView, coordinator: Coordinator) {
        coordinator.parent.onControlResolved?(nil)
    }

    final class Coordinator: NSObject {
        var parent: SettingsIOSButtonSwitch

        init(parent: SettingsIOSButtonSwitch) {
            self.parent = parent
        }

        @objc func tapped(_ sender: UIButton) {
            guard parent.isEnabled,
                  parent.isUserInteractionEnabled,
                  let container = sender.superview as? SwitchContainerView else { return }
            let newValue = !parent.isOn
            container.uiSwitch.setOn(newValue, animated: true)
            parent.isOn = newValue
        }
    }

    final class SwitchContainerView: UIView {
        let uiSwitch = UISwitch()
        let button = UIButton(type: .custom)

        override init(frame: CGRect) {
            super.init(frame: frame)

            uiSwitch.translatesAutoresizingMaskIntoConstraints = false
            button.translatesAutoresizingMaskIntoConstraints = false
            button.backgroundColor = .clear

            addSubview(uiSwitch)
            addSubview(button)

            NSLayoutConstraint.activate([
                uiSwitch.leadingAnchor.constraint(equalTo: leadingAnchor),
                uiSwitch.centerYAnchor.constraint(equalTo: centerYAnchor),
                button.leadingAnchor.constraint(equalTo: leadingAnchor),
                button.trailingAnchor.constraint(equalTo: trailingAnchor),
                button.topAnchor.constraint(equalTo: topAnchor),
                button.bottomAnchor.constraint(equalTo: bottomAnchor),
                heightAnchor.constraint(greaterThanOrEqualTo: uiSwitch.heightAnchor)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var intrinsicContentSize: CGSize {
            uiSwitch.intrinsicContentSize
        }
    }
}
#endif

@available(iOS 14.0, *)
private struct SettingsIOSSegmentedPicker<Value: Hashable>: UIViewRepresentable {
    @Binding var selection: Value
    let previousSelectedIndex: Binding<Int>?
    let options: [SettingsPickerOption<Value>]
    let isEnabled: Bool
    let isUserInteractionEnabled: Bool
    let widthDistribution: SettingsPickerWidthDistribution
    let onDisabledOptionTapped: ((Value) -> Void)?
    let onSelectionChanging: ((Int, Value) -> Void)?
    let onControlResolved: ((UISegmentedControl?) -> Void)?
    let selectedTintColor: UIColor
    let interfaceStyle: UIUserInterfaceStyle

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UISegmentedControl {
        UISegmentedControl.installPreviousSelectionTracking()
        let segmentedControl = UISegmentedControl()
        segmentedControl.setContentHuggingPriority(.defaultLow, for: .horizontal)
        segmentedControl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        segmentedControl.addTarget(
            context.coordinator,
            action: #selector(Coordinator.selectionChanged(_:)),
            for: .valueChanged
        )
        update(segmentedControl, coordinator: context.coordinator, rebuild: true)
        onControlResolved?(segmentedControl)
        return segmentedControl
    }

    func updateUIView(_ segmentedControl: UISegmentedControl, context: Context) {
        context.coordinator.parent = self
        let newValues = options.map(\.value)
        let newTitles = options.map(\.title)
        let rebuild = context.coordinator.values != newValues || context.coordinator.titles != newTitles
        update(segmentedControl, coordinator: context.coordinator, rebuild: rebuild)
    }

    private func update(_ segmentedControl: UISegmentedControl, coordinator: Coordinator, rebuild: Bool) {
        if rebuild {
            segmentedControl.removeAllSegments()
            for (index, option) in options.enumerated() {
                segmentedControl.insertSegment(withTitle: option.title, at: index, animated: false)
            }
            coordinator.values = options.map(\.value)
            coordinator.titles = options.map(\.title)
        }

        if coordinator.isEnabled != isEnabled {
            segmentedControl.isEnabled = isEnabled
            coordinator.isEnabled = isEnabled
        }
        if coordinator.isUserInteractionEnabled != isUserInteractionEnabled {
            segmentedControl.isUserInteractionEnabled = isUserInteractionEnabled
            coordinator.isUserInteractionEnabled = isUserInteractionEnabled
        }
        let apportionsSegmentWidthsByContent = widthDistribution == .proportionalToContent
        if coordinator.apportionsSegmentWidthsByContent != apportionsSegmentWidthsByContent {
            segmentedControl.apportionsSegmentWidthsByContent = apportionsSegmentWidthsByContent
            coordinator.apportionsSegmentWidthsByContent = apportionsSegmentWidthsByContent
        }
        if coordinator.interfaceStyle != interfaceStyle {
            segmentedControl.overrideUserInterfaceStyle = interfaceStyle
            coordinator.interfaceStyle = interfaceStyle
        }
        coordinator.updateDisabledOptionTapRecognizer(on: segmentedControl)
        if coordinator.tintColor != selectedTintColor {
            segmentedControl.tintColor = selectedTintColor
            coordinator.tintColor = selectedTintColor
        }
        if coordinator.selectedTintColor != selectedTintColor {
            segmentedControl.selectedSegmentTintColor = .clear
            segmentedControl.selectedSegmentTintColor = selectedTintColor
            coordinator.selectedTintColor = selectedTintColor
        }
        let optionEnabledStates = options.map(\.isEnabled)
        if rebuild || coordinator.optionEnabledStates != optionEnabledStates {
            for (index, option) in options.enumerated() {
                segmentedControl.setEnabled(option.isEnabled, forSegmentAt: index)
            }
            coordinator.optionEnabledStates = optionEnabledStates
        }

        let selectedIndex = options.firstIndex { $0.value == selection } ?? UISegmentedControl.noSegment
        if segmentedControl.selectedSegmentIndex != selectedIndex {
            segmentedControl.selectedSegmentIndex = selectedIndex
        }
    }

    final class Coordinator: NSObject {
        var parent: SettingsIOSSegmentedPicker
        var values: [Value] = []
        var titles: [String] = []
        var optionEnabledStates: [Bool] = []
        var isEnabled: Bool?
        var isUserInteractionEnabled: Bool?
        var apportionsSegmentWidthsByContent: Bool?
        var interfaceStyle: UIUserInterfaceStyle?
        var tintColor: UIColor?
        var selectedTintColor: UIColor?
        private weak var disabledOptionTapRecognizer: UITapGestureRecognizer?

        init(parent: SettingsIOSSegmentedPicker) {
            self.parent = parent
        }

        func updateDisabledOptionTapRecognizer(on segmentedControl: UISegmentedControl) {
            let needsRecognizer = parent.onDisabledOptionTapped != nil &&
                parent.options.contains { !$0.isEnabled }
            if needsRecognizer {
                if disabledOptionTapRecognizer == nil {
                    let recognizer = UITapGestureRecognizer(
                        target: self,
                        action: #selector(segmentTapped(_:))
                    )
                    recognizer.cancelsTouchesInView = false
                    segmentedControl.addGestureRecognizer(recognizer)
                    disabledOptionTapRecognizer = recognizer
                }
            } else if let recognizer = disabledOptionTapRecognizer {
                segmentedControl.removeGestureRecognizer(recognizer)
                disabledOptionTapRecognizer = nil
            }
        }

        @objc func selectionChanged(_ sender: UISegmentedControl) {
            guard values.indices.contains(sender.selectedSegmentIndex) else { return }
            let value = values[sender.selectedSegmentIndex]
            guard parent.options.first(where: { $0.value == value })?.isEnabled == true else {
                restoreBindingSelection(in: sender)
                return
            }

            let previousIndex = sender.previousSelectedSegmentIndex
            if let onSelectionChanging = parent.onSelectionChanging {
                onSelectionChanging(previousIndex, value)
            } else {
                publishPreviousSelectedIndex(previousIndex)
                parent.selection = value
            }
            if parent.selection != value {
                restoreBindingSelection(in: sender)
            }
        }

        private func publishPreviousSelectedIndex(_ index: Int) {
            guard index != UISegmentedControl.noSegment else { return }
            parent.previousSelectedIndex?.wrappedValue = index
        }

        @objc func segmentTapped(_ recognizer: UITapGestureRecognizer) {
            guard let segmentedControl = recognizer.view as? UISegmentedControl,
                  !values.isEmpty else { return }
            let visualIndex = min(
                Int(recognizer.location(in: segmentedControl).x /
                    max(segmentedControl.bounds.width / CGFloat(values.count), 1)),
                values.count - 1
            )
            let index = segmentedControl.effectiveUserInterfaceLayoutDirection == .rightToLeft
                ? values.count - visualIndex - 1
                : visualIndex
            guard values.indices.contains(index),
                  parent.options[index].isEnabled == false else { return }
            parent.onDisabledOptionTapped?(values[index])
        }

        private func restoreBindingSelection(in segmentedControl: UISegmentedControl) {
            let selectedIndex = values.firstIndex { $0 == parent.selection }
                ?? UISegmentedControl.noSegment
            segmentedControl.selectedSegmentIndex = selectedIndex
        }
    }
}
