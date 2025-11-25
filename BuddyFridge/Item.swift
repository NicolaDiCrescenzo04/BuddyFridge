//
//  Item.swift
//  BuddyFridge
//
//  Created by Nicola Di Crescenzo on 25/11/25.
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
