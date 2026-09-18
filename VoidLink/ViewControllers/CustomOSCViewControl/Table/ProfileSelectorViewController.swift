//
//  ProfileSelectorViewController.swift
//  VoidLink
//
//  Created by True砖家 on 2026.7.28
//  Copyright © 2026 True砖家 on Bilibili. All rights reserved.
//

import Compression
import UIKit

#if os(tvOS)
private final class ProfileSelectorNoFocusWindow: UIWindow {
    override var canBecomeFocused: Bool {
        false
    }

    override func shouldUpdateFocus(in context: UIFocusUpdateContext) -> Bool {
        context.nextFocusedItem == nil
    }
}
#endif

private final class ProfileCollectionViewCell: UICollectionViewCell, ControllerNavigationHighlightTargetProviding {
    static let reuseIdentifier = "ProfileCollectionViewCell"

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let checkmarkLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    var controllerNavigationHighlightTargetView: UIView {
        contentView
    }

    private func setupViews() {
        contentView.layer.cornerRadius = PublicUtils.isIPhone ? 14 : 16
        contentView.layer.masksToBounds = true

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 15 : 18, weight: .semibold)
        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.72

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 10 : 12, weight: .medium)
        subtitleLabel.numberOfLines = 1

        checkmarkLabel.translatesAutoresizingMaskIntoConstraints = false
        checkmarkLabel.text = "✓"
        checkmarkLabel.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 20 : 24, weight: .bold)
        checkmarkLabel.textAlignment = .center
        checkmarkLabel.textColor = .systemGreen

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(checkmarkLabel)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: PublicUtils.isIPhone ? 10 : 14),
            titleLabel.trailingAnchor.constraint(equalTo: checkmarkLabel.leadingAnchor, constant: -8),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: PublicUtils.isIPhone ? 9 : 13),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            subtitleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: PublicUtils.isIPhone ? -8 : -11),

            checkmarkLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: PublicUtils.isIPhone ? -9 : -12),
            checkmarkLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkLabel.widthAnchor.constraint(equalToConstant: PublicUtils.isIPhone ? 24 : 30),
            checkmarkLabel.heightAnchor.constraint(equalTo: checkmarkLabel.widthAnchor),
        ])
    }

    func configure(title: String, selected: Bool, pickingData: Bool, userInterfaceStyle: UIUserInterfaceStyle) {
        let darkMode = userInterfaceStyle == .dark
        titleLabel.text = title
        subtitleLabel.text = selected && !pickingData ? "Selected".localized : "Profile".localized
        checkmarkLabel.isHidden = !selected || pickingData

        titleLabel.textColor = darkMode ? .white : UIColor(white: 0.08, alpha: 1)
        subtitleLabel.textColor = darkMode ? UIColor(white: 1, alpha: 0.5) : UIColor(white: 0, alpha: 0.45)
        
        if selected && !pickingData {
            /* contentView.backgroundColor = darkMode
                ? UIColor.systemGreen.withAlphaComponent(0.22)
                : UIColor.systemGreen.withAlphaComponent(0.16) */
            contentView.backgroundColor = darkMode ? .clear : .clear
            contentView.layer.borderWidth = darkMode ? 2 : 3
            contentView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.65).cgColor
        } else {
            /*
            contentView.backgroundColor = darkMode
                ? UIColor(white: 1.0, alpha: 0.075)
                : UIColor(white: 1.0, alpha: 0.56) */
            contentView.backgroundColor = darkMode ? .clear : .clear
            contentView.layer.borderWidth = 1
            contentView.layer.borderColor = darkMode
                ? UIColor(white: 1.0, alpha: 0.23).cgColor
                : UIColor(white: 0.0, alpha: 0.3).cgColor
        }
    }

    override var canBecomeFocused: Bool {
        return false
    }
}

@objc(FileOperation)
enum FileOperation: Int {
    case importOperation = 0
    case exportOperation = 1
}

private enum ProfileExportScope {
    case selectedProfile
    case allProfiles
}

private enum ProfilePayloadCompression: UInt8 {
    case none = 0
    case lzfse = 1
    case lz4 = 2
    case lzma = 3
    case zlib = 4

    var systemAlgorithm: compression_algorithm? {
        switch self {
        case .none:
            return nil
        case .lzfse:
            return COMPRESSION_LZFSE
        case .lz4:
            return COMPRESSION_LZ4
        case .lzma:
            return COMPRESSION_LZMA
        case .zlib:
            return COMPRESSION_ZLIB
        }
    }
}

enum ProfileFileContainer {
    private static let magic = Array("VLPR".utf8)
    private static let version: UInt8 = 1
    private static let headerSize = 14
    private static let defaultCompression: ProfilePayloadCompression = .lz4

    static func packedData(from payload: Data) -> Data {
        pack(payload, compression: defaultCompression)
    }

    static func unpackedData(from data: Data) throws -> Data {
        guard hasHeader(data) else {
            return data
        }

        let header = Array(data.prefix(headerSize))
        guard header[4] == version,
              let compression = ProfilePayloadCompression(rawValue: header[5]) else {
            throw NSError(domain: "ProfileFileContainer", code: 1)
        }

        let originalLength = UInt64(littleEndianBytes: Array(header[6..<14]))
        let payload = data.dropFirst(headerSize)

        guard let algorithm = compression.systemAlgorithm else {
            return Data(payload)
        }

        guard let unpacked = decompress(Data(payload), originalLength: Int(originalLength), algorithm: algorithm) else {
            throw NSError(domain: "ProfileFileContainer", code: 2)
        }

        return unpacked
    }

    private static func pack(_ payload: Data, compression: ProfilePayloadCompression) -> Data {
        guard let algorithm = compression.systemAlgorithm,
              let compressedPayload = compress(payload, algorithm: algorithm) else {
            return header(compression: .none, originalLength: payload.count) + payload
        }

        return header(compression: compression, originalLength: payload.count) + compressedPayload
    }

    private static func hasHeader(_ data: Data) -> Bool {
        data.count >= headerSize && Array(data.prefix(magic.count)) == magic
    }

    private static func header(compression: ProfilePayloadCompression, originalLength: Int) -> Data {
        var data = Data(magic)
        data.append(version)
        data.append(compression.rawValue)

        var length = UInt64(originalLength).littleEndian
        withUnsafeBytes(of: &length) { bytes in
            data.append(contentsOf: bytes)
        }

        return data
    }

    private static func compress(_ data: Data, algorithm: compression_algorithm) -> Data? {
        if data.isEmpty {
            return Data()
        }

        return data.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }

            var destinationSize = max(64, data.count + data.count / 16 + 64)
            let maximumDestinationSize = max(destinationSize, data.count * 4 + 1024)

