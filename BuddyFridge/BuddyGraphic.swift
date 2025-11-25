import SwiftUI

struct BuddyGraphic: View {
    var mood: BuddyView.BuddyMood
    
    // Colori
    let bodyColor = Color(red: 0.45, green: 0.78, blue: 0.95) // Azzurro
    let shadowColor = Color(red: 0.25, green: 0.55, blue: 0.75) // Azzurro scuro
    
    var body: some View {
        ZStack {
            // 0. VAPORE (Dietro)
            if mood == .happy || mood == .worried {
                SteamView(mood: mood)
                    .offset(y: -110)
            }
            
            // 1. BRACCIA
            ArmsView(mood: mood, color: shadowColor)
            
            // 2. CORPO PRINCIPALE
            ZStack {
                // Lato scuro (Profondità 3D - Destra)
                RoundedRectangle(cornerRadius: 35)
                    .fill(shadowColor)
                    .frame(width: 170, height: 260)
                    .offset(x: 10, y: 0)
                
                // Fronte (Sportello)
                RoundedRectangle(cornerRadius: 35)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.6, green: 0.85, blue: 1.0), bodyColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 160, height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 35)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            }
            
            // 3. DETTAGLI "FRIGO" (Posizionati precisamente sui bordi)
            ZStack {
                // MANIGLIA (Bordo Sinistro)
                ZStack {
                    // Ombra maniglia
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.1))
                        .frame(width: 8, height: 50)
                        .offset(x: 2)
                    
                    // Maniglia cromata
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.white, .gray], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 10, height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray, lineWidth: 0.5)
                        )
                }
                .offset(x: -80) // <--- ORA È ATTACCATA PERFETTAMENTE AL BORDO SINISTRO
                
                // CERNIERE (Bordo Destro)
                VStack(spacing: 140) {
                    ForEach(0..<2) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 6, height: 15)
                            .shadow(radius: 1)
                    }
                }
                .offset(x: 80) // <--- ORA È ATTACCATA PERFETTAMENTE AL BORDO DESTRO
            }
            
            // 4. FACCIA (Centrale)
            VStack(spacing: 12) {
                Spacer().frame(height: 50)
                
                // OCCHI
                HStack(spacing: 28) {
                    EyeView(mood: mood)
                    EyeView(mood: mood)
                }
                
                // GUANCE
                if mood == .happy {
                    HStack(spacing: 64) {
                        Circle().fill(Color.pink.opacity(0.25)).frame(width: 18)
                        Circle().fill(Color.pink.opacity(0.25)).frame(width: 18)
                    }
                    .frame(height: 10)
                    .offset(y: -6)
                }
                
                // BOCCA
                MouthView(mood: mood)
                    .padding(.top, 4)
                
                Spacer()
            }
            .frame(height: 260)
        }
    }
}

// --- SOTTO-COMPONENTI INVARIATI ---

struct EyeView: View {
    var mood: BuddyView.BuddyMood
    var body: some View {
        ZStack {
            Circle().fill(Color.black.opacity(0.85)).frame(width: 18, height: 18)
            Circle().fill(Color.white).frame(width: 6, height: 6).offset(x: 4, y: -4)
            switch mood {
            case .worried: Capsule().fill(Color.black.opacity(0.85)).frame(width: 22, height: 3).offset(y: -14).rotationEffect(.degrees(-15))
            case .sad: Rectangle().fill(Color(red: 0.6, green: 0.85, blue: 1.0)).frame(width: 20, height: 10).offset(y: -8)
            default: EmptyView()
            }
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

struct ArmsView: View {
    var mood: BuddyView.BuddyMood; var color: Color
    var body: some View {
        ZStack {
            if mood == .happy {
                Path { p in p.move(to: CGPoint(x: -60, y: 150)); p.addQuadCurve(to: CGPoint(x: -100, y: 100), control: CGPoint(x: -120, y: 150)) }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                Circle().fill(.white).frame(width: 35).position(x: -100, y: 100).shadow(radius: 2)
                Text("👍").font(.largeTitle).position(x: -100, y: 100)
            } else if mood == .sad {
                Path { p in p.move(to: CGPoint(x: -60, y: 150)); p.addLine(to: CGPoint(x: -90, y: 200)) }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                Circle().fill(.white).frame(width: 30).position(x: -90, y: 200)
            } else {
                Path { p in p.move(to: CGPoint(x: -60, y: 150)); p.addQuadCurve(to: CGPoint(x: -70, y: 180), control: CGPoint(x: -90, y: 160)) }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
            }
            if mood == .sad {
                Path { p in p.move(to: CGPoint(x: 230, y: 150)); p.addLine(to: CGPoint(x: 260, y: 200)) }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                Circle().fill(.white).frame(width: 30).position(x: 260, y: 200)
            } else {
                Path { p in p.move(to: CGPoint(x: 230, y: 150)); p.addQuadCurve(to: CGPoint(x: 270, y: 120), control: CGPoint(x: 260, y: 180)) }
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                Circle().fill(.white).frame(width: 30).position(x: 270, y: 120)
            }
        }
        .offset(x: -85)
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
