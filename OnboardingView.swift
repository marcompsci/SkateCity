import SwiftUI

// MARK: - Profile Model

struct SkaterDraftProfile: Codable {
    var name:        String       = ""
    var age:         String       = ""
    var email:       String       = ""
    var stance:      SkaterStance = .regular
    var style:       SkatingStyle = .street
    var outfitTop:   String       = "Spitfire Hoodie"
    var outfitPants: String       = "Baggy Jeans"
    var accessory:   String       = "Snapback"
    var deckGraphic: String       = "Anti Hero Eagle"
    var truckColor:  String       = "Silver"
    var wheelColor:  String       = "Natural"
    var shoe:        String       = "Vans Old Skool"
}

enum SkaterStance: String, CaseIterable, Codable, Identifiable {
    case regular = "Regular"
    case goofy   = "Goofy"
    var id: String { rawValue }
    var subtitle: String {
        self == .regular ? "Left foot forward" : "Right foot forward"
    }
}

enum SkatingStyle: String, CaseIterable, Codable, Identifiable {
    case street  = "Street"
    case vert    = "Vert"
    case park    = "Park"
    case cruiser = "Cruiser"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .street:  return "🏙️"
        case .vert:    return "🌊"
        case .park:    return "🛹"
        case .cruiser: return "🌆"
        }
    }
    var subtitle: String {
        switch self {
        case .street:  return "Ledges · Rails · Stairs"
        case .vert:    return "Halfpipes · Bowls · Airs"
        case .park:    return "Flow · Transitions · All Terrain"
        case .cruiser: return "City · Exploration · Speed"
        }
    }
}

// MARK: - Step

private enum OnboardingStep: Int, CaseIterable {
    case welcome, skaterCard, outfit, board, shoes, dropIn
}

// MARK: - Brand Colors

private extension Color {
    static let skRed   = Color(red: 0.85, green: 0.08, blue: 0.08)
    static let skDark  = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let skPanel = Color(white: 0.12)
    static let skSteel = Color(white: 0.60)
}

// MARK: - Root View

struct OnboardingView: View {
    @State private var step      = OnboardingStep.welcome
    @State private var profile   = SkaterDraftProfile()
    @State private var goForward = true

    var body: some View {
        ZStack {
            Color.skDark.ignoresSafeArea()

            Group {
                switch step {
                case .welcome:
                    WelcomeStepView(onDrop: advance)
                case .skaterCard:
                    SkaterCardStepView(profile: $profile, onNext: advance, onBack: retreat)
                case .outfit:
                    CustomizerStep(
                        title: "OUTFIT", stepNum: 2,
                        profile: profile,
                        focus: .outfit,
                        panel: OutfitPanelView(profile: $profile),
                        onNext: advance, onBack: retreat
                    )
                case .board:
                    CustomizerStep(
                        title: "BOARD SETUP", stepNum: 3,
                        profile: profile,
                        focus: .board,
                        panel: BoardPanelView(profile: $profile),
                        onNext: advance, onBack: retreat
                    )
                case .shoes:
                    CustomizerStep(
                        title: "KICKS", stepNum: 4,
                        profile: profile,
                        focus: .shoes,
                        panel: ShoesPanelView(profile: $profile),
                        onNext: advance, onBack: retreat
                    )
                case .dropIn:
                    DropInStepView(profile: profile, onComplete: complete)
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: goForward ? .trailing : .leading)
                               .combined(with: .opacity),
                removal:   .move(edge: goForward ? .leading : .trailing)
                               .combined(with: .opacity)
            ))
        }
        .ignoresSafeArea()
    }

    private func advance() {
        goForward = true
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            let all = OnboardingStep.allCases
            if let i = all.firstIndex(of: step), i + 1 < all.count { step = all[i + 1] }
        }
    }

    private func retreat() {
        goForward = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            let all = OnboardingStep.allCases
            if let i = all.firstIndex(of: step), i > 0 { step = all[i - 1] }
        }
    }

    private func complete() {
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: "skaterProfile")
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }
}

// MARK: - Red Grunge Header Banner

