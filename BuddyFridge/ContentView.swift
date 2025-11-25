import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            FridgeView().tabItem { Label("Inventario", systemImage: "refrigerator") }
            ShoppingListView().tabItem { Label("Spesa", systemImage: "list.bullet.clipboard") }
        }
    }
}

struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    @State private var showAddItemSheet = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false

    var body: some View {
        // Raggruppamento ottimizzato
        let groupedItems = Dictionary(grouping: items, by: { $0.name })
        let sortedProductNames = groupedItems.keys.sorted()

        NavigationStack {
            VStack {
                BuddyView()
                
                if items.isEmpty {
                    ContentUnavailableView("Frigo Vuoto", systemImage: "refrigerator", description: Text("Tappa + per iniziare."))
                } else {
                    List {
                        ForEach(sortedProductNames, id: \.self) { productName in
                            if let batches = groupedItems[productName], let firstItem = batches.first {
                                // Somma totale dei PEZZI (es. 3 confezioni totali)
                                let totalQuantity = batches.reduce(0) { $0 + $1.quantity }
                                
                                DisclosureGroup {
                                    ForEach(batches) { batch in
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Scade: \(batch.expiryDate.formatted(date: .numeric, time: .omitted))")
                                                    .foregroundStyle(batch.isExpired ? .red : .primary)
                                                    .font(.subheadline)
                                                
                                                // Mostriamo dove si trova e se è ricorrente
                                                HStack {
                                                    Text(batch.location.rawValue)
                                                    if batch.isRecurring {
                                                        Image(systemName: "arrow.triangle.2.circlepath").font(.caption2)
                                                    }
                                                }
                                                .font(.caption2).foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // --- QUI LA MODIFICA CHIAVE ---
                                            // Se c'è un peso, scriviamo: "2 x 500g"
                                            // Se no, scriviamo solo "x2"
                                            if !batch.formattedMeasure.isEmpty {
                                                Text("\(batch.quantity) x \(batch.formattedMeasure)")
                                                    .bold()
                                                    .font(.callout)
                                            } else {
                                                Text("x\(batch.quantity)")
                                                    .bold()
                                            }
                                            // -----------------------------
                                            
                                            Button(action: { consumeItem(batch, allItems: items) }) {
                                                Image(systemName: "fork.knife.circle.fill")
                                                    .foregroundStyle(.blue).font(.title2)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Button(action: { deleteItem(batch) }) {
                                                Image(systemName: "trash").foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain).padding(.leading, 10)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                } label: {
                                    HStack {
                                        Text(firstItem.emoji).font(.title2)
                                        Text(productName).font(.headline)
                                        Spacer()
                                        Text("\(totalQuantity)")
                                            .font(.caption).fontWeight(.black)
                                            .padding(6).background(Color.blue.opacity(0.1)).clipShape(Circle())
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Inventario")
            .toolbar {
                Button(action: { showAddItemSheet = true }) {
                    Image(systemName: "plus.circle.fill").font(.title2)
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

    private func consumeItem(_ item: FoodItem, allItems: [FoodItem]) {
        withAnimation {
            if item.quantity > 1 {
                item.quantity -= 1
            } else {
                checkIfLastAndSuggest(item, allItems: allItems)
                modelContext.delete(item)
            }
        }
    }
    
    private func deleteItem(_ item: FoodItem) { withAnimation { modelContext.delete(item) } }
    
    private func checkIfLastAndSuggest(_ item: FoodItem, allItems: [FoodItem]) {
        let otherBatchesCount = allItems.filter {
            $0.name == item.name && $0.persistentModelID != item.persistentModelID
        }.count
        if otherBatchesCount == 0 {
            itemToAddToShop = item.name
            showShopAlert = true
        }
    }
    
    private func addToShoppingList(_ name: String) {
        let shopItem = ShoppingItem(name: name)
        modelContext.insert(shopItem)
    }
}
