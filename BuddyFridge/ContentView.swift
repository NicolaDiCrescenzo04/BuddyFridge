import SwiftUI
import SwiftData

// 1. NUOVO ENUM PER IL FILTRO (Include "Tutto")
enum FilterScope: String, CaseIterable {
    case all = "Tutto"
    case fridge = "Frigo"
    case freezer = "Congelatore"
    case pantry = "Dispensa"
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme

    var backgroundColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.10, green: 0.12, blue: 0.18)
        } else {
            return Color(red: 0.95, green: 0.97, blue: 1.0)
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

struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) var colorScheme
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    let backgroundColor: Color
    
    @State private var showAddItemSheet = false
    @State private var isBuddyOpen = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false
    
    // NUOVO STATO: Gestisce l'apertura delle impostazioni
    @State private var showSettings = false
    
    @Namespace private var animationNamespace

    var body: some View {
        let groupedItems = Dictionary(grouping: items, by: { $0.name })
        let sortedProductNames = groupedItems.keys.sorted()

        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    if items.isEmpty {
                        // --- CASO 1: FRIGO VUOTO ---
                        Spacer()
                        
                        BuddyView(isDoorOpen: $isBuddyOpen) {
                            apriFrigo()
                        }
                        .matchedGeometryEffect(id: "BuddyFridge", in: animationNamespace)
                        .frame(maxHeight: .infinity)
                        
                        Spacer()
                        
                    } else {
                        // --- CASO 2: FRIGO PIENO ---
                        BuddyView(isDoorOpen: $isBuddyOpen) {
                            apriFrigo()
                        }
                        .padding(.bottom, 10)
                        .background(backgroundColor)
                        .matchedGeometryEffect(id: "BuddyFridge", in: animationNamespace)
                        
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
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .padding()
                            .padding(.bottom, 80)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle(items.isEmpty ? "" : "Inventario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            
            // --- NUOVO: BOTTONE IMPOSTAZIONI (INGRANAGGIO) ---
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape") // Icona ingranaggio discreta
                            .foregroundStyle(.gray)
                    }
                }
            }
            // ------------------------------------------------
            
            // Scheda Aggiunta Cibo
            .sheet(isPresented: $showAddItemSheet, onDismiss: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    isBuddyOpen = false
                }
            }) {
                AddItemView()
                    .presentationDetents([.fraction(0.65)])
                    .presentationDragIndicator(.visible)
            }
            
            // NUOVO: Scheda Impostazioni
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            
            // Alert Spesa
            .alert("Prodotto Finito!", isPresented: $showShopAlert) {
                Button("Sì, metti in lista") { if let name = itemToAddToShop { addToShoppingList(name) } }
                Button("No, grazie", role: .cancel) { }
            } message: {
                Text("Hai finito \(itemToAddToShop ?? "il prodotto"). Vuoi aggiungerlo alla lista della spesa?")
            }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: items.isEmpty)
    }

    // --- FUNZIONE PER APRIRE IL FRIGO ---
    private func apriFrigo() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            isBuddyOpen = true
        }
        showAddItemSheet = true
    }

    // --- ALTRE LOGICHE ---
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

// --- CARD DEL PRODOTTO ---
struct ProductCard: View {
    let productName: String
    let batches: [FoodItem]
    let onConsume: (FoodItem) -> Void
    let onDelete: (FoodItem) -> Void
    // NESSUN parametro 'onEdit' qui
    
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
    var cardBackground: Color { Color(uiColor: .secondarySystemGroupedBackground) }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                HStack(spacing: 15) {
                    Rectangle().fill(statusColor).frame(width: 5).frame(maxHeight: .infinity)
                    Text(firstItem?.emoji ?? "📦").font(.system(size: 40)).padding(.vertical, 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(productName).font(.headline).foregroundStyle(.primary)
                        if let first = firstItem {
                            if batches.count > 1 {
                                Text("\(batches.count) lotti diversi").font(.caption).foregroundStyle(.secondary)
                            } else {
                                Text("Scade: \(first.expiryDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(first.isExpired ? .red : .secondary)
                            }
                        }
                    }
                    Spacer()
                    Text("\(totalQuantity)").font(.title3).fontWeight(.bold).foregroundStyle(.white)
                        .frame(width: 40, height: 40).background(statusColor.opacity(0.8)).clipShape(Circle())
                    Image(systemName: "chevron.down").rotationEffect(.degrees(isExpanded ? 180 : 0)).foregroundStyle(.gray).padding(.trailing, 10)
                }
                .background(cardBackground)
            }
            .buttonStyle(.plain)
            
            if isExpanded {
                Divider()
                VStack(spacing: 0) {
                    ForEach(batches) { batch in
                        SwipeableBatchRow(onDelete: { onDelete(batch) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Scade: \(batch.expiryDate.formatted(date: .abbreviated, time: .omitted))").font(.subheadline).foregroundStyle(batch.isExpired ? .red : .primary)
                                    HStack {
                                        Text(batch.location.rawValue)
                                        if !batch.formattedMeasure.isEmpty { Text("• \(batch.formattedMeasure)") }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(action: { onConsume(batch) }) {
                                    HStack(spacing: 4) { Image(systemName: "fork.knife"); Text("Mangia").fontWeight(.semibold) }
                                        .font(.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundStyle(.white).clipShape(Capsule()).shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                                }.padding(.trailing, 5)
                                Text("x\(batch.quantity)").bold().frame(minWidth: 25)
                            }
                            .padding().background(cardBackground)
                        }
                        if batch.id != batches.last?.id { Divider().padding(.leading) }
                    }
                }
            }
        }
        .background(cardBackground).clipShape(RoundedRectangle(cornerRadius: 16)).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

// --- RIGA SWIPEABLE ---
struct SwipeableBatchRow<Content: View>: View {
    var onDelete: () -> Void
    var onEdit: () -> Void
    @ViewBuilder var content: Content
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped: Bool = false
    let buttonWidth: CGFloat = 70
    
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) {
                Spacer()
                Button(action: { withAnimation { offset = 0; isSwiped = false }; onEdit() }) {
                    ZStack { Color.orange; Image(systemName: "pencil").foregroundStyle(.white).font(.title2) }
                }.frame(width: buttonWidth)
                Button(action: { withAnimation { offset = 0; isSwiped = false }; onDelete() }) {
                    ZStack { Color.red; Image(systemName: "trash.fill").foregroundStyle(.white).font(.title2) }
                }.frame(width: buttonWidth)
            }
            content.offset(x: offset)
                .gesture(DragGesture().onChanged { value in if value.translation.width < 0 { offset = value.translation.width } }
                    .onEnded { value in withAnimation(.spring()) { if value.translation.width < -100 { offset = -(buttonWidth * 2); isSwiped = true } else { offset = 0; isSwiped = false } } })
        }
        .onTapGesture { if isSwiped { withAnimation { offset = 0; isSwiped = false } } }
    }
}
