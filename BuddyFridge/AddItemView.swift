import SwiftUI
import SwiftData
import UserNotifications

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // --- 1. RECUPERIAMO LA MEMORIA STORICA ---
    @Query(sort: \FrequentItem.lastUsed, order: .reverse) private var frequentItems: [FrequentItem]
    
    // Dati Prodotto
    @State private var name: String = ""
    @State private var selectedEmoji: String = "🛍️"
    
    // Quantità e Misure
    @State private var quantity: Int = 1
    @State private var isRecurring: Bool = false
    @State private var measureValue: Double = 0
    @State private var measureUnit: MeasureUnit = .pieces
    
    // Scadenza e Posizione
    // MODIFICA: hasExpiry controlla se attivare la logica
    @State private var hasExpiry: Bool = true
    @State private var expiryDate: Date = Date()
    @State private var location: StorageLocation = .fridge
    
    // --- STATI PER LE MODALI ---
    @State private var showScanner = false
    @State private var isLoadingScan = false
    @State private var showEmojiPicker = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    Section(header: Text("Cosa e Quanto?")) {
                        // 1. CAMPO NOME + SELETTORE EMOJI
                        HStack(spacing: 12) {
                            Button(action: { showEmojiPicker = true }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    Text(selectedEmoji).font(.system(size: 30))
                                }
                            }
                            .buttonStyle(.borderless)
                            
                            TextField("Nome prodotto", text: $name)
                                .onChange(of: name) { oldValue, newValue in
                                    if newValue.isEmpty { resetFields() }
                                }
                            
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
                        
                        // --- 2. ZONA SUGGERIMENTI INTELLIGENTI (SOLO LOCALE) ---
                        if !name.isEmpty {
                            let suggestions = frequentItems.filter {
                                $0.name.localizedCaseInsensitiveContains(name) && $0.name != name
                            }
                            
                            if !suggestions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(suggestions) { item in
                                            Button(action: { applySuggestion(item) }) {
                                                HStack(spacing: 6) {
                                                    Text(item.emoji)
                                                    VStack(alignment: .leading, spacing: 0) {
                                                        Text(item.name).font(.subheadline).fontWeight(.semibold)
                                                        Text("x\(item.defaultQuantity)").font(.caption).opacity(0.8)
                                                    }
                                                }
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(20)
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .padding(.vertical, 5)
                            }
                        }
                        
                        Stepper("Numero Pezzi: \(quantity)", value: $quantity, in: 1...100)
                        
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
                        
                        // --- LOGICA SCADENZA FACOLTATIVA ---
                        Toggle("Ha una scadenza?", isOn: $hasExpiry)
                        
                        if hasExpiry {
                            DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                            
                            // BOTTONI RAPIDI "Consumare in..."
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    QuickDateButton(days: 2, label: "+2 gg", current: expiryDate, action: setDate)
                                    QuickDateButton(days: 4, label: "+4 gg", current: expiryDate, action: setDate)
                                    QuickDateButton(days: 7, label: "+1 sett", current: expiryDate, action: setDate)
                                    QuickDateButton(days: 14, label: "+2 sett", current: expiryDate, action: setDate)
                                    QuickDateButton(days: 30, label: "+1 mese", current: expiryDate, action: setDate)
                                }
                            }
                            .padding(.top, 5)
                        }
                    }
                }
                
                if isLoadingScan {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Cerco prodotto...").padding().background(.white).cornerRadius(10)
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
            .sheet(isPresented: $showScanner) {
                ScannerView { code in handleScan(code: code) }.ignoresSafeArea()
            }
            .sheet(isPresented: $showEmojiPicker) {
                FoodEmojiPicker(selectedEmoji: $selectedEmoji)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // --- LOGICA ---
    
    private func setDate(days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
            withAnimation {
                self.expiryDate = newDate
            }
        }
    }
    
    private func applySuggestion(_ item: FrequentItem) {
        withAnimation {
            self.name = item.name
            self.selectedEmoji = item.emoji
            self.quantity = item.defaultQuantity
            self.measureValue = item.defaultMeasureValue
            self.measureUnit = item.defaultMeasureUnit
            self.location = item.defaultLocation
            self.isRecurring = item.isRecurring
            
            // Logica Intelligente Data
            if let days = item.shelfLifeDays {
                self.hasExpiry = true
                if let smartDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
                    self.expiryDate = smartDate
                }
            } else {
                self.expiryDate = Date()
            }
        }
    }
    
    private func resetFields() {
        self.selectedEmoji = "🛍️"
        self.quantity = 1
        self.measureValue = 0
        self.measureUnit = .pieces
    }
    
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
        // Determiniamo la data finale: nil se hasExpiry è false
        let finalDate: Date? = hasExpiry ? expiryDate : nil
        
        let newItem = FoodItem(
            name: name,
            emoji: selectedEmoji,
            quantity: quantity,
            expiryDate: finalDate, // Passiamo l'opzionale
            location: location,
            isRecurring: isRecurring,
            measureValue: measureValue,
            measureUnit: measureUnit
        )
        modelContext.insert(newItem)
        
        // Pianifica notifica SOLO se c'è una data
        if let _ = finalDate {
            NotificationManager.shared.scheduleNotification(for: newItem)
        }
        
        updateFrequencyHistory(finalDate: finalDate)
        
        dismiss()
    }
    
    private func updateFrequencyHistory(finalDate: Date?) {
        // Se non c'è scadenza, salviamo nil come durata stimata
        var estimatedShelfLife: Int? = nil
        
        if let date = finalDate {
            let daysDiff = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
            estimatedShelfLife = daysDiff > 0 ? daysDiff : nil
        }
        
        if let existingItem = frequentItems.first(where: { $0.name.lowercased() == name.lowercased() }) {
            existingItem.emoji = selectedEmoji
            existingItem.defaultQuantity = quantity
            existingItem.defaultMeasureValue = measureValue
            existingItem.defaultMeasureUnit = measureUnit
            existingItem.defaultLocation = location
            existingItem.isRecurring = isRecurring
            existingItem.lastUsed = Date()
            
            // Aggiorniamo la durata anche nella memoria
            if let life = estimatedShelfLife {
                existingItem.shelfLifeDays = life
            }
        } else {
            let newFrequent = FrequentItem(
                name: name,
                emoji: selectedEmoji,
                defaultQuantity: quantity,
                defaultMeasureValue: measureValue,
                defaultMeasureUnit: measureUnit,
                defaultLocation: location,
                isRecurring: isRecurring,
                shelfLifeDays: estimatedShelfLife
            )
            modelContext.insert(newFrequent)
        }
    }
    
    // Componente Tasto Rapido
    struct QuickDateButton: View {
        let days: Int
        let label: String
        let current: Date
        let action: (Int) -> Void
        
        var body: some View {
            Button(action: { action(days) }) {
                Text(label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(8)
            }
        }
    }
    
    // --- STRUTTURA MANCANTE ---
    struct EmojiItem: Hashable {
        let icon: String
        let keywords: String
    }
    // --------------------------
    
    struct FoodEmojiPicker: View {
        @Binding var selectedEmoji: String
        @Environment(\.dismiss) var dismiss
        
        @State private var searchText = ""
        
        // 1. CIBO: TUTTO (Frutta, verdura, piatti pronti, bevande)
        let foodItems: [EmojiItem] = [
            .init(icon: "🍎", keywords: "mela frutta rossa"),
            .init(icon: "🍐", keywords: "pera frutta verde"),
            .init(icon: "🍊", keywords: "arancia agrumi frutta"),
            .init(icon: "🍋", keywords: "limone agrumi giallo"),
            .init(icon: "🍌", keywords: "banana frutta giallo"),
            .init(icon: "🍉", keywords: "anguria cocomero frutta estate"),
            .init(icon: "🍇", keywords: "uva frutta vino"),
            .init(icon: "🍓", keywords: "fragola frutta rosso"),
            .init(icon: "🫐", keywords: "mirtilli frutti di bosco"),
            .init(icon: "🍒", keywords: "ciliegie frutta rosso"),
            .init(icon: "🍑", keywords: "pesca frutta"),
            .init(icon: "🥭", keywords: "mango frutta esotico"),
            .init(icon: "🍍", keywords: "ananas frutta tropicale"),
            .init(icon: "🍅", keywords: "pomodoro verdura rosso sugo"),
            .init(icon: "🍆", keywords: "melanzana verdura"),
            .init(icon: "🥑", keywords: "avocado verdura"),
            .init(icon: "🥦", keywords: "broccoli verdura verde"),
            .init(icon: "🥬", keywords: "lattuga insalata verdura"),
            .init(icon: "🥒", keywords: "cetriolo verdura"),
            .init(icon: "🌶", keywords: "peperoncino piccante"),
            .init(icon: "🫑", keywords: "peperone verdura"),
            .init(icon: "🌽", keywords: "mais granoturco"),
            .init(icon: "🥕", keywords: "carota verdura arancione"),
            .init(icon: "🥔", keywords: "patata tubero"),
            .init(icon: "🧅", keywords: "cipolla"),
            .init(icon: "🧄", keywords: "aglio"),
            .init(icon: "🥖", keywords: "pane baguette"),
            .init(icon: "🍞", keywords: "pane bauletto toast"),
            .init(icon: "🥐", keywords: "cornetto brioche colazione"),
            .init(icon: "🧀", keywords: "formaggio latticini"),
            .init(icon: "🥚", keywords: "uovo uova"),
            .init(icon: "🥓", keywords: "bacon pancetta salumi"),
            .init(icon: "🍔", keywords: "hamburger panino"),
            .init(icon: "🍟", keywords: "patatine fritte"),
            .init(icon: "🍕", keywords: "pizza"),
            .init(icon: "🍝", keywords: "pasta spaghetti"),
            .init(icon: "🍜", keywords: "noodles ramen zuppa"),
            .init(icon: "🍣", keywords: "sushi pesce giapponese"),
            .init(icon: "🍦", keywords: "gelato dolce"),
            .init(icon: "🍫", keywords: "cioccolato dolce"),
            .init(icon: "🍪", keywords: "biscotto dolce"),
            .init(icon: "🍩", keywords: "ciambella dolce"),
            .init(icon: "🥛", keywords: "latte bevanda"),
            .init(icon: "☕️", keywords: "caffe bevanda colazione"),
            .init(icon: "🍺", keywords: "birra alcol"),
            .init(icon: "🍷", keywords: "vino alcol rosso"),
            .init(icon: "🍾", keywords: "spumante champagne bottiglia"),
            .init(icon: "🥤", keywords: "bibita lattina coca"),
            .init(icon: "🧃", keywords: "succo di frutta"),
            .init(icon: "🧂", keywords: "sale spezie"),
            .init(icon: "🍽", keywords: "piatto posate"),
            .init(icon: "🥣", keywords: "ciotola cereali zuppa"),
            .init(icon: "🛍️", keywords: "spesa busta altro")
        ]
        
        // 2. PROTEINE ANIMALI (Solo cose commestibili!)
        let animalItems: [EmojiItem] = [
            .init(icon: "🐟", keywords: "pesce fresco mare"),
            .init(icon: "🐠", keywords: "pesce"),
            .init(icon: "🐡", keywords: "pesce"),
            .init(icon: "🐙", keywords: "polpo"),
            .init(icon: "🦑", keywords: "calamaro"),
            .init(icon: "🦐", keywords: "gambero gamberetto"),
            .init(icon: "🦞", keywords: "aragosta"),
            .init(icon: "🦀", keywords: "granchio"),
            .init(icon: "🐔", keywords: "pollo gallina"),
            .init(icon: "🍗", keywords: "pollo coscia carne"),
            .init(icon: "🦃", keywords: "tacchino"),
            .init(icon: "🦆", keywords: "anatra papera"),
            .init(icon: "🐷", keywords: "maiale"),
            .init(icon: "🍖", keywords: "carne osso"),
            .init(icon: "🥩", keywords: "carne bistecca rossa"),
            .init(icon: "🐮", keywords: "manzo mucca"),
            .init(icon: "🐂", keywords: "bue manzo"),
            .init(icon: "🐏", keywords: "agnello pecora"),
            .init(icon: "🐇", keywords: "coniglio")
        ]
        
        // 3. IGIENE & CASA (Solo prodotti da supermercato)
        let houseItems: [EmojiItem] = [
            .init(icon: "🧻", keywords: "carta igienica rotolo bagno"),
            .init(icon: "🧼", keywords: "sapone lavare mani"),
            .init(icon: "🧽", keywords: "spugna pulire"),
            .init(icon: "🧹", keywords: "scopa pulire"),
            .init(icon: "🧺", keywords: "cesto panni lavatrice"),
            .init(icon: "🧴", keywords: "crema shampoo bagnoschiuma detersivo"),
            .init(icon: "🪥", keywords: "spazzolino denti"),
            .init(icon: "🪒", keywords: "rasoio barba"),
            .init(icon: "🛁", keywords: "bagno schiuma"),
            .init(icon: "🩹", keywords: "cerotto"),
            .init(icon: "💊", keywords: "pillola medicina farmacia"),
            .init(icon: "🗑️", keywords: "spazzatura cestino sacchetti")
        ]
        
        let columns = [GridItem(.adaptive(minimum: 45))]
        
        var filteredSections: [(String, [EmojiItem])] {
            if searchText.isEmpty {
                return [
                    ("Cibo & Bevande", foodItems),
                    ("Carne & Pesce", animalItems),
                    ("Igiene & Casa", houseItems)
                ]
            } else {
                // Uniamo tutte le liste
                let allItems = foodItems + animalItems + houseItems
                
                // Filtriamo controllando se le parole chiave contengono il testo cercato
                let found = allItems.filter { item in
                    item.keywords.lowercased().contains(searchText.lowercased())
                }
                return found.isEmpty ? [] : [("Risultati Ricerca", found)]
            }
        }
        
        var body: some View {
            NavigationStack {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(filteredSections, id: \.0) { section in
                            Section(header: Text(section.0).font(.headline).padding(.leading, 5)) {
                                LazyVGrid(columns: columns, spacing: 10) {
                                    ForEach(section.1, id: \.self) { item in
                                        Button(action: {
                                            selectedEmoji = item.icon
                                            dismiss()
                                        }) {
                                            Text(item.icon)
                                                .font(.system(size: 40))
                                                .frame(width: 50, height: 50)
                                                .background(selectedEmoji == item.icon ? Color.blue.opacity(0.2) : Color.clear)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .navigationTitle("Scegli Icona")
                .navigationBarTitleDisplayMode(.inline)
                // Barra di ricerca
                .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Cerca (es. latte, pesce...)")
            }
        }
    }
}
