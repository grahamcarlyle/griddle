import Testing
import Foundation
@testable import GriddleLib

/// QWERTY label lookup for deterministic test results.
private func qwertyLabel(_ keyCode: UInt16) -> String {
    KeyMap.qwertyLabels[keyCode] ?? "?"
}

@Suite("KeyMap building and prefix allocation")
struct KeyMapTests {

    // MARK: - Spatial: no prefixes needed (≤3 rows)

    @Test("spatial 2x2 — all direct, no prefixes")
    func spatial2x2() {
        let km = KeyMap.build(for: .spatial, columns: 2, rows: 2, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 4)
        #expect(km.labels == ["Q", "W", "A", "S"])
        // All bindings are direct
        for (_, binding) in km.bindings {
            if case .prefix = binding { Issue.record("Expected no prefix bindings for 2x2") }
        }
        #expect(km.bindings[12] == .direct(cellIndex: 0)) // Q
        #expect(km.bindings[13] == .direct(cellIndex: 1)) // W
        #expect(km.bindings[0] == .direct(cellIndex: 2))  // A
        #expect(km.bindings[1] == .direct(cellIndex: 3))  // S
    }

    @Test("spatial 3x3 — all direct, 9 cells")
    func spatial3x3() {
        let km = KeyMap.build(for: .spatial, columns: 3, rows: 3, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 9)
        #expect(km.labels == ["Q", "W", "E", "A", "S", "D", "Z", "X", "C"])
        #expect(km.bindings[6] == .direct(cellIndex: 6))  // Z
    }

    @Test("spatial 6x3 — max direct layout, 18 cells")
    func spatial6x3() {
        let km = KeyMap.build(for: .spatial, columns: 6, rows: 3, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 18)
        // All direct
        for (_, binding) in km.bindings {
            if case .prefix = binding { Issue.record("Expected no prefix bindings for 6x3") }
        }
    }

    @Test("spatial 1x1 — single direct key")
    func spatial1x1() {
        let km = KeyMap.build(for: .spatial, columns: 1, rows: 1, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 1)
        #expect(km.labels == ["Q"])
        #expect(km.bindings.count == 1)
    }

    // MARK: - Spatial: prefix keys (>3 rows)

    @Test("spatial 4x4 — 2 direct rows + Z prefix for rows 3-4")
    func spatial4x4() {
        let km = KeyMap.build(for: .spatial, columns: 4, rows: 4, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 16)

        // Rows 1-2: direct (8 cells)
        #expect(km.bindings[12] == .direct(cellIndex: 0))  // Q → (0,0)
        #expect(km.bindings[15] == .direct(cellIndex: 3))  // R → (0,3)
        #expect(km.bindings[0] == .direct(cellIndex: 4))   // A → (1,0)
        #expect(km.bindings[3] == .direct(cellIndex: 7))   // F → (1,3)

        // Z is a prefix key
        if case .prefix(let children) = km.bindings[6] {
            #expect(children.count == 8) // 4 cols × 2 rows
            // Row 3 children use Q-row keys
            #expect(children[0] == KeyChild(keyCode: 12, label: "Q", cellIndex: 8))
            #expect(children[3] == KeyChild(keyCode: 15, label: "R", cellIndex: 11))
            // Row 4 children use A-row keys
            #expect(children[4] == KeyChild(keyCode: 0, label: "A", cellIndex: 12))
            #expect(children[7] == KeyChild(keyCode: 3, label: "F", cellIndex: 15))
        } else {
            Issue.record("Z should be a prefix binding")
        }

        // Labels for prefix cells
        #expect(km.labels[8] == "Z·Q")
        #expect(km.labels[12] == "Z·A")
        #expect(km.labels[15] == "Z·F")
    }

    @Test("spatial 6x4 — Z prefix covers 12 overflow cells")
    func spatial6x4() {
        let km = KeyMap.build(for: .spatial, columns: 6, rows: 4, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 24)

        // 12 direct + 12 via prefix
        let directCount = km.bindings.values.filter {
            if case .direct = $0 { return true }; return false
        }.count
        #expect(directCount == 12)

        if case .prefix(let children) = km.bindings[6] {
            #expect(children.count == 12)
        } else {
            Issue.record("Z should be a prefix binding")
        }
    }

