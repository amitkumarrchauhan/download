#!/usr/bin/env bash
# Move x* chunk files one at a time from the parent dir into the repo,
# committing each with an incrementing numeric message and pushing.
set -euo pipefail

REPO="${1:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}"
SRC="$(dirname "$REPO")"
cd "$REPO"

while :; do
  file="$(find "$SRC" -maxdepth 1 -type f -name 'x*' -exec basename {} \; | sort | head -n 1)"
  if [ -z "$file" ]; then
    echo "Done: no more x* files in $SRC"
    break
  fi

  last="$(git log -1 --format=%s)"
  if ! [[ "$last" =~ ^[0-9]+$ ]]; then
    echo "Last commit message '$last' is not a number; stopping." >&2
    exit 1
  fi
  next=$((last + 1))

  mv "$SRC/$file" "$REPO/$file"
  git add .
  git commit -q -m "$next"
  git push -q origin main
  echo "Pushed $file as commit $next ($(find "$SRC" -maxdepth 1 -type f -name 'x*' | wc -l | tr -d ' ') left)"
done