private struct RedBanner: View {
    let title: String
    let stepNum: Int
    let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(
                    colors: [Color.skRed, Color(red: 0.55, green: 0.04, blue: 0.04)],
                    startPoint: .leading, endPoint: .trailing
                )
                // Diagonal scratch-line texture
                Canvas { ctx, size in
                    let spacing: CGFloat = 14
                    let n = Int(size.width / spacing) + Int(size.height / spacing) + 2
                    for i in 0..<n {
                        var p = Path()
                        let x = CGFloat(i) * spacing - size.height
                        p.move(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                        ctx.stroke(p, with: .color(.white.opacity(0.07)), lineWidth: 1)
                    }
                }
                .allowsHitTesting(false)

                HStack {
                    Text(title)
                        .font(.system(size: 24, weight: .black))
                        .tracking(5)
                        .foregroundStyle(.white)

                    Spacer()

                    HStack(spacing: 7) {
                        ForEach(1...totalSteps, id: \.self) { i in
                            Circle()
                                .fill(i == stepNum ? Color.white : Color.white.opacity(0.28))
                                .frame(
                                    width:  i == stepNum ? 10 : 7,
                                    height: i == stepNum ? 10 : 7
                                )
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 62)

            Color.skRed.opacity(0.55).frame(height: 2)
        }
    }
}

// MARK: - Bottom Nav Bar

private struct BottomNav: View {
    let canAdvance: Bool
    let showBack:   Bool
    let onBack:     () -> Void
    let onNext:     () -> Void

    var body: some View {
        HStack {
            if showBack {
                Button(action: onBack) {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                        Text("BACK").tracking(2)
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.skSteel)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.skPanel))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button(action: onNext) {
                HStack(spacing: 5) {
                    Text("NEXT").tracking(3)
                    Image(systemName: "chevron.right")
                }
                .font(.system(size: 14, weight: .black))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(canAdvance ? Color.skRed : Color.skPanel)
                )
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(
            Color.skDark
                .overlay(Divider().overlay(Color.skRed.opacity(0.35)), alignment: .top)
        )
    }
}

// MARK: - STEP 1: Welcome

private struct WelcomeStepView: View {
    let onDrop: () -> Void

    @State private var logoScale:   CGFloat = 0.55
    @State private var logoAlpha:   Double  = 0
    @State private var taglineAlpha: Double = 0
    @State private var btnScale:    CGFloat = 0.8
    @State private var pulse = false

    var body: some View {
        ZStack {
            CitySkylineCanvas().opacity(0.22).ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 4) {
                    Text("SKATE")
                        .font(.system(size: 86, weight: .black))
                        .tracking(14)
                        .foregroundStyle(.white)
                    Text("CITY")
                        .font(.system(size: 86, weight: .black))
                        .tracking(14)
                        .foregroundStyle(Color.skRed)
                        .shadow(color: Color.skRed.opacity(0.9), radius: 24)
                }
                .scaleEffect(logoScale)
                .opacity(logoAlpha)

                Spacer().frame(height: 36)

                Text("ARE YOU READY TO DROP IN?")
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(6)
                    .foregroundStyle(Color.skSteel)
                    .opacity(taglineAlpha)

                Spacer()

                // Drop In button
                Button(action: onDrop) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.skRed.opacity(0.35))
                            .blur(radius: pulse ? 22 : 10)
                            .scaleEffect(pulse ? 1.10 : 1.0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.skRed)
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                        Text("DROP IN")
                            .font(.system(size: 23, weight: .black))
                            .tracking(9)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 260, height: 66)
                }
                .buttonStyle(.plain)
                .scaleEffect(btnScale)

                Spacer().frame(height: 90)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.70).delay(0.10)) {
                logoScale = 1.0; logoAlpha = 1.0
            }
            withAnimation(.easeIn(duration: 0.55).delay(0.55)) {
                taglineAlpha = 1.0
            }
            withAnimation(.spring(response: 0.48, dampingFraction: 0.78).delay(0.82)) {
                btnScale = 1.0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(1.2)) {
                pulse = true
            }
        }
    }
}

