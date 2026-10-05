#!/usr/bin/env bash
# Commit chunk files matching $PATTERN in batches: each batch of N files
# is one commit with an incrementing numeric message, pushed to
# origin $BRANCH before the next batch starts. Chunks are taken from the
# repo's parent dir (moved in) and from untracked files in the repo root.
#
# Usage: push-chunks.sh [--batch N] [--prepare-only] [--yes] [repo]
#   --batch N       files per commit/push (default 5)
#   --prepare-only  prepare one batch, list it, and exit without pushing
#   --yes           push every batch without asking until no files remain
# With neither flag it asks on the terminal before each push.
# Re-run under bash if started as `sh push-chunks.sh`: sh can't parse >(...).
if [ -z "${BASH_VERSION:-}" ] || shopt -oq posix; then exec bash "$0" "$@"; fi

set -euo pipefail

# Override from the environment, e.g. BRANCH=main PATTERN='x*' push-chunks.sh
BRANCH="${BRANCH:-qwen3.8-27B-GGUF}"
PATTERN="${PATTERN:-x_qwen_*}"

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

# Chunk names still to commit: in the parent dir, or untracked in the repo root.
chunks() {
  {
    find "$SRC" -maxdepth 1 -type f -name "$PATTERN" -exec basename {} \;
    git ls-files --others --exclude-standard -- "$PATTERN" | { grep -v / || true; }
  } | sort -u
}
remaining() { chunks | grep -c . || true; }
pending() { git rev-list --count "origin/$BRANCH..HEAD"; }

commit_batch() {
  local last next files
  last="$(git log -1 --format=%s)"
  if ! [[ "$last" =~ ^[0-9]+$ ]]; then
    log "Last commit message '$last' is not a number; stopping."
    exit 1
  fi
  next=$((last + 1))
  files="$(chunks | head -n "$BATCH")"
  for f in $files; do
    [ -e "$REPO/$f" ] || mv "$SRC/$f" "$REPO/$f"
  done
  # Add only this batch, so other untracked chunks stay out of the commit.
  git add -- $files
  git commit -q -m "$next"
  log "Committed $(echo $files) as $next"
}

if [ "$MODE" = ask ] && ! { exec 3</dev/tty; } 2>/dev/null; then
  log "No terminal to ask for confirmation; use --prepare-only or --yes."
  exit 1
fi

log "Started in $REPO (branch $BRANCH, pattern $PATTERN, batch $BATCH, mode $MODE, log: $LOG)"
while :; do
  # Unpushed commits from an earlier run are pushed first as their own batch.
  n="$(pending)"
  if [ "$n" -eq 0 ]; then
    if [ "$(remaining)" -eq 0 ]; then
      log "Done: no more $PATTERN files and nothing left to push"
      break
    fi
    commit_batch
    n="$(pending)"
  fi

  log "Batch ready: $n unpushed commit(s), $(remaining) file(s) still waiting"
  git log --reverse --format='  commit %s:' --name-only "origin/$BRANCH..HEAD" | grep -v '^$'

  case "$MODE" in
    prepare)
      log "Prepared only; not pushing."
      exit 0 ;;
    ask)
      read -r -p "Push this batch? [y]es / [a]ll remaining batches without asking / [n]o: " ans <&3
      case "$ans" in
        y|Y) ;;
        a|A) MODE=all ;;
        *) log "Not pushing. $n commit(s) stay local; re-run to push them."; exit 0 ;;
      esac ;;
  esac

  log "Pushing $n commit(s)..."
  git push -q origin "$BRANCH"
  log "Pushed. $(remaining) file(s) left."
done