            while destinationSize <= maximumDestinationSize {
                var destination = [UInt8](repeating: 0, count: destinationSize)
                let encodedCount = compression_encode_buffer(
                    &destination,
                    destinationSize,
                    source,
                    data.count,
                    nil,
                    algorithm
                )

                if encodedCount > 0 {
                    return Data(destination.prefix(encodedCount))
                }

                destinationSize *= 2
            }

            return nil
        }
    }

    private static func decompress(_ data: Data, originalLength: Int, algorithm: compression_algorithm) -> Data? {
        if originalLength == 0 {
            return Data()
        }

        return data.withUnsafeBytes { sourceBuffer in
            guard let source = sourceBuffer.bindMemory(to: UInt8.self).baseAddress else {
                return nil
            }

            var destination = [UInt8](repeating: 0, count: originalLength)
            let decodedCount = compression_decode_buffer(
                &destination,
                originalLength,
                source,
                data.count,
                nil,
                algorithm
            )

            guard decodedCount == originalLength else {
                return nil
            }

            return Data(destination)
        }
    }
}

private extension UInt64 {
    init(littleEndianBytes bytes: [UInt8]) {
        var value: UInt64 = 0
        for (index, byte) in bytes.enumerated() {
            value |= UInt64(byte) << UInt64(index * 8)
        }
        self = value
    }
}

@objc enum ProfileSelectorLoadingMode: Int {
    case selectProfileFromLayoutTool  
    case selectProfileFromStreamView
    case selectProfileFromMainFrame
    case pickProfile
    case pickProfileData
}

@objcMembers
final class ProfileSelectorViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIGestureRecognizerDelegate, ControllerUINavigationDelegate {

    var currentFileOperation: FileOperation = .importOperation
    private var currentExportScope: ProfileExportScope = .allProfiles
    var needToUpdateOscLayoutTVC: (() -> Void)?
    var loadingMode: ProfileSelectorLoadingMode = .selectProfileFromLayoutTool
    @nonobjc var pickedProfileDataHandler: ((OSCProfile) -> Void)?
    weak var currentOSCButtonLayers: NSMutableSet?
    var layoutViewBounds: CGRect = .zero

    private var profilesManager: OSCProfilesManager!
    private var horizontalConstraintsConfigured = false
    private(set) var profiles: NSMutableArray = []
    private(set) var selectedProfileIndex = 0
    private var profilesLoadGeneration = 0
    private var profileCollectionView: UICollectionView!
    private let contentView = UIView()
    private let toolbarView = UIView()
    private let toolbarStackView = UIStackView()
    private let duplicateButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let importButton = UIButton(type: .system)
    private let exportButton = UIButton(type: .system)
    private let restoreButton = UIButton(type: .system)
    private var panelConstraints: [NSLayoutConstraint] = []
    private var pendingTransitionSize: CGSize?
    private var presentationWindow: UIWindow?
    private var themeObserver: NSObjectProtocol?
    private var profileOrderChanged = false
    private var controllerNavigationReorderActive = false
    private var controllerNavigationReorderUpdateInFlight = false
    private var pendingControllerNavigationReorderMove: (horizontal: Int, vertical: Int)?
    private var controllerNavigationReorderSnapshotView: UIView?
    private var controllerNavigationReorderHiddenIndexPath: IndexPath?
    private var controllerNavigationPersistOrderWhenReorderSettles = false
    private var controllerNavigationReorderPressBeganAt: CFTimeInterval?
    private var controllerNavigationDeleteDoublePressWindowOpen = false
    private var controllerNavigationDeleteDoublePressToken = 0

    private func contentWidthMultiplier() -> CGFloat {
        isLayoutLandscape() ? (PublicUtils.isIPhone ? 0.62 : 0.595) : (PublicUtils.isIPhone ? 0.88 : 0.86)
    }

    private func updateHorizontalLayoutConstraints() {
        setupPanelConstraints()
    }

    private func isLayoutLandscape() -> Bool {
        if let pendingTransitionSize {
            return pendingTransitionSize.width > pendingTransitionSize.height
        }
        return PublicUtils.viewIsLandscape(view)
    }

#if !os(tvOS)
    private func getCurrentOrientation() -> UIInterfaceOrientationMask {
        let bounds = UIScreen.main.bounds
        if bounds.width > bounds.height {
            return .landscape
        } else {
            return [.portrait, .portraitUpsideDown]
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        getCurrentOrientation()
    }
#endif

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            persistProfileOrderIfNeeded(notify: false)
        }
        NotificationCenter.default.post(name: Notification.Name(PublicUtils.isTVOS ? "GameProfileSelectorCloseNotification" : "ProfileSelectorCloseNotification"), object: self)
        // tvOS launches profileSelector without layout editor
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if #available(iOS 13.0, *) {
            cancelControllerNavigationReorderIfNeeded()
            ControllerNavigator.restorePreviousUINavigationDelegate(ifCurrentDelegateIs: self)
        }
        if isBeingDismissed || navigationController?.isBeingDismissed == true {
            presentationWindow?.isHidden = true
            presentationWindow = nil
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        profilesManager = OSCProfilesManager.sharedManager(layoutViewBounds)
        observeThemeChanges()
        setupProfilePanel()
        updateHorizontalLayoutConstraints()
        horizontalConstraintsConfigured = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissSelf))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        view.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleCollectionLongPress(_:)))
        longPress.minimumPressDuration = 0.25
        profileCollectionView.addGestureRecognizer(longPress)

        reloadProfilesAsync(scrollToSelected: true)
    }

    deinit {
        removeThemeObserver()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { _ in
            self.pendingTransitionSize = size
            self.updateHorizontalLayoutConstraints()
            self.profileCollectionView?.collectionViewLayout.invalidateLayout()
            self.view.layoutIfNeeded()
        }, completion: { _ in
            self.pendingTransitionSize = nil
            self.updateHorizontalLayoutConstraints()
            self.profileCollectionView?.collectionViewLayout.invalidateLayout()
            self.view.layoutIfNeeded()
        })
    }

    @objc private func dismissSelf() {
        dismiss(animated: false)
    }

    @objc func presentInKeyWindow(animated: Bool) {
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve

        guard #available(iOS 13.0, *),
              let windowScene = UIApplication.shared.connectedScenes
                  .compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }) else {
            PublicUtils.topViewController()?.present(self, animated: animated)
            return
        }

#if os(tvOS)
        let window = ProfileSelectorNoFocusWindow(windowScene: windowScene)
#else
        let window = UIWindow(windowScene: windowScene)
