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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$script_dir/$package
if [[ ! -f $package_dir/PKGBUILD ]]; then
  printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
  exit 1
fi

if ! command -v namcap >/dev/null 2>&1; then
  printf 'Error: namcap is required but was not found in PATH\n' >&2
  exit 127
fi

cd -- "$package_dir"
exec namcap PKGBUILD
