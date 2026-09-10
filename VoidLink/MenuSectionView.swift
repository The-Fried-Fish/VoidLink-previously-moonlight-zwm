//
//  MenuSectionView.m -> MenuSectionView.swift
//  VoidLink
//
//  Created by True砖家 on 2025.5.18
//  Copyright © 2025 True砖家 @ Bilibili. All rights reserved.
//

import UIKit

@available(iOS 13.0, *)
enum MenuSectionIconPipeline {
    static func configuredImage(
        _ icon: UIImage?,
        pointSize: CGFloat,
        symbolWeight: UIImage.SymbolWeight
    ) -> UIImage? {
        guard var displayIcon = icon else { return nil }

        let configuration: UIImage.SymbolConfiguration
        if displayIcon.isSymbolImage {
            configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: symbolWeight)
        } else {
            configuration = UIImage.SymbolConfiguration(pointSize: pointSize)
            displayIcon = displayIcon.withRenderingMode(.alwaysTemplate)
        }
        return displayIcon.withConfiguration(configuration)
    }
}

@objc
protocol MenuSectionDelegate: NSObjectProtocol {
    func hideOverlappedDynamicLabels()
    func getSettingsMenuMode() -> SettingsMenuMode
}

@objcMembers
class MenuSectionView: UIView {
    static var overridePersistedFoldState = true

    var rootStackView: UIStackView!
    var leadingTrailingPadding: CGFloat = 5 {
        didSet {
            updateLayout()
        }
    }
    var separatorLinePadding: CGFloat = 40
    var titleLabel: UILabel!
    var sectionTitle: String = "Section" {
        didSet {
            titleLabel?.text = sectionTitle
        }
    }
    var identifier: String?
    var isExpanded = true
    var expandable = true
    var lockedSectionHandler: (() -> Void)?
    var rootStackViewSpacing: CGFloat = UIDevice.current.userInterfaceIdiom == .phone ? 10 : 12 {
        didSet {
            rootStackView?.spacing = rootStackViewSpacing
            updateLayout()
        }
    }
    var headerViewHeight: CGFloat = 37
    var headerViewVerticalSpacing: CGFloat = 25
    var subStackViews = NSMutableArray()
    var iconImageView: UIImageView!
    var separatorLine: UIView!
    weak var delegate: MenuSectionDelegate?

    private var toggleButton: UIButton!
    private var toggleArea: UIButton!
    private var heightConstraint: NSLayoutConstraint!
    var headerView: UIView!
    private var titleOffset: CGFloat = 41.5

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        layer.cornerRadius = 10
        layer.masksToBounds = true
        backgroundColor = .clear

        headerView = UIButton()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.accessibilityIdentifier = "sectionHeader"
        addSubview(headerView)

        iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.tintColor = ThemeManager.textColor
        headerView.addSubview(iconImageView)

        titleLabel = UILabel()
        titleLabel.text = sectionTitle
        titleLabel.accessibilityIdentifier = "menuSectionTitleLabel"
        titleLabel.font = .systemFont(ofSize: 19.5, weight: .medium)
        titleLabel.textColor = ThemeManager.textColor
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(titleLabel)

