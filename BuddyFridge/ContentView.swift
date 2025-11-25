import SwiftUI
import SwiftData

struct ContentView: View {
    // Rileviamo se siamo in Dark Mode
    @Environment(\.colorScheme) var colorScheme

    // Calcoliamo il colore di sfondo in base alla modalità
    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.12, blue: 0.18) // Blu notte scuro
        } else {
            return Color(red: 0.95, green: 0.97, blue: 1.0) // Azzurro ghiaccio
        }
    }

    var body: some View {
        TabView {
            FridgeView(backgroundColor: backgroundColor)
                .tabItem {
                    Label("Inventario", systemImage: "refrigerator")
                }
            
            ShoppingListView()
                .tabItem {
                    Label("Spesa", systemImage: "list.bullet.clipboard")
                }
        }
        .tint(.blue)
    }
}

// --- VISTA FRIGO A SCHEDE (CARDS) ---
struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    let backgroundColor: Color
    
    @State private var showAddItemSheet = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false

    var body: some View {
        let groupedItems = Dictionary(grouping: items, by: { $0.name })
        let sortedProductNames = groupedItems.keys.sorted()

        NavigationStack {
            ZStack {
                // 1. SFONDO
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    BuddyView()
                        .padding(.bottom, 10)
                        .background(backgroundColor)
                    
                    if items.isEmpty {
                        ContentUnavailableView("Frigo Vuoto", systemImage: "refrigerator", description: Text("Tappa + per iniziare."))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(sortedProductNames, id: \.self) { productName in
                                    if let batches = groupedItems[productName] {
                                        ProductCard(
                                            productName: productName,
                                            batches: batches,
                                            onConsume: { batch in consumeItem(batch, allItems: items) },
                                            onDelete: { batch in deleteItem(batch) }
                                        )
                                    }
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                    }
                }
            }
            .navigationTitle("Inventario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbar {
                // --- BOTTONE PIÙ FIXATO ---
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddItemSheet = true }) {
                        // Invece di usare un font, disegniamo un cerchio vero
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 32, height: 32)
                                // Ombra delicata che non "sbava"
                                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold)) // Icona più piccola e grassa
                                .foregroundStyle(.white) // Sempre bianca, anche in dark mode
                        }
                    }
                }
                // --------------------------
            }
            .sheet(isPresented: $showAddItemSheet) { AddItemView() }
            .alert("Prodotto Finito!", isPresented: $showShopAlert) {
                Button("Sì, metti in lista") { if let name = itemToAddToShop { addToShoppingList(name) } }
                Button("No, grazie", role: .cancel) { }
            } message: {
                Text("Hai finito \(itemToAddToShop ?? "il prodotto"). Vuoi aggiungerlo alla lista della spesa?")
            }
        }
    }

    // --- LOGICA ---
    private func consumeItem(_ item: FoodItem, allItems: [FoodItem]) {
        withAnimation {
            if item.quantity > 1 { item.quantity -= 1 }
            else { checkIfLastAndSuggest(item, allItems: allItems); modelContext.delete(item) }
        }
    }
    
    private func deleteItem(_ item: FoodItem) { withAnimation { modelContext.delete(item) } }
    
    private func checkIfLastAndSuggest(_ item: FoodItem, allItems: [FoodItem]) {
        let otherBatchesCount = allItems.filter { $0.name == item.name && $0.persistentModelID != item.persistentModelID }.count
        if otherBatchesCount == 0 { itemToAddToShop = item.name; showShopAlert = true }
    }
    
    private func addToShoppingList(_ name: String) {
        modelContext.insert(ShoppingItem(name: name))
    }
}

// --- CARD DEL PRODOTTO (Dark Mode Ready) ---
struct ProductCard: View {
    let productName: String
    let batches: [FoodItem]
    let onConsume: (FoodItem) -> Void
    let onDelete: (FoodItem) -> Void
    
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var statusColor: Color {
        if batches.contains(where: { $0.isExpired }) { return .red }
        let soonDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        if batches.contains(where: { $0.expiryDate <= soonDate }) { return .orange }
        return .green
    }
    
    var totalQuantity: Int { batches.reduce(0) { $0 + $1.quantity } }
    var firstItem: FoodItem? { batches.first }
    
    var cardBackground: Color {
        Color(uiColor: .secondarySystemGroupedBackground)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- HEADER ---
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack(spacing: 15) {
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: 5)
                        .frame(maxHeight: .infinity)
                    
                    Text(firstItem?.emoji ?? "📦")
                        .font(.system(size: 40))
                        .padding(.vertical, 10)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        if let first = firstItem {
                            if batches.count > 1 {
                                Text("\(batches.count) lotti diversi")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Scade: \(first.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(first.isExpired ? .red : .secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(totalQuantity)")
                        .font(.title3).fontWeight(.bold).foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(statusColor.opacity(0.8))
                        .clipShape(Circle())
                    
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.gray)
                        .padding(.trailing, 10)
                }
                .background(cardBackground)
            }
            .buttonStyle(.plain)
            
            // --- DETTAGLI ---
            if isExpanded {
                Divider()
                
                VStack(spacing: 0) {
                    ForEach(batches) { batch in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Scadenza: \(batch.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.subheadline)
                                    .foregroundStyle(batch.isExpired ? .red : .primary)
                                
                                HStack {
                                    Text(batch.location.rawValue)
                                    if !batch.formattedMeasure.isEmpty {
                                        Text("• \(batch.formattedMeasure)")
                                    }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 15) {
                                Text("x\(batch.quantity)").bold()
                                
                                Button(action: { onConsume(batch) }) {
                                    Image(systemName: "fork.knife")
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Color.blue)
                                        .clipShape(Circle())
                                }
                                
                                Button(action: { onDelete(batch) }) {
                                    Image(systemName: "trash")
                                        .foregroundStyle(.white)
                                        .frame(width: 30, height: 30)
                                        .background(Color.red.opacity(0.8))
                                        .clipShape(Circle())
                                }
                            }
                        }
                        .padding()
                        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05))
                        
                        if batch.id != batches.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
