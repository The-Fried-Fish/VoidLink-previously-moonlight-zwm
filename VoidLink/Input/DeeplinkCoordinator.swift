import UIKit
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
    func mainFrameDidAppear() {
        viewReady = true
        if case .waitingForView = stage, hostViewWaitStartedAt == nil {
            hostViewWaitStartedAt = .now()
        }
        beginIfReady()
    }

    func viewWillLeave() {
        viewReady = false
        switch stage {
        case .waitingForHost, .highlightingHost, .highlightingApp, .quittingApp: reset()
        default: break
        }
    }

    func didReturnToHostView() {
        switch stage {
        case .highlightingHost, .waitingForApps, .highlightingApp, .quittingApp: reset()
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
        guard let index = apps.firstIndex(where: { $0.id == appID }) else {
            reset()
            showNotice("DeepLink app was not found.".localized)
            return
        }
        stage = .highlightingApp
        highlight(mainFrame, index: index) { [weak self, weak mainFrame] in
            guard let self, let mainFrame, mainFrame.isInAppView(), !mainFrame.isStreaming(),
                  let app = mainFrame.sortedAppList?.first(where: { $0.host === host && $0.id == appID }) else { return }
            if host.currentGame == nil || host.currentGame == "0" || host.currentGame == appID {
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
                    // Quit may refresh/reorder the app grid. Resolve the target again
                    // and show its highlight after the loading overlay has gone away.
                    self.highlightAndLaunchApp(host: host, appID: appID)
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

    static func addLinkAction(to alert: UIAlertController, presenter: UIViewController,
                              host: TemporaryHost, appID: String?) {
        guard let url = Target(hostID: host.uuid, appID: appID)?.url else { return }
#if os(tvOS)
        let label = "Show DeepLink".localized
#else
        let label = "Copy DeepLink".localized
#endif
        alert.addAction(UIAlertAction(title: label, style: .default) { [weak alert, weak presenter] _ in
            guard let presenter else { return }
            let showLink = {
#if os(tvOS)
                AlertControllerUtil.showAlert(in: presenter, title: "DeepLink", message: url.absoluteString,
                                              withCancel: false, buttonTitle: "Ok".localized, countdown: 0)
#else
                UIPasteboard.general.string = url.absoluteString
                Self.showNotice("DeepLink copied to clipboard".localized, in: presenter)
#endif
            }
            DispatchQueue.main.async {
                if let alert, let transition = alert.transitionCoordinator, alert.isBeingDismissed {
                    if transition.animate(alongsideTransition: nil, completion: { _ in showLink() }) { return }
                }
                if let alert, alert.presentingViewController != nil {
                    alert.dismiss(animated: true, completion: showLink)
                } else {
                    showLink()
                }
            }
        })
    }

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
