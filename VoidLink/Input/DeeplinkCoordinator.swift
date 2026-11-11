//
//  DeeplinkCoordinator.swift
//  VoidLink
//
//  Created by True砖家 on 2026/11/7.
//  Copyright © 2026 True砖家@Bilibili. All rights reserved.
//


import UIKit
#if os(iOS)
import AppIntents
#endif
#if os(tvOS)
import TVServices
#endif

@objcMembers
final class DeeplinkCoordinator: NSObject {
    private enum LinkScheme {
        static let current: String = {
            // Read the scheme iOS or tvOS actually registered for this bundle.
            let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]]
            let type = types?.first { $0["CFBundleURLName"] as? String == "com.voidlink.deeplink" }
            let schemes = type?["CFBundleURLSchemes"] as? [String]
            return schemes?.first?.lowercased() ?? "voidlinkwild"
        }()
    }

    private struct Target {
        let hostSuffix: String
        let appID: String?

        init?(hostID: String, appID: String?) {
            guard hostID.count >= 8, appID?.isEmpty != true else { return nil }
            hostSuffix = String(hostID.suffix(8)).lowercased()
            self.appID = appID
        }

        init?(url: URL) {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  components.scheme?.lowercased() == LinkScheme.current,
                  components.user == nil, components.password == nil, components.port == nil,
                  components.query == nil, components.fragment == nil else { return nil }
            let parts = components.percentEncodedPath.split(separator: "/", omittingEmptySubsequences: false)
            guard parts.first?.isEmpty == true, parts.count >= 2,
                  let suffix = parts[1].removingPercentEncoding, suffix.count == 8 else { return nil }
            switch (components.host?.lowercased(), parts.count) {
            case ("host", 2):
                appID = nil
            case ("play", 3):
                guard let id = parts[2].removingPercentEncoding, !id.isEmpty else { return nil }
                appID = id
            default:
                return nil
            }
            hostSuffix = suffix.lowercased()
        }

        var url: URL? {
            var components = URLComponents()
            components.scheme = LinkScheme.current
            components.host = appID == nil ? "host" : "play"
            let segments = [hostSuffix] + (appID.map { [$0] } ?? [])
            var allowed = CharacterSet.urlPathAllowed
            allowed.remove(charactersIn: "/")
            let encoded = segments.compactMap { $0.addingPercentEncoding(withAllowedCharacters: allowed) }
            guard encoded.count == segments.count else { return nil }
            components.percentEncodedPath = "/" + encoded.joined(separator: "/")
            return components.url
        }
    }

    private enum Stage {
        case idle
        case waitingForView
        case waitingForHost
        case highlightingHost
        case waitingForApps(TemporaryHost)
        case highlightingApp
        case checkingRunningApp
        case quittingApp
    }

    private weak var mainFrame: MainFrameViewController?
    private var stage = Stage.idle
    private var target: Target?
    private var generation = 0
    private var hostDeadline: DispatchTime?
    private var clearHighlight: (() -> Void)?
    private var viewReady = false
    private var hostViewWaitStartedAt: DispatchTime?
    private var needsInitialization = false
    private var hasRefreshedApps = false
    private var didAttemptWake = false
    private var didSendWake = false
    private var fallbackReady = false
    private weak var initializationAlert: UIAlertController?
    var hasPendingLink: Bool { target != nil }

    init(mainFrame: MainFrameViewController) {
        self.mainFrame = mainFrame
    }

    @objc(canHandleURL:)
    static func canHandle(_ url: URL) -> Bool {
        Target(url: url) != nil
    }

    func open(_ url: URL) {
        guard let target = Target(url: url) else { return }
        reset()
        self.target = target
        stage = .waitingForView
        // An already-visible MainFrame will not receive another viewDidAppear.
        if viewReady { hostViewWaitStartedAt = .now() }
        beginIfReady()
    }

    // Called only from MainFrame.viewDidAppear, after its setup has completed.
    @MainActor func mainFrameDidAppear() {
        viewReady = true
        if case .waitingForView = stage, hostViewWaitStartedAt == nil {
            hostViewWaitStartedAt = .now()
        }
        beginIfReady()
#if os(iOS)
        if #available(iOS 16.0, *), Self.shortcutCoordinators.allObjects.isEmpty {
            VoidLinkAppShortcuts.updateAppShortcutParameters()
        }
        Self.shortcutCoordinators.add(self)
        Self.deliverPendingShortcut()
