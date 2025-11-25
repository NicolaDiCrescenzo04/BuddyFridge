import SwiftUI
import SwiftData
import UserNotifications

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Dati Prodotto
    @State private var name: String = ""
    @State private var selectedEmoji: String = "🛍️"
    
    // Quantità e Misure
    @State private var quantity: Int = 1
    @State private var isRecurring: Bool = false
    @State private var measureValue: Double = 0
    @State private var measureUnit: MeasureUnit = .pieces
    
    // Scadenza e Posizione
    @State private var expiryDate: Date = Date()
    @State private var location: StorageLocation = .fridge
    
    // --- GESTIONE SCANNER ---
    @State private var showScanner = false // Apre la fotocamera
    @State private var isLoadingScan = false // Mostra caricamento mentre cerca il prodotto

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: Text("Cosa e Quanto?")) {
                        // 1. CAMPO NOME + BOTTONE SCANNER
                        HStack {
                            // Icona modificabile
                            TextField("", text: $selectedEmoji)
                                .font(.title)
                                .multilineTextAlignment(.center)
                                .frame(width: 50, height: 50)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                                .onChange(of: selectedEmoji) {
                                    if selectedEmoji.count > 1 { selectedEmoji = String(selectedEmoji.last!) }
                                }
                            
                            // Campo nome SEMPLICE (senza ricerca live)
                            TextField("Nome prodotto", text: $name)
                            
                            // BOTTONE SCANNER
                            Button(action: { showScanner = true }) {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                    .padding(8)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        
                        // QUANTITÀ
                        Stepper("Numero Pezzi: \(quantity)", value: $quantity, in: 1...100)
                        
                        // MISURA
                        HStack {
                            Text("Peso unità:")
                            Spacer()
                            if measureUnit != .pieces {
                                TextField("0", value: $measureValue, format: .number)
                                    .keyboardType(.decimalPad)
                                    .frame(width: 70)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Picker("", selection: $measureUnit) {
                                ForEach(MeasureUnit.allCases, id: \.self) { unit in
                                    Text(unit.rawValue).tag(unit)
                                }
                            }
                            .labelsHidden()
                        }
                        
                        Toggle("Prodotto Ricorrente", isOn: $isRecurring)
                    }
                    
                    Section(header: Text("Dettagli")) {
                        Picker("Posizione", selection: $location) {
                            ForEach(StorageLocation.allCases, id: \.self) { loc in
                                Text(loc.rawValue).tag(loc)
                            }
                        }
                        DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                    }
                }
                
                // Overlay Caricamento (se stiamo cercando il codice online)
                if isLoadingScan {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Cerco prodotto...")
                        .padding()
                        .background(.white)
                        .cornerRadius(10)
                }
            }
            .navigationTitle("Nuovo Cibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveItem() }
                    .disabled(name.isEmpty)
                }
            }
            // APERTURA SCANNER
            .sheet(isPresented: $showScanner) {
                ScannerView { code in
                    // Quando trova un codice, eseguiamo questo:
                    handleScan(code: code)
                }
                .ignoresSafeArea()
            }
        }
    }

    // --- LOGICA ---
    
    private func handleScan(code: String) {
        isLoadingScan = true
        
        Task {
            // Cerchiamo su OpenFoodFacts tramite il codice letto
            if let product = await ProductLibrary.shared.fetchProductByBarcode(code: code) {
                name = product.name
                selectedEmoji = product.emoji
                
                if product.category == "Congelatore" { location = .freezer }
                else if product.category == "Frigo" { location = .fridge }
                else { location = .pantry }
            } else {
                // Se non lo trova
                name = "Prodotto sconosciuto"
            }
            isLoadingScan = false
        }
    }

    private func saveItem() {
        let finalEmoji = selectedEmoji.isEmpty ? "🛍️" : selectedEmoji
        let newItem = FoodItem(
            name: name,
            emoji: finalEmoji,
            quantity: quantity,
            expiryDate: expiryDate,
            location: location,
            isRecurring: isRecurring,
            measureValue: measureValue,
            measureUnit: measureUnit
        )
        modelContext.insert(newItem)
        scheduleNotification(for: newItem)
        dismiss()
    }

    private func scheduleNotification(for item: FoodItem) {
        let content = UNMutableNotificationContent()
        content.title = "Scadenza in arrivo! ⚠️"
        content.body = "'\(item.name)' sta per scadere."
        content.sound = .default
        
        var dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: item.expiryDate)
        dateComponents.hour = 9
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
