import SwiftUI
import SwiftData
import UserNotifications

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Dati Prodotto
    @State private var name: String = ""
    // Emoji di default
    @State private var selectedEmoji: String = "🛍️"
    
    // Quantità e Misure
    @State private var quantity: Int = 1
    @State private var isRecurring: Bool = false
    @State private var measureValue: Double = 0
    @State private var measureUnit: MeasureUnit = .pieces
    
    // Scadenza e Posizione
    @State private var expiryDate: Date = Date()
    @State private var location: StorageLocation = .fridge
    
    // --- STATI PER LE MODALI ---
    @State private var showScanner = false
    @State private var isLoadingScan = false
    @State private var showEmojiPicker = false // <--- NUOVO: Apre il nostro picker

    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: Text("Cosa e Quanto?")) {
                        // 1. CAMPO NOME + SELETTORE EMOJI "BOTTONE"
                        HStack(spacing: 12) {
                            
                            // --- BOTTONE EMOJI (Niente più cursore!) ---
                            Button(action: { showEmojiPicker = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    
                                    Text(selectedEmoji)
                                        .font(.system(size: 30)) // Icona bella grande
                                }
                            }
                            .buttonStyle(.borderless) // Importante per non cliccare tutta la riga
                            // -------------------------------------------
                            
                            // Campo nome
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
                            .buttonStyle(.borderless)
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
                
                // Overlay Caricamento
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
                    handleScan(code: code)
                }
                .ignoresSafeArea()
            }
            // APERTURA PICKER EMOJI
            .sheet(isPresented: $showEmojiPicker) {
                FoodEmojiPicker(selectedEmoji: $selectedEmoji)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // --- LOGICA ---
    
    private func handleScan(code: String) {
        isLoadingScan = true
        Task {
            if let product = await ProductLibrary.shared.fetchProductByBarcode(code: code) {
                name = product.name
                selectedEmoji = product.emoji
                if product.category == "Congelatore" { location = .freezer }
                else if product.category == "Frigo" { location = .fridge }
                else { location = .pantry }
            } else {
                name = "Prodotto sconosciuto"
            }
            isLoadingScan = false
        }
    }

    private func saveItem() {
        let newItem = FoodItem(
            name: name,
            emoji: selectedEmoji,
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

// --- NUOVO COMPONENTE: TASTIERA EMOJI CIBO ---
struct FoodEmojiPicker: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) var dismiss
    
    // Lista curata delle emoji più utili per la spesa
    let foodEmojis = [
        "🍎", "🍐", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🫐", "🍈", "🍒", "🍑", "🥭", "🍍", "🥥", "🥝", "🍅", "🍆", "🥑", "🥦", "🥬", "🥒", "🌶", "🫑", "🌽", "🥕", "🫒", "🧄", "🧅", "🥔", "🍠",
        "🥐", "🥯", "🍞", "🥖", "🥨", "🧀", "🥚", "🍳", "🧈", "🥞", "🧇", "🥓", "🥩", "🍗", "🍖", "🦴", "🌭", "🍔", "🍟", "🍕", "🫓", "🥪", "🥙", "🧆", "🌮", "🌯", "🫔", "🥗", "🥘", "🫕", "🥫",
        "🍝", "🍜", "🍲", "🍛", "🍣", "🍱", "🥟", "🦪", "🍤", "🍙", "🍚", "🍘", "🍥", "🥠", "🍢", "🍡", "🍧", "🍨", "🍦", "🥧", "🧁", "🍰", "🎂", "🍮", "🍭", "🍬", "🍫", "🍿", "🍩", "🍪",
        "🌰", "🥜", "🍯", "🥛", "🍼", "🫖", "☕️", "🍵", "🧃", "🥤", "🧋", "🍶", "🍺", "🍻", "🥂", "🍷", "🥃", "🍸", "🍹", "🧉", "🍾", "🧊", "🥄", "🍴", "🍽", "🥣", "🥡", "🥢", "🧂", "🛍️"
    ]
    
    let columns = [GridItem(.adaptive(minimum: 45))]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(foodEmojis, id: \.self) { emoji in
                        Button(action: {
                            selectedEmoji = emoji
                            dismiss()
                        }) {
                            Text(emoji)
                                .font(.system(size: 40))
                                .frame(width: 50, height: 50)
                                .background(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.clear)
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scegli Icona")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
