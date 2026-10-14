import AppKit

/// The sheet behind the Options button in Screen Saver settings.
final class OptionsSheet: NSObject {
    /// System Settings can drop the view that made the sheet while it is
    /// open, so the open sheet keeps itself alive here until Done.
    private static var open: OptionsSheet?

    let window: NSWindow
    private let popup = NSPopUpButton()
    private let generated = NSButton(checkboxWithTitle: "Include Steam's generated covers", target: nil, action: nil)
    private let onDone: () -> Void

    init(onDone: @escaping () -> Void) {
        self.onDone = onDone
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 340, height: 140),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        super.init()

        popup.addItems(withTitles: DisplayMode.allCases.map(\.title))
        popup.selectItem(at: DisplayMode.allCases.firstIndex(of: Preferences.mode) ?? 0)
        generated.state = Preferences.includeGenerated ? .on : .off

        let grid = NSGridView(views: [
            [NSTextField(labelWithString: "Display:"), popup],
            [NSGridCell.emptyContentView, generated],
        ])
        grid.rowAlignment = .firstBaseline
        grid.column(at: 0).xPlacement = .trailing
        grid.columnSpacing = 8
        grid.rowSpacing = 12

        let done = NSButton(title: "Done", target: self, action: #selector(finish))
        done.keyEquivalent = "\r"

        let stack = NSStackView(views: [grid, done])
        stack.orientation = .vertical
        stack.alignment = .trailing
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = stack
        Self.open = self
    }

    @objc private func finish() {
        Preferences.mode = DisplayMode.allCases[max(popup.indexOfSelectedItem, 0)]
        Preferences.includeGenerated = generated.state == .on
        if let parent = window.sheetParent {
            parent.endSheet(window)
        } else {
            window.orderOut(nil)
        }
        onDone()
        Self.open = nil
    }
}
