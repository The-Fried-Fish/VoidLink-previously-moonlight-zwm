//
//  VirtualKeyboardView.swift
//  VoidLink
//
//  Created by True砖家 on 2026/3/25.
//  Copyright © 2026 True砖家 @ Bilibili. All rights reserved.
//

import SwiftUI
import Combine
import UIKit

@available(iOS 13.0, *)
enum KeyboardType {
    case win
    case mac
}

@available(iOS 13.0, *)
enum KeyRole {
    case normal
    case fn
    case keyboardSwitch
}

@available(iOS 13.0, *)
enum KeyVisualStyle {
    case standard
    case directionPad
}

@available(iOS 13.0, *)
enum KeyboardSelectionFamily: Hashable {
    case wasd
    case arrow
}

@available(iOS 13.0, *)
enum KeyboardSelectionState: Hashable {
    case none
    case single(String)
    case pad
}

@available(iOS 13.0, *)
struct KeyboardWidgetOption: Hashable {
    let command: String
    let description: String
    let highlightedLabels: [String]
    let family: KeyboardSelectionFamily
    let selectionState: KeyboardSelectionState
}

@available(iOS 13.0, *)
enum KeyHighlightStyle {
    case none
    case single
    case pad
}

@available(iOS 13.0, *)
public enum VirtualKeyboardMode {
    case picker
    case typing
    case shortcutPicker
}

@available(iOS 13.0, *)
struct Key: Identifiable {
    let id = UUID()
    let role: KeyRole
    let identity: String?
    let visualStyle: KeyVisualStyle
    let label: String
    let width: CGFloat
    let sfSymbolName: String?
    let winCmdString: String?
    let macCmdString: String?
    let winKeyCode: Int16?
    let macKeyCode: Int16?

    init(
        label: String,
        role: KeyRole = .normal,
        identity: String? = nil,
        visualStyle: KeyVisualStyle = .standard,
        width: CGFloat,
        sfSymbolName: String? = nil,
        winCmdString: String? = nil,
        macCmdString: String? = nil,
        winKeyCode: Int16? = nil,
        macKeyCode: Int16? = nil
    ) {
        self.label = label
        self.identity = identity
        self.width = width
        self.visualStyle = visualStyle
        self.sfSymbolName = sfSymbolName
        self.winCmdString = winCmdString
        self.macCmdString = macCmdString
        self.winKeyCode = winKeyCode
        self.macKeyCode = macKeyCode
        self.role = role
    }

    func cmdString(for keyboardType: KeyboardType) -> String? {
        switch keyboardType {
        case .win: return winCmdString
        case .mac: return macCmdString == nil ? winCmdString : macCmdString
        }
    }

    func keyCode(for keyboardType: KeyboardType) -> Int16? {
        switch keyboardType {
        case .win: return winKeyCode == nil ? 0xFF : winKeyCode
        case .mac: return macKeyCode == nil ? 0xFF : macKeyCode
        }
    }
}

@available(iOS 13.0, *)
struct Row: Identifiable {
    let id = UUID()
    let keys: [Key]
}

@available(iOS 13.0, *)
struct VirtualKeyboardView: View {
    let mode: VirtualKeyboardMode
    var canSelectCommand: ((String) -> Bool)? = nil
    var isCommandSelected: ((String) -> Bool)? = nil
    var onCommandSelected: ((String) -> Void)? = nil
    var onCommandDeselected: ((String) -> Void)? = nil
    var resetToken: Int = 0
    var selectionSyncToken: Int = 0
    var externalDeselectionCommand: String? = nil
    var externalDeselectionToken: Int = 0

    @SwiftUI.State private var fnMode = false
    @SwiftUI.State private var keyboardType: KeyboardType = .win
    @SwiftUI.State private var showsMouseWidgets: Bool
    @SwiftUI.State private var highlightedKeyIDs: Set<String> = []
    @SwiftUI.State private var directionSingleKeyLabels: Set<String> = []
    @SwiftUI.State private var padSelections: Set<KeyboardSelectionFamily> = []
    @SwiftUI.State private var pendingKeyboardOptions: [KeyboardWidgetOption] = []
    @SwiftUI.State private var pendingSelectionFamily: KeyboardSelectionFamily?
    @SwiftUI.State private var showKeyboardWidgetPicker = false
    @SwiftUI.State private var lastAppliedResetToken: Int = 0
    @SwiftUI.State private var lastAppliedSelectionSyncToken: Int = 0
    @SwiftUI.State private var lastAppliedExternalDeselectionToken: Int = 0
    
    let keyHeight: CGFloat = 36
    let spacing: CGFloat = 6
    let unit: CGFloat = 36 // 1u = 正方形边长

    static var tappedKeyLabels: [String] = []
    static var selectedCmd: String = ""
    static var lastSelectionDisplayText: String? = nil
    static var lastSelectionUsesMacLayout = false
    static var lastSelectionFromMouseWidgets = false
    static var lastSelectionUsesFnCommandDisplay = false

    init(
        mode: VirtualKeyboardMode = .typing,
        canSelectCommand: ((String) -> Bool)? = nil,
        isCommandSelected: ((String) -> Bool)? = nil,
        onCommandSelected: ((String) -> Void)? = nil,
        onCommandDeselected: ((String) -> Void)? = nil,
        resetToken: Int = 0,
        selectionSyncToken: Int = 0,
        externalDeselectionCommand: String? = nil,
        externalDeselectionToken: Int = 0
    ) {
        self.mode = mode
        self.canSelectCommand = canSelectCommand
        self.isCommandSelected = isCommandSelected
        self.onCommandSelected = onCommandSelected
        self.onCommandDeselected = onCommandDeselected
        self.resetToken = resetToken
        self.selectionSyncToken = selectionSyncToken
        self.externalDeselectionCommand = externalDeselectionCommand
        self.externalDeselectionToken = externalDeselectionToken
        _showsMouseWidgets = SwiftUI.State(initialValue: mode != .typing)
    }
    
