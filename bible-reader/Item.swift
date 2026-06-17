//
//  Item.swift
//  bible-reader
//
//  Created by Corleone on 2026/6/17.
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
