//
//  GeneralTab.swift
//  Lotsen
//
//  Created by Aleksandr Strizhnev on 10.06.2024.
//

import SwiftUI
import UniformTypeIdentifiers
import ServiceManagement
import CoreFoundation
import KeyboardShortcuts
import Combine

/// SwiftUI reads and writes documents on a background thread, so this stays off the main actor.
nonisolated struct SettingsDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]

    // Serialized on the way in: [String: Any] cannot cross a Sendable boundary.
    private var data: Data

    init(settings: [String: Any] = [:]) {
        data = (try? JSONSerialization.data(withJSONObject: settings, options: .prettyPrinted)) ?? Data()
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents,
              let object = try? JSONSerialization.jsonObject(with: contents),
              object is [String: Any] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: data)
    }
}

struct GeneralTab: View {
    @Bindable private var localization = Localization.shared
    @AppStorage("switch_closeSourceTab") private var closeSourceTab = false
    @State private var isDefault = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var exportDocument = SettingsDocument()
    @State private var resetPresented = false
    @Environment(\.fitSettingsHeight) private var fitSettingsHeight
    @AppStorage("copy_closeAfterCopy") private var closeAfterCopy: Bool = false
    @AppStorage("copy_alternativeShortcut") private var alternativeShortcut: Bool = false
    @AppStorage("showInMenuBar") private var showInMenuBar: Bool = true
    @AppStorage("apps_atTop") private var appsAtTop: Bool = true

    func makeDefaultBrowser() async {
        defer { refreshIsDefault() }
        // Throws when the user declines the system prompt, which needs no alert
        // and no second prompt for https.
        do {
            try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "http")
            try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: "https")
        } catch {}
    }

    func refreshIsDefault() {
        isDefault = ["http:", "https:"].allSatisfy { scheme in
            guard let url = URL(string: scheme),
                  let application = NSWorkspace.shared.urlForApplication(toOpen: url) else { return false }
            return Bundle(url: application)?.bundleIdentifier == Bundle.main.bundleIdentifier
        }
    }

    func exportSettings() {
        let defaults = UserDefaults.standard
        let dictionary = defaults.dictionaryRepresentation()

        let appSettings = dictionary.filter { Self.settingsKeys.contains($0.key) }

        exportDocument = SettingsDocument(settings: appSettings)
        showingExportPicker = true
    }

    private static let settingsKeys = SettingsPolicy.keys

    func resetSettings() {
        let defaults = UserDefaults.standard
        KeyboardShortcuts.setShortcut(nil, for: .moveCurrentTab)
        defaults.removeObject(forKey: "browserDataAccess")
        Self.settingsKeys.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }

    func importSettings(from url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let settings = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            guard let settings = settings else {
                BrowserUtil.presentError(NSError(domain: "Lotsen", code: 2, userInfo: [NSLocalizedDescriptionKey: L10n.text("errors.invalid_settings_format")]), title: L10n.text("errors.import_settings.title"))
                return
            }

            let defaults = UserDefaults.standard
            let accepted = try SettingsPolicy.validate(settings)
            for (key, value) in accepted {
                if key == "KeyboardShortcuts_moveCurrentTab", let raw = value as? String {
                    let shortcut = try JSONDecoder().decode(KeyboardShortcuts.Shortcut.self, from: Data(raw.utf8))
                    KeyboardShortcuts.setShortcut(shortcut, for: .moveCurrentTab)
                } else { defaults.set(value, forKey: key) }
            }
        } catch {
            BrowserUtil.presentError(NSError(domain: "Lotsen", code: 2, userInfo: [NSLocalizedDescriptionKey: L10n.text("errors.invalid_settings_format")]), title: L10n.text("errors.import_settings.title"))
        }
    }

    var body: some View {
        Form {
            Section(L10n.text("settings.default_browser.title")) {
                if isDefault {
                    Label(L10n.text("settings.default_browser.active"), systemImage: "checkmark.circle.fill")
                } else {
                    LabeledContent(L10n.text("settings.default_browser.description")) {
                        Button(L10n.text("settings.default_browser.make_default")) {
                            Task { await makeDefaultBrowser() }
                        }
                    }
                }
                LabeledContent(L10n.text("settings.default_browser.test_description")) {
                    Button(L10n.text("settings.default_browser.test")) {
                        (NSApp.delegate as? AppDelegate)?.testBrowserPicker()
                    }
                }
            }

            Section {
                Picker(L10n.text("settings.language.title"), selection: $localization.selectedLanguage) {
                    Text(verbatim: L10n.text("settings.language.system_default")).tag("")
                    ForEach(LanguagePolicy.options, id: \.id) { option in
                        Text(verbatim: option.name).tag(option.id)
                    }
                }
            }

            Section {
                LabeledContent(L10n.text("tabs.transfer.title")) {
                    LocalizedShortcutRecorder().fixedSize()
                }
                Toggle(L10n.text("tabs.transfer.close_source"), isOn: $closeSourceTab)
            } footer: {
                Text(verbatim: L10n.text("tabs.transfer.safari_keep_source"))
            }

            Section(L10n.text("settings.copy_url.title")) {
                Toggle(L10n.text("settings.copy_url.close_after_copy"), isOn: $closeAfterCopy)
                Toggle(L10n.text("settings.copy_url.alternative_shortcut"), isOn: $alternativeShortcut)
            }

            Section(L10n.text("settings.appearance.title")) {
                Toggle(L10n.text("settings.appearance.apps_at_top"), isOn: $appsAtTop)
                Toggle(L10n.text("settings.appearance.show_menu_bar"), isOn: $showInMenuBar)
            }

            Section(L10n.text("settings.startup.title")) {
                Toggle(L10n.text("settings.startup.launch_at_login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }

            Section(L10n.text("settings.import_export.title")) {
                LabeledContent(L10n.text("settings.import_export.export_description")) {
                    Button(L10n.text("settings.import_export.export")) {
                        exportSettings()
                    }
                }
                LabeledContent(L10n.text("settings.import_export.import_description")) {
                    Button(L10n.text("settings.import_export.import")) {
                        showingImportPicker = true
                    }
                }
            }

            Section(L10n.text("settings.reset.title")) {
                LabeledContent(L10n.text("settings.reset.description")) {
                    Button(L10n.text("settings.reset.action")) {
                        resetPresented = true
                    }
                }
                .confirmationDialog(
                    L10n.text("settings.reset.confirmation"),
                    isPresented: $resetPresented
                ) {
                    Button(L10n.text("settings.reset.confirm"), role: .destructive) {
                        resetSettings()
                    }
                } message: {
                    Text(verbatim: L10n.text("settings.reset.confirmation_message"))
                }
            }
        }
        .formStyle(.grouped)
        .modifier(FitsSettingsHeight(fit: fitSettingsHeight))
        .onAppear(perform: refreshIsDefault)
        // The default browser can change in System Settings while this pane is open.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshIsDefault()
        }
        .fileExporter(
            isPresented: $showingExportPicker,
            document: exportDocument,
            contentType: .json,
            defaultFilename: "lotsen-settings"
        ) { result in
            if case .failure(let error) = result {
                BrowserUtil.presentError(error, title: L10n.text("errors.export_settings.title"))
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.json],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importSettings(from: url)
                }
            case .failure(let error):
                BrowserUtil.presentError(error, title: L10n.text("errors.import_settings.title"))
            }
        }
    }
}