    @Test("spatial 4x5 — needs 2 prefix keys (Z, X)")
    func spatial4x5() {
        let km = KeyMap.build(for: .spatial, columns: 4, rows: 5, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 20)

        // Direct: 2 rows × 4 cols = 8
        // Z prefix: rows 3-4 = 8 cells
        // X prefix: row 5 = 4 cells
        if case .prefix(let zChildren) = km.bindings[6] {
            #expect(zChildren.count == 8)
        } else {
            Issue.record("Z should be a prefix")
        }

        if case .prefix(let xChildren) = km.bindings[7] {
            #expect(xChildren.count == 4) // only row 5
            #expect(xChildren[0] == KeyChild(keyCode: 12, label: "Q", cellIndex: 16))
        } else {
            Issue.record("X should be a prefix")
        }

        #expect(km.labels[16] == "X·Q")
    }

    @Test("spatial 6x6 — 2 prefix keys cover 24 overflow cells")
    func spatial6x6() {
        let km = KeyMap.build(for: .spatial, columns: 6, rows: 6, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 36)

        // Direct: 12, Z prefix: 12, X prefix: 12
        if case .prefix(let zChildren) = km.bindings[6] {
            #expect(zChildren.count == 12)
        } else {
            Issue.record("Z should be a prefix")
        }
        if case .prefix(let xChildren) = km.bindings[7] {
            #expect(xChildren.count == 12)
        } else {
            Issue.record("X should be a prefix")
        }
    }

    // MARK: - Numbers: no prefixes needed (≤9 cells)

    @Test("numbers 2x2 — all direct, 4 cells")
    func numbers2x2() {
        let km = KeyMap.build(for: .numbers, columns: 2, rows: 2, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 4)
        #expect(km.labels == ["1", "2", "3", "4"])
        #expect(km.bindings[18] == .direct(cellIndex: 0)) // key 1
        #expect(km.bindings[21] == .direct(cellIndex: 3)) // key 4
    }

    @Test("numbers 3x3 — all direct, 9 cells (max without prefix)")
    func numbers3x3() {
        let km = KeyMap.build(for: .numbers, columns: 3, rows: 3, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 9)
        for (_, binding) in km.bindings {
            if case .prefix = binding { Issue.record("Expected no prefix bindings for 9 cells") }
        }
    }

    // MARK: - Numbers: prefix keys (>9 cells)

    @Test("numbers 4x3 (12 cells) — key 9 becomes prefix")
    func numbers12() {
        let km = KeyMap.build(for: .numbers, columns: 4, rows: 3, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 12)

        // Keys 1-8 direct
        #expect(km.bindings[18] == .direct(cellIndex: 0)) // 1
        #expect(km.bindings[28] == .direct(cellIndex: 7)) // 8

        // Key 9 is prefix
        if case .prefix(let children) = km.bindings[25] { // keyCode 25 = key 9
            #expect(children.count == 4) // cells 8-11
            #expect(children[0] == KeyChild(keyCode: 18, label: "1", cellIndex: 8))  // 9·1
            #expect(children[3] == KeyChild(keyCode: 21, label: "4", cellIndex: 11)) // 9·4
        } else {
            Issue.record("Key 9 should be a prefix")
        }

        #expect(km.labels[8] == "9·1")
        #expect(km.labels[11] == "9·4")
    }

    @Test("numbers 16 cells — key 9 prefix with 8 children")
    func numbers16() {
        let km = KeyMap.build(for: .numbers, columns: 4, rows: 4, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 16)

        // 8 direct + 8 via prefix 9 = 16
        if case .prefix(let children) = km.bindings[25] {
            #expect(children.count == 8)
        } else {
            Issue.record("Key 9 should be a prefix")
        }
    }

    @Test("numbers 18 cells — keys 8 and 9 become prefixes")
    func numbers18() {
        let km = KeyMap.build(for: .numbers, columns: 6, rows: 3, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 18)

        // 7 direct + 7 via prefix 8 + 4 via prefix 9 = 18
        let directCount = km.bindings.values.filter {
            if case .direct = $0 { return true }; return false
        }.count
        #expect(directCount == 7)

        // Key 8 (keyCode 28) is prefix
        if case .prefix(let children8) = km.bindings[28] {
            #expect(children8.count == 7)
        } else {
            Issue.record("Key 8 should be a prefix")
        }

        // Key 9 (keyCode 25) is prefix
        if case .prefix(let children9) = km.bindings[25] {
            #expect(children9.count == 4) // remaining cells
        } else {
            Issue.record("Key 9 should be a prefix")
        }
    }

    @Test("numbers 24 cells — keys 7, 8, 9 become prefixes")
    func numbers24() {
        let km = KeyMap.build(for: .numbers, columns: 6, rows: 4, labelForKeyCode: qwertyLabel)
        #expect(km.cellCount == 24)

        // 6 direct + 6×3 prefix = 24
        let directCount = km.bindings.values.filter {
            if case .direct = $0 { return true }; return false
        }.count
        #expect(directCount == 6)

        #expect(km.labels[0] == "1")
        #expect(km.labels[5] == "6")
        #expect(km.labels[6] == "7·1") // first child of prefix 7
    }

