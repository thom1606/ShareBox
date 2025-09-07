//
//  PickerView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

private struct NSPickerContent: View {
    @Environment(\.isEnabled) var isEnabled
    @Environment(\.hasErrored) private var errored: Bool

    var title: String
    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(LocalizedStringKey(title))
                .lineLimit(1)
                .font(.body.weight(.semibold))
                .foregroundColor(Color(NSColor.labelColor))
                .animation(.snappy, value: title)
                .contentTransition(.numericText(countsDown: true))
            Spacer()
            ZStack {
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .heavy))
                    .foregroundColor(.primary)
            }
            .frame(width: 16, height: 16)
            .background(RoundedRectangle(cornerRadius: 4).fill(.primary.opacity(0.2)))
        }
        .frame(height: 36)
        .padding(.horizontal, 8)
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .stroke(.primary.opacity(0.2))
        )
        .overlay {
            if isHovered {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.clear)
                    .stroke(Color(NSColor.secondaryLabelColor), style: .init(lineWidth: 3))
            }
        }
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
}

private struct NSPicker: NSViewRepresentable {
    let selection: Binding<String>
    let items: [(String, String)]

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        // Find the selected item's title
        let selectedItemTitle = items.first { $0.0 == selection.wrappedValue }?.1 ?? NSLocalizedString("Select", comment: "")

        // Create the SwiftUI view
        let pickerContent = NSPickerContent(title: selectedItemTitle)

        // Create an NSHostingView with the SwiftUI view
        let hostingView = NSHostingView(rootView: pickerContent)

        // Create the NSButton
        let button = NSButton(title: "", target: context.coordinator, action: #selector(context.coordinator.buttonClicked))
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.button = button

        // Add the hosting view as a subview of the button
        button.addSubview(hostingView)

        // Set constraints for the hosting view to match the button's size
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.heightAnchor.constraint(equalToConstant: 52)
        ])

        view.addSubview(button)

        // Set constraints for the button to match the view's size
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            button.heightAnchor.constraint(equalToConstant: 52)
        ])

        // Set constraints for the view to match the provided frame size
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 52)
        ])

        // let button = NSButton(title: "Select an item", target: context.coordinator, action: #selector(context.coordinator.buttonClicked))
        // context.coordinator.button = button

        // Create popover menu
        let menu = NSMenu()
        for item in items {
            let menuItem = NSMenuItem(title: item.1, action: #selector(context.coordinator.menuItemSelected(_:)), keyEquivalent: "")
            menuItem.target = context.coordinator
            menuItem.representedObject = item.0
            menu.addItem(menuItem)
        }

        button.menu = menu
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Update the selected item's title
        if let button = context.coordinator.button {
            let selectedItemTitle = items.first { $0.0 == selection.wrappedValue }?.1 ?? NSLocalizedString("Select", comment: "")
            if let hostingView = button.subviews.first as? NSHostingView<NSPickerContent> {
                hostingView.rootView = NSPickerContent(title: selectedItemTitle)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: NSPicker
        weak var button: NSButton?

        init(_ parent: NSPicker) {
            self.parent = parent
        }

        @MainActor
        @objc func buttonClicked() {
            if let button = button {
                button.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: button.superview)
            }
        }

        @objc func menuItemSelected(_ sender: NSMenuItem) {
            if let selectedValue = sender.representedObject as? String {
                parent.selection.wrappedValue = selectedValue
            }
        }
    }
}

struct PickerView: View {
    var label: LocalizedStringKey
    @Binding var selection: String
    let items: [(String, String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            NSPicker(selection: $selection, items: items)
        }
    }
}

#Preview {
    PickerView(label: "Label", selection: .constant(""), items: [])
}
