//
//  HostCardView.m -> HostCardView.swift
//  VoidLink
//
//  Created by True砖家 on 2025.5.18
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

import UIKit

@objc
protocol HostCardActionDelegate: NSObjectProtocol {
    @objc(appButtonTappedForHost:)
    func appButtonTapped(for host: TemporaryHost)
    @objc(launchButtonTappedForHost:)
    func launchButtonTapped(for host: TemporaryHost)
    @objc(wakeupButtonTappedForHost:)
    func wakeupButtonTapped(for host: TemporaryHost)
    @objc(pairButtonTappedForHost:)
    func pairButtonTapped(for host: TemporaryHost)
    @objc(hostCardLongPressed:view:)
    func hostCardLongPressed(_ host: TemporaryHost, view: UIView)
    @objc(isStreaming)
    func isStreaming() -> Bool
}

@objcMembers
class HostCardView: UIView {
    var sizeFactor: CGFloat = 1
    private(set) var size: CGSize = .zero
    weak var delegate: HostCardActionDelegate?

    private var iconBackgroundView: UIView!
    private var hostIconView: UIImageView!
    private var hostNameLabel: UILabel!
    private var statusIcon: UIImageView!
    private var statusLabel: UILabel!
    private var appButton: UIButton!
    private var launchButton: UIButton!
    private var pairButton: UIButton!
    private var wakeupButton: UIButton!
    private var transparentButton: UIButton!
    private var widthConstraint: NSLayoutConstraint!
    private var heightConstraint: NSLayoutConstraint!
    private var separatorLine: UIView!
    private var cardContentpadding: CGFloat = 0

    private var host: TemporaryHost?
    private var hostSpinner: UIActivityIndicatorView!
    private var lockIconView: UIImageView!
    private var computerIconMonitorCenterYOffset: CGFloat = 0
    private var buttonHeight: CGFloat = 0
    private var buttonLabelFontSize: CGFloat = 0
    private var iconAndButtonSpacing: CGFloat = 0
    private var defaultBlue: UIColor = ThemeManager.appPrimaryColor
    private var defaultGreen: UIColor = UIColor(red: 52 / 255, green: 199 / 255, blue: 89 / 255, alpha: 1)
    private var backgroundLayer: CAGradientLayer!
    private var longPressFired = false

    private static let refreshCycle: TimeInterval = 2
    private let stateUnknown = State(rawValue: 0)!
    private let stateOffline = State(rawValue: 1)!
    private let stateOnline = State(rawValue: 2)!
    private let pairStatePaired = PairState(rawValue: 2)!

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    @objc(initWithHost:)
    convenience init(host: TemporaryHost) {
        self.init(host: host, andSizeFactor: 1)
    }

    @objc(initWithHost:andSizeFactor:)
    init(host: TemporaryHost, andSizeFactor sizeFactor: CGFloat) {
        self.sizeFactor = sizeFactor
        self.host = host
        super.init(frame: .zero)
        commonInit()
    }

    private func commonInit() {
        buttonLabelFontSize = 15 * sizeFactor
        longPressFired = false
        computerIconMonitorCenterYOffset = isIPhone() ? -2.75 * sizeFactor : -3.2 * sizeFactor
        iconAndButtonSpacing = 37 * sizeFactor
        buttonHeight = 39 * sizeFactor
        defaultBlue = ThemeManager.appPrimaryColor
        defaultGreen = UIColor(red: 52 / 255, green: 199 / 255, blue: 89 / 255, alpha: 1)

        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(hostCardLongPressed(_:)))
        addGestureRecognizer(longPressRecognizer)

