import Cocoa

/// A tab button that distinguishes a click from a drag and always accepts its
/// context-menu click while Host is in the background.
final class TabButton: NSButton {
    var bundleIdentifier = ""
    var tabName = ""
    var tabIcon: NSImage?
    var workspaceIndex: Int?
    var showsLabel = false
    var onDragMoved: ((TabButton, CGPoint) -> Void)?
    var onDragEnded: ((TabButton) -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu else {
            super.rightMouseDown(with: event)
            return
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func mouseDown(with event: NSEvent) {
        let start = event.locationInWindow
        var dragging = false

        while let next = NSApp.nextEvent(matching: [.leftMouseDragged, .leftMouseUp],
                                         until: .distantFuture,
                                         inMode: .eventTracking, dequeue: true) {
            if next.type == .leftMouseUp { break }
            // A few points of slop, so a slightly unsteady click is still a click.
            if !dragging && abs(next.locationInWindow.x - start.x) > 4 { dragging = true }
            if dragging, let parent = superview {
                onDragMoved?(self, parent.convert(next.locationInWindow, from: nil))
            }
        }

        if dragging {
            onDragEnded?(self)
        } else if let action, let target {
            sendAction(action, to: target)
        }
    }
}
