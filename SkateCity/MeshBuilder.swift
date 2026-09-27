//  MeshBuilder.swift
//  Builds custom SceneKit geometry (boxes, kicker wedges, curved quarter pipes)
//  with world-scale UVs (1 UV unit = 1 metre) so textures never stretch.
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import SceneKit
import simd

struct MeshBuilder {
    private(set) var positions: [SIMD3<Float>] = []
    private(set) var normals: [SIMD3<Float>] = []
    private(set) var uvs: [SIMD2<Float>] = []
    private(set) var indices: [UInt32] = []

    var isEmpty: Bool { indices.isEmpty }

    private func planarUV(_ p: SIMD3<Float>, _ n: SIMD3<Float>) -> SIMD2<Float> {
        let a = abs(n)
        if a.y >= a.x && a.y >= a.z { return SIMD2(p.x, p.z) }
        if a.x >= a.z { return SIMD2(p.z, -p.y) }
        return SIMD2(p.x, -p.y)
    }

    private mutating func push(_ p: SIMD3<Float>, _ n: SIMD3<Float>, _ uv: SIMD2<Float>? = nil) {
        positions.append(p)
        normals.append(n)
        uvs.append(uv ?? planarUV(p, n))
        indices.append(UInt32(positions.count - 1))
    }

    mutating func addTriangle(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, outward: SIMD3<Float>) {
        var n = simd_cross(b - a, c - a)
        guard simd_length(n) > 1e-9 else { return }
        n = simd_normalize(n)
        if simd_dot(n, outward) < 0 {
            push(a, -n); push(c, -n); push(b, -n)
        } else {
            push(a, n); push(b, n); push(c, n)
        }
    }

    /// Quad given in cyclic order (a, b, c, d).
    mutating func addQuad(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>, _ d: SIMD3<Float>, outward: SIMD3<Float>) {
        addTriangle(a, b, c, outward: outward)
        addTriangle(a, c, d, outward: outward)
    }

    /// Smooth-shaded quad with explicit per-vertex normals and UVs.
    mutating func addSmoothQuad(_ p: [SIMD3<Float>], _ n: [SIMD3<Float>], _ uv: [SIMD2<Float>]) {
        let face = simd_cross(p[1] - p[0], p[2] - p[0])
        let avg = n[0] + n[1] + n[2] + n[3]
        let order: [Int] = simd_dot(face, avg) >= 0 ? [0, 1, 2, 0, 2, 3] : [0, 2, 1, 0, 3, 2]
        for i in order { push(p[i], simd_normalize(n[i]), uv[i]) }
    }

    mutating func addBox(center c: SIMD3<Float>, size s: SIMD3<Float>, bottom: Bool = false) {
        let h = s / 2
        func p(_ x: Float, _ y: Float, _ z: Float) -> SIMD3<Float> { c + SIMD3(x * h.x, y * h.y, z * h.z) }
        addQuad(p(-1, 1, -1), p(1, 1, -1), p(1, 1, 1), p(-1, 1, 1), outward: SIMD3(0, 1, 0))
        addQuad(p(1, -1, -1), p(1, 1, -1), p(1, 1, 1), p(1, -1, 1), outward: SIMD3(1, 0, 0))
        addQuad(p(-1, -1, -1), p(-1, -1, 1), p(-1, 1, 1), p(-1, 1, -1), outward: SIMD3(-1, 0, 0))
        addQuad(p(-1, -1, 1), p(1, -1, 1), p(1, 1, 1), p(-1, 1, 1), outward: SIMD3(0, 0, 1))
        addQuad(p(-1, -1, -1), p(-1, 1, -1), p(1, 1, -1), p(1, -1, -1), outward: SIMD3(0, 0, -1))
        if bottom {
            addQuad(p(-1, -1, -1), p(1, -1, -1), p(1, -1, 1), p(-1, -1, 1), outward: SIMD3(0, -1, 0))
        }
    }

    /// Flat horizontal rectangle (ground, road paint…).
    mutating func addPlane(center c: SIMD3<Float>, width w: Float, depth d: Float) {
        let a = c + SIMD3(-w / 2, 0, -d / 2), b = c + SIMD3(w / 2, 0, -d / 2)
        let e = c + SIMD3(w / 2, 0, d / 2), f = c + SIMD3(-w / 2, 0, d / 2)
        addQuad(a, b, e, f, outward: SIMD3(0, 1, 0))
    }

