//
//  PromptRows.swift
//  Lotsen
//

import Foundation

/// One row of the picker: a browser, or an app mapped to the link's host.
struct PromptRow {
    let presentation: BrowserTargetPresentation
    let app: App?
    let shortcut: String?

    var target: BrowserTarget { presentation.target }
}

/// Everything the picker lists, resolved once when it opens. The rows are read
/// on every render and every arrow key, and resolving them touches app bundles,
/// stored JSON settings and the browsers' profile data.
struct PromptRows {
    let apps: [PromptRow]
    let browsers: [PromptRow]
    let appsAtTop: Bool
    /// In display order, so a selection index maps straight onto a row.
    let all: [PromptRow]

    init(
        urls: [URL],
        sourceTab: SourceTabSnapshot?,
        settings: AppSettings = .shared,
        defaults: UserDefaults = .standard
    ) {
        let browsers = settings.browsers
        let hidden = settings.hiddenBrowsers
        let apps = settings.apps
        let shortcuts = settings.shortcuts
        let profilesEnabled = defaults.object(forKey: "profilesEnabled") as? Bool ?? true
        let appsAtTop = defaults.object(forKey: "apps_atTop") as? Bool ?? true

        func shortcut(for presentation: BrowserTargetPresentation) -> String? {
            presentation.bundleIdentifier.flatMap {
                shortcuts[presentation.target.shortcutKey(bundleIdentifier: $0)]
            }
        }

        let visible = TargetPolicy.visible(browsers, hidden: hidden, profilesEnabled: profilesEnabled)

        // A row whose bundle no longer resolves renders as nothing, so leaving it
        // out keeps the keyboard selection indices in step with what is on screen.
        // A mapping to a hidden browser still shows: the domain asked for it.
        let appRows: [PromptRow] = apps.filter { app in
            sourceTab == nil && !urls.isEmpty && urls.allSatisfy { $0.matchesHost(app.host) }
        }
        .filter { !visible.contains($0.target) }
        .compactMap { app in
            BrowserTargetPresentation(app.target).map {
                PromptRow(presentation: $0, app: app, shortcut: shortcut(for: $0))
            }
        }

        let browserRows: [PromptRow] = visible
            .compactMap(BrowserTargetPresentation.init)
            .filter { $0.bundleIdentifier != sourceTab?.bundleIdentifier || $0.target.profile != nil }
            .map { PromptRow(presentation: $0, app: nil, shortcut: shortcut(for: $0)) }

        self.apps = appRows
        self.browsers = browserRows
        self.appsAtTop = appsAtTop
        self.all = appsAtTop ? appRows + browserRows : browserRows + appRows
    }
}
