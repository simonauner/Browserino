//
//  EditAppForm.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct EditAppForm: View {
    @Binding var app: App

    @Setting(\.apps) private var apps
    @Environment(\.dismiss) private var dismiss

    /// Edits are made on a copy, so Cancel leaves the saved site untouched.
    @State private var draft: App
    @State private var deletePresented = false

    init(app: Binding<App>) {
        _app = app
        _draft = State(initialValue: app.wrappedValue)
    }

    private var hostUrl: URL? {
        let url = if draft.host.starts(with: /https?:\/\//) {
            draft.host
        } else {
            "http://" + draft.host
        }

        return draft.host.isEmpty ? nil : URL(string: url)
    }

    private var hostValid: Bool {
        hostUrl?.host() != nil
    }

    var body: some View {
        Form {
            Section {
                TextField(L10n.text("apps.editor.host"), text: $draft.host)
                    .autocorrectionDisabled()

                LabeledContent(L10n.text("browsers.target.open_in")) {
                    BrowserTargetPicker(
                        app: Binding(
                            get: { draft.app },
                            set: { if let selected = $0 { draft.app = selected } }
                        ),
                        profile: $draft.profile
                    )
                }
            } header: {
                Text(verbatim: L10n.text("apps.editor.edit_title"))
            } footer: {
                if !draft.host.isEmpty && !hostValid {
                    Label(L10n.text("apps.editor.invalid_host"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section(L10n.text("settings.section.advanced")) {
                LabeledContent(L10n.text("apps.editor.replace_scheme")) {
                    TextField(L10n.text("apps.editor.replace_scheme"), text: $draft.schemeOverride)
                        .labelsHidden()
                        .monospaced()
                        .autocorrectionDisabled()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .toolbar {
            ToolbarItem(placement: .destructiveAction) {
                Button(L10n.text("common.delete"), role: .destructive) {
                    deletePresented = true
                }
            }

            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.text("common.cancel"), role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.text("common.save")) {
                    guard let host = hostUrl?.host() else {
                        return
                    }

                    draft.host = host
                    app = draft
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hostValid)
            }
        }
        .confirmationDialog(
            L10n.text("apps.editor.delete_confirmation"),
            isPresented: $deletePresented
        ) {
            Button(L10n.text("common.delete"), role: .destructive) {
                apps.removeAll {
                    $0 == app
                }
                dismiss()
            }
        }
    }
}

#Preview {
    EditAppForm(
        app: .constant(
            App(
                host: "mm.2gis.one",
                schemeOverride: "",
                app: URL(string: "file:///Applications/Mattermost.app")!
            )
        )
    )
}
