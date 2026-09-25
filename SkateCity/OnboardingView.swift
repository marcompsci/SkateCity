import SwiftUI

// MARK: - Legacy profile (kept for UserDefaults compat with GameViewController)

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
    case regular = "Regular"; case goofy = "Goofy"
    var id: String { rawValue }
}

enum SkatingStyle: String, CaseIterable, Codable, Identifiable {
    case street = "Street"; case vert = "Vert"; case park = "Park"; case cruiser = "Cruiser"
    var id: String { rawValue }
}

// MARK: - Brand palette

private extension Color {
    static let obOrange = Color(hex: "#ff7a1a")
    static let obRed    = Color(hex: "#e0463c")
    static let obDark   = Color(hex: "#0b0b0c")
    static let obPanel  = Color(hex: "#101010")
    static let obSteel  = Color(white: 0.55)
    static let obCoin   = Color(hex: "#72c269")
}

// MARK: - Skew effect

struct SkewX: GeometryEffect {
    var degrees: Double
    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = CGFloat(tan(degrees * .pi / 180))
        return ProjectionTransform(CGAffineTransform(a: 1, b: 0, c: t, d: 1, tx: 0, ty: 0))
    }
}

// MARK: - Step enum

private enum ObStep: Int, CaseIterable {
    case title, createSkater, store, boardRoom, review
}

// MARK: - Root

struct OnboardingView: View {
    @State private var step    = ObStep.title
    @State private var forward = true
    @State private var profile = SkaterWardrobeProfile()

    var body: some View {
        ZStack {
            Color.obDark.ignoresSafeArea()
            Group {
                switch step {
                case .title:        TitleScreenView(profile: profile, onDrop: advance)
                case .createSkater: CreateASkaterView(profile: $profile, onNext: advance, onBack: retreat)
                case .store:        StoreScreenView(profile: $profile, onNext: advance, onBack: retreat)
                case .boardRoom:    BoardRoomView(profile: $profile, onNext: advance, onBack: retreat)
                case .review:       ReviewView(profile: profile, onComplete: complete, onBack: retreat)
                }
            }
            .id(step)
            .transition(.asymmetric(
                insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                removal:   .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
            ))
        }
        .ignoresSafeArea()
        .onAppear { if profile.owned.isEmpty { profile.initStarterOwned() } }
    }

    private func advance() {
        forward = true
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            let all = ObStep.allCases
            if let i = all.firstIndex(of: step), i + 1 < all.count { step = all[i + 1] }
        }
    }
    private func retreat() {
        forward = false
        withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
            let all = ObStep.allCases
            if let i = all.firstIndex(of: step), i > 0 { step = all[i - 1] }
        }
    }
    private func complete() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "skaterWardrobeProfile")
        }
        var legacy = SkaterDraftProfile()
        legacy.name   = profile.username
        legacy.stance = profile.stance == "goofy" ? .goofy : .regular
        if let data = try? JSONEncoder().encode(legacy) {
            UserDefaults.standard.set(data, forKey: "skaterProfile")
        }
        UserDefaults.standard.set(true, forKey: "onboardingComplete")
    }
}

// MARK: - Brick wall canvas

struct BrickWallCanvas: View {
    var body: some View {
        Canvas { ctx, size in
            let bh: CGFloat = 22
            let bw: CGFloat = 46
            let gap: CGFloat = 3
            let rows = Int(size.height / (bh + gap)) + 2
            let cols = Int(size.width  / (bw + gap)) + 3
            for r in 0..<rows {
                let xOff: CGFloat = (r % 2 == 0) ? 0 : (bw + gap) * 0.5
                for c in (-1)..<cols {
                    let x = CGFloat(c) * (bw + gap) + xOff
                    let y = CGFloat(r) * (bh + gap)
                    let v = Double((r * 7 + c * 13 + 3) % 9) / 80.0
                    ctx.fill(
                        Path(roundedRect: CGRect(x: x, y: y, width: bw, height: bh), cornerRadius: 1),
                        with: .color(Color(red: 0.22 + v, green: 0.10 + v * 0.4, blue: 0.08 + v * 0.3))
                    )
                }
            }
        }
    }
}

// MARK: - City skyline canvas

