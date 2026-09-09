//
//  HotKeyService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/19.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Foundation
import Cocoa
import Magnet
import RealmSwift

final class HotKeyService: NSObject {

    // MARK: - Properties
    static var defaultKeyCombos: [String: Any] = {
        // MainMenu:    ⌘ + Shift + V
        // HistoryMenu: ⌘ + Control + V
        return [Constants.Menu.clip: ["keyCode": 9, "modifiers": 768],
                Constants.Menu.history: ["keyCode": 9, "modifiers": 4352]]
    }()

    fileprivate(set) var mainKeyCombo: KeyCombo?
    fileprivate(set) var historyKeyCombo: KeyCombo?
    fileprivate(set) var clearHistoryKeyCombo: KeyCombo?

}

// MARK: - Actions
extension HotKeyService {
    @objc func popupMainMenu() {
        let menuManager = AppEnvironment.current.menuManager
        menuManager.toggleSearchPopoverAtMouseLocation()
    }

    @objc func popupHistoryMenu() {
        AppEnvironment.current.menuManager.popUpMenu(.history)
    }

    @objc func showSearchPopover() {
        let menuManager = AppEnvironment.current.menuManager
        let rect = NSRect(x: NSEvent.mouseLocation.x, y: NSEvent.mouseLocation.y, width: 0, height: 0)
        let view = NSApp.mainWindow?.contentView ?? NSView()
        menuManager.showSearchPopover(relativeTo: rect, of: view)
    }

    @objc func popUpClearHistoryAlert() {
        guard let appDelegate = NSApp.delegate as? AppDelegate else { return }
        appDelegate.clearAllHistory()
    }
}

// MARK: - Setup
extension HotKeyService {
    func setupDefaultHotKeys() {
        // Migration new framework
        if !AppEnvironment.current.defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo) {
            migrationKeyCombos()
            AppEnvironment.current.defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
            AppEnvironment.current.defaults.synchronize()
        }
        // Legacy snippet data
        cleanupLegacySnippetData()

        // Main menu
        change(with: .main, keyCombo: savedKeyCombo(forKey: Constants.HotKey.mainKeyCombo))
        // History menu
        change(with: .history, keyCombo: savedKeyCombo(forKey: Constants.HotKey.historyKeyCombo))
        // Clear History
        changeClearHistoryKeyCombo(savedKeyCombo(forKey: Constants.HotKey.clearHistoryKeyCombo))
    }

    func change(with type: MenuType, keyCombo: KeyCombo?) {
        switch type {
        case .main:
            mainKeyCombo = keyCombo
        case .history:
            historyKeyCombo = keyCombo
        }
        register(with: type, keyCombo: keyCombo)
    }

    func changeClearHistoryKeyCombo(_ keyCombo: KeyCombo?) {
        clearHistoryKeyCombo = keyCombo
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: Constants.HotKey.clearHistoryKeyCombo)
        AppEnvironment.current.defaults.synchronize()
        // Reset hotkey
        HotKeyCenter.shared.unregisterHotKey(with: "ClearHistory")
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        let hotkey = HotKey(identifier: "ClearHistory", keyCombo: keyCombo, target: self, action: #selector(HotKeyService.popUpClearHistoryAlert))
        hotkey.register()
    }

    private func savedKeyCombo(forKey key: String) -> KeyCombo? {
        guard let data = AppEnvironment.current.defaults.object(forKey: key) as? Data else { return nil }
        guard let keyCombo = NSKeyedUnarchiver.unarchiveObject(with: data) as? KeyCombo else { return nil }
        return keyCombo
    }
}

// MARK: - Register
private extension HotKeyService {
    func register(with type: MenuType, keyCombo: KeyCombo?) {
        save(with: type, keyCombo: keyCombo)
        // Reset hotkey
        HotKeyCenter.shared.unregisterHotKey(with: type.rawValue)
        // Register new hotkey
        guard let keyCombo = keyCombo else { return }
        let hotKey = HotKey(identifier: type.rawValue, keyCombo: keyCombo, target: self, action: type.hotKeySelector)
        hotKey.register()
    }

    func save(with type: MenuType, keyCombo: KeyCombo?) {
        AppEnvironment.current.defaults.set(keyCombo?.archive(), forKey: type.userDefaultsKey)
        AppEnvironment.current.defaults.synchronize()
    }
}

// MARK: - Migration
private extension HotKeyService {
    /**
     *  Migration for changing the storage with v1.1.0
     *  Changed framework, PTHotKey to Magnet
     */
    func migrationKeyCombos() {
        guard let keyCombos = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.hotKeys) as? [String: Any] else { return }

        // Main menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.clip) {
            if let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers) {
                AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.mainKeyCombo)
            }
        }
        // History menu
        if let (keyCode, modifiers) = parse(with: keyCombos, forKey: Constants.Menu.history) {
            if let keyCombo = KeyCombo(QWERTYKeyCode: keyCode, carbonModifiers: modifiers) {
                AppEnvironment.current.defaults.set(keyCombo.archive(), forKey: Constants.HotKey.historyKeyCombo)
            }
        }
    }

    func parse(with keyCombos: [String: Any], forKey key: String) -> (Int, Int)? {
        guard let combos = keyCombos[key] as? [String: Any] else { return nil }
        guard let keyCode = combos["keyCode"] as? Int, let modifiers = combos["modifiers"] as? Int else { return nil }
        return (keyCode, modifiers)
    }
}

// MARK: - Legacy Snippet Cleanup
extension HotKeyService {
    /// Snippets have been removed entirely. Hotkeys that were bound to the
    /// snippet menu or snippet folders by older versions are unregistered,
    /// and their saved key combos are dropped on launch.
    func cleanupLegacySnippetData() {
        HotKeyCenter.shared.unregisterHotKey(with: "SnippetMenu")
        HotKeyCenter.shared.unregisterHotKey(with: "SnippetsMenu")
        let defaults = AppEnvironment.current.defaults
        if let data = defaults.object(forKey: Constants.HotKey.folderKeyCombos) as? Data,
           let keyCombos = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: KeyCombo] {
            keyCombos.keys.forEach { HotKeyCenter.shared.unregisterHotKey(with: $0) }
        }
        defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
        defaults.removeObject(forKey: "kCPYHotKeySnippetKeyCombo")
        defaults.synchronize()
    }
}
