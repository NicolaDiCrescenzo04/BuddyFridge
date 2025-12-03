import SwiftUI
import SwiftData

struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \ShoppingItem.addedDate) private var shoppingItems: [ShoppingItem]
    
    @State private var newItemName: String = ""
    @State private var showBoughtConfetti = false
    
    // Alert for "Moving to Fridge"
    @State private var itemToMove: ShoppingItem?

    var backgroundColor: Color { colorScheme == .dark ? Color(red: 0.10, green: 0.12, blue: 0.18) : Color(red: 0.95, green: 0.97, blue: 1.0) }

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // INPUT FIELD
                    HStack(spacing: 12) {
                        TextField("Cosa devi comprare?", text: $newItemName)
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .onSubmit { addItem() }
                        
                        Button(action: addItem) {
                            Image(systemName: "plus").bold().foregroundStyle(.white)
                                .frame(width: 44, height: 44).background(Color.blue).clipShape(Circle())
                        }
                    }
                    .padding()
                    
                    if shoppingItems.isEmpty {
                        Spacer()
                        ContentUnavailableView("Tutto preso!", systemImage: "cart", description: Text("La lista è vuota."))
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(shoppingItems) { item in
                                    ShoppingCard(item: item, onToggle: {
                                        buyItem(item)
                                    }, onDelete: {
                                        deleteItem(item)
                                    })
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Lista Spesa")
            .sheet(item: $itemToMove) { item in
                MoveToFridgeView(shoppingItem: item)
            }
        }
    }
    
    private func addItem() {
        guard !newItemName.isEmpty else { return }
        withAnimation { modelContext.insert(ShoppingItem(name: newItemName)) }
        newItemName = ""
    }
    
    private func deleteItem(_ item: ShoppingItem) {
        withAnimation { modelContext.delete(item) }
    }
    
    private func buyItem(_ item: ShoppingItem) {
        // Trigger the "Fly Over" flow -> Opens the Move Sheet
        itemToMove = item
    }
}

struct ShoppingCard: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            // 1. CHECK BUTTON (Moves to Inventory)
            Button(action: onToggle) {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundStyle(.gray)
            }
            .padding(.trailing, 8)
            
            // 2. TEXT
            Text(item.name)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            // 3. DELETE (Plain Trash)
            Button(action: onDelete) {
                Image(systemName: "trash").foregroundStyle(.red.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// --- HELPER VIEW: SPOSTA IN FRIGO ---
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
                        TextField("", text: $selectedEmoji).font(.system(size: 40)).frame(width: 50)
                        Text(shoppingItem.name).font(.headline)
                    }
                }
                
                Section(header: Text("Dove lo metti?")) {
                    Picker("Posizione", selection: $location) {
                        ForEach(StorageLocation.allCases, id: \.self) { loc in Text(loc.rawValue).tag(loc) }
                    }.pickerStyle(.segmented)
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...50)
                }
                
                Section(header: Text("Quando scade?")) {
                    DatePicker("Scadenza", selection: $expiryDate, displayedComponents: .date)
                    // Tasti Rapidi
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button("+3 gg") { addDays(3) }.buttonStyle(.bordered)
                            Button("+1 sett") { addDays(7) }.buttonStyle(.bordered)
                            Button("+2 sett") { addDays(14) }.buttonStyle(.bordered)
                        }
                    }.listRowInsets(EdgeInsets()).padding(.vertical, 8)
                }
            }
            .navigationTitle("Metti in Frigo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Fatto!") { confirmMove() } }
            }
            .onAppear {
                selectedEmoji = guessIcon(for: shoppingItem.name)
            }
        }
    }
    
    private func confirmMove() {
        let newFood = FoodItem(name: shoppingItem.name, emoji: selectedEmoji, quantity: quantity, expiryDate: expiryDate, location: location)
        modelContext.insert(newFood)
        NotificationManager.shared.scheduleNotification(for: newFood)
        modelContext.delete(shoppingItem)
        dismiss()
    }
    
    private func addDays(_ days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: Date()) { expiryDate = newDate }
    }
    
    private func guessIcon(for text: String) -> String {
        let lower = text.lowercased()
        if lower.contains("latte") { return "🥛" }
        if lower.contains("uov") { return "🥚" }
        if lower.contains("pan") { return "🍞" }
        if lower.contains("pasta") { return "🍝" }
        if lower.contains("mela") { return "🍎" }
        if lower.contains("pesce") { return "🐟" }
        return "🛍️"
    }
}