struct CitySkylineCanvas: View {
    private struct Bldg { let xf, wf, hf: CGFloat }
    private let bldgs: [Bldg] = [
        .init(xf:0.01,wf:0.07,hf:0.52), .init(xf:0.06,wf:0.05,hf:0.38),
        .init(xf:0.10,wf:0.09,hf:0.64), .init(xf:0.18,wf:0.07,hf:0.47),
        .init(xf:0.24,wf:0.11,hf:0.72), .init(xf:0.34,wf:0.08,hf:0.44),
        .init(xf:0.41,wf:0.09,hf:0.58), .init(xf:0.49,wf:0.12,hf:0.82),
        .init(xf:0.60,wf:0.07,hf:0.53), .init(xf:0.66,wf:0.10,hf:0.68),
        .init(xf:0.75,wf:0.08,hf:0.46), .init(xf:0.82,wf:0.09,hf:0.61),
        .init(xf:0.90,wf:0.07,hf:0.50), .init(xf:0.96,wf:0.06,hf:0.39),
    ]
    var body: some View {
        Canvas { ctx, size in
            for (bi, b) in bldgs.enumerated() {
                let bh   = size.height * b.hf
                let rect = CGRect(x: size.width*b.xf, y: size.height-bh, width: size.width*b.wf, height: bh)
                ctx.fill(Path(rect), with: .color(Color(white: 0.14)))
                ctx.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 2)),
                         with: .color(Color(white: 0.28)))
                let cols = Int(rect.width / 9), rows = Int(bh / 14)
                for r in 0..<rows { for c in 0..<cols {
                    if (bi*7+r*5+c*3) % 4 == 0 {
                        let isOrg = (bi*3+r*2+c) % 5 == 0
                        ctx.fill(
                            Path(CGRect(x: rect.minX+CGFloat(c)*9+2, y: rect.minY+CGFloat(r)*14+4, width: 5, height: 7)),
                            with: .color(isOrg ? Color(hex: "#ff7a1a").opacity(0.55) : .yellow.opacity(0.45))
                        )
                    }
                }}
            }
        }
    }
}

// MARK: - Skater silhouette placeholder

private struct SkaterSilhouette: View {
    var scale:      CGFloat = 1.0
    var skinColor:  Color   = Color(hex: "#d6a07a")
    var topColor:   Color   = Color.obOrange
    var pantsColor: Color   = Color(hex: "#2a2230")

    var body: some View {
        let s = scale
        VStack(spacing: 0) {
            // Head
            Circle()
                .fill(skinColor)
                .frame(width: 34 * s, height: 34 * s)
            // Torso / hoodie
            RoundedRectangle(cornerRadius: 6 * s)
                .fill(topColor)
                .frame(width: 40 * s, height: 56 * s)
                .offset(y: -3 * s)
            // Legs
            HStack(spacing: 6 * s) {
                RoundedRectangle(cornerRadius: 4 * s)
                    .fill(pantsColor)
                    .frame(width: 16 * s, height: 50 * s)
                RoundedRectangle(cornerRadius: 4 * s)
                    .fill(pantsColor)
                    .frame(width: 16 * s, height: 50 * s)
            }
            .offset(y: -10 * s)
            // Shoes
            HStack(spacing: 6 * s) {
                RoundedRectangle(cornerRadius: 3 * s)
                    .fill(Color(white: 0.15))
                    .frame(width: 20 * s, height: 10 * s)
                RoundedRectangle(cornerRadius: 3 * s)
                    .fill(Color(white: 0.15))
                    .frame(width: 20 * s, height: 10 * s)
            }
            .offset(y: -18 * s)
            // Skateboard at feet
            RoundedRectangle(cornerRadius: 3 * s)
                .fill(Color(hex: "#3a1a12"))
                .frame(width: 52 * s, height: 8 * s)
                .offset(y: -16 * s)
        }
    }
}

// MARK: - Coin badge

private struct CoinBadge: View {
    let coins: Int
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.obCoin)
            Text("\(coins)")
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color.obCoin)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Slash button

