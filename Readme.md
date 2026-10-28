# Browserino

![Browserino](images/browserino.png?v2)

Browserino is a tiny browser selector for MacOS written in SwiftUI. Just set as default browser, assign shortcuts, and now you can choose in which application you want to open the link.

Inspired by great [Browserosaurus](https://github.com/will-stone/browserosaurus), but a little bit faster and smaller thanks to native code, and fixes annoying Electron bug.

# About this fork

This is a fork of [AlexStrNik/Browserino](https://github.com/AlexStrNik/Browserino). It adds the following on top of the original:

- **Browser profiles**: Chromium profiles show up as separate targets, with custom names, visibility and shortcuts (upstream PRs [#48](https://github.com/AlexStrNik/Browserino/pull/48) and [#65](https://github.com/AlexStrNik/Browserino/pull/65)).
- **Move current tab**: send the open tab to another browser from the menu bar or a global shortcut ([#61](https://github.com/AlexStrNik/Browserino/pull/61)).
- **Missing apps** stay visible and editable instead of disappearing ([#63](https://github.com/AlexStrNik/Browserino/pull/63)).
- **Localization** in ten languages, with a manual language picker.
- **Rules**: write a rule as a simple wildcard pattern such as `https://example.com*` instead of a regex, or generate a regex from the URLs in Test URLs.
- **Modern macOS**: Swift 6, macOS 14 minimum ([#64](https://github.com/AlexStrNik/Browserino/pull/64)), Liquid Glass on macOS 26 and builds with the Xcode 27 SDK.

The fork has no Homebrew cask and no prebuilt releases, so you build it from source. If you want the original app, install it from [the upstream repository](https://github.com/AlexStrNik/Browserino#installation).

# Installation

Requirements: macOS 14 or later and Xcode (the Command Line Tools alone can't build apps).

```bash
git clone https://github.com/simonauner/Browserino.git
cd Browserino
./scripts/install-local.sh
```

The script builds Browserino, ad-hoc signs it, installs it to `/Applications` and launches it, replacing any running copy. Then pick Browserino as the default browser in **System Settings → Desktop & Dock → Default web browser**.

If you already have the original installed with Homebrew, uninstall it first so the two copies don't compete:

```bash
brew uninstall --cask browserino
```

To update, pull and run the script again:

```bash
git pull && ./scripts/install-local.sh
```

Because the app is built on your own machine it has no quarantine flag, so Gatekeeper doesn't block it on first launch.

If you want to support the original author, you can buy Browserino on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).

## Languages

The interface supports English, Russian, German, French, Spanish, Brazilian Portuguese, Italian, Japanese, Korean and Simplified Chinese. Browserino follows the macOS preferred language order and falls back to English. Choose a language manually in General > Language, or select System default; changes take effect immediately and persist across launches. Translations are maintained in `Browserino/Localizable.xcstrings` with semantic keys such as `settings.language.title`; displayed text belongs in the language values.

Validate translation coverage with `python3 scripts/check-localizations.py`.

## Browser profiles and tab transfer

Requires macOS 14 or later. The selector uses Liquid Glass on macOS 26 and later.

Chromium profiles appear in Browsers. Use Enable profiles to grant access to the browser data folder when macOS requires it. Profile names, visibility, shortcuts and rule/app destinations can be customized. Turning off profile display preserves those preferences.

Use Move current tab from the menu bar or assign its global shortcut in General. Allow Automation only for the browser you want to control. Closing the original is optional and disabled by default; Safari keeps its source tab open. Chromium closing requires the same original tab/window IDs and URL. Application launch success does not confirm that the destination page finished loading.

Browser authentication sessions may still require Safari. Release signing and notarization are separate from these development builds.

## Local development

`./scripts/install-local.sh` builds a Release build by default. Set `CONFIGURATION=Debug` for a debug build; the build log is written to `build/xcodebuild.log`.

Upstream attribution and validation notes: [integration review](docs/UPSTREAM_REVIEW.md). KeyboardShortcuts is licensed under MIT; its notice is bundled with the app.
