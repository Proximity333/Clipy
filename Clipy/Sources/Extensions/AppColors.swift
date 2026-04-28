import Cocoa

enum AppColors {

    static let clipy = NSColor(name: "clipy") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(red: 0.27, green: 0.58, blue: 0.86, alpha: 1)
            : NSColor(red: 0.165, green: 0.518, blue: 0.824, alpha: 1)
    }

    static let title = NSColor(name: "title") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.85, alpha: 1)
            : NSColor(red: 0.267, green: 0.267, blue: 0.267, alpha: 1)
    }

    static let tabTitle = NSColor(name: "tabTitle") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.55, alpha: 1)
            : NSColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1)
    }

    static let windowBackground = NSColor(name: "windowBackground") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.14, alpha: 1)
            : NSColor(white: 0.99, alpha: 1)
    }

    static let disabledText = NSColor(name: "disabledText") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(white: 0.4, alpha: 1)
            : NSColor.lightGray
    }
}
