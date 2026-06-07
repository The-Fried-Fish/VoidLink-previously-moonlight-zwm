//
//  WidgetPickerView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/4/1.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import UIKit
import Combine

@available(iOS 13.0, *)
private extension View {
    @ViewBuilder
    func widgetPickerIgnoreKeyboardSafeAreaWhenAvailable() -> some View {
        if #available(iOS 14.0, *) {
            ignoresSafeArea(.keyboard, edges: .bottom)
        } else {
            self
        }
    }
}

@available(iOS 13.0, *)
final class WidgetPickerPresentationState: ObservableObject {
    @Published var hasHostAppeared = false
}

@available(iOS 13.0, *)
enum WidgetPickerTab: String, CaseIterable, Identifiable, Equatable {
    case gamepad = "Gamepad"
    case keyboard = "Keyboard & Mouse"
    case functional = "Functional"
    case shortcuts = "Shortcuts"

    var id: String { rawValue }

    var persistenceIdentifier: String {
        switch self {
        case .gamepad:
            return "gamepad"
        case .keyboard:
            return "keyboard"
        case .functional:
            return "functional"
        case .shortcuts:
            return "shortcuts"
        }
    }

    var title: String {
        switch self {
        case .gamepad:
            return LocalizationHelper.localizedString(forKey: "Gamepad")
        case .keyboard:
            return LocalizationHelper.localizedString(forKey: "Keyboard / Mouse")
        case .functional:
            return LocalizationHelper.localizedString(forKey: "Functional Widgets")
        case .shortcuts:
            return LocalizationHelper.localizedString(forKey: "ShortcutsTab")
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
        case "shortcuts", "shortcut", "shortcutlibrary", "shortcut_library", "shortcut-library":
            self = .shortcuts
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
    case shortcuts
    case interval
}

@available(iOS 13.0, *)
enum WidgetPoolVisualKind: Equatable {
    case gamepadButton
    case gamepadPad
    case keyboardButton
    case keyboardPad
    case functionalButton
    case shortcutButton
    case triggerInterval
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
        if let displayText, !displayText.isEmpty {
            return displayText
        }
        switch source {
        case .gamepad:
            let baseCommand = WidgetPickerView.selectionIdentifier(for: cmd)
            if baseCommand.hasPrefix("OSC") {
                return String(baseCommand.dropFirst(3))
            }
            return baseCommand
        case .keyboard:
            return displayText ?? cmd
        case .functional:
            return cmd
        case .shortcuts:
            return cmd
        case .interval:
            return WidgetPickerView.intervalDisplayText(for: cmd)
        }
    }

    var span: Int {
        switch visualKind {
        case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton, .triggerInterval:
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
            return LocalizationHelper.localizedString(forKey: "Create New")
        case .modify:
            return LocalizationHelper.localizedString(forKey: "Modify")
        }
    }

    var poolActionTitle: String {
        switch self {
        case .create:
            return LocalizationHelper.localizedString(forKey: "Create New")
        case .modify:
            return LocalizationHelper.localizedString(forKey: "Modify")
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
            return LocalizationHelper.localizedString(forKey: "Skill combo")
        case .shortcut:
            return LocalizationHelper.localizedString(forKey: "Shortcut combo")
        }
    }
}

@available(iOS 13.0, *)
private enum WidgetButtonMacroMode: Int, CaseIterable, Identifiable {
    case holdUntilRelease = 0
    case timedRelease = 1
    case tap = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .holdUntilRelease:
            return LocalizationHelper.localizedString(forKey: "Hold until release")
        case .timedRelease:
            return LocalizationHelper.localizedString(forKey: "Timed release")
        case .tap:
            return LocalizationHelper.localizedString(forKey: "Tap")
        }
    }
}

@available(iOS 13.0, *)
private enum TriggerIntervalEditMode: Int, CaseIterable, Identifiable {
    case all = 0
    case individual = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all:
            return LocalizationHelper.localizedString(forKey: "Set all")
        case .individual:
            return LocalizationHelper.localizedString(forKey: "Set this")
        }
    }
}

@available(iOS 13.0, *)
private enum ShortcutPickerButtonMode: String, CaseIterable, Identifiable {
    case normal
    case tapToToggle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .normal:
            return LocalizationHelper.localizedString(forKey: "Normal")
        case .tapToToggle:
            return LocalizationHelper.localizedString(forKey: "Tap to toggle")
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
            return LocalizationHelper.localizedString(forKey: "Circle")
        case .square:
            return LocalizationHelper.localizedString(forKey: "Square")
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
    let localizationKey: String
    let cmd: String
    let tip: String
    let allowsKeyboardCombination: Bool
    let allowsGamepadCombination: Bool
    let allowsSkillCombo: Bool
    let allowsShortcutCombo: Bool
    let forcedComboMode: WidgetCreateComboMode?
}

@available(iOS 13.0, *)
private final class WidgetLabelTextField: UITextField {
    private let horizontalInset: CGFloat = 12

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalInset, dy: 0)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalInset, dy: 0)
    }

    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.insetBy(dx: horizontalInset, dy: 0)
    }
}

@available(iOS 13.0, *)
private struct InteractiveTextField: UIViewRepresentable {
    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InteractiveTextField

        init(parent: InteractiveTextField) {
            self.parent = parent
        }

        func textFieldDidChangeSelection(_ textField: UITextField) {
            parent.text = textField.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }

