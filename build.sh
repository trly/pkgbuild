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
if [[ ! -f $package_dir/PKGBUILD ]]; then
  printf 'Error: PKGBUILD not found: %s/PKGBUILD\n' "$package" >&2
  exit 1
fi

if ! command -v pkgctl >/dev/null 2>&1; then
  printf 'Error: pkgctl is required but was not found in PATH\n' >&2
  exit 127
fi

key_files=()
for key_file in "$package_dir"/keys/pgp/*.asc; do
  [[ -f $key_file ]] && key_files+=("$key_file")
done
if (( ${#key_files[@]} )); then
  gpg --batch --import "${key_files[@]}"
fi

cd -- "$package_dir"
exec pkgctl build