// Deterministic city skyline so Canvas never flickers on re-draw
private struct CitySkylineCanvas: View {
    private struct Building { let xFrac, wFrac, hFrac: CGFloat }
    private let buildings: [Building] = [
        .init(xFrac: 0.01, wFrac: 0.07, hFrac: 0.52),
        .init(xFrac: 0.06, wFrac: 0.05, hFrac: 0.38),
        .init(xFrac: 0.10, wFrac: 0.09, hFrac: 0.64),
        .init(xFrac: 0.18, wFrac: 0.07, hFrac: 0.47),
        .init(xFrac: 0.24, wFrac: 0.11, hFrac: 0.72),
        .init(xFrac: 0.34, wFrac: 0.08, hFrac: 0.44),
        .init(xFrac: 0.41, wFrac: 0.09, hFrac: 0.58),
        .init(xFrac: 0.49, wFrac: 0.12, hFrac: 0.82),
        .init(xFrac: 0.60, wFrac: 0.07, hFrac: 0.53),
        .init(xFrac: 0.66, wFrac: 0.10, hFrac: 0.68),
        .init(xFrac: 0.75, wFrac: 0.08, hFrac: 0.46),
        .init(xFrac: 0.82, wFrac: 0.09, hFrac: 0.61),
        .init(xFrac: 0.90, wFrac: 0.07, hFrac: 0.50),
        .init(xFrac: 0.96, wFrac: 0.06, hFrac: 0.39),
    ]

