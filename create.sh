#!/usr/bin/env bash
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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$script_dir/$package
if [[ -e $package_dir ]]; then
  printf 'Error: package directory already exists: %s\n' "$package" >&2
  exit 1
fi

mkdir -- "$package_dir"
cat > "$package_dir/PKGBUILD" <<EOF
# Maintainer: TODO
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
