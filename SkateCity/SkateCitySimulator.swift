// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import SwiftUI

// MARK: - Simulator State

@Observable
final class SimState {
    // Board
    var boardX: CGFloat = 180
    var boardY: CGFloat = 0       // offset from ground — positive = airborne
    var boardRotation: Double = 0 // board flip/spin degrees (visual only)
    var isAirborne: Bool = false
    var isGrinding: Bool = false

    // Trick
    var currentTrickName: String = ""
    var trickFlashOpacity: Double = 0

    // Grind balance
    var balanceOffset: Double = 0   // -1 ... 1
    var balanceVel: Double = 0

    // Combo
    var comboScore: Int = 0
    var comboMultiplier: Int = 1
    var totalScore: Int = 0
    var lastBailed: Bool = false

    // Internal tick timer
    var tickCount: Int = 0
}

// MARK: - Main View

struct SkateCitySimulatorView: View {
    @State private var sim = SimState()
    @State private var timer: Timer? = nil

    // Obstacle definitions: (centerX, topY-from-ground, width, label)
    private let obstacles: [(x: CGFloat, groundH: CGFloat, w: CGFloat, label: String)] = [
        (300, 18, 80, "LEDGE"),
        (500, 28, 12, "RAIL"),
        (660, 44, 90, "KICKER"),
    ]
    private let groundY: CGFloat = 260