#endif
        let rootViewController = UIViewController()
        rootViewController.view.backgroundColor = .clear
        window.rootViewController = rootViewController
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        window.isHidden = false
        window.makeKeyAndVisible()
        presentationWindow = window

        rootViewController.present(self, animated: animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !horizontalConstraintsConfigured {
            updateHorizontalLayoutConstraints()
            horizontalConstraintsConfigured = true
        }
        if profiles.count > 0 {
            scrollToSelectedProfile(animated: true)
            notifyProfileViewDidRefresh()
        } else {
            reloadProfilesAsync(scrollToSelected: true, notify: true)
        }
        
        if (loadingMode == .selectProfileFromMainFrame || loadingMode == .selectProfileFromStreamView)
            && ControllerUtil.primaryGCController != nil {
            if #available(iOS 13.0, *) {
                ControllerNavigator.setUINavigationDelegate(self)
            }
        }
    }

    private func setupProfilePanel() {
        view.subviews.forEach { $0.removeFromSuperview() }
        view.backgroundColor = .clear

        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.layer.cornerRadius = PublicUtils.isIPhone ? 18 : 22
        contentView.layer.masksToBounds = true
        view.addSubview(contentView)

        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = gridSpacing()
        layout.minimumLineSpacing = gridSpacing()

        profileCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        profileCollectionView.translatesAutoresizingMaskIntoConstraints = false
        profileCollectionView.backgroundColor = collectionSurfaceColor()
        profileCollectionView.layer.cornerRadius = PublicUtils.isIPhone ? 14 : 18
        profileCollectionView.layer.masksToBounds = true
        profileCollectionView.alwaysBounceVertical = true
        profileCollectionView.dataSource = self
        profileCollectionView.delegate = self
        profileCollectionView.allowsSelection = true
        profileCollectionView.contentInsetAdjustmentBehavior = .never
        profileCollectionView.register(ProfileCollectionViewCell.self, forCellWithReuseIdentifier: ProfileCollectionViewCell.reuseIdentifier)

        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        toolbarView.layer.cornerRadius = PublicUtils.isIPhone ? 13 : 16
        toolbarView.layer.masksToBounds = true

        toolbarStackView.translatesAutoresizingMaskIntoConstraints = false
        toolbarStackView.axis = .horizontal
        toolbarStackView.alignment = .fill
        toolbarStackView.distribution = .fillEqually
        toolbarStackView.spacing = PublicUtils.isIPhone ? 4 : 8

        configureToolbarButton(duplicateButton, title: "Duplicate".localized, symbolName: "plus.square.on.square")
        configureToolbarButton(deleteButton, title: "Delete".localized, symbolName: "minus.circle")
        configureToolbarButton(importButton, title: "Import".localized, symbolName: "square.and.arrow.down")
        configureToolbarButton(exportButton, title: "Export".localized, symbolName: "square.and.arrow.up")
        configureToolbarButton(restoreButton, title: "Restore".localized, symbolName: "arrow.counterclockwise")

        duplicateButton.addTarget(self, action: #selector(duplicateTapped(_:)), for: .touchUpInside)
        deleteButton.addTarget(self, action: #selector(deleteTapped(_:)), for: .touchUpInside)
        importButton.addTarget(self, action: #selector(importDataTapped(_:)), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportDataTapped(_:)), for: .touchUpInside)
        restoreButton.addTarget(self, action: #selector(restoreTapped(_:)), for: .touchUpInside)

        contentView.addSubview(profileCollectionView)
        contentView.addSubview(toolbarView)
        toolbarView.addSubview(toolbarStackView)
        [duplicateButton, deleteButton, importButton, exportButton, restoreButton].forEach(toolbarStackView.addArrangedSubview)

        updatePanelTheme()
        updateToolbarVisibility()
    }

    private func setupPanelConstraints() {
        guard profileCollectionView != nil else { return }

        NSLayoutConstraint.deactivate(panelConstraints)
        panelConstraints.removeAll()

        let sideInset: CGFloat = PublicUtils.isIPhone ? 10 : 18
        let topInset: CGFloat = PublicUtils.isIPhone ? 10 : 18
        let toolbarVerticalInset: CGFloat = PublicUtils.isIPhone ? 6 : 11
        let toolbarHeight: CGFloat = PublicUtils.isIPhone ? 38 : 54

        panelConstraints = [
            contentView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: contentWidthMultiplier()),
            contentView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: PublicUtils.isIPhone ? 0.93 : 0.93),
            contentView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            contentView.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),

            toolbarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
            toolbarView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
            toolbarView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -toolbarVerticalInset),
            toolbarView.heightAnchor.constraint(equalToConstant: toolbarHeight),

            toolbarStackView.leadingAnchor.constraint(equalTo: toolbarView.leadingAnchor, constant: PublicUtils.isIPhone ? 5 : 8),
            toolbarStackView.trailingAnchor.constraint(equalTo: toolbarView.trailingAnchor, constant: PublicUtils.isIPhone ? -5 : -8),
            toolbarStackView.topAnchor.constraint(equalTo: toolbarView.topAnchor, constant: PublicUtils.isIPhone ? 3 : 8),
            toolbarStackView.bottomAnchor.constraint(equalTo: toolbarView.bottomAnchor, constant: PublicUtils.isIPhone ? -3 : -8),

            profileCollectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: sideInset),
            profileCollectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -sideInset),
            profileCollectionView.topAnchor.constraint(equalTo: contentView.safeAreaLayoutGuide.topAnchor, constant: topInset),
            profileCollectionView.bottomAnchor.constraint(
                equalTo: toolbarView.isHidden ? contentView.bottomAnchor : toolbarView.topAnchor,
                constant: toolbarView.isHidden ? -toolbarVerticalInset : -toolbarVerticalInset
            ),
        ]
        
        if PublicUtils.isIPhone {
            panelConstraints.append(contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 3))
        }
        else {
            panelConstraints.append(contentView.centerYAnchor.constraint(equalTo: view.centerYAnchor))
        }

        
        NSLayoutConstraint.activate(panelConstraints)
    }

    private func updatePanelTheme() {
        let darkMode = currentUserInterfaceStyle() == .dark
        contentView.backgroundColor = darkMode
            ? UIColor(white: 0.09, alpha: loadingMode == .selectProfileFromMainFrame ? 0.92 : 0.88)
            : UIColor(white: 0.94, alpha: loadingMode == .selectProfileFromMainFrame ? 0.73 : 0.7)
        toolbarView.backgroundColor = darkMode
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 1.0, alpha: 0.5)
        profileCollectionView?.backgroundColor = collectionSurfaceColor()
        
        contentView.layer.borderColor = UIColor(white: 0.0, alpha: 0.3).cgColor
        contentView.layer.borderWidth = darkMode ? 0 : 0.5

        let tint = darkMode ? UIColor(white: 1, alpha: 0.86) : UIColor(white: 0.10, alpha: 0.86)
        [duplicateButton, deleteButton, importButton, exportButton, restoreButton].forEach { button in
            button.tintColor = tint
            button.setTitleColor(tint, for: .normal)
            button.backgroundColor = .clear
        }
    }

    private func updateToolbarVisibility() {
        let hidden = loadingMode == .pickProfileData
        toolbarView.isHidden = hidden
        setupPanelConstraints()
    }

    private func collectionSurfaceColor() -> UIColor {
        if currentUserInterfaceStyle() == .dark {
            // return UIColor(white: 1.0, alpha: 0)
            return .clear
        }
        return UIColor(white: 1.0, alpha: 0.18)
    }

    private func currentUserInterfaceStyle() -> UIUserInterfaceStyle {
        if #available(iOS 13.0, *) {
            return ThemeManager.userInterfaceStyle()
        }
        return .light
    }

    private func observeThemeChanges() {
        removeThemeObserver()
        themeObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(ThemeManager.ThemeDidChangeNotification),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleThemeDidChange()
        }
    }

    private func removeThemeObserver() {
        if let themeObserver {
            NotificationCenter.default.removeObserver(themeObserver)
            self.themeObserver = nil
        }
    }

    private func handleThemeDidChange() {
        updatePanelTheme()
        profileCollectionView?.reloadData()
    }

    private func gridSpacing() -> CGFloat {
        PublicUtils.isIPhone ? 8 : 12
    }

    private func gridInsets() -> UIEdgeInsets {
        let inset = PublicUtils.isIPhone ? 2.0 : 4.0
        return UIEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
    }

    private func columnCount(for width: CGFloat) -> Int {
        if PublicUtils.isIPhone {
            return isLayoutLandscape() ? 3 : 2
        }
        return width >= 760 ? 4 : 3
    }

    private func configureToolbarButton(_ button: UIButton, title: String, symbolName: String) {
        button.layer.cornerRadius = PublicUtils.isIPhone ? 11 : 13
        button.layer.masksToBounds = true
        button.titleLabel?.font = UIFont.systemFont(ofSize: PublicUtils.isIPhone ? 10 : 14, weight: .semibold)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.7
        button.setTitle(title, for: .normal)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: PublicUtils.isIPhone ? 4 : 8, bottom: 0, right: PublicUtils.isIPhone ? 4 : 8)

        if #available(iOS 13.0, tvOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: PublicUtils.isIPhone ? 9 : 11, weight: .semibold)
            let image = UIImage(systemName: symbolName, withConfiguration: config)
            button.setImage(image, for: .normal)
            button.imageView?.contentMode = .scaleAspectFit
            button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -1, bottom: 0, right: PublicUtils.isIPhone ? 3 : 6)
        }
    }

    private func reloadProfilesAsync(scrollToSelected: Bool = false, notify: Bool = false) {
        profilesLoadGeneration += 1
        let generation = profilesLoadGeneration
        let manager = profilesManager

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let manager else { return }

            let loadedProfiles = manager.getAllProfiles()
            let loadedSelectedIndex = Self.selectedProfileIndex(in: loadedProfiles)

            DispatchQueue.main.async { [weak self] in
                guard let self, generation == self.profilesLoadGeneration else { return }

                self.profiles = loadedProfiles
                self.selectedProfileIndex = loadedSelectedIndex
                self.profileCollectionView?.reloadData()

                if scrollToSelected {
                    self.scrollToSelectedProfile(animated: true)
                }

                if notify {
                    self.notifyProfileViewDidRefresh()
                }
            }
        }
    }

    private func scrollToSelectedProfile(animated: Bool) {
        guard let selectedProfileIndex = validProfileIndex(selectedProfileIndex) else {
            return
        }

        profileCollectionView?.scrollToItem(at: IndexPath(item: selectedProfileIndex, section: 0), at: .centeredVertically, animated: animated)
    }

    private func moveSelectedProfile(by offset: Int) {
        moveSelectedProfile(horizontalOffset: offset, verticalOffset: 0)
    }

    private func moveSelectedProfile(horizontalOffset: Int = 0, verticalOffset: Int = 0) {
        PublicUtils.runOnMain { [weak self] in
            guard let self,
                  self.profiles.count > 0,
                  self.profileCollectionView.numberOfSections > 0,
                  self.profileCollectionView.numberOfItems(inSection: 0) > 0 else {
                return
            }

            let maxIndex = min(self.profiles.count, self.profileCollectionView.numberOfItems(inSection: 0)) - 1
            let currentIndex = min(max(self.selectedProfileIndex, 0), maxIndex)
            let itemCount = maxIndex + 1
            let columnOffset: Int
            if verticalOffset == 0 {
                columnOffset = 0
            } else {
                let columns = max(1, self.columnCount(for: self.profileCollectionView.bounds.width))
                columnOffset = verticalOffset * columns
            }
            let rawNextIndex = currentIndex + horizontalOffset + columnOffset
            let nextIndex = (rawNextIndex % itemCount + itemCount) % itemCount
            guard nextIndex != currentIndex else {
                self.restoreControllerNavigationHighlight()
                return
            }

            let nextIndexPath = IndexPath(item: nextIndex, section: 0)

            self.profileCollectionView.selectItem(at: nextIndexPath, animated: true, scrollPosition: .centeredVertically)
            self.collectionView(self.profileCollectionView, didSelectItemAt: nextIndexPath)
            self.restoreControllerNavigationHighlight()
        }
    }

    private func validProfileIndex(_ index: Int) -> Int? {
        guard profiles.count > 0 else { return nil }
        return min(max(index, 0), profiles.count - 1)
    }

    private func notifyProfileViewDidRefresh() {
        needToUpdateOscLayoutTVC?()
        if loadingMode != .selectProfileFromStreamView
            && loadingMode != .pickProfile
            && loadingMode != .pickProfileData
            && loadingMode != .selectProfileFromLayoutTool
        {
            guard let selectedProfileIndex = validProfileIndex(selectedProfileIndex) else { return }
            NotificationCenter.default.post(name: Notification.Name("GameProfileSelectedNotification"), object: self.profiles[selectedProfileIndex])
        }
    }

    private func persistProfileOrderIfNeeded(notify: Bool) {
        guard profileOrderChanged else { return }
        profilesManager.persistProfileOrder(profiles)
        profileOrderChanged = false
        if notify {
            notifyProfileViewDidRefresh()
        }
    }

    private func markProfileSelectedLocally(at index: Int) {
        for i in 0..<profiles.count {
            guard let profile = profiles.object(at: i) as? OSCProfile else {
                continue
            }
            profile.isSelected = i == index
        }
        selectedProfileIndex = index
    }

    private static func selectedProfileIndex(in profiles: NSMutableArray) -> Int {
        for index in 0..<profiles.count {
            guard let profile = profiles.object(at: index) as? OSCProfile else {
                continue
            }

            if profile.isSelected {
                return index
            }
        }

        return 0
    }

    @IBAction func duplicateTapped(_ sender: Any?) {
        let inputAlert = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: "Enter the name you want to save this profile as"),
            message: "",
            preferredStyle: .alert
        )
        inputAlert.addTextField { textField in
            textField.placeholder = LocalizationHelper.localizedString(forKey: "name")
            if #available(iOS 13.0, *) {
                // textField.textColor = .label
            }
            textField.clearButtonMode = .whileEditing
            textField.borderStyle = .none
        }
        inputAlert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Cancel"), style: .default) { _ in
            inputAlert.dismiss(animated: false)
        })
        inputAlert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Save"), style: .default) { [weak self] _ in
            guard let self else { return }
            let enteredProfileName = inputAlert.textFields?.first?.text ?? ""

            if enteredProfileName == "Default" {
                let alert = UIAlertController(
                    title: "",
                    message: LocalizationHelper.localizedString(forKey: "Saving over the 'Default' profile is not allowed"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default) { _ in
                    alert.dismiss(animated: false) {
                        self.present(inputAlert, animated: true)
                    }
                })
                self.present(alert, animated: true)
            } else if enteredProfileName.isEmpty {
                let alert = UIAlertController(
                    title: "",
                    message: LocalizationHelper.localizedString(forKey: "Profile name cannot be blank!"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default) { _ in
                    alert.dismiss(animated: false) {
                        self.present(inputAlert, animated: true)
                    }
                })
                self.present(alert, animated: true)
            } else if self.profilesManager.profileNameAlreadyExist(enteredProfileName) {
                let alert = UIAlertController(
                    title: "",
                    message: LocalizationHelper.localizedString(forKey: "Profile name already exists"),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default))
                self.present(alert, animated: true)
            } else {
                self.profilesManager.duplicateSelectedProfile(withName: enteredProfileName)
                let alert = UIAlertController(
                    title: "",
                    message: LocalizationHelper.localizedString(forKey: "Profile %@ duplicated from current layout", enteredProfileName),
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default) { _ in
                    alert.dismiss(animated: false)
                    self.profileViewRefresh()
                })
                self.present(alert, animated: true)
            }
        })

        present(inputAlert, animated: true)
    }

    func profileViewRefresh() {
        reloadProfilesAsync(notify: true)
    }

    @IBAction func deleteTapped(_ sender: Any?) {
        profilesManager.deleteCurrentSelectedProfile()
        profileViewRefresh()
    }

    @IBAction func exportDataTapped(_ sender: Any?) {
        let alert = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: "Export"),
            message: nil,
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Current Profile"), style: .default) { [weak self] _ in
            self?.beginExport(scope: .selectedProfile)
        })
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "All Profiles"), style: .default) { [weak self] _ in
            self?.beginExport(scope: .allProfiles)
        })
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Cancel"), style: .cancel))

        if let popoverPresentationController = alert.popoverPresentationController {
            let sourceView = sender as? UIView ?? exportButton
            popoverPresentationController.sourceView = sourceView
            popoverPresentationController.sourceRect = sourceView.bounds
        }

        present(alert, animated: true)
    }

    private func beginExport(scope: ProfileExportScope) {
#if os(tvOS)
        _ = scope
#else
        currentFileOperation = .exportOperation
        currentExportScope = scope
        let tempPath = NSTemporaryDirectory().appending(exportFileName(for: scope))
        try? Data().write(to: URL(fileURLWithPath: tempPath), options: .atomic)

        let picker = UIDocumentPickerViewController(url: URL(fileURLWithPath: tempPath), in: .exportToService)
        picker.delegate = self
        present(picker, animated: true)
#endif
    }

    @IBAction func importDataTapped(_ sender: Any?) {
#if os(tvOS)
        _ = sender
#else
        currentFileOperation = .importOperation
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .open)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
#endif
    }

    @IBAction func restoreTapped(_ sender: Any?) {
        profilesManager.importDefaultTemplates()
        profileViewRefresh()
    }