/// Reports how far the form's content runs past what the window shows, so the
/// settings window can grow to fit it. The scroll geometry this needs arrived in
/// macOS 15; on 14 the window keeps its size and the form scrolls.
private struct FitsSettingsHeight: ViewModifier {
    let fit: FitSettingsHeightAction

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { geometry in
                // Measure what is visible, not what scrolls under the toolbar.
                geometry.contentSize.height - (geometry.containerSize.height - geometry.contentInsets.top - geometry.contentInsets.bottom)
            } action: { _, overflow in
                fit(overflow)
            }
        } else {
            content
        }
    }
}

#Preview {
    PreferencesView()
}

/// KeyboardShortcuts uses its own bundle language for its Cocoa recorder.
/// The recorder emits a recording-state notification; bridge it
/// to Lotsen's selected language, including first-responder transitions.
struct LocalizedShortcutRecorder: NSViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let view = KeyboardShortcuts.RecorderCocoa(for: .moveCurrentTab)
        context.coordinator.attach(view)
        view.placeholderString = L10n.text("shortcuts.recorder.assign")
        view.setAccessibilityPlaceholderValue(L10n.text("shortcuts.recorder.assign"))
        return view
    }
    func updateNSView(_ view: KeyboardShortcuts.RecorderCocoa, context: Context) {
        context.coordinator.refresh()
    }
    final class Coordinator {
        weak var view: KeyboardShortcuts.RecorderCocoa?
        private var observations: [AnyCancellable] = []
        private var placeholderObservation: NSKeyValueObservation?
        private var recording = false
        func attach(_ view: KeyboardShortcuts.RecorderCocoa) {
            self.view = view
            // The recorder puts its own placeholder back when it leaves a window,
            // which a Form does to its rows while laying them out, and when its
            // window loses key status, in a task that may run after ours. Answer
            // every reset rather than trying to come last.
            placeholderObservation = view.observe(\.placeholderString) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            let recorderState = Notification.Name("KeyboardShortcuts_recorderActiveStatusDidChange")
            for name in [recorderState, NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
                observations.append(NotificationCenter.default.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] notification in
                    let name = notification.name
                    let object = notification.object as AnyObject?
                    let active = notification.userInfo?["isActive"] as? Bool
                    MainActor.assumeIsolated {
                        guard let self, let view = self.view else { return }
                        if name == recorderState, let active { self.recording = active }
                        else if object === view.window { self.recording = false }
                        else { return }
                        self.refresh()
                    }
                })
            }
        }
        func refresh() {
            guard let view else { return }
            let label = L10n.text(recording ? "shortcuts.recorder.press_key" : "shortcuts.recorder.assign")
            // Only on a real change, since setting it reports back through the observation.
            if view.placeholderString != label {
                view.placeholderString = label
            }
            view.setAccessibilityPlaceholderValue(label)
        }
    }
}
