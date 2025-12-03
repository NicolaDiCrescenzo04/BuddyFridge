import SwiftUI
import SwiftData

// ENUM PER IL FILTRO
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
    
    // Stati Gestione
    @State private var showAddItemSheet = false
    @State private var isBuddyOpen = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false
    @State private var showSettings = false
    @State private var itemToEdit: FoodItem?
    
    // STATO RICERCA E FILTRI
    @State private var searchText = ""
    @State private var selectedFilter: FilterScope = .all
    
    // EXPAND LOGIC
    @State private var isExpanded: Bool = false
    
    // DIALOGS
    @State private var itemPendingOpen: FoodItem?
    @State private var pendingOpenDuration: Int = 0
    @State private var showOpenQuantityDialog = false
    
    var filteredItems: [FoodItem] {
        let locationItems: [FoodItem]
        switch selectedFilter {
        case .all: locationItems = items
        case .fridge: locationItems = items.filter { $0.location == .fridge }
        case .freezer: locationItems = items.filter { $0.location == .freezer }
        case .pantry: locationItems = items.filter { $0.location == .pantry }
        }
        if searchText.isEmpty { return locationItems }
        else { return locationItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) } }
    }

    var body: some View {
        let groupedItems = Dictionary(grouping: filteredItems, by: { $0.name })
        let sortedProductNames = groupedItems.keys.sorted { name1, name2 in
            let date1 = groupedItems[name1]?.first?.expiryDate ?? Date.distantFuture
            let date2 = groupedItems[name2]?.first?.expiryDate ?? Date.distantFuture
            return date1 < date2
        }

        GeometryReader { geometry in
                    // Heights
                    let collapsedHeight: CGFloat = 430
                    
                    // 👇 CORREZIONE 1: Aggiungiamo safeAreaInsets.bottom per coprire il bordo inferiore
                    let expandedHeight: CGFloat = geometry.size.height - geometry.safeAreaInsets.top - 20 + geometry.safeAreaInsets.bottom
                    
                    let currentHeight = isExpanded ? expandedHeight : collapsedHeight

                    ZStack(alignment: .top) {
                        // 1. BACKGROUND & MASCOT
                        backgroundColor.ignoresSafeArea()
                        
                        VStack {
                            Spacer().frame(height: geometry.safeAreaInsets.top + 20)
                            
                            BuddyView(
                                isDoorOpen: $isBuddyOpen,
                                forcedMood: isExpanded ? .observing : nil,
                                onTap: { withAnimation { showAddItemSheet = true } }
                            )
                            .scaleEffect(isExpanded ? 0.8 : 1.0)
                            .offset(y: isExpanded ? -120 : -50)
                            
                            Spacer()
                        }
                        .frame(width: geometry.size.width)
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: isExpanded)
                        
                        // 2. NATIVE FLOATING CARD
                        // 👇 CORREZIONE 2: Applichiamo ignoresSafeArea a QUESTO VStack contenitore
                        VStack {
                            Spacer()
                            
                            NavigationStack {
                                VStack(spacing: 0) {
                                    
                                    // A. FILTER SCOPE
                                    Picker("Filtra", selection: $selectedFilter) {
                                        ForEach(FilterScope.allCases, id: \.self) { scope in
                                            Text(scope.rawValue).tag(scope)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .padding(.horizontal)
                                    .padding(.vertical, 10)
                                    
                                    // B. NATIVE LIST
                                    if filteredItems.isEmpty {
                                        ContentUnavailableView(
                                            "Vuoto",
                                            systemImage: "tray",
                                            description: Text("Niente in \(selectedFilter.rawValue.lowercased()).")
                                        )
                                    } else {
                                        List {
                                            ForEach(sortedProductNames, id: \.self) { productName in
                                                if let batches = groupedItems[productName] {
                                                    ProductCard(
                                                        productName: productName,
                                                        batches: batches,
                                                        onConsume: { b in consumeItem(b, allItems: items) },
                                                        onConsumePartial: { b, f in consumePartial(b, remainingFraction: f) },
                                                        onDelete: { b in deleteItem(b) },
                                                        onEdit: { b in itemToEdit = b },
                                                        onOpenRequest: { b, d in requestOpen(item: b, days: d) },
                                                        onAdd: { addOneMore(of: batches) }
                                                    )
                                                    .listRowSeparator(.hidden)
                                                    .listRowBackground(Color.clear)
                                                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                                        Button(role: .destructive) {
                                                            if let first = batches.first { deleteItem(first) }
                                                        } label: {
                                                            Label("Butta", systemImage: "trash")
                                                        }
                                                    }
                                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                                        Button {
                                                            if let first = batches.first { consumeItem(first, allItems: items) }
                                                        } label: {
                                                            Label("Mangia", systemImage: "fork.knife")
                                                        }
                                                        .tint(.green)
                                                    }
                                                }
                                            }
                                        }
                                        .listStyle(.plain)
                                        .scrollContentBackground(.hidden)
                                    }
                                }
                                .navigationTitle("La mia Dispensa")
                                .navigationBarTitleDisplayMode(.inline)
                                .searchable(text: $searchText, placement: .automatic, prompt: "Cerca cibo...")
                                .toolbar {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button(action: { withAnimation(.spring) { isExpanded.toggle() } }) {
                                            Image(systemName: isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                                .bold()
                                        }
                                    }
                                    ToolbarItem(placement: .topBarTrailing) {
                                        Button(action: { showSettings = true }) {
                                            Image(systemName: "gearshape.fill")
                                        }
                                    }
                                }
                            }
                            .frame(height: currentHeight)
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 30))
                            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 5)
                            // Rimuovi padding e safe area quando espanso per "incollare" la card
                            .padding(.horizontal, isExpanded ? 0 : 16)
                            .padding(.bottom, isExpanded ? 0 : 20)
                        }
                        // 👇 QUESTA È LA CHIAVE: Il contenitore ignora la safe area bottom quando espanso
                        // Così lo Spacer() interno spinge la card fino al bordo fisico del telefono.
                        .ignoresSafeArea(edges: isExpanded ? .bottom : [])
                    }
                }
        .toolbar(isExpanded ? .hidden : .visible, for: .tabBar)
        .sheet(isPresented: $showAddItemSheet) {
            AddItemView(defaultLocation: locationFromFilter(selectedFilter))
                .presentationDetents([.fraction(0.85)])
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .sheet(item: $itemToEdit) { item in EditItemView(item: item) }
        .alert("Prodotto Finito!", isPresented: $showShopAlert) {
            Button("Metti in lista") { if let name = itemToAddToShop { addToShoppingList(name) } }
            Button("No", role: .cancel) { }
        } message: { Text("Hai finito \(itemToAddToShop ?? ""). Aggiungo alla spesa?") }
    }

    // HELPER FUNCTIONS
    private func locationFromFilter(_ filter: FilterScope) -> StorageLocation {
        switch filter {
        case .freezer: return .freezer
        case .pantry: return .pantry
        default: return .fridge
        }
    }
    
    private func consumeItem(_ item: FoodItem, allItems: [FoodItem]) {
        withAnimation {
            if item.quantity > 1 { item.quantity -= 1 }
            else {
                modelContext.delete(item)
                itemToAddToShop = item.name
                showShopAlert = true
            }
        }
        NotificationManager.shared.cancelNotification(for: item)
    }
    
    private func addOneMore(of batches: [FoodItem]) {
        if let template = batches.max(by: { $0.addedDate < $1.addedDate }) {
            withAnimation {
                let newItem = FoodItem(name: template.name, emoji: template.emoji, quantity: 1, expiryDate: template.expiryDate, location: template.location, measureValue: template.measureValue, measureUnit: template.measureUnit)
                modelContext.insert(newItem)
            }
        }
    }
    
    private func consumePartial(_ item: FoodItem, remainingFraction: Double) { withAnimation { let newValue = item.measureValue * remainingFraction; item.measureValue = round(newValue * 100) / 100 } }
    private func deleteItem(_ item: FoodItem) { withAnimation { NotificationManager.shared.cancelNotification(for: item); modelContext.delete(item) } }
    private func requestOpen(item: FoodItem, days: Int) { /* Logic from previous turn */ }
    private func addToShoppingList(_ name: String) { modelContext.insert(ShoppingItem(name: name)) }
}

