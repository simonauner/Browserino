//
//  PreferencesView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import SwiftUI

enum SettingsPane: CaseIterable, Identifiable {
    case general, browsers, apps, rules, locations, shortcuts, about

    var id: Self { self }

    var titleKey: String {
        switch self {
        case .general: "settings.tabs.general"
        case .browsers: "settings.tabs.browsers"
        case .apps: "settings.tabs.apps"
        case .rules: "settings.tabs.rules"
        case .locations: "settings.tabs.locations"
        case .shortcuts: "settings.tabs.shortcuts"
        case .about: "settings.tabs.about"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .browsers: "globe"
        case .apps: "square.grid.2x2"
        case .rules: "arrow.triangle.branch"
        case .locations: "folder"
        case .shortcuts: "keyboard"
        case .about: "info.circle"
        }
    }

    @ViewBuilder
    var content: some View {
        switch self {
        case .general: GeneralTab()
        case .browsers: BrowsersTab()
        case .apps: AppsTab()
        case .rules: RulesTab()
        case .locations: BrowserSearchLocationsTab()
        case .shortcuts: ShortcutsTab()
        case .about: AboutTab()
        }
    }
}

extension EnvironmentValues {
    /// Lets a pane ask the settings window to grow or shrink by the height its
    /// content overflows the visible area.
    @Entry var fitSettingsHeight: @MainActor @Sendable (CGFloat) -> Void = { _ in }
}

struct PreferencesView: View {
    static let sidebarWidth: CGFloat = 200
    static let contentMinSize = CGSize(width: 860, height: 500)

    @State private var selection: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                // An empty header keeps the first row's highlight off the
                // toolbar's separator; the sidebar ignores content margins.
                Section {
                    ForEach(SettingsPane.allCases) { pane in
                        Label(L10n.text(pane.titleKey), systemImage: pane.systemImage)
                            .tag(pane)
                    }
                } header: {
                    Color.clear.frame(height: 0)
                }
            }
            .navigationSplitViewColumnWidth(Self.sidebarWidth)
            // The panes are the window's only navigation; hiding the list leaves no way back.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            selection.content
                // NavigationSplitView sizes the detail at a near-zero width when it
                // works out the window's minimum height. Text that wraps without
                // truncating, like the Rules toggle, then asks for hundreds of
                // points and pushes the whole window up under the title bar.
                .frame(minWidth: Self.contentMinSize.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .navigationTitle(L10n.text(selection.titleKey))
        }
        .frame(
            minWidth: Self.sidebarWidth + Self.contentMinSize.width,
            minHeight: Self.contentMinSize.height
        )
    }
}

#Preview {
    PreferencesView()
}
