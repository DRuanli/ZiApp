//
//  Item.swift
//  ZiApp
//
//  Created by Lê Nguyễn on 16/9/25.
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
