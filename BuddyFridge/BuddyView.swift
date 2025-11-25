import SwiftUI
import SwiftData

struct BuddyView: View {
    @Query private var items: [FoodItem]
    
    enum BuddyMood {
        case happy, worried, sad, neutral
    }
    
    var currentMood: BuddyMood {
        if items.isEmpty { return .neutral }
        
        let hasExpiredItems = items.contains { $0.isExpired }
        if hasExpiredItems { return .sad }
        
        // Calcola se qualcosa scade entro domani
        let soonDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let hasExpiringSoon = items.contains { item in
            return item.expiryDate <= soonDate && !item.isExpired
        }
        if hasExpiringSoon { return .worried }
        
        return .happy
    }
    
    var moodData: (color: Color, icon: String, message: String) {
        switch currentMood {
        case .happy: return (.green, "face.smiling", "Tutto fresco!")
        case .worried: return (.orange, "face.dashed", "Occhio alle scadenze...")
        case .sad: return (.red, "exclamationmark.triangle", "Qualcosa è andato a male!")
        case .neutral: return (.blue, "face.smiling", "Il frigo è vuoto.")
        }
    }
    
    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(moodData.color.opacity(0.2)).frame(width: 120, height: 120)
                Circle().stroke(moodData.color, lineWidth: 3).frame(width: 120, height: 120)
                Image(systemName: moodData.icon)
                    .font(.system(size: 60))
                    .foregroundStyle(moodData.color)
            }
            .padding(.top, 20)
            
            Text(moodData.message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 10)
        .animation(.spring(), value: currentMood)
    }
}
