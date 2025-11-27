import SwiftUI
import SwiftData
import UserNotifications // 1. Serve per le notifiche

@main
struct BuddyFridgeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // 2. Chiediamo il permesso per le notifiche all'avvio
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                        if granted {
                            print("Permesso notifiche accordato! 👍")
                        } else {
                            print("Niente notifiche per noi. 😢")
                        }
                    }
                }
        }
        // 3. FONDAMENTALE: Qui usiamo FoodItem, non Item!
        .modelContainer(for: [FoodItem.self, ShoppingItem.self, FrequentItem.self])
    }
}
