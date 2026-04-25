import Cocoa
import GriddleLib

// Parse --output-dir argument
var outputDir = "screenshots"
if let idx = CommandLine.arguments.firstIndex(of: "--output-dir"),
   idx + 1 < CommandLine.arguments.count {
    outputDir = CommandLine.arguments[idx + 1]
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let demo = DemoController(outputDir: outputDir)

// Start the demo after the run loop is up
DispatchQueue.main.async {
    demo.run()
}

app.run()
