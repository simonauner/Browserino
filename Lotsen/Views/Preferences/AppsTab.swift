//
//  AppsTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct App: Codable, Hashable {
    var host: String
    var schemeOverride: String
    var app: URL
    var profile: String?

    var target: BrowserTarget {
        BrowserTarget(app: app, profile: profile)
    }
}

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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EditableList(
                count: apps.count,
                add: {
                    addPresented = true
                },
                edit: { index in
                    editing = EditedRow(id: index, value: apps[index])
                },
                remove: { rows in
                    apps.remove(atOffsets: rows)
                }
            ) { index in
                AppRow(app: apps[index])
            }
            
            Text(verbatim: L10n.text("apps.list.instructions"))
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .sheet(isPresented: $addPresented) {
            AppForm(app: nil) {
                apps.append($0)
            }
        }
        .sheet(item: $editing) { row in
            AppForm(
                app: row.value,
                onSave: { app in
                    if apps.indices.contains(row.id) {
                        apps[row.id] = app
                    }
                },
                onDelete: {
                    apps.removeAll {
                        $0 == row.value
                    }
                }
            )
        }
    }
}

#Preview {
    AppsTab()
}
