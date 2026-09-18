//
//  ToolboxViewController.swift
//  VoidLink
//
//  Created by True砖家 on 2024/7/23.
//  Copyright © 2024 True砖家 on Bilibili. All rights reserved.
//

import UIKit

@objc protocol ToolboxSpecialEntryDelegate: NSObjectProtocol {
    @objc optional func openWidgetLayoutTool()
    @objc optional func openWidgetProfileTable(pickProfile: Bool)
    @objc optional func bringUpSoftKeyboard()
    @objc optional func enterPip()
    @objc optional func toggleStatsOverlay()
    @objc optional func disconnectAndQuitApp()
}

#if os(tvOS)
private protocol ToolboxWidgetPickerDelegateConformance {}
#else
private typealias ToolboxWidgetPickerDelegateConformance = WidgetPickerViewControllerDelegate
#endif

@objc public class ToolboxViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, ToolboxWidgetPickerDelegateConformance {

    private enum ToolboxEntry {
        case special(id: String, title: String)
        case command(offset: Int, command: RemoteCommand)

        var isSpecial: Bool {
            if case .special = self { return true }
            return false
        }

        var orderIdentifier: String {
            switch self {
            case .special(let id, _):
                return "special:\(id)"
            case .command(_, let command):
                return "command:\(command.identifier)"
            }
        }
    }

    private enum Metrics {
        static let contentCornerRadius: CGFloat = 22
        static let cardCornerRadius: CGFloat = 16
        static let buttonCornerRadius: CGFloat = 13
    }

    private static let entryOrderDefaultsKey = "ToolboxViewController.entryOrder"
    private static let controllerNavigationHighlightDefaultsKey = "ToolboxViewController.controllerNavigationHighlightedEntry"

    @objc weak var specialEntryDelegate: ToolboxSpecialEntryDelegate?

    // Kept for Objective-C/source compatibility with older callers. The UI is now collectionView.
    public let tableView = UITableView(frame: .zero)
    public private(set) var collectionView: UICollectionView!

    private let addButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let editButton = UIButton(type: .system)
    private let pinButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let toolbarView = UIView()
    private let toolbarStackView = UIStackView()
    private var contentView = UIView()
    private var pinButtonWidthConstraint: NSLayoutConstraint?
    private var layoutConstraints: [NSLayoutConstraint] = []
    private var toolbarButtonConstraints: [NSLayoutConstraint] = []
    private var pendingTransitionSize: CGSize?

    @objc public var specialEntries: NSMutableArray = ["widgetSwitchTool", "widgetLayoutTool", "bringUpSoftKeyboard", "enterPip", "toggleStatsOverlay", "disconnectAndQuitApp"]
    private let specialEntryAliasDic: [String: String] = [
        "widgetSwitchTool": "=toolboxSwitchProfile",
        "widgetLayoutTool": "=toolboxWidgetLayout",
        "bringUpSoftKeyboard": "=toolboxSoftKeyboard",
        "enterPip": "=enterPiP",
        "toggleStatsOverlay": "=toolboxStatsOverlay",
        "disconnectAndQuitApp": "=toolboxDisconnectQuit"
    ]