#endif
    }

    func viewWillLeave() {
        viewReady = false
        switch stage {
        case .waitingForHost, .highlightingHost, .highlightingApp, .checkingRunningApp, .quittingApp: reset()
        default: break
        }
    }

    func didReturnToHostView() {
        switch stage {
        case .highlightingHost, .waitingForApps, .highlightingApp, .checkingRunningApp, .quittingApp: reset()
        default: break
        }
    }

    func userWillEnterAppView() {
        reset()
    }

    private func beginIfReady() {
        guard case .waitingForView = stage, viewReady, let mainFrame, !mainFrame.isStreaming() else { return }
        if let presented = mainFrame.presentedViewController ?? mainFrame.view.window?.rootViewController?.presentedViewController {
            if let alert = presented as? UIAlertController {
                alert.dismiss(animated: false) { [weak self] in self?.beginIfReady() }
            }
            return
        }

        stage = .waitingForHost
        guard let waitStartedAt = hostViewWaitStartedAt else { return }
        let deadline = waitStartedAt + 120
        hostDeadline = deadline
        let token = generation
        mainFrame.prepareDeeplinkHostView()
        DispatchQueue.main.asyncAfter(deadline: waitStartedAt + 2.6) { [weak self] in
            guard let self, self.generation == token, case .waitingForHost = self.stage else { return }
            self.fallbackReady = true
            self.matchStoredHost()
        }
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self, self.generation == token, case .waitingForHost = self.stage else { return }
            self.reset()
            self.showNotice("DeepLink host did not come online.".localized)
        }
    }

    private func matchStoredHost() {
        guard case .waitingForHost = stage, let target, let mainFrame,
              let collection = mainFrame.hostCollectionVC,
              let hosts = collection.items as? [TemporaryHost],
              let index = hosts.firstIndex(where: { $0.uuid.lowercased().hasSuffix(target.hostSuffix) }) else { return }
        let host = hosts[index]
        if host.state == State(rawValue: 2) {
            reportOnlineHost(host)
            return
        }
        collection.showDeeplinkNavigationHighlight(at: IndexPath(item: index, section: 0))
        clearHighlight = { [weak collection] in collection?.finishDeeplinkNavigationHighlight() }
        guard !didAttemptWake else { return }
        didAttemptWake = true
        didSendWake = mainFrame.wakeDeeplinkHost(host)
        // Discovery can initially report an online PC as unknown/offline. Only a
        // WOL request accepted for sending by this flow requires initialization.
        needsInitialization = didSendWake
        if didSendWake {
            showNotice("Sent Wake-on-LAN".localized)
        } else {
            showNotice("Host MAC unknown, unable to send WOL Packet".localized)
        }
    }

    func reportOnlineHost(_ host: TemporaryHost) {
        guard case .waitingForHost = stage, viewReady, let target, let hostDeadline,
              DispatchTime.now() < hostDeadline,
              host.uuid.lowercased().hasSuffix(target.hostSuffix) else { return }
        guard host.state == State(rawValue: 2) else {
            if fallbackReady { matchStoredHost() }
            return
        }
        guard let mainFrame, let collection = mainFrame.hostCollectionVC,
              let index = (collection.items as? [TemporaryHost])?.firstIndex(where: { $0 === host }) else { return }
        stage = .highlightingHost
        clearHighlight?()
        highlight(collection, index: index) { [weak self, weak mainFrame] in
            guard let self, let mainFrame, !mainFrame.isInAppView(), !mainFrame.isStreaming() else {
                self?.reset()
                return
            }
            self.stage = .waitingForApps(host)
            // An auto-dismiss WOL notice can still be visible when the host comes online.
            let token = self.generation
            let open = { [weak self, weak mainFrame] in
                guard let self, self.generation == token, case .waitingForApps = self.stage else { return }
                mainFrame?.openDeeplinkHost(host, showHiddenApps: target.appID != nil)
            }
            if let alert = mainFrame.presentedViewController as? UIAlertController {
                alert.dismiss(animated: false, completion: open)
            } else { open() }
        }
    }

    @objc(isWaitingForAppsForHost:)
    func isWaitingForApps(for host: TemporaryHost?) -> Bool {
        guard case .waitingForApps(let expectedHost) = stage else { return false }
        return expectedHost === host
    }

    func didEnterDeeplinkAppView() {
        guard case .waitingForApps(let host) = stage, didSendWake, needsInitialization, initializationAlert == nil,
              target?.appID != nil, let mainFrame else { return }
        let token = generation
        initializationAlert = AlertControllerUtil.showContinuingCountdown(
            in: mainFrame, message: "Waiting for host system initialization".localized, seconds: 10
        ) { [weak self] in
            guard let self, self.generation == token, self.isWaitingForApps(for: host) else { return }
            self.initializationAlert = nil
            self.needsInitialization = false
            if self.hasRefreshedApps { self.appsDidRefresh(for: host) }
        }
    }

    func appsDidRefresh(for host: TemporaryHost) {
        guard isWaitingForApps(for: host), let mainFrame, mainFrame.isInAppView() else { return }
        guard let appID = target?.appID else {
            reset()
            return
        }
        hasRefreshedApps = true
        guard !needsInitialization else { return }
        startApp(host: host, appID: appID)
    }

    private func startApp(host: TemporaryHost, appID: String) {
        guard let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming() else { reset(); return }
        let apps = mainFrame.sortedAppList ?? []
        guard apps.contains(where: { $0.host === host && $0.id == appID }) else {
            reset()
            showNotice("DeepLink app was not found.".localized)
            return
        }
        stage = .checkingRunningApp
        let token = generation
        mainFrame.queryDeeplinkHost(host) { [weak self, weak mainFrame] success, busy, runningAppID in
            guard let self, self.generation == token, case .checkingRunningApp = self.stage else { return }
            guard success, let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming() else {
                self.reset()
                self.showNotice("Failed to connect to PC".localized)
                return
            }
            guard let index = mainFrame.sortedAppList?.firstIndex(where: { $0.host === host && $0.id == appID }) else {
                self.reset()
                self.showNotice("DeepLink app was not found.".localized)
                return
            }
            // Use the live response, not host.currentGame, which discovery can
            // overwrite and which /applist does not refresh.
            self.stage = .highlightingApp
            self.highlight(mainFrame, index: index) { [weak self, weak mainFrame] in
                guard let self, let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming(),
                      let app = mainFrame.sortedAppList?.first(where: { $0.host === host && $0.id == appID }) else { return }
                if !busy || runningAppID == appID {
                    self.reset()
                    mainFrame.launch(app)
                } else {
                    self.stage = .quittingApp
                    let token = self.generation
                    mainFrame.quitApp(app) { [weak self, weak mainFrame] success in
                        guard let self, self.generation == token, case .quittingApp = self.stage else { return }
                        guard success, let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming() else {
                            self.reset()
                            return
                        }
                        self.highlightAndLaunchApp(host: host, appID: appID)
                    }
                }
            }
        }
    }

    private func highlightAndLaunchApp(host: TemporaryHost, appID: String) {
        guard let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming(),
              let index = mainFrame.sortedAppList?.firstIndex(where: { $0.host === host && $0.id == appID }) else {
            reset()
            return
        }
        stage = .highlightingApp
        highlight(mainFrame, index: index) { [weak self, weak mainFrame] in
            guard let self, let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming(),
                  let app = mainFrame.sortedAppList?.first(where: { $0.host === host && $0.id == appID }) else { return }
            self.reset()
            mainFrame.launch(app)
        }
    }

    private func highlight(_ controller: UICollectionViewController, index: Int, then action: @escaping () -> Void) {
        controller.showDeeplinkNavigationHighlight(at: IndexPath(item: index, section: 0))
        clearHighlight = { [weak controller] in controller?.finishDeeplinkNavigationHighlight() }
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.generation == token else { return }
            self.clearHighlight?()
            self.clearHighlight = nil
            action()
        }
    }

    private func reset() {
        generation += 1
        initializationAlert?.dismiss(animated: false)
        initializationAlert = nil
        needsInitialization = false
        hasRefreshedApps = false
        didAttemptWake = false
        didSendWake = false
        fallbackReady = false
        clearHighlight?()
        clearHighlight = nil
        hostDeadline = nil
        hostViewWaitStartedAt = nil
        target = nil
        stage = .idle
    }

    private func showNotice(_ message: String) {
        guard let mainFrame, mainFrame.viewIfLoaded?.window != nil, mainFrame.presentedViewController == nil else { return }
        Self.showNotice(message, in: mainFrame)
    }

    private static func showNotice(_ message: String, in presenter: UIViewController) {
        AlertControllerUtil.showAutoDismissNotice(in: presenter, message: message, seconds: 1)
    }

    @MainActor static func addLinkAction(to alert: UIAlertController, presenter: UIViewController,
                                         host: TemporaryHost, appID: String?) {
        guard let url = Target(hostID: host.uuid, appID: appID)?.url else { return }
#if os(tvOS)
        let label = "Show DeepLink".localized
#else
        let label = "Shortcuts".localized
#endif
        alert.addAction(UIAlertAction(title: label, style: .default) { [weak alert, weak presenter] _ in
            AlertControllerUtil.afterActionDismissal(of: alert) {
                guard let presenter else { return }
#if os(tvOS)
                AlertControllerUtil.showAlert(in: presenter, title: "DeepLink", message: url.absoluteString,
                                              withCancel: false, buttonTitle: "Ok".localized, countdown: 0)
#elseif os(iOS)
                showShortcutChoices(in: presenter, host: host, appID: appID, url: url)
#endif
            }
        })
    }