    var body: some View {
        Canvas { ctx, size in
            for (bi, b) in buildings.enumerated() {
                let bh = size.height * b.hFrac
                let rect = CGRect(
                    x: size.width * b.xFrac,
                    y: size.height - bh,
                    width: size.width * b.wFrac,
                    height: bh
                )
                ctx.fill(Path(rect), with: .color(Color(white: 0.07)))

                let cols = Int(rect.width / 8)
                let rows = Int(bh / 12)
                for r in 0..<rows {
                    for c in 0..<cols {
                        // deterministic "25% windows lit" pattern
                        if (bi * 7 + r * 5 + c * 3) % 4 == 0 {
                            let wr = CGRect(
                                x: rect.minX + CGFloat(c) * 8 + 2,
                                y: rect.minY + CGFloat(r) * 12 + 3,
                                width: 4, height: 6
                            )
                            ctx.fill(Path(wr), with: .color(.yellow.opacity(0.35)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - STEP 2: Skater Card

private struct SkaterCardStepView: View {
    @Binding var profile: SkaterDraftProfile
    let onNext: () -> Void
    let onBack: () -> Void

    private var canAdvance: Bool {
        !profile.name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            RedBanner(title: "CREATE YOUR SKATER", stepNum: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    FieldBlock(label: "SKATER NAME") {
                        DarkField("Enter your skater name", text: $profile.name)
                    }
                    FieldBlock(label: "AGE") {
                        DarkField("How old are you?", text: $profile.age)
                    }
                    FieldBlock(label: "EMAIL") {
                        DarkField("your@email.com", text: $profile.email)
                    }
                    FieldBlock(label: "STANCE") {
                        HStack(spacing: 12) {
                            ForEach(SkaterStance.allCases) { s in
                                StanceCard(stance: s, isSelected: profile.stance == s) {
                                    profile.stance = s
                                }
                            }
                        }
                    }
                    FieldBlock(label: "SKATING STYLE") {
                        VStack(spacing: 8) {
                            ForEach(SkatingStyle.allCases) { s in
                                StyleRow(style: s, isSelected: profile.style == s) {
                                    profile.style = s
                                }
                            }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, 110)
            }

            BottomNav(canAdvance: canAdvance, showBack: false, onBack: onBack, onNext: onNext)
        }
    }
}

private struct FieldBlock<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
                .font(.system(size: 10, weight: .black))
                .tracking(3)
                .foregroundStyle(Color.skRed)
            content()
        }
    }
}

private struct DarkField: View {
    let placeholder: String
    @Binding var text: String
    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }
    var body: some View {
        TextField(placeholder, text: $text)
            .foregroundStyle(.white)
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.skPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .strokeBorder(Color.skRed.opacity(0.4), lineWidth: 1)
                    )
            )
    }
}

private struct StanceCard: View {
    let stance: SkaterStance
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(stance.rawValue.uppercased())
                    .font(.system(size: 15, weight: .black))
                    .tracking(2)
                Text(stance.subtitle)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? .white : Color.skSteel)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.skRed : Color.skPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.07),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct StyleRow: View {
    let style: SkatingStyle
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Text(style.icon).font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(style.rawValue.uppercased())
                        .font(.system(size: 14, weight: .black))
                        .tracking(2)
                        .foregroundStyle(isSelected ? .white : Color.skSteel)
                    Text(style.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.skSteel.opacity(0.65))
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.skRed)
                        .font(.title3)
                }
            }
            .padding(15)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.skRed.opacity(0.14) : Color.skPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(
                                isSelected ? Color.skRed.opacity(0.55) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Character Preview Canvas

enum PreviewFocus { case outfit, board, shoes }

struct CharacterPreviewCanvas: View {
    let profile: SkaterDraftProfile
    let focus: PreviewFocus

    private var topColor: Color {
        switch profile.outfitTop {
        case "Spitfire Hoodie": return Color(red: 0.83, green: 0.12, blue: 0.12)
        case "Zoo York Tee":    return Color(red: 0.14, green: 0.24, blue: 0.78)
        case "Baker Flannel":   return Color(red: 0.55, green: 0.18, blue: 0.18)
        case "Thrasher Tee":    return Color(red: 0.08, green: 0.08, blue: 0.08)
        case "Primitive Tee":   return Color(red: 0.20, green: 0.20, blue: 0.22)
        default:                return Color(red: 0.28, green: 0.28, blue: 0.30)
        }
    }
    private var pantsColor: Color {
        switch profile.outfitPants {
        case "Baggy Jeans":  return Color(red: 0.28, green: 0.33, blue: 0.55)
        case "Slim Jeans":   return Color(red: 0.18, green: 0.22, blue: 0.44)
        case "Ripped Jeans": return Color(red: 0.22, green: 0.28, blue: 0.50)
        case "Cargos":       return Color(red: 0.32, green: 0.30, blue: 0.22)
        default:             return Color(red: 0.22, green: 0.28, blue: 0.46)
        }
    }
    private var shoeColor: Color {
        switch profile.shoe {
        case "Vans Old Skool":    return Color(white: 0.95)
        case "Vans Checkerboard": return Color(white: 0.88)
        case "Nike SB Dunk":      return Color(red: 0.80, green: 0.14, blue: 0.14)
        case "Adidas Samba":      return Color(white: 0.92)
        case "DC Court Graffik":  return Color(white: 0.10)
        case "Emerica Reynolds":  return Color(red: 0.10, green: 0.10, blue: 0.72)
        default:                  return Color(white: 0.90)
        }
    }
    private var deckColor: Color {
        switch profile.deckGraphic {
        case "Anti Hero Eagle":     return Color(red: 0.83, green: 0.12, blue: 0.12)
        case "Zoo York Subway":     return Color(red: 0.12, green: 0.12, blue: 0.78)
        case "Baker Brand Logo":    return Color(red: 0.65, green: 0.14, blue: 0.14)
        case "Girl Chocolate":      return Color(red: 0.58, green: 0.38, blue: 0.18)
        case "Primitive Dragon":    return Color(red: 0.10, green: 0.62, blue: 0.34)
        case "Deathwish Gang Logo": return Color(white: 0.08)
        default:                    return Color(red: 0.55, green: 0.38, blue: 0.16)
        }
    }

    var body: some View {
        Canvas { ctx, size in
            let cx  = size.width * 0.5
            let sc  = size.height / 320
            let by  = size.height * 0.78      // board Y

            // Ground shadow
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 45*sc, y: by + 18*sc, width: 90*sc, height: 9*sc)),
                with: .color(.black.opacity(0.28))
            )

            // — BOARD —
            var dk = Path()
            dk.addRoundedRect(
                in: CGRect(x: cx - 32*sc, y: by, width: 64*sc, height: 10*sc),
                cornerSize: CGSize(width: 6*sc, height: 5*sc)
            )
            ctx.fill(dk, with: .color(deckColor))
            ctx.stroke(dk, with: .color(.white.opacity(0.14)), lineWidth: 0.8)
            // Trucks
            for xo: CGFloat in [-20, 20] {
                ctx.fill(
                    Path(CGRect(x: cx + xo*sc - 18*sc, y: by + 8*sc, width: 36*sc, height: 4*sc)),
                    with: .color(Color(white: 0.58))
                )
            }
            // Wheels
            for xo: CGFloat in [-28, -10, 10, 28] {
                ctx.fill(
                    Path(ellipseIn: CGRect(x: cx + xo*sc - 5*sc, y: by + 10*sc, width: 10*sc, height: 10*sc)),
                    with: .color(Color(white: 0.84))
                )
            }

            // — LEGS —
            let hipY = by - 52*sc
            var ll = Path()
            ll.move(to:    CGPoint(x: cx - 5*sc,  y: hipY))
            ll.addLine(to: CGPoint(x: cx - 14*sc, y: by + 1*sc))
            ll.addLine(to: CGPoint(x: cx - 4*sc,  y: by + 1*sc))
            ll.addLine(to: CGPoint(x: cx + 4*sc,  y: hipY))
            ctx.fill(ll, with: .color(pantsColor))

            var rl = Path()
            rl.move(to:    CGPoint(x: cx + 4*sc,  y: hipY))
            rl.addLine(to: CGPoint(x: cx + 10*sc, y: by + 1*sc))
            rl.addLine(to: CGPoint(x: cx + 22*sc, y: by + 1*sc))
            rl.addLine(to: CGPoint(x: cx + 16*sc, y: hipY))
            ctx.fill(rl, with: .color(pantsColor))

            // Shoes
            for (xo, wm): (CGFloat, CGFloat) in [(-15, 1.0), (8, 0.9)] {
                var sh = Path()
                sh.addRoundedRect(
                    in: CGRect(x: cx + xo*sc, y: by - 2*sc, width: 16*wm*sc, height: 8*sc),
                    cornerSize: CGSize(width: 3*sc, height: 3*sc)
                )
                ctx.fill(sh, with: .color(shoeColor))
            }

            // — TORSO —
            let tt = hipY - 75*sc
            var torso = Path()
            torso.addRoundedRect(
                in: CGRect(x: cx - 18*sc, y: tt, width: 38*sc, height: 75*sc),
                cornerSize: CGSize(width: 5*sc, height: 5*sc)
            )
            ctx.fill(torso, with: .color(topColor))
            // Collar V
            var collar = Path()
            collar.move(to:    CGPoint(x: cx - 8*sc, y: tt))
            collar.addLine(to: CGPoint(x: cx,        y: tt + 12*sc))
            collar.addLine(to: CGPoint(x: cx + 8*sc, y: tt))
            ctx.stroke(collar, with: .color(.white.opacity(0.18)), lineWidth: 1.5)

            // — ARMS —
            var la = Path()
            la.move(to:    CGPoint(x: cx - 16*sc, y: tt + 8*sc))
            la.addLine(to: CGPoint(x: cx - 30*sc, y: tt + 55*sc))
            la.addLine(to: CGPoint(x: cx - 23*sc, y: tt + 58*sc))
            la.addLine(to: CGPoint(x: cx - 10*sc, y: tt + 12*sc))
            ctx.fill(la, with: .color(topColor))

            var ra = Path()
            ra.move(to:    CGPoint(x: cx + 16*sc, y: tt + 8*sc))
            ra.addLine(to: CGPoint(x: cx + 34*sc, y: tt + 38*sc))
            ra.addLine(to: CGPoint(x: cx + 27*sc, y: tt + 42*sc))
            ra.addLine(to: CGPoint(x: cx + 10*sc, y: tt + 12*sc))
            ctx.fill(ra, with: .color(topColor))

            // — HEAD —
            let hy = tt - 42*sc
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 17*sc, y: hy, width: 34*sc, height: 38*sc)),
                with: .color(Color(red: 0.84, green: 0.70, blue: 0.57))
            )
            // Hair
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 17*sc, y: hy, width: 34*sc, height: 15*sc)),
                with: .color(Color(red: 0.18, green: 0.14, blue: 0.11))
            )

            // Focus glow under highlighted area
            let glowColor: Color
            switch focus {
            case .outfit: glowColor = topColor
            case .board:  glowColor = deckColor
            case .shoes:  glowColor = shoeColor
            }
            ctx.fill(
                Path(ellipseIn: CGRect(x: cx - 50*sc, y: by - 6*sc, width: 100*sc, height: 32*sc)),
                with: .color(glowColor.opacity(0.25))
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(white: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.skRed.opacity(0.28), lineWidth: 1)
                )
        )
    }
}

