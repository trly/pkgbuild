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
if (( ${#package} > 255 )); then
  printf 'Error: package name is longer than 255 characters: %s\n' "$package" >&2
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package_dir=$script_dir/$package
if [[ ! -f $package_dir/PKGBUILD ]]; then
  printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
  exit 1
fi

for tool in diff makepkg namcap shellcheck; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Error: %s is required but was not found in PATH\n' "$tool" >&2
    exit 127
  fi
done

cd -- "$package_dir"
shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD

if [[ ! -f .SRCINFO ]]; then
  printf 'Error: .SRCINFO not found: %s/.SRCINFO\n' "$package" >&2
  exit 1
fi

generated_srcinfo=$(mktemp)
trap 'rm -f -- "$generated_srcinfo"' EXIT
makepkg --printsrcinfo > "$generated_srcinfo"
if ! diff --unified=3 .SRCINFO "$generated_srcinfo"; then
  printf 'Error: .SRCINFO is out of sync with PKGBUILD\n' >&2
  exit 1
fi

namcap PKGBUILD
