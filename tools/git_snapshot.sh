#!/usr/bin/env bash
# Record the whole working tree (tracked + untracked, minus .gitignore) as a
# commit under refs/snapshots/<label>. HEAD, branches, the index and files are
# untouched, and plain `git push` does not send these refs. Prints the ref.
# Usage: tools/git_snapshot.sh <label>   (see docs/CODEX_ORCHESTRATION.md)
set -euo pipefail

label="${1:-}"
if [[ ! "$label" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ || "$label" == *..* ]]; then
  printf 'Usage: %s <label>  (letters, digits, ., _ and -; no ..)\n' "$0" >&2
  exit 2
fi
ref="refs/snapshots/$label"
cd "$(git rev-parse --show-toplevel)"

# Stage into a throwaway copy of the index so the real one keeps the user's
# staging. Copying keeps cached file stats, so unchanged large assets aren't
# rehashed.
tmp_index="$(mktemp)"
trap 'rm -f "$tmp_index"' EXIT
real_index="$(git rev-parse --git-path index)"
if [[ -f "$real_index" ]]; then cp "$real_index" "$tmp_index"; else rm -f "$tmp_index"; fi
tree="$(GIT_INDEX_FILE="$tmp_index" git add -A && GIT_INDEX_FILE="$tmp_index" git write-tree)"

parent=()
if head="$(git rev-parse -q --verify HEAD)"; then parent=(-p "$head"); fi
commit="$(git commit-tree "$tree" "${parent[@]}" -m "Snapshot: $label")"
# An empty old value makes update-ref fail rather than overwrite an existing label.
git update-ref -m "snapshot $label" "$ref" "$commit" ""
printf '%s\n' "$ref"