    private var entries: [ToolboxEntry] = []
    private var viewPinned = false
    private var selectedCommandOffsets = Set<Int>()
    private var lastSelectedCommandOffset: Int?
    private var controllerNavigationReorderActive = false
    private var controllerNavigationReorderUpdateInFlight = false
    private var pendingControllerNavigationReorderMove: (horizontal: Int, vertical: Int)?
    private var controllerNavigationReorderSnapshotView: UIView?
    private var controllerNavigationReorderHiddenIndexPath: IndexPath?
    private var controllerNavigationReorderPressBeganAt: CFTimeInterval?
    private var controllerNavigationPersistOrderWhenReorderSettles = false
    private var controllerNavigationDeleteDoublePressWindowOpen = false
    private var controllerNavigationDeleteDoublePressToken = 0
    private var controllerNavigationExecuteDismissWindowOpen = false
    private var controllerNavigationExecuteDismissToken = 0
    private var controllerNavigationExecuteSuppressNextRelease = false
    private var pendingSpecialEntryToken = 0
    private var isEditingMode = false {
        didSet {
            if !isEditingMode {
                selectedCommandOffsets.removeAll()
            }
            updateEditingMode()
            collectionView?.reloadData()
        }
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupConstraints()
        reloadTableView()

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.delegate = self
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCollectionLongPress(_:)))
        longPress.minimumPressDuration = 0.25
        collectionView.addGestureRecognizer(longPress)

        CommandManager.shared.viewController = self
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if #available(iOS 13.0, *), ControllerUtil.primaryGCController != nil {
            ControllerNavigator.setUINavigationDelegate(self)
            ControllerNavigator.restoreUINavigationHighlight()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if #available(iOS 13.0, *) {
            if controllerNavigationReorderActive {
                controllerNavigationReorderActive = false
                pendingControllerNavigationReorderMove = nil
            }
            controllerNavigationReorderUpdateInFlight = false
            controllerNavigationPersistOrderWhenReorderSettles = false
            closeControllerNavigationDeleteDoublePressWindow()
            closeControllerNavigationExecuteDismissWindow()
            controllerNavigationExecuteSuppressNextRelease = false
            controllerNavigationReorderSnapshotView?.removeFromSuperview()
            controllerNavigationReorderSnapshotView = nil
            controllerNavigationReorderHiddenIndexPath = nil
            updateVisibleReorderHiddenCells()
            persistControllerNavigationHighlight()
            ControllerNavigator.restorePreviousUINavigationDelegate(ifCurrentDelegateIs: self)
        }
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        pendingTransitionSize = size
        setupConstraints()
        coordinator.animate(alongsideTransition: { _ in
            self.updatePinVisibility()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.pendingTransitionSize = nil
            self.setupConstraints()
            self.updatePinVisibility()
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.view.layoutIfNeeded()
        })
    }

    private func setupViews() {
        view.backgroundColor = .clear

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerRadius = Metrics.contentCornerRadius
        contentView.layer.masksToBounds = true
        view.addSubview(contentView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "Toolbox".localized
        titleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 18 : 24, weight: .bold)
        titleLabel.textAlignment = .center

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 11 : 13, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.75

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = gridSpacing()
        layout.minimumLineSpacing = gridSpacing()

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = collectionSurfaceColor()
        collectionView.layer.cornerRadius = PublicUtils.isIPhone ? 14 : 18
        collectionView.layer.masksToBounds = true
        collectionView.alwaysBounceVertical = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.allowsSelection = true
        collectionView.allowsMultipleSelection = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.register(ToolboxCardCell.self, forCellWithReuseIdentifier: ToolboxCardCell.reuseIdentifier)

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.layer.cornerRadius = Metrics.buttonCornerRadius
        toolbarView.layer.masksToBounds = true

        toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarStackView.axis = .horizontal
        toolbarStackView.alignment = .fill
        toolbarStackView.distribution = .fill
        toolbarStackView.spacing = PublicUtils.isIPhone ? 6 : 8

        configureToolbarButton(pinButton, title: "", symbolName: "pin")
        configureToolbarButton(deleteButton, title: "Delete".localized, symbolName: "minus.circle")
        configureToolbarButton(addButton, title: "Add".localized, symbolName: "plus.circle")
        configureToolbarButton(editButton, title: "Edit".localized, symbolName: "pencil")

        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        pinButton.addTarget(self, action: #selector(pinButtonTapped), for: .touchUpInside)

        contentView.addSubview(collectionView)
        contentView.addSubview(toolbarView)
        toolbarView.addSubview(toolbarStackView)
        [pinButton, deleteButton, addButton, editButton].forEach(toolbarStackView.addArrangedSubview)

        updateTheme()
        updatePinVisibility()
        updateEditingMode()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateTheme()
        collectionView.visibleCells.forEach { cell in
            (cell as? ToolboxCardCell)?.applyTheme()
        }
    }

    private func updateTheme() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        contentView.backgroundColor = darkMode
            ? UIColor(white: 0.09, alpha: 0.88)
            : UIColor(white: 0.94, alpha: 0.8)
        toolbarView.backgroundColor = darkMode
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 1.0, alpha: 0.41)
        titleLabel.textColor = darkMode ? .white : UIColor(white: 0.08, alpha: 1)
        subtitleLabel.textColor = darkMode ? UIColor(white: 1, alpha: 0.54) : UIColor(white: 0, alpha: 0.46)
        collectionView?.backgroundColor = collectionSurfaceColor()
        updateToolbarColors()
    }

    private func updateToolbarColors() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let normalTint = darkMode ? UIColor(white: 1, alpha: 0.86) : UIColor(white: 0.10, alpha: 0.86)
        let disabledTint = darkMode ? UIColor(white: 1, alpha: 0.25) : UIColor(white: 0, alpha: 0.24)

        [addButton, deleteButton, editButton, pinButton].forEach { button in
            button.tintColor = button.isEnabled ? normalTint : disabledTint
            button.setTitleColor(button.isEnabled ? normalTint : disabledTint, for: .normal)
            button.backgroundColor = .clear
        }

        if viewPinned {
            pinButton.tintColor = UIColor.systemOrange
            pinButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(darkMode ? 0.24 : 0.18)
        }
    }

    @objc public func setupConstraints() {
        NSLayoutConstraint.deactivate(layoutConstraints)
        layoutConstraints.removeAll()

        let topInset: CGFloat = PublicUtils.isIPhone ? 10 : 18
        let sideInset: CGFloat = PublicUtils.isIPhone ? 10 : 18
        let toolbarVerticalInset: CGFloat = PublicUtils.isIPhone ? 5 : 11
        let toolbarHeight: CGFloat = PublicUtils.isIPhone ? 36 : 54

        layoutConstraints = [
            contentView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: contentWidthMultiplier()),
            contentView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: PublicUtils.isIPhone ? 0.93 : 0.93),
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            contentView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
            toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -toolbarVerticalInset),
            toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight),

            toolbarStackView.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: PublicUtils.isIPhone ? 6 : 8),
            toolbarStackView.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor, constant: PublicUtils.isIPhone ? -6 : -8),
            toolbarStackView.topAnchor.constraint(equalTo: toolbarView.topAnchor, constant: PublicUtils.isIPhone ? 3 : 8),
            toolbarStackView.bottomAnchor.constraint(equalTo: toolbarView.bottomAnchor, constant: PublicUtils.isIPhone ? -3 : -8),

            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
            collectionView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: topInset),
            collectionView.bottomAnchor.constraint(equalTo: toolbarView.topAnchor, constant: -toolbarVerticalInset),
        ]
        
        if PublicUtils.isIPhone {
            layoutConstraints.append(contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 3))
        }
        else {
            layoutConstraints.append(contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor))
        }

        NSLayoutConstraint.activate(layoutConstraints)

        setupToolbarConstraints()
    }

    private func setupToolbarConstraints() {
        NSLayoutConstraint.deactivate(toolbarButtonConstraints)
        toolbarButtonConstraints.removeAll()

        [editButton, deleteButton, pinButton, addButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        let pinWidth: CGFloat = PublicUtils.isIPhone ? 44 : 52

        pinButtonWidthConstraint = pinButton.widthAnchor.constraint(equalToConstant: pinWidth)

        toolbarButtonConstraints = [
            deleteButton.widthAnchor.constraint(equalTo: editButton.widthAnchor),
            pinButtonWidthConstraint!,
            addButton.widthAnchor.constraint(equalTo: editButton.widthAnchor),
        ]
        NSLayoutConstraint.activate(toolbarButtonConstraints)
    }

    private func contentWidthMultiplier() -> CGFloat {
        if PublicUtils.isIPhone {
            return isLayoutLandscape() ? 0.62 : 0.88
        }
        return isLayoutLandscape() ? 0.595 : 0.86
    }

    private func isLayoutLandscape() -> Bool {
        if let pendingTransitionSize {
            return pendingTransitionSize.width > pendingTransitionSize.height
        }
        return PublicUtils.viewIsLandscape(view)
    }

    private func gridSpacing() -> CGFloat {
        return PublicUtils.isIPhone ? 8 : 12
    }

    private func gridInsets() -> UIEdgeInsets {
        let inset = PublicUtils.isIPhone ? 2.0 : 4.0
        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }

    private func collectionSurfaceColor() -> UIColor {
        if traitCollection.userInterfaceStyle == .dark {
            return UIColor(white: 1.0, alpha: 0.035)
        }
        return UIColor(white: 1.0, alpha: 0.18)
    }

    private func columnCount(for width: CGFloat) -> Int {
        #if os(tvOS)
        return width >= 780 ? 4 : 3
        #else
        if PublicUtils.isIPhone {
            return isLayoutLandscape() ? 3 : 2
        }
        return width >= 760 ? 4 : 3
        #endif
    }

    private func makeEntries() -> [ToolboxEntry] {
        let specialEntries = specialEntries.compactMap { value -> ToolboxEntry? in
            guard let id = value as? String else { return nil }
            let title = specialEntryAliasDic[id] ?? id
            return .special(id: id, title: title)
        }

        let commandEntries = CommandManager.shared.getAllCommands().enumerated().map {
            ToolboxEntry.command(offset: $0.offset, command: $0.element)
        }

        let defaultEntries = specialEntries + commandEntries
        guard let persistedOrder = UserDefaults.standard.stringArray(forKey: Self.entryOrderDefaultsKey),
              !persistedOrder.isEmpty else {
            return defaultEntries
        }

        let entriesByID = Dictionary(uniqueKeysWithValues: defaultEntries.map { ($0.orderIdentifier, $0) })
        var usedIDs = Set<String>()
        var orderedEntries: [ToolboxEntry] = []

        for identifier in persistedOrder {
            guard let entry = entriesByID[identifier],
                  !usedIDs.contains(identifier) else {
                continue
            }
            orderedEntries.append(entry)
            usedIDs.insert(identifier)
        }

        for entry in defaultEntries where !usedIDs.contains(entry.orderIdentifier) {
            orderedEntries.append(entry)
        }

        return orderedEntries
    }

    private func entriesPreservingCurrentOrder(includeMissingEntries: Bool) -> [ToolboxEntry] {
        let currentOrder = entries.map(\.orderIdentifier)
        let specialEntries = specialEntries.compactMap { value -> ToolboxEntry? in
            guard let id = value as? String else { return nil }
            let title = specialEntryAliasDic[id] ?? id
            return .special(id: id, title: title)
        }
        let commandEntries = CommandManager.shared.getAllCommands().enumerated().map {
            ToolboxEntry.command(offset: $0.offset, command: $0.element)
        }
        let latestEntries = specialEntries + commandEntries
        let latestEntriesByID = Dictionary(uniqueKeysWithValues: latestEntries.map { ($0.orderIdentifier, $0) })

        var usedIDs = Set<String>()
        var reconciledEntries: [ToolboxEntry] = []

        for identifier in currentOrder {
            guard let entry = latestEntriesByID[identifier],
                  !usedIDs.contains(identifier) else {
                continue
            }
            reconciledEntries.append(entry)
            usedIDs.insert(identifier)
        }

        if includeMissingEntries {
            for entry in latestEntries where !usedIDs.contains(entry.orderIdentifier) {
                reconciledEntries.append(entry)
            }
        }

        return reconciledEntries
    }

    private func configureToolbarButton(_ button: UIButton, title: String, symbolName: String) {
        button.layer.cornerRadius = Metrics.buttonCornerRadius
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 11 : 15, weight: .semibold)
        button.setTitle(title, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: PublicUtils.isIPhone ? 8 : 11, bottom: 0, right: PublicUtils.isIPhone ? 8 : 12)

        let toolbarImage: UIImage?
        
        if #available(iOS 13.0, tvOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: PublicUtils.isIPhone ? 9 : 11, weight: .semibold)
            toolbarImage = UIImage(systemName: symbolName, withConfiguration: config) ?? UIImage(named: symbolName)
        } else {
            toolbarImage = UIImage(named: symbolName)
        }

        if let image = toolbarImage {
            button.setImage(image, for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -2, bottom: 0, right: title.isEmpty ? -2 : 6)
        }
    }

    private func updateEditingMode() {
        collectionView?.allowsMultipleSelection = isEditingMode
        addButton.isEnabled = isEditingMode
        deleteButton.isEnabled = isEditingMode && !selectedCommandOffsets.isEmpty
        editButton.setTitle(isEditingMode ? "Done".localized : "Edit".localized, for: .normal)
        subtitleLabel.text = isEditingMode
            ? "Select shortcuts to delete".localized
            : "Tap a card to send a command".localized
        updateToolbarColors()
    }

    private func updatePinVisibility() {
        let shouldHide = PublicUtils.isIPhone && !isLayoutLandscape()
        pinButton.isHidden = shouldHide
        pinButtonWidthConstraint?.constant = shouldHide ? 0 : (PublicUtils.isIPhone ? 44 : 52)
        toolbarStackView.setCustomSpacing(shouldHide ? 0 : toolbarStackView.spacing, after: deleteButton)
        toolbarStackView.setCustomSpacing(shouldHide ? 0 : toolbarStackView.spacing, after: pinButton)
    }

    @objc private func pinButtonTapped() {
        viewPinned.toggle()
        updateToolbarColors()
    }

