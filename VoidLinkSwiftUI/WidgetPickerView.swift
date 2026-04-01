//
//  WidgetPickerView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/4/1.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import UIKit

@available(iOS 13.0, *)
enum WidgetPickerTab: String, CaseIterable, Identifiable, Equatable {
    case gamepad = "Gamepad"
    case keyboard = "Keyboard & Mouse"
    case functional = "Functional"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gamepad:
            return SwiftLocalizationHelper.localizedString(forKey: "Gamepad")
        case .keyboard:
            return SwiftLocalizationHelper.localizedString(forKey: "Keyboard / Mouse")
        case .functional:
            return SwiftLocalizationHelper.localizedString(forKey: "Functional Buttons")
        }
    }

    init?(identifier: String) {
        switch identifier.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "gamepad", "Gamepad":
            self = .gamepad
        case "keyboard", "keyboardmouse", "keyboard_mouse", "keyboard-mouse":
            self = .keyboard
        case "functional", "function", "functions":
            self = .functional
        default:
            return nil
        }
    }
}

@available(iOS 13.0, *)
enum WidgetPoolSource: Equatable {
    case gamepad
    case keyboard
    case functional
}

@available(iOS 13.0, *)
enum WidgetPoolVisualKind: Equatable {
    case gamepadButton
    case gamepadPad
    case keyboardButton
    case keyboardPad
    case functionalButton
}

@available(iOS 13.0, *)
struct WidgetPoolItem: Identifiable {
    let id = UUID()
    let cmd: String
    let source: WidgetPoolSource
    let visualKind: WidgetPoolVisualKind
    let staysAtTail: Bool
    let displayText: String?

    var displayCmd: String {
        switch source {
        case .gamepad:
            if cmd.hasPrefix("OSC") {
                return String(cmd.dropFirst(3))
            }
            return cmd
        case .keyboard:
            return displayText ?? cmd
        case .functional:
            return cmd
        }
    }

    var span: Int {
        switch visualKind {
        case .gamepadButton, .keyboardButton, .functionalButton:
            return 1
        case .gamepadPad, .keyboardPad:
            return 2
        }
    }
}

@available(iOS 13.0, *)
struct WidgetPoolPlacement: Identifiable {
    let id: UUID
    let item: WidgetPoolItem
    let row: Int
    let column: Int
}

@available(iOS 13.0, *)
private enum PoolPadHighlightStyle {
    static let fillTop = Color(red: 0.82, green: 0.84, blue: 1.00).opacity(0.92)
    static let fillBottom = Color(red: 0.56, green: 0.60, blue: 0.94).opacity(0.84)
    static let stroke = Color(red: 0.38, green: 0.42, blue: 0.82).opacity(0.90)
}

@available(iOS 13.0, *)
private enum WidgetCreateTargetKind {
    case button
    case pad
}

@available(iOS 13.0, *)
private enum WidgetPickerSubmissionAction: String {
    case create
    case modify

    var payloadValue: String { rawValue }

    var confirmationTitle: String {
        switch self {
        case .create:
            return SwiftLocalizationHelper.localizedString(forKey: "Create New")
        case .modify:
            return SwiftLocalizationHelper.localizedString(forKey: "Modify")
        }
    }

    var poolActionTitle: String {
        switch self {
        case .create:
            return SwiftLocalizationHelper.localizedString(forKey: "Create New")
        case .modify:
            return SwiftLocalizationHelper.localizedString(forKey: "Modify")
        }
    }
}

@available(iOS 13.0, *)
enum WidgetCreateComboMode: String, CaseIterable, Identifiable {
    case skill
    case shortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .skill:
            return SwiftLocalizationHelper.localizedString(forKey: "Skill combo")
        case .shortcut:
            return SwiftLocalizationHelper.localizedString(forKey: "Shortcut combo")
        }
    }
}

@available(iOS 13.0, *)
private enum WidgetCreateShape: String, CaseIterable, Identifiable {
    case round = "r"
    case square = "s"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .round:
            return SwiftLocalizationHelper.localizedString(forKey: "Circle")
        case .square:
            return SwiftLocalizationHelper.localizedString(forKey: "Square")
        }
    }
}

@available(iOS 13.0, *)
struct GyroButtonOption: Identifiable {
    let id = UUID()
    let cmd: String
    let description: String
}

@available(iOS 13.0, *)
struct FunctionalButtonOption: Identifiable {
    let id = UUID()
    let label: String
    let cmd: String
    let tip: String
    let allowsKeyboardCombination: Bool
    let allowsGamepadCombination: Bool
    let allowsSkillCombo: Bool
    let allowsShortcutCombo: Bool
    let forcedComboMode: WidgetCreateComboMode?
}

@available(iOS 13.0, *)
private struct WidgetPickerMetrics {
    let isPhone: Bool
    let outerPadding: CGFloat
    let panelSpacing: CGFloat
    let blurPadding: CGFloat
    let blurCornerRadius: CGFloat
    let panelPadding: CGFloat
    let panelCornerRadius: CGFloat
    let panelShadowRadius: CGFloat
    let panelShadowYOffset: CGFloat
    let sectionSpacing: CGFloat
    let pickerSectionSpacing: CGFloat
    let poolSectionSpacing: CGFloat
    let headerSpacing: CGFloat
    let titleFontSize: CGFloat
    let poolTitleFontSize: CGFloat
    let subtitleFontSize: CGFloat
    let tabSpacing: CGFloat
    let tabFontSize: CGFloat
    let tabHorizontalPadding: CGFloat
    let tabHeight: CGFloat
    let pickerInsetKeyboard: CGFloat
    let pickerInsetGamepadHorizontal: CGFloat
    let pickerInsetGamepadVertical: CGFloat
    let pickerInsetFunctional: CGFloat
    let pickerSurfaceCornerRadius: CGFloat
    let tipHeight: CGFloat
    let tipFontSize: CGFloat
    let chipHeight: CGFloat
    let chipFontSize: CGFloat
    let chipCornerRadius: CGFloat
    let poolGridSpacing: CGFloat
    let poolGridInset: CGFloat
    let rightPanelMinWidth: CGFloat
    let leftWidthRatio: CGFloat

    static func make(for isPhone: Bool) -> WidgetPickerMetrics {
        WidgetPickerMetrics(
            isPhone: isPhone,
            outerPadding: isPhone ? 4 : 24,
            panelSpacing: isPhone ? 6 : 22,
            blurPadding: isPhone ? 4 : 18,
            blurCornerRadius: isPhone ? 20 : 34,
            panelPadding: isPhone ? 7 : 22,
            panelCornerRadius: isPhone ? 18 : 30,
            panelShadowRadius: isPhone ? 8 : 22,
            panelShadowYOffset: isPhone ? 4 : 12,
            sectionSpacing: isPhone ? 2.5 : 18,
            pickerSectionSpacing: isPhone ? 3 : 13,
            poolSectionSpacing: isPhone ? 9 : 24,
            headerSpacing: isPhone ? 0.5 : 6,
            titleFontSize: isPhone ? 11.5 : 28,
            poolTitleFontSize: isPhone ? 11 : 20,
            subtitleFontSize: isPhone ? 7 : 13,
            tabSpacing: isPhone ? 4 : 10,
            tabFontSize: isPhone ? 7.2 : 13,
            tabHorizontalPadding: isPhone ? 5 : 16,
            tabHeight: isPhone ? 16 : 38,
            pickerInsetKeyboard: isPhone ? 1 : 16,
            pickerInsetGamepadHorizontal: isPhone ? 10 : 24,
            pickerInsetGamepadVertical: isPhone ? 10 : 24,
            pickerInsetFunctional: isPhone ? 2 : 24,
            pickerSurfaceCornerRadius: isPhone ? 14 : 28,
            tipHeight: isPhone ? 36 : 68,
            tipFontSize: isPhone ? 9.5 : 13,
            chipHeight: isPhone ? 24 : 46,
            chipFontSize: isPhone ? 9.5 : 14,
            chipCornerRadius: isPhone ? 9 : 16,
            poolGridSpacing: isPhone ? 3 : 10,
            poolGridInset: isPhone ? 5 : 14,
            rightPanelMinWidth: isPhone ? 180 : 280,
            leftWidthRatio: isPhone ? 0.68 : 0.64
        )
    }
}

@available(iOS 13.0, *)
struct WidgetPickerView: View {
    private enum PoolTipMessageType {
        case normal
        case error
    }

