import Combine
import Foundation

enum BrightnessDirection: CaseIterable {
    case lower
    case raise

    func destination(from level: Int) -> Int {
        switch self {
        case .lower:
            return max(0, (level - 1) / 10 * 10)
        case .raise:
            return min(100, (level / 10 + 1) * 10)
        }
    }
}

struct BrightnessWriteFailure {
    let destination: Int
    let message: String
}

struct DisplayBrightness: Identifiable {
    let display: DisplayInfo
    let level: Int?
    var failure: BrightnessWriteFailure?

    var id: Int { display.id }
    var screenIntensity: Double { Double(level ?? 0) / 100 }
}

struct BrightnessSummary {
    let lowest: Int
    let highest: Int
    let intensity: Double

    init?(levels: [Int]) {
        guard let lowest = levels.min(), let highest = levels.max() else { return nil }
        self.lowest = lowest
        self.highest = highest
        intensity = Double(levels.reduce(0, +)) / Double(levels.count * 100)
    }
}

protocol BrightnessHardware: Sendable {
    func readDisplays() async throws -> [DisplayBrightness]
    func setBrightness(
        _ level: Int,
        on targets: [DisplayInfo],
        matching expectedDisplays: [DisplayInfo]
    ) async throws -> [DisplayBrightness]
}

/// Keeps the existing synchronous DDC calls off the main actor and serializes hardware access.
actor DDCBrightnessHardware: BrightnessHardware {
    private let service = M1DDCService()

    func readDisplays() throws -> [DisplayBrightness] {
        service.refreshExecutablePath()
        return try service.listDisplays().map { display in
            DisplayBrightness(display: display, level: readLevel(for: display))
        }
    }

    func setBrightness(
        _ level: Int,
        on targets: [DisplayInfo],
        matching expectedDisplays: [DisplayInfo]
    ) throws -> [DisplayBrightness] {
        // m1ddc identifies displays by their position in the list, which can change on reconnect.
        guard try service.listDisplays() == expectedDisplays else {
            throw M1DDCError.commandFailed("The connected displays changed. Refresh the list and try again.")
        }

        return targets.map { display in
            do {
                try service.setLuminance(level, forDisplayIndex: display.index)
                return DisplayBrightness(display: display, level: level)
            } catch {
                return DisplayBrightness(
                    display: display,
                    level: readLevel(for: display),
                    failure: BrightnessWriteFailure(destination: level, message: error.localizedDescription)
                )
            }
        }
    }

    private func readLevel(for display: DisplayInfo) -> Int? {
        guard let level = try? service.getLuminance(for: display.index),
              (0...100).contains(level) else { return nil }
        return level
    }
}

@MainActor
final class DisplayLuminanceViewModel: ObservableObject {
    enum Activity {
        case refreshing
        case adjusting
    }

    @Published private(set) var displays: [DisplayBrightness] = []
    @Published private(set) var activity: Activity?
    @Published private(set) var errorMessage: String?

    private let hardware: any BrightnessHardware

    init(hardware: any BrightnessHardware = DDCBrightnessHardware()) {
        self.hardware = hardware
    }

    var isBusy: Bool { activity != nil }
    var hasUnknownLevels: Bool { displays.contains { $0.level == nil } }
    var summary: BrightnessSummary? { BrightnessSummary(levels: displays.compactMap(\.level)) }

    func groupDestination(_ direction: BrightnessDirection) -> Int? {
        guard !hasUnknownLevels, let summary else { return nil }
        // Step past the relevant edge of a mixed range so every display moves in the chosen direction.
        return direction.destination(from: direction == .lower ? summary.lowest : summary.highest)
    }

    func canSetGroup(to destination: Int) -> Bool {
        !isBusy && displays.contains { $0.level != destination }
    }

    func refresh() async {
        guard !isBusy else { return }
        activity = .refreshing
        errorMessage = nil
        defer { activity = nil }

        do {
            displays = try await hardware.readDisplays()
        } catch M1DDCError.noDisplays {
            displays = []
        } catch {
            displays = []
            errorMessage = error.localizedDescription
        }
    }

    func adjustAll(_ direction: BrightnessDirection) async {
        guard let destination = groupDestination(direction), canSetGroup(to: destination) else { return }
        await setBrightness(destination, on: displays.map(\.display))
    }

    func adjust(_ direction: BrightnessDirection, on display: DisplayInfo) async {
        guard let level = displays.first(where: { $0.display == display })?.level else { return }
        let destination = direction.destination(from: level)
        guard destination != level else { return }
        await setBrightness(destination, on: [display])
    }

    func retry(_ display: DisplayInfo) async {
        guard let failure = displays.first(where: { $0.display == display })?.failure else { return }
        await setBrightness(failure.destination, on: [display])
    }

    private func setBrightness(_ level: Int, on targets: [DisplayInfo]) async {
        guard !isBusy else { return }
        activity = .adjusting
        errorMessage = nil
        defer { activity = nil }

        do {
            let results = try await hardware.setBrightness(level, on: targets, matching: displays.map(\.display))
            let updates = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
            displays = displays.map { updates[$0.id] ?? $0 }
        } catch {
            displays = []
            errorMessage = error.localizedDescription
        }
    }
}
