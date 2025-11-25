//
//  BuddyFridgeApp.swift
//  BuddyFridge
//
//  Created by Nicola Di Crescenzo on 25/11/25.
//

import SwiftUI
import SwiftData

@main
struct BuddyFridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: FoodItem.self)
    }
}
