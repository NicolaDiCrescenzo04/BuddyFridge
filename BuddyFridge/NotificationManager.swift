import Foundation
import UserNotifications
import SwiftUI

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }
    
    // 1. PIANIFICAZIONE INTELLIGENTE
    func scheduleNotification(for item: FoodItem) {
        // Passo 0: Pulisci sempre tutto per evitare duplicati
        cancelNotification(for: item)
        
        // --- NUOVO: SE È IN CONGELATORE, STOP! ---
        // I prodotti congelati sono "bloccati nel tempo", niente notifiche.
        if item.location == .freezer {
            return
        }
        // -----------------------------------------
        
        // Passo 1: Controllo Interruttore Generale
        let isEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        if !isEnabled { return }
        
        // Passo 2: Recupero preferenze utente
        let notifySameDay = UserDefaults.standard.object(forKey: "notifySameDay") as? Bool ?? true
        let notifyOneDayBefore = UserDefaults.standard.object(forKey: "notifyOneDayBefore") as? Bool ?? true
        let notifyFiveDaysBefore = UserDefaults.standard.object(forKey: "notifyFiveDaysBefore") as? Bool ?? false
        
        let content = UNMutableNotificationContent()
        content.sound = .default
        
        // --- A. GIORNO STESSO (09:00) ---
        if notifySameDay {
            content.title = "Scade oggi! ⚠️"
            content.body = "Il prodotto '\(item.emoji) \(item.name)' scade oggi. Usalo subito!"
            
            var dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: item.expiryDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let request = UNNotificationRequest(identifier: "\(item.id.uuidString)-today", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
        
        // --- B. 1 GIORNO PRIMA (18:00) ---
        if notifyOneDayBefore {
            scheduleAdvanceNotification(for: item, daysBefore: 1, hour: 18, idSuffix: "-1day")
        }
        
        // --- C. 5 GIORNI PRIMA (18:00) ---
        if notifyFiveDaysBefore {
            scheduleAdvanceNotification(for: item, daysBefore: 5, hour: 18, idSuffix: "-5days")
        }
    }
    
    private func scheduleAdvanceNotification(for item: FoodItem, daysBefore: Int, hour: Int, idSuffix: String) {
        if let targetDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: item.expiryDate) {
            if targetDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Scadenza vicina 🕒"
                content.body = "'\(item.emoji) \(item.name)' scade tra \(daysBefore) giorni."
                content.sound = .default
                
                var comps = Calendar.current.dateComponents([.day, .month, .year], from: targetDate)
                comps.hour = hour
                comps.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "\(item.id.uuidString)\(idSuffix)", content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    // 2. CANCELLA
    func cancelNotification(for item: FoodItem) {
        let ids = [
            "\(item.id.uuidString)-today",
            "\(item.id.uuidString)-1day",
            "\(item.id.uuidString)-5days"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
    
    // 3. AGGIORNA
    func updateNotification(for item: FoodItem) {
        scheduleNotification(for: item)
    }
}