#if !os(tvOS)
    @available(iOS 13.0, *)
    public func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary) {
        createEntry(cmdString: payload["cmdString"] as? String, alias: payload["buttonLabel"] as? String)
    }
#endif

    private func createEntry(cmdString: String?, alias: String?) {
        let cmdString = cmdString ?? ""
        let alias = alias ?? cmdString
        let previousOffset = lastSelectedCommandOffset
        let shouldPreserveEditingOrder = isEditingMode

        let newCommand = RemoteCommand(cmdString: cmdString, alias: alias)
        let addCommandSucceeded = CommandManager.shared.addCommand(newCommand)

        if addCommandSucceeded {
            if shouldPreserveEditingOrder {
                entries = entriesPreservingCurrentOrder(includeMissingEntries: true)
                collectionView.reloadData()
            }
            let newOffset = max(CommandManager.shared.getAllCommands().count - 1, 0)
            if isEditingMode {
                scrollToCommand(offset: newOffset)
            } else {
                selectCommand(offset: newOffset, scrollPosition: .centeredVertically)
            }
        } else if let previousOffset {
            if isEditingMode {
                scrollToCommand(offset: previousOffset)
            } else {
                selectCommand(offset: previousOffset, scrollPosition: .centeredVertically)
            }
        }
    }

    @objc private func addButtonTapped() {
#if !os(tvOS)
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = self
            pickerViewController.keyboardPickerMode = .shortcutPicker
            pickerViewController.shortcutPickerNeedAlias = true
            pickerViewController.tabIdentifiers = ["keyboard", "shortcuts"]
            pickerViewController.initialTabIdentifier = "keyboard"
            pickerViewController.presentOverFullScreen(from: self)
            return
        }
