// Render images/wall.jpg for the README: the Wall layout at 1600 × 900 with
// covers from this Mac's Steam cache. App IDs given as arguments fill the
// first tiles in order; the rest are shuffled.
//
//   swiftc -O saver/CoverLibrary.swift tools/wall/main.swift -o build/wall && build/wall [appid …]
//   jpegoptim --strip-all --all-progressive images/wall.jpg
import AppKit

let width = 1600, height = 900
let rows = 3
let gap: CGFloat = 4

let covers = CoverLibrary.coverURLs(includeGenerated: false)
let appID = { (url: URL) in url.pathComponents.first { Int($0) != nil } ?? "" }
let picked = CommandLine.arguments.dropFirst().compactMap { id in covers.first { appID($0) == id } }
let order = picked + covers.filter { !picked.contains($0) }.shuffled()

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.setFillColor(CGColor(gray: 0.04, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

// Same arithmetic as CoversView.wallFrames(): the row count sets the tile
// size and the columns overflow both edges evenly.
let tileHeight = (CGFloat(height) - gap * CGFloat(rows - 1)) / CGFloat(rows)
let tileWidth = tileHeight * 2 / 3
let columns = Int(ceil((CGFloat(width) + gap) / (tileWidth + gap)))
let x0 = (CGFloat(width) - (CGFloat(columns) * (tileWidth + gap) - gap)) / 2

var index = 0
for row in (0..<rows).reversed() {
    for column in 0..<columns where !order.isEmpty {
        let rect = CGRect(x: x0 + CGFloat(column) * (tileWidth + gap),
                          y: CGFloat(row) * (tileHeight + gap), width: tileWidth, height: tileHeight)
        let url = order[index % order.count]
        index += 1
        guard let image = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else { continue }

        // Aspect fill, as the tiles do.
        let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        context.saveGState()
        context.clip(to: rect)
        context.draw(image, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                       width: size.width, height: size.height))
        context.restoreGState()
    }
}

let out = URL(fileURLWithPath: "images/wall.jpg")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])!.write(to: out)
print("Wrote \(out.path) with \(min(index, order.count)) of \(covers.count) covers")
