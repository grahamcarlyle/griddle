import Testing
import Cocoa
@testable import GriddleLib

@Suite("HotkeyManager.nsModifierFlags")
struct ModifierFlagsTests {

    @Test("ctrl maps to .control")
    func ctrl() {
        let flags = HotkeyManager.nsModifierFlags(from: ["ctrl"])
        #expect(flags.contains(.control))
        #expect(!flags.contains(.option))
        #expect(!flags.contains(.command))
        #expect(!flags.contains(.shift))
    }

    @Test("alt maps to .option")
    func alt() {
        let flags = HotkeyManager.nsModifierFlags(from: ["alt"])
        #expect(flags.contains(.option))
    }

    @Test("cmd maps to .command")
    func cmd() {
        let flags = HotkeyManager.nsModifierFlags(from: ["cmd"])
        #expect(flags.contains(.command))
    }

    @Test("shift maps to .shift")
    func shift() {
        let flags = HotkeyManager.nsModifierFlags(from: ["shift"])
        #expect(flags.contains(.shift))
    }

    @Test("multiple modifiers are combined")
    func combined() {
        let flags = HotkeyManager.nsModifierFlags(from: ["ctrl", "alt"])
        #expect(flags.contains(.control))
        #expect(flags.contains(.option))
        #expect(!flags.contains(.command))
    }

    @Test("case insensitive")
    func caseInsensitive() {
        let flags = HotkeyManager.nsModifierFlags(from: ["CTRL", "Alt", "CMD"])
        #expect(flags.contains(.control))
        #expect(flags.contains(.option))
        #expect(flags.contains(.command))
    }

    @Test("unknown keys are ignored")
    func unknownKeys() {
        let flags = HotkeyManager.nsModifierFlags(from: ["ctrl", "unknown", "bogus"])
        #expect(flags.contains(.control))
        #expect(!flags.contains(.option))
        #expect(!flags.contains(.command))
        #expect(!flags.contains(.shift))
    }

    @Test("empty input returns empty flags")
    func empty() {
        let flags = HotkeyManager.nsModifierFlags(from: [])
        #expect(flags.isEmpty)
    }
}