// MARK: - Customizer Step Layout (shared)

private struct CustomizerStep<Panel: View>: View {
    let title:   String
    let stepNum: Int
    let profile: SkaterDraftProfile
    let focus:   PreviewFocus
    let panel:   Panel
    let onNext:  () -> Void
    let onBack:  () -> Void

    var body: some View {
        VStack(spacing: 0) {
            RedBanner(title: title, stepNum: stepNum)

            HStack(spacing: 0) {
                // Left: animated character
                CharacterPreviewCanvas(profile: profile, focus: focus)
                    .padding(14)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .animation(.spring(response: 0.35), value: profile.outfitTop)
                    .animation(.spring(response: 0.35), value: profile.deckGraphic)
                    .animation(.spring(response: 0.35), value: profile.shoe)

                Color.skRed.opacity(0.35).frame(width: 1)

                // Right: option list
                ScrollView {
                    panel.padding(16).padding(.bottom, 100)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            BottomNav(canAdvance: true, showBack: true, onBack: onBack, onNext: onNext)
        }
    }
}

// MARK: - Selection Widget

private struct ItemList: View {
    let sectionTitle: String
    let items: [String]
    @Binding var selected: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sectionTitle)
                .font(.system(size: 10, weight: .black))
                .tracking(3)
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.skRed)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            VStack(spacing: 5) {
                ForEach(items, id: \.self) { item in
                    Button {
                        withAnimation(.spring(response: 0.22)) { selected = item }
                    } label: {
                        HStack {
                            Text(item)
                                .font(.system(size: 13, weight: selected == item ? .bold : .regular))
                                .foregroundStyle(selected == item ? .white : Color.skSteel)
                            Spacer()
                            if selected == item {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.skRed)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selected == item ? Color.skRed.opacity(0.14) : Color.skPanel)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(
                                            selected == item ? Color.skRed.opacity(0.5) : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Outfit / Board / Shoes Panels

private struct OutfitPanelView: View {
    @Binding var profile: SkaterDraftProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ItemList(
                sectionTitle: "TOP",
                items: ["Spitfire Hoodie", "Zoo York Tee", "Baker Flannel", "Thrasher Tee", "Primitive Tee"],
                selected: $profile.outfitTop
            )
            ItemList(
                sectionTitle: "PANTS",
                items: ["Baggy Jeans", "Slim Jeans", "Ripped Jeans", "Cargos"],
                selected: $profile.outfitPants
            )
            ItemList(
                sectionTitle: "ACCESSORY",
                items: ["Snapback", "Beanie", "Bucket Hat", "None"],
                selected: $profile.accessory
            )
        }
    }
}

private struct BoardPanelView: View {
    @Binding var profile: SkaterDraftProfile
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ItemList(
                sectionTitle: "DECK GRAPHIC",
                items: ["Anti Hero Eagle", "Zoo York Subway", "Baker Brand Logo",
                        "Girl Chocolate", "Primitive Dragon", "Deathwish Gang Logo"],
                selected: $profile.deckGraphic
            )
            ItemList(
                sectionTitle: "TRUCKS",
                items: ["Silver", "Black", "Gold", "Raw"],
                selected: $profile.truckColor
            )
            ItemList(
                sectionTitle: "WHEELS",
                items: ["Natural", "White", "Yellow", "Red", "Black"],
                selected: $profile.wheelColor
            )
        }
    }
}

private struct ShoesPanelView: View {
    @Binding var profile: SkaterDraftProfile
    var body: some View {
        ItemList(
            sectionTitle: "SHOES",
            items: ["Vans Old Skool", "Vans Checkerboard", "Nike SB Dunk",
                    "Adidas Samba", "DC Court Graffik", "Emerica Reynolds"],
            selected: $profile.shoe
        )
    }
}

// MARK: - STEP 6: Drop In

private struct DropInStepView: View {
    let profile: SkaterDraftProfile
    let onComplete: () -> Void

