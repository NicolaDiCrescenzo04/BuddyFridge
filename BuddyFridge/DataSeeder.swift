import Foundation
import SwiftData
import SwiftUI

class DataSeeder {
    static let shared = DataSeeder()
    
    // Flag per sapere se abbiamo già caricato i dati (salvato nelle impostazioni utente)
    @AppStorage("didPreloadData") private var didPreloadData = false
    
    func preloadData(context: ModelContext) {
        // Se lo abbiamo già fatto, ci fermiamo
        if didPreloadData { return }
        
        // --- IL CERVELLO PRE-IMPOSTATO DI BUDDY ---
        let starterPack = [
            // FRESCHI & FRIGO
            FrequentItem(name: "Latte Fresco", emoji: "🥛", defaultQuantity: 1, defaultMeasureValue: 1, defaultMeasureUnit: .liters, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 6),
            FrequentItem(name: "Uova", emoji: "🥚", defaultQuantity: 6, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 20),
            FrequentItem(name: "Yogurt", emoji: "🥣", defaultQuantity: 2, defaultMeasureValue: 125, defaultMeasureUnit: .grams, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 14),
            FrequentItem(name: "Burro", emoji: "🧈", defaultQuantity: 1, defaultMeasureValue: 250, defaultMeasureUnit: .grams, defaultLocation: .fridge, isRecurring: false, shelfLifeDays: 60),
            FrequentItem(name: "Petto di Pollo", emoji: "🍗", defaultQuantity: 1, defaultMeasureValue: 400, defaultMeasureUnit: .grams, defaultLocation: .fridge, isRecurring: false, shelfLifeDays: 3),
            FrequentItem(name: "Salmone", emoji: "🐟", defaultQuantity: 1, defaultMeasureValue: 200, defaultMeasureUnit: .grams, defaultLocation: .fridge, isRecurring: false, shelfLifeDays: 2),
            FrequentItem(name: "Parmigiano", emoji: "🧀", defaultQuantity: 1, defaultMeasureValue: 300, defaultMeasureUnit: .grams, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 45),
            FrequentItem(name: "Insalata", emoji: "🥬", defaultQuantity: 1, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 4),
            
            // FRUTTA & VERDURA (Il problema "Banana")
            FrequentItem(name: "Banane", emoji: "🍌", defaultQuantity: 4, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .pantry, isRecurring: true, shelfLifeDays: 5),
            FrequentItem(name: "Mele", emoji: "🍎", defaultQuantity: 4, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 14),
            FrequentItem(name: "Limoni", emoji: "🍋", defaultQuantity: 3, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .fridge, isRecurring: false, shelfLifeDays: 20),
            FrequentItem(name: "Pomodori", emoji: "🍅", defaultQuantity: 6, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .fridge, isRecurring: true, shelfLifeDays: 7),
            FrequentItem(name: "Patate", emoji: "🥔", defaultQuantity: 1, defaultMeasureValue: 1, defaultMeasureUnit: .kilograms, defaultLocation: .pantry, isRecurring: false, shelfLifeDays: 21),
            FrequentItem(name: "Cipolle", emoji: "🧅", defaultQuantity: 3, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .pantry, isRecurring: true, shelfLifeDays: 21),
            
            // DISPENSA
            FrequentItem(name: "Pasta", emoji: "🍝", defaultQuantity: 1, defaultMeasureValue: 500, defaultMeasureUnit: .grams, defaultLocation: .pantry, isRecurring: true, shelfLifeDays: 730), // 2 anni
            FrequentItem(name: "Riso", emoji: "🍚", defaultQuantity: 1, defaultMeasureValue: 1, defaultMeasureUnit: .kilograms, defaultLocation: .pantry, isRecurring: false, shelfLifeDays: 365),
            FrequentItem(name: "Pane", emoji: "🍞", defaultQuantity: 1, defaultMeasureValue: 0, defaultMeasureUnit: .pieces, defaultLocation: .pantry, isRecurring: true, shelfLifeDays: 3),
            FrequentItem(name: "Tonno", emoji: "🥫", defaultQuantity: 3, defaultMeasureValue: 80, defaultMeasureUnit: .grams, defaultLocation: .pantry, isRecurring: false, shelfLifeDays: 1000), // Lunga conservazione
            FrequentItem(name: "Caffè", emoji: "☕️", defaultQuantity: 1, defaultMeasureValue: 250, defaultMeasureUnit: .grams, defaultLocation: .pantry, isRecurring: true, shelfLifeDays: 180),
            
            // SURGELATI
            FrequentItem(name: "Piselli", emoji: "🟢", defaultQuantity: 1, defaultMeasureValue: 450, defaultMeasureUnit: .grams, defaultLocation: .freezer, isRecurring: false, shelfLifeDays: 365),
            FrequentItem(name: "Spinaci", emoji: "🍃", defaultQuantity: 1, defaultMeasureValue: 450, defaultMeasureUnit: .grams, defaultLocation: .freezer, isRecurring: false, shelfLifeDays: 365),
            FrequentItem(name: "Gelato", emoji: "🍦", defaultQuantity: 1, defaultMeasureValue: 500, defaultMeasureUnit: .grams, defaultLocation: .freezer, isRecurring: false, shelfLifeDays: 180)
        ]
        
        // Inserimento nel database
        for item in starterPack {
            context.insert(item)
        }
        
        // Segniamo che abbiamo finito, così non lo rifà al prossimo avvio
        didPreloadData = true
        print("✅ Buddy ha imparato i prodotti base!")
    }
}
