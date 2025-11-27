//
import SwiftUI
import SwiftData
import UserNotifications

@main
struct BuddyFridgeApp: App {
    // Creiamo il container manualmente per poter accedere al context
    let container: ModelContainer
    
    init() {
        do {
            container = try ModelContainer(for: FoodItem.self, ShoppingItem.self, FrequentItem.self)
        } catch {
            fatalError("Impossibile inizializzare il database: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 1. Notifiche
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
                    
                    // 2. Pre-caricamento dati "Stock"
                    // Eseguiamo sul MainActor perché SwiftData non è thread-safe fuori dal contesto
                    Task { @MainActor in
                        DataSeeder.shared.preloadData(context: container.mainContext)
                    }
                }
        }
        .modelContainer(container)
    }
}
