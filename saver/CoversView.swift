import ScreenSaver
import QuartzCore
import os

/// A wall of Steam covers. Every few seconds one tile fades to another game.
@objc(CoversView)
final class CoversView: ScreenSaverView {
    private let log = Logger(subsystem: "local.covers-for-steam", category: "view")
    private var images: [CGImage] = []
    private var tiles: [CALayer] = []
    private var shown: [Int] = []

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 3
        wantsLayer = true
        layer?.backgroundColor = NSColor(white: 0.04, alpha: 1).cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var hasConfigureSheet: Bool { false }

    override func startAnimation() {
        super.startAnimation()
        if images.isEmpty {
            images = CoverLibrary.coverURLs().compactMap { url in
                NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
            log.notice("Loaded \(self.images.count, privacy: .public) images, preview: \(self.isPreview, privacy: .public)")
        }
        buildWall()
    }

    override func animateOneFrame() {
        guard images.count > shown.count, let slot = shown.indices.randomElement() else { return }
        guard let next = images.indices.filter({ !shown.contains($0) }).randomElement() else { return }

        let fade = CATransition()
        fade.type = .fade
        fade.duration = 1.5
        tiles[slot].add(fade, forKey: "contents")
        tiles[slot].contents = images[next]
        shown[slot] = next
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        buildWall()
    }

    // Covers are 2:3, so the row count sets the tile size and the columns
    // overflow the edges evenly.
    private func buildWall() {
        guard let root = layer else { return }
        tiles.forEach { $0.removeFromSuperlayer() }
        tiles = []
        shown = []

        guard !images.isEmpty else {
            showEmptyMessage(in: root)
            return
        }

        let rows = isPreview ? 2 : 3
        let gap: CGFloat = isPreview ? 2 : 6
        let height = (bounds.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let width = height * 2 / 3
        let columns = Int(ceil((bounds.width + gap) / (width + gap)))
        let wallWidth = CGFloat(columns) * (width + gap) - gap
        let x0 = (bounds.width - wallWidth) / 2

        let pool = images.indices.shuffled()
        for row in 0..<rows {
            for column in 0..<columns {
                let tile = CALayer()
                tile.frame = CGRect(
                    x: x0 + CGFloat(column) * (width + gap),
                    y: CGFloat(row) * (height + gap),
                    width: width,
                    height: height
                )
                tile.contentsGravity = .resizeAspectFill
                tile.masksToBounds = true
                let index = pool[(row * columns + column) % pool.count]
                tile.contents = images[index]
                root.addSublayer(tile)
                tiles.append(tile)
                shown.append(index)
            }
        }
    }

    private func showEmptyMessage(in root: CALayer) {
        let text = CATextLayer()
        text.string = "No Steam covers found.\nOpen your Steam library once to fill the cache."
        text.alignmentMode = .center
        text.fontSize = isPreview ? 10 : 24
        text.foregroundColor = NSColor(white: 0.7, alpha: 1).cgColor
        text.contentsScale = window?.backingScaleFactor ?? 2
        text.frame = bounds.insetBy(dx: 20, dy: bounds.height / 2 - (isPreview ? 20 : 40))
        root.addSublayer(text)
        tiles.append(text)
    }
}
