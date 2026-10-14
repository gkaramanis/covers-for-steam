import QuartzCore

extension CoversView {
    /// One full-height cover on a random side, and columns of two covers
    /// filling the rest. Every panel is close to 2:3.
    func origamiFrames() -> [CGRect] {
        let gap: CGFloat = isPreview ? 2 : 8
        let height = bounds.height
        let bigWidth = (height * 2 / 3).rounded()
        let rest = bounds.width - bigWidth - gap
        let columns = max(1, Int((rest / (height / 3)).rounded()))
        let columnWidth = (rest - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let halfHeight = (height - gap) / 2

        let bigOnLeft = Bool.random()
        let big = CGRect(x: bigOnLeft ? 0 : bounds.width - bigWidth, y: 0, width: bigWidth, height: height)
        let x0 = bigOnLeft ? bigWidth + gap : 0

        let small = (0..<columns).flatMap { column in
            let x = x0 + CGFloat(column) * (columnWidth + gap)
            return [
                CGRect(x: x, y: 0, width: columnWidth, height: halfHeight),
                CGRect(x: x, y: halfHeight + gap, width: columnWidth, height: halfHeight),
            ]
        }
        return [big] + small
    }

    /// Unfold `image` over `panel`: two halves hinged at the panel's outer
    /// edges swing flat and meet at the centre crease.
    func fold(_ image: CGImage, into panel: CALayer) {
        let size = panel.bounds.size
        let crop = fillRect(image: image, in: size)
        let duration: CFTimeInterval = 1.4

        let stage = CALayer()
        stage.frame = panel.frame
        stage.sublayerTransform.m34 = -1 / (size.width * 3)
        canvas.addSublayer(stage)

        // Swap the panel's image and drop the halves once both have landed.
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            panel.contents = image
            stage.removeFromSuperlayer()
            CATransaction.commit()
        }
        defer { CATransaction.commit() }

        for side in [0, 1] {
            let left = side == 0
            let half = CALayer()
            half.bounds = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)
            half.anchorPoint = CGPoint(x: left ? 0 : 1, y: 0.5)
            half.position = CGPoint(x: left ? 0 : size.width, y: size.height / 2)
            half.contents = image
            half.contentsGravity = .resize
            half.contentsRect = CGRect(
                x: crop.minX + (left ? 0 : crop.width / 2),
                y: crop.minY,
                width: crop.width / 2,
                height: crop.height
            )
            half.masksToBounds = true

            let shade = CALayer()
            shade.frame = half.bounds
            shade.backgroundColor = CGColor(gray: 0, alpha: 1)
            shade.opacity = 0
            half.addSublayer(shade)
            stage.addSublayer(half)

            let swing = CABasicAnimation(keyPath: "transform.rotation.y")
            swing.fromValue = (left ? 1 : -1) * CGFloat.pi * 0.49
            swing.toValue = 0
            swing.duration = duration
            swing.timingFunction = CAMediaTimingFunction(name: .easeOut)
            half.add(swing, forKey: "swing")

            let darken = CABasicAnimation(keyPath: "opacity")
            darken.fromValue = 0.7
            darken.toValue = 0
            darken.duration = duration
            darken.timingFunction = CAMediaTimingFunction(name: .easeIn)
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
