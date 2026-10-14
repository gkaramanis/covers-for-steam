import AppKit

/// The sheet behind the Options button in Screen Saver settings.
final class OptionsSheet: NSObject {
    let window: NSWindow
    private let popup = NSPopUpButton()
    private let onDone: (DisplayMode) -> Void

    init(current: DisplayMode, onDone: @escaping (DisplayMode) -> Void) {
        self.onDone = onDone
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 110),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        super.init()

        popup.addItems(withTitles: DisplayMode.allCases.map(\.title))
        popup.selectItem(at: DisplayMode.allCases.firstIndex(of: current) ?? 0)

        let label = NSTextField(labelWithString: "Display:")
        let row = NSStackView(views: [label, popup])
        row.spacing = 8

        let done = NSButton(title: "Done", target: self, action: #selector(finish))
        done.keyEquivalent = "\r"

        let stack = NSStackView(views: [row, done])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = stack
    }

    @objc private func finish() {
        let mode = DisplayMode.allCases[max(popup.indexOfSelectedItem, 0)]
        DisplayMode.saved = mode
        window.sheetParent?.endSheet(window)
        onDone(mode)
    }
}
