#!/usr/bin/env bash
# Move x* chunk files one at a time from the parent dir into the repo,
# committing each with an incrementing numeric message and pushing.
set -euo pipefail

REPO="${1:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}"
SRC="$(dirname "$REPO")"
LOG="$SRC/push-chunks.log"
cd "$REPO"

# Mirror all output to a log outside the repo; follow it with: tail -f "$LOG"
exec > >(tee -a "$LOG") 2>&1
log() { echo "[$(date '+%H:%M:%S')] $*"; }
log "Started in $REPO (log: $LOG)"

while :; do
  file="$(find "$SRC" -maxdepth 1 -type f -name 'x*' -exec basename {} \; | sort | head -n 1)"
  if [ -z "$file" ]; then
    log "Done: no more x* files in $SRC"
    break
  fi

  last="$(git log -1 --format=%s)"
  if ! [[ "$last" =~ ^[0-9]+$ ]]; then
    log "Last commit message '$last' is not a number; stopping."
    exit 1
  fi
  next=$((last + 1))

  log "Moving $file"
  mv "$SRC/$file" "$REPO/$file"
  git add .
  git commit -q -m "$next"
  log "Committed $next, pushing..."
  git push -q origin main
  log "Pushed $file as commit $next ($(find "$SRC" -maxdepth 1 -type f -name 'x*' | wc -l | tr -d ' ') left)"
done
