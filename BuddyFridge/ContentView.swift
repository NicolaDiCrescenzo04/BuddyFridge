import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        // TABVIEW: La struttura principale che tiene insieme Frigo e Spesa
        TabView {
            FridgeView()
                .tabItem {
                    Label("Inventario", systemImage: "refrigerator")
                }
            
            ShoppingListView()
                .tabItem {
                    Label("Spesa", systemImage: "list.bullet.clipboard")
                }
        }
    }
}

// --- LA VISTA FRIGO POTENZIATA (Raggruppata) ---
struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    // Carichiamo tutti i cibi ordinati per scadenza
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    @State private var showAddItemSheet = false
    
    // Variabili per gestire il suggerimento "Hai finito il latte, lo ricompri?"
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false

    // 1. RAGGRUPPAMENTO: Crea un dizionario "Nome Prodotto" -> [Lista di lotti]
    var groupedItems: [String: [FoodItem]] {
        Dictionary(grouping: items, by: { $0.name })
    }
    
    // 2. ORDINAMENTO: Prende i nomi dei prodotti in ordine alfabetico per la lista
    var sortedProductNames: [String] {
        groupedItems.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            VStack {
                // La nostra mascotte Buddy sempre presente
                BuddyView()
                
                if items.isEmpty {
                    ContentUnavailableView(
                        "Il frigo è vuoto!",
                        systemImage: "refrigerator",
                        description: Text("Tappa su + per riempirlo.")
                    )
                } else {
                    List {
                        // Ciclo sui NOMI dei prodotti (non sui singoli lotti)
                        ForEach(sortedProductNames, id: \.self) { productName in
                            // Controlliamo che ci siano dati (sicurezza)
                            if let batches = groupedItems[productName], let firstItem = batches.first {
                                
                                // Calcoliamo la quantità TOTALE sommando i vari lotti
                                let totalQuantity = batches.reduce(0) { $0 + $1.quantity }
                                
                                // 3. DISCLOSURE GROUP: La lista che si apre e chiude
                                DisclosureGroup {
                                    // --- CONTENUTO NASCOSTO (I singoli lotti) ---
                                    ForEach(batches) { batch in
                                        HStack {
                                            // Info scadenza e posizione
                                            VStack(alignment: .leading) {
                                                Text("Scade: \(batch.expiryDate.formatted(date: .numeric, time: .omitted))")
                                                    .foregroundStyle(batch.isExpired ? .red : .primary)
                                                    .font(.subheadline)
                                                Text(batch.location.rawValue)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            
                                            Spacer()
                                            
                                            // Quantità del singolo lotto
                                            Text("x\(batch.quantity)")
                                                .bold()
                                            
                                            // BOTTONE MANGIA (Forchetta)
                                            Button(action: { consumeItem(batch) }) {
                                                Image(systemName: "fork.knife.circle.fill")
                                                    .foregroundStyle(.blue)
                                                    .font(.title2)
                                            }
                                            .buttonStyle(.plain) // Importante per non cliccare la riga intera
                                            
                                            // BOTTONE BUTTA (Cestino)
                                            Button(action: { deleteItem(batch) }) {
                                                Image(systemName: "trash")
                                                    .foregroundStyle(.red)
                                            }
                                            .buttonStyle(.plain)
                                            .padding(.leading, 10)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                } label: {
                                    // --- INTESTAZIONE VISIBILE (Nome e Totale) ---
                                    HStack {
                                        Text(firstItem.emoji).font(.title2)
                                        Text(productName).font(.headline)
                                        Spacer()
                                        // Badge con il totale pezzi
                                        Text("\(totalQuantity)")
                                            .font(.caption)
                                            .fontWeight(.black)
                                            .padding(6)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Circle())
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
            .sheet(isPresented: $showAddItemSheet) {
                AddItemView()
            }
            // 4. ALERT INTELLIGENTE: Ti chiede se vuoi ricomprare
            .alert("Prodotto Finito!", isPresented: $showShopAlert) {
                Button("Sì, metti in lista") {
                    if let name = itemToAddToShop {
                        addToShoppingList(name)
                    }
                }
                Button("No, grazie", role: .cancel) { }
            } message: {
                Text("Hai finito \(itemToAddToShop ?? "il prodotto"). Vuoi aggiungerlo alla lista della spesa?")
            }
        }
    }

    // --- LOGICHE DI GESTIONE ---

    // Consuma un'unità. Se arriva a 0, cancella e controlla se era l'ultimo.
    private func consumeItem(_ item: FoodItem) {
        withAnimation {
            if item.quantity > 1 {
                item.quantity -= 1
            } else {
                // Era l'ultimo pezzo di questo lotto.
                // Prima di cancellare, controlliamo se ne hai altri in frigo.
                checkIfLastAndSuggest(item)
                modelContext.delete(item)
            }
        }
    }
    
    // Cancella direttamente (es. andato a male)
    private func deleteItem(_ item: FoodItem) {
        withAnimation {
            modelContext.delete(item)
        }
    }
    
    // Il cervello di Buddy: controlla se il frigo è rimasto senza quel prodotto
    private func checkIfLastAndSuggest(_ item: FoodItem) {
        // Cerchiamo altri lotti con lo stesso nome, ESCLUDENDO quello che stiamo cancellando ora
        let otherBatchesCount = items.filter {
            $0.name == item.name && $0.persistentModelID != item.persistentModelID
        }.count
        
        // Se il conteggio è 0, vuol dire che abbiamo finito tutte le scorte!
        if otherBatchesCount == 0 {
            itemToAddToShop = item.name
            
            // Se il prodotto è marcato come "Ricorrente" (isRecurring),
            // Buddy si attiva sicuramente.
            if item.isRecurring {
                showShopAlert = true
            } else {
                // Opzionale: possiamo decidere se chiedere anche per i non ricorrenti.
                // Per ora chiediamo sempre, è più comodo.
                showShopAlert = true
            }
        }
    }
    
    // Aggiunge alla lista spesa
    private func addToShoppingList(_ name: String) {
        let shopItem = ShoppingItem(name: name)
        modelContext.insert(shopItem)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [FoodItem.self, ShoppingItem.self], inMemory: true)
}
