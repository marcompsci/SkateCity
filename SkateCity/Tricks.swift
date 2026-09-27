//  Tricks.swift
//  Trick definitions (flips, grabs, grinds), combo scoring and small math helpers.
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import simd

// MARK: - Stick direction helper

enum StickDir {
    case neutral, up, down, left, right, upLeft, upRight, downLeft, downRight

    init(_ s: SIMD2<Float>) {
        guard simd_length(s) > 0.4 else { self = .neutral; return }
        let a = atan2(s.y, s.x) // 0 = right, pi/2 = up
        let twoPi: Float = Float.pi * 2
        let normalized = (a + twoPi).truncatingRemainder(dividingBy: twoPi)
        let oct = Int((normalized + Float.pi / 8) / (Float.pi / 4)) % 8
        switch oct {
        case 0: self = .right
        case 1: self = .upRight
        case 2: self = .up
        case 3: self = .upLeft
        case 4: self = .left
        case 5: self = .downLeft
        case 6: self = .down
        default: self = .downRight
        }
    }
}

// MARK: - Flip tricks (Flip button + direction)

enum FlipKind {
    case kickflip, heelflip, shoveIt, impossible, treFlip, varialKick, varialHeel, hardflip

    static func from(_ s: SIMD2<Float>) -> FlipKind {
        switch StickDir(s) {
        case .neutral, .left: return .kickflip
        case .right: return .heelflip
        case .up: return .impossible
        case .down: return .shoveIt
        case .upLeft: return .treFlip
        case .upRight: return .hardflip
        case .downLeft: return .varialKick
        case .downRight: return .varialHeel
        }
    }

    var name: String {
        switch self {
        case .kickflip: return "Kickflip"
        case .heelflip: return "Heelflip"
        case .shoveIt: return "Pop Shove-It"
        case .impossible: return "Impossible"
        case .treFlip: return "360 Flip"
        case .varialKick: return "Varial Kickflip"
        case .varialHeel: return "Varial Heelflip"
        case .hardflip: return "Hardflip"
        }
    }

    var points: Int {
        switch self {
        case .kickflip, .heelflip, .shoveIt: return 100
        case .varialKick, .varialHeel: return 200
        case .hardflip: return 250
        case .impossible: return 250
        case .treFlip: return 350
        }
    }

    var duration: Float {
        switch self {
        case .treFlip, .hardflip, .impossible: return 0.5
        default: return 0.42
        }
    }

    /// Turns around each board axis: roll = long axis (Z), pitch = X, yaw = Y.
    private var turns: (roll: Float, pitch: Float, yaw: Float) {
        switch self {
        case .kickflip: return (-1, 0, 0)
        case .heelflip: return (1, 0, 0)
        case .shoveIt: return (0, 0, 0.5)
        case .impossible: return (0, 1, 0)
        case .treFlip: return (-1, 0, 1)
        case .varialKick: return (-1, 0, 0.5)
        case .varialHeel: return (1, 0, -0.5)
        case .hardflip: return (0.5, 0.5, 0)
        }
    }

    func rotation(at t: Float) -> simd_quatf {
        let tw = turns
        let full = Float.pi * 2
        return simd_quatf(angle: tw.yaw * full * t, axis: SIMD3(0, 1, 0)) *
            simd_quatf(angle: tw.pitch * full * t, axis: SIMD3(1, 0, 0)) *
            simd_quatf(angle: tw.roll * full * t, axis: SIMD3(0, 0, 1))
    }
}

// MARK: - Grabs (hold Grab + direction)

enum GrabKind {
    case melon, indy, method, noseGrab, tailGrab

    static func from(_ s: SIMD2<Float>) -> GrabKind {
        switch StickDir(s) {
        case .left, .upLeft, .downLeft: return .indy
        case .right, .upRight, .downRight: return .method
        case .up: return .noseGrab
        case .down: return .tailGrab
        case .neutral: return .melon
        }
    }

    var name: String {
        switch self {
        case .melon: return "Melon"
        case .indy: return "Indy"
        case .method: return "Method"
        case .noseGrab: return "Nosegrab"
        case .tailGrab: return "Tailgrab"
        }
    }

