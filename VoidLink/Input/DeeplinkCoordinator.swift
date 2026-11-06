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
    }

    private weak var mainFrame: MainFrameViewController?
    private var stage = Stage.idle
    private var target: Target?
    private var generation = 0
    private var hostDeadline: DispatchTime?
    private var clearHighlight: (() -> Void)?
    private var viewReady = false
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
        beginIfReady()
    }

    func viewDidBecomeReady() {
        viewReady = true
        beginIfReady()
    }

    func viewWillLeave() {
        viewReady = false
        switch stage {
        case .waitingForHost, .highlightingHost, .highlightingApp: reset()
        default: break
        }
    }

    func didReturnToHostView() {
        switch stage {
        case .highlightingHost, .waitingForApps, .highlightingApp: reset()
        default: break
        }
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
        let deadline = DispatchTime.now() + 5
        hostDeadline = deadline
        let token = generation
        mainFrame.prepareDeeplinkHostView()
        DispatchQueue.main.asyncAfter(deadline: deadline) { [weak self] in
            guard let self, self.generation == token, case .waitingForHost = self.stage else { return }
            self.reset()
            self.showNotice("DeepLink host did not come online.".localized)
        }
    }

    func reportOnlineHost(_ host: TemporaryHost) {
        guard case .waitingForHost = stage, viewReady, let target, let hostDeadline,
              DispatchTime.now() < hostDeadline,
              host.state == State(rawValue: 2),
              host.uuid.lowercased().hasSuffix(target.hostSuffix),
              let mainFrame, let collection = mainFrame.hostCollectionVC,
              let index = (collection.items as? [TemporaryHost])?.firstIndex(where: { $0 === host }) else { return }
        stage = .highlightingHost
        highlight(collection, index: index) { [weak self, weak mainFrame] in
            guard let self, let mainFrame, !mainFrame.isInAppView(), !mainFrame.isStreaming() else {
                self?.reset()
                return
            }
            self.stage = .waitingForApps(host)
            mainFrame.openDeeplinkHost(host, showHiddenApps: target.appID != nil)
        }
    }

    @objc(isWaitingForAppsForHost:)
    func isWaitingForApps(for host: TemporaryHost?) -> Bool {
        guard case .waitingForApps(let expectedHost) = stage else { return false }
        return expectedHost === host
    }

    func appsDidRefresh(for host: TemporaryHost) {
        guard isWaitingForApps(for: host), let mainFrame, mainFrame.isInAppView() else { return }
        guard let appID = target?.appID else {
            reset()
            return
        }
        let apps = mainFrame.sortedAppList ?? []
        guard let index = apps.firstIndex(where: { $0.id == appID }) else {
            reset()
            showNotice("DeepLink app was not found.".localized)
            return
        }
        stage = .highlightingApp
        highlight(mainFrame, index: index) { [weak self, weak mainFrame] in
            self?.reset()
            guard let mainFrame, mainFrame.isInAppView(),
                  let app = mainFrame.sortedAppList?.first(where: { $0.host === host && $0.id == appID }) else { return }
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
        clearHighlight?()
        clearHighlight = nil
        hostDeadline = nil
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
