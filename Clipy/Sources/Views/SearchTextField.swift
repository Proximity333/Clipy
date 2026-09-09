//
//  SearchTextField.swift
//  Clipy
//
//  Created by AI Assistant on 2026/05/17.
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

protocol SearchTextFieldDelegate: AnyObject {
    func searchTextFieldDidReceiveEscape(_ textField: SearchTextField)
    func searchTextFieldDidReceiveEnter(_ textField: SearchTextField)
    func searchTextFieldDidReceiveUpArrow(_ textField: SearchTextField)
    func searchTextFieldDidReceiveDownArrow(_ textField: SearchTextField)
}

final class SearchTextField: NSTextField {

    // MARK: - Properties
    weak var searchDelegate: SearchTextFieldDelegate?

    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    // MARK: - Setup
    private func setup() {
        placeholderString = "搜索粘贴历史..."
        font = NSFont.systemFont(ofSize: 13)
        isBordered = false
        isEditable = true
        isSelectable = true
        drawsBackground = false
        focusRingType = .none
        // Ensure no background
        backgroundColor = .clear
        // Allow input method
        allowsEditingTextAttributes = false
    }

    // MARK: - Key Event Handling
    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        switch keyCode {
        case 53: // Escape
            searchDelegate?.searchTextFieldDidReceiveEscape(self)
        case 36: // Enter
            searchDelegate?.searchTextFieldDidReceiveEnter(self)
        case 126: // Up Arrow
            searchDelegate?.searchTextFieldDidReceiveUpArrow(self)
        case 125: // Down Arrow
            searchDelegate?.searchTextFieldDidReceiveDownArrow(self)
        default:
            super.keyDown(with: event)
        }
    }
}
