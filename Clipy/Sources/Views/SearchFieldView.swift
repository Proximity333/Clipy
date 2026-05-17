//
//  SearchFieldView.swift
//  Clipy
//
//  Created by AI Assistant on 2026/05/17.
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class SearchFieldView: NSView {
    
    // MARK: - Properties
    let searchTextField: SearchTextField
    private let searchIcon: NSImageView
    
    // MARK: - Initialization
    override init(frame frameRect: NSRect) {
        searchTextField = SearchTextField(frame: .zero)
        searchIcon = NSImageView(frame: .zero)
        super.init(frame: frameRect)
        setup()
    }
    
    required init?(coder: NSCoder) {
        searchTextField = SearchTextField(frame: .zero)
        searchIcon = NSImageView(frame: .zero)
        super.init(coder: coder)
        setup()
    }
    
    // MARK: - Setup
    private func setup() {
        // Configure search icon
        searchIcon.image = NSImage(named: NSImage.touchBarSearchTemplateName)
        searchIcon.imageScaling = .scaleProportionallyDown
        searchIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // Configure search text field
        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Add subviews
        addSubview(searchIcon)
        addSubview(searchTextField)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Search icon constraints
            searchIcon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            searchIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchIcon.widthAnchor.constraint(equalToConstant: 14),
            searchIcon.heightAnchor.constraint(equalToConstant: 14),
            
            // Search text field constraints
            searchTextField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 6),
            searchTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            searchTextField.centerYAnchor.constraint(equalTo: centerYAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        // Transparent background - no layer styling
        wantsLayer = false
    }
}