    private let maxPoolSlots = 16
    private let isEditMode: Bool
    private let initialCmdString: String?
    private let initialButtonLabel: String?
    private let initialShape: String?
    private let availableTabs: [WidgetPickerTab]
    private let preferredInitialTab: WidgetPickerTab?
    var onWidgetCreated: (([String: String]) -> Void)? = nil
    var onCloseRequested: (() -> Void)? = nil

    @SwiftUI.State private var selectedTab: WidgetPickerTab
    @SwiftUI.State private var selectedGamepadType: GamepadType = .xbox
    @SwiftUI.State private var selectedCmds: [String] = []
    @SwiftUI.State private var poolItems: [WidgetPoolItem] = []
    @SwiftUI.State private var resetToken: Int = 0
    @SwiftUI.State private var tipMessage: String = SwiftLocalizationHelper.localizedString(forKey: "Tap any control to add it")
    @SwiftUI.State private var tipMessageType: PoolTipMessageType = .normal
    @SwiftUI.State private var keyboardDeselectionCommand: String = ""
    @SwiftUI.State private var keyboardDeselectionToken: Int = 0
    @SwiftUI.State private var gamepadDeselectionCommand: String = ""
    @SwiftUI.State private var gamepadDeselectionToken: Int = 0
    @SwiftUI.State private var showGyroPicker = false
    @SwiftUI.State private var selectedGyroCommand: String? = nil
    @SwiftUI.State private var showCreateWidgetSheet = false
    @SwiftUI.State private var widgetComboMode: WidgetCreateComboMode = .skill
    @SwiftUI.State private var widgetTriggerInterval: Double = 0
    @SwiftUI.State private var widgetShape: WidgetCreateShape = .round
    @SwiftUI.State private var widgetButtonLabel: String = ""
    @SwiftUI.State private var lastCreatedWidgetPayload: [String: String]? = nil
    @SwiftUI.State private var pendingSubmissionAction: WidgetPickerSubmissionAction = .create
    @SwiftUI.State private var didApplyInitialConfiguration: Bool = false
    @SwiftUI.State private var selectionSyncToken: Int = 0

    init(
        isEditMode: Bool = false,
        initialCmdString: String? = nil,
        initialButtonLabel: String? = nil,
        initialShape: String? = nil,
        availableTabs: [WidgetPickerTab] = WidgetPickerTab.allCases,
        preferredInitialTab: WidgetPickerTab? = nil,
        onWidgetCreated: (([String: String]) -> Void)? = nil,
        onCloseRequested: (() -> Void)? = nil
    ) {
        let normalizedTabs = availableTabs.isEmpty ? WidgetPickerTab.allCases : availableTabs
        let resolvedInitialTab = preferredInitialTab.flatMap { normalizedTabs.contains($0) ? $0 : nil }
        self.isEditMode = isEditMode
        self.initialCmdString = initialCmdString
        self.initialButtonLabel = initialButtonLabel
        self.initialShape = initialShape
        self.availableTabs = normalizedTabs
        self.preferredInitialTab = resolvedInitialTab
        self.onWidgetCreated = onWidgetCreated
        self.onCloseRequested = onCloseRequested
        _selectedTab = SwiftUI.State(initialValue: resolvedInitialTab ?? (normalizedTabs.contains(.keyboard) ? .keyboard : normalizedTabs[0]))
    }