private struct SlashButton: View {
    let label: String; let icon: String?; let ghost: Bool; let compact: Bool; let action: () -> Void
    init(_ label: String, icon: String? = nil, ghost: Bool = false, compact: Bool = false,
         action: @escaping () -> Void) {
        self.label = label; self.icon = icon; self.ghost = ghost
        self.compact = compact; self.action = action
    }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let ic = icon { Image(systemName: ic).font(.system(size: compact ? 11 : 13, weight: .black)) }
                Text(label).font(.system(size: compact ? 13 : 17, weight: .black)).tracking(1.2)
            }
            .modifier(SkewX(degrees: 12))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 16 : 22)
            .padding(.vertical, compact ? 8 : 11)
            .background(ghost ? Color.black.opacity(0.75) : Color.obOrange)
            .modifier(SkewX(degrees: -12))
            .shadow(color: ghost ? .clear : Color.obOrange.opacity(0.40), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section label

private func obLabel(_ t: String) -> some View {
    Text(t)
        .font(.system(size: 9, weight: .black))
        .tracking(4)
        .foregroundStyle(Color.obOrange)
}

// MARK: - Helper

private func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { max(lo, min(hi, v)) }

// MARK: - Screen 1: Title

private struct TitleScreenView: View {
    let profile: SkaterWardrobeProfile
    let onDrop:  () -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Background: deep gradient + city skyline
                LinearGradient(
                    colors: [Color(hex: "#110a05"), Color(hex: "#0b0b0c"), Color(hex: "#0f0806")],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.obOrange.opacity(0.15), .clear],
                    center: .bottomLeading,
                    startRadius: 0,
                    endRadius: geo.size.width * 0.80
                )
                .ignoresSafeArea()

                CitySkylineCanvas().opacity(0.45).ignoresSafeArea()

                // Subtle diagonal stripe
                Rectangle()
                    .fill(Color.obOrange)
                    .frame(width: geo.size.width * 1.5, height: 2)
                    .rotationEffect(.degrees(-6))
                    .offset(y: geo.size.height * 0.22)
                    .opacity(0.35)
                    .allowsHitTesting(false)

                VStack(alignment: .leading, spacing: 0) {
                    // ── TOP BAR ──────────────────────────────────────────
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SKATECITY")
                                .font(.system(size: 12, weight: .black))
                                .tracking(4)
                                .foregroundStyle(.white)
                            Text("A STREETLIFE WORLD")
                                .font(.system(size: 8, weight: .semibold))
                                .tracking(3)
                                .foregroundStyle(.white.opacity(0.50))
                        }

                        Spacer()

                        // Level chip
                        HStack(spacing: 0) {
                            ZStack {
                                Color.obOrange
                                Text("LV")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 24, height: 36)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(profile.username.isEmpty ? "NEW SKATER" : profile.username.uppercased())
                                    .font(.system(size: 9, weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(.white)
                                Text("LVLV \(profile.level)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.60))
                            }
                            .padding(.horizontal, 8)
                        }
                        .frame(height: 36)
                        .background(Color.black.opacity(0.72))
                        .overlay(Rectangle().fill(Color.obOrange).frame(height: 2), alignment: .bottom)
                    }
                    .padding(.horizontal, clamp(geo.size.width * 0.04, 16, 60))
                    .padding(.top, geo.safeAreaInsets.top + 12)

                    Spacer()

                    // ── MAIN MENU ──────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        // Primary: CREATE SKATER /
                        Button { onDrop() } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text("CREATE SKATER")
                                    .font(.system(size: clamp(geo.size.height * 0.080, 28, 58), weight: .black))
                                    .foregroundStyle(.white)
                                Text("/")
                                    .font(.system(size: clamp(geo.size.height * 0.080, 28, 58), weight: .black))
                                    .foregroundStyle(Color.obOrange)
                            }
                        }
                        .buttonStyle(.plain)

                        menuRow("QUICK DROP-IN",
                                size: clamp(geo.size.height * 0.060, 22, 44)) { onDrop() }
                        menuRow("HOW TO RIDE",
                                size: clamp(geo.size.height * 0.060, 22, 44)) {}

                        Text("Controls")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.38))
                            .padding(.top, 6)
                    }
                    .padding(.leading, clamp(geo.size.width * 0.06, 18, 80))

                    Spacer()

                    // ── BOTTOM HINT ────────────────────────────────────────
                    Text("TAP CREATE SKATER TO BEGIN")
                        .font(.system(size: 9, weight: .bold))
                        .tracking(4)
                        .foregroundStyle(.white.opacity(0.30))
                        .padding(.leading, clamp(geo.size.width * 0.06, 18, 80))
                        .padding(.bottom, geo.safeAreaInsets.bottom + 20)
                }
            }
        }
    }

    private func menuRow(_ label: String, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: size, weight: .black))
                .foregroundStyle(.white.opacity(0.40))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Screen 2: Create-A-Skater

private struct CreateASkaterView: View {
    @Binding var profile: SkaterWardrobeProfile
    let onNext: () -> Void
    let onBack: () -> Void

    private enum CASSection: String, CaseIterable {
        case look = "LOOK"; case hair = "HAIR"; case facial = "FACIAL"; case stance = "STANCE"
    }
    @State private var section = CASSection.look
    @FocusState private var nameFocused: Bool