#if !os(tvOS)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        switch currentFileOperation {
        case .exportOperation:
            profilesToFile(url)
        case .importOperation:
            fileToProfiles(url)
        }
    }
#endif

    private func profilesToFile(_ destinationURL: URL) {
        do {
            let payload = try NSKeyedArchiver.archivedData(withRootObject: encodedProfilesForExport(), requiringSecureCoding: true)
            let data = ProfileFileContainer.packedData(from: payload)
            let accessed = destinationURL.startAccessingSecurityScopedResource()
            defer {
                if accessed {
                    destinationURL.stopAccessingSecurityScopedResource()
                }
            }
            try data.write(to: destinationURL, options: .atomic)
        } catch {
            // NSLog("写入失败: \(error)")
        }
    }

    private func encodedProfilesForExport() -> NSMutableArray {
        switch currentExportScope {
        case .allProfiles:
            return profilesManager.getEncodedProfiles()
        case .selectedProfile:
            let encodedProfiles = NSMutableArray()
            guard let selectedProfileIndex = validProfileIndex(selectedProfileIndex),
                  let selectedProfile = profiles.object(at: selectedProfileIndex) as? OSCProfile,
                  let encodedProfile = try? NSKeyedArchiver.archivedData(withRootObject: selectedProfile, requiringSecureCoding: true) else {
                return encodedProfiles
            }
            encodedProfiles.add(encodedProfile)
            return encodedProfiles
        }
    }

    private func exportFileName(for scope: ProfileExportScope) -> String {
        switch scope {
        case .allProfiles:
            return "profiles.bin"
        case .selectedProfile:
            guard let selectedProfileIndex = validProfileIndex(selectedProfileIndex),
                  let selectedProfile = profiles.object(at: selectedProfileIndex) as? OSCProfile else {
                return "profile.bin"
            }
            return "\(sanitizedExportFileName(selectedProfile.name)).bin"
        }
    }

    private func sanitizedExportFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/\\?%*|\"<>:")
            .union(.newlines)
            .union(.controlCharacters)
        let sanitized = fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "profile" : sanitized
    }

    private func fileToProfiles(_ sourceURL: URL) {
        var restoreFailed = false
        let accessed = sourceURL.startAccessingSecurityScopedResource()
        if !accessed {
            restoreFailed = true
        }

        defer {
            if accessed {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let fileData = try Data(contentsOf: sourceURL)
            let profilePayloadData = try ProfileFileContainer.unpackedData(from: fileData)
            // NSLog("profile file read: \(UInt32(fileData.count))")
            let classes: [AnyClass] = [NSMutableData.self, NSMutableArray.self]
            let profilesEncoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: profilePayloadData) as? NSMutableArray

            let restoredAlert = UIAlertController(
                title: LocalizationHelper.localizedString(forKey: ""),
                message: LocalizationHelper.localizedString(forKey: "Pofiles imported"),
                preferredStyle: .alert
            )
            let failedAlert = UIAlertController(
                title: LocalizationHelper.localizedString(forKey: ""),
                message: LocalizationHelper.localizedString(forKey: "Failed to import profiles"),
                preferredStyle: .alert
            )
            let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default)

            if restoreFailed || profilesEncoded == nil {
                failedAlert.addAction(okAction)
                present(failedAlert, animated: true)
            } else {
                profilesManager.importEncodedProfiles(profilesEncoded!)
                restoredAlert.addAction(okAction)
                present(restoredAlert, animated: true)
            }

            profileViewRefresh()
            // NSLog("profile test: \(UInt32(profilesEncoded?.count ?? 0))")
        } catch {
            restoreFailed = true
            let failedAlert = UIAlertController(
                title: LocalizationHelper.localizedString(forKey: ""),
                message: LocalizationHelper.localizedString(forKey: "Failed to import profiles"),
                preferredStyle: .alert
            )
            failedAlert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default))
            present(failedAlert, animated: true)
            profileViewRefresh()
            // NSLog("解码失败: \(error)")
        }
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        profiles.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ProfileCollectionViewCell.reuseIdentifier, for: indexPath)
        cell.isHidden = false
        guard let profileCell = cell as? ProfileCollectionViewCell,
              indexPath.item < profiles.count,
              let profile = profiles.object(at: indexPath.item) as? OSCProfile else {
            return cell
        }

        profileCell.configure(
            title: profile.name.localizedProfileName,
            selected: indexPath.item == selectedProfileIndex,
            pickingData: loadingMode == .pickProfileData,
            userInterfaceStyle: currentUserInterfaceStyle()
        )
        cell.isHidden = indexPath == controllerNavigationReorderHiddenIndexPath
        return profileCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        activateProfile(at: indexPath.item)
    }

    func collectionView(_ collectionView: UICollectionView, canMoveItemAt indexPath: IndexPath) -> Bool {
        loadingMode != .pickProfileData && indexPath.item > 0 && indexPath.item < profiles.count
    }

    func collectionView(_ collectionView: UICollectionView, targetIndexPathForMoveFromItemAt originalIndexPath: IndexPath, toProposedIndexPath proposedIndexPath: IndexPath) -> IndexPath {
        if proposedIndexPath.item == 0 {
            return IndexPath(item: 1, section: proposedIndexPath.section)
        }
        return proposedIndexPath
    }

    func collectionView(_ collectionView: UICollectionView, moveItemAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard sourceIndexPath.item != destinationIndexPath.item,
              sourceIndexPath.item > 0,
              sourceIndexPath.item < profiles.count,
              destinationIndexPath.item > 0,
              destinationIndexPath.item < profiles.count else {
            return
        }

        let movedProfile = profiles.object(at: sourceIndexPath.item)
        profiles.removeObject(at: sourceIndexPath.item)
        profiles.insert(movedProfile, at: destinationIndexPath.item)
        selectedProfileIndex = Self.selectedProfileIndex(in: profiles)
        profileOrderChanged = true
    }

    @objc private func handleCollectionLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: profileCollectionView)

        switch gesture.state {
        case .began:
            guard loadingMode != .pickProfileData else {
                return
            }
            guard let indexPath = profileCollectionView.indexPathForItem(at: location),
                  indexPath.item > 0 else {
                return
            }
            profileCollectionView.beginInteractiveMovementForItem(at: indexPath)

        case .changed:
            profileCollectionView.updateInteractiveMovementTargetPosition(location)

        case .ended:
            profileCollectionView.endInteractiveMovement()

        default:
            profileCollectionView.cancelInteractiveMovement()
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        gridInsets()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        gridSpacing()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        gridSpacing()
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets = gridInsets()
        let columns = columnCount(for: collectionView.bounds.width)
        let totalSpacing = CGFloat(columns - 1) * gridSpacing() + insets.left + insets.right
        let width = floor((collectionView.bounds.width - totalSpacing) / CGFloat(columns))
        let height: CGFloat

        if PublicUtils.isIPhone {
            height = max(58, min(102, width * 0.58))
        } else {
            height = max(94, min(126, width * 0.62))
        }

        return CGSize(width: width, height: height)
    }

    private func activateProfile(at index: Int) {
        guard index >= 0,
              index < profiles.count else {
            return
        }

        if loadingMode == .pickProfileData,
           let pickedProfile = profiles.object(at: index) as? OSCProfile {
            pickedProfileDataHandler?(pickedProfile)
            dismiss(animated: false)
            return
        }

        let lastSelectedIndex = validProfileIndex(selectedProfileIndex)

        if index != lastSelectedIndex {
            markProfileSelectedLocally(at: index)
            if profileOrderChanged {
                profilesManager.persistProfileOrder(profiles)
                profileOrderChanged = false
            } else {
                profilesManager.setProfileToSelected(UInt32(index))
            }

            let itemsToReload = [lastSelectedIndex, selectedProfileIndex]
                .compactMap { $0 }
                .filter { $0 >= 0 && $0 < profileCollectionView.numberOfItems(inSection: 0) }
                .map { IndexPath(item: $0, section: 0) }
            if !itemsToReload.isEmpty {
                UIView.performWithoutAnimation {
                    profileCollectionView.reloadItems(at: itemsToReload)
                }
            }
        }

        if loadingMode == .pickProfile {
            notifyProfileViewDidRefresh()
            dismiss(animated: false)
        } else {
            profileViewRefresh()
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if (loadingMode != .selectProfileFromLayoutTool
            && loadingMode != .selectProfileFromMainFrame
            && loadingMode != .selectProfileFromStreamView
            ),
           let touchView = touch.view,
           touchView.isDescendant(of: profileCollectionView) {
            return true
        }
        return touch.view == view
    }
    
    @available(iOS 13.0, *)
    func getNavigationElements() -> [ControllerNavigationElement] {
        var elements: [ControllerNavigationElement] = []
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .rightStick : .leftStick, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .abxy : .dpad, action: "focusNavigation"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .y, action: "holdToReorder"))
        // elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadUp : .y, action: "doublePressToDelete"))
        elements.append(ControllerNavigationElement(control:ControllerNavigator.radialMenuButtonPosition == .left ? .dpadRight : .b, action: "exit"))
        return elements
    }
    
    func navigateByController(forward: Bool) {
        if controllerNavigationReorderActive {
            if #available(iOS 13.0, *) {
                moveControllerNavigationReorderedProfile(horizontalOffset: forward ? 1 : -1)
            }
            return
        }
        moveSelectedProfile(horizontalOffset: forward ? 1 : -1)
    }
    
    func navigateByController(downward: Bool) {
        if controllerNavigationReorderActive {
            if #available(iOS 13.0, *) {
                moveControllerNavigationReorderedProfile(verticalOffset: downward ? 1 : -1)
            }
            return
        }
        moveSelectedProfile(verticalOffset: downward ? 1 : -1)
    }

    func persistControllerNavigationHighlight() {}
    
    func restoreControllerNavigationHighlight() {
        guard #available(iOS 13.0, *) else { return }
        restoreSelectedProfileControllerNavigationHighlight()
    }
    
    func restoreControllerNavigationHighlightAfterSettingsModeSwitch() {
        restoreControllerNavigationHighlight()
    }
    
    func uiWidgetActionForControllerNavigator(forward: Bool, from navigation: ControllerNavigationElement) {
        guard navigation.action == "focusNavigation" else { return }
        moveSelectedProfile(horizontalOffset: forward ? 1 : -1)
    }
    
    func uiButtonActionForControllerNavigator(pressed: Bool, from navigation: ControllerNavigationElement) {
        if navigation.action == "holdToReorder" {
            if #available(iOS 13.0, *) {
                handleControllerNavigationReorderHold(pressed: pressed)
            }
            return
        }

        guard pressed else { return }
        PublicUtils.runOnMain { [weak self] in
            switch navigation.action {
            case "previousItem":
                self?.moveSelectedProfile(by: -1)
            case "nextItem":
                self?.moveSelectedProfile(by: 1)
            case "exit":
                self?.dismiss(animated: false)
            default:
                break
            }
        }
    }
}

