// Render images/wall.jpg or images/origami.jpg for the README at 1600 × 900
// with covers from this Mac's Steam cache. App IDs after the mode fill the
// first tiles in order; the rest are shuffled.
//
//   swiftc -O saver/CoverLibrary.swift tools/wall/main.swift -o build/wall && build/wall wall|origami [appid …]
//   jpegoptim --strip-all --all-progressive images/wall.jpg
import AppKit

let width: CGFloat = 1600, height: CGFloat = 900

// Gaps in the saver are in points on a screen about 1440 points tall.
let pointScale = height / 1440

let arguments = Array(CommandLine.arguments.dropFirst())
let mode = arguments.first ?? "wall"
guard mode == "wall" || mode == "origami" else {
    print("Mode must be wall or origami")
    exit(1)
}

let covers = CoverLibrary.coverURLs(includeGenerated: false, gamesOnly: true)
let appID = { (url: URL) in url.pathComponents.first { Int($0) != nil } ?? "" }
let picked = arguments.dropFirst().compactMap { id in covers.first { appID($0) == id } }
let order = picked + covers.filter { !picked.contains($0) }.shuffled()

// Same arithmetic as CoversView.wallFrames(): the row count sets the tile
// size and the columns overflow both edges evenly. Rows run top to bottom.
func wallFrames() -> [CGRect] {
    let rows = 3
    let gap = 6 * pointScale
    let tileHeight = (height - gap * CGFloat(rows - 1)) / CGFloat(rows)
    let tileWidth = tileHeight * 2 / 3
    let columns = Int(ceil((width + gap) / (tileWidth + gap)))
    let x0 = (width - (CGFloat(columns) * (tileWidth + gap) - gap)) / 2
    return (0..<rows).reversed().flatMap { row in
        (0..<columns).map { column in
            CGRect(x: x0 + CGFloat(column) * (tileWidth + gap), y: CGFloat(row) * (tileHeight + gap),
                   width: tileWidth, height: tileHeight)
        }
    }
}

// Layout 2 of CoversView.origamiFrames(layout:): a full-height cover in the
// middle between columns of two.
func origamiFrames() -> [CGRect] {
    let gap = 8 * pointScale
    let big = (height * 2 / 3).rounded()
    let x = ((width - big) / 2).rounded()

    func stackedColumns(from x0: CGFloat, to x1: CGFloat) -> [CGRect] {
        let span = x1 - x0
        let half = (height - gap) / 2
        let count = max(1, Int((span / (half * 2 / 3)).rounded()))
        let columnWidth = (span - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).flatMap { column in
            let cx = x0 + CGFloat(column) * (columnWidth + gap)
            return [CGRect(x: cx, y: half + gap, width: columnWidth, height: half),
                    CGRect(x: cx, y: 0, width: columnWidth, height: half)]
        }
    }

    return [CGRect(x: x, y: 0, width: big, height: height)]
        + stackedColumns(from: 0, to: x - gap)
        + stackedColumns(from: x + big + gap, to: width)
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let context = CGContext(data: nil, width: Int(width), height: Int(height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.interpolationQuality = .high
context.setFillColor(CGColor(gray: 0.04, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

let frames = mode == "wall" ? wallFrames() : origamiFrames()
for (index, rect) in frames.enumerated() where !order.isEmpty {
    guard let image = NSImage(contentsOf: order[index % order.count])?
        .cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }

    // Aspect fill, as the tiles do.
    let scale = max(rect.width / CGFloat(image.width), rect.height / CGFloat(image.height))
    let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
    context.saveGState()
    context.clip(to: rect)
    context.draw(image, in: CGRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2,
                                   width: size.width, height: size.height))
    context.restoreGState()
}

let out = URL(fileURLWithPath: "images/\(mode).jpg")
try FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
try rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72])!.write(to: out)
for (index, url) in order.prefix(frames.count).enumerated() { print(index, appID(url)) }
print("Wrote \(out.path) with \(min(frames.count, order.count)) of \(covers.count) covers")
