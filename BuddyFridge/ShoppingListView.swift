import SwiftUI
import SwiftData
import UserNotifications

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \ShoppingItem.addedDate) private var shoppingItems: [ShoppingItem]
    
    @State private var newItemName: String = ""
    @State private var itemToMove: ShoppingItem?
    @FocusState private var isInputFocused: Bool

    // Colore di sfondo coerente con il Frigo
    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.12, blue: 0.18)
        } else {
            return Color(red: 0.95, green: 0.97, blue: 1.0)
        }
    }
    
    // Colore delle card (Bianco di giorno, Grigio scuro di notte)
    var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // 1. SFONDO
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // 2. BARRA DI INSERIMENTO MODERNA
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.gray)
                            
                            TextField("Aggiungi cose da comprare...", text: $newItemName)
                                .focused($isInputFocused)
                                .submitLabel(.done)
                                .onSubmit { addItem() }
                            
                            if !newItemName.isEmpty {
                                Button(action: { newItemName = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.gray.opacity(0.5))
                                }
                            }
                        }
                        .padding(12)
                        .background(cardBackground)
                        .clipShape(Capsule())
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                        
                        // Bottone "+" (Stile Pillola/Cerchio)
                        Button(action: addItem) {
                            ZStack {
                                Circle()
                                    .fill(newItemName.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                                    .frame(width: 45, height: 45)
                                    .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                                
                                Image(systemName: "plus")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 20, weight: .bold))
                            }
                        }
                        .disabled(newItemName.isEmpty)
                    }
                    .padding()
                    .background(backgroundColor) // Si fonde con lo sfondo
                    .zIndex(1) // Sta sopra la lista quando scorri
                    
                    // 3. LA LISTA SPESA A CARD
                    if shoppingItems.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "Lista Vuota",
                            systemImage: "cart",
                            description: Text("Aggiungi i prodotti che ti mancano.")
                        )
                        Spacer()
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(shoppingItems) { item in
                                    // Usiamo una riga personalizzata con Swipe
                                    ShoppingItemRow(item: item, cardBackground: cardBackground) {
                                        // Azione SPUNTA (Sposta in frigo)
                                        itemToMove = item
                                    } onDelete: {
                                        deleteItem(item)
                                    }
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationTitle("Lista Spesa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            
            // PANNELLO SPOSTA IN FRIGO
            .sheet(item: $itemToMove) { item in
                MoveToFridgeView(shoppingItem: item)
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // --- LOGICHE ---
    private func addItem() {
        guard !newItemName.isEmpty else { return }
        let newItem = ShoppingItem(name: newItemName)
        withAnimation {
            modelContext.insert(newItem)
        }
        newItemName = ""
        // Manteniamo il focus per inserimenti rapidi
        isInputFocused = true
    }
    
    private func deleteItem(_ item: ShoppingItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }
}

// --- RIGA PERSONALIZZATA (CARD CON SWIPE) ---
struct ShoppingItemRow: View {
    let item: ShoppingItem
    let cardBackground: Color
    let onCheck: () -> Void
    let onDelete: () -> Void
    
    // Stato per gestire lo swipe manuale
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Sfondo Rosso (Cestino nascosto sotto)
            Color.red
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .padding(.trailing, 20)
                }
            
            // Contenuto Bianco (La Card vera e propria)
            HStack(spacing: 15) {
                // CHECKBOX (Cerchio)
                Button(action: onCheck) {
                    ZStack {
                        // Bordo
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        
                        // Interno se selezionato (anche se sparisce subito, è bello vederlo)
                        if item.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 28, height: 28)
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                // NOME PRODOTTO
                Text(item.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(item.isCompleted)
                    .foregroundStyle(item.isCompleted ? .secondary : .primary)
                
                Spacer()
            }
            .padding(16)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            .offset(x: offset)
            // GESTURE DI SWIPE
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Permetti solo swipe a sinistra
                        if value.translation.width < 0 {
                            offset = value.translation.width
                        }
                    }
                    .onEnded { value in
                        withAnimation(.spring()) {
                            // Se trascini oltre 60pt, blocca aperto
                            if value.translation.width < -60 {
                                offset = -80
                                isSwiped = true
                            } else {
                                offset = 0
                                isSwiped = false
                            }
                        }
                    }
            )
            // Se è aperto il cestino, un tap chiude o elimina (qui impostato per eliminare se tappi rosso)
            .onTapGesture {
                if isSwiped { onDelete() }
            }
        }
        // Tap gesture generale per chiudere lo swipe se tappi fuori
        .onTapGesture {
            if isSwiped {
                withAnimation { offset = 0; isSwiped = false }
            }
        }
    }
}

// --- SOTTO-VISTA: IL PANNELLO SPOSTA IN FRIGO ---
struct MoveToFridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let shoppingItem: ShoppingItem
    
    @State private var expiryDate: Date = Date()
    @State private var quantity: Int = 1
    @State private var location: StorageLocation = .fridge
    @State private var selectedEmoji: String = "🛍️"
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Stai mettendo via:")) {
                    HStack {
                        TextField("", text: $selectedEmoji)
                            .font(.system(size: 40))
                            .multilineTextAlignment(.center)
                            .frame(width: 50)
                        
                        Text(shoppingItem.name)
                            .font(.headline)
                    }
                }
                
                Section(header: Text("Dove lo metti?")) {
                    Picker("Posizione", selection: $location) {
                        ForEach(StorageLocation.allCases, id: \.self) { loc in
                            Text(loc.rawValue).tag(loc)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...50)
                }
                
                Section(header: Text("Quando scade?")) {
                    DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                    
                    // BOTTONI RAPIDI
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("+3 gg") { addDays(3) }.buttonStyle(.bordered)
                            Button("+5 gg") { addDays(5) }.buttonStyle(.bordered)
                            Button("+1 sett") { addDays(7) }.buttonStyle(.bordered)
                            Button("+2 sett") { addDays(14) }.buttonStyle(.bordered)
                        }
                    }
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Metti in Frigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto!") { confirmMove() }
                }
            }
            .onAppear {
                // Cerca di indovinare l'icona appena apri
                selectedEmoji = guessIcon(for: shoppingItem.name)
            }
        }
    }
    
    private func confirmMove() {
        let newFood = FoodItem(
            name: shoppingItem.name,
            emoji: selectedEmoji,
            quantity: quantity,
            expiryDate: expiryDate,
            location: location
        )
        modelContext.insert(newFood)
        
        // Notifica
        let content = UNMutableNotificationContent()
        content.title = "Scadenza in arrivo! ⚠️"
        content.body = "'\(newFood.name)' sta per scadere."
        content.sound = .default
        var dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: expiryDate)
        dateComponents.hour = 9
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        modelContext.delete(shoppingItem)
        dismiss()
    }
    
    private func addDays(_ days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
            expiryDate = newDate
        }
    }
    
    // Funzione helper locale per indovinare l'icona
    private func guessIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("latte") { return "🥛" }
        if lower.contains("uov") { return "🥚" }
        if lower.contains("pan") { return "🍞" }
        if lower.contains("pasta") || lower.contains("spagh") { return "🍝" }
        if lower.contains("mela") { return "🍎" }
        if lower.contains("carne") || lower.contains("poll") { return "🥩" }
        if lower.contains("pesce") { return "🐟" }
        if lower.contains("pizza") { return "🍕" }
        if lower.contains("yogurt") { return "🥣" }
        if lower.contains("formag") { return "🧀" }
        if lower.contains("verdur") || lower.contains("insalat") { return "🥗" }
        return "🛍️"
    }
}
