import SwiftUI
import SwiftData

struct BuddyView: View {
    @Query private var items: [FoodItem]
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isDoorOpen: Bool
    
    // Parametro opzionale: se settato, sovrascrive l'umore automatico
    var forcedMood: BuddyMood? = nil
    
    var onTap: () -> Void
    
    enum BuddyMood { case happy, worried, sad, neutral, observing }
    
    var currentMood: BuddyMood {
        if let forced = forcedMood { return forced }
        
        if items.isEmpty { return .neutral }
        
        let activeItems = items.filter { $0.location != .freezer }
        if activeItems.isEmpty { return .happy }
        
        let hasExpiredItems = activeItems.contains { $0.isExpired }
        if hasExpiredItems { return .sad }
        
        let soonDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        let isWorried = activeItems.contains { item in
            guard let expiry = item.expiryDate else { return false }
            return expiry <= soonDate && !item.isExpired
        }
        
        if isWorried { return .worried }
        
        return .happy
    }
    
    var message: String {
        // Se stiamo osservando, niente testo per pulizia
        if forcedMood == .observing { return "" }
        
        if items.isEmpty { return "Il frigo è vuoto. Facciamo la spesa?" }
        switch currentMood {
        case .happy: return "Tutto fresco! 😄"
        case .worried: return "Occhio alle scadenze... 😰"
        case .sad: return "Qualcosa è andato a male! 🤢"
        case .neutral: return ""
        case .observing: return ""
        }
    }
    
    var bubbleColor: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    
    var body: some View {
        VStack(spacing: 15) {
            
            // 1. FUMETTO (Ora è SOPRA il frigo)
            // Mostriamo il messaggio solo se c'è testo e NON siamo in modalità osservazione forzata
            if !message.isEmpty && forcedMood != .observing {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    // FRECCETTA DEL FUMETTO (Punta in BASSO verso la testa)
                    .overlay(alignment: .bottom) {
                        Image(systemName: "arrowtriangle.down.fill")
                            .foregroundStyle(bubbleColor)
                            .offset(y: 8) // Spostata in basso
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.horizontal, 20)
                    // Nascondi se la porta è aperta (perché ruota sopra)
                    .opacity(isDoorOpen ? 0 : 1)
            }
            
            // 2. BUDDY INTERATTIVO (Sotto il fumetto)
            Button(action: {
                onTap()
            }) {
                BuddyGraphic(mood: currentMood, isOpen: isDoorOpen)
                    .scaleEffect(items.isEmpty && forcedMood != .observing ? 1.2 : 1.0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentMood)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isDoorOpen)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}
