//
//  BrowsersTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI

struct BrowsersTab: View {
    @Setting(\.browsers) private var browsers
    @Setting(\.hiddenBrowsers) private var hiddenBrowsers
    @AppStorage("profilesEnabled") private var profilesEnabled = true
    @Setting(\.profileNames) private var profileNames
    @Setting(\.privateArgs) private var privateArgs

    private var displayed: [(offset: Int, element: BrowserTarget)] {
        var seen = Set<URL>()
        return browsers.enumerated().compactMap { index, target in
            if profilesEnabled { return (index, target) }
            return seen.insert(target.app).inserted ? (index, BrowserTarget(app: target.app)) : nil
        }
    }
    private func move(from source: IndexSet, to destination: Int) {
        guard profilesEnabled else { return }
        browsers.move(fromOffsets: source, toOffset: destination)
    }

    private func privateArg(for key: String) -> Binding<String> {
        return .init(
            get: { self.privateArgs[key, default: ""] },
            set: { self.privateArgs[key] = $0 })
    }

    /// Offer the grant only where it could actually help: a Chromium browser whose
    /// profiles we have not been able to read yet.
    private func needsProfileAccess(_ target: BrowserTarget) -> Bool {
        ChromiumProfileService.userDataDirectory(forAppAt: target.app) != nil
            && ChromiumProfileService.profiles(forAppAt: target.app) == nil
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Toggle(L10n.text("browsers.profiles.show"), isOn: $profilesEnabled)

                Spacer()

                Button(L10n.text("settings.installed_browsers.rescan")) {
                    if let refreshed = BrowserUtil.rescanBrowsers(oldBrowsers: browsers) { browsers = refreshed }
                }
                .help(L10n.text("settings.installed_browsers.description"))
            }
            .padding(.horizontal, 20)
            List {
                ForEach(displayed, id: \.offset) { offset, browser in
                    // Resolved once per row: each piece otherwise reads the browser's profile data again.
                    if let presentation = BrowserTargetPresentation(browser) {
                        let isFirstOfApp = browsers.first(where: { $0.app == browser.app }) == browser
                        let isHidden = TargetPolicy.visible(browsers.filter { $0.app == browser.app }, hidden: hiddenBrowsers, profilesEnabled: profilesEnabled).isEmpty
                            || TargetPolicy.isHidden(browser, hidden: hiddenBrowsers)

                        HStack(spacing: 12) {
                            Text((offset + 1).formatted())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 20, alignment: .trailing)

                            BrowserTargetIcon(presentation)
                                .frame(width: 24, height: 24)

                            if let profile = browser.profile, let identifier = presentation.bundleIdentifier {
                                TextField(profile, text: Binding(
                                    get: { profileNames[browser.shortcutKey(bundleIdentifier: identifier)] ?? presentation.profile?.name ?? profile },
                                    set: { profileNames[browser.shortcutKey(bundleIdentifier: identifier)] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 100, maxWidth: 200)
                            } else {
                                Text(presentation.displayName)
                            }

                            Spacer()

                            if let browserId = presentation.bundleIdentifier {
                                // Incognito is a property of the browser, not of one
                                // profile, so it stays on the plain row and every
                                // profile of that browser inherits it.
                                if !profilesEnabled || isFirstOfApp {
                                    TextField(L10n.text("browsers.private_argument.placeholder"),
                                        text: privateArg(for: browserId)
                                    )
                                    .textFieldStyle(.roundedBorder)
                                    .monospaced()
                                    .autocorrectionDisabled()
                                    .frame(width: 180)
                                }

                                ShortcutButton(
                                    shortcutKey: browser.shortcutKey(bundleIdentifier: browserId)
                                )
                            }

                            if profilesEnabled && isFirstOfApp && needsProfileAccess(browser) {
                                Button(L10n.text("browsers.profiles.enable")) {
                                    // Rescan whatever the result: picking the folder grants access even
                                    // when no bookmark could be saved, and the rescan is idempotent.
                                    ChromiumProfileService.requestAccess(forAppAt: browser.app)
                                    if let refreshed = BrowserUtil.rescanBrowsers(oldBrowsers: browsers) { browsers = refreshed }
                                }
                            }

                            Button(action: {
                                hiddenBrowsers = TargetPolicy.toggle(browser, targets: browsers, hidden: hiddenBrowsers)
                            }) {
                                Image(systemName: isHidden ? "eye.slash" : "eye")
                                    .foregroundStyle(isHidden ? .secondary : .primary)
                                    .frame(width: 20)
                            }
                            .buttonStyle(.borderless)
                            .help(L10n.text(isHidden ? "browsers.visibility.show" : "browsers.visibility.hide"))
                            .accessibilityLabel(L10n.text(isHidden ? "browsers.visibility.show" : "browsers.visibility.hide"))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onMove(perform: move)
                .moveDisabled(!profilesEnabled)
            }
            .scrollContentBackground(.hidden)
            .onChange(of: profilesEnabled) { _, _ in
                if let refreshed = BrowserUtil.rescanBrowsers(oldBrowsers: browsers) { browsers = refreshed }
            }
            .onAppear {
                // Safe to run every time: the merge keeps the user's order and is
                // idempotent, so this picks up profiles added since the last visit
                // without waiting for an explicit Rescan.
                if let refreshed = BrowserUtil.rescanBrowsers(oldBrowsers: browsers) { browsers = refreshed }
            }

            Text(verbatim: L10n.text("browsers.list.instructions"))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
        }
        .padding(.bottom, 20)
    }
}

#Preview {
    PreferencesView()
}
