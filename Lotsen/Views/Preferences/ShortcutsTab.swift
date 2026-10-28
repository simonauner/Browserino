//
//  ShortcutsTab.swift
//  Lotsen
//

import SwiftUI
import KeyboardShortcuts

/// A read-only overview of every keyboard shortcut. They are assigned in the
/// Browsers, Apps and General panes; the picker's own keys are fixed.
struct ShortcutsTab: View {
    @Setting(\.browsers) private var browsers
    @Setting(\.apps) private var apps
    @Setting(\.shortcuts) private var shortcuts
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false

    /// Browsers, then apps not already listed as browsers, that have a key assigned.
    private var assigned: [(presentation: BrowserTargetPresentation, key: String)] {
        var targets = browsers
        for app in apps where !targets.contains(app.target) {
            targets.append(app.target)
        }

        return targets
            .compactMap(BrowserTargetPresentation.init)
            .compactMap { presentation in
                guard let identifier = presentation.bundleIdentifier,
                      let key = shortcuts[presentation.target.shortcutKey(bundleIdentifier: identifier)] ?? shortcuts[identifier],
                      !key.isEmpty else {
                    return nil
                }
                return (presentation, key)
            }
    }

    var body: some View {
        Form {
            Section(L10n.text("shortcuts.section.global")) {
                if let shortcut = KeyboardShortcuts.getShortcut(for: .moveCurrentTab) {
                    row(L10n.text("tabs.transfer.title"), keys: shortcut.description)
                } else {
                    LabeledContent {
                        Text(verbatim: L10n.text("shortcuts.not_set"))
                            .foregroundStyle(.secondary)
                    } label: {
                        Text(verbatim: L10n.text("tabs.transfer.title"))
                    }
                }
            }

            Section(L10n.text("shortcuts.section.picker")) {
                row(L10n.text("shortcuts.picker.select"), keys: "↑ ↓")
                row(L10n.text("shortcuts.picker.open"), keys: "↩")
                row(L10n.text("shortcuts.picker.open_private"), keys: "⇧↩")
                row(L10n.text("settings.copy_url.title"), keys: alternativeShortcut ? "⌘C" : "⌥⌘C")
                row(L10n.text("shortcuts.picker.close"), keys: "esc")
            }

            Section {
                let assigned = assigned
                if assigned.isEmpty {
                    Text(verbatim: L10n.text("shortcuts.browsers.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(assigned, id: \.presentation.target) { item in
                        LabeledContent {
                            KeyCap(item.key.uppercased())
                        } label: {
                            Label {
                                Text(verbatim: item.presentation.displayName)
                            } icon: {
                                BrowserTargetIcon(item.presentation, badgeSize: 9)
                                    .frame(width: 18, height: 18)
                            }
                        }
                    }
                }
            } header: {
                Text(verbatim: L10n.text("shortcuts.section.browsers"))
            } footer: {
                Text(verbatim: L10n.text("shortcuts.browsers.private_hint"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func row(_ title: String, keys: String) -> some View {
        LabeledContent {
            KeyCap(keys)
        } label: {
            Text(verbatim: title)
        }
    }
}

private struct KeyCap: View {
    let keys: String

    init(_ keys: String) {
        self.keys = keys
    }

    var body: some View {
        Text(verbatim: keys)
            .font(.system(.body, design: .rounded).weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: .rect(cornerRadius: 5))
    }
}

#Preview {
    ShortcutsTab()
}
