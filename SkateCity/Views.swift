//  Views.swift
//  SwiftUI screens: title/menu, loading, in-game HUD + touch controls, results.

import SwiftUI
import SceneKit

// MARK: - Root

struct RootView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        ZStack {
            switch model.screen {
            case .menu: MenuView()
            case .loading: LoadingView()
            case .playing: GameScreen()
            case .results: ResultsView()
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.25), value: model.screen)
    }
}

// MARK: - Menu

struct MenuView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.2), Color(red: 0.45, green: 0.1, blue: 0.45), .black],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            HStack(alignment: .center, spacing: 40) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("SKATECITY")
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .italic()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 0, x: 5, y: 5)
                    Text("STREET SESSIONS")
                        .font(.system(size: 18, weight: .heavy))
                        .tracking(6)
                        .foregroundStyle(.yellow)
                    Text("Best: \(model.bestScore.formatted())")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer().frame(height: 10)
                    Picker("Mode", selection: $model.mode) {
                        ForEach(GameMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    Picker("Graphics", selection: $model.quality) {
                        ForEach(GraphicsQuality.allCases) { Text("Graphics: \($0.rawValue)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)
                    Button {
                        model.beginLoading()
                    } label: {
                        Text("DROP IN")
                            .font(.system(size: 26, weight: .black))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 44).padding(.vertical, 14)
                            .background(Capsule().fill(.yellow))
                    }
                    .padding(.top, 8)
                }
                VStack(spacing: 10) {
                    Text("CHOOSE YOUR SKATER").font(.caption.weight(.heavy)).tracking(3).foregroundStyle(.white.opacity(0.7))
                    ForEach(Array(SkaterStyle.roster.enumerated()), id: \.offset) { i, s in
                        Button {
                            model.skaterIndex = i
                        } label: {
                            HStack(spacing: 12) {
                                Circle().fill(Color(s.top)).frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(.white, lineWidth: model.skaterIndex == i ? 3 : 0))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.headline).foregroundStyle(.white)
                                    Text(s.tagline).font(.caption).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                            }
                            .padding(10)
                            .frame(width: 250)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(model.skaterIndex == i ? Color.white.opacity(0.25) : Color.black.opacity(0.3)))
                        }
                    }
                }
            }
            .padding(30)
        }
    }
}

// MARK: - Loading

struct LoadingView: View {
    @EnvironmentObject var model: GameModel
    private let tips = [
        "Hold OLLIE to crouch, release to pop. Hold longer for more height.",
        "Tap MANUAL right as you land to keep your combo alive.",
        "FLIP + a direction = different flip tricks. Try up-left for a 360 Flip.",
        "Hit GRIND near a rail or ledge. Keep the balance meter centered with the stick.",
        "On quarter pipes, spin 180 in the air to land forward."
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Text("SKATECITY").font(.system(size: 44, weight: .black, design: .rounded)).italic().foregroundStyle(.white)
                ProgressView().tint(.yellow).scaleEffect(1.4)
                Text(tips.randomElement() ?? "").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                    .multilineTextAlignment(.center).frame(maxWidth: 480)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 120_000_000) // let this screen render first
            TextureCache.shared.warmUp()
            model.screen = .playing
        }
    }
}

// MARK: - Game

struct SceneKitView: UIViewRepresentable {
    let model: GameModel

    final class Coordinator {
        var engine: GameEngine?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero)
        let engine = GameEngine(view: view, model: model)
        context.coordinator.engine = engine
        engine.start()
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        coordinator.engine?.stop()
        coordinator.engine = nil
    }
}

struct GameScreen: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        ZStack {
            SceneKitView(model: model).ignoresSafeArea()
            HUDView()
            ControlsView()
            if model.isPaused { PauseView() }
        }
    }
}

struct HUDView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        VStack {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(model.score.formatted())
                        .font(.system(size: 34, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { i in
                            Text(["S", "K", "A", "T", "E"][i])
                                .font(.system(size: 16, weight: .black))
                                .foregroundStyle(model.letters[i] ? Color.yellow : Color.white.opacity(0.25))
                        }
                    }
                    Text("\(model.speedKmh) km/h").font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
                if model.mode == .session {
                    Text(String(format: "%d:%02d", model.timeLeft / 60, model.timeLeft % 60))
                        .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(model.timeLeft <= 10 ? Color.red : Color.white)
                        .shadow(color: .black, radius: 0, x: 2, y: 2)
                }
                Button { model.isPaused = true } label: {
                    Image(systemName: "pause.fill").font(.title2).foregroundStyle(.white)
                        .padding(10).background(Circle().fill(.black.opacity(0.35)))
                }
                .padding(.leading, 12)
            }
            .padding(.horizontal, 50).padding(.top, 20)

            if !model.comboText.isEmpty {
                VStack(spacing: 2) {
                    Text(model.comboText)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text("\(model.comboValue.formatted()) × \(model.comboMultiplier)")
                        .font(.system(size: 26, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.yellow)
                }
                .shadow(color: .black, radius: 0, x: 2, y: 2)
                .transition(.opacity)
            }

            if let msg = model.message {
                Text(msg)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .italic()
                    .foregroundStyle(.orange)
                    .shadow(color: .black, radius: 0, x: 3, y: 3)
                    .padding(.top, 6)
            }

            if let b = model.balance {
                HUDBalanceMeter(value: b).frame(width: 220, height: 16).padding(.top, 8)
            }
            Spacer()
        }
        .allowsHitTesting(true)
    }
}