    private let functionalButtonOptions: [FunctionalButtonOption] = [
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Settings"),
            cmd: "SETTINGS",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Expands setting menu during streaming"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Folder"),
            cmd: "FOLDER",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Collect, fold & unfold other widgets or subfolders"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Toolbox"),
            cmd: "TOOLBOX",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Activate toolbox menu during streaming"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Edit Layout"),
            cmd: "WIDGETTOOL",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Open on-screen widget layout tool"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Pick profile"),
            cmd: "PICKPRFL",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Pick a game/on-screen-widget profile"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Profiles"),
            cmd: "PROFILES",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Select a game/on-screen-widget profile"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "SoftKeyboard"),
            cmd: "SOFTKEYBOARD",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Bring up softkeyboard"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Disable touch"),
            cmd: "DISABLETOUCH",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Temporarily disable touch input for stream view"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Pressure curve"),
            cmd: "PRESSURECURVE",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Opens pencil pressure curve tool"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Pencil hover"),
            cmd: "PENCILHOVER",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Force pencil entering hovering on host"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Brush shortcut"),
            cmd: "BRUSH",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Combine this with a brush keyboard shortcut for PC software"),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: false,
            allowsShortcutCombo: true,
            forcedComboMode: .shortcut
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Eraser shortcut"),
            cmd: "ERASER",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Combine this with a eraser keyboard shortcut for PC software"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: true,
            forcedComboMode: .shortcut
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Disable single point touch"),
            cmd: "NOSINGLETOUCH",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Disable single finger touch for stream view"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            label: SwiftLocalizationHelper.localizedString(forKey: "Absolute touch drag"),
            cmd: "ABSTCHDRAG",
            tip: SwiftLocalizationHelper.localizedString(forKey: "Replace mouse button action in single point touch mode with another button temporarily"),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: true,
            allowsShortcutCombo: false,
            forcedComboMode: .skill
        ),
    ]

    private var defaultTipMessage: String {
        SwiftLocalizationHelper.localizedString(forKey: "Tap any control to add it")
    }

    private var tipMessageColor: Color {
        switch tipMessageType {
        case .normal:
            return Color.black.opacity(1)
        case .error:
            return Color(red: 0.76, green: 0.30, blue: 0.22)
        }
    }

    private func setTipMessage(_ message: String, type: PoolTipMessageType = .normal) {
        tipMessage = message
        tipMessageType = type
    }

    private func resetTipMessage() {
        setTipMessage(defaultTipMessage)
    }

    private var hasAnySingleItem: Bool {
        poolItems.count == 1
    }

    private var hasMultipleButtonItemsOnly: Bool {
        poolItems.count > 1 && poolItems.allSatisfy { !isPad($0) }
    }

    private var hasButtonThenPadCombination: Bool {
        guard let firstItem = poolItems.first, let lastItem = poolItems.last else { return false }
        return !isPad(firstItem) && isPad(lastItem) && poolItems.contains(where: isPad) && poolItems.contains(where: { !isPad($0) })
    }

    private var hasPadThenButtonCombination: Bool {
        guard let firstItem = poolItems.first, let lastItem = poolItems.last else { return false }
        return isPad(firstItem) && !isPad(lastItem) && poolItems.contains(where: isPad) && poolItems.contains(where: { !isPad($0) })
    }

    private func updateTipMessageForCurrentPoolState() {
        if poolItems.isEmpty {
            resetTipMessage()
        } else if hasButtonThenPadCombination {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "A button with touchpad functionality will be created"))
        } else if hasPadThenButtonCombination {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "A touchpad with double-tap button triggering will be created"))
        } else if let selectedFunctionalButtonOption {
            setTipMessage(selectedFunctionalButtonOption.tip)
        } else if hasAnySingleItem || hasMultipleButtonItemsOnly {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "You can continue adding controls to this combination"))
        } else {
            resetTipMessage()
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = WidgetPickerMetrics.make(for: UIDevice.current.userInterfaceIdiom == .phone)
            let usesVerticalLayout = proxy.size.height > proxy.size.width
            let isPadPortrait = !metrics.isPhone && usesVerticalLayout
            let isPhonePortrait = metrics.isPhone && usesVerticalLayout
            let verticalOuterPadding = isPhonePortrait ? metrics.outerPadding * 0.5 : metrics.outerPadding
            let reclaimedBottomSafeArea = isPhonePortrait ? proxy.safeAreaInsets.bottom : 0
            let leftWidth = max(metrics.isPhone ? 0 : 420, proxy.size.width * metrics.leftWidthRatio)
            let rightWidth = max(
                metrics.rightPanelMinWidth,
                proxy.size.width - leftWidth - metrics.panelSpacing - metrics.outerPadding * 2
            )
            let sharedVerticalAvailableHeight = proxy.size.height - metrics.panelSpacing - verticalOuterPadding * 2
            let poolVerticalBonusHeight = isPhonePortrait ? 16.0 : 20.0
            let sharedVerticalHeight = max(220, sharedVerticalAvailableHeight * 0.5)
            let verticalPoolHeight = max(220, sharedVerticalHeight + poolVerticalBonusHeight)
            let verticalPickerHeight = max(220, sharedVerticalAvailableHeight - verticalPoolHeight)
            let bottomStackPadding = isPhonePortrait ? (verticalOuterPadding - reclaimedBottomSafeArea) : verticalOuterPadding

            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.95, green: 0.97, blue: 1.0),
                        Color(red: 0.84, green: 0.92, blue: 0.94)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                RoundedRectangle(cornerRadius: metrics.blurCornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.30))
                    .blur(radius: 40)
                    .padding(metrics.blurPadding)

                Group {
                    if usesVerticalLayout {
                        VStack(alignment: .leading, spacing: metrics.panelSpacing) {
                            widgetPoolPanel(metrics: metrics, isPadPortrait: isPadPortrait)
                                .frame(maxWidth: .infinity)
                                .frame(height: verticalPoolHeight)

                            widgetPickerPanel(metrics: metrics, isPadPortrait: isPadPortrait)
                                .frame(maxWidth: .infinity)
                                .frame(height: verticalPickerHeight)
                        }
                    } else {
                        HStack(alignment: .top, spacing: metrics.panelSpacing) {
                            widgetPoolPanel(metrics: metrics, isPadPortrait: isPadPortrait)
                                .frame(width: rightWidth)

                            widgetPickerPanel(metrics: metrics, isPadPortrait: isPadPortrait)
                                .frame(width: leftWidth)
                        }
                    }
                }
                .padding(.top, verticalOuterPadding)
                .padding(.leading, metrics.outerPadding)
                .padding(.trailing, metrics.outerPadding)
                .padding(.bottom, bottomStackPadding)
                .edgesIgnoringSafeArea(.bottom)

                if showGyroPicker {
                    GyroButtonPickerOverlay(
                        options: gyroOptions,
                        onSelect: { option in
                            selectGyroOption(option)
                        },
                        onCancel: {
                            showGyroPicker = false
                        }
                    )
                    .zIndex(999)
                }

                if showCreateWidgetSheet {
                    createWidgetSheet
                        .zIndex(1000)
                }
            }
        }
        .onAppear {
            applyInitialConfigurationIfNeeded()
        }
    }

    private func widgetPickerPanel(metrics: WidgetPickerMetrics, isPadPortrait: Bool = false) -> some View {
        let pickerSectionSpacing = isPadPortrait ? 9.0 : metrics.pickerSectionSpacing
        let pickerTitleFontSize = isPadPortrait ? 20.0 : metrics.poolTitleFontSize
        let pickerPanelPadding = isPadPortrait ? 14.0 : metrics.panelPadding
        let pickerInsetGamepadHorizontal = isPadPortrait ? 10.0 : metrics.pickerInsetGamepadHorizontal
        let pickerInsetGamepadVertical = isPadPortrait ? 50 : metrics.pickerInsetGamepadVertical
        let pickerInsetKeyboard = isPadPortrait ? 6.0 : metrics.pickerInsetKeyboard
        let pickerInsetFunctional = isPadPortrait ? 10.0 : metrics.pickerInsetFunctional
        let modeButtonFontSize = isPadPortrait ? 11.0 : max(metrics.tabFontSize, 10)
        let modeButtonHeight = isPadPortrait ? 28.0 : max(metrics.tabHeight, 22)
        let modeButtonHorizontalPadding = isPadPortrait ? 10.0 : 8.0
        let pickerHeaderMinHeight = isPadPortrait ? 0.0 : 0.0

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: pickerSectionSpacing) {
                HStack(alignment: .center, spacing: 10) {
                    Text(SwiftLocalizationHelper.localizedString(forKey: "Widget Picker"))
                        .font(.system(size: pickerTitleFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(Color.black.opacity(0.82))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Spacer(minLength: 8)
                }
                .frame(minHeight: pickerHeaderMinHeight, alignment: .topLeading)

                widgetPickerTabBar(metrics: metrics, isPadPortrait: isPadPortrait)

                ZStack {
                    pickerSurface(metrics: metrics)

                    switch selectedTab {
                    case .gamepad:
                        AbstractGamepadView(
                            gamepadType: selectedGamepadType,
                            canSelectCommand: { canSelectCommand($0, source: .gamepad) },
                            isCommandSelected: { selectedCmds.contains($0) },
                            onCommandSelected: { appendCommand($0, source: .gamepad) },
                            onCommandDeselected: { removeCommand($0, source: .gamepad) },
                            resetToken: resetToken,
                            selectionSyncToken: selectionSyncToken,
                            externalDeselectionCommand: gamepadDeselectionCommand,
                            externalDeselectionToken: gamepadDeselectionToken
                        )
                        .padding(.horizontal, pickerInsetGamepadHorizontal)
                        .padding(.vertical, pickerInsetGamepadVertical)
                    case .keyboard:
                    VirtualKeyboardView(
                        mode: .picker,
                        canSelectCommand: { canSelectCommand($0, source: .keyboard) },
                        isCommandSelected: { selectedCmds.contains($0) },
                        onCommandSelected: { appendCommand($0, source: .keyboard) },
                        onCommandDeselected: { removeCommand($0, source: .keyboard) },
                        resetToken: resetToken,
                            selectionSyncToken: selectionSyncToken,
                            externalDeselectionCommand: keyboardDeselectionCommand,
                            externalDeselectionToken: keyboardDeselectionToken
                        )
                        .padding(pickerInsetKeyboard)
                    case .functional:
                        FunctionalButtonCollectionView(
                            items: functionalButtonOptions,
                            isSelected: { selectedCmds.contains($0) },
                            onSelect: { handleFunctionalButtonSelection($0) },
                            onDeselect: { handleFunctionalButtonDeselection($0) }
                        )
                            .padding(pickerInsetFunctional)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .mask(
                    Group {
                        if selectedTab == .gamepad {
                            Rectangle()
                        } else {
                            RoundedRectangle(cornerRadius: metrics.pickerSurfaceCornerRadius, style: .continuous)
                        }
                    }
                )
            }

            HStack(spacing: 8) {
                if selectedTab == .gamepad {
                    Button(action: {
                        selectedGamepadType = selectedGamepadType == .xbox ? .ps : .xbox
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: selectedGamepadType == .xbox ? "xmark.circle.fill" : "p.circle.fill")
                                .font(.system(size: max(modeButtonFontSize - 1, 9), weight: .bold))

                            Text(selectedGamepadType == .xbox ? "Xbox" : "PS")
                                .font(.system(size: modeButtonFontSize, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(Color.black.opacity(0.66))
                        .padding(.horizontal, modeButtonHorizontalPadding)
                        .frame(height: modeButtonHeight)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.78))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Button(action: {
                    onCloseRequested?()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: max(modeButtonFontSize, 10), weight: .bold))
                        .foregroundColor(Color.black.opacity(0.66))
                        .frame(width: modeButtonHeight, height: modeButtonHeight)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.78))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.9), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(pickerPanelPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(panelCardFill(metrics: metrics))
        .overlay(panelCardStroke(metrics: metrics))
        .shadow(color: Color.black.opacity(0.08), radius: metrics.panelShadowRadius, x: 0, y: metrics.panelShadowYOffset)
    }

    private func widgetPickerTabBar(metrics: WidgetPickerMetrics, isPadPortrait: Bool = false) -> some View {
        let tabSpacing = isPadPortrait ? 8.0 : metrics.tabSpacing
        let tabFontSize = isPadPortrait ? 12.0 : metrics.tabFontSize
        let tabHorizontalPadding = isPadPortrait ? 10.0 : metrics.tabHorizontalPadding
        let tabHeight = isPadPortrait ? 30.0 : metrics.tabHeight

        return HStack(spacing: tabSpacing) {
            ForEach(availableTabs) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.title)
                        .font(.system(size: tabFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTab == tab ? Color.white : Color.black.opacity(0.56))
                        .padding(.horizontal, tabHorizontalPadding)
                        .frame(height: tabHeight)
                        .background(
                            Capsule()
                                .fill(
                                    selectedTab == tab
                                    ? LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.18, green: 0.61, blue: 0.67),
                                            Color(red: 0.13, green: 0.45, blue: 0.52)
                                        ]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    : LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color.white.opacity(0.75),
                                            Color.white.opacity(0.38)
                                        ]),
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(selectedTab == tab ? 0.18 : 0.55), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }

    private func widgetPoolPanel(metrics: WidgetPickerMetrics, isPadPortrait: Bool) -> some View {
        let poolTitleFontSize = isPadPortrait ? 20.0 : metrics.poolTitleFontSize
        let poolSubtitleFontSize = isPadPortrait ? 11.0 : metrics.subtitleFontSize
        let poolHeaderSpacing = metrics.headerSpacing + (metrics.isPhone ? 0 : (isPadPortrait ? 2 : 19))
        let poolTipHeight = isPadPortrait ? 54.0 : metrics.tipHeight
        let poolTipFontSize = isPadPortrait ? 11.0 : metrics.tipFontSize
        let poolChipHeight = isPadPortrait ? 36.0 : metrics.chipHeight
        let poolChipFontSize = isPadPortrait ? 12.0 : metrics.chipFontSize
        let poolGridWidth: CGFloat? = isPadPortrait ? min(240, UIScreen.main.bounds.width * 0.34) : nil

        return VStack(alignment: .leading, spacing: metrics.poolSectionSpacing) {
            VStack(alignment: .leading, spacing: poolHeaderSpacing) {
                Text(SwiftLocalizationHelper.localizedString(forKey: "Widget Pool"))
                    .font(.system(size: poolTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                

                Text(SwiftLocalizationHelper.localizedString(forKey: "Selected widgets are queued here in tap order."))
                    .font(.system(size: poolSubtitleFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.48))
                    .lineLimit(metrics.isPhone ? 1 : 2)
                    .minimumScaleFactor(0.85)
            }

            poolTipArea(metrics: metrics, customHeight: poolTipHeight, customFontSize: poolTipFontSize)

            WidgetPoolGridView(
                items: poolItems,
                onItemTap: { handlePoolItemTap($0) },
                spacing: metrics.poolGridSpacing,
                contentInset: metrics.poolGridInset
            )
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: poolGridWidth ?? .infinity, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

                PoolActionChip(
                    title: SwiftLocalizationHelper.localizedString(forKey: "Gyro switch button"),
                    isPrimary: false,
                    height: poolChipHeight,
                    fontSize: poolChipFontSize,
                    cornerRadius: metrics.chipCornerRadius
                ) {
                    handleGyroButtonTap()
                }
                .overlay(
                    Group {
                        if selectedGyroCommand != nil {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.orange.opacity(0.75), lineWidth: 1.4)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [
                                                    Color(red: 1.00, green: 0.96, blue: 0.74).opacity(0.34),
                                                    Color(red: 0.95, green: 0.78, blue: 0.32).opacity(0.22)
                                                ]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .allowsHitTesting(false)
                        }
                    }
                )

            HStack(spacing: metrics.isPhone ? 8 : 12) {
                PoolActionChip(
                    title: isEditMode
                        ? WidgetPickerSubmissionAction.create.poolActionTitle
                        : SwiftLocalizationHelper.localizedString(forKey: "Create widget"),
                    isPrimary: true,
                    height: poolChipHeight,
                    fontSize: poolChipFontSize,
                    cornerRadius: metrics.chipCornerRadius
                ) {
                    presentCreateWidgetSheet(for: .create)
                }

                if isEditMode {
                    PoolActionChip(
                        title: WidgetPickerSubmissionAction.modify.poolActionTitle,
                        isPrimary: false,
                        height: poolChipHeight,
                        fontSize: poolChipFontSize,
                        cornerRadius: metrics.chipCornerRadius
                    ) {
                        presentCreateWidgetSheet(for: .modify)
                    }
                }

                PoolActionChip(
                    title: SwiftLocalizationHelper.localizedString(forKey: "Reset"),
                    isPrimary: false,
                    height: poolChipHeight,
                    fontSize: poolChipFontSize,
                    cornerRadius: metrics.chipCornerRadius
                ) {
                    selectedCmds.removeAll()
                    poolItems.removeAll()
                    selectedGyroCommand = nil
                    showGyroPicker = false
                    resetTipMessage()
                    resetToken += 1
                    selectionSyncToken += 1
                }
            }
        }
        .padding(metrics.panelPadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(panelCardFill(metrics: metrics))
        .overlay(panelCardStroke(metrics: metrics))
        .shadow(color: Color.black.opacity(0.08), radius: metrics.panelShadowRadius, x: 0, y: metrics.panelShadowYOffset)
    }

    private func poolTipArea(metrics: WidgetPickerMetrics, customHeight: CGFloat? = nil, customFontSize: CGFloat? = nil) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.white.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .frame(height: customHeight ?? metrics.tipHeight)
            .overlay(
                HStack {
                    Text(tipMessage)
                        .font(.system(size: customFontSize ?? metrics.tipFontSize, weight: .semibold, design: .rounded))
                        .foregroundColor(tipMessageColor)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(.horizontal, metrics.isPhone ? 10 : 14)
            )
    }

    private func pickerSurface(metrics: WidgetPickerMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.pickerSurfaceCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.88),
                        Color(red: 0.90, green: 0.95, blue: 0.96).opacity(0.98)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.pickerSurfaceCornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.80), lineWidth: 1.2)
            )
    }

    private func panelCardFill(metrics: WidgetPickerMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.72),
                        Color.white.opacity(0.54)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func panelCardStroke(metrics: WidgetPickerMetrics) -> some View {
        RoundedRectangle(cornerRadius: metrics.panelCornerRadius, style: .continuous)
            .stroke(Color.white.opacity(0.82), lineWidth: 1.1)
    }

    private func appendCommand(_ cmd: String, source: WidgetPoolSource) {
        let existingCount = poolItems.count
        guard !cmd.isEmpty else { return }
        let item = WidgetPoolItem(
            cmd: cmd,
            source: source,
            visualKind: visualKind(for: cmd, source: source),
            staysAtTail: shouldMarkItemAsTailLocked(cmd: cmd, source: source, existingCount: existingCount),
            displayText: keyboardPoolDisplayText(for: cmd, source: source)
        )

        if shouldInsertCommandAtFront(cmd) {
            selectedCmds.insert(cmd, at: 0)
            poolItems.insert(item, at: 0)
        } else if shouldKeepItemAtPoolTail(item), !poolItems.isEmpty {
            selectedCmds.append(cmd)
            poolItems.append(item)
        } else if let trailingPadIndex = trailingCombinablePadIndex {
            selectedCmds.insert(cmd, at: trailingPadIndex)
            poolItems.insert(item, at: trailingPadIndex)
        } else {
            selectedCmds.append(cmd)
            poolItems.append(item)
        }
        updateTipMessageForCurrentPoolState()
    }

    private func visualKind(for cmd: String, source: WidgetPoolSource) -> WidgetPoolVisualKind {
        switch source {
        case .gamepad:
            return gamepadPadCommands.contains(cmd) ? .gamepadPad : .gamepadButton
        case .functional:
            return .functionalButton
        case .keyboard:
            return keyboardPadCommands.contains(cmd) ? .keyboardPad : .keyboardButton
        }
    }

    private var keyboardPadCommands: Set<String> {
        [
            "WASDPAD",
            "ARROWPAD",
            "WHEEL",
            "MOUSEPAD",
            "TRACKBALL"
        ]
    }

    private var gamepadPadCommands: Set<String> {
        [
            "DPAD",
            "LSWHEEL",
            "LSPAD",
            "RSPAD",
            "RSVPAD",
            "LTPAD",
            "RTPAD",
            "DS4TOUCH"
        ]
    }

    private var directionPadPriorityCommands: Set<String> {
        [
            "WASDPAD",
            "ARROWPAD",
            "DPAD"
        ]
    }

    private var gyroCommands: Set<String> {
        [
            "GYRO",
            "GYROPAUSE"
        ]
    }

    private var priorityFirstCommands: Set<String> {
        directionPadPriorityCommands.union(gyroCommands)
    }

    private func shouldInsertCommandAtFront(_ cmd: String) -> Bool {
        if priorityFirstCommands.contains(cmd) {
            return true
        }

        if cmd == "RS", poolItems.contains(where: { $0.cmd == "RSPAD" || $0.cmd == "RSVPAD" }) {
            return true
        }

        return false
    }

    private func shouldMarkItemAsTailLocked(cmd: String, source: WidgetPoolSource, existingCount: Int) -> Bool {
        let item = WidgetPoolItem(
            cmd: cmd,
            source: source,
            visualKind: visualKind(for: cmd, source: source),
            staysAtTail: false,
            displayText: keyboardPoolDisplayText(for: cmd, source: source)
        )
        return existingCount > 0 && isCombinableNonDirectionPad(item)
    }

    private func keyboardPoolDisplayText(for cmd: String, source: WidgetPoolSource) -> String? {
        guard source == .keyboard else { return nil }
        if VirtualKeyboardView.lastSelectionUsesMacLayout
            || VirtualKeyboardView.lastSelectionFromMouseWidgets
            || VirtualKeyboardView.lastSelectionUsesFnCommandDisplay {
            return cmd
        }
        return VirtualKeyboardView.lastSelectionDisplayText ?? cmd
    }

    private func shouldKeepItemAtPoolTail(_ item: WidgetPoolItem) -> Bool {
        isCombinableNonDirectionPad(item) && !poolItems.isEmpty
    }

    private var trailingCombinablePadIndex: Int? {
        guard let lastItem = poolItems.last, lastItem.staysAtTail, isCombinableNonDirectionPad(lastItem) else {
            return nil
        }
        return poolItems.count - 1
    }

    private func isCombinableNonDirectionPad(_ item: WidgetPoolItem) -> Bool {
        guard isPad(item) else { return false }
        if directionPadPriorityCommands.contains(item.cmd) { return false }
        if item.cmd == "LSWHEEL" { return false }
        return true
    }

    private var wasdSingleCommands: Set<String> {
        [
            "W",
            "A",
            "S",
            "D",
            "WMAC",
            "AMAC",
            "SMAC",
            "DMAC"
        ]
    }

    private var arrowSingleCommands: Set<String> {
        [
            "UPARR",
            "DOWNARR",
            "LEFTARR",
            "RIGHTARR",
            "UPARRMAC",
            "DOWNARRMAC",
            "LEFTARRMAC",
            "RIGHTARRMAC"
        ]
    }

    private var dpadSingleCommands: Set<String> {
        [
            "OSCUP",
            "OSCDOWN",
            "OSCLEFT",
            "OSCRIGHT"
        ]
    }

    private func triggerGroup(for cmd: String) -> String? {
        switch cmd {
        case "LT", "LTPAD":
            return "LT"
        case "RT", "RTPAD":
            return "RT"
        default:
            return nil
        }
    }

    private func directionPadGroup(for cmd: String) -> String? {
        if cmd == "WASDPAD" || wasdSingleCommands.contains(cmd) {
            return "WASD"
        }

        if cmd == "ARROWPAD" || arrowSingleCommands.contains(cmd) {
            return "ARROW"
        }

        if cmd == "DPAD" || dpadSingleCommands.contains(cmd) {
            return "DPAD"
        }

        return nil
    }

    private func isDirectionPadContainerCommand(_ cmd: String) -> Bool {
        directionPadPriorityCommands.contains(cmd)
    }

    private func isDirectionPadSingleCommand(_ cmd: String) -> Bool {
        wasdSingleCommands.contains(cmd) || arrowSingleCommands.contains(cmd) || dpadSingleCommands.contains(cmd)
    }

    private func removeCommand(_ cmd: String, source: WidgetPoolSource) {
        guard !cmd.isEmpty else { return }

        if let cmdIndex = selectedCmds.firstIndex(of: cmd) {
            selectedCmds.remove(at: cmdIndex)
        }

        if let itemIndex = poolItems.firstIndex(where: { $0.cmd == cmd && $0.source == source }) {
            poolItems.remove(at: itemIndex)
        }

        updateTipMessageForCurrentPoolState()
        selectionSyncToken += 1
    }

    private func handlePoolItemTap(_ item: WidgetPoolItem) {
        removeCommand(item.cmd, source: item.source)

        switch item.source {
        case .keyboard:
            keyboardDeselectionCommand = item.cmd
            keyboardDeselectionToken += 1
        case .gamepad:
            gamepadDeselectionCommand = item.cmd
            gamepadDeselectionToken += 1
        case .functional:
            if selectedGyroCommand == item.cmd {
                selectedGyroCommand = nil
            }
        }
    }

    private func isPad(_ item: WidgetPoolItem) -> Bool {
        item.visualKind == .keyboardPad || item.visualKind == .gamepadPad
    }

    private func canSelectCommand(_ cmd: String, source: WidgetPoolSource) -> Bool {
        if selectedCmds.contains(cmd) {
            return false
        }

        let candidate = WidgetPoolItem(
            cmd: cmd,
            source: source,
            visualKind: visualKind(for: cmd, source: source),
            staysAtTail: false,
            displayText: keyboardPoolDisplayText(for: cmd, source: source)
        )

        if occupiedSlots + candidate.span > maxPoolSlots {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Widget pool is full"), type: .error)
            return false
        }

        if isPad(candidate), poolItems.contains(where: isPad) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Cannot select two touchpad controls at the same time"), type: .error)
            return false
        }

        if let candidateDirectionGroup = directionPadGroup(for: cmd),
           poolItems.contains(where: { existing in
               directionPadGroup(for: existing.cmd) == candidateDirectionGroup
               && (
                   (isDirectionPadContainerCommand(cmd) && isDirectionPadSingleCommand(existing.cmd))
                   || (isDirectionPadSingleCommand(cmd) && isDirectionPadContainerCommand(existing.cmd))
               )
           }) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Direction pad cannot be combined with their inner button"), type: .error)
            return false
        }

        if let candidateTriggerGroup = triggerGroup(for: cmd),
           poolItems.contains(where: { existing in
               triggerGroup(for: existing.cmd) == candidateTriggerGroup && existing.cmd != cmd
           }) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Trigger button cannot be combined with trigger pad"), type: .error)
            return false
        }

        if directionPadPriorityCommands.contains(cmd), poolItems.contains(where: { gyroCommands.contains($0.cmd) }) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Direction pad cannot be combined with gyro button"), type: .error)
            return false
        }

        if gyroCommands.contains(cmd), poolItems.contains(where: { directionPadPriorityCommands.contains($0.cmd) }) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Gyro widgets cannot be combined with direction pad"), type: .error)
            return false
        }

        if cmd == "LSWHEEL", !poolItems.isEmpty {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "LS wheel must be placed alone"), type: .error)
            return false
        }

        if !poolItems.isEmpty, poolItems.contains(where: { $0.cmd == "LSWHEEL" }) {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "LsWheel cannot be combined with other widgets"), type: .error)
            return false
        }

        if source == .functional, !gyroCommands.contains(cmd) {
            guard let option = functionalButtonOption(for: cmd) else {
                resetTipMessage()
                return false
            }

            if poolItems.contains(where: isPad) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Functional button widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }

            if poolItems.contains(where: { $0.source == .functional }) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Functional button widgets cannot be combined with other functional buttons"), type: .error)
                return false
            }

            if !option.allowsKeyboardCombination,
               poolItems.contains(where: { $0.source == .keyboard && !isPad($0) }) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "This functional button cannot be combined with keyboard or mouse buttons"), type: .error)
                return false
            }

            if !option.allowsGamepadCombination,
               poolItems.contains(where: { $0.source == .gamepad && !isPad($0) }) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "This functional button cannot be combined with gamepad buttons"), type: .error)
                return false
            }
        }

        if source == .keyboard || source == .gamepad {
            if poolItems.contains(where: isPad) && poolItems.contains(where: { $0.source == .functional && !gyroCommands.contains($0.cmd) }) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Functional button widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }

            if let existingFunctionalItem = poolItems.first(where: { $0.source == .functional && !gyroCommands.contains($0.cmd) }),
               let option = functionalButtonOption(for: existingFunctionalItem.cmd) {
                if source == .keyboard && !option.allowsKeyboardCombination {
                    setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "This functional button cannot be combined with keyboard or mouse buttons"), type: .error)
                    return false
                }

                if source == .gamepad && !option.allowsGamepadCombination {
                    setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "This functional button cannot be combined with gamepad buttons"), type: .error)
                    return false
                }
            }

            if isPad(candidate),
               poolItems.contains(where: { $0.source == .functional && !gyroCommands.contains($0.cmd) }) {
                setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Functional button widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }
        }

        resetTipMessage()
        return true
    }

    private func functionalButtonOption(for cmd: String) -> FunctionalButtonOption? {
        functionalButtonOptions.first(where: { $0.cmd == cmd })
    }

    private var occupiedSlots: Int {
        poolItems.reduce(0) { $0 + $1.span }
    }

    private var gyroOptions: [GyroButtonOption] {
        [
            GyroButtonOption(
                cmd: "GYRO",
                description: SwiftLocalizationHelper.localizedString(forKey: "Gyro on while activated")
            ),
            GyroButtonOption(
                cmd: "GYROPAUSE",
                description: SwiftLocalizationHelper.localizedString(forKey: "Gyro off while activated")
            )
        ]
    }

    private func handleGyroButtonTap() {
        if let selectedGyroCommand {
            removeCommand(selectedGyroCommand, source: .functional)
            self.selectedGyroCommand = nil
        } else {
            showGyroPicker = true
        }
    }

    private func selectGyroOption(_ option: GyroButtonOption) {
        guard canSelectCommand(option.cmd, source: .functional) else {
            showGyroPicker = false
            return
        }

        appendCommand(option.cmd, source: .functional)
        selectedGyroCommand = option.cmd
        showGyroPicker = false
    }

    private func handleFunctionalButtonSelection(_ option: FunctionalButtonOption) {
        guard canSelectCommand(option.cmd, source: .functional) else { return }
        appendCommand(option.cmd, source: .functional)
    }

    private func handleFunctionalButtonDeselection(_ option: FunctionalButtonOption) {
        removeCommand(option.cmd, source: .functional)
    }

    private var createWidgetSheet: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let contentSpacing: CGFloat = isPhone ? 10 : 16
        let sectionSpacing: CGFloat = isPhone ? 7 : 10
        let fieldHeight: CGFloat = isPhone ? 30 : 38
        let actionSpacing: CGFloat = isPhone ? 8 : 12
        let actionHeight: CGFloat = isPhone ? 34 : 44
        let actionFontSize: CGFloat = isPhone ? 13 : 15
        let cardPadding: CGFloat = isPhone ? 12 : 18
        let cardMaxWidth: CGFloat = isPhone ? 320 : 420
        let cardCornerRadius: CGFloat = isPhone ? 22 : 28
        let horizontalInset: CGFloat = isPhone ? 14 : 24
        return ZStack {
            Color.black.opacity(0.28)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    setCreateWidgetSheetVisible(false)
                }

            VStack(alignment: .leading, spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    if targetWidgetKind == .button {
                        if showsButtonLabelField {
                            createWidgetSection(title: SwiftLocalizationHelper.localizedString(forKey: "Button label")) {
                                TextField(
                                    SwiftLocalizationHelper.localizedString(forKey: "Enter label(optional)"),
                                    text: $widgetButtonLabel
                                )
                                .padding(.horizontal, 12)
                                .frame(height: fieldHeight)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.78))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.88), lineWidth: 1)
                                )
                            }
                        }

                        if showsComboModeControl {
                            createWidgetSection(title: SwiftLocalizationHelper.localizedString(forKey: "Combination mode")) {
                                Picker("", selection: widgetComboModeBinding) {
                                    ForEach(WidgetCreateComboMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .disabled(isComboModeLocked)
                                .opacity(isComboModeLocked ? 0.45 : 1.0)
                            }
                        }
                    }

                    if showsIntervalSlider {
                        createWidgetSection(title: "\(SwiftLocalizationHelper.localizedString(forKey: "Trigger interval")): \(effectiveTriggerIntervalValue) ms") {
                            Slider(
                                value: $widgetTriggerInterval,
                                in: 0...2000,
                                step: 1
                            )
                            .disabled(isShortcutMode)
                            .opacity(isShortcutMode ? 0.45 : 1.0)
                        }
                    }

                    if targetWidgetKind == .button, showsShapeControl {
                        createWidgetSection(title: SwiftLocalizationHelper.localizedString(forKey: "Shape")) {
                            Picker("", selection: $widgetShape) {
                                ForEach(WidgetCreateShape.allCases) { shape in
                                    Text(shape.title).tag(shape)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                    }
                }

                HStack(spacing: actionSpacing) {
                    PoolActionChip(
                        title: SwiftLocalizationHelper.localizedString(forKey: "Cancel"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        setCreateWidgetSheetVisible(false)
                    }

                    PoolActionChip(
                        title: pendingSubmissionAction.confirmationTitle,
                        isPrimary: true,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        submitWidgetPayload()
                    }
                }
                .padding(.top, isPhone ? 2 : 0)
            }
            .padding(cardPadding)
            .frame(maxWidth: cardMaxWidth)
            .background(
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.97, blue: 0.98).opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.96), lineWidth: 1.1)
                    )
            )
            .shadow(color: Color.black.opacity(0.12), radius: 24, x: 0, y: 12)
            .padding(.horizontal, horizontalInset)
        }
    }

    private func createWidgetSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let titleFontSize: CGFloat = isPhone ? 11.5 : 13
        let sectionSpacing: CGFloat = isPhone ? 5 : 7
        let sectionHorizontalPadding: CGFloat = isPhone ? 9 : 12
        let sectionVerticalPadding: CGFloat = isPhone ? 6 : 10
        let sectionCornerRadius: CGFloat = isPhone ? 12 : 14

        return VStack(alignment: .leading, spacing: sectionSpacing) {
            Text(title)
                .font(.system(size: titleFontSize, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.64))

            content()
                .padding(.horizontal, sectionHorizontalPadding)
                .padding(.vertical, sectionVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.9))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.94), lineWidth: 1)
                )
        }
    }

    private var firstPoolItem: WidgetPoolItem? {
        poolItems.first
    }

    private var targetWidgetKind: WidgetCreateTargetKind {
        guard let firstPoolItem else { return .button }
        switch firstPoolItem.visualKind {
        case .gamepadPad, .keyboardPad:
            return .pad
        case .gamepadButton, .keyboardButton, .functionalButton:
            return .button
        }
    }

    private var firstPoolItemIsFromGamepad: Bool {
        firstPoolItem?.source == .gamepad
    }

    private var isFunctionalOnlySelection: Bool {
        firstPoolItem?.source == .functional
    }

    private var buttonCommandCount: Int {
        poolItems.filter { item in
            switch item.visualKind {
            case .gamepadButton, .keyboardButton, .functionalButton:
                return true
            case .gamepadPad, .keyboardPad:
                return false
            }
        }.count
    }

    private var hasPadCommand: Bool {
        poolItems.contains(where: isPad)
    }

    private var isShortcutMode: Bool {
        effectiveWidgetComboMode == .shortcut
    }

    private var selectedFunctionalButtonOption: FunctionalButtonOption? {
        guard let functionalItem = poolItems.first(where: { $0.source == .functional && !gyroCommands.contains($0.cmd) }) else {
            return nil
        }
        return functionalButtonOption(for: functionalItem.cmd)
    }

    private var forcedComboMode: WidgetCreateComboMode? {
        guard showsComboModeControl else { return nil }
        if targetWidgetKind == .button && hasPadCommand {
            return .skill
        }
        return selectedFunctionalButtonOption?.forcedComboMode
    }

    private var effectiveWidgetComboMode: WidgetCreateComboMode {
        forcedComboMode ?? widgetComboMode
    }

    private var isComboModeLocked: Bool {
        forcedComboMode != nil
    }

    private var widgetComboModeBinding: Binding<WidgetCreateComboMode> {
        Binding(
            get: { effectiveWidgetComboMode },
            set: { widgetComboMode = $0 }
        )
    }

    private var showsComboModeControl: Bool {
        guard targetWidgetKind == .button else { return false }
        if let selectedFunctionalButtonOption {
            return selectedFunctionalButtonOption.allowsSkillCombo || selectedFunctionalButtonOption.allowsShortcutCombo
        }
        return !isFunctionalOnlySelection
    }

    private var showsShapeControl: Bool {
        targetWidgetKind == .button
    }

    private var showsButtonLabelField: Bool {
        targetWidgetKind == .button
    }

    private var showsIntervalSlider: Bool {
        guard buttonCommandCount >= 2 else { return false }
        if let selectedFunctionalButtonOption {
            return selectedFunctionalButtonOption.allowsSkillCombo
        }
        return !isFunctionalOnlySelection
    }

    private var effectiveTriggerIntervalValue: Int {
        if effectiveWidgetComboMode == .shortcut && showsComboModeControl {
            return 200
        }
        return Int(widgetTriggerInterval.rounded())
    }

    private var widgetPayloadPreviewText: String {
        let payload = makeWidgetPayload()
        return "{\n  \"cmdString\": \"\(payload["cmdString"] ?? "")\",\n  \"buttonLabel\": \"\(payload["buttonLabel"] ?? "")\",\n  \"shape\": \"\(payload["shape"] ?? "")\"\n}"
    }

    private var shouldBypassCreateWidgetSheet: Bool {
        poolItems.count == 1 || (targetWidgetKind == .pad && buttonCommandCount == 1)
    }

    private func prepareCreateWidgetDefaults(for submissionAction: WidgetPickerSubmissionAction) {
        if let selectedFunctionalButtonOption {
            if selectedFunctionalButtonOption.allowsSkillCombo {
                widgetComboMode = .skill
            } else if selectedFunctionalButtonOption.allowsShortcutCombo {
                widgetComboMode = .shortcut
            } else {
                widgetComboMode = .skill
            }
        } else {
            widgetComboMode = .skill
        }
        if let forcedComboMode {
            widgetComboMode = forcedComboMode
        }
        if isEditMode {
            widgetComboMode = initialComboMode(from: initialCmdString)
            widgetTriggerInterval = Double(initialTriggerInterval(from: initialCmdString))
        } else {
            widgetTriggerInterval = 0
        }
        if isEditMode,
           submissionAction == .modify,
           let initialButtonLabel,
           targetWidgetKind == .button {
            widgetButtonLabel = initialButtonLabel
        } else {
            widgetButtonLabel = ""
        }

        if isEditMode,
           targetWidgetKind == .button,
           let initialShape = normalizedShape(from: initialShape),
           initialShape != .largeSquare {
            widgetShape = initialShape == .round ? .round : .square
        } else {
            widgetShape = firstPoolItemIsFromGamepad ? .round : .square
        }

        pendingSubmissionAction = submissionAction
    }

    private func presentCreateWidgetSheet(for submissionAction: WidgetPickerSubmissionAction) {
        guard !poolItems.isEmpty else {
            setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Select at least one command before creating a widget"), type: .error)
            return
        }

        prepareCreateWidgetDefaults(for: submissionAction)

        if shouldBypassCreateWidgetSheet {
            submitWidgetPayload()
            return
        }

        setCreateWidgetSheetVisible(true)
    }

    private func submitWidgetPayload() {
        let payload = makeWidgetPayload()
        lastCreatedWidgetPayload = payload
        setTipMessage(SwiftLocalizationHelper.localizedString(forKey: "Widget config generated"))
        onWidgetCreated?(payload)
        print("widgetPicker payload =", payload as NSDictionary)
        setCreateWidgetSheetVisible(false)
    }

    private func makeWidgetPayload() -> [String: String] {
        [
            "cmdString": buildCmdString(),
            "buttonLabel": targetWidgetKind == .button ? widgetButtonLabel : "",
            "shape": targetWidgetKind == .button ? widgetShape.rawValue : "",
            "pickerAction": pendingSubmissionAction.payloadValue
        ]
    }

    private func buildCmdString() -> String {
        let joiner = effectiveWidgetComboMode == .shortcut && showsComboModeControl ? "+" : "-"
        var cmdString = selectedCmds.joined(separator: joiner)

        let shouldAppendInterval = effectiveWidgetComboMode != .shortcut
            && effectiveTriggerIntervalValue != 0
            && (hasPadCommand || effectiveWidgetComboMode == .skill)
        if shouldAppendInterval {
            cmdString += "-\(effectiveTriggerIntervalValue)MS"
        }

        return cmdString
    }

    private func setCreateWidgetSheetVisible(_ isVisible: Bool) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            showCreateWidgetSheet = isVisible
        }
    }

    private func applyInitialConfigurationIfNeeded() {
        guard !didApplyInitialConfiguration else { return }
        didApplyInitialConfiguration = true
        guard let initialCmdString, !initialCmdString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let parsedCommands = parseCommands(from: initialCmdString)
        guard !parsedCommands.isEmpty else { return }

        selectedCmds = parsedCommands.map(\.cmd)
        poolItems = parsedCommands.map { descriptor in
            WidgetPoolItem(
                cmd: descriptor.cmd,
                source: descriptor.source,
                visualKind: visualKind(for: descriptor.cmd, source: descriptor.source),
                staysAtTail: descriptor.isTailLocked,
                displayText: descriptor.displayText
            )
        }
        selectedGyroCommand = parsedCommands.first(where: { gyroCommands.contains($0.cmd) })?.cmd

        if let preferredTab = parsedCommands.first(where: { $0.source != .functional || !gyroCommands.contains($0.cmd) })?.source {
            switch preferredTab {
            case .gamepad:
                selectedTab = .gamepad
            case .keyboard:
                selectedTab = .keyboard
            case .functional:
                selectedTab = .functional
            }
        } else if parsedCommands.contains(where: { $0.source == .functional }) {
            selectedTab = .functional
        }

        updateTipMessageForCurrentPoolState()
    }

    private func parseCommands(from cmdString: String) -> [(cmd: String, source: WidgetPoolSource, isTailLocked: Bool, displayText: String?)] {
        let normalized = cmdString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else { return [] }

        var commands: [String]
        if normalized.contains("+") {
            commands = normalized
                .split(separator: "+")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        } else {
            commands = normalized
                .split(separator: "-")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        if let last = commands.last,
           last.range(of: #"^\d+MS$"#, options: .regularExpression) != nil {
            commands.removeLast()
        }

        var parsed: [(cmd: String, source: WidgetPoolSource, isTailLocked: Bool, displayText: String?)] = []
        for rawCommand in commands where !rawCommand.isEmpty {
            let canonicalCommand = canonicalCommand(for: rawCommand)
            guard let source = source(for: canonicalCommand) else { continue }
            let displayText: String?
            if source == .keyboard {
                displayText = canonicalCommand
            } else {
                displayText = nil
            }

            let item = WidgetPoolItem(
                cmd: canonicalCommand,
                source: source,
                visualKind: visualKind(for: canonicalCommand, source: source),
                staysAtTail: false,
                displayText: displayText
            )
            let isTailLocked = parsed.isEmpty ? false : isCombinableNonDirectionPad(item)
            parsed.append((cmd: canonicalCommand, source: source, isTailLocked: isTailLocked, displayText: displayText))
        }

        return parsed
    }

    private func source(for cmd: String) -> WidgetPoolSource? {
        if gamepadCommands.contains(cmd) {
            return .gamepad
        }
        if keyboardCommands.contains(cmd) {
            return .keyboard
        }
        if functionalCommands.contains(cmd) {
            return .functional
        }
        return nil
    }

    private func canonicalCommand(for cmd: String) -> String {
        switch cmd {
        case "PICKPROFILE":
            return "PICKPRFL"
        case "WIDGETPROFILES":
            return "PROFILES"
        default:
            return cmd
        }
    }

    private var gamepadCommands: Set<String> {
        [
            "OSCA", "OSCB", "OSCX", "OSCY",
            "OSCSELECT", "OSCSTART", "OSCHOME",
            "HOME",
            "DPAD",
            "OSCUP", "OSCDOWN", "OSCLEFT", "OSCRIGHT",
            "LS", "LSWHEEL", "LSPAD",
            "RS", "RSPAD", "RSVPAD",
            "LB", "RB",
            "LT", "LTPAD",
            "RT", "RTPAD",
            "DS4TOUCH", "DS4TCHBTN"
        ]
    }

    private var keyboardCommands: Set<String> {
        Set(CommandManager.keyboardButtonMappings.keys)
            .union(Set(CommandManager.mouseButtonMappings.keys))
            .union(keyboardPadCommands)
    }

    private var functionalCommands: Set<String> {
        Set(functionalButtonOptions.map(\.cmd)).union(gyroCommands)
    }

    private enum InitialWidgetShape {
        case round
        case square
        case largeSquare
    }

    private func normalizedShape(from value: String?) -> InitialWidgetShape? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !value.isEmpty else {
            return nil
        }

        switch value {
        case "r", "round":
            return .round
        case "s", "square":
            return .square
        case "largesquare":
            return .largeSquare
        default:
            return nil
        }
    }

    private func initialComboMode(from cmdString: String?) -> WidgetCreateComboMode {
        let normalized = cmdString?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""

        if normalized.contains("+") {
            return .shortcut
        }
        return .skill
    }

    private func initialTriggerInterval(from cmdString: String?) -> Int {
        let normalized = cmdString?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""

        guard let match = normalized.range(of: #"(\d+)MS$"#, options: .regularExpression) else {
            return 0
        }

        let suffix = String(normalized[match])
        return Int(suffix.replacingOccurrences(of: "MS", with: "")) ?? 0
    }
}

