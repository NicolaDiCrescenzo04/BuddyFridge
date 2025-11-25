import SwiftUI
import SwiftData

struct AddItemView: View {
    // 1. Questo è il "collegamento" al database per poter salvare
    @Environment(\.modelContext) private var modelContext
    // Questo serve per chiudere la finestra dopo aver salvato
    @Environment(\.dismiss) private var dismiss

    // 2. Le variabili temporanee per il modulo (dove scriviamo prima di salvare)
    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var expiryDate: Date = Date() // Parte da oggi
    @State private var location: StorageLocation = .fridge // Parte da Frigo

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Dettagli Prodotto")) {
                    TextField("Nome prodotto (es. Latte)", text: $name)
                    
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...100)
                    
                    Picker("Posizione", selection: $location) {
                        // Prende le opzioni direttamente dal nostro Modello creato prima
                        ForEach(StorageLocation.allCases, id: \.self) { location in
                            Text(location.rawValue).tag(location)
                        }
                    }
                }
                
                Section(header: Text("Scadenza")) {
                    DatePicker("Data di scadenza", selection: $expiryDate, displayedComponents: .date)
                }
            }
            .navigationTitle("Nuovo Cibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Bottone Annulla (a sinistra)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                // Bottone Salva (a destra)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveItem()
                    }
                    // Il tasto è disabilitato se non hai scritto il nome
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    // 3. La funzione che crea davvero l'oggetto e lo salva
    private func saveItem() {
        // Creiamo il nuovo oggetto usando i dati del modulo
        let newItem = FoodItem(
            name: name,
            quantity: quantity,
            expiryDate: expiryDate,
            location: location
        )
        
        // Lo inseriamo nel database (SwiftData fa la magia qui)
        modelContext.insert(newItem)
        
        // Chiudiamo la finestra
        dismiss()
    }
}

#Preview {
    AddItemView()
}
