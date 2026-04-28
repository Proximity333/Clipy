import Cocoa

final class ThemeService {

    enum Theme: Int {
        case auto = 0
        case light = 1
        case dark = 2

        var appearance: NSAppearance? {
            switch self {
            case .auto: return nil
            case .light: return NSAppearance(named: .aqua)
            case .dark: return NSAppearance(named: .darkAqua)
            }
        }

        var localizedName: String {
            switch self {
            case .auto: return L10n.auto
            case .light: return L10n.light
            case .dark: return L10n.dark
            }
        }

        static let allCases: [Theme] = [.auto, .light, .dark]
    }

    var current: Theme {
        didSet { apply() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.current = Theme(rawValue: defaults.integer(forKey: Constants.UserDefaults.appearance)) ?? .auto
    }

    func apply() {
        defaults.set(current.rawValue, forKey: Constants.UserDefaults.appearance)
        NSApp.appearance = current.appearance
        NotificationCenter.default.post(name: .themeDidChange, object: nil)
    }

    func start() {
        apply()
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("themeDidChange")
}
