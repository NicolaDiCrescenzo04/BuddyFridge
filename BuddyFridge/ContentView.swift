import SwiftUI
import SwiftData

struct ContentView: View {
    // Usiamo un colore personalizzato per lo sfondo (Ice Blue leggero)
    let backgroundColor = Color(red: 0.95, green: 0.97, blue: 1.0)

    init() {
        // Trucco per rendere la TabBar trasparente/bianca
        UITabBar.appearance().backgroundColor = UIColor.white
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
        .tint(.blue) // Colore dei tab attivi
    }
}

// --- VISTA FRIGO A SCHEDE (CARDS) ---
struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    let backgroundColor: Color // Riceviamo il colore di sfondo
    
    @State private var showAddItemSheet = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false

    var body: some View {
        // Raggruppamento dati
        let groupedItems = Dictionary(grouping: items, by: { $0.name })
        let sortedProductNames = groupedItems.keys.sorted()

        NavigationStack {
            ZStack {
                // 1. SFONDO COLORATO
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Buddy è fuori dalla lista, fisso in alto
                    BuddyView()
                        .padding(.bottom, 10)
                        .background(backgroundColor) // Si fonde con lo sfondo
                    
                    if items.isEmpty {
                        ContentUnavailableView("Frigo Vuoto", systemImage: "refrigerator", description: Text("Tappa + per iniziare."))
                    } else {
                        // 2. SCROLLVIEW AL POSTO DI LIST
                        ScrollView {
                            LazyVStack(spacing: 16) { // Spazio tra le card
                                ForEach(sortedProductNames, id: \.self) { productName in
                                    if let batches = groupedItems[productName] {
                                        // 3. COMPONENTE CARD PERSONALIZZATO
                                        ProductCard(
                                            productName: productName,
                                            batches: batches,
                                            onConsume: { batch in consumeItem(batch, allItems: items) },
                                            onDelete: { batch in deleteItem(batch) }
                                        )
                                    }
                                }
                            }
                            .padding() // Margine laterale
                            .padding(.bottom, 80) // Spazio per non coprire l'ultima card con la tabbar
                        }
                    }
                }
            }
            .navigationTitle("Inventario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbar {
                Button(action: { showAddItemSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.blue)
                        .shadow(radius: 2)
                }
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

    // --- LOGICA (Identica a prima) ---
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

// --- NUOVO COMPONENTE: LA CARD DEL PRODOTTO ---
struct ProductCard: View {
    let productName: String
    let batches: [FoodItem]
    let onConsume: (FoodItem) -> Void
    let onDelete: (FoodItem) -> Void
    
    @State private var isExpanded: Bool = false
    
    // Calcoliamo il colore della barra laterale in base alla scadenza peggiore
    var statusColor: Color {
        if batches.contains(where: { $0.isExpired }) { return .red }
        // Se scade entro 3 giorni
        let soonDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        if batches.contains(where: { $0.expiryDate <= soonDate }) { return .orange }
        return .green
    }
    
    var totalQuantity: Int { batches.reduce(0) { $0 + $1.quantity } }
    var firstItem: FoodItem? { batches.first }
    
    var body: some View {
        VStack(spacing: 0) {
            // --- HEADER DELLA CARD (Sempre visibile) ---
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack(spacing: 15) {
                    // Barra colorata laterale
                    Rectangle()
                        .fill(statusColor)
                        .frame(width: 5)
                        .frame(maxHeight: .infinity) // Si adatta all'altezza
                    
                    // Icona
                    Text(firstItem?.emoji ?? "📦")
                        .font(.system(size: 40))
                        .padding(.vertical, 10)
                    
                    // Testi
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        // Sottotitolo intelligente
                        if let first = firstItem {
                            if batches.count > 1 {
                                Text("\(batches.count) lotti diversi")
                                    .font(.caption).foregroundStyle(.secondary)
                            } else {
                                // CORRETTO QUI: .abbreviated invece di .medium
                                Text("Scade: \(first.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(first.isExpired ? .red : .secondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Badge Quantità Totale
                    Text("\(totalQuantity)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(statusColor.opacity(0.8)) // Colore coordinato
                        .clipShape(Circle())
                    
                    // Freccina
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .foregroundStyle(.gray)
                        .padding(.trailing, 10)
                }
                .background(Color.white) // Sfondo bianco della card
            }
            .buttonStyle(.plain) // Rimuove l'effetto click grigio standard
            
            // --- DETTAGLI (Visibili solo se espanso) ---
            if isExpanded {
                Divider() // Linea separatrice sottile
                
                VStack(spacing: 0) {
                    ForEach(batches) { batch in
                        HStack {
                            VStack(alignment: .leading) {
                                // CORRETTO ANCHE QUI
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
                            
                            // Controlli
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
                        .background(Color.gray.opacity(0.05)) // Sfondo leggermente diverso per i dettagli
                        
                        if batch.id != batches.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16)) // Angoli molto arrotondati
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2) // Ombra soft
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodItem.self, ShoppingItem.self], inMemory: true)
}
