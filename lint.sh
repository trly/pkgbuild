#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Travis Lyons
# SPDX-License-Identifier: MIT

set -euo pipefail

usage() {
  printf 'Usage: %s PACKAGE|all\n' "${0##*/}" >&2
}

if (( $# != 1 )); then
  usage
  exit 2
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

for tool in diff makepkg namcap reuse shellcheck; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    printf 'Error: %s is required but was not found in PATH\n' "$tool" >&2
    exit 127
  fi
done

lint_package() {
  local package=$1
  local package_dir=$script_dir/$package
  local generated_srcinfo

  if [[ ! $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; then
    printf 'Error: invalid package name: %s\n' "$package" >&2
    return 2
  fi
  if (( ${#package} > 255 )); then
    printf 'Error: package name is longer than 255 characters: %s\n' "$package" >&2
    return 2
  fi
  if [[ ! -f $package_dir/PKGBUILD ]]; then
    printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
    return 1
  fi

  cd -- "$package_dir"
  shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD

  if [[ ! -f .SRCINFO ]]; then
    printf 'Error: .SRCINFO not found: %s/.SRCINFO\n' "$package" >&2
    return 1
  fi

  generated_srcinfo=$(mktemp)
  makepkg --printsrcinfo > "$generated_srcinfo"
  if ! diff --unified=3 .SRCINFO "$generated_srcinfo"; then
    rm -f -- "$generated_srcinfo"
    printf 'Error: .SRCINFO is out of sync with PKGBUILD\n' >&2
    return 1
  fi
  rm -f -- "$generated_srcinfo"

  namcap PKGBUILD
}

if [[ $1 == all ]]; then
  shopt -s nullglob
  mapfile -t packages < <(
    for pkgbuild in "$script_dir"/*/PKGBUILD; do
      package_dir=${pkgbuild%/PKGBUILD}
      printf '%s\n' "${package_dir##*/}"
    done
  )
else
  packages=("$1")
fi

if (( ${#packages[@]} == 0 )); then
  printf 'Error: no PKGBUILD files found under %s\n' "$script_dir" >&2
  exit 1
fi

for package in "${packages[@]}"; do
  printf '==> Linting %s\n' "$package" >&2
  lint_package "$package"
done

cd -- "$script_dir"
reuse lint