    @State private var cardAlpha:  Double  = 0
    @State private var cardOffset: CGFloat = 36
    @State private var btnPulse  = false

    var body: some View {
        ZStack {
            CitySkylineCanvas().opacity(0.18).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                ZStack {
                    LinearGradient(
                        colors: [Color.skRed, Color(red: 0.45, green: 0.04, blue: 0.04)],
                        startPoint: .leading, endPoint: .trailing
                    )
                    Text("SKATER PROFILE")
                        .font(.system(size: 22, weight: .black))
                        .tracking(5)
                        .foregroundStyle(.white)
                }
                .frame(height: 62)
                Color.skRed.opacity(0.55).frame(height: 2)

                Spacer()

                // Profile card
                VStack(spacing: 0) {
                    // Name + tags
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(profile.name.isEmpty ? "ANONYMOUS" : profile.name.uppercased())
                                .font(.system(size: 26, weight: .black))
                                .tracking(2)
                                .foregroundStyle(.white)
                            HStack(spacing: 8) {
                                ProfileTag(profile.stance.rawValue)
                                ProfileTag(profile.style.rawValue)
                            }
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(Color.skRed.opacity(0.14))

                    Divider().overlay(Color.skRed.opacity(0.35))

                    HStack(alignment: .top, spacing: 0) {
                        CharacterPreviewCanvas(profile: profile, focus: .outfit)
                            .frame(width: 130, height: 190)
                            .padding(10)

                        Divider().overlay(Color.skRed.opacity(0.25))

                        VStack(alignment: .leading, spacing: 10) {
                            ProfileRow(icon: "tshirt",          label: "TOP",    value: profile.outfitTop)
                            ProfileRow(icon: "figure.walk",      label: "PANTS",  value: profile.outfitPants)
                            ProfileRow(icon: "shoeprints.fill",  label: "SHOES",  value: profile.shoe)
                            ProfileRow(icon: "rectangle.fill",   label: "DECK",   value: profile.deckGraphic)
                            ProfileRow(icon: "gearshape.fill",   label: "TRUCKS", value: profile.truckColor)
                            ProfileRow(icon: "circle.fill",      label: "WHEELS", value: profile.wheelColor)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .background(Color.skPanel)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.skRed.opacity(0.45), lineWidth: 1)
                )
                .shadow(color: Color.skRed.opacity(0.15), radius: 20)
                .padding(.horizontal, 22)
                .opacity(cardAlpha)
                .offset(y: cardOffset)

                Spacer()

                // Drop In CTA
                Button(action: onComplete) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.skRed.opacity(0.38))
                            .blur(radius: btnPulse ? 22 : 8)
                            .scaleEffect(btnPulse ? 1.08 : 1.0)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.skRed)
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.white.opacity(0.20), lineWidth: 1)
                        Text("DROP IN!")
                            .font(.system(size: 22, weight: .black))
                            .tracking(9)
                            .foregroundStyle(.white)
                    }
                    .frame(width: 270, height: 66)
                }
                .buttonStyle(.plain)

                Spacer().frame(height: 70)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.78).delay(0.15)) {
                cardAlpha = 1; cardOffset = 0
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(0.8)) {
                btnPulse = true
            }
        }
    }
}

private struct ProfileTag: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .black))
            .tracking(2)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.skRed.opacity(0.80))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

private struct ProfileRow: View {
    let icon: String
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(Color.skRed)
                .frame(width: 14)
            Text(label)
                .font(.system(size: 9, weight: .black))
                .tracking(2)
                .foregroundStyle(Color.skSteel)
                .frame(width: 46, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView()
}
