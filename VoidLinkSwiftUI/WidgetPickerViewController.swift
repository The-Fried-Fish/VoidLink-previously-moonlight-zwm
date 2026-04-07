import SwiftUI
import UIKit

@available(iOS 13.0, *)
@objc public protocol WidgetPickerViewControllerDelegate: AnyObject {
    func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary)
    @objc optional func widgetPickerViewControllerDidCancel(_ controller: WidgetPickerViewController)
}

@available(iOS 13.0, *)
@objcMembers
public final class WidgetPickerViewController: UIViewController {
    public weak var delegate: WidgetPickerViewControllerDelegate?
    public var isEditMode: Bool = false
    public var initialCmdString: String?
    public var initialButtonLabel: String?
    public var initialShape: String?
    public var tabIdentifiers: [String] = []
    public var initialTabIdentifier: String?
    public var keyboardPickerMode: VirtualKeyboardMode = .picker
    public var shortcutPickerTipText: String?
    @objc public var shortcutIdentifier: String?

    private var hostingViewController: UIHostingController<WidgetPickerView>?

    public override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let rootView = WidgetPickerView(
            isEditMode: isEditMode,
            initialCmdString: initialCmdString,
            initialButtonLabel: initialButtonLabel,
            initialShape: initialShape,
            availableTabs: resolvedTabs(),
            preferredInitialTab: resolvedInitialTab(),
            keyboardPickerMode: keyboardPickerMode,
            shortcutPickerTipText: shortcutPickerTipText,
            shortcutIdentififier: shortcutIdentifier,
            onWidgetCreated: { [weak self] payload in
                guard let self else { return }
                self.delegate?.widgetPickerViewController(self, didCreateWidget: payload as NSDictionary)
                self.dismiss(animated: true)
            },
            onCloseRequested: { [weak self] in
                self?.dismiss(animated: true)
            }
        )
        let hostingViewController = UIHostingController(rootView: rootView)
        self.hostingViewController = hostingViewController

        addChild(hostingViewController)
        hostingViewController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingViewController.view)
        hostingViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            hostingViewController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            hostingViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        preferredContentSize = CGSize(width: 1120, height: 760)
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }

    private func resolvedTabs() -> [WidgetPickerTab] {
        let tabs = tabIdentifiers.compactMap(WidgetPickerTab.init(identifier:))
        return tabs.isEmpty ? WidgetPickerTab.allCases : tabs
    }

    private func resolvedInitialTab() -> WidgetPickerTab? {
        guard let initialTabIdentifier else { return nil }
        return WidgetPickerTab(identifier: initialTabIdentifier)
    }
}
