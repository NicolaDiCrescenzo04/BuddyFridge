import Foundation
import SwiftUI

// Strutture per la risposta Barcode di Open Food Facts
struct OFFBarcodeResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

struct OFFProduct: Codable {
    let product_name: String?
    let categories: String? // Es. "Snacks, Biscotti"
    let brands: String?     // Es. "Barilla"
}

// Il nostro template interno
struct ProductTemplate: Identifiable {
    var id: String { name }
    let name: String
    let emoji: String
    let category: String
}

@Observable
class ProductLibrary {
    static let shared = ProductLibrary()
    var isLoading: Bool = false
    
    // Funzione per cercare tramite CODICE A BARRE
    func fetchProductByBarcode(code: String) async -> ProductTemplate? {
        // L'API per il barcode è specifica
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(code).json"
        
        guard let url = URL(string: urlString) else { return nil }
        
        await MainActor.run { self.isLoading = true }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decodedResponse = try JSONDecoder().decode(OFFBarcodeResponse.self, from: data)
            
            await MainActor.run { self.isLoading = false }
            
            // Se status è 1, il prodotto è stato trovato
            if decodedResponse.status == 1, let product = decodedResponse.product, let name = product.product_name {
                
                // Costruiamo il nome completo (es. "Barilla - Spaghetti")
                let brand = product.brands ?? ""
                let fullName = brand.isEmpty ? name : "\(brand) \(name)"
                
                let cats = product.categories ?? ""
                let emoji = guessEmoji(category: cats, name: name)
                let simpleCat = simplifyCategory(cats)
                
                return ProductTemplate(name: fullName, emoji: emoji, category: simpleCat)
            }
        } catch {
            print("Errore barcode: \(error)")
        }
        
        await MainActor.run { self.isLoading = false }
        return nil
    }
    
    // --- Le funzioni Helper restano uguali ---
    
    private func guessEmoji(category: String, name: String) -> String {
        let lowerCat = category.lowercased()
        let lowerName = name.lowercased()
        
        if lowerCat.contains("beverag") || lowerCat.contains("water") || lowerCat.contains("drink") { return "🥤" }
        if lowerCat.contains("biscuit") || lowerCat.contains("cookie") { return "🍪" }
        if lowerCat.contains("milk") || lowerCat.contains("yogurt") || lowerCat.contains("dair") { return "🥛" }
        if lowerCat.contains("bread") || lowerCat.contains("pan") { return "🍞" }
        if lowerCat.contains("pasta") || lowerCat.contains("spagh") { return "🍝" }
        if lowerCat.contains("meat") || lowerCat.contains("ham") || lowerCat.contains("salami") { return "🥩" }
        if lowerCat.contains("fish") || lowerCat.contains("tuna") { return "🐟" }
        if lowerCat.contains("cheese") { return "🧀" }
        if lowerCat.contains("fruit") { return "🍎" }
        if lowerCat.contains("vegetable") || lowerCat.contains("plant") { return "🥗" }
        if lowerCat.contains("sauce") || lowerCat.contains("tomat") { return "🍅" }
        if lowerCat.contains("pizza") { return "🍕" }
        if lowerCat.contains("chocola") { return "🍫" }
        
        if lowerName.contains("latte") { return "🥛" }
        if lowerName.contains("uov") { return "🥚" }
        
        return "🛍️"
    }
    
    private func simplifyCategory(_ category: String) -> String {
        if category.lowercased().contains("frozen") || category.lowercased().contains("surgelat") { return "Congelatore" }
        if category.lowercased().contains("fresh") || category.lowercased().contains("frigo") || category.lowercased().contains("cheese") || category.lowercased().contains("meat") { return "Frigo" }
        return "Dispensa"
    }
}