    var points: Int { self == .method ? 250 : 150 }
}

// MARK: - Grinds (Grind button + direction when you lock on)

enum GrindKind {
    case fiftyFifty, fiveO, noseGrind, boardslide

    static func from(_ s: SIMD2<Float>) -> GrindKind {
        switch StickDir(s) {
        case .up: return .noseGrind
        case .down: return .fiveO
        case .left, .right, .upLeft, .upRight, .downLeft, .downRight: return .boardslide
        case .neutral: return .fiftyFifty
        }
    }

    func name(on kind: Rail.Kind) -> String {
        switch (self, kind) {
        case (.fiftyFifty, .coping): return "Lip Grind"
        case (.fiftyFifty, _): return "50-50"
        case (.fiveO, _): return "5-0"
        case (.noseGrind, _): return "Nosegrind"
        case (.boardslide, .ledge): return "Noseblunt Slide"
        case (.boardslide, _): return "Boardslide"
        }
    }

    var points: Int { self == .fiftyFifty ? 100 : 175 }
}

// MARK: - Combo scoring (THPS-style: sum of tricks x number of tricks, repeats lose value)

struct ComboTracker {
    private(set) var names: [String] = []
    private(set) var base = 0
    private var counts: [String: Int] = [:]

    var active: Bool { !names.isEmpty }
    var multiplier: Int { names.count }
    var total: Int { base * max(1, multiplier) }

    mutating func add(_ name: String, _ value: Int) {
        let n = counts[name, default: 0]
        counts[name] = n + 1
        let factor = max(0.1, 1.0 - 0.25 * Double(n))
        base += Int(Double(value) * factor)
        names.append(name)
    }

    mutating func addBonus(_ v: Int) { base += max(0, v) }

    var text: String {
        guard !names.isEmpty else { return "" }
        let tail = names.suffix(4).joined(separator: " + ")
        return names.count > 4 ? "… + " + tail : tail
    }

    mutating func reset() {
        names = []
        base = 0
        counts = [:]
    }
}

// MARK: - Math helpers

@inline(__always) func wrapAngle(_ a: Float) -> Float {
    var x = a.truncatingRemainder(dividingBy: .pi * 2)
    if x > .pi { x -= .pi * 2 }
    if x < -.pi { x += .pi * 2 }
    return x
}

@inline(__always) func lerpAngle(_ a: Float, _ b: Float, _ t: Float) -> Float {
    a + wrapAngle(b - a) * t
}

@inline(__always) func lerp(_ a: Float, _ b: Float, _ t: Float) -> Float { a + (b - a) * t }

@inline(__always) func lerp3(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ t: Float) -> SIMD3<Float> { a + (b - a) * t }

func quatFromTo(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> simd_quatf {
    let d = simd_dot(a, b)
    if d > 0.99999 { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
    if d < -0.99999 {
        var axis = simd_cross(a, SIMD3<Float>(1, 0, 0))
        if simd_length(axis) < 1e-3 { axis = simd_cross(a, SIMD3<Float>(0, 0, 1)) }
        return simd_quatf(angle: .pi, axis: simd_normalize(axis))
    }
    return simd_quatf(from: a, to: b)
}

/// Two-bone IK (hip-knee-ankle / shoulder-elbow-wrist). Returns the middle joint and the reachable end point.
func twoBoneIK(root: SIMD3<Float>, target: SIMD3<Float>, l1: Float, l2: Float, bend: SIMD3<Float>) -> (joint: SIMD3<Float>, end: SIMD3<Float>) {
    var d = target - root
    var dist = simd_length(d)
    if dist < 1e-4 { d = SIMD3(0, -1, 0); dist = 1 }
    let dir = d / dist
    let reach = min(dist, l1 + l2 - 0.001)
    let a = (l1 * l1 - l2 * l2 + reach * reach) / (2 * reach)
    let h = sqrt(max(0, l1 * l1 - a * a))
    var b = bend - dir * simd_dot(bend, dir)
    if simd_length(b) < 1e-4 { b = SIMD3(1, 0, 0) }
    b = simd_normalize(b)
    return (root + dir * a + b * h, root + dir * reach)
}
