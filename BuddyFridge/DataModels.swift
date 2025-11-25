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
    var emoji: String // L'icona del cibo (es. 🥛)
    var quantity: Int
    var expiryDate: Date
    var addedDate: Date
    var location: StorageLocation
    var status: ItemStatus
    
    // Inizializzatore (Come si crea un nuovo oggetto)
    init(name: String, emoji: String = "🍎", quantity: Int = 1, expiryDate: Date, location: StorageLocation = .fridge) {
        self.name = name
        self.emoji = emoji
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.addedDate = Date() // Imposta la data di oggi automaticamente
        self.location = location
        self.status = .available
    }
    
    // Una funzione utile per capire se è scaduto
    var isExpired: Bool {
        return expiryDate < Date() && status == .available
    }
}
