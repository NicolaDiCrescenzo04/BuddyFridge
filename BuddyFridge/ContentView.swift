import SwiftUI
import SwiftData

struct ContentView: View {
    // DATABASE: Ci serve per cancellare
    @Environment(\.modelContext) private var modelContext
    
    // QUERY: Legge i dati ordinati per scadenza
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    @State private var showAddItemSheet = false

    var body: some View {
        NavigationStack {
            VStack {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Il frigo è vuoto!",
                        systemImage: "refrigerator", // Icona di un frigo (simulata)
                        description: Text("Tappa su + per riempirlo.")
                    )
                } else {
                    List {
                        ForEach(items) { item in
                            HStack {
                                Text(item.emoji)
                                    .font(.title)
                                
                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.headline)
                                    // Formattiamo la data in modo semplice
                                    Text(item.expiryDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption)
                                        .foregroundStyle(item.isExpired ? .red : .secondary)
                                }
                                
                                Spacer()
                                
                                Text("x\(item.quantity)")
                                    .fontWeight(.bold)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                }
            }
            .navigationTitle("BuddyFridge")
            .toolbar {
                Button(action: { showAddItemSheet = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .sheet(isPresented: $showAddItemSheet) {
                AddItemView()
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}
