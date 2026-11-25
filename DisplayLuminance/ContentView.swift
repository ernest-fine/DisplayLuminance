import SwiftUI

enum LuminanceStep {
    static let increment = 10

    static func snap(_ value: Int) -> Int {
        min(100, max(0, ((value + increment / 2) / increment) * increment))
    }
}

enum M1DDCBuildMode {
    static var label: String {
        #if DEBUG
        "debug"
        #else
        "production"
        #endif
    }
}

enum BrightnessControlMode: String, CaseIterable, Identifiable {
    case allDisplays = "All displays"
    case individual = "Per display"

    var id: String { rawValue }
}

@MainActor
final class DisplayLuminanceViewModel: ObservableObject {
    @Published var luminanceText = "50"
    @Published var displays: [DisplayInfo] = []
    @Published var statusMessage = ""
    @Published var isError = false
    @Published var isBusy = false
    @Published var m1ddcReady = false
    @Published var controlMode: BrightnessControlMode = .allDisplays
    @Published var selectedDisplayIndex = 1

    private let service = M1DDCService.shared
    private var hasLoadedInitialLuminance = false
    private var lastAppliedLuminance: [Int: Int] = [:]

    var selectedDisplay: DisplayInfo? {
        displays.first { $0.index == selectedDisplayIndex }
    }

    var applyButtonTitle: String {
        controlMode == .allDisplays ? "Apply to All Displays" : "Apply to Display"
    }

    func onAppear() {
        refresh()
    }

    func refresh() {
        service.refreshExecutablePath()
        m1ddcReady = service.executablePath != nil

        guard m1ddcReady else {
            displays = []
            statusMessage = M1DDCError.notInstalled.localizedDescription
            isError = true
            return
        }

        do {
            displays = try service.listDisplays()
            isError = false
            ensureValidSelection()

            if !hasLoadedInitialLuminance {
                loadLuminanceForCurrentTarget()
                hasLoadedInitialLuminance = true
            }

            if displays.isEmpty {
                statusMessage = "No displays listed. Connect an external monitor and click Refresh."
            } else {
                statusMessage = "Found \(displays.count) display\(displays.count == 1 ? "" : "s")."
            }
        } catch {
            displays = []
            isError = true
            statusMessage = error.localizedDescription
        }
    }

    func controlModeChanged() {
        loadLuminanceForCurrentTarget()
    }

    func selectedDisplayChanged() {
        loadLuminanceForCurrentTarget()
    }

    func selectDisplay(_ display: DisplayInfo) {
        guard controlMode == .individual else { return }
        selectedDisplayIndex = display.index
        selectedDisplayChanged()
    }

    func cancelChanges() {
        loadLuminanceForCurrentTarget()
        isError = false
        statusMessage = ""
    }

    func applyBrightness() {
        guard let raw = Int(luminanceText.trimmingCharacters(in: .whitespaces)),
              (0 ... 100).contains(raw)
        else {
            isError = true
            statusMessage = "Enter a whole number from 0 to 100."
            return
        }

        let value = LuminanceStep.snap(raw)
        luminanceText = String(value)

        isBusy = true
        defer { isBusy = false }

        do {
            switch controlMode {
            case .allDisplays:
                try service.setLuminance(value, onAllDisplays: true)
                for display in displays {
                    lastAppliedLuminance[display.index] = value
                }
            case .individual:
                try service.setLuminance(value, forDisplayIndex: selectedDisplayIndex)
                lastAppliedLuminance[selectedDisplayIndex] = value
            }
            isError = false
            statusMessage = ""
        } catch {
            isError = true
            statusMessage = error.localizedDescription
        }
    }

    private func ensureValidSelection() {
        guard !displays.isEmpty else { return }
        if !displays.contains(where: { $0.index == selectedDisplayIndex }) {
            selectedDisplayIndex = displays[0].index
        }
    }

    /// Updates the slider from DDC read only — never sends brightness to the display.
    private func loadLuminanceForCurrentTarget() {
        guard m1ddcReady, !displays.isEmpty else { return }

        let index: Int
        switch controlMode {
        case .allDisplays:
            index = displays[0].index
        case .individual:
            ensureValidSelection()
            index = selectedDisplayIndex
        }

        if let cached = lastAppliedLuminance[index] {
            luminanceText = String(cached)
            return
        }

        let currentUI = LuminanceStep.snap(Int(luminanceText.trimmingCharacters(in: .whitespaces)) ?? 50)

        guard let read = try? service.getLuminance(for: index) else { return }

        let snapped = LuminanceStep.snap(read)
        // Ignore suspicious low reads (common HDMI DDC glitch); allow reads at or above current UI.
        if snapped >= currentUI || abs(snapped - currentUI) <= 20 {
            luminanceText = String(snapped)
        }
    }
}

/// Warm amber tint used for the brightness readout — a single, deliberately
/// desaturated accent that reads as "light" without screaming.
private enum BrightnessPalette {
    static let warm = Color(red: 0.97, green: 0.71, blue: 0.24)
}

private let brightnessPresets = [0, 20, 50, 80, 100]

struct ContentView: View {
    @StateObject private var viewModel = DisplayLuminanceViewModel()
    @State private var hoveredDisplayIndex: Int?

    /// Snapped 0–100 value currently shown in the controls.
    private var level: Int {
        LuminanceStep.snap(Int(viewModel.luminanceText) ?? 50)
    }