#endif

        let alert = UIAlertController(title: "New Command".localized, message: "Enter a new command and alias".localized, preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Command".localized }
        alert.addTextField { $0.placeholder = "Alias (optional)".localized }
        alert.textFields?[0].keyboardType = .asciiCapable
        alert.textFields?[0].autocorrectionType = .no
        alert.textFields?[0].spellCheckingType = .no
        alert.textFields?[1].keyboardType = .default
        alert.textFields?[1].autocorrectionType = .no
        alert.textFields?[1].spellCheckingType = .no

        let submitAction = UIAlertAction(title: "Add".localized, style: .default) { [unowned alert] _ in
            self.createEntry(cmdString: alert.textFields?[0].text ?? "", alias: alert.textFields?[1].text)
        }

        alert.addAction(submitAction)
        alert.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        present(alert, animated: true)
    }

    @objc private func deleteButtonTapped() {
        guard !selectedCommandOffsets.isEmpty else { return }

        let sortedOffsets = selectedCommandOffsets.sorted(by: >)
        sortedOffsets.forEach { CommandManager.shared.deleteCommand(at: $0) }

        let nextOffset = max((sortedOffsets.min() ?? 0) - 1, 0)
        selectedCommandOffsets.removeAll()
        entries = entriesPreservingCurrentOrder(includeMissingEntries: false)
        collectionView.reloadData()
        updateEditingMode()

        if CommandManager.shared.getAllCommands().indices.contains(nextOffset) {
            scrollToCommand(offset: nextOffset)
        }
    }

    @objc private func editButtonTapped() {
        if isEditingMode {
            persistEntryOrder()
        }
        isEditingMode.toggle()
    }

    @objc public func reloadTableView() {
        entries = makeEntries()
        collectionView?.reloadData()
        updateEditingMode()
    }

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return entries.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ToolboxCardCell.reuseIdentifier, for: indexPath)
        guard let cardCell = cell as? ToolboxCardCell else { return cell }

        configure(cardCell, at: indexPath)
        cardCell.isHidden = indexPath == controllerNavigationReorderHiddenIndexPath
        return cardCell
    }

    private func configure(_ cardCell: ToolboxCardCell, at indexPath: IndexPath) {
        let entry = entries[indexPath.item]
        switch entry {
        case .special(let id, let title):
            cardCell.configure(
                title: title.localized,
                subtitle: specialSubtitle(for: id),
                symbolName: specialSymbolName(for: id),
                kind: .special,
                selectedForEditing: false,
                editing: isEditingMode
            )
        case .command(let offset, let command):
            cardCell.configure(
                title: command.alias.localized,
                subtitle: command.cmdString,
                symbolName: "keyboard",
                kind: .command,
                selectedForEditing: selectedCommandOffsets.contains(offset),
                editing: isEditingMode
            )
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        activateEntry(at: indexPath)
    }

    private func activateEntry(at indexPath: IndexPath, dismissAfterAction: Bool = true) {
        guard entries.indices.contains(indexPath.item) else { return }
        let entryIdentifier = entries[indexPath.item].orderIdentifier
        activateEntry(withIdentifier: entryIdentifier, fallbackIndexPath: indexPath, dismissAfterAction: dismissAfterAction)
    }

    private func activateEntry(withIdentifier identifier: String, fallbackIndexPath: IndexPath? = nil, dismissAfterAction: Bool = true) {
        guard let item = entries.firstIndex(where: { $0.orderIdentifier == identifier }) else { return }
        let indexPath = IndexPath(item: item, section: 0)
        pendingSpecialEntryToken += 1

        switch entries[item] {
        case .special(let id, _):
            collectionView.deselectItem(at: fallbackIndexPath ?? indexPath, animated: false)
            if !isEditingMode {
                flashCell(at: indexPath)
                handleSpecialEntry(id: id)
            }

        case .command(let offset, let command):
            lastSelectedCommandOffset = offset
            if isEditingMode {
                if selectedCommandOffsets.contains(offset) {
                    selectedCommandOffsets.remove(offset)
                    collectionView.deselectItem(at: indexPath, animated: true)
                } else {
                    selectedCommandOffsets.insert(offset)
                }
                updateEditingMode()
                if let cell = collectionView.cellForItem(at: indexPath) as? ToolboxCardCell {
                    configure(cell, at: indexPath)
                }
            } else {
                flashCell(at: indexPath)
                sendKeyboardCommand(command)
                if dismissAfterAction && !viewPinned {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        guard self.presentingViewController != nil else { return }
                        self.dismiss(animated: false)
                    }
                }
            }
        }
    }

    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        guard entries.indices.contains(indexPath.item) else { return }
        guard case .command(let offset, _) = entries[indexPath.item] else { return }

        selectedCommandOffsets.remove(offset)
        updateEditingMode()
        if let cell = collectionView.cellForItem(at: indexPath) as? ToolboxCardCell {
            configure(cell, at: indexPath)
        }
    }

    public func collectionView(_ collectionView: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        guard entries.indices.contains(indexPath.item) else { return false }
        return !isEditingMode || !entries[indexPath.item].isSpecial
    }

    public func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        return isEditingMode && entries.indices.contains(indexPath.item)
    }

    public func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard isEditingMode,
              entries.indices.contains(sourceIndexPath.item),
              destinationIndexPath.item >= 0,
              destinationIndexPath.item <= entries.count else {
            return
        }

        let movedEntry = entries.remove(at: sourceIndexPath.item)
        let destination = min(destinationIndexPath.item, entries.count)
        entries.insert(movedEntry, at: destination)
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return gridInsets()
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return gridSpacing()
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return gridSpacing()
    }

    public func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets = gridInsets()
        let columns = columnCount(for: collectionView.bounds.width)
        let totalSpacing = CGFloat(columns - 1) * gridSpacing() + insets.left + insets.right
        let width = floor((collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        let height: CGFloat

        #if os(tvOS)
        height = max(118, width * 0.62)
        #else
        if PublicUtils.isIPhone {
            height = max(56, min(112, width * 0.59))
        } else {
            height = max(108, min(140, width * 0.68))
        }
        #endif

        return CGSize(width: width, height: height)
    }

    @objc private func handleCollectionLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard isEditingMode else { return }

        let location = gesture.location(in: collectionView)
        switch gesture.state {
        case .began:
            guard let indexPath = collectionView.indexPathForItem(at: location),
                  entries.indices.contains(indexPath.item) else {
                return
            }
            collectionView.beginInteractiveMovementForItem(at: indexPath)

        case .changed:
            collectionView.updateInteractiveMovementTargetPosition(location)

        case .ended:
            collectionView.endInteractiveMovement()

        default:
            collectionView.cancelInteractiveMovement()
        }
    }

    private func persistEntryOrder() {
        let orderedSpecialIDs = entries.compactMap { entry -> String? in
            if case .special(let id, _) = entry { return id }
            return nil
        }
        specialEntries = NSMutableArray(array: orderedSpecialIDs)

        let orderedCommandIDs = entries.compactMap { entry -> String? in
            if case .command(_, let command) = entry { return command.identifier }
            return nil
        }
        CommandManager.shared.reorderCommands(withIdentifiers: orderedCommandIDs)

        UserDefaults.standard.set(entries.map(\.orderIdentifier), forKey: Self.entryOrderDefaultsKey)
        entries = makeEntries()
    }

    private func selectCommand(offset: Int, scrollPosition: UICollectionView.ScrollPosition) {
        guard let item = entries.firstIndex(where: {
            if case .command(let entryOffset, _) = $0 { return entryOffset == offset }
            return false
        }) else { return }

        let indexPath = IndexPath(item: item, section: 0)
        lastSelectedCommandOffset = offset
        collectionView.selectItem(at: indexPath, animated: true, scrollPosition: scrollPosition)
    }

    private func scrollToCommand(offset: Int) {
        guard let item = entries.firstIndex(where: {
            if case .command(let entryOffset, _) = $0 { return entryOffset == offset }
            return false
        }) else { return }

        let indexPath = IndexPath(item: item, section: 0)
        lastSelectedCommandOffset = offset
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)
    }

    private func flashCell(at indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? ToolboxCardCell else { return }
        cell.flash()
    }

    private func specialSubtitle(for id: String) -> String {
        switch id {
        case "widgetSwitchTool":
            return "Profiles".localized
        case "widgetLayoutTool":
            return "Layout".localized
        case "bringUpSoftKeyboard":
            return "Keyboard".localized
        case "enterPip":
            return "PiP".localized
        case "toggleStatsOverlay":
            return "Stats".localized
        case "disconnectAndQuitApp":
            return "Session".localized
        default:
            return ""
        }
    }

    private func specialSymbolName(for id: String) -> String {
        switch id {
        case "widgetSwitchTool":
            return "square.grid.2x2"
        case "widgetLayoutTool":
            return "rectangle.and.pencil.and.ellipsis"
        case "bringUpSoftKeyboard":
            return "keyboard"
        case "enterPip":
            return "pip.enter"
        case "toggleStatsOverlay":
            return "chart.bar"
        case "disconnectAndQuitApp":
            return "power"
        default:
            return "square"
        }
    }

    private func handleSpecialEntry(id: String) {
        pendingSpecialEntryToken += 1
        let token = pendingSpecialEntryToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            guard self.pendingSpecialEntryToken == token else { return }
            self.dismiss(animated: false)

            switch id {
            case "widgetLayoutTool":
                self.specialEntryDelegate?.openWidgetLayoutTool?()
            case "widgetSwitchTool":
                self.specialEntryDelegate?.openWidgetProfileTable?(pickProfile: false)
            case "bringUpSoftKeyboard":
                self.specialEntryDelegate?.bringUpSoftKeyboard?()
            case "enterPip":
                self.specialEntryDelegate?.enterPip?()
            case "toggleStatsOverlay":
                self.specialEntryDelegate?.toggleStatsOverlay?()
            case "disconnectAndQuitApp":
                self.specialEntryDelegate?.disconnectAndQuitApp?()
            default:
                break
            }
        }
    }

    private func sendKeyboardCommand(_ cmd: RemoteCommand) {
        guard let keyboardCmdStrings = CommandManager.shared.extractAutoReleaseButtonStrings(from: cmd.cmdString) else { return }
        CommandManager.shared.sendAutoReleaseComboCommand(cmdStrings: keyboardCmdStrings)
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        return touch.view == view
    }

    @objc private func dismissSelf() {
        dismiss(animated: false)
    }
}

