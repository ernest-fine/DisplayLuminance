import AppKit
import ColorSync
import CoreGraphics
import SwiftUI

enum BrightnessPalette {
    static let window = adaptive(light: 0xF6F4EF, dark: 0x1F2121)
    static let panel = adaptive(light: 0xFFFDFA, dark: 0x242626)
    static let text = adaptive(light: 0x2C2925, dark: 0xF2EDE6)
    static let secondary = adaptive(light: 0x605A51, dark: 0xC9C4BA)
    static let warmText = adaptive(light: 0x56351A, dark: 0xFFF0D6)
    static let amber = adaptive(light: 0x8C4D16, dark: 0xF5BF7D)
    static let connected = adaptive(light: 0x3B7454, dark: 0x9CC7A8)
    static let warmSurface = adaptive(light: 0xFFF7E8, dark: 0x2E2621)
    static let spillLight = adaptive(light: 0xED923E, dark: 0xFFC679)
    static let coolSpillLight = adaptive(light: 0x468CCC, dark: 0x91CFFF)
    static let spillBezel = adaptive(light: 0x645D57, dark: 0x393632)
    static let controlTint = adaptive(light: 0x413C36, dark: 0xFFFFFF)
    static let border = controlTint.opacity(0.1)
    static let panelRadius: CGFloat = 15

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let rgb = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(
                srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255,
                green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}

enum DisplayArrangement {
    struct Placement: Identifiable {
        let display: DisplayBrightness
        let frame: CGRect

        var id: Int { display.id }
    }

    static func onlineBounds() -> [UUID: CGRect] {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success, count > 0 else { return [:] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return [:] }

        var bounds: [UUID: CGRect] = [:]
        for id in ids.prefix(Int(count)) {
            guard let displayUUID = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
                  let uuid = UUID(uuidString: CFUUIDCreateString(nil, displayUUID) as String) else { continue }
            let frame = CGDisplayBounds(id)
            if !frame.isEmpty {
                bounds[uuid] = frame
            }
        }
        return bounds
    }

    static func placements(
        for displays: [DisplayBrightness], using bounds: [UUID: CGRect], in viewport: CGSize
    ) -> [Placement]? {
        let frames = displays.compactMap { $0.display.systemUUID.flatMap { bounds[$0] } }
        guard frames.count == displays.count, !frames.isEmpty else { return nil }
        let overlaps = frames.enumerated().contains { index, frame in
            frames.prefix(index).contains { !$0.intersection(frame).isEmpty }
        }
        guard !overlaps else { return nil }

        let singleDisplay = frames.count == 1
        let minWidth = frames.map(\.width).min() ?? 0
        let minHeight = frames.map(\.height).min() ?? 0
        let artworkFrames = frames.map { frame in
            // Cap the overlap by the smallest monitor so a large screen cannot hide a smaller one.
            let outset = singleDisplay ? 0 : 0.14 * min(minWidth / frame.width, minHeight / frame.height)
            return frame.insetBy(dx: -frame.width * outset, dy: -frame.height * outset)
        }
        let footprint = artworkFrames.reduce(CGRect.null) { $0.union($1) }
        let availableWidth = singleDisplay ? min(144, viewport.width) : viewport.width
        let scale = min(availableWidth / footprint.width, (viewport.height - 14) / footprint.height)
        guard scale > 0 else { return nil }

        let offsetX = (viewport.width - footprint.width * scale) / 2
        let offsetY = (viewport.height - footprint.height * scale) / 2
        let artworkScale = singleDisplay ? scale * 0.9 : scale
        return zip(displays, artworkFrames).map { display, frame in
            // Core Graphics and SwiftUI both measure down from the top of this layout.
            let centerX = offsetX + (frame.midX - footprint.minX) * scale
            let centerY = offsetY + (frame.midY - footprint.minY) * scale
            let width = frame.width * artworkScale
            let height = frame.height * artworkScale
            return Placement(
                display: display,
                frame: CGRect(x: centerX - width / 2, y: centerY - height / 2, width: width, height: height)
            )
        }
    }
}

struct ScreenSpill: View {
    let displays: [DisplayBrightness]
    let displayBounds: [UUID: CGRect]