    private var canAdvance: Bool { !profile.username.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {

                // ── LEFT: ICON STRIP ───────────────────────────────────────
                VStack(spacing: 0) {
                    Spacer().frame(height: geo.safeAreaInsets.top + 16)

                    VStack(spacing: 14) {
                        ForEach(CASSection.allCases, id: \.self) { sec in
                            Button {
                                withAnimation(.easeOut(duration: 0.16)) { section = sec }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(section == sec ? Color.obOrange : Color.black.opacity(0.80))
                                        .overlay(Circle().strokeBorder(
                                            .white.opacity(section == sec ? 0 : 0.18), lineWidth: 1.5))
                                    Image(systemName: icon(sec))
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 48, height: 48)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Spacer()

                    // GET THE DROP button
                    Button {
                        if canAdvance { onNext() }
                    } label: {
                        VStack(spacing: 3) {
                            Text("GET THE")
                                .font(.system(size: 8, weight: .black))
                                .tracking(2)
                            Text("DROP")
                                .font(.system(size: 14, weight: .black))
                                .tracking(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(canAdvance ? Color.obOrange : Color.obOrange.opacity(0.35))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                }
                .frame(width: 64)
                .background(Color.black.opacity(0.90))

                // ── CENTER: CHARACTER PREVIEW ───────────────────────────────
                ZStack {
                    BrickWallCanvas()
                    // Bottom fade
                    LinearGradient(colors: [.clear, Color.obDark.opacity(0.55)],
                                   startPoint: .top, endPoint: .bottom)
                    // Skater
                    SkaterSilhouette(
                        scale: clamp(geo.size.height / 200, 0.9, 1.5),
                        skinColor: Color(hex: Wardrobe.skinTones.indices.contains(profile.skin)
                            ? Wardrobe.skinTones[profile.skin] : "#d6a07a")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -10)
                }
                .frame(width: geo.size.width * 0.28)

                // ── RIGHT: CONTENT PANEL ────────────────────────────────────
                ZStack(alignment: .top) {
                    Color.obPanel

                    VStack(alignment: .leading, spacing: 0) {
                        // Top bar
                        HStack {
                            // Tab strip
                            ForEach(CASSection.allCases, id: \.self) { sec in
                                Button {
                                    withAnimation(.easeOut(duration: 0.16)) { section = sec }
                                } label: {
                                    VStack(spacing: 3) {
                                        Text(sec.rawValue)
                                            .font(.system(size: 10, weight: .black))
                                            .tracking(2)
                                            .foregroundStyle(section == sec ? Color.obOrange : .white.opacity(0.38))
                                        Rectangle()
                                            .fill(section == sec ? Color.obOrange : .clear)
                                            .frame(height: 2)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Coin display
                            Text("your coins: @\(profile.coins)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.obCoin)
                                .padding(.trailing, 16)
                        }
                        .padding(.top, geo.safeAreaInsets.top + 6)
                        .background(Color.black.opacity(0.45))

                        // Section content
                        ScrollView {
                            casContent
                                .padding(.horizontal, 18)
                                .padding(.top, 14)
                                .padding(.bottom, 80)
                        }
                    }

                    // Bottom action bar
                    VStack {
                        Spacer()
                        HStack {
                            Button { onBack() } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.left")
                                    Text("BACK")
                                }
                                .font(.system(size: 11, weight: .black))
                                .tracking(1)
                                .foregroundStyle(.white.opacity(0.55))
                            }
                            .buttonStyle(.plain)
                            .padding(.leading, 16)

                            Spacer()

                            if section == .stance {
                                SlashButton("LACE IT UP", icon: "checkmark", compact: true) {
                                    if canAdvance { onNext() }
                                }
                                .opacity(canAdvance ? 1 : 0.4)
                                .padding(.trailing, 16)
                            }
                        }
                        .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                        .background(
                            LinearGradient(colors: [.clear, Color.obPanel],
                                           startPoint: .top, endPoint: .bottom)
                        )
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder private var casContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch section {
            case .look:
                // Name card (matches reference design)
                VStack(alignment: .leading, spacing: 8) {
                    Text("name")
                        .font(.system(size: 26, weight: .black))
                        .foregroundStyle(.white)
                    TextField("enter your tag", text: $profile.username)
                        .focused($nameFocused)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .tint(Color.obOrange)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.10))
                        .overlay(Rectangle().fill(Color.obOrange).frame(height: 2), alignment: .bottom)
                    Text("letters, numbers, dots and dashes · shows\nup on the map and in the feed")
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.40))
                        .lineSpacing(3)
                    // Inline LACE IT UP (matches reference)
                    SlashButton("LACE IT UP", compact: true) {
                        nameFocused = false
                        withAnimation(.easeOut(duration: 0.16)) { section = .hair }
                    }
                    .opacity(canAdvance ? 1 : 0.35)
                    .padding(.top, 4)
                }

                obLabel("SKIN TONE").padding(.top, 8)
                LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Array(Wardrobe.skinTones.enumerated()), id: \.offset) { i, hex in
                        Button { profile.skin = i } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .overlay(Circle().strokeBorder(
                                    profile.skin == i ? .white : .clear, lineWidth: 2.5))
                                .frame(width: 30, height: 30)
                        }.buttonStyle(.plain)
                    }
                }

            case .hair:
                obLabel("STYLE")
                itemList(Wardrobe.hairstyles.map { ($0.id, $0.name) },
                         selected: profile.hair) { profile.hair = $0 }
                obLabel("COLOR").padding(.top, 8)
                colorGrid(Wardrobe.hairColors.map { $0.hex },
                          selected: profile.hairColor) { profile.hairColor = $0 }

            case .facial:
                obLabel("FACIAL HAIR")
                itemList(Wardrobe.facial.map { ($0.id, $0.name) },
                         selected: profile.facial) { profile.facial = $0 }

            case .stance:
                obLabel("STANCE")
                HStack(spacing: 10) {
                    ForEach(["regular", "goofy"], id: \.self) { s in
                        Button { profile.stance = s } label: {
                            VStack(spacing: 5) {
                                Image(systemName: s == "regular" ? "figure.walk" : "figure.walk.motion")
                                    .font(.system(size: 26))
                                Text(s.uppercased())
                                    .font(.system(size: 13, weight: .black))
                                    .tracking(2)
                                Text(s == "regular" ? "Left foot forward" : "Right foot forward")
                                    .font(.system(size: 10))
                                    .foregroundStyle(profile.stance == s ? .white.opacity(0.8) : Color.obSteel)
                            }
                            .foregroundStyle(profile.stance == s ? .white : Color.obSteel)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                Rectangle()
                                    .fill(profile.stance == s ? Color.obOrange : Color(white: 0.10))
                                    .overlay(Rectangle().strokeBorder(
                                        .white.opacity(profile.stance == s ? 0.14 : 0.07), lineWidth: 1))
                            )
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func itemList(_ items: [(String, String)], selected: String,
                           action: @escaping (String) -> Void) -> some View {
        VStack(spacing: 0) {
            ForEach(items, id: \.0) { id, name in
                Button { action(id) } label: {
                    HStack {
                        Text(name)
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        if selected == id {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .black))
                        }
                    }
                    .foregroundStyle(selected == id ? Color.obOrange : .white.opacity(0.75))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(selected == id ? Color.obOrange.opacity(0.12) : .clear)
                }
                .buttonStyle(.plain)
                Divider().background(Color.white.opacity(0.06))
            }
        }
        .background(Color(white: 0.06))
    }

    private func colorGrid(_ hexes: [String], selected: Int,
                            action: @escaping (Int) -> Void) -> some View {
        LazyVGrid(columns: Array(repeating: .init(.flexible(), spacing: 8), count: 8), spacing: 8) {
            ForEach(Array(hexes.enumerated()), id: \.offset) { i, hex in
                Button { action(i) } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .overlay(Circle().strokeBorder(
                            selected == i ? .white : Color(white: 0.30), lineWidth: 2))
                        .frame(width: 26, height: 26)
                }.buttonStyle(.plain)
            }
        }
    }

    private func icon(_ sec: CASSection) -> String {
        switch sec {
        case .look:   return "person.crop.circle"
        case .hair:   return "scissors"
        case .facial: return "mustache"
        case .stance: return "figure.skateboarding"
        }
    }
}

// MARK: - Screen 3: CURBSIDE Store

private struct StoreScreenView: View {
    @Binding var profile: SkaterWardrobeProfile
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var catIndex = 0
    @State private var toast: String?

    private var cat: WardrobeCategory { Wardrobe.store.categories[catIndex] }

    private func sel(for key: String) -> WardrobeSelection {
        switch key {
        case "hat":    return profile.hat
        case "top":    return profile.top
        case "bottom": return profile.bottom
        case "shoes":  return profile.shoes
        default:       return profile.extra
        }
    }
    private func setSel(_ key: String, _ val: WardrobeSelection) {
        switch key {
        case "hat":    profile.hat    = val
        case "top":    profile.top    = val
        case "bottom": profile.bottom = val
        case "shoes":  profile.shoes  = val
        default:       profile.extra  = val
        }
    }

    private var selectedIdx: Int {
        cat.items.firstIndex(where: { $0.id == sel(for: cat.key).itemID }) ?? 0
    }

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {

                // ── LEFT: STORE PANEL ───────────────────────────────────────
                VStack(spacing: 0) {

                    // CURBSIDE header
                    HStack(spacing: 0) {
                        ZStack {
                            Color.obOrange
                            Text("C")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 44, height: 44)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("CURBSIDE")
                                .font(.system(size: 14, weight: .black))
                                .tracking(2)
                                .foregroundStyle(.white)
                            HStack(spacing: 4) {
                                Text(cat.label)
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1)
                                    .foregroundStyle(.white.opacity(0.55))
                                Text("·")
                                    .foregroundStyle(.white.opacity(0.30))
                                Text("\(selectedIdx + 1) / \(cat.items.count)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.40))
                            }
                        }
                        .padding(.leading, 10)
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                    .background(Color.black.opacity(0.85))

                    // Category tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(Array(Wardrobe.store.categories.enumerated()), id: \.offset) { i, c in
                                Button { withAnimation(.easeOut(duration: 0.15)) { catIndex = i } } label: {
                                    VStack(spacing: 3) {
                                        Text(c.label)
                                            .font(.system(size: 10, weight: .black))
                                            .tracking(1)
                                            .foregroundStyle(catIndex == i ? Color.obOrange : .white.opacity(0.42))
                                        Rectangle()
                                            .fill(catIndex == i ? Color.obOrange : .clear)
                                            .frame(height: 2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                }.buttonStyle(.plain)
                            }
                        }
                    }
                    .background(Color.black.opacity(0.65))

                    // Item list
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(cat.items) { item in
                                storeRow(item: item, key: cat.key, geo: geo)
                                Divider().background(Color.white.opacity(0.06))
                            }
                        }
                    }
                    .background(Color(hex: "#0d0b0b"))

                    // Bottom nav
                    HStack {
                        Button { onBack() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("BACK")
                            }
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.50))
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .padding(.bottom, geo.safeAreaInsets.bottom)
                    .background(Color.black.opacity(0.80))
                }
                .frame(width: geo.size.width * 0.40)

                // ── RIGHT: CHARACTER PREVIEW ────────────────────────────────
                ZStack(alignment: .bottomTrailing) {
                    BrickWallCanvas()
                    LinearGradient(colors: [.clear, Color.obDark.opacity(0.38)],
                                   startPoint: .top, endPoint: .bottom)

                    // Skater in selected outfit
                    SkaterSilhouette(
                        scale: clamp(geo.size.height / 180, 1.0, 1.8),
                        skinColor: Color(hex: Wardrobe.skinTones.indices.contains(profile.skin)
                            ? Wardrobe.skinTones[profile.skin] : "#d6a07a"),
                        topColor:   sel(for: "top").color1(in: Wardrobe.store, key: "top"),
                        pantsColor: sel(for: "bottom").color1(in: Wardrobe.store, key: "bottom")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -20)

                    // SALE badge top right
                    Text("SALE")
                        .font(.system(size: 10, weight: .black))
                        .tracking(2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.obRed)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(.top, geo.safeAreaInsets.top + 10)
                        .padding(.trailing, 14)

                    // LOOKS GOOD button
                    SlashButton("LOOKS GOOD", icon: "arrow.right", compact: true) { onNext() }
                        .padding(.trailing, 14)
                        .padding(.bottom, geo.safeAreaInsets.bottom + 14)

                    // Coin display
                    CoinBadge(coins: profile.coins)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, geo.safeAreaInsets.top + 10)
                        .padding(.leading, 12)

                    // Toast
                    if let msg = toast {
                        Text(msg)
                            .font(.system(size: 16, weight: .black))
                            .modifier(SkewX(degrees: 10))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 7)
                            .background(Color.obOrange)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            .padding(.top, geo.safeAreaInsets.top + 50)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func storeRow(item: WardrobeItem, key: String, geo: GeometryProxy) -> some View {
        let curSel = sel(for: key)
        let isSel  = curSel.itemID == item.id
        let owned  = profile.isOwned(key: key, id: item.id)

        VStack(spacing: 0) {
            Button {
                if !isSel {
                    if owned || item.price == 0 {
                        setSel(key, WardrobeSelection(item.id))
                    } else if profile.buy(key: key, id: item.id, price: item.price) {
                        setSel(key, WardrobeSelection(item.id))
                        toast("PURCHASED!")
                    } else {
                        toast("NOT ENOUGH COINS")
                    }
                }
            } label: {
                HStack {
                    // Orange left-bar on selected
                    Rectangle()
                        .fill(Color.obOrange)
                        .frame(width: 3)
                        .opacity(isSel ? 1 : 0)

                    Text(item.name)
                        .font(.system(size: 13, weight: isSel ? .bold : .medium))
                        .lineLimit(1)
                        .foregroundStyle(isSel ? .white : .white.opacity(0.75))
                        .padding(.leading, 10)

                    Spacer()

                    Text(item.price == 0 ? "FREE" : "$\(item.price)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(owned ? Color.obCoin : Color.obSteel)
                        .padding(.trailing, 12)
                }
                .frame(height: 34)
                .background(isSel ? Color.obOrange.opacity(0.10) : .clear)
            }
            .buttonStyle(.plain)

            // Variant row under selected item
            if isSel && !item.variants.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        var s = curSel
                        s.variant = max(0, s.variant - 1)
                        setSel(key, s)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(item.variants.enumerated()), id: \.offset) { vi, v in
                                Button {
                                    var s = curSel; s.variant = vi
                                    setSel(key, s)
                                } label: {
                                    Circle()
                                        .fill(Color(hex: v.color1))
                                        .overlay(Circle().strokeBorder(
                                            curSel.variant == vi ? .white : Color(white: 0.30),
                                            lineWidth: curSel.variant == vi ? 2 : 1.2))
                                        .frame(width: 18, height: 18)
                                }.buttonStyle(.plain)
                            }
                        }
                    }

                    Button {
                        var s = curSel
                        s.variant = min(item.variants.count - 1, s.variant + 1)
                        setSel(key, s)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                    .buttonStyle(.plain)

                    if item.variants.indices.contains(curSel.variant) {
                        Text(item.variants[curSel.variant].name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.60))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55))
            }
        }
    }

    private func toast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation { toast = nil }
        }
    }
}

