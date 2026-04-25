import Cocoa
import GriddleLib

// Parse --output-dir argument
var outputDir = "screenshots"
if let idx = CommandLine.arguments.firstIndex(of: "--output-dir"),
   idx + 1 < CommandLine.arguments.count {
    outputDir = CommandLine.arguments[idx + 1]
}

// Parse --blessed-dir argument (for snapshot comparison)
var blessedDir: String?
if let idx = CommandLine.arguments.firstIndex(of: "--blessed-dir"),
   idx + 1 < CommandLine.arguments.count {
    blessedDir = CommandLine.arguments[idx + 1]
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let demo = DemoController(outputDir: outputDir)

// Start the demo after the run loop is up
DispatchQueue.main.async {
    demo.run()

    if let blessedDir = blessedDir {
        let framesDir = "\(outputDir)/frames"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: blessedDir, withIntermediateDirectories: true)

        let comparer = SnapshotComparer(generatedDir: framesDir, blessedDir: blessedDir)
        let results = comparer.compare()

        var hasMismatch = false
        var hasNew = false
        var hasBlessed = false

        for r in results {
            switch r.result {
            case .match:
                hasBlessed = true
                NSLog("Snapshot OK: \(r.name)")
            case .mismatch(let diff):
                hasBlessed = true
                hasMismatch = true
                NSLog("Snapshot FAIL: \(r.name) — \(String(format: "%.2f", diff))%% pixels differ")
            case .newSnapshot:
                hasNew = true
                NSLog("Snapshot NEW: \(r.name) — blessed")
            }
        }

        if !hasBlessed && hasNew {
            NSLog("Snapshot: No existing blessed images. Generated \(results.count) new snapshots.")
        }

        if hasMismatch {
            NSLog("Snapshot: FAILED — visual regression detected. Trigger 'Bless Snapshots' workflow to update.")
            exit(1)
        } else {
            NSLog("Snapshot: All \(results.count) snapshots OK.")
        }
    }

    NSApplication.shared.terminate(nil)
}

app.run()
