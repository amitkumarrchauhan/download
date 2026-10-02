#!/usr/bin/env bash
# Move x* chunk files one at a time from the parent dir into the repo,
# one commit per file with an incrementing numeric message, and push
# them to origin main in batches.
#
# Usage: push-chunks.sh [--batch N] [--prepare-only] [--yes] [repo]
#   --batch N       commits per push (default 5)
#   --prepare-only  prepare one batch, list it, and exit without pushing
#   --yes           push every batch without asking until no files remain
# With neither flag it asks on the terminal before each push.
set -euo pipefail

BATCH=5; MODE=ask; REPO=""
while [ $# -gt 0 ]; do
  case "$1" in
    --batch) BATCH="$2"; shift 2 ;;
    --prepare-only) MODE=prepare; shift ;;
    --yes) MODE=all; shift ;;
    *) REPO="$1"; shift ;;
  esac
done
REPO="${REPO:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel)}"
SRC="$(dirname "$REPO")"
LOG="$SRC/push-chunks.log"
cd "$REPO"

# Mirror all output to a log outside the repo; follow it with: tail -f "$LOG"
exec > >(tee -a "$LOG") 2>&1
log() { echo "[$(date '+%H:%M:%S')] $*"; }

remaining() { find "$SRC" -maxdepth 1 -type f -name 'x*' | wc -l | tr -d ' '; }
pending() { git rev-list --count origin/main..HEAD; }

commit_next() {
  local file last next
  file="$(find "$SRC" -maxdepth 1 -type f -name 'x*' -exec basename {} \; | sort | head -n 1)"
  last="$(git log -1 --format=%s)"
  if ! [[ "$last" =~ ^[0-9]+$ ]]; then
    log "Last commit message '$last' is not a number; stopping."
    exit 1
  fi
  next=$((last + 1))
  mv "$SRC/$file" "$REPO/$file"
  git add .
  git commit -q -m "$next"
  log "Committed $file as $next"
}

if [ "$MODE" = ask ] && ! { exec 3</dev/tty; } 2>/dev/null; then
  log "No terminal to ask for confirmation; use --prepare-only or --yes."
  exit 1
fi

log "Started in $REPO (batch $BATCH, mode $MODE, log: $LOG)"
while :; do
  # Unpushed commits from an earlier run count toward the batch.
  while [ "$(pending)" -lt "$BATCH" ] && [ "$(remaining)" -gt 0 ]; do
    commit_next
  done

  n="$(pending)"
  if [ "$n" -eq 0 ]; then
    log "Done: no more x* files in $SRC and nothing left to push"
    break
  fi

  log "Batch ready: $n unpushed commit(s), $(remaining) file(s) still waiting"
  git log --reverse --format='  commit %s:' --name-only origin/main..HEAD | grep -v '^$'

  case "$MODE" in
    prepare)
      log "Prepared only; not pushing."
      exit 0 ;;
    ask)
      read -r -p "Push this batch? [y]es / [a]ll remaining without asking / [n]o: " ans <&3
      case "$ans" in
        y|Y) ;;
        a|A) MODE=all ;;
        *) log "Not pushing. $n commit(s) stay local; re-run to push them."; exit 0 ;;
      esac ;;
  esac

  log "Pushing $n commit(s)..."
  git push -q origin main
  log "Pushed. $(remaining) file(s) left."
done
