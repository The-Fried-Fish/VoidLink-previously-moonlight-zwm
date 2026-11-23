import Foundation

private struct TestFailure: Error, CustomStringConvertible {
    let description: String
}

private func expect(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw TestFailure(description: message) }
}

private func expectError(_ expected: LocalKeyboardShortcutError, _ operation: () throws -> Void) throws {
    do {
        try operation()
        throw TestFailure(description: "Expected shortcut validation failure")
    } catch let actual as LocalKeyboardShortcutError {
        try expect(actual == expected, "Unexpected validation failure: \(actual)")
    }
}

@main
private enum LocalKeyboardShortcutsTests {
    static func main() throws {
        let suite = "LocalKeyboardShortcutsTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            throw TestFailure(description: "Could not create isolated defaults")
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.removePersistentDomain(forName: suite)
        let store = LocalKeyboardShortcuts(defaults: defaults)
        let meh = LocalKeyboardShortcutBinding.defaultModifiers
        let expected: [(LocalKeyboardShortcutAction, Int)] = [
            (.disconnect, 7), (.statistics, 18), (.settings, 22),
            (.mouseCapture, 16), (.mouseVisibility, 6), (.quitHostApp, 20)
        ]
        for (action, code) in expected {
            try expect(store.action(keyCode: code, modifierFlags: meh) == action, "Default shortcut changed")
            try expect(store.action(keyCode: code, modifierFlags: 0) == .none, "Ordinary letter intercepted")
            try expect(store.action(keyCode: code, modifierFlags: meh | LocalKeyboardShortcutBinding.command) == .none,
                       "Additional command modifier must not match")
        }
        try expect(store.action(keyCode: 8, modifierFlags: meh) == .none, "Unassigned chord matched")
        print("PASS: all six defaults and ordinary/unassigned keys")

        let custom = LocalKeyboardShortcutBinding(keyCode: 14,
            modifiers: LocalKeyboardShortcutBinding.control | LocalKeyboardShortcutBinding.command,
            isEnabled: true, keyLabel: "Ж")
        try store.setBinding(custom, for: .settings)
        try expect(store.action(keyCode: 22, modifierFlags: meh) == .none, "Old chord remained active")
        try expect(store.action(keyCode: 14, modifierFlags: custom.modifiers) == .settings, "Custom chord did not match")
        guard let reloadedDefaults = UserDefaults(suiteName: suite) else {
            throw TestFailure(description: "Could not reopen isolated defaults")
        }
        let reloaded = LocalKeyboardShortcuts(defaults: reloadedDefaults)
        try expect(reloaded.binding(for: .settings) == custom, "Custom chord did not persist")
        try expect(reloaded.binding(for: .settings).displayName == "⌃⌘Ж", "Recorded keyboard-layout label lost")
        print("PASS: remapping, old-chord passthrough and stored layout-label readback")

        try expectError(.conflict(.settings)) { try store.setBinding(custom, for: .statistics) }
        try expect(store.binding(for: .statistics) == .defaultBinding(for: .statistics), "Conflict changed another binding")
        var disabled = custom
        disabled.isEnabled = false
        try store.setBinding(disabled, for: .settings)
        try expect(store.action(keyCode: 14, modifierFlags: custom.modifiers) == .none, "Disabled chord matched")
        try store.setBinding(custom, for: .statistics)
        try expectError(.conflict(.statistics)) { try store.setBinding(custom, for: .settings) }
        try expect(!store.binding(for: .settings).isEnabled, "Failed enable changed stored binding")
        print("PASS: duplicate validation, disable, and safe re-enable refusal")

        store.disableAll()
        for (action, code) in expected {
            try expect(!store.binding(for: action).isEnabled, "Disable all left an action enabled")
            try expect(store.action(keyCode: code, modifierFlags: meh) == .none, "Disabled default still matched")
        }
        try expect(store.binding(for: .statistics).keyCode == custom.keyCode, "Disable all discarded custom assignment")
        try expect(store.binding(for: .statistics).keyLabel == custom.keyLabel, "Disable all discarded recorded key label")
        store.restoreDefaults()
        for (action, code) in expected {
            try expect(store.action(keyCode: code, modifierFlags: meh) == action, "Restore defaults failed")
        }
        try expect(defaults.object(forKey: LocalKeyboardShortcuts.defaultsKey) == nil, "Reset left stale overrides")
        print("PASS: disable all preserves assignments and reset restores defaults")

        for code in [0, 3, 224, 231, 65535] {
            let invalid = LocalKeyboardShortcutBinding(keyCode: code, modifiers: meh, isEnabled: true)
            try expectError(.invalidKey) { try store.setBinding(invalid, for: .settings) }
        }
        let unsupported = LocalKeyboardShortcutBinding(keyCode: 14, modifiers: UInt.max, isEnabled: true)
        try expectError(.invalidKey) { try store.setBinding(unsupported, for: .settings) }
        try expectError(.invalidKey) { try store.setBinding(custom, for: .none) }
        for label in ["", "\n", String(repeating: "A", count: 9)] {
            var invalidLabel = custom
            invalidLabel.keyLabel = label
            try expectError(.invalidKey) { try store.setBinding(invalidLabel, for: .settings) }
        }
        print("PASS: invalid/modifier-only key, unsupported flag and label validation")

        let corruptRecords: [Any] = [
            "invalid",
            ["settings": ["keyCode": 0, "modifiers": meh, "enabled": true] as [String: Any]],
            ["settings": ["keyCode": 22, "modifiers": -1, "enabled": true] as [String: Any]],
            ["settings": ["keyCode": 22, "modifiers": meh, "enabled": "invalid"] as [String: Any]],
            ["settings": ["keyCode": 22, "modifiers": meh, "enabled": true, "keyLabel": "\n"] as [String: Any]]
        ]
        for invalid in corruptRecords {
            defaults.set(invalid, forKey: LocalKeyboardShortcuts.defaultsKey)
            try expect(store.binding(for: .settings) == .defaultBinding(for: .settings), "Corrupt preferences did not fall back safely")
        }
        store.restoreDefaults()
        let lockFlags: UInt = (1 << 16) | (1 << 21)
        try expect(store.action(keyCode: 22, modifierFlags: meh | lockFlags) == .settings,
                   "Caps/numeric lock changed an otherwise identical chord")
        try expect(LocalKeyboardShortcutBinding.defaultBinding(for: .settings).displayName == "⌃⌥⇧S", "Default label incorrect")
        try expect(LocalKeyboardShortcutBinding.keyName(58) == "F1", "Function key label incorrect")
        try expect(LocalKeyboardShortcutBinding.keyName(82) == "↑", "Arrow label incorrect")
        print("PASS: corrupt-data fallback, lock flags and key labels")
        print("PASS: local keyboard shortcut regression checks")
    }
}
