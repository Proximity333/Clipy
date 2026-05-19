//
//  SearchPopoverController.swift
//  Clipy
//
//  Created by AI Assistant on 2026/05/17.
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import PINCache
import RealmSwift

protocol SearchPopoverDelegate: AnyObject {
    func searchPopoverDidSelectResult(_ result: SearchPopoverController.ResultItem)
    func searchPopoverDidCancel()
}

// swiftlint:disable type_body_length file_length
final class SearchPopoverController: NSViewController {
    enum FilterTab: Int, CaseIterable {
        case all
        case history
        case snippets

        var title: String {
            switch self {
            case .all: return "全部"
            case .history: return "粘贴历史"
            case .snippets: return "片段"
            }
        }
    }

    enum ResultItem {
        case clip(CPYClip)
        case snippet(CPYSnippet)
    }

    private struct SearchPalette {
        let chromeBackground: NSColor
        let chromeBorder: NSColor
        let cardBackground: NSColor
        let cardBorder: NSColor
    }

    // MARK: - Properties
    weak var delegate: SearchPopoverDelegate?

    private let clips: [CPYClip]
    private let snippets: [CPYSnippet]
    private var filteredResults: [ResultItem]
    private var activeTab: FilterTab = .all
    private var searchWindow: SearchWindow?
    private var clickMonitor: Any?
    private(set) var previousActiveApp: NSRunningApplication?

    private let searchContainer = NSView()
    private let searchField = NSSearchField()
    private let tabContainer = NSView()
    private let tabSegmentedControl = NSSegmentedControl()
    private let settingsButton = NSButton()
    private let chromeView = NSView()

    private let contentContainer = NSView()
    private let listContainer = NSView()
    private let previewContainer = NSView()
    private let metaContainer = NSView()

    private let listTitleLabel = NSTextField(labelWithString: "")
    private let listActionButton = NSButton()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyStateLabel = NSTextField(labelWithString: "未找到匹配的历史记录")

    private let previewImageView = NSImageView()
    private let previewTextScrollView = NSScrollView()
    private let previewTextView = NSTextView()
    private let previewTitleLabel = NSTextField(labelWithString: "")
    private let previewSubtitleLabel = NSTextField(labelWithString: "")
    private var previewImageHeightConstraint: NSLayoutConstraint?
    private var previewTextTopConstraint: NSLayoutConstraint?
    private var previewTextBottomConstraint: NSLayoutConstraint?

    private let typeKeyLabel = NSTextField(labelWithString: "类型")
    private let typeValueLabel = NSTextField(labelWithString: "-")
    private let sizeKeyLabel = NSTextField(labelWithString: "尺寸")
    private let sizeValueLabel = NSTextField(labelWithString: "-")
    private let quitButton = NSButton()

    // MARK: - Initialization
    init(clips: [CPYClip]) {
        self.clips = clips
        let realm = try! Realm()
        self.snippets = Array(realm.objects(CPYSnippet.self).filter("enable == true").sorted(byKeyPath: #keyPath(CPYSnippet.index), ascending: true))
        self.filteredResults = clips.map(ResultItem.clip) + self.snippets.map(ResultItem.snippet)
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func loadView() {
        let rootView = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 420))
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.clear.cgColor
        view = rootView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = NSSize(width: 640, height: 420)
        setupUI()
        applyTheme()
        NotificationCenter.default.addObserver(self, selector: #selector(handleThemeDidChange), name: .themeDidChange, object: nil)
        reloadResults(keepSelection: false)
        updateListActionButton()
    }

    // MARK: - Setup
    private func setupUI() {
        setupChromeView()
        setupSearchContainer()
        setupContentContainers()
        setupListView()
        setupPreviewView()
        setupMetaView()
        setupConstraints()
    }

    private func setupChromeView() {
        chromeView.wantsLayer = true
        chromeView.layer?.cornerRadius = 18
        chromeView.layer?.masksToBounds = true
        chromeView.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.98).cgColor
        chromeView.layer?.borderWidth = 1
        chromeView.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        chromeView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chromeView)
    }

