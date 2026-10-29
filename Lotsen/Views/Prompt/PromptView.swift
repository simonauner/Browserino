//
//  PromptView.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

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
                shortcuts[presentation.target.shortcutKey(bundleIdentifier: $0)] ?? shortcuts[$0]
            }
        }

        // A row whose bundle no longer resolves renders as nothing, so leaving it
        // out keeps the keyboard selection indices in step with what is on screen.
        let appRows: [PromptRow] = apps.filter { app in
            sourceTab == nil && urls.contains { $0.matchesHost(app.host) }
        }
        .filter { !browsers.contains($0.target) }
        .compactMap { app in
            BrowserTargetPresentation(app.target).map {
                PromptRow(presentation: $0, app: app, shortcut: shortcut(for: $0))
            }
        }

        let browserRows: [PromptRow] = TargetPolicy.visible(browsers, hidden: hidden, profilesEnabled: profilesEnabled)
            .compactMap(BrowserTargetPresentation.init)
            .filter { $0.bundleIdentifier != sourceTab?.bundleIdentifier }
            .map { PromptRow(presentation: $0, app: nil, shortcut: shortcut(for: $0)) }

        self.apps = appRows
        self.browsers = browserRows
        self.appsAtTop = appsAtTop
        self.all = appsAtTop ? appRows + browserRows : browserRows + appRows
    }
}

struct PromptView: View {
    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @Setting(\.rules) private var rules
    @AppStorage("rules_showInPicker") private var showRuleOption: Bool = true

    let urls: [URL]
    var sourceTab: SourceTabSnapshot? = nil
    @AppStorage("switch_closeSourceTab") private var closeSourceTab = false

    private let rows: PromptRows

    init(urls: [URL], sourceTab: SourceTabSnapshot? = nil) {
        self.urls = urls
        self.sourceTab = sourceTab
        self.rows = PromptRows(urls: urls, sourceTab: sourceTab)
    }

    private func open(_ urls: [URL], target: BrowserTarget, isIncognito: Bool, savingRule: Bool = true) {
        if savingRule {
            saveRuleIfRequested(for: target)
        }
        BrowserUtil.openURL(urls, target: target, isIncognito: isIncognito) { app, error in
            if let error { BrowserSwitchService.shared.presentOpenFailedAlert(error); return }
            guard app != nil, let sourceTab, closeSourceTab else { return }
            Task {
                do { try await BrowserTabScripting.close(sourceTab) }
                catch { BrowserSwitchService.shared.presentCloseFailedAlert() }
            }
        }
    }


    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @FocusState private var focused: Bool
    @State private var alwaysOpen = false
    /// The rows' full height, which the picker shrinks to fit.
    @State private var listHeight: CGFloat = 0
    /// Past this the rows scroll rather than the picker growing.
    private static let maxListHeight: CGFloat = 400

    /// Rules only apply to a single opened link, so moving a tab or opening
    /// several links offers no rule.
    var offersRule: Bool {
        showRuleOption && sourceTab == nil && urls.count == 1
    }

    /// The highlighted row.
    var selectedItem: PromptRow? {
        rows.all.indices.contains(selected) ? rows.all[selected] : nil
    }

    /// A rule opens the link unchanged, so an app that rewrites the scheme cannot get one.
    func canSaveRule(for app: App?) -> Bool {
        app?.schemeOverride.isEmpty ?? true
    }

    /// What the rule row matches: the link's whole host, rather than the one link.
    var rulePattern: String {
        urls.first.map(Rule.hostPattern(for:)) ?? ""
    }

    private func saveRuleIfRequested(for target: BrowserTarget) {
        guard offersRule, alwaysOpen else { return }
        rules = Rule.addingPattern(rulePattern, target: target, to: rules)
    }

    /// Opens Settings with a rule for the link filled in, so a pattern can be
    /// adjusted and tested before it is saved. The link opens once the form
    /// closes: a browser opened alongside it takes the focus from Settings.
    func editRule() {
        guard let item = selectedItem, let url = urls.first else { return }
        let draft = RuleDraft(
            rule: Rule(regex: rulePattern, app: item.target.app, profile: item.target.profile, kind: .pattern),
            link: url
        )

        (NSApp.delegate as? AppDelegate)?.openRuleEditor(draft)
    }

