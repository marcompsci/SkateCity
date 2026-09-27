//  TextureFactory.swift
//  Procedurally generated PBR texture sets (albedo + roughness + normal [+ emission]).
//  No image assets needed to run — swap in photoscanned textures later for even more realism
//  (see README: Poly Haven / ambientCG CC0 textures drop straight into `TextureCache`).

import UIKit
import SceneKit
import simd

struct PBRSet {
    let albedo: UIImage
    let roughness: UIImage
    let normal: UIImage
    var emission: UIImage?
}

enum TextureFactory {

    struct Sample {
        var color: SIMD3<Float>
        var rough: Float
        var height: Float
        var glow = SIMD3<Float>(0, 0, 0)
    }

    // MARK: Noise

    static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Float {
        var h = UInt64(truncatingIfNeeded: (x &* 73856093) ^ (y &* 19349663) ^ (seed &* 83492791))
        h = (h ^ (h >> 33)) &* 0xff51afd7ed558ccd
        h = (h ^ (h >> 33)) &* 0xc4ceb9fe1a85ec53
        h ^= h >> 33
        return Float(h & 0xFFFFFF) / Float(0xFFFFFF)
    }

    /// Tileable value noise.
    static func valueNoise(_ x: Float, _ y: Float, period: Int, seed: Int) -> Float {
        let xf = floor(x), yf = floor(y)
        let xi = Int(xf), yi = Int(yf)
        let fx = x - xf, fy = y - yf
        let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
        let x0 = ((xi % period) + period) % period, x1 = (((xi + 1) % period) + period) % period
        let y0 = ((yi % period) + period) % period, y1 = (((yi + 1) % period) + period) % period
        let a = hash(x0, y0, seed), b = hash(x1, y0, seed)
        let c = hash(x0, y1, seed), d = hash(x1, y1, seed)
        let top = a + (b - a) * ux
        let bottom = c + (d - c) * ux
        return top + (bottom - top) * uy
    }

    static func fbm(_ u: Float, _ v: Float, period: Int, octaves: Int, seed: Int) -> Float {
        var sum: Float = 0, amp: Float = 0.5, norm: Float = 0
        var p = period
        for o in 0..<octaves {
            sum += amp * valueNoise(u * Float(p), v * Float(p), period: p, seed: seed + o * 131)
            norm += amp
            amp *= 0.5
            p *= 2
        }
        return sum / norm
    }

    // MARK: Generator

