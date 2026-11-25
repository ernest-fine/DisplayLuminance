import SwiftUI

@main
struct DisplayLuminanceApp: App {
    @StateObject private var viewModel = DisplayLuminanceViewModel()

    var body: some Scene {
        Window("Display Luminance", id: "brightness") {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 860, height: 410)
        .windowResizability(.contentMinSize)
    }
}
