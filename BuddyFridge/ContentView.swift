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
    
    // La Query recupera già gli elementi ordinati per data, ma gestiamo l'ordine finale nel body.
    @Query(sort: \FoodItem.expiryDate) private var items: [FoodItem]
    
    let backgroundColor: Color
    
    @State private var showAddItemSheet = false
    @State private var isBuddyOpen = false
    @State private var itemToAddToShop: String?
    @State private var showShopAlert = false
    @State private var showSettings = false
    @State private var itemToEdit: FoodItem?
    
    // --- STATI PER APERTURA PACCHI MULTIPLI (Spinacine vs Latte) ---
    @State private var itemPendingOpen: FoodItem?      // L'oggetto che stai per aprire
    @State private var pendingOpenDuration: Int = 0    // La durata scelta (es. 3 giorni)
    @State private var showOpenQuantityDialog = false  // Mostra il menu di scelta
    
    // STATO FILTRO
    @State private var selectedFilter: FilterScope = .all
    
    @Namespace private var animationNamespace

    var filteredItems: [FoodItem] {
        switch selectedFilter {
        case .all: return items
        case .fridge: return items.filter { $0.location == .fridge }
        case .freezer: return items.filter { $0.location == .freezer }
        case .pantry: return items.filter { $0.location == .pantry }
        }
    }

    var body: some View {
        // 1. Raggruppiamo gli elementi per nome
        let groupedItems = Dictionary(grouping: filteredItems, by: { $0.name })
        
        // 2. MODIFICA: Ordiniamo i NOMI dei prodotti in base alla scadenza del loro primo lotto
        // Se un prodotto non ha scadenza (nil), lo consideriamo nel futuro lontano (.distantFuture)
        let sortedProductNames = groupedItems.keys.sorted { name1, name2 in
            let date1 = groupedItems[name1]?.first?.expiryDate ?? Date.distantFuture
            let date2 = groupedItems[name2]?.first?.expiryDate ?? Date.distantFuture
            return date1 < date2
        }

        NavigationStack {
            ZStack {
                backgroundColor.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    if items.isEmpty {
                        Spacer()
                        BuddyView(isDoorOpen: $isBuddyOpen) { apriFrigo() }
                            .matchedGeometryEffect(id: "BuddyFridge", in: animationNamespace)
                            .frame(maxHeight: .infinity)
                        Spacer()
                    } else {
                        BuddyView(isDoorOpen: $isBuddyOpen) { apriFrigo() }
                            .padding(.bottom, 10)
                            .background(backgroundColor)
                            .matchedGeometryEffect(id: "BuddyFridge", in: animationNamespace)
                        
                        Picker("Filtra", selection: $selectedFilter) {
                            ForEach(FilterScope.allCases, id: \.self) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                        .background(backgroundColor)
                        
                        if filteredItems.isEmpty {
                            Spacer()
                            ContentUnavailableView(
                                "Nessun prodotto",
                                systemImage: "tray",
                                description: Text("Non c'è nulla in \(selectedFilter.rawValue.lowercased()).")
                            )
                            Spacer()
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 16) {
                                    ForEach(sortedProductNames, id: \.self) { productName in
                                        if let batches = groupedItems[productName] {
                                            ProductCard(
                                                productName: productName,
                                                batches: batches,
                                                onConsume: { batch in consumeItem(batch, allItems: items) },
                                                onConsumePartial: { batch, fraction in consumePartial(batch, remainingFraction: fraction) },
                                                onDelete: { batch in deleteItem(batch) },
                                                onEdit: { batch in itemToEdit = batch },
                                                onOpenRequest: { batch, days in requestOpen(item: batch, days: days) }
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
            }
            .navigationTitle(items.isEmpty ? "" : "Inventario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(backgroundColor, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) { Image(systemName: "gearshape").foregroundStyle(.gray) }
                }
            }
            .sheet(isPresented: $showAddItemSheet, onDismiss: { withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { isBuddyOpen = false } }) {
                AddItemView().presentationDetents([.fraction(0.65)]).presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(item: $itemToEdit) { item in EditItemView(item: item) }
            // --- DIALOGO SCELTA QUANTITA APERTURA ---
            .confirmationDialog("Quanti ne stai aprendo?", isPresented: $showOpenQuantityDialog, titleVisibility: .visible) {
                if let item = itemPendingOpen {
                    Button("Apri solo 1 (es. 1 Bottiglia)") {
                        confirmOpen(item: item, days: pendingOpenDuration, openAll: false)
                    }
                    Button("Apri Tutti e \(item.quantity) (es. Pacco intero)") {
                        confirmOpen(item: item, days: pendingOpenDuration, openAll: true)
                    }
                    Button("Annulla", role: .cancel) {
                        itemPendingOpen = nil
                    }
                }
            } message: {
                if let item = itemPendingOpen {
                    Text("Hai \(item.quantity) pezzi di '\(item.name)'.")
                }
            }
            // ----------------------------------------
            .alert("Prodotto Finito!", isPresented: $showShopAlert) {
                Button("Sì, metti in lista") { if let name = itemToAddToShop { addToShoppingList(name) } }
                Button("No, grazie", role: .cancel) { }
            } message: { Text("Hai finito \(itemToAddToShop ?? "il prodotto"). Vuoi aggiungerlo alla lista della spesa?") }
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: items.isEmpty)
    }

    private func apriFrigo() { withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { isBuddyOpen = true }; showAddItemSheet = true }
    private func consumeItem(_ item: FoodItem, allItems: [FoodItem]) { withAnimation { if item.quantity > 1 { item.quantity -= 1 } else { checkIfLastAndSuggest(item, allItems: allItems); NotificationManager.shared.cancelNotification(for: item); modelContext.delete(item) } } }
    private func consumePartial(_ item: FoodItem, remainingFraction: Double) { withAnimation { let newValue = item.measureValue * remainingFraction; item.measureValue = round(newValue * 100) / 100 } }
    private func deleteItem(_ item: FoodItem) { withAnimation { NotificationManager.shared.cancelNotification(for: item); modelContext.delete(item) } }
    private func checkIfLastAndSuggest(_ item: FoodItem, allItems: [FoodItem]) { let otherBatchesCount = allItems.filter { $0.name == item.name && $0.persistentModelID != item.persistentModelID }.count; if otherBatchesCount == 0 { itemToAddToShop = item.name; showShopAlert = true } }
    private func addToShoppingList(_ name: String) { modelContext.insert(ShoppingItem(name: name)) }
    
    // --- GESTIONE RICHIESTA APERTURA ---
    private func requestOpen(item: FoodItem, days: Int) {
        if item.quantity == 1 {
            // Se ne hai solo 1, non c'è ambiguità: aprilo e basta
            confirmOpen(item: item, days: days, openAll: true)
        } else {
            // Se ne hai 6 (es. Spinacine o Latte), chiediamo all'utente
            itemPendingOpen = item
            pendingOpenDuration = days
            showOpenQuantityDialog = true
        }
    }
    
    // --- ESECUZIONE APERTURA (SPLIT O TOTALE) ---
    private func confirmOpen(item: FoodItem, days: Int, openAll: Bool) {
        withAnimation {
            let quantityToMove = openAll ? item.quantity : 1
            
            // 1. Gestiamo il prodotto originale chiuso
            if item.quantity > quantityToMove {
                // Caso Latte: Riduciamo quelli chiusi
                item.quantity -= quantityToMove
            } else {
                // Caso Spinacine (o ultima bottiglia): Rimuoviamo il "chiuso"
                NotificationManager.shared.cancelNotification(for: item)
                modelContext.delete(item)
            }
            
            // 2. Creiamo il prodotto "Aperto"
            let newExpiry = Calendar.current.date(byAdding: .day, value: days, to: Date()) ?? Date()
            
            let openedItem = FoodItem(
                name: item.name,
                emoji: item.emoji,
                quantity: quantityToMove, // Spostiamo la quantità scelta (1 o 6)
                expiryDate: newExpiry,
                location: item.location,
                isRecurring: item.isRecurring,
                measureValue: item.measureValue,
                measureUnit: item.measureUnit,
                isOpened: true // BANDIERINA APERTO
            )
            
            modelContext.insert(openedItem)
            NotificationManager.shared.scheduleNotification(for: openedItem)
        }
        
        // Reset stati
        itemPendingOpen = nil
        pendingOpenDuration = 0
    }
}

// --- CARD DEL PRODOTTO ---
struct ProductCard: View {
    let productName: String
    let batches: [FoodItem]
    let onConsume: (FoodItem) -> Void
    let onConsumePartial: (FoodItem, Double) -> Void
    let onDelete: (FoodItem) -> Void
    let onEdit: (FoodItem) -> Void
    // Nuova callback
    let onOpenRequest: (FoodItem, Int) -> Void
    
    @State private var isExpanded: Bool = false
    @Environment(\.colorScheme) var colorScheme
    
    var firstItem: FoodItem? { batches.first }
    
    // Logica colori aggiornata per gestire le date opzionali
    var statusColor: Color {
        if batches.contains(where: { $0.isOpened }) { return .orange }
        if let first = firstItem, first.location == .freezer { return .cyan }
        if batches.contains(where: { $0.isExpired }) { return .red }
        
        let soonDate = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
        
        // Controlliamo se c'è almeno un batch che scade presto (e che ha una data)
        if batches.contains(where: {
            guard let date = $0.expiryDate else { return false }
            return date <= soonDate
        }) { return .orange }
        
        return .green
    }
    
    var totalQuantity: Int { batches.reduce(0) { $0 + $1.quantity } }
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
                                if first.location == .freezer {
                                    Text("Congelato ❄️").font(.caption).fontWeight(.semibold).foregroundStyle(.cyan)
                                } else if first.isOpened {
                                    if let date = first.expiryDate {
                                        Text("APERTO - Scade: \(date.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                                    } else {
                                        Text("APERTO").font(.caption).fontWeight(.bold).foregroundStyle(.orange)
                                    }
                                } else {
                                    // MODIFICA QUI: GESTIONE DATA NIL
                                    if let date = first.expiryDate {
                                        Text("Scade: \(date.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption).foregroundStyle(first.isExpired ? .red : .secondary)
                                    } else {
                                        Text("Nessuna scadenza")
                                            .font(.caption).foregroundStyle(.green)
                                    }
                                }
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
                        SwipeableBatchRow(onDelete: { onDelete(batch) }, onEdit: { onEdit(batch) }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    if batch.location == .freezer {
                                        Text("Bloccato nel tempo ❄️").font(.subheadline).foregroundStyle(.cyan)
                                    } else if batch.isOpened {
                                        HStack {
                                            Image(systemName: "lock.open.fill")
                                            Text("APERTO").fontWeight(.bold)
                                        }
                                        .font(.caption).foregroundStyle(.orange)
                                        
                                        if let date = batch.expiryDate {
                                            Text("Scade: \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.subheadline).foregroundStyle(.primary)
                                        }
                                    } else {
                                        // MODIFICA QUI: GESTIONE DATA NIL NELLA LISTA ESPANSA
                                        if let date = batch.expiryDate {
                                            Text("Scade: \(date.formatted(date: .abbreviated, time: .omitted))")
                                                .font(.subheadline).foregroundStyle(batch.isExpired ? .red : .primary)
                                        } else {
                                            Text("Nessuna scadenza")
                                                .font(.subheadline).foregroundStyle(.green)
                                        }
                                    }
                                    HStack {
                                        Text(batch.location.rawValue)
                                        if !batch.formattedMeasure.isEmpty { Text("• \(batch.formattedMeasure)") }
                                    }.font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                
                                // BOTTONE APRI (Solo se non aperto e non freezer)
                                if !batch.isOpened && batch.location != .freezer {
                                    Menu {
                                        Text("Consumare entro:")
                                        Button("24 Ore") { onOpenRequest(batch, 1) }
                                        Button("3 Giorni") { onOpenRequest(batch, 3) }
                                        Button("5 Giorni") { onOpenRequest(batch, 5) }
                                        Button("7 Giorni") { onOpenRequest(batch, 7) }
                                    } label: {
                                        VStack(spacing: 2) {
                                            Image(systemName: "arrow.up.bin.fill")
                                            Text("Apri").font(.caption2).bold()
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .cornerRadius(8)
                                    }
                                    .padding(.trailing, 5)
                                }
                                
                                if batch.measureUnit == .pieces || batch.quantity > 1 {
                                    Button(action: { onConsume(batch) }) {
                                        HStack(spacing: 4) { Image(systemName: "fork.knife"); Text("Mangia").fontWeight(.semibold) }
                                            .font(.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.blue).foregroundStyle(.white).clipShape(Capsule()).shadow(color: .blue.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                } else {
                                    Menu {
                                        Button("🍽️ Mangia Tutto (Finito!)") { onConsume(batch) }
                                        Divider()
                                        Text("Consuma una parte:")
                                        Button("🍰 Mangia Metà (Ne rimane 1/2)") { onConsumePartial(batch, 0.5) }
                                        Button("🤏 Mangia un po' (Ne rimane 3/4)") { onConsumePartial(batch, 0.75) }
                                        Button("🥄 Mangia molto (Ne rimane 1/4)") { onConsumePartial(batch, 0.25) }
                                        Button("⚠️ Quasi finito (Ne rimane 10%)") { onConsumePartial(batch, 0.10) }
                                    } label: {
                                        HStack(spacing: 4) { Image(systemName: "slider.horizontal.below.rectangle"); Text("Consuma...").fontWeight(.semibold) }
                                            .font(.caption).padding(.horizontal, 12).padding(.vertical, 6).background(Color.indigo).foregroundStyle(.white).clipShape(Capsule()).shadow(color: .indigo.opacity(0.3), radius: 2, x: 0, y: 1)
                                    }
                                }
                                Text("x\(batch.quantity)").bold().frame(minWidth: 25).padding(.trailing, 5)
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

// RIGA SWIPEABLE (Standard)
struct SwipeableBatchRow<Content: View>: View {
    var onDelete: () -> Void; var onEdit: (() -> Void)? = nil; @ViewBuilder var content: Content; @State private var offset: CGFloat = 0; @State private var isSwiped: Bool = false; let buttonWidth: CGFloat = 70
    var body: some View {
        ZStack(alignment: .trailing) {
            HStack(spacing: 0) { Spacer(); if let onEdit = onEdit { Button(action: { withAnimation { offset = 0; isSwiped = false }; onEdit() }) { ZStack { Color.orange; Image(systemName: "pencil").foregroundStyle(.white).font(.title2) } }.frame(width: buttonWidth) }; Button(action: { withAnimation { offset = 0; isSwiped = false }; onDelete() }) { ZStack { Color.red; Image(systemName: "trash.fill").foregroundStyle(.white).font(.title2) } }.frame(width: buttonWidth) }
            content.offset(x: offset).gesture(DragGesture().onChanged { value in if value.translation.width < 0 { offset = value.translation.width } }.onEnded { value in withAnimation(.spring()) { let threshold: CGFloat = (onEdit != nil) ? -140 : -70; let finalOffset: CGFloat = (onEdit != nil) ? -(buttonWidth * 2) : -buttonWidth; if value.translation.width < threshold { offset = finalOffset; isSwiped = true } else { offset = 0; isSwiped = false } } })
        }.onTapGesture { if isSwiped { withAnimation { offset = 0; isSwiped = false } } }
    }
}