    private var levelFraction: Double {
        Double(level) / 100
    }

    /// Human label for whatever the brightness will be applied to.
    private var targetLabel: String {
        switch viewModel.controlMode {
        case .allDisplays:
            return "All displays"
        case .individual:
            return viewModel.selectedDisplay?.label ?? "No display selected"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            brightnessHero
            modeSelector
            sliderControls
            actionButtons
            displaysList
            footer
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .frame(width: WindowMetrics.contentWidth, height: WindowMetrics.contentHeight)
        .background(WindowConfigurator())
        .onAppear { viewModel.onAppear() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Display Luminance")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .tracking(-0.2)

            Text("Hardware brightness for external displays over DDC/CI. Needs Apple Silicon and a DDC-capable monitor.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Hero brightness readout

    private var brightnessHero: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(BrightnessPalette.warm.opacity(0.10 + 0.14 * levelFraction))
                    .frame(width: 68, height: 68)

                Image(systemName: "sun.max.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(BrightnessPalette.warm)
                    .scaleEffect(0.72 + 0.42 * levelFraction)
                    .opacity(0.4 + 0.6 * levelFraction)
                    .shadow(
                        color: BrightnessPalette.warm.opacity(0.55 * levelFraction),
                        radius: 14 * levelFraction
                    )
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(level)")
                        .font(.system(size: 52, weight: .semibold, design: .rounded).monospacedDigit())
                    Text("%")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(targetLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: level)
    }

    // MARK: - Mode

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Apply to")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            FullWidthSegmentedControl(
                segments: BrightnessControlMode.allCases.map(\.rawValue),
                selectedIndex: Binding(
                    get: {
                        BrightnessControlMode.allCases.firstIndex(of: viewModel.controlMode) ?? 0
                    },
                    set: { index in
                        let modes = BrightnessControlMode.allCases
                        guard modes.indices.contains(index) else { return }
                        viewModel.controlMode = modes[index]
                    }
                )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 28)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onChange(of: viewModel.controlMode) { _ in
            viewModel.controlModeChanged()
        }
    }

    // MARK: - Slider + presets

    private var sliderControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)

                Slider(
                    value: Binding(
                        get: { Double(level) },
                        set: { viewModel.luminanceText = String(LuminanceStep.snap(Int($0))) }
                    ),
                    in: 0 ... 100,
                    step: Double(LuminanceStep.increment)
                )
                .frame(maxWidth: .infinity)

                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }

            HStack(spacing: 6) {
                ForEach(brightnessPresets, id: \.self) { preset in
                    Button {
                        viewModel.luminanceText = String(LuminanceStep.snap(preset))
                    } label: {
                        Text("\(preset)")
                            .frame(maxWidth: .infinity)
                            .monospacedDigit()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(level == preset ? BrightnessPalette.warm : nil)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actionsDisabled: Bool {
        viewModel.isBusy || !viewModel.m1ddcReady || viewModel.displays.isEmpty
    }

    private var actionButtons: some View {
        Grid(horizontalSpacing: 8) {
            GridRow {
                Button {
                    viewModel.cancelChanges()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)
                .disabled(actionsDisabled)

                Button {
                    viewModel.applyBrightness()
                } label: {
                    Text(viewModel.applyButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(actionsDisabled)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Displays

    private var displaysList: some View {
        GroupBox {
            if viewModel.displays.isEmpty {
                emptyDisplays
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if viewModel.controlMode == .individual {
                        Text("Pick a display to target")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 2)
                    }

                    ForEach(viewModel.displays) { display in
                        displayRow(display)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } label: {
            Text("Displays")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayRow(_ display: DisplayInfo) -> some View {
        let selectable = viewModel.controlMode == .individual
        let isSelected = selectable && display.index == viewModel.selectedDisplayIndex
        let isHovered = selectable && hoveredDisplayIndex == display.index

        return Button {
            viewModel.selectDisplay(display)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "display")
                    .foregroundStyle(isSelected ? BrightnessPalette.warm : .secondary)
                    .frame(width: 20)

                Text(display.label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(BrightnessPalette.warm)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(rowBackground(isSelected: isSelected, isHovered: isHovered))
        }
        .buttonStyle(.plain)
        .disabled(!selectable)
        .onHover { hovering in
            guard selectable else { return }
            hoveredDisplayIndex = hovering ? display.index : nil
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private func rowBackground(isSelected: Bool, isHovered: Bool) -> some View {
        let fill: Color = {
            if isSelected { return BrightnessPalette.warm.opacity(0.16) }
            if isHovered { return Color.primary.opacity(0.06) }
            return .clear
        }()
        return RoundedRectangle(cornerRadius: 7).fill(fill)
    }

    private var emptyDisplays: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("No external displays found")
                .font(.callout.weight(.medium))
            Text("Connect a DDC-capable monitor, then click Refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !viewModel.statusMessage.isEmpty {
                Label {
                    Text(viewModel.statusMessage)
                        .textSelection(.enabled)
                } icon: {
                    Image(systemName: viewModel.isError
                        ? "exclamationmark.triangle.fill"
                        : "info.circle")
                }
                .font(.callout)
                .foregroundStyle(viewModel.isError ? .red : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if viewModel.m1ddcReady {
                Text("m1ddc · \(M1DDCBuildMode.label)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
