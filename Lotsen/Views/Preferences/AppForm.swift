//
//  AppForm.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct AppForm: View {
    var isNew: Bool
    var onSave: (App) -> Void
    /// Nil for a domain that isn't saved yet, which has nothing to delete.
    var onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    /// Edits are made on a copy, so Cancel leaves the saved domain untouched.
    @State private var host: String
    @State private var schemeOverride: String
    @State private var url: URL?
    @State private var profile: String?
    @State private var deletePresented = false

    init(app: App?, onSave: @escaping (App) -> Void, onDelete: (() -> Void)? = nil) {
        isNew = app == nil
        self.onSave = onSave
        self.onDelete = onDelete
        _host = State(initialValue: app?.host ?? "")
        _schemeOverride = State(initialValue: app?.schemeOverride ?? "")
        _url = State(initialValue: app?.app)
        _profile = State(initialValue: app?.profile)
    }

    private var trimmedHost: String {
        host.trimmingCharacters(in: .whitespaces)
    }

    private var hostUrl: URL? {
        let url = if trimmedHost.starts(with: /https?:\/\//) {
            trimmedHost
        } else {
            "http://" + trimmedHost
        }

        return URL(string: url)
    }

    /// An empty host matches every domain.
    private var hostValid: Bool {
        trimmedHost.isEmpty || hostUrl?.host() != nil
    }

    /// Accepts "figma", "figma:" or "figma://", since all three name the same scheme.
    private var parsedScheme: String? {
        var scheme = schemeOverride.trimmingCharacters(in: .whitespaces)
        if scheme.hasSuffix("://") {
            scheme.removeLast(3)
        } else if scheme.hasSuffix(":") {
            scheme.removeLast()
        }

        // URLComponents traps on a scheme it can't represent, so reject those here.
        return scheme.isEmpty || scheme.wholeMatch(of: /[A-Za-z][A-Za-z0-9+.\-]*/) != nil ? scheme : nil
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    L10n.text("apps.editor.host"),
                    text: $host,
                    prompt: Text(verbatim: L10n.text("apps.host.placeholder"))
                )
                .autocorrectionDisabled()

                LabeledContent(L10n.text("browsers.target.open_in")) {
                    BrowserTargetPicker(app: $url, profile: $profile)
                }
            } header: {
                Text(verbatim: L10n.text(isNew ? "apps.editor.new_title" : "apps.editor.edit_title"))
            } footer: {
                if !hostValid {
                    Label(L10n.text("apps.editor.invalid_host"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text(verbatim: L10n.text("apps.editor.host_help"))
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                LabeledContent(L10n.text("apps.editor.replace_scheme")) {
                    TextField(
                        L10n.text("apps.editor.replace_scheme"),
                        text: $schemeOverride,
                        prompt: Text(verbatim: "figma")
                    )
                        .labelsHidden()
                        .monospaced()
                        .autocorrectionDisabled()
                }
            } header: {
                Text(verbatim: L10n.text("settings.section.advanced"))
            } footer: {
                if parsedScheme == nil {
                    Label(L10n.text("apps.editor.invalid_scheme"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text(verbatim: L10n.text("apps.editor.replace_scheme_help"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .toolbar {
            if onDelete != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button(L10n.text("common.delete"), role: .destructive) {
                        deletePresented = true
                    }
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
                    guard let url, hostValid, let scheme = parsedScheme else {
                        return
                    }

                    onSave(
                        App(
                            host: trimmedHost.isEmpty ? "" : hostUrl?.host() ?? trimmedHost,
                            schemeOverride: scheme,
                            app: url,
                            profile: profile
                        )
                    )
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!hostValid || parsedScheme == nil || url == nil)
            }
        }
        .confirmationDialog(
            L10n.text("apps.editor.delete_confirmation"),
            isPresented: $deletePresented
        ) {
            Button(L10n.text("common.delete"), role: .destructive) {
                onDelete?()
                dismiss()
            }
        }
    }
}

#Preview {
    AppForm(
        app: App(
            host: "mm.2gis.one",
            schemeOverride: "",
            app: URL(string: "file:///Applications/Mattermost.app")!
        ),
        onSave: { _ in },
        onDelete: {}
    )
}
