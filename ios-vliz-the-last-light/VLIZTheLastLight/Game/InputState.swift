import Foundation
import GameController

/// Shared input written by touch controls / keyboard and consumed by the scene each frame.
/// Presses are edge-triggered and cleared once read.
@MainActor
final class InputState {
    var touchMoveX: CGFloat = 0
    var touchAttackHeld = false
    var touchJumpHeld = false

    private(set) var attackPressed = false
    private(set) var jumpPressed = false
    private(set) var dashPressed = false
    private(set) var swapPressed = false
    private(set) var pausePressed = false

    // Keyboard state
    private var keyMoveX: CGFloat = 0
    private var keyAttack = false
    private var keyJump = false
    private var prevKeys: Set<GCKeyCode> = []

    var moveX: CGFloat {
        let v = touchMoveX + keyMoveX
        return max(-1, min(1, v))
    }
    var attackHeld: Bool { touchAttackHeld || keyAttack }
    var jumpHeld: Bool { touchJumpHeld || keyJump }

    func pressAttack() { attackPressed = true; touchAttackHeld = true }
    func releaseAttack() { touchAttackHeld = false }
    func pressJump() { jumpPressed = true; touchJumpHeld = true }
    func releaseJump() { touchJumpHeld = false }
    func pressDash() { dashPressed = true }
    func pressSwap() { swapPressed = true }

    func consumeAttack() -> Bool { defer { attackPressed = false }; return attackPressed }
    func consumeJump() -> Bool { defer { jumpPressed = false }; return jumpPressed }
    func consumeDash() -> Bool { defer { dashPressed = false }; return dashPressed }
    func consumeSwap() -> Bool { defer { swapPressed = false }; return swapPressed }
    func consumePause() -> Bool { defer { pausePressed = false }; return pausePressed }

    func reset() {
        touchMoveX = 0
        touchAttackHeld = false
        touchJumpHeld = false
        attackPressed = false
        jumpPressed = false
        dashPressed = false
        swapPressed = false
        pausePressed = false
        keyMoveX = 0
        keyAttack = false
        keyJump = false
    }

    /// Polls a hardware keyboard (simulator / iPad keyboard) for testing.
    func pollKeyboard() {
        guard let kb = GCKeyboard.coalesced?.keyboardInput else {
            keyMoveX = 0; keyAttack = false; keyJump = false
            return
        }
        func down(_ code: GCKeyCode) -> Bool { kb.button(forKeyCode: code)?.isPressed ?? false }
        let watched: [GCKeyCode] = [.keyA, .keyD, .leftArrow, .rightArrow, .spacebar, .upArrow, .keyW,
                                    .leftShift, .keyK, .keyJ, .keyL, .keyQ, .escape, .keyP]
        var now: Set<GCKeyCode> = []
        for code in watched where down(code) { now.insert(code) }
        func pressed(_ codes: GCKeyCode...) -> Bool { codes.contains { now.contains($0) && !prevKeys.contains($0) } }

        var x: CGFloat = 0
        if now.contains(.keyA) || now.contains(.leftArrow) { x -= 1 }
        if now.contains(.keyD) || now.contains(.rightArrow) { x += 1 }
        keyMoveX = x
        keyJump = now.contains(.spacebar) || now.contains(.upArrow) || now.contains(.keyW)
        keyAttack = now.contains(.keyJ)
        if pressed(.spacebar, .upArrow, .keyW) { jumpPressed = true }
        if pressed(.keyJ) { attackPressed = true }
        if pressed(.leftShift, .keyK) { dashPressed = true }
        if pressed(.keyL, .keyQ) { swapPressed = true }
        if pressed(.escape, .keyP) { pausePressed = true }
        prevKeys = now
    }
}
