//
//  DataManager.m -> DataManager.swift
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//
//  Modified by True砖家 since 2024.6.1
//  Copyright © 2024 True砖家 @ Bilibili. All rights reserved.
//

import Foundation
import CoreData
import UIKit

// Keep raw values stable for persisted settings and profiles.

@objc enum ControllerGyroSwitchMode: Int {
    case disabled
    case pressToToggle
    case holdDown
}

@objc enum TouchMode: Int {
    case relative = 0
    case native = 1
    case absolute = 2
    case disabled = 3
    case nativeOnly = 4
}

@objc enum TrackpadGestureMode: Int {
    case pinchDisabled
    case zoomViewport
    case nativeTrackpad
    case ctrlAndScroll
}

@objc enum TouchEventPriorityEnum: Int {
    case AsyncNativeTouchOff
    case EqualPriority
    case TouchDownPriority
    case TouchMovePriority
}

@objc enum GyroMode: Int {
    case off
    case auto
    case alwaysDevice
    case alwaysController
}

@objc enum HapticEnginePreference: Int {
    case auto
    case rumbleDevice
    case leftRightSwapped
    case rumbleOff
}

@objc enum FramePacingMode: Int {
    case off
    case legacy
    case queue
    case interpolation
}

@objc enum SettingsMenuMode: Int {
    case all
    case favorite
    case removeSettingItem
}

@objc enum WidgetSizeTransition: Int {
    case keepWidgetSize
    case transitionWithOrientation
}

@objc enum PencilTickMode: Int {
    case disabled
    case manualTick
}

@objc enum ExternalDisplayMode: Int {
    case duplicated
    case extended
}

@objc enum MousePointerMode: Int {
    case captured
    case hidden
    case visible
}

@objc enum AudioConfig: Int {
    case stereo = 2
    case stereoSDL = 3
    case SDL51 = 6
    case SDL71 = 8
}

@objc enum StatsOverlayLevel: Int {
    case off
    case simplified
    case detailed
}

/// A main-queue child context backed by AppDelegate's persistent context.
/// Public selectors remain compatible with the Objective-C callers.
@objc(DataManager)
@objcMembers
final class DataManager: NSObject {
    private let managedObjectContext: NSManagedObjectContext
    private let appDelegate: AppDelegate

    override init() {
        // UIApplication's delegate must only be read on the main thread.
        let delegate: AppDelegate
        if Thread.isMainThread {
            delegate = UIApplication.shared.delegate as! AppDelegate
        } else {
            delegate = DispatchQueue.main.sync { UIApplication.shared.delegate as! AppDelegate }
        }
        appDelegate = delegate
        managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.parent = delegate.managedObjectContext
        super.init()
    }

    @objc(updateUniqueId:)
    func updateUniqueId(_ uniqueId: String) {
        managedObjectContext.performAndWait {
            retrieveSettings().uniqueId = uniqueId
            saveData()
        }
    }

    func getUniqueId() -> String! {
        var uniqueId: String?
        managedObjectContext.performAndWait {
            let settings = retrieveSettings()!
            uniqueId = settings.uniqueId
            if settings.isInserted {
                saveData()
            }
        }
        return uniqueId
    }

    @objc(updateHost:)
    func update(_ host: TemporaryHost) {
        managedObjectContext.performAndWait {
            let parent = findHost(host) ?? Host(
                entity: NSEntityDescription.entity(forEntityName: "Host", in: managedObjectContext)!,
                insertInto: managedObjectContext)
            host.propagateChanges(toParent: parent)
            saveData()
        }
    }

    func updateAppsForExistingHost(_ host: TemporaryHost) {
        managedObjectContext.performAndWait {
            guard let parent = findHost(host) else { return }
            let appRecords: [App] = fetchRecords("App")
            var appList = Set<App>()
            for case let app as TemporaryApp in host.appList {
                let parentApp = findApp(app, in: appRecords) ?? App(
                    entity: NSEntityDescription.entity(forEntityName: "App", in: managedObjectContext)!,
                    insertInto: managedObjectContext)
                app.propagateChanges(toParent: parentApp, with: parent)
                appList.insert(parentApp)
            }
            parent.appList = appList
            saveData()
        }
    }

    func getSettings() -> TemporarySettings! {
        var settings: TemporarySettings?
        managedObjectContext.performAndWait {
            let record = retrieveSettings()!
            settings = TemporarySettings(from: record)
        }
        return settings
    }

    // Callers edit this managed object on its main queue, then call saveData().
    func retrieveSettings() -> Settings! {
        let records: [Settings] = fetchRecords("Settings")
        if let settings = records.first { return settings }

        let settings = Settings(
            entity: NSEntityDescription.entity(forEntityName: "Settings", in: managedObjectContext)!,
            insertInto: managedObjectContext)
        settings.uniqueId = IdManager.generateUniqueId()
        return settings
    }

    func removeApp(_ app: TemporaryApp) {
        managedObjectContext.performAndWait {
            if let managedApp = findApp(app, in: fetchRecords("App")) {
                managedObjectContext.delete(managedApp)
                saveData()
            }
        }
    }

    func removeHost(_ host: TemporaryHost) {
        managedObjectContext.performAndWait {
            if let managedHost = findHost(host) {
                managedObjectContext.delete(managedHost)
                saveData()
            }
        }
    }

    func saveData() {
        saveData(waitForPersistentStore: false)
    }

    func saveDataSynchronously() {
        saveData(waitForPersistentStore: true)
    }

    private func saveData(waitForPersistentStore: Bool) {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                NSLog("Unable to save hosts to database: %@", error as NSError)
            }
        }
#if os(tvOS)
        // Keep the startup snapshot current only until Settings consumes it.
        appDelegate.refreshTvOSInitialSettingsSnapshot(TemporarySettings(from: retrieveSettings()))
#endif
        if waitForPersistentStore {
            appDelegate.saveContextSynchronously()
        } else {
            appDelegate.saveContext()
        }
    }

    func getHosts() -> [TemporaryHost] {
        var hosts: [TemporaryHost] = []
        managedObjectContext.performAndWait {
            let records: [Host] = fetchRecords("Host")
            hosts = records.map { TemporaryHost(from: $0) }
        }
        return hosts
    }

    // Helpers below run on managedObjectContext's queue.
    private func findHost(_ host: TemporaryHost) -> Host? {
        let records: [Host] = fetchRecords("Host")
        return records.first { $0.uuid != nil && $0.uuid == host.uuid }
    }

    private func findApp(_ app: TemporaryApp, in records: [App]) -> App? {
        // Unlike Optional equality, Objective-C string equality never matches two nils.
        guard let appId = app.id, let hostId = app.host?.uuid else { return nil }
        return records.first { $0.id == appId && $0.host?.uuid == hostId }
    }

    private func fetchRecords<T: NSManagedObject>(_ entityName: String) -> [T] {
        let request = NSFetchRequest<T>(entityName: entityName)
        return (try? managedObjectContext.fetch(request)) ?? []
    }
}