    var body: some View {
        ZStack {
            background
            sceneCanvas
            hudOverlay
            controlStrip
        }
        .frame(width: 390, height: 480)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.4), radius: 18, y: 8)
        .onAppear  { startTick() }
        .onDisappear { timer?.invalidate() }
    }

    // MARK: - Background

    var background: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(hue: 0.60, saturation: 0.55, brightness: 0.22),
                         Color(hue: 0.62, saturation: 0.40, brightness: 0.35)],
                startPoint: .top, endPoint: .bottom)

            // Ground / asphalt band
            Rectangle()
                .fill(Color(white: 0.18))
                .frame(height: 80)
        }
    }

    // MARK: - 2D Scene

    var sceneCanvas: some View {
        Canvas { ctx, size in
            let gy = groundY

            // Ground line
            ctx.stroke(Path { p in
                p.move(to: CGPoint(x: 0, y: gy))
                p.addLine(to: CGPoint(x: size.width, y: gy))
            }, with: .color(.white.opacity(0.12)), lineWidth: 1)

            // Obstacles
            for obs in obstacles {
                let rect = CGRect(x: obs.x - obs.w / 2,
                                  y: gy - obs.groundH,
                                  width: obs.w,
                                  height: obs.groundH)
                ctx.fill(Path(rect), with: .color(Color(white: 0.55, opacity: 0.85)))
                ctx.stroke(Path(rect), with: .color(.white.opacity(0.5)), lineWidth: 1)
            }

            // Board
            let bx = sim.boardX
            let by = gy - 10 - sim.boardY
            let boardRect = CGRect(x: bx - 24, y: by - 4, width: 48, height: 8)
            var t = CGAffineTransform(translationX: bx, y: by)
                .rotated(by: sim.boardRotation * .pi / 180)
                .translatedBy(x: -bx, y: -by)
            ctx.concatenate(t)
            ctx.fill(Path(boardRect), with: .color(.white))
            ctx.concatenate(t.inverted())

            // Wheels (small circles under board, skip when airborne if spinning fast)
            if abs(sim.boardRotation).truncatingRemainder(dividingBy: 360) < 270 {
                for wx in [bx - 16, bx + 16] {
                    let wr = CGRect(x: wx - 4, y: by + 4, width: 8, height: 8)
                    ctx.fill(Path(ellipseIn: wr), with: .color(Color(white: 0.85)))
                }
            }

            // Grind spark (rail contact glow)
            if sim.isGrinding {
                let spark = CGRect(x: bx - 6, y: by + 2, width: 12, height: 4)
                ctx.fill(Path(spark), with: .color(.yellow.opacity(0.85)))
            }
        }
    }

    // MARK: - HUD

    var hudOverlay: some View {
        VStack {
            HStack(alignment: .top) {
                // Score readout
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(sim.totalScore)")
                        .font(.system(size: 26, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                    if sim.comboMultiplier > 1 {
                        Text("\(sim.comboScore) × \(sim.comboMultiplier)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.yellow)
                    }
                }
                .padding(.leading, 16)
                .padding(.top, 14)

                Spacer()

                // Balance meter (only shown while grinding)
                if sim.isGrinding {
                    BalanceMeter(offset: sim.balanceOffset)
                        .padding(.top, 14)
                        .padding(.trailing, 16)
                }
            }

            Spacer()

            // Trick flash
            if sim.trickFlashOpacity > 0 {
                Text(sim.currentTrickName.uppercased())
                    .font(.system(size: 20, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .yellow.opacity(0.8), radius: 8)
                    .opacity(sim.trickFlashOpacity)
                    .padding(.bottom, 82)
            }

            // Bail flash
            if sim.lastBailed {
                Text("BAILED")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.red)
                    .padding(.bottom, 82)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Controls

    var controlStrip: some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                ForEach(TrickRegistryType.allCases.prefix(6), id: \.rawValue) { trick in
                    Button {
                        performTrick(trick)
                    } label: {
                        Text(shortLabel(trick))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 54, height: 32)
                            .background(Color.white.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 10)
        }
    }

    // MARK: - Simulation tick

    private func startTick() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        sim.tickCount += 1

        // Board rolls forward
        sim.boardX += isNearObstacle ? 0.3 : 1.2
        if sim.boardX > 390 + 30 { sim.boardX = -30 }

        // Gravity when airborne
        if sim.isAirborne {
            sim.boardY = max(0, sim.boardY - 2.4)
            sim.boardRotation += 12
            if sim.boardY <= 0 {
                sim.isAirborne = false
                sim.boardRotation = 0
                landTrick()
            }
        }

        // Grind balance drift
        if sim.isGrinding {
            let noise = sin(Double(sim.tickCount) * 0.23) * 0.04
            sim.balanceVel += noise
            sim.balanceVel *= 0.92
            sim.balanceOffset = max(-1, min(1, sim.balanceOffset + sim.balanceVel * 0.08))
            if abs(sim.balanceOffset) > 0.9 { bail() }
        }

        // Trick flash fade
        if sim.trickFlashOpacity > 0 {
            sim.trickFlashOpacity = max(0, sim.trickFlashOpacity - 0.025)
        }

        // Auto-grind when over rail
        let nearRail = obstacles.first(where: { $0.label == "RAIL" &&
            abs(sim.boardX - $0.x) < 20 })
        if !sim.isAirborne && nearRail != nil && !sim.isGrinding {
            sim.isGrinding = true
        } else if sim.isGrinding && nearRail == nil {
            sim.isGrinding = false
            sim.balanceOffset = 0
            sim.balanceVel = 0
        }
    }

    private var isNearObstacle: Bool {
        obstacles.contains { abs(sim.boardX - $0.x) < 60 }
    }

    // MARK: - Trick logic

    private func performTrick(_ trick: TrickRegistryType) {
        guard !sim.isAirborne else { return }
        let points = TrickRegistry.basePoints(for: trick)
        sim.currentTrickName = trick.rawValue
        sim.trickFlashOpacity = 1
        sim.lastBailed = false
        sim.isAirborne = true
        sim.boardY = 0
        sim.comboScore += points
        sim.comboMultiplier = min(8, sim.comboMultiplier + 1)
        withAnimation(.spring(duration: 0.1)) {
            sim.boardY = 60
        }
    }

    private func landTrick() {
        sim.totalScore += sim.comboScore * sim.comboMultiplier
        sim.comboScore = 0
        sim.comboMultiplier = 1
    }

    private func bail() {
        sim.isGrinding = false
        sim.lastBailed = true
        sim.comboScore = 0
        sim.comboMultiplier = 1
        sim.balanceOffset = 0
        sim.balanceVel = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            sim.lastBailed = false
        }
    }

    private func shortLabel(_ trick: TrickRegistryType) -> String {
        switch trick {
        case .ollie:          return "OLLIE"
        case .kickflip:       return "KICK"
        case .heelflip:       return "HEEL"
        case .popShuvit:      return "SHUV"
        case .impossible:     return "IMP"
        case .doubleKickflip: return "2×KF"
        case .varialKickflip: return "VAR K"
        case .varialHeelflip: return "VAR H"
        case .threeShoveIt:   return "360 S"
        case .threeFlip:      return "360 F"
        case .hardflip:       return "HARD"
        }
    }
}

// MARK: - Balance Meter

struct BalanceMeter: View {
    var offset: Double   // -1 ... 1

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.15))
                .frame(width: 80, height: 12)

            RoundedRectangle(cornerRadius: 3)
                .fill(meterColor)
                .frame(width: 10, height: 10)
                .offset(x: CGFloat((offset + 1) / 2) * 70)
                .animation(.linear(duration: 0.05), value: offset)
        }
        .frame(width: 80, height: 12)
        .overlay(
            Text("BALANCE")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .offset(y: 12)
        )
    }

    var meterColor: Color {
        let abs = Swift.abs(offset)
        if abs < 0.5 { return .green }
        if abs < 0.8 { return .yellow }
        return .red
    }
}

// MARK: - Preview

#Preview("SkateCity Simulator") {
    SkateCitySimulatorView()
        .frame(width: 390, height: 480)
        .background(Color.black)
}
