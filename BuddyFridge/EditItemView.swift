import SwiftUI
import SwiftData

struct EditItemView: View {
    @Bindable var item: FoodItem
    @Environment(\.dismiss) private var dismiss
    
    // Memorizziamo la posizione originale quando apriamo la schermata
    @State private var originalLocation: StorageLocation?
    // Stato per l'avviso scongelamento
    @State private var showThawAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Prodotto")) {
                    HStack {
                        TextField("Emoji", text: $item.emoji).frame(width: 40)
                        TextField("Nome", text: $item.name).bold()
                    }
                    Stepper("Quantità: \(item.quantity)", value: $item.quantity, in: 1...100)
                    if item.measureUnit != .pieces {
                        HStack {
                            Text("Peso/Volume:")
                            TextField("Valore", value: $item.measureValue, format: .number).keyboardType(.decimalPad)
                            Picker("", selection: $item.measureUnit) { ForEach(MeasureUnit.allCases, id: \.self) { unit in Text(unit.rawValue).tag(unit) } }.labelsHidden()
                        }
                    }
                }
                
                Section(header: Text("Sposta e Scadenza")) {
                    Picker("Posizione", selection: $item.location) {
                        ForEach(StorageLocation.allCases, id: \.self) { loc in Text(loc.rawValue).tag(loc) }
                    }
                    .pickerStyle(.segmented)
                    
                    DatePicker("Scadenza", selection: $item.expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Modifica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        handleSave()
                    }
                }
            }
            .onAppear {
                // Salviamo la posizione di partenza
                originalLocation = item.location
            }
            // AVVISO BUDDY SCONGELAMENTO
            .alert("Buddy ti ricorda:", isPresented: $showThawAlert) {
                Button("Ho capito", role: .cancel) {
                    finalizeSave()
                }
            } message: {
                Text("Hai tirato fuori '\(item.name)' dal congelatore.\n\nMi raccomando: una volta scongelato, non ricongelarlo più! ❄️🚫")
            }
        }
    }
    
    private func handleSave() {
        // Controlliamo se stiamo "Scongelando" (Da Freezer -> Altro)
        if originalLocation == .freezer && item.location != .freezer {
            showThawAlert = true
        } else {
            finalizeSave()
        }
    }
    
    private func finalizeSave() {
        NotificationManager.shared.updateNotification(for: item)
        dismiss()
    }
}
