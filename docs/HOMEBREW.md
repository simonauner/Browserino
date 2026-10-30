# Homebrew releases

Lotsen uses the public `simonauner/homebrew-tap` repository and installs with:

```sh
brew install --cask simonauner/tap/lotsen
```

Version 1.5.1 is the first binary release. Installation from the published tap has
been verified. The release workflow maintains `Casks/lotsen.rb` automatically.

## Signing and first launch

The universal app uses ad hoc signing with hardened runtime and the Apple Events
entitlement. No Apple Developer membership, certificate, API key or notarization
is required. Ad hoc signing does not establish a verified developer identity or
provide Apple's malware check.

macOS may block the first launch of the downloaded app. Try opening Lotsen, then
use **System Settings → Privacy & Security → Open Anyway** if you trust the download.
See [Apple's instructions](https://support.apple.com/en-gb/102445). Managed Macs may
not allow the exception. Homebrew displays this information after installation;
the cask does not remove quarantine or change system security settings.

## Tap credential

The tap uses a dedicated SSH deploy key with write access only to
`simonauner/homebrew-tap`. Its public key belongs under the tap's **Settings →
Deploy keys**, named `Lotsen release workflow`; its private key is the Actions
secret `HOMEBREW_TAP_SSH_KEY` in `simonauner/lotsen`.

The default Actions token publishes Lotsen's GitHub release. The deploy key lets
the checkout action push the cask update to the separate tap. No personal GitHub
token or `APPLE_*` secrets are used.

To rotate the deploy key, generate a new SSH key pair, add its public key to the
tap with write access, replace the private-key secret in Lotsen, then remove the
old deploy key. Never commit the private key or paste it into chat.

## Publishing a release

Use `scripts/bump-version.sh major|minor|patch` according to the changes, then merge
the version bump to main. Do not reuse a version or move an existing tag to a
different commit. Releases before 1.5.1 contain notes only.

The Release workflow:

1. Detects a version change and checks the version/tag.
2. Builds a universal Release app for `arm64` and `x86_64`.
3. Ad hoc signs nested code and the app, preserving the Apple Events entitlement,
   and verifies the signatures before creating `Lotsen.zip`.
4. Publishes `Lotsen.zip` to the GitHub release.
5. Downloads the published ZIP, verifies its checksum against the build, generates
   `Casks/lotsen.rb`, and commits it to the tap.

The cask keeps the ZIP's SHA-256 and the macOS 14 minimum. Normal uninstall removes
only the app and leaves user preferences intact.

When changing the distribution workflow, test installation from the published
tap and check first launch, default-browser selection and Automation permission
for tab transfer. Local package validation alone cannot confirm Gatekeeper's
behavior on another user's Mac.

## Later releases and recovery

Continue using the existing version-bump workflow. Every new version updates both
the GitHub download and the tap. Release workflows are serialized so their tap
updates do not run concurrently.

If the tap update fails after publishing, fix its deploy key/permissions and use
**Re-run failed jobs** on that run. This retries the tap job against the published
ZIP without rebuilding or replacing the download.

The workflow can also be started manually on main for an unpublished version or
when its version tag points to that exact commit. Downloads are never overwritten;
if an asset was already uploaded and the publishing job failed afterwards, inspect
the draft/release before retrying. Publish a new version when rebuilding an already
published app.

Local checks:

```sh
python3 scripts/test-homebrew-cask.py
bash -n scripts/package-release.sh
bash scripts/package-release.sh
```
