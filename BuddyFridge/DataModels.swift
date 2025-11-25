import Foundation
import SwiftData

// 1. Definiamo le posizioni
enum StorageLocation: String, Codable, CaseIterable {
    case fridge = "Frigo"
    case freezer = "Congelatore"
    case pantry = "Dispensa"
}

// 2. Definiamo le unità di misura
enum MeasureUnit: String, Codable, CaseIterable {
    case pieces = "Pezzi"
    case grams = "g"
    case kilograms = "kg"
    case liters = "L"
    case milliliters = "ml"
}

enum ItemStatus: String, Codable {
    case available = "Disponibile"
    case consumed = "Consumato"
    case thrown = "Buttato"
    case toBuy = "Da Comprare"
}

// 3. IL MODELLO CIBO
@Model
class FoodItem {
    var name: String
    var emoji: String
    var quantity: Int      // Es. 2 (pacchi)
    var expiryDate: Date
    var addedDate: Date
    var location: StorageLocation
    var status: ItemStatus
    var isRecurring: Bool
    
    // NUOVI CAMPI PER IL PESO/VOLUME
    var measureValue: Double // Es. 500 (grammi)
    var measureUnit: MeasureUnit // Es. .grams
    
    init(name: String,
         emoji: String = "🍎",
         quantity: Int = 1,
         expiryDate: Date,
         location: StorageLocation = .fridge,
         isRecurring: Bool = false,
         measureValue: Double = 0,    // Default 0 se sono "Pezzi" semplici
         measureUnit: MeasureUnit = .pieces) {
        
        self.name = name
        self.emoji = emoji
        self.quantity = quantity
        self.expiryDate = expiryDate
        self.addedDate = Date()
        self.location = location
        self.status = .available
        self.isRecurring = isRecurring
        self.measureValue = measureValue
        self.measureUnit = measureUnit
    }
    
    var isExpired: Bool {
        return expiryDate < Date() && status == .available
    }
    
    // Funzione helper per scrivere "500g" o nascondere se è solo "Pezzi"
    var formattedMeasure: String {
        if measureUnit == .pieces {
            return "" // Non scriviamo nulla se sono pezzi generici
        } else {
            // Rimuoviamo gli zeri decimali inutili (es. 1.0 kg -> 1 kg)
            let valueString = String(format: "%g", measureValue)
            return "\(valueString) \(measureUnit.rawValue)"
        }
    }
}

// 4. LA LISTA SPESA (Invariata per ora)
@Model
class ShoppingItem {
    var name: String
    var isCompleted: Bool
    var addedDate: Date
    
    init(name: String, isCompleted: Bool = false) {
        self.name = name
        self.isCompleted = isCompleted
        self.addedDate = Date()
    }
}