    private func setupSearchContainer() {
        styleCard(searchContainer, radius: 16)
        searchContainer.translatesAutoresizingMaskIntoConstraints = false
        chromeView.addSubview(searchContainer)

        searchField.placeholderString = "搜索..."
        searchField.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        searchField.sendsSearchStringImmediately = true
        searchField.focusRingType = .none
        searchField.isBordered = false
        searchField.bezelStyle = .roundedBezel
        searchField.drawsBackground = false
        searchField.cell?.usesSingleLineMode = true
        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.searchButtonCell = nil
            cell.cancelButtonCell = nil
        }
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchContainer.addSubview(searchField)

        tabContainer.wantsLayer = true
        tabContainer.layer?.backgroundColor = NSColor.clear.cgColor
        tabContainer.layer?.borderWidth = 0
        tabContainer.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(tabContainer)

        tabSegmentedControl.segmentCount = 3
        FilterTab.allCases.enumerated().forEach { index, tab in
            tabSegmentedControl.setLabel(tab.title, forSegment: index)
        }
        tabSegmentedControl.selectedSegment = FilterTab.all.rawValue
        tabSegmentedControl.segmentStyle = .capsule
        tabSegmentedControl.target = self
        tabSegmentedControl.action = #selector(tabChanged(_:))
        tabSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(tabSegmentedControl)

