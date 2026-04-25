import Testing
import CoreGraphics
@testable import GriddleLib

@Suite("SimulatedDisplaySystem")
struct SimulatedDisplaySystemTests {
    let screen = ScreenInfo(
        id: "Test @ 0,0",
        localizedName: "Test",
        frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
        visibleFrame: CGRect(x: 0, y: 25, width: 1920, height: 1055)
    )

    @Test("moveFocusedWindow updates the focused window's frame")
    func moveUpdatesFrame() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true)
        ])

        let newFrame = CGRect(x: 0, y: 25, width: 960, height: 527.5)
        sim.moveFocusedWindow(to: newFrame)

        #expect(sim.focusedWindow?.frame == newFrame)
    }

    @Test("moveFocusedWindow only moves the focused window")
    func moveOnlyAffectsFocused() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true),
            SimWindow(title: "Terminal", appName: "Terminal",
                      frame: CGRect(x: 300, y: 200, width: 500, height: 300))
        ])

        let originalTerminalFrame = sim.windows[1].frame
        sim.moveFocusedWindow(to: CGRect(x: 0, y: 0, width: 100, height: 100))

        #expect(sim.windows[1].frame == originalTerminalFrame)
    }

    @Test("screenForFocusedWindow returns correct screen")
    func screenForFocused() {
        let screen2 = ScreenInfo(
            id: "External @ 1920,0",
            localizedName: "External",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 25, width: 2560, height: 1415)
        )

        let sim = SimulatedDisplaySystem(screens: [screen, screen2], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 2000, y: 100, width: 600, height: 400), isFocused: true)
        ])

        let result = sim.screenForFocusedWindow()
        #expect(result?.id == "External @ 1920,0")
    }

    @Test("isFocusedWindowFullScreen reflects focused window state")
    func fullScreenCheck() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                      isFocused: true, isFullScreen: true)
        ])

        #expect(sim.isFocusedWindowFullScreen() == true)
    }

    @Test("focusWindow helper changes focus correctly")
    func focusWindowHelper() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true),
            SimWindow(title: "Terminal", appName: "Terminal",
                      frame: CGRect(x: 300, y: 200, width: 500, height: 300))
        ])

        sim.focusWindow(at: 1)
        #expect(sim.windows[0].isFocused == false)
        #expect(sim.windows[1].isFocused == true)
        #expect(sim.focusedWindow?.title == "Terminal")
    }

    @Test("end-to-end: tile focused window into grid cell")
    func endToEndTiling() {
        let sim = SimulatedDisplaySystem(screens: [screen], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 100, y: 100, width: 600, height: 400), isFocused: true)
        ])

        let layout = GridLayout.uniform(id: "2x2", name: "2x2", columns: 2, rows: 2)
        let cell = layout.cells[0] // top-left
        let targetFrame = WindowMover.frame(for: cell, in: layout, on: screen)
        sim.moveFocusedWindow(to: targetFrame)

        let result = sim.focusedWindow!.frame
        #expect(result.origin.x == 0)
        #expect(result.origin.y == 25)
        #expect(result.width == 960)
        #expect(result.height == 527.5)
    }

    @Test("end-to-end: multi-screen tiling uses correct screen frame")
    func multiScreenTiling() {
        let screen2 = ScreenInfo(
            id: "External @ 1920,0",
            localizedName: "External",
            frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
            visibleFrame: CGRect(x: 1920, y: 25, width: 2560, height: 1415)
        )

        let sim = SimulatedDisplaySystem(screens: [screen, screen2], windows: [
            SimWindow(title: "Safari", appName: "Safari",
                      frame: CGRect(x: 2000, y: 100, width: 600, height: 400), isFocused: true)
        ])

        guard let focusedScreen = sim.screenForFocusedWindow() else {
            #expect(Bool(false), "Should find screen for focused window")
            return
        }

        let layout = GridLayout.uniform(id: "2x1", name: "2x1", columns: 2, rows: 1)
        let cell = layout.cells[0] // left half
        let targetFrame = WindowMover.frame(for: cell, in: layout, on: focusedScreen)
        sim.moveFocusedWindow(to: targetFrame)

        let result = sim.focusedWindow!.frame
        #expect(result.origin.x == 1920) // on the external screen
        #expect(result.width == 1280)    // half of 2560
    }
}
