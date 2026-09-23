import Foundation

// MARK: - Gesture Direction (mirrors Unity draft key codes: L/R/U/D)

enum TrickGesture: String {
    case up    = "U"   // swipe up on screen   → pop / launch
    case down  = "D"   // swipe down            → shove-it direction
    case left  = "L"   // swipe left            → kickflip axis
    case right = "R"   // swipe right           → heelflip axis
}

// MARK: - Trick Animation Parameters

struct TrickDefinition {
    let basePoints:  Int
    let flipAxis:    Float   // board Z-spin multiplier  (−1 = kickflip, +1 = heelflip)
    let shuvAxis:    Float   // board Y-spin multiplier  (0.5 = 180°,  1.0 = 360°)
    let wrapAxis:    Float   // board X-wrap             (impossible / hardflip)
    let airDuration: Float   // expected air time in seconds
}

// MARK: - Trick Types

enum TrickRegistryType: String, CaseIterable {
    // Single-gesture
    case ollie          = "Ollie"
    case kickflip       = "Kickflip"
    case heelflip       = "Heelflip"
    case popShuvit      = "Pop Shuvit"
    case impossible     = "Impossible"
    // Two-gesture combos (from Unity draft's Flips dictionary)
    case doubleKickflip = "Double Kickflip"
    case varialKickflip = "Varial Kickflip"
    case varialHeelflip = "Varial Heelflip"
    case threeShoveIt   = "360 Shove-it"
    case threeFlip      = "360 Flip"
    case hardflip       = "Hardflip"
}

// MARK: - Registry Lookup Table

enum TrickRegistry {

    /// Gesture-sequence key → trick.
    /// Keys are TrickGesture rawValues joined (e.g. "UD" = up then down = 360 Flip).
    static let table: [String: (type: TrickRegistryType, def: TrickDefinition)] = [
        "U":  (.ollie,          TrickDefinition(basePoints:  60,  flipAxis:  0,    shuvAxis:  0,    wrapAxis: 0,   airDuration: 0.35)),
        "L":  (.kickflip,       TrickDefinition(basePoints: 300,  flipAxis: -1,    shuvAxis:  0,    wrapAxis: 0,   airDuration: 0.42)),
        "R":  (.heelflip,       TrickDefinition(basePoints: 300,  flipAxis:  1,    shuvAxis:  0,    wrapAxis: 0,   airDuration: 0.42)),
        "D":  (.popShuvit,      TrickDefinition(basePoints: 250,  flipAxis:  0,    shuvAxis:  0.5,  wrapAxis: 0,   airDuration: 0.38)),
        "UU": (.impossible,     TrickDefinition(basePoints: 420,  flipAxis:  0,    shuvAxis:  0,    wrapAxis: 1,   airDuration: 0.48)),
        "LL": (.doubleKickflip, TrickDefinition(basePoints: 650,  flipAxis: -2,    shuvAxis:  0,    wrapAxis: 0,   airDuration: 0.60)),
        "DL": (.varialKickflip, TrickDefinition(basePoints: 500,  flipAxis: -1,    shuvAxis:  0.5,  wrapAxis: 0,   airDuration: 0.50)),
        "DR": (.varialHeelflip, TrickDefinition(basePoints: 500,  flipAxis:  1,    shuvAxis: -0.5,  wrapAxis: 0,   airDuration: 0.50)),
        "DD": (.threeShoveIt,   TrickDefinition(basePoints: 450,  flipAxis:  0,    shuvAxis:  1,    wrapAxis: 0,   airDuration: 0.50)),
        "UD": (.threeFlip,      TrickDefinition(basePoints: 800,  flipAxis: -1,    shuvAxis:  1,    wrapAxis: 0,   airDuration: 0.60)),
        "UL": (.hardflip,       TrickDefinition(basePoints: 600,  flipAxis: -1,    shuvAxis:  0,    wrapAxis: 0.5, airDuration: 0.55)),
    ]

    static func lookup(gestures: [TrickGesture]) -> (type: TrickRegistryType, def: TrickDefinition)? {
        table[gestures.map { $0.rawValue }.joined()]
    }

    static func basePoints(for type: TrickRegistryType) -> Int {
        table.values.first { $0.type == type }?.def.basePoints ?? 60
    }
}
