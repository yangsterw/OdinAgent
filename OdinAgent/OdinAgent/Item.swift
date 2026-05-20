//
//  Item.swift
//  OdinAgent
//
//  Created by yang on 5/19/26.
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
