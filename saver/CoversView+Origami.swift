import QuartzCore

/// Origami, after Apple's slideshow style of that name: covers sit in a
/// layout of panels. Most ticks one panel turns over to a new cover; every
/// third tick the whole layout changes with an accordion, a page flip or a
/// fold.
extension CoversView {
    private static let layoutCount = 6
    private static let transitionDuration: CFTimeInterval = 1.3
    private static let layoutEvery = 3

    func origamiTick() {
        guard !images.isEmpty, !transitioning else { return }
        origamiTicks += 1
        if origamiTicks % Self.layoutEvery == 0 {
            changeLayout()
        } else {
            flipOneTile()
        }
    }

    /// The frames of a layout other than the current one.
    func nextOrigamiFrames() -> [CGRect] {
        var next = Int.random(in: 0..<Self.layoutCount)
        while next == layoutIndex {
            next = Int.random(in: 0..<Self.layoutCount)
        }
        layoutIndex = next
        return origamiFrames(layout: next)
    }

    // MARK: Single tiles

    /// A new cover drops onto one tile, hinged at one of its edges.
    private func flipOneTile() {
        guard images.count > shown.count, let slot = shown.indices.randomElement(),
              let next = images.indices.filter({ !shown.contains($0) }).randomElement()
        else { return }

        let tile = tiles[slot]
        let card = makeTile(frame: tile.frame, image: images[next])
        smoothEdges(card)
        let edge = Edge.allCases.randomElement()!
        hinge(card, at: edge)
        let stage = makeStage()
        stage.addSublayer(card)

        run(cleanup: {
            tile.contents = self.images[next]
            stage.removeFromSuperlayer()
        }) {
            swing(card, edge: edge, from: edge.openAngle, to: 0, timing: .easeOut)
            darken(card, from: 0.7, to: 0, timing: .easeIn)
        }
        shown[slot] = next
    }

    // MARK: Layout changes

    private enum Transition: CaseIterable {
        case accordion, accordionIn, flip, fold
    }

    private func changeLayout() {
        let oldTiles = tiles
        let frames = nextOrigamiFrames()

        // Covers not on screen first, so a change brings new games.
        var pool = images.indices.filter { !shown.contains($0) }.shuffled()
        if pool.count < frames.count {
            pool += shown.shuffled() + images.indices.shuffled()
        }
        let newTiles = frames.enumerated().map { number, frame in
            makeTile(frame: frame, image: images[pool[number]])
        }

        // The new layout goes underneath; copies of the old one cover it
        // and move away.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        newTiles.reversed().forEach { canvas.insertSublayer($0, at: 0) }
        let stage = makeStage()
        let transition = Transition.allCases.randomElement()!
        switch transition {
        case .accordion: accordion(oldTiles, in: stage, toCentre: false)
        case .accordionIn: accordion(oldTiles, in: stage, toCentre: true)
        case .flip: pageFlip(from: oldTiles, to: newTiles, in: stage)
        case .fold: fold(oldTiles, in: stage)
        }
        oldTiles.forEach { $0.removeFromSuperlayer() }
        CATransaction.commit()

        tiles = newTiles
        shown = Array(pool.prefix(frames.count))
    }

    /// The old screen collapses in pleats towards an edge, or the centre.
    private func accordion(_ old: [CALayer], in stage: CALayer, toCentre: Bool) {
        let edge = Edge.allCases.randomElement()!
        let count = Int.random(in: 4...6)
        let strips = (0..<count).map { edge.strip($0, of: count, in: bounds) }
        let target = toCentre ? edge.centre(of: bounds) : edge.position(in: bounds)

        let pieces = strips.map { copy(of: old, clippedTo: $0) }
        pieces.forEach(stage.addSublayer)
        run(cleanup: { stage.removeFromSuperlayer() }) {
            for (number, piece) in pieces.enumerated() {
                let to = edge.moving(piece.position, to: target)
                move(piece, to: to)
                let angle = (number.isMultiple(of: 2) ? 1 : -1) * CGFloat.pi * 0.47
                swing(piece, edge: edge, from: 0, to: angle, timing: .easeIn)
                darken(piece, from: 0, to: 0.8, timing: .easeIn)
            }
        }
    }

    /// Part of the old screen turns over like a page about a line at a half
    /// or a third, revealing the new layout, and its back lands with the new
    /// layout on the other side of the line.
    private func pageFlip(from old: [CALayer], to new: [CALayer], in stage: CALayer) {
        let edge = Edge.allCases.randomElement()!
        let fraction = [0.5, 1.0 / 3, 2.0 / 3].randomElement()!
        let (near, far) = edge.split(bounds, at: fraction)

        // `near` is the side the page lands on; `far` is where it starts.
        let still = copy(of: old, clippedTo: near)
        let front = copy(of: old, clippedTo: far)
        let back = copy(of: new, clippedTo: near)
        // Both hinge on the line between the parts.
        hinge(front, at: edge)
        hinge(back, at: edge.opposite)
        [still, front, back].forEach(stage.addSublayer)

        let half = Self.transitionDuration / 2
        run(cleanup: { stage.removeFromSuperlayer() }) {
            swing(front, edge: edge, from: 0, to: edge.openAngle, duration: half, timing: .easeIn)
            darken(front, from: 0, to: 0.6, duration: half, timing: .easeIn)
            swing(back, edge: edge.opposite, from: edge.opposite.openAngle, to: 0, delay: half, duration: half, timing: .easeOut)
            darken(back, from: 0.6, to: 0, delay: half, duration: half, timing: .easeOut)
            hide(still, after: Self.transitionDuration)
        }
    }