// MARK: - Screen 4: Board Room

private struct BoardRoomView: View {
    @Binding var profile: SkaterWardrobeProfile
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var catIndex = 0
    private var cat: WardrobeCategory { Wardrobe.boardShop.categories[catIndex] }

    private func sel(for key: String) -> WardrobeSelection {
        switch key {
        case "deck":   return profile.deck
        case "trucks": return profile.trucks
        case "wheels": return profile.wheels
        default:       return WardrobeSelection(profile.grip)
        }
    }
    private func setSel(_ key: String, _ val: WardrobeSelection) {
        switch key {
        case "deck":   profile.deck   = val
        case "trucks": profile.trucks = val
        case "wheels": profile.wheels = val
        default:       profile.grip   = val.itemID
        }
    }

    var body: some View {
        GeometryReader { geo in
            let curSel  = sel(for: cat.key)
            let selItem = cat.items.first(where: { $0.id == curSel.itemID }) ?? cat.items.first

            VStack(spacing: 0) {

                // ── TOP: DECK / GRIP / TRUCKS / WHEELS tabs ─────────────────
                HStack(spacing: 0) {
                    ForEach(Array(Wardrobe.boardShop.categories.enumerated()), id: \.offset) { i, c in
                        Button { withAnimation(.easeOut(duration: 0.15)) { catIndex = i } } label: {
                            VStack(spacing: 3) {
                                Text(c.label)
                                    .font(.system(size: clamp(geo.size.width * 0.022, 13, 22), weight: .black))
                                    .tracking(1)
                                    .foregroundStyle(catIndex == i ? .white : .white.opacity(0.40))
                                Rectangle()
                                    .fill(catIndex == i ? Color.obOrange : .clear)
                                    .frame(height: 3)
                                    .modifier(SkewX(degrees: catIndex == i ? -18 : 0))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)

                        if i < Wardrobe.boardShop.categories.count - 1 {
                            Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 20)
                        }
                    }

                    Spacer()

                    // Coin + LOOKS GOOD
                    HStack(spacing: 10) {
                        CoinBadge(coins: profile.coins)
                        SlashButton("LOOKS GOOD", icon: "arrow.right", compact: true) { onNext() }
                    }
                    .padding(.trailing, 14)
                }
                .padding(.top, geo.safeAreaInsets.top + 6)
                .background(Color.black.opacity(0.88))

                // ── MIDDLE: Board preview + char ────────────────────────────
                HStack(spacing: 0) {

                    // Board preview panel
                    ZStack(alignment: .bottomLeading) {
                        BrickWallCanvas()
                        LinearGradient(colors: [.clear, Color.obDark.opacity(0.5)],
                                       startPoint: .top, endPoint: .bottom)

                        VStack(alignment: .leading, spacing: 8) {
                            if let item = selItem {
                                // Board graphic
                                DeckThumbView(item: item, catalog: cat.key, large: true)
                                    .frame(width: 60, height: clamp(geo.size.height * 0.38, 80, 160))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .rotationEffect(.degrees(-90))
                                    .frame(maxWidth: .infinity)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("THE BOARD ROOM")
                                        .font(.system(size: 9, weight: .black))
                                        .tracking(3)
                                        .foregroundStyle(Color.obOrange)

                                    Text(item.name)
                                        .font(.system(size: clamp(geo.size.height * 0.055, 20, 38), weight: .black))
                                        .foregroundStyle(.white)
                                        .lineLimit(2)

                                    // POWERED badge
                                    Text("POWERED")
                                        .font(.system(size: 8, weight: .black))
                                        .tracking(2)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.obOrange.opacity(0.85))

                                    // BUY + FLIP buttons
                                    HStack(spacing: 8) {
                                        let owned = profile.isOwned(key: cat.key, id: item.id) || item.price == 0
                                        Button {
                                            if !owned {
                                                _ = profile.buy(key: cat.key, id: item.id, price: item.price)
                                            }
                                            setSel(cat.key, WardrobeSelection(item.id))
                                        } label: {
                                            Text(owned ? "EQUIPPED" : "BUY $\(item.price)")
                                                .font(.system(size: 11, weight: .black))
                                                .tracking(1)
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 7)
                                                .background(owned ? Color(white: 0.22) : Color.obOrange)
                                                .modifier(SkewX(degrees: -8))
                                        }
                                        .buttonStyle(.plain)

                                        Text("FLIP BOARD")
                                            .font(.system(size: 11, weight: .black))
                                            .tracking(1)
                                            .foregroundStyle(.white.opacity(0.70))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Color(white: 0.14))
                                            .overlay(Rectangle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
                                            .modifier(SkewX(degrees: -8))
                                    }
                                }
                                .padding(.leading, 16)
                                .padding(.bottom, 14)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                    .frame(width: geo.size.width * 0.42)

                    // Character preview on brick
                    ZStack {
                        BrickWallCanvas()
                        LinearGradient(colors: [.clear, Color.obDark.opacity(0.40)],
                                       startPoint: .top, endPoint: .bottom)
                        SkaterSilhouette(
                            scale: clamp(geo.size.height / 190, 1.0, 1.8),
                            skinColor: Color(hex: Wardrobe.skinTones.indices.contains(profile.skin)
                                ? Wardrobe.skinTones[profile.skin] : "#d6a07a")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .offset(y: -20)
                    }
                }
                .frame(maxHeight: .infinity)

                // ── BOTTOM: Horizontal deck carousel ───────────────────────
                ZStack {
                    Color.black.opacity(0.88)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(cat.items) { item in
                                let isSel = curSel.itemID == item.id
                                Button {
                                    let owned = profile.isOwned(key: cat.key, id: item.id) || item.price == 0
                                    var s = sel(for: cat.key); s.itemID = item.id
                                    if owned { setSel(cat.key, s) }
                                    else if profile.buy(key: cat.key, id: item.id, price: item.price) {
                                        setSel(cat.key, s)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        DeckThumbView(item: item, catalog: cat.key, large: false)
                                            .frame(width: 32, height: clamp(geo.size.height * 0.09, 44, 70))
                                            .clipShape(RoundedRectangle(cornerRadius: 4))
                                        Text(item.name)
                                            .font(.system(size: 8, weight: .bold))
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                            .foregroundStyle(isSel ? Color.obOrange : .white.opacity(0.55))
                                    }
                                    .frame(width: 52)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isSel ? Color.obOrange.opacity(0.14) : .clear)
                                            .overlay(RoundedRectangle(cornerRadius: 4)
                                                .strokeBorder(isSel ? Color.obOrange : .clear, lineWidth: 1.5))
                                    )
                                    .offset(y: isSel ? -4 : 0)
                                    .animation(.easeOut(duration: 0.15), value: isSel)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 14)
                    }
                }
                .frame(height: clamp(geo.size.height * 0.19, 80, 110))

                // ── BACK button ─────────────────────────────────────────────
                HStack {
                    Button { onBack() } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .font(.system(size: 11, weight: .black))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.50))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 16)
                    Spacer()
                }
                .frame(height: 38 + geo.safeAreaInsets.bottom)
                .background(Color.black.opacity(0.85))
                .padding(.bottom, geo.safeAreaInsets.bottom)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Deck thumbnail

