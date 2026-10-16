// Draw saver/Resources/thumbnail.png and thumbnail@2x.png, the images System
// Settings shows for the screensaver: the Wall layout with plain gradient
// tiles in place of cover art. Run with `swift tools/thumbnail.swift`.
import AppKit

let resources = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "saver/Resources")

// Top and bottom colours of each tile, in reading order.
let palette: [(UInt32, UInt32)] = [
    (0x3B5B7A, 0x14202E), (0xC2743A, 0x4A2412), (0x5E7F4B, 0x1D2A17),
    (0x8A3B4F, 0x2C1018), (0xD9B45A, 0x5C4416), (0x40707A, 0x122428),
    (0x6B4F8A, 0x1E1530), (0xB0503A, 0x3A160E), (0x2F6B5A, 0x0E241D),
    (0x9A7B5C, 0x30241A), (0x4A5A9A, 0x161B36), (0xC9905E, 0x4A2E18),
]

func color(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

func draw(width: Int, height: Int, scale: CGFloat) -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(CGColor(gray: 0.04, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Two rows, as in the saver's own preview; the columns overflow evenly.
    let rows = 2
    let gap = 1.5 * scale
    let tileHeight = (CGFloat(height) - gap * CGFloat(rows - 1)) / CGFloat(rows)
    let tileWidth = tileHeight * 2 / 3
    let columns = Int(ceil((CGFloat(width) + gap) / (tileWidth + gap)))
    let x0 = (CGFloat(width) - (CGFloat(columns) * (tileWidth + gap) - gap)) / 2

    var index = 0
    for row in (0..<rows).reversed() {
        for column in 0..<columns {
            let rect = CGRect(x: x0 + CGFloat(column) * (tileWidth + gap),
                              y: CGFloat(row) * (tileHeight + gap), width: tileWidth, height: tileHeight)
            let (top, bottom) = palette[index % palette.count]
            index += 1
            let gradient = CGGradient(colorsSpace: space, colors: [color(top), color(bottom)] as CFArray,
                                      locations: [0, 1])!
            context.saveGState()
            context.clip(to: rect)
            context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.maxY),
                                       end: CGPoint(x: rect.midX, y: rect.minY), options: [])

            // A pale bar where a cover usually carries its title.
            context.setFillColor(CGColor(gray: 1, alpha: 0.35))
            context.fill(CGRect(x: rect.minX + rect.width * 0.18, y: rect.minY + rect.height * 0.16,
                                width: rect.width * 0.64, height: max(1, rect.height * 0.06)))
            context.restoreGState()
        }
    }

    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
try draw(width: 90, height: 58, scale: 1).write(to: resources.appending(path: "thumbnail.png"))
try draw(width: 180, height: 116, scale: 2).write(to: resources.appending(path: "thumbnail@2x.png"))
print("Wrote thumbnails to \(resources.path)")
