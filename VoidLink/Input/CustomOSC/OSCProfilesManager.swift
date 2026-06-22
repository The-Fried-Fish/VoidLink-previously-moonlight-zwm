//
//  OSCProfilesManager.m -> OSCProfilesManager.swift
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//
//  Modified by True砖家 since 2024.6.24
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

import UIKit

@objcMembers
class OSCProfilesManager: NSObject {
    private static let profilesDefaultsKey = "OSCProfiles"
    private static let widgetProfileUpdatedKey = "widgetProfileUpdated-20260606"

    private static var sharedInstance: OSCProfilesManager?
    private static var onScreenWidgetViews: NSMutableSet?
    private static var layoutViewBounds: CGRect = .zero

    var currentProfiles: NSMutableArray = []
    var widgetSizeTransition: WidgetSizeTransition = .keepWidgetSize

    @objc(sharedManager:)
    class func sharedManager(_ viewBounds: CGRect) -> OSCProfilesManager {
        if viewBounds != .zero {
            layoutViewBounds = viewBounds
        }
        if let sharedInstance {
            return sharedInstance
        }

        let manager = OSCProfilesManager()
        sharedInstance = manager
        return manager
    }

    @objc(setOnScreenWidgetViewsSet:)
    class func setOnScreenWidgetViewsSet(_ set: NSMutableSet) {
        onScreenWidgetViews = set
    }

    @objc(setLayoutViewBounds:)
    class func setLayoutViewBounds(_ bounds: CGRect) {
        layoutViewBounds = bounds
    }

    private static let profileCodingClasses: [AnyClass] = [
        NSString.self,
        NSMutableData.self,
        NSMutableArray.self,
        OSCProfile.self,
        OnScreenButtonState.self,
    ]

    private static let buttonStateCodingClasses: [AnyClass] = [
        NSString.self,
        OnScreenButtonState.self,
        NSSet.self,
        NSNumber.self,
    ]

    private func oscProfile(withName name: String) -> OSCProfile? {
        let profiles = getAllProfiles()
        for case let profile as OSCProfile in profiles where profile.name == name {
            return profile
        }
        return nil
    }

    private func encodedProfiles(from profiles: NSMutableArray) -> NSMutableArray {
        let profilesEncoded = NSMutableArray()
        for case let profile as OSCProfile in profiles {
            if let profileEncoded = try? NSKeyedArchiver.archivedData(withRootObject: profile, requiringSecureCoding: true) {
                profilesEncoded.add(profileEncoded)
            }
        }
        return profilesEncoded
    }

    private func persistProfiles(_ profiles: NSMutableArray) {
        let profilesEncoded = encodedProfiles(from: profiles)
        persistEncodedProfiles(profilesEncoded)
    }

