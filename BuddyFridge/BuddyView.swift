import SwiftUI
import SwiftData

struct BuddyView: View {
    @Query private var items: [FoodItem]
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var isDoorOpen: Bool
    var onTap: () -> Void
    
    enum BuddyMood { case happy, worried, sad, neutral }
    
    var currentMood: BuddyMood {
        if items.isEmpty { return .neutral }
        
        // --- LOGICA SMART: Ignoriamo il congelatore per l'umore ---
        // I prodotti in congelatore sono "bloccati", non rendono Buddy triste.
        let activeItems = items.filter { $0.location != .freezer }
        
        // Se tutto è nel congelatore, Buddy è felice (o neutro se vuoto attivo)
        if activeItems.isEmpty { return .happy }
        
        let hasExpiredItems = activeItems.contains { $0.isExpired }
        if hasExpiredItems { return .sad }
        
        let soonDate = Calendar.current.date(byAdding: .day, value: 2, to: Date())!
        if activeItems.contains(where: { $0.expiryDate <= soonDate && !$0.isExpired }) { return .worried }
        
        return .happy
    }
    
    var message: String {
        if items.isEmpty { return "Il frigo è vuoto. Facciamo la spesa?" }
        switch currentMood {
        case .happy: return "Tutto fresco! 😄" // O "Brrr... che freddo!" se c'è roba in freezer? :D
        case .worried: return "Occhio alle scadenze... 😰"
        case .sad: return "Qualcosa è andato a male! 🤢"
        case .neutral: return ""
        }
    }
    
    var bubbleColor: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    
    var body: some View {
        VStack(spacing: 15) {
            
            // BUDDY INTERATTIVO
            Button(action: {
                onTap()
            }) {
                BuddyGraphic(mood: currentMood, isOpen: isDoorOpen)
                    .scaleEffect(items.isEmpty ? 1.2 : 0.9)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6), value: currentMood)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isDoorOpen)
            }
            .buttonStyle(.plain)
            
            // FUMETTO
            if !items.isEmpty || currentMood == .neutral {
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .overlay(alignment: .top) {
                        Image(systemName: "arrowtriangle.up.fill")
                            .foregroundStyle(bubbleColor)
                            .offset(y: -8)
                    }
                    .transition(.opacity.combined(with: .scale))
                    .padding(.horizontal, 20)
                    .opacity(isDoorOpen ? 0 : 1)
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
    }
}
