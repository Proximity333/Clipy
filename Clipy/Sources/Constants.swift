//
//  Constants.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/04/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation

struct Constants {

    struct Application {
        #if DEBUG
            static let name = "ClipyDEBUG"
        #else
            static let name = "Clipy"
        #endif

        static let appcastURL = URL(string: "https://raw.githubusercontent.com/Proximity333/Clipy/develop/appcast.xml")!
    }

    struct Menu {
        static let clip = "ClipMenu"
        static let history = "HistoryMenu"
    }

    struct UserDefaults {
        static let hotKeys = "kCPYPrefHotKeysKey"
        static let maxHistorySize = "kCPYPrefMaxHistorySizeKey"
        static let storeTypes = "kCPYPrefStoreTypesKey"
        static let inputPasteCommand = "kCPYPrefInputPasteCommandKey"
        static let reorderClipsAfterPasting = "kCPYPrefReorderClipsAfterPasting"
        static let addClearHistoryMenuItem = "kCPYPrefAddClearHistoryMenuItemKey"
        static let showAlertBeforeClearHistory = "kCPYPrefShowAlertBeforeClearHistoryKey"
        static let loginItem = "loginItem"
        static let suppressAlertForLoginItem = "suppressAlertForLoginItem"
        static let showStatusItem = "kCPYPrefShowStatusItemKey"
        static let overwriteSameHistory = "kCPYPrefOverwriteSameHistroy"
        static let copySameHistory = "kCPYPrefCopySameHistroy"
        static let excludeApplications = "kCPYExcludeApplications"
        static let collectCrashReport = "kCPYCollectCrashReport"
        static let showColorPreviewInTheMenu = "kCPYPrefShowColorPreviewInTheMenu"
        static let appearance = "kCPYPrefAppearance"
        static let searchWindowWidth = "kCPYSearchWindowWidth"
        static let searchWindowHeight = "kCPYSearchWindowHeight"
        static let searchListWidth = "kCPYSearchListWidth"
    }

    struct Update {
        static let enableAutomaticCheck = "kCPYEnableAutomaticCheckKey"
        static let checkInterval = "kCPYUpdateCheckIntervalKey"
    }

    struct HotKey {
        static let mainKeyCombo = "kCPYHotKeyMainKeyCombo"
        static let historyKeyCombo = "kCPYHotKeyHistoryKeyCombo"
        static let migrateNewKeyCombo = "kCPYMigrateNewKeyCombo"
        static let folderKeyCombos = "kCPYFolderKeyCombos"
        static let clearHistoryKeyCombo = "kCPYClearHistoryKeyCombo"
    }

}