    var body: some View {
        Group {
            if usesPickerLayout {
                GeometryReader { proxy in
                    let isPhone = UIDevice.current.userInterfaceIdiom == .phone
                    let horizontalInset: CGFloat = isPhone ? 6 : 12
                    let verticalInset: CGFloat = isPhone ? 6 : 12
                    let availableWidth = max(proxy.size.width - horizontalInset * 2, 1)
                    let availableHeight = max(proxy.size.height - verticalInset * 2, 1)
                    let scale = min(
                        availableWidth / pickerContentWidth,
                        availableHeight / pickerContentHeight,
                        1
                    )

                    ZStack {
                        Color.clear

                        pickerContent
                            .frame(width: pickerContentWidth, height: pickerContentHeight, alignment: .topLeading)
                            .scaleEffect(scale, anchor: .topLeading)
                            .frame(
                                width: pickerContentWidth * scale,
                                height: pickerContentHeight * scale,
                                alignment: .topLeading
                            )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, horizontalInset)
                    .padding(.vertical, verticalInset)
                }
            } else {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 20) {
                        mainBlock
                        navBlock
                        numpadBlock
                    }
                    .padding()
                }
            }
        }
        .overlay(
            Group {
                if showKeyboardWidgetPicker {
                    KeyboardWidgetPickerOverlay(
                        options: pendingKeyboardOptions,
                        onSelect: { option in
                            selectKeyboardWidget(option)
                        },
                        onReset: {
                            resetCurrentKeyboardWidgetSelection()
                        },
                        onCancel: {
                            showKeyboardWidgetPicker = false
                        }
                    )
                    .zIndex(999)
                }
            }
        )
        .onReceive(Just(resetToken)) { token in
            guard token != lastAppliedResetToken else { return }
            lastAppliedResetToken = token
            resetAllSelections()
        }
        .onReceive(Just(selectionSyncToken)) { token in
            guard token != lastAppliedSelectionSyncToken else { return }
            lastAppliedSelectionSyncToken = token
            synchronizeSelectionHighlights()
        }
        .onReceive(Just(externalDeselectionToken)) { token in
            guard token != lastAppliedExternalDeselectionToken else { return }
            lastAppliedExternalDeselectionToken = token
            if let command = externalDeselectionCommand, !command.isEmpty {
                deselectCommand(command)
            }
        }
        .onAppear {
            synchronizeSelectionHighlights()
        }
    }

    private var pickerContent: some View {
        VStack(alignment: .leading, spacing: pickerSectionSpacing) {
            mainBlock
            pickerBottomRow
        }
    }

    private var pickerBottomRow: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            navBlock
                .frame(width: navBlockWidth, alignment: .leading)
                .offset(x: equalBottomRowGap)

            numpadBlock
                .frame(width: numpadBlockWidth, alignment: .leading)
                .offset(x: equalBottomRowGap * 2 + navBlockWidth)
        }
        .frame(width: mainBlockWidth, height: totalHeight, alignment: .topLeading)
    }
    
    // MARK: - 主键区
    var mainBlock: some View {
        VStack(spacing: spacing) {
            ForEach(mainRows) { row in
                HStack(spacing: spacing) {
                    ForEach(row.keys) { key in
                        KeyView(
                            key: key,
                            height: keyHeight,
                            keyboardType: keyboardType,
                            mode: mode,
                            usesDirectionPadBaseStyle: usesDirectionPadBaseStyle,
                            isActive:
                                (key.role == .fn && fnMode)
                                || (key.role == .keyboardSwitch && keyboardType == .mac),
                            highlightStyle: highlightStyle(for: key),
                            action: {
                                handleKeyTap(key)
                            }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyboardKeyView(
        _ key: Key,
        height: CGFloat? = nil,
        isActive: Bool = false,
        customAction: (() -> Void)? = nil
    ) -> some View {
        KeyView(
            key: key,
            height: height ?? keyHeight,
            keyboardType: keyboardType,
            mode: mode,
            usesDirectionPadBaseStyle: usesDirectionPadBaseStyle,
            isActive: isActive,
            highlightStyle: highlightStyle(for: key),
            action: {
                if let customAction = customAction {
                    customAction()
                } else {
                    handleKeyTap(key)
                }
            }
        )
    }

    private func handleKeyTap(_ key: Key) {
        switch key.role {
        case .fn:
            fnMode.toggle()
        case .keyboardSwitch:
            keyboardType = keyboardType == .win ? .mac : .win
        case .normal:
            if usesPickerSelectionBehavior, let family = selectionFamily(for: key) {
                handleDirectionKeyTap(key, family: family)
            } else if usesPickerSelectionBehavior || isTypingToggleKey(key) {
                toggleRegularKeyHighlight(key)
            }
        }
    }

    private func isTypingToggleKey(_ key: Key) -> Bool {
        let normalizedLabel = key.label.lowercased()
        return normalizedLabel == "tab"
            || normalizedLabel == "shift"
            || normalizedLabel == "ctrl"
            || normalizedLabel == "alt"
            || normalizedLabel == "control"
            || normalizedLabel == "opt"
    }

    private func toggleRegularKeyHighlight(_ key: Key) {
        let keyID = regularHighlightID(for: key)
        
        if highlightedKeyIDs.contains(keyID) {
            highlightedKeyIDs.remove(keyID)
            if let cmd = key.cmdString(for: keyboardType), !cmd.isEmpty {
                onCommandDeselected?(cmd)
            }
            if VirtualKeyboardView.selectedCmd == key.cmdString(for: keyboardType) {
                VirtualKeyboardView.selectedCmd = ""
            }
        } else {
            let cmd = key.cmdString(for: keyboardType) ?? ""
            if !cmd.isEmpty, canSelectCommand?(cmd) == false {
                return
            }
            highlightedKeyIDs.insert(keyID)
            VirtualKeyboardView.tappedKeyLabels = [key.label]
            VirtualKeyboardView.selectedCmd = cmd
            VirtualKeyboardView.lastSelectionDisplayText = poolDisplayText(for: key)
            VirtualKeyboardView.lastSelectionUsesMacLayout = keyboardType == .mac
            VirtualKeyboardView.lastSelectionFromMouseWidgets = isMouseWidgetKey(key)
            VirtualKeyboardView.lastSelectionUsesFnCommandDisplay = usesFnCommandDisplay(for: key)
            if !VirtualKeyboardView.selectedCmd.isEmpty {
                onCommandSelected?(VirtualKeyboardView.selectedCmd)
            }
        }
    }

    private func handleDirectionKeyTap(_ key: Key, family: KeyboardSelectionFamily) {
        if padSelections.contains(family) {
            padSelections.remove(family)
            onCommandDeselected?(padCommand(for: family))
            if VirtualKeyboardView.selectedCmd == padCommand(for: family) {
                VirtualKeyboardView.selectedCmd = ""
            }
            if mode != .shortcutPicker {
                return
            }
        }

        if directionSingleKeyLabels.contains(key.label) {
            directionSingleKeyLabels.remove(key.label)
            if let cmd = key.cmdString(for: keyboardType), !cmd.isEmpty {
                onCommandDeselected?(cmd)
            }
            if VirtualKeyboardView.selectedCmd == key.cmdString(for: keyboardType) {
                VirtualKeyboardView.selectedCmd = ""
            }
            return
        }

        if mode == .shortcutPicker {
            let command = key.cmdString(for: keyboardType) ?? key.label
            if canSelectCommand?(command) == false {
                return
            }
            let option = KeyboardWidgetOption(
                command: command,
                description: singleKeyDescription(for: key, family: family),
                highlightedLabels: [key.label],
                family: family,
                selectionState: .single(key.label)
            )
            applySelection(option)
            VirtualKeyboardView.tappedKeyLabels = [key.label]
            VirtualKeyboardView.selectedCmd = command
            VirtualKeyboardView.lastSelectionDisplayText = poolDisplayText(for: option)
            VirtualKeyboardView.lastSelectionUsesMacLayout = keyboardType == .mac
            VirtualKeyboardView.lastSelectionFromMouseWidgets = false
            VirtualKeyboardView.lastSelectionUsesFnCommandDisplay = false
            onCommandSelected?(command)
            return
        }

        pendingSelectionFamily = family
        pendingKeyboardOptions = keyboardOptions(for: key, family: family)
        VirtualKeyboardView.tappedKeyLabels = [key.label]
        showKeyboardWidgetPicker = true
    }

    private func keyboardOptions(for key: Key, family: KeyboardSelectionFamily) -> [KeyboardWidgetOption] {
        let singleCommand = key.cmdString(for: keyboardType) ?? key.label
        let singleDescription = singleKeyDescription(for: key, family: family)

        switch family {
        case .wasd:
            return [
                KeyboardWidgetOption(
                    command: singleCommand,
                    description: singleDescription,
                    highlightedLabels: [key.label],
                    family: .wasd,
                    selectionState: .single(key.label)
                ),
                KeyboardWidgetOption(
                    command: "WASDPAD",
                    description: SwiftLocalizationHelper.localizedString(forKey: "WASD direction pad"),
                    highlightedLabels: ["W", "A", "S", "D"],
                    family: .wasd,
                    selectionState: .pad
                )
            ]
        case .arrow:
            return [
                KeyboardWidgetOption(
                    command: singleCommand,
                    description: singleDescription,
                    highlightedLabels: [key.label],
                    family: .arrow,
                    selectionState: .single(key.label)
                ),
                KeyboardWidgetOption(
                    command: "ARROWPAD",
                    description: SwiftLocalizationHelper.localizedString(forKey: "Arrow direction pad"),
                    highlightedLabels: ["↑", "↓", "←", "→"],
                    family: .arrow,
                    selectionState: .pad
                )
            ]
        }
    }

    private func singleKeyDescription(for key: Key, family: KeyboardSelectionFamily) -> String {
        switch family {
        case .wasd:
            return key.label
        case .arrow:
            switch key.label {
            case "↑": return SwiftLocalizationHelper.localizedString(forKey: "Up Arrow")
            case "↓": return SwiftLocalizationHelper.localizedString(forKey: "Down Arrow")
            case "←": return SwiftLocalizationHelper.localizedString(forKey: "Left Arrow")
            case "→": return SwiftLocalizationHelper.localizedString(forKey: "Right Arrow")
            default: return key.label
            }
        }
    }

    private func poolDisplayText(for key: Key) -> String {
        key.label
    }

    private func poolDisplayText(for option: KeyboardWidgetOption) -> String {
        switch option.family {
        case .wasd:
            if option.selectionState == .pad {
                return "WASD"
            }
        case .arrow:
            if option.selectionState == .pad {
                return "Arrows"
            }
        }
        return option.highlightedLabels.first ?? option.command
    }

    private func isMouseWidgetKey(_ key: Key) -> Bool {
        let mouseCommands: Set<String> = [
            "MLEFT", "MRIGHT", "MMIDDLE", "MX1", "MX2",
            "WHEELUP", "WHEELDOWN", "WHEEL", "MOUSEPAD", "TRACKBALL"
        ]
        if let command = key.cmdString(for: keyboardType) {
            return mouseCommands.contains(command)
        }
        return false
    }

    private func usesFnCommandDisplay(for key: Key) -> Bool {
        guard fnMode else { return false }
        let fnRowLabels: Set<String> = [
            "F1", "F2", "F3", "F4", "F5", "F6",
            "F7", "F8", "F9", "F10", "F11", "F12",
            "App1", "App2"
        ]
        return fnRowLabels.contains(key.label)
    }

    private func selectKeyboardWidget(_ option: KeyboardWidgetOption) {
        if canSelectCommand?(option.command) == false {
            showKeyboardWidgetPicker = false
            return
        }
        applySelection(option)
        VirtualKeyboardView.tappedKeyLabels = option.highlightedLabels
        VirtualKeyboardView.selectedCmd = option.command
        VirtualKeyboardView.lastSelectionDisplayText = poolDisplayText(for: option)
        VirtualKeyboardView.lastSelectionUsesMacLayout = keyboardType == .mac
        VirtualKeyboardView.lastSelectionFromMouseWidgets = false
        VirtualKeyboardView.lastSelectionUsesFnCommandDisplay = false
        onCommandSelected?(option.command)
        showKeyboardWidgetPicker = false
    }

    private func resetCurrentKeyboardWidgetSelection() {
        if let family = pendingSelectionFamily {
            notifyDeselection(for: family)
            clearSelection(for: family)
        }
        VirtualKeyboardView.tappedKeyLabels = []
        VirtualKeyboardView.selectedCmd = ""
        showKeyboardWidgetPicker = false
    }

    private func clearSelection(for family: KeyboardSelectionFamily) {
        directionSingleKeyLabels.subtract(labels(for: family))
        padSelections.remove(family)
    }

    private func selectionFamily(for key: Key) -> KeyboardSelectionFamily? {
        if ["W", "A", "S", "D"].contains(key.label) {
            return .wasd
        }

        if ["↑", "↓", "←", "→"].contains(key.label) {
            return .arrow
        }

        return nil
    }

    private func labels(for family: KeyboardSelectionFamily) -> [String] {
        switch family {
        case .wasd:
            return ["W", "A", "S", "D"]
        case .arrow:
            return ["↑", "↓", "←", "→"]
        }
    }
    
    private func padCommand(for family: KeyboardSelectionFamily) -> String {
        switch family {
        case .wasd:
            return "WASDPAD"
        case .arrow:
            return "ARROWPAD"
        }
    }
    
    private func applySelection(_ option: KeyboardWidgetOption) {
        switch option.selectionState {
        case .single(let label):
            padSelections.remove(option.family)
            directionSingleKeyLabels.insert(label)
        case .pad:
            directionSingleKeyLabels.subtract(labels(for: option.family))
            padSelections.insert(option.family)
        case .none:
            clearSelection(for: option.family)
        }
    }
    
    private func highlightStyle(for key: Key) -> KeyHighlightStyle {
        if usesPadSelectionHighlight, let family = selectionFamily(for: key), padSelections.contains(family) {
            return .pad
        }
        
        if highlightedKeyIDs.contains(regularHighlightID(for: key))
            || (usesPickerSelectionBehavior && directionSingleKeyLabels.contains(key.label)) {
            return isPadLikeControl(key) ? .pad : .single
        }
        
        return .none
    }

    private func regularHighlightID(for key: Key) -> String {
        if let identity = key.identity {
            return identity
        }
        let cmd = key.cmdString(for: keyboardType) ?? "NULL"
        let code = key.keyCode(for: keyboardType) ?? 0xFF
        return "\(key.label)|\(cmd)|\(code)"
    }

    private func isPadLikeControl(_ key: Key) -> Bool {
        let padCommands: Set<String> = ["WHEEL", "MOUSEPAD", "TRACKBALL"]
        if let cmd = key.cmdString(for: keyboardType) {
            return padCommands.contains(cmd)
        }
        return false
    }
    
    
    var mainRows: [Row] {
        [
            Row(keys: [
                Key(label: "Esc", width: unit, winCmdString: "ESC", macCmdString: "ESCAPEMAC", winKeyCode: 0x1B, macKeyCode: 0x35),

                Key(label: "F1", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "speaker.slash.fill" : "sun.min") : nil, winCmdString: fnMode ? "VOLMUTE" : "F1", macCmdString: fnMode ? "FUNCTION-F1MAC-50MS" : "F1MAC", winKeyCode: fnMode ? 0xAD : 0x70, macKeyCode: 0x7A),
                Key(label: "F2", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "speaker.wave.1.fill" : "sun.max") : nil, winCmdString: fnMode ? "VOLDOWN" : "F2", macCmdString: fnMode ? "FUNCTION-F2MAC-50MS" : "F2MAC", winKeyCode: fnMode ? 0xAE : 0x71, macKeyCode: 0x78),
                Key(label: "F3", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "speaker.wave.3.fill" : "rectangle.3.offgrid") : nil, winCmdString: fnMode ? "VOLUP" : "F3", macCmdString: fnMode ? "FUNCTION-F3MAC-50MS" : "F3MAC", winKeyCode: fnMode ? 0xAF : 0x72, macKeyCode: 0x63),
                Key(label: "F4", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "music.note" : "magnifyingglass") : nil, winCmdString: fnMode ? "MEDIA_SELECT" : "F4", macCmdString: fnMode ? "FUNCTION-F4MAC-50MS" : "F4MAC", winKeyCode: fnMode ? 0xB5 : 0x73, macKeyCode: 0x76),

                Key(label: "F5", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "backward.fill" : "mic") : nil, winCmdString: fnMode ? "MEDIAPREV" : "F5", macCmdString: fnMode ? "FUNCTION-F5MAC-50MS" : "F5MAC", winKeyCode: fnMode ? 0xB1 : 0x74, macKeyCode: 0x60),
                Key(label: "F6", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "playpause.fill" : "moon") : nil, winCmdString: fnMode ? "PLAYPAUSE" : "F6", macCmdString: fnMode ? "FUNCTION-F6MAC-50MS" : "F6MAC", winKeyCode: fnMode ? 0xB3 : 0x75, macKeyCode: 0x61),
                Key(label: "F7", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "forward.fill" : "backward.fill") : nil, winCmdString: fnMode ? "MEDIANEXT" : "F7", macCmdString: fnMode ? "FUNCTION-F7MAC-50MS" : "F7MAC", winKeyCode: fnMode ? 0xB0 : 0x76, macKeyCode: 0x62),
                Key(label: "F8", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "stop.fill" : "playpause.fill") : nil, winCmdString: fnMode ? "MEDIASTOP" : "F8", macCmdString: fnMode ? "FUNCTION-F8MAC-50MS" : "F8MAC", winKeyCode: fnMode ? 0xB2 : 0x77, macKeyCode: 0x64),

                Key(label: "F9", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? "envelope.fill" : "forward.fill") : nil, winCmdString: fnMode ? "LAUNCHMAIL" : "F9", macCmdString: fnMode ? "FUNCTION-F9MAC-50MS" : "F9MAC", winKeyCode: fnMode ? 0xB4 : 0x78, macKeyCode: 0x65),
                Key(label: fnMode ? "App1" : "F10", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? nil : "speaker.slash") : nil, winCmdString: fnMode ? "LAUNCHAPP1" : "F10", macCmdString: fnMode ? "FUNCTION-F10MAC-50MS" : "F10MAC", winKeyCode: fnMode ? 0xB6 : 0x79, macKeyCode: 0x6D),
                Key(label: fnMode ? "App2" : "F11", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? nil : "speaker.wave.1") : nil, winCmdString: fnMode ? "LAUNCHAPP2" : "F11", macCmdString: fnMode ? "FUNCTION-F11MAC-50MS" : "F11MAC", winKeyCode: fnMode ? 0xB7 : 0x7A, macKeyCode: 0x67),
                Key(label: "F12", width: unit, sfSymbolName: fnMode ? (keyboardType == .win ? nil : "speaker.wave.3") : nil, winCmdString: "F12", macCmdString: fnMode ? "FUNCTION-F12MAC-50MS" : "F12MAC", winKeyCode: 0x7B, macKeyCode: 0x6F),
                
                Key(label: "Null", width: unit, winCmdString: "NULL", macCmdString: "NULL", winKeyCode: 0xFF, macKeyCode: 0xFF),
            ]),
            Row(keys: [
                Key(label: "` ~", width: unit, winCmdString: "GRAVEACCENT", macCmdString: "GRAVEACCENTMAC", winKeyCode: 0xC0, macKeyCode: 0x32),
                Key(label: "1 !", width: unit, winCmdString: "1", macCmdString: "1MAC", winKeyCode: 0x31, macKeyCode: 0x53),
                Key(label: "2 @", width: unit, winCmdString: "2", macCmdString: "2MAC", winKeyCode: 0x32, macKeyCode: 0x54),
                Key(label: "3 #", width: unit, winCmdString: "3", macCmdString: "3MAC", winKeyCode: 0x33, macKeyCode: 0x55),
                Key(label: "4 $", width: unit, winCmdString: "4", macCmdString: "4MAC", winKeyCode: 0x34, macKeyCode: 0x56),
                Key(label: "5 %", width: unit, winCmdString: "5", macCmdString: "5MAC", winKeyCode: 0x35, macKeyCode: 0x57),
                Key(label: "6 ^", width: unit, winCmdString: "6", macCmdString: "6MAC", winKeyCode: 0x36, macKeyCode: 0x58),
                Key(label: "7 &", width: unit, winCmdString: "7", macCmdString: "7MAC", winKeyCode: 0x37, macKeyCode: 0x59),
                Key(label: "8 *", width: unit, winCmdString: "8", macCmdString: "8MAC", winKeyCode: 0x38, macKeyCode: 0x5A),
                Key(label: "9 (", width: unit, winCmdString: "9", macCmdString: "9MAC", winKeyCode: 0x39, macKeyCode: 0x5B),
                Key(label: "0 )", width: unit, winCmdString: "0", macCmdString: "0MAC", winKeyCode: 0x30, macKeyCode: 0x52),
                Key(label: "- _", width: unit, winCmdString: "MINUS", macCmdString: "MINUSMAC", winKeyCode: 0xBD, macKeyCode: 0x1B),
                Key(label: "= +", width: unit, winCmdString: "EQUALS", macCmdString: "EQUALSMAC", winKeyCode: 0xBB, macKeyCode: 0x18),
                Key(label: keyboardType == .win ? "Backspace" : "Delete", width: unit * 2, winCmdString: "BACKSPACE", macCmdString: "BACKSPACEMAC", winKeyCode: 0x08, macKeyCode: 0x33)
            ]),
            Row(keys: [
                Key(label: "Tab", width: unit * 1.5, winCmdString: "TAB", macCmdString: "TABMAC", winKeyCode: 0x09, macKeyCode: 0x30),
                Key(label: "Q", width: unit, winCmdString: "Q", macCmdString: "QMAC", winKeyCode: 0x51, macKeyCode: 0x0C),
                Key(label: "W", visualStyle: .directionPad, width: unit, winCmdString: "W", macCmdString: "WMAC", winKeyCode: 0x57, macKeyCode: 0x0D),
                Key(label: "E", width: unit, winCmdString: "E", macCmdString: "EMAC", winKeyCode: 0x45, macKeyCode: 0x0E),
                Key(label: "R", width: unit, winCmdString: "R", macCmdString: "RMAC", winKeyCode: 0x52, macKeyCode: 0x0F),
                Key(label: "T", width: unit, winCmdString: "T", macCmdString: "TMAC", winKeyCode: 0x54, macKeyCode: 0x11),
                Key(label: "Y", width: unit, winCmdString: "Y", macCmdString: "YMAC", winKeyCode: 0x59, macKeyCode: 0x10),
                Key(label: "U", width: unit, winCmdString: "U", macCmdString: "UMAC", winKeyCode: 0x55, macKeyCode: 0x20),
                Key(label: "I", width: unit, winCmdString: "I", macCmdString: "IMAC", winKeyCode: 0x49, macKeyCode: 0x22),
                Key(label: "O", width: unit, winCmdString: "O", macCmdString: "OMAC", winKeyCode: 0x4F, macKeyCode: 0x1F),
                Key(label: "P", width: unit, winCmdString: "P", macCmdString: "PMAC", winKeyCode: 0x50, macKeyCode: 0x23),
                Key(label: "[ {", width: unit, winCmdString: "OPENBRACKET", macCmdString: "OPENBRACKETMAC", winKeyCode: 0xDB, macKeyCode: 0x21),
                Key(label: "] }", width: unit, winCmdString: "CLOSEBRACKET", macCmdString: "CLOSEBRACKETMAC", winKeyCode: 0xDD, macKeyCode: 0x1E),
                Key(label: "\\ |", width: unit * 1.5, winCmdString: "BACKSLASH", macCmdString: "BACKSLASHMAC", winKeyCode: 0xDC, macKeyCode: 0x2A)
            ]),
            Row(keys: [
                Key(label: "Caps", width: unit * 1.75, winCmdString: "CAPSLOCK", macCmdString: "CAPSLOCKMAC", winKeyCode: 0x14, macKeyCode: 0x39),
                Key(label: "A", visualStyle: .directionPad, width: unit, winCmdString: "A", macCmdString: "AMAC", winKeyCode: 0x41, macKeyCode: 0x00),
                Key(label: "S", visualStyle: .directionPad, width: unit, winCmdString: "S", macCmdString: "SMAC", winKeyCode: 0x53, macKeyCode: 0x01),
                Key(label: "D", visualStyle: .directionPad, width: unit, winCmdString: "D", macCmdString: "DMAC", winKeyCode: 0x44, macKeyCode: 0x02),
                Key(label: "F", width: unit, winCmdString: "F", macCmdString: "FMAC", winKeyCode: 0x46, macKeyCode: 0x03),
                Key(label: "G", width: unit, winCmdString: "G", macCmdString: "GMAC", winKeyCode: 0x47, macKeyCode: 0x05),
                Key(label: "H", width: unit, winCmdString: "H", macCmdString: "HMAC", winKeyCode: 0x48, macKeyCode: 0x04),
                Key(label: "J", width: unit, winCmdString: "J", macCmdString: "JMAC", winKeyCode: 0x4A, macKeyCode: 0x26),
                Key(label: "K", width: unit, winCmdString: "K", macCmdString: "KMAC", winKeyCode: 0x4B, macKeyCode: 0x28),
                Key(label: "L", width: unit, winCmdString: "L", macCmdString: "LMAC", winKeyCode: 0x4C, macKeyCode: 0x25),
                Key(label: "; :", width: unit, winCmdString: "SEMICOLON", macCmdString: "SEMICOLONMAC", winKeyCode: 0xBA, macKeyCode: 0x29),
                Key(label: "' \"", width: unit, winCmdString: "SINGLEQUOTE", macCmdString: "SINGLEQUOTEMAC", winKeyCode: 0xDE, macKeyCode: 0x27),
                Key(label: keyboardType == .win ?  "Enter" : "Return", identity: "main-enter", width: unit * 2.25, winCmdString: "ENTER", macCmdString: "RETURNMAC", winKeyCode: 0x0D, macKeyCode: 0x24)
            ]),
            Row(keys: [
                Key(label: "Shift", identity: "left-shift", width: unit * 2.25, winCmdString: "SHIFT", macCmdString: "SHIFTMAC", winKeyCode: 0x10, macKeyCode: 0x38),
                Key(label: "Z", width: unit, winCmdString: "Z", macCmdString: "ZMAC", winKeyCode: 0x5A, macKeyCode: 0x06),
                Key(label: "X", width: unit, winCmdString: "X", macCmdString: "XMAC", winKeyCode: 0x58, macKeyCode: 0x07),
                Key(label: "C", width: unit, winCmdString: "C", macCmdString: "CMAC", winKeyCode: 0x43, macKeyCode: 0x08),
                Key(label: "V", width: unit, winCmdString: "V", macCmdString: "VMAC", winKeyCode: 0x56, macKeyCode: 0x09),
                Key(label: "B", width: unit, winCmdString: "B", macCmdString: "BMAC", winKeyCode: 0x42, macKeyCode: 0x0B),
                Key(label: "N", width: unit, winCmdString: "N", macCmdString: "NMAC", winKeyCode: 0x4E, macKeyCode: 0x2D),
                Key(label: "M", width: unit, winCmdString: "M", macCmdString: "MMAC", winKeyCode: 0x4D, macKeyCode: 0x2E),
                Key(label: ", <", width: unit, winCmdString: "COMMA", macCmdString: "COMMAMAC", winKeyCode: 0xBC, macKeyCode: 0x2B),
                Key(label: ". >", width: unit, winCmdString: "PERIOD", macCmdString: "PERIODMAC", winKeyCode: 0xBE, macKeyCode: 0x2F),
                Key(label: "/ ?", width: unit, winCmdString: "FORWARDSLASH", macCmdString: "FORWARDSLASHMAC", winKeyCode: 0xBF, macKeyCode: 0x2C),
                Key(label: "Shift", identity: "right-shift", width: unit * 2.75, winCmdString: "RSHIFT", macCmdString: "SHIFTMAC", winKeyCode: 0xA1, macKeyCode: 0x38)
            ]),
            Row(keys: keyboardType == .win ? [
                Key(label: keyboardType == .win ? "Win" : "Mac", role: .keyboardSwitch, width: unit * 1.25, winCmdString: "NULL", macCmdString: "NULL", winKeyCode: 0xFF, macKeyCode: 0xFF),
                Key(label: "Fn", role: .fn,  width: unit * 1.25, winCmdString: "FUNCTION", macCmdString: "FUNCTION", winKeyCode: nil, macKeyCode: 0x3F),
                
                Key(label: "Ctrl", width: unit * 1.25, winCmdString: "CTRL", macCmdString: nil, winKeyCode: 0x11, macKeyCode: nil),
                Key(label: "Win", width: unit * 1.25, sfSymbolName: "square.grid.2x2.fill", winCmdString: "WIN", macCmdString: nil, winKeyCode: 0x5B, macKeyCode: nil),
                Key(label: "Alt", width: unit * 1.25, winCmdString: "ALT", macCmdString: nil, winKeyCode: 0x12, macKeyCode: nil),
                Key(label: "Space", width: unit * 6, winCmdString: "SPACE", macCmdString: nil, winKeyCode: 0x20, macKeyCode: nil),
                Key(label: "Alt", width: unit * 1.25, winCmdString: "RALT", macCmdString: nil, winKeyCode: 0xA5, macKeyCode: nil),
                Key(label: "Apps", width: unit * 1.25, sfSymbolName: "filemenu.and.selection", winCmdString: "APPS", macCmdString: nil, winKeyCode: 0x5D, macKeyCode: nil),
                Key(label: "Ctrl", width: unit * 1.25, winCmdString: "RCTRL", macCmdString: nil, winKeyCode: 0xA3, macKeyCode: nil)
            ]:[
                Key(label: keyboardType == .win ? "Win" : "Mac", role: .keyboardSwitch, width: unit * 1.25, winCmdString: "NULL", macCmdString: "NULL", winKeyCode: 0xFF, macKeyCode: 0xFF),
                Key(label: "Fn", role: .fn,  width: unit * 1.25, winCmdString: "FUNCTION", macCmdString: "FUNCTION", winKeyCode: nil, macKeyCode: 0x3F),
                
                Key(label: "Control", width: unit * 1.25, sfSymbolName: "control", winCmdString: nil, macCmdString: "CONTROL", winKeyCode: nil, macKeyCode: 0x3B),
                Key(label: "Opt", width: unit * 1.25, sfSymbolName: "option", winCmdString: nil, macCmdString: "OPT", winKeyCode: nil, macKeyCode: 0x3A),
                Key(label: "Cmd", width: unit * 1.25, sfSymbolName: "command", winCmdString: nil, macCmdString: "CMD", winKeyCode: nil, macKeyCode: 0x37),
                Key(label: "Space", width: unit * 6, winCmdString: nil, macCmdString: "SPACEMAC", winKeyCode: nil, macKeyCode: 0x31),
                Key(label: "Cmd", width: unit * 1.25, sfSymbolName: "command", winCmdString: nil, macCmdString: "RIGHTCMD", winKeyCode: nil, macKeyCode: 0x36),
                Key(label: "Opt", width: unit * 1.25, sfSymbolName: "option", winCmdString: nil, macCmdString: "RIGHTOPT", winKeyCode: nil, macKeyCode: 0x3D),
                Key(label: "Control", width: unit * 1.25, sfSymbolName: "control", winCmdString: nil, macCmdString: "RIGHTCONTROL", winKeyCode: nil, macKeyCode: 0x3E),
            ])
        ]
    }
    
    // MARK: - 导航区
    var navBlock: some View {
        VStack(spacing: spacing) {
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    keyboardKeyView(Key(label: keyboardType == .win ? "PrScr" : "F13", width: unit, winCmdString: "PRSCR", macCmdString: "F13MAC", winKeyCode: 0x2C, macKeyCode: 0x69))
                    keyboardKeyView(Key(label: keyboardType == .win ? "ScrLk" : "F14", width: unit, winCmdString: "SCRLCK", macCmdString: "F14MAC", winKeyCode: 0x91, macKeyCode: 0x6B))
                    keyboardKeyView(Key(label: keyboardType == .win ? "Pause" : "F15", width: unit, winCmdString: "PAUSE", macCmdString: "F15MAC", winKeyCode: 0x13, macKeyCode: 0x71))
                }
                HStack(spacing: spacing) {
                    keyboardKeyView(Key(label: "Ins", width: unit, sfSymbolName:(keyboardType == .win ? nil : "filemenu.and.selection"), winCmdString: "INSERT", macCmdString: "CONTEXTMAC", winKeyCode: 0x2D, macKeyCode: 0x72))
                    keyboardKeyView(Key(label: "Home", width: unit, winCmdString: "HOME", macCmdString: "HOMEMAC", winKeyCode: 0x24, macKeyCode: 0x73))
                    keyboardKeyView(Key(label: "PgUp", width: unit, winCmdString: "PGUP", macCmdString: "PGUPMAC", winKeyCode: 0x21, macKeyCode: 0x74))
                }
                HStack(spacing: spacing) {
                    keyboardKeyView(Key(label: "Del", width: unit, sfSymbolName:(keyboardType == .win ? nil : "delete.right"), winCmdString: "DEL", macCmdString: "DELMAC", winKeyCode: 0x2E, macKeyCode: 0x75))
                    keyboardKeyView(Key(label: "End", width: unit, winCmdString: "END", macCmdString: "ENDMAC", winKeyCode: 0x23, macKeyCode: 0x77))
                    keyboardKeyView(Key(label: "PgDn", width: unit, winCmdString: "PGDN", macCmdString: "PGDNMAC", winKeyCode: 0x22, macKeyCode: 0x79))
                }
            }
            Spacer()
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    keyboardKeyView(Key(label: "←", visualStyle: .directionPad, width: unit, winCmdString: "LEFTARR", macCmdString: "LEFTARRMAC", winKeyCode: 0x25, macKeyCode: 0x7B)).opacity(0)
                    keyboardKeyView(Key(label: "↑", visualStyle: .directionPad, width: unit, winCmdString: "UPARR", macCmdString: "UPARRMAC", winKeyCode: 0x26, macKeyCode: 0x7E))
                    keyboardKeyView(Key(label: "→", visualStyle: .directionPad, width: unit, winCmdString: "RIGHTARR", macCmdString: "RIGHTARRMAC", winKeyCode: 0x27, macKeyCode: 0x7C)).opacity(0)
                }
                HStack(spacing: spacing) {
                    keyboardKeyView(Key(label: "←", visualStyle: .directionPad, width: unit, winCmdString: "LEFTARR", macCmdString: "LEFTARRMAC", winKeyCode: 0x25, macKeyCode: 0x7B))
                    keyboardKeyView(Key(label: "↓", visualStyle: .directionPad, width: unit, winCmdString: "DOWNARR", macCmdString: "DOWNARRMAC", winKeyCode: 0x28, macKeyCode: 0x7D))
                    keyboardKeyView(Key(label: "→", visualStyle: .directionPad, width: unit, winCmdString: "RIGHTARR", macCmdString: "RIGHTARRMAC", winKeyCode: 0x27, macKeyCode: 0x7C))
                }
            }
        }
        .frame(height: totalHeight, alignment: .top)
    }
    
    // MARK: - 小键盘
    // MARK: - 小键盘 / 鼠标控件区
    var numpadBlock: some View {
        VStack(spacing: spacing) {
            if usesPickerLayout {
                HStack(spacing: spacing) {
                    KeyView(
                        key: Key(
                            label: showsMouseWidgets
                                ? SwiftLocalizationHelper.localizedString(forKey: "Mouse Widgets")
                                : SwiftLocalizationHelper.localizedString(forKey: "Numpad"),
                            width: unit * 2 + spacing,
                            sfSymbolName: showsMouseWidgets
                                ? "computermouse.fill"
                                : "circle.grid.3x3",
                            winCmdString: "NULL",
                            macCmdString: "NULL",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ),
                        height: keyHeight,
                        keyboardType: keyboardType,
                        mode: mode
                    )

                    KeyView(
                        key: Key(
                            label: showsMouseWidgets
                                ? SwiftLocalizationHelper.localizedString(forKey: "numpad")
                                : SwiftLocalizationHelper.localizedString(forKey: "mouse widgets"),
                            width: unit * 2 + spacing,
                            winCmdString: "NULL",
                            macCmdString: "NULL",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ),
                        height: keyHeight,
                        keyboardType: keyboardType,
                        mode: mode,
                        isActive: showsMouseWidgets,
                        action: {
                            showsMouseWidgets.toggle()
                        }
                    )
                }
            }

            if usesPickerLayout {
                if showsMouseWidgets {
                    mouseWidgetsBlock
                } else {
                    numpadKeysBlock
                }
            } else {
                Spacer()
                numpadKeysBlock
            }
        }
        .frame(height: totalHeight, alignment: .top)
    }

    var numpadKeysBlock: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                keyboardKeyView(Key(label: keyboardType == .win ? "Num" : "Clear", width: unit, winCmdString: "NUMLCK", macCmdString: "NUMPADCLEARMAC", winKeyCode: 0x90, macKeyCode: 0x47))
                keyboardKeyView(Key(label: "/", width: unit, winCmdString: "DIVIDE", macCmdString: "NUMPADDIVIDEMAC", winKeyCode: 0x6F, macKeyCode: 0x4B))
                keyboardKeyView(Key(label: "*", width: unit, winCmdString: "MULTIPLY", macCmdString: "NUMPADMULTIPLYMAC", winKeyCode: 0x6A, macKeyCode: 0x43))
                keyboardKeyView(Key(label: "-", width: unit, winCmdString: "SUBTRACT", macCmdString: "NUMPADSUBTRACTMAC", winKeyCode: 0x6D, macKeyCode: 0x4E))
            }

            HStack(alignment: .top, spacing: spacing) {
                VStack(spacing: spacing) {
                    HStack(spacing: spacing) {
                        keyboardKeyView(Key(label: "7", width: unit, winCmdString: "NUMPAD7", macCmdString: "NUMPAD7MAC", winKeyCode: 0x67, macKeyCode: 0x56))
                        keyboardKeyView(Key(label: "8", width: unit, winCmdString: "NUMPAD8", macCmdString: "NUMPAD8MAC", winKeyCode: 0x68, macKeyCode: 0x57))
                        keyboardKeyView(Key(label: "9", width: unit, winCmdString: "NUMPAD9", macCmdString: "NUMPAD9MAC", winKeyCode: 0x69, macKeyCode: 0x58))
                    }

                    HStack(spacing: spacing) {
                        keyboardKeyView(Key(label: "4", width: unit, winCmdString: "NUMPAD4", macCmdString: "NUMPAD4MAC", winKeyCode: 0x64, macKeyCode: 0x53))
                        keyboardKeyView(Key(label: "5", width: unit, winCmdString: "NUMPAD5", macCmdString: "NUMPAD5MAC", winKeyCode: 0x65, macKeyCode: 0x54))
                        keyboardKeyView(Key(label: "6", width: unit, winCmdString: "NUMPAD6", macCmdString: "NUMPAD6MAC", winKeyCode: 0x66, macKeyCode: 0x55))
                    }

                    HStack(spacing: spacing) {
                        keyboardKeyView(Key(label: "1", width: unit, winCmdString: "NUMPAD1", macCmdString: "NUMPAD1MAC", winKeyCode: 0x61, macKeyCode: 0x50))
                        keyboardKeyView(Key(label: "2", width: unit, winCmdString: "NUMPAD2", macCmdString: "NUMPAD2MAC", winKeyCode: 0x62, macKeyCode: 0x51))
                        keyboardKeyView(Key(label: "3", width: unit, winCmdString: "NUMPAD3", macCmdString: "NUMPAD3MAC", winKeyCode: 0x63, macKeyCode: 0x52))
                    }

                    HStack(spacing: spacing) {
                        keyboardKeyView(Key(label: "0", width: unit * 2 + spacing, winCmdString: "NUMPAD0", macCmdString: "NUMPAD0MAC", winKeyCode: 0x60, macKeyCode: 0x4F))
                        keyboardKeyView(Key(label: ".", width: unit, winCmdString: "DECIMAL", macCmdString: "NUMPADDECIMALMAC", winKeyCode: 0x6E, macKeyCode: 0x41))
                    }
                }

                VStack(spacing: spacing) {
                    keyboardKeyView(
                        Key(label: "+", width: unit, winCmdString: "ADD", macCmdString: "NUMPADADDMAC", winKeyCode: 0x6B, macKeyCode: 0x45),
                        height: keyHeight * (keyboardType == .win ? 2 : 1) + (keyboardType == .win ? spacing : 0)
                    )
                    keyboardType == .win ? nil : keyboardKeyView(Key(label: "=", width: unit, winCmdString: nil, macCmdString: "NUMPADEQUALMAC", winKeyCode: nil, macKeyCode: 0x51))
                    keyboardKeyView(
                        Key(label: "Enter", identity: "numpad-enter", width: unit, winCmdString: "ENTER", macCmdString: "ENTERMAC", winKeyCode: 0x0D, macKeyCode: 0x4C),
                        height: keyHeight * 2 + spacing
                    )
                }
            }
        }
    }

    var mouseWidgetsBlock: some View {
        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                KeyView(
                    key: Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "Left Button"),
                        width: unit * 2 + spacing,
                        winCmdString: "MLEFT",
                        macCmdString: "MLEFT",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    ),
                    height: keyHeight,
                    keyboardType: keyboardType,
                    mode: mode,
                    highlightStyle: highlightStyle(for: Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "Left Button"),
                        width: unit * 2 + spacing,
                        winCmdString: "MLEFT",
                        macCmdString: "MLEFT",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    )),
                    action: {
                        handleKeyTap(Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Left Button"),
                            width: unit * 2 + spacing,
                            winCmdString: "MLEFT",
                            macCmdString: "MLEFT",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ))
                    }
                )

                KeyView(
                    key: Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "Right Button"),
                        width: unit * 2 + spacing,
                        winCmdString: "MRIGHT",
                        macCmdString: "MRIGHT",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    ),
                    height: keyHeight,
                    keyboardType: keyboardType,
                    mode: mode,
                    highlightStyle: highlightStyle(for: Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "Right Button"),
                        width: unit * 2 + spacing,
                        winCmdString: "MRIGHT",
                        macCmdString: "MRIGHT",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    )),
                    action: {
                        handleKeyTap(Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Right Button"),
                            width: unit * 2 + spacing,
                            winCmdString: "MRIGHT",
                            macCmdString: "MRIGHT",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ))
                    }
                )
            }

            HStack(spacing: spacing) {
                keyboardKeyView(
                    Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "Middle Button"),
                        width: unit * 2 + spacing,
                        winCmdString: "MMIDDLE",
                        macCmdString: "MMIDDLE",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    )
                )

                keyboardKeyView(
                    Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "X1"),
                        width: unit,
                        winCmdString: "MX1",
                        macCmdString: "MX1",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    )
                )

                keyboardKeyView(
                    Key(
                        label: SwiftLocalizationHelper.localizedString(forKey: "X2"),
                        width: unit,
                        winCmdString: "MX2",
                        macCmdString: "MX2",
                        winKeyCode: 0xFF,
                        macKeyCode: 0xFF
                    )
                )
            }

            if mode == .shortcutPicker {
                HStack(spacing: spacing) {
                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nUp"),
                            width: unit,
                            winCmdString: "WHEELDOWN",
                            macCmdString: "WHEELDOWN",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        )
                    )

                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nDown"),
                            width: unit,
                            winCmdString: "WHEELUP",
                            macCmdString: "WHEELUP",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        )
                    )
                }
            } else {
                HStack(spacing: spacing) {
                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nUp"),
                            width: unit,
                            winCmdString: "WHEELDOWN",
                            macCmdString: "WHEELDOWN",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        )
                    )

                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nDown"),
                            width: unit,
                            winCmdString: "WHEELUP",
                            macCmdString: "WHEELUP",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        )
                    )

                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "WheelPad"),
                            width: unit * 2 + spacing,
                            winCmdString: "WHEEL",
                            macCmdString: "WHEEL",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        )
                    )
                }
            }

            if mode != .shortcutPicker {
                HStack(spacing: spacing) {
                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "MousePad"),
                            width: unit * 2 + spacing,
                            winCmdString: "MOUSEPAD",
                            macCmdString: "MOUSEPAD",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ),
                        height: keyHeight * 2 + spacing
                    )

                    keyboardKeyView(
                        Key(
                            label: SwiftLocalizationHelper.localizedString(forKey: "Trackball"),
                            width: unit * 2 + spacing,
                            winCmdString: "TRACKBALL",
                            macCmdString: "TRACKBALL",
                            winKeyCode: 0xFF,
                            macKeyCode: 0xFF
                        ),
                        height: keyHeight * 2 + spacing
                    )
                }
            }
        }
    }
    var totalHeight: CGFloat {
        CGFloat(mainRows.count) * keyHeight + CGFloat(mainRows.count - 1) * spacing
    }

    private var pickerSectionSpacing: CGFloat {
        18
    }

    private var mainBlockWidth: CGFloat {
        mainRows
            .map { row in
                row.keys.reduce(CGFloat(0)) { partialResult, key in
                    partialResult + key.width
                } + CGFloat(max(row.keys.count - 1, 0)) * spacing
            }
            .max() ?? 0
    }

    private var navBlockWidth: CGFloat {
        unit * 3 + spacing * 2
    }

    private var numpadBlockWidth: CGFloat {
        unit * 4 + spacing * 3
    }

    private var equalBottomRowGap: CGFloat {
        max((mainBlockWidth - navBlockWidth - numpadBlockWidth) / 3, 0)
    }

    private var pickerContentWidth: CGFloat {
        mainBlockWidth
    }

    private var pickerContentHeight: CGFloat {
        totalHeight * 2 + pickerSectionSpacing
    }

    private func resetAllSelections() {
        highlightedKeyIDs.removeAll()
        directionSingleKeyLabels.removeAll()
        padSelections.removeAll()
        pendingKeyboardOptions.removeAll()
        pendingSelectionFamily = nil
        showKeyboardWidgetPicker = false
        VirtualKeyboardView.tappedKeyLabels = []
        VirtualKeyboardView.selectedCmd = ""
    }

    private func synchronizeSelectionHighlights() {
        highlightedKeyIDs.removeAll()
        directionSingleKeyLabels.removeAll()
        padSelections.removeAll()

        guard let isCommandSelected = isCommandSelected else { return }

        for family in [KeyboardSelectionFamily.wasd, .arrow] {
            let command = padCommand(for: family)
            if isCommandSelected(command) {
                padSelections.insert(family)
            } else {
                for label in labels(for: family) {
                    if let key = key(forLabel: label),
                       let singleCommand = key.cmdString(for: keyboardType),
                       isCommandSelected(singleCommand) {
                        directionSingleKeyLabels.insert(label)
                    }
                }
            }
        }

        for key in allKeys {
            guard selectionFamily(for: key) == nil,
                  let command = key.cmdString(for: keyboardType),
                  isCommandSelected(command) else { continue }
            highlightedKeyIDs.insert(regularHighlightID(for: key))
        }
    }

    private func deselectCommand(_ command: String) {
        if command == "WASDPAD" {
            padSelections.remove(.wasd)
        } else if command == "ARROWPAD" {
            padSelections.remove(.arrow)
        }

        for family in [KeyboardSelectionFamily.wasd, .arrow] {
            for label in labels(for: family) {
                if let key = key(forLabel: label), key.cmdString(for: keyboardType) == command {
                    directionSingleKeyLabels.remove(label)
                }
            }
        }

        for key in allKeys where key.cmdString(for: keyboardType) == command {
            highlightedKeyIDs.remove(regularHighlightID(for: key))
        }

        if VirtualKeyboardView.selectedCmd == command {
            VirtualKeyboardView.selectedCmd = ""
        }
    }

    private func notifyDeselection(for family: KeyboardSelectionFamily) {
        if padSelections.contains(family) {
            onCommandDeselected?(padCommand(for: family))
        }

        for label in labels(for: family) where directionSingleKeyLabels.contains(label) {
            if let key = key(forLabel: label), let cmd = key.cmdString(for: keyboardType), !cmd.isEmpty {
                onCommandDeselected?(cmd)
            }
        }
    }

    private func key(forLabel label: String) -> Key? {
        allKeys.first(where: { $0.label == label })
    }

    private var allKeys: [Key] {
        mainRows.flatMap(\.keys)
        + navKeys
        + numpadKeys
        + mouseWidgetKeys
    }

    private var navKeys: [Key] {
        [
            Key(label: keyboardType == .win ? "PrScr" : "F13", width: unit, winCmdString: "PRSCR", macCmdString: "F13MAC", winKeyCode: 0x2C, macKeyCode: 0x69),
            Key(label: keyboardType == .win ? "ScrLk" : "F14", width: unit, winCmdString: "SCRLCK", macCmdString: "F14MAC", winKeyCode: 0x91, macKeyCode: 0x6B),
            Key(label: keyboardType == .win ? "Pause" : "F15", width: unit, winCmdString: "PAUSE", macCmdString: "F15MAC", winKeyCode: 0x13, macKeyCode: 0x71),
            Key(label: "Ins", width: unit, sfSymbolName:(keyboardType == .win ? nil : "filemenu.and.selection"), winCmdString: "INSERT", macCmdString: "CONTEXTMAC", winKeyCode: 0x2D, macKeyCode: 0x72),
            Key(label: "Home", width: unit, winCmdString: "HOME", macCmdString: "HOMEMAC", winKeyCode: 0x24, macKeyCode: 0x73),
            Key(label: "PgUp", width: unit, winCmdString: "PGUP", macCmdString: "PGUPMAC", winKeyCode: 0x21, macKeyCode: 0x74),
            Key(label: "Del", width: unit, sfSymbolName:(keyboardType == .win ? nil : "delete.right"), winCmdString: "DEL", macCmdString: "DELMAC", winKeyCode: 0x2E, macKeyCode: 0x75),
            Key(label: "End", width: unit, winCmdString: "END", macCmdString: "ENDMAC", winKeyCode: 0x23, macKeyCode: 0x77),
            Key(label: "PgDn", width: unit, winCmdString: "PGDN", macCmdString: "PGDNMAC", winKeyCode: 0x22, macKeyCode: 0x79),
            Key(label: "↑", visualStyle: .directionPad, width: unit, winCmdString: "UPARR", macCmdString: "UPARRMAC", winKeyCode: 0x26, macKeyCode: 0x7E),
            Key(label: "←", visualStyle: .directionPad, width: unit, winCmdString: "LEFTARR", macCmdString: "LEFTARRMAC", winKeyCode: 0x25, macKeyCode: 0x7B),
            Key(label: "↓", visualStyle: .directionPad, width: unit, winCmdString: "DOWNARR", macCmdString: "DOWNARRMAC", winKeyCode: 0x28, macKeyCode: 0x7D),
            Key(label: "→", visualStyle: .directionPad, width: unit, winCmdString: "RIGHTARR", macCmdString: "RIGHTARRMAC", winKeyCode: 0x27, macKeyCode: 0x7C)
        ]
    }

    private var numpadKeys: [Key] {
        [
            Key(label: keyboardType == .win ? "Num" : "Clear", width: unit, winCmdString: "NUMLCK", macCmdString: "NUMPADCLEARMAC", winKeyCode: 0x90, macKeyCode: 0x47),
            Key(label: "/", width: unit, winCmdString: "DIVIDE", macCmdString: "NUMPADDIVIDEMAC", winKeyCode: 0x6F, macKeyCode: 0x4B),
            Key(label: "*", width: unit, winCmdString: "MULTIPLY", macCmdString: "NUMPADMULTIPLYMAC", winKeyCode: 0x6A, macKeyCode: 0x43),
            Key(label: "-", width: unit, winCmdString: "SUBTRACT", macCmdString: "NUMPADSUBTRACTMAC", winKeyCode: 0x6D, macKeyCode: 0x4E),
            Key(label: "7", width: unit, winCmdString: "NUMPAD7", macCmdString: "NUMPAD7MAC", winKeyCode: 0x67, macKeyCode: 0x56),
            Key(label: "8", width: unit, winCmdString: "NUMPAD8", macCmdString: "NUMPAD8MAC", winKeyCode: 0x68, macKeyCode: 0x57),
            Key(label: "9", width: unit, winCmdString: "NUMPAD9", macCmdString: "NUMPAD9MAC", winKeyCode: 0x69, macKeyCode: 0x58),
            Key(label: "4", width: unit, winCmdString: "NUMPAD4", macCmdString: "NUMPAD4MAC", winKeyCode: 0x64, macKeyCode: 0x53),
            Key(label: "5", width: unit, winCmdString: "NUMPAD5", macCmdString: "NUMPAD5MAC", winKeyCode: 0x65, macKeyCode: 0x54),
            Key(label: "6", width: unit, winCmdString: "NUMPAD6", macCmdString: "NUMPAD6MAC", winKeyCode: 0x66, macKeyCode: 0x55),
            Key(label: "1", width: unit, winCmdString: "NUMPAD1", macCmdString: "NUMPAD1MAC", winKeyCode: 0x61, macKeyCode: 0x50),
            Key(label: "2", width: unit, winCmdString: "NUMPAD2", macCmdString: "NUMPAD2MAC", winKeyCode: 0x62, macKeyCode: 0x51),
            Key(label: "3", width: unit, winCmdString: "NUMPAD3", macCmdString: "NUMPAD3MAC", winKeyCode: 0x63, macKeyCode: 0x52),
            Key(label: "0", width: unit * 2 + spacing, winCmdString: "NUMPAD0", macCmdString: "NUMPAD0MAC", winKeyCode: 0x60, macKeyCode: 0x4F),
            Key(label: ".", width: unit, winCmdString: "DECIMAL", macCmdString: "NUMPADDECIMALMAC", winKeyCode: 0x6E, macKeyCode: 0x41),
            Key(label: "+", width: unit, winCmdString: "ADD", macCmdString: "NUMPADADDMAC", winKeyCode: 0x6B, macKeyCode: 0x45),
            Key(label: "=", width: unit, winCmdString: nil, macCmdString: "NUMPADEQUALMAC", winKeyCode: nil, macKeyCode: 0x51),
            Key(label: "Enter", identity: "numpad-enter", width: unit, winCmdString: "ENTER", macCmdString: "ENTERMAC", winKeyCode: 0x0D, macKeyCode: 0x4C)
        ]
    }

    private var mouseWidgetKeys: [Key] {
        var keys = [
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Left Button"), width: unit * 2 + spacing, winCmdString: "MLEFT", macCmdString: "MLEFT", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Right Button"), width: unit * 2 + spacing, winCmdString: "MRIGHT", macCmdString: "MRIGHT", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Middle Button"), width: unit * 2 + spacing, winCmdString: "MMIDDLE", macCmdString: "MMIDDLE", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "X1"), width: unit, winCmdString: "MX1", macCmdString: "MX1", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "X2"), width: unit, winCmdString: "MX2", macCmdString: "MX2", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nUp"), width: unit, winCmdString: "WHEELDOWN", macCmdString: "WHEELDOWN", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Wheel\nDown"), width: unit, winCmdString: "WHEELUP", macCmdString: "WHEELUP", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "WheelPad"), width: unit * 2 + spacing, winCmdString: "WHEEL", macCmdString: "WHEEL", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "MousePad"), width: unit * 2 + spacing, winCmdString: "MOUSEPAD", macCmdString: "MOUSEPAD", winKeyCode: 0xFF, macKeyCode: 0xFF),
            Key(label: SwiftLocalizationHelper.localizedString(forKey: "Trackball"), width: unit * 2 + spacing, winCmdString: "TRACKBALL", macCmdString: "TRACKBALL", winKeyCode: 0xFF, macKeyCode: 0xFF)
        ]
        if mode == .shortcutPicker {
            keys.removeAll { key in
                let command = key.cmdString(for: keyboardType) ?? ""
                return command == "WHEEL" || command == "MOUSEPAD" || command == "TRACKBALL"
            }
        }
        return keys
    }

    private var usesPickerLayout: Bool {
        mode != .typing
    }

    private var usesPickerSelectionBehavior: Bool {
        mode == .picker || mode == .shortcutPicker
    }

    private var usesPadSelectionHighlight: Bool {
        mode == .picker
    }

    private var usesDirectionPadBaseStyle: Bool {
        mode == .picker
    }
}

