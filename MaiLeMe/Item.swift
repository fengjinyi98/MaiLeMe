//
//  Item.swift
//  MaiLeMe
//
//  Created by fengjinyi on 2026/2/28.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
