import SwiftUI

enum BrightnessPalette {
    static let window = Color(red: 0.12, green: 0.13, blue: 0.13)
    static let panel = Color(red: 0.14, green: 0.15, blue: 0.15)
    static let text = Color(red: 0.95, green: 0.93, blue: 0.9)
    static let secondary = Color(red: 0.79, green: 0.77, blue: 0.73)
    static let warmText = Color(red: 1, green: 0.94, blue: 0.84)
    static let amber = Color(red: 0.96, green: 0.75, blue: 0.49)
    static let connected = Color(red: 0.61, green: 0.78, blue: 0.66)
    static let border = Color.white.opacity(0.1)
    static let panelRadius: CGFloat = 15
}

struct BrightnessHalo: View {
    let intensity: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let radius = min(width * 0.42, 175)

            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.18, green: 0.15, blue: 0.13), BrightnessPalette.window],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: [BrightnessPalette.amber.opacity(0.58), .clear],
                    center: UnitPoint(x: 1.02, y: 0.07),
                    startRadius: 0,
                    endRadius: width * 0.82
                )
                .opacity(intensity)

                ForEach(0..<3) { ring in
                    let diameter = 2 * radius + CGFloat(ring * 20)
                    Circle()
                        .strokeBorder(BrightnessPalette.amber.opacity(intensity * 0.2), lineWidth: 1)
                        .frame(width: diameter, height: diameter)
                        .position(x: width - 27, y: 8)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: intensity)
        .accessibilityHidden(true)
    }
}

struct MonitorThumbnail: View {
    let intensity: Double
    let warm: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black.opacity(0.47))
                .overlay {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                        .overlay {
                            LinearGradient(
                                colors: warm
                                    ? [BrightnessPalette.amber, Color(red: 0.29, green: 0.21, blue: 0.3)]
                                    : [Color(red: 0.64, green: 0.83, blue: 0.83),
                                       Color(red: 0.26, green: 0.35, blue: 0.52)],
                                startPoint: warm ? .bottomLeading : .topTrailing,
                                endPoint: warm ? .topTrailing : .bottomLeading
                            )
                            .opacity(intensity)
                            .clipShape(RoundedRectangle(cornerRadius: 2))
                        }
                        .padding(3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(BrightnessPalette.secondary.opacity(0.62))
                }
                .frame(width: 48, height: 29)

            Rectangle()
                .fill(BrightnessPalette.secondary.opacity(0.6))
                .frame(width: 3, height: 4)
            Capsule()
                .fill(BrightnessPalette.secondary.opacity(0.6))
                .frame(width: 14, height: 1.5)
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
        let tint = warm ? BrightnessPalette.amber : .white

        configuration.label
            .padding(.horizontal, 10)
            .background(tint.opacity(configuration.isPressed ? 0.19 : 0.075), in: shape)
            .overlay { shape.strokeBorder(tint.opacity(warm ? 0.3 : 0.14)) }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.4)
    }
}