    static func generate(size n: Int, normalStrength: Float, withEmission: Bool = false,
                         _ f: (Float, Float, Int, Int) -> Sample) -> PBRSet {
        var alb = [UInt8](repeating: 255, count: n * n * 4)
        var rgh = [UInt8](repeating: 255, count: n * n * 4)
        var emi = [UInt8](repeating: 255, count: withEmission ? n * n * 4 : 0)
        var hgt = [Float](repeating: 0, count: n * n)

        for y in 0..<n {
            for x in 0..<n {
                let s = f((Float(x) + 0.5) / Float(n), (Float(y) + 0.5) / Float(n), x, y)
                let i = (y * n + x) * 4
                let c = simd_clamp(s.color, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
                alb[i] = UInt8(c.x * 255); alb[i + 1] = UInt8(c.y * 255); alb[i + 2] = UInt8(c.z * 255)
                let r = UInt8(max(0, min(1, s.rough)) * 255)
                rgh[i] = r; rgh[i + 1] = r; rgh[i + 2] = r
                if withEmission {
                    let g = simd_clamp(s.glow, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
                    emi[i] = UInt8(g.x * 255); emi[i + 1] = UInt8(g.y * 255); emi[i + 2] = UInt8(g.z * 255)
                }
                hgt[y * n + x] = s.height
            }
        }

        var nrm = [UInt8](repeating: 255, count: n * n * 4)
        for y in 0..<n {
            for x in 0..<n {
                let l = hgt[y * n + (x + n - 1) % n], r = hgt[y * n + (x + 1) % n]
                let u = hgt[((y + n - 1) % n) * n + x], d = hgt[((y + 1) % n) * n + x]
                let v = simd_normalize(SIMD3<Float>((l - r) * normalStrength, (u - d) * normalStrength, 1))
                let i = (y * n + x) * 4
                nrm[i] = UInt8((v.x * 0.5 + 0.5) * 255)
                nrm[i + 1] = UInt8((v.y * 0.5 + 0.5) * 255)
                nrm[i + 2] = UInt8((v.z * 0.5 + 0.5) * 255)
            }
        }

        return PBRSet(albedo: image(alb, n), roughness: image(rgh, n), normal: image(nrm, n),
                      emission: withEmission ? image(emi, n) : nil)
    }

    static func image(_ px: [UInt8], _ n: Int) -> UIImage {
        let provider = CGDataProvider(data: Data(px) as CFData)!
        let cg = CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4,
                         space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                         provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
        return UIImage(cgImage: cg)
    }

    // MARK: Surfaces

    /// Street asphalt with aggregate stones and hairline cracks. Tile = 6 m.
    static func asphalt() -> PBRSet {
        generate(size: 512, normalStrength: 5) { u, v, x, y in
            let large = fbm(u, v, period: 4, octaves: 3, seed: 1)
            let fine = fbm(u, v, period: 48, octaves: 2, seed: 7)
            let grain = hash(x, y, 3)
            var c = SIMD3<Float>(repeating: 0.15 + large * 0.09 + (fine - 0.5) * 0.08) * SIMD3(1.0, 0.98, 0.95)
            var h = fine * 0.6 + grain * 0.25
            if grain > 0.965 { c += 0.11; h += 0.3 }
            let crack = abs(fbm(u, v, period: 5, octaves: 3, seed: 21) - 0.5)
            if crack < 0.006 { c *= 0.45; h -= 0.5 }
            return Sample(color: c, rough: 0.8 + fine * 0.15, height: h)
        }
    }

    /// Smooth plaza concrete slabs with expansion joints. Tile = 4 m (2 m slabs).
    static func concrete(tint: SIMD3<Float> = SIMD3(0.58, 0.57, 0.55), slabs: Float = 2) -> PBRSet {
        generate(size: 256, normalStrength: 4) { u, v, _, _ in
            let gu = (u * slabs).truncatingRemainder(dividingBy: 1), gv = (v * slabs).truncatingRemainder(dividingBy: 1)
            let joint = min(min(gu, 1 - gu), min(gv, 1 - gv)) < 0.008
            let slabTint = hash(Int(u * slabs), Int(v * slabs), 9) * 0.06 - 0.03
            let stain = fbm(u, v, period: 4, octaves: 3, seed: 5)
            let fine = fbm(u, v, period: 64, octaves: 2, seed: 2)
            var c = tint * (0.85 + stain * 0.25 + slabTint) + (fine - 0.5) * 0.05
            var h = fine * 0.35
            if joint { c *= 0.55; h = -0.6 }
            return Sample(color: c, rough: 0.62 + stain * 0.2, height: h)
        }
    }

    /// Skatelite-style ramp surface: dark, smooth, waxed streaks. Tile = 4 m.
    static func rampSurface() -> PBRSet {
        generate(size: 256, normalStrength: 2) { u, v, _, _ in
            let n = fbm(u, v, period: 4, octaves: 3, seed: 31)
            let streak = fbm(u * 0.25, v * 4, period: 8, octaves: 2, seed: 33)
            let c = SIMD3<Float>(0.19, 0.17, 0.16) * (0.85 + n * 0.3) + SIMD3<Float>(repeating: streak > 0.62 ? 0.05 : 0)
            return Sample(color: c, rough: 0.32 + n * 0.2 - (streak > 0.62 ? 0.1 : 0), height: n * 0.2)
        }
    }

    /// Building facade with window grid; some windows glow (emission) for a golden-hour city feel. Tile = 8 m.
    static func facade(wall: SIMD3<Float>, seed: Int) -> PBRSet {
        generate(size: 256, normalStrength: 6, withEmission: true) { u, v, _, _ in
            let cols: Float = 3, rows: Float = 3
            let cu = u * cols, cv = v * rows
            let fu = cu - floor(cu), fv = cv - floor(cv)
            let cellX = Int(floor(cu)), cellY = Int(floor(cv))
            let n = fbm(u, v, period: 4, octaves: 3, seed: seed)
            let isWindow = fu > 0.16 && fu < 0.84 && fv > 0.22 && fv < 0.82
            let isFrame = !isWindow && fu > 0.13 && fu < 0.87 && fv > 0.19 && fv < 0.85
            if isWindow {
                let lit = hash(cellX, cellY, seed) > 0.58
                let blind = fv < 0.22 + hash(cellX, cellY, seed + 1) * 0.3
                var c = SIMD3<Float>(0.05, 0.07, 0.09) + n * 0.03
                var glow = SIMD3<Float>(0, 0, 0)
                if lit {
                    let warm = SIMD3<Float>(1.0, 0.78, 0.5) * (0.55 + hash(cellX, cellY, seed + 2) * 0.45)
                    glow = blind ? warm * 0.6 : warm
                    c = warm * 0.4
                }
                return Sample(color: c, rough: 0.08, height: -0.4, glow: glow)
            }
            if isFrame { return Sample(color: SIMD3(0.12, 0.12, 0.13), rough: 0.4, height: -0.1) }
            let ledge = fv > 0.9 || fv < 0.06
            let c = wall * (0.82 + n * 0.3) * (ledge ? 0.85 : 1)
            return Sample(color: c, rough: 0.8, height: n * 0.3 + (ledge ? 0.4 : 0))
        }
    }

    static func grass() -> PBRSet {
        generate(size: 128, normalStrength: 5) { u, v, x, y in
            let n = fbm(u, v, period: 8, octaves: 3, seed: 51)
            let g = hash(x, y, 52)
            let c = SIMD3<Float>(0.16, 0.3, 0.09) * (0.7 + n * 0.5 + g * 0.2)
            return Sample(color: c, rough: 0.9, height: g)
        }
    }

    static func gripTape() -> UIImage {
        generate(size: 128, normalStrength: 1) { _, _, x, y in
            Sample(color: SIMD3(repeating: 0.03 + hash(x, y, 77) * 0.07), rough: 1, height: 0)
        }.albedo
    }

    // MARK: Drawn art (CoreGraphics)

    static func deckGraphic(_ a: UIColor, _ b: UIColor) -> UIImage {
        let size = CGSize(width: 512, height: 128)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [a.cgColor, b.cgColor] as CFArray
            if let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            }
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 64, weight: .black),
                .foregroundColor: UIColor.white,
                .strokeColor: UIColor.black,
                .strokeWidth: -4
            ]
            let text = NSAttributedString(string: "SKATECITY", attributes: attrs)
            let ts = text.size()
            text.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2))
        }
    }

    static func graffiti() -> UIImage {
        let size = CGSize(width: 1536, height: 288)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.55, green: 0.54, blue: 0.52, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))
            var seed = 12345
            func rnd() -> CGFloat {
                seed = (seed &* 1103515245 &+ 12345) & 0x7fffffff
                return CGFloat(seed % 10000) / 10000
            }
            let palette: [UIColor] = [.systemPink, .systemTeal, .systemYellow, .systemOrange, .systemPurple, .systemGreen]
            for _ in 0..<60 {
                let c = palette[Int(rnd() * CGFloat(palette.count)) % palette.count].withAlphaComponent(0.35)
                c.setFill()
                let r = 20 + rnd() * 90
                cg.fillEllipse(in: CGRect(x: rnd() * size.width, y: rnd() * size.height, width: r * 1.6, height: r))
            }
            // Drips
            for _ in 0..<40 {
                palette[Int(rnd() * 6) % 6].withAlphaComponent(0.6).setFill()
                cg.fill(CGRect(x: rnd() * size.width, y: 150 + rnd() * 40, width: 4, height: 30 + rnd() * 80))
            }
            let main: [NSAttributedString.Key: Any] = [
                .font: UIFont.italicSystemFont(ofSize: 170).withWeight(.black),
                .foregroundColor: UIColor(red: 1, green: 0.35, blue: 0.2, alpha: 1),
                .strokeColor: UIColor.white,
                .strokeWidth: -6
            ]
            let t = NSAttributedString(string: "SKATE CITY", attributes: main)
            let ts = t.size()
            // shadow layer
            let shadow = NSAttributedString(string: "SKATE CITY", attributes: [
                .font: main[.font]!, .foregroundColor: UIColor.black.withAlphaComponent(0.7)])
            shadow.draw(at: CGPoint(x: (size.width - ts.width) / 2 + 12, y: (size.height - ts.height) / 2 + 10))
            t.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2))
            let tag = NSAttributedString(string: "est. 2026  ·  skate or die  ·  no cops no stops", attributes: [
                .font: UIFont.systemFont(ofSize: 30, weight: .heavy),
                .foregroundColor: UIColor.systemYellow])
            tag.draw(at: CGPoint(x: 60, y: size.height - 50))
        }
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let d = fontDescriptor.addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
        return UIFont(descriptor: d, size: pointSize)
    }
}

