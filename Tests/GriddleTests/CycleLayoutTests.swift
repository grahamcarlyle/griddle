import Testing
import Foundation
@testable import GriddleLib

@Suite("ConfigStore.cycleLayout")
struct CycleLayoutTests {
    private func makeStore(activeID: String = "A") -> ConfigStore {
        let layouts = [
            GridLayout.uniform(id: "A", name: "A", columns: 2, rows: 2),
            GridLayout.uniform(id: "B", name: "B", columns: 3, rows: 2),
            GridLayout.uniform(id: "C", name: "C", columns: 3, rows: 3),
        ]
        let config = GriddleConfig(
            activeLayoutID: activeID,
            layouts: layouts,
            modifier: .init(keys: ["ctrl", "alt"])
        )
        return ConfigStore(config: config)
    }

    @Test("forward cycle wraps through layouts globally")
    func forwardWraps() {
        let store = makeStore()
        store.cycleLayout()
        #expect(store.config.activeLayoutID == "B")
        store.cycleLayout()
        #expect(store.config.activeLayoutID == "C")
        store.cycleLayout()
        #expect(store.config.activeLayoutID == "A")
    }

    @Test("reverse cycle wraps backwards through layouts globally")
    func reverseWraps() {
        let store = makeStore()
        store.cycleLayout(reverse: true)
        #expect(store.config.activeLayoutID == "C")
        store.cycleLayout(reverse: true)
        #expect(store.config.activeLayoutID == "B")
        store.cycleLayout(reverse: true)
        #expect(store.config.activeLayoutID == "A")
    }

    @Test("single-layout pool is a no-op in both directions")
    func singleLayoutNoOp() {
        let layouts = [GridLayout.uniform(id: "A", name: "A", columns: 2, rows: 2)]
        let config = GriddleConfig(
            activeLayoutID: "A",
            layouts: layouts,
            modifier: .init(keys: ["ctrl", "alt"])
        )
        let store = ConfigStore(config: config)

        store.cycleLayout()
        #expect(store.config.activeLayoutID == "A")
        store.cycleLayout(reverse: true)
        #expect(store.config.activeLayoutID == "A")
    }

    @Test("per-screen cycle updates screenLayouts, not activeLayoutID")
    func perScreenCycle() {
        let store = makeStore()
        let screen = ScreenInfo(
            id: "screen-1",
            localizedName: "Test",
            frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )

        store.cycleLayout(on: screen)
        #expect(store.config.screenLayouts["screen-1"] == "B")
        #expect(store.config.activeLayoutID == "A")

        store.cycleLayout(on: screen, reverse: true)
        #expect(store.config.screenLayouts["screen-1"] == "A")
        #expect(store.config.activeLayoutID == "A")
    }

    @Test("legacy shift modifier is stripped on decode")
    func shiftStrippedFromLegacyConfig() throws {
        let json = """
        {
          "activeLayoutID": "2x2",
          "layouts": [
            {
              "id": "2x2", "name": "2×2", "columns": 2, "rows": 2,
              "cells": [
                {"col":0,"row":0,"colSpan":1,"rowSpan":1},
                {"col":1,"row":0,"colSpan":1,"rowSpan":1},
                {"col":0,"row":1,"colSpan":1,"rowSpan":1},
                {"col":1,"row":1,"colSpan":1,"rowSpan":1}
              ]
            }
          ],
          "modifier": {"keys": ["ctrl", "alt", "shift"]}
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(GriddleConfig.self, from: json)
        #expect(decoded.modifier.keys == ["ctrl", "alt"])
    }
}
