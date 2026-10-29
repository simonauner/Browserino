//
//  LotsenApp.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 06.06.2024.
//

import SwiftUI
import Foundation
import KeyboardShortcuts

extension UserDefaults {
    /// Exposed for key-value observing; the app reads the setting through @AppStorage.
    @objc dynamic var showInMenuBar: Bool {
        bool(forKey: "showInMenuBar")
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, BrowserSwitchPresenting {
    private var menuBarObservation: NSKeyValueObservation?
    private var selectorWindow: LotsenWindow?
    private var preferencesWindow: NSWindow?
    /// Set while the selector is up over a settings window that was sitting behind
    /// other apps, so closing the selector can put it back there.
    private var preferencesHiddenForSelector = false
    /// Set once the user resizes the settings window by hand, so the height
    /// fitted to its content stops overriding their choice.
    private var preferencesResizedByUser = false
    private var linksAwaitingBrowserSettings: [URL]?
    
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    
    var statusMenu: NSMenu!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        SettingsPolicy.migrateFromBrowserino(
            defaults: .standard,
            browserino: UserDefaults.standard.persistentDomain(forName: SettingsPolicy.browserinoBundleIdentifier)
        )
        if let chrome = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") {
            SettingsPolicy.migrateLegacyProfiles(defaults: .standard, chrome: chrome)
        }
        BrowserSwitchService.shared.presenter = self
        BrowserSwitchService.shared.startTracking()
        KeyboardShortcuts.onKeyUp(for: .moveCurrentTab) { BrowserSwitchService.shared.beginMove(preferFrontmost: true) }
        observeLanguage()
        setupStatusBar()

        menuBarObservation = UserDefaults.standard.observe(\.showInMenuBar) { [weak self] _, _ in
            // Another process writing our defaults delivers this off the main
            // thread, so hop rather than assuming isolation.
            Task { @MainActor in
                self?.setupStatusBar()
                self?.updateActivationPolicy()
            }
        }
        
        if UserDefaults.standard.object(forKey: "browsers") == nil {
            openPreferences()
        }
        loadBrowsersIfEmpty()
        BrowserUtil.moveShortcutsToProfiles(AppSettings.shared.browsers)
    }

