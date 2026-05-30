//
//  LayoutOnScreenControlsViewController.m -> LayoutOnScreenControlsViewController.swift
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

import UIKit

@objcMembers
final class LayoutOnScreenControlsViewController: UIViewController, OnScreenWidgetView.OnScreenWidgetLayoutUpdateDelegate, UITextFieldDelegate {
    private enum AlphaSliderMode: Int {
        case widgetAlpha
        case labelAlpha
        case borderAlpha
        case highlightAlpha
    }

    private enum BorderWidthSliderMode: Int {
        case widgetBorderWidth
        case highlightSize
    }

    private enum DecelerationRateSliderMode: Int {
        case decelerationRateX
        case decelerationRateY
    }

    var layoutOSC: LayoutOnScreenControls!
    var onScreenWidgetViews = NSMutableSet()
    var OSCSegmentSelected: Int = 0
    dynamic var quickSwitchEnabled = false

    @IBOutlet weak var trashCanButton: UIButton!
    @IBOutlet weak var undoButton: UIButton!

    @IBOutlet weak var toolbarRootView: ToolBarContainerView!
    @IBOutlet weak var chevronView: UIView!
    @IBOutlet weak var chevronImageView: UIImageView!
    @IBOutlet weak var toolbarStackView: UIStackView!

    @IBOutlet weak var currentProfileLabel: UILabel!
    @IBOutlet weak var widgetSizeLabel: UILabel!
    @IBOutlet weak var widgetSizeSlider: UISlider!
    @IBOutlet weak var widgetSizeStack: UIStackView!
    @IBOutlet weak var widgetHeightLabel: UILabel!
    @IBOutlet weak var widgetHeightSlider: UISlider!
    @IBOutlet weak var widgetHeightStack: UIStackView!
    @IBOutlet weak var widgetBorderWidthLabel: UILabel!
    @IBOutlet weak var widgetBorderWidthSlider: UISlider!
    @IBOutlet weak var widgetAlphaLabel: UILabel!
    @IBOutlet weak var widgetAlphaSlider: UISlider!
    @IBOutlet weak var borderWidthAlphaStack: UIStackView!
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet weak var loadButton: UIButton!
    @IBOutlet weak var addButton: UIButton!
    @IBOutlet weak var editButton: UIButton!

    @IBOutlet weak var stickIndicatorOffsetLabel: UILabel!
    @IBOutlet weak var stickIndicatorOffsetSlider: UISlider!
    @IBOutlet weak var stickIndicatorOffsetStack: UIStackView!
    
    @IBOutlet weak var anchorModeStack: UIStackView!
    @IBOutlet weak var anchorModeSelector: UISegmentedControl!

    @IBOutlet weak var sensitivityXLabel: UILabel!
    @IBOutlet weak var sensitivityXSlider: UISlider!
    @IBOutlet weak var sensitivityXStack: UIStackView!
    @IBOutlet weak var sensitivityYLabel: UILabel!
    @IBOutlet weak var sensitivityYSlider: UISlider!
    @IBOutlet weak var sensitivityYStack: UIStackView!

    @IBOutlet weak var yawFactorLabel: UILabel!
    @IBOutlet weak var yawFactorSlider: UISlider!
    @IBOutlet weak var yawFactorStack: UIStackView!
    @IBOutlet weak var pitchFactorLabel: UILabel!
    @IBOutlet weak var pitchFactorSlider: UISlider!
    @IBOutlet weak var pitchFactorStack: UIStackView!
    @IBOutlet weak var rollFactorLabel: UILabel!
    @IBOutlet weak var rollFactorSlider: UISlider!
    @IBOutlet weak var rollFactorStack: UIStackView!

    @IBOutlet weak var decelerationRateStack: UIStackView!
    @IBOutlet weak var decelerationRateLabel: UILabel!
    @IBOutlet weak var decelerationRateSlider: UISlider!

    @IBOutlet weak var vibrationStyleSelector: UISegmentedControl!
    @IBOutlet weak var vibrationStyleStack: UIStackView!
    @IBOutlet weak var tipContentLabel: UILabel!
    @IBOutlet weak var tipTitleLabel: UILabel!
    @IBOutlet weak var mouseDownButtonStack: UIStackView!
    @IBOutlet weak var mouseButtonDownSelector: UISegmentedControl!
    @IBOutlet weak var buttonModeStack: UIStackView!
    @IBOutlet weak var buttonModeSelector: UISegmentedControl!
    
    @IBOutlet weak var autoTapStack: UIStackView!
    @IBOutlet weak var autoTapLabel: UILabel!
    @IBOutlet weak var autoTapField: UITextField!
    @IBOutlet weak var autoTapRepeatsField: UITextField!
    
    @IBOutlet weak var slideThresholdStack: UIStackView!
    @IBOutlet weak var slideThresholdLabel: UILabel!
    @IBOutlet weak var slideThresholdSlider: UISlider!
    @IBOutlet weak var minStickOffsetStack: UIStackView!
    @IBOutlet weak var minStickOffsetLabel: UILabel!
    @IBOutlet weak var minStickOffsetSlider: UISlider!
    @IBOutlet weak var componentSizeStack: UIStackView!
    @IBOutlet weak var componentSizeLabel: UILabel!
    @IBOutlet weak var componentSizeSlider: UISlider!
    @IBOutlet weak var walkModeThresholdStack: UIStackView!
    @IBOutlet weak var walkModeThresholdLabel: UILabel!
    @IBOutlet weak var walkModeThresholdSlider: UISlider!
    @IBOutlet weak var collectedWidgetsStack: UIStackView!
    @IBOutlet weak var collectedWidgetsSelector: UISegmentedControl!
    @IBOutlet weak var revealModeSelector: UISegmentedControl!
    @IBOutlet weak var bulkMoveStack: UIStackView!
    @IBOutlet weak var bulkMoveSelector: UISegmentedControl!
    @IBOutlet weak var importFromOtherButton: UIButton!
    @IBOutlet weak var clearFolderButton: UIButton!
    @IBOutlet weak var bulkEditButton: UIButton!
    @IBOutlet weak var placeHolderLabel1: UILabel!
    
    
    @IBOutlet weak var bulkEditStack: UIStackView!
    private var bulkEditStacks: [UIStackView]? = []
    private var preBulkEditStacks: [UIStackView] = []

    @IBOutlet weak var bulkWidthStack: UIStackView!
    @IBOutlet weak var bulkWidthLabel: UILabel!
    @IBOutlet weak var bulkWidthSlider: UISlider!
    
    @IBOutlet weak var bulkHeightStack: UIStackView!
    @IBOutlet weak var bulkHeightLabel: UILabel!
    @IBOutlet weak var bulkHeightSlider: UISlider!
    
    @IBOutlet weak var bulkAlphaStack: UIStackView!
    @IBOutlet weak var bulkAlphaLabel: UILabel!
    @IBOutlet weak var bulkAlphaSlider: UISlider!
    
    @IBOutlet weak var bulkBorderWidthStack: UIStackView!
    @IBOutlet weak var bulkBorderWidthSlider: UISlider!
    @IBOutlet weak var bulkBorderWidthLabel: UILabel!
    
    @IBOutlet weak var bulkLabelAlphaStack: UIStackView!
    @IBOutlet weak var bulkLabelAlphaLabel: UILabel!
    @IBOutlet weak var bulkLabelAlphaSlider: UISlider!
    
    @IBOutlet weak var bulkBorderAlphaStack: UIStackView!
    @IBOutlet weak var bulkBorderAlphaLabel: UILabel!
    @IBOutlet weak var bulkBorderAlphaSlider: UISlider!
    
    @IBOutlet weak var bulkHighlightAlphaStack: UIStackView!
    @IBOutlet weak var bulkHighlightAlphaLabel: UILabel!
    @IBOutlet weak var bulkHighlightAlphaSlider: UISlider!
    
    @IBOutlet weak var bulkHighlightSizeStack: UIStackView!
    @IBOutlet weak var bulkHighlightSizeLabel: UILabel!
    @IBOutlet weak var bulkHighlightSizeSlider: UISlider!
    
    @IBOutlet weak var autoDockTimerStack: UIStackView!
    @IBOutlet weak var autoDockTimerLabel: UILabel!
    @IBOutlet weak var autoDockTimerSlider: UISlider!
    
    @IBOutlet weak var dockedAlphaStack: UIStackView!
    @IBOutlet weak var dockedAlphaLabel: UILabel!
    @IBOutlet weak var dockedAlphaSlider: UISlider!
    
    @IBOutlet weak var sprintKeyStack: UIStackView!
    @IBOutlet weak var sprintKeySelector: UISegmentedControl!
    @IBOutlet weak var sprintKeyThresholdLabel: UILabel!
    @IBOutlet weak var sprintKeyThresholdSlider: UISlider!
    
    @IBOutlet weak var walkKeyStack: UIStackView!
    @IBOutlet weak var walkKeySelector: UISegmentedControl!
    @IBOutlet weak var walkKeyThresholdLabel: UILabel!
    @IBOutlet weak var walkKeyThresholdSlider: UISlider!
    
    @IBOutlet weak var animatedStack: UIStackView!
    @IBOutlet weak var animatedSelector: UISegmentedControl!
    
    @IBOutlet weak var widgetPanelStack: UIStackView!

    @IBOutlet private weak var toolbarTopConstraintiPhone: NSLayoutConstraint!
    @IBOutlet private weak var toolbarTopConstraintiPad: NSLayoutConstraint!

