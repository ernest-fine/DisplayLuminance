import SwiftUI

private enum AppAppearance: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

@main
struct DisplayLuminanceApp: App {
    @StateObject private var viewModel = DisplayLuminanceViewModel()
    @AppStorage("appAppearance") private var appearance = AppAppearance.dark

    var body: some Scene {
        Window("Display Luminance", id: "brightness") {
            ContentView(viewModel: viewModel)
                .preferredColorScheme(appearance.colorScheme)
        }
        .defaultSize(width: 860, height: 410)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppAppearance.allCases, id: \.self) { option in
                        Text(option.rawValue.capitalized)
                            .tag(option)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }
}