    /// The list is otherwise only filled when the Browsers pane appears, which a
    /// new install or a reset may never have shown.
    private func loadBrowsersIfEmpty() {
        if AppSettings.shared.browsers.isEmpty {
            AppSettings.shared.browsers = BrowserUtil.loadBrowsers(oldBrowsers: [])
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        self.openPreferences()
        return true
    }
    
    func setupStatusBar() {
        if showInMenuBar {
            if statusBarItem == nil {
                statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                let statusButton = statusBarItem!.button
                statusButton!.image = NSImage.menuIcon
                
                let preferences = NSMenuItem(title: L10n.text("menu.preferences"), action: #selector(openPreferences), keyEquivalent: "")
                let quit = NSMenuItem(title: L10n.text("menu.quit"), action: #selector(quitApp), keyEquivalent: "")
                
                statusMenu = NSMenu()
                
                let move = NSMenuItem(title: L10n.text("tabs.transfer.title"), action: #selector(moveCurrentTab), keyEquivalent: "")
                statusMenu!.addItem(move)
                statusMenu!.addItem(.separator())
                statusMenu!.addItem(preferences)
                statusMenu!.addItem(.separator())
                statusMenu!.addItem(quit)
                
                statusBarItem!.menu = statusMenu!
            }
        } else {
            if statusBarItem != nil {
                NSStatusBar.system.removeStatusItem(statusBarItem!)
                statusBarItem = nil
            }
        }
    }
    
    /// Rebuilds the menu bar item in the new language. Observation fires once per
    /// change, so each change re-registers for the next one.
    private func observeLanguage() {
        withObservationTracking {
            _ = Localization.shared.activeLanguage
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if let item = self.statusBarItem { NSStatusBar.system.removeStatusItem(item); self.statusBarItem = nil }
                // The settings window's title follows its selected pane on its own.
                self.setupStatusBar()
                self.observeLanguage()
            }
        }
    }
    
    func application(_ application: NSApplication, willContinueUserActivityWithType userActivityType: String) -> Bool {
        if userActivityType == NSUserActivityTypeBrowsingWeb {
            return true
        }
        
        return false
    }
    
    func application(_ application: NSApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([any NSUserActivityRestoring]) -> Void) -> Bool {
        if let url = userActivity.webpageURL {
            self.application(application, open: [url])
            return true
        }
        
        return false
    }
    
    @objc func moveCurrentTab() { BrowserSwitchService.shared.beginMove(preferFrontmost: false) }

    func presentMovePrompt(snapshot: SourceTabSnapshot) {
        loadBrowsersIfEmpty()
        guard !PromptRows(urls: [snapshot.url], sourceTab: snapshot).browsers.isEmpty else {
            BrowserSwitchService.shared.presentNoDestinationAlert(); return
        }
        presentSelector(urls: [snapshot.url], sourceTab: snapshot)
    }

    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private var preferencesMinSize: NSSize {
        NSSize(
            width: PreferencesView.sidebarWidth + PreferencesView.contentMinSize.width,
            height: PreferencesView.contentMinSize.height
        )
    }

    @objc func openPreferences() {
        showPreferences()
    }

    func testBrowserPicker() {
        presentSelector(urls: [URL(string: "https://example.com/")!])
    }

    func openBrowserPreferences(urls: [URL]) {
        linksAwaitingBrowserSettings = urls
        showPreferences(pane: .browsers)
    }

    /// Opens Settings on the Rules pane with a new rule filled in from `draft`.
    func openRuleEditor(_ draft: RuleDraft) {
        showPreferences(ruleDraft: draft)
    }

    private func showPreferences(pane: SettingsPane? = nil, ruleDraft: RuleDraft? = nil) {
        // Rebuilding the window's content would reset its pane and close a rule
        // being edited, so an open window is only brought forward.
        if ruleDraft == nil, pane == nil, let window = preferencesWindow, window.isVisible {
            NSApplication.shared.activate()
            window.makeKeyAndOrderFront(nil)
            return
        }
        if preferencesWindow == nil {
            preferencesWindow = NSWindow(
                contentRect: NSRect(origin: .zero, size: preferencesMinSize),
                styleMask: [.miniaturizable, .closable, .resizable, .titled, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        
        preferencesWindow!.center()
        preferencesWindow!.title = L10n.text("settings.window.title")
        preferencesResizedByUser = false
        // Made out here so the root view's closure captures the action, not self:
        // the window would otherwise hold its delegate through its content.
        let fitHeight = FitSettingsHeightAction { [weak self] overflow in
            self?.fitPreferencesHeight(overflow: overflow)
        }
        preferencesWindow!.contentView = NSHostingView(rootView: LocalizedRoot {
            PreferencesView(pane: pane ?? .general, ruleDraft: ruleDraft)
                .environment(\.fitSettingsHeight, fitHeight)
        })
        
        preferencesWindow!.isReleasedWhenClosed = false
        preferencesWindow!.titlebarAppearsTransparent = true
        // A unified toolbar gives the pane title the same height and placement
        // as System Settings.
        if preferencesWindow!.toolbar == nil {
            preferencesWindow!.toolbar = NSToolbar()
        }
        preferencesWindow!.toolbarStyle = .unified

        preferencesWindow!.contentMinSize = preferencesMinSize
        
        preferencesWindow!.collectionBehavior = [.moveToActiveSpace, .fullScreenNone]
        preferencesWindow!.delegate = self

        preferencesHiddenForSelector = false
        updateActivationPolicy(preferencesOpen: true)
        NSApplication.shared.activate()
        
        preferencesWindow!.makeKeyAndOrderFront(nil)
        preferencesWindow!.orderFrontRegardless()
    }
    
    /// Tall enough to show every setting without scrolling, but never more than
    /// 90% of the screen's visible height (menu bar and Dock excluded). Runs on
    /// every measurement, since the first ones come before the window has its
    /// final layout and settle over a few passes.
    private func fitPreferencesHeight(overflow: CGFloat) {
        guard !preferencesResizedByUser, overflow.magnitude >= 1, let window = preferencesWindow,
              let screen = window.screen ?? NSScreen.main else { return }

        let minHeight = window.frameRect(forContentRect: NSRect(origin: .zero, size: window.contentMinSize)).height
        let maxHeight = (screen.visibleFrame.height * 0.9).rounded(.down)
        var frame = window.frame
        frame.size.height = min(max(frame.height + overflow, minHeight), maxHeight)
        window.setFrame(frame, display: true)
        window.center()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let processedUrls = urls.compactMap(\.lotsenIncomingURL)
        guard !processedUrls.isEmpty else { return }

        if processedUrls.count == 1 {
            let urlString = processedUrls.first!.absoluteString

            if let rule = Rule.firstMatch(in: AppSettings.shared.rules, for: urlString) {
                // A rule's browser may be uninstalled; the picker keeps the link.
                BrowserUtil.openURL(processedUrls, target: rule.target, isIncognito: false) { _, error in
                    if error != nil { self.presentSelector(urls: processedUrls) }
                }
                return
            }
        }
        
        presentSelector(urls: processedUrls)
    }

    private func presentSelector(urls: [URL], sourceTab: SourceTabSnapshot? = nil) {
        loadBrowsersIfEmpty()
        if selectorWindow == nil {
            selectorWindow = LotsenWindow()
        }
        // A width saved before the picker was widened would cut off the rule row.
        if selectorWindow!.frame.width < LotsenWindow.selectorWidth {
            selectorWindow!.setContentSize(NSSize(width: LotsenWindow.selectorWidth, height: selectorWindow!.frame.height))
        }
        
        guard let screen = (getScreenWithMouse() ?? NSScreen.main ?? NSScreen.screens.first)?.visibleFrame else { return }
        
        selectorWindow?.setFrameOrigin(
            NSPoint(
                x: clamp(
                    min: screen.minX + 20,
                    max: screen.maxX - selectorWindow!.frame.width - 20,
                    value: NSEvent.mouseLocation.x - selectorWindow!.frame.width / 2
                ),
                y: clamp(
                    min: screen.minY + 20,
                    max: screen.maxY - selectorWindow!.frame.height - 20,
                    value: NSEvent.mouseLocation.y - (selectorWindow!.frame.height - 30)
                )
            )
        )
        
        // Activating the app raises every window it has, so a settings window left
        // open behind other apps would otherwise surface along with the selector.
        if !NSApp.isActive, let preferences = preferencesWindow, preferences.isVisible {
            preferences.orderOut(nil)
            preferencesHiddenForSelector = true
        }

        NSApplication.shared.activate()
        selectorWindow!.deactivateDelay()
        
        let prompt = NSHostingView(
            rootView: LocalizedRoot { PromptView(urls: urls, sourceTab: sourceTab) }
        )
        // The picker sets its own height, which a minimum size taken from the
        // SwiftUI content would hold the window above.
        prompt.sizingOptions = []
        selectorWindow!.contentView = prompt
        
        selectorWindow!.makeKeyAndOrderFront(nil)
        selectorWindow!.isReleasedWhenClosed = false
        selectorWindow!.delegate = self
    }
    
    func clamp(min: CGFloat, max: CGFloat, value: CGFloat) -> CGFloat {
        CGFloat.minimum(CGFloat.maximum(min, value), max)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === selectorWindow, selectorWindow?.hidesOnDeactivate == true, selectorWindow?.presentingAlert == false, selectorWindow?.attachedSheet == nil {
            selectorWindow!.contentView = nil
            selectorWindow!.close()
        }
    }
    
    /// An accessory app never appears in Cmd-Tab, so the settings window would be
    /// unreachable from the keyboard once another app is in front. Run as a regular
    /// app while it is open and go back to living in the menu bar when it closes.
    private func updateActivationPolicy(preferencesOpen: Bool? = nil) {
        let open = preferencesOpen ?? (preferencesWindow?.isVisible == true || preferencesHiddenForSelector)
        NSApp.setActivationPolicy(open ? .regular : .accessory)
    }

    func windowWillStartLiveResize(_ notification: Notification) {
        if notification.object as? NSWindow === preferencesWindow {
            preferencesResizedByUser = true
        }
    }

    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === preferencesWindow {
            updateActivationPolicy(preferencesOpen: false)
            if let urls = linksAwaitingBrowserSettings {
                linksAwaitingBrowserSettings = nil
                Task { @MainActor in self.presentSelector(urls: urls) }
            }
            return
        }
        guard notification.object as? NSWindow === selectorWindow, preferencesHiddenForSelector else { return }
        preferencesHiddenForSelector = false
        preferencesWindow?.orderBack(nil)
    }
    
    func getScreenWithMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        let screens = NSScreen.screens
        let screenWithMouse = (screens.first { NSMouseInRect(mouseLocation, $0.frame, false) })
        
        return screenWithMouse
    }
}