private struct DeckThumbView: View {
    let item:    WardrobeItem
    let catalog: String
    var large:   Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if !item.variants.isEmpty {
                    LinearGradient(
                        colors: [Color(hex: item.variants[0].color1),
                                 Color(hex: item.variants[0].color2)],
                        startPoint: .top, endPoint: .bottom
                    )
                } else {
                    Color(white: 0.18)
                }

                if catalog == "grip" {
                    Canvas { ctx, size in
                        for i in stride(from: 0.0, to: size.width, by: 3) {
                            for j in stride(from: 0.0, to: size.height, by: 3) {
                                if Int(i * 3 + j) % 5 < 3 {
                                    ctx.fill(
                                        Path(ellipseIn: CGRect(x: i, y: j, width: 1.5, height: 1.5)),
                                        with: .color(.white.opacity(0.20))
                                    )
                                }
                            }
                        }
                    }
                }

                if catalog == "trucks" {
                    // Hanger bar
                    Rectangle()
                        .fill(Color(white: 0.75))
                        .frame(width: geo.size.width * 0.85, height: geo.size.height * 0.18)
                }

                if catalog == "wheels" {
                    // Wheel circles
                    Circle()
                        .fill(Color(white: 0.92))
                        .frame(width: geo.size.width * 0.65)
                    Circle()
                        .stroke(.black.opacity(0.15), lineWidth: 1)
                        .frame(width: geo.size.width * 0.30)
                }
            }
        }
    }
}

