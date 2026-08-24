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

## Creating Packages

Use the `create-package` skill at
`.agents/skills/create-package/SKILL.md` when creating a package from a GitHub
release or an existing AUR PKGBUILD. It contains the repository's PKGBUILD,
attribution, Renovate, licensing, and validation requirements.

## Local Development

From a package directory, regenerate metadata with:

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
3. Ensure the package builds successfully with `pkgctl build` and passes
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
