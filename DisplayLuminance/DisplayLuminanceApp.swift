import SwiftUI

@main
struct DisplayLuminanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .defaultSize(width: WindowMetrics.contentWidth, height: WindowMetrics.contentHeight)
        .windowResizability(.contentSize)
    }
}
