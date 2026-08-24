---
name: create-package
description: Create a trly/PKGBUILD compliant Arch Linux package from a GitHub releases URL or an existing AUR PKGBUILD.
---

# Create Package

Use this skill when designing a new package in this repository. Work from the
repository root and keep the package in a new top-level directory. Default to only x86_64 unless instructed otherwise.

## Inputs

Obtain:

- A package name matching `^[a-z0-9][a-z0-9@._+-]*$` and the Arch package-name
  length limit. (255 characters)
- Either a GitHub repository or releases URL, or an AUR package name/URL.

Use a `-bin` suffix for packages that redistribute upstream prebuilt binaries.
Do not overwrite an existing package directory. Before writing the final
PKGBUILD, confirm the upstream license, supported architectures, release format,
and runtime, build, and test requirements.

## Scaffold

Run the skill-owned scaffold script from the repository root:

```bash
bash .agents/skills/create-package/scripts/create.sh PACKAGE
```

It creates `PKGBUILD`, `.SRCINFO`, `.gitignore`, and package-local `REUSE.toml`.
The repository-root `build.sh` and `lint.sh` are shared CI tooling and must not
be copied into this skill's `scripts/` directory.

The generated PKGBUILD is deliberately an incomplete scaffold. Replace every
scaffold value and make `package()` install the intended files before treating
the package as complete.

## GitHub Releases

1. Derive `OWNER/REPOSITORY` from the supplied URL.
2. Resolve the latest release and inspect its assets, using
   `gh api repos/OWNER/REPOSITORY/releases/latest` when available.
3. Select the correct asset for each supported architecture. Prefer upstream
   release archives over generated or repacked sources. Use explicit
   `source_x86_64`/`source_aarch64` arrays when assets differ by architecture,
   with matching checksum arrays.
4. Keep download URLs and archive names derived from `pkgver`, for example:
   `${url}/releases/download/v${pkgver}/...`.
5. Annotate GitHub-tagged versions for Renovate:

   ```bash
   pkgver=1.2.3 # renovate: datasource=github-tags depName=OWNER/REPOSITORY
   ```

6. Generate checksums with `updpkgsums` after the source definition is final.
   Prefer the strongest checksum published by upstream (`b2`, then SHA-512,
   SHA-384, SHA-256, SHA-224, SHA-1, MD5, and finally CRC32). Never use `SKIP`
   for a downloadable release archive without documenting an unavoidable
   reason. `updpkgsums` rewrites existing checksum entries, including
   intentional `SKIP` entries. After running it, inspect the diff and restore
   documented `SKIP` values for mutable repository metadata or other sources
   that cannot be reproducibly hashed.

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
- Review all dependencies, source URLs, checksums, signatures, architecture
  declarations, install paths, and shell commands against current upstream.
- Add a GitHub Renovate annotation when the upstream source supports it.

## PKGBUILD Requirements

Keep fields in this order:

1. Maintainer and contributor comments.
2. `pkgname`, internal version variables, `pkgver`, `pkgrel`, and only an
   evidence-based `epoch` when version ordering requires it.
3. `pkgdesc`, `arch`, `url`, and `license`.
4. `groups`, `depends`, `makedepends`, `checkdepends`, and `optdepends`.
5. `provides`, `conflicts`, and `replaces` when their relationships are real.
6. `options`, `install`, `backup`, and `changelog` when needed.
7. Sources, `noextract`, architecture-specific sources, checksums, and
   signature keys.
8. Optional `prepare()`, `pkgver()`, `build()`, `check()`, `verify()`, and the
   required `package()` function.

Use Bash arrays and quote expansions. Keep the file non-interactive and
compatible with makepkg's Bash execution. Do not use `pkgbase` for these
single-output packages; it defaults to `pkgname`.

### Metadata

- `pkgname` must match `^[a-z0-9][a-z0-9@._+-]*$`, must not start with a dot or
  hyphen, and should match the package's public name where practical.
- `pkgver` must be a valid pacman version: no spaces or hyphens; translate an
  upstream hyphen to an underscore. `pkgver` may contain underscores. `pkgrel`
   is normally a positive integer. Reset it to `1` for a new upstream version
   and increment it for every packaging-only change, including changes to
   dependencies, architecture support, install paths, relations, source
   handling, or license metadata. Use `epoch` only to repair version ordering.
- Keep `pkgdesc` concise, useful, and preferably no longer than 80 characters;
  do not write it as a self-referential sentence. Set `arch=('any')` only for
  architecture-independent output; compiled or prebuilt binaries need explicit
  supported architectures.
- Use the official project URL and SPDX license identifiers. For a custom or
  proprietary license, use `LicenseRef-*` or `custom:*` and install its text
  under `/usr/share/licenses/${pkgname}`. Do not claim a license merely because
  it is convenient for the scaffold.

### Dependencies and Relations

- List every direct runtime dependency in `depends`, every build-only tool in
  `makedepends`, and test-only requirements in `checkdepends`. Do not duplicate
  runtime dependencies in `makedepends`; `base-devel` is implicit.
- Disable optional upstream features whose dependencies are not packaged, or
  declare those dependencies explicitly. Avoid automagic features selected by
  whatever happens to be installed on the build host.
