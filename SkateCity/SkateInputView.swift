// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

#if os(iOS)
import UIKit
import simd

struct TouchSample {
    let position:  simd_float2
    let timestamp: TimeInterval
}

class SkateInputView: UIView {
    private var leftThumbTouch:  UITouch?
    private var rightThumbTouch: UITouch?

    private(set) var leftStickOutput = simd_float2(0, 0)
    private var rightTouchHistory: [TouchSample] = []
    private let maxBufferDuration: TimeInterval = 0.20

    // Gesture combo buffer (mirrors Unity draft's 0.13 s combo window)
    private var gestureBuffer:     [(gesture: TrickGesture, timestamp: TimeInterval)] = []
    private var gestureEvalTimer:  Timer?
    private var lastFlickVelocity: Float = 0

    var onStanceChanged: ((simd_float2) -> Void)?
    var onTrickPopped:   ((TrickRegistryType, Float) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isMultipleTouchEnabled = true
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)
            if location.x < bounds.width * 0.40 {
                if leftThumbTouch == nil {
                    leftThumbTouch = touch
                    processLeftMovement(touch)
                }
            } else {
                if rightThumbTouch == nil {
                    rightThumbTouch = touch
                    rightTouchHistory.removeAll()
                    recordRightSample(touch)
                }
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == leftThumbTouch {
                processLeftMovement(touch)
            } else if touch == rightThumbTouch {
                recordRightSample(touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == leftThumbTouch {
                leftThumbTouch  = nil
                leftStickOutput = simd_float2(0, 0)
                onStanceChanged?(.zero)
            } else if touch == rightThumbTouch {
                evaluateFlick()
                rightThumbTouch = nil
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Left stick (stance / carve)

    private func processLeftMovement(_ touch: UITouch) {
        let cur  = touch.location(in: self)
        let prev = touch.previousLocation(in: self)
        let dX = Float(cur.x - prev.x) / 50.0
        let dY = Float(cur.y - prev.y) / 50.0
        leftStickOutput.x = max(-1, min(1, leftStickOutput.x + dX))
        leftStickOutput.y = max(-1, min(1, leftStickOutput.y - dY))
        onStanceChanged?(leftStickOutput)
    }

    // MARK: - Right flick sampling

    private func recordRightSample(_ touch: UITouch) {
        let loc    = touch.location(in: self)
        let pos    = simd_float2(Float(loc.x / bounds.width), Float(loc.y / bounds.height))
        let sample = TouchSample(position: pos, timestamp: CACurrentMediaTime())
        rightTouchHistory.append(sample)
        let cutoff = sample.timestamp - maxBufferDuration
        rightTouchHistory = rightTouchHistory.filter { $0.timestamp >= cutoff }
    }

    // MARK: - Flick classification → gesture buffer

    private func evaluateFlick() {
        guard rightTouchHistory.count >= 3 else { return }
        let first    = rightTouchHistory.first!
        let last     = rightTouchHistory.last!
        let delta    = last.position - first.position
        let duration = last.timestamp - first.timestamp
        let distance = length(delta)

        guard duration < 0.18, distance > 0.04 else { return }

        lastFlickVelocity = Float(Double(distance) / duration)
        let gesture = classifyFlick(delta: delta)
        gestureBuffer.append((gesture, CACurrentMediaTime()))

        // Restart the 0.13 s evaluation window after every new flick
        gestureEvalTimer?.invalidate()
        gestureEvalTimer = Timer.scheduledTimer(withTimeInterval: 0.13, repeats: false) { [weak self] _ in
            self?.dispatchGestureBuffer()
        }
    }

    private func classifyFlick(delta: simd_float2) -> TrickGesture {
        // Dominant-axis maps UIKit screen coords to UDLR matching Unity draft's key codes:
        //   Screen-up  (negative Y) → .up   → pop / launch
        //   Screen-down (positive Y)→ .down  → shove-it
        //   Screen-left             → .left  → kickflip axis
        //   Screen-right            → .right → heelflip axis
        if abs(delta.x) > abs(delta.y) {
            return delta.x < 0 ? .left : .right
        } else {
            return delta.y < 0 ? .up : .down
        }
    }

    private func dispatchGestureBuffer() {
        let gestures = gestureBuffer.map { $0.gesture }
        gestureBuffer.removeAll()
        guard let result = TrickRegistry.lookup(gestures: gestures) else { return }
        onTrickPopped?(result.type, lastFlickVelocity)
    }
}
#endif
