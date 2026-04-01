import Testing
import Foundation
@testable import GriddleLib

@Suite("KeyStyle and key code mapping")
struct KeyStyleTests {

    // MARK: - Spatial key codes

    @Test("spatial 2x2 returns Q/W/A/S codes")
    func spatial2x2() {
        let codes = HotkeyManager.keyCodes(for: .spatial, columns: 2, rows: 2)
        #expect(codes == [12, 13, 0, 1]) // Q, W, A, S
    }

    @Test("spatial 3x2 returns Q/W/E/A/S/D codes")
    func spatial3x2() {
        let codes = HotkeyManager.keyCodes(for: .spatial, columns: 3, rows: 2)
        #expect(codes == [12, 13, 14, 0, 1, 2]) // Q, W, E, A, S, D
    }

    @Test("spatial 3x3 returns 9 codes across 3 keyboard rows")
    func spatial3x3() {
        let codes = HotkeyManager.keyCodes(for: .spatial, columns: 3, rows: 3)
        #expect(codes == [12, 13, 14, 0, 1, 2, 6, 7, 8]) // Q,W,E, A,S,D, Z,X,C
    }

    @Test("spatial 1x1 returns just Q")
    func spatial1x1() {
        let codes = HotkeyManager.keyCodes(for: .spatial, columns: 1, rows: 1)
        #expect(codes == [12]) // Q
    }

    @Test("spatial respects column count per row")
    func spatial2x3() {
        let codes = HotkeyManager.keyCodes(for: .spatial, columns: 2, rows: 3)
        #expect(codes == [12, 13, 0, 1, 6, 7]) // Q,W, A,S, Z,X
    }

    // MARK: - Number key codes

    @Test("numbers style returns sequential number row codes")
    func numbers2x2() {
        let codes = HotkeyManager.keyCodes(for: .numbers, columns: 2, rows: 2)
        #expect(codes == [18, 19, 20, 21]) // 1, 2, 3, 4
    }

    @Test("numbers style caps at 9 keys")
    func numbersCapsAt9() {
        let codes = HotkeyManager.keyCodes(for: .numbers, columns: 4, rows: 3)
        #expect(codes.count == 9)
    }

    // MARK: - Key labels

    @Test("spatial labels for 2x2")
    func spatialLabels2x2() {
        let labels = HotkeyManager.keyLabels(for: .spatial, columns: 2, rows: 2)
        #expect(labels == ["Q", "W", "A", "S"])
    }

    @Test("spatial labels for 3x3")
    func spatialLabels3x3() {
        let labels = HotkeyManager.keyLabels(for: .spatial, columns: 3, rows: 3)
        #expect(labels == ["Q", "W", "E", "A", "S", "D", "Z", "X", "C"])
    }

    @Test("number labels for 2x2")
    func numberLabels2x2() {
        let labels = HotkeyManager.keyLabels(for: .numbers, columns: 2, rows: 2)
        #expect(labels == ["1", "2", "3", "4"])
    }

    @Test("number labels for 3x3")
    func numberLabels3x3() {
        let labels = HotkeyManager.keyLabels(for: .numbers, columns: 3, rows: 3)
        #expect(labels == ["1", "2", "3", "4", "5", "6", "7", "8", "9"])
    }

    // MARK: - Config

    @Test("default key style is spatial")
    func defaultKeyStyle() {
        #expect(GriddleConfig.default.keyStyle == .spatial)
    }

    @Test("keyStyle roundtrips through JSON")
    func keyStyleRoundtrip() throws {
        let config = GriddleConfig(
            activeLayoutID: "2x2",
            layouts: [.uniform(id: "2x2", name: "2×2", columns: 2, rows: 2)],
            modifier: .init(keys: ["ctrl"]),
            keyStyle: .numbers
        )
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: data)
        #expect(decoded.keyStyle == .numbers)
    }

    @Test("missing keyStyle in JSON defaults to spatial")
    func missingKeyStyleDefaultsToSpatial() throws {
        let json = """
        {
            "activeLayoutID": "2x2",
            "layouts": [],
            "modifier": {"keys": ["ctrl"]}
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: json)
        #expect(decoded.keyStyle == .spatial)
    }
}
