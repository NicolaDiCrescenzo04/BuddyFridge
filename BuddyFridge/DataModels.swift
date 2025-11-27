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

@Model
class FoodItem: Identifiable {
    @Attribute(.unique) var id: UUID
    
    var name: String
    var emoji: String
    var quantity: Int
    var expiryDate: Date
    var addedDate: Date
    var location: StorageLocation
    var status: ItemStatus
    var isRecurring: Bool
    
    var measureValue: Double
    var measureUnit: MeasureUnit
    
    // NUOVO: Flag per sapere se la confezione è aperta
    var isOpened: Bool
    
    init(name: String,
         emoji: String = "🍎",
         quantity: Int = 1,
         expiryDate: Date,
         location: StorageLocation = .fridge,
         isRecurring: Bool = false,
         measureValue: Double = 0,
         measureUnit: MeasureUnit = .pieces,
         isOpened: Bool = false, // Default chiuso
         id: UUID = UUID()) {
        
        self.id = id
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
        self.isOpened = isOpened
    }
    
    var isExpired: Bool {
        return expiryDate < Date() && status == .available
    }
    
    var formattedMeasure: String {
        if measureUnit == .pieces {
            return ""
        } else {
            let valueString = String(format: "%g", measureValue)
            return "\(valueString) \(measureUnit.rawValue)"
        }
    }
}

// 4. LA LISTA SPESA
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

// 5. MODELLO MEMORIA (Brain)
@Model
class FrequentItem {
    @Attribute(.unique) var name: String
    var emoji: String
    var defaultQuantity: Int
    var defaultMeasureValue: Double
    var defaultMeasureUnit: MeasureUnit
    var defaultLocation: StorageLocation
    var isRecurring: Bool
    var shelfLifeDays: Int? // Durata stimata
    var lastUsed: Date
    
    init(name: String, emoji: String, defaultQuantity: Int, defaultMeasureValue: Double, defaultMeasureUnit: MeasureUnit, defaultLocation: StorageLocation, isRecurring: Bool, shelfLifeDays: Int? = nil) {
        self.name = name
        self.emoji = emoji
        self.defaultQuantity = defaultQuantity
        self.defaultMeasureValue = defaultMeasureValue
        self.defaultMeasureUnit = defaultMeasureUnit
        self.defaultLocation = defaultLocation
        self.isRecurring = isRecurring
        self.shelfLifeDays = shelfLifeDays
        self.lastUsed = Date()
    }
}
