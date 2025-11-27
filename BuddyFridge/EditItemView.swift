import SwiftUI
import SwiftData

struct EditItemView: View {
    @Bindable var item: FoodItem
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Prodotto")) {
                    HStack {
                        TextField("Emoji", text: $item.emoji)
                            .frame(width: 40)
                        TextField("Nome", text: $item.name)
                            .bold()
                    }
                    
                    Stepper("Quantità: \(item.quantity)", value: $item.quantity, in: 1...100)
                    
                    // Modifica Peso/Volume se presente
                    if item.measureUnit != .pieces {
                        HStack {
                            Text("Peso/Volume:")
                            TextField("Valore", value: $item.measureValue, format: .number)
                                .keyboardType(.decimalPad)
                            Picker("", selection: $item.measureUnit) {
                                ForEach(MeasureUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
                
                Section(header: Text("Sposta e Scadenza")) {
                    // CAMBIARE POSIZIONE (SPOSTA)
                    Picker("Posizione", selection: $item.location) {
                        ForEach(StorageLocation.allCases, id: \.self) { loc in
                            Text(loc.rawValue).tag(loc)
                        }
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
                        // AGGIORNA NOTIFICA
                        NotificationManager.shared.updateNotification(for: item)
                        dismiss()
                    }
                }
            }
        }
    }
}
