import AppKit
import SwiftUI

/// NSSegmentedControl with equal fill distribution so segments span the full width.
struct FullWidthSegmentedControl: NSViewRepresentable {
    let segments: [String]
    @Binding var selectedIndex: Int

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedIndex: $selectedIndex)
    }

    func makeNSView(context: Context) -> NSView {
        let container = NSView(frame: .zero)
        let control = NSSegmentedControl(
            labels: segments,
            trackingMode: .selectOne,
            target: context.coordinator,
            action: #selector(Coordinator.segmentChanged(_:))
        )
        control.segmentDistribution = .fillEqually
        control.translatesAutoresizingMaskIntoConstraints = false
        control.selectedSegment = selectedIndex
        container.addSubview(control)

        NSLayoutConstraint.activate([
            control.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            control.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            control.topAnchor.constraint(equalTo: container.topAnchor),
            control.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        context.coordinator.control = control
        return container
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let control = context.coordinator.control else { return }
        if control.selectedSegment != selectedIndex {
            control.selectedSegment = selectedIndex
        }
    }

    final class Coordinator: NSObject {
        @Binding var selectedIndex: Int
        weak var control: NSSegmentedControl?

        init(selectedIndex: Binding<Int>) {
            _selectedIndex = selectedIndex
        }

        @objc func segmentChanged(_ sender: NSSegmentedControl) {
            selectedIndex = sender.selectedSegment
        }
    }
}