    var body: some View {
        GeometryReader { geometry in
            if let placements = DisplayArrangement.placements(for: displays, using: displayBounds, in: geometry.size) {
                ZStack {
                    ForEach(placements) { placement in
                        SpillGlow(display: placement.display, size: placement.frame.size)
                            .position(x: placement.frame.midX, y: placement.frame.midY)
                    }
                    ForEach(placements) { placement in
                        SpillScreen(display: placement.display, size: placement.frame.size)
                            .position(x: placement.frame.midX, y: placement.frame.midY)
                    }
                }
            } else {
                fallbackGrid(in: geometry.size)
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func fallbackGrid(in size: CGSize) -> some View {
        let count = max(1, displays.count)
        let preferredColumns = max(3, Int(Double(count).squareRoot().rounded(.up)))
        let columns = count == 4 ? 2 : min(count, preferredColumns)
        let rows = (count + columns - 1) / columns
        let spacing = min(10, size.width / CGFloat(columns * 6), size.height / CGFloat(rows * 6))
        let availableWidth = size.width - CGFloat(columns - 1) * spacing
        let availableHeight = size.height - CGFloat(rows - 1) * spacing
        let standard = MonitorThumbnail.standardScreenSize
        let width = min(128, availableWidth / CGFloat(columns), availableHeight / CGFloat(rows) * standard.width / (standard.height + 5.5))
        let screenSize = CGSize(width: width, height: width * standard.height / standard.width)

        return VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                let start = row * columns
                let end = min(start + columns, displays.count)
                HStack(spacing: spacing) {
                    ForEach(displays[start..<end]) { display in
                        ZStack {
                            SpillGlow(display: display, size: screenSize)
                            SpillScreen(display: display, size: screenSize)
                        }
                        .frame(height: width / standard.width * (standard.height + 5.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SpillGlow: View {
    let display: DisplayBrightness
    let size: CGSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let intensity = display.screenIntensity
        let energy = pow(intensity, 0.8)
        let spread = 0.55 + 0.45 * energy
        let light = display.usesWarmTint ? BrightnessPalette.spillLight : BrightnessPalette.coolSpillLight
        let blurScale = min(size.width, size.height)

        ZStack {
            RoundedRectangle(cornerRadius: blurScale * 0.4)
                .fill(light)
                .frame(width: size.width * 1.32, height: size.height * 1.04)
                .blur(radius: blurScale * 0.31)
                .scaleEffect(spread)
                .offset(y: -size.height * 0.1)
                .opacity(0.74 * energy)

            Ellipse()
                .fill(light)
                .frame(width: size.width * 1.36, height: size.height * 0.36)
                .blur(radius: blurScale * 0.15)
                .scaleEffect(x: spread, y: 1)
                .offset(y: size.height * 0.55)
                .opacity(0.82 * energy)
        }
        .frame(width: size.width, height: size.height)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: intensity)
    }
}

private struct SpillScreen: View {
    let display: DisplayBrightness
    let size: CGSize

    var body: some View {
        MonitorThumbnail(
            intensity: pow(display.screenIntensity, 0.8),
            warm: display.usesWarmTint,
            screenSize: size,
            bezel: BrightnessPalette.spillBezel
        )
        .frame(width: size.width, height: size.height, alignment: .top)
    }
}

struct MonitorThumbnail: View {
    static let standardScreenSize = CGSize(width: 56, height: 34)

    let intensity: Double
    let warm: Bool
    var screenSize = MonitorThumbnail.standardScreenSize
    var bezel = Color.black.opacity(0.47)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let scale = min(screenSize.width / Self.standardScreenSize.width, screenSize.height / Self.standardScreenSize.height)
        let highlight = warm
            ? Color(red: 1, green: 0.97, blue: 0.85)
            : Color(red: 0.89, green: 0.98, blue: 1)
        let tint = warm
            ? Color(red: 1, green: 0.65, blue: 0.29)
            : Color(red: 0.45, green: 0.74, blue: 1)

        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4 * scale)
                .fill(bezel)
                .overlay {
                    RoundedRectangle(cornerRadius: 2 * scale)
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                        .overlay {
                            LinearGradient(
                                colors: [highlight, tint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(intensity)
                            .clipShape(RoundedRectangle(cornerRadius: 2 * scale))
                        }
                        .padding(3 * scale)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4 * scale)
                        .strokeBorder(BrightnessPalette.secondary.opacity(0.62), lineWidth: scale)
                }
                .frame(width: screenSize.width, height: screenSize.height)
                .shadow(color: tint.opacity(0.45 * intensity), radius: 5 * intensity * scale)

            Rectangle()
                .fill(BrightnessPalette.secondary.opacity(0.6))
                .frame(width: 3 * scale, height: 4 * scale)
            Capsule()
                .fill(BrightnessPalette.secondary.opacity(0.6))
                .frame(width: 14 * scale, height: 1.5 * scale)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: intensity)
        .accessibilityHidden(true)
    }
}

struct BrightnessButtonStyle: ButtonStyle {
    var warm = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8)
        let tint = warm ? BrightnessPalette.amber : BrightnessPalette.controlTint

        configuration.label
            .padding(.horizontal, 10)
            .background(tint.opacity(configuration.isPressed ? 0.19 : 0.075), in: shape)
            .overlay { shape.strokeBorder(tint.opacity(warm ? 0.3 : 0.14)) }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
