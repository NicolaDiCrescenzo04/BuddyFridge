import SwiftUI
import SwiftData

struct BuddyView: View {
    @Query private var items: [FoodItem]
    @Environment(\.colorScheme) var colorScheme // Per la dark mode
    
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
    
    var message: String {
        switch currentMood {
        case .happy: return "Tutto fresco! 😎"
        case .worried: return "Occhio alle scadenze... 😬"
        case .sad: return "Qualcosa è andato a male! 🤢"
        case .neutral: return "Il frigo è vuoto. Facciamo la spesa?"
        }
    }
    
    // Colore del fumetto adattivo
    var bubbleColor: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    var body: some View {
        VStack(spacing: 15) {
            
            // 1. IL NOSTRO DISEGNO
            BuddyGraphic(mood: currentMood)
                .scaleEffect(0.9)
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentMood)
            
            // 2. FUMETTO
            if !items.isEmpty || currentMood == .neutral {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(bubbleColor) // <--- Colore adattivo
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .overlay(alignment: .top) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .foregroundStyle(bubbleColor) // <--- Anche la freccia
                            .offset(y: -8)
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}