    /// The old screen folds away in two or three panels, the one furthest
    /// from the edge first.
    private func fold(_ old: [CALayer], in stage: CALayer) {
        let edge = Edge.allCases.randomElement()!
        let count = Int.random(in: 2...3)
        let panels = (0..<count).map { edge.strip($0, of: count, in: bounds) }
        let pieces = panels.map { copy(of: old, clippedTo: $0) }
        pieces.forEach { hinge($0, at: edge) }
        pieces.forEach(stage.addSublayer)

        let step = Self.transitionDuration / Double(count + 1)
        run(cleanup: { stage.removeFromSuperlayer() }) {
            for (order, piece) in edge.farthestFirst(pieces).enumerated() {
                let delay = Double(order) * step
                swing(piece, edge: edge, from: 0, to: edge.openAngle, delay: delay, duration: step * 2, timing: .easeIn)
                darken(piece, from: 0, to: 0.8, delay: delay, duration: step * 2, timing: .easeIn)
            }
        }
    }

    // MARK: Building blocks

    /// A layer holding copies of `tiles`, clipped to `rect`. The copies share
    /// the tiles' decoded images, so they cost little.
    private func copy(of tiles: [CALayer], clippedTo rect: CGRect) -> CALayer {
        let box = CALayer()
        box.frame = rect
        box.masksToBounds = true
        // Opaque, so the gaps between panels don't show the layer beneath.
        box.backgroundColor = Self.backdrop
        smoothEdges(box)
        for tile in tiles where tile.frame.intersects(rect) {
            box.addSublayer(makeTile(frame: tile.frame.offsetBy(dx: -rect.minX, dy: -rect.minY), image: tile.contents as! CGImage))
        }
        return box
    }

    /// Rotated layers get jagged, flickering edges unless antialiased.
    private func smoothEdges(_ layer: CALayer) {
        layer.allowsEdgeAntialiasing = true
        layer.isDoubleSided = false
    }

    private func makeStage() -> CALayer {
        let stage = CALayer()
        stage.frame = bounds
        stage.sublayerTransform.m34 = -1 / (max(bounds.width, bounds.height) * 1.5)
        canvas.addSublayer(stage)
        return stage
    }

    /// Move the anchor to `edge` without moving the layer.
    private func hinge(_ layer: CALayer, at edge: Edge) {
        let frame = layer.frame
        layer.anchorPoint = edge.anchor
        layer.frame = frame
    }

    /// Run `animations` as one transaction; `cleanup` runs when all of them
    /// end. No other change starts meanwhile.
    private func run(cleanup: @escaping () -> Void, animations: () -> Void) {
        transitioning = true
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            cleanup()
            CATransaction.commit()
            self.transitioning = false
        }
        animations()
        CATransaction.commit()
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
}

// MARK: - Animation helpers

private let defaultDuration: CFTimeInterval = 1.3

/// Each helper sets the final value on the layer and adds an animation from
/// the start value, held until its delay ends.
private func animate(_ layer: CALayer, _ keyPath: String, from: Any, to: Any, delay: CFTimeInterval,
                     duration: CFTimeInterval, timing: CAMediaTimingFunctionName) {
    let animation = CABasicAnimation(keyPath: keyPath)
    animation.fromValue = from
    animation.toValue = to
    animation.beginTime = CACurrentMediaTime() + delay
    animation.duration = duration
    animation.fillMode = .backwards
    animation.timingFunction = CAMediaTimingFunction(name: timing)
    layer.setValue(to, forKeyPath: keyPath)
    layer.add(animation, forKey: keyPath)
}

private func swing(_ layer: CALayer, edge: Edge, from: CGFloat, to: CGFloat, delay: CFTimeInterval = 0,
                   duration: CFTimeInterval = defaultDuration, timing: CAMediaTimingFunctionName) {
    animate(layer, edge.rotationKey, from: from, to: to, delay: delay, duration: duration, timing: timing)

    // Under perspective a panel near edge-on still shows: a wide sliver
    // thrown past its hinge, over the layout beneath. It fades out there.
    let edgeOn = CGFloat.pi * 0.4
    if abs(to) >= edgeOn {
        fade(layer, values: [1, 1, 0], keyTimes: [0, 0.8, 1], delay: delay, duration: duration)
    } else if abs(from) >= edgeOn {
        fade(layer, values: [0, 1, 1], keyTimes: [0, 0.2, 1], delay: delay, duration: duration)
    }
}