@available(iOS 13.0, *)
struct KeyView: View {
    let key: Key
    let height: CGFloat
    let keyboardType: KeyboardType
    let fontSize: CGFloat = 10
    var mode: VirtualKeyboardMode = .typing
    var usesDirectionPadBaseStyle: Bool = true
    var isActive: Bool = false
    var highlightStyle: KeyHighlightStyle = .none
    var action: (() -> Void)? = nil
    
    @SwiftUI.State private var isPressed = false
    
    var cmdString: String? {
        key.cmdString(for: keyboardType)
    }
    
    var keyCode: Int16? {
        key.keyCode(for: keyboardType)
    }

    private var typingHighlightFill: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.78, green: 0.84, blue: 0.92).opacity(0.95),
                Color(red: 0.66, green: 0.74, blue: 0.85).opacity(0.88)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var typingHighlightStroke: Color {
        Color(red: 0.42, green: 0.52, blue: 0.66).opacity(0.78)
    }

    private var keyFillColor: Color {
        switch key.visualStyle {
        case .standard:
            return Color.gray.opacity(0.2)
        case .directionPad:
            return usesDirectionPadBaseStyle
                ? Color(red: 0.16, green: 0.72, blue: 0.66).opacity(0.2)
                : Color.gray.opacity(0.2)
        }
    }

    private var keyStrokeColor: Color {
        switch key.visualStyle {
        case .standard:
            return Color.gray.opacity(0.2)
        case .directionPad:
            return usesDirectionPadBaseStyle
                ? Color(red: 0.08, green: 0.49, blue: 0.45).opacity(0.55)
                : Color.gray.opacity(0.2)
        }
    }

    private var foregroundColor: Color {
        if mode == .typing && (highlightStyle != .none || isPressed) {
            return Color.black.opacity(0.72)
        }
        
        if highlightStyle != .none {
            if mode == .typing {
                return Color.black.opacity(0.72)
            }
            return Color.black.opacity(0.58)
        }

        switch key.visualStyle {
        case .standard:
            return Color.primary
        case .directionPad:
            return Color.primary
        }
    }
    
    @ViewBuilder
    private var keyContent: some View {
        if let name = key.sfSymbolName, !name.isEmpty {
            Image(systemName: name)
                .font(.system(size: fontSize))
                .foregroundColor(.black)
        } else {
            Text(key.label)
                .font(.system(size: fontSize, weight: .regular, design: .rounded))
                .foregroundColor(.black)
        }
    }
    
    private var backgroundColor: Color {
        if highlightStyle != .none {
            return Color.clear
        }

        if isPressed || isActive {
            return Color.gray.opacity(0.4)
        }
        return keyFillColor
    }

    @ViewBuilder
    private var keyBackground: some View {
        if mode == .typing, (highlightStyle != .none || isPressed) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(typingHighlightFill)
        } else if highlightStyle == .pad {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.82, green: 0.84, blue: 1.00).opacity(0.92),
                            Color(red: 0.56, green: 0.60, blue: 0.94).opacity(0.84)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        } else if highlightStyle == .single {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
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
        } else {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor)
        }
    }

    private var borderColor: Color {
        if mode == .typing, (highlightStyle != .none || isPressed) {
            return typingHighlightStroke
        }
        if highlightStyle == .pad {
            return Color(red: 0.38, green: 0.42, blue: 0.82).opacity(0.90)
        }
        if highlightStyle == .single {
            return Color.orange.opacity(0.75)
        }
        return keyStrokeColor
    }

    var body: some View {
        keyContent
            .foregroundColor(foregroundColor)
            .frame(width: key.width, height: height)
            .background(keyBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: highlightStyle == .none ? (key.visualStyle == .standard ? 1 : 1.5) : 1.5)
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        action?()
                        print("cmdString \(String(describing: cmdString)) code \(String(describing: keyCode))")
                    }
            )
    }
}

@available(iOS 13.0, *)
struct KeyboardWidgetPickerOverlay: View {
    let options: [KeyboardWidgetOption]
    let onSelect: (KeyboardWidgetOption) -> Void
    let onReset: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onCancel()
                }

            VStack(spacing: 14) {
                Text(SwiftLocalizationHelper.localizedString(forKey: "Select Control"))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        Button(action: {
                            onSelect(option)
                        }) {
                            HStack(spacing: 12) {
                                Text(option.description)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)

                                Spacer()

                                Text(option.command)
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

                HStack(spacing: 12) {
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

                    Button(action: {
                        onReset()
                    }) {
                        Text(SwiftLocalizationHelper.localizedString(forKey: "Reset"))
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
struct VirtualKeyboardView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // VirtualKeyboardView(mode: .typing)
               // .frame(height: 320)

            VirtualKeyboardView(mode: .picker)
                .frame(height: 320)
                .previewDisplayName("Picker")

            VirtualKeyboardView(mode: .shortcutPicker)
                .frame(height: 320)
                .previewDisplayName("Shortcut Picker")
        }
    }
}
