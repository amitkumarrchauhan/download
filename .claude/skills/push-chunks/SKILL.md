---
name: push-chunks
description: Move x* chunk files one at a time from the parent directory into this repo, committing each with the next numeric message (5, 6, ...) and pushing to origin main, until none remain. Use when the user asks to push/upload the remaining chunks or x files.
---

# Push chunks

Run the bundled script in the background (it can take a long time — one push per ~20MB file):

```bash
.claude/skills/push-chunks/push-chunks.sh
```

For each iteration the script:
1. Picks the first `x*` file (sorted) in the repo's parent directory.
2. Moves it into the repo directory.
3. Runs `git add .`
4. Runs `git commit -m '<N>'` where N = last commit message + 1.
5. Runs `git push origin main`.

It stops when no `x*` files remain in the parent, or on the first error
(e.g. push failure).

Progress is printed to the console and appended to `push-chunks.log` in
the repo's parent directory (outside the repo, so it is never committed).
Tell the user they can watch it live in a terminal with:

```bash
tail -f ../push-chunks.log
```

Before starting, check that another run isn't already going
(`pgrep -f push-chunks.sh`); two runs at once would race on the same files. The script is safe to re-run: it resumes from
whatever is left. If it fails, report the error output to the user
rather than retrying blindly — a moved-but-unpushed file will be picked
up by the next commit/push on re-run.
