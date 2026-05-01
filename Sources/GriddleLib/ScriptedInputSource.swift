/// Programmatic input source for tests and demos — no system permissions needed.
public class ScriptedInputSource: InputSource {
    private weak var handler: InputHandler?

    public init() {}

    public func start(handler: InputHandler) {
        self.handler = handler
    }

    public func stop() {
        // No-op for scripted input
    }

    public func cancelModifierTap() {
        // No-op for scripted input
    }

    public func sendModifierTap() {
        handler?.handleModifierTap()
    }

    @discardableResult
    public func sendKeyDown(keyCode: UInt16, shiftHeld: Bool = false) -> Bool {
        return handler?.handleKeyDown(keyCode: keyCode, shiftHeld: shiftHeld) ?? false
    }

    public func sendShiftFlagsChanged(held: Bool) {
        handler?.handleShiftFlagsChanged(held: held)
    }
}
