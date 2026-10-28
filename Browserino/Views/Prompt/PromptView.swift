//
//  PromptView.swift
//  Browserino
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import AppKit
import SwiftUI

struct PromptView: View {
    @AppStorage("browsers") private var browsers: [BrowserTarget] = []
    @AppStorage("hiddenBrowsers") private var hiddenBrowsers: [BrowserTarget] = []
    @AppStorage("apps") private var apps: [App] = []
    @AppStorage("shortcuts") private var shortcuts: [String: String] = [:]

    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @AppStorage("profilesEnabled") private var profilesEnabled = true
    @AppStorage("apps_atTop") private var appsAtTop: Bool = true
    @AppStorage("rules") private var rules: [Rule] = []
    @AppStorage("rules_showInPicker") private var showRuleOption: Bool = true

    let urls: [URL]
    var sourceTab: SourceTabSnapshot? = nil
    @AppStorage("switch_closeSourceTab") private var closeSourceTab = false

    private func open(_ urls: [URL], target: BrowserTarget, isIncognito: Bool, savingRule: Bool = true) {
        if savingRule {
            saveRuleIfRequested(for: target)
        }
        BrowserUtil.openURL(urls, target: target, isIncognito: isIncognito) { app, error in
            if let error { BrowserSwitchService.shared.presentOpenFailedAlert(error); return }
            guard app != nil, let sourceTab, closeSourceTab else { return }
            Task {
                do { try await BrowserTabScripting.close(sourceTab) }
                catch { BrowserSwitchService.shared.presentCloseFailedAlert(error) }
            }
        }
    }


    @State private var opacityAnimation = 0.0
    @State private var selected = 0
    @FocusState private var focused: Bool
    @State private var alwaysOpen = false
    @State private var rulePattern = ""
    @FocusState private var patternFocused: Bool

    /// Rules only apply to a single opened link, so moving a tab or opening
    /// several links offers no rule.
    var offersRule: Bool {
        showRuleOption && sourceTab == nil && urls.count == 1
    }

    /// The highlighted row, with its app mapping when it is an app row.
    var selectedItem: (target: BrowserTarget, app: App?)? {
        let browserIndex = appsAtTop ? selected - appsForUrls.count : selected
        if visibleBrowsers.indices.contains(browserIndex) {
            return (visibleBrowsers[browserIndex], nil)
        }

        let appIndex = appsAtTop ? selected : selected - visibleBrowsers.count
        guard appsForUrls.indices.contains(appIndex) else { return nil }
        return (appsForUrls[appIndex].target, appsForUrls[appIndex])
    }

    /// A rule opens the link unchanged, so an app that rewrites the scheme cannot get one.
    func canSaveRule(for app: App?) -> Bool {
        app?.schemeOverride.isEmpty ?? true
    }

    private func saveRuleIfRequested(for target: BrowserTarget) {
        guard offersRule, alwaysOpen else { return }
        rules = Rule.addingPattern(rulePattern, target: target, to: rules)
    }

    func openSelected(isIncognito: Bool) {
        guard let item = selectedItem else { return }
        if let app = item.app {
            openUrlsInApp(app: app)
        } else {
            open(urls, target: item.target, isIncognito: isIncognito)
        }
    }

    var appsForUrls: [App] {
        (sourceTab == nil ? urls : []).flatMap { url in
            return apps.filter { app in
                url.matchesHost(app.host)
            }
        }
        .filter {
            !browsers.contains($0.target)
        }
        // A row whose bundle no longer resolves renders as nothing, so excluding it
        // here keeps the keyboard selection indices in step with what is on screen.
        .filter {
            Bundle(url: $0.app) != nil
        }
    }

    var visibleBrowsers: [BrowserTarget] {
        TargetPolicy.visible(browsers, hidden: hiddenBrowsers, profilesEnabled: profilesEnabled).filter {
            Bundle(url: $0.app) != nil && Bundle(url: $0.app)?.bundleIdentifier != sourceTab?.bundleIdentifier
        }
    }

