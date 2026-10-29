//  BrowserSearchLocationsTab.swift
//  Lotsen
//
//  Created by byt3m4st3r.
//

import SwiftUI

struct BrowserSearchLocationsTab: View {
    @Setting(\.directories) private var directories
    @State private var explorerPresented = false
    private var undoManager: UndoManager? { (NSApp.delegate as? AppDelegate)?.settingsUndoManager }

    private func update(_ value: [Directory], action: String) {
        AppSettings.shared.replace(\.directories, with: value, undoManager: undoManager, actionName: L10n.text(action))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableList(
                items: directories,
                add: {
                    explorerPresented = true
                },
                remove: { rows in
                    var value = directories
                    value.remove(atOffsets: rows)
                    update(value, action: "common.delete")
                },
                isRemovable: { directory in
                    directory.directoryPath != "/Applications"
                }
            ) { directory in
                Label {
                    Text(verbatim: directory.directoryPath)
                } icon: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: directory.directoryPath))
                        .resizable()
                        .frame(width: 16, height: 16)
                }
            }
            .fileImporter(
                isPresented: $explorerPresented,
                allowedContentTypes: [.directory]
            ) { result in
                if case let .success(dir) = result {
                    let newDirectory = Directory(directoryPath: dir.path)
                    if !directories.contains(newDirectory) {
                        update(directories + [newDirectory], action: "common.add")
                    }
                }
            }

            Text(verbatim: L10n.text("locations.list.instructions"))
                .foregroundStyle(.secondary)

            Text(verbatim: L10n.text("locations.add.instructions"))
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.text("settings.list.undo_hint"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

#Preview {
    BrowserSearchLocationsTab()
}
