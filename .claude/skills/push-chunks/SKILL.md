---
name: push-chunks
description: Commit chunk files (default x_qwen_*) from the parent directory or untracked in this repo, 5 files per commit with the next numeric message, pushing each commit to origin <branch> (default qwen3.8-27B-GGUF) after confirmation, until none remain. Use when the user asks to push/upload the remaining chunks or x files.
---

# Push chunks

The script `.claude/skills/push-chunks/push-chunks.sh` takes the next 5
files matching `$PATTERN` (sorted) — moving them in from the repo's parent
directory, or using untracked ones already in the repo root — runs
`git add` on just those files and `git commit -m '<N>'` (N = last commit
message + 1) as a single commit, then pushes it to `origin $BRANCH` before
starting the next batch. Unpushed
commits left over from an earlier run are pushed first as their own batch.

Branch and file pattern are shell variables at the top of the script
(defaults `BRANCH=qwen3.8-27B-GGUF`, `PATTERN='x_qwen_*'`) and can be
overridden from the environment, e.g.
`BRANCH=main PATTERN='x*' .claude/skills/push-chunks/push-chunks.sh --prepare-only`.

Before starting, check that no run is already going
(`pgrep -f push-chunks.sh`); two runs at once would race on the same files.

## Steps

1. Prepare one batch (foreground, quick — no network):
   ```bash
   .claude/skills/push-chunks/push-chunks.sh --prepare-only
   ```
2. Show the user the batch it listed (commit numbers and files) and ask
   with AskUserQuestion:
   - **Push this batch** — run `git push origin "$BRANCH"` (default `qwen3.8-27B-GGUF`), then go back to step 1
     and ask again for the next batch.
   - **Push all remaining** — run in the background without further prompts:
     ```bash
     .claude/skills/push-chunks/push-chunks.sh --yes
     ```
   - **Don't push** — stop; the prepared commits stay local and are pushed
     by the next run.
3. With "Push all remaining" the script loops: commit 5 files, push,
   commit the next 5, push, ... until no files remain.
4. If the script prints "Done", report that everything is pushed.

If any step fails, report the error output to the user rather than
retrying blindly.

## Watching progress

Everything is printed and also appended to `push-chunks.log` in the
repo's parent directory (outside the repo, so never committed). Tell the
user they can follow it live with:

```bash
tail -f ../push-chunks.log
```

Run directly in a terminal with no flags, the script asks
`[y]es / [a]ll / [n]o` before each push itself.
