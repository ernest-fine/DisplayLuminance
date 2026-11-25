import Foundation

enum M1DDCError: LocalizedError {
    case notInstalled
    case invalidLuminance(Int)
    case commandFailed(String)
    case noDisplays

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Bundled m1ddc is missing from the app. Rebuild the project in Xcode."
        case .invalidLuminance(let value):
            return "Luminance must be between 0 and 100 (got \(value))."
        case .commandFailed(let message):
            return message
        case .noDisplays:
            return "No external DDC-capable displays were found."
        }
    }
}

struct DisplayInfo: Identifiable, Hashable {
    let index: Int
    let label: String

    var id: Int { index }
}

final class M1DDCService {
    static let shared = M1DDCService()

    private(set) var executablePath: String?

    init() {
        executablePath = Self.resolveExecutablePath()
    }

    /// Bundled at `Contents/Resources/m1ddc` by the "Bundle m1ddc" build phase.
    private static func resolveExecutablePath() -> String? {
        guard let bundled = Bundle.main.url(forResource: "m1ddc", withExtension: nil)?.path else {
            return nil
        }
        guard FileManager.default.isExecutableFile(atPath: bundled) else {
            return nil
        }
        return bundled
    }

    func refreshExecutablePath() {
        executablePath = Self.resolveExecutablePath()
    }

