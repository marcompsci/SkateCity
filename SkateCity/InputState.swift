//  InputState.swift
//  Merges touch controls, MFi / Xbox / PlayStation controllers and a hardware keyboard.
//
//  Controller:  Left stick = steer/spin   A = Ollie (hold to crouch, release to pop)
//               X = Flip   Y = Grab   B = Grind   R1 = Manual
//  Keyboard:    WASD / arrows = steer   Space = Ollie   J = Flip   K = Grab   L = Grind   I = Manual
// Copyright © 2026 MAR / SkateCity. All rights reserved.
// Unauthorized reproduction, distribution, or modification is strictly prohibited.

import GameController
import QuartzCore
import simd

@MainActor
final class InputState {
    // Written by the on-screen controls
    var touchStick = SIMD2<Float>(0, 0)
    var touchOllie = false
    var touchGrab = false
    var touchGrind = false

    // Effective values read by the engine
    private(set) var stick = SIMD2<Float>(0, 0)
    private(set) var ollieHeld = false
    private(set) var grabHeld = false
    private(set) var grindHeld = false

    private var flipQueued = false
    private var grindTappedAt: CFTimeInterval = -10
    private var manualTappedAt: CFTimeInterval = -10
    private var prevPad = (flip: false, grind: false, manual: false)

    // Touch button events
    func pressFlip() { flipQueued = true }
    func pressGrind() { grindTappedAt = CACurrentMediaTime() }
    func pressManual() { manualTappedAt = CACurrentMediaTime() }

    func consumeFlip() -> Bool {
        let f = flipQueued
        flipQueued = false
        return f
    }

    /// Grind is "buffered" if held, or tapped in the last 0.35 s (forgiving on touch screens).
    var grindBuffered: Bool { grindHeld || CACurrentMediaTime() - grindTappedAt < 0.35 }
    func consumeGrind() { grindTappedAt = -10 }

    var manualBuffered: Bool { CACurrentMediaTime() - manualTappedAt < 0.3 }
    func consumeManual() { manualTappedAt = -10 }

    func reset() {
        touchStick = .zero
        touchOllie = false
        touchGrab = false
        touchGrind = false
        flipQueued = false
        grindTappedAt = -10
        manualTappedAt = -10
    }

    /// Called once per rendered frame by the engine.
    func poll() {
        var padStick = SIMD2<Float>(0, 0)
        var pOllie = false, pGrab = false, pFlip = false, pGrind = false, pManual = false

        if let pad = GCController.current?.extendedGamepad {
            padStick = SIMD2(pad.leftThumbstick.xAxis.value, pad.leftThumbstick.yAxis.value)
            let dx = pad.dpad.xAxis.value, dy = pad.dpad.yAxis.value
            if abs(dx) > 0.1 || abs(dy) > 0.1 { padStick = SIMD2(dx, dy) }
            pOllie = pad.buttonA.isPressed
            pFlip = pad.buttonX.isPressed
            pGrab = pad.buttonY.isPressed
            pGrind = pad.buttonB.isPressed
            pManual = pad.rightShoulder.isPressed
        }

        if let kb = GCKeyboard.coalesced?.keyboardInput {
            func k(_ code: GCKeyCode) -> Bool { kb.button(forKeyCode: code)?.isPressed ?? false }
            var ks = SIMD2<Float>(0, 0)
            if k(.keyA) || k(.leftArrow) { ks.x -= 1 }
            if k(.keyD) || k(.rightArrow) { ks.x += 1 }
            if k(.keyW) || k(.upArrow) { ks.y += 1 }
            if k(.keyS) || k(.downArrow) { ks.y -= 1 }
            if ks.x != 0 || ks.y != 0 { padStick = ks }
            pOllie = pOllie || k(.spacebar)
            pFlip = pFlip || k(.keyJ)
            pGrab = pGrab || k(.keyK)
            pGrind = pGrind || k(.keyL)
            pManual = pManual || k(.keyI)
        }

        var s = simd_length(touchStick) > 0.05 ? touchStick : padStick
        let len = simd_length(s)
        if len > 1 { s /= len }
        stick = s

        ollieHeld = touchOllie || pOllie
        grabHeld = touchGrab || pGrab
        grindHeld = touchGrind || pGrind

        if pFlip && !prevPad.flip { flipQueued = true }
        if pGrind && !prevPad.grind { pressGrind() }
        if pManual && !prevPad.manual { pressManual() }
        prevPad = (pFlip, pGrind, pManual)
    }
}
