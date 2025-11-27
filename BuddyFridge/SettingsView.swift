import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Query per ottenere tutte le "memorie" salvate, dalla più recente
    @Query(sort: \FrequentItem.lastUsed, order: .reverse) private var frequentItems: [FrequentItem]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if frequentItems.isEmpty {
                        ContentUnavailableView(
                            "Nessuna memoria",
                            systemImage: "brain.head.profile",
                            description: Text("Buddy imparerà le tue preferenze man mano che inserisci prodotti.")
                        )
                    } else {
                        ForEach(frequentItems) { item in
                            HStack {
                                Text(item.emoji)
                                    .font(.largeTitle)
                                    .padding(.trailing, 5)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.headline)
                                    
                                    // Mostra un riassunto della preferenza imparata
                                    Text("Ricorda: x\(item.defaultQuantity) in \(item.defaultLocation.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                } header: {
                    Text("Memorie Prodotti")
                } footer: {
                    Text("Questi sono i prodotti di cui Buddy ha imparato le tue preferenze (quantità, icona, posizione). Scorri verso sinistra per eliminarli se le tue abitudini sono cambiate.")
                }
            }
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") { dismiss() }
                }
            }
        }
    }
    
    // Funzione per eliminare la memoria
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(frequentItems[index])
            }
        }
    }
}
