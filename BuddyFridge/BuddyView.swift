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
    
    var message: String {
        switch currentMood {
        case .happy: return "Tutto fresco! 😎"
        case .worried: return "Occhio alle scadenze... 😬"
        case .sad: return "Qualcosa è andato a male! 🤢"
        case .neutral: return "Il frigo è vuoto. Facciamo la spesa?"
        }
    }
    
    var body: some View {
        // VSTACK: Dispone gli elementi verticalmente (uno sotto l'altro)
        VStack(spacing: 15) {
            
            // 1. IL NOSTRO DISEGNO (Centrato)
            BuddyGraphic(mood: currentMood)
                .scaleEffect(0.9) // Leggermente più grande ora che è al centro
                .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentMood)
            
            // 2. FUMETTO (Sotto)
            if !items.isEmpty || currentMood == .neutral {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center) // Testo centrato
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    // Triangolino che punta verso l'ALTO (verso Buddy)
                    .overlay(alignment: .top) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .foregroundStyle(.white)
                            .offset(y: -8) // Lo spinge fuori dal bordo superiore
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.horizontal, 20) // Margine dai bordi dello schermo
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity) // Assicura che tutto il blocco sia centrato nello schermo
    }
}

#Preview {
    BuddyView()
        .modelContainer(for: [FoodItem.self, ShoppingItem.self], inMemory: true)
}
