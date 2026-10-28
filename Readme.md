<img src="images/lotsen.png" width="128" height="128" alt="Lotsen icon: an orange pilot boat flying the pilot flag">

# Lotsen

![Illustration of the Lotsen selector opened from a link in a chat app, with Chrome profiles, shortcuts and the option to save a rule](images/screenshot.png)

Lotsen is a tiny browser selector for macOS written in SwiftUI. Set it as the default browser, assign shortcuts, and choose which app opens each link. Like a harbour pilot (*lots* in Swedish), it guides every link to the right place.

## Based on Browserino

Lotsen started as a fork of [Browserino](https://github.com/AlexStrNik/Browserino) by [Aleksandr Strizhnev](https://github.com/AlexStrNik), and most of what it does comes from Aleksandr's work and from the Browserino contributors. Browserino was in turn inspired by [Browserosaurus](https://github.com/will-stone/browserosaurus) by Will Stone. The fork was renamed once it had drifted far enough from the original that sharing a name would confuse people about which app they're running. It is not endorsed by the Browserino author, so please report Lotsen issues here rather than upstream.

On top of Browserino, Lotsen adds:

- **Browser profiles**: Chromium profiles show up as separate targets, with custom names, visibility and shortcuts (Browserino PRs [#48](https://github.com/AlexStrNik/Browserino/pull/48) and [#65](https://github.com/AlexStrNik/Browserino/pull/65)).
- **Move current tab**: send the open tab to another browser from the menu bar or a global shortcut ([#61](https://github.com/AlexStrNik/Browserino/pull/61)).
- **Missing apps** stay visible and editable instead of disappearing ([#63](https://github.com/AlexStrNik/Browserino/pull/63)).
- **Localization** in ten languages, with a manual language picker.
- **Rules**: write a rule as a simple wildcard pattern such as `https://example.com*` instead of a regex, or generate a regex from the URLs in Test URLs.
- **Modern macOS**: Swift 6, macOS 14 minimum ([#64](https://github.com/AlexStrNik/Browserino/pull/64)), Liquid Glass on macOS 26 and builds with the Xcode 27 SDK.

Lotsen has no Homebrew cask and no prebuilt releases yet, so you build it from source. If you want the original app, install it from [the Browserino repository](https://github.com/AlexStrNik/Browserino#installation).

# Installation

Requirements: macOS 14 or later and Xcode (the Command Line Tools alone can't build apps).

```bash
git clone https://github.com/simonauner/lotsen.git
cd lotsen
./scripts/install-local.sh
```

The script builds Lotsen, ad-hoc signs it, installs it to `/Applications` and launches it, replacing any running copy. Then pick Lotsen as the default browser in **System Settings → Desktop & Dock → Default web browser**.

### Coming from Browserino

On first launch Lotsen copies your Browserino settings (browsers, apps, rules, shortcuts and language), so nothing needs to be set up again. Links that use the old `browserino://` scheme keep working. Launch at login has to be turned on again in General.

Then uninstall Browserino so the two apps don't compete as the default browser. If you installed it with Homebrew:

```bash
brew uninstall --cask browserino
```

To update, pull and run the script again:

```bash
git pull && ./scripts/install-local.sh
```

Because the app is built on your own machine it has no quarantine flag, so Gatekeeper doesn't block it on first launch.

If you want to support Browserino's author, you can buy Browserino on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).

## Languages

The interface supports English, Russian, German, French, Spanish, Brazilian Portuguese, Italian, Japanese, Korean and Simplified Chinese. Lotsen follows the macOS preferred language order and falls back to English. Choose a language manually in General > Language, or select System default; changes take effect immediately and persist across launches. Translations are maintained in `Lotsen/Localizable.xcstrings` with semantic keys such as `settings.language.title`; displayed text belongs in the language values.

Validate translation coverage with `python3 scripts/check-localizations.py`.

## Browser profiles and tab transfer

Requires macOS 14 or later. The selector uses Liquid Glass on macOS 26 and later.

Chromium profiles appear in Browsers. Use Enable profiles to grant access to the browser data folder when macOS requires it. Profile names, visibility, shortcuts and rule/app destinations can be customized. Turning off profile display preserves those preferences.

Use Move current tab from the menu bar or assign its global shortcut in General. Allow Automation only for the browser you want to control. Closing the original is optional and disabled by default; Safari keeps its source tab open. Chromium closing requires the same original tab/window IDs and URL. Application launch success does not confirm that the destination page finished loading.

Browser authentication sessions may still require Safari. Release signing and notarization are separate from these development builds.

## Local development

`./scripts/install-local.sh` builds a Release build by default. The app icon is drawn in `images/icon/AppIcon.svg`; run `./scripts/build-icons.sh` after editing it to regenerate `Lotsen/Lotsen.icns` and the logo above. Set `CONFIGURATION=Debug` for a debug build; the build log is written to `build/xcodebuild.log`.

Browserino attribution and validation notes: [integration review](docs/UPSTREAM_REVIEW.md). KeyboardShortcuts is licensed under MIT; its notice is bundled with the app.

## License

Lotsen is free software under the [GNU General Public License v3](LICENSE), the same license as Browserino. Browserino is copyright © 2024 Aleksandr Strizhnev; the changes in Lotsen are copyright © 2026 Simon Aunér.
