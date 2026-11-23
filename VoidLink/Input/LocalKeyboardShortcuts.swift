//
//  LocalKeyboardShortcuts.swift
//  VoidLink
//

import Foundation

@objc enum LocalKeyboardShortcutAction: Int, CaseIterable {
    case none = 0
    case disconnect
    case statistics
    case settings
    case mouseCapture
    case mouseVisibility
    case quitHostApp

    static var configurableActions: [Self] { allCases.filter { $0 != .none } }

    var storageKey: String {
        switch self {
        case .none: return "none"
        case .disconnect: return "disconnect"
        case .statistics: return "statistics"
        case .settings: return "settings"
        case .mouseCapture: return "mouseCapture"
        case .mouseVisibility: return "mouseVisibility"
        case .quitHostApp: return "quitHostApp"
        }
    }

    var titleKey: String {
        switch self {
        case .none: return "Disabled"
        case .disconnect: return "Disconnect Stream"
        case .statistics: return "Toggle Statistics Overlay"
        case .settings: return "Open Settings"
        case .mouseCapture: return "Toggle Mouse Capture"
        case .mouseVisibility: return "Toggle Mouse Visibility"
        case .quitHostApp: return "Disconnect and Quit Host App"
        }
    }

    var defaultKeyCode: Int {
        // USB keyboard-page usages, also used by UIKeyboardHIDUsage.
        switch self {
        case .none: return 0
        case .disconnect: return 7   // D
        case .statistics: return 18  // O
        case .settings: return 22   // S
        case .mouseCapture: return 16 // M
        case .mouseVisibility: return 6 // C
        case .quitHostApp: return 20 // Q
        }
    }
}

struct LocalKeyboardShortcutBinding: Equatable {
    // UIKeyModifierFlags uses these device-independent modifier bits.
    static let shift: UInt = 1 << 17
    static let control: UInt = 1 << 18
    static let option: UInt = 1 << 19
    static let command: UInt = 1 << 20
    static let modifierMask = shift | control | option | command
    static let defaultModifiers = control | option | shift

    var keyCode: Int
    var modifiers: UInt
    var isEnabled: Bool
    var keyLabel: String? = nil

    static func defaultBinding(for action: LocalKeyboardShortcutAction) -> Self {
        Self(keyCode: action.defaultKeyCode, modifiers: defaultModifiers, isEnabled: true)
    }

    var displayName: String {
        let prefix = [(Self.control, "⌃"), (Self.option, "⌥"), (Self.shift, "⇧"), (Self.command, "⌘")]
            .filter { modifiers & $0.0 != 0 }.map { $0.1 }.joined()
        return prefix + (keyLabel ?? Self.keyName(keyCode))
    }

    static func keyName(_ code: Int) -> String {
        if (4...29).contains(code) { return String(UnicodeScalar(code - 4 + 65)!) }
        if (30...38).contains(code) { return String(code - 29) }
        if code == 39 { return "0" }
        if (58...69).contains(code) { return "F\(code - 57)" }
        let names = [40: "↩", 41: "⎋", 42: "⌫", 43: "⇥", 44: "Space", 45: "-", 46: "=",
                     47: "[", 48: "]", 49: "\\", 50: "#", 51: ";", 52: "'", 53: "`",
                     54: ",", 55: ".", 56: "/", 57: "⇪", 74: "Home", 75: "Page Up",
                     76: "⌦", 77: "End", 78: "Page Down", 79: "→", 80: "←", 81: "↓", 82: "↑"]
        return names[code] ?? "Key \(code)"
    }
}

enum LocalKeyboardShortcutError: Error, Equatable {
    case invalidKey
    case conflict(LocalKeyboardShortcutAction)
}

/// Local actions only. StreamView continues forwarding the original key events.
@objc(LocalKeyboardShortcuts)
final class LocalKeyboardShortcuts: NSObject {
    static let defaultsKey = "localKeyboardShortcutBindings"
    static let shared = LocalKeyboardShortcuts()
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()
    }

    func binding(for action: LocalKeyboardShortcutAction) -> LocalKeyboardShortcutBinding {
        let fallback = LocalKeyboardShortcutBinding.defaultBinding(for: action)
        guard let records = defaults.dictionary(forKey: Self.defaultsKey),
              let record = records[action.storageKey] as? [String: Any],
              let code = record["keyCode"] as? Int, (4..<224).contains(code),
              let modifiers = record["modifiers"] as? UInt,
              modifiers & ~LocalKeyboardShortcutBinding.modifierMask == 0,
              let enabled = record["enabled"] as? Bool else { return fallback }
        return LocalKeyboardShortcutBinding(keyCode: code, modifiers: modifiers, isEnabled: enabled,
            keyLabel: Self.validatedLabel(record["keyLabel"] as? String))
    }

    func action(keyCode: Int, modifierFlags: UInt) -> LocalKeyboardShortcutAction {
        let modifiers = modifierFlags & LocalKeyboardShortcutBinding.modifierMask
        for action in LocalKeyboardShortcutAction.configurableActions {
            let binding = binding(for: action)
            if binding.isEnabled && binding.keyCode == keyCode && binding.modifiers == modifiers {
                return action
            }
        }
        return .none
    }

    @objc(actionForKeyCode:modifierFlags:)
    static func action(keyCode: Int, modifierFlags: UInt) -> LocalKeyboardShortcutAction {
        shared.action(keyCode: keyCode, modifierFlags: modifierFlags)
    }

    func setBinding(_ binding: LocalKeyboardShortcutBinding, for action: LocalKeyboardShortcutAction) throws {
        guard action != .none, (4..<224).contains(binding.keyCode),
              binding.modifiers & ~LocalKeyboardShortcutBinding.modifierMask == 0,
              binding.keyLabel == Self.validatedLabel(binding.keyLabel) else {
            throw LocalKeyboardShortcutError.invalidKey
        }
        if binding.isEnabled {
            for other in LocalKeyboardShortcutAction.configurableActions where other != action {
                let existing = self.binding(for: other)
                if existing.isEnabled && existing.keyCode == binding.keyCode && existing.modifiers == binding.modifiers {
                    throw LocalKeyboardShortcutError.conflict(other)
                }
            }
        }
        var records = defaults.dictionary(forKey: Self.defaultsKey) ?? [:]
        records[action.storageKey] = record(for: binding)
        defaults.set(records, forKey: Self.defaultsKey)
    }

    func disableAll() {
        var records: [String: Any] = [:]
        for action in LocalKeyboardShortcutAction.configurableActions {
            var binding = binding(for: action)
            binding.isEnabled = false
            records[action.storageKey] = record(for: binding)
        }
        defaults.set(records, forKey: Self.defaultsKey)
    }

    func restoreDefaults() {
        defaults.removeObject(forKey: Self.defaultsKey)
    }

    private func record(for binding: LocalKeyboardShortcutBinding) -> [String: Any] {
        var record: [String: Any] = ["keyCode": binding.keyCode, "modifiers": binding.modifiers,
                                     "enabled": binding.isEnabled]
        if let label = binding.keyLabel { record["keyLabel"] = label }
        return record
    }

    private static func validatedLabel(_ label: String?) -> String? {
        guard let label, !label.isEmpty, label.count <= 8,
              !label.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { return nil }
        return label
    }
}
