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
