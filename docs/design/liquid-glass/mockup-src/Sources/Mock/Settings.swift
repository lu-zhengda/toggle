import SwiftUI

struct OrderRow: View {
    let item: Item
    var lifted = false
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal").font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary).frame(width: 18)
                .accessibilityLabel("Reorder \(item.name)")
            GlyphView(glyph: item.glyph, size: 12)
                .foregroundStyle(item.visible ? Color.white : Color.secondary)
                .frame(width: 26, height: 26)
                .background(Circle().fill(item.visible ? item.tint.gradient : Color.gray.opacity(0.25).gradient))
            Text(item.name).font(.system(size: 13))
                .foregroundStyle(item.visible ? .primary : .secondary)
            if item.options != nil {
                Text("Dropdown").font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(.primary.opacity(0.08)))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Show", isOn: .constant(item.visible)).toggleStyle(.checkbox)
        }
        .padding(.horizontal, 12).frame(height: 38)
        .background {
            if lifted {
                RoundedRectangle(cornerRadius: 12).fill(.background)
                    .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5))
            }
        }
        .scaleEffect(lifted ? 1.02 : 1)
    }
}

struct TogglesTab: View {
    var dragging = false
    var body: some View {
        var items = Sample.sections.flatMap(\.items)
        let hide: Set = ["stage", "desk", "dock"]
        for i in items.indices where hide.contains(items[i].id) { items[i].visible = false }
        let liftedID = "awake"
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Toggles").font(.system(size: 15, weight: .semibold))
                    Text("Drag to reorder. Unchecked toggles are hidden from the menu bar panel.")
                        .font(.system(size: 11.5)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Default view", selection: .constant(Mode.grid)) {
                    Label("Grid", systemImage: "square.grid.2x2").tag(Mode.grid)
                    Label("List", systemImage: "list.bullet").tag(Mode.list)
                }
                .pickerStyle(.segmented).frame(width: 150).labelsHidden()
            }
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, it in
                        if dragging && it.id == liftedID {
                            EmptyView()
                        } else {
                            if dragging && idx == 3 {
                                // insertion gap where the dragged row will land
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))
                                    .frame(height: 38).padding(.horizontal, 6)
                                Divider().padding(.leading, 66)
                            }
                            OrderRow(item: it)
                            if idx < items.count - 1 { Divider().padding(.leading, 66) }
                        }
                    }
                }
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary.opacity(0.5)))
                if dragging, let it = items.first(where: { $0.id == liftedID }) {
                    OrderRow(item: it, lifted: true).padding(.horizontal, 10).offset(x: 4, y: 131)
                }
            }
            HStack {
                Button("Move Up") {}.disabled(false)
                Button("Move Down") {}
                Spacer()
                Button("Restore Default Order") {}
            }
            .controlSize(.small)
        }
        .padding(20)
        .frame(width: 560)
    }
}

struct PlaceholderTab: View {
    let title: String
    var body: some View { Text(title).frame(width: 560, height: 200) }
}
