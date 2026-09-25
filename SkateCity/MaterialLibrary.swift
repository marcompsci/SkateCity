#if os(iOS)
// Port of the SkateCity.Draft world-space PBR shader library.
// Every material uses SceneKit's physicallyBased pipeline with world-space Metal shader
// modifiers that produce: worn asphalt with tyre tracks, paving joints, grass variation,
// building windows that light up at night, animated water, pier planks, and wind-swayed trees.
import UIKit
import SceneKit

// MARK: - Colour palette

enum Palette {
    static let land: UInt32      = 0xE6E1D6
    static let park: UInt32      = 0x9FCB83
    static let water: UInt32     = 0x3F8FC4
    static let road: UInt32      = 0x9EA4AD
    static let roadLine: UInt32  = 0xF4F4F0
    static let sidewalk: UInt32  = 0xD9D3CA
    static let curb: UInt32      = 0xBDB8B0
    static let plaza: UInt32     = 0xE0D9CE
    static let concrete: UInt32  = 0xC9C6C0
    static let roof: UInt32      = 0xD5D0C8
    static let wood: UInt32      = 0xC9B9A0
    static let kicker: UInt32    = 0xD9C6A8
    static let rail: UInt32      = 0xC3CAD3
    static let zipp: UInt32      = 0x17B3A3
    static let zippAccent: UInt32 = 0xFF7A59
    static let buildings: [UInt32] = [0xECE8E1, 0xE2DBD0, 0xD9C3A0, 0xC98F76,
                                       0xB9C4CF, 0xE8E3DA, 0xD4CFC6, 0xBFA58A,
                                       0xA9B3AD, 0xEFE9DF]
    static let skin:    [UInt32] = [0xF3D2B3, 0xDCAE86, 0xB98059, 0x8A5A3C, 0x5E3B26]
    static let hoodies: [UInt32] = [0xFF7A59, 0x17B3A3, 0x5B6CFF, 0xF2C14E, 0x2B2F38, 0xE8E6E1]
    static let decks:   [UInt32] = [0xFF4F6D, 0x2FB8FF, 0xFFD23F, 0x8B5CF6, 0x1E1E1E, 0x3DDC84]
    static let cars:    [UInt32] = [0xE85D5D, 0x5B8DEF, 0xF2C14E, 0x3FB98A,
                                     0xF4F4F4, 0x2B2F38, 0xB28DFF, 0xFF9F5A]
}

// MARK: - Material factory

enum Mat {
    private static var cache: [String: SCNMaterial] = [:]
    private static var emissiveEntries: [(SCNMaterial, CGFloat)] = []

    static func pbr(_ hex: UInt32,
                    rough: CGFloat = 0.85,
                    metal: CGFloat = 0,
                    emission: UInt32? = nil,
                    emissionIntensity: CGFloat = 1,
                    clearcoat: Bool = false) -> SCNMaterial {
        let key = "\(hex)-\(rough)-\(metal)-\(emission ?? 0)-\(emissionIntensity)-\(clearcoat)"
        if let m = cache[key] { return m }
        let m = make(hex, rough: rough, metal: metal)
        if let e = emission {
            m.emission.contents = UIColor(rgb: e)
            m.emission.intensity = emissionIntensity
            emissiveEntries.append((m, emissionIntensity))
        }
        if clearcoat {
            m.clearCoat.contents = NSNumber(value: 1.0)
            m.clearCoatRoughness.contents = NSNumber(value: 0.05)
        }
        cache[key] = m
        return m
    }

    static func make(_ hex: UInt32, rough: CGFloat = 0.85, metal: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents   = UIColor(rgb: hex)
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        return m
    }

    /// Update all emissive materials for a 0→1 night factor.
    static func setNight(_ n: Float) {
        for (m, base) in emissiveEntries {
            m.emission.intensity = base * CGFloat(1 + n * 3.5)
        }
    }