        settingsButton.bezelStyle = .texturedRounded
        settingsButton.isBordered = false
        if #available(macOS 11.0, *) {
            settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "设置")
        } else {
            settingsButton.image = NSImage(named: NSImage.Name("NSActionTemplate"))
        }
        settingsButton.imagePosition = .imageOnly
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        searchContainer.addSubview(settingsButton)
    }

    private func setupContentContainers() {
        contentContainer.wantsLayer = true
        contentContainer.layer?.backgroundColor = NSColor.clear.cgColor
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        chromeView.addSubview(contentContainer)

        styleCard(listContainer, radius: 16)
        styleCard(previewContainer, radius: 16)
        styleCard(metaContainer, radius: 16)

        [listContainer, previewContainer, metaContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentContainer.addSubview($0)
        }
    }

    private func setupListView() {
        listTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        listTitleLabel.textColor = .secondaryLabelColor
        listTitleLabel.stringValue = FilterTab.history.title
        listTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(listTitleLabel)

        listActionButton.bezelStyle = .texturedRounded
        listActionButton.isBordered = false
        listActionButton.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        listActionButton.target = self
        listActionButton.action = #selector(listActionClicked)
        listActionButton.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(listActionButton)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipColumn"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 36
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.focusRingType = .none
        tableView.allowsEmptySelection = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(tableViewDoubleClicked)

        scrollView.documentView = tableView
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(scrollView)

        emptyStateLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        emptyStateLabel.textColor = .secondaryLabelColor
        emptyStateLabel.alignment = .center
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(emptyStateLabel)
    }

    private func setupPreviewView() {
        previewTitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        previewTitleLabel.textColor = .secondaryLabelColor
        previewTitleLabel.stringValue = "预览"
        previewTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewTitleLabel)

        previewImageView.imageScaling = .scaleProportionallyUpOrDown
        previewImageView.wantsLayer = true
        previewImageView.layer?.cornerRadius = 12
        previewImageView.layer?.masksToBounds = true
        previewImageView.layer?.backgroundColor = NSColor.clear.cgColor
        previewImageView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewImageView)

        previewTextView.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        previewTextView.textColor = .labelColor
        previewTextView.isEditable = false
        previewTextView.isSelectable = false
        previewTextView.isRichText = false
        previewTextView.isVerticallyResizable = true
        previewTextView.isHorizontallyResizable = false
        previewTextView.minSize = NSSize(width: 0, height: 0)
        previewTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        previewTextView.autoresizingMask = [.width]
        previewTextView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        previewTextView.textContainer?.lineBreakMode = .byCharWrapping
        previewTextView.textContainer?.widthTracksTextView = true
        previewTextView.textContainerInset = NSSize(width: 0, height: 2)
        previewTextView.drawsBackground = false

        previewTextScrollView.drawsBackground = false
        previewTextScrollView.borderType = .noBorder
        previewTextScrollView.hasVerticalScroller = true
        previewTextScrollView.hasHorizontalScroller = false
        previewTextScrollView.autohidesScrollers = true
        previewTextScrollView.scrollerStyle = .overlay
        previewTextScrollView.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewTextScrollView)
        previewTextScrollView.documentView = previewTextView

        previewSubtitleLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        previewSubtitleLabel.textColor = .secondaryLabelColor
        previewSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.addSubview(previewSubtitleLabel)
    }

    private func setupMetaView() {
        let labels = [typeKeyLabel, typeValueLabel, sizeKeyLabel, sizeValueLabel]
        labels.forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            metaContainer.addSubview($0)
        }

        [typeKeyLabel, sizeKeyLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 10, weight: .medium)
            $0.textColor = .secondaryLabelColor
        }

        [typeValueLabel, sizeValueLabel].forEach {
            $0.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            $0.textColor = .labelColor
        }

        quitButton.bezelStyle = .texturedRounded
        quitButton.isBordered = false
        if #available(macOS 11.0, *) {
            quitButton.image = NSImage(systemSymbolName: "power", accessibilityDescription: "退出")
        } else {
            quitButton.image = NSImage(named: NSImage.stopProgressTemplateName)
        }
        quitButton.imagePosition = .imageOnly
        quitButton.target = self
        quitButton.action = #selector(quitApplication)
        quitButton.translatesAutoresizingMaskIntoConstraints = false
        metaContainer.addSubview(quitButton)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            chromeView.topAnchor.constraint(equalTo: view.topAnchor),
            chromeView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chromeView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chromeView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            searchContainer.topAnchor.constraint(equalTo: chromeView.topAnchor, constant: 14),
            searchContainer.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 14),
            searchContainer.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor, constant: -14),
            searchContainer.heightAnchor.constraint(equalToConstant: 36),

            searchField.leadingAnchor.constraint(equalTo: searchContainer.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: -10),
            searchField.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),

            tabContainer.trailingAnchor.constraint(equalTo: settingsButton.leadingAnchor, constant: -6),
            tabContainer.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            tabContainer.widthAnchor.constraint(equalToConstant: 250),
            tabContainer.heightAnchor.constraint(equalToConstant: 28),

            tabSegmentedControl.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor, constant: 6),
            tabSegmentedControl.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor, constant: -6),
            tabSegmentedControl.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),

            settingsButton.trailingAnchor.constraint(equalTo: searchContainer.trailingAnchor, constant: -10),
            settingsButton.centerYAnchor.constraint(equalTo: searchContainer.centerYAnchor),
            settingsButton.widthAnchor.constraint(equalToConstant: 24),
            settingsButton.heightAnchor.constraint(equalToConstant: 24),

            contentContainer.topAnchor.constraint(equalTo: searchContainer.bottomAnchor, constant: 12),
            contentContainer.leadingAnchor.constraint(equalTo: chromeView.leadingAnchor, constant: 14),
            contentContainer.trailingAnchor.constraint(equalTo: chromeView.trailingAnchor, constant: -14),
            contentContainer.bottomAnchor.constraint(equalTo: chromeView.bottomAnchor, constant: -14),

            listContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            listContainer.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            listContainer.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            listContainer.widthAnchor.constraint(equalToConstant: 220),

            previewContainer.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            previewContainer.leadingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: 10),
            previewContainer.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            previewContainer.heightAnchor.constraint(equalToConstant: 288),

            metaContainer.topAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: 6),
            metaContainer.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor),
            metaContainer.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor),
            metaContainer.heightAnchor.constraint(equalToConstant: 52),
            metaContainer.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),

            listTitleLabel.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 10),
            listTitleLabel.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 16),
            listTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: listActionButton.leadingAnchor, constant: -8),

            listActionButton.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -12),
            listActionButton.centerYAnchor.constraint(equalTo: listTitleLabel.centerYAnchor),

            scrollView.topAnchor.constraint(equalTo: listTitleLabel.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 4),
            scrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -4),
            scrollView.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -8),

            emptyStateLabel.centerXAnchor.constraint(equalTo: listContainer.centerXAnchor),
            emptyStateLabel.centerYAnchor.constraint(equalTo: listContainer.centerYAnchor),

            previewTitleLabel.topAnchor.constraint(equalTo: previewContainer.topAnchor, constant: 10),
            previewTitleLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            previewTitleLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),

            previewImageView.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 8),
            previewImageView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 12),
            previewImageView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -12),
            {
                let constraint = previewImageView.heightAnchor.constraint(equalToConstant: 140)
                self.previewImageHeightConstraint = constraint
                return constraint
            }(),

            {
                let constraint = previewTextScrollView.topAnchor.constraint(equalTo: previewTitleLabel.bottomAnchor, constant: 12)
                self.previewTextTopConstraint = constraint
                return constraint
            }(),
            previewTextScrollView.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            previewTextScrollView.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            {
                let constraint = previewTextScrollView.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10)
                self.previewTextBottomConstraint = constraint
                return constraint
            }(),

            previewSubtitleLabel.leadingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: 14),
            previewSubtitleLabel.trailingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: -14),
            previewSubtitleLabel.bottomAnchor.constraint(equalTo: previewContainer.bottomAnchor, constant: -10),

            typeKeyLabel.topAnchor.constraint(equalTo: metaContainer.topAnchor, constant: 8),
            typeKeyLabel.leadingAnchor.constraint(equalTo: metaContainer.leadingAnchor, constant: 14),
            typeValueLabel.topAnchor.constraint(equalTo: typeKeyLabel.bottomAnchor, constant: 1),
            typeValueLabel.leadingAnchor.constraint(equalTo: typeKeyLabel.leadingAnchor),

            sizeKeyLabel.topAnchor.constraint(equalTo: metaContainer.topAnchor, constant: 8),
            sizeKeyLabel.leadingAnchor.constraint(equalTo: metaContainer.leadingAnchor, constant: 170),
            sizeValueLabel.topAnchor.constraint(equalTo: sizeKeyLabel.bottomAnchor, constant: 1),
            sizeValueLabel.leadingAnchor.constraint(equalTo: sizeKeyLabel.leadingAnchor),

            quitButton.centerYAnchor.constraint(equalTo: metaContainer.centerYAnchor),
            quitButton.trailingAnchor.constraint(equalTo: metaContainer.trailingAnchor, constant: -12),
            quitButton.widthAnchor.constraint(equalToConstant: 24),
            quitButton.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - Public Methods
    func show(at location: NSPoint) {
        previousActiveApp = NSWorkspace.shared.frontmostApplication

        let windowWidth: CGFloat = 640
        let windowHeight: CGFloat = 420
        let screen = NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? .zero

        var originX = location.x
        var originY = location.y - windowHeight

        if originX + windowWidth > visibleFrame.maxX {
            originX = visibleFrame.maxX - windowWidth
        }
        if originX < visibleFrame.minX {
            originX = visibleFrame.minX
        }
        if originY < visibleFrame.minY {
            originY = visibleFrame.minY
        }
        if originY + windowHeight > visibleFrame.maxY {
            originY = visibleFrame.maxY - windowHeight
        }

        searchWindow = SearchWindow(contentRect: NSRect(x: originX, y: originY, width: windowWidth, height: windowHeight), contentViewController: self)
        searchWindow?.preferredFirstResponder = searchField
        searchWindow?.onEscape = { [weak self] in
            self?.delegate?.searchPopoverDidCancel()
            self?.close()
        }
        searchWindow?.onTabNavigation = { [weak self] movesForward in
            self?.selectAdjacentTab(movingForward: movesForward)
        }
        searchWindow?.delegate = self
        NSApp.activate(ignoringOtherApps: true)
        searchWindow?.makeKeyAndOrderFront(nil)

        setupClickOutsideMonitor()

        DispatchQueue.main.async { [weak self] in
            self?.searchField.window?.makeFirstResponder(self?.searchField)
        }
    }

    func close() {
        removeClickMonitor()
        searchWindow?.close()
        searchWindow = nil
    }

    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let window = self.searchWindow else { return }
            let location = NSEvent.mouseLocation
            if !window.frame.contains(location) {
                self.delegate?.searchPopoverDidCancel()
                self.close()
            }
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    // MARK: - Private Helpers
    private func styleCard(_ view: NSView, radius: CGFloat) {
        view.wantsLayer = true
        view.layer?.cornerRadius = radius
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 1
    }

    @objc private func handleThemeDidChange() {
        applyTheme()
        tableView.reloadData()
    }

    private func applyTheme() {
        let palette = currentPalette
        chromeView.layer?.backgroundColor = palette.chromeBackground.cgColor
        chromeView.layer?.borderColor = palette.chromeBorder.cgColor

        [searchContainer, listContainer, previewContainer, metaContainer].forEach {
            $0.layer?.backgroundColor = palette.cardBackground.cgColor
            $0.layer?.borderColor = palette.cardBorder.cgColor
        }

        tabContainer.layer?.backgroundColor = NSColor.clear.cgColor
        tabContainer.layer?.borderColor = NSColor.clear.cgColor
    }

    private var currentPalette: SearchPalette {
        if isDarkMode {
            return SearchPalette(
                chromeBackground: NSColor(calibratedWhite: 0.15, alpha: 0.98),
                chromeBorder: NSColor.white.withAlphaComponent(0.14),
                cardBackground: NSColor(calibratedWhite: 0.12, alpha: 0.92),
                cardBorder: NSColor.white.withAlphaComponent(0.08)
            )
        }

        return SearchPalette(
            chromeBackground: NSColor(calibratedRed: 0.93, green: 0.94, blue: 0.96, alpha: 0.98),
            chromeBorder: NSColor(calibratedWhite: 0.70, alpha: 0.95),
            cardBackground: NSColor(calibratedRed: 0.98, green: 0.98, blue: 0.99, alpha: 0.98),
            cardBorder: NSColor(calibratedWhite: 0.80, alpha: 0.95)
        )
    }

    private var isDarkMode: Bool {
        view.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private func reloadResults(keepSelection: Bool) {
        let selectedIdentifier = keepSelection ? selectedResultIdentifier() : nil
        tableView.reloadData()
        emptyStateLabel.isHidden = !filteredResults.isEmpty
        listTitleLabel.stringValue = activeTab == .all ? "全部结果" : activeTab.title

        if filteredResults.isEmpty {
            renderPreview(for: nil)
            return
        }

        if let selectedIdentifier,
           let index = filteredResults.firstIndex(where: { resultIdentifier(for: $0) == selectedIdentifier }) {
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }

        updatePreviewFromSelection()
    }

    private func selectedResult() -> ResultItem? {
        let row = tableView.selectedRow
        guard row >= 0, row < filteredResults.count else { return nil }
        return filteredResults[row]
    }

    private func filter(with searchText: String) {
        filteredResults = results(for: activeTab, searchText: searchText)
        reloadResults(keepSelection: true)
    }

    private func results(for tab: FilterTab, searchText: String) -> [ResultItem] {
        let normalized = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        func matches(_ value: String) -> Bool {
            normalized.isEmpty || value.localizedCaseInsensitiveContains(normalized)
        }

        let historyResults = clips
            .filter { matches($0.title) }
            .map(ResultItem.clip)
        let snippetResults = snippets
            .filter { matches($0.title) || matches($0.content) }
            .map(ResultItem.snippet)

        switch tab {
        case .all:
            return historyResults + snippetResults
        case .history:
            return historyResults
        case .snippets:
            return snippetResults
        }
    }

    private func selectedResultIdentifier() -> String? {
        selectedResult().map(resultIdentifier(for:))
    }

    private func resultIdentifier(for result: ResultItem) -> String {
        switch result {
        case let .clip(clip): return "clip:\(clip.dataHash)"
        case let .snippet(snippet): return "snippet:\(snippet.identifier)"
        }
    }

    private func loadClipData(for clip: CPYClip) -> CPYClipData? {
        guard !clip.dataPath.isEmpty else { return nil }
        return NSKeyedUnarchiver.unarchiveObject(withFile: clip.dataPath) as? CPYClipData
    }

    private func updatePreviewFromSelection() {
        guard let result = selectedResult() else {
            renderPreview(for: nil)
            return
        }
        renderPreview(for: result)
    }

    private func renderPreview(for result: ResultItem?) {
        guard let result else {
            previewImageView.isHidden = true
            previewTextScrollView.isHidden = false
            previewTextView.string = "选择一项查看预览"
            previewSubtitleLabel.stringValue = ""
            typeValueLabel.stringValue = "-"
            sizeValueLabel.stringValue = "-"
            return
        }

        switch result {
        case let .clip(clip):
            renderClipPreview(for: clip, data: loadClipData(for: clip))
        case let .snippet(snippet):
            renderSnippetPreview(for: snippet)
        }
    }

    private func renderClipPreview(for clip: CPYClip, data: CPYClipData?) {
        guard let data else {
            renderPreview(for: nil)
            return
        }

        let previewImage = previewImage(for: clip, data: data)
        previewImageView.image = previewImage
        previewImageView.isHidden = previewImage == nil
        previewImageHeightConstraint?.constant = previewImage == nil ? 0 : 140

        let previewText = previewText(for: data, image: previewImage)
        previewTextView.string = previewText
        previewTextScrollView.isHidden = previewImage != nil && previewText.isEmpty
        previewTextScrollView.hasVerticalScroller = true
        previewTextScrollView.contentView.scroll(to: .zero)
        previewTextScrollView.reflectScrolledClipView(previewTextScrollView.contentView)
        previewTextTopConstraint?.constant = previewImage == nil ? 8 : 12
        previewTextBottomConstraint?.constant = -10

        previewSubtitleLabel.stringValue = ""
        previewSubtitleLabel.isHidden = true
        typeValueLabel.stringValue = typeLabel(for: data)
        sizeValueLabel.stringValue = previewSizeText(for: data, image: previewImage)
    }

    private func renderSnippetPreview(for snippet: CPYSnippet) {
        previewImageView.image = nil
        previewImageView.isHidden = true
        previewImageHeightConstraint?.constant = 0
        previewTextScrollView.isHidden = false
        previewTextView.string = snippet.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "空片段" : snippet.content
        previewTextScrollView.contentView.scroll(to: .zero)
        previewTextScrollView.reflectScrolledClipView(previewTextScrollView.contentView)
        previewTextTopConstraint?.constant = 8
        previewTextBottomConstraint?.constant = -10
        previewSubtitleLabel.stringValue = snippet.folder?.title ?? ""
        previewSubtitleLabel.isHidden = previewSubtitleLabel.stringValue.isEmpty
        typeValueLabel.stringValue = "片段"
        sizeValueLabel.stringValue = "\(snippet.content.count) 字符"
    }

    private func previewImage(for clip: CPYClip, data: CPYClipData) -> NSImage? {
        if let image = PINCache.shared.object(forKey: clip.thumbnailPath) as? NSImage {
            return image
        }

        if let thumbnail = data.thumbnailImage {
            if !clip.thumbnailPath.isEmpty {
                PINCache.shared.setObject(thumbnail, forKey: clip.thumbnailPath)
            }
            return thumbnail
        }

        return data.colorCodeImage
    }

    private func previewText(for data: CPYClipData, image: NSImage?) -> String {
        if image != nil, let fileName = data.fileNames.first {
            let pathExtension = URL(fileURLWithPath: fileName).pathExtension.lowercased()
            let imageFileExtensions = ["jpg", "jpeg", "png", "bmp", "tiff"]
            if imageFileExtensions.contains(pathExtension) {
                return ""
            }
        }

        if !data.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return data.stringValue
        }
        if let fileName = data.fileNames.first {
            return fileName
        }
        if let url = data.URLs.first {
            return url
        }
        if data.PDF != nil {
            return "PDF 内容"
        }
        if data.image != nil || data.thumbnailImage != nil || data.colorCodeImage != nil {
            return ""
        }
        return "无可预览内容"
    }

    private func typeLabel(for data: CPYClipData) -> String {
        if data.image != nil || data.thumbnailImage != nil {
            return "图片"
        }
        if !data.fileNames.isEmpty {
            return "文件"
        }
        if !data.URLs.isEmpty {
            return "链接"
        }
        if data.PDF != nil {
            return "PDF"
        }
        return "文本"
    }

    private func previewSizeText(for data: CPYClipData, image: NSImage?) -> String {
        if let image {
            let size = image.size
            return "\(Int(size.width)) x \(Int(size.height))"
        }
        if let fileName = data.fileNames.first,
           let attributes = try? FileManager.default.attributesOfItem(atPath: fileName),
           let fileSize = attributes[.size] as? NSNumber {
            return ByteCountFormatter.string(fromByteCount: fileSize.int64Value, countStyle: .file)
        }
        return "-"
    }

    @objc private func tableViewDoubleClicked() {
        guard let result = selectedResult() else { return }
        delegate?.searchPopoverDidSelectResult(result)
        close()
    }

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        guard let tab = FilterTab(rawValue: sender.selectedSegment) else { return }
        activeTab = tab
        filter(with: searchField.stringValue)
        updateListActionButton()
    }

    private func selectAdjacentTab(movingForward: Bool) {
        let allTabs = FilterTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: activeTab) else { return }

        let nextIndex: Int
        if movingForward {
            nextIndex = (currentIndex + 1) % allTabs.count
        } else {
            nextIndex = (currentIndex - 1 + allTabs.count) % allTabs.count
        }

        tabSegmentedControl.selectedSegment = allTabs[nextIndex].rawValue
        tabChanged(tabSegmentedControl)
    }

    @objc private func openSettings() {
        delegate?.searchPopoverDidCancel()
        close()
        NSApp.activate(ignoringOtherApps: true)
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.showPreferenceWindow()
        }
    }

    @objc private func quitApplication() {
        delegate?.searchPopoverDidCancel()
        close()
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.terminate()
        } else {
            NSApp.terminate(nil)
        }
    }

    private func updateListActionButton() {
        switch activeTab {
        case .history:
            listActionButton.title = "清空"
            listActionButton.isHidden = false
        case .snippets:
            listActionButton.title = "编辑"
            listActionButton.isHidden = false
        case .all:
            listActionButton.isHidden = true
        }
    }

    @objc private func listActionClicked() {
        switch activeTab {
        case .history:
            delegate?.searchPopoverDidCancel()
            close()
            NSApp.activate(ignoringOtherApps: true)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.clearAllHistory()
            }
        case .snippets:
            delegate?.searchPopoverDidCancel()
            close()
            NSApp.activate(ignoringOtherApps: true)
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showSnippetEditorWindow()
            }
        case .all:
            break
        }
    }
}
// swiftlint:enable type_body_length