// MARK: - Screen 5: Review

private struct ReviewView: View {
    let profile:    SkaterWardrobeProfile
    let onComplete: () -> Void
    let onBack:     () -> Void

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {

                // Left: char preview
                ZStack {
                    BrickWallCanvas()
                    LinearGradient(colors: [.clear, Color.obDark.opacity(0.50)],
                                   startPoint: .top, endPoint: .bottom)
                    SkaterSilhouette(
                        scale: clamp(geo.size.height / 185, 1.0, 1.8),
                        skinColor: Color(hex: Wardrobe.skinTones.indices.contains(profile.skin)
                            ? Wardrobe.skinTones[profile.skin] : "#d6a07a")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .offset(y: -14)

                    VStack(alignment: .leading) {
                        Spacer()
                        Text(profile.username.isEmpty ? "SKATER" : profile.username.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .foregroundStyle(.white)
                        Text(profile.stance.uppercased() + " STANCE")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(3)
                            .foregroundStyle(Color.obOrange)
                    }
                    .padding(.leading, 18)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
                .frame(width: geo.size.width * 0.42)

                // Right: summary panel
                VStack(alignment: .leading, spacing: 0) {
                    Text("READY TO SKATE")
                        .font(.system(size: 11, weight: .black))
                        .tracking(4)
                        .foregroundStyle(Color.obOrange)
                        .padding(.top, geo.safeAreaInsets.top + 18)
                        .padding(.leading, 20)

                    Text("Review your setup")
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(.white)
                        .padding(.leading, 20)
                        .padding(.bottom, 12)

                    ScrollView {
                        VStack(spacing: 0) {
                            reviewRow("STANCE",  profile.stance.uppercased())
                            reviewRow("SKIN",    "TONE \(profile.skin + 1)")
                            reviewRow("HAIR",    profile.hair.uppercased())
                            reviewRow("HAT",     profile.hat.itemID.uppercased())
                            reviewRow("TOP",     profile.top.itemID.uppercased())
                            reviewRow("BOTTOMS", profile.bottom.itemID.uppercased())
                            reviewRow("SHOES",   profile.shoes.itemID.uppercased())
                            reviewRow("DECK",    profile.deck.itemID.uppercased())
                            reviewRow("GRIP",    profile.grip.uppercased())
                            reviewRow("TRUCKS",  profile.trucks.itemID.uppercased())
                            reviewRow("WHEELS",  profile.wheels.itemID.uppercased())
                        }
                    }

                    Spacer()

                    HStack {
                        Button { onBack() } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("BACK")
                            }
                            .font(.system(size: 11, weight: .black))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.50))
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, 20)

                        Spacer()

                        SlashButton("DROP IN", icon: "skateboard") { onComplete() }
                            .padding(.trailing, 20)
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 14)
                }
                .background(Color.obPanel)
            }
            .ignoresSafeArea()
        }
    }

    private func reviewRow(_ label: String, _ value: String) -> some View {
        HStack {
            Rectangle().fill(Color.obOrange).frame(width: 3)
            Text(label)
                .font(.system(size: 10, weight: .black))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.45))
                .frame(width: 70, alignment: .leading)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
            Spacer()
        }
        .frame(height: 32)
        .padding(.horizontal, 16)
        .background(Color.white.opacity(0.025))
        .padding(.bottom, 1)
    }
}
