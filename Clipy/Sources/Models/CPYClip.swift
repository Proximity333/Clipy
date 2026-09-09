//
//  CPYClip.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2015/06/21.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import RealmSwift

final class CPYClip: Object {

    // MARK: - Properties
    @objc dynamic var dataPath = ""
    @objc dynamic var title = ""
    @objc dynamic var dataHash = ""
    @objc dynamic var primaryType = ""
    @objc dynamic var updateTime = 0
    @objc dynamic var thumbnailPath = ""
    @objc dynamic var isColorCode = false
    @objc dynamic var sourceBundleIdentifier = ""
    @objc dynamic var sourceAppName = ""
    @objc dynamic var isFavorite = false

    // MARK: Primary Key
    override static func primaryKey() -> String? {
        return "dataHash"
    }

}
