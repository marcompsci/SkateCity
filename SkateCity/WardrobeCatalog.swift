import Foundation
import SwiftUI

// MARK: - Catalog Types

struct WardrobeVariant: Codable, Identifiable {
    let name:   String
    let color1: String
    let color2: String
    var id: String { name }
}

struct WardrobeItem: Codable, Identifiable {
    let id:       String
    let name:     String
    let price:    Int
    var variants: [WardrobeVariant]
}

struct WardrobeCategory: Codable, Identifiable {
    let key:   String
    let label: String
    let items: [WardrobeItem]
    var id: String { key }
}

struct WardrobeCatalog: Codable {
    let name:       String
    let categories: [WardrobeCategory]

    func category(_ key: String) -> WardrobeCategory? {
        categories.first { $0.key == key }
    }
    func item(key: String, id: String) -> WardrobeItem? {
        category(key)?.items.first { $0.id == id }
    }
}

// MARK: - Selection

struct WardrobeSelection: Codable, Equatable {
    var itemID:  String
    var variant: Int
    init(_ id: String, _ v: Int = 0) { itemID = id; variant = v }

    func color1(in catalog: WardrobeCatalog, key: String) -> Color {
        guard let it = catalog.item(key: key, id: itemID),
              it.variants.indices.contains(variant) else { return .gray }
        return Color(hex: it.variants[variant].color1)
    }
    func color2(in catalog: WardrobeCatalog, key: String) -> Color {
        guard let it = catalog.item(key: key, id: itemID),
              it.variants.indices.contains(variant) else { return .gray }
        return Color(hex: it.variants[variant].color2)
    }
}

// MARK: - Skater Profile

struct SkaterWardrobeProfile: Codable {
    var username:  String            = ""
    var skin:      Int               = 5
    var hair:      String            = "fade"
    var hairColor: Int               = 0
    var facial:    String            = "none"
    var stance:    String            = "regular"
    // outfit
    var hat:       WardrobeSelection = .init("beanie")
    var top:       WardrobeSelection = .init("hoodie")
    var bottom:    WardrobeSelection = .init("jeans")
    var shoes:     WardrobeSelection = .init("vulcLow")
    var extra:     WardrobeSelection = .init("none")
    // board
    var deck:      WardrobeSelection = .init("roundel")
    var grip:      String            = "black"
    var trucks:    WardrobeSelection = .init("raw")
    var wheels:    WardrobeSelection = .init("w52")
    // economy
    var coins:     Int               = 250
    var owned:     [String]          = []
    var level:     Int               = 1

    mutating func initStarterOwned() {
        owned = Wardrobe.starterOwned
    }
    func isOwned(key: String, id: String) -> Bool { owned.contains("\(key):\(id)") }
    mutating func buy(key: String, id: String, price: Int) -> Bool {
        guard !isOwned(key: key, id: id), coins >= price else { return false }
        coins -= price; owned.append("\(key):\(id)"); return true
    }
}

// MARK: - Catalog Data

enum Wardrobe {

    static let skinTones: [String] = [
        "#f6d7bd", "#eac19b", "#d6a07a", "#b98059",
        "#9c6a46", "#8a5a3c", "#6b4329", "#4d2f1d"
    ]

    static let hairColors: [(name: String, hex: String)] = [
        ("Jet", "#141110"), ("Espresso", "#3b2618"), ("Chestnut", "#6b4226"), ("Honey", "#a8743f"),
        ("Platinum", "#e3dccb"), ("Silver", "#a9adb3"), ("Cherry", "#a8322a"), ("Electric", "#3d5bd9"),
    ]

    static let hairstyles: [(id: String, name: String)] = [
        ("fade", "Taper Fade"), ("buzz", "Buzz Cut"), ("afro", "Afro"),
        ("locs", "Locs"), ("twists", "Twists"), ("curls", "Curly Top"),
        ("swoop", "Swoop"), ("bun", "Top Knot"), ("bald", "Clean Shave"),
    ]

    static let facial: [(id: String, name: String)] = [
        ("none", "None"), ("stubble", "Stubble"), ("goatee", "Goatee"), ("beard", "Full Beard")
    ]