    func shortcut(for target: BrowserTarget) -> String? {
        Bundle(url: target.app)?.bundleIdentifier.flatMap {
            shortcuts[target.shortcutKey(bundleIdentifier: $0)] ?? shortcuts[$0]
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
                        if !appsForUrls.isEmpty && appsAtTop {
                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                PromptItem(
                                    target: app.target,
                                    title: app.target.displayName,
                                    shortcut: shortcut(for: app.target),
                                    shortcutsEnabled: !patternFocused
                                ) {
                                    openUrlsInApp(app: app)
                                }
                                .id(index)
                                .buttonStyle(
                                    SelectButtonStyle(
                                        selected: selected == index
                                    )
                                )
                            }

                            Divider()
                        }
                        
                        ForEach(Array(visibleBrowsers.enumerated()), id: \.offset) {
                            index, browser in
                            PromptItem(
                                target: browser,
                                title: browser.displayName,
                                shortcut: shortcut(for: browser),
                                shortcutsEnabled: !patternFocused
                            ) {
                                open(
                                    urls,
                                    target: browser,
                                    isIncognito: NSEvent.modifierFlags.contains(.shift)
                                )
                            }
                            .id(index + (appsAtTop ? appsForUrls.count : 0))
                            .buttonStyle(
                                SelectButtonStyle(
                                    selected: selected == index + (appsAtTop ? appsForUrls.count : 0)
                                )
                            )
                        }

                        if !appsForUrls.isEmpty && !appsAtTop {
                            Divider()

                            ForEach(Array(appsForUrls.enumerated()), id: \.offset) { index, app in
                                PromptItem(
                                    target: app.target,
                                    title: app.target.displayName,
                                    shortcut: shortcut(for: app.target),
                                    shortcutsEnabled: !patternFocused
                                ) {
                                    openUrlsInApp(app: app)
                                }
                                .id(visibleBrowsers.count + index)
                                .buttonStyle(
                                    SelectButtonStyle(
                                        selected: selected == visibleBrowsers.count + index
                                    )
                                )
                            }
                        }
                    }
                }
                .focusable()
                .focusEffectDisabled()
                .focused($focused)
                .onMoveCommand { command in
                    if command == .up {
                        selected = max(0, selected - 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    } else if command == .down {
                        selected = min(visibleBrowsers.count + appsForUrls.count - 1, selected + 1)
                        scrollViewProxy.scrollTo(selected, anchor: .center)
                    }
                }
                .background {
                    Button(action: {
                        openSelected(isIncognito: false)
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.defaultAction)
                    .disabled(patternFocused)

                    Button(action: {
                        openSelected(isIncognito: true)
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.return, modifiers: [.shift])
                    .disabled(patternFocused)

                    Button(action: {
                        NSApplication.shared.keyWindow?.close()
                    }) {}
                    .opacity(0)
                    .keyboardShortcut(.cancelAction)
                    .disabled(patternFocused)
                }
                .onAppear {
                    focused.toggle()
                    withAnimation(.interactiveSpring(duration: 0.3)) {
                        opacityAnimation = 1
                    }
                }
                .scrollEdgeEffectDisabledCompat()
            }
            // Grows a small picker to fit the rule row rather than leaving room for only one browser.
            .frame(minHeight: offersRule ? 120 : nil)

            Divider()

            if offersRule {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $alwaysOpen) {
                        Text(verbatim: L10n.format("rules.picker.always_open", selectedItem?.target.displayName ?? ""))
                    }
                    .disabled(!canSaveRule(for: selectedItem?.app))

                    TextField(L10n.text("rules.picker.pattern"), text: $rulePattern)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!alwaysOpen || !canSaveRule(for: selectedItem?.app))
                        .focused($patternFocused)
                        .onSubmit {
                            openSelected(isIncognito: NSEvent.modifierFlags.contains(.shift))
                        }
                        .onExitCommand {
                            focused = true
                        }
                }
                .font(.callout)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: alwaysOpen) {
                    if !alwaysOpen {
                        focused = true
                    }
                }

                Divider()
            }

            if let host = urls.first?.host() {
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.declareTypes([.string], owner: nil)
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
                .toolTip(urls.first?.absoluteString ?? "")
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .modifier(SelectorSurface())
        .onAppear {
            rulePattern = urls.first?.absoluteString ?? ""
        }
        .opacity(opacityAnimation)
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    PromptView(urls: [])
}