@available(iOS 13.0, *)
extension ToolboxViewController: ControllerCollectionNavigationDelegate {
    var controllerNavigationCollectionView: UICollectionView {
        collectionView
    }

    @objc func persistControllerNavigationHighlight() {
        guard !controllerNavigationReorderActive else { return }
        guard let indexPath = controllerNavigationCurrentIndexPathForControllerNavigator(),
              entries.indices.contains(indexPath.item) else {
            return
        }

        UserDefaults.standard.set(entries[indexPath.item].orderIdentifier, forKey: Self.controllerNavigationHighlightDefaultsKey)
    }

    @objc func restoreControllerNavigationHighlight() {
        guard ControllerNavigator.enabled, ControllerUtil.primaryGCController != nil else { return }

        PublicUtils.runOnMain { [weak self] in
            guard let self, !self.entries.isEmpty else {
                self?.clearCollectionControllerNavigationHighlightForControllerNavigator()
                return
            }

            let savedIdentifier = UserDefaults.standard.string(forKey: Self.controllerNavigationHighlightDefaultsKey)
            let item = savedIdentifier.flatMap { identifier in
                self.entries.firstIndex { $0.orderIdentifier == identifier }
            } ?? 0

            self.collectionView.layoutIfNeeded()
            self.controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: item, section: 0))
        }
    }

    @objc func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {
    }

    @objc func navigateByController(forward: Bool) {
        if controllerNavigationReorderActive {
            moveControllerNavigationHighlightedEntry(horizontalOffset: forward ? 1 : -1)
            return
        }

        controllerNavigationNavigateCollection(forward: forward)
    }

    @objc func navigateByController(downward: Bool) {
        if controllerNavigationReorderActive {
            moveControllerNavigationHighlightedEntry(verticalOffset: downward ? 1 : -1)
            return
        }

        controllerNavigationNavigateCollection(downward: downward)
    }

    @objc func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {
    }

    @objc func getNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .rightStick : .leftStick, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .abxy : .dpad, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "execute"))
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .a, action: "doublePressPinExecute"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .y, action: "holdToReorder"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .y, action: "doublePressToDelete"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadLeft : .x, action: "addEntry"))
        elements.append(ControllerNavigationElement(control: ControllerNavigator.radialMenuButtonPosition == .left ? .dpadDown : .b, action: "exit"))
        return elements
    }

    @objc func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        if navigation.action == "holdToReorder" {
            handleControllerNavigationReorderHold(pressed: pressed)
            return
        }

        if navigation.action == "execute" {
            handleControllerNavigationExecute(pressed: pressed)
            return
        }

        guard pressed else { return }
        
        if navigation.action == "addEntry" {
            DispatchQueue.main.async{ [weak self] in
                self?.addButtonTapped()
            }
        }
        
        if navigation.action == "exit" {
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.dismiss(animated: true)
            }
        }
    }

    private func handleControllerNavigationExecute(pressed: Bool) {
        if pressed {
            if controllerNavigationExecuteDismissWindowOpen {
                closeControllerNavigationExecuteDismissWindow()
                controllerNavigationExecuteSuppressNextRelease = true
                return
            }

            PublicUtils.runOnMain { [weak self] in
                guard let self,
                      let indexPath = self.controllerNavigationCurrentIndexPathForControllerNavigator() else {
                    return
                }

                self.activateEntry(at: indexPath, dismissAfterAction: false)
            }
            return
        }

        guard !controllerNavigationExecuteSuppressNextRelease else {
            controllerNavigationExecuteSuppressNextRelease = false
            return
        }

        guard !viewPinned else { return }
        openControllerNavigationExecuteDismissWindow()
    }

    private func openControllerNavigationExecuteDismissWindow() {
        controllerNavigationExecuteDismissWindowOpen = true
        controllerNavigationExecuteDismissToken += 1
        let token = controllerNavigationExecuteDismissToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self,
                  self.controllerNavigationExecuteDismissToken == token,
                  self.controllerNavigationExecuteDismissWindowOpen else {
                return
            }

            self.closeControllerNavigationExecuteDismissWindow()
            self.dismiss(animated: false)
        }
    }

    private func closeControllerNavigationExecuteDismissWindow() {
        controllerNavigationExecuteDismissWindowOpen = false
        controllerNavigationExecuteDismissToken += 1
    }

    private func handleControllerNavigationReorderHold(pressed: Bool) {
        if pressed {
            if controllerNavigationDeleteDoublePressWindowOpen {
                controllerNavigationDeleteDoublePressWindowOpen = false
                controllerNavigationDeleteDoublePressToken += 1
                deleteControllerNavigationHighlightedCommand()
                return
            }

            guard let currentIndexPath = controllerNavigationCurrentIndexPathForControllerNavigator() else { return }
            controllerNavigationReorderPressBeganAt = CACurrentMediaTime()
            controllerNavigationReorderActive = true
            beginControllerNavigationReorderSnapshot(at: currentIndexPath)
            controllerNavigationSelectedIndexPath = currentIndexPath
            return
        }

        let pressDuration = controllerNavigationReorderPressBeganAt.map { CACurrentMediaTime() - $0 } ?? .greatestFiniteMagnitude
        controllerNavigationReorderPressBeganAt = nil

        guard controllerNavigationReorderActive else { return }
        controllerNavigationReorderActive = false
        pendingControllerNavigationReorderMove = nil
        controllerNavigationPersistOrderWhenReorderSettles = true
        if pressDuration <= 0.2 {
            openControllerNavigationDeleteDoublePressWindow()
        } else {
            closeControllerNavigationDeleteDoublePressWindow()
        }
        guard !controllerNavigationReorderUpdateInFlight else { return }
        persistEntryOrder()
        controllerNavigationPersistOrderWhenReorderSettles = false
        endControllerNavigationReorderSnapshot()
        restoreControllerNavigationHighlight()
        persistControllerNavigationHighlight()
    }

    private func openControllerNavigationDeleteDoublePressWindow() {
        controllerNavigationDeleteDoublePressWindowOpen = true
        controllerNavigationDeleteDoublePressToken += 1
        let token = controllerNavigationDeleteDoublePressToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self,
                  self.controllerNavigationDeleteDoublePressToken == token else {
                return
            }

            self.controllerNavigationDeleteDoublePressWindowOpen = false
        }
    }

    private func closeControllerNavigationDeleteDoublePressWindow() {
        controllerNavigationDeleteDoublePressWindowOpen = false
        controllerNavigationDeleteDoublePressToken += 1
    }

    private func deleteControllerNavigationHighlightedCommand() {
        guard let indexPath = controllerNavigationCurrentIndexPathForControllerNavigator(),
              entries.indices.contains(indexPath.item),
              case .command(let offset, _) = entries[indexPath.item] else {
            return
        }

        closeControllerNavigationDeleteDoublePressWindow()
        controllerNavigationReorderActive = false
        pendingControllerNavigationReorderMove = nil
        controllerNavigationPersistOrderWhenReorderSettles = false
        endControllerNavigationReorderSnapshot()
        clearAllControllerNavigationHighlightsForReorder()

        CommandManager.shared.deleteCommand(at: offset)
        selectedCommandOffsets.remove(offset)
        entries = entriesPreservingCurrentOrder(includeMissingEntries: false)
        persistEntryOrder()
        collectionView.reloadData()
        updateEditingMode()

        guard !entries.isEmpty else { return }

        let targetItem = min(indexPath.item, entries.count - 1)
        let targetIndexPath = IndexPath(item: targetItem, section: 0)
        collectionView.layoutIfNeeded()
        controllerNavigationHighlightItemForControllerNavigator(at: targetIndexPath)
        persistControllerNavigationHighlight()
    }

    private func moveControllerNavigationHighlightedEntry(horizontalOffset: Int) {
        guard !controllerNavigationReorderUpdateInFlight else {
            pendingControllerNavigationReorderMove = (horizontalOffset, 0)
            return
        }

        guard let currentIndexPath = controllerNavigationCurrentIndexPathForControllerNavigator() else { return }
        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 1 else { return }

        let nextItem = min(max(currentIndexPath.item + horizontalOffset, 0), itemCount - 1)
        guard nextItem != currentIndexPath.item else { return }

        moveControllerNavigationHighlightedEntry(from: currentIndexPath, to: IndexPath(item: nextItem, section: currentIndexPath.section))
    }

    private func moveControllerNavigationHighlightedEntry(verticalOffset: Int) {
        guard !controllerNavigationReorderUpdateInFlight else {
            pendingControllerNavigationReorderMove = (0, verticalOffset)
            return
        }

        guard let currentIndexPath = controllerNavigationCurrentIndexPathForControllerNavigator() else { return }
        guard let destinationIndexPath = controllerNavigationReorderDestination(from: currentIndexPath, verticalOffset: verticalOffset) else { return }

        moveControllerNavigationHighlightedEntry(from: currentIndexPath, to: destinationIndexPath)
    }

    private func controllerNavigationReorderDestination(from currentIndexPath: IndexPath, verticalOffset: Int) -> IndexPath? {
        let itemCount = collectionView.numberOfItems(inSection: 0)
        guard itemCount > 1,
              let currentAttributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: currentIndexPath) else {
            return nil
        }

        let currentCenter = currentAttributes.center
        let candidates = (0..<itemCount).compactMap { item -> (indexPath: IndexPath, attributes: UICollectionViewLayoutAttributes)? in
            let indexPath = IndexPath(item: item, section: 0)
            guard indexPath != currentIndexPath,
                  let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else {
                return nil
            }

            let isTargetDirection = verticalOffset > 0
                ? attributes.center.y > currentCenter.y + 1
                : attributes.center.y < currentCenter.y - 1
            return isTargetDirection ? (indexPath, attributes) : nil
        }

        return candidates.min { lhs, rhs in
            let lhsVerticalDistance = abs(lhs.attributes.center.y - currentCenter.y)
            let rhsVerticalDistance = abs(rhs.attributes.center.y - currentCenter.y)
            if abs(lhsVerticalDistance - rhsVerticalDistance) > 0.5 {
                return lhsVerticalDistance < rhsVerticalDistance
            }

            let lhsHorizontalDistance = abs(lhs.attributes.center.x - currentCenter.x)
            let rhsHorizontalDistance = abs(rhs.attributes.center.x - currentCenter.x)
            if abs(lhsHorizontalDistance - rhsHorizontalDistance) > 0.5 {
                return lhsHorizontalDistance < rhsHorizontalDistance
            }

            return verticalOffset > 0
                ? lhs.indexPath.item < rhs.indexPath.item
                : lhs.indexPath.item > rhs.indexPath.item
        }?.indexPath
    }

    private func moveControllerNavigationHighlightedEntry(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.section == 0,
              destinationIndexPath.section == 0,
              entries.indices.contains(sourceIndexPath.item),
              entries.indices.contains(destinationIndexPath.item) else {
            return
        }

        controllerNavigationReorderUpdateInFlight = true
        pendingControllerNavigationReorderMove = nil
        clearAllControllerNavigationHighlightsForReorder()
        controllerNavigationReorderHiddenIndexPath = sourceIndexPath
        updateVisibleReorderHiddenCells()

        let movedEntry = entries.remove(at: sourceIndexPath.item)
        entries.insert(movedEntry, at: destinationIndexPath.item)

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.clearAllControllerNavigationHighlightsForReorder()
            self.scrollToControllerNavigationReorderItemIfNeeded(at: destinationIndexPath, animated: true)
            self.updateControllerNavigationReorderSnapshotFrame(to: destinationIndexPath, animated: true)
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.07)
            self.collectionView.performBatchUpdates {
                self.collectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
            } completion: { [weak self] _ in
                guard let self else { return }
                self.clearAllControllerNavigationHighlightsForReorder()
                self.scrollToControllerNavigationReorderItemIfNeeded(at: destinationIndexPath, animated: false)
                self.updateControllerNavigationReorderSnapshotFrame(to: destinationIndexPath, animated: false)
                self.controllerNavigationReorderHiddenIndexPath = destinationIndexPath
                self.updateVisibleReorderHiddenCells()
                self.controllerNavigationSelectedIndexPath = destinationIndexPath
                self.controllerNavigationReorderUpdateInFlight = false

                if self.consumePendingControllerNavigationReorderMoveIfNeeded() {
                    return
                }

                if self.controllerNavigationPersistOrderWhenReorderSettles {
                    self.persistEntryOrder()
                    self.controllerNavigationPersistOrderWhenReorderSettles = false
                }

                guard !self.controllerNavigationReorderActive else { return }
                self.endControllerNavigationReorderSnapshot()
                self.controllerNavigationHighlightItemForControllerNavigator(at: destinationIndexPath)
                self.persistControllerNavigationHighlight()
            }
            CATransaction.commit()
        }
    }

    private func beginControllerNavigationReorderSnapshot(at indexPath: IndexPath) {
        clearAllControllerNavigationHighlightsForReorder()
        controllerNavigationReorderSnapshotView?.removeFromSuperview()

        collectionView.layoutIfNeeded()
        guard let cell = collectionView.cellForItem(at: indexPath),
              let snapshot = cell.snapshotView(afterScreenUpdates: true) else {
            return
        }

        snapshot.frame = cell.frame
        snapshot.layer.cornerRadius = Metrics.cardCornerRadius
        snapshot.layer.masksToBounds = true
        snapshot.layer.borderWidth = 3
        snapshot.layer.borderColor = UIColor.systemOrange.withAlphaComponent(ThemeManager.userInterfaceStyle() == .dark ? 0.8 : 0.97).cgColor
        snapshot.alpha = 1
        snapshot.transform = .identity
        snapshot.layer.zPosition = 1000

        collectionView.addSubview(snapshot)
        controllerNavigationReorderSnapshotView = snapshot
        controllerNavigationReorderHiddenIndexPath = indexPath
        updateVisibleReorderHiddenCells()
    }

    private func scrollToControllerNavigationReorderItemIfNeeded(at indexPath: IndexPath, animated: Bool) {
        guard indexPath.section < collectionView.numberOfSections,
              indexPath.item >= 0,
              indexPath.item < collectionView.numberOfItems(inSection: indexPath.section) else {
            return
        }

        collectionView.scrollToItem(at: indexPath, at: [.centeredHorizontally, .centeredVertically], animated: animated)
        collectionView.layoutIfNeeded()
    }

    private func updateControllerNavigationReorderSnapshotFrame(to indexPath: IndexPath, animated: Bool) {
        guard let snapshot = controllerNavigationReorderSnapshotView else { return }

        collectionView.layoutIfNeeded()
        guard let attributes = collectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else { return }

        let updates = {
            snapshot.center = attributes.center
            snapshot.bounds.size = attributes.bounds.size
        }

        if animated {
            UIView.animate(withDuration: 0.07, delay: 0, options: [.beginFromCurrentState, .curveEaseInOut], animations: updates)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
                self?.updateControllerNavigationReorderSnapshotFrame(to: indexPath, animated: false)
            }
        } else {
            updates()
        }
    }

    private func endControllerNavigationReorderSnapshot() {
        guard let snapshot = controllerNavigationReorderSnapshotView else { return }
        controllerNavigationReorderSnapshotView = nil
        controllerNavigationReorderHiddenIndexPath = nil
        updateVisibleReorderHiddenCells()
        UIView.animate(withDuration: 0.12, animations: {
            snapshot.alpha = 0
            snapshot.transform = .identity
        }) { _ in
            snapshot.removeFromSuperview()
        }
    }

    private func clearAllControllerNavigationHighlightsForReorder() {
        invalidateCollectionControllerNavigationHighlightForControllerNavigator()
        collectionView.visibleCells.forEach { cell in
            (cell as? ToolboxCardCell)?.clearControllerNavigationHighlight()
        }
    }

    private func updateVisibleReorderHiddenCells() {
        collectionView.visibleCells.forEach { cell in
            guard let indexPath = collectionView.indexPath(for: cell) else {
                cell.isHidden = false
                return
            }

            cell.isHidden = indexPath == controllerNavigationReorderHiddenIndexPath
        }
    }

    @discardableResult
    private func consumePendingControllerNavigationReorderMoveIfNeeded() -> Bool {
        guard controllerNavigationReorderActive,
              !controllerNavigationReorderUpdateInFlight,
              let pendingMove = pendingControllerNavigationReorderMove else {
            pendingControllerNavigationReorderMove = nil
            return false
        }

        pendingControllerNavigationReorderMove = nil

        if pendingMove.horizontal != 0 {
            moveControllerNavigationHighlightedEntry(horizontalOffset: pendingMove.horizontal)
            return true
        }

        if pendingMove.vertical != 0 {
            moveControllerNavigationHighlightedEntry(verticalOffset: pendingMove.vertical)
            return true
        }

        return false
    }
}