    /// Material with a world-space shader modifier; the `uNight` uniform is updated by the TOD system.
    static func surface(_ hex: UInt32, rough: CGFloat, metal: CGFloat = 0, shader: String) -> SCNMaterial {
        let m = make(hex, rough: rough, metal: metal)
        m.emission.contents = UIColor(white: 0.002, alpha: 1)
        m.shaderModifiers = [.surface: shader]
        m.setValue(NSNumber(value: 0.0), forKey: "uNight")
        return m
    }
}

// MARK: - UIColor hex helper

extension UIColor {
    convenience init(rgb hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >>  8) & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: alpha)
    }

    convenience init(hex string: String, alpha: CGFloat = 1) {
        var hex = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex = String(hex.dropFirst()) }
        let value = UInt64(hex, radix: 16) ?? 0
        self.init(
            red:   CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >>  8) & 0xFF) / 255,
            blue:  CGFloat( value        & 0xFF) / 255,
            alpha: alpha)
    }
}

// MARK: - World-space shader modifiers (Metal syntax, SCN modifier format)

enum Shaders {

    // MARK: Shared preamble

    static let common = """
    float sc_h21(float2 p) {
        p = fract(p * float2(123.34, 456.21));
        p += dot(p, p + 45.32);
        return fract(p.x * p.y);
    }
    float sc_vn(float2 p) {
        float2 i = floor(p); float2 sc_f = fract(p);
        sc_f = sc_f * sc_f * (3.0 - 2.0 * sc_f);
        return mix(mix(sc_h21(i), sc_h21(i + float2(1.0, 0.0)), sc_f.x),
                   mix(sc_h21(i + float2(0.0, 1.0)), sc_h21(i + float2(1.0, 1.0)), sc_f.x), sc_f.y);
    }
    float sc_fbm(float2 p) {
        float s = 0.0; float a = 0.5;
        for (int k = 0; k < 4; k++) { s += a * sc_vn(p); p *= 2.03; a *= 0.5; }
        return s;
    }
    #pragma arguments
    float uNight;
    #pragma body
    float3 sc_wp = (scn_frame.inverseViewTransform * float4(_surface.position, 1.0)).xyz;
    float3 sc_wn = normalize((scn_frame.inverseViewTransform * float4(_surface.normal, 0.0)).xyz);
    """

    // MARK: Surface shaders

    static let road = common + """
    float sc_rdx = abs(fmod(sc_wp.x + 196.0, 56.0) - 28.0);
    float sc_rdz = abs(fmod(sc_wp.z + 196.0, 56.0) - 28.0);
    float sc_wear = (1.0 - smoothstep(0.15, 0.8, abs(sc_rdx - 2.4))) * step(4.6, sc_rdz)
                  + (1.0 - smoothstep(0.15, 0.8, abs(sc_rdz - 2.4))) * step(4.6, sc_rdx);
    float sc_an   = sc_fbm(sc_wp.xz * 1.9);
    float sc_big  = sc_fbm(sc_wp.xz * 0.06);
    float sc_spk  = step(0.92, sc_h21(floor(sc_wp.xz * 30.0)));
    float sc_pat  = smoothstep(0.55, 0.7, sc_fbm(sc_wp.xz * 0.12 + 7.0));
    _surface.diffuse.rgb *= (0.84 + 0.2*sc_an + 0.07*sc_spk - 0.12*sc_big)
                           * (1.0 - 0.1*sc_wear) * (1.0 - 0.07*sc_pat);
    _surface.roughness = clamp(0.92 - 0.25*sc_wear - 0.1*sc_vn(sc_wp.xz*3.0), 0.4, 1.0);
    """

