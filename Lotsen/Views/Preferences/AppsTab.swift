//
//  AppsTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct AppRow: View {
    let app: App

    var body: some View {
        let bundle = Bundle(url: app.app)

        HStack {
            Text(verbatim: app.host.isEmpty ? L10n.text("apps.list.all_domains") : app.host)

            if !app.schemeOverride.isEmpty {
                Text(verbatim: L10n.format("apps.list.opens_as", app.schemeOverride))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(bundle == nil
                 ? L10n.format("browsers.status.not_installed", app.app.appDisplayName)
                 : app.target.displayName)
                .foregroundStyle(
                    bundle == nil || app.target.hasMissingProfile ? .secondary : .primary
                )

            if let browserId = bundle?.bundleIdentifier {
                ShortcutButton(
                    shortcutKey: app.target.shortcutKey(bundleIdentifier: browserId)
                )
            }

            if bundle != nil {
                BrowserTargetIcon(target: app.target)
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "questionmark.app.dashed")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.vertical, 2)
    }
}

struct AppsTab: View {
    @Setting(\.apps) private var apps
    @State private var addPresented = false
    @State private var editing: EditedRow<App>?
    private var undoManager: UndoManager? { (NSApp.delegate as? AppDelegate)?.settingsUndoManager }

    private func update(_ value: [App], action: String) {
        AppSettings.shared.replace(\.apps, with: value, undoManager: undoManager, actionName: L10n.text(action))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableList(
                items: apps,
                add: {
                    addPresented = true
                },
                edit: { index in
                    if apps.indices.contains(index) {
                        editing = EditedRow(id: index, value: apps[index])
                    }
                },
                remove: { rows in
                    var value = apps
                    value.remove(atOffsets: rows)
                    update(value, action: "common.delete")
                }
            ) { app in
                AppRow(app: app)
            }
            
            Text(verbatim: L10n.text("apps.list.instructions"))
                .foregroundStyle(.secondary)
            Text(verbatim: L10n.text("settings.list.undo_hint"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $addPresented) {
            AppForm(app: nil) {
                update(apps + [$0], action: "common.add")
            }
        }
        .sheet(item: $editing) { row in
            AppForm(
                app: row.value,
                onSave: { app in
                    if apps.indices.contains(row.id) {
                        var value = apps
                        value[row.id] = app
                        update(value, action: "common.edit")
                    }
                },
                onDelete: {
                    if apps.indices.contains(row.id), apps[row.id] == row.value {
                        var value = apps
                        value.remove(at: row.id)
                        update(value, action: "common.delete")
                    }
                }
            )
        }
    }
}

#Preview {
    AppsTab()
}