        toggleButton = UIButton(type: .system)
        toggleArea = UIButton(type: .system)
        if #available(iOS 13.0, *) {
            let config = UIImage.SymbolConfiguration(pointSize: headerViewHeight * 0.31, weight: .bold)
            toggleButton.setImage(UIImage(systemName: "chevron.right", withConfiguration: config), for: .normal)
        }
        toggleButton.addTarget(self, action: #selector(toggleFold), for: .touchUpInside)
        toggleArea.addTarget(self, action: #selector(toggleFold), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleArea.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.contentEdgeInsets = UIEdgeInsets(top: -10, left: -10, bottom: -10, right: -10)
        headerView.addSubview(toggleButton)
        headerView.addSubview(toggleArea)

        rootStackView = UIStackView()
        rootStackView.axis = .vertical
        rootStackView.spacing = rootStackViewSpacing
        rootStackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rootStackView)

        separatorLine = UIView()
        separatorLine.backgroundColor = ThemeManager.separatorColor
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        addSubview(separatorLine)

        heightConstraint = heightAnchor.constraint(equalToConstant: 44)
        heightConstraint.isActive = true

        setupConstraints()
        updateViewForFoldState()

        lockedSectionHandler = {
            NSLog("Null execution of lockedSectionHandler")
        }
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            headerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: headerViewHeight),
        ])

        if #available(iOS 13.0, *) {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: titleOffset),
                titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                titleLabel.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -8),
            ])
        } else {
            NSLayoutConstraint.activate([
                titleLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
                titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
                titleLabel.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -8),
            ])
        }

        NSLayoutConstraint.activate([
            toggleButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -leadingTrailingPadding),
            toggleButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: headerViewHeight * 0.8),
            toggleButton.heightAnchor.constraint(equalToConstant: headerViewHeight * 0.8),
        ])

        NSLayoutConstraint.activate([
            toggleArea.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            toggleArea.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            toggleArea.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor),
            toggleArea.heightAnchor.constraint(equalToConstant: headerViewHeight + 25),
        ])

        layoutIfNeeded()

        NSLayoutConstraint.activate([
            rootStackView.topAnchor.constraint(equalTo: topAnchor, constant: headerViewHeight + headerViewVerticalSpacing),
            rootStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingTrailingPadding),
            rootStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -leadingTrailingPadding),
            rootStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
        ])

        clipsToBounds = false
        NSLayoutConstraint.activate([
            separatorLine.centerXAnchor.constraint(equalTo: centerXAnchor),
            separatorLine.widthAnchor.constraint(equalTo: widthAnchor, constant: -5),
            separatorLine.bottomAnchor.constraint(equalTo: bottomAnchor),
            separatorLine.heightAnchor.constraint(equalToConstant: GenericUtils.menuSectionSeparatorWidth),
        ])

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: topAnchor),
            rootStackView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
        ])
    }

    @objc(setSectionWithIcon:size:sizeConstraint:)
    func setSection(withIcon icon: UIImage?, size: CGFloat, sizeConstraint constant: CGFloat) {
        if #available(iOS 13.0, *) {
            iconImageView.image = MenuSectionIconPipeline.configuredImage(
                icon,
                pointSize: size,
                symbolWeight: .bold
            )
        } else {
            iconImageView.image = icon
        }
        iconImageView.tintColor = ThemeManager.textColor
        iconImageView.isHidden = icon == nil

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: headerView.leadingAnchor, constant: leadingTrailingPadding + headerViewHeight / 2 - 3),
            iconImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: headerViewHeight + constant),
            iconImageView.heightAnchor.constraint(equalToConstant: headerViewHeight + constant),
        ])

        updateLayout()
    }

    @available(iOS 13.0, *)
    @objc(setSectionWithIcon:size:weight:sizeConstraint:)
    func setSection(withIcon icon: UIImage?, size: CGFloat, weight: UIImage.SymbolWeight, sizeConstraint constant: CGFloat) {
        iconImageView.image = MenuSectionIconPipeline.configuredImage(
            icon,
            pointSize: size,
            symbolWeight: weight
        )
        iconImageView.tintColor = ThemeManager.textColor
        iconImageView.isHidden = icon == nil

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: headerView.leadingAnchor, constant: leadingTrailingPadding + headerViewHeight / 2 - 3),
            iconImageView.centerYAnchor.constraint(equalTo: headerView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: headerViewHeight + constant),
            iconImageView.heightAnchor.constraint(equalToConstant: headerViewHeight + constant),
        ])

        updateLayout()
    }

    @objc(setExpanded:)
    func setExpanded(_ isExpanded: Bool) {
        self.isExpanded = !expandable ? false : isExpanded
        updateViewForFoldState()
        if let identifier {
            UserDefaults.standard.set(self.isExpanded, forKey: identifier)
            UserDefaults.standard.synchronize()
        }
    }

    func addSubStackView(_ stackView: UIStackView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        UIView.performWithoutAnimation {
            if !subStackViews.contains(stackView) {
                subStackViews.add(stackView)
                rootStackView.addArrangedSubview(stackView)
            }
        }
        CATransaction.commit()
    }

    func add(toParentStack parentStack: UIStackView) {
        parentStack.insertArrangedSubview(self, at: parentStack.arrangedSubviews.count)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parentStack.leadingAnchor),
            trailingAnchor.constraint(equalTo: parentStack.trailingAnchor),
        ])

        let persistedFoldState: Bool
        if let identifier, UserDefaults.standard.object(forKey: identifier) != nil {
            persistedFoldState = UserDefaults.standard.bool(forKey: identifier)
        } else {
            persistedFoldState = true
        }
        setExpanded(MenuSectionView.overridePersistedFoldState ? expandable : persistedFoldState)
        
        headerView.accessibilityIdentifier = "\(self.headerView.accessibilityIdentifier ?? "sectionHeader")-\(self.identifier ?? "")"
    }

    func removeSubStackView(_ stackView: UIStackView) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if subStackViews.contains(stackView) {
            subStackViews.remove(stackView)
            rootStackView.removeArrangedSubview(stackView)
            stackView.removeFromSuperview()
            updateLayout()
        }
        CATransaction.commit()
    }

    func updateLayout() {
        for constraint in constraints {
            if constraint.firstItem === rootStackView && constraint.firstAttribute == .leading {
                constraint.constant = leadingTrailingPadding
            } else if constraint.firstItem === rootStackView && constraint.firstAttribute == .trailing {
                constraint.constant = -leadingTrailingPadding
            }
        }

        for constraint in headerView.constraints {
            if constraint.firstItem === iconImageView && constraint.firstAttribute == .leading {
                constraint.constant = leadingTrailingPadding
            } else if constraint.firstItem === toggleButton && constraint.firstAttribute == .trailing {
                constraint.constant = -leadingTrailingPadding
            }
        }

        setNeedsLayout()
        layoutIfNeeded()
    }

    @objc func toggleFold() {
        isExpanded = !expandable ? false : !isExpanded
        if !expandable {
            lockedSectionHandler?()
        }
        updateViewForFoldState()
        if let identifier {
            UserDefaults.standard.set(isExpanded, forKey: identifier)
            UserDefaults.standard.synchronize()
        }
    }

    func getSettingsMenuMode() -> SettingsMenuMode {
        let allSettings = SettingsMenuMode(rawValue: 0)!
        if delegate?.responds(to: #selector(MenuSectionDelegate.getSettingsMenuMode)) == true {
            return delegate?.getSettingsMenuMode() ?? allSettings
        }
        return allSettings
    }

    func updateViewForFoldState() {
        let visibleCount = rootStackView.arrangedSubviews.filter { !$0.isHidden }.count
        isHidden = visibleCount == 0

        if isExpanded {
            rootStackView.isHidden = false
            separatorLine.isHidden = false
            var fittingSize = rootStackView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            let rootStackViewHeight = fittingSize.height
            fittingSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            let headerHeight = fittingSize.height

            heightConstraint.constant = headerHeight + headerViewVerticalSpacing + rootStackViewHeight + separatorLinePadding + 1

            UIView.animate(withDuration: 0) {
                self.toggleButton.transform = CGAffineTransform(rotationAngle: .pi / 2)
                NSLayoutConstraint.activate([
                    self.rootStackView.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -self.separatorLinePadding),
                ])
                self.layoutIfNeeded()
            }
        } else {
            let fittingSize = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
            rootStackView.isHidden = true
            separatorLine.isHidden = false
            heightConstraint.constant = fittingSize.height + headerViewVerticalSpacing

            UIView.animate(withDuration: 0) {
                self.toggleButton.transform = .identity
                NSLayoutConstraint.activate([
                    self.headerView.topAnchor.constraint(equalTo: self.topAnchor),
                ])
                self.layoutIfNeeded()
            }
        }

        if delegate?.responds(to: #selector(MenuSectionDelegate.hideOverlappedDynamicLabels)) == true {
            delegate?.hideOverlappedDynamicLabels()
        }
    }
}
