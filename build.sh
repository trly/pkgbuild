#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage: %s [all] PACKAGE\n' "${0##*/}" >&2
}

if (( $# != 1 )); then
  usage
  exit 2
fi

if ! command -v pkgctl >/dev/null 2>&1; then
  printf 'Error: pkgctl is required but was not found in PATH\n' >&2
  exit 127
fi

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if (( EUID != 0 )); then
  if command -v sudo >/dev/null 2>&1; then
    exec sudo \
      --preserve-env=PATH,SOURCE_DATE_EPOCH,MAKEFLAGS,MAKEPKG_CONF,PACKAGER,GPGKEY,GNUPGHOME,PKGDEST,SRCDEST,LOGDEST,CCACHE_DIR \
      "$script_dir/build.sh" "$@"
  fi
  printf 'Error: root privileges are required to manage pkgctl chroots\n' >&2
  exit 1
fi

cd -- "$script_dir"

build_one() {
  local package=$1
  local package_dir=$script_dir/$package

  key_files=()
  for key_file in "$package_dir"/keys/pgp/*.asc; do
    [[ -f $key_file ]] && key_files+=("$key_file")
  done
  if (( ${#key_files[@]} )); then
    gpg --batch --import "${key_files[@]}"
  fi

  cd -- "$package_dir"
  pkgctl build
}

if [[ $1 == all ]]; then
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
