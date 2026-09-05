#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Travis Lyons
# SPDX-License-Identifier: MIT

set -euo pipefail
umask 022

usage() {
  printf 'Usage: %s PACKAGE\n' "${0##*/}" >&2
}

if (( $# != 1 )); then
  usage
  exit 2
fi

package=$1
if [[ ! $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; then
  printf 'Error: invalid package name: %s\n' "$package" >&2
  exit 2
fi
if (( ${#package} > 255 )); then
  printf 'Error: package name is longer than 255 characters: %s\n' "$package" >&2
  exit 2
fi

if ! repo_root=$(git rev-parse --show-toplevel 2>/dev/null); then
  printf 'Error: must be run inside the package repository\n' >&2
  exit 1
fi

if ! command -v makepkg >/dev/null 2>&1; then
  printf 'Error: makepkg is required to generate .SRCINFO\n' >&2
  exit 127
fi

package_dir="$repo_root/$package"
if [[ -e $package_dir ]]; then
  printf 'Error: package directory already exists: %s\n' "$package" >&2
  exit 1
fi

mkdir -- "$package_dir"
cat > "$package_dir/PKGBUILD" <<EOF
# Maintainer: Travis Lyons <pkgbuild at trly dot dev>
# Replace every scaffold value and implement package() before building.
pkgname=$package
pkgver=0.1.0
pkgrel=1
pkgdesc="Package description"
arch=('x86_64')
url="https://example.com/"
license=()

depends=()
makedepends=()
checkdepends=()
optdepends=()
provides=()
conflicts=()
replaces=()

options=()
backup=()
source=()
sha256sums=()

package() {
  printf '%s\\n' 'Populate package() before building this scaffold.' >&2
  return 1
}
EOF

cat > "$package_dir/.gitignore" <<'EOF'
/pkg/
/src/
/*.pkg.tar.*
/*.src.tar.*
/*.tar.*
/*.tgz
/*.zip
EOF

cat > "$package_dir/REUSE.toml" <<'EOF'
version = 1

[[annotations]]
path = [".gitignore", ".SRCINFO", "PKGBUILD"]
precedence = "aggregate"
SPDX-FileCopyrightText = "Arch Linux Contributors"
SPDX-License-Identifier = "0BSD"
EOF

(cd -- "$package_dir" && makepkg --printsrcinfo > .SRCINFO)
