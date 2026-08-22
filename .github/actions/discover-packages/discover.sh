#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Travis Lyons
# SPDX-License-Identifier: MIT

set -euo pipefail

: "${HEAD_SHA:?head commit is required}"
: "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required}"
base_sha=${BASE_SHA:-}
full_rebuild_paths=${FULL_REBUILD_PATHS:-}
require_base=${REQUIRE_BASE:-false}

empty_tree=$(git hash-object -t tree /dev/null)
diff_base=$empty_tree
unavailable=
if [[ -z $base_sha || $base_sha =~ ^0+$ ]] ||
   ! git cat-file -e "${base_sha}^{commit}" 2>/dev/null ||
   ! git cat-file -e "${HEAD_SHA}^{commit}" 2>/dev/null; then
  unavailable='the base commit is unavailable'
elif ! diff_base=$(git merge-base "$base_sha" "$HEAD_SHA"); then
  unavailable='no merge base could be determined'
  diff_base=$empty_tree
fi

if [[ -n $unavailable ]]; then
  # Widening to every package is a safe over-approximation when the result is
  # only checked, but never when it is published: republishing an unchanged
  # package reproduces a filename that already exists in the repository.
  if [[ $require_base == true ]]; then
    echo "::error::Refusing to select packages because $unavailable; history was probably rewritten."
    exit 1
  fi
  echo "::warning::Selecting every current package because $unavailable."
fi

mapfile -t changed_files < <(git diff --name-only "$diff_base" "$HEAD_SHA")
mapfile -t rebuild_patterns < <(printf '%s\n' "$full_rebuild_paths" | sed '/^[[:space:]]*$/d')

# A change to a shared build input invalidates every package, not just the
# directories touched by the same commit, so widen the diff to the whole tree.
for path in "${changed_files[@]}"; do
  for pattern in "${rebuild_patterns[@]}"; do
    # shellcheck disable=SC2053 # patterns are supplied as globs on purpose
    if [[ $path == $pattern ]]; then
      echo "::notice::$path matches '$pattern'; selecting every current package."
      mapfile -t changed_files < <(git ls-tree -r --name-only "$HEAD_SHA")
      break 2
    fi
  done
done

declare -A seen=()
packages=()
for path in "${changed_files[@]}"; do
  [[ $path == */* ]] || continue
  package=${path%%/*}
  if [[ -z ${seen["$package"]+present} ]] &&
     git cat-file -e "$HEAD_SHA:$package/PKGBUILD" 2>/dev/null; then
    seen["$package"]=1
    packages+=("$package")
  fi
done

{
  printf 'packages='
  jq -cn '$ARGS.positional' --args "${packages[@]}"
} >> "$GITHUB_OUTPUT"
