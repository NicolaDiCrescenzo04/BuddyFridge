import Foundation
import SwiftUI

// --- STRUTTURE DATI ---

struct OFFSearchResponse: Codable {
    let products: [OFFProduct]
}

struct OFFBarcodeResponse: Codable {
    let status: Int
    let product: OFFProduct?
}

struct OFFProduct: Codable {
    let product_name: String?
    let categories: String?
    let brands: String?
}

struct ProductTemplate: Identifiable, Sendable { // Aggiunto Sendable per sicurezza
    var id: String { name }
    let name: String
    let emoji: String
    let category: String
}

// --- IL MOTORE DI RICERCA (Ora Blindato sul MainActor) ---

@MainActor // <--- QUESTA È LA CHIAVE: Protegge tutta la classe
@Observable
class ProductLibrary {
    static let shared = ProductLibrary()
    
    var products: [ProductTemplate] = []
    var isLoading: Bool = false
    
    // A. RICERCA PER NOME
    func searchOnline(query: String) async {
        guard query.count > 2 else {
            self.products = [] // Possiamo modificare direttamente le variabili!
            return
        }
        
        let urlString = "https://world.openfoodfacts.org/cgi/search.pl?search_terms=\(query)&search_simple=1&action=process&json=1&page_size=5"
        guard let url = URL(string: urlString) else { return }
        
        self.isLoading = true
        
        do {
            // URLSession è intelligente e lavora in background automaticamente
            // anche se noi siamo sul MainActor
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OFFSearchResponse.self, from: data)
            
            let found = decoded.products.compactMap { convertToTemplate($0) }
            
            // Aggiorniamo l'interfaccia direttamente
            self.products = found
            self.isLoading = false
            
        } catch {
            if (error as NSError).code != -999 {
                print("Errore ricerca: \(error)")
            }
            self.isLoading = false
        }
    }
    
    // B. RICERCA PER BARCODE
    func fetchProductByBarcode(code: String) async -> ProductTemplate? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(code).json"
        guard let url = URL(string: urlString) else { return nil }
        
        self.isLoading = true
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OFFBarcodeResponse.self, from: data)
            
            self.isLoading = false
            
            if decoded.status == 1, let product = decoded.product {
                return convertToTemplate(product)
            }
        } catch {
            print("Errore barcode: \(error)")
        }
        
        self.isLoading = false
        return nil
    }
    
    // --- FUNZIONI DI SUPPORTO ---
    
    private func convertToTemplate(_ p: OFFProduct) -> ProductTemplate? {
        guard let name = p.product_name else { return nil }
        
        let brand = p.brands ?? ""
        let fullName = brand.isEmpty ? name : "\(brand) \(name)"
        let cats = p.categories ?? ""
        
        let emoji = guessEmoji(category: cats, name: name)
        let simpleCat = simplifyCategory(cats)
        
        return ProductTemplate(name: fullName, emoji: emoji, category: simpleCat)
    }
    
    private func guessEmoji(category: String, name: String) -> String {
        let lowerCat = category.lowercased()
        let lowerName = name.lowercased()
        
        if lowerCat.contains("beverag") || lowerCat.contains("water") || lowerCat.contains("drink") || lowerCat.contains("soda") { return "🥤" }
        if lowerCat.contains("biscuit") || lowerCat.contains("cookie") { return "🍪" }
        if lowerCat.contains("milk") || lowerCat.contains("yogurt") || lowerCat.contains("dair") { return "🥛" }
        if lowerCat.contains("bread") || lowerCat.contains("pan") || lowerCat.contains("bakery") { return "🍞" }
        if lowerCat.contains("pasta") || lowerCat.contains("spagh") { return "🍝" }
        if lowerCat.contains("meat") || lowerCat.contains("ham") || lowerCat.contains("salami") || lowerCat.contains("chick") { return "🥩" }
        if lowerCat.contains("fish") || lowerCat.contains("tuna") || lowerCat.contains("sea") { return "🐟" }
        if lowerCat.contains("cheese") { return "🧀" }
        if lowerCat.contains("fruit") || lowerCat.contains("apple") || lowerCat.contains("banana") { return "🍎" }
        if lowerCat.contains("vegetable") || lowerCat.contains("plant") || lowerCat.contains("salad") { return "🥗" }
        if lowerCat.contains("sauce") || lowerCat.contains("tomat") { return "🍅" }
        if lowerCat.contains("pizza") { return "🍕" }
        if lowerCat.contains("chocola") || lowerCat.contains("cocoa") { return "🍫" }
        if lowerCat.contains("ice cream") || lowerCat.contains("frozen") { return "🍦" }
        
        if lowerName.contains("latte") { return "🥛" }
        if lowerName.contains("uov") { return "🥚" }
        if lowerName.contains("vin") { return "🍷" }
        if lowerName.contains("birr") { return "🍺" }
        
        return "🛍️"
    }
    
    private func simplifyCategory(_ category: String) -> String {
        let lower = category.lowercased()
        if lower.contains("frozen") || lower.contains("surgelat") || lower.contains("ice") { return "Congelatore" }
        if lower.contains("fresh") || lower.contains("frigo") || lower.contains("cheese") || lower.contains("meat") || lower.contains("dairy") || lower.contains("yogurt") { return "Frigo" }
        return "Dispensa"
    }
}