@available(iOS 13.0, *)
struct FunctionalButtonCollectionView: View {
    let items: [FunctionalButtonOption]
    let isSelected: (String) -> Bool
    let onSelect: (FunctionalButtonOption) -> Void
    let onDeselect: (FunctionalButtonOption) -> Void

    private let desiredColumns: CGFloat = 7
    private let horizontalSpacing: CGFloat = 8
    private let verticalSpacing: CGFloat = 8

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            FunctionalButtonFlowLayout(
                items: items,
                desiredColumns: desiredColumns,
                horizontalSpacing: horizontalSpacing,
                verticalSpacing: verticalSpacing,
                isSelected: isSelected,
                onSelect: onSelect,
                onDeselect: onDeselect
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@available(iOS 13.0, *)
struct FunctionalButtonFlowLayout: View {
    let items: [FunctionalButtonOption]
    let desiredColumns: CGFloat
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let isSelected: (String) -> Bool
    let onSelect: (FunctionalButtonOption) -> Void
    let onDeselect: (FunctionalButtonOption) -> Void

    @SwiftUI.State private var contentHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { proxy in
            generateContent(in: proxy)
        }
        .frame(height: contentHeight)
    }

    private func generateContent(in proxy: GeometryProxy) -> some View {
        let buttonSize = max(
            44,
            floor((max(proxy.size.width, 1) - horizontalSpacing * (desiredColumns - 1)) / desiredColumns)
        )
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                FunctionalCollectionButton(
                    item: item,
                    isSelected: isSelected(item.cmd),
                    width: buttonSize
                ) {
                    if isSelected(item.cmd) {
                        onDeselect(item)
                    } else {
                        onSelect(item)
                    }
                }
                .alignmentGuide(.leading) { dimensions in
                    if currentX + dimensions.width > proxy.size.width, currentX > 0 {
                        currentX = 0
                        currentY += dimensions.height + verticalSpacing
                    }

                    let result = currentX
                    currentX += dimensions.width + horizontalSpacing
                    return -result
                }
                .alignmentGuide(.top) { _ in
                    let result = currentY
                    if item.id == items.last?.id {
                        currentX = 0
                        currentY = 0
                    }
                    return -result
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear.preference(key: FunctionalFlowHeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(FunctionalFlowHeightPreferenceKey.self) { contentHeight = $0 }
    }
}

@available(iOS 13.0, *)
struct FunctionalCollectionButton: View {
    let item: FunctionalButtonOption
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void

    private var labelFontSize: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 8 : 12
    }

    var body: some View {
        Button(action: action) {
            Text(item.label)
                .font(.system(size: labelFontSize, weight: .bold, design: .rounded))
                .foregroundColor(Color.black.opacity(0.70))
                .minimumScaleFactor(0.7)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 4)
                .frame(width: width, height: width)
                .background(backgroundFill)
                .overlay(borderOverlay)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var backgroundFill: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: isSelected
                        ? [
                            Color(red: 1.00, green: 0.96, blue: 0.74),
                            Color(red: 0.95, green: 0.78, blue: 0.32)
                        ]
                        : [
                            Color.white.opacity(0.82),
                            Color.white.opacity(0.58)
                        ]
                    ),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                isSelected ? Color.orange.opacity(0.75) : Color.white.opacity(0.76),
                lineWidth: 1.4
            )
    }
}