#if os(iOS)
    @MainActor private static func showShortcutChoices(in presenter: UIViewController, host: TemporaryHost,
                                                       appID: String?, url: URL) {
        let choices = UIAlertController(title: "Shortcuts".localized, message: nil, preferredStyle: .alert)
        choices.addAction(UIAlertAction(title: "Copy DeepLink".localized, style: .default) { [weak choices, weak presenter] _ in
            UIPasteboard.general.string = url.absoluteString
            AlertControllerUtil.afterActionDismissal(of: choices) {
                if let presenter { showNotice("DeepLink copied to clipboard".localized, in: presenter) }
            }
        })
        if #available(iOS 16.0, *) {
            let hostID = host.uuid.lowercased()
            let existing = ShortcutCatalog.entries.first { $0.hostID == hostID && $0.appID == appID }
            let label = existing == nil ? "Add to Shortcuts" : "Remove from Shortcuts"
            choices.addAction(UIAlertAction(title: label.localized, style: .default) { [weak choices, weak presenter] _ in
                if let existing {
                    ShortcutCatalog.update { $0.removeAll { $0.id == existing.id } }
                } else {
                    let appName = appID.flatMap { id in
                        (host.appList as? Set<TemporaryApp>)?.first { $0.id == id }.map { $0.name ?? id }
                    }
                    guard appID == nil || appName != nil else {
                        AlertControllerUtil.afterActionDismissal(of: choices) {
                            if let presenter { showNotice("DeepLink app was not found.".localized, in: presenter) }
                        }
                        return
                    }
                    ShortcutCatalog.update { entries in
                        guard !entries.contains(where: { $0.hostID == hostID && $0.appID == appID }) else { return }
                        entries.append(ShortcutCatalog.Entry(id: UUID().uuidString, hostID: hostID,
                            hostName: host.name, appID: appID, appName: appName))
                    }
                }
                AlertControllerUtil.afterActionDismissal(of: choices) {
                    guard let presenter else { return }
                    let message = existing == nil ? "Added to Shortcuts List" : "Removed from Shortcuts List"
                    showNotice(message.localized, in: presenter)
                }
            })
        }
        choices.addAction(UIAlertAction(title: "Cancel".localized, style: .cancel))
        presenter.present(choices, animated: true)
    }

    @MainActor static func removeShortcutTargets(forHost host: TemporaryHost) {
        ShortcutCatalog.update { entries in
            entries.removeAll { $0.hostID == host.uuid.lowercased() }
        }
    }

    // Called only with the full, successfully refreshed app list, including hidden apps.
    @MainActor static func reconcileShortcutTargets(forHost host: TemporaryHost) {
        let apps = host.appList as? Set<TemporaryApp> ?? []
        let names = Dictionary(apps.compactMap { app -> (String, String)? in
            guard let id = app.id else { return nil }
            return (id, app.name ?? id)
        }, uniquingKeysWith: { first, _ in first })
        let hostID = host.uuid.lowercased()
        ShortcutCatalog.update { entries in
            entries = entries.compactMap { entry in
                guard entry.hostID == hostID else { return entry }
                var updated = entry
                updated.hostName = host.name
                if let appID = entry.appID {
                    guard let name = names[appID] else { return nil }
                    updated.appName = name
                }
                return updated
            }
        }
    }

    @MainActor private static let shortcutCoordinators = NSHashTable<DeeplinkCoordinator>.weakObjects()
    @MainActor private static var pendingShortcutURL: URL?

    @MainActor @nonobjc fileprivate static func openShortcut(_ entry: ShortcutCatalog.Entry) throws {
        guard let url = Target(hostID: entry.hostID, appID: entry.appID)?.url else {
            throw ShortcutTargetUnavailable()
        }
        pendingShortcutURL = url
        deliverPendingShortcut()
    }

    @MainActor static func deliverPendingShortcut() {
        guard let url = pendingShortcutURL else { return }
        let active = shortcutCoordinators.allObjects.filter {
            $0.mainFrame?.viewIfLoaded?.window?.windowScene?.activationState == .foregroundActive
        }
        guard let coordinator = active.first(where: { $0.mainFrame?.viewIfLoaded?.window?.isKeyWindow == true })
            ?? active.first else { return }
        pendingShortcutURL = nil
        coordinator.open(url)
    }