    /// Kicker / bank: rises along +Z from height 0 at z=0 to `height` at z=`length`.
    mutating func addWedge(width w: Float, length L: Float, height h: Float) {
        let hw = w / 2
        let A = SIMD3<Float>(-hw, 0, 0), B = SIMD3<Float>(hw, 0, 0)
        let C = SIMD3<Float>(hw, h, L), D = SIMD3<Float>(-hw, h, L)
        let E = SIMD3<Float>(-hw, 0, L), F = SIMD3<Float>(hw, 0, L)
        addQuad(A, B, C, D, outward: SIMD3(0, L, -h))
        addQuad(F, E, D, C, outward: SIMD3(0, 0, 1))
        addTriangle(A, E, D, outward: SIMD3(-1, 0, 0))
        addTriangle(B, C, F, outward: SIMD3(1, 0, 0))
    }

    /// Curved quarter pipe. Transition rises along +Z; returns (lip height, lip z).
    @discardableResult
    mutating func addQuarterPipe(width w: Float, radius R: Float, maxAngle: Float, deck: Float, segments: Int = 18) -> (height: Float, lipZ: Float) {
        let hw = w / 2
        var prof: [(p: SIMD2<Float>, n: SIMD2<Float>, s: Float)] = [] // p = (z, y), n = (nz, ny)
        for i in 0...segments {
            let t = maxAngle * Float(i) / Float(segments)
            prof.append((SIMD2(R * sin(t), R * (1 - cos(t))), SIMD2(-sin(t), cos(t)), R * t))
        }
        for i in 0..<segments {
            let a = prof[i], b = prof[i + 1]
            let ps: [SIMD3<Float>] = [SIMD3(-hw, a.p.y, a.p.x), SIMD3(hw, a.p.y, a.p.x), SIMD3(hw, b.p.y, b.p.x), SIMD3(-hw, b.p.y, b.p.x)]
            let na = SIMD3<Float>(0, a.n.y, a.n.x), nb = SIMD3<Float>(0, b.n.y, b.n.x)
            let uv: [SIMD2<Float>] = [SIMD2(-hw, a.s), SIMD2(hw, a.s), SIMD2(hw, b.s), SIMD2(-hw, b.s)]
            addSmoothQuad(ps, [na, na, nb, nb], uv)
        }
        let H = prof[segments].p.y, zLip = prof[segments].p.x, zBack = zLip + deck
        addQuad(SIMD3(-hw, H, zLip), SIMD3(hw, H, zLip), SIMD3(hw, H, zBack), SIMD3(-hw, H, zBack), outward: SIMD3(0, 1, 0))
        addQuad(SIMD3(-hw, 0, zBack), SIMD3(hw, 0, zBack), SIMD3(hw, H, zBack), SIMD3(-hw, H, zBack), outward: SIMD3(0, 0, 1))
        for sx in [-hw, hw] {
            let out = SIMD3<Float>(sx > 0 ? 1 : -1, 0, 0)
            let corner = SIMD3<Float>(sx, 0, zBack)
            for i in 0..<segments {
                addTriangle(corner, SIMD3(sx, prof[i].p.y, prof[i].p.x), SIMD3(sx, prof[i + 1].p.y, prof[i + 1].p.x), outward: out)
            }
            addTriangle(corner, SIMD3(sx, H, zLip), SIMD3(sx, H, zBack), outward: out)
        }
        return (H, zLip)
    }

    func geometry(_ material: SCNMaterial) -> SCNGeometry {
        let v = SCNGeometrySource(vertices: positions.map { SCNVector3($0.x, $0.y, $0.z) })
        let n = SCNGeometrySource(normals: normals.map { SCNVector3($0.x, $0.y, $0.z) })
        let t = SCNGeometrySource(textureCoordinates: uvs.map { CGPoint(x: CGFloat($0.x), y: CGFloat($0.y)) })
        let e = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let g = SCNGeometry(sources: [v, n, t], elements: [e])
        g.materials = [material]
        return g
    }
}