    @discardableResult
    func run(arguments: [String]) throws -> String {
        guard let executablePath else {
            throw M1DDCError.notInstalled
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let errorOutput = String(data: errData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard process.terminationStatus == 0 else {
            let message = [errorOutput, output]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            if message.isEmpty {
                throw M1DDCError.commandFailed("m1ddc failed (exit \(process.terminationStatus)).")
            }
            throw M1DDCError.commandFailed(message)
        }

        return output
    }

    func listDisplays() throws -> [DisplayInfo] {
        let output: String
        do {
            output = try run(arguments: ["display", "list"])
        } catch {
            let probed = probeDisplays()
            if probed.isEmpty {
                throw error
            }
            return probed
        }

        let parsed = Self.parseDisplayList(output)
        if !parsed.isEmpty {
            return parsed
        }

        let probed = probeDisplays()
        if probed.isEmpty {
            throw M1DDCError.noDisplays
        }
        return probed
    }

    /// m1ddc prints lines like: `[1] LG ULTRAWIDE (UUID)`
    private static func parseDisplayList(_ output: String) -> [DisplayInfo] {
        var displays: [DisplayInfo] = []
        let lines = output.split(whereSeparator: \.isNewline)

        for lineSub in lines {
            let line = String(lineSub)
            guard let index = parseDisplayIndex(from: line) else { continue }
            let label = parseDisplayLabel(from: line, index: index)
            if !displays.contains(where: { $0.index == index }) {
                displays.append(DisplayInfo(index: index, label: label))
            }
        }

        return displays.sorted { $0.index < $1.index }
    }

    /// Probe display indices 1…max by running a lightweight m1ddc command on each.
    private func probeDisplays(maxIndex: Int = 8) -> [DisplayInfo] {
        var displays: [DisplayInfo] = []
        for index in 1 ... maxIndex {
            let ok = (try? run(arguments: ["display", "\(index)", "max", "luminance"])) != nil
            if ok {
                displays.append(DisplayInfo(index: index, label: "Display \(index)"))
            }
        }
        return displays
    }

    func setLuminance(_ value: Int, forDisplayIndex index: Int) throws {
        try setLuminance(value, on: [index])
    }

    func setLuminance(_ value: Int, onAllDisplays: Bool = true) throws {
        let displays = try listDisplays()
        guard !displays.isEmpty else {
            throw M1DDCError.noDisplays
        }
        let indices = onAllDisplays ? displays.map(\.index) : [displays[0].index]
        try setLuminance(value, on: indices)
    }

    func setLuminance(_ value: Int, on displayIndices: [Int]) throws {
        guard (0 ... 100).contains(value) else {
            throw M1DDCError.invalidLuminance(value)
        }
        guard !displayIndices.isEmpty else {
            throw M1DDCError.noDisplays
        }

        var failures: [String] = []
        var successCount = 0

        for index in displayIndices {
            let writeValue = try ddcWriteValue(forPercent: value, displayIndex: index)
            let args = ["display", "\(index)", "set", "luminance", "\(writeValue)"]
            do {
                _ = try run(arguments: args)
                successCount += 1
            } catch {
                failures.append("Display \(index): \(error.localizedDescription)")
            }
        }

        if successCount == 0 {
            if failures.isEmpty {
                throw M1DDCError.noDisplays
            }
            throw M1DDCError.commandFailed(failures.joined(separator: "\n"))
        }

        if !failures.isEmpty {
            throw M1DDCError.commandFailed(failures.joined(separator: "\n"))
        }
    }

    /// Read-only brightness query. Never uses `chg` — m1ddc `chg` always writes to the display.
    func getLuminance(for displayIndex: Int) throws -> Int? {
        let maxValue = fetchMaxLuminance(displayIndex: displayIndex)
        guard let raw = try readRawLuminance(displayIndex: displayIndex, command: "get") else {
            return nil
        }
        return normalizeLuminancePercent(raw, maxValue: maxValue)
    }

    private func fetchMaxLuminance(displayIndex: Int) -> Int? {
        guard
            let maxOutput = try? run(arguments: ["display", "\(displayIndex)", "max", "luminance"]),
            let maxValue = parseNumericOutput(maxOutput),
            maxValue > 0
        else { return nil }
        return maxValue
    }

    private func ddcWriteValue(forPercent percent: Int, displayIndex: Int) throws -> Int {
        let clamped = min(100, max(0, percent))
        guard let maxValue = fetchMaxLuminance(displayIndex: displayIndex), maxValue > 100 else {
            return clamped
        }
        return min(maxValue, max(0, Int((Double(clamped) * Double(maxValue) / 100.0).rounded())))
    }

    private func readRawLuminance(displayIndex: Int, command: String, change: String? = nil) throws -> Int? {
        var args = ["display", "\(displayIndex)", command, "luminance"]
        if let change {
            args.append(change)
        }
        let output = try run(arguments: args)
        return parseNumericOutput(output)
    }

    private func normalizeLuminancePercent(_ raw: Int, maxValue: Int?) -> Int? {
        if let maxValue, maxValue > 0 {
            if maxValue <= 100, raw > maxValue {
                return nil
            }
            if maxValue <= 100, raw <= 100 {
                return min(100, max(0, raw))
            }
            let percent = Int((Double(raw) * 100.0 / Double(maxValue)).rounded())
            return min(100, max(0, percent))
        }

        if raw <= 100 {
            return raw
        }
        if raw <= 255 {
            return min(100, max(0, Int((Double(raw) * 100.0 / 255.0).rounded())))
        }
        return nil
    }

    private func parseNumericOutput(_ output: String) -> Int? {
        for line in output.split(whereSeparator: \.isNewline).reversed() {
            let trimmed = String(line).trimmingCharacters(in: .whitespaces)
            if let value = Int(trimmed) {
                return value
            }
        }
        return nil
    }

    private static func parseDisplayIndex(from line: String) -> Int? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // m1ddc format: [1] Product Name (uuid)
        if let match = trimmed.firstMatch(of: /^\[(\d+)\]/) {
            return Int(match.1)
        }
        return nil
    }

    private static func parseDisplayLabel(from line: String, index: Int) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        // Strip "[n] " prefix and trailing " (uuid)"
        guard let bracketEnd = trimmed.firstIndex(of: "]") else {
            return "Display \(index)"
        }
        var label = String(trimmed[trimmed.index(after: bracketEnd)...])
            .trimmingCharacters(in: .whitespaces)
        if let openParen = label.lastIndex(of: "("),
           label.hasSuffix(")"),
           openParen > label.startIndex
        {
            label = String(label[..<openParen]).trimmingCharacters(in: .whitespaces)
        }
        if label.isEmpty {
            return "Display \(index)"
        }
        return label
    }
}