// --- NUOVA CARD RIDISEGNATA (Added back to ensure it exists) ---
struct ProductCard: View {
    let productName: String
    let batches: [FoodItem]
    let onConsume: (FoodItem) -> Void
    let onConsumePartial: (FoodItem, Double) -> Void
    let onDelete: (FoodItem) -> Void
    let onEdit: (FoodItem) -> Void
    let onOpenRequest: (FoodItem, Int) -> Void
    let onAdd: () -> Void
    
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var firstItem: FoodItem? { batches.sorted(by: { ($0.expiryDate ?? Date.distantFuture) < ($1.expiryDate ?? Date.distantFuture) }).first }
    var totalQuantity: Int { batches.reduce(0) { $0 + $1.quantity } }
    
    var statusColor: Color {
        guard let item = firstItem, let expiry = item.expiryDate else { return .green }
        if item.isExpired { return .red }
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
        if daysLeft <= 3 { return .orange }
        return .green
    }
    
    var expiryText: String {
        guard let item = firstItem else { return "" }
        if item.location == .freezer { return "Congelato ❄️" }
        if item.isOpened { return "Aperto" }
        guard let expiry = item.expiryDate else { return "Nessuna scadenza" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Scade " + formatter.localizedString(for: expiry, relativeTo: Date())
    }
    
    var progressValue: Double {
        guard let item = firstItem, let expiry = item.expiryDate else { return 0 }
        let totalSpan = expiry.timeIntervalSince(item.addedDate)
        let timeGone = Date().timeIntervalSince(item.addedDate)
        if totalSpan <= 0 { return 1.0 }
        return min(max(timeGone / totalSpan, 0), 1.0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(Color(hue: 0.12, saturation: 0.1, brightness: 0.98)).frame(width: 48, height: 48)
                    Text(firstItem?.emoji ?? "📦").font(.system(size: 26))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(productName).font(.system(.title3, design: .rounded)).fontWeight(.bold).foregroundStyle(.primary)
                    HStack(spacing: 4) {
                        if statusColor == .orange || statusColor == .red { Image(systemName: "clock.fill").font(.caption) }
                        Text(expiryText).font(.caption).fontWeight(.medium)
                    }.foregroundStyle(statusColor)
                }
                Spacer()
                HStack(spacing: 0) {
                    Button(action: { if let item = firstItem { onConsume(item) } }) {
                        Image(systemName: "minus").font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32).background(Color.gray.opacity(0.1)).clipShape(Circle())
                    }.buttonStyle(.plain)
                    Text("\(totalQuantity)").font(.system(.body, design: .rounded).monospacedDigit()).fontWeight(.semibold).frame(minWidth: 30).contentTransition(.numericText(value: Double(totalQuantity)))
                    Button(action: { onAdd() }) {
                        Image(systemName: "plus").font(.system(size: 14, weight: .bold)).frame(width: 32, height: 32).background(Color.blue.opacity(0.1)).foregroundStyle(.blue).clipShape(Circle())
                    }.buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            
            if let _ = firstItem?.expiryDate {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(Color.gray.opacity(0.1))
                        Rectangle().fill(statusColor).frame(width: geo.size.width * progressValue)
                    }
                }.frame(height: 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 4)
        .onTapGesture {
            if batches.count > 1 { withAnimation { isExpanded.toggle() } }
            else { if let item = firstItem { onEdit(item) } }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }}
