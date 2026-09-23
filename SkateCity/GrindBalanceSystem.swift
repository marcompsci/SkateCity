import Foundation

struct GrindBalanceState {
    var centerOfMassOffset: Float = 0.0   // -1.0 (left) to 1.0 (right)
    var angularVelocity:    Float = 0.0
    let gravityTippingFactor:   Float = 4.5
    let playerControlAuthority: Float = 6.0
}

class GrindBalanceSystem {
    var activeBalance = GrindBalanceState()
    private(set) var isWrecked: Bool = false

    /// Call every frame while the skater is grinding.
    /// leftJoystickY: +1 = up (corrects rightward tip), -1 = down.
    func updateGrindBalance(
        deltaTime:       TimeInterval,
        currentTime:     TimeInterval,
        leftJoystickY:   Float
    ) {
        guard !isWrecked else { return }

        // Layered sine noise gives an organic, unpredictable wobble
        let wobble = Float(sin(currentTime * 3.5) * 0.12 * cos(currentTime * 7.35))

        let gravityForce = activeBalance.centerOfMassOffset * activeBalance.gravityTippingFactor
        let playerForce  = leftJoystickY * activeBalance.playerControlAuthority
        let netAccel     = gravityForce - playerForce + wobble

        activeBalance.angularVelocity    += netAccel * Float(deltaTime)
        activeBalance.centerOfMassOffset += activeBalance.angularVelocity * Float(deltaTime)

        if abs(activeBalance.centerOfMassOffset) >= 1.0 {
            isWrecked = true
        }
    }

    func resetSystem() {
        activeBalance.centerOfMassOffset = 0.0
        activeBalance.angularVelocity    = 0.0
        isWrecked = false
    }
}
