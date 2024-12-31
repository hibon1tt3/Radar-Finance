//
//  Item.swift
//  Radar Finance
//
//  Created by Theodore Tomita III on 12/30/24.
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