        createBackgroundLayer()
        setupUI()
    }

    private func isIPhone() -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    @objc func appButtonTapped() {
        guard host?.pairState == pairStatePaired, host?.state == .online, self.parentViewController?.hasNoPresentedVC == true else { return }
        if longPressFired {
            longPressFired = false
            return
        }
        guard let host else { return }
        if let delegate {
            delegate.appButtonTapped(for: host)
        } else {
            NSLog("Delegate not set or does not respond to appButtonTappedForHost:")
        }
    }

    @objc func launchButtonTapped() {
        guard host?.pairState == pairStatePaired, host?.state == .online, self.parentViewController?.hasNoPresentedVC == true else { return }
        if longPressFired {
            longPressFired = false
            return
        }
        guard let host else { return }
        if let delegate {
            delegate.launchButtonTapped(for: host)
        } else {
            NSLog("Delegate not set or does not respond to launchButtonTappedForHost:")
        }
    }

    @objc func wakeupButtonTapped() {
        guard host?.state != .online, self.parentViewController?.hasNoPresentedVC == true else { return }
        if longPressFired {
            longPressFired = false
            return
        }
        guard let host else { return }
        if let delegate {
            delegate.wakeupButtonTapped(for: host)
        } else {
            NSLog("Delegate not set or does not respond to launchButtonTappedForHost:")
        }
    }

    @objc func pairButtonTapped() {
        guard !pairButton.isHidden, self.parentViewController?.hasNoPresentedVC == true else { return }
        if longPressFired {
            longPressFired = false
            return
        }
        guard let host else { return }
        if let delegate {
            delegate.pairButtonTapped(for: host)
        } else {
            NSLog("Delegate not set or does not respond to pairButtonTappedForHost:")
        }
    }

    @objc func hostCardLongPressed(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let host else { return }
        longPressFired = true
        if let delegate {
            delegate.hostCardLongPressed(host, view: self)
        } else {
            NSLog("Delegate not set or does not respond")
        }
    }

    @objc(resizeBySizeFactor:)
    func resizeBySizeFactor(_ factor: CGFloat) {
        subviews.forEach { $0.removeFromSuperview() }
        sizeFactor = factor
        setupUI()
    }

    private func setupUI() {
        isUserInteractionEnabled = true
        backgroundColor = ThemeManager.widgetBackgroundColor
        cardContentpadding = 13 * sizeFactor
        clipsToBounds = true
        translatesAutoresizingMaskIntoConstraints = false

        let appButtonWidth = 100 * sizeFactor
        let launchButtonWidth = 120 * sizeFactor
        let cardWidth = cardContentpadding * 2 + appButtonWidth + 15 * sizeFactor + launchButtonWidth
        layer.cornerRadius = 2 * CGFloat(UInt16(cardWidth * 0.0603 / 2))
        if #available(iOS 13.0, *) {
            layer.cornerCurve = .continuous
        }

        heightConstraint = heightAnchor.constraint(equalToConstant: 300)
        heightConstraint.isActive = true
        widthConstraint = widthAnchor.constraint(equalToConstant: 300)
        widthConstraint.isActive = true

        iconBackgroundView = UIView(frame: CGRect(x: cardContentpadding, y: cardContentpadding, width: 80 * sizeFactor, height: 80 * sizeFactor))
        iconBackgroundView.backgroundColor = defaultBlue
        iconBackgroundView.layer.cornerRadius = 2 * CGFloat(UInt16(20 * sizeFactor / 2))
        if #available(iOS 13.0, *) {
            iconBackgroundView.layer.cornerCurve = .continuous
        }
        addSubview(iconBackgroundView)

        hostIconView = UIImageView()
        hostIconView.translatesAutoresizingMaskIntoConstraints = false
        hostIconView.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *) {
            hostIconView.image = UIImage(named: "display")?.withRenderingMode(.alwaysTemplate)
        } else {
            hostIconView.image = UIImage(named: "Computer")
            NSLayoutConstraint.activate([
                hostIconView.heightAnchor.constraint(equalToConstant: 57 * sizeFactor),
                hostIconView.widthAnchor.constraint(equalToConstant: 57 * sizeFactor),
            ])
        }
        hostIconView.tintColor = .white
        iconBackgroundView.addSubview(hostIconView)
        NSLayoutConstraint.activate([
            hostIconView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            hostIconView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            hostIconView.heightAnchor.constraint(equalToConstant: 53.9 * sizeFactor),
            hostIconView.widthAnchor.constraint(equalToConstant: 53.9 * sizeFactor),
        ])

        let oldIOS: Bool
        if #available(iOS 13.0, *) {
            oldIOS = false
        } else {
            oldIOS = true
        }

        hostSpinner = UIActivityIndicatorView(style: .white)
        hostSpinner.isUserInteractionEnabled = false
        hostSpinner.translatesAutoresizingMaskIntoConstraints = false
        hostSpinner.hidesWhenStopped = true
        iconBackgroundView.addSubview(hostSpinner)
        NSLayoutConstraint.activate([
            hostSpinner.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            hostSpinner.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor, constant: oldIOS ? -5.5 * sizeFactor : computerIconMonitorCenterYOffset),
        ])
        let spinnerSizeFactor = sizeFactor * (PublicUtils.isTVOS ? 0.5 : 1)
        hostSpinner.transform = CGAffineTransform(scaleX: spinnerSizeFactor, y: spinnerSizeFactor)
        hostSpinner.stopAnimating()

        lockIconView = UIImageView()
        lockIconView.translatesAutoresizingMaskIntoConstraints = false
        lockIconView.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *) {
            lockIconView.image = UIImage(named: "lock.fill")?.withRenderingMode(.alwaysTemplate)
        } else {
            lockIconView.image = UIImage(named: "LockedOverlayIcon")
            computerIconMonitorCenterYOffset = -5 * sizeFactor
        }
        lockIconView.tintColor = .white
        iconBackgroundView.addSubview(lockIconView)
        NSLayoutConstraint.activate([
            lockIconView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            lockIconView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor, constant: computerIconMonitorCenterYOffset),
            lockIconView.widthAnchor.constraint(equalToConstant: 17.05 * sizeFactor),
            lockIconView.heightAnchor.constraint(equalToConstant: 17.05 * sizeFactor),
        ])
        lockIconView.isHidden = true

        let hostNameLabelCoordX = cardContentpadding + iconBackgroundView.frame.size.width + 16 * sizeFactor
        hostNameLabel = UILabel(frame: CGRect(x: hostNameLabelCoordX, y: cardContentpadding + iconBackgroundView.frame.size.height * 0.02, width: cardWidth - hostNameLabelCoordX - cardContentpadding, height: 30 * sizeFactor))
        hostNameLabel.numberOfLines = 1
        hostNameLabel.adjustsFontSizeToFitWidth = true
        hostNameLabel.minimumScaleFactor = 0.8
        hostNameLabel.lineBreakMode = .byTruncatingTail
        hostNameLabel.text = "RazerBlade 16"
        hostNameLabel.textColor = .white
        hostNameLabel.font = .boldSystemFont(ofSize: 18 * sizeFactor)
        addSubview(hostNameLabel)

        statusLabel = UILabel(frame: CGRect(x: 205, y: 68, width: 100, height: 24))
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = LocalizationHelper.localizedString(forKey: "Online")
        statusLabel.font = .systemFont(ofSize: 14 * sizeFactor, weight: .medium)
        statusLabel.textColor = defaultGreen

        statusIcon = UIImageView(frame: CGRect(x: 0, y: 0, width: 16 * sizeFactor, height: 16 * sizeFactor))
        statusIcon.contentMode = .scaleAspectFit
        statusIcon.translatesAutoresizingMaskIntoConstraints = false
        statusIcon.image = UIImage(named: "wifi_green")?.withRenderingMode(.alwaysOriginal)
        addSubview(statusIcon)
        addSubview(statusLabel)
        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: statusIcon.trailingAnchor, constant: 3 * sizeFactor),
            statusLabel.topAnchor.constraint(equalTo: hostNameLabel.bottomAnchor),
            statusIcon.centerYAnchor.constraint(equalTo: statusLabel.centerYAnchor),
            statusIcon.leadingAnchor.constraint(equalTo: hostNameLabel.leadingAnchor),
            statusIcon.widthAnchor.constraint(equalToConstant: 16 * sizeFactor),
        ])
        
