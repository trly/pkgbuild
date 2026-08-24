#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Travis Lyons
# SPDX-License-Identifier: MIT

set -euo pipefail

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

repo_root=$(git rev-parse --show-toplevel)
package_dir=$repo_root/$package
if [[ -e $package_dir ]]; then
  printf 'Error: package directory already exists: %s\n' "$package" >&2
  exit 1
fi

mkdir -- "$package_dir"
cat > "$package_dir/PKGBUILD" <<EOF
# Maintainer: Travis Lyons <pkgbuild at trly dot dev>
pkgname=$package
pkgver=0.1.0
pkgrel=1
pkgdesc="TODO"
arch=('any')
url="TODO"
license=('MIT')
depends=()
source=()
sha256sums=()

package() {
  # TODO: install files into \${pkgdir}.
  :
}
EOF

cat > "$package_dir/.gitignore" <<'EOF'
/pkg/
/src/
/*.pkg.tar.*
/*.src.tar.*
EOF

cat > "$package_dir/REUSE.toml" <<'EOF'
version = 1

[[annotations]]
path = [".gitignore", ".SRCINFO", "PKGBUILD"]
precedence = "aggregate"
SPDX-FileCopyrightText = "Arch Linux Contributors"
SPDX-License-Identifier = "0BSD"
EOF