    static var starterOwned: [String] {
        store.categories.flatMap    { c in c.items.filter { $0.price == 0 }.map { "\(c.key):\($0.id)" } } +
        boardShop.categories.flatMap { c in c.items.filter { $0.price == 0 }.map { "\(c.key):\($0.id)" } }
    }

    static let store = WardrobeCatalog(name: "CURBSIDE", categories: [
        WardrobeCategory(key: "hat", label: "HEADWEAR", items: [
            WardrobeItem(id: "none",    name: "No Headwear",           price: 0,   variants: []),
            WardrobeItem(id: "beanie",  name: "Cuffed Beanie",         price: 0,   variants: [
                .init(name: "Charcoal",      color1: "#2b2f38", color2: "#2b2f38"),
                .init(name: "Safety Orange", color1: "#ff6a2b", color2: "#ff6a2b"),
                .init(name: "Forest",        color1: "#2f5d3a", color2: "#2f5d3a"),
                .init(name: "Bone",          color1: "#e8e2d2", color2: "#e8e2d2"),
                .init(name: "Cherry",        color1: "#b3262f", color2: "#b3262f"),
            ]),
            WardrobeItem(id: "cap",     name: "Six-Panel Cap",         price: 35,  variants: [
                .init(name: "Navy",  color1: "#1d2a4a", color2: "#ffffff"),
                .init(name: "Black", color1: "#161719", color2: "#d8b04a"),
                .init(name: "Kelly", color1: "#1f7a45", color2: "#ffffff"),
                .init(name: "Sand",  color1: "#cbb38a", color2: "#3b2f22"),
            ]),
            WardrobeItem(id: "capBack", name: "Backwards Cap",         price: 35,  variants: [
                .init(name: "Black", color1: "#161719", color2: "#ffffff"),
                .init(name: "Red",   color1: "#c2272d", color2: "#ffffff"),
                .init(name: "Royal", color1: "#2f54c9", color2: "#ffffff"),
            ]),
            WardrobeItem(id: "bucket",  name: "Bucket Hat",            price: 55,  variants: [
                .init(name: "Woodland", color1: "#556b3a", color2: "#3b2f22"),
                .init(name: "Desert",   color1: "#c9b28a", color2: "#8b6c47"),
                .init(name: "Night",    color1: "#2b2f38", color2: "#4a5568"),
            ]),
        ]),
        WardrobeCategory(key: "top", label: "TOPS", items: [
            WardrobeItem(id: "hoodie",     name: "Heavyweight Hoodie",      price: 0,   variants: [
                .init(name: "Safety Orange", color1: "#ff6a2b", color2: "#ff6a2b"),
                .init(name: "Olive",         color1: "#5b5a36", color2: "#5b5a36"),
                .init(name: "Heather Grey",  color1: "#9ea3a8", color2: "#9ea3a8"),
                .init(name: "Black",         color1: "#1d1e22", color2: "#1d1e22"),
                .init(name: "Teal",          color1: "#17a397", color2: "#17a397"),
                .init(name: "Mustard",       color1: "#d8a23a", color2: "#d8a23a"),
            ]),
            WardrobeItem(id: "tee",        name: "Pocket Tee",              price: 0,   variants: [
                .init(name: "White", color1: "#f2f0ea", color2: "#f2f0ea"),
                .init(name: "Royal", color1: "#3a5fc8", color2: "#3a5fc8"),
                .init(name: "Black", color1: "#1d1e22", color2: "#1d1e22"),
                .init(name: "Brick", color1: "#a4452f", color2: "#a4452f"),
            ]),
            WardrobeItem(id: "stripeTee",  name: "Stripe Tee",              price: 30,  variants: [
                .init(name: "Grey / Navy",   color1: "#8b9097", color2: "#2a3550"),
                .init(name: "Cream / Red",   color1: "#efe7d4", color2: "#b3262f"),
                .init(name: "Black / White", color1: "#1d1e22", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "graphicTee", name: "Sesh Graphic Tee",        price: 45,  variants: [
                .init(name: "Black", color1: "#1d1e22", color2: "#ff4f6d"),
                .init(name: "White", color1: "#f2f0ea", color2: "#1d6ff2"),
                .init(name: "Sky",   color1: "#8cc8ec", color2: "#1d1e22"),
            ]),
            WardrobeItem(id: "longsleeve", name: "Checker-Arm Long Sleeve", price: 50,  variants: [
                .init(name: "Mustard", color1: "#e2b23b", color2: "#1d1e22"),
                .init(name: "White",   color1: "#f2f0ea", color2: "#1d1e22"),
                .init(name: "Black",   color1: "#1d1e22", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "flannel",    name: "Open Flannel",             price: 70,  variants: [
                .init(name: "Red Buffalo", color1: "#b3262f", color2: "#1d1e22"),
                .init(name: "Teal Tartan", color1: "#1f7a7a", color2: "#e8e2d2"),
                .init(name: "Brown Check", color1: "#6b4a2e", color2: "#d9c9a8"),
            ]),
            WardrobeItem(id: "coach",      name: "Nylon Coach Jacket",       price: 90,  variants: [
                .init(name: "Black",  color1: "#161719", color2: "#e8e2d2"),
                .init(name: "Forest", color1: "#264a33", color2: "#e8e2d2"),
                .init(name: "Purple", color1: "#5b3aa0", color2: "#f2c14e"),
            ]),
            WardrobeItem(id: "varsity",    name: "Varsity Jacket",           price: 140, variants: [
                .init(name: "Red / Cream",   color1: "#a8252c", color2: "#efe7d4"),
                .init(name: "Navy / Gold",   color1: "#1d2a4a", color2: "#d8b04a"),
                .init(name: "Green / White", color1: "#1f5a3a", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "tank",       name: "Muscle Tank",              price: 20,  variants: [
                .init(name: "White",  color1: "#f2f0ea", color2: "#f2f0ea"),
                .init(name: "Black",  color1: "#1d1e22", color2: "#1d1e22"),
                .init(name: "Yellow", color1: "#f2c14e", color2: "#f2c14e"),
            ]),
        ]),
        WardrobeCategory(key: "bottom", label: "BOTTOMS", items: [
            WardrobeItem(id: "jeans",  name: "Straight Jeans", price: 0,   variants: [
                .init(name: "Indigo",     color1: "#2e3f66", color2: "#2e3f66"),
                .init(name: "Black Wash", color1: "#25272c", color2: "#25272c"),
                .init(name: "Light Wash", color1: "#7d93b8", color2: "#7d93b8"),
            ]),
            WardrobeItem(id: "baggy",  name: "Baggy Denim",    price: 45,  variants: [
                .init(name: "Mid Wash", color1: "#445a86", color2: "#445a86"),
                .init(name: "Raw",      color1: "#1f2b48", color2: "#1f2b48"),
                .init(name: "Stone",    color1: "#9aa6b8", color2: "#9aa6b8"),
            ]),
            WardrobeItem(id: "cargo",  name: "Camo Cargos",    price: 80,  variants: [
                .init(name: "Woodland", color1: "#6b6a3f", color2: "#3b2f22"),
                .init(name: "Urban",    color1: "#6f737a", color2: "#2b2f38"),
                .init(name: "Sand",     color1: "#b9a07a", color2: "#6b5536"),
            ]),
            WardrobeItem(id: "chinos", name: "Work Chinos",    price: 35,  variants: [
                .init(name: "Khaki", color1: "#b8a47e", color2: "#b8a47e"),
                .init(name: "Black", color1: "#232428", color2: "#232428"),
                .init(name: "Olive", color1: "#5b5a36", color2: "#5b5a36"),
            ]),
            WardrobeItem(id: "flames", name: "Flame Denim",    price: 120, variants: [
                .init(name: "Toxic",   color1: "#1d1e22", color2: "#28e07a"),
                .init(name: "Hot Rod", color1: "#1d1e22", color2: "#ff6a2b"),
                .init(name: "Ice",     color1: "#1d2a4a", color2: "#8cd8ff"),
            ]),
            WardrobeItem(id: "shorts", name: "Skate Shorts",   price: 25,  variants: [
                .init(name: "Khaki", color1: "#b8a47e", color2: "#b8a47e"),
                .init(name: "Black", color1: "#232428", color2: "#232428"),
                .init(name: "Navy",  color1: "#1d2a4a", color2: "#1d2a4a"),
            ]),
        ]),
        WardrobeCategory(key: "shoes", label: "SHOES", items: [
            WardrobeItem(id: "vulcLow",  name: "Vulc Low",        price: 0,  variants: [
                .init(name: "Black / White", color1: "#1d1e22", color2: "#f2f0ea"),
                .init(name: "Navy / Gum",    color1: "#1d2a4a", color2: "#c89a5c"),
                .init(name: "Red / White",   color1: "#b3262f", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "vulcHigh", name: "Vulc High",       price: 60, variants: [
                .init(name: "Black / White", color1: "#1d1e22", color2: "#f2f0ea"),
                .init(name: "Burgundy",      color1: "#6e1f2a", color2: "#f2f0ea"),
                .init(name: "Mustard",       color1: "#d8a23a", color2: "#1d1e22"),
            ]),
            WardrobeItem(id: "slipOn",   name: "Checker Slip-On", price: 55, variants: [
                .init(name: "Black Check", color1: "#1d1e22", color2: "#f2f0ea"),
                .init(name: "Red Check",   color1: "#b3262f", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "puffy",    name: "Puffy 90s Skate", price: 75, variants: [
                .init(name: "Grey / Blue",   color1: "#9ea3a8", color2: "#2f54c9"),
                .init(name: "White / Red",   color1: "#f2f0ea", color2: "#c2272d"),
                .init(name: "Black / Green", color1: "#1d1e22", color2: "#28e07a"),
            ]),
            WardrobeItem(id: "runner",   name: "Chunky Runner",   price: 95, variants: [
                .init(name: "Triple White", color1: "#f2f0ea", color2: "#dcd8cf"),
                .init(name: "Volt",         color1: "#1d1e22", color2: "#c6f432"),
                .init(name: "Sunset",       color1: "#ff6a2b", color2: "#f2f0ea"),
            ]),
        ]),
        WardrobeCategory(key: "extra", label: "EXTRAS", items: [
            WardrobeItem(id: "none",   name: "No Extras",         price: 0,   variants: []),
            WardrobeItem(id: "shades", name: "Wraparound Shades", price: 35,  variants: [
                .init(name: "Smoke",       color1: "#15171a", color2: "#1d1e22"),
                .init(name: "Mirror Gold", color1: "#b8892b", color2: "#d8b04a"),
                .init(name: "Ice Blue",    color1: "#5aa9d6", color2: "#e8e2d2"),
            ]),
            WardrobeItem(id: "chain",  name: "Rope Chain",        price: 150, variants: [
                .init(name: "Gold",   color1: "#d8b04a", color2: "#d8b04a"),
                .init(name: "Silver", color1: "#c3cad3", color2: "#c3cad3"),
            ]),
            WardrobeItem(id: "watch",  name: "Field Watch",       price: 60,  variants: [
                .init(name: "Black", color1: "#1d1e22", color2: "#d8b04a"),
                .init(name: "Steel", color1: "#c3cad3", color2: "#1d2a4a"),
            ]),
            WardrobeItem(id: "phones", name: "Neck Headphones",   price: 80,  variants: [
                .init(name: "Black", color1: "#1d1e22", color2: "#ff4f6d"),
                .init(name: "White", color1: "#f2f0ea", color2: "#17b3a3"),
            ]),
        ]),
    ])

    static let boardShop = WardrobeCatalog(name: "THE BOARD ROOM", categories: [
        WardrobeCategory(key: "deck", label: "DECK", items: [
            WardrobeItem(id: "roundel", name: "City Roundel",   price: 0,  variants: [
                .init(name: "Hot Pink", color1: "#ff4f6d", color2: "#ff4f6d"),
                .init(name: "Sky",      color1: "#2fb8ff", color2: "#2fb8ff"),
                .init(name: "Lemon",    color1: "#ffd23f", color2: "#ffd23f"),
            ]),
            WardrobeItem(id: "sunset",  name: "Sunset Fade",    price: 0,  variants: [
                .init(name: "Dusk",  color1: "#ff7a2b", color2: "#6b2fa0"),
                .init(name: "Beach", color1: "#ffd23f", color2: "#ff4f6d"),
            ]),
            WardrobeItem(id: "checker", name: "Checkerboard",   price: 40, variants: [
                .init(name: "Classic", color1: "#1d1e22", color2: "#f2f0ea"),
                .init(name: "Red",     color1: "#b3262f", color2: "#f2f0ea"),
            ]),
            WardrobeItem(id: "flame",   name: "Hot Rod Flames", price: 60, variants: [
                .init(name: "Classic", color1: "#1d1e22", color2: "#ff6a2b"),
                .init(name: "Toxic",   color1: "#1d1e22", color2: "#28e07a"),
            ]),
            WardrobeItem(id: "bridge",  name: "Fog Bridge",     price: 70, variants: [
                .init(name: "Morning", color1: "#e9dccb", color2: "#d9532b"),
                .init(name: "Night",   color1: "#1d2a4a", color2: "#ff7a2b"),
            ]),
            WardrobeItem(id: "pigeon",  name: "Street Pigeon",  price: 55, variants: [
                .init(name: "Mint",  color1: "#9fe0c8", color2: "#2b2f38"),
                .init(name: "Lilac", color1: "#c9b3ef", color2: "#2b2f38"),
            ]),
            WardrobeItem(id: "wave",    name: "Ocean Beach",    price: 45, variants: [
                .init(name: "Blue", color1: "#1d6ff2", color2: "#e8f4ff"),
                .init(name: "Teal", color1: "#17a397", color2: "#fff3d6"),
            ]),
            WardrobeItem(id: "grid",    name: "Night Grid",     price: 65, variants: [
                .init(name: "Neon", color1: "#120c24", color2: "#ff3df2"),
                .init(name: "Cyan", color1: "#07131f", color2: "#23e0ff"),
            ]),
            WardrobeItem(id: "tiger",   name: "Tiger Stripe",   price: 80, variants: [
                .init(name: "Orange", color1: "#ff8a1f", color2: "#1d1e22"),
                .init(name: "White",  color1: "#f2f0ea", color2: "#1d1e22"),
            ]),
        ]),
        WardrobeCategory(key: "grip", label: "GRIP", items: [
            WardrobeItem(id: "black",   name: "Classic Black", price: 0,  variants: []),
            WardrobeItem(id: "speckle", name: "Speckle",       price: 15, variants: []),
            WardrobeItem(id: "split",   name: "Split Cut",     price: 20, variants: []),
            WardrobeItem(id: "logo",    name: "Cut-Out Logo",  price: 25, variants: []),
        ]),
        WardrobeCategory(key: "trucks", label: "TRUCKS", items: [
            WardrobeItem(id: "raw",   name: "Raw Silver 139", price: 0,  variants: [.init(name: "Raw",   color1: "#c3cad3", color2: "#c3cad3")]),
            WardrobeItem(id: "black", name: "Blackout 139",   price: 30, variants: [.init(name: "Black", color1: "#2b2d31", color2: "#2b2d31")]),
            WardrobeItem(id: "gold",  name: "Gold Hollow",    price: 55, variants: [.init(name: "Gold",  color1: "#d8b04a", color2: "#d8b04a")]),
            WardrobeItem(id: "color", name: "Powder Coat",    price: 40, variants: [
                .init(name: "Red",  color1: "#c2272d", color2: "#c2272d"),
                .init(name: "Blue", color1: "#2f54c9", color2: "#2f54c9"),
                .init(name: "Teal", color1: "#17a397", color2: "#17a397"),
            ]),
        ]),
        WardrobeCategory(key: "wheels", label: "WHEELS", items: [
            WardrobeItem(id: "w52", name: "52mm Street",  price: 0,  variants: [.init(name: "White",  color1: "#f6efe0", color2: "#f6efe0")]),
            WardrobeItem(id: "w54", name: "54mm Conical", price: 20, variants: [
                .init(name: "Yellow", color1: "#ffd23f", color2: "#ffd23f"),
                .init(name: "Red",    color1: "#e8453c", color2: "#e8453c"),
            ]),
            WardrobeItem(id: "w56", name: "56mm Cruiser", price: 35, variants: [
                .init(name: "Blue",         color1: "#3a74e8", color2: "#3a74e8"),
                .init(name: "Mint",         color1: "#8fe3c7", color2: "#8fe3c7"),
                .init(name: "Clear Orange", color1: "#ff9a3c", color2: "#ff9a3c"),
            ]),
        ]),
    ])
}

// MARK: - Color Hex

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red:   Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >>  8) & 0xFF) / 255,
            blue:  Double( rgb        & 0xFF) / 255
        )
    }
}