private struct FunctionalFlowHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = .zero

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

@available(iOS 13.0, *)
struct PoolActionChip: View {
    let title: String
    let isPrimary: Bool
    let height: CGFloat
    let fontSize: CGFloat
    let cornerRadius: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(isPrimary ? .white : Color.black.opacity(0.66))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            isPrimary
                            ? LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.18, green: 0.61, blue: 0.67),
                                    Color(red: 0.14, green: 0.46, blue: 0.52)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.82),
                                    Color.white.opacity(0.58)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isPrimary ? 0.22 : 0.76), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

@available(iOS 13.0, *)
struct GyroButtonPickerOverlay: View {
    let options: [GyroButtonOption]
    let onSelect: (GyroButtonOption) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 14) {
                Text(SwiftLocalizationHelper.localizedString(forKey: "Select Gyro Button"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(SwiftLocalizationHelper.localizedString(forKey: "Choose a gyro control style"))
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.78))
                    .multilineTextAlignment(.center)

                VStack(spacing: 10) {
                    ForEach(options) { option in
                        Button(action: {
                            onSelect(option)
                        }) {
                            HStack(spacing: 12) {
                                Text(option.description)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Text(option.cmd)
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.72))
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Button(action: {
                    onCancel()
                }) {
                    Text(SwiftLocalizationHelper.localizedString(forKey: "Cancel"))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .frame(height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.black.opacity(0.16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(18)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.15, green: 0.46, blue: 0.50),
                                Color(red: 0.11, green: 0.34, blue: 0.39)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.2)
                    )
            )
            .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 24)
        }
    }
}

