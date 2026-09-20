# Repository Instructions

- This repository contains independent Arch Linux packages. Keep package changes inside the affected top-level package directory; shared build and workflow changes are handled separately.
- When designing a new package, use the `create-package` skill at `.agents/skills/create-package/SKILL.md`.
- Each package is defined by `PKGBUILD`; keep its tracked `.SRCINFO` synchronized with `makepkg --printsrcinfo > .SRCINFO` from that package directory.
- After testing package functionality, check both metadata and the built archive with `namcap PKGBUILD` and `namcap pkgname.pkg.tar.zst`; namcap checks common `PKGBUILD` and hierarchy errors, shared-library dependencies in ELF files, and missing or redundant dependencies.
- Preserve the package-local `REUSE.toml` SPDX annotations when adding or changing package metadata files.
- Increment `pkgrel` for every packaging-only change, including dependency, architecture, install-path, relation, source-handling, and license-metadata changes; regenerate `.SRCINFO` in the same change.
- Treat `SKIP` checksums as exceptional and documented. Inspect the diff after `updpkgsums`, which can replace intentional `SKIP` entries for mutable metadata sources.
- For detached signatures from package-specific upstream keys, use a tracked key in `keys/pgp/` and an isolated `verify()` function that imports it into a temporary GPG home. Do not rely on the host keyring being available inside clean-chroot builds; use a `.signature` source suffix when bypassing makepkg's automatic `.sig` verification.
- Prefer `./lint.sh all` for repository-wide validation. It checks ShellCheck, `.SRCINFO`, `namcap`, and REUSE annotations.
- Use `makepkg --cleanbuild --clean --force` for initial package development and local change validation. Ensure build and runtime dependencies are installed; do not use `--nodeps` as normal validation.
- Use `./build.sh` for clean-chroot validation. The `Check and build packages` job in `.github/workflows/test-packages.yml` invokes it as a required pull-request CI check for every changed package; this CI job runs in a privileged Arch container and is the authoritative clean-chroot validation. If local sudo cannot run non-interactively, report that local clean-chroot validation is unavailable rather than presenting a local `makepkg` build as equivalent.

## Renovate-managed packages

- To enable Renovate for a package whose upstream publishes GitHub tags or releases, add a Renovate annotation to its `pkgver` assignment in `PKGBUILD`:
  `pkgver=1.2.3 # renovate: datasource=github-tags depName=OWNER/REPOSITORY`
- Use the upstream repository's `OWNER/REPOSITORY` value for `depName`; the repository's `renovate.json` removes an optional leading `v` from Git tags.
- The `github-tags` datasource matches tags, not releases. When upstream tags versions without publishing releases with assets, the update pull request cannot build; add an `allowedVersions` rule to `renovate.json` (for example `"allowedVersions": "<2"`) and let Renovate close that update until real releases exist.
- Keep package source URLs, archive names, and any version-derived variables based on `pkgver` so Renovate's version replacement updates the downloadable source as well.
- Renovate updates the version only. On same-repository Renovate pull requests targeting `main` that change `*/PKGBUILD`, the `Update package metadata` workflow recalculates checksums with `updpkgsums`, regenerates `.SRCINFO`, and commits those files back to the Renovate branch. It does not update forks or unrelated pull requests.
- A Renovate pull request that fails `Check package metadata` on the `.SRCINFO` diff usually means the `Update package metadata` workflow has not pushed its metadata commit yet; check that workflow's latest run for the pull request first. After fixing the workflow, re-run its failed runs instead of hand-editing `.SRCINFO` on the branch.
- The `Update package metadata` workflow pushes its commit with the `METADATA_PUSH_TOKEN` repository secret; a push failure with a git credentials error means the token expired. Rotate the secret and re-run the failed workflow runs.
- New packages using this pattern are picked up automatically. Packages whose upstream version is stored in another variable, or whose releases are not available through a supported Renovate datasource, require a corresponding custom-manager or datasource change before adding an annotation.

## Package publishing

- Pushes to `main` trigger the `Publish main` workflow, which builds and publishes only the packages the push touches and refuses to overwrite an already-published filename. Only a new `pkgver`, release, or `pkgrel` produces a publishable filename.
- Publish runs queue behind a running publish instead of cancelling it, so merging to `main` while a publish is in flight never aborts publishing; the queued run publishes its own diff afterward.
- A package update that merged to `main` without being published (for example, under the previous cancel-in-progress behavior) is recovered with a `pkgrel` bump merged to `main`. Re-running the cancelled run cannot recover it: the workflow's `Confirm main is current` checks reject superseded commits.

## Additional References
- https://wiki.archlinux.org/title/Creating_packages
- https://man.archlinux.org/man/PKGBUILD.5
