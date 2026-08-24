---
name: create-package
description: Create a repo-compliant Arch Linux package from a GitHub releases URL or an existing AUR PKGBUILD.
---

# Create Package

Use this skill when designing a new package in this repository. Work from the
repository root and keep the package in a new top-level directory.

## Inputs

Obtain:

- A package name that matches `^[a-z0-9][a-z0-9@._+-]*$`.
- Either a GitHub repository or releases URL, or an AUR package name/URL.

Use a `-bin` suffix for packages that redistribute upstream prebuilt binaries.
Do not overwrite an existing package directory.

## Scaffold

Run the skill-owned scaffold script from the repository root:

```bash
bash .agents/skills/create-package/scripts/create.sh PACKAGE
```

It creates `PKGBUILD`, `.gitignore`, and package-local `REUSE.toml`. The
repository-root `build.sh` and `lint.sh` are shared CI tooling and must not be
copied into this skill's `scripts/` directory.

## GitHub Releases

1. Derive `OWNER/REPOSITORY` from the supplied URL.
2. Resolve the latest release and inspect its assets, using
   `gh api repos/OWNER/REPOSITORY/releases/latest` when available.
3. Select the correct asset for each supported architecture. Prefer upstream
   release archives over generated or repacked sources.
4. Keep the download URL and archive name derived from `pkgver`, for example:
   `${url}/releases/download/v${pkgver}/...`.
5. Annotate GitHub-tagged versions for Renovate:

   ```bash
   pkgver=1.2.3 # renovate: datasource=github-tags depName=OWNER/REPOSITORY
   ```

6. Generate checksums with `updpkgsums` after the source definition is final.

If the release uses a tag format or asset naming scheme that cannot be safely
represented using `pkgver`, document the limitation rather than adding a
fragile Renovate annotation.

## Existing AUR PKGBUILD

Fetch the source PKGBUILD, preferably from the AUR cgit endpoints:

```text
https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=PACKAGE
https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=PACKAGE
```

When adapting it:

- Keep the local maintainer first:
  `# Maintainer: Travis Lyons <pkgbuild at trly dot dev>`.
- Copy every upstream `# Maintainer:` and `# Contributor:` attribution as a
  `# Contributor:` line below the local maintainer. Preserve names and contact
  formatting; do not discard current AUR contributors.
- Add an attribution note such as:
  `# Adapted from https://aur.archlinux.org/cgit/aur.git/tree/PKGBUILD?h=PACKAGE`.
- Preserve useful packaging logic, but review all dependencies, sources,
  checksums, architecture declarations, install paths, and shell commands.
- Add a GitHub Renovate annotation when the upstream source supports it.

## PKGBUILD Requirements

Keep fields in this order:

1. Maintainer and contributor comments.
2. `pkgname`, internal version variables, `pkgver`, and `pkgrel`.
3. `pkgdesc`, `arch`, `url`, and `license`.
4. `depends`, `makedepends`, `checkdepends`, `provides`, and `conflicts`.
5. `options`, `install`, and `backup`.
6. Sources, architecture-specific sources, checksums, and signature keys.
7. Optional `prepare()`, `build()`, `check()`, `verify()`, and `package()`.

Use quoted paths and standard filesystem locations:

- Executables: `/usr/bin`.
- Licenses: `/usr/share/licenses/${pkgname}`.
- Documentation: `/usr/share/doc/${pkgname}`.
- Desktop files and icons: their standard `/usr/share` locations.
- Configuration: `/etc`, with `backup` when appropriate.

For prebuilt binaries, normally use `options=('!debug' '!strip')`. If the
package replaces an unsuffixed package, declare matching `provides` and
`conflicts` entries. Install upstream license and documentation files when
available. Use an appropriate Arch license identifier, including a
`LicenseRef-*` identifier when no standard identifier applies.

Verify upstream signatures when available. Store trusted keys under
`keys/pgp/`, declare fingerprints in `validpgpkeys`, and add `verify()` when
the signature layout needs custom validation. Extend the package-local
`REUSE.toml` annotation paths for any added metadata, keys, or install files.

## Finalize And Validate

From the repository root:

```bash
cd PACKAGE
makepkg --printsrcinfo > .SRCINFO
cd ..
./lint.sh PACKAGE
./build.sh PACKAGE
```

`lint.sh` runs `namcap PKGBUILD`; `build.sh` performs the repository's clean
chroot build through `pkgctl`. The build requires an Arch `base-devel`
environment, `devtools`, and a non-root build user. If it cannot run locally,
state that clearly and still run metadata checks that are available.

After a successful build, validate the archive as well:

```bash
cd PACKAGE
namcap PKGBUILD
namcap PACKAGE-*.pkg.tar.zst
```

Do not leave `TODO` placeholders, unsynchronized `.SRCINFO`, missing checksums,
or unexplained dependencies in the completed package. Summarize any checks
that could not run and why.