    private var oscProfilesTableViewController: OSCProfilesTableViewController?
    private var profilesManager: OSCProfilesManager!
    private var bulkEditEnabled: Bool = false
    private var selectedWidget: OnScreenWidgetView?
    private var alphaSliderMode: AlphaSliderMode = .widgetAlpha
    private var borderWidthSliderMode: BorderWidthSliderMode = .widgetBorderWidth
    private var decelerationRateSliderMode: DecelerationRateSliderMode = .decelerationRateX
    private var selectedControllerLayer: CALayer?
    private var controllerLoadedBounds: CGRect = .zero
    private var widgetViewSelected = false
    private var controllerLayerSelected = false
    private var viewWillBeResized = false
    private var originalTrackPointEnabled = false
    private var isToolbarHidden = false
    private var trashCanStoryBoardColor: UIColor?
    private var widgetPanelMovedByTouch = false
    private var widgetPanelStoredCenter: CGPoint = .zero
    private var latestTouchLocation: CGPoint = .zero
    private var vibrationGenerator = UIImpactFeedbackGenerator(style: .medium)
    private var widgetSizeTransition: WidgetSizeTransition = .keepWidgetSize

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        let dataMan = DataManager()
        let currentSettings = dataMan.retrieveSettings()
        if currentSettings?.unlockDisplayOrientation == true {
            return .all
        } else {
            return GenericUtils.isIPhone() ? .landscape : getCurrentOrientation()
        }
    }

    private func getCurrentOrientation() -> UIInterfaceOrientationMask {
        let bounds = UIScreen.main.bounds
        return bounds.width > bounds.height ? .landscape : [.portrait, .portraitUpsideDown]
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        profilesManager = OSCProfilesManager.sharedManager(view.bounds)
        onScreenWidgetViews = NSMutableSet()
        OSCProfilesManager.setOnScreenWidgetViewsSet(onScreenWidgetViews)
        quickSwitchEnabled = false
        viewWillBeResized = false

        let maskPath = UIBezierPath(
            roundedRect: chevronView.bounds,
            byRoundingCorners: [.bottomLeft, .bottomRight],
            cornerRadii: CGSize(width: 10, height: 10)
        )
        let maskLayer = CAShapeLayer()
        maskLayer.frame = view.bounds
        maskLayer.path = maskPath.cgPath
        chevronView.layer.mask = maskLayer

        let swipeUp = UISwipeGestureRecognizer(target: self, action: #selector(moveToolbar(_:)))
        swipeUp.direction = .up
        toolbarRootView.addGestureRecognizer(swipeUp)

        let tap = UITapGestureRecognizer(target: self, action: #selector(moveToolbar(_:)))
        chevronView.addGestureRecognizer(tap)

        layoutOSC = LayoutOnScreenControls(view: view, controllerSup: nil, streamConfig: nil, oscLevel: Int32(OSCSegmentSelected))
        layoutOSC._level = .custom
        layoutOSC.layoutToolVC = self
        addInnerAnalogSticksToOuterAnalogLayers()

        undoButton.alpha = 0.3
        trashCanStoryBoardColor = trashCanButton.tintColor
        toolbarRootView.layer.shadowColor = UIColor.black.cgColor
        toolbarRootView.layer.shadowOffset = .zero
        toolbarRootView.layer.shadowOpacity = 0.5
        toolbarRootView.layer.shadowRadius = 7
        vibrationGenerator = UIImpactFeedbackGenerator(style: .medium)
        widgetSizeTransition = .keepWidgetSize
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            UIView.animate(
                withDuration: 0.2,
                delay: 0.25,
                usingSpringWithDamping: 0.9,
                initialSpringVelocity: 0.5,
                options: .curveEaseInOut
            ) {
                self.toolbarRootView.frame = CGRect(
                    x: self.toolbarRootView.frame.origin.x,
                    y: self.toolbarRootView.frame.origin.y,
                    width: self.toolbarRootView.frame.width,
                    height: self.toolbarRootView.frame.height
                )
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(legacyOscLayerTapped(_:)), name: Notification.Name("LegacyOscCALayerSelectedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProfileTablViewDismiss), name: Notification.Name("OscLayoutTableViewCloseNotification"), object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(dummytest), name: Notification.Name("GameProfileSelectedNotification"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(widgetViewTapped(_:)), name: Notification.Name("OnScreenWidgetViewSelected"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(OSCLayoutChanged), name: Notification.Name("OSCLayoutChanged"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleReturnToForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
        // NotificationCenter.default.addObserver(self, selector: #selector(handleEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(deviceOrientationDidChange), name: UIDevice.orientationDidChangeNotification, object: nil)
        OnScreenWidgetView.editMode = true
        handleMissingToolBarIcon(toolbarRootView)
        widgetPanelStack.isHidden = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bulkEditStacks = [bulkWidthStack, bulkHeightStack, bulkAlphaStack, bulkBorderAlphaStack, bulkLabelAlphaStack, bulkBorderWidthStack, bulkHighlightAlphaStack, bulkHighlightSizeStack]
        bulkEditEnabled = false
        OnScreenWidgetView.editMode = true
        selectedWidget = nil
        widgetPanelStoredCenter = widgetPanelStack.center
        setupWidgetPanel()
        profileRefresh()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        OnScreenWidgetView.editMode = false
        OnScreenWidgetView.isTweakingHighlight = false
        for case let widget as OnScreenWidgetView in onScreenWidgetViews {
            widget.updateMovementThresholdPreview()
        }
        super.viewWillDisappear(animated)
        NotificationCenter.default.post(name: Notification.Name("GameProfileSelectorCloseNotification"), object: self)
    }

    @objc func dummytest() {}

    private func denormalizeWidgetPosition(_ position: CGPoint) -> CGPoint {
        guard position.x < 1.0, position.y < 1.0 else { return position }
        return CGPoint(x: position.x * view.bounds.width, y: position.y * view.bounds.height)
    }

    private func getCurrentWidgetSizeReference() -> WidgetSizeReference {
        if widgetSizeTransition == .keepWidgetSize { return .longSide }
        if widgetSizeTransition == .transitionWithOrientation {
            return view.bounds.width > view.bounds.height ? .longSide : .shortSide
        }
        return .longSide
    }

    private func clearOnScreenWidgets() {
        OnScreenWidgetView.clearMappings()
        for subview in view.subviews where subview is OnScreenWidgetView {
            subview.removeFromSuperview()
        }
        onScreenWidgetViews.removeAllObjects()
    }

    private func reloadLegacyOnScreenControls(_ profile: OSCProfile) {
        layoutOSC.updateLegacyWidgets(with: profile)
        addInnerAnalogSticksToOuterAnalogLayers()
        layoutOSC.layoutChanges.removeAllObjects()
        OSCLayoutChanged()
    }

    @objc func reloadOnScreenWidgetViews() {
        if self.profileTableLoadingMode == .selectProfileFromMainFrame { return }

        OnScreenWidgetView.isTweakingHighlight = false
        OnScreenWidgetView.editMode = true

        DispatchQueue.main.async {
            self.hideStickIndicators()
            self.clearOnScreenWidgets()

            guard let oscProfile = self.profilesManager?.getSelectedProfile() else { return }
            
            if self.profileTableLoadingMode == .selectProfileFromStreamView {
                NotificationCenter.default.post(name: Notification.Name("GameProfileSelectedNotification"), object: oscProfile)
            }
            
            self.loadWidgets(from: oscProfile)

            if !self.quickSwitchEnabled {
                self.originalTrackPointEnabled = OnScreenWidgetView.trackPointEnabled
                OnScreenWidgetView.trackPointEnabled = true
            }
        }
    }

    private func loadWidgets(from oscProfile: OSCProfile, to folder: OnScreenWidgetView? = nil) {
        var sequence: Int16 = folder == nil ? -1 : (folder?.getAvailableSequence() ?? -1)
        var importedWidgetSequenceMap: [Int16: Int16] = [:]
        var independentWidgetSequencesPriorToImport: [Int16] = []
        var newWidgetBatch: Set<OnScreenWidgetView> = Set()
        
        var hasLegacyWidget = false
        for case let encoded as Data in oscProfile.buttonStatesEncoded {
            guard let buttonState = self.profilesManager?.unarchiveButtonStateEncoded(encoded) else { continue }
            
            if folder != nil {
                if buttonState.alias == "=widgets"
                    || buttonState.alias == "=pickProfile"
                    || buttonState.alias == "widgetTool" {
                    continue
                }
            }
            
            if buttonState.widgetType == 1 {
                let widgetView = OnScreenWidgetView.widget(cmdString: buttonState.name, buttonLabel: buttonState.alias, shape: buttonState.widgetShape, profile: oscProfile)
                widgetView.sequence = (buttonState.sequence == -1 || folder != nil) ? {
                    sequence += 1
                    return sequence
                }() : buttonState.sequence
                
                OnScreenWidgetView.set(widget: widgetView, for: widgetView.sequence)
                widgetView.sequenceSet = buttonState.sequenceSet as? Set<Int16> ?? Set()
                widgetView.parentSequence = buttonState.parentSequence
                widgetView.autoDockIdleDuration = TimeInterval(buttonState.autoDockTimer)
                widgetView.autoDockSettledAlpha = CGFloat(buttonState.dockedAlpha)
                widgetView.folded = buttonState.folded
                widgetView.revealMode = RevealMode(rawValue: Int(buttonState.revealMode)) ?? .coexist
                widgetView.bulkMoveEnabled = buttonState.bulkMoveEnabled
                widgetView.layoutUpdateDelegate = self
                widgetView.translatesAutoresizingMaskIntoConstraints = false
                widgetView.widthFactor = buttonState.widthFactor
                widgetView.heightFactor = buttonState.heightFactor
                widgetView.borderWidth = buttonState.borderWidth
                widgetView.highlightSizeFactor = buttonState.highlightSizeFactor
                widgetView.autoTapInterval = Int(buttonState.autoTapInterval)
                widgetView.autoTapRepeats = UInt32(buttonState.autoTapRepeats)
                widgetView.setVibration(style: Int(buttonState.vibrationStyle))
                widgetView.mouseButtonAction = MouseButtonAction(rawValue: Int(buttonState.mouseButtonAction)) ?? .hovering
                widgetView.animatesTransition = buttonState.animatesTransition
                widgetView.sensitivityFactorY = buttonState.sensitivityFactorY
                widgetView.slideThreshold = buttonState.slideThreshold
                widgetView.yawFactor = buttonState.yawFactor
                widgetView.pitchFactor = buttonState.pitchFactor
                widgetView.rollFactor = buttonState.rollFactor
                widgetView.decelerationRateX = buttonState.decelerationRateX
                widgetView.decelerationRateY = buttonState.decelerationRateY
                widgetView.dWheelWalkModeThreshold = buttonState.walkModeThreshold
                widgetView.minStickOffset = buttonState.minStickOffset
                widgetView.buttonMode = ButtonMode(rawValue: Int(buttonState.buttonMode)) ?? .slideToToggle
                widgetView.sprintKeyActionType = OnScreenWidgetView.WalkSprintKeyActionType(rawValue: buttonState.sprintKeyActionType) ?? .hold
                widgetView.sprintKeyThreshold = buttonState.sprintKeyThreshold
                widgetView.walkKeyActionType = OnScreenWidgetView.WalkSprintKeyActionType(rawValue: buttonState.walkKeyActionType) ?? .hold
                widgetView.walkKeyThreshold = buttonState.walkKeyThreshold

                self.view.insertSubview(widgetView, belowSubview: self.widgetPanelStack)
                buttonState.position = self.denormalizeWidgetPosition(buttonState.position)
                widgetView.setLocation(position: buttonState.position)
                widgetView.sizeReference = self.getCurrentWidgetSizeReference().rawValue
                widgetView.resizeWidgetView()
                widgetView.adjustTransparency(alpha: buttonState.backgroundAlpha, tweakBorderAlpha: false)
                widgetView.tweakLabelAlpha(alpha: buttonState.labelAlpha)
                widgetView.tweakBorderAlpha(alpha: buttonState.borderAlpha)
                widgetView.tweakHighlightAlpha(alpha: buttonState.highlightAlpha)
                widgetView.adjustBorder(width: buttonState.borderWidth)
                ///
                widgetView.sensitivityFactorX = buttonState.sensitivityFactorX
                widgetView.componentSizeFactor = buttonState.componentSizeFactor
                widgetView.touchPointAnchored = buttonState.touchPointAnchored
                widgetView.stickIndicatorOffset = buttonState.stickIndicatorOffset
                
                self.onScreenWidgetViews.add(widgetView)
                
                guard let folder = folder else { continue }
                if !folder.folded {
                    if widgetView.parentSequence == -1 {
                        folder.sequenceSet.insert(widgetView.sequence)
                        widgetView.parentSequence = folder.sequence
                        independentWidgetSequencesPriorToImport.append(widgetView.sequence)
                    }
                    importedWidgetSequenceMap[buttonState.sequence] = widgetView.sequence
                    newWidgetBatch.insert(widgetView)
                }
                
            } else if buttonState.widgetType == 0 {
                hasLegacyWidget = true
            }
        }
        
        if let folder = folder {
            for widget in newWidgetBatch where
            widget.isFolder
            && widget.parentSequence != -1
            && widget != folder
            {
                widget.sequenceSet = Set(widget.sequenceSet.map {importedWidgetSequenceMap[$0] ?? -1})
                if !independentWidgetSequencesPriorToImport.contains(widget.sequence) {widget.parentSequence = importedWidgetSequenceMap[widget.parentSequence] ?? -1}
                // print("label: \(widget.widgetLabel) sequence: \(widget.sequence) set: \(widget.sequenceSet) parent: \(String(describing: OnScreenWidgetView.mapping[widget.parentSequence]?.widgetLabel))")
            }
        }

        for case let widget as OnScreenWidgetView in self.onScreenWidgetViews {
            widget.accessWidgetAttributes()
        }

        OnScreenWidgetView.unfoldedExclusiveFolderSequence = oscProfile.unfoldedExclusiveFolderSequence
        OnScreenWidgetView.setPostExclusiveUnfoldeds(oscProfile.postExclusiveUnfoldedSequences as NSSet)
        OnScreenWidgetView.restoreFoldedStates()
        
        if hasLegacyWidget {
            self.reloadLegacyOnScreenControls(oscProfile)
        } else {
            for case let layer as CALayer in self.layoutOSC.oscButtonLayerPool {
                layer.removeFromSuperlayer()
            }
            self.layoutOSC.oscButtonLayerPool.removeAllObjects()
        }
        
        OnScreenWidgetView.deepestButton = nil;
        _ = OnScreenWidgetView.getDeepestButton()
        if let deepestButton = OnScreenWidgetView.deepestButton {
            for widget in OnScreenWidgetView.mapping.values {
                if widget.widgetType == .touchPad {
                    widget.superview?.insertSubview(widget, belowSubview: deepestButton)
                }
            }
        }
        
        view.bringSubviewToFront(toolbarRootView)
    }
    
    @objc func profileRefresh() {
        let storyboardName = UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad"
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        oscProfilesTableViewController = storyboard.instantiateViewController(withIdentifier: "OSCProfilesTableViewController") as? OSCProfilesTableViewController
        oscProfilesTableViewController?.needToUpdateOscLayoutTVC = { [weak self] in
            guard let self else { return }
            if !loadJustTapped {
                self.reloadOnScreenWidgetViews()
            }
            loadJustTapped = false
            self.oscProfilesTableViewController?.currentOSCButtonLayers = self.layoutOSC.oscButtonLayerPool
        }
        oscProfilesTableViewController?.tableView?.reloadData()
        reloadOnScreenWidgetViews()
    }

    @objc var profileTableLoadingMode: OSCProfilesTableViewLoadingMode = .selectProfile
    @objc(presentProfilesTableViewWithLoadingMode:)
    func presentProfilesTableView(with loadingMode: OSCProfilesTableViewLoadingMode) {
        profileTableLoadingMode = loadingMode
        presentProfilesTableView(with: loadingMode, pickedProfileDataHandler: nil)
    }

    private func presentProfilesTableView(
        with loadingMode: OSCProfilesTableViewLoadingMode,
        pickedProfileDataHandler: ((OSCProfile) -> Void)? = nil
    ) {
        hideStickIndicators()
        if loadingMode != .pickProfileData {selectedWidget = nil}
        let storyboardName = UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad"
        let storyboard = UIStoryboard(name: storyboardName, bundle: nil)
        let controller = storyboard.instantiateViewController(withIdentifier: "OSCProfilesTableViewController") as? OSCProfilesTableViewController
        controller?.layoutViewBounds = view.bounds
        controller?.needToUpdateOscLayoutTVC = { [weak self] in
            guard let self else { return }
            if loadingMode == .selectProfile || loadingMode == .selectProfileFromStreamView {
                self.reloadOnScreenWidgetViews()
            }
        }
        controller?.currentOSCButtonLayers = layoutOSC.oscButtonLayerPool
        controller?.modalPresentationStyle = .overCurrentContext
        controller?.loadingMode = loadingMode
        controller?.pickedProfileDataHandler = pickedProfileDataHandler
        widgetPanelStack.isHidden = true
        oscProfilesTableViewController = controller
        if let controller {
            present(controller, animated: false)
        }
    }

    private var loadJustTapped:Bool = false
    @IBAction func loadTapped(_ sender: Any?) {
        // saveTapped(nil)
        loadJustTapped = true
        presentProfilesTableView(with: .selectProfile)
    }

    @IBAction func importFromOtherButtonTapped(_ sender: Any?) {
        // importFromOtherButton.setTitle(LocalizationHelper.localizedString(forKey: "Import"), for: .normal)
        presentProfilesTableView(with: .pickProfileData) { [weak self] profile in
            if profile.name == self?.profilesManager.getSelectedProfile().name {return}
            self?.loadWidgets(from: profile, to: self?.selectedWidget)
        }
    }

    @IBAction func clearFolderButtonTapped(_ sender: Any?) {
        for widget in OnScreenWidgetView.mapping.values {
            if widget.parentSequence == selectedWidget?.sequence, widget.sequenceSet.isEmpty {
                selectedWidget?.sequenceSet.remove(widget.sequence)
                OnScreenWidgetView.mapping.removeValue(forKey: widget.sequence)
                widget.removeFromSuperview()
            }
        }
                
        selectedWidget?.sequenceSet = Set()
    }
    
    private func setBulkEditStackHidden(_ hidden:Bool) {
        // bulkEditStack.isHidden = hidden
        let bulkEditStacks = bulkEditStacks ?? []
       
        if !hidden {
            for stack in widgetPanelStack.arrangedSubviews where stack is UIStackView {
                if !stack.isHidden {
                    preBulkEditStacks.append(stack as! UIStackView)
                    if stack == bulkMoveStack {continue}
                    stack.isHidden = true
                }
            }
        }
        else {
            for stack in preBulkEditStacks {
                stack.isHidden = false
            }
            preBulkEditStacks = []
        }
       
        for stack in bulkEditStacks {
            stack.isHidden = hidden
        }
        
        buttonModeStack.isHidden = !hidden || (selectedWidget?.widgetType != .button)
        collectedWidgetsStack.isHidden = selectedWidget?.isFolder != true
        
        if GenericUtils.isIPhone() {
            vibrationStyleStack.isHidden = false
        }
        
        autoFitStack(widgetPanelStack)
    }
    
    @IBAction func bulkEditButtonTapped(_ sender: Any?) {
        guard let selectedWidgetView = selectedWidget else {return}
        if !bulkEditEnabled {applyTitle("Batch updated", for: sender as! UIButton)}
        else {applyTitle("Batch edit", for: sender as! UIButton)}
        bulkEditEnabled = !bulkEditEnabled
        
        setBulkEditStackHidden(!bulkEditEnabled)
        if selectedWidgetView.parentSequence != -1 || !bulkEditEnabled { refreshPanelForSelectedWidget(selectedWidgetView)
        }
    }

    /*
    @objc private func handleEnterBackground() {
    }
    */

    @objc private func handleReturnToForeground() {
        if (self.profileTableLoadingMode != .selectProfileFromMainFrame
            && self.profileTableLoadingMode != .selectProfileFromMainFrame)
        {setupWidgetPanel()}
        updateViewBounds()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        viewWillBeResized = true
        hideStickIndicators()
        if self.profileTableLoadingMode == .selectProfile {
            
            let oldSize = view.bounds.size
            let scaleX = size.width / oldSize.width
            let scaleY = size.height / oldSize.height
            
            for widget in OnScreenWidgetView.mapping.values {
                let oldCenter = widget.center
                let oldStoredCenter = widget.storedCenter
                
                coordinator.animate(alongsideTransition: { _ in
                    widget.center = CGPoint(
                        x: oldCenter.x * scaleX,
                        y: oldCenter.y * scaleY
                    )
                    widget.storedCenter = CGPoint(
                        x: oldStoredCenter.x * scaleX,
                        y: oldStoredCenter.y * scaleY
                    )
                }, completion: nil)
            }
            
            for buttonLayer in self.layoutOSC.oscButtonLayerPool {
                if let layer = buttonLayer as? CALayer {
                    let oldPosition = layer.position
                    coordinator.animate(alongsideTransition: { _ in
                        if layer == self.layoutOSC._leftStick
                           || layer == self.layoutOSC._rightStick {return}
                        layer.position = CGPoint(
                            x: oldPosition.x * scaleX,
                            y: oldPosition.y * scaleY
                        )
                    }, completion: nil)
                }
            }
        }
    }

    @objc private func deviceOrientationDidChange() {
        perform(#selector(handleOrientationChangeForOnScreenWidgets), with: self, afterDelay: 0)
    }

    @objc private func handleOrientationChangeForOnScreenWidgets() {
    
        if !viewWillBeResized { return }
        setupWidgetPanel()
        updateViewBounds()
    }

    private func updateViewBounds() {
        viewWillBeResized = false
        selectedWidget = nil
        selectedControllerLayer = nil
        oscProfilesTableViewController?.layoutViewBounds = view.bounds
        OSCProfilesManager.setLayoutViewBounds(view.bounds)
        OSCProfilesManager.setOnScreenWidgetViewsSet(onScreenWidgetViews)
        // reloadOnScreenWidgetViews()
    }

    @objc func OSCLayoutChanged() {
        undoButton.alpha = layoutOSC.layoutChanges.count > 0 ? 1.0 : 0.3
    }

    private func enableCommonWidgetTools() {
        tipTitleLabel.isHidden = true
        tipContentLabel.isHidden = true
        widgetSizeStack.isHidden = false
        widgetHeightStack.isHidden = false
        borderWidthAlphaStack.isHidden = false
        if isIPhone() { vibrationStyleStack.isHidden = false }
    }

    private func autoFitLabel(_ label: UILabel) {
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.3
        label.numberOfLines = 1
    }

    private func autoFitStack(_ stack: UIStackView) {
        let fittingSize = stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        var newFrame = stack.frame
        newFrame.size = fittingSize
        stack.frame = newFrame
        updateClippedMask(for: stack)
        if #available(iOS 14, *) {
        } else {
            applyShadowForiOS13(stack)
        }
    }

    private func hideStickIndicators() {
        for case let widget as OnScreenWidgetView in view.subviews {
            widget.stickAnchorLayer.isHidden = true
            widget.anchorBall.isHidden = true
        }
    }

    @objc private func switchAlphaSlider(_ sender: UITapGestureRecognizer) {
        guard widgetViewSelected else { return }
        alphaSliderMode = AlphaSliderMode(rawValue: (alphaSliderMode.rawValue + 1) % 4) ?? .widgetAlpha
        OnScreenWidgetView.isTweakingHighlight = alphaSliderMode == .highlightAlpha || borderWidthSliderMode == .highlightSize
        loadWidgetAlphas()
    }

    @objc private func switchBorderWidthSlider(_ sender: UITapGestureRecognizer) {
        guard widgetViewSelected else { return }
        borderWidthSliderMode = BorderWidthSliderMode(rawValue: (borderWidthSliderMode.rawValue + 1) % 2) ?? .widgetBorderWidth
        OnScreenWidgetView.isTweakingHighlight = alphaSliderMode == .highlightAlpha || borderWidthSliderMode == .highlightSize
        loadWidgetWidths()
    }

    @objc private func switchDecelerationRateSlider(_ sender: UITapGestureRecognizer) {
        guard widgetViewSelected else { return }
        decelerationRateSliderMode = DecelerationRateSliderMode(rawValue: (decelerationRateSliderMode.rawValue + 1) % 2) ?? .decelerationRateX
        loadDecelerationRates()
    }

    private func setHiddenForWidgetHighlights(_ widget:OnScreenWidgetView) {
        widget.buttonDownVisualEffectLayer.isHidden = !OnScreenWidgetView.isTweakingHighlight
        widget.l3r3Indicator.isHidden = !widget.hasL3R3Indicator || !OnScreenWidgetView.isTweakingHighlight
        let hidden = !widget.isDirectionPad && !OnScreenWidgetView.isTweakingHighlight
        widget.anchorBall.isHidden = hidden
        widget.upIndicator.isHidden = hidden
        widget.downIndicator.isHidden = hidden
        widget.leftIndicator.isHidden = hidden
        widget.rightIndicator.isHidden = hidden
    }

    private func loadWidgetAlphas() {
        guard let selectedWidget, widgetViewSelected else { return }
        setHiddenForWidgetHighlights(selectedWidget)
        self.widgetAlphaSlider.isEnabled = selectedWidget.folded || !selectedWidget.isFolder
        switch alphaSliderMode {
        case .widgetAlpha:
            widgetAlphaSlider.maximumValue = 1
            widgetAlphaSlider.minimumValue = -1
            widgetAlphaSlider.value = Float(selectedWidget.originalBackgroundAlpha)
            widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Opacity: %.2f", widgetAlphaSlider.value)
        case .labelAlpha:
            widgetAlphaSlider.maximumValue = 1
            widgetAlphaSlider.minimumValue = -1
            widgetAlphaSlider.value = Float(selectedWidget.originalLabelAlpha)
            widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Label opacity: %.2f", widgetAlphaSlider.value)
        case .borderAlpha:
            widgetAlphaSlider.maximumValue = 1
            widgetAlphaSlider.minimumValue = -1
            widgetAlphaSlider.value = Float(selectedWidget.borderAlpha)
            widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Border opacity: %.2f", widgetAlphaSlider.value)
        case .highlightAlpha:
            widgetAlphaSlider.maximumValue = 1
            widgetAlphaSlider.minimumValue = 0
            widgetAlphaSlider.value = Float(selectedWidget.highlightAlpha)
            widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Highlight opacity: %.2f", widgetAlphaSlider.value)
        }
    }

    private func loadWidgetWidths() {
        guard let selectedWidget, widgetViewSelected else { return }
        setHiddenForWidgetHighlights(selectedWidget)
        switch borderWidthSliderMode {
        case .widgetBorderWidth:
            widgetBorderWidthSlider.minimumValue = 0
            widgetBorderWidthSlider.maximumValue = 8
            widgetBorderWidthSlider.setValue(Float(selectedWidget.borderWidth), animated: false)
            widgetBorderWidthLabel.text = LocalizationHelper.localizedString(forKey: "Border width: %.2f", widgetBorderWidthSlider.value)
        case .highlightSize:
            widgetBorderWidthSlider.minimumValue = 0.01
            widgetBorderWidthSlider.maximumValue = 2
            widgetBorderWidthSlider.setValue(Float(selectedWidget.highlightSizeFactor), animated: false)
            widgetBorderWidthLabel.text = LocalizationHelper.localizedString(forKey: "Highlight size: %.2f", widgetBorderWidthSlider.value)
        }
    }

    private func loadDecelerationRates() {
        guard let selectedWidget else { return }
        let value = decelerationRateSliderMode == .decelerationRateX ? selectedWidget.decelerationRateX : selectedWidget.decelerationRateY
        decelerationRateSlider.value = Float(value)
        let key = decelerationRateSliderMode == .decelerationRateX ? "DecelerationRateX: %.3f  " : "DecelerationRateY: %.3f  "
        decelerationRateLabel.text = LocalizationHelper.localizedString(forKey: key, decelerationRateSlider.value)
    }

    private func refreshPanelForSelectedWidget(_ widgetView: OnScreenWidgetView) {
        // hideStickIndicators()
        if OnScreenWidgetView.gamepadArrivalReported {clearSickInput()}
        enableCommonWidgetTools()
        widgetViewSelected = true
        controllerLayerSelected = false

        if widgetView !== selectedWidget {
            selectedWidget?.setAutoTapIntervalByText(str: autoTapField.text ?? "")
        }
        
        widgetView.hideAllHighlightLayersOfAllWidgets(selfIncluded: true)

        autoFitLabel(currentProfileLabel)
        currentProfileLabel.textAlignment = .left
        currentProfileLabel.text = LocalizationHelper.localizedString(forKey: "  Profile: %@    Alias: %@    Cmd: %@    Parent: %@", profilesManager.getSelectedProfile().name, widgetView.widgetLabel, widgetView.cmdString,           LocalizationHelper.localizedString(forKey:OnScreenWidgetView.mapping[widgetView.parentSequence]?.widgetLabel ?? "null"))
        if selectedWidget?.hasWalkSprintKeys == true {
            let cmdCounts = widgetView.comboButtonStrings.count
            currentProfileLabel.text = LocalizationHelper.localizedString(forKey: "  Cmd: %@    Sprint: %@    Walk: %@    Parent: %@",
                widgetView.cmdString, cmdCounts>0 ? widgetView.comboButtonStrings[0] : LocalizationHelper.localizedString(forKey: "null"),
                cmdCounts>1 ? widgetView.comboButtonStrings[1] : LocalizationHelper.localizedString(forKey: "null"),  LocalizationHelper.localizedString(forKey:OnScreenWidgetView.mapping[widgetView.parentSequence]?.widgetLabel ?? "null"))
        }
        
        undoButton.alpha = widgetView.layoutChanges.count > 1 ? 1.0 : 0.3

        widgetView.accessWidgetAttributes()

        sensitivityXStack.isHidden = !widgetView.hasSensitivityX
        if widgetView.hasSensitivityX {
            sensitivityXSlider.minimumValue = Float(widgetView.sensitivityXMin)
            sensitivityXSlider.maximumValue = Float(widgetView.sensitivityXMax)
            sensitivityXSlider.value = Float(widgetView.sensitivityFactorX)
            let key = widgetView.hasSensitivityY ? "SensitivityX: %.2f" : "Sensitivity: %.2f"
            sensitivityXLabel.text = LocalizationHelper.localizedString(forKey: key, widgetView.sensitivityFactorX)
            autoFitLabel(sensitivityXLabel)
        }

        sensitivityYStack.isHidden = !widgetView.hasSensitivityY
        if widgetView.hasSensitivityY {
            sensitivityYSlider.minimumValue = Float(widgetView.sensitivityYMin)
            sensitivityYSlider.maximumValue = Float(widgetView.sensitivityYMax)
            sensitivityYSlider.value = Float(widgetView.sensitivityFactorY)
            sensitivityYLabel.text = LocalizationHelper.localizedString(forKey: "SensitivityY: %.2f", widgetView.sensitivityFactorY)
            autoFitLabel(sensitivityYLabel)
        }

        minStickOffsetStack.isHidden = !widgetView.hasMinStickOffset
        if widgetView.hasMinStickOffset {
            minStickOffsetSlider.value = Float(widgetView.minStickOffset)
            minStickOffsetLabel.text = LocalizationHelper.localizedString(forKey: "Minimum offset: %.0f", widgetView.minStickOffset)
            autoFitLabel(minStickOffsetLabel)
        }

        walkModeThresholdStack.isHidden = !widgetView.isStickWheel
        if widgetView.isStickWheel {
            walkModeThresholdSlider.value = Float(widgetView.dWheelWalkModeThreshold)
            walkModeThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Walkmode threshold: %.0f   ", widgetView.dWheelWalkModeThreshold)
            autoFitLabel(walkModeThresholdLabel)
        }

        
        sprintKeyStack.isHidden = !(widgetView.hasWalkSprintKeys && !widgetView.comboButtonStrings.isEmpty)
        walkKeyStack.isHidden = !(widgetView.hasWalkSprintKeys && widgetView.comboButtonStrings.count > 1)
        if widgetView.hasWalkSprintKeys {
            let clampedWalkThreshold = min(widgetView.walkKeyThreshold, widgetView.sprintKeyThreshold)
            if clampedWalkThreshold != widgetView.walkKeyThreshold {
                widgetView.walkKeyThreshold = clampedWalkThreshold
            }
            
            sprintKeyThresholdSlider.value = Float(widgetView.sprintKeyThreshold)
            sprintKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: " Slide threshold: %0.2f  ", sprintKeyThresholdSlider.value)
            autoFitLabel(sprintKeyThresholdLabel)
            sprintKeySelector.selectedSegmentIndex = Int(widgetView.sprintKeyActionType.rawValue)

            walkKeyThresholdSlider.value = Float(widgetView.walkKeyThreshold)
            walkKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: " Slide threshold: %0.2f  ", walkKeyThresholdSlider.value)
            walkKeySelector.selectedSegmentIndex = Int(widgetView.walkKeyActionType.rawValue)
            autoFitLabel(walkKeyThresholdLabel)

            widgetView.updateMovementThresholdPreview()
        } else {
            widgetView.updateMovementThresholdPreview()
        }

        
        slideThresholdStack.isHidden = !widgetView.hasSlideThreshold
        if widgetView.hasSlideThreshold {
            slideThresholdSlider.minimumValue = Float(widgetView.slideThresholdMin)
            slideThresholdSlider.maximumValue = Float(widgetView.slideThresholdMax)
            slideThresholdSlider.value = Float(widgetView.slideThreshold)
            slideThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Slide threshold: %.1f   ", widgetView.slideThreshold)
            autoFitLabel(slideThresholdLabel)
        }

        yawFactorStack.isHidden = !widgetView.hasYawFactor
        if widgetView.hasYawFactor {
            yawFactorSlider.minimumValue = Float(widgetView.yawFactorMin)
            yawFactorSlider.maximumValue = Float(widgetView.yawFactorMax)
            yawFactorSlider.value = Float(widgetView.yawFactor)
            yawFactorLabel.text = LocalizationHelper.localizedString(forKey: "Yaw factor: %.2f", widgetView.yawFactor)
            autoFitLabel(yawFactorLabel)
        }

        pitchFactorStack.isHidden = !widgetView.hasPitchFactor
        if widgetView.hasPitchFactor {
            pitchFactorSlider.minimumValue = Float(widgetView.pitchFactorMin)
            pitchFactorSlider.maximumValue = Float(widgetView.pitchFactorMax)
            pitchFactorSlider.value = Float(widgetView.pitchFactor)
            pitchFactorLabel.text = LocalizationHelper.localizedString(forKey: "Pitch factor: %.2f", widgetView.pitchFactor)
            autoFitLabel(pitchFactorLabel)
        }

        rollFactorStack.isHidden = !widgetView.hasRollFactor
        if widgetView.hasRollFactor {
            rollFactorSlider.minimumValue = Float(widgetView.rollFactorMin)
            rollFactorSlider.maximumValue = Float(widgetView.rollFactorMax)
            rollFactorSlider.value = Float(widgetView.rollFactor)
            rollFactorLabel.text = LocalizationHelper.localizedString(forKey: "Roll factor: %.2f", widgetView.rollFactor)
            autoFitLabel(rollFactorLabel)
        }

        stickIndicatorOffsetStack.isHidden = !widgetView.hasStickIndicatorOffset
        if widgetView.hasStickIndicatorOffset {
            hideStickIndicators()
            widgetView.touchBeganLocation = CGPoint(x: widgetView.frame.width / 2, y: widgetView.frame.height / 4)
            widgetView.showStickIndicator()
            stickIndicatorOffsetSlider.value = Float(widgetView.stickIndicatorOffset)
            stickIndicatorOffsetSliderMoved(stickIndicatorOffsetSlider)
            autoFitLabel(stickIndicatorOffsetLabel)
        }

        anchorModeStack.isHidden = !widgetView.hasAnchorMode
        if !anchorModeStack.isHidden {
            anchorModeSelector.selectedSegmentIndex = widgetView.touchPointAnchored ? 1 : 0
            autoFitLabel(stickIndicatorOffsetLabel)
        }

        widgetSizeSlider.value = Float(widgetView.denormalizedWidthFactor)
        widgetSizeLabel.text = LocalizationHelper.localizedString(forKey: "Size: %.2f", widgetView.denormalizedWidthFactor)
        autoFitLabel(widgetSizeLabel)

        widgetHeightSlider.value = Float(widgetView.denormalizedHeightFactor)
        widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", widgetView.denormalizedHeightFactor)
        autoFitLabel(widgetHeightLabel)

        componentSizeStack.isHidden = !widgetView.hasComponent
        componentSizeSlider.value = Float(widgetView.denormalizedComponentSizeFactor)
        componentSizeLabel.text = LocalizationHelper.localizedString(forKey: "Component size: %.2f   ", widgetView.denormalizedComponentSizeFactor)
        autoFitLabel(componentSizeLabel)

        loadWidgetAlphas()
        loadWidgetWidths()
        autoTapStack.isHidden = !widgetView.hasAutoTap
        autoTapField.text = widgetView.getAutoTapIntervalStr()
        autoTapField.textColor = .white
        autoTapField.keyboardType = .numbersAndPunctuation
        autoTapField.attributedPlaceholder = NSAttributedString(
            string: LocalizationHelper.localizedString(forKey: "autoTapTimerTip"),
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.77), .font: UIFont.systemFont(ofSize: 10)]
        )
        
        autoTapRepeatsField.text = widgetView.autoTapRepeats == 0 ? "∞" : "\(widgetView.autoTapRepeats)"
        autoTapRepeatsField.textColor = .white
        autoTapRepeatsField.keyboardType = .numbersAndPunctuation
        autoTapRepeatsField.attributedPlaceholder = NSAttributedString(
            string: LocalizationHelper.localizedString(forKey: "0 - infinite"),
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.77), .font: UIFont.systemFont(ofSize: 10)]
        )
        
        autoFitLabel(autoTapLabel)

        decelerationRateStack.isHidden = !widgetView.hasInertia
        decelerationRateSlider.value = Float(widgetView.decelerationRateX)
        loadDecelerationRates()
        autoFitLabel(decelerationRateLabel)

        mouseDownButtonStack.isHidden = !widgetView.isMousePadWithButtonActions
        mouseButtonDownSelector.selectedSegmentIndex = Int(widgetView.mouseButtonAction.rawValue)
        
        animatedStack.isHidden = !(widgetView.isMagnifier || widgetView.isFolder)
        animatedSelector.selectedSegmentIndex = widgetView.animatesTransition ? 1 : 0

        autoDockTimerStack.isHidden = !(widgetView.isFolder && widgetView.parentSequence == -1);
        autoDockTimerSlider.value = Float(widgetView.autoDockIdleDuration)
        autoDockTimerSliderMoved(autoDockTimerSlider)
        
        dockedAlphaStack.isHidden = !(widgetView.isFolder && widgetView.parentSequence == -1);
        dockedAlphaSlider.value = Float(widgetView.autoDockSettledAlpha)
        dockedAlphaSliderMoved(dockedAlphaSlider)

        buttonModeStack.isHidden = widgetView.widgetType != .button
        buttonModeSelector.selectedSegmentIndex = Int(widgetView.buttonMode.rawValue)
        
        collectedWidgetsStack.isHidden = !widgetView.isFolder
        collectedWidgetsSelector.selectedSegmentIndex = widgetView.folded ? 1 : 0
        revealModeSelector.selectedSegmentIndex = Int(widgetView.revealMode.rawValue)
        OnScreenWidgetView.set(folded: widgetView.folded, for: widgetView)
        
        self.bulkEditButton.isEnabled = collectedWidgetsSelector.selectedSegmentIndex == 0
        self.importFromOtherButton.isEnabled = collectedWidgetsSelector.selectedSegmentIndex == 0
        self.clearFolderButton.isEnabled = collectedWidgetsSelector.selectedSegmentIndex  == 0
        // self.placeHolderLabel1.isHidden = collectedWidgetsSelector.selectedSegmentIndex == 0
        
        // bulkMoveStack.isHidden = !widgetView.isFolder
        bulkMoveStack.isHidden = !(widgetView.isFolder || widgetView.parentSequence == -1)
        bulkMoveSelector.isEnabled = widgetView.isFolder
        clearFolderButton.isEnabled = widgetView.isFolder && !widgetView.folded
        importFromOtherButton.isEnabled = widgetView.isFolder && !widgetView.folded
        bulkMoveSelector.selectedSegmentIndex = widgetView.bulkMoveEnabled ? 1 : 0
        if !widgetView.isFolder {
            bulkMoveSelector.selectedSegmentIndex = 0
        }

        setBulkEditStackHidden(!(bulkEditEnabled && widgetView.isFolder && !widgetView.folded))
                
        if isIPhone() {
            vibrationStyleStack.isHidden = !widgetView.hasHapticFeedback
            vibrationStyleSelector.selectedSegmentIndex = widgetView.vibrationStyle
        }
        autoFitStack(widgetPanelStack)
    }

    private func popFolderTutorialTip() {
        AlertControllerUtil.cancelButtonString = LocalizationHelper.localizedString(forKey: "Detailed Tutorial")
        AlertControllerUtil.showAlert(
            in: self,
            title: LocalizationHelper.localizedString(forKey: "Folder Button"),
            message: LocalizationHelper.localizedString(forKey: "folderTutorialTip"),
            withCancel: true,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 5,
            completion: {
                if AlertControllerUtil.actionCancelled {
                    GenericUtils.openUrl(LocalizationHelper.localizedString(forKey: "folderTutorialUrl"))
                }
                else {return}
            }
        )
    }
    
    @objc private func widgetViewTapped(_ notification: Notification) {
        guard let widgetView = notification.object as? OnScreenWidgetView else { return }
        selectedWidget = widgetView
        layoutOSC.updateGuidelinesFor(onScreenWidget: widgetView)
        if bulkEditEnabled {
            bulkEditButtonTapped(bulkEditButton) // this will call refreshPanelForSelectedWidget too
            return
        }
        refreshPanelForSelectedWidget(widgetView)
        
        if (widgetView.isFolder && GenericUtils.isFirstTappingFolderInLayoutTool()) {
            self.popFolderTutorialTip()
        }
    }

    @objc private func legacyOscLayerTapped(_ notification: Notification) {
        guard let controllerLayer = notification.object as? CALayer else { return }
        enableCommonWidgetTools()
        hideStickIndicators()
        widgetViewSelected = false
        selectedWidget = nil
        autoTapStack.isHidden = true
        stickIndicatorOffsetStack.isHidden = true
        sensitivityXStack.isHidden = true
        sensitivityYStack.isHidden = true
        sprintKeyStack.isHidden = true
        walkKeyStack.isHidden = true
        mouseDownButtonStack.isHidden = true
        decelerationRateStack.isHidden = true

        controllerLayerSelected = true
        selectedControllerLayer = controllerLayer
        controllerLoadedBounds = controllerLayer.bounds

        autoFitLabel(currentProfileLabel)
        currentProfileLabel.textAlignment = .left
        currentProfileLabel.text = LocalizationHelper.localizedString(forKey: "  Profile: %@    Widget: %@", profilesManager.getSelectedProfile().name, selectedControllerLayer?.name ?? "")

        let sizeFactor = OnScreenControls.getControllerLayerSizeFactor(controllerLayer)
        widgetSizeSlider.value = Float(sizeFactor)
        widgetHeightSlider.value = Float(sizeFactor)
        let alpha = layoutOSC.getControllerLayerOpacity(controllerLayer)
        widgetAlphaSlider.value = Float(alpha)
        widgetSizeLabel.text = LocalizationHelper.localizedString(forKey: "Size: %.2f", sizeFactor)
        widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", sizeFactor)
        widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Opacity: %.2f", alpha)
        if isIPhone() {
            vibrationStyleStack.isHidden = false
            if let style = OnScreenControls.layerVibrationStyleDic()?.object(forKey: controllerLayer.name ?? "") as? NSNumber {
                vibrationStyleSelector.selectedSegmentIndex = style.intValue
            }
        }
        autoFitStack(widgetPanelStack)
    }

    @IBAction func closeTapped(_ sender: Any?) {
        clearSickInput()
        dismiss(animated: true) {
            OnScreenWidgetView.trackPointEnabled = self.originalTrackPointEnabled
        }
    }

    @IBAction func trashCanTapped(_ sender: Any?) {
        let alert = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: "Delete Buttons Here"),
            message: LocalizationHelper.localizedString(forKey: "Drag and drop buttons onto this trash can to remove them from the interface"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default))
        present(alert, animated: true)
    }

    @IBAction func undoTapped(_ sender: Any?) {
        let alert = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: "Nothing to Undo"),
            message: LocalizationHelper.localizedString(forKey: "There are no changes to undo"),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default))

        if !widgetViewSelected {
            if layoutOSC.layoutChanges.count > 0,
               let buttonState = layoutOSC.layoutChanges.lastObject as? OnScreenButtonState,
               let buttonLayer = layoutOSC.controllerLayer(fromName: buttonState.name) {
                buttonLayer.position = buttonState.position
                buttonLayer.isHidden = buttonState.isHidden
                if buttonLayer.name == "dPad" {
                    layoutOSC._upButton.isHidden = buttonState.isHidden
                    layoutOSC._rightButton.isHidden = buttonState.isHidden
                    layoutOSC._downButton.isHidden = buttonState.isHidden
                    layoutOSC._leftButton.isHidden = buttonState.isHidden
                }
                if buttonLayer.name == "leftStickBackground" {
                    layoutOSC._leftStick.isHidden = buttonState.isHidden
                }
                if buttonLayer.name == "rightStickBackground" {
                    layoutOSC._rightStick.isHidden = buttonState.isHidden
                }
                layoutOSC.layoutChanges.removeLastObject()
                OSCLayoutChanged()
            } else {
                present(alert, animated: true)
            }
        } else if let selectedWidget {
            if selectedWidget.layoutChanges.count > 1 {
                selectedWidget.undoRelocation()
            } else {
                present(alert, animated: true)
            }
            undoButton.alpha = selectedWidget.layoutChanges.count > 1 ? 1.0 : 0.3
        }
    }

    private func presentInvalidWidgetCommandAlert() {
        let alert = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: "Invalid Input"),
            message: LocalizationHelper.localizedString(forKey: "Check the command and parameter."),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Read Widget Instruction"), style: .default) { _ in
            guard let url = URL(string: LocalizationHelper.localizedString(forKey: "onScreenWidgetStackDoc")),
                  UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        })
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default))
        present(alert, animated: true)
    }

    private func isWidgetParamsValid(_ params: NSMutableDictionary) -> Bool {
        let cmdString = (params["cmdString"] as? String ?? "").uppercased()
        let buttonLabel = params["buttonLabel"] as? String ?? ""
        var widgetShape = (params["shape"] as? String ?? "").lowercased()

        params["cmdString"] = cmdString
        let noValidKeyboardString = CommandManager.shared.extractAutoReleaseButtonStrings(from: cmdString) == nil
        let noValidSuperCombo = CommandManager.shared.extractCmdStrings(from: cmdString) == nil
        let noValidMouse = !CommandManager.mouseButtonMappings.keys.contains(cmdString)
        let noValidTouchPad = !CommandManager.touchPadCmds.contains(cmdString)
        let noValidOsc = !CommandManager.oscButtonMappings.keys.contains(cmdString)
        let noValidFunctional = !CommandManager.functionalButtonCmds.contains(cmdString)
        let noValidMotion = !CommandManager.motionControlButtonCmds.contains(cmdString)
        var invalid = noValidKeyboardString && noValidMouse && noValidTouchPad && noValidOsc && noValidFunctional && noValidSuperCombo && noValidMotion

        if buttonLabel.isEmpty {
            params["buttonLabel"] = cmdString.lowercased().capitalized
        }

        let validShapes: Set<String> = ["round", "square", "largesquare"]
        if widgetShape == "r" { widgetShape = "round" }
        else if widgetShape == "s" { widgetShape = "square" }
        else if widgetShape.isEmpty { widgetShape = "default" }
        else if !validShapes.contains(widgetShape) { invalid = true }
        params["shape"] = widgetShape

        if invalid { presentInvalidWidgetCommandAlert() }
        return !invalid
    }

    private func updateWidget(_ widget: OnScreenWidgetView, params: NSMutableDictionary, createNew: Bool) {
        guard isWidgetParamsValid(params) else { return }
        let profile = OSCProfilesManager.sharedManager(.zero).getSelectedProfile()
        let newWidget = OnScreenWidgetView.widget(
            cmdString: params["cmdString"] as? String ?? "",
            buttonLabel: params["buttonLabel"] as? String ?? "",
            shape: params["shape"] as? String ?? "",
            profile: profile
        )

        newWidget.sequence = widget.sequence
        newWidget.autoDockIdleDuration = widget.autoDockIdleDuration
        newWidget.autoDockSettledAlpha = widget.autoDockSettledAlpha
        newWidget.revealMode = widget.revealMode
        newWidget.bulkMoveEnabled = widget.bulkMoveEnabled
        newWidget.layoutUpdateDelegate = self
        newWidget.translatesAutoresizingMaskIntoConstraints = false
        newWidget.widthFactor = widget.widthFactor
        newWidget.heightFactor = widget.heightFactor
        newWidget.borderWidth = widget.borderWidth
        newWidget.highlightSizeFactor = widget.highlightSizeFactor
        newWidget.autoTapInterval = widget.autoTapInterval
        newWidget.autoTapRepeats = widget.autoTapRepeats
        newWidget.sensitivityFactorY = widget.sensitivityFactorY
        newWidget.slideThreshold = widget.slideThreshold
        newWidget.yawFactor = widget.yawFactor
        newWidget.pitchFactor = widget.pitchFactor
        newWidget.rollFactor = widget.rollFactor
        newWidget.decelerationRateX = widget.decelerationRateX
        newWidget.decelerationRateY = widget.decelerationRateY
        newWidget.dWheelWalkModeThreshold = widget.dWheelWalkModeThreshold
        newWidget.minStickOffset = widget.minStickOffset
        newWidget.setVibration(style: Int(widget.vibrationStyle))
        newWidget.mouseButtonAction = widget.mouseButtonAction
        newWidget.animatesTransition = widget.animatesTransition
        newWidget.sprintKeyActionType = widget.sprintKeyActionType
        newWidget.sprintKeyThreshold = widget.sprintKeyThreshold
        newWidget.walkKeyActionType = widget.walkKeyActionType
        newWidget.walkKeyThreshold = widget.walkKeyThreshold

        guard newWidget.widgetType == widget.widgetType else { return }
        view.insertSubview(newWidget, belowSubview: widgetPanelStack)
        newWidget.accessWidgetAttributes()
        newWidget.buttonMode = (newWidget.widgetType == .button && newWidget.touchPadString != "") ? .regular : widget.buttonMode
        newWidget.sensitivityFactorX = widget.sensitivityFactorX
        newWidget.componentSizeFactor = widget.componentSizeFactor
        newWidget.touchPointAnchored = widget.touchPointAnchored
        newWidget.stickIndicatorOffset = widget.stickIndicatorOffset

        if createNew {
            newWidget.setLocation(position: CGPoint(x: 90, y: 130))
            newWidget.sequence = newWidget.getAvailableSequence()
        } else {
            newWidget.setLocation(position: widget.center)
            newWidget.sequenceSet = widget.sequenceSet
            newWidget.parentSequence = widget.parentSequence
        }

        OnScreenWidgetView.set(widget: newWidget, for: newWidget.sequence)
        newWidget.sizeReference = widget.sizeReference
        newWidget.resizeWidgetView()
        newWidget.adjustTransparency(alpha: widget.backgroundAlpha, tweakBorderAlpha: false)
        newWidget.tweakLabelAlpha(alpha: widget.labelAlpha)
        newWidget.tweakBorderAlpha(alpha: widget.borderAlpha)
        newWidget.tweakHighlightAlpha(alpha: widget.highlightAlpha)
        newWidget.adjustBorder(width: widget.borderWidth)
        onScreenWidgetViews.add(newWidget)
        selectedWidget = newWidget
        if !createNew {
            onScreenWidgetViews.remove(widget)
            widget.removeFromSuperview()
        }
    }

    private func createWidgetFromParams(_ params: NSMutableDictionary) {
        guard isWidgetParamsValid(params) else { return }
        let profile = OSCProfilesManager.sharedManager(.zero).getSelectedProfile()
        let widgetView = OnScreenWidgetView.widget(
            cmdString: params["cmdString"] as? String ?? "",
            buttonLabel: params["buttonLabel"] as? String ?? "",
            shape: params["shape"] as? String ?? "",
            profile: profile
        )
        view.insertSubview(widgetView, belowSubview: widgetPanelStack)
        widgetView.isHidden = true
        widgetView.sequence = widgetView.getAvailableSequence()
        OnScreenWidgetView.set(widget: widgetView, for: widgetView.sequence)
        widgetView.layoutUpdateDelegate = self
        widgetView.translatesAutoresizingMaskIntoConstraints = false
        onScreenWidgetViews.add(widgetView)
        widgetView.setLocation(position: CGPoint(x: 90, y: 130))
        widgetView.isHidden = false
        widgetView.resizeWidgetView()
        let componentSizeFactor = widgetView.componentSizeFactor
        widgetView.componentSizeFactor = componentSizeFactor
        widgetView.setVibration(style: Int(UIImpactFeedbackGenerator.FeedbackStyle.light.rawValue))
    }

    private func configureWidgetAlertTextField(
        _ textField: UITextField,
        labelText: String,
        placeholder: String,
        keyboardType: UIKeyboardType,
        text: String? = nil,
        isEnabled: Bool = true
    ) {
        let label = UILabel()
        label.text = LocalizationHelper.localizedString(forKey: labelText)
        label.font = .systemFont(ofSize: 15)
        label.sizeToFit()
        textField.leftView = label
        textField.leftViewMode = .always
        textField.attributedPlaceholder = GenericUtils.getAtrributedPlaceHolder(text: LocalizationHelper.localizedString(forKey: placeholder))
        textField.font = .systemFont(ofSize: 15)
        textField.keyboardType = keyboardType
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        textField.delegate = self
        textField.text = text
        textField.isEnabled = isEnabled
    }

    private func presentLegacyAddWidgetAlert() {
        let params = NSMutableDictionary()
        let alertController = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: ""),
            message: LocalizationHelper.localizedString(forKey: "New On-Screen Widget"),
            preferredStyle: .alert
        )

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Command: ",
                placeholder: "e.g. ctrl, lswheel, wasdpad...",
                keyboardType: .asciiCapable
            )
        }

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Label: ",
                placeholder: "optional",
                keyboardType: .default
            )
        }

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Shape: ",
                placeholder: "r - round/circle, s - square/rect",
                keyboardType: .asciiCapable
            )
        }

        let readInstruction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Read Widget Instruction"), style: .default) { _ in
            if let url = URL(string: LocalizationHelper.localizedString(forKey: "onScreenWidgetStackDoc")),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }

        let cancelAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Cancel"), style: .cancel)
        let okAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "OK"), style: .default) { [weak self, weak alertController] _ in
            guard let self, let fields = alertController?.textFields, fields.count >= 3 else { return }
            params["cmdString"] = fields[0].text ?? ""
            params["buttonLabel"] = fields[1].text ?? ""
            params["shape"] = fields[2].text ?? ""
            self.createWidgetFromParams(params)
        }

        alertController.addAction(readInstruction)
        alertController.addAction(cancelAction)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }

    private func presentLegacyEditWidgetAlert(for widget: OnScreenWidgetView) {
        let params = NSMutableDictionary()
        let alertController = UIAlertController(
            title: LocalizationHelper.localizedString(forKey: ""),
            message: LocalizationHelper.localizedString(forKey: "Edit Selected Widget"),
            preferredStyle: .alert
        )

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Command: ",
                placeholder: "e.g. ctrl, lswheel, wasdpad...",
                keyboardType: .asciiCapable,
                text: widget.cmdString.lowercased()
            )
        }

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Label: ",
                placeholder: "optional",
                keyboardType: .default,
                text: widget.widgetLabel
            )
        }

        alertController.addTextField { [weak self] textField in
            self?.configureWidgetAlertTextField(
                textField,
                labelText: "Shape: ",
                placeholder: "r - round/circle, s - square/rect",
                keyboardType: .asciiCapable,
                text: widget.shape,
                isEnabled: widget.shape != "largeSquare"
            )
        }

        let createNewAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Create New"), style: .default) { [weak self, weak alertController] _ in
            guard let self, let fields = alertController?.textFields, fields.count >= 3 else { return }
            params["cmdString"] = fields[0].text ?? ""
            params["buttonLabel"] = fields[1].text ?? ""
            params["shape"] = fields[2].text ?? ""
            self.updateWidget(widget, params: params, createNew: true)
        }

        let modifyAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Modify"), style: .default) { [weak self, weak alertController] _ in
            guard let self, let fields = alertController?.textFields, fields.count >= 3 else { return }
            params["cmdString"] = fields[0].text ?? ""
            params["buttonLabel"] = fields[1].text ?? ""
            params["shape"] = fields[2].text ?? ""
            self.updateWidget(widget, params: params, createNew: false)
        }

        let cancelAction = UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Cancel"), style: .default)

        alertController.addAction(createNewAction)
        alertController.addAction(modifyAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    @IBAction func addTapped(_ sender: Any?) {
        GenericUtils.autoPopSoftKeyboard = false
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = self
            pickerViewController.tabIdentifiers = ["gamepad", "keyboard", "functional","shortcuts"]
            pickerViewController.initialTabIdentifier = "gamepad"
            pickerViewController.presentOverFullScreen(from: self)
            return
        }

        presentLegacyAddWidgetAlert()
    }

    @available(iOS 13.0, *)
    func widgetPickerViewController(_ controller: WidgetPickerViewController, didCreateWidget payload: NSDictionary) {
        let params = payload.mutableCopy() as? NSMutableDictionary ?? NSMutableDictionary()
        let pickerAction = ((params["pickerAction"] as? String) ?? "").lowercased()
        params.removeObject(forKey: "pickerAction")
        if pickerAction == "modify", let selectedWidget {
            updateWidget(selectedWidget, params: params, createNew: false)
            return
        }
        if pickerAction == "create", controller.isEditMode, let selectedWidget {
            updateWidget(selectedWidget, params: params, createNew: true)
            return
        }
        createWidgetFromParams(params)
    }

    @IBAction func editTapped(_ sender: Any?) {
        GenericUtils.autoPopSoftKeyboard = false
        guard let selectedWidget else {
            AlertControllerUtil.autoCompletion = true
            AlertControllerUtil.showAlert(in: self, title: "", message: LocalizationHelper.localizedString(forKey: "No widget selected"), withCancel: false, buttonTitle: "", countdown: 1, action: {}, completion: {})
            return
        }
        if #available(iOS 13.0, *) {
            let pickerViewController = WidgetPickerViewController()
            pickerViewController.delegate = self
            pickerViewController.tabIdentifiers = ["gamepad", "keyboard", "functional", "shortcuts"]
            pickerViewController.initialTabIdentifier = "gamepad"
            pickerViewController.isEditMode = true
            pickerViewController.initialCmdString = selectedWidget.cmdString
            pickerViewController.initialButtonLabel = selectedWidget.widgetLabel
            pickerViewController.initialShape = selectedWidget.shape
            pickerViewController.presentOverFullScreen(from: self)
            return
        }

        presentLegacyEditWidgetAlert(for: selectedWidget)
    }

    @IBAction func saveTapped(_ sender: Any?) {
        
        if false {
            let targetProfile = profilesManager.getAllProfiles()[0]
            let currentProfile = profilesManager.getSelectedProfile()
            // currentProfile.name = "RPG游戏示例 / RPG example (ZZZ in Genshin style)"
            currentProfile.name = "Default"
            // currentProfile.name = "Editable default";
            profilesManager.replace(targetProfile as! OSCProfile, with: currentProfile)
        }
         
        clearSickInput()
        OSCProfilesManager.setLayoutViewBounds(view.bounds)
        let success = profilesManager.updateSelectedProfile(layoutOSC.oscButtonLayerPool)
        guard sender != nil else { return }
        let message = success
            ? LocalizationHelper.localizedString(forKey: "profileSaveTip")
            : LocalizationHelper.localizedString(forKey: "Profile Default can not be overwritten")
        let alert = UIAlertController(title: success ? LocalizationHelper.localizedString(forKey: "Profile updated successfully") : "", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default) { _ in
            if !success {
                // self.oscProfilesTableViewController?.profileViewRefresh()
            }
        })
        present(alert, animated: true)
    }

    @objc func updateGuidelinesForOnScreenWidget(_ sender: Any) {
        guard let widget = sender as? OnScreenWidgetView else { return }
        layoutOSC.updateGuidelinesFor(onScreenWidget: widget)
        view.bringSubviewToFront(widget)
        let overlapping = layerIsOverlappingWithTrashcanButton(widget.layer)
        selectedWidget?.isOverlappingWithTrashcan = overlapping
        let color = overlapping ? UIColor.red : trashCanStoryBoardColor ?? UIColor.systemTeal
        trashCanButton.tintColor = color
        trashCanButton.titleLabel?.textColor = color
        if overlapping, let selectedWidget {
            OnScreenWidgetView.setFree(widget: selectedWidget)
        }
        undoButton.alpha = 1.0
    }

    private func isIPhone() -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    private func clearSickInput() {
        if selectedWidget != nil && widgetViewSelected && OnScreenWidgetView.gamepadArrivalReported {
            OnScreenControls.shared()?.clearLeftStickTouchPadFlag()
            OnScreenControls.shared()?.clearRightStickTouchPadFlag()
        }
    }

    private func updateClippedMask(for view: UIView) {
        if isIPhone() {
            let maskLayer = CAShapeLayer()
            view.layer.mask = nil
            let visibleRect = view.bounds.insetBy(dx: 40, dy: 0)
            maskLayer.path = UIBezierPath(roundedRect: visibleRect, cornerRadius: 12).cgPath
            view.layer.mask = maskLayer
        }
    }

    private func applyShadowForiOS13(_ stack: UIStackView) {
        stack.backgroundColor = .clear
        for view in stack.arrangedSubviews {
            if let subStack = view as? UIStackView {
                for subview in subStack.arrangedSubviews {
                    if let label = subview as? UILabel {
                        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                        label.layer.cornerRadius = 6
                        label.clipsToBounds = true
                        label.textAlignment = .center
                    } else {
                        subview.tintColor = .systemTeal
                        subview.layer.shadowColor = UIColor.black.withAlphaComponent(0.9).cgColor
                        subview.layer.shadowOffset = CGSize(width: 1, height: 1)
                        subview.layer.shadowOpacity = 1
                        subview.layer.shadowRadius = 5
                    }
                }
            } else {
                view.layer.cornerRadius = 10
                view.clipsToBounds = true
                view.backgroundColor = UIColor.black.withAlphaComponent(0.5)
            }
        }
    }

    @objc private func handleProfileTablViewDismiss() {
        
        switch profileTableLoadingMode {
        case .selectProfile:
            if oscProfilesTableViewController?.loadingMode != .pickProfileData {
                setupWidgetPanel()
            }
            else {widgetPanelStack.isHidden = false}
        case .selectProfileFromMainFrame, .selectProfileFromStreamView:
            clearOnScreenWidgets()
            dismiss(animated: false)
        case .pickProfile:
            clearOnScreenWidgets()
            dismiss(animated: false)
        case .pickProfileData:
            widgetPanelStack.isHidden = false
        }
        
        /*
        if quickSwitchEnabled {
            clearOnScreenWidgets()
            dismiss(animated: false)
        } else {
            if oscProfilesTableViewController?.loadingMode != .pickProfileData {
                setupWidgetPanel()
            }
            else {widgetPanelStack.isHidden = false}
        }*/
    }

    private func addInnerAnalogSticksToOuterAnalogLayers() {
        layoutOSC._rightStickBackground.addSublayer(layoutOSC._rightStick)
        layoutOSC._rightStick.position = CGPoint(x: layoutOSC._rightStickBackground.frame.width / 2, y: layoutOSC._rightStickBackground.frame.height / 2)
        layoutOSC._leftStickBackground.addSublayer(layoutOSC._leftStick)
        layoutOSC._leftStick.position = CGPoint(x: layoutOSC._leftStickBackground.frame.width / 2, y: layoutOSC._leftStickBackground.frame.height / 2)
    }

    
    @objc private func moveToolbar(_ sender: UIGestureRecognizer) {
        let toolbarTopConstraint = UIDevice.current.model.hasPrefix("iPad") ? toolbarTopConstraintiPad! : toolbarTopConstraintiPhone!
        if !isToolbarHidden {
            UIView.animate(withDuration: 0.2, animations: {
                toolbarTopConstraint.constant -= self.toolbarRootView.frame.height
                self.view.layoutIfNeeded()
            }, completion: { finished in
                if finished {
                    self.isToolbarHidden = true
                    self.chevronImageView.image = UIImage(named: "ChevronCompactDown")
                }
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                toolbarTopConstraint.constant += self.toolbarRootView.frame.height
                self.view.layoutIfNeeded()
            }, completion: { finished in
                if finished {
                    self.isToolbarHidden = false
                    self.chevronImageView.image = UIImage(named: "ChevronCompactUp")
                }
            })
        }
    }

    private func handleMissingToolBarIcon(_ view: UIView) {
        for subview in view.subviews {
            if let button = subview as? UIButton {
                button.imageView?.image = button.imageView?.image?.withRenderingMode(.alwaysTemplate)
                button.tintColor = .systemTeal
                if #available(iOS 13.0, *) {
                } else {
                    button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
                    button.setImage(nil, for: .normal)

                    if button === exitButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Exit"), for: .normal)
                    }
                    if button === trashCanButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Del"), for: .normal)
                    }
                    if button === undoButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Undo"), for: .normal)
                    }
                    if button === saveButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Save"), for: .normal)
                    }
                    if button === loadButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Load"), for: .normal)
                    }
                    if button === addButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Add"), for: .normal)
                    }
                    if button === editButton {
                        button.setTitle(LocalizationHelper.localizedString(forKey: "Edit"), for: .normal)
                    }
                }
            }
            handleMissingToolBarIcon(subview)
        }
    }

    private func setupWidgetPanel() {        
        widgetPanelStack.isHidden = profileTableLoadingMode != .selectProfile
        tipTitleLabel.textAlignment = .left
        tipTitleLabel.contentMode = .top
        tipTitleLabel.lineBreakMode = .byWordWrapping
        tipTitleLabel.numberOfLines = 0
        tipTitleLabel.font = .systemFont(ofSize: 23, weight: .bold)
        tipTitleLabel.text = LocalizationHelper.localizedString(forKey: "Important Tips")
        tipTitleLabel.isHidden = isIPhone()

        tipContentLabel.textAlignment = .left
        tipContentLabel.lineBreakMode = .byWordWrapping
        tipContentLabel.contentMode = .top
        tipContentLabel.numberOfLines = 0
        tipContentLabel.accessibilityIdentifier = "tipContent"
        tipContentLabel.font = .systemFont(ofSize: 15)
        tipContentLabel.text = LocalizationHelper.localizedString(forKey: "loadOswConfigTip")
        tipContentLabel.isHidden = false

        widgetPanelStack.layoutMargins = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        widgetPanelStack.isLayoutMarginsRelativeArrangement = true
        widgetPanelStack.layer.cornerRadius = 16
        widgetPanelStack.clipsToBounds = true
        widgetPanelStack.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        currentProfileLabel.text = LocalizationHelper.localizedString(forKey: "Profile: %@", profilesManager.getSelectedProfile().name)
        currentProfileLabel.layer.cornerRadius = isIPhone() ? 9 : 12
        currentProfileLabel.clipsToBounds = true
        currentProfileLabel.textAlignment = .center

        widgetSizeStack.isUserInteractionEnabled = true
        for view in widgetPanelStack.subviews {
            view.isUserInteractionEnabled = true
            if let label = view as? UILabel, view.accessibilityIdentifier == nil {
                label.font = .systemFont(ofSize: 18)
                label.textColor = .white
            }
        }

        widgetSizeSlider.addTarget(self, action: #selector(widgetSizeSliderMoved(_:)), for: .valueChanged)
        widgetSizeSlider.addTarget(self, action: #selector(widgetSizeSliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        widgetSizeLabel.text = LocalizationHelper.localizedString(forKey: "Size")
        widgetSizeStack.isHidden = true
        
        widgetHeightSlider.addTarget(self, action: #selector(widgetHeightSliderMoved(_:)), for: .valueChanged)
        widgetHeightSlider.addTarget(self, action: #selector(widgetSizeSliderTouchUp(_:)), for: [.touchUpInside, .touchUpOutside])
        widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height")
        widgetHeightStack.isHidden = true
        
        componentSizeSlider.addTarget(self, action: #selector(componentSizeSliderMoved(_:)), for: .valueChanged)
        componentSizeLabel.text = LocalizationHelper.localizedString(forKey: "Component size")
        componentSizeStack.isHidden = true
        alphaSliderMode = .widgetAlpha
        widgetAlphaSlider.addTarget(self, action: #selector(widgetAlphaSliderMoved(_:)), for: .valueChanged)
        widgetAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Opacity")
        widgetAlphaLabel.isUserInteractionEnabled = true
        widgetAlphaLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(switchAlphaSlider(_:))))
        borderWidthSliderMode = .widgetBorderWidth
        widgetBorderWidthSlider.addTarget(self, action: #selector(widgetBorderWidthSliderMoved(_:)), for: .valueChanged)
        widgetBorderWidthLabel.text = LocalizationHelper.localizedString(forKey: "Border width")
        widgetBorderWidthLabel.isUserInteractionEnabled = true
        widgetBorderWidthLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(switchBorderWidthSlider(_:))))
        borderWidthAlphaStack.isHidden = true
        
        autoTapLabel.text = LocalizationHelper.localizedString(forKey: "Autotap timer   ")
        autoTapField.delegate = self
        autoTapRepeatsField.delegate = self
        autoTapStack.isHidden = true
        
        sensitivityXSlider.addTarget(self, action: #selector(sensitivityXSliderMoved(_:)), for: .valueChanged)
        sensitivityXLabel.text = LocalizationHelper.localizedString(forKey: "SensitivityX")
        sensitivityXStack.isHidden = true
        sensitivityYSlider.addTarget(self, action: #selector(sensitivityYSliderMoved(_:)), for: .valueChanged)
        sensitivityYLabel.text = LocalizationHelper.localizedString(forKey: "SensitivityY")
        sensitivityYStack.isHidden = true
        
        walkModeThresholdSlider.addTarget(self, action: #selector(walkModeThresholdSliderMoved(_:)), for: .valueChanged)
        walkModeThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Walkmode threshold")
        walkModeThresholdStack.isHidden = true
        
        let whiteAttrs: [NSAttributedString.Key: Any] = [.foregroundColor: UIColor.white]
        
        sprintKeyThresholdSlider.addTarget(self, action: #selector(sprintKeyThresholdSliderMoved(_:)), for: .valueChanged)
        sprintKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Slide threshold")
        sprintKeySelector.addTarget(self, action: #selector(sprintKeyActionChanged(_:)), for: .valueChanged)
        sprintKeySelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        sprintKeyStack.isHidden = true
        
        walkKeyThresholdSlider.addTarget(self, action: #selector(walkKeyThresholdSliderMoved(_:)), for: .valueChanged)
        walkKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Slide threshold")
        walkKeySelector.addTarget(self, action: #selector(walkKeyActionChanged(_:)), for: .valueChanged)
        walkKeySelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        walkKeyStack.isHidden = true
        
        minStickOffsetSlider.addTarget(self, action: #selector(minStickOffsetSliderMoved(_:)), for: .valueChanged)
        minStickOffsetLabel.text = LocalizationHelper.localizedString(forKey: "Minimum offset")
        minStickOffsetStack.isHidden = true
        slideThresholdSlider.addTarget(self, action: #selector(slideThresholdSliderMoved(_:)), for: .valueChanged)
        slideThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Slide threshold")
        slideThresholdStack.isHidden = true
        yawFactorSlider.addTarget(self, action: #selector(yawFactorSliderMoved(_:)), for: .valueChanged)
        yawFactorLabel.text = LocalizationHelper.localizedString(forKey: "Yaw Factor")
        yawFactorStack.isHidden = true
        pitchFactorSlider.addTarget(self, action: #selector(pitchFactorSliderMoved(_:)), for: .valueChanged)
        pitchFactorLabel.text = LocalizationHelper.localizedString(forKey: "Pitch Factor")
        pitchFactorStack.isHidden = true
        rollFactorSlider.addTarget(self, action: #selector(rollFactorSliderMoved(_:)), for: .valueChanged)
        rollFactorLabel.text = LocalizationHelper.localizedString(forKey: "Roll Factor")
        rollFactorStack.isHidden = true
        decelerationRateLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(switchDecelerationRateSlider(_:))))
        decelerationRateLabel.isUserInteractionEnabled = true
        decelerationRateSlider.addTarget(self, action: #selector(decelerationRateSliderMoved(_:)), for: .valueChanged)
        decelerationRateLabel.text = LocalizationHelper.localizedString(forKey: "Deceleration Rate")
        decelerationRateStack.isHidden = true
        
        stickIndicatorOffsetSlider.addTarget(self, action: #selector(stickIndicatorOffsetSliderMoved(_:)), for: .valueChanged)
        stickIndicatorOffsetLabel.text = LocalizationHelper.localizedString(forKey: "Indicator offset")
        stickIndicatorOffsetStack.isHidden = true
        
        autoDockTimerSlider.addTarget(self, action: #selector(autoDockTimerSliderMoved(_:)), for: .valueChanged)
        autoDockTimerLabel.text = LocalizationHelper.localizedString(forKey: "Auto dock")
        autoDockTimerStack.isHidden = true;
        
        dockedAlphaSlider.addTarget(self, action: #selector(dockedAlphaSliderMoved(_:)), for: .valueChanged)
        dockedAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Docked opacity")
        dockedAlphaStack.isHidden = true;
        
        anchorModeSelector.addTarget(self, action: #selector(anchorModeChanged(_:)), for: .valueChanged)
        anchorModeSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        anchorModeStack.isHidden = true
        
        mouseButtonDownSelector.addTarget(self, action: #selector(mouseDownButtonChanged(_:)), for: .valueChanged)
        mouseButtonDownSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        mouseDownButtonStack.isHidden = true
        
        animatedSelector.addTarget(self, action: #selector(animationChanged(_:)), for: .valueChanged)
        animatedSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        animatedStack.isHidden = true
        
        buttonModeSelector.addTarget(self, action: #selector(buttonModeChanged(_:)), for: .valueChanged)
        buttonModeSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        buttonModeStack.isHidden = true
        
        collectedWidgetsSelector.addTarget(self, action: #selector(collectionHiddenChanged(_:)), for: .valueChanged)
        collectedWidgetsSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        revealModeSelector.addTarget(self, action: #selector(revealModeChanged(_:)), for: .valueChanged)
        revealModeSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        collectedWidgetsStack.isHidden = true
        
        bulkMoveSelector.addTarget(self, action: #selector(bulkMoveChanged(_:)), for: .valueChanged)
        bulkMoveSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
        bulkMoveStack.isHidden = true
        
        applyTitle("Clear", for: clearFolderButton)
        applyTitle("Import", for: importFromOtherButton)
        applyTitle("Batch edit", for: bulkEditButton, state: .normal)
        
        bulkWidthSlider.addTarget(self, action: #selector(bulkWidthSliderMoved(_:)), for: .valueChanged)
        bulkWidthLabel.text = LocalizationHelper.localizedString(forKey: "Width")
        
        bulkHeightSlider.addTarget(self, action: #selector(bulkHeightSliderMoved(_:)), for: .valueChanged)
        bulkHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height")
        
        bulkAlphaSlider.addTarget(self, action: #selector(bulkAlphaSliderMoved(_:)), for: .valueChanged)
        bulkAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Opacity")
        
        bulkBorderWidthSlider.addTarget(self, action: #selector(bulkBorderWidthSliderMoved(_:)), for: .valueChanged)
        bulkBorderWidthLabel.text = LocalizationHelper.localizedString(forKey: "Border width")
        
        bulkLabelAlphaSlider.addTarget(self, action: #selector(bulkLabelAlphaSliderMoved(_:)), for: .valueChanged)
        bulkLabelAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Label opacity")
        
        bulkBorderAlphaSlider.addTarget(self, action: #selector(bulkBorderAlphaSliderMoved(_:)), for: .valueChanged)
        bulkBorderAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Border opacity")

        bulkHighlightAlphaSlider.addTarget(self, action: #selector(bulkHighlightAlphaSliderMoved(_:)), for: .valueChanged)
        bulkHighlightAlphaSlider.addTarget(self, action: #selector(bulkHighlightAlphaSliderMoveStopped(_:)), for: [.touchUpInside, .touchUpOutside])
        bulkHighlightAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Highlight opacity")

        bulkHighlightSizeSlider.minimumValue = 0.01
        bulkHighlightSizeSlider.maximumValue = 2
        bulkHighlightSizeSlider.addTarget(self, action: #selector(bulkHighlightSizeSliderMoved(_:)), for: .valueChanged)
        bulkHighlightSizeSlider.addTarget(self, action: #selector(bulkHighlightSizeSliderMoveStopped(_:)), for: [.touchUpInside, .touchUpOutside])
        bulkHighlightSizeLabel.text = LocalizationHelper.localizedString(forKey: "Highlight size")

        
        for stack in bulkEditStacks ?? [] {
            stack.isHidden = true
        }

        if isIPhone() {
            vibrationStyleSelector.addTarget(self, action: #selector(vibrationStyleChanged(_:)), for: .valueChanged)
            vibrationStyleSelector.setTitleTextAttributes(whiteAttrs, for: .normal)
            vibrationStyleStack.isHidden = true
        }

        view.bringSubviewToFront(toolbarRootView)
        view.insertSubview(widgetPanelStack, belowSubview: toolbarRootView)
        widgetPanelStack.translatesAutoresizingMaskIntoConstraints = true
        widgetPanelStack.frame = CGRect(x: view.bounds.width / 2 - widgetPanelStack.frame.width / 2, y: 100, width: widgetPanelStack.frame.width, height: widgetPanelStack.frame.height)
        autoFitStack(widgetPanelStack)

        if isIPhone() {
            for view in widgetPanelStack.arrangedSubviews {
                view.transform = CGAffineTransform(scaleX: 0.83, y: 0.83)
            }
            widgetPanelStack.layoutMargins = UIEdgeInsets(top: 3, left: 2, bottom: 7, right: 2)
            let maskLayer = CAShapeLayer()
            let visibleRect = widgetPanelStack.bounds.insetBy(dx: 40, dy: 0)
            maskLayer.path = UIBezierPath(roundedRect: visibleRect, cornerRadius: 12).cgPath
            widgetPanelStack.layer.mask = maskLayer
            let shouldTrimVibrationSegments: Bool
            if #available(iOS 13.0, *) {
                shouldTrimVibrationSegments = vibrationStyleSelector.numberOfSegments != 6
            } else {
                shouldTrimVibrationSegments = true
            }
            if shouldTrimVibrationSegments {
                vibrationStyleSelector.removeSegment(at: 3, animated: false)
                vibrationStyleSelector.removeSegment(at: 3, animated: false)
            }
        }
    }

    private func applyTitle(_ title:String, for button: UIButton, state: UIControl.State = .normal) {
        let title = LocalizationHelper.localizedString(forKey: title)
        let attr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 115/255.0, green: 224/255.0, blue: 251/255.0, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        button.setAttributedTitle(NSAttributedString(string: title, attributes: attr), for: state)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == autoTapField {
            textField.resignFirstResponder()
            selectedWidget?.setAutoTapIntervalByText(str: textField.text ?? "")
        }
        if textField == autoTapRepeatsField {
            textField.resignFirstResponder()
            if let repeats = UInt32(textField.text ?? "") {
                selectedWidget?.autoTapRepeats = repeats
            }
            else {selectedWidget?.autoTapRepeats = 0}
        }
        return true
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        if GenericUtils.autoPopSoftKeyboard {
            return true
        }
        GenericUtils.autoPopSoftKeyboard = true
        return false
    }

    @objc private func widgetSizeSliderMoved(_ sender: UISlider) {
        if let selectedWidget, widgetViewSelected {
            selectedWidget.translatesAutoresizingMaskIntoConstraints = true
            let aspectRatio = selectedWidget.heightFactor / selectedWidget.widthFactor
            selectedWidget.widthFactor = CGFloat(sender.value)
            selectedWidget.heightFactor = min(max(CGFloat(sender.minimumValue), selectedWidget.widthFactor * aspectRatio), CGFloat(sender.maximumValue))
            widgetSizeLabel.text = LocalizationHelper.localizedString(forKey: "Size: %.2f", sender.value)
            widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", selectedWidget.heightFactor)
            widgetHeightSlider.value = Float(selectedWidget.heightFactor)
        }
        if let selectedControllerLayer, controllerLayerSelected {
            layoutOSC.resizeControllerLayer(with: selectedControllerLayer, and: CGFloat(sender.value))
            widgetSizeLabel.text = LocalizationHelper.localizedString(forKey: "Size: %.2f", sender.value)
            widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", sender.value)
            widgetHeightSlider.value = sender.value
        }
    }
    
    @objc private func widgetSizeSliderTouchUp(_ sender: UISlider) {
        if let selectedWidget, widgetViewSelected {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                selectedWidget.isBeingResized = false
            }
        }
    }

    @objc private func widgetHeightSliderMoved(_ sender: UISlider) {
        widgetHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", sender.value)
        if let selectedWidget, widgetViewSelected {
            selectedWidget.translatesAutoresizingMaskIntoConstraints = true
            if selectedWidget.shape == "round" { return }
            selectedWidget.heightFactor = CGFloat(sender.value)
        }
    }

    @objc private func componentSizeSliderMoved(_ sender: UISlider) {
        componentSizeLabel.text = LocalizationHelper.localizedString(forKey: "Component size: %.2f   ", sender.value)
        if let selectedWidget, widgetViewSelected {
            selectedWidget.translatesAutoresizingMaskIntoConstraints = true
            selectedWidget.componentSizeFactor = CGFloat(sender.value)
        }
    }

    @objc private func widgetAlphaSliderMoved(_ sender: UISlider) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if let selectedWidget, widgetViewSelected {
            switch alphaSliderMode {
            case .widgetAlpha: selectedWidget.adjustTransparency(alpha: CGFloat(sender.value), tweakBorderAlpha: true)
            case .labelAlpha: selectedWidget.tweakLabelAlpha(alpha: CGFloat(sender.value))
            case .borderAlpha: selectedWidget.tweakBorderAlpha(alpha: CGFloat(sender.value))
            case .highlightAlpha: selectedWidget.tweakHighlightAlpha(alpha: CGFloat(sender.value))
            }
            loadWidgetAlphas()
        }
        if let selectedControllerLayer, controllerLayerSelected {
            layoutOSC.adjustControllerLayerOpacity(with: selectedControllerLayer, and: CGFloat(sender.value))
        }
        CATransaction.commit()
    }

    @objc private func widgetBorderWidthSliderMoved(_ sender: UISlider) {
        if let selectedWidget, widgetViewSelected {
            switch borderWidthSliderMode {
            case .widgetBorderWidth:
                selectedWidget.adjustBorder(width: CGFloat(sender.value))
            case .highlightSize:
                selectedWidget.highlightSizeFactor = CGFloat(sender.value)
                if selectedWidget.widgetType == .button { selectedWidget.setupButtonDownVisualEffectLayer() }
                if selectedWidget.hasL3R3Indicator { selectedWidget.setupL3R3Indicator() }
                if selectedWidget.isDirectionPad { selectedWidget.setupLrudDirectionIndicatorlayers() }
            }
        }
        loadWidgetWidths()
    }
    
    
    @objc private func bulkBorderWidthSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkBorderWidthLabel.text = LocalizationHelper.localizedString(forKey: "Border width: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                OnScreenWidgetView.mapping[sequence]?.adjustBorder(width: CGFloat(sender.value))
            }
        }
        else if selectedWidget.parentSequence == -1 {
            for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                widget.adjustBorder(width: CGFloat(sender.value))
            }
        }
    }
    
    @objc private func bulkWidthSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkWidthLabel.text = LocalizationHelper.localizedString(forKey: "Width: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence];
                if widget?.widgetType == .touchPad { continue }
                widget?.widthFactor = CGFloat(sender.value)
            }
        }
        else if selectedWidget.parentSequence == -1 {
             for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                 if widget.widgetType == .touchPad { continue }
                 widget.widthFactor = CGFloat(sender.value)
             }
         }
    }

    @objc private func bulkHeightSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkHeightLabel.text = LocalizationHelper.localizedString(forKey: "Height: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence];
                if widget?.widgetType == .touchPad { continue }
                widget?.heightFactor = CGFloat(sender.value)
            }
        }
        else if selectedWidget.parentSequence == -1 {
             for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                 if widget.widgetType == .touchPad { continue }
                 widget.heightFactor = CGFloat(sender.value)
             }
         }
    }
    
    @objc private func bulkAlphaSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Opacity: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence];
                if widget?.widgetType == .touchPad { continue }
                widget?.adjustTransparency(alpha: CGFloat(sender.value), tweakBorderAlpha: false)
            }
        }
        else if selectedWidget.parentSequence == -1 {
            for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                if widget.widgetType == .touchPad { continue }
                widget.adjustTransparency(alpha: CGFloat(sender.value), tweakBorderAlpha: false)
            }
        }
    }
    
    @objc private func bulkLabelAlphaSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkLabelAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Label opacity: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                OnScreenWidgetView.mapping[sequence]?.tweakLabelAlpha(alpha: CGFloat(sender.value))
            }
        }
        else if selectedWidget.parentSequence == -1 {
             for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                 widget.tweakLabelAlpha(alpha: CGFloat(sender.value))
             }
         }
    }

    @objc private func bulkBorderAlphaSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkBorderAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Border opacity: %.2f", sender.value)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                OnScreenWidgetView.mapping[sequence]?.tweakBorderAlpha(alpha: CGFloat(sender.value))
            }
        }
        else if selectedWidget.parentSequence == -1 {
            for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                widget.tweakBorderAlpha(alpha: CGFloat(sender.value))
            }
        }
    }
    
    @objc private func bulkHighlightAlphaSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkHighlightAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Highlight opacity: %.2f", sender.value)
        OnScreenWidgetView.isTweakingHighlight = true
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence]
                widget?.tweakHighlightAlpha(alpha: CGFloat(sender.value))
                guard let widget = widget else {continue}
                setHiddenForWidgetHighlights(widget)
            }
        }
        else if selectedWidget.parentSequence == -1 {
            for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                widget.tweakHighlightAlpha(alpha: CGFloat(sender.value))
                setHiddenForWidgetHighlights(widget)
            }
        }
    }
    
    @objc private func bulkHighlightAlphaSliderMoveStopped(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            OnScreenWidgetView.isTweakingHighlight = false
            if selectedWidget.isFolder {
                for sequence in selectedWidget.sequenceSet {
                    let widget = OnScreenWidgetView.mapping[sequence]
                    guard let widget = widget else {continue}
                    self.setHiddenForWidgetHighlights(widget)
                }
            }
            else if selectedWidget.parentSequence == -1 {
                for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                    self.setHiddenForWidgetHighlights(widget)
                }
            }
        }
    }
    
    @objc private func bulkHighlightSizeSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        bulkHighlightSizeLabel.text = LocalizationHelper.localizedString(forKey: "Highlight size: %.2f", sender.value)
        OnScreenWidgetView.isTweakingHighlight = true
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if selectedWidget.isFolder {
            for sequence in selectedWidget.sequenceSet {
                let widget = OnScreenWidgetView.mapping[sequence]
                if widget?.widgetType == .button {
                    widget?.highlightSizeFactor = CGFloat(sender.value)
                    widget?.setupButtonDownVisualEffectLayer()
                }
                // if widget?.hasL3R3Indicator == true { widget?.setupL3R3Indicator() }
                guard let widget = widget else {continue}
                setHiddenForWidgetHighlights(widget)
            }
        }
        else if selectedWidget.parentSequence == -1 {
            for widget in OnScreenWidgetView.mapping.values where widget.parentSequence == -1 {
                if widget.widgetType == .button {
                    widget.highlightSizeFactor = CGFloat(sender.value)
                    widget.setupButtonDownVisualEffectLayer()
                }
                self.setHiddenForWidgetHighlights(widget)
            }
        }
        CATransaction.commit()
    }
    
    @objc private func bulkHighlightSizeSliderMoveStopped(_ sender: UISlider) {
        bulkHighlightAlphaSliderMoveStopped(sender)
        return
    }
    
    @objc private func autoDockTimerSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        selectedWidget.autoDockIdleDuration = TimeInterval(Int(sender.value))
        autoDockTimerLabel.text = Int(sender.value) == 0 ? LocalizationHelper.localizedString(forKey: "Auto dock disabled", Int(sender.value)) : LocalizationHelper.localizedString(forKey: "Auto dock: %d s", Int(sender.value))
        return
    }

    @objc private func dockedAlphaSliderMoved(_ sender: UISlider) {
        guard let selectedWidget = selectedWidget else {return}
        selectedWidget.autoDockSettledAlpha = CGFloat(sender.value)
        dockedAlphaLabel.text = LocalizationHelper.localizedString(forKey: "Docked opacity: %d%%", Int(sender.value*100))
        return
    }
    
    @objc private func animationChanged(_ sender: UISegmentedControl) {
        selectedWidget?.animatesTransition = sender.selectedSegmentIndex == 1
    }
    
    @objc private func mouseDownButtonChanged(_ sender: UISegmentedControl) {
        selectedWidget?.mouseButtonAction = MouseButtonAction(rawValue: sender.selectedSegmentIndex) ?? .hovering
    }

    @objc private func buttonModeChanged(_ sender: UISegmentedControl) {
        if let selectedWidget {
            switch sender.selectedSegmentIndex {
            case ButtonMode.slideToToggle.rawValue where selectedWidget.isFunctionalButton:
                self.handleInvalidButtonModeTipsFor(widget: selectedWidget, sender: sender)
            case ButtonMode.slideAndHold.rawValue where (selectedWidget.isFunctionalButton && !selectedWidget.isFolder) || selectedWidget.containsShortcutAction:
                self.handleInvalidButtonModeTipsFor(widget: selectedWidget, sender: sender)
            case ButtonMode.tapToToggle.rawValue where selectedWidget.isFunctionalButton && !selectedWidget.isTapToToggleException:
                self.handleInvalidButtonModeTipsFor(widget: selectedWidget, sender: sender)
            default:
                GenericUtils.handleButtonModeTip(in: self)
                selectedWidget.buttonMode = ButtonMode(rawValue: sender.selectedSegmentIndex) ?? .slideToToggle
            }
        }
    }
    private func handleInvalidButtonModeTipsFor(widget: OnScreenWidgetView, sender: UISegmentedControl) {
        AlertControllerUtil.showAlert(
            in: self,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: "\n\(LocalizationHelper.localizedString(forKey: "invalidButtonModeTip"))\n\n\(LocalizationHelper.localizedString(forKey:widget.isFolder ? "folderButtonModeTip" : ""))",
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 0,
            completion: {
                sender.selectedSegmentIndex = sender.previousSelectedSegmentIndex
            }
        )
    }
    
    private func popBulkEditTip() {
        AlertControllerUtil.showAlert(
            in: self,
            title: LocalizationHelper.localizedString(forKey: "Tips"),
            message: LocalizationHelper.localizedString(forKey: "bulkEditTip"),
            withCancel: false,
            buttonTitle: LocalizationHelper.localizedString(forKey: "Got it!"),
            countdown: 0,
        )
    }

    @objc private func collectionHiddenChanged(_ sender: UISegmentedControl) {
        if let selectedWidget {
            OnScreenWidgetView.set(folded: sender.selectedSegmentIndex == 1, for: selectedWidget)
            if sender.selectedSegmentIndex == 1, bulkEditEnabled {
                self.bulkEditButtonTapped(self.bulkEditButton)
            }
        }
        self.bulkEditButton.isEnabled = sender.selectedSegmentIndex == 0
        self.importFromOtherButton.isEnabled = sender.selectedSegmentIndex == 0
        self.clearFolderButton.isEnabled = sender.selectedSegmentIndex  == 0
        self.widgetAlphaSlider.isEnabled = sender.selectedSegmentIndex == 1
    }

    @objc private func bulkMoveChanged(_ sender: UISegmentedControl) {
        selectedWidget?.bulkMoveEnabled = sender.selectedSegmentIndex == 1
    }

    @objc private func revealModeChanged(_ sender: UISegmentedControl) {
        if let selectedWidget {
            selectedWidget.revealMode = RevealMode(rawValue: sender.selectedSegmentIndex) ?? .coexist
            OnScreenWidgetView.set(folded: selectedWidget.folded, for: selectedWidget)
        }
    }

    @objc private func vibrationStyleChanged(_ sender: UISegmentedControl) {
        guard let selectedWidgetView = selectedWidget else {return}
        
        if #available(iOS 13.0, *) {
            if sender.selectedSegmentIndex <= UIImpactFeedbackGenerator.FeedbackStyle.rigid.rawValue {
                vibrationGenerator = UIImpactFeedbackGenerator(style: UIImpactFeedbackGenerator.FeedbackStyle(rawValue: sender.selectedSegmentIndex) ?? .light)
                vibrationGenerator.prepare()
                vibrationGenerator.impactOccurred()
            }
        }
        selectedWidgetView.setVibration(style: sender.selectedSegmentIndex)
        
        if bulkEditEnabled, selectedWidgetView.isFolder {
            let folder = selectedWidgetView
            for sequence in folder.sequenceSet {
                OnScreenWidgetView.mapping[sequence]?.setVibration(style: sender.selectedSegmentIndex)
            }
        }
        
        if let selectedControllerLayer, controllerLayerSelected {
            OnScreenControls.layerVibrationStyleDic()?.setObject(NSNumber(value: sender.selectedSegmentIndex), forKey: (selectedControllerLayer.name ?? "") as NSString)
        }
    }

    @objc private func sensitivityXSliderMoved(_ sender: UISlider) {
        let key = selectedWidget?.hasSensitivityY == true ? "SensitivityX: %.2f" : "Sensitivity: %.2f"
        sensitivityXLabel.text = LocalizationHelper.localizedString(forKey: key, sender.value)
        sensitivityYLabel.text = LocalizationHelper.localizedString(forKey: "SensitivityY: %.2f", sender.value)
        sensitivityYSlider.value = sender.value
        selectedWidget?.sensitivityFactorX = CGFloat(sender.value)
        selectedWidget?.sensitivityFactorY = CGFloat(sender.value)
    }

    @objc private func sensitivityYSliderMoved(_ sender: UISlider) {
        sensitivityYLabel.text = LocalizationHelper.localizedString(forKey: "SensitivityY: %.2f", sender.value)
        selectedWidget?.sensitivityFactorY = CGFloat(sender.value)
    }

    @objc private func walkModeThresholdSliderMoved(_ sender: UISlider) {
        walkModeThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Walkmode threshold: %.0f   ", sender.value)
        if let selectedWidget, widgetViewSelected {
            selectedWidget.dWheelWalkModeThreshold = CGFloat(sender.value)
            guard let onScreenControls = OnScreenControls.shared() else { return }
            if selectedWidget.touchPadString == "LSWHEEL" {
                onScreenControls.sendLeftStickTouchPadEvent(0, CGFloat(sender.value))
            }
            if selectedWidget.touchPadString == "RSWHEEL" {
                onScreenControls.sendRightStickTouchPadEvent(0, CGFloat(sender.value))
            }
        }
    }

    @objc private func minStickOffsetSliderMoved(_ sender: UISlider) {
        minStickOffsetLabel.text = LocalizationHelper.localizedString(forKey: "Minimum offset: %.0f", sender.value)
        if let selectedWidget, widgetViewSelected {
            selectedWidget.minStickOffset = CGFloat(sender.value)
            guard let onScreenControls = OnScreenControls.shared() else { return }
            if selectedWidget.touchPadString == "LSPAD"
                || selectedWidget.touchPadString == "LSVPAD"
                || selectedWidget.touchPadString == "LSWHEEL" {
                onScreenControls.sendLeftStickTouchPadEvent(CGFloat(sender.value), 0)
            }
            if selectedWidget.touchPadString == "RSPAD"
                || selectedWidget.touchPadString == "RSVPAD"
                || selectedWidget.touchPadString == "RSWHEEL" {
                onScreenControls.sendRightStickTouchPadEvent(CGFloat(sender.value), 0)
            }
        }
    }

    @objc private func slideThresholdSliderMoved(_ sender: UISlider) {
        slideThresholdLabel.text = LocalizationHelper.localizedString(forKey: "Slide threshold: %.1f   ", sender.value)
        selectedWidget?.slideThreshold = CGFloat(sender.value)
    }
    
    @objc private func sprintKeyActionChanged(_ sender: UISegmentedControl) {
        selectedWidget?.sprintKeyActionType = OnScreenWidgetView.WalkSprintKeyActionType(rawValue: UInt8(sender.selectedSegmentIndex)) ?? .hold
    }

    @objc private func sprintKeyThresholdSliderMoved(_ sender: UISlider) {
        sprintKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: " Slide threshold: %0.2f  ", sender.value)
        autoFitLabel(sprintKeyThresholdLabel)

        guard OnScreenWidgetView.editMode, let selectedWidget, widgetViewSelected else { return }

        if sender.value < walkKeyThresholdSlider.value {
            walkKeyThresholdSlider.value = sender.value
            walkKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: " Slide threshold: %0.2f  ", walkKeyThresholdSlider.value)
            autoFitLabel(walkKeyThresholdLabel)
        }

        selectedWidget.sprintKeyThreshold = CGFloat(sender.value)
        selectedWidget.walkKeyThreshold = CGFloat(walkKeyThresholdSlider.value)
        selectedWidget.updateMovementThresholdPreview()
    }
    
    @objc private func walkKeyActionChanged(_ sender: UISegmentedControl) {
        selectedWidget?.walkKeyActionType = OnScreenWidgetView.WalkSprintKeyActionType(rawValue: UInt8(sender.selectedSegmentIndex)) ?? .hold
    }

    @objc private func walkKeyThresholdSliderMoved(_ sender: UISlider) {
        if sender.value > sprintKeyThresholdSlider.value {
            sender.value = sprintKeyThresholdSlider.value
        }

        walkKeyThresholdLabel.text = LocalizationHelper.localizedString(forKey: " Slide threshold: %0.2f  ", sender.value)
        autoFitLabel(walkKeyThresholdLabel)

        guard OnScreenWidgetView.editMode, let selectedWidget, widgetViewSelected else { return }

        selectedWidget.walkKeyThreshold = CGFloat(sender.value)
        selectedWidget.updateMovementThresholdPreview()
    }

    @objc private func yawFactorSliderMoved(_ sender: UISlider) {
        yawFactorLabel.text = LocalizationHelper.localizedString(forKey: "Yaw factor: %.2f", sender.value)
        pitchFactorLabel.text = LocalizationHelper.localizedString(forKey: "Pitch factor: %.2f", sender.value)
        pitchFactorSlider.value = sender.value
        selectedWidget?.yawFactor = CGFloat(sender.value)
        selectedWidget?.pitchFactor = CGFloat(sender.value)
    }

    @objc private func pitchFactorSliderMoved(_ sender: UISlider) {
        pitchFactorLabel.text = LocalizationHelper.localizedString(forKey: "Pitch factor: %.2f", sender.value)
        selectedWidget?.pitchFactor = CGFloat(sender.value)
    }

    @objc private func rollFactorSliderMoved(_ sender: UISlider) {
        rollFactorLabel.text = LocalizationHelper.localizedString(forKey: "Roll factor: %.2f", sender.value)
        selectedWidget?.rollFactor = CGFloat(sender.value)
    }

    @objc private func decelerationRateSliderMoved(_ sender: UISlider) {
        if let selectedWidget {
            switch decelerationRateSliderMode {
            case .decelerationRateX: selectedWidget.decelerationRateX = CGFloat(sender.value)
            case .decelerationRateY: selectedWidget.decelerationRateY = CGFloat(sender.value)
            }
        }
        loadDecelerationRates()
    }

    @objc private func anchorModeChanged(_ sender: UISegmentedControl) {
        if let selectedWidget {
            selectedWidget.touchPointAnchored = sender.selectedSegmentIndex == 1
            
            if selectedWidget.isDisplacementBasedStickPad {
                componentSizeStack.isHidden = sender.selectedSegmentIndex != 0
                stickIndicatorOffsetStack.isHidden = sender.selectedSegmentIndex != 1
                stickIndicatorOffsetSlider.value = Float(selectedWidget.stickIndicatorOffset)
                self.stickIndicatorOffsetSliderMoved(stickIndicatorOffsetSlider)
            }
            
            if selectedWidget.isDirectionPad {
                sensitivityXSlider.value = sender.selectedSegmentIndex == 0 ? 0.0 : 6.5
                sensitivityXSliderMoved(sensitivityXSlider)
            }
            
            autoFitStack(self.widgetPanelStack)
        }
    }

    @objc private func stickIndicatorOffsetSliderMoved(_ sender: UISlider) {
        stickIndicatorOffsetLabel.text = LocalizationHelper.localizedString(forKey: "Indicator offset: %.0f", sender.value)
        if let selectedWidget {
            selectedWidget.stickIndicatorOffset = CGFloat(sender.value)
        }
    }

    private func widgetPanelTouched(_ touch: UITouch) -> Bool {
        let point = touch.location(in: widgetPanelStack)
        return widgetPanelStack.hitTest(point, with: nil) != nil
    }
    
    private func bulkEditButtonTouched(_ touch: UITouch) -> Bool {
        let point = touch.location(in: bulkEditButton)
        return bulkEditButton.bounds.contains(point)
    }

    private func handleWidgetPanelMove(_ touch: UITouch) {
        guard widgetPanelMovedByTouch else { return }
        let currentLocation = touch.location(in: view)
        let offsetX = currentLocation.x - latestTouchLocation.x
        let offsetY = currentLocation.y - latestTouchLocation.y
        widgetPanelStack.center = CGPoint(x: widgetPanelStack.center.x + offsetX, y: widgetPanelStack.center.y + offsetY)
        latestTouchLocation = currentLocation
        widgetPanelStoredCenter = widgetPanelStack.center
    }

    private func layerIsOverlappingWithTrashcanButton(_ layer: CALayer) -> Bool {
        let commonLayer = view.layer
        let rect1 = layer.convert(layer.bounds, to: commonLayer)
        let rect2 = trashCanButton.layer.convert(trashCanButton.layer.bounds, to: commonLayer)
        return rect1.intersects(rect2)  && !self.isToolbarHidden
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            widgetPanelMovedByTouch = widgetPanelTouched(touch)
            if widgetPanelMovedByTouch {
                latestTouchLocation = touch.location(in: view)
            }
            if widgetPanelTouched(touch), selectedWidget != nil {
                GenericUtils.handleWidgetPanelTip(in: self)
            }
            if bulkEditButtonTouched(touch), selectedWidget?.isFolder == true, selectedWidget?.folded == true {
                self.popBulkEditTip()
            }
        }
        for touch in touches {
            var touchLocation = touch.location(in: view)
            touchLocation = touch.view?.convert(touchLocation, to: nil) ?? touchLocation
            guard let layer = view.layer.hitTest(touchLocation) else { continue }
            if layer == toolbarRootView.layer || layer == chevronView.layer || layer == chevronImageView.layer || layer == toolbarStackView.layer || layer == view.layer {
                return
            }
        }
        if let event {
            let bridgedTouches = Set(touches.map { AnyHashable($0) })
            layoutOSC.touchesBegan(bridgedTouches, with: event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            handleWidgetPanelMove(touch)
        }
        if let event {
            let bridgedTouches = Set(touches.map { AnyHashable($0) })
            layoutOSC.touchesMoved(bridgedTouches, with: event)
        }
        let color = (layoutOSC.layerBeingDragged != nil && layerIsOverlappingWithTrashcanButton(layoutOSC.layerBeingDragged!)) ? UIColor.red : (trashCanStoryBoardColor ?? .systemTeal)
        trashCanButton.tintColor = color
        trashCanButton.titleLabel?.textColor = color
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        widgetPanelStack.isUserInteractionEnabled = true
        if let selectedWidget {
            view.insertSubview(selectedWidget, belowSubview: widgetPanelStack)
            if selectedWidget.widgetType == .touchPad {
                view.sendSubviewToBack(selectedWidget)
            }
        }
        if !isToolbarHidden, let selectedWidget, layerIsOverlappingWithTrashcanButton(selectedWidget.layer), selectedWidget.firstTouchMoved {
            OnScreenWidgetView.setFree(widget: selectedWidget)
            OnScreenWidgetView.removeWidgetFromMappings(key: selectedWidget.sequence)
            selectedWidget.removeFromSuperview()
            onScreenWidgetViews.remove(selectedWidget)
        }
        if !isToolbarHidden, let draggedLayer = layoutOSC.layerBeingDragged, layerIsOverlappingWithTrashcanButton(draggedLayer) {
            draggedLayer.isHidden = true
            if draggedLayer.name == "dPad" {
                layoutOSC._upButton.isHidden = true
                layoutOSC._rightButton.isHidden = true
                layoutOSC._downButton.isHidden = true
                layoutOSC._leftButton.isHidden = true
            }
            if draggedLayer.name == "leftStickBackground" { layoutOSC._leftStick.isHidden = true }
            if draggedLayer.name == "rightStickBackground" { layoutOSC._rightStick.isHidden = true }
        }
        if let event {
            let bridgedTouches = Set(touches.map { AnyHashable($0) })
            layoutOSC.touchesEnded(bridgedTouches, with: event)
        }
        if profilesManager.getIndexOfSelectedProfile() == 0, layoutOSC.layoutChanges.count > 0 {
            let alert = UIAlertController(title: "", message: LocalizationHelper.localizedString(forKey: "Layout of the Default profile can not be changed"), preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: LocalizationHelper.localizedString(forKey: "Ok"), style: .default) { _ in
                self.oscProfilesTableViewController?.profileViewRefresh()
            })
            present(alert, animated: true)
        }
        let color = trashCanStoryBoardColor ?? .systemTeal
        trashCanButton.tintColor = color
        trashCanButton.titleLabel?.textColor = color
        widgetPanelMovedByTouch = false
    }
    
    deinit {
        bulkEditStacks = nil
    }
}

@available(iOS 13.0, *)
extension LayoutOnScreenControlsViewController: WidgetPickerViewControllerDelegate {}
