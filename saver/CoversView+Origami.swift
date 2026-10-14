import QuartzCore

/// Origami: every few seconds a new arrangement of panels folds in over the
/// screen, one panel after another.
extension CoversView {
    private static let layoutCount = 6
    private static let foldDuration: CFTimeInterval = 1.2
    private static let stagger: CFTimeInterval = 0.15

    /// The frames of a layout other than the current one.
    func nextOrigamiFrames() -> [CGRect] {
        var next = Int.random(in: 0..<Self.layoutCount)
        while next == layoutIndex {
            next = Int.random(in: 0..<Self.layoutCount)
        }
        layoutIndex = next
        return origamiFrames(layout: next)
    }

    /// Fold a new layout in over the old one, then drop the old panels.
    func foldInNextLayout() {
        guard !images.isEmpty else { return }
        let frames = nextOrigamiFrames()
        let old = tiles

        // Covers not on screen first, so a change brings new games.
        var pool = images.indices.filter { !shown.contains($0) }.shuffled()
        if pool.count < frames.count {
            pool += shown.shuffled() + images.indices.shuffled()
        }

        tiles = []
        shown = []
        for (step, number) in frames.indices.shuffled().enumerated() {
            let index = pool[number]
            let tile = makeTile(frame: frames[number], image: images[index])
            tile.isHidden = true
            canvas.addSublayer(tile)
            tiles.append(tile)
            shown.append(index)
            fold(images[index], into: tile, delay: Double(step) * Self.stagger)
        }

        let done = Double(frames.count - 1) * Self.stagger + Self.foldDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + done) {
            CATransaction.begin()
            CATransaction.setCompletionBlock { old.forEach { $0.removeFromSuperlayer() } }
            old.forEach { $0.opacity = 0 }
            CATransaction.commit()
        }
    }

    // Covers are 2:3. Full-height panels hold one cover; the smaller ones
    // stack two to a column. Widths are rounded to whole columns, so some
    // panels crop a little.
    private func origamiFrames(layout: Int) -> [CGRect] {
        let gap: CGFloat = isPreview ? 2 : 8
        let width = bounds.width
        let height = bounds.height
        let big = (height * 2 / 3).rounded()

        switch layout {
        case 0:
            return [CGRect(x: 0, y: 0, width: big, height: height)]
                + stackedColumns(from: big + gap, to: width, gap: gap)
        case 1:
            return stackedColumns(from: 0, to: width - big - gap, gap: gap)
                + [CGRect(x: width - big, y: 0, width: big, height: height)]
        case 2:
            let x = ((width - big) / 2).rounded()
            return stackedColumns(from: 0, to: x - gap, gap: gap)
                + [CGRect(x: x, y: 0, width: big, height: height)]
                + stackedColumns(from: x + big + gap, to: width, gap: gap)
        case 3:
            return fullColumns(3, gap: gap)
        case 4:
            return fullColumns(2, gap: gap)
        default:
            return stackedColumns(from: 0, to: width, gap: gap)
        }
    }

    private func fullColumns(_ count: Int, gap: CGFloat) -> [CGRect] {
        let width = (bounds.width - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).map { column in
            CGRect(x: CGFloat(column) * (width + gap), y: 0, width: width, height: bounds.height)
        }
    }

    /// Columns of two panels filling x0...x1.
    private func stackedColumns(from x0: CGFloat, to x1: CGFloat, gap: CGFloat) -> [CGRect] {
        let span = x1 - x0
        guard span > 0 else { return [] }
        let half = (bounds.height - gap) / 2
        let count = max(1, Int((span / (half * 2 / 3)).rounded()))
        let width = (span - gap * CGFloat(count - 1)) / CGFloat(count)
        return (0..<count).flatMap { column in
            let x = x0 + CGFloat(column) * (width + gap)
            return [
                CGRect(x: x, y: 0, width: width, height: half),
                CGRect(x: x, y: half + gap, width: width, height: half),
            ]
        }
    }

    /// Unfold `image` over `panel` after `delay`: two halves hinged at the
    /// panel's outer edges swing flat and meet at a centre crease, which runs
    /// up and down or across at random. The panel shows once they land.
    private func fold(_ image: CGImage, into panel: CALayer, delay: CFTimeInterval) {
        let size = panel.bounds.size
        let crop = fillRect(image: image, in: size)
        let across = Bool.random()

        let stage = CALayer()
        stage.frame = panel.frame
        stage.sublayerTransform.m34 = -1 / (max(size.width, size.height) * 3)
        canvas.addSublayer(stage)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            panel.isHidden = false
            stage.removeFromSuperlayer()
            CATransaction.commit()
        }
        defer { CATransaction.commit() }

        let start = CACurrentMediaTime() + delay
        for first in [true, false] {
            let half = CALayer()
            half.contents = image
            half.contentsGravity = .resize
            half.masksToBounds = true

            // contentsRect runs bottom-up here, like the layer frames.
            let angle: CGFloat
            if across {
                half.bounds = CGRect(x: 0, y: 0, width: size.width, height: size.height / 2)
                half.anchorPoint = CGPoint(x: 0.5, y: first ? 0 : 1)
                half.position = CGPoint(x: size.width / 2, y: first ? 0 : size.height)
                half.contentsRect = CGRect(
                    x: crop.minX, y: crop.minY + (first ? 0 : crop.height / 2),
                    width: crop.width, height: crop.height / 2
                )
                angle = (first ? -1 : 1) * .pi * 0.49
            } else {
                half.bounds = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
                half.anchorPoint = CGPoint(x: first ? 0 : 1, y: 0.5)
                half.position = CGPoint(x: first ? 0 : size.width, y: size.height / 2)
                half.contentsRect = CGRect(
                    x: crop.minX + (first ? 0 : crop.width / 2), y: crop.minY,
                    width: crop.width / 2, height: crop.height
                )
                angle = (first ? 1 : -1) * .pi * 0.49
            }

            let shade = CALayer()
            shade.frame = half.bounds
            shade.backgroundColor = CGColor(gray: 0, alpha: 1)
            shade.opacity = 0
            half.addSublayer(shade)
            stage.addSublayer(half)

            let swing = CABasicAnimation(keyPath: across ? "transform.rotation.x" : "transform.rotation.y")
            swing.fromValue = angle
            swing.toValue = 0
            let darken = CABasicAnimation(keyPath: "opacity")
            darken.fromValue = 0.7
            darken.toValue = 0

            // Held at the start value until the delay ends.
            for (animation, timing) in [(swing, CAMediaTimingFunctionName.easeOut), (darken, .easeIn)] {
                animation.beginTime = start
                animation.duration = Self.foldDuration
                animation.fillMode = .backwards
                animation.timingFunction = CAMediaTimingFunction(name: timing)
            }
            half.add(swing, forKey: "swing")
            shade.add(darken, forKey: "darken")
        }
    }

    /// The part of `image`, in unit coordinates, that aspect-fills `size`.
    private func fillRect(image: CGImage, in size: CGSize) -> CGRect {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let panelAspect = size.width / size.height
        if imageAspect > panelAspect {
            let width = panelAspect / imageAspect
            return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
        }
        let height = imageAspect / panelAspect
        return CGRect(x: 0, y: (1 - height) / 2, width: 1, height: height)
    }
}
