//
//  EditableList.swift
//  Lotsen
//

import SwiftUI

/// A row being edited in a sheet. It carries the row's value, so the sheet never
/// reads the list by index after the row may have been deleted.
struct EditedRow<Value>: Identifiable {
    let id: Int
    let value: Value
}

/// A bordered list with + and − buttons underneath, like the lists in System
/// Settings. Rows are selected by index; double-clicking one edits it, and the
/// Delete key or − removes the selection.
struct EditableList<Item, Row: View>: View {
    let items: [Item]
    var add: () -> Void
    var edit: ((Int) -> Void)?
    var remove: (IndexSet) -> Void
    var move: ((IndexSet, Int) -> Void)?
    /// Rows that can't be removed, such as a built-in default.
    var isRemovable: (Item) -> Bool = { _ in true }
    @ViewBuilder var row: (Item) -> Row

    private var count: Int { items.count }

    @State private var selection = Set<Int>()

    private var removable: IndexSet {
        IndexSet(selection.filter { items.indices.contains($0) && isRemovable(items[$0]) })
    }

    private func removeSelection() {
        let rows = removable
        guard !rows.isEmpty else { return }
        selection = []
        remove(rows)
    }

    private var selectedIndex: Int? {
        selection.count == 1 ? selection.first.flatMap { (0..<count).contains($0) ? $0 : nil } : nil
    }

    private func moveSelection(by offset: Int) {
        guard let index = selectedIndex, (0..<count).contains(index + offset) else { return }
        moveRows(IndexSet(integer: index), to: index + (offset > 0 ? 2 : -1))
    }

    private func moveRows(_ rows: IndexSet, to destination: Int) {
        guard let move else { return }
        move(rows, destination)
        let start = destination - rows.filter { $0 < destination }.count
        selection = Set(start..<(start + rows.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(0..<count, id: \.self) { index in
                    // AppKit can render an old row while applying a deletion.
                    // Read this view's snapshot, never the caller's live array.
                    row(items[index])
                }
                .onMove(perform: moveRows)
                .moveDisabled(move == nil)
            }
            .listStyle(.plain)
            .alternatingRowBackgrounds(count == 0 ? .disabled : .enabled)
            .contextMenu(forSelectionType: Int.self) { rows in
                if let edit, rows.count == 1, let index = rows.first {
                    Button(L10n.text("common.edit")) {
                        edit(index)
                    }
                }

                Button(L10n.text("common.delete"), role: .destructive) {
                    selection = rows
                    removeSelection()
                }
                .disabled(!rows.contains { items.indices.contains($0) && isRemovable(items[$0]) })
            } primaryAction: { rows in
                if let edit, rows.count == 1, let index = rows.first {
                    edit(index)
                }
            }
            .onDeleteCommand(perform: removeSelection)

            Divider()

            HStack(spacing: 0) {
                Button(action: add) {
                    Image(systemName: "plus")
                        .frame(width: 24, height: 20)
                        .contentShape(.rect)
                }
                .help(L10n.text("common.add"))
                .accessibilityLabel(L10n.text("common.add"))

                Divider()
                    .frame(height: 14)

                Button(action: removeSelection) {
                    Image(systemName: "minus")
                        .frame(width: 24, height: 20)
                        .contentShape(.rect)
                }
                .disabled(removable.isEmpty)
                .help(L10n.text("common.remove"))
                .accessibilityLabel(L10n.text("common.remove"))

                if move != nil {
                    Divider().frame(height: 14)
                    Button { moveSelection(by: -1) } label: {
                        Image(systemName: "arrow.up").frame(width: 24, height: 20)
                    }
                    .disabled(selectedIndex == nil || selectedIndex == 0)
                    .help(L10n.text("common.move_up"))
                    .accessibilityLabel(L10n.text("common.move_up"))
                    Button { moveSelection(by: 1) } label: {
                        Image(systemName: "arrow.down").frame(width: 24, height: 20)
                    }
                    .disabled(selectedIndex == nil || selectedIndex == count - 1)
                    .help(L10n.text("common.move_down"))
                    .accessibilityLabel(L10n.text("common.move_down"))
                }

                Spacer()
            }
            .buttonStyle(.borderless)
            .padding(4)
        }
        .background(.background)
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(.separator)
        }
    }
}
