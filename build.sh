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

if [[ $1 != all ]]; then
  package=$1
  if [[ ! $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; then
    printf 'Error: invalid package name: %s\n' "$package" >&2
    exit 2
  fi
  if (( ${#package} > 255 )); then
    printf 'Error: package name is longer than 255 characters: %s\n' "$package" >&2
    exit 2
  fi
  if [[ ! -f $script_dir/$package/PKGBUILD ]]; then
    printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
    exit 1
  fi
fi

if (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then
    if ! sudo -n true 2>/dev/null; then
      printf 'Error: root privileges are required; passwordless sudo is unavailable in this non-interactive shell\n' >&2
      printf 'Run this command as root or authenticate with sudo before retrying.\n' >&2
      exit 1
    fi
    exec sudo -n \
      --preserve-env=SOURCE_DATE_EPOCH,MAKEFLAGS,MAKEPKG_CONF,PACKAGER,GPGKEY,PKGDEST,SRCDEST,LOGDEST,CCACHE_DIR \
      "$script_dir/build.sh" "$@"
  fi
  printf 'Error: root privileges are required to manage pkgctl chroots\n' >&2
  exit 1
fi

if ! command -v pkgctl >/dev/null 2>&1; then
  printf 'Error: pkgctl is required but was not found in PATH\n' >&2
  exit 127
fi

cd -- "$script_dir"

gnupg_home=$(mktemp -d)
chmod 700 "$gnupg_home"
trap 'rm -rf -- "$gnupg_home"' EXIT
export GNUPGHOME="$gnupg_home"

build_one() {
  local package=$1
  local package_dir="$script_dir/$package"

  local -a key_files=()
  for key_file in "$package_dir"/keys/pgp/*.asc; do
    [[ -f $key_file ]] && key_files+=("$key_file")
  done
  if (( ${#key_files[@]} )); then
    gpg --batch --import "${key_files[@]}"
  fi

  cd -- "$package_dir"
  printf '==> Building %s in a clean chroot\n' "$package" >&2
  pkgctl build
}

if [[ $1 == all ]]; then
  shopt -s nullglob
  mapfile -t packages < <(
    for pkgbuild in */PKGBUILD; do
      [[ -f $pkgbuild ]] && printf '%s\n' "${pkgbuild%%/*}"
    done
  )
  if (( ${#packages[@]} == 0 )); then
    printf 'Error: no PKGBUILD files found under %s\n' "$script_dir" >&2
    exit 1
  fi

  for package in "${packages[@]}"; do
    build_one "$package"
  done
  exit 0
fi

package=$1
if [[ ! $package =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; then
  printf 'Error: invalid package name: %s\n' "$package" >&2
  exit 2
fi

package_dir=$script_dir/$package
if [[ ! -f $package_dir/PKGBUILD ]]; then
  printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
  exit 1
fi

build_one "$package"
