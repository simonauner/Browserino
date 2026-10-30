# Homebrew releases

Lotsen uses the public `simonauner/homebrew-tap` repository and installs with:

```sh
brew install --cask simonauner/tap/lotsen
```

The tap starts with a README. `Casks/lotsen.rb` is added automatically only after
the first signed, notarized release is published. Until then, use the source
installation in the main README.

## One-time credentials

An Apple Developer Program membership and a **Developer ID Application**
certificate with its private key are required. Export that identity from Keychain
Access as a password-protected `.p12`. Do not use an Apple Development or Developer
ID Installer certificate.

Create a team App Store Connect API key for notarization, with the Developer role.
Keep the downloaded `.p8`, its key ID and issuer ID. See Apple's
[notarytool authentication guide](https://developer.apple.com/documentation/technotes/tn3147-migrating-to-the-latest-notarization-tool).

Add the following repository Actions secrets under
[Lotsen → Settings → Secrets and variables → Actions](https://github.com/simonauner/lotsen/settings/secrets/actions):

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Base64-encoded `.p12`, including the private key |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_NOTARY_KEY_P8` | Full text of the notarization `.p8` file |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API team issuer ID |
| `HOMEBREW_TAP_TOKEN` | Fine-grained GitHub token scoped only to `simonauner/homebrew-tap`, with Contents: read and write |

For example, upload the files directly with GitHub CLI, without pasting their
contents into chat or committing them:

```sh
base64 < /path/to/DeveloperID.p12 | gh secret set APPLE_CERTIFICATE_P12_BASE64 --repo simonauner/lotsen
gh secret set APPLE_CERTIFICATE_PASSWORD --repo simonauner/lotsen
gh secret set APPLE_NOTARY_KEY_P8 --repo simonauner/lotsen < /path/to/AuthKey.p8
gh secret set APPLE_NOTARY_KEY_ID --repo simonauner/lotsen
gh secret set APPLE_NOTARY_ISSUER_ID --repo simonauner/lotsen
gh secret set HOMEBREW_TAP_TOKEN --repo simonauner/lotsen
```

The default Actions token can publish a release in Lotsen, but cannot push to the
separate tap. The scoped tap token supplies that access. Keep all credentials in
Actions secrets. The macOS job imports Apple credentials into a temporary keychain
and removes the keychain and credential files even if the build fails.

## First release

Existing releases contain notes only. After configuring the secrets, use
`scripts/bump-version.sh patch` to give the first binary release an unused version,
then merge that bump to main. Do not move an existing tag to a different commit.

The Release workflow:

1. Detects a version change and checks the version/tag.
2. Builds a universal Release app for `arm64` and `x86_64`.
3. Signs nested code and the app with Developer ID, hardened runtime, a timestamp
   and Lotsen's Apple Events entitlement.
4. Waits for notarization, staples and validates the ticket, and checks Gatekeeper.
5. Publishes `Lotsen.zip`, containing the stapled app, to the GitHub release.
6. Downloads the published ZIP, verifies its checksum against the build, generates
   `Casks/lotsen.rb`, and commits it to the tap.

The cask keeps the ZIP's SHA-256 and the macOS 14 minimum. Normal uninstall removes
the app and leaves user preferences intact. No quarantine bypass is needed.

Check the first release on a Mac using the command above, then open Lotsen and
verify default-browser selection and the Automation permission for tab transfer.
This requires real signing credentials and cannot be validated by the generator
tests alone. Once verified, remove the pending-first-release notice from the main
README and update the tap README with the installation command.

## Later releases and recovery

Continue using the existing version-bump workflow. Every new version updates both
the GitHub download and the tap. Release workflows are serialized so their tap
updates do not run concurrently.

If the tap update fails after publishing, fix its token/permissions and use
**Re-run failed jobs** on that run. This retries the tap job against the published
ZIP without rebuilding or replacing the signed download.

The workflow can also be started manually on main for an unpublished version or
when its version tag points to that exact commit. Downloads are never overwritten;
if an asset was already uploaded and the publishing job failed afterwards, inspect
the draft/release before retrying. Publish a new version when rebuilding an already
published app.

Local checks:

```sh
python3 scripts/test-homebrew-cask.py
bash -n scripts/package-release.sh
```