@available(iOS 13.0, *)
struct WidgetPoolGridView: View {
    let items: [WidgetPoolItem]
    let onItemTap: (WidgetPoolItem) -> Void
    let spacing: CGFloat
    let contentInset: CGFloat

    private let columns = 4

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let availableSide = max(min(width, height) - contentInset * 2, 1)
            let cellSize = (availableSide - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let gridSide = cellSize * CGFloat(columns) + spacing * CGFloat(columns - 1)
            let gridOriginX = (width - gridSide) * 0.5
            let gridOriginY = (height - gridSide) * 0.5
            let placements = makePlacements(for: items, columns: columns)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.83, green: 0.90, blue: 0.93),
                                Color(red: 0.72, green: 0.82, blue: 0.86)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.75), lineWidth: 1.2)
                    )

                ForEach(0..<columns, id: \.self) { column in
                    ForEach(0..<columns, id: \.self) { row in
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white.opacity(0.16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                            )
                            .frame(width: cellSize, height: cellSize)
                            .position(
                                x: gridOriginX + CGFloat(column) * (cellSize + spacing) + cellSize * 0.5,
                                y: gridOriginY + CGFloat(row) * (cellSize + spacing) + cellSize * 0.5
                            )
                    }
                }

                ForEach(placements) { placement in
                    poolItemView(for: placement.item, cellSize: cellSize)
                        .frame(
                            width: cellSize * CGFloat(placement.item.span) + spacing * CGFloat(placement.item.span - 1),
                            height: cellSize
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onItemTap(placement.item)
                        }
                        .position(
                            x: gridOriginX + CGFloat(placement.column) * (cellSize + spacing)
                                + (cellSize * CGFloat(placement.item.span) + spacing * CGFloat(placement.item.span - 1)) * 0.5,
                            y: gridOriginY + CGFloat(placement.row) * (cellSize + spacing) + cellSize * 0.5
                        )
                }
            }
        }
    }

    private func poolItemView(for item: WidgetPoolItem, cellSize: CGFloat) -> some View {
        Group {
            if item.visualKind == .gamepadButton {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.96, blue: 0.74),
                                Color(red: 0.95, green: 0.78, blue: 0.32)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.orange.opacity(0.75), lineWidth: 1.4)
                    )
                    .overlay(
                        Text(item.displayCmd)
                            .font(.system(size: max(11, cellSize * 0.18), weight: .bold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.70))
                            .minimumScaleFactor(0.6)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            } else if item.visualKind == .keyboardButton {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.96, blue: 0.74),
                                Color(red: 0.95, green: 0.78, blue: 0.32)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.75), lineWidth: 1.4)
                    )
                    .overlay(
                        Text(item.displayCmd)
                            .font(.system(size: max(11, cellSize * 0.18), weight: .bold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.70))
                            .minimumScaleFactor(0.6)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            } else if item.visualKind == .functionalButton {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 1.00, green: 0.96, blue: 0.74),
                                Color(red: 0.95, green: 0.78, blue: 0.32)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.orange.opacity(0.75), lineWidth: 1.4)
                    )
                    .overlay(
                        Text(item.displayCmd)
                            .font(.system(size: max(11, cellSize * 0.17), weight: .semibold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.72))
                            .minimumScaleFactor(0.7)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            } else {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                PoolPadHighlightStyle.fillTop,
                                PoolPadHighlightStyle.fillBottom
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(PoolPadHighlightStyle.stroke, lineWidth: 1.2)
                    )
                    .overlay(
                        Text(item.displayCmd)
                            .font(.system(size: max(11, cellSize * 0.17), weight: .semibold, design: .rounded))
                            .foregroundColor(Color.black.opacity(0.72))
                            .minimumScaleFactor(0.7)
                            .lineLimit(2)
                            .padding(.horizontal, 8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            }
        }
    }

    private func makePlacements(for items: [WidgetPoolItem], columns: Int) -> [WidgetPoolPlacement] {
        var placements: [WidgetPoolPlacement] = []
        var row = 0
        var column = 0

        for item in items {
            let span = min(item.span, columns)

            if column + span > columns {
                row += 1
                column = 0
            }

            placements.append(
                WidgetPoolPlacement(
                    id: item.id,
                    item: item,
                    row: row,
                    column: column
                )
            )

            column += span
            if column >= columns {
                row += 1
                column = 0
            }
        }

        return placements
    }
}

@available(iOS 13.0, *)
struct WidgetPickerView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetPickerView()
            .previewLayout(.fixed(width: 1400, height: 860))
    }
}
