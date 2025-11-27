import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    // Query per le memorie
    @Query(sort: \FrequentItem.lastUsed, order: .reverse) private var frequentItems: [FrequentItem]
    
    // --- PREFERENZE NOTIFICHE (Salvate in automatico) ---
    // Il valore dopo '=' è il default se l'utente non ha mai toccato l'impostazione
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("notifySameDay") private var notifySameDay = true
    @AppStorage("notifyOneDayBefore") private var notifyOneDayBefore = true
    @AppStorage("notifyFiveDaysBefore") private var notifyFiveDaysBefore = false // Default spento, l'utente può attivarlo
    
    var body: some View {
        NavigationStack {
            List {
                // SEZIONE 1: GESTIONE NOTIFICHE
                Section(header: Text("Notifiche Scadenze"), footer: Text("Scegli quando vuoi che Buddy ti avvisi.")) {
                    Toggle("Abilita Notifiche", isOn: $notificationsEnabled)
                        .tint(.blue)
                    
                    if notificationsEnabled {
                        Group {
                            Toggle("Giorno stesso (ore 09:00)", isOn: $notifySameDay)
                            Toggle("1 Giorno prima (ore 18:00)", isOn: $notifyOneDayBefore)
                            Toggle("5 Giorni prima (ore 18:00)", isOn: $notifyFiveDaysBefore)
                        }
                        .padding(.leading, 10) // Leggero rientro visivo
                    }
                }
                
                // SEZIONE 2: MEMORIE PRODOTTI (Quella di prima)
                Section(header: Text("Memorie Prodotti"), footer: Text("Scorri a sinistra per dimenticare un'abitudine.")) {
                    if frequentItems.isEmpty {
                        ContentUnavailableView(
                            "Nessuna memoria",
                            systemImage: "brain.head.profile",
                            description: Text("Buddy impara mentre usi l'app.")
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
                                    
                                    Text("Ricorda: x\(item.defaultQuantity) in \(item.defaultLocation.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
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
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(frequentItems[index])
            }
        }
    }
}
