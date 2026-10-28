# Lotsen

## Versioning

Lotsen follows [semantic versioning](https://semver.org). The version lives in
`MARKETING_VERSION` in `Lotsen.xcodeproj/project.pbxproj`; never edit it by hand.

Every pull request that changes the app bumps the version exactly once, in its own
`chore: bump version to X.Y.Z` commit at the end of the branch:

```sh
scripts/bump-version.sh major|minor|patch
```

Pick the level from the largest change on the branch, using its conventional commits:

- **major**: anything that breaks existing users, such as settings or rules that no
  longer load, a removed feature, or a raised minimum macOS version. Commits marked
  `!` or with a `BREAKING CHANGE:` footer.
- **minor**: a new feature or user-visible behaviour (`feat`).
- **patch**: bug fixes and other changes to the shipped app that add nothing new
  (`fix`, `perf`, a `refactor` or translation change that reaches users).
- **none**: changes that don't touch the shipped app (`docs`, `test`, `ci`, build
  scripts, agent instructions).

If main moves on while a branch is open, rebase and re-run the bump against main's
version rather than keeping the old number, so two branches never ship the same one.

Merging a bump to main publishes the release: `.github/workflows/release.yml` tags
the merge commit `vX.Y.Z` and creates a GitHub release with notes generated from the
merged pull requests, so their titles are what users read. It fails if the tag
already exists, so never reuse a version.