// MARK: - NSSearchFieldDelegate
extension SearchPopoverController: NSSearchFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        filter(with: searchField.stringValue)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(cancelOperation(_:)) {
            delegate?.searchPopoverDidCancel()
            close()
            return true
        }

        if commandSelector == #selector(insertNewline(_:)) {
            guard let result = selectedResult() else { return true }
            delegate?.searchPopoverDidSelectResult(result)
            close()
            return true
        }

        if commandSelector == #selector(insertTab(_:)) {
            selectAdjacentTab(movingForward: true)
            return true
        }

        if commandSelector == #selector(insertBacktab(_:)) {
            selectAdjacentTab(movingForward: false)
            return true
        }

        if commandSelector == #selector(moveDown(_:)) {
            let nextRow = min(tableView.selectedRow + 1, filteredResults.count - 1)
            if nextRow >= 0, !filteredResults.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: nextRow), byExtendingSelection: false)
                tableView.scrollRowToVisible(nextRow)
                updatePreviewFromSelection()
            }
            return true
        }

        if commandSelector == #selector(moveUp(_:)) {
            let previousRow = max(tableView.selectedRow - 1, 0)
            if previousRow >= 0, !filteredResults.isEmpty {
                tableView.selectRowIndexes(IndexSet(integer: previousRow), byExtendingSelection: false)
                tableView.scrollRowToVisible(previousRow)
                updatePreviewFromSelection()
            }
            return true
        }

        return false
    }
}

