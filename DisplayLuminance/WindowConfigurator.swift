import AppKit
import SwiftUI

enum WindowMetrics {
    static let contentWidth: CGFloat = 480
    static let contentHeight: CGFloat = 580
}

enum WindowFullscreenDisabler {
    private static var configuredWindows = NSHashTable<NSWindow>.weakObjects()

    static func apply(to window: NSWindow) {
        guard configuredWindows.contains(window) == false else {
            refresh(window)
            return
        }

        configuredWindows.add(window)
        refresh(window)

        if window.delegate == nil {
            window.delegate = WindowDelegate.shared
        } else if window.delegate !== WindowDelegate.shared {
            window.delegate = WindowDelegate.shared
        }
    }

    static func applyToAllWindows() {
        for window in NSApplication.shared.windows {
            apply(to: window)
        }
    }

    private static func refresh(_ window: NSWindow) {
        var behavior = window.collectionBehavior
        behavior.remove([.fullScreenPrimary, .fullScreenAuxiliary, .fullScreenAllowsTiling])
        behavior.insert(.fullScreenNone)
        window.collectionBehavior = behavior

        if !window.styleMask.contains(.fullScreen) {
            window.styleMask.remove(.resizable)
        }

        let fixedSize = NSSize(width: WindowMetrics.contentWidth, height: WindowMetrics.contentHeight)
        window.contentMinSize = fixedSize
        window.contentMaxSize = fixedSize
        window.setContentSize(fixedSize)

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.isEnabled = false
            zoomButton.isHidden = true
        }
    }

    static func disableFullScreenMenuItems() {
        guard let viewMenu = NSApp.mainMenu?.items
            .first(where: { $0.title == "View" })?
            .submenu
        else { return }

        for item in viewMenu.items {
            if item.action == #selector(NSWindow.toggleFullScreen(_:)) {
                item.isHidden = true
                item.isEnabled = false
            }
        }
    }
}

private final class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()

    func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        WindowFullscreenDisabler.apply(to: window)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        sender.frame.size
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let window = note.object as? NSWindow else { return }
            WindowFullscreenDisabler.apply(to: window)
        }

        DispatchQueue.main.async {
            WindowFullscreenDisabler.disableFullScreenMenuItems()
            WindowFullscreenDisabler.applyToAllWindows()
        }
    }
}

/// Disables macOS fullscreen for the app's main window.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowDisablingView {
        WindowDisablingView()
    }

    func updateNSView(_ nsView: WindowDisablingView, context: Context) {
        nsView.attachToWindowIfNeeded()
    }
}

final class WindowDisablingView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        attachToWindowIfNeeded()
    }

    func attachToWindowIfNeeded() {
        guard let window else { return }
        WindowFullscreenDisabler.apply(to: window)
    }
}
