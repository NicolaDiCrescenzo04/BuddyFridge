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
    @State private var hasExpiry: Bool = true
    @State private var expiryDate: Date = Date()
    @State private var location: StorageLocation
    
    // --- FOCUS & MODALI ---
    @FocusState private var isNameFocused: Bool
    @State private var showScanner = false
    @State private var isLoadingScan = false
    @State private var showEmojiPicker = false
    
    // Init personalizzato per Smart Defaults
    init(defaultLocation: StorageLocation = .fridge) {
        _location = State(initialValue: defaultLocation)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // SEZIONE 1: INPUT VELOCE
                    Section {
                        HStack(spacing: 12) {
                            // EMOJI BUTTON
                            Button(action: { showEmojiPicker = true }) {
                                ZStack {
                                    Circle().fill(Color.gray.opacity(0.1)).frame(width: 50, height: 50)
                                    Text(selectedEmoji).font(.system(size: 30))
                                }
                            }
                            .buttonStyle(.plain)
                            
                            // TEXT FIELD (Auto-Focus)
                            TextField("Nome prodotto...", text: $name)
                                .font(.title3)
                                .focused($isNameFocused)
                                .submitLabel(.next)
                                .onChange(of: name) { oldValue, newValue in
                                    if newValue.isEmpty { resetFields() }
                                }
                        }
                        .padding(.vertical, 4)
                        
                        // SUGGERIMENTI (Smart Suggestions)
                        if !name.isEmpty {
                            let suggestions = frequentItems.filter {
                                $0.name.localizedCaseInsensitiveContains(name) && $0.name != name
                            }
                            if !suggestions.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack {
                                        ForEach(suggestions) { item in
                                            Button(action: { applySuggestion(item) }) {
                                                HStack(spacing: 4) {
                                                    Text(item.emoji)
                                                    Text(item.name).fontWeight(.semibold)
                                                }
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .cornerRadius(12)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .listRowInsets(EdgeInsets())
                                .padding(.bottom, 8)
                            }
                        }
                    } header: {
                        Text("Cosa stai aggiungendo?")
                    }
                    
                    // SEZIONE 2: DETTAGLI & POSIZIONE (Smart Default applicato)
                    Section {
                        Picker("Posizione", selection: $location) {
                            ForEach(StorageLocation.allCases, id: \.self) { loc in
                                Text(loc.rawValue).tag(loc)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 4)
                        
                        Stepper("Quantità: \(quantity)", value: $quantity, in: 1...100)
                        
                        HStack {
                            Text("Peso/Unità (Opzionale)")
                            Spacer()
                            TextField("0", value: $measureValue, format: .number).keyboardType(.decimalPad).frame(width: 50).multilineTextAlignment(.trailing)
                            Picker("", selection: $measureUnit) { ForEach(MeasureUnit.allCases, id: \.self) { unit in Text(unit.rawValue).tag(unit) } }.labelsHidden()
                        }
                    }
                    
                    // SEZIONE 3: SCADENZA (Quick Actions)
                    Section {
                        Toggle("Ha una scadenza?", isOn: $hasExpiry)
                        
                        if hasExpiry {
                            DatePicker("Data", selection: $expiryDate, displayedComponents: .date)
                            
                            // QUICK DATES GRID
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 10) {
                                QuickDateButton(icon: "sun.max", label: "+2 gg", days: 2, action: setDate)
                                QuickDateButton(icon: "calendar", label: "+4 gg", days: 4, action: setDate)
                                QuickDateButton(icon: "1.circle", label: "1 Sett", days: 7, action: setDate)
                                QuickDateButton(icon: "2.circle", label: "2 Sett", days: 14, action: setDate)
                            }
                            .padding(.top, 8)
                        }
                    } header: {
                        Text("Quando scade?")
                    }
                }
                
                // BARCODE SCANNER: Large Floating Action Button
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(radius: 4, y: 2)
                        }
                        .padding()
                    }
                    Spacer()
                }
                
                if isLoadingScan {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView("Cerco prodotto...").padding().background(.white).cornerRadius(10)
                }
            }
            .navigationTitle("Nuovo Cibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Chiudi") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveItem() }.bold().disabled(name.isEmpty)
                }
            }
            .onAppear {
                // ACTIVE KEYBOARD IMMEDIATELY
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFocused = true
                }
            }
            .sheet(isPresented: $showScanner) {
                ScannerView { code in handleScan(code: code) }.ignoresSafeArea()
            }
            .sheet(isPresented: $showEmojiPicker) {
                FoodEmojiPicker(selectedEmoji: $selectedEmoji)
            }
        }
    }
    
    // --- LOGICA ---
    private func setDate(days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
            withAnimation { self.expiryDate = newDate }
        }
    }
    
    private func applySuggestion(_ item: FrequentItem) {
        withAnimation {
            self.name = item.name; self.selectedEmoji = item.emoji
            self.quantity = item.defaultQuantity; self.location = item.defaultLocation
            if let days = item.shelfLifeDays {
                self.hasExpiry = true
                self.expiryDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
            }
        }
    }
    
    private func resetFields() { selectedEmoji = "🛍️"; quantity = 1 }
    
    private func handleScan(code: String) {
        isLoadingScan = true
        Task {
            if let product = await ProductLibrary.shared.fetchProductByBarcode(code: code) {
                name = product.name; selectedEmoji = product.emoji
                if product.category == "Congelatore" { location = .freezer }
                else if product.category == "Frigo" { location = .fridge }
                else { location = .pantry }
            } else { name = "Prodotto sconosciuto" }
            isLoadingScan = false
        }
    }
    
    private func saveItem() {
        let finalDate: Date? = hasExpiry ? expiryDate : nil
        let newItem = FoodItem(name: name, emoji: selectedEmoji, quantity: quantity, expiryDate: finalDate, location: location, measureValue: measureValue, measureUnit: measureUnit)
        modelContext.insert(newItem)
        if let _ = finalDate { NotificationManager.shared.scheduleNotification(for: newItem) }
        updateFrequencyHistory(finalDate: finalDate)
        dismiss()
    }
    
    private func updateFrequencyHistory(finalDate: Date?) {
        let shelfLife = finalDate.flatMap { Calendar.current.dateComponents([.day], from: Date(), to: $0).day }
        if let existing = frequentItems.first(where: { $0.name.lowercased() == name.lowercased() }) {
            existing.lastUsed = Date()
        } else {
            modelContext.insert(FrequentItem(name: name, emoji: selectedEmoji, defaultQuantity: quantity, defaultMeasureValue: measureValue, defaultMeasureUnit: measureUnit, defaultLocation: location, isRecurring: isRecurring, shelfLifeDays: shelfLife))
        }
    }
    
    // Componente Tasto Rapido
    struct QuickDateButton: View {
        let icon: String
        let label: String
        let days: Int
        let action: (Int) -> Void
        
        var body: some View {
            Button(action: { action(days) }) {
                VStack(spacing: 4) {
                    Image(systemName: icon).font(.title3)
                    Text(label).font(.caption2).fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
}

// --- EMOJI PICKER COMPONENTS ---

struct EmojiItem: Hashable {
    let icon: String
    let keywords: String
}

struct FoodEmojiPicker: View {
    @Binding var selectedEmoji: String
    @Environment(\.dismiss) var dismiss
    
    @State private var searchText = ""
    
    // 1. CIBO
    let foodItems: [EmojiItem] = [
        .init(icon: "🍎", keywords: "mela frutta"), .init(icon: "🍐", keywords: "pera"), .init(icon: "🍊", keywords: "arancia"),
        .init(icon: "🍋", keywords: "limone"), .init(icon: "🍌", keywords: "banana"), .init(icon: "🍉", keywords: "anguria"),
        .init(icon: "🍇", keywords: "uva"), .init(icon: "🍓", keywords: "fragola"), .init(icon: "🫐", keywords: "mirtilli"),
        .init(icon: "🍒", keywords: "ciliegie"), .init(icon: "🍑", keywords: "pesca"), .init(icon: "🥭", keywords: "mango"),
        .init(icon: "🍍", keywords: "ananas"), .init(icon: "🍅", keywords: "pomodoro"), .init(icon: "🍆", keywords: "melanzana"),
        .init(icon: "🥑", keywords: "avocado"), .init(icon: "🥦", keywords: "broccoli"), .init(icon: "🥬", keywords: "lattuga"),
        .init(icon: "🥒", keywords: "cetriolo"), .init(icon: "🌶", keywords: "peperoncino"), .init(icon: "🫑", keywords: "peperone"),
        .init(icon: "🌽", keywords: "mais"), .init(icon: "🥕", keywords: "carota"), .init(icon: "🥔", keywords: "patata"),
        .init(icon: "🧅", keywords: "cipolla"), .init(icon: "🧄", keywords: "aglio"), .init(icon: "🥖", keywords: "pane"),
        .init(icon: "🍞", keywords: "pane toast"), .init(icon: "🥐", keywords: "brioche"), .init(icon: "🧀", keywords: "formaggio"),
        .init(icon: "🥚", keywords: "uovo"), .init(icon: "🥓", keywords: "bacon"), .init(icon: "🍔", keywords: "hamburger"),
        .init(icon: "🍟", keywords: "patatine"), .init(icon: "🍕", keywords: "pizza"), .init(icon: "🍝", keywords: "pasta"),
        .init(icon: "🍜", keywords: "ramen"), .init(icon: "🍣", keywords: "sushi"), .init(icon: "🍦", keywords: "gelato"),
        .init(icon: "🍫", keywords: "cioccolato"), .init(icon: "🍪", keywords: "biscotto"), .init(icon: "🍩", keywords: "ciambella"),
        .init(icon: "🥛", keywords: "latte"), .init(icon: "☕️", keywords: "caffe"), .init(icon: "🍺", keywords: "birra"),
        .init(icon: "🍷", keywords: "vino"), .init(icon: "🍾", keywords: "spumante"), .init(icon: "🥤", keywords: "bibita"),
        .init(icon: "🧃", keywords: "succo"), .init(icon: "🧂", keywords: "sale"), .init(icon: "🍽", keywords: "piatto"),
        .init(icon: "🥣", keywords: "ciotola"), .init(icon: "🛍️", keywords: "spesa")
    ]
    
    // 2. PROTEINE & ANIMALI
    let animalItems: [EmojiItem] = [
        .init(icon: "🐟", keywords: "pesce"), .init(icon: "🐠", keywords: "pesce"), .init(icon: "🐡", keywords: "pesce"),
        .init(icon: "🐙", keywords: "polpo"), .init(icon: "🦑", keywords: "calamaro"), .init(icon: "🦐", keywords: "gambero"),
        .init(icon: "🦞", keywords: "aragosta"), .init(icon: "🦀", keywords: "granchio"), .init(icon: "🐔", keywords: "pollo"),
        .init(icon: "🍗", keywords: "pollo"), .init(icon: "🦃", keywords: "tacchino"), .init(icon: "🦆", keywords: "anatra"),
        .init(icon: "🐷", keywords: "maiale"), .init(icon: "🍖", keywords: "carne"), .init(icon: "🥩", keywords: "bistecca"),
        .init(icon: "🐮", keywords: "manzo"), .init(icon: "🐂", keywords: "manzo"), .init(icon: "🐏", keywords: "agnello"),
        .init(icon: "🐇", keywords: "coniglio")
    ]
    
    // 3. IGIENE & CASA
    let houseItems: [EmojiItem] = [
        .init(icon: "🧻", keywords: "carta igienica"), .init(icon: "🧼", keywords: "sapone"), .init(icon: "🧽", keywords: "spugna"),
        .init(icon: "🧹", keywords: "scopa"), .init(icon: "🧺", keywords: "panni"), .init(icon: "🧴", keywords: "crema detersivo"),
        .init(icon: "🪥", keywords: "spazzolino"), .init(icon: "🪒", keywords: "rasoio"), .init(icon: "🛁", keywords: "bagno"),
        .init(icon: "🩹", keywords: "cerotto"), .init(icon: "💊", keywords: "farmacia"), .init(icon: "🗑️", keywords: "spazzatura")
    ]
    
    let columns = [GridItem(.adaptive(minimum: 45))]
    
    var filteredSections: [(String, [EmojiItem])] {
        if searchText.isEmpty {
            return [("Cibo", foodItems), ("Carne/Pesce", animalItems), ("Casa", houseItems)]
        } else {
            let all = foodItems + animalItems + houseItems
            let found = all.filter { $0.keywords.localizedCaseInsensitiveContains(searchText) }
            return found.isEmpty ? [] : [("Risultati", found)]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(filteredSections, id: \.0) { section in
                        Section(header: Text(section.0).font(.headline).padding(.leading)) {
                            LazyVGrid(columns: columns, spacing: 10) {
                                ForEach(section.1, id: \.self) { item in
                                    Button(action: { selectedEmoji = item.icon; dismiss() }) {
                                        Text(item.icon).font(.system(size: 40))
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
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        }
    }
}
