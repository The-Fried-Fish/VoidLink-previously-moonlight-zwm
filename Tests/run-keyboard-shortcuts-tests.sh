#!/usr/bin/env bash
# Run Foundation-only production shortcut-model checks on macOS with Xcode.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
build=$(mktemp -d "${TMPDIR:-/tmp}/voidlink-shortcut-tests.XXXXXX")
trap 'rm -rf "$build"' EXIT
xcrun swiftc -warnings-as-errors -parse-as-library \
  "$root/VoidLink/Input/LocalKeyboardShortcuts.swift" \
  "$root/Tests/LocalKeyboardShortcutsTests.swift" \
  -o "$build/LocalKeyboardShortcutsTests"
"$build/LocalKeyboardShortcutsTests"