#endif

#if os(tvOS)
    private static func topShelfURL(host: TemporaryHost, app: TemporaryApp?) -> URL? {
        let appID = app?.id
        guard app == nil || appID != nil else { return nil }
        return Target(hostID: host.uuid, appID: appID)?.url
    }

    static func isOnTopShelf(host: TemporaryHost, app: TemporaryApp?) -> Bool {
        guard let url = topShelfURL(host: host, app: app) else { return false }
        return TopShelfStore.contains(url)
    }

    static func toggleTopShelf(host: TemporaryHost, app: TemporaryApp?, presenter: UIViewController) {
        guard let url = topShelfURL(host: host, app: app) else { return }
        let name = app?.name ?? host.name
        do {
            let removed = try TopShelfStore.removeIfPresent(url)
            if !removed {
                try TopShelfStore.add(title: name, url: url, isApp: app != nil,
                                      artworkPath: app.flatMap { AppAssetManager.boxArtPath(for: $0) })
            }
            TVTopShelfContentProvider.topShelfContentDidChange()
            GamepadNavigationIllustrationHud.updateHud()
            let message = removed ? "Removed from Top Shelf".localized
                                  : LocalizationHelper.localizedString(forKey: "Added “%@” to Top Shelf", name)
            showNotice(message, in: presenter)
        } catch {
            NSLog("Top Shelf update failed: %@", String(describing: error))
            showNotice("Could not update Top Shelf.".localized, in: presenter)
        }
    }