#if !os(tvOS)
extension ProfileSelectorViewController: UIDocumentPickerDelegate {}
#endif

@available(iOS 13.0, *)
extension ProfileSelectorViewController: ControllerCollectionNavigationDelegate {
    var controllerNavigationCollectionView: UICollectionView {
        profileCollectionView
    }

    private func restoreSelectedProfileControllerNavigationHighlight() {
        PublicUtils.runOnMain { [weak self] in
            guard let self,
                  self.profileCollectionView.numberOfSections > 0,
                  self.profileCollectionView.numberOfItems(inSection: 0) > 0,
                  let selectedProfileIndex = self.validProfileIndex(self.selectedProfileIndex) else {
                self?.clearCollectionControllerNavigationHighlightForControllerNavigator()
                return
            }

            self.profileCollectionView.layoutIfNeeded()
            self.controllerNavigationHighlightItemForControllerNavigator(at: IndexPath(item: selectedProfileIndex, section: 0))
        }
    }

    private func handleControllerNavigationReorderHold(pressed: Bool) {
        PublicUtils.runOnMain { [weak self] in
            guard let self else { return }

            if pressed {
                if self.controllerNavigationDeleteDoublePressWindowOpen {
                    self.closeControllerNavigationDeleteDoublePressWindow()
                    self.deleteControllerNavigationHighlightedProfile()
                    return
                }

                guard !self.controllerNavigationReorderActive,
                      let currentIndexPath = self.controllerNavigationCurrentIndexPathForControllerNavigator()
                        ?? self.validProfileIndex(self.selectedProfileIndex).map({ IndexPath(item: $0, section: 0) }),
                      self.canControllerNavigationReorderProfile(at: currentIndexPath) else {
                    return
                }

                self.controllerNavigationReorderPressBeganAt = CACurrentMediaTime()
                self.controllerNavigationReorderActive = true
                self.pendingControllerNavigationReorderMove = nil
                self.controllerNavigationPersistOrderWhenReorderSettles = false
                self.beginControllerNavigationReorderSnapshot(at: currentIndexPath)
                self.controllerNavigationSelectedIndexPath = currentIndexPath
                return
            }

            let pressDuration = self.controllerNavigationReorderPressBeganAt.map { CACurrentMediaTime() - $0 } ?? .greatestFiniteMagnitude
            self.controllerNavigationReorderPressBeganAt = nil

            guard self.controllerNavigationReorderActive else { return }
            self.controllerNavigationReorderActive = false
            self.pendingControllerNavigationReorderMove = nil
            self.controllerNavigationPersistOrderWhenReorderSettles = true
            if pressDuration <= 0.2 {
                self.openControllerNavigationDeleteDoublePressWindow()
            } else {
                self.closeControllerNavigationDeleteDoublePressWindow()
            }

            guard !self.controllerNavigationReorderUpdateInFlight else { return }
            self.persistProfileOrderIfNeeded(notify: false)
            self.controllerNavigationPersistOrderWhenReorderSettles = false
            self.endControllerNavigationReorderSnapshot()
            self.restoreControllerNavigationHighlight()
        }
    }

