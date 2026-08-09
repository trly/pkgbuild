# trly/PKGBUILD

My personally maintained set of Arch Linux packages. This repository is intended
to allow me the ease of installing packages I need on any system without having
to review AUR PKGBUILDS before each install.

## Using the Repository

Packages are published to a pkgdepot instance running at [packages.trly.dev](https://packages.trly.dev)

Add the stable repository to `/etc/pacman.conf`:

```ini
[stable]
Server = https://packages.trly.dev/repos/stable/$arch
```

Then synchronize package databases and install packages with `pacman` as
usual:

```sh
sudo pacman -Syu
sudo pacman -S package-name
```

## Package Structure

Use one top-level directory per package. The directory name is the package
identifier used by the build scripts and release matrix, and must contain a
file named `PKGBUILD`.

A package directory normally contains:

```text
package-name/
  PKGBUILD
  .SRCINFO
  .gitignore
  REUSE.toml
  LICENSE
  keys/pgp/                 # only when source signatures are verified
  package-name.install      # only when install hooks are needed
  package-name.license      # only when upstream licensing requires it
```

Build outputs and downloaded sources stay untracked. Ignore `pkg/`, `src/`,
package archives, source archives, and package-specific downloaded source
files in the package's `.gitignore`.

Preserve the package-local `REUSE.toml` annotations when adding or changing
package metadata files. Keep `.SRCINFO` tracked and synchronized with the
`PKGBUILD`.

## PKGBUILD Conventions

Structure `PKGBUILD` files in the following order:

1. Maintainer comment.
2. Package identity and version: `pkgname`, optional internal version
   variables, `pkgver`, and `pkgrel`.
3. Description and package metadata: `pkgdesc`, `arch`, `url`, and `license`.
4. Package relationships and dependencies: `depends`, `makedepends`,
   `checkdepends`, `provides`, and `conflicts` as needed.
5. Build options and auxiliary files: `options`, `install`, and `backup` as
   needed.
6. Sources, architecture-specific sources, checksums, and signature keys.
7. Optional `prepare()`, `build()`, `check()`, `verify()`, and `package()`
   functions.

Use standard Arch packaging variables and quote paths that may contain shell
metacharacters. Keep version-derived URLs, archive names, and checksums tied
to `pkgver`. Use architecture-specific variables such as `source_x86_64` and
`sha256sums_x86_64` when upstream distributes different artifacts per
architecture.

Prefer upstream-provided release archives for binary packages. Set
`options=('!debug' '!strip')` when stripping or debug package generation is
not appropriate for a prebuilt binary. For packages that replace another
package, declare the relationship with `provides` and `conflicts` rather than
silently installing overlapping files.

Install files into `${pkgdir}` using `install` with explicit modes and the
standard filesystem locations:

- Executables in `/usr/bin`.
- Licenses in `/usr/share/licenses/${pkgname}`.
- Documentation in `/usr/share/doc/${pkgname}`.
- Desktop files and icons in their standard `/usr/share` locations.
- Configuration files in `/etc`, with `backup` when local changes should be
  preserved across upgrades.

Verify upstream signatures when they are available. Store trusted public keys
under `keys/pgp/`, declare their fingerprints in `validpgpkeys`, and implement
`verify()` when the archive format or upstream signature layout requires
custom verification. Checksums must cover every source that is not explicitly
skipped.

For GitHub-tagged or released upstream projects, annotate the `pkgver`
assignment so Renovate can update it:

```bash
pkgver=1.2.3 # renovate: datasource=github-tags depName=OWNER/REPOSITORY
```

Use the upstream `OWNER/REPOSITORY` value. The source URL and archive naming
must derive from `pkgver`; Renovate updates the version, while automation
updates checksums and `.SRCINFO`.

## Local Development

Create a package skeleton with:

```sh
./create.sh package-name
```

Replace the generated placeholders and add required package files. From the
package directory, regenerate metadata with:

```sh
makepkg --printsrcinfo > .SRCINFO
```

Run the metadata linter and a clean chroot build from the repository root:

```sh
./lint.sh package-name
./build.sh package-name
```

`build.sh` invokes `pkgctl build` and requires an Arch `base-devel`
environment, `devtools`, and a non-root build user. If a package depends on a
locally built package, pass it to `pkgctl build` with `-I` as appropriate.

After building, validate both the `PKGBUILD` and generated archive:

```sh
cd package-name
namcap PKGBUILD
namcap package-name-*.pkg.tar.zst
```

Increment `pkgrel` for packaging-only changes. Update `pkgver` for a new
upstream release and regenerate checksums and `.SRCINFO`.

## Automated Checks

Pull request CI:

- Runs ShellCheck on tracked shell scripts and `actionlint` on workflows.
- Discovers changed top-level directories containing a `PKGBUILD`.
- Rebuilds all packages when shared build scripts or package workflows change.
- Runs `namcap`, verifies that `.SRCINFO` matches `makepkg --printsrcinfo`,
  builds in an Arch clean chroot, and validates the resulting archive.

Changes outside package directories do not normally trigger package builds.
Changes to `build.sh`, `lint.sh`, or the package CI and publish workflows
trigger all package builds.

## Automated Releases

Packages are published by `.github/workflows/publish.yml` after a push to
`main`. To include a new package in automated releases:

1. Add a new top-level directory containing a valid `PKGBUILD`.
2. Commit its synchronized `.SRCINFO`, package `.gitignore`, and required
   metadata or verification files.
3. Add the directory name to the `jobs.build.strategy.matrix.package` list in
   `.github/workflows/publish.yml`.
4. Ensure the package builds successfully with `pkgctl build` and passes
   `namcap`.

The publish workflow builds every package in that matrix, uploads each
resulting `*.pkg.tar.zst` as a short-lived artifact, and publishes new
filenames to the `stable` repository with `pkgdepot`. It rejects duplicate
local filenames and refuses to republish a changed package under an existing
remote filename. A version or release change must therefore produce a new
archive filename.

Renovate pull requests that change `*/PKGBUILD` are handled by the metadata
workflow. For same-repository Renovate branches, it recalculates checksums,
regenerates `.SRCINFO`, and commits those updates back to the branch. The
pull request must still pass normal CI before it can reach `main` and the
release workflow.

## References

- [Arch Linux package creation](https://wiki.archlinux.org/title/Creating_packages)
- [`PKGBUILD(5)`](https://man.archlinux.org/man/PKGBUILD.5)
