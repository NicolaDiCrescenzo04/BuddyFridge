import SwiftUI
import SwiftData
import UserNotifications

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.addedDate) private var shoppingItems: [ShoppingItem]
    
    @State private var newItemName: String = ""
    
    // Variabile per gestire l'oggetto che stiamo spostando nel frigo
    @State private var itemToMove: ShoppingItem?

    var body: some View {
        NavigationStack {
            VStack {
                // CAMPO DI INSERIMENTO
                HStack {
                    TextField("Aggiungi alla lista...", text: $newItemName)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.done)
                        .onSubmit { addItem() }
                    
                    Button(action: addItem) {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .disabled(newItemName.isEmpty)
                }
                .padding()
                
                // LA LISTA
                if shoppingItems.isEmpty {
                    ContentUnavailableView(
                        "Lista vuota",
                        systemImage: "cart",
                        description: Text("Aggiungi cosa devi comprare.")
                    )
                } else {
                    List {
                        ForEach(shoppingItems) { item in
                            HStack {
                                // Tasto "Comprato"
                                Button(action: {
                                    // Invece di spuntare e basta, apriamo il pannello
                                    itemToMove = item
                                }) {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.gray)
                                        .font(.title2)
                                }
                                .buttonStyle(.plain)
                                
                                Text(item.name)
                                Spacer()
                            }
                            .swipeActions {
                                Button("Elimina", role: .destructive) {
                                    modelContext.delete(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista Spesa 🛒")
            // IL PANNELLO MAGICO "SPOSTA IN FRIGO"
            .sheet(item: $itemToMove) { item in
                MoveToFridgeView(shoppingItem: item)
                    .presentationDetents([.medium]) // Occupa solo metà schermo
            }
        }
    }
    
    private func addItem() {
        guard !newItemName.isEmpty else { return }
        let newItem = ShoppingItem(name: newItemName)
        modelContext.insert(newItem)
        newItemName = ""
    }
}

// --- SOTTO-VISTA: IL PANNELLO CHE COMPARE QUANDO COMPRI ---
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
                        Text(selectedEmoji).font(.largeTitle)
                        Text(shoppingItem.name).font(.headline)
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
                // Appena apre, indovina l'icona
                selectedEmoji = guessIcon(for: shoppingItem.name)
            }
        }
    }
    
    // Logica per spostare da Spesa -> Frigo
    private func confirmMove() {
        // 1. Crea il nuovo cibo nel frigo
        let newFood = FoodItem(
            name: shoppingItem.name,
            emoji: selectedEmoji,
            quantity: quantity,
            expiryDate: expiryDate,
            location: location
        )
        modelContext.insert(newFood)
        
        // 2. Programma notifica
        scheduleNotification(for: newFood)
        
        // 3. Cancella dalla lista della spesa
        modelContext.delete(shoppingItem)
        
        dismiss()
    }
    
    private func addDays(_ days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) {
            expiryDate = newDate
        }
    }
    
    // Ricopio qui la funzione icone per comodità
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