// MARK: - NSTableViewDataSource
extension SearchPopoverController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredResults.count
    }
}

// MARK: - NSTableViewDelegate
extension SearchPopoverController: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredResults.count else { return nil }

        let result = filteredResults[row]
        let cellIdentifier = NSUserInterfaceItemIdentifier("ClipCell")

        let cell: SearchResultCellView
        if let reusedCell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? SearchResultCellView {
            cell = reusedCell
        } else {
            cell = SearchResultCellView()
            cell.identifier = cellIdentifier
        }

        let title: String
        let image: NSImage?
        switch result {
        case let .clip(clip):
            let data = loadClipData(for: clip)
            let rawTitle = data?.titleText ?? clip.title
            title = rawTitle.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            image = previewImage(for: clip, data: data ?? CPYClipData(image: NSImage(size: .zero)))
        case let .snippet(snippet):
            let rawTitle = snippet.title.isEmpty ? snippet.content : snippet.title
            title = rawTitle.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            image = nil
        }
        cell.configure(title: title, image: image)

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updatePreviewFromSelection()
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        SearchResultRowView()
    }
}

// MARK: - NSWindowDelegate
extension SearchPopoverController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        removeClickMonitor()
        searchWindow = nil
    }
}

// MARK: - SearchWindow
private final class SearchWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    weak var preferredFirstResponder: NSResponder?
    var onEscape: (() -> Void)?
    var onTabNavigation: ((Bool) -> Void)?

    init(contentRect: NSRect, contentViewController: NSViewController) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.contentViewController = contentViewController
        self.isReleasedWhenClosed = false
        self.level = .floating
        self.isMovableByWindowBackground = true
        self.hasShadow = true
        self.isOpaque = false
        self.backgroundColor = .clear
        self.collectionBehavior = [.transient, .ignoresCycle]

        contentView?.wantsLayer = true
        contentView?.layer?.cornerRadius = 18
        contentView?.layer?.masksToBounds = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor

        contentView?.superview?.wantsLayer = true
        contentView?.superview?.layer?.cornerRadius = 18
        contentView?.superview?.layer?.masksToBounds = true
        contentView?.superview?.layer?.backgroundColor = NSColor.clear.cgColor
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape?()
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == 48 {
            let movesForward = !event.modifierFlags.contains(.shift)
            onTabNavigation?(movesForward)
            return
        }

        super.sendEvent(event)

        if event.type == .leftMouseDown || event.type == .rightMouseDown {
            restorePreferredFirstResponder()
        }
    }

    private func restorePreferredFirstResponder() {
        guard isKeyWindow,
              let preferredFirstResponder,
              firstResponder !== preferredFirstResponder,
              fieldEditor(false, for: preferredFirstResponder) !== firstResponder else {
            return
        }

        DispatchQueue.main.async { [weak self, weak preferredFirstResponder] in
            guard let self, self.isKeyWindow, let preferredFirstResponder else { return }
            self.makeFirstResponder(preferredFirstResponder)
        }
    }
}