    func openSelected(isIncognito: Bool) {
        guard let item = selectedItem else { return }
        activate(item, isIncognito: isIncognito)
    }

    func activate(_ row: PromptRow, isIncognito: Bool) {
        if let app = row.app {
            openUrlsInApp(app: app)
        } else {
            open(urls, target: row.target, isIncognito: isIncognito)
        }
    }

    /// The rows from `offset` on in `rows.all`, which is what selection indices count.
    func items(_ section: [PromptRow], offset: Int) -> some View {
        ForEach(Array(section.enumerated()), id: \.offset) { index, row in
            PromptItem(
                presentation: row.presentation,
                shortcut: row.shortcut
            ) {
                activate(row, isIncognito: NSEvent.modifierFlags.contains(.shift))
            }
            .id(offset + index)
            .buttonStyle(
                SelectButtonStyle(
                    selected: selected == offset + index
                )
            )
        }
    }

    func openUrlsInApp(app: App) {
        let urls: [URL] =
            if app.schemeOverride.isEmpty {
                urls
            } else {
                urls.compactMap {
                    guard var components = URLComponents(url: $0, resolvingAgainstBaseURL: false) else { return nil }
                    components.scheme = app.schemeOverride
                    return components.url
                }
            }

        open(
            urls,
            target: app.target,
            isIncognito: false,
            savingRule: canSaveRule(for: app)
        )
    }

    var body: some View {
        VStack {
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if !rows.apps.isEmpty && rows.appsAtTop {
                            items(rows.apps, offset: 0)

                            Divider()
                        }

                        items(rows.browsers, offset: rows.appsAtTop ? rows.apps.count : 0)

                        if !rows.apps.isEmpty && !rows.appsAtTop {
                            Divider()

                            items(rows.apps, offset: rows.browsers.count)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self, of: \.size.height) { listHeight = $0 }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($focused)
                .onMoveCommand { command in
                    if command == .up {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    } else if command == .down {
                        selected = min(rows.all.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    }
                }
                .background {
                    Button(action: {
                        openSelected(isIncognito: false)
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.defaultAction)

                    Button(action: {
                        openSelected(isIncognito: true)
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.return, modifiers: [.shift])

                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.cancelAction)
                }
                .onAppear {
                    focused.toggle()
                    withAnimation(.interactiveSpring(duration: 0.3)) {
                        opacityAnimation = 1
                    }
                }
                .scrollEdgeEffectDisabledCompat()
            }
            .frame(height: min(listHeight, Self.maxListHeight))

            Divider()

            if offersRule {
                HStack(alignment: .firstTextBaseline) {
                    Toggle(isOn: $alwaysOpen) {
                        Text(verbatim: L10n.format(
                            "rules.picker.always_open_host",
                            urls.first?.host() ?? rulePattern,
                            selectedItem?.presentation.displayName ?? ""
                        ))
                        .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 8)

                    Button(L10n.text("rules.picker.edit_rule"), action: editRule)
                        .controlSize(.small)
                }
                .disabled(!canSaveRule(for: selectedItem?.app))
                .font(.callout)
                .onChange(of: alwaysOpen) {
                    // Keeps the arrow keys and Return on the browser list.
                    focused = true
                }

                Divider()
            }

            if let host = urls.first?.host() {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(urls.first?.absoluteString ?? "", forType: .string)

                    if closeAfterCopy {
                        NSApplication.shared.keyWindow?.close()
                    }
                }) {
                    Text(
                        host
                    )
                }
                .buttonStyle(.plain)
                .keyboardShortcut(
                    KeyEquivalent("c"),
                    modifiers: alternativeShortcut ? [.command] : [.command, .option]
                )
                .help(urls.first?.absoluteString ?? "")
            }
        }
        .padding(12)
        // As tall as its rows, so a short list leaves no gap above the rule row.
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            NSApp.windows.compactMap { $0 as? LotsenWindow }.first?.fitContentHeight(height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(SelectorSurface())
        .opacity(opacityAnimation)
        .ignoresSafeArea()
    }
}

#Preview {
    PromptView(urls: [])
}
