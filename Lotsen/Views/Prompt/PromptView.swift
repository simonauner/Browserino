//
//  PromptView.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PromptView: View {
    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @Setting(\.rules) private var rules
    @Setting(\.privateArgs) private var privateArgs
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
    @State private var otherApplicationPresented = false
    /// The rows' full height, which the picker shrinks to fit.
    @State private var listHeight: CGFloat = 0
    /// Past this the rows scroll rather than the picker growing.
    private static let maxListHeight: CGFloat = 400

    /// Rules only apply to a single opened link, so moving a tab or opening
    /// several links offers no rule.
    var offersRule: Bool {
        showRuleOption && sourceTab == nil && urls.count == 1 && !rows.all.isEmpty
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
        AppSettings.shared.replace(
            \.rules, with: Rule.addingPattern(rulePattern, target: target, to: rules),
            undoManager: (NSApp.delegate as? AppDelegate)?.settingsUndoManager,
            actionName: L10n.text("common.add")
        )
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
        guard !isIncognito || supportsPrivate(row) else {
            BrowserUtil.presentError(NSError(domain: "Lotsen", code: 1, userInfo: [NSLocalizedDescriptionKey: L10n.text("picker.private.unavailable")]))
            return
        }
        if let app = row.app {
            openUrlsInApp(app: app, isIncognito: isIncognito)
        } else {
            open(urls, target: row.target, isIncognito: isIncognito)
        }
    }

    private func supportsPrivate(_ row: PromptRow) -> Bool {
        PrivateBrowsingPolicy.canOpen(identifier: row.presentation.bundleIdentifier, overrides: privateArgs, schemeOverride: row.app?.schemeOverride ?? "")
    }

    /// The rows from `offset` on in `rows.all`, which is what selection indices count.
    func items(_ section: [PromptRow], offset: Int) -> some View {
        ForEach(Array(section.enumerated()), id: \.offset) { index, row in
            PromptItem(
                presentation: row.presentation,
                shortcut: row.shortcut,
                supportsPrivate: supportsPrivate(row)
            ) {
                activate(row, isIncognito: NSEvent.modifierFlags.contains(.shift))
            }
            .id(offset + index)
            .contextMenu {
                Button(L10n.text("picker.private.open")) { activate(row, isIncognito: true) }
                    .disabled(!supportsPrivate(row))
            }
            .buttonStyle(
                SelectButtonStyle(
                    selected: selected == offset + index
                )
            )
        }
    }

    func openUrlsInApp(app: App, isIncognito: Bool) {
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
            isIncognito: isIncognito,
            savingRule: canSaveRule(for: app)
        )
    }

    var body: some View {
        VStack {
            if urls.count > 1 {
                DisclosureGroup {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(urls.enumerated()), id: \.offset) { _, url in
                                Text(verbatim: url.absoluteString)
                                    .font(.caption)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 100)
                } label: {
                    Text(verbatim: L10n.format("picker.batch.title", String(urls.count)))
                        .font(.headline)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: L10n.text("picker.batch.description"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(urls.map(\.absoluteString).joined(separator: "\n"), forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help(L10n.text("picker.batch.copy"))
                    .accessibilityLabel(L10n.text("picker.batch.copy"))
                    .keyboardShortcut(KeyEquivalent("c"), modifiers: alternativeShortcut ? [.command] : [.command, .option])
                }
                Divider()
            }
            ScrollViewReader { scrollViewProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        if rows.all.isEmpty {
                            ContentUnavailableView {
                                Label(L10n.text("picker.empty.title"), systemImage: "globe")
                            } description: {
                                Text(verbatim: L10n.text("picker.empty.description"))
                            } actions: {
                                Button(L10n.text("picker.empty.manage")) {
                                    (NSApp.delegate as? AppDelegate)?.openBrowserPreferences(urls: urls)
                                }
                                Button(L10n.text("browsers.target.other_application")) {
                                    otherApplicationPresented = true
                                }
                            }
                        }
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
                // The focused list handles the browsers' keys itself: plain-key
                // shortcuts on the rows' own buttons never fired, they just beeped.
                .onKeyPress { press in
                    guard press.modifiers.isDisjoint(with: [.command, .option, .control]),
                          let row = rows.all.first(where: { $0.shortcut == press.key.character.uppercased() })
                    else { return .ignored }
                    activate(row, isIncognito: press.modifiers.contains(.shift))
                    return .handled
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

            if urls.count == 1, let host = urls.first?.host() {
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
        .fileImporter(isPresented: $otherApplicationPresented, allowedContentTypes: [.application]) { result in
            if case .success(let application) = result {
                open(urls, target: BrowserTarget(app: application), isIncognito: false, savingRule: false)
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