private final class SearchResultRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { true }
        set { }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 6, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        let isDarkMode = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let selectionColor = isDarkMode
            ? NSColor(calibratedRed: 0.20, green: 0.40, blue: 0.73, alpha: 1.0)
            : NSColor(calibratedRed: 0.27, green: 0.52, blue: 0.90, alpha: 1.0)
        selectionColor.setFill()
        path.fill()
    }

    override func drawBackground(in dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()
    }
}

private final class SearchResultCellView: NSTableCellView {
    private let thumbnailView = NSImageView()
    private let titleField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        thumbnailView.imageScaling = .scaleProportionallyUpOrDown
        thumbnailView.wantsLayer = true
        thumbnailView.layer?.cornerRadius = 6
        thumbnailView.layer?.masksToBounds = true
        addSubview(thumbnailView)

        titleField.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleField.textColor = .labelColor
        titleField.lineBreakMode = .byTruncatingTail
        titleField.maximumNumberOfLines = 1
        titleField.cell?.usesSingleLineMode = true
        titleField.cell?.wraps = false
        titleField.cell?.lineBreakMode = .byTruncatingTail
        titleField.isEditable = false
        titleField.isSelectable = false
        addSubview(titleField)

        textField = titleField
        imageView = thumbnailView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, image: NSImage?) {
        titleField.stringValue = title
        thumbnailView.image = image
        thumbnailView.isHidden = image == nil
        needsLayout = true
    }

    override func layout() {
        super.layout()

        let bounds = self.bounds.insetBy(dx: 0, dy: 0)
        let imageSize: CGFloat = thumbnailView.isHidden ? 0 : 20
        let imageSpacing: CGFloat = thumbnailView.isHidden ? 0 : 6
        let textX = bounds.minX + imageSize + imageSpacing
        let textWidth = max(0, bounds.width - imageSize - imageSpacing)

        thumbnailView.frame = NSRect(
            x: bounds.minX,
            y: floor((bounds.height - 20) / 2),
            width: imageSize,
            height: 20
        )

        titleField.frame = NSRect(
            x: textX,
            y: floor((bounds.height - 16) / 2),
            width: textWidth,
            height: 16
        )
    }
}
