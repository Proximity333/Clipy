import Cocoa

final class CPYGeneralPreferenceViewController: NSViewController {

    @IBOutlet private var themePopup: NSPopUpButton!
    @IBOutlet private var statusBarIconPopup: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupThemePopup()
        setupStatusBarIconPopup()
    }

    private func setupThemePopup() {
        guard let popup = themePopup else { return }
        popup.removeAllItems()
        popup.addItems(withTitles: ThemeService.Theme.allCases.map { $0.localizedName })
        let currentTheme = AppEnvironment.current.themeService.current
        popup.selectItem(at: currentTheme.rawValue)
        popup.target = self
        popup.action = #selector(themeChanged(_:))
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let theme = ThemeService.Theme(rawValue: sender.indexOfSelectedItem) else { return }
        AppEnvironment.current.themeService.current = theme
    }

    private func setupStatusBarIconPopup() {
        guard let popup = statusBarIconPopup else { return }
        popup.selectItem(withTag: AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.showStatusItem))
        popup.target = self
        popup.action = #selector(statusBarIconChanged(_:))
    }

    @objc private func statusBarIconChanged(_ sender: NSPopUpButton) {
        let selectedTag = sender.selectedTag()
        let previousTag = AppEnvironment.current.defaults.integer(forKey: Constants.UserDefaults.showStatusItem)

        guard selectedTag != MenuManager.StatusType.none.rawValue else {
            let alert = NSAlert()
            alert.messageText = "Hide status bar icon?"
            alert.informativeText = "Clipy will stay available from the Dock while the status bar icon is hidden, so you can open Preferences and turn it back on later."
            alert.addButton(withTitle: "Hide")
            alert.addButton(withTitle: "Cancel")
            NSApp.activate(ignoringOtherApps: true)

            guard alert.runModal() == .alertFirstButtonReturn else {
                sender.selectItem(withTag: previousTag)
                return
            }

            saveStatusBarIconSelection(selectedTag)
            return
        }

        saveStatusBarIconSelection(selectedTag)
    }

    private func saveStatusBarIconSelection(_ tag: Int) {
        AppEnvironment.current.defaults.set(tag, forKey: Constants.UserDefaults.showStatusItem)
        AppEnvironment.current.defaults.synchronize()
    }
}