// MARK: - Material helpers + cache

enum Materials {
    static func pbr(_ set: PBRSet, worldSize: Float, emissionIntensity: CGFloat = 0) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = set.albedo
        m.roughness.contents = set.roughness
        m.normal.contents = set.normal
        m.metalness.contents = NSNumber(value: 0)
        if let e = set.emission, emissionIntensity > 0 {
            m.emission.contents = e
            m.emission.intensity = emissionIntensity
        }
        let s = CGFloat(1 / worldSize)
        for p in [m.diffuse, m.roughness, m.normal, m.emission] {
            p.wrapS = .repeat
            p.wrapT = .repeat
            p.contentsTransform = SCNMatrix4MakeScale(Float(s), Float(s), 1)
            p.mipFilter = .linear
            p.maxAnisotropy = 8
        }
        return m
    }

    static func color(_ c: UIColor, rough: CGFloat, metal: CGFloat = 0, emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = c
        m.roughness.contents = NSNumber(value: Double(rough))
        m.metalness.contents = NSNumber(value: Double(metal))
        if let e = emission { m.emission.contents = e }
        return m
    }
}

/// Textures are generated once per launch (takes ~1 s in Release, a few seconds in Debug).
@MainActor
final class TextureCache {
    static let shared = TextureCache()

    private(set) var ready = false
    private(set) var asphalt: SCNMaterial!
    private(set) var concrete: SCNMaterial!
    private(set) var sidewalk: SCNMaterial!
    private(set) var ramp: SCNMaterial!
    private(set) var grass: SCNMaterial!
    private(set) var facades: [SCNMaterial] = []
    private(set) var roof: SCNMaterial!
    private(set) var graffiti: UIImage!
    private(set) var grip: UIImage!

