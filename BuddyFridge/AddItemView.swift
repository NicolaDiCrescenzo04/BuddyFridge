import SwiftUI
import SwiftData
import UserNotifications

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isRecurring: Bool = false
    @State private var name: String = ""
    @State private var quantity: Int = 1
    @State private var expiryDate: Date = Date()
    @State private var location: StorageLocation = .fridge
    @State private var selectedEmoji: String = "🛍️" // Icona modificabile

    let suggestedFoods = ["Latte", "Uova", "Pane", "Yogurt", "Pollo", "Insalata", "Pasta"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra Suggerimenti
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(suggestedFoods, id: \.self) { food in
                            Button(action: {
                                name = food
                                selectedEmoji = guessIcon(for: food)
                            }) {
                                Text(food)
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .systemGroupedBackground))
                
                Form {
                    Section(header: Text("Dettagli Prodotto")) {
                        HStack {
                            Text(selectedEmoji)
                                .font(.title)
                                .padding(5)
                                .background(Color.gray.opacity(0.1))
                                .clipShape(Circle())
                            
                            TextField("Nome prodotto", text: $name)
                                .onChange(of: name) {
                                    let newIcon = guessIcon(for: name)
                                    if newIcon != "🛍️" { selectedEmoji = newIcon }
                                }
                        }
                        
                        Stepper("Quantità: \(quantity)", value: $quantity, in: 1...100)
                        
                        Toggle("Prodotto Ricorrente", isOn: $isRecurring)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                        
                        Picker("Posizione", selection: $location) {
                            ForEach(StorageLocation.allCases, id: \.self) { location in
                                Text(location.rawValue).tag(location)
                            }
                        }
                    }
                    
                    Section(header: Text("Scadenza")) {
                        DatePicker("Data di scadenza", selection: $expiryDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Nuovo Cibo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { saveItem() }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    // Funzione Magica Icone
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
        return "🛍️"
    }

    // Salvataggio + Notifica
    private func saveItem() {
        let newItem = FoodItem(
                name: name,
                emoji: selectedEmoji,
                quantity: quantity,
                expiryDate: expiryDate,
                location: location,
                isRecurring: isRecurring // <--- Passiamo il valore
            )
        modelContext.insert(newItem)
        scheduleNotification(for: newItem) // Schedula la notifica
        dismiss()
    }
    
    private func scheduleNotification(for item: FoodItem) {
        let content = UNMutableNotificationContent()
        content.title = "Scadenza in arrivo! ⚠️"
        content.body = "'\(item.name)' sta per scadere. Usalo presto!"
        content.sound = .default

        var dateComponents = Calendar.current.dateComponents([.day, .month, .year], from: item.expiryDate)
        dateComponents.hour = 9 // Avvisa alle 9:00 del giorno di scadenza
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
