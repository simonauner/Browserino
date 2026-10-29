//  BrowserSearchLocationsTab.swift
//  Lotsen
//
//  Created by byt3m4st3r.
//

import SwiftUI

struct BrowserSearchLocationsTab: View {
    @Setting(\.directories) private var directories
    @State private var explorerPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableList(
                count: directories.count,
                add: {
                    explorerPresented = true
                },
                remove: { rows in
                    directories.remove(atOffsets: rows)
                },
                isRemovable: { index in
                    directories[index].directoryPath != "/Applications"
                }
            ) { index in
                Label {
                    Text(verbatim: directories[index].directoryPath)
                } icon: {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: directories[index].directoryPath))
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
                        directories.append(newDirectory)
                    }
                }
            }

            Text(verbatim: L10n.text("locations.list.instructions"))
                .foregroundStyle(.secondary)

            Text(verbatim: L10n.text("locations.add.instructions"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }
}

#Preview {
    BrowserSearchLocationsTab()
}