    func warmUp() {
        guard !ready else { return }
        asphalt = Materials.pbr(TextureFactory.asphalt(), worldSize: 6)
        concrete = Materials.pbr(TextureFactory.concrete(), worldSize: 4)
        sidewalk = Materials.pbr(TextureFactory.concrete(tint: SIMD3(0.66, 0.64, 0.6), slabs: 4), worldSize: 4)
        ramp = Materials.pbr(TextureFactory.rampSurface(), worldSize: 4)
        grass = Materials.pbr(TextureFactory.grass(), worldSize: 2)
        facades = [
            Materials.pbr(TextureFactory.facade(wall: SIMD3(0.55, 0.3, 0.24), seed: 100), worldSize: 8, emissionIntensity: 1.6),
            Materials.pbr(TextureFactory.facade(wall: SIMD3(0.72, 0.66, 0.56), seed: 200), worldSize: 8, emissionIntensity: 1.6),
            Materials.pbr(TextureFactory.facade(wall: SIMD3(0.36, 0.4, 0.45), seed: 300), worldSize: 8, emissionIntensity: 1.6)
        ]
        roof = Materials.pbr(TextureFactory.concrete(tint: SIMD3(0.3, 0.3, 0.3), slabs: 1), worldSize: 6)
        graffiti = TextureFactory.graffiti()
        grip = TextureFactory.gripTape()
        ready = true
    }
}