    static let sidewalk = common + """
    float2 sc_tg = abs(fract(sc_wp.xz / 1.5) - 0.5);
    float sc_joint = smoothstep(0.465, 0.49, max(sc_tg.x, sc_tg.y));
    float sc_tv = sc_h21(floor(sc_wp.xz / 1.5));
    _surface.diffuse.rgb *= (1.0 - 0.22*sc_joint) * (0.94 + 0.08*sc_tv)
                           * (0.93 + 0.1*sc_fbm(sc_wp.xz*2.5));
    """

    static let ground = common + """
    float sc_g1 = sc_fbm(sc_wp.xz * 0.35); float sc_g2 = sc_fbm(sc_wp.xz * 6.0);
    float sc_isGrass = step(_surface.diffuse.r + 0.05, _surface.diffuse.g);
    _surface.diffuse.rgb *= mix(0.9 + 0.14*sc_g1 + 0.05*sc_g2,
                                0.75 + 0.35*sc_g1 + 0.15*sc_g2, sc_isGrass);
    """

    static let paint = common + """
    _surface.diffuse.rgb *= 0.86 + 0.14 * sc_fbm(sc_wp.xz * 5.0);
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb, float3(0.6),
                               0.25 * step(0.72, sc_fbm(sc_wp.xz * 1.3)));
    """

    static let concrete = common + """
    _surface.diffuse.rgb *= 0.88 + 0.18 * sc_fbm(sc_wp.xz*1.4 + sc_wp.y*1.4);
    _surface.diffuse.rgb *= mix(0.68, 1.0, smoothstep(0.0, 0.45, sc_wp.y));
    """

    static let planks = common + """
    float sc_plank = smoothstep(0.42, 0.48, abs(fract(sc_wp.z / 0.28) - 0.5));
    float sc_topFace = step(0.9, sc_wn.y);
    _surface.diffuse.rgb *= mix(1.0, (1.0 - 0.4*sc_plank)
                              * (0.82 + 0.3*sc_h21(float2(floor(sc_wp.z/0.28), 3.0))), sc_topFace);
    """

    /// Building facades with glass windows that light up at dusk (driven by `uNight`).
    static let building = common + """
    float sc_wall = 1.0 - step(0.6, abs(sc_wn.y));
    float sc_u    = abs(sc_wn.x) > 0.5 ? sc_wp.z : sc_wp.x;
    float sc_v    = sc_wp.y;
    float2 sc_cell = float2(sc_u / 2.9, (sc_v - 0.4) / 3.5);
    float2 sc_f    = fract(sc_cell); float2 sc_cid = floor(sc_cell);
    float sc_seed  = sc_h21(floor(sc_wp.xz / 9.0) + sc_wn.xz * 3.1);
    float sc_h     = sc_h21(sc_cid + sc_seed * 31.0);
    float sc_upper = step(3.9, sc_v);
    float sc_win   = step(0.17, sc_f.x) * step(sc_f.x, 0.83)
                   * step(0.22, sc_f.y) * step(sc_f.y, 0.8) * sc_upper;
    float sc_store = step(0.45, sc_v) * step(sc_v, 3.25)
                   * step(0.06, fract(sc_u/5.2)) * step(fract(sc_u/5.2), 0.94);
    sc_win = max(sc_win, sc_store) * sc_wall;
    float sc_band  = 1.0 - sc_wall * (1.0 - step(0.05, fract((sc_v-0.4)/3.5))) * 0.12;
    float3 sc_glass = mix(float3(0.08,0.11,0.15), float3(0.2,0.26,0.33), sc_h);
    float3 sc_base  = _surface.diffuse.rgb * sc_band * (0.94 + 0.1*sc_vn(float2(sc_u,sc_v)*0.9));
    _surface.diffuse.rgb = mix(sc_base, sc_glass, sc_win) * mix(0.66, 1.0, smoothstep(0.0,1.6,sc_v));
    _surface.roughness   = mix(_surface.roughness, 0.05, sc_win);
    _surface.metalness   = mix(_surface.metalness, 0.7,  sc_win);
    float sc_lit = step(0.6, sc_h21(sc_cid*1.7 + 3.1 + sc_seed)) * sc_win * sc_upper
                 + sc_store * sc_wall;
    _surface.emission.rgb += float3(1.0, 0.74, 0.45) * sc_lit * uNight * (0.35 + 0.7*sc_h);
    """

