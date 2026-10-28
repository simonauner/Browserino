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
struct EditableList<Row: View>: View {
    let count: Int
    var add: () -> Void
    var edit: ((Int) -> Void)?
    var remove: (IndexSet) -> Void
    /// Rows that can't be removed, such as a built-in default.
    var isRemovable: (Int) -> Bool = { _ in true }
    @ViewBuilder var row: (Int) -> Row

    @State private var selection = Set<Int>()

    private var removable: IndexSet {
        IndexSet(selection.filter { $0 < count && isRemovable($0) })
    }

    private func removeSelection() {
        let rows = removable
        guard !rows.isEmpty else { return }
        selection = []
        remove(rows)
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach(0..<count, id: \.self) { index in
                    row(index)
                }
            }
            .listStyle(.plain)
            .alternatingRowBackgrounds()
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
                .disabled(!rows.contains(where: isRemovable))
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
