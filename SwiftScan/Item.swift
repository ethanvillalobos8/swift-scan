//
//  Item.swift
//  SwiftScan
//
//  Created by Ethan Villalobos on 10/27/23.
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
