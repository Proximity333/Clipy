import Cocoa

final class CPYGeneralPreferenceViewController: NSViewController {

    @IBOutlet private var themePopup: NSPopUpButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupThemePopup()
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
}
