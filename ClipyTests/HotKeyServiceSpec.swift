import Quick
import Nimble
import Magnet
import Carbon
@testable import Clipy

class HotKeyServiceSpec: QuickSpec {
    // swiftlint:disable:next function_body_length
    override class func spec() {

        describe("Migrate HotKey") {

            beforeEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.synchronize()
            }

            it("Migrate default settings") {
                let service = HotKeyService()
                expect(service.mainKeyCombo) == nil
                expect(service.historyKeyCombo) == nil

                let defaults = UserDefaults.standard

                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)) == false
                service.setupDefaultHotKeys()
                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)) == true

                expect(service.mainKeyCombo) != nil
                expect(service.mainKeyCombo?.QWERTYKeyCode) == 9
                expect(service.mainKeyCombo?.modifiers) == 768
                expect(service.mainKeyCombo?.doubledModifiers) == false
                expect(service.mainKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(service.historyKeyCombo) != nil
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 9
                expect(service.historyKeyCombo?.modifiers) == 4352
                expect(service.historyKeyCombo?.doubledModifiers) == false
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == "V"
            }

            it("Migrate customize settings") {
                let service = HotKeyService()
                expect(service.mainKeyCombo) == nil
                expect(service.historyKeyCombo) == nil

                let defaults = UserDefaults.standard
                let defaultKeyCombos: [String: Any] = [Constants.Menu.clip: ["keyCode": 0, "modifiers": 4352],
                                                       Constants.Menu.history: ["keyCode": 9, "modifiers": 768]]
                defaults.register(defaults: [Constants.UserDefaults.hotKeys: defaultKeyCombos])
                defaults.synchronize()

                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)) == false
                service.setupDefaultHotKeys()
                expect(defaults.bool(forKey: Constants.HotKey.migrateNewKeyCombo)) == true

                expect(service.mainKeyCombo) != nil
                expect(service.mainKeyCombo?.QWERTYKeyCode) == 0
                expect(service.mainKeyCombo?.modifiers) == 4352
                expect(service.mainKeyCombo?.doubledModifiers) == false
                expect(service.mainKeyCombo?.keyEquivalent.uppercased()) == "A"

                expect(service.historyKeyCombo) != nil
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 9
                expect(service.historyKeyCombo?.modifiers) == 768
                expect(service.historyKeyCombo?.doubledModifiers) == false
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == "V"
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.synchronize()
            }
        }

        describe("Save HotKey") {

            beforeEach {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.synchronize()
            }

            it("Save key combos") {
                let service = HotKeyService()
                expect(service.mainKeyCombo) == nil
                expect(service.historyKeyCombo) == nil

                let defautls = UserDefaults.standard
                expect(defautls.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo)) == nil
                expect(defautls.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)) == nil

                service.setupDefaultHotKeys()
                expect(service.mainKeyCombo) == nil
                expect(service.historyKeyCombo) == nil

                let mainKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
                let historyKeyCombo = KeyCombo(doubledCocoaModifiers: .command)

                service.change(with: .main, keyCombo: mainKeyCombo)
                service.change(with: .history, keyCombo: historyKeyCombo)

                let savedMainKeyCombo = defautls.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo)
                let savedHistoryKeyCombo = defautls.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.historyKeyCombo)

                expect(savedMainKeyCombo) != nil
                expect(savedMainKeyCombo?.QWERTYKeyCode) == 9
                expect(savedMainKeyCombo?.modifiers) == 768
                expect(savedMainKeyCombo?.doubledModifiers) == false
                expect(savedMainKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(savedHistoryKeyCombo) != nil
                expect(savedHistoryKeyCombo?.QWERTYKeyCode) == 0
                expect(savedHistoryKeyCombo?.modifiers) == cmdKey
                expect(savedHistoryKeyCombo?.doubledModifiers) == true
                expect(savedHistoryKeyCombo?.keyEquivalent.uppercased()) == ""

                service.change(with: .main, keyCombo: nil)
                expect(service.mainKeyCombo) == nil
                expect(defautls.archiveDataForKey(KeyCombo.self, key: Constants.HotKey.mainKeyCombo)) == nil
            }

            it("Unarchive saved key combos") {
                let mainKeyCombo = KeyCombo(QWERTYKeyCode: 9, carbonModifiers: 768)
                let historyKeyCombo = KeyCombo(doubledCocoaModifiers: .command)

                let defaults = UserDefaults.standard
                defaults.setArchiveData(mainKeyCombo!, forKey: Constants.HotKey.mainKeyCombo)
                defaults.setArchiveData(historyKeyCombo!, forKey: Constants.HotKey.historyKeyCombo)

                let service = HotKeyService()
                expect(service.mainKeyCombo) == nil
                expect(service.historyKeyCombo) == nil

                service.setupDefaultHotKeys()

                expect(service.mainKeyCombo) != nil
                expect(service.mainKeyCombo?.QWERTYKeyCode) == 9
                expect(service.mainKeyCombo?.modifiers) == 768
                expect(service.mainKeyCombo?.doubledModifiers) == false
                expect(service.mainKeyCombo?.keyEquivalent.uppercased()) == "V"

                expect(service.historyKeyCombo) != nil
                expect(service.historyKeyCombo?.QWERTYKeyCode) == 0
                expect(service.historyKeyCombo?.modifiers) == cmdKey
                expect(service.historyKeyCombo?.doubledModifiers) == true
                expect(service.historyKeyCombo?.keyEquivalent.uppercased()) == ""
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.UserDefaults.hotKeys)
                defaults.removeObject(forKey: Constants.HotKey.migrateNewKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.mainKeyCombo)
                defaults.removeObject(forKey: Constants.HotKey.historyKeyCombo)
                defaults.synchronize()
            }
        }

        describe("Key comobos") {
            it("Default key combos") {
                let keyCombos = HotKeyService.defaultKeyCombos
                let mainCombos = keyCombos[Constants.Menu.clip] as? [String: Int]
                let historyCombos = keyCombos[Constants.Menu.history] as? [String: Int]

                expect(mainCombos?["keyCode"]) == 9
                expect(mainCombos?["modifiers"]) == 768

                expect(historyCombos?["keyCode"]) == 9
                expect(historyCombos?["modifiers"]) == 4352
            }
        }

        describe("Clear History HotKey") {
            beforeEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.HotKey.clearHistoryKeyCombo)
                defaults.synchronize()
            }

            it("Add and remove clear history hokey") {
                let service = HotKeyService()

                expect(service.clearHistoryKeyCombo) == nil

                let keyCombo = KeyCombo(QWERTYKeyCode: 10, carbonModifiers: cmdKey)
                service.changeClearHistoryKeyCombo(keyCombo)

                expect(service.clearHistoryKeyCombo) != nil
                expect(service.clearHistoryKeyCombo) == keyCombo

                let savedData = UserDefaults.standard.object(forKey: Constants.HotKey.clearHistoryKeyCombo) as? Data
                let savedKeyCombo = NSKeyedUnarchiver.unarchiveObject(with: savedData!) as? KeyCombo
                expect(savedKeyCombo) == keyCombo

                service.changeClearHistoryKeyCombo(nil)
                expect(service.clearHistoryKeyCombo) == nil
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.HotKey.clearHistoryKeyCombo)
                defaults.synchronize()
            }
        }

        describe("Legacy snippet data") {
            it("clears folder key combos saved by older versions") {
                let defaults = UserDefaults.standard
                defaults.set(true, forKey: Constants.HotKey.folderKeyCombos)

                HotKeyService().cleanupLegacySnippetData()

                expect(defaults.object(forKey: Constants.HotKey.folderKeyCombos)) == nil
            }

            afterEach {
                let defaults = UserDefaults.standard
                defaults.removeObject(forKey: Constants.HotKey.folderKeyCombos)
                defaults.synchronize()
            }
        }
    }
}
