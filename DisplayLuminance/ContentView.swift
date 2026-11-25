import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: DisplayLuminanceViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ViewThatFits(in: .horizontal) {
                    HStack {
                        title
                        Spacer(minLength: 16)
                        connectionStatus
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        title
                        connectionStatus
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 14) {
                        AllDisplaysCard(viewModel: viewModel)
                            .frame(minWidth: 310)

                        DisplayListCard(viewModel: viewModel)
                            .frame(minWidth: 325)
                    }

                    VStack(spacing: 14) {
                        AllDisplaysCard(viewModel: viewModel)
                        DisplayListCard(viewModel: viewModel)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(maxWidth: 1_040)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 360, minHeight: 340)
        .background(BrightnessPalette.window)
        .foregroundStyle(BrightnessPalette.text)
        .task { await viewModel.refresh() }
    }

    private var title: some View {
        Text("Brightness")
            .font(.system(size: 41, weight: .semibold))
            .tracking(-1.5)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var connectionStatus: some View {
        HStack(spacing: 8) {
            if let activity = viewModel.activity {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
                Text(activity == .refreshing ? "Looking for displays…" : "Adjusting brightness…")
            } else if let error = viewModel.errorMessage, !error.isEmpty {
                Label("Display connection unavailable", systemImage: "exclamationmark.circle")
            } else if viewModel.displays.isEmpty {
                Text("No displays connected")
            } else {
                Circle()
                    .fill(BrightnessPalette.connected)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                let count = viewModel.displays.count
                Text(count == 1 ? "1 display connected" : "\(count) displays connected")
            }
        }
        .font(.callout)
        .foregroundStyle(BrightnessPalette.secondary)
    }
}

private struct AllDisplaysCard: View {
    @ObservedObject var viewModel: DisplayLuminanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All displays")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let groupStatus {
                    Text(groupStatus)
                        .font(.caption)
                        .foregroundStyle(BrightnessPalette.warmText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BrightnessPalette.amber.opacity(0.09), in: RoundedRectangle(cornerRadius: 5))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Current brightness")
                    .font(.callout)
                    .foregroundStyle(BrightnessPalette.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(groupValue ?? "—")
                        .font(.system(size: 62, weight: .medium))
                        .monospacedDigit()
                        .tracking(-2.5)
                        .lineLimit(1)
                        .minimumScaleFactor(0.55)

                    if groupValue != nil {
                        Text("%")
                            .font(.system(size: 26, weight: .medium))
                            .foregroundStyle(BrightnessPalette.amber)
                    }
                }
                .foregroundStyle(BrightnessPalette.warmText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Current brightness")
            .accessibilityValue(groupValue.map { "\($0) percent" } ?? "Unavailable")
            .padding(.top, 27)
            .padding(.bottom, 25)

            Spacer(minLength: 0)

            HStack(spacing: 9) {
                ForEach(BrightnessDirection.allCases, id: \.self) { direction in
                    groupButton(direction)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 282, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            BrightnessHalo(intensity: viewModel.summary?.intensity ?? 0)
                .clipShape(RoundedRectangle(cornerRadius: BrightnessPalette.panelRadius))
        }
        .overlay {
            RoundedRectangle(cornerRadius: BrightnessPalette.panelRadius)
                .strokeBorder(BrightnessPalette.border)
                .allowsHitTesting(false)
        }
    }

    private var groupValue: String? {
        guard !viewModel.hasUnknownLevels, let summary = viewModel.summary else { return nil }
        return summary.lowest == summary.highest
            ? String(summary.lowest)
            : "\(summary.lowest)–\(summary.highest)"
    }

    private var groupStatus: String? {
        if viewModel.hasUnknownLevels { return "Readings incomplete" }
        guard let summary = viewModel.summary, viewModel.displays.count > 1 else { return nil }
        return summary.lowest == summary.highest ? "Same level" : "Mixed levels"
    }

    private func groupButton(_ direction: BrightnessDirection) -> some View {
        let destination = viewModel.groupDestination(direction)
        let verb = direction == .lower ? "Lower" : "Raise"
        let action = "\(verb) all"

        return Button {
            Task { await viewModel.adjustAll(direction) }
        } label: {
            VStack(spacing: 2) {
                Text(destination.map { "\($0)%" } ?? "—")
                    .font(.system(size: 19, weight: .semibold))
                    .monospacedDigit()
                Text(action)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 61)
            .foregroundStyle(BrightnessPalette.warmText)
        }
        .buttonStyle(BrightnessButtonStyle(warm: true))
        .accessibilityLabel(destination.map { "\(action) to \($0) percent" } ?? action)
        .disabled(destination.map { !viewModel.canSetGroup(to: $0) } ?? true)
    }
}

private struct DisplayListCard: View {
    @ObservedObject var viewModel: DisplayLuminanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Individual displays")
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.caption.weight(.medium))
                        .frame(minHeight: 28)
                }
                .buttonStyle(BrightnessButtonStyle())
                .keyboardShortcut("r", modifiers: .command)
                .disabled(viewModel.isBusy)
            }

            if viewModel.displays.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.displays) { reading in
                        if reading.id != viewModel.displays.first?.id {
                            Divider().overlay(BrightnessPalette.border)
                        }

                        DisplayBrightnessRow(reading: reading, viewModel: viewModel)
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 282, alignment: .topLeading)
        .background(BrightnessPalette.panel, in: RoundedRectangle(cornerRadius: BrightnessPalette.panelRadius))
        .overlay {
            RoundedRectangle(cornerRadius: BrightnessPalette.panelRadius)
                .strokeBorder(BrightnessPalette.border)
                .allowsHitTesting(false)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: viewModel.errorMessage == nil ? "display" : "exclamationmark.circle")
                .font(.system(size: 25))
                .accessibilityHidden(true)

            if viewModel.activity == .refreshing {
                Text("Looking for external displays…")
            } else if let error = viewModel.errorMessage {
                Text("Couldn’t load displays")
                    .font(.headline)
                Text(error)
                    .font(.callout)
                    .textSelection(.enabled)
            } else {
                Text("No external displays found")
                    .font(.headline)
                Text("Connect a DDC/CI-capable monitor, then click Refresh.")
                    .font(.callout)
            }
        }
        .foregroundStyle(BrightnessPalette.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 20)
    }
}

