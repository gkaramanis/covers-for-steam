import ScreenSaver
import QuartzCore
import os

/// Steam covers as a wall of tiles or as origami panels.
@objc(CoversView)
final class CoversView: ScreenSaverView {
    private let log = Logger(subsystem: "is.karaman.covers-for-steam", category: "view")
    private var optionsSheet: OptionsSheet?
    private var mode = Preferences.mode
    private var loadedGenerated = false

    static let backdrop = CGColor(gray: 0.04, alpha: 1)

    /// Holds every layer the saver draws, apart from AppKit's own.
    let canvas = CALayer()
    var images: [CGImage] = []
    var tiles: [CALayer] = []
    var shown: [Int] = []
    var layoutIndex = -1
    var origamiTicks = 0
    var transitioning = false

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = mode.interval
        wantsLayer = true
        layer?.backgroundColor = Self.backdrop
        canvas.frame = bounds
        layer?.addSublayer(canvas)
        log.notice("View created, preview: \(isPreview, privacy: .public), pid: \(getpid(), privacy: .public)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let sheet = OptionsSheet { [weak self] in
            guard let self else { return }
            self.optionsSheet = nil
            self.applyPreferences()
            self.build()
        }
        optionsSheet = sheet
        log.notice("Options opened, preview: \(self.isPreview, privacy: .public), pid: \(getpid(), privacy: .public)")
        return sheet.window
    }

    // Since macOS 14 the host does not always stop a view when the screen
    // saver ends. A view whose window has gone stops animating.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil, isAnimating {
            log.notice("Window gone, stopping, preview: \(self.isPreview, privacy: .public)")
            stopAnimation()
        }
    }

    override func startAnimation() {
        applyPreferences()
        super.startAnimation()
        build()
    }

    /// Read the saved options and reload the covers if the set changed.
    private func applyPreferences() {
        mode = Preferences.mode
        animationTimeInterval = mode.interval
        let includeGenerated = Preferences.includeGenerated
        if images.isEmpty || includeGenerated != loadedGenerated {
            images = CoverLibrary.coverURLs(includeGenerated: includeGenerated).compactMap { url in
                NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil).flatMap(Self.decoded)
            }
            loadedGenerated = includeGenerated
        }
        log.notice("Mode \(self.mode.rawValue, privacy: .public), \(self.images.count, privacy: .public) images, generated: \(includeGenerated, privacy: .public), preview: \(self.isPreview, privacy: .public), pid: \(getpid(), privacy: .public)")
    }

    override func animateOneFrame() {
        if mode == .origami {
            origamiTick()
            return
        }
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
        build()
    }

    private func build() {
        canvas.frame = bounds
        canvas.sublayers?.forEach { $0.removeFromSuperlayer() }
        tiles = []
        shown = []

        guard !images.isEmpty else {
            showEmptyMessage()
            return
        }

        let frames = switch mode {
        case .wall: wallFrames()
        case .origami: nextOrigamiFrames()
        }

        let pool = images.indices.shuffled()
        for (number, frame) in frames.enumerated() {
            let index = pool[number % pool.count]
            let tile = makeTile(frame: frame, image: images[index])
            canvas.addSublayer(tile)
            tiles.append(tile)
            shown.append(index)
        }
    }

    /// A bitmap copy of `image`. JPEGs otherwise decode on first draw, in
    /// the middle of an animation.
    private static func decoded(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return image }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }

    func makeTile(frame: CGRect, image: CGImage) -> CALayer {
        let tile = CALayer()
        tile.frame = frame
        tile.contentsGravity = .resizeAspectFill
        tile.masksToBounds = true
        tile.contents = image
        return tile
    }

    // Covers are 2:3, so the row count sets the tile size and the columns
    // overflow the edges evenly.
    private func wallFrames() -> [CGRect] {
        let rows = isPreview ? 2 : 3
        let gap: CGFloat = isPreview ? 2 : 6
        let height = (bounds.height - gap * CGFloat(rows - 1)) / CGFloat(rows)
        let width = height * 2 / 3
        let columns = Int(ceil((bounds.width + gap) / (width + gap)))
        let wallWidth = CGFloat(columns) * (width + gap) - gap
        let x0 = (bounds.width - wallWidth) / 2

        return (0..<rows).flatMap { row in
            (0..<columns).map { column in
                CGRect(
                    x: x0 + CGFloat(column) * (width + gap),
                    y: CGFloat(row) * (height + gap),
                    width: width,
                    height: height
                )
            }
        }
    }

    private func showEmptyMessage() {
        let text = CATextLayer()
        text.string = "No Steam covers found.\nOpen your Steam library once to fill the cache."
        text.alignmentMode = .center
        text.fontSize = isPreview ? 10 : 24
        text.foregroundColor = NSColor(white: 0.7, alpha: 1).cgColor
        text.contentsScale = window?.backingScaleFactor ?? 2
        text.frame = bounds.insetBy(dx: 20, dy: bounds.height / 2 - (isPreview ? 20 : 40))
        canvas.addSublayer(text)
    }
}
