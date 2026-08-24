# Repository Instructions

- This repository contains independent Arch Linux packages. Keep package changes inside the affected top-level package directory; shared build and workflow changes are handled separately.
- When designing a new package, use the `create-package` skill at `.agents/skills/create-package/SKILL.md`.
- Each package is defined by `PKGBUILD`; keep its tracked `.SRCINFO` synchronized with `makepkg --printsrcinfo > .SRCINFO` from that package directory.
- After testing package functionality, check both metadata and the built archive with `namcap PKGBUILD` and `namcap pkgname.pkg.tar.zst`; namcap checks common `PKGBUILD` and hierarchy errors, shared-library dependencies in ELF files, and missing or redundant dependencies.
- Preserve the package-local `REUSE.toml` SPDX annotations when adding or changing package metadata files.

## Renovate-managed packages

- To enable Renovate for a package whose upstream publishes GitHub tags or releases, add a Renovate annotation to its `pkgver` assignment in `PKGBUILD`:
  `pkgver=1.2.3 # renovate: datasource=github-tags depName=OWNER/REPOSITORY`
- Use the upstream repository's `OWNER/REPOSITORY` value for `depName`; the repository's `renovate.json` removes an optional leading `v` from Git tags.
- Keep package source URLs, archive names, and any version-derived variables based on `pkgver` so Renovate's version replacement updates the downloadable source as well.
- Renovate updates the version only. On same-repository Renovate pull requests targeting `main` that change `*/PKGBUILD`, the `Update package metadata` workflow recalculates checksums with `updpkgsums`, regenerates `.SRCINFO`, and commits those files back to the Renovate branch. It does not update forks or unrelated pull requests.
- New packages using this pattern are picked up automatically. Packages whose upstream version is stored in another variable, or whose releases are not available through a supported Renovate datasource, require a corresponding custom-manager or datasource change before adding an annotation.

## Additional References
- https://wiki.archlinux.org/title/Creating_packages
- https://man.archlinux.org/man/PKGBUILD.5
