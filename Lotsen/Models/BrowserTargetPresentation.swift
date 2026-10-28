import AppKit
import Foundation

extension BrowserTarget {
    var chromiumProfile: ChromiumProfile? {
        guard let profile else {
            return nil
        }

        return ChromiumProfileService.profiles(forAppAt: app)?
            .first { $0.directory == profile }
    }

    /// A profile the browser no longer knows about — the user switched machines,
    /// restored a backup, or deleted it in the browser.
    var hasMissingProfile: Bool {
        profile != nil && chromiumProfile == nil
    }

    /// "Chrome", or "Chrome — Work" for a profile.
    var displayName: String {
        displayName(bundle: Bundle(url: app)) { chromiumProfile }
    }

    /// The profile is only looked up when no alias names it, since that means
    /// reading the browser's Local State.
    fileprivate func displayName(bundle: Bundle?, chromiumProfile: () -> ChromiumProfile?) -> String {
        let browser = bundle?.appDisplayName ?? app.appDisplayName

        guard let profile else {
            return browser
        }

        let aliases = AppSettings.shared.profileNames
        let aliasKey = shortcutKey(bundleIdentifier: bundle?.bundleIdentifier ?? app.path)
        return "\(browser) — \(aliases[aliasKey] ?? chromiumProfile()?.name ?? profile)"
    }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: app.path)
    }

    var avatarImage: NSImage? {
        chromiumProfile?.avatar.flatMap(ChromiumProfileService.avatarImage)
    }
}

/// What a row shows for a target, resolved once. Each piece reads the app bundle
/// or the browser's profile data, which is too slow to repeat on every render.
struct BrowserTargetPresentation {
    let target: BrowserTarget
    let bundleIdentifier: String?
    let displayName: String
    let icon: NSImage
    let avatar: NSImage?

    /// nil when the app is no longer installed where the target points.
    init?(_ target: BrowserTarget) {
        guard let bundle = Bundle(url: target.app) else {
            return nil
        }

        let profile = target.chromiumProfile

        self.target = target
        bundleIdentifier = bundle.bundleIdentifier
        displayName = target.displayName(bundle: bundle) { profile }
        icon = target.icon
        avatar = profile?.avatar.flatMap(ChromiumProfileService.avatarImage)
    }
}