#if !os(tvOS)
        let defaultButtonType: UIButton.ButtonType = .system
#else
        let defaultButtonType: UIButton.ButtonType = .plain
#endif

        appButton = UIButton(type: defaultButtonType)
        appButton.translatesAutoresizingMaskIntoConstraints = false
        appButton.frame = CGRect(x: 20, y: 200, width: 150, height: buttonHeight)
        appButton.setTitle(LocalizationHelper.localizedString(forKey: "Applications"), for: .normal)
        appButton.setTitleColor(ThemeManager.textColorGray, for: .normal)
        appButton.titleLabel?.font = .systemFont(ofSize: buttonLabelFontSize)
        appButton.addTarget(self, action: #selector(appButtonTapped), for: .primaryActionTriggered)
        addSubview(appButton)
        NSLayoutConstraint.activate([
            appButton.leadingAnchor.constraint(equalTo: iconBackgroundView.leadingAnchor),
            appButton.topAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: iconAndButtonSpacing),
            appButton.widthAnchor.constraint(equalToConstant: appButtonWidth),
            appButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])

        launchButton = UIButton(type: defaultButtonType)
        launchButton.translatesAutoresizingMaskIntoConstraints = false
        launchButton.frame = CGRect(x: 0, y: 0, width: 150, height: 50)
        launchButton.backgroundColor = defaultBlue
        launchButton.layer.cornerRadius = 2 * CGFloat(UInt16(cardWidth * 0.0377 / 2))
        if #available(iOS 13.0, *) {
            launchButton.layer.cornerCurve = .continuous
        }
        launchButton.setTitle(LocalizationHelper.localizedString(forKey: "  Launch"), for: .normal)
        launchButton.setTitleColor(.white, for: .normal)
        launchButton.titleLabel?.font = .boldSystemFont(ofSize: buttonLabelFontSize)
        launchButton.tintColor = .white
        launchButton.addTarget(self, action: #selector(launchButtonTapped), for: .primaryActionTriggered)
        addSubview(launchButton)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: buttonHeight * 0.263)
            launchButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
        }
        NSLayoutConstraint.activate([
            launchButton.leadingAnchor.constraint(equalTo: appButton.trailingAnchor, constant: 15 * sizeFactor),
            launchButton.centerYAnchor.constraint(equalTo: appButton.centerYAnchor),
            launchButton.widthAnchor.constraint(equalToConstant: launchButtonWidth),
            launchButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])

        pairButton = UIButton(type: defaultButtonType)
        pairButton.translatesAutoresizingMaskIntoConstraints = false
        pairButton.frame = CGRect(x: 0, y: 0, width: 150, height: 50)
        pairButton.backgroundColor = ThemeManager.textTintColorWithAlpha
        pairButton.layer.cornerRadius = 2 * CGFloat(UInt16(cardWidth * 0.0377 / 2))
        if #available(iOS 13.0, *) {
            pairButton.layer.cornerCurve = .continuous
        }
        pairButton.setTitle(LocalizationHelper.localizedString(forKey: "  Pair with PIN"), for: .normal)
        pairButton.setTitleColor(defaultBlue, for: .normal)
        pairButton.titleLabel?.font = .boldSystemFont(ofSize: buttonLabelFontSize)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: buttonHeight / 3.4, weight: .bold)
            let templateImage = UIImage(systemName: "lock.open.fill", withConfiguration: config)
            let coloredImage = templateImage?.withTintColor(defaultBlue, renderingMode: .alwaysOriginal)
            pairButton.setImage(coloredImage, for: .normal)
        }
        pairButton.addTarget(self, action: #selector(pairButtonTapped), for: .primaryActionTriggered)
        addSubview(pairButton)
        NSLayoutConstraint.activate([
            pairButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: cardContentpadding),
            pairButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -cardContentpadding),
            pairButton.topAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: iconAndButtonSpacing),
            pairButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])

        wakeupButton = UIButton(type: defaultButtonType)
        wakeupButton.translatesAutoresizingMaskIntoConstraints = false
        wakeupButton.frame = CGRect(x: 0, y: 0, width: 150, height: 50)
        wakeupButton.backgroundColor = ThemeManager.textTintColorWithAlpha
        wakeupButton.layer.cornerRadius = 2 * CGFloat(UInt16(cardWidth * 0.0377 / 2))
        if #available(iOS 13.0, *) {
            wakeupButton.layer.cornerCurve = .continuous
        }
        wakeupButton.setTitle(LocalizationHelper.localizedString(forKey: "  Wake-on-LAN"), for: .normal)
        wakeupButton.setTitleColor(defaultBlue, for: .normal)
        wakeupButton.titleLabel?.font = .boldSystemFont(ofSize: buttonLabelFontSize)
        wakeupButton.addTarget(self, action: #selector(wakeupButtonTapped), for: .primaryActionTriggered)
        addSubview(wakeupButton)
        NSLayoutConstraint.activate([
            wakeupButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: cardContentpadding),
            wakeupButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -cardContentpadding),
            wakeupButton.topAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: iconAndButtonSpacing),
            wakeupButton.heightAnchor.constraint(equalToConstant: buttonHeight),
        ])

        separatorLine = UIView()
        separatorLine.backgroundColor = UIColor(white: 0.3, alpha: 5)
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)
        NSLayoutConstraint.activate([
            separatorLine.leadingAnchor.constraint(equalTo: leadingAnchor, constant: cardContentpadding),
            separatorLine.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -cardContentpadding),
            separatorLine.centerYAnchor.constraint(equalTo: iconBackgroundView.bottomAnchor, constant: iconAndButtonSpacing / 2),
            separatorLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),
        ])

        transparentButton = UIButton(type: .custom)
        transparentButton.translatesAutoresizingMaskIntoConstraints = false
        transparentButton.backgroundColor = .clear
        transparentButton.setTitle("", for: .normal)
        transparentButton.setImage(nil, for: .normal)
        transparentButton.addTarget(self, action: #selector(appButtonTapped), for: .primaryActionTriggered)
        addSubview(transparentButton)
        NSLayoutConstraint.activate([
            transparentButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            transparentButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            transparentButton.topAnchor.constraint(equalTo: topAnchor),
            transparentButton.bottomAnchor.constraint(equalTo: separatorLine.topAnchor),
        ])

        widthConstraint.constant = cardContentpadding * 2 + appButtonWidth + 15 * sizeFactor + launchButtonWidth
        heightConstraint.constant = cardContentpadding * 2 + iconBackgroundView.frame.size.height + iconAndButtonSpacing + buttonHeight + 1
        size = CGSize(width: widthConstraint.constant, height: heightConstraint.constant)

        updateTheme()
    }

    private func updateBackgroundLayerTheme() {
        let gradientColorDark = UIColor(red: 0, green: 0.319, blue: 0.64, alpha: 1)
        let gradientColorLight = gradientColorDark.withAlphaComponent(0.52)
        let gradientColor = ThemeManager.userInterfaceStyle() == .dark ? gradientColorDark.cgColor : gradientColorLight.cgColor
        backgroundLayer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            gradientColor,
        ]
    }

    private func createBackgroundLayer() {
        backgroundLayer = CAGradientLayer()
        updateBackgroundLayerTheme()
        backgroundLayer.locations = [0, 0.18, 0.5, 1]
        backgroundLayer.startPoint = CGPoint(x: 0.25, y: 0.5)
        backgroundLayer.endPoint = CGPoint(x: 0.75, y: 0.5)
        let transform = CGAffineTransform(a: -1.01, b: -1, c: 1, d: -3.67, tx: 0.5, ty: 2.83)
        backgroundLayer.transform = CATransform3DMakeAffineTransform(transform)
        layer.insertSublayer(backgroundLayer, at: 0)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        backgroundLayer.bounds = bounds.insetBy(dx: -0.5 * bounds.size.width, dy: -0.5 * bounds.size.height)
        backgroundLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        updateContents(for: host)
    }

    func tintAdjustmentModeDidChange() {
        tintAdjustmentMode = .normal
    }

    func updateTheme() {
        backgroundColor = ThemeManager.widgetBackgroundColor
        hostNameLabel?.textColor = ThemeManager.textColor
        appButton?.setTitleColor(ThemeManager.appPrimaryColor, for: .normal)
        separatorLine?.backgroundColor = ThemeManager.hostCardSeparatorColor

        backgroundLayer?.isHidden = false
        updateBackgroundLayerTheme()
        updateContents(for: host)
    }

    override func didMoveToSuperview() {
        if superview != nil && host != nil {
            NSLog("start update loop")
            updateLoop()
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    }

    private func isDarkTheme() -> Bool {
        ThemeManager.userInterfaceStyle() == .dark
    }

    @objc func updateLoop() {
        if superview == nil || delegate?.isStreaming() == true {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now()+0.36) { [weak self] in
            self?.updateContents(for: self?.host)
        }
        
        perform(#selector(updateLoop), with: self, afterDelay: Self.refreshCycle)
    }

    private func updateContents(for host: TemporaryHost?) {
        guard let host else { return }

        hostNameLabel.text = host.name
        backgroundLayer.isHidden = !(host.state == stateOnline && host.pairState == pairStatePaired)

        let hostPaired = host.pairState == pairStatePaired
        let hasValidMac = host.mac != nil && host.mac != "00:00:00:00:00:00"

        switch host.state {
        case stateOnline:
            hostSpinner.stopAnimating()
            statusLabel.textColor = defaultGreen
            statusLabel.text = LocalizationHelper.localizedString(forKey: "Online")
            statusIcon.image = UIImage(named: "wifi_green")?.withRenderingMode(.alwaysOriginal)
            statusIcon.isHidden = false
            appButton.titleLabel?.font = .systemFont(ofSize: buttonLabelFontSize)
            if host.pairState == pairStatePaired {
                hostIconView.tintColor = .white
                iconBackgroundView.backgroundColor = defaultBlue
                lockIconView.isHidden = true
                appButton.setTitle(LocalizationHelper.localizedString(forKey: "Applications"), for: .normal)
                launchButton.setTitle(LocalizationHelper.localizedString(forKey: "  Launch"), for: .normal)
                appButton.isEnabled = true
                launchButton.isEnabled = true
                appButton.isHidden = false
                launchButton.isHidden = false
                pairButton.isHidden = true
                wakeupButton.isHidden = true
                appButton.setTitleColor(defaultBlue, for: .normal)
                if #available(iOS 13.0, *) {
                    let config = UIImage.SymbolConfiguration(pointSize: buttonHeight * 0.263)
                    launchButton.setImage(UIImage(systemName: "play.fill", withConfiguration: config), for: .normal)
                }
                launchButton.backgroundColor = defaultBlue
                launchButton.setTitleColor(.white, for: .normal)
            } else {
                iconBackgroundView.backgroundColor = ThemeManager.appPrimaryColorWithAlpha
                let iconColor = UIColor.white.withAlphaComponent(isDarkTheme() ? 0.63 : 1)
                hostIconView.tintColor = iconColor
                lockIconView.tintColor = iconColor
                lockIconView.isHidden = false
                appButton.isHidden = true
                launchButton.isHidden = true
                pairButton.isHidden = false
                wakeupButton.isHidden = true
            }

        case stateOffline:
            hostSpinner.stopAnimating()
            iconBackgroundView.backgroundColor = ThemeManager.offlineHostIconBackgroundColor
            statusLabel.textColor = ThemeManager.textColorGray
            statusLabel.text = LocalizationHelper.localizedString(forKey: "Offline")
            statusIcon.tintColor = ThemeManager.textColorGray
            if #available(iOS 13.0, *) {
                statusIcon.image = UIImage(systemName: "exclamationmark.triangle.fill")
            } else {
                statusIcon.isHidden = true
            }

            hostIconView.tintColor = ThemeManager.lowProfileGray
            lockIconView.tintColor = ThemeManager.lowProfileGray
            lockIconView.isHidden = hostPaired
            appButton.isHidden = true
            launchButton.isHidden = true
            pairButton.isHidden = true
            wakeupButton.isHidden = false

            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: buttonHeight / 3.45, weight: .bold)
                let templateImage = UIImage(systemName: "power", withConfiguration: config)
                let color = hasValidMac ? defaultBlue : ThemeManager.textColorGray
                wakeupButton.setImage(templateImage?.withTintColor(color, renderingMode: .alwaysOriginal), for: .normal)
            }

            wakeupButton.backgroundColor = hasValidMac ? ThemeManager.textTintColorWithAlpha : ThemeManager.textColorGray.withAlphaComponent(0.2)
            wakeupButton.setTitleColor(hasValidMac ? defaultBlue : ThemeManager.textColorGray, for: .normal)

        case stateUnknown:
            hostSpinner.color = .white
            hostSpinner.startAnimating()
            iconBackgroundView.backgroundColor = ThemeManager.appPrimaryColorWithAlpha
            statusLabel.textColor = ThemeManager.textColorGray
            statusLabel.text = LocalizationHelper.localizedString(forKey: "Detecting...")
            statusIcon.tintColor = ThemeManager.textColorGray
            if #available(iOS 13.0, *) {
                statusIcon.image = UIImage(systemName: "antenna.radiowaves.left.and.right")
            } else {
                statusIcon.isHidden = true
            }
            hostIconView.tintColor = defaultBlue
            lockIconView.isHidden = true
            appButton.isHidden = true
            launchButton.isHidden = true
            pairButton.isHidden = true
            wakeupButton.isHidden = false

            if #available(iOS 13.0, *) {
                let config = UIImage.SymbolConfiguration(pointSize: buttonHeight / 3.45, weight: .bold)
                let templateImage = UIImage(systemName: "power", withConfiguration: config)
                let color = hasValidMac ? defaultBlue : ThemeManager.textColorGray
                wakeupButton.setImage(templateImage?.withTintColor(color, renderingMode: .alwaysOriginal), for: .normal)
            }
            wakeupButton.backgroundColor = hasValidMac ? ThemeManager.textTintColorWithAlpha : ThemeManager.textColorGray.withAlphaComponent(0.2)
            wakeupButton.setTitleColor(hasValidMac ? defaultBlue : ThemeManager.textColorGray, for: .normal)

        default:
            break
        }
    }
}
