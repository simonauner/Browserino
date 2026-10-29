//
//  PreferencesView.swift
//  Lotsen
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
    func content(ruleDraft: Binding<RuleDraft?>) -> some View {
        switch self {
        case .general: GeneralTab()
        case .browsers: BrowsersTab()
        case .apps: AppsTab()
        case .rules: RulesTab(draft: ruleDraft)
        case .locations: BrowserSearchLocationsTab()
        case .shortcuts: ShortcutsTab()
        case .about: AboutTab()
        }
    }
}

/// Lets a pane ask the settings window to grow or shrink by the height its
/// content overflows the visible area. A value with an identity rather than a
/// bare closure, because SwiftUI cannot compare closures and would otherwise
/// treat every update as a new action.
nonisolated struct FitSettingsHeightAction: Equatable, Sendable {
    static let none = FitSettingsHeightAction { _ in }

    private let id = UUID()
    private let perform: @MainActor @Sendable (CGFloat) -> Void

    init(_ perform: @escaping @MainActor @Sendable (CGFloat) -> Void) {
        self.perform = perform
    }

    @MainActor func callAsFunction(_ overflow: CGFloat) {
        perform(overflow)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension EnvironmentValues {
    @Entry var fitSettingsHeight: FitSettingsHeightAction = .none
}

struct PreferencesView: View {
    static let sidebarWidth: CGFloat = 200
    static let contentMinSize = CGSize(width: 860, height: 500)

    @State private var selection: SettingsPane
    @State private var ruleDraft: RuleDraft?

    /// A rule draft opens on the Rules pane with the new rule's form already up.
    init(ruleDraft: RuleDraft? = nil) {
        _selection = State(initialValue: ruleDraft == nil ? .general : .rules)
        _ruleDraft = State(initialValue: ruleDraft)
    }

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
            // Asks for a fixed width; macOS still lets the divider be dragged.
            .navigationSplitViewColumnWidth(min: Self.sidebarWidth, ideal: Self.sidebarWidth, max: Self.sidebarWidth)
            // The panes are the window's only navigation; hiding the list leaves no way back.
            .toolbar(removing: .sidebarToggle)
        } detail: {
            selection.content(ruleDraft: $ruleDraft)
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
            minHeight: Self.contentMinSize.height,
            // The sidebar can still be dragged wider than the window's minimum allows;
            // pin to the left so the overflow goes off the right edge, not both.
            alignment: .topLeading
        )
    }
}

#Preview {
    PreferencesView()
}