- Describe optional functionality as `optdepends=('package: feature')` and use
  version constraints only where required. Inspect ELF requirements with
  `find-libdeps` and shipped libraries with `find-libprovides` when available.
- Never add `pkgname` to `provides` or `conflicts`. Add versioned `provides`
  for real compatibility alternatives, use `conflicts` only when packages
  cannot coexist, and reserve `replaces` for obsolete names upgraded
  automatically.

### Sources and Integrity

- Derive URLs, archive names, and checksums from `pkgver`. Use a unique
  `name::url` source name when an upstream filename could collide in `SRCDEST`.
  Pin VCS sources to a tag or commit when reproducibility matters.
- Use `noextract` only for sources that must remain untouched, and extract them
  explicitly in `prepare()` with the required tool in `makedepends`.
- When upstream publishes detached signatures, include the signature in
  `source`, set full uppercase `validpgpkeys` fingerprints, and keep trusted
  keys in package-local `keys/pgp/`. The host's temporary GPG keyring is not
  available inside clean-chroot builds, so `validpgpkeys` alone is insufficient
  for keys that are not in the Arch keyring. For those sources, name the
  downloaded signature with a `.signature` suffix rather than `.sig`, and use
  `verify()` to import the tracked key into a temporary `--homedir` and verify
  the archive there. Do not download keys from an untrusted build-time URL.
- Keep each integrity array aligned one-for-one with its corresponding source
  array, including architecture-specific arrays.
- `.install` files are referenced with the `install` variable and are detected
  automatically by makepkg; do not redundantly add them to `source`.
- Keep `.SRCINFO` and `pkgrel` updates in the same change as the PKGBUILD.

## Build Functions And Paths

Use quoted paths and standard filesystem locations:

- Executables: `/usr/bin`.
- Licenses: `/usr/share/licenses/${pkgname}`.
- Documentation: `/usr/share/doc/${pkgname}`.
- Desktop files and icons: their standard `/usr/share` locations.
- Configuration: `/etc`, with `backup` when appropriate.

`makepkg` provides absolute `srcdir` and `pkgdir` paths. Keep source changes in
`prepare()`, repeatable compilation in `build()`, tests in `check()`, and staged
installation in `package()`. `package()` is required; the other functions are
optional. A VCS package may use `pkgver()` after extraction to derive a valid
version without embedding a changing date in `pkgver`.

Install files with `install` rather than copying them, set executable modes
explicitly, and never write outside `${pkgdir}`. Use `DESTDIR="${pkgdir}"` for
staged installs; never run `make install` against the live filesystem. Do not
move build outputs from `${srcdir}` into `${pkgdir}`, because that breaks
`makepkg --repackage`.

For prebuilt binaries, normally use `options=('!debug' '!strip')`, declare
matching `provides`/`conflicts` when replacing an unsuffixed package, and
install upstream license and useful documentation files. Use an install script
only when a pacman lifecycle action is genuinely required; do not end an
`.install` script with `exit`.

## Finalize And Validate

From the repository root:

```bash
cd PACKAGE
updpkgsums                 # after source and signature entries are final
makepkg --printsrcinfo > .SRCINFO
cd ..
./lint.sh PACKAGE
makepkg --cleanbuild --clean --force
```

`lint.sh` runs ShellCheck with SC2034, SC2154, and SC2164 excluded, verifies
`.SRCINFO` against `makepkg --printsrcinfo`, runs `namcap` against `PKGBUILD`,
and runs `reuse lint`; use `./lint.sh all` to validate every package in one
invocation. `build.sh` performs the repository's clean-chroot build through
`pkgctl`; use it only for explicit clean-chroot validation. After a pull
request is opened, the required `Check and build packages` job in
`.github/workflows/test-packages.yml` invokes `./build.sh PACKAGE` for each
changed package in a privileged Arch container. That CI job is the authoritative
clean-chroot validation. Use
`makepkg --cleanbuild --clean --force` for initial development and local change
validation; it runs without root but requires the necessary dependencies to be
installed in the host environment. Do not use `--nodeps` as normal validation.
The clean-chroot build requires an Arch `base-devel` environment, `devtools`,
and a non-root build user with passwordless or already-authenticated `sudo`
when invoked as a non-root user. If local clean-chroot validation cannot run,
state that clearly; a local `makepkg` build is useful local validation but is
not equivalent to the required pull-request CI clean-chroot build.

After a successful build, validate the archive as well:

```bash
cd PACKAGE
archive=$(makepkg --packagelist)
namcap PKGBUILD
namcap "$archive"
pacman -Qip "$archive"
pacman -Qlp "$archive"
```

Test the installed application and, optionally, verify reproducibility with
`makerepropkg PACKAGE-*.pkg.tar.zst` from `devtools`.

Do not leave scaffold values, unsynchronized `.SRCINFO`, missing checksums,
unverified available signatures, unexplained dependencies, stale package
archives, or unexplained `SKIP` entries in the completed package. Summarize
any checks that could not run and why. For archive inspection, use the filename
from `makepkg --packagelist` or remove stale archives first; do not let a
wildcard validate an older build.