#endif
}

#if os(iOS)
@MainActor
private enum ShortcutCatalog {
    struct Entry: Codable, Equatable {
        let id: String
        let hostID: String
        var hostName: String
        let appID: String?
        var appName: String?
    }

    private static let defaultsKey = "VoidLinkShortcutTargets"

    static var entries: [Entry] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Entry].self, from: data)) ?? []
    }

    static func update(_ edit: (inout [Entry]) -> Void) {
        let previous = entries
        var updated = previous
        edit(&updated)
        guard updated != previous, let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
        if #available(iOS 16.0, *) {
            VoidLinkAppShortcuts.updateAppShortcutParameters()
        }
    }
}

private struct ShortcutTargetUnavailable: LocalizedError {
    var errorDescription: String? { "This VoidLink shortcut target is no longer available.".localized }
}

@available(iOS 16.0, *)
struct VoidLinkShortcutTarget: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Streaming Target"
    static let defaultQuery = VoidLinkShortcutTargetQuery()

    let id: String
    let name: String
    let hostName: String?

    fileprivate init(_ entry: ShortcutCatalog.Entry) {
        id = entry.id
        name = entry.appName ?? entry.hostName
        hostName = entry.appID == nil ? nil : entry.hostName
    }

    var displayRepresentation: DisplayRepresentation {
        if let hostName {
            return DisplayRepresentation(title: "\(name)", subtitle: "\(hostName)", image: .init(systemName: "play.rectangle"))
        }
        return DisplayRepresentation(title: "\(name)", image: .init(systemName: "desktopcomputer"))
    }
}

@available(iOS 16.0, *)
struct VoidLinkShortcutTargetQuery: EntityQuery {
    @MainActor func suggestedEntities() async throws -> [VoidLinkShortcutTarget] {
        ShortcutCatalog.entries.map(VoidLinkShortcutTarget.init)
    }

    @MainActor func entities(for identifiers: [String]) async throws -> [VoidLinkShortcutTarget] {
        let entries = ShortcutCatalog.entries
        return identifiers.compactMap { id in
            entries.first { $0.id == id }.map(VoidLinkShortcutTarget.init)
        }
    }
}

@available(iOS 16.0, *)
struct OpenVoidLinkShortcutTarget: OpenIntent {
    static let title: LocalizedStringResource = "Open VoidLink Target"
    static var openAppWhenRun: Bool { true }

    @Parameter(title: "Streaming Target")
    var target: VoidLinkShortcutTarget

    @MainActor func perform() async throws -> some IntentResult {
        guard let entry = ShortcutCatalog.entries.first(where: { $0.id == target.id }) else {
            throw ShortcutTargetUnavailable()
        }
        try DeeplinkCoordinator.openShortcut(entry)
        return .result()
    }
}

@available(iOS 16.0, *)
struct VoidLinkAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: OpenVoidLinkShortcutTarget(),
                    phrases: ["Open \(\.$target) in \(.applicationName)"],
                    shortTitle: "Open VoidLink Target",
                    systemImageName: "play.rectangle")
    }
}
#endif
