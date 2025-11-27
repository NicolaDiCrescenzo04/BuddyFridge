import SwiftUI

struct BuddyGraphic: View {
    var mood: BuddyView.BuddyMood
    var isOpen: Bool
    
    // Colori
    let bodyColor = Color(red: 0.45, green: 0.78, blue: 0.95)
    let shadowColor = Color(red: 0.25, green: 0.55, blue: 0.75)
    let insideColor = Color(red: 0.85, green: 0.92, blue: 0.98)
    
    var body: some View {
        ZStack {
            // 0. VAPORE (Solo se felice o preoccupato)
            if mood == .happy || mood == .worried {
                SteamView(mood: mood)
                    .offset(y: -110)
                    .opacity(isOpen ? 0 : 1)
            }
            
            // (BRACCIA RIMOSSE PER PULIZIA)
            
            // 1. CORPO PRINCIPALE
            ZStack {
                // Profondità 3D (Lato ORA A SINISTRA)
                RoundedRectangle(cornerRadius: 35)
                    .fill(shadowColor)
                    .frame(width: 170, height: 260)
                    .offset(x: -10, y: 0) // <--- MODIFICA QUI: da 10 a -10
                
                // Interno del Frigo (visibile quando aperto)
                ZStack {
                    RoundedRectangle(cornerRadius: 35)
                        .fill(insideColor)
                        .frame(width: 160, height: 260)
                        .overlay(RoundedRectangle(cornerRadius: 35).stroke(Color.white, lineWidth: 4))
                    
                    // Ripiani
                    VStack(spacing: 60) {
                        ForEach(0..<3) { _ in
                            Rectangle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 140, height: 4)
                                .shadow(radius: 1, y: 1)
                        }
                    }
                }
            }
            
            // 2. PORTA (Ruotante)
            ZStack {
                // Fronte della porta
                RoundedRectangle(cornerRadius: 35)
                    .fill(LinearGradient(colors: [Color(red: 0.6, green: 0.85, blue: 1.0), bodyColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 160, height: 260)
                    .overlay(RoundedRectangle(cornerRadius: 35).stroke(Color.white.opacity(0.3), lineWidth: 1))
                
                // Dettagli Porta (Maniglia + Faccia)
                ZStack {
                    // Maniglia (Sinistra)
                    ZStack {
                        RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.1)).frame(width: 8, height: 50).offset(x: 2)
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [.white, .gray], startPoint: .leading, endPoint: .trailing)).frame(width: 10, height: 50)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 0.5))
                    }.offset(x: -80)
                    
                    // FACCIA
                    VStack(spacing: 12) {
                        Spacer().frame(height: 50)
                        HStack(spacing: 28) { EyeView(mood: mood); EyeView(mood: mood) }
                        
                        // GUANCE (Solo se felice)
                        if mood == .happy {
                            HStack(spacing: 64) {
                                Circle().fill(Color.pink.opacity(0.25)).frame(width: 18)
                                Circle().fill(Color.pink.opacity(0.25)).frame(width: 18)
                            }
                            .frame(height: 10).offset(y: -6)
                        }
                        MouthView(mood: mood).padding(.top, 4)
                        Spacer()
                    }
                    .frame(height: 260)
                }
            }
            .rotation3DEffect(.degrees(isOpen ? 80 : 0), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
            
            // 3. Cerniere (Destra)
            VStack(spacing: 140) {
                ForEach(0..<2) { _ in RoundedRectangle(cornerRadius: 2).fill(Color.white.opacity(0.5)).frame(width: 6, height: 15).shadow(radius: 1) }
            }.offset(x: 80)
        }
    }
}

// --- SOTTO-COMPONENTI AGGIORNATI ---

struct EyeView: View {
    var mood: BuddyView.BuddyMood
    var body: some View {
        ZStack {
            // Occhio base con maschera per espressioni (triste/preoccupato)
            Circle().fill(Color.black.opacity(0.85)).frame(width: 18, height: 18)
                .mask(
                    ZStack {
                        Circle().frame(width: 18, height: 18)
                        if mood == .sad {
                            Rectangle().frame(width: 20, height: 10).offset(y: -8).blendMode(.destinationOut)
                        }
                        if mood == .worried {
                            Rectangle().frame(width: 22, height: 10).offset(y: -10).rotationEffect(.degrees(-15)).blendMode(.destinationOut)
                        }
                    }.compositingGroup()
                )
            
            // Riflesso (se non è triste)
            if mood != .sad {
                Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: 4, y: -4)
            }
            
            // (SOPRACCIGLIA FELICI RIMOSSE)
        }
    }
}

struct MouthView: View {
    var mood: BuddyView.BuddyMood
    var body: some View {
        Group {
            switch mood {
            case .happy: SmileShape().stroke(Color.black.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 32, height: 16)
            case .neutral: Capsule().fill(Color.black.opacity(0.8)).frame(width: 14, height: 3)
            case .worried: Circle().stroke(Color.black.opacity(0.8), lineWidth: 3).frame(width: 10, height: 10)
            case .sad: SmileShape().stroke(Color.black.opacity(0.8), style: StrokeStyle(lineWidth: 3, lineCap: .round)).frame(width: 32, height: 16).rotationEffect(.degrees(180))
            }
        }
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: 0)); path.addQuadCurve(to: CGPoint(x: rect.width, y: 0), control: CGPoint(x: rect.width/2, y: rect.height)); return path
    }
}

struct SteamView: View {
    var mood: BuddyView.BuddyMood; @State private var animate = false
    var body: some View {
        HStack(spacing: 20) {
            if mood == .happy {
                Image(systemName: "cloud.fill").font(.system(size: 40)).foregroundStyle(.white.opacity(0.8)).offset(y: animate ? -20 : 0).scaleEffect(animate ? 1.1 : 0.9)
                Image(systemName: "cloud.fill").font(.system(size: 30)).foregroundStyle(.white.opacity(0.6)).offset(y: animate ? -30 : -10)
            } else if mood == .worried { Text("?").font(.largeTitle).foregroundStyle(.gray.opacity(0.5)).offset(y: animate ? -20 : 0) }
        }
        .onAppear { withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { animate = true } }
    }
}