private func fade(_ layer: CALayer, values: [Float], keyTimes: [NSNumber], delay: CFTimeInterval,
                  duration: CFTimeInterval) {
    let animation = CAKeyframeAnimation(keyPath: "opacity")
    animation.values = values
    animation.keyTimes = keyTimes
    animation.beginTime = CACurrentMediaTime() + delay
    animation.duration = duration
    animation.fillMode = .backwards
    layer.opacity = values.last!
    layer.add(animation, forKey: "fade")
}

private func move(_ layer: CALayer, to position: CGPoint) {
    animate(layer, "position", from: NSValue(point: layer.position), to: NSValue(point: position),
            delay: 0, duration: defaultDuration, timing: .easeIn)
}

/// A black overlay on `layer`, faded between the two opacities.
private func darken(_ layer: CALayer, from: Float, to: Float, delay: CFTimeInterval = 0,
                    duration: CFTimeInterval = defaultDuration, timing: CAMediaTimingFunctionName) {
    let shade = CALayer()
    shade.frame = layer.bounds
    shade.backgroundColor = CGColor(gray: 0, alpha: 1)
    layer.addSublayer(shade)
    animate(shade, "opacity", from: from, to: to, delay: delay, duration: duration, timing: timing)
}

private func hide(_ layer: CALayer, after delay: CFTimeInterval) {
    animate(layer, "opacity", from: Float(1), to: Float(0), delay: delay, duration: 0.01, timing: .linear)
}

// MARK: - Edges

/// A screen or tile edge, in the canvas's bottom-up coordinates.
private enum Edge: CaseIterable {
    case left, right, bottom, top

    var opposite: Edge {
        switch self {
        case .left: .right
        case .right: .left
        case .bottom: .top
        case .top: .bottom
        }
    }

    var isVertical: Bool { self == .left || self == .right }

    var anchor: CGPoint {
        switch self {
        case .left: CGPoint(x: 0, y: 0.5)
        case .right: CGPoint(x: 1, y: 0.5)
        case .bottom: CGPoint(x: 0.5, y: 0)
        case .top: CGPoint(x: 0.5, y: 1)
        }
    }

    /// Hinges on the left or right turn about the y axis.
    var rotationKey: String { isVertical ? "transform.rotation.y" : "transform.rotation.x" }

    /// Nearly edge-on, swung towards the viewer.
    var openAngle: CGFloat {
        switch self {
        case .left, .top: -.pi * 0.49
        case .right, .bottom: .pi * 0.49
        }
    }

    /// Strip `index` of `count`, cut across the axis this edge sits on.
    func strip(_ index: Int, of count: Int, in bounds: CGRect) -> CGRect {
        // Cut on whole points, so neighbouring strips meet without a seam.
        let length = isVertical ? bounds.width : bounds.height
        let start = (length * CGFloat(index) / CGFloat(count)).rounded()
        let end = (length * CGFloat(index + 1) / CGFloat(count)).rounded()
        if isVertical {
            return CGRect(x: start, y: 0, width: end - start, height: bounds.height)
        }
        return CGRect(x: 0, y: start, width: bounds.width, height: end - start)
    }

    /// The edge's coordinate along its axis.
    func position(in bounds: CGRect) -> CGFloat {
        switch self {
        case .left: bounds.minX
        case .right: bounds.maxX
        case .bottom: bounds.minY
        case .top: bounds.maxY
        }
    }

    func centre(of bounds: CGRect) -> CGFloat { isVertical ? bounds.midX : bounds.midY }

    func moving(_ point: CGPoint, to coordinate: CGFloat) -> CGPoint {
        isVertical ? CGPoint(x: coordinate, y: point.y) : CGPoint(x: point.x, y: coordinate)
    }

    /// `bounds` split at `fraction` from this edge: the part by the edge, and the rest.
    func split(_ bounds: CGRect, at fraction: Double) -> (near: CGRect, far: CGRect) {
        let length = ((isVertical ? bounds.width : bounds.height) * fraction).rounded()
        let edge: CGRectEdge = switch self {
        case .left: .minXEdge
        case .right: .maxXEdge
        case .bottom: .minYEdge
        case .top: .maxYEdge
        }
        let parts = bounds.divided(atDistance: length, from: edge)
        return (parts.slice, parts.remainder)
    }

    func farthestFirst(_ layers: [CALayer]) -> [CALayer] {
        layers.sorted { distance(of: $0) > distance(of: $1) }
    }

    private func distance(of layer: CALayer) -> CGFloat {
        let frame = layer.frame
        switch self {
        case .left: return frame.midX
        case .right: return -frame.midX
        case .bottom: return frame.midY
        case .top: return -frame.midY
        }
    }
}
