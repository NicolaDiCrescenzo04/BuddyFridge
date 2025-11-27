import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    // Richiesta permessi (da chiamare all'avvio se vuoi, o usiamo quello in App)
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            print("Permesso notifiche: \(granted ? "SI" : "NO")")
        }
    }
    
    // 1. PIANIFICA (Crea o Sovrascrive)
    func scheduleNotification(for item: FoodItem) {
        // Prima puliamo eventuali vecchie notifiche per questo item
        cancelNotification(for: item)
        
        // Contenuto base
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        // A. NOTIFICA GIORNO SCADENZA (Ore 09:00)
        content.title = "Scade oggi! ⚠️"
        content.body = "Il prodotto '\(item.emoji) \(item.name)' scade oggi. Usalo subito!"
        
        var dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: item.expiryDate)
        dateComponents.hour = 9
        dateComponents.minute = 0
        
        let triggerDay = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let requestDay = UNNotificationRequest(identifier: "\(item.id.uuidString)-today", content: content, trigger: triggerDay)
        
        UNUserNotificationCenter.current().add(requestDay)
        
        // B. NOTIFICA GIORNO PRIMA (Ore 18:00)
        // Calcoliamo la data del giorno prima
        if let dayBeforeDate = Calendar.current.date(byAdding: .day, value: -1, to: item.expiryDate) {
            // Verifichiamo che il giorno prima non sia già passato (es. se inserisco un prodotto che scade oggi)
            if dayBeforeDate > Date() {
                let contentBefore = UNMutableNotificationContent()
                contentBefore.title = "Scade domani 🕒"
                contentBefore.body = "Ricorda: '\(item.emoji) \(item.name)' scadrà domani."
                contentBefore.sound = .default
                
                var dateComponentsBefore = Calendar.current.dateComponents([.day, .month, .year], from: dayBeforeDate)
                dateComponentsBefore.hour = 18 // Avvisami alle 18:00 del giorno prima
                dateComponentsBefore.minute = 0
                
                let triggerBefore = UNCalendarNotificationTrigger(dateMatching: dateComponentsBefore, repeats: false)
                let requestBefore = UNNotificationRequest(identifier: "\(item.id.uuidString)-tomorrow", content: contentBefore, trigger: triggerBefore)
                
                UNUserNotificationCenter.current().add(requestBefore)
            }
        }
    }
    
    // 2. CANCELLA (Quando mangi o elimini)
    func cancelNotification(for item: FoodItem) {
        let ids = [
            "\(item.id.uuidString)-today",
            "\(item.id.uuidString)-tomorrow"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    // 3. AGGIORNA (Quando modifichi data o nome)
    func updateNotification(for item: FoodItem) {
        // È sufficiente richiamare schedule, perché al suo interno chiama già cancel
        scheduleNotification(for: item)
    }
}
