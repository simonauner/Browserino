//
//  BrowserinoApp.swift
//  Browserino
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

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, BrowserSwitchPresenting {
    private var menuBarObservation: NSKeyValueObservation?
    private var selectorWindow: BrowserinoWindow?
    private var preferencesWindow: NSWindow?
    /// Set while the selector is up over a settings window that was sitting behind
    /// other apps, so closing the selector can put it back there.
    private var preferencesHiddenForSelector = false
    
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    
    var statusMenu: NSMenu!
    var statusBarItem: NSStatusItem!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
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
                NSApp.setActivationPolicy(.accessory)
            }
        }
        
        if UserDefaults.standard.object(forKey: "browsers") == nil {
            openPreferences()
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
        let targets = AppSettings.shared.browsers
        let hidden = AppSettings.shared.hiddenBrowsers
        guard TargetPolicy.visible(targets, hidden: hidden, profilesEnabled: UserDefaults.standard.object(forKey: "profilesEnabled") as? Bool != false).contains(where: { Bundle(url: $0.app) != nil && Bundle(url: $0.app)?.bundleIdentifier != snapshot.bundleIdentifier }) else {
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
        preferencesWindow!.contentView = NSHostingView(rootView: LocalizedRoot { PreferencesView() })
        
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
        
        preferencesHiddenForSelector = false
        NSApplication.shared.activate()
        
        preferencesWindow!.makeKeyAndOrderFront(nil)
        preferencesWindow!.orderFrontRegardless()
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        let processedUrls = urls.compactMap(\.browserinoIncomingURL)
        guard !processedUrls.isEmpty else { return }

        if processedUrls.count == 1 {
            let urlString = processedUrls.first!.absoluteString

            for rule in AppSettings.shared.rules {
                if let regex = rule.compiledRegex, urlString.firstMatch(of: regex) != nil {
                    BrowserUtil.openURL(
                        processedUrls,
                        target: rule.target,
                        isIncognito: false
                    )
                    return
                }
            }
        }
        
        presentSelector(urls: processedUrls)
    }

    private func presentSelector(urls: [URL], sourceTab: SourceTabSnapshot? = nil) {
        if selectorWindow == nil {
            selectorWindow = BrowserinoWindow()
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
        
        selectorWindow!.contentView = NSHostingView(
            rootView: LocalizedRoot { PromptView(urls: urls, sourceTab: sourceTab) }
        )
        
        selectorWindow!.makeKeyAndOrderFront(nil)
        selectorWindow!.isReleasedWhenClosed = false
        selectorWindow!.delegate = self
    }
    
    func clamp(min: CGFloat, max: CGFloat, value: CGFloat) -> CGFloat {
        CGFloat.minimum(CGFloat.maximum(min, value), max)
    }
    
    func windowDidResignKey(_ notification: Notification) {
        if notification.object as? NSWindow === selectorWindow, selectorWindow?.hidesOnDeactivate == true, selectorWindow?.presentingAlert == false {
            selectorWindow!.contentView = nil
            selectorWindow!.close()
        }
    }
    
    func windowWillClose(_ notification: Notification) {
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
