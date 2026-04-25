import CoreGraphics
import Foundation
import ImageIO

enum SnapshotResult {
    case match
    case mismatch(diffPercentage: Double)
    case newSnapshot
}

struct SnapshotComparison {
    let name: String
    let result: SnapshotResult
}

struct SnapshotComparer {
    let generatedDir: String
    let blessedDir: String

    func compare() -> [SnapshotComparison] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: generatedDir) else { return [] }
        let pngs = files.filter { $0.hasSuffix(".png") }.sorted()

        var results: [SnapshotComparison] = []

        for file in pngs {
            let generatedPath = "\(generatedDir)/\(file)"
            let blessedPath = "\(blessedDir)/\(file)"

            if !fm.fileExists(atPath: blessedPath) {
                // New snapshot — copy to blessed dir
                try? fm.copyItem(atPath: generatedPath, toPath: blessedPath)
                results.append(SnapshotComparison(name: file, result: .newSnapshot))
                continue
            }

            // Compare pixels
            guard let generatedImage = loadImage(at: generatedPath),
                  let blessedImage = loadImage(at: blessedPath) else {
                results.append(SnapshotComparison(name: file, result: .mismatch(diffPercentage: 100.0)))
                continue
            }

            let diff = pixelDifference(generatedImage, blessedImage)
            if diff == 0.0 {
                results.append(SnapshotComparison(name: file, result: .match))
            } else {
                results.append(SnapshotComparison(name: file, result: .mismatch(diffPercentage: diff)))
            }
        }

        return results
    }

    private func loadImage(at path: String) -> CGImage? {
        let url = URL(fileURLWithPath: path) as CFURL
        guard let source = CGImageSourceCreateWithURL(url, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func pixelDifference(_ a: CGImage, _ b: CGImage) -> Double {
        let width = a.width
        let height = a.height

        guard width == b.width, height == b.height else { return 100.0 }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height

        var pixelsA = [UInt8](repeating: 0, count: totalBytes)
        var pixelsB = [UInt8](repeating: 0, count: totalBytes)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctxA = CGContext(data: &pixelsA, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: colorSpace, bitmapInfo: bitmapInfo),
              let ctxB = CGContext(data: &pixelsB, width: width, height: height,
                                   bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                                   space: colorSpace, bitmapInfo: bitmapInfo)
        else { return 100.0 }

        ctxA.draw(a, in: CGRect(x: 0, y: 0, width: width, height: height))
        ctxB.draw(b, in: CGRect(x: 0, y: 0, width: width, height: height))

        var diffCount = 0
        let totalPixels = width * height
        for i in stride(from: 0, to: totalBytes, by: bytesPerPixel) {
            if pixelsA[i] != pixelsB[i] || pixelsA[i+1] != pixelsB[i+1] ||
               pixelsA[i+2] != pixelsB[i+2] || pixelsA[i+3] != pixelsB[i+3] {
                diffCount += 1
            }
        }

        return Double(diffCount) / Double(totalPixels) * 100.0
    }
}