    /// Ocean / river water with real-time normal derivation from fbm height field.
    static let water = common + """
    float2 sc_wpp = sc_wp.xz * 0.35 + scn_frame.time * float2(0.12, 0.07);
    float sc_e  = 0.08;
    float sc_h0 = sc_fbm(sc_wpp);
    float sc_hx = sc_fbm(sc_wpp + float2(sc_e, 0.0));
    float sc_hz = sc_fbm(sc_wpp + float2(0.0, sc_e));
    float3 sc_nW = normalize(float3((sc_h0 - sc_hx) * 3.0, 1.0, (sc_h0 - sc_hz) * 3.0));
    _surface.normal = normalize((scn_frame.viewTransform * float4(sc_nW, 0.0)).xyz);
    _surface.roughness = 0.04 + 0.06 * sc_vn(sc_wpp * 2.0);
    _surface.metalness = 0.9;
    """

    static let leaves = common + """
    _surface.diffuse.rgb *= 0.8 + 0.35 * sc_vn(sc_wp.xz*1.7 + sc_wp.y*2.0);
    """

    /// Deck underside: blends raw maple in where the Metal scratch map has been painted.
    static let deckWear = """
    #pragma arguments
    texture2d<float> scratchMap;
    #pragma body
    constexpr sampler sc_s(filter::linear, address::clamp_to_edge);
    float sc_wearAmt = scratchMap.sample(sc_s, _surface.diffuseTexcoord).r;
    _surface.diffuse.rgb = mix(_surface.diffuse.rgb,
                               float3(0.84, 0.72, 0.54), clamp(sc_wearAmt * 1.4, 0.0, 1.0));
    _surface.roughness = mix(_surface.roughness, 0.9, sc_wearAmt);
    """

    /// Geometry modifier: wind sway for trees. Applied to the geometry stage.
    static let wind = """
    float4 sc_wpos = scn_node.modelTransform * _geometry.position;
    float sc_sway = max(sc_wpos.y - 2.6, 0.0) * 0.04;
    _geometry.position.x += sin(scn_frame.time*1.4 + sc_wpos.x*0.31 + sc_wpos.z*0.17) * sc_sway;
    _geometry.position.z += cos(scn_frame.time*1.1 + sc_wpos.x*0.20) * sc_sway * 0.7;
    """

    /// Wet asphalt: reflective puddles appear on lower roughness patches (rain mode).
    static let wetRoad = common + """
    float sc_rdx = abs(fmod(sc_wp.x + 196.0, 56.0) - 28.0);
    float sc_rdz = abs(fmod(sc_wp.z + 196.0, 56.0) - 28.0);
    float sc_wear = (1.0 - smoothstep(0.15, 0.8, abs(sc_rdx - 2.4))) * step(4.6, sc_rdz)
                  + (1.0 - smoothstep(0.15, 0.8, abs(sc_rdz - 2.4))) * step(4.6, sc_rdx);
    float sc_an   = sc_fbm(sc_wp.xz * 1.9);
    // puddle warp driven by time
    float2 sc_pd  = sc_wp.xz * 0.9 + scn_frame.time * float2(0.02, 0.015);
    float sc_puddle = smoothstep(0.62, 0.72, sc_fbm(sc_pd));
    _surface.diffuse.rgb  *= (0.82 + 0.18*sc_an) * (1.0 - 0.3*sc_puddle);
    _surface.roughness     = mix(0.85 - 0.25*sc_wear, 0.04, sc_puddle);
    _surface.metalness     = mix(0.0, 0.7, sc_puddle);
    """
}
#endif
