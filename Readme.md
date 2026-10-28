# Browserino

![Browserino](images/browserino.png?v2)

Browserino is a tiny browser selector for MacOS written in SwiftUI. Just set as default browser, assign shortcuts, and now you can choose in which application you want to open the link.

Inspired by great [Browserosaurus](https://github.com/will-stone/browserosaurus), but a little bit faster and smaller thanks to native code, and fixes annoying Electron bug.

# Installation

```bash
brew tap AlexStrNik/Browserino
brew trust alexstrnik/browserino
brew install browserino
```

`brew trust` is required on newer Homebrew versions to load casks from third-party taps. The `--no-quarantine` flag has been removed from Homebrew.

Or download Browserino from the [releases page](https://github.com/AlexStrNik/Browserino/releases).

## "Apple could not verify Browserino.app is free of malware"

Browserino is not notarized by Apple, so Gatekeeper blocks it on first launch. To allow it, either:

- Try to open Browserino, click **Done**, then go to **System Settings → Privacy & Security**, scroll to the **Security** section at the bottom and click **Open Anyway**, or
- Remove the quarantine flag from Terminal:

  ```bash
  xattr -dr com.apple.quarantine /Applications/Browserino.app
  ```

If you want to support the app, you can buy it on [Gumroad](https://alexstrnik.gumroad.com/l/browserino).

## Languages

The interface supports English, Russian, German, French, Spanish, Brazilian Portuguese, Italian, Japanese, Korean and Simplified Chinese. Browserino follows the macOS preferred language order and falls back to English. Choose a language manually in General > Language, or select System default; changes take effect immediately and persist across launches. Translations are maintained in `Browserino/Localizable.xcstrings` with semantic keys such as `settings.language.title`; displayed text belongs in the language values.

Validate translation coverage with `python3 scripts/check-localizations.py`.

## Browser profiles and tab transfer

Requires macOS 14 or later. The selector uses Liquid Glass on macOS 26 and later.

Chromium profiles appear in Browsers. Use Enable profiles to grant access to the browser data folder when macOS requires it. Profile names, visibility, shortcuts and rule/app destinations can be customized. Turning off profile display preserves those preferences.

Use Move current tab from the menu bar or assign its global shortcut in General. Allow Automation only for the browser you want to control. Closing the original is optional and disabled by default; Safari keeps its source tab open. Chromium closing requires the same original tab/window IDs and URL. Application launch success does not confirm that the destination page finished loading.

Browser authentication sessions may still require Safari. Release signing and notarization are separate from these development builds.

## Local development

Run `./scripts/install-local.sh` to build Browserino, ad-hoc sign it and install it to `/Applications`, replacing any running copy. Uninstall the Homebrew cask first so the two copies don't compete. Set `CONFIGURATION=Debug` for a debug build; the build log is written to `build/xcodebuild.log`.

Upstream attribution and validation notes: [integration review](docs/UPSTREAM_REVIEW.md). KeyboardShortcuts is licensed under MIT; its notice is bundled with the app.