struct HUDBalanceMeter: View {
    let value: Double
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(LinearGradient(colors: [.red, .yellow, .green, .yellow, .red], startPoint: .leading, endPoint: .trailing))
                    .opacity(0.85)
                Rectangle().fill(.white)
                    .frame(width: 4, height: geo.size.height + 8)
                    .offset(x: CGFloat((value + 1) / 2) * geo.size.width - 2)
            }
        }
    }
}

// MARK: - Touch controls

struct ControlsView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom) {
                Joystick { model.input.touchStick = $0 }
                    .frame(width: 170, height: 170)
                Spacer()
                ZStack {
                    ActionButton(label: "GRAB", color: .blue, size: 70,
                                 onPress: { model.input.touchGrab = true }, onRelease: { model.input.touchGrab = false })
                        .offset(x: 0, y: -80)
                    ActionButton(label: "FLIP", color: .red, size: 70,
                                 onPress: { model.input.pressFlip() }, onRelease: {})
                        .offset(x: -80, y: 0)
                    ActionButton(label: "GRIND", color: .purple, size: 70,
                                 onPress: { model.input.pressGrind(); model.input.touchGrind = true },
                                 onRelease: { model.input.touchGrind = false })
                        .offset(x: 80, y: 0)
                    ActionButton(label: "OLLIE", color: .green, size: 84,
                                 onPress: { model.input.touchOllie = true }, onRelease: { model.input.touchOllie = false })
                        .offset(x: 0, y: 80)
                    ActionButton(label: "MANUAL", color: .orange, size: 54,
                                 onPress: { model.input.pressManual() }, onRelease: {})
                        .offset(x: 80, y: -80)
                }
                .frame(width: 240, height: 240)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
    }
}

struct Joystick: View {
    let onChange: (SIMD2<Float>) -> Void
    @State private var knob: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                Circle().fill(.black.opacity(0.25)).overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 2))
                Circle().fill(.white.opacity(0.75)).frame(width: r * 0.8, height: r * 0.8).offset(knob)
            }
            .contentShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { v in
                        var dx = v.location.x - r, dy = v.location.y - r
                        let len = sqrt(dx * dx + dy * dy)
                        if len > r { dx *= r / len; dy *= r / len }
                        knob = CGSize(width: dx, height: dy)
                        onChange(SIMD2(Float(dx / r), Float(-dy / r)))
                    }
                    .onEnded { _ in
                        knob = .zero
                        onChange(SIMD2(0, 0))
                    }
            )
        }
    }
}

struct ActionButton: View {
    let label: String
    let color: Color
    let size: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void
    @State private var pressed = false

    var body: some View {
        Text(label)
            .font(.system(size: size * 0.2, weight: .black))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color.opacity(pressed ? 0.95 : 0.55)))
            .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 2))
            .scaleEffect(pressed ? 0.9 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !pressed { pressed = true; onPress() }
                    }
                    .onEnded { _ in
                        pressed = false
                        onRelease()
                    }
            )
    }
}

// MARK: - Pause & results

struct PauseView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("PAUSED").font(.system(size: 40, weight: .black)).foregroundStyle(.white)
                GoalsList()
                HStack(spacing: 16) {
                    Button("RESUME") { model.isPaused = false }
                        .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                    Button("QUIT") { model.quitToMenu() }
                        .buttonStyle(.bordered).tint(.white)
                }
                .font(.headline)
            }
        }
    }
}

struct GoalsList: View {
    @EnvironmentObject var model: GameModel
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(model.goals) { g in
                HStack {
                    Image(systemName: g.done ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(g.done ? Color.green : Color.white.opacity(0.5))
                    Text(g.title).foregroundStyle(.white)
                }
            }
        }
        .font(.subheadline.weight(.semibold))
    }
}

struct ResultsView: View {
    @EnvironmentObject var model: GameModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.3, green: 0.05, blue: 0.3)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            HStack(spacing: 60) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SESSION OVER").font(.system(size: 20, weight: .heavy)).tracking(4).foregroundStyle(.yellow)
                    Text(model.score.formatted())
                        .font(.system(size: 64, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                    Text(model.score >= model.bestScore && model.score > 0 ? "NEW PERSONAL BEST!" : "Best: \(model.bestScore.formatted())")
                        .font(.headline).foregroundStyle(.white.opacity(0.8))
                    HStack(spacing: 14) {
                        Button("SKATE AGAIN") { model.beginLoading() }
                            .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
                        Button("MENU") { model.screen = .menu }
                            .buttonStyle(.bordered).tint(.white)
                    }
                    .font(.headline)
                    .padding(.top, 10)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("GOALS").font(.caption.weight(.heavy)).tracking(3).foregroundStyle(.white.opacity(0.7))
                    GoalsList()
                }
            }
        }
    }
}