    private func persistEncodedProfiles(_ profilesEncoded: NSMutableArray) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: profilesEncoded, requiringSecureCoding: true) else {
            return
        }
        let defaults = UserDefaults.standard
        defaults.set(data, forKey: Self.profilesDefaultsKey)
        defaults.synchronize()
    }

    func deleteCurrentSelectedProfile() {
        let profiles = getAllProfiles()
        var selectedIndex = getIndexOfSelectedProfile()

        if selectedIndex != 0 {
            profiles.removeObject(at: selectedIndex)
        } else {
            NSLog("Default profile!")
        }

        selectedIndex -= 1
        if selectedIndex < 0 {
            selectedIndex = 0
        }

        if let newSelectedProfile = profiles[safe: selectedIndex] as? OSCProfile {
            newSelectedProfile.isSelected = true
        }

        persistProfiles(profiles)
    }

    func replaceSelectedProfile(with newProfile: OSCProfile, overwriteDefault: Bool) {
        let profiles = getAllProfiles()
        var index = 0

        for case let profile as OSCProfile in profiles where profile.isSelected {
            index = profiles.index(of: profile)
        }

        if index > 0 || overwriteDefault {
            profiles.replaceObject(at: index, with: newProfile)
        }

        persistProfiles(profiles)
    }

    @objc(replaceProfile:withProfile:)
    func replaceProfile(_ oldProfile: OSCProfile, withProfile newProfile: OSCProfile) {
        let profiles = getAllProfiles()

        for case let profile as OSCProfile in profiles {
            profile.isSelected = false
        }

        newProfile.isSelected = true

        var index = 0
        for i in 0 ..< profiles.count {
            guard let profile = profiles[i] as? OSCProfile else { continue }
            if profile.name == oldProfile.name {
                index = i
            }
        }

        profiles.removeObject(at: index)
        profiles.insert(newProfile, at: index)
        persistProfiles(profiles)
    }

    func replace(_ oldProfile: OSCProfile, with newProfile: OSCProfile) {
        replaceProfile(oldProfile, withProfile: newProfile)
    }

    func getEncodedProfiles() -> NSMutableArray {
        guard
            let profilesArrayEncoded = UserDefaults.standard.object(forKey: Self.profilesDefaultsKey) as? Data,
            let profilesEncoded = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.profileCodingClasses, from: profilesArrayEncoded) as? NSMutableArray
        else {
            return NSMutableArray()
        }

        return profilesEncoded
    }

    func importEncodedProfiles(_ profilesEncoded: NSMutableArray) {
        let localProfiles = currentProfiles.mutableCopy() as? NSMutableArray ?? NSMutableArray()

        if localProfiles.count > 0 {
            localProfiles.removeObject(at: 0)
        }
        
        let profilesDecoded = decodeProfiles(from: profilesEncoded)
        
        let localProfileNames = Set(
            localProfiles.compactMap { ($0 as? OSCProfile)?.name }
        )
        
        for case let profile as OSCProfile in profilesDecoded {
            if localProfileNames.contains(profile.name) {
                // profile.name = "\(profile.name)-\(LocalizationHelper.localizedString(forKey:"Restored"))"
                profile.name = "\(profile.name) - Restored"
            }
        }
        
        let importedProfileNames = Set(
            profilesDecoded.compactMap { ($0 as? OSCProfile)?.name }
        )
        
        var localProfilesToRemove: [OSCProfile] = []
        for case let profile as OSCProfile in localProfiles {
            if importedProfileNames.contains(profile.name) {localProfilesToRemove.append(profile)}
        }
        
        for case let profile as Any in localProfilesToRemove {
            localProfiles.remove(profile)
        }
        
        var indexOffset = 0
        for profile in localProfiles {
            profilesDecoded.insert(profile, at: 1+indexOffset)
            indexOffset += 1
        }

        persistEncodedProfiles(encodedProfiles(from: profilesDecoded))
    }

    private func isIPhone() -> Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    func importDefaultTemplates() {
        guard let filePath = Bundle.main.path(forResource: isIPhone() ? "widgetTemplatesIPhone" : "widgetTemplates", ofType: "bin") else {
            return
        }

        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath), options: .mappedIfSafe)
            if let profilesEncoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSMutableData.self, NSMutableArray.self], from: fileData) as? NSMutableArray {
                importEncodedProfiles(profilesEncoded)
                setProfileToSelected(0)
            }
        } catch {
            return
        }
    }

    /*
    func updateDefaultTemplates() {
        guard let filePath = Bundle.main.path(forResource: isIPhone() ? "widgetTemplatesIPhone" : "widgetTemplates", ofType: "bin") else {
            return
        }

        do {
            let fileData = try Data(contentsOf: URL(fileURLWithPath: filePath), options: .mappedIfSafe)
            guard let defaultProfilesEncoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.profileCodingClasses, from: fileData) as? NSMutableArray else {
                return
            }

            let targetProfilesDecoded = getAllProfiles()
            var newPencilProProfile: OSCProfile?
            var pencilProProfileExisted = false

            for case let profileEncoded as Data in defaultProfilesEncoded {
                guard let defaultProfileDecoded = try NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.profileCodingClasses, from: profileEncoded) as? OSCProfile else {
                    continue
                }

                let targetProfile = findProfile(byName: defaultProfileDecoded.name, inProfileArray: targetProfilesDecoded)
                if defaultProfileDecoded.name == "Pencil Pro" {
                    newPencilProProfile = defaultProfileDecoded.mutableCopy() as? OSCProfile
                }

                if let targetProfile {
                    if targetProfile.name == "Pencil Pro" {
                        pencilProProfileExisted = true
                    }
                    let targetIndex = targetProfilesDecoded.index(of: targetProfile)
                    targetProfilesDecoded.replaceObject(at: targetIndex, with: defaultProfileDecoded)
                }
            }

            if let newPencilProProfile, !pencilProProfileExisted {
                targetProfilesDecoded.insert(newPencilProProfile, at: 1)
            }

            persistProfiles(targetProfilesDecoded)
            setProfileToSelected(0)
        } catch {
            return
        }
    }
     */

    func getAllProfiles() -> NSMutableArray {
        guard
            let profilesArrayEncoded = UserDefaults.standard.object(forKey: Self.profilesDefaultsKey) as? Data,
            let profilesEncoded = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.profileCodingClasses, from: profilesArrayEncoded) as? NSMutableArray
        else {
            currentProfiles = NSMutableArray()
            return currentProfiles
        }

        let profilesDecoded = decodeProfiles(from: profilesEncoded)
        currentProfiles = profilesDecoded
        return profilesDecoded
    }

    private func decodeProfiles(from profilesEncoded: NSMutableArray) -> NSMutableArray {
        let profilesDecoded = NSMutableArray()
        for case let profileEncoded as Data in profilesEncoded {
            guard let profileDecoded = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.profileCodingClasses, from: profileEncoded) as? OSCProfile else {
                continue
            }
            profilesDecoded.add(profileDecoded)
        }
        return profilesDecoded
    }

    func getSelectedProfile() -> OSCProfile {
        var profiles = getAllProfiles()
        let defaults = UserDefaults.standard
        let needImportDefaultTemplates = defaults.object(forKey: Self.widgetProfileUpdatedKey) == nil

        if (profiles.count == 0 || needImportDefaultTemplates) && !GenericUtils.pencilProPurchaseProcessedWithImportingWidgetTemplates {
            importDefaultTemplates()
            defaults.set(true, forKey: Self.widgetProfileUpdatedKey)
            defaults.synchronize()
            profiles = getAllProfiles()
        }

        for case let profile as OSCProfile in profiles where profile.isSelected {
            return profile
        }

        return (profiles.firstObject as? OSCProfile) ?? OSCProfile(name: "", buttonStates: NSMutableArray(), isSelected: false)
    }

    func getIndexOfSelectedProfile() -> Int {
        let profiles = getAllProfiles()
        for case let profile as OSCProfile in profiles where profile.isSelected {
            return profiles.index(of: profile)
        }
        return 0
    }

    func getIndexOfLastProfile() -> UInt32 {
        let profiles = getAllProfiles()
        return profiles.count > 0 ? UInt32(profiles.count - 1) : 0
    }

    func setProfileToSelected(_ tableIndex: UInt32) {
        let profiles = getAllProfiles()

        for (idx, element) in profiles.enumerated() {
            guard let profile = element as? OSCProfile else { continue }
            profile.isSelected = idx == Int(tableIndex)
        }

        persistProfiles(profiles)
    }

    func updateSelectedProfile(_ oscButtonLayers: NSMutableSet) -> Bool {
        let buttonStatesEncoded = convertOnScreenControllerAndWidgetsToButtonStates(oscButtonLayers)
        if getIndexOfSelectedProfile() == 0 {
            return false
        }

        let selectedProfile = getSelectedProfile()
        selectedProfile.buttonStatesEncoded = buttonStatesEncoded
        selectedProfile.unfoldedExclusiveFolderSequence = OnScreenWidgetView.unfoldedExclusiveFolderSequence
        selectedProfile.postExclusiveUnfoldedSequences = Set(OnScreenWidgetView.postExclusiveUnfoldedSequences.map { NSNumber(value: $0) })
        replaceSelectedProfile(with: selectedProfile, overwriteDefault: false)
        return true
    }

    func duplicateSelectedProfile(withName name: String) {
        if profileNameAlreadyExist(name) {
            return
        }

        let profiles = getAllProfiles()
        var newProfile: OSCProfile?

        for case let profile as OSCProfile in profiles where profile.isSelected {
            profile.isSelected = false
            newProfile = profile.mutableCopy() as? OSCProfile
            newProfile?.isSelected = true
            newProfile?.name = name
        }

        guard let newProfile, let newProfileEncoded = try? NSKeyedArchiver.archivedData(withRootObject: newProfile, requiringSecureCoding: true) else {
            return
        }

        let profilesEncoded = encodedProfiles(from: profiles)
        profilesEncoded.add(newProfileEncoded)
        persistEncodedProfiles(profilesEncoded)
    }

    func normalizeWidgetPosition(_ position: CGPoint) -> CGPoint {
        var normalizedPosition = position
        let originalPosition = position
        if position.x > 1.0, position.y > 1.0 {
            normalizedPosition.x = position.x / Self.layoutViewBounds.size.width
            normalizedPosition.y = position.y / Self.layoutViewBounds.size.height
        }
        NSLog("layoutToolView bounds: %f, %f", Self.layoutViewBounds.size.width, Self.layoutViewBounds.size.height)
        NSLog("position: %f, %f, denormalized position: %f, %f", normalizedPosition.x, normalizedPosition.y, originalPosition.x, originalPosition.y)
        return normalizedPosition
    }

    private func denormalizeWidgetPosition(_ position: CGPoint) -> CGPoint {
        var denormalizedPosition = position
        if position.x < 1.0, position.y < 1.0 {
            denormalizedPosition.x = position.x * Self.layoutViewBounds.size.width
            denormalizedPosition.y = position.y * Self.layoutViewBounds.size.height
        }
        return denormalizedPosition
    }

    private func convertOnScreenControllerAndWidgetsToButtonStates(_ oscButtonLayers: NSMutableSet) -> NSMutableArray {
        let buttonStatesEncoded = NSMutableArray()

        for case let oscButtonLayer as CALayer in oscButtonLayers {
            if oscButtonLayer.isHidden {
                continue
            }

            let normalizedPosition = normalizeWidgetPosition(oscButtonLayer.position)
            let layerName = oscButtonLayer.name ?? ""
            let buttonState = OnScreenButtonState(buttonName: layerName, buttonType: 0, andPosition: normalizedPosition)
            buttonState.isHidden = oscButtonLayer.isHidden
            buttonState.oscLayerSizeFactor = OnScreenControls.getControllerLayerSizeFactor(oscButtonLayer)
            buttonState.backgroundAlpha = CGFloat(oscButtonLayer.opacity)

            if let style = OnScreenControls.layerVibrationStyleDic()?.object(forKey: layerName) as? NSNumber {
                buttonState.vibrationStyle = style.uint8Value
            } else {
                buttonState.vibrationStyle = UInt8(UIImpactFeedbackGenerator.FeedbackStyle.light.rawValue)
            }

            if let buttonStateEncoded = try? NSKeyedArchiver.archivedData(withRootObject: buttonState, requiringSecureCoding: true) {
                buttonStatesEncoded.add(buttonStateEncoded)
            }
        }

        widgetSizeTransition = .keepWidgetSize
        for widgetView in OnScreenWidgetView.mapping.values {
            let normalizedPosition = normalizeWidgetPosition(widgetView.storedCenter)
            let buttonState = OnScreenButtonState(buttonName: widgetView.cmdString, buttonType: 1, andPosition: normalizedPosition)
            buttonState.alias = widgetView.widgetLabel
            buttonState.sequence = widgetView.sequence
            buttonState.sequenceSet = Set(widgetView.sequenceSet.map { NSNumber(value: $0) })
            buttonState.parentSequence = widgetView.parentSequence
            buttonState.autoDockTimer = Int16(widgetView.autoDockIdleDuration)
            buttonState.dockedAlpha = widgetView.autoDockSettledAlpha
            buttonState.folded = widgetView.folded
            buttonState.revealMode = UInt8(widgetView.revealMode.rawValue)
            buttonState.bulkMoveEnabled = widgetView.bulkMoveEnabled
            buttonState.widthFactor = normalizeSizeWidthFactor(with: widgetView)
            buttonState.heightFactor = normalizeSizeHeightFactor(with: widgetView)
            buttonState.backgroundAlpha = widgetView.originalBackgroundAlpha
            buttonState.labelAlpha = widgetView.originalLabelAlpha
            buttonState.borderAlpha = widgetView.borderAlpha
            buttonState.highlightAlpha = widgetView.highlightAlpha
            buttonState.borderWidth = widgetView.borderWidth
            buttonState.highlightSizeFactor = widgetView.highlightSizeFactor
            buttonState.autoTapInterval = UInt16(widgetView.autoTapInterval)
            buttonState.autoTapRepeats = widgetView.autoTapRepeats
            buttonState.vibrationStyle = UInt8(widgetView.vibrationStyle)
            buttonState.mouseButtonAction = UInt8(widgetView.mouseButtonAction.rawValue)
            buttonState.animatesTransition = widgetView.animatesTransition
            buttonState.sensitivityFactorY = widgetView.sensitivityFactorY
            buttonState.slideThreshold = widgetView.slideThreshold
            buttonState.yawFactor = widgetView.yawFactor
            buttonState.pitchFactor = widgetView.pitchFactor
            buttonState.rollFactor = widgetView.rollFactor
            buttonState.decelerationRateX = widgetView.decelerationRateX
            buttonState.decelerationRateY = widgetView.decelerationRateY
            buttonState.widgetShape = widgetView.shape
            buttonState.walkModeThreshold = widgetView.dWheelWalkModeThreshold
            buttonState.minStickOffset = widgetView.minStickOffset
            buttonState.buttonMode = UInt8(widgetView.buttonMode.rawValue)
            buttonState.sprintKeyActionType = widgetView.sprintKeyActionType.rawValue
            buttonState.sprintKeyThreshold = widgetView.sprintKeyThreshold
            buttonState.walkKeyActionType = widgetView.walkKeyActionType.rawValue
            buttonState.walkKeyThreshold = widgetView.walkKeyThreshold
            buttonState.sensitivityFactorX = widgetView.sensitivityFactorX
            buttonState.componentSizeFactor = normalizeComponentSizeFactor(with: widgetView)
            buttonState.touchPointAnchored = widgetView.touchPointAnchored
            buttonState.stickIndicatorOffset = widgetView.stickIndicatorOffset

            if let buttonStateEncoded = try? NSKeyedArchiver.archivedData(withRootObject: buttonState, requiringSecureCoding: true) {
                buttonStatesEncoded.add(buttonStateEncoded)
            }
        }

        return buttonStatesEncoded
    }

    private func getReferenceLen() -> CGFloat {
        let screenBounds = UIScreen.main.bounds
        let screenWidthInPoints = screenBounds.width
        let screenHeightInPoints = screenBounds.height
        let longSideLen = max(screenWidthInPoints, screenHeightInPoints)

        if widgetSizeTransition == .transitionWithOrientation {
            return screenWidthInPoints
        }
        return longSideLen
    }

    private func normalizeSizeWidthFactor(with widget: OnScreenWidgetView) -> CGFloat {
        widget.bounds.size.width / getReferenceLen() * 10000
    }

    private func normalizeSizeHeightFactor(with widget: OnScreenWidgetView) -> CGFloat {
        widget.bounds.size.height / getReferenceLen() * 10000
    }

    private func normalizeComponentSizeFactor(with widget: OnScreenWidgetView) -> CGFloat {
        if widget.isStickWheel || widget.isDisplacementBasedStickPad {
            return widget.denormalizedComponentSizeFactor * widget.baselineDiameter / getReferenceLen() * 10000
        }
        return 1
    }

    func profileNameAlreadyExist(_ name: String) -> Bool {
        let profiles = getAllProfiles()
        for case let profile as OSCProfile in profiles where profile.name == name {
            return true
        }
        return false
    }

    @objc(findProfileByName:inProfileArray:)
    func findProfile(byName name: String, inProfileArray profiles: NSMutableArray) -> OSCProfile? {
        for case let profile as OSCProfile in profiles where profile.name == name {
            return profile
        }
        return nil
    }
    
    func getIndex(byName name: String) -> UInt32? {
        let profiles = getAllProfiles()
        for case let profile as OSCProfile in profiles where profile.name == name {
            return UInt32(profiles.index(of: profile))
        }
        return nil
    }

    func unarchiveButtonStateEncoded(_ data: Data) -> OnScreenButtonState {
        if let buttonState = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: Self.buttonStateCodingClasses, from: data) as? OnScreenButtonState {
            return buttonState
        }
        return OnScreenButtonState(buttonName: "", buttonType: 0, andPosition: .zero)
    }
}

private extension NSMutableArray {
    subscript(safe index: Int) -> Any? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
