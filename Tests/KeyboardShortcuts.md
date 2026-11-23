# Local keyboard shortcuts

Open **Settings > Peripherals > Local Keyboard Shortcuts** on iPhone or iPad.
Select an action to open its scrollable configuration page. From there, record
a hardware-keyboard shortcut, enable or disable it, or restore its default.
Changes are saved in device-local preferences immediately.

## Defaults

| Local action | Default |
| --- | --- |
| Disconnect stream | Control + Option + Shift + D |
| Toggle statistics overlay | Control + Option + Shift + O |
| Open settings | Control + Option + Shift + S |
| Toggle mouse capture | Control + Option + Shift + M |
| Toggle mouse visibility | Control + Option + Shift + C |
| Disconnect and quit the host app | Control + Option + Shift + Q |

Bindings use physical USB keyboard usages. Recorded printable labels reflect
that keyboard's layout. Default labels use their existing US key names.
Modifier matching considers Control, Option, Shift and Command. Lock and
numeric-keypad metadata do not change the match.

An enabled shortcut cannot duplicate another enabled local action. Recording,
re-enabling or restoring a conflicting assignment leaves both assignments
unchanged and explains the conflict. Disabled assignments can overlap.

**Disable All Shortcuts** disables these six local actions while retaining the
assignments. **Restore Default Shortcuts** removes their overrides after
confirmation. Other input behavior, including existing Option-arrow handling,
is outside this configuration.

This feature changes local action selection, not the stream's keyboard
forwarding. Disabling a shortcut removes its local action. OS-reserved
shortcuts might never reach the app. Key events used in the recording screen
are configuration input, not stream input.

## Model regression tests

On macOS with Xcode or its command-line tools installed:

```sh
./Tests/run-keyboard-shortcuts-tests.sh
```

The script compiles the production Foundation-only model with warnings treated
as errors. It uses an isolated preferences domain and removes that domain
when the checks finish. Coverage includes:

- All six defaults and ordinary/unassigned keys.
- Rebinding and reading saved preferences through a new store.
- Recorded keyboard-layout labels.
- Duplicate rejection without changing either assignment.
- Disable, re-enable conflicts, disable all and restore defaults.
- Invalid keys, unsupported flags, malformed preferences and lock flags.

These tests do not build the app, drive UIKit or prove remote key delivery.

## Manual acceptance checks

Run these checks with the real app before claiming end-to-end acceptance:

1. Open the shortcut screen from Peripherals, both before and during a stream.
2. Check the six default assignments and their existing local actions.
3. Record a new chord. Reopen the screen and relaunch the app to check persistence.
4. Attempt a duplicate chord. Check the error and both unchanged assignments.
5. Disable one action, then all actions. Check the host receives the intended
   down/up events without those local actions.
6. Enable a conflicting disabled assignment. Check the existing action remains
   enabled and the conflicting assignment stays disabled. Record an available
   chord next and check that the previous validation error disappears.
7. Check individual reset, cancelled global reset and confirmed global reset.
8. Cancel recording and dismiss the screen. Check keyboard focus returns.
9. Check ordinary keys, modifier release orders, mixed press batches and touch
   controls during a stream.
10. Inspect iPhone and iPad layouts, light/dark appearance, large text and VoiceOver.
11. At the largest accessibility text size, scroll through the action page and
    recording instructions. Trigger a conflict and check that the full error is reachable.
12. With controller hints visible in Settings, open the shortcut screen. Check
    that the old hints disappear and return to the correct Settings context on dismissal.

Keep model tests, app compilation, visual checks and physical-device streaming
results separate in the contribution's verification report.