private final class ToolboxCardCell: UICollectionViewCell, ControllerNavigationHighlightTargetProviding {
    enum Kind {
        case special
        case command
    }

    static let reuseIdentifier = "ToolboxCardCell"

    private let symbolView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkmarkView = UIImageView()
    private let disabledOverlay = UIView()
    private let highlightOverlayView = UIView()
    private var kind: Kind = .command
    private var selectedForEditing = false
    private var editing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    override var canBecomeFocused: Bool {
        return false
    }

    var controllerNavigationHighlightTargetView: UIView {
        highlightOverlayView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isHidden = false
        selectedForEditing = false
        editing = false
        disabledOverlay.isHidden = true
        checkmarkView.isHidden = true
        clearControllerNavigationHighlight()
        contentView.transform = .identity
    }

    func configure(title: String, subtitle: String, symbolName: String, kind: Kind, selectedForEditing: Bool, editing: Bool) {
        self.kind = kind
        self.selectedForEditing = selectedForEditing
        self.editing = editing

        titleLabel.text = title
        subtitleLabel.text = subtitle
        if #available(iOS 13.0, tvOS 13.0, *) {
            symbolView.image = UIImage(systemName: symbolName) ?? UIImage(named: symbolName)
        } else {
            symbolView.image = UIImage(named: symbolName)
        }
        disabledOverlay.isHidden = !(editing && kind == .special)
        checkmarkView.isHidden = !(editing && kind == .command)
        checkmarkView.alpha = selectedForEditing ? 1 : 0.28
        if #available(iOS 13.0, tvOS 13.0, *) {
            checkmarkView.image = UIImage(systemName: selectedForEditing ? "checkmark.circle.fill" : "circle")
        } else {
            checkmarkView.image = nil
        }

        applyTheme()
    }

    func applyTheme() {
        let darkMode = traitCollection.userInterfaceStyle == .dark
        let special = kind == .special

        if selectedForEditing {
            contentView.backgroundColor = UIColor.systemOrange.withAlphaComponent(darkMode ? 0.34 : 0.24)
            contentView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.90).cgColor
            contentView.layer.borderWidth = 1.5
        } else {
            contentView.backgroundColor = special
                ? (darkMode ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 1, alpha: 0.72))
            // : (darkMode ? UIColor(red: 0.27, green: 0.23, blue: 0.13, alpha: 0.90) : UIColor(red: 1.00, green: 0.94, blue: 0.62, alpha: 0.88))
            : .clear
            contentView.layer.borderColor = special
                ? (darkMode ? UIColor(white: 1, alpha: 0.18).cgColor : UIColor(white: 1, alpha: 0.88).cgColor)
                : UIColor.systemOrange.withAlphaComponent(darkMode ? 0.45 : 0.6).cgColor
            contentView.layer.borderWidth = special ? 1.0 : 1.2
        }

        titleLabel.textColor = darkMode ? .white : UIColor(white: 0.10, alpha: 1)
        subtitleLabel.textColor = darkMode ? UIColor(white: 1, alpha: 0.56) : UIColor(white: 0, alpha: 0.50)
        symbolView.tintColor = special
            ? (darkMode ? UIColor(white: 1, alpha: 0.82) : UIColor(white: 0.12, alpha: 0.72))
            : UIColor.systemOrange
        checkmarkView.tintColor = UIColor.systemOrange
        disabledOverlay.backgroundColor = darkMode ? UIColor(white: 0, alpha: 0.36) : UIColor(white: 1, alpha: 0.48)
    }

    func controllerNavigationHighlightDidClear() {
        applyTheme()
    }

    func controllerNavigationHighlightDidApply() {
        guard kind == .special else { return }
        contentView.layer.borderWidth = 0
        contentView.layer.borderColor = nil
    }

    func clearControllerNavigationHighlight() {
        highlightOverlayView.layer.borderWidth = 0
        highlightOverlayView.layer.borderColor = nil
        applyTheme()
    }

    func flash() {
        UIView.animate(withDuration: 0.08, animations: {
            self.contentView.transform = CGAffineTransform(scaleX: 0.97, y: 0.97)
        }) { _ in
            UIView.animate(withDuration: 0.16) {
                self.contentView.transform = .identity
            }
        }
    }

    private func setupViews() {
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true

        symbolView.translatesAutoresizingMaskIntoConstraints = false
        symbolView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 13 : 15, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.66
        titleLabel.lineBreakMode = .byTruncatingTail

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        if #available(iOS 13.0, tvOS 13.0, *) {
            subtitleLabel.font = UIFont.monospacedSystemFont(ofSize: PublicUtils.isIPhone ? 10 : 12, weight: .medium)
        } else {
            subtitleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 10 : 12, weight: .medium)
        }
        subtitleLabel.numberOfLines = 1
        subtitleLabel.adjustsFontSizeToFitWidth = true
        subtitleLabel.minimumScaleFactor = 0.6

        checkmarkView.translatesAutoresizingMaskIntoConstraints = false
        disabledOverlay.translatesAutoresizingMaskIntoConstraints = false
        disabledOverlay.isUserInteractionEnabled = false
        highlightOverlayView.translatesAutoresizingMaskIntoConstraints = false
        highlightOverlayView.isUserInteractionEnabled = false
        highlightOverlayView.backgroundColor = .clear
        highlightOverlayView.layer.cornerRadius = 16
        highlightOverlayView.layer.masksToBounds = true

        contentView.addSubview(symbolView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(checkmarkView)
        contentView.addSubview(disabledOverlay)
        contentView.addSubview(highlightOverlayView)

        let iconSize: CGFloat = PublicUtils.isIPhone ? 24 : 30
        let sidePadding: CGFloat = PublicUtils.isIPhone ? 10 : 14
        let topPadding: CGFloat = PublicUtils.isIPhone ? 9 : 12

        NSLayoutConstraint.activate([
            symbolView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            symbolView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topPadding),
            symbolView.widthAnchor.constraint(equalToConstant: iconSize),
            symbolView.heightAnchor.constraint(equalToConstant: iconSize),

            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            checkmarkView.centerYAnchor.constraint(equalTo: symbolView.centerYAnchor),
            checkmarkView.widthAnchor.constraint(equalToConstant: iconSize),
            checkmarkView.heightAnchor.constraint(equalToConstant: iconSize),

            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sidePadding),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sidePadding),
            titleLabel.topAnchor.constraint(equalTo: symbolView.bottomAnchor, constant: PublicUtils.isIPhone ? 6 : 10),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 3),
            subtitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -topPadding),

            disabledOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            disabledOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            disabledOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            disabledOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            highlightOverlayView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            highlightOverlayView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            highlightOverlayView.topAnchor.constraint(equalTo: contentView.topAnchor),
            highlightOverlayView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        applyTheme()
    }

    #if os(tvOS)
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.contentView.transform = self.isFocused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
        }
    }
    #endif
}