    let placeholder: String
    @Binding var text: String
    var isEnabled: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextField {
        let textField = WidgetLabelTextField(frame: .zero)
        textField.borderStyle = .none
        textField.delegate = context.coordinator
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.78)
        textField.textColor = UIColor.black.withAlphaComponent(0.82)
        textField.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: UIColor.systemGray3]
        )
        textField.returnKeyType = .done
        textField.clearButtonMode = .whileEditing
        textField.layer.cornerRadius = 12
        textField.layer.masksToBounds = true
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.white.withAlphaComponent(0.88).cgColor
        return textField
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        if uiView.placeholder != placeholder {
            uiView.placeholder = placeholder
        }
        if uiView.isEnabled != isEnabled {
            DispatchQueue.main.async {
                uiView.isEnabled = isEnabled
            }
        }
        uiView.alpha = isEnabled ? 1.0 : 0.45
    }
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
    private static let lastSelectedTabDefaultsKey = "WidgetPickerView.lastSelectedTabIdentifier"

    private enum PoolTipMessageType {
        case normal
        case error
    }

    private let maxPoolSlots = 64
    private let buttonMacroMinimumDuration: Double = 30
    private let buttonMacroTimedMinimumDuration: Double = 50
    private let buttonMacroMaximumDuration: Double = 2000
    private let triggerIntervalMinimumDuration: Double = 0
    private let triggerIntervalMaximumDuration: Double = 3000
    private let isEditMode: Bool
    private let initialCmdString: String?
    private let initialButtonLabel: String?
    private let initialShape: String?
    private let availableTabs: [WidgetPickerTab]
    private let preferredInitialTab: WidgetPickerTab?
    private let keyboardPickerMode: VirtualKeyboardMode
    var shortcutPickerNeedAlias: Bool = false
    var shortcutPickerNeedButtonMode: Bool = false
    private let shortcutPickerTipText: String?
    private let shortcutIdentifier: String?
    @ObservedObject private var presentationState: WidgetPickerPresentationState
    var onWidgetCreated: (([String: String]) -> Void)? = nil
    var onCloseRequested: (() -> Void)? = nil

    @SwiftUI.State private var selectedTab: WidgetPickerTab
    @SwiftUI.State private var selectedGamepadType: GamepadType = .xbox
    @SwiftUI.State private var selectedCmds: [String] = []
    @SwiftUI.State private var poolItems: [WidgetPoolItem] = []
    @SwiftUI.State private var resetToken: Int = 0
    @SwiftUI.State private var tipMessage: String
    @SwiftUI.State private var tipMessageType: PoolTipMessageType = .normal
    @SwiftUI.State private var keyboardDeselectionCommand: String = ""
    @SwiftUI.State private var keyboardDeselectionToken: Int = 0
    @SwiftUI.State private var gamepadDeselectionCommand: String = ""
    @SwiftUI.State private var gamepadDeselectionToken: Int = 0
    @SwiftUI.State private var showGyroPicker = false
    @SwiftUI.State private var selectedGyroCommand: String? = nil
    @SwiftUI.State private var showCreateWidgetSheet = false
    @SwiftUI.State private var widgetComboMode: WidgetCreateComboMode = .skill
    @SwiftUI.State private var shortcutPickerButtonMode: ShortcutPickerButtonMode = .normal
    @SwiftUI.State private var widgetTriggerInterval: Double = 0
    @SwiftUI.State private var widgetShape: WidgetCreateShape = .round
    @SwiftUI.State private var widgetButtonLabel: String = ""
    @SwiftUI.State private var lastCreatedWidgetPayload: [String: String]? = nil
    @SwiftUI.State private var pendingSubmissionAction: WidgetPickerSubmissionAction = .create
    @SwiftUI.State private var didApplyInitialConfiguration: Bool = false
    @SwiftUI.State private var selectionSyncToken: Int = 0
    @SwiftUI.State private var showButtonMacroSheet = false
    @SwiftUI.State private var editingButtonMacroItemID: UUID? = nil
    @SwiftUI.State private var buttonMacroMode: WidgetButtonMacroMode = .holdUntilRelease
    @SwiftUI.State private var buttonMacroDuration: Double = 2000
    @SwiftUI.State private var buttonMacroManualDurationText: String = ""
    @SwiftUI.State private var showTriggerIntervalSheet = false
    @SwiftUI.State private var editingTriggerIntervalItemID: UUID? = nil
    @SwiftUI.State private var triggerIntervalEditMode: TriggerIntervalEditMode = .all
    @SwiftUI.State private var triggerIntervalEditorValue: Double = 0
    @SwiftUI.State private var triggerIntervalManualValueText: String = ""
    @SwiftUI.State private var suppressKeyboardDrivenLayoutAnimation = false
    @SwiftUI.State private var poolGridInteractionResetToken: Int = 0
    @SwiftUI.State private var poolAutoScrollTargetItemID: UUID? = nil
    @SwiftUI.State private var poolAutoScrollRequestToken: Int = 0

    private static func restoredTab(from availableTabs: [WidgetPickerTab]) -> WidgetPickerTab {
        if let persistedIdentifier = UserDefaults.standard.string(forKey: lastSelectedTabDefaultsKey),
           let persistedTab = WidgetPickerTab(identifier: persistedIdentifier),
           availableTabs.contains(persistedTab) {
            return persistedTab
        }
        return availableTabs[0]
    }

    init(
        isEditMode: Bool = false,
        initialCmdString: String? = nil,
        initialButtonLabel: String? = nil,
        initialShape: String? = nil,
        availableTabs: [WidgetPickerTab] = WidgetPickerTab.allCases,
        preferredInitialTab: WidgetPickerTab? = nil,
        keyboardPickerMode: VirtualKeyboardMode = .picker,
        shortcutPickerNeedAlias: Bool = false,
        shortcutPickerNeedButtonMode: Bool = false,
        shortcutPickerTipText: String? = nil,
        shortcutIdentififier: String? = nil,
        presentationState: WidgetPickerPresentationState = WidgetPickerPresentationState(),
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
        self.keyboardPickerMode = keyboardPickerMode
        self.shortcutPickerNeedAlias = shortcutPickerNeedAlias
        self.shortcutPickerNeedButtonMode = shortcutPickerNeedButtonMode
        self.shortcutPickerTipText = shortcutPickerTipText
        self.shortcutIdentifier = shortcutIdentififier
        self.presentationState = presentationState
        self.onWidgetCreated = onWidgetCreated
        self.onCloseRequested = onCloseRequested
        _selectedTab = SwiftUI.State(
            initialValue: isEditMode
                ? (resolvedInitialTab ?? (normalizedTabs.contains(.keyboard) ? .keyboard : normalizedTabs[0]))
                : Self.restoredTab(from: normalizedTabs)
        )
        _tipMessage = SwiftUI.State(
            initialValue: (keyboardPickerMode == .shortcutPicker && !(shortcutPickerTipText ?? "").isEmpty)
                ? (shortcutPickerTipText ?? "")
                : LocalizationHelper.localizedString(forKey: "Tap any control to add it")
        )
    }

    private let functionalButtonOptions: [FunctionalButtonOption] = [
        FunctionalButtonOption(
            localizationKey: "=settings",
            cmd: "SETTINGS",
            tip: LocalizationHelper.localizedString(forKey: "Expands setting menu during streaming"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=disconnect",
            cmd: "DISCONNECT",
            tip: LocalizationHelper.localizedString(forKey: "Disconnect current connection"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=quitApp",
            cmd: "QUITAPP",
            tip: LocalizationHelper.localizedString(forKey: "Disconnect and quit current app"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=enterPiP",
            cmd: "PIP",
            tip: LocalizationHelper.localizedString(forKey: "Enter picture-in-picture mode"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=Folder",
            cmd: "FOLDER",
            tip: LocalizationHelper.localizedString(forKey: "Collect other widgets or subfolders. Button-combo available."),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: true,
            allowsShortcutCombo: true,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=toolbox",
            cmd: "TOOLBOX",
            tip: LocalizationHelper.localizedString(forKey: "Activate toolbox menu during streaming"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=widgetTool",
            cmd: "WIDGETTOOL",
            tip: LocalizationHelper.localizedString(forKey: "Open on-screen widget layout tool"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=pickProfile",
            cmd: "PICKPRFL",
            tip: LocalizationHelper.localizedString(forKey: "Pick a game/on-screen-widget profile"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=profiles",
            cmd: "PROFILES",
            tip: LocalizationHelper.localizedString(forKey: "Select a game/on-screen-widget profile"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=softkeyboard",
            cmd: "SOFTKEYBOARD",
            tip: LocalizationHelper.localizedString(forKey: "Bring up softkeyboard"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        
        FunctionalButtonOption(
            localizationKey: "=DisableTouch",
            cmd: "DISABLETOUCH",
            tip: LocalizationHelper.localizedString(forKey: "Temporarily disable touch input for stream view"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=gamepadOverlaySwitch",
            cmd: "GAMEPADOVERLAY",
            tip: LocalizationHelper.localizedString(forKey: "Switch on/off a floating gamepad overlay with live input feedback"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=pressureCurve",
            cmd: "PRESSURECURVE",
            tip: LocalizationHelper.localizedString(forKey: "Opens pencil pressure curve tool"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=pencilHover",
            cmd: "PENCILHOVER",
            tip: LocalizationHelper.localizedString(forKey: "Force pencil entering hovering on host"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=brushShortcut",
            cmd: "BRUSH",
            tip: LocalizationHelper.localizedString(forKey: "Combine this with a brush keyboard shortcut for PC software"),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: false,
            allowsShortcutCombo: true,
            forcedComboMode: .shortcut
        ),
        FunctionalButtonOption(
            localizationKey: "=eraserShortcut",
            cmd: "ERASER",
            tip: LocalizationHelper.localizedString(forKey: "Combine this with a eraser keyboard shortcut for PC software"),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: false,
            allowsShortcutCombo: true,
            forcedComboMode: .shortcut
        ),
        FunctionalButtonOption(
            localizationKey: "=disableSinglePointTouch",
            cmd: "NOSINGLETOUCH",
            tip: LocalizationHelper.localizedString(forKey: "Disable single finger touch for stream view"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: nil
        ),
        FunctionalButtonOption(
            localizationKey: "=absoluteTouchDrag",
            cmd: "ABSTCHDRAG",
            tip: LocalizationHelper.localizedString(forKey: "Replace mouse button action in single point touch mode with another button temporarily"),
            allowsKeyboardCombination: true,
            allowsGamepadCombination: true,
            allowsSkillCombo: true,
            allowsShortcutCombo: false,
            forcedComboMode: .skill
        ),
        FunctionalButtonOption(
            localizationKey: "=magnifier",
            cmd: "MAGNIFIER",
            tip: LocalizationHelper.localizedString(forKey: "magnifierTip"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: .skill
        ),
        FunctionalButtonOption(
            localizationKey: "=dummyPad",
            cmd: "DUMMYPAD",
            tip: LocalizationHelper.localizedString(forKey: "dummyPadTip"),
            allowsKeyboardCombination: false,
            allowsGamepadCombination: false,
            allowsSkillCombo: false,
            allowsShortcutCombo: false,
            forcedComboMode: .skill
        ),
    ]

    private let shortcutLibraryOptions: [FunctionalButtonOption] = [
        FunctionalButtonOption(localizationKey: "=nvidiaShot", cmd: "ALT+F1", tip: LocalizationHelper.localizedString(forKey: "=nvidiaShot"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=nvidiaRec", cmd: "ALT+F9", tip: LocalizationHelper.localizedString(forKey: "=nvidiaRec"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=hdr", cmd: "WIN+ALT+B", tip: LocalizationHelper.localizedString(forKey: "=hdr"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=taskManager", cmd: "CTRL+SHIFT+ESC", tip: LocalizationHelper.localizedString(forKey: "=taskManager"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=snip", cmd: "WIN+SHIFT+S", tip: LocalizationHelper.localizedString(forKey: "=snip"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=copy", cmd: "CTRL+C", tip: LocalizationHelper.localizedString(forKey: "=copy"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=cut", cmd: "CTRL+X", tip: LocalizationHelper.localizedString(forKey: "=cut"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=paste", cmd: "CTRL+V", tip: LocalizationHelper.localizedString(forKey: "=paste"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=undo", cmd: "CTRL+Z", tip: LocalizationHelper.localizedString(forKey: "=undo"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=redo", cmd: "CTRL+Y", tip: LocalizationHelper.localizedString(forKey: "=redo"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=selectAll", cmd: "CTRL+A", tip: LocalizationHelper.localizedString(forKey: "=selectAll"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=save", cmd: "CTRL+S", tip: LocalizationHelper.localizedString(forKey: "=save"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=find", cmd: "CTRL+F", tip: LocalizationHelper.localizedString(forKey: "=find"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=zoomIn", cmd: "CTRL+EQUALS", tip: LocalizationHelper.localizedString(forKey: "=zoomIn"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=zoomOut", cmd: "CTRL+MINUS", tip: LocalizationHelper.localizedString(forKey: "=zoomOut"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=ime", cmd: "WIN+SPACE", tip: LocalizationHelper.localizedString(forKey: "=ime"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=lang", cmd: "ALT+SHIFT", tip: LocalizationHelper.localizedString(forKey: "=lang"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=switchWindow", cmd: "ALT+TAB", tip: LocalizationHelper.localizedString(forKey: "=switchWindow"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=closeWindow", cmd: "ALT+F4", tip: LocalizationHelper.localizedString(forKey: "=closeWindow"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=desktop", cmd: "WIN+D", tip: LocalizationHelper.localizedString(forKey: "=desktop"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=fileExplorer", cmd: "WIN+E", tip: LocalizationHelper.localizedString(forKey: "=fileExplorer"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=settingsShortcut", cmd: "WIN+I", tip: LocalizationHelper.localizedString(forKey: "=settingsShortcut"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=powerMenu", cmd: "WIN+X", tip: LocalizationHelper.localizedString(forKey: "=powerMenu"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=lock", cmd: "WIN+L", tip: LocalizationHelper.localizedString(forKey: "=lock"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=run", cmd: "WIN+R", tip: LocalizationHelper.localizedString(forKey: "=run"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=search", cmd: "WIN+S", tip: LocalizationHelper.localizedString(forKey: "=search"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=taskView", cmd: "WIN+TAB", tip: LocalizationHelper.localizedString(forKey: "=taskView"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=snapLeft", cmd: "WIN+LEFTARR", tip: LocalizationHelper.localizedString(forKey: "=snapLeft"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=snapRight", cmd: "WIN+RIGHTARR", tip: LocalizationHelper.localizedString(forKey: "=snapRight"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=maximize", cmd: "WIN+UPARR", tip: LocalizationHelper.localizedString(forKey: "=maximize"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=minimize", cmd: "WIN+DOWNARR", tip: LocalizationHelper.localizedString(forKey: "=minimize"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=newFolder", cmd: "CTRL+SHIFT+N", tip: LocalizationHelper.localizedString(forKey: "=newFolder"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=newTab", cmd: "CTRL+T", tip: LocalizationHelper.localizedString(forKey: "=newTab"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
        FunctionalButtonOption(localizationKey: "=closeTab", cmd: "CTRL+W", tip: LocalizationHelper.localizedString(forKey: "=closeTab"), allowsKeyboardCombination: false, allowsGamepadCombination: false, allowsSkillCombo: false, allowsShortcutCombo: false, forcedComboMode: .shortcut),
    ]

    private var defaultTipMessage: String {
        if isShortcutPickerMode, let shortcutPickerTipText, !shortcutPickerTipText.isEmpty {
            return shortcutPickerTipText
        }
        return LocalizationHelper.localizedString(forKey: "Tap any control to add it")
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
        if isShortcutPickerMode, let shortcutPickerTipText, !shortcutPickerTipText.isEmpty {
            tipMessage = shortcutPickerTipText
            tipMessageType = .normal
            return
        }
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

    private var selectedMovementPadCommand: String? {
        poolItems.first(where: {
            let command = Self.selectionIdentifier(for: $0.cmd)
            return command == "WASDPAD" || command == "ARROWPAD"
        })?.cmd
    }

    private var movementPadSingleButtonCount: Int {
        guard selectedMovementPadCommand != nil else { return 0 }
        return poolItems.filter { !isPad($0) }.count
    }

    private var movementPadNeedsWalkKeyTip: Bool {
        selectedMovementPadCommand != nil && movementPadSingleButtonCount == 0
    }

    private var movementPadNeedsSprintKeyTip: Bool {
        selectedMovementPadCommand != nil && movementPadSingleButtonCount == 1
    }

    private var movementPadHasReachedSingleKeyLimit: Bool {
        selectedMovementPadCommand != nil && movementPadSingleButtonCount >= 2
    }

    private func updateTipMessageForCurrentPoolState() {
        if poolItems.isEmpty {
            resetTipMessage()
        } else if movementPadNeedsWalkKeyTip {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Please select a sprint key"))
        } else if movementPadNeedsSprintKeyTip {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Sprint key set. Select a walk key (optional, you can skip and create)"))
        } else if movementPadHasReachedSingleKeyLimit {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Sprint and walk keys are set"))
        } else if hasButtonThenPadCombination {
            setTipMessage(LocalizationHelper.localizedString(forKey: "A button with touchpad functionality will be created"))
        } else if hasPadThenButtonCombination {
            setTipMessage(LocalizationHelper.localizedString(forKey: "A touchpad with double-tap button triggering will be created"))
        } else if let selectedFunctionalButtonOption {
            setTipMessage(selectedFunctionalButtonOption.tip)
        } else if hasAnySingleItem || hasMultipleButtonItemsOnly {
            setTipMessage(
                LocalizationHelper.localizedString(
                    forKey: "Continue adding controls to this combination, or tap button in the pool to set macro."
                )
            )
        } else {
            resetTipMessage()
        }
    }

    private var pickerMetrics: WidgetPickerMetrics {
        WidgetPickerMetrics.make(for: UIDevice.current.userInterfaceIdiom == .phone)
    }

    var body: some View {
        ZStack {
            mainPickerBackdropAndContent

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

            if showButtonMacroSheet {
                buttonMacroSheet
                    .zIndex(1001)
            }

            if showTriggerIntervalSheet {
                triggerIntervalSheet
                    .zIndex(1002)
            }
        }
        .transaction { transaction in
            if suppressKeyboardDrivenLayoutAnimation {
                transaction.animation = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
            guard showCreateWidgetSheet || showButtonMacroSheet || showTriggerIntervalSheet else { return }
            suppressKeyboardDrivenLayoutAnimation = true
            resetKeyboardAnimationSuppression(using: notification)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            guard showCreateWidgetSheet || showButtonMacroSheet || showTriggerIntervalSheet else { return }
            suppressKeyboardDrivenLayoutAnimation = true
            resetKeyboardAnimationSuppression(using: notification)
        }
        .onAppear {
            UISegmentedControl.appearance().apportionsSegmentWidthsByContent = true
            applyInitialConfigurationIfNeeded()
        }
        .onDisappear {
            UISegmentedControl.appearance().apportionsSegmentWidthsByContent = false
        }
    }

    private var mainPickerBackdropAndContent: some View {
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

            RoundedRectangle(cornerRadius: pickerMetrics.blurCornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.30))
                .blur(radius: 40)
                .padding(pickerMetrics.blurPadding)

            GeometryReader { contentProxy in
                let usesVerticalLayout = contentProxy.size.height > contentProxy.size.width
                let isPadPortrait = !pickerMetrics.isPhone && usesVerticalLayout
                let isPhonePortrait = pickerMetrics.isPhone && usesVerticalLayout
                let verticalOuterPadding = isPhonePortrait ? pickerMetrics.outerPadding * 0.5 : pickerMetrics.outerPadding
                let reclaimedBottomSafeArea = isPhonePortrait ? contentProxy.safeAreaInsets.bottom : 0
                let centeredContentTopInset = pickerMetrics.isPhone ? 0 : contentProxy.safeAreaInsets.top
                let centeredContentBottomInset = pickerMetrics.isPhone ? 0 : contentProxy.safeAreaInsets.bottom
                let leftWidth = max(pickerMetrics.isPhone ? 0 : 420, contentProxy.size.width * pickerMetrics.leftWidthRatio)
                let rightWidth = max(
                    pickerMetrics.rightPanelMinWidth,
                    contentProxy.size.width - leftWidth - pickerMetrics.panelSpacing - pickerMetrics.outerPadding * 2
                )
                let centeredContentHeight = max(
                    contentProxy.size.height - centeredContentTopInset - centeredContentBottomInset,
                    0
                )
                let sharedVerticalAvailableHeight = centeredContentHeight - pickerMetrics.panelSpacing - verticalOuterPadding * 2
                let poolVerticalBonusHeight = isPhonePortrait ? 16.0 : 20.0
                let sharedVerticalHeight = max(220, sharedVerticalAvailableHeight * 0.5)
                let verticalPoolHeight = max(220, sharedVerticalHeight + poolVerticalBonusHeight)
                let verticalPickerHeight = max(220, sharedVerticalAvailableHeight - verticalPoolHeight)
                let bottomStackPadding = isPhonePortrait ? (verticalOuterPadding - reclaimedBottomSafeArea) : verticalOuterPadding

                VStack {
                    Group {
                        if usesVerticalLayout {
                            VStack(alignment: .leading, spacing: pickerMetrics.panelSpacing) {
                                widgetPoolPanel(metrics: pickerMetrics, isPadPortrait: isPadPortrait)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: verticalPoolHeight)

                                widgetPickerPanel(metrics: pickerMetrics, isPadPortrait: isPadPortrait)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: verticalPickerHeight)
                            }
                        } else {
                            HStack(alignment: .top, spacing: pickerMetrics.panelSpacing) {
                                widgetPoolPanel(metrics: pickerMetrics, isPadPortrait: isPadPortrait)
                                    .frame(width: rightWidth)

                                widgetPickerPanel(metrics: pickerMetrics, isPadPortrait: isPadPortrait)
                                    .frame(width: leftWidth)
                            }
                        }
                    }
                    .allowsHitTesting(!showGyroPicker && !showCreateWidgetSheet && !showButtonMacroSheet && !showTriggerIntervalSheet)
                    .padding(.top, verticalOuterPadding)
                    .padding(.leading, pickerMetrics.outerPadding)
                    .padding(.trailing, pickerMetrics.outerPadding)
                    .padding(.bottom, bottomStackPadding)
                    .frame(maxWidth: .infinity, maxHeight: centeredContentHeight, alignment: .center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .widgetPickerIgnoreKeyboardSafeAreaWhenAvailable()
    }

    private func resetKeyboardAnimationSuppression(using notification: Notification) {
        let duration = (notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.35
        DispatchQueue.main.asyncAfter(deadline: .now() + max(duration, 0.05)) {
            suppressKeyboardDrivenLayoutAnimation = false
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
                    Text(LocalizationHelper.localizedString(forKey: "Widget Picker"))
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

                    AbstractGamepadView(
                        gamepadType: selectedGamepadType,
                        metricsProfile: .picker,
                        canSelectCommand: { canSelectCommand($0, source: .gamepad) },
                        isCommandSelected: { selectedCmds.contains($0) },
                        onCommandSelected: { appendCommand($0, source: .gamepad) },
                        onCommandDeselected: { removeCommand($0, source: .gamepad) },
                        resetToken: resetToken,
                        selectionSyncToken: selectionSyncToken,
                        externalDeselectionCommand: gamepadDeselectionCommand,
                        externalDeselectionToken: gamepadDeselectionToken
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, pickerInsetGamepadHorizontal)
                    .padding(.vertical, pickerInsetGamepadVertical)
                    .contentShape(Rectangle())
                    .opacity(contentVisibilityOpacity(for: .gamepad))
                    .allowsHitTesting(isContentInteractive(for: .gamepad))
                    .accessibility(hidden: !isContentVisible(for: .gamepad))

                    VirtualKeyboardView(
                        mode: keyboardPickerMode,
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
                    .opacity(contentVisibilityOpacity(for: .keyboard))
                    .allowsHitTesting(isContentInteractive(for: .keyboard))
                    .accessibility(hidden: !isContentVisible(for: .keyboard))

                    FunctionalButtonCollectionView(
                        items: functionalButtonOptions,
                        isSelected: { selectedCmds.contains($0) },
                        onSelect: { handleFunctionalButtonSelection($0) },
                        onDeselect: { handleFunctionalButtonDeselection($0) }
                    )
                    .padding(pickerInsetFunctional)
                    .opacity(contentVisibilityOpacity(for: .functional))
                    .allowsHitTesting(isContentInteractive(for: .functional))
                    .accessibility(hidden: !isContentVisible(for: .functional))

                    FunctionalButtonCollectionView(
                        items: shortcutLibraryOptions,
                        isSelected: { selectedCmds.contains($0) },
                        onSelect: { handleShortcutLibrarySelection($0) },
                        onDeselect: { handleShortcutLibraryDeselection($0) }
                    )
                    .padding(pickerInsetFunctional)
                    .opacity(contentVisibilityOpacity(for: .shortcuts))
                    .allowsHitTesting(isContentInteractive(for: .shortcuts))
                    .accessibility(hidden: !isContentVisible(for: .shortcuts))
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
                    handleCloseRequested()
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

    private func isContentVisible(for tab: WidgetPickerTab) -> Bool {
        presentationState.hasHostAppeared && selectedTab == tab
    }

    private func isContentInteractive(for tab: WidgetPickerTab) -> Bool {
        isContentVisible(for: tab)
    }

    private func contentVisibilityOpacity(for tab: WidgetPickerTab) -> Double {
        isContentVisible(for: tab) ? 1 : 0
    }

    private func widgetPickerTabBar(metrics: WidgetPickerMetrics, isPadPortrait: Bool = false) -> some View {
        let tabSpacing = isPadPortrait ? 8.0 : metrics.tabSpacing
        let tabFontSize = isPadPortrait ? 12.0 : metrics.tabFontSize
        let tabHorizontalPadding = isPadPortrait ? 10.0 : metrics.tabHorizontalPadding
        let tabHeight = isPadPortrait ? 30.0 : metrics.tabHeight
        let tabMinWidth = isPadPortrait ? 88.0 : (metrics.isPhone ? 43 : 50)

        return HStack(spacing: tabSpacing) {
            ForEach(availableTabs) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    Text(tab.title)
                        .font(.system(size: tabFontSize, weight: .bold, design: .rounded))
                        .foregroundColor(selectedTab == tab ? Color.white : Color.black.opacity(0.56))
                        .padding(.horizontal, tabHorizontalPadding)
                        .frame(minWidth: tabMinWidth)
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
                Text(LocalizationHelper.localizedString(forKey: "Widget Pool"))
                    .font(.system(size: poolTitleFontSize, weight: .bold, design: .rounded))
                    .foregroundColor(Color.black.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                

                Text(LocalizationHelper.localizedString(forKey: "Selected widgets are queued here in tap order."))
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
                contentInset: metrics.poolGridInset,
                scrollTargetItemID: poolAutoScrollTargetItemID,
                scrollRequestToken: poolAutoScrollRequestToken
            )
                .id(poolGridInteractionResetToken)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: poolGridWidth ?? .infinity, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .center)

            if keyboardPickerMode != .shortcutPicker {
                HStack(spacing: metrics.isPhone ? 8 : 12) {
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Gyro button"),
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
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Insert trigger interval"),
                        isPrimary: false,
                        height: poolChipHeight,
                        fontSize: poolChipFontSize,
                        cornerRadius: metrics.chipCornerRadius
                    ) {
                        handleInsertTriggerIntervalTap()
                    }
                }
            }

            HStack(spacing: metrics.isPhone ? 8 : 12) {
                PoolActionChip(
                    title: isShortcutPickerMode
                        ? LocalizationHelper.localizedString(forKey: "Create shortcut")
                        : (isEditMode
                            ? WidgetPickerSubmissionAction.create.poolActionTitle
                            : LocalizationHelper.localizedString(forKey: "Create widget")),
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
                    title: LocalizationHelper.localizedString(forKey: "Reset"),
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
                        .minimumScaleFactor(0.5)
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
            .allowsHitTesting(false)
    }

    private func appendCommand(_ cmd: String, source: WidgetPoolSource) {
        let existingCount = poolItems.count
        let shouldRebalanceTriggerIntervals = hasTriggerIntervalSlots
        guard !cmd.isEmpty else { return }
        let item = WidgetPoolItem(
            cmd: cmd,
            source: source,
            visualKind: visualKind(for: cmd, source: source),
            staysAtTail: shouldMarkItemAsTailLocked(cmd: cmd, source: source, existingCount: existingCount),
            displayText: keyboardPoolDisplayText(for: cmd, source: source)
        )

        if shouldInsertCommandAtFront(cmd) {
            selectedCmds.insert(Self.selectionIdentifier(for: cmd), at: 0)
            poolItems.insert(item, at: 0)
        } else if shouldKeepItemAtPoolTail(item), !poolItems.isEmpty {
            selectedCmds.append(Self.selectionIdentifier(for: cmd))
            poolItems.append(item)
        } else if let trailingPadIndex = trailingCombinablePadIndex {
            selectedCmds.insert(Self.selectionIdentifier(for: cmd), at: trailingPadIndex)
            poolItems.insert(item, at: trailingPadIndex)
        } else {
            selectedCmds.append(Self.selectionIdentifier(for: cmd))
            poolItems.append(item)
        }
        if shouldRebalanceTriggerIntervals {
            rebalanceTriggerIntervalItems()
        }
        normalizeLeadingFunctionalItemPriorityIfNeeded()
        poolAutoScrollTargetItemID = item.id
        poolAutoScrollRequestToken += 1
        updateTipMessageForCurrentPoolState()
    }

    private func visualKind(for cmd: String, source: WidgetPoolSource) -> WidgetPoolVisualKind {
        switch source {
        case .gamepad:
            return gamepadPadCommands.contains(cmd) ? .gamepadPad : .gamepadButton
        case .functional:
            return .functionalButton
        case .shortcuts:
            return .shortcutButton
        case .keyboard:
            return keyboardPadCommands.contains(cmd) ? .keyboardPad : .keyboardButton
        case .interval:
            return .triggerInterval
        }
    }

    private var keyboardPadCommands: Set<String> {
        [
            "WASDPAD",
            "ARROWPAD",
            "WHEEL",
            "MOUSEPAD",
            "ABSMOUSEPAD",
            "TRACKBALL"
        ]
    }

    private var gamepadPadCommands: Set<String> {
        [
            "DPAD",
            "LSWHEEL",
            "LSPAD",
            "LSVPAD",
            "RSPAD",
            "RSVPAD",
            "RSWHEEL",
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
        if leadingPriorityFunctionalCommands.contains(Self.selectionIdentifier(for: cmd)) {
            return true
        }

        if priorityFirstCommands.contains(cmd) {
            return true
        }

        if cmd == "RS", poolItems.contains(where: { $0.cmd == "RSPAD" || $0.cmd == "RSVPAD" }) {
            return true
        }

        if cmd == "LS", poolItems.contains(where: { $0.cmd == "LSPAD" || $0.cmd == "LSVPAD" }) {
            return true
        }
        
        return false
    }

    private var leadingPriorityFunctionalCommands: Set<String> {
        ["FOLDER", "ERASER", "BRUSH"]
    }

    private func normalizeLeadingFunctionalItemPriorityIfNeeded() {
        guard let leadingItemIndex = poolItems.firstIndex(where: {
            leadingPriorityFunctionalCommands.contains(Self.selectionIdentifier(for: $0.cmd))
        }), leadingItemIndex > 0 else {
            return
        }

        let leadingItem = poolItems.remove(at: leadingItemIndex)
        let leadingIdentifier = Self.selectionIdentifier(for: leadingItem.cmd)
        poolItems.insert(leadingItem, at: 0)

        if let selectedItemIndex = selectedCmds.firstIndex(of: leadingIdentifier), selectedItemIndex > 0 {
            let selectedItem = selectedCmds.remove(at: selectedItemIndex)
            selectedCmds.insert(selectedItem, at: 0)
        }
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
        if item.cmd == "RSWHEEL" { return false }
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
        switch Self.selectionIdentifier(for: cmd) {
        case "LT", "LTPAD":
            return "LT"
        case "RT", "RTPAD":
            return "RT"
        default:
            return nil
        }
    }

    private func directionPadGroup(for cmd: String) -> String? {
        let normalized = Self.selectionIdentifier(for: cmd)
        if normalized == "WASDPAD" || wasdSingleCommands.contains(normalized) {
            return "WASD"
        }

        if normalized == "ARROWPAD" || arrowSingleCommands.contains(normalized) {
            return "ARROW"
        }

        if normalized == "DPAD" || dpadSingleCommands.contains(normalized) {
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

        let shouldRebalanceTriggerIntervals = hasTriggerIntervalSlots && source != .interval

        if source != .interval {
            let selectionIdentifier = Self.selectionIdentifier(for: cmd)
            if let cmdIndex = selectedCmds.firstIndex(of: selectionIdentifier) {
                selectedCmds.remove(at: cmdIndex)
            }
        }

        if let itemIndex = poolItems.firstIndex(where: { $0.cmd == cmd && $0.source == source }) {
            poolItems.remove(at: itemIndex)
        }

        if shouldRebalanceTriggerIntervals {
            rebalanceTriggerIntervalItems()
        }

        updateTipMessageForCurrentPoolState()
        selectionSyncToken += 1
    }

    private func removePoolItem(_ item: WidgetPoolItem) {
        let deselectionCommand = Self.selectionIdentifier(for: item.cmd)
        removeCommand(item.cmd, source: item.source)
        let shouldClearHighlight = !selectedCmds.contains(deselectionCommand)

        switch item.source {
        case .keyboard:
            if shouldClearHighlight {
                keyboardDeselectionCommand = deselectionCommand
                keyboardDeselectionToken += 1
            }
        case .gamepad:
            if shouldClearHighlight {
                gamepadDeselectionCommand = deselectionCommand
                gamepadDeselectionToken += 1
            }
        case .functional:
            if shouldClearHighlight, selectedGyroCommand == deselectionCommand {
                selectedGyroCommand = nil
            }
        case .shortcuts:
            break
        case .interval:
            break
        }
    }

    private func handlePoolItemTap(_ item: WidgetPoolItem) {
        if isTriggerIntervalItem(item) {
            prepareTriggerIntervalSheet(for: item)
            showTriggerIntervalSheet = true
            return
        }

        let shouldPresentMacroSheet = shouldPresentButtonMacroSheet(for: item)
        NSLog(
            "WidgetPickerView handlePoolItemTap cmd=%@ visualKind=%@ shouldPresentMacroSheet=%@",
            item.cmd,
            String(describing: item.visualKind),
            shouldPresentMacroSheet ? "YES" : "NO"
        )

        if shouldPresentMacroSheet {
            prepareButtonMacroSheet(for: item)
            showButtonMacroSheet = true
            return
        }

        removePoolItem(item)
    }

    private func shouldPresentButtonMacroSheet(for item: WidgetPoolItem) -> Bool {
        guard !isShortcutPickerMode else { return false }
        guard !containsMovementDirectionPad else { return false }
        switch item.visualKind {
        case .keyboardButton, .gamepadButton:
            return true
        case .gamepadPad, .keyboardPad, .functionalButton, .shortcutButton, .triggerInterval:
            return false
        }
    }

    private func prepareButtonMacroSheet(for item: WidgetPoolItem) {
        editingButtonMacroItemID = item.id
        buttonMacroManualDurationText = ""
        let displaySuffix = macroDisplaySuffix(for: item)
        if displaySuffix == localizedTapLabel {
            buttonMacroMode = .tap
        } else if let duration = Self.macroDuration(for: item.cmd) {
            buttonMacroMode = .timedRelease
            if isButtonMacroDurationWithinSliderRange(duration) {
                buttonMacroDuration = Double(duration)
            } else {
                buttonMacroManualDurationText = String(duration)
                buttonMacroDuration = buttonMacroTimedMinimumDuration
            }
        } else {
            buttonMacroMode = .holdUntilRelease
        }
        normalizeButtonMacroState()
    }

    private func normalizeButtonMacroState() {
        switch buttonMacroMode {
        case .holdUntilRelease:
            buttonMacroDuration = buttonMacroMaximumDuration
        case .timedRelease:
            buttonMacroDuration = min(buttonMacroMaximumDuration, max(buttonMacroTimedMinimumDuration, buttonMacroDuration.rounded()))
        case .tap:
            buttonMacroDuration = buttonMacroMinimumDuration
        }
    }

    private var buttonMacroModeSelectionBinding: Binding<Int> {
        Binding(
            get: { buttonMacroMode.rawValue },
            set: { newValue in
                buttonMacroMode = WidgetButtonMacroMode(rawValue: newValue) ?? .holdUntilRelease
                normalizeButtonMacroState()
            }
        )
    }

    private var localizedTapLabel: String {
        LocalizationHelper.localizedString(forKey: "tap")
    }

    private func macroDisplaySuffix(for item: WidgetPoolItem) -> String? {
        guard let displayText = item.displayText else { return nil }
        let lines = displayText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.count >= 2 ? lines.last : nil
    }

    private func baseDisplayLabel(for item: WidgetPoolItem) -> String {
        if let displayText = item.displayText {
            let firstLine = displayText
                .components(separatedBy: .newlines)
                .first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !firstLine.isEmpty {
                return firstLine
            }
        }
        return item.displayCmd.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var manualButtonMacroDurationValue: Int? {
        let trimmedValue = buttonMacroManualDurationText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, let duration = Int(trimmedValue), duration >= 0 else {
            return nil
        }
        return duration
    }

    private func isButtonMacroDurationWithinSliderRange(_ duration: Int) -> Bool {
        duration >= Int(buttonMacroMinimumDuration) && duration <= Int(buttonMacroMaximumDuration)
    }

    private var buttonMacroDurationTitleText: String {
        let pressDurationTitle = LocalizationHelper.localizedString(forKey: "Press duration")
        if manualButtonMacroDurationValue != nil {
            return "\(pressDurationTitle): "
        }

        switch buttonMacroMode {
        case .holdUntilRelease:
            return pressDurationTitle
        case .timedRelease, .tap:
            return LocalizationHelper.localizedString(forKey: "Press duration: %d ms", effectiveButtonMacroDurationValue)
        }
    }

    private var effectiveButtonMacroDurationValue: Int {
        if let manualButtonMacroDurationValue {
            return manualButtonMacroDurationValue
        }
        switch buttonMacroMode {
        case .holdUntilRelease:
            return Int(buttonMacroMaximumDuration)
        case .timedRelease:
            return Int(min(buttonMacroMaximumDuration, max(buttonMacroTimedMinimumDuration, buttonMacroDuration.rounded())))
        case .tap:
            return Int(buttonMacroMinimumDuration)
        }
    }

    private func dismissButtonMacroSheet() {
        NSLog("WidgetPickerView dismissButtonMacroSheet resetTokenBefore=%d", poolGridInteractionResetToken)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            showButtonMacroSheet = false
            // editingButtonMacroItemID = nil
            // poolGridInteractionResetToken += 1
            NSLog("WidgetPickerView dismissButtonMacroSheet resetTokenAfter=%d", poolGridInteractionResetToken)
        }
    }

    private func removeEditingButtonMacroItem() {
        guard let editingButtonMacroItemID,
              let item = poolItems.first(where: { $0.id == editingButtonMacroItemID }) else {
            dismissButtonMacroSheet()
            return
        }

        dismissButtonMacroSheet()
        removePoolItem(item)
    }

    private func applyButtonMacroChanges() {
        guard let editingButtonMacroItemID,
              let itemIndex = poolItems.firstIndex(where: { $0.id == editingButtonMacroItemID }) else {
            dismissButtonMacroSheet()
            return
        }

        let item = poolItems[itemIndex]
        let baseCommand = Self.selectionIdentifier(for: item.cmd)
        let baseLabel = baseDisplayLabel(for: item)

        let resolvedCommand: String
        let resolvedDisplayText: String
        switch buttonMacroMode {
        case .holdUntilRelease:
            resolvedCommand = baseCommand
            resolvedDisplayText = baseLabel
        case .timedRelease:
            let duration = effectiveButtonMacroDurationValue
            resolvedCommand = "\(baseCommand).\(duration)"
            resolvedDisplayText = "\(baseLabel)\n\(LocalizationHelper.localizedString(forKey: "↓%dms", duration))"
        case .tap:
            resolvedCommand = "\(baseCommand).30"
            resolvedDisplayText = "\(baseLabel)\n\(localizedTapLabel)"
        }

        poolItems[itemIndex] = WidgetPoolItem(
            cmd: resolvedCommand,
            source: item.source,
            visualKind: item.visualKind,
            staysAtTail: item.staysAtTail,
            displayText: resolvedDisplayText
        )
        updateTipMessageForCurrentPoolState()
        dismissButtonMacroSheet()
    }

    private func isPad(_ item: WidgetPoolItem) -> Bool {
        item.visualKind == .keyboardPad || item.visualKind == .gamepadPad
    }

    private func isTriggerIntervalItem(_ item: WidgetPoolItem) -> Bool {
        item.visualKind == .triggerInterval
    }

    private func isButtonItem(_ item: WidgetPoolItem) -> Bool {
        switch item.visualKind {
        case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton:
            return true
        case .gamepadPad, .keyboardPad, .triggerInterval:
            return false
        }
    }

    private var hasTriggerIntervalSlots: Bool {
        poolItems.contains(where: isTriggerIntervalItem)
    }

    private var buttonItemsInPool: [WidgetPoolItem] {
        poolItems.filter(isButtonItem)
    }

    private var triggerIntervalItems: [WidgetPoolItem] {
        poolItems.filter(isTriggerIntervalItem)
    }

    private func makeTriggerIntervalItem(milliseconds: Int) -> WidgetPoolItem {
        WidgetPoolItem(
            cmd: Self.makeTriggerIntervalCommand(milliseconds: milliseconds),
            source: .interval,
            visualKind: .triggerInterval,
            staysAtTail: false,
            displayText: nil
        )
    }

    private func rebalanceTriggerIntervalItems(defaultMilliseconds: Int? = nil) {
        let baseItems = poolItems.filter { !isTriggerIntervalItem($0) }
        let buttonCount = baseItems.filter(isButtonItem).count
        guard buttonCount >= 2 else {
            poolItems = baseItems
            return
        }

        let existingValues = triggerIntervalItems.compactMap { Self.triggerIntervalMilliseconds(for: $0.cmd) }
        var nextIntervalIndex = 0
        var remainingButtons = buttonCount
        var rebuiltItems: [WidgetPoolItem] = []

        for item in baseItems {
            rebuiltItems.append(item)
            guard isButtonItem(item) else { continue }
            remainingButtons -= 1
            guard remainingButtons > 0 else { continue }
            let milliseconds = defaultMilliseconds
                ?? (nextIntervalIndex < existingValues.count ? existingValues[nextIntervalIndex] : nil)
                ?? 0
            rebuiltItems.append(makeTriggerIntervalItem(milliseconds: milliseconds))
            nextIntervalIndex += 1
        }

        poolItems = rebuiltItems
        normalizeLeadingFunctionalItemPriorityIfNeeded()
    }

    private func handleInsertTriggerIntervalTap() {
        guard !containsMovementDirectionPad else {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Trigger interval cannot be inserted when WASDPAD or ARROWPAD is in the pool"), type: .error)
            return
        }

        let buttonCount = buttonItemsInPool.count
        guard buttonCount >= 2 else {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Select at least two button controls before inserting trigger intervals"), type: .error)
            return
        }

        if hasTriggerIntervalSlots {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Trigger interval slots are already inserted"))
            return
        }

        let requiredSlots = buttonCount - 1
        guard occupiedSlots + requiredSlots <= maxPoolSlots else {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Not enough room to insert trigger interval slots"), type: .error)
            return
        }

        rebalanceTriggerIntervalItems(defaultMilliseconds: 0)
        updateTipMessageForCurrentPoolState()
    }

    private func prepareTriggerIntervalSheet(for item: WidgetPoolItem) {
        editingTriggerIntervalItemID = item.id
        triggerIntervalManualValueText = ""
        let currentValue = Self.triggerIntervalMilliseconds(for: item.cmd) ?? 0
        let allValues = triggerIntervalItems.compactMap { Self.triggerIntervalMilliseconds(for: $0.cmd) }
        let uniformNonZeroValue = allValues.allSatisfy { $0 > 0 } ? allValues.first : nil
        let allValuesAreEqual = !allValues.isEmpty && Set(allValues).count == 1

        if allValuesAreEqual, let uniformValue = uniformNonZeroValue {
            triggerIntervalEditMode = .all
            triggerIntervalEditorValue = Double(uniformValue)
        } else {
            triggerIntervalEditMode = .individual
            triggerIntervalEditorValue = Double(max(Int(triggerIntervalMinimumDuration), currentValue))
        }
    }

    private var manualTriggerIntervalValue: Int? {
        let trimmedValue = triggerIntervalManualValueText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty, let value = Int(trimmedValue), value >= 0 else {
            return nil
        }
        return value
    }

    private var triggerIntervalTitleText: String {
        let title = LocalizationHelper.localizedString(forKey: "Trigger interval")
        if manualTriggerIntervalValue != nil {
            return "\(title): "
        }
        return "\(title): \(effectiveTriggerIntervalEditorValue) ms"
    }

    private var effectiveTriggerIntervalEditorValue: Int {
        if let manualTriggerIntervalValue {
            return manualTriggerIntervalValue
        }
        return Int(min(triggerIntervalMaximumDuration, max(triggerIntervalMinimumDuration, triggerIntervalEditorValue.rounded())))
    }

    private var triggerIntervalEditModeBinding: Binding<Int> {
        Binding(
            get: { triggerIntervalEditMode.rawValue },
            set: { newValue in
                triggerIntervalEditMode = TriggerIntervalEditMode(rawValue: newValue) ?? .all
            }
        )
    }

    private func dismissTriggerIntervalSheet() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            showTriggerIntervalSheet = false
            // editingTriggerIntervalItemID = nil
            // poolGridInteractionResetToken += 1
        }
    }

    private func applyTriggerIntervalChanges() {
        let newMilliseconds = effectiveTriggerIntervalEditorValue

        switch triggerIntervalEditMode {
        case .all:
            for index in poolItems.indices where isTriggerIntervalItem(poolItems[index]) {
                poolItems[index] = makeTriggerIntervalItem(milliseconds: newMilliseconds)
            }
        case .individual:
            guard let editingTriggerIntervalItemID,
                  let itemIndex = poolItems.firstIndex(where: { $0.id == editingTriggerIntervalItemID }) else {
                dismissTriggerIntervalSheet()
                return
            }
            poolItems[itemIndex] = makeTriggerIntervalItem(milliseconds: newMilliseconds)
        }

        updateTipMessageForCurrentPoolState()
        dismissTriggerIntervalSheet()
    }

    private func canSelectCommand(_ cmd: String, source: WidgetPoolSource) -> Bool {
        if selectedCmds.contains(Self.selectionIdentifier(for: cmd)) {
            return canAppendDuplicateCommand(cmd, source: source)
        }

        if movementPadHasReachedSingleKeyLimit {
            setTipMessage(
                LocalizationHelper.localizedString(forKey: "Walk and sprint keys are already set. No more keys can be added"),
                type: .error
            )
            return false
        }

        let candidate = WidgetPoolItem(
            cmd: cmd,
            source: source,
            visualKind: visualKind(for: cmd, source: source),
            staysAtTail: false,
            displayText: keyboardPoolDisplayText(for: cmd, source: source)
        )

        let additionalIntervalSlotCost = hasTriggerIntervalSlots && isButtonItem(candidate) ? 1 : 0
        if occupiedSlots + candidate.span + additionalIntervalSlotCost > maxPoolSlots {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Widget pool is full"), type: .error)
            return false
        }

        if isPad(candidate), poolItems.contains(where: isPad) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Cannot select two touchpad controls at the same time"), type: .error)
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
            setTipMessage(LocalizationHelper.localizedString(forKey: "Direction pad cannot be combined with their inner button"), type: .error)
            return false
        }

        if let candidateTriggerGroup = triggerGroup(for: cmd),
           poolItems.contains(where: { existing in
               triggerGroup(for: existing.cmd) == candidateTriggerGroup && existing.cmd != cmd
           }) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Trigger button cannot be combined with trigger pad"), type: .error)
            return false
        }

        if directionPadPriorityCommands.contains(cmd), poolItems.contains(where: { gyroCommands.contains($0.cmd) }) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Direction pad cannot be combined with gyro button"), type: .error)
            return false
        }

        if gyroCommands.contains(cmd), poolItems.contains(where: { directionPadPriorityCommands.contains($0.cmd) }) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Gyro widgets cannot be combined with direction pad"), type: .error)
            return false
        }

        if cmd == "LSWHEEL", !poolItems.isEmpty {
            setTipMessage(LocalizationHelper.localizedString(forKey: "LS wheel must be placed alone"), type: .error)
            return false
        }

        if !poolItems.isEmpty, poolItems.contains(where: { $0.cmd == "LSWHEEL" }) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "LsWheel cannot be combined with other widgets"), type: .error)
            return false
        }
        
        if cmd == "RSWHEEL", !poolItems.isEmpty {
            setTipMessage(LocalizationHelper.localizedString(forKey: "RS wheel must be placed alone"), type: .error)
            return false
        }

        if !poolItems.isEmpty, poolItems.contains(where: { $0.cmd == "RSWHEEL" }) {
            setTipMessage(LocalizationHelper.localizedString(forKey: "RsWheel cannot be combined with other widgets"), type: .error)
            return false
        }

        if (source == .functional || source == .shortcuts), !gyroCommands.contains(cmd) {
            guard let option = functionalButtonOption(for: cmd) ?? shortcutLibraryOption(for: cmd) else {
                resetTipMessage()
                return false
            }

            if poolItems.contains(where: isPad) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "Functional widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }

            if poolItems.contains(where: { $0.source == .functional || $0.source == .shortcuts }) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "Functional widgets cannot be combined with other functional widgets"), type: .error)
                return false
            }

            if !option.allowsKeyboardCombination,
               poolItems.contains(where: { $0.source == .keyboard && !isPad($0) }) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "This functional widget cannot be combined with keyboard or mouse buttons"), type: .error)
                return false
            }

            if !option.allowsGamepadCombination,
               poolItems.contains(where: { $0.source == .gamepad && !isPad($0) }) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "This functional widget cannot be combined with gamepad buttons"), type: .error)
                return false
            }
        }

        if source == .keyboard || source == .gamepad {
            if poolItems.contains(where: isPad) && poolItems.contains(where: { ($0.source == .functional || $0.source == .shortcuts) && !gyroCommands.contains($0.cmd) }) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "Functional widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }

            if let existingFunctionalItem = poolItems.first(where: { ($0.source == .functional || $0.source == .shortcuts) && !gyroCommands.contains($0.cmd) }),
               let option = functionalButtonOption(for: existingFunctionalItem.cmd) ?? shortcutLibraryOption(for: existingFunctionalItem.cmd) {
                if source == .keyboard && !option.allowsKeyboardCombination {
                    setTipMessage(LocalizationHelper.localizedString(forKey: "This functional widget cannot be combined with keyboard or mouse buttons"), type: .error)
                    return false
                }

                if source == .gamepad && !option.allowsGamepadCombination {
                    setTipMessage(LocalizationHelper.localizedString(forKey: "This functional widget cannot be combined with gamepad buttons"), type: .error)
                    return false
                }
            }

            if isPad(candidate),
               poolItems.contains(where: { ($0.source == .functional || $0.source == .shortcuts) && !gyroCommands.contains($0.cmd) }) {
                setTipMessage(LocalizationHelper.localizedString(forKey: "Functional widgets cannot be combined with touchpad controls"), type: .error)
                return false
            }
        }

        resetTipMessage()
        return true
    }

    private func canAppendDuplicateCommand(_ cmd: String, source: WidgetPoolSource) -> Bool {
        let selectionIdentifier = Self.selectionIdentifier(for: cmd)
        guard let lastMatchingItem = poolItems.last(where: {
            $0.source == source && Self.selectionIdentifier(for: $0.cmd) == selectionIdentifier
        }) else {
            return false
        }

        return Self.macroDuration(for: lastMatchingItem.cmd) != nil
    }

    private func functionalButtonOption(for cmd: String) -> FunctionalButtonOption? {
        functionalButtonOptions.first(where: { $0.cmd == cmd })
    }

    private func shortcutLibraryOption(for cmd: String) -> FunctionalButtonOption? {
        shortcutLibraryOptions.first(where: { $0.cmd == cmd })
    }

    private func localizedFunctionalButtonLabel(for option: FunctionalButtonOption) -> String {
        LocalizationHelper.localizedString(forKey: option.localizationKey)
    }

    private var occupiedSlots: Int {
        poolItems.reduce(0) { $0 + $1.span }
    }

    private var gyroOptions: [GyroButtonOption] {
        [
            GyroButtonOption(
                cmd: "GYRO",
                description: LocalizationHelper.localizedString(forKey: "Gyro on while activated")
            ),
            GyroButtonOption(
                cmd: "GYROPAUSE",
                description: LocalizationHelper.localizedString(forKey: "Gyro off while activated")
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

    private func handleShortcutLibrarySelection(_ option: FunctionalButtonOption) {
        guard canSelectCommand(option.cmd, source: .shortcuts) else { return }
        appendCommand(option.cmd, source: .shortcuts)
    }

    private func handleShortcutLibraryDeselection(_ option: FunctionalButtonOption) {
        removeCommand(option.cmd, source: .shortcuts)
    }

    private var createWidgetSheet: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let contentSpacing: CGFloat = isPhone ? 10 : 16
        let sectionSpacing: CGFloat = isPhone ? 7 : 10
        let fieldHeight: CGFloat = isPhone ? 30 : 38
        let segmentedControlHeight: CGFloat = isPhone ? 36 : 38
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    if targetWidgetKind == .button {
                        if showsButtonLabelField {
                            createWidgetSection(title: LocalizationHelper.localizedString(forKey: "Button label")) {
                                InteractiveTextField(
                                    placeholder: LocalizationHelper.localizedString(forKey: "Enter label(optional)"),
                                    text: $widgetButtonLabel
                                )
                                .frame(height: fieldHeight)
                            }
                            .zIndex(40)
                        }

                        if showsComboModeControl {
                            createInteractiveControlSection(
                                title: LocalizationHelper.localizedString(forKey: "Combination mode"),
                                controlHeight: segmentedControlHeight
                            ) {
                                Picker("", selection: widgetComboModeBinding) {
                                    ForEach(WidgetCreateComboMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .sheetSegmentedControlStyle(height: segmentedControlHeight)
                                .disabled(isComboModeLocked)
                                .opacity(isComboModeLocked ? 0.45 : 1.0)
                            }
                            .zIndex(30)
                        }

                        if showsShortcutButtonModeControl {
                            createInteractiveControlSection(
                                title: LocalizationHelper.localizedString(forKey: "Button mode"),
                                controlHeight: segmentedControlHeight
                            ) {
                                Picker("", selection: $shortcutPickerButtonMode) {
                                    ForEach(ShortcutPickerButtonMode.allCases) { mode in
                                        Text(mode.title).tag(mode)
                                    }
                                }
                                .sheetSegmentedControlStyle(height: segmentedControlHeight)
                            }
                        }
                    }

                    if showsIntervalSlider {
                        createInteractiveControlSection(
                            title: "\(LocalizationHelper.localizedString(forKey: "Trigger interval")): \(effectiveTriggerIntervalValue) ms",
                            controlHeight: fieldHeight
                        ) {
                            Slider(
                                value: $widgetTriggerInterval,
                                in: 0...2000,
                                step: 1
                            )
                            .environment(\.colorScheme, .light)
                                .frame(height: fieldHeight)
                                .disabled(isShortcutMode)
                                .opacity(isShortcutMode ? 0.45 : 1.0)
                        }
                        .zIndex(20)
                    }

                    if targetWidgetKind == .button, showsShapeControl {
                        createInteractiveControlSection(
                            title: LocalizationHelper.localizedString(forKey: "Shape"),
                            controlHeight: segmentedControlHeight
                        ) {
                            Picker("", selection: $widgetShape) {
                                ForEach(WidgetCreateShape.allCases) { shape in
                                    Text(shape.title).tag(shape)
                                }
                            }
                            .sheetSegmentedControlStyle(height: segmentedControlHeight)
                        }
                        .zIndex(10)
                    }
                }

                HStack(spacing: actionSpacing) {
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Cancel"),
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
                .zIndex(0)
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
        .widgetPickerIgnoreKeyboardSafeAreaWhenAvailable()
    }

    private var buttonMacroSheet: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let contentSpacing: CGFloat = isPhone ? 10 : 16
        let sectionSpacing: CGFloat = isPhone ? 7 : 10
        let fieldHeight: CGFloat = isPhone ? 30 : 38
        let segmentedControlHeight: CGFloat = isPhone ? 36 : 38
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: sectionSpacing) {

                    if true {
                        createInteractiveControlSection(
                            title: LocalizationHelper.localizedString(forKey: "Action mode"),
                            controlHeight: segmentedControlHeight
                        ) {
                            Picker("", selection: buttonMacroModeSelectionBinding) {
                                ForEach(WidgetButtonMacroMode.allCases) { mode in
                                    Text(mode.title).tag(mode.rawValue)
                                }
                            }
                            .sheetSegmentedControlStyle(height: segmentedControlHeight)
                        }
                        .zIndex(30)
                    }

                    if true {
                        createInteractiveControlSection(
                            title: buttonMacroDurationTitleText,
                            controlHeight: fieldHeight
                        ) {
                            Slider(
                                value: $buttonMacroDuration,
                                in: buttonMacroMinimumDuration...buttonMacroMaximumDuration,
                                step: 1
                            )
                            .environment(\.colorScheme, .light)
                            .frame(height: fieldHeight)
                            .disabled(buttonMacroMode != .timedRelease || manualButtonMacroDurationValue != nil)
                            .opacity((buttonMacroMode == .timedRelease && manualButtonMacroDurationValue == nil) ? 1.0 : 0.45)
                        }
                        .zIndex(20)
                    }
                    
                    if true {
                        createWidgetSection(title: LocalizationHelper.localizedString(forKey: "Manually enter press duration in milliseconds")) {
                            InteractiveTextField(
                                placeholder: LocalizationHelper.localizedString(forKey: ""),
                                text: $buttonMacroManualDurationText,
                                isEnabled: buttonMacroMode == .timedRelease
                            )
                            .frame(height: fieldHeight)
                        }
                        .zIndex(40)
                    }
                }

                HStack(spacing: actionSpacing) {
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Cancel"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        dismissButtonMacroSheet()
                    }

                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Remove"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        removeEditingButtonMacroItem()
                    }

                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Confirm"),
                        isPrimary: true,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        applyButtonMacroChanges()
                    }
                }
                .padding(.top, isPhone ? 2 : 0)
                .zIndex(0)
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
        // .widgetPickerIgnoreKeyboardSafeAreaWhenAvailable()
    }
    
    private var triggerIntervalSheet: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let contentSpacing: CGFloat = isPhone ? 10 : 16
        let sectionSpacing: CGFloat = isPhone ? 7 : 10
        let fieldHeight: CGFloat = isPhone ? 30 : 38
        let segmentedControlHeight: CGFloat = isPhone ? 36 : 38
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                VStack(alignment: .leading, spacing: sectionSpacing) {
                    createInteractiveControlSection(
                        title: "",
                        controlHeight: segmentedControlHeight
                    ) {
                        Picker("", selection: triggerIntervalEditModeBinding) {
                            ForEach(TriggerIntervalEditMode.allCases) { mode in
                                Text(mode.title).tag(mode.rawValue)
                            }
                        }
                        .sheetSegmentedControlStyle(height: segmentedControlHeight)
                    }
                    .zIndex(30)

                    createInteractiveControlSection(
                        title: triggerIntervalTitleText,
                        controlHeight: fieldHeight
                    ) {
                        Slider(
                            value: $triggerIntervalEditorValue,
                            in: triggerIntervalMinimumDuration...triggerIntervalMaximumDuration,
                            step: 1
                        )
                        .environment(\.colorScheme, .light)
                        .frame(height: fieldHeight)
                        .disabled(manualTriggerIntervalValue != nil)
                        .opacity(manualTriggerIntervalValue == nil ? 1.0 : 0.45)
                    }
                    .zIndex(20)
                    
                    createWidgetSection(title: LocalizationHelper.localizedString(forKey: "Manually enter trigger interval in milliseconds")) {
                        InteractiveTextField(
                            placeholder: "",
                            text: $triggerIntervalManualValueText
                        )
                        .frame(height: fieldHeight)
                    }
                    .zIndex(40)
                }

                HStack(spacing: actionSpacing) {
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Cancel"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        dismissTriggerIntervalSheet()
                    }

                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Confirm"),
                        isPrimary: true,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        applyTriggerIntervalChanges()
                    }
                }
                .padding(.top, isPhone ? 2 : 0)
                .zIndex(0)
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
        // .widgetPickerIgnoreKeyboardSafeAreaWhenAvailable()
    }


    /*
    private var buttonMacroSheet: some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let contentSpacing: CGFloat = isPhone ? 10 : 16
        let segmentedControlHeight: CGFloat = isPhone ? 36 : 38
        let sliderHeight: CGFloat = isPhone ? 30 : 38
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

            VStack(alignment: .leading, spacing: contentSpacing) {
                createInteractiveControlSection(
                    title: LocalizationHelper.localizedString(forKey: "Action mode"),
                    controlHeight: segmentedControlHeight
                ) {
                    Picker("", selection: buttonMacroModeSelectionBinding) {
                        ForEach(WidgetButtonMacroMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .sheetSegmentedControlStyle(height: segmentedControlHeight)
                }

                createInteractiveControlSection(
                    title: buttonMacroDurationTitleText,
                    controlHeight: sliderHeight
                ) {
                    Slider(
                        value: $buttonMacroDuration,
                        in: buttonMacroMinimumDuration...buttonMacroMaximumDuration,
                        step: 1
                    )
                    .environment(\.colorScheme, .light)
                    .frame(height: sliderHeight)
                    .disabled(buttonMacroMode != .timedRelease || manualButtonMacroDurationValue != nil)
                    .opacity((buttonMacroMode == .timedRelease && manualButtonMacroDurationValue == nil) ? 1.0 : 0.45)
                }

                createInteractiveControlContainer(controlHeight: sliderHeight) {
                    InteractiveTextField(
                        placeholder: LocalizationHelper.localizedString(forKey: "Manually enter press duration in milliseconds"),
                        text: $buttonMacroManualDurationText,
                        isEnabled: buttonMacroMode == .timedRelease
                    )
                    .frame(height: sliderHeight)
                }

                HStack(spacing: actionSpacing) {
                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Cancel"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        dismissButtonMacroSheet()
                    }

                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Remove"),
                        isPrimary: false,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        removeEditingButtonMacroItem()
                    }

                    PoolActionChip(
                        title: LocalizationHelper.localizedString(forKey: "Confirm"),
                        isPrimary: true,
                        height: actionHeight,
                        fontSize: actionFontSize,
                        cornerRadius: 14
                    ) {
                        applyButtonMacroChanges()
                    }
                }
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
     */


    /*
    private func createInteractiveControlContainer<Content: View>(
        controlHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        createWidgetControlContainer(clipsContentToBounds: true) {
            content()
                .frame(height: controlHeight)
        }
    }
     */

    private func createInteractiveControlSection<Content: View>(
        title: String,
        controlHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        createWidgetSection(title: title, clipsContentToBounds: true) {
            content()
                .frame(height: controlHeight)
        }
    }

    private func createWidgetSection<Content: View>(
        title: String,
        clipsContentToBounds: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
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

            let sectionContent = content()
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

            if clipsContentToBounds {
                sectionContent
                    .clipShape(
                        RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                    )
                    .contentShape(
                        RoundedRectangle(cornerRadius: sectionCornerRadius, style: .continuous)
                    )
            } else {
                sectionContent
            }
        }
    }

    /*
    @ViewBuilder
    private func createWidgetControlContainer<Content: View>(
        clipsContentToBounds: Bool,
        sectionHorizontalPadding: CGFloat? = nil,
        sectionVerticalPadding: CGFloat? = nil,
        sectionCornerRadius: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        let horizontalPadding = sectionHorizontalPadding ?? (isPhone ? 9 : 12)
        let verticalPadding = sectionVerticalPadding ?? (isPhone ? 6 : 10)
        let cornerRadius = sectionCornerRadius ?? (isPhone ? 12 : 14)

        let sectionContent = content()
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.94), lineWidth: 1)
            )

        if clipsContentToBounds {
            sectionContent
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .contentShape(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            sectionContent
        }
    }
    */

    private var firstPoolItem: WidgetPoolItem? {
        poolItems.first(where: { !isTriggerIntervalItem($0) })
    }

    private var targetWidgetKind: WidgetCreateTargetKind {
        guard let firstPoolItem else { return .button }
        switch firstPoolItem.visualKind {
        case .gamepadPad, .keyboardPad:
            return .pad
        case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton, .triggerInterval:
            return .button
        }
    }

    private var firstPoolItemIsFromGamepad: Bool {
        firstPoolItem?.source == .gamepad
    }

    private var isFunctionalOnlySelection: Bool {
        firstPoolItem?.source == .functional || firstPoolItem?.source == .shortcuts
    }

    private var buttonCommandCount: Int {
        poolItems.filter { item in
            switch item.visualKind {
            case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton:
                return true
            case .gamepadPad, .keyboardPad, .triggerInterval:
                return false
            }
        }.count
    }

    private var hasPadCommand: Bool {
        poolItems.contains(where: isPad)
    }

    private var hasGamepadButtonCommand: Bool {
        poolItems.contains { $0.visualKind == .gamepadButton }
    }

    private var isShortcutMode: Bool {
        effectiveWidgetComboMode == .shortcut
    }

    private var selectedFunctionalButtonOption: FunctionalButtonOption? {
        guard let functionalItem = poolItems.first(where: { ($0.source == .functional || $0.source == .shortcuts) && !gyroCommands.contains($0.cmd) }) else {
            return nil
        }
        return functionalButtonOption(for: functionalItem.cmd) ?? shortcutLibraryOption(for: functionalItem.cmd)
    }

    private var forcedComboMode: WidgetCreateComboMode? {
        guard showsComboModeControl else { return nil }
        if hasTriggerIntervalSlots {
            return .skill
        }
        if targetWidgetKind == .button && (hasPadCommand || hasGamepadButtonCommand) {
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
        if isShortcutPickerMode { return false }
        guard targetWidgetKind == .button else { return false }
        if let selectedFunctionalButtonOption {
            return selectedFunctionalButtonOption.allowsSkillCombo || selectedFunctionalButtonOption.allowsShortcutCombo
        }
        return !isFunctionalOnlySelection
    }

    private var showsShapeControl: Bool {
        if isShortcutPickerMode { return false }
        return targetWidgetKind == .button
    }

    private var showsButtonLabelField: Bool {
        if isShortcutPickerMode { return shortcutPickerNeedAlias }
        return targetWidgetKind == .button
    }

    private var showsShortcutButtonModeControl: Bool {
        isShortcutPickerMode && shortcutPickerNeedButtonMode && targetWidgetKind == .button
    }

    private var showsIntervalSlider: Bool {
        if isShortcutPickerMode { return false }
        if hasTriggerIntervalSlots { return false }
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

    private var isShortcutPickerMode: Bool {
        keyboardPickerMode == .shortcutPicker
    }

    private var containsMovementDirectionPad: Bool {
        poolItems.contains {
            let command = Self.selectionIdentifier(for: $0.cmd)
            return command == "WASDPAD" || command == "ARROWPAD"
        }
    }

    private var shouldBypassCreateWidgetSheet: Bool {
        if isShortcutPickerMode {
            // return true
        }

        if containsMovementDirectionPad {
            return true
        }

        guard !poolItems.isEmpty else { return false }

        let hasVisibleConfigurationSection =
            showsButtonLabelField ||
            showsShortcutButtonModeControl ||
            showsComboModeControl ||
            showsIntervalSlider ||
            showsShapeControl
        return !hasVisibleConfigurationSection
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
        shortcutPickerButtonMode = shortcutPickerNeedsTapToToggle(initialCmdString) ? .tapToToggle : .normal
        if isEditMode,
           submissionAction == .modify,
           let initialButtonLabel,
           targetWidgetKind == .button {
            widgetButtonLabel = initialButtonLabel
        } else if targetWidgetKind == .button,
                  let selectedFunctionalButtonOption {
            widgetButtonLabel = localizedFunctionalButtonLabel(for: selectedFunctionalButtonOption)
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
        guard isShortcutPickerMode || !poolItems.isEmpty else {
            setTipMessage(LocalizationHelper.localizedString(forKey: "Select at least one command before creating a widget"), type: .error)
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
        persistCurrentTabSelection()
        lastCreatedWidgetPayload = payload
        setTipMessage(LocalizationHelper.localizedString(forKey: "Widget config generated"))
        onWidgetCreated?(payload)
        print("widgetPicker payload =", payload as NSDictionary)
        setCreateWidgetSheetVisible(false)
    }

    private func makeWidgetPayload() -> [String: String] {
        [
            "cmdString": buildCmdString(),
            "buttonLabel": targetWidgetKind == .button ? resolvedWidgetButtonLabel() : "",
            "shape": targetWidgetKind == .button ? widgetShape.rawValue : "",
            "pickerAction": pendingSubmissionAction.payloadValue,
            "shortcutIdentifier": shortcutIdentifier ?? ""
        ]
    }

    private func buildCmdString() -> String {
        if isShortcutPickerMode {
            var cmdString = poolItems.map(\.cmd).joined(separator: "+")
            if shortcutPickerButtonMode == .tapToToggle, !cmdString.isEmpty {
                cmdString += "+NULL"
            }
            return cmdString
        }

        let joiner = comboJoiner
        if hasTriggerIntervalSlots {
            let intervalValues = triggerIntervalItems.compactMap { Self.triggerIntervalMilliseconds(for: $0.cmd) }
            let nonIntervalCommands = poolItems.filter { !isTriggerIntervalItem($0) }.map(\.cmd)
            guard !nonIntervalCommands.isEmpty else { return "" }

            if intervalValues.allSatisfy({ $0 == 0 }) {
                return (comboJoiner == "+" && nonIntervalCommands.count == 1)
                    ? "\(nonIntervalCommands[0])+"
                    : nonIntervalCommands.joined(separator: joiner)
            }

            if let firstInterval = intervalValues.first,
               firstInterval > 0,
               intervalValues.allSatisfy({ $0 == firstInterval }) {
                var cmdString = (comboJoiner == "+" && nonIntervalCommands.count == 1)
                    ? "\(nonIntervalCommands[0])+"
                    : nonIntervalCommands.joined(separator: joiner)
                cmdString += "-\(firstInterval)MS"
                return cmdString
            }

            let inlineTokens = poolItems.compactMap { item -> String? in
                if isTriggerIntervalItem(item) {
                    guard let milliseconds = Self.triggerIntervalMilliseconds(for: item.cmd), milliseconds > 0 else {
                        return nil
                    }
                    return "\(milliseconds)MS"
                }
                return item.cmd
            }
            return inlineTokens.joined(separator: joiner)
        }

        let payloadCommands = poolItems.map(\.cmd)
        guard !payloadCommands.isEmpty else { return "" }
        var cmdString = (comboJoiner == "+" && payloadCommands.count == 1) ? "\(payloadCommands[0])+" : payloadCommands.joined(separator: joiner)

        let shouldAppendInterval = effectiveWidgetComboMode != .shortcut
            && effectiveTriggerIntervalValue != 0
            && (hasPadCommand || effectiveWidgetComboMode == .skill)
        if shouldAppendInterval {
            cmdString += "-\(effectiveTriggerIntervalValue)MS"
        }

        return cmdString
    }

    private func resolvedWidgetButtonLabel() -> String {
        let trimmedManualLabel = widgetButtonLabel
        if !trimmedManualLabel.isEmpty {
            if let selectedFunctionalButtonOption,
               trimmedManualLabel == localizedFunctionalButtonLabel(for: selectedFunctionalButtonOption) {
                return selectedFunctionalButtonOption.localizationKey
            }
            return trimmedManualLabel
        }
        return defaultWidgetButtonLabel()
    }

    private func defaultWidgetButtonLabel() -> String {
        if let selectedFunctionalButtonOption {
            return selectedFunctionalButtonOption.localizationKey
        }

        let labelParts = poolItems.compactMap(defaultLabelPart(for:))
        guard !labelParts.isEmpty else { return "" }
        return sanitizedAutoButtonLabel(labelParts.joined(separator: comboJoiner))
    }

    private func sanitizedAutoButtonLabel(_ value: String) -> String {
        value.components(separatedBy: .whitespacesAndNewlines).joined()
    }

    private func defaultLabelPart(for item: WidgetPoolItem) -> String? {
        if isTriggerIntervalItem(item) {
            return nil
        }
        if let displayText = item.displayText?.trimmingCharacters(in: .whitespacesAndNewlines), !displayText.isEmpty {
            return sanitizedAutoButtonLabel(displayText)
        }
        switch item.source {
        case .gamepad:
            return sanitizedAutoButtonLabel(item.displayCmd)
        case .keyboard:
            let label = (item.displayText ?? item.cmd).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { return nil }
            if let firstCharacter = label.first, firstCharacter.isNumber {
                return String(firstCharacter)
            }
            return sanitizedAutoButtonLabel(label)
        case .functional:
            if let option = functionalButtonOption(for: item.cmd) {
                return option.localizationKey
            }
            let label = item.displayCmd.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? nil : sanitizedAutoButtonLabel(label)
        case .shortcuts:
            if let option = shortcutLibraryOption(for: item.cmd) {
                return option.localizationKey
            }
            let label = item.displayCmd.trimmingCharacters(in: .whitespacesAndNewlines)
            return label.isEmpty ? nil : sanitizedAutoButtonLabel(label)
        case .interval:
            return nil
        }
    }

    private var comboJoiner: String {
        (isShortcutPickerMode || effectiveWidgetComboMode == .shortcut)
        && selectedFunctionalButtonOption?.allowsShortcutCombo != false ? "+" : "-"
    }

    private func setCreateWidgetSheetVisible(_ isVisible: Bool) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            showCreateWidgetSheet = isVisible
        }
    }

    private func persistCurrentTabSelection() {
        UserDefaults.standard.set(selectedTab.persistenceIdentifier, forKey: Self.lastSelectedTabDefaultsKey)
    }

    private func handleCloseRequested() {
        persistCurrentTabSelection()
        onCloseRequested?()
    }

    private func applyInitialConfigurationIfNeeded() {
        guard !didApplyInitialConfiguration else { return }
        didApplyInitialConfiguration = true
        guard let initialCmdString, !initialCmdString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        let parsedCommands = parseCommands(from: initialCmdString)
        guard !parsedCommands.isEmpty else { return }

        selectedCmds = parsedCommands
            .filter { $0.source != .interval }
            .map { Self.selectionIdentifier(for: $0.cmd) }
        poolItems = parsedCommands.map { descriptor in
            WidgetPoolItem(
                cmd: descriptor.cmd,
                source: descriptor.source,
                visualKind: visualKind(for: descriptor.cmd, source: descriptor.source),
                staysAtTail: descriptor.isTailLocked,
                displayText: descriptor.displayText
            )
        }
        normalizeLeadingFunctionalItemPriorityIfNeeded()
        selectedGyroCommand = parsedCommands.first(where: { gyroCommands.contains($0.cmd) })?.cmd

        if let preferredTab = parsedCommands.first(where: {
            $0.source != .interval && ($0.source != .functional || !gyroCommands.contains($0.cmd))
        })?.source {
            switch preferredTab {
            case .gamepad:
                selectedTab = .gamepad
            case .keyboard:
                selectedTab = .keyboard
            case .functional:
                selectedTab = .functional
            case .shortcuts:
                selectedTab = .shortcuts
            case .interval:
                break
            }
        } else if parsedCommands.contains(where: { $0.source == .functional }) {
            selectedTab = .functional
        } else if parsedCommands.contains(where: { $0.source == .shortcuts }) {
            selectedTab = .shortcuts
        }

        updateTipMessageForCurrentPoolState()
    }

    private func parseCommands(from cmdString: String) -> [(cmd: String, source: WidgetPoolSource, isTailLocked: Bool, displayText: String?)] {
        let normalized = cmdString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        guard !normalized.isEmpty else { return [] }

        if isShortcutPickerMode, shortcutLibraryCommands.contains(normalized) {
            return [(cmd: normalized, source: .shortcuts, isTailLocked: false, displayText: macroDisplayText(for: normalized, source: .shortcuts))]
        }

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

        if isShortcutPickerMode, commands.last == "NULL" {
            commands.removeLast()
        }

        var parsed: [(cmd: String, source: WidgetPoolSource, isTailLocked: Bool, displayText: String?)] = []
        var trailingUniformInterval: Int? = nil
        if let last = commands.last,
           let trailingInterval = Self.triggerIntervalMilliseconds(for: last) {
            trailingUniformInterval = trailingInterval
            commands.removeLast()
        }

        for rawCommand in commands where !rawCommand.isEmpty {
            if let intervalValue = Self.triggerIntervalMilliseconds(for: rawCommand) {
                parsed.append((cmd: Self.makeTriggerIntervalCommand(milliseconds: intervalValue), source: .interval, isTailLocked: false, displayText: nil))
                continue
            }

            let canonicalCommand = canonicalCommand(for: rawCommand)
            let selectionIdentifier = Self.selectionIdentifier(for: canonicalCommand)
            guard let source = source(for: selectionIdentifier) else { continue }
            let displayText = macroDisplayText(for: canonicalCommand, source: source)

            let item = WidgetPoolItem(
                cmd: canonicalCommand,
                source: source,
                visualKind: visualKind(for: selectionIdentifier, source: source),
                staysAtTail: false,
                displayText: displayText
            )
            let isTailLocked = parsed.isEmpty ? false : isCombinableNonDirectionPad(item)
            parsed.append((cmd: canonicalCommand, source: source, isTailLocked: isTailLocked, displayText: displayText))
        }

        if let trailingUniformInterval {
            var rebuilt: [(cmd: String, source: WidgetPoolSource, isTailLocked: Bool, displayText: String?)] = []
            let buttonDescriptorCount = parsed.filter { descriptor in
                let visualKind = visualKind(for: descriptor.cmd, source: descriptor.source)
                switch visualKind {
                case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton:
                    return true
                case .gamepadPad, .keyboardPad, .triggerInterval:
                    return false
                }
            }.count
            var remainingButtons = buttonDescriptorCount

            for descriptor in parsed {
                rebuilt.append(descriptor)
                let visualKind = visualKind(for: descriptor.cmd, source: descriptor.source)
                switch visualKind {
                case .gamepadButton, .keyboardButton, .functionalButton, .shortcutButton:
                    remainingButtons -= 1
                    if remainingButtons > 0 {
                        rebuilt.append((cmd: Self.makeTriggerIntervalCommand(milliseconds: trailingUniformInterval), source: .interval, isTailLocked: false, displayText: nil))
                    }
                case .gamepadPad, .keyboardPad, .triggerInterval:
                    break
                }
            }
            return rebuilt
        }

        return parsed
    }

    private func shortcutPickerNeedsTapToToggle(_ cmdString: String?) -> Bool {
        guard isShortcutPickerMode,
              let normalized = cmdString?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased(),
              !normalized.isEmpty else {
            return false
        }

        return normalized.split(separator: "+").last == "NULL"
    }

    private func source(for cmd: String) -> WidgetPoolSource? {
        if Self.triggerIntervalMilliseconds(for: cmd) != nil {
            return .interval
        }
        if gamepadCommands.contains(cmd) {
            return .gamepad
        }
        if isShortcutPickerMode, shortcutLibraryCommands.contains(cmd) {
            return .shortcuts
        }
        if functionalCommands.contains(cmd) {
            return .functional
        }
        return .keyboard
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

    private func macroDisplayText(for cmd: String, source: WidgetPoolSource) -> String? {
        let selectionIdentifier = Self.selectionIdentifier(for: cmd)
        let baseLabel = baseDisplayText(for: selectionIdentifier, source: source)
        guard let duration = Self.macroDuration(for: cmd) else {
            return source == .keyboard ? baseLabel : (baseLabel == selectionIdentifier ? nil : baseLabel)
        }

        let format = duration == Int(buttonMacroMinimumDuration)
            ? LocalizationHelper.localizedString(forKey: "tap")
            : LocalizationHelper.localizedString(forKey: "↓%dms", duration)
        let suffix = duration == Int(buttonMacroMinimumDuration)
            ? format
            : String(format: format, duration)
        return "\(baseLabel)\n\(suffix)"
    }

    private func baseDisplayText(for cmd: String, source: WidgetPoolSource) -> String {
        switch source {
        case .gamepad:
            if cmd.hasPrefix("OSC") {
                return String(cmd.dropFirst(3))
            }
            return cmd
        case .keyboard:
            return cmd
        case .functional:
            if let option = functionalButtonOption(for: cmd) {
                return localizedFunctionalButtonLabel(for: option)
            }
            return cmd
        case .shortcuts:
            if let option = shortcutLibraryOption(for: cmd) {
                return localizedFunctionalButtonLabel(for: option)
            }
            return cmd
        case .interval:
            return Self.intervalDisplayText(for: cmd)
        }
    }

    static func selectionIdentifier(for cmd: String) -> String {
        guard let duration = macroDuration(for: cmd), duration > 0 else { return cmd }
        let suffix = ".\(duration)"
        guard cmd.hasSuffix(suffix) else { return cmd }
        return String(cmd.dropLast(suffix.count))
    }

    static func macroDuration(for cmd: String) -> Int? {
        guard let dotIndex = cmd.lastIndex(of: ".") else { return nil }
        let suffixStart = cmd.index(after: dotIndex)
        guard suffixStart < cmd.endIndex else { return nil }
        let suffix = cmd[suffixStart...]
        guard suffix.allSatisfy(\.isNumber), let duration = Int(suffix) else { return nil }
        return duration
    }

    static func triggerIntervalMilliseconds(for cmd: String) -> Int? {
        let normalized = cmd.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard normalized.hasSuffix("MS") else { return nil }
        let numericPart = normalized.dropLast(2)
        guard !numericPart.isEmpty,
              numericPart.allSatisfy(\.isNumber),
              let milliseconds = Int(numericPart) else {
            return nil
        }
        return milliseconds
    }

    static func makeTriggerIntervalCommand(milliseconds: Int) -> String {
        "\(milliseconds)MS"
    }

    static func intervalDisplayText(for cmd: String) -> String {
        guard let milliseconds = triggerIntervalMilliseconds(for: cmd) else { return cmd.lowercased() }
        return "\(milliseconds)ms"
    }

    private var gamepadCommands: Set<String> {
        [
            "OSCA", "OSCB", "OSCX", "OSCY",
            "OSCSELECT", "OSCSTART", "OSCHOME",
            "HOME",
            "DPAD",
            "OSCUP", "OSCDOWN", "OSCLEFT", "OSCRIGHT",
            "LS", "LSWHEEL", "LSPAD", "LSVPAD",
            "RS", "RSPAD", "RSVPAD", "RSWHEEL",
            "LB", "RB",
            "LT", "LTPAD",
            "RT", "RTPAD",
            "DS4TOUCH", "DS4TCHBTN"
        ]
    }

    private var functionalCommands: Set<String> {
        Set(functionalButtonOptions.map(\.cmd)).union(gyroCommands)
    }

    private var shortcutLibraryCommands: Set<String> {
        Set(shortcutLibraryOptions.map(\.cmd))
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
            Text(LocalizationHelper.localizedString(forKey: item.localizationKey))
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
private extension View {
    func sheetSegmentedControlStyle(height: CGFloat) -> some View {
        self
            .pickerStyle(SegmentedPickerStyle())
            .environment(\.colorScheme, .light)
            .frame(height: height)
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
                Text(LocalizationHelper.localizedString(forKey: "Select Gyro Button"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(LocalizationHelper.localizedString(forKey: "Choose a gyro control style"))
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
                    Text(LocalizationHelper.localizedString(forKey: "Cancel"))
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
    let scrollTargetItemID: UUID?
    let scrollRequestToken: Int

    private let columns = 4
    private let visibleRows = 4
    @SwiftUI.State private var lastHandledScrollRequestToken: Int = -1

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let availableSide = max(min(width, height) - contentInset * 2, 1)
            let cellSize = (availableSide - CGFloat(columns - 1) * spacing) / CGFloat(columns)
            let placements = makePlacements(for: items, columns: columns)
            let totalRows = max(visibleRows, (placements.map(\.row).max() ?? -1) + 1)
            let gridWidth = cellSize * CGFloat(columns) + spacing * CGFloat(columns - 1)
            let viewportGridHeight = cellSize * CGFloat(visibleRows) + spacing * CGFloat(visibleRows - 1)
            let contentGridHeight = cellSize * CGFloat(totalRows) + spacing * CGFloat(max(totalRows - 1, 0))
            let viewportHeight = viewportGridHeight + contentInset * 2
            let contentHeight = contentGridHeight + contentInset * 2
            let gridOriginX = (width - gridWidth) * 0.5

            ZStack {
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
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .onTapGesture {
                        NSLog("WidgetPickerView pool grid background tapped")
                    }

                Group {
                    if #available(iOS 14.0, *) {
                        poolScrollViewWithAutoScroll(
                            width: width,
                            cellSize: cellSize,
                            contentHeight: contentHeight,
                            contentInset: contentInset,
                            totalRows: totalRows,
                            gridOriginX: gridOriginX,
                            placements: placements,
                            showsIndicators: totalRows > visibleRows
                        )
                    } else {
                        ScrollView(.vertical, showsIndicators: totalRows > visibleRows) {
                            poolGridContent(
                                width: width,
                                cellSize: cellSize,
                                contentHeight: contentHeight,
                                contentInset: contentInset,
                                totalRows: totalRows,
                                gridOriginX: gridOriginX,
                                placements: placements
                            )
                        }
                    }
                }
                .frame(height: viewportHeight)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .frame(height: viewportHeight)
        }
    }

    @available(iOS 14.0, *)
    private func poolScrollViewWithAutoScroll(
        width: CGFloat,
        cellSize: CGFloat,
        contentHeight: CGFloat,
        contentInset: CGFloat,
        totalRows: Int,
        gridOriginX: CGFloat,
        placements: [WidgetPoolPlacement],
        showsIndicators: Bool
    ) -> some View {
        ScrollViewReader { scrollProxy in
            ScrollView(.vertical, showsIndicators: showsIndicators) {
                poolGridContent(
                    width: width,
                    cellSize: cellSize,
                    contentHeight: contentHeight,
                    contentInset: contentInset,
                    totalRows: totalRows,
                    gridOriginX: gridOriginX,
                    placements: placements
                )
            }
            .onReceive(Just(scrollRequestToken)) { requestToken in
                guard requestToken != lastHandledScrollRequestToken else { return }
                lastHandledScrollRequestToken = requestToken
                guard let scrollTargetItemID else { return }
                DispatchQueue.main.async {
                    scrollProxy.scrollTo(scrollTargetItemID, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private func poolGridContent(
        width: CGFloat,
        cellSize: CGFloat,
        contentHeight: CGFloat,
        contentInset: CGFloat,
        totalRows: Int,
        gridOriginX: CGFloat,
        placements: [WidgetPoolPlacement]
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<columns, id: \.self) { column in
                ForEach(0..<totalRows, id: \.self) { row in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 5]))
                        )
                        .frame(width: cellSize, height: cellSize)
                        .position(
                            x: gridOriginX + CGFloat(column) * (cellSize + spacing) + cellSize * 0.5,
                            y: contentInset + CGFloat(row) * (cellSize + spacing) + cellSize * 0.5
                        )
                        .allowsHitTesting(false)
                }
            }

            ForEach(placements) { placement in
                poolItemView(for: placement.item, cellSize: cellSize)
                    .frame(
                        width: cellSize * CGFloat(placement.item.span) + spacing * CGFloat(placement.item.span - 1),
                        height: cellSize
                    )
                    .contentShape(Rectangle())
                    .id(placement.item.id)
                    .onTapGesture {
                        NSLog(
                            "WidgetPickerView pool item tapped cmd=%@ id=%@ row=%d column=%d span=%d",
                            placement.item.cmd,
                            placement.item.id.uuidString,
                            placement.row,
                            placement.column,
                            placement.item.span
                        )
                        onItemTap(placement.item)
                    }
                    .position(
                        x: gridOriginX + CGFloat(placement.column) * (cellSize + spacing)
                            + (cellSize * CGFloat(placement.item.span) + spacing * CGFloat(placement.item.span - 1)) * 0.5,
                        y: contentInset + CGFloat(placement.row) * (cellSize + spacing) + cellSize * 0.5
                    )
                    .zIndex(1)
            }
        }
        .frame(width: width, height: contentHeight, alignment: .topLeading)
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
                            .minimumScaleFactor(0.25)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 6)
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
                            .minimumScaleFactor(0.25)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
            } else if item.visualKind == .functionalButton || item.visualKind == .shortcutButton {
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
                            .multilineTextAlignment(.center)
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
                            .multilineTextAlignment(.center)
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
