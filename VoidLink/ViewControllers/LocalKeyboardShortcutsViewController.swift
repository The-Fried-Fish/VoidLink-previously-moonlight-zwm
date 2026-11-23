//
//  LocalKeyboardShortcutsViewController.swift
//  VoidLink
//

#if !os(tvOS)
import UIKit

@available(iOS 14.0, *)
final class LocalKeyboardShortcutsViewController: UITableViewController, UIAdaptivePresentationControllerDelegate {
    private let shortcuts: LocalKeyboardShortcuts
    private let actions = LocalKeyboardShortcutAction.configurableActions
    private weak var previousResponder: UIResponder?

    private init(shortcuts: LocalKeyboardShortcuts = .shared) {
        self.shortcuts = shortcuts
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    static func present(from presenter: UIViewController) {
        let controller = LocalKeyboardShortcutsViewController()
        controller.previousResponder = firstResponder(in: presenter.view.window ?? presenter.view)
        let navigation = LocalKeyboardShortcutNavigationController(rootViewController: controller)
        navigation.previousNavigationDelegate = ControllerNavigator.uiNavigationDelegate
        navigation.modalPresentationStyle = .formSheet
        navigation.preferredContentSize = CGSize(width: 520, height: 580)
        navigation.overrideUserInterfaceStyle = ThemeManager.overrideUserInterfaceStyle()
        presenter.present(navigation, animated: true) {
            navigation.presentationController?.delegate = controller
        }
    }

    private static func firstResponder(in view: UIView) -> UIResponder? {
        if view.isFirstResponder { return view }
        for child in view.subviews {
            if let responder = firstResponder(in: child) { return responder }
        }
        return nil
    }

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Local Keyboard Shortcuts".localized
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.accessibilityIdentifier = "localKeyboardShortcutsList"
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    @objc private func close() {
        let responder = previousResponder
        dismiss(animated: true) { responder?.becomeFirstResponder() }
    }

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        previousResponder?.becomeFirstResponder()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? actions.count : 2
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 0
            ? "These settings change local actions only. They do not change how VoidLink forwards keyboard input.".localized
            : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .subheadline)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.textColor = .secondaryLabel
        if indexPath.section == 0 {
            let action = actions[indexPath.row]
            let binding = shortcuts.binding(for: action)
            cell.textLabel?.text = action.titleKey.localized
            cell.detailTextLabel?.text = binding.isEnabled ? binding.displayName : "Disabled".localized
            cell.accessibilityIdentifier = "localKeyboardShortcut-\(action.storageKey)"
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = (indexPath.row == 0 ? "Disable All Shortcuts" : "Restore Default Shortcuts").localized
            cell.textLabel?.textColor = view.tintColor
            cell.accessibilityIdentifier = indexPath.row == 0 ? "disableAllLocalShortcuts" : "restoreLocalShortcutDefaults"
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 {
            if indexPath.row == 0 {
                shortcuts.disableAll()
                tableView.reloadData()
            } else {
                let alert = UIAlertController(title: "Restore Default Shortcuts?".localized,
                    message: "This replaces all custom local keyboard shortcuts.".localized, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
                alert.addAction(UIAlertAction(title: "Restore Defaults".localized, style: .destructive) { [weak self] _ in
                    self?.shortcuts.restoreDefaults()
                    self?.tableView.reloadData()
                })
                present(alert, animated: true)
            }
            return
        }

        let action = actions[indexPath.row]
        let detail = LocalKeyboardShortcutActionViewController(action: action, shortcuts: shortcuts,
            onRecord: { [weak self] in self?.recordShortcut(for: action) },
            save: { [weak self] binding in
                guard let self else { return "Shortcut Not Changed".localized }
                return self.save(binding, for: action)
            })
        navigationController?.pushViewController(detail, animated: true)
    }

    private func save(_ binding: LocalKeyboardShortcutBinding, for action: LocalKeyboardShortcutAction) -> String? {
        do {
            try shortcuts.setBinding(binding, for: action)
            tableView.reloadData()
            return nil
        } catch {
            return errorMessage(error)
        }
    }

    private func errorMessage(_ error: Error) -> String {
        if case let LocalKeyboardShortcutError.conflict(other) = error {
            return LocalizationHelper.localizedString(forKey: "This shortcut is already assigned to %@.", other.titleKey.localized)
        }
        return "Choose a keyboard key rather than a modifier on its own.".localized
    }

    private func recordShortcut(for action: LocalKeyboardShortcutAction) {
        let recorder = LocalKeyboardShortcutRecorder(action: action) { [weak self] binding in
            guard let self else { return "Shortcut Not Changed".localized }
            return self.save(binding, for: action)
        }
        navigationController?.pushViewController(recorder, animated: true)
    }
}

/// A full page keeps every action reachable at accessibility text sizes.
@available(iOS 14.0, *)
private final class LocalKeyboardShortcutActionViewController: UITableViewController {
    private let action: LocalKeyboardShortcutAction
    private let shortcuts: LocalKeyboardShortcuts
    private let onRecord: () -> Void
    private let save: (LocalKeyboardShortcutBinding) -> String?
    private var errorMessage: String?

