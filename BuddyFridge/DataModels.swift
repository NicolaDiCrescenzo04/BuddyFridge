import Foundation
import SwiftData

// 1. Definiamo le posizioni possibili
enum StorageLocation: String, Codable, CaseIterable {
    case fridge = "Frigo"
    case freezer = "Congelatore"
    case pantry = "Dispensa"
}

// 2. Definiamo lo stato del cibo
enum ItemStatus: String, Codable {
    case available = "Disponibile" // È in frigo
    case consumed = "Consumato"    // Mangiato (Yummy!)
    case thrown = "Buttato"        // Scaduto/Andato a male (Sad Buddy)
    case toBuy = "Da Comprare"     // Lista della spesa
}

// 3. IL MODELLO PRINCIPALE: Il cibo vero e proprio
@Model
class FoodItem {
    var name: String
    var emoji: String
    var quantity: Int
    var expiryDate: Date
    var addedDate: Date
    var location: StorageLocation
    var status: ItemStatus
    
    // NUOVO CAMPO: Se è true, Buddy lo suggerisce appena finisce
    var isRecurring: Bool
    
    init(name: String, emoji: String = "🍎", quantity: Int = 1, expiryDate: Date, location: StorageLocation = .fridge, isRecurring: Bool = false) {
        self.name = name
        self.emoji = emoji
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.addedDate = Date()
        self.location = location
        self.status = .available
        self.isRecurring = isRecurring // <--- Aggiunto qui
    }
    
    var isExpired: Bool {
        return expiryDate < Date() && status == .available
    }
}

@Model
class ShoppingItem {
    var name: String
    var isCompleted: Bool // Se è stato spuntato
    var addedDate: Date
    
    init(name: String, isCompleted: Bool = false) {
        self.name = name
        self.isCompleted = isCompleted
        self.addedDate = Date()
    }
}