private struct DisplayBrightnessRow: View {
    let reading: DisplayBrightness
    @ObservedObject var viewModel: DisplayLuminanceViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 11) {
                MonitorThumbnail(intensity: reading.screenIntensity, warm: reading.id % 2 == 1)

                Text(reading.display.label)
                    .font(.headline)
                    .lineLimit(2)
                    .help(reading.display.label)

                Spacer(minLength: 4)

                if let level = reading.level {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(level)")
                            .font(.system(size: 25, weight: .semibold))
                            .monospacedDigit()
                        Text("%")
                            .font(.caption)
                            .foregroundStyle(BrightnessPalette.secondary)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Brightness")
                    .accessibilityValue("\(level) percent")
                } else {
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(BrightnessPalette.secondary)
                }
            }

            HStack(spacing: 7) {
                Spacer(minLength: 0)

                ForEach(BrightnessDirection.allCases, id: \.self) { direction in
                    stepButton(direction)
                }
            }

            if let failure = reading.failure {
                HStack(spacing: 8) {
                    Label("Couldn’t set \(failure.destination)%", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(BrightnessPalette.amber)
                        .help(failure.message)

                    Spacer(minLength: 0)

                    Button("Retry") {
                        Task { await viewModel.retry(reading.display) }
                    }
                    .buttonStyle(.link)
                    .accessibilityLabel("Retry setting \(reading.display.label) to \(failure.destination) percent")
                    .disabled(viewModel.isBusy)
                }
            }
        }
    }

    private func stepButton(_ direction: BrightnessDirection) -> some View {
        let lowering = direction == .lower
        let verb = lowering ? "Lower" : "Raise"

        return Button {
            Task { await viewModel.adjust(direction, on: reading.display) }
        } label: {
            Text(lowering ? "−10%" : "+10%")
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .frame(minWidth: 62, minHeight: 35)
        }
        .buttonStyle(BrightnessButtonStyle())
        .accessibilityLabel("\(verb) brightness for \(reading.display.label)")
        .disabled(viewModel.isBusy || (reading.level.map { direction.destination(from: $0) == $0 } ?? true))
    }
}