    // MARK: - Huffman property: no key is both direct and a prefix child

    @Test("spatial prefix children don't collide with direct bindings")
    func spatialHuffmanProperty() {
        let km = KeyMap.build(for: .spatial, columns: 4, rows: 4, labelForKeyCode: qwertyLabel)

        // Collect all child key codes from prefix bindings
        var childKeyCodes = Set<UInt16>()
        var prefixKeyCodes = Set<UInt16>()
        for (code, binding) in km.bindings {
            if case .prefix(let children) = binding {
                prefixKeyCodes.insert(code)
                for child in children {
                    childKeyCodes.insert(child.keyCode)
                }
            }
        }

        // No prefix key code should also be a child key code
        #expect(prefixKeyCodes.isDisjoint(with: childKeyCodes),
                "Prefix keys must not appear as children (Huffman property)")
    }

    @Test("number prefix children don't collide with prefix keys")
    func numbersHuffmanProperty() {
        let km = KeyMap.build(for: .numbers, columns: 4, rows: 3, labelForKeyCode: qwertyLabel)

        var childKeyCodes = Set<UInt16>()
        var prefixKeyCodes = Set<UInt16>()
        for (code, binding) in km.bindings {
            if case .prefix(let children) = binding {
                prefixKeyCodes.insert(code)
                for child in children {
                    childKeyCodes.insert(child.keyCode)
                }
            }
        }

        #expect(prefixKeyCodes.isDisjoint(with: childKeyCodes))
    }

    // MARK: - Coverage: all cells have bindings

    @Test("spatial 4x4 covers all 16 cells")
    func spatialCoverage() {
        let km = KeyMap.build(for: .spatial, columns: 4, rows: 4, labelForKeyCode: qwertyLabel)
        var coveredCells = Set<Int>()
        for (_, binding) in km.bindings {
            switch binding {
            case .direct(let idx): coveredCells.insert(idx)
            case .prefix(let children): children.forEach { coveredCells.insert($0.cellIndex) }
            }
        }
        #expect(coveredCells == Set(0..<16))
    }

    @Test("numbers 12 covers all 12 cells")
    func numbersCoverage() {
        let km = KeyMap.build(for: .numbers, columns: 4, rows: 3, labelForKeyCode: qwertyLabel)
        var coveredCells = Set<Int>()
        for (_, binding) in km.bindings {
            switch binding {
            case .direct(let idx): coveredCells.insert(idx)
            case .prefix(let children): children.forEach { coveredCells.insert($0.cellIndex) }
            }
        }
        #expect(coveredCells == Set(0..<12))
    }

    // MARK: - Backward compatibility: small grids match existing behavior

    @Test("spatial keyCodes match HotkeyManager for small grids")
    func spatialBackwardCompat() {
        for (cols, rows) in [(2, 2), (3, 2), (3, 3), (6, 3)] {
            let km = KeyMap.build(for: .spatial, columns: cols, rows: rows, labelForKeyCode: qwertyLabel)
            let legacyCodes = HotkeyManager.keyCodes(for: .spatial, columns: cols, rows: rows)
            let legacyLabels = HotkeyManager.keyLabels(for: .spatial, columns: cols, rows: rows)

            // All bindings should be direct, and key codes should match
            let kmCodes = km.topLevelKeyCodes.sorted()
            #expect(kmCodes == legacyCodes.sorted(),
                    "KeyMap codes should match legacy for \(cols)x\(rows)")
            #expect(km.labels == legacyLabels,
                    "KeyMap labels should match legacy for \(cols)x\(rows)")
        }
    }

    @Test("numbers keyCodes match HotkeyManager for small grids")
    func numbersBackwardCompat() {
        for (cols, rows) in [(2, 2), (3, 3)] {
            let km = KeyMap.build(for: .numbers, columns: cols, rows: rows, labelForKeyCode: qwertyLabel)
            let legacyCodes = HotkeyManager.keyCodes(for: .numbers, columns: cols, rows: rows)
            let legacyLabels = HotkeyManager.keyLabels(for: .numbers, columns: cols, rows: rows)

            let kmCodes = km.topLevelKeyCodes.sorted()
            #expect(kmCodes == legacyCodes.sorted(),
                    "KeyMap codes should match legacy for \(cols)x\(rows)")
            #expect(km.labels == legacyLabels,
                    "KeyMap labels should match legacy for \(cols)x\(rows)")
        }
    }
}