    init(action: LocalKeyboardShortcutAction, shortcuts: LocalKeyboardShortcuts,
         onRecord: @escaping () -> Void, save: @escaping (LocalKeyboardShortcutBinding) -> String?) {
        self.action = action
        self.shortcuts = shortcuts
        self.onRecord = onRecord
        self.save = save
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = action.titleKey.localized
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 56
        tableView.accessibilityIdentifier = "localKeyboardShortcutActions"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        errorMessage = nil
        tableView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 2 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 0 ? 1 : 3 }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        section == 1 ? errorMessage : nil
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let binding = shortcuts.binding(for: action)
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .subheadline)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.textColor = .secondaryLabel
        if indexPath.section == 0 {
            cell.textLabel?.text = action.titleKey.localized
            cell.detailTextLabel?.text = binding.isEnabled ? binding.displayName : "Disabled".localized
            cell.accessibilityIdentifier = "localKeyboardShortcutCurrent-\(action.storageKey)"
            cell.selectionStyle = .none
        } else {
            let titles = ["Record Shortcut", binding.isEnabled ? "Disable Shortcut" : "Enable Shortcut", "Restore Default"]
            let identifiers = ["localKeyboardShortcutRecord", "localKeyboardShortcutToggle", "localKeyboardShortcutReset"]
            cell.textLabel?.text = titles[indexPath.row].localized
            cell.textLabel?.textColor = view.tintColor
            cell.accessibilityIdentifier = identifiers[indexPath.row]
            cell.accessibilityTraits.insert(.button)
            if indexPath.row == 0 { cell.accessoryType = .disclosureIndicator }
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.section == 1 else { return }
        if indexPath.row == 0 {
            onRecord()
            return
        }
        var binding = shortcuts.binding(for: action)
        if indexPath.row == 1 { binding.isEnabled.toggle() }
        else { binding = .defaultBinding(for: action) }
        errorMessage = save(binding)
        tableView.reloadData()
        if let errorMessage {
            tableView.layoutIfNeeded()
            tableView.scrollRectToVisible(tableView.rectForFooter(inSection: 1), animated: true)
            UIAccessibility.post(notification: .announcement, argument: errorMessage)
        }
    }
}

/// The whole modal owns controller focus, including pushes and temporary alerts.
@available(iOS 14.0, *)
private final class LocalKeyboardShortcutNavigationController: UINavigationController, ControllerUINavigationDelegate {
    // Alert controllers also borrow navigation. Keep the original owner separately.
    weak var previousNavigationDelegate: ControllerUINavigationDelegate?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ControllerNavigator.setUINavigationDelegate(self)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if ControllerNavigator.uiNavigationDelegate === self {
            ControllerNavigator.setUINavigationDelegate(previousNavigationDelegate)
        }
    }

    func getNavigationElements() -> [ControllerNavigationElement] { [] }
    func navigateByController(forward: Bool) {}
    func navigateByController(downward: Bool) {}
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {}
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {}
    func persistControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlight() {}
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {}
}

@available(iOS 14.0, *)
private final class LocalKeyboardShortcutRecorder: UIViewController {
    private let action: LocalKeyboardShortcutAction
    private let save: (LocalKeyboardShortcutBinding) -> String?
    private let errorLabel = UILabel()
    private let scrollView = UIScrollView()

    init(action: LocalKeyboardShortcutAction, save: @escaping (LocalKeyboardShortcutBinding) -> String?) {
        self.action = action
        self.save = save
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Record Shortcut".localized
        view.backgroundColor = .systemGroupedBackground
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
        let titleLabel = UILabel()
        titleLabel.text = action.titleKey.localized
        titleLabel.font = .preferredFont(forTextStyle: .title2)
        let instruction = UILabel()
        instruction.text = "Press the new shortcut on your hardware keyboard. System-reserved shortcuts may not reach VoidLink.".localized
        instruction.font = .preferredFont(forTextStyle: .body)
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.textColor = .systemRed
        errorLabel.accessibilityIdentifier = "localKeyboardShortcutRecordingError"
        for label in [titleLabel, instruction, errorLabel] {
            label.textAlignment = .center
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        let stack = UIStackView(arrangedSubviews: [titleLabel, instruction, errorLabel])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        let content = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.accessibilityIdentifier = "localKeyboardShortcutRecordingContent"
        view.addSubview(scrollView)
        scrollView.addSubview(content)
        content.addSubview(stack)
        let viewportHeight = content.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        viewportHeight.priority = .defaultLow
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            viewportHeight,
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor)
        ])
        view.accessibilityIdentifier = "localKeyboardShortcutRecorder"
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    @objc private func cancel() {
        navigationController?.popViewController(animated: true)
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let keys = presses.compactMap(\.key).filter { (4..<224).contains(Int($0.keyCode.rawValue)) }
        guard keys.count == 1, let key = keys.first else { return }
        let code = Int(key.keyCode.rawValue)
        var binding = LocalKeyboardShortcutBinding(keyCode: code,
            modifiers: UInt(key.modifierFlags.rawValue) & LocalKeyboardShortcutBinding.modifierMask,
            isEnabled: true)
        // Preserve the recorded layout's printable label, not a US-layout guess.
        let label = key.charactersIgnoringModifiers.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if (4...56).contains(code), !label.isEmpty, label.count <= 8,
           !label.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) {
            binding.keyLabel = label
        }
        if let error = save(binding) {
            errorLabel.text = error
            view.layoutIfNeeded()
            scrollView.scrollRectToVisible(errorLabel.convert(errorLabel.bounds, to: scrollView), animated: true)
            UIAccessibility.post(notification: .announcement, argument: error)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }

    // Recording must not forward the captured chord or its releases to a stream.
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {}
}
#endif