    private func moveControllerNavigationReorderedProfile(horizontalOffset: Int) {
        moveControllerNavigationReorderedProfile(horizontalOffset: horizontalOffset, verticalOffset: 0)
    }

    private func moveControllerNavigationReorderedProfile(verticalOffset: Int) {
        moveControllerNavigationReorderedProfile(horizontalOffset: 0, verticalOffset: verticalOffset)
    }

    private func moveControllerNavigationReorderedProfile(horizontalOffset: Int, verticalOffset: Int) {
        guard !controllerNavigationReorderUpdateInFlight else {
            pendingControllerNavigationReorderMove = (horizontalOffset, verticalOffset)
            return
        }

        guard let currentIndexPath = controllerNavigationCurrentIndexPathForControllerNavigator(),
              canControllerNavigationReorderProfile(at: currentIndexPath),
              let destinationIndexPath = controllerNavigationReorderDestination(from: currentIndexPath, horizontalOffset: horizontalOffset, verticalOffset: verticalOffset) else {
            return
        }

        moveControllerNavigationReorderedProfile(from: currentIndexPath, to: destinationIndexPath)
    }

    private func openControllerNavigationDeleteDoublePressWindow() {
        controllerNavigationDeleteDoublePressWindowOpen = true
        controllerNavigationDeleteDoublePressToken += 1
        let token = controllerNavigationDeleteDoublePressToken

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
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

    private func deleteControllerNavigationHighlightedProfile() {
        guard let indexPath = controllerNavigationCurrentIndexPathForControllerNavigator()
                ?? validProfileIndex(selectedProfileIndex).map({ IndexPath(item: $0, section: 0) }),
              indexPath.section == 0,
              indexPath.item > 0,
              indexPath.item < profiles.count,
              indexPath.item < profileCollectionView.numberOfItems(inSection: 0) else {
            return
        }

        closeControllerNavigationDeleteDoublePressWindow()
        controllerNavigationReorderActive = false
        pendingControllerNavigationReorderMove = nil
        controllerNavigationPersistOrderWhenReorderSettles = false
        endControllerNavigationReorderSnapshot()
        invalidateCollectionControllerNavigationHighlightForControllerNavigator()

        markProfileSelectedLocally(at: indexPath.item)
        if profileOrderChanged {
            profilesManager.persistProfileOrder(profiles)
            profileOrderChanged = false
        } else {
            profilesManager.setProfileToSelected(UInt32(indexPath.item))
        }

        profilesManager.deleteCurrentSelectedProfile()

        let targetItem = max(indexPath.item - 1, 0)
        profiles.removeObject(at: indexPath.item)
        if profiles.count > 0 {
            markProfileSelectedLocally(at: min(targetItem, profiles.count - 1))
        }

        profileCollectionView.performBatchUpdates {
            profileCollectionView.deleteItems(at: [indexPath])
        } completion: { [weak self] _ in
            guard let self else { return }

            self.profileCollectionView.reloadData()
            self.notifyProfileViewDidRefresh()
            self.scrollToSelectedProfile(animated: true)
            self.restoreControllerNavigationHighlight()
        }
    }

    private func controllerNavigationReorderDestination(from currentIndexPath: IndexPath, horizontalOffset: Int, verticalOffset: Int) -> IndexPath? {
        let itemCount = min(profiles.count, profileCollectionView.numberOfItems(inSection: 0))
        let movableCount = itemCount - 1
        guard movableCount > 1 else { return nil }

        let columns = max(1, columnCount(for: profileCollectionView.bounds.width))
        let rawOffset = horizontalOffset + verticalOffset * columns
        guard rawOffset != 0 else { return nil }

        let currentSortableIndex = currentIndexPath.item - 1
        let nextSortableIndex = (currentSortableIndex + rawOffset) % movableCount
        let wrappedSortableIndex = (nextSortableIndex + movableCount) % movableCount
        let nextItem = wrappedSortableIndex + 1
        guard nextItem != currentIndexPath.item else { return nil }

        return IndexPath(item: nextItem, section: currentIndexPath.section)
    }

    private func moveControllerNavigationReorderedProfile(from sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        guard canControllerNavigationReorderProfile(at: sourceIndexPath),
              canControllerNavigationReorderProfile(at: destinationIndexPath),
              sourceIndexPath != destinationIndexPath else {
            return
        }

        controllerNavigationReorderUpdateInFlight = true
        pendingControllerNavigationReorderMove = nil
        invalidateCollectionControllerNavigationHighlightForControllerNavigator()
        controllerNavigationReorderHiddenIndexPath = sourceIndexPath
        updateVisibleReorderHiddenCells()

        let movedProfile = profiles.object(at: sourceIndexPath.item)
        profiles.removeObject(at: sourceIndexPath.item)
        profiles.insert(movedProfile, at: destinationIndexPath.item)
        selectedProfileIndex = destinationIndexPath.item
        profileOrderChanged = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.scrollToControllerNavigationReorderProfileIfNeeded(at: destinationIndexPath, animated: true)
            self.updateControllerNavigationReorderSnapshotFrame(to: destinationIndexPath, animated: true)
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.07)
            self.profileCollectionView.performBatchUpdates {
                self.profileCollectionView.moveItem(at: sourceIndexPath, to: destinationIndexPath)
            } completion: { [weak self] _ in
                guard let self else { return }

                self.scrollToControllerNavigationReorderProfileIfNeeded(at: destinationIndexPath, animated: false)
                self.updateControllerNavigationReorderSnapshotFrame(to: destinationIndexPath, animated: false)
                self.controllerNavigationReorderHiddenIndexPath = destinationIndexPath
                self.updateVisibleReorderHiddenCells()
                self.controllerNavigationSelectedIndexPath = destinationIndexPath
                self.controllerNavigationReorderUpdateInFlight = false

                if self.consumePendingControllerNavigationReorderMoveIfNeeded() {
                    return
                }

                if self.controllerNavigationPersistOrderWhenReorderSettles {
                    self.persistProfileOrderIfNeeded(notify: false)
                    self.controllerNavigationPersistOrderWhenReorderSettles = false
                }

                guard !self.controllerNavigationReorderActive else { return }
                self.endControllerNavigationReorderSnapshot()
                self.restoreControllerNavigationHighlight()
            }
            CATransaction.commit()
        }
    }

    private func beginControllerNavigationReorderSnapshot(at indexPath: IndexPath) {
        controllerNavigationReorderSnapshotView?.removeFromSuperview()
        invalidateCollectionControllerNavigationHighlightForControllerNavigator()

        profileCollectionView.layoutIfNeeded()
        guard let cell = profileCollectionView.cellForItem(at: indexPath),
              let snapshot = cell.snapshotView(afterScreenUpdates: true) else {
            return
        }

        snapshot.frame = cell.frame
        snapshot.layer.cornerRadius = cell.contentView.layer.cornerRadius
        snapshot.layer.masksToBounds = true
        snapshot.layer.zPosition = 1000

        profileCollectionView.addSubview(snapshot)
        controllerNavigationReorderSnapshotView = snapshot
        controllerNavigationReorderHiddenIndexPath = indexPath
        updateVisibleReorderHiddenCells()
    }

    private func scrollToControllerNavigationReorderProfileIfNeeded(at indexPath: IndexPath, animated: Bool) {
        guard indexPath.section < profileCollectionView.numberOfSections,
              indexPath.item >= 0,
              indexPath.item < profileCollectionView.numberOfItems(inSection: indexPath.section) else {
            return
        }

        profileCollectionView.scrollToItem(at: indexPath, at: [.centeredHorizontally, .centeredVertically], animated: animated)
        profileCollectionView.layoutIfNeeded()
    }

    private func updateControllerNavigationReorderSnapshotFrame(to indexPath: IndexPath, animated: Bool) {
        guard let snapshot = controllerNavigationReorderSnapshotView else { return }

        profileCollectionView.layoutIfNeeded()
        guard let attributes = profileCollectionView.collectionViewLayout.layoutAttributesForItem(at: indexPath) else { return }

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

    private func updateVisibleReorderHiddenCells() {
        profileCollectionView.visibleCells.forEach { cell in
            guard let indexPath = profileCollectionView.indexPath(for: cell) else {
                cell.isHidden = false
                return
            }

            cell.isHidden = indexPath == controllerNavigationReorderHiddenIndexPath
        }
    }

    private func canControllerNavigationReorderProfile(at indexPath: IndexPath) -> Bool {
        loadingMode != .pickProfileData
            && indexPath.section == 0
            && indexPath.item > 0
            && indexPath.item < profiles.count
            && indexPath.item < profileCollectionView.numberOfItems(inSection: 0)
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
            moveControllerNavigationReorderedProfile(horizontalOffset: pendingMove.horizontal)
            return true
        }

        if pendingMove.vertical != 0 {
            moveControllerNavigationReorderedProfile(verticalOffset: pendingMove.vertical)
            return true
        }

        return false
    }

    private func cancelControllerNavigationReorderIfNeeded() {
        controllerNavigationReorderActive = false
        controllerNavigationReorderUpdateInFlight = false
        pendingControllerNavigationReorderMove = nil
        controllerNavigationPersistOrderWhenReorderSettles = false
        controllerNavigationReorderPressBeganAt = nil
        closeControllerNavigationDeleteDoublePressWindow()
        controllerNavigationReorderSnapshotView?.removeFromSuperview()
        controllerNavigationReorderSnapshotView = nil
        controllerNavigationReorderHiddenIndexPath = nil
        updateVisibleReorderHiddenCells()
    }
}
