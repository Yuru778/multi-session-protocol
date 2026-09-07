#!/bin/sh
# watch-mailbox.sh - offset-based watcher for a shared file mailbox.
#
# Prints only the bytes appended since the last check, and filters out FYI lines
# (that level was never meant to wake you).
#
# Why not `tail -F`: if the other side rewrites the file (new inode) or truncates
# it, `tail -F` replays the entire history into your context. This script realigns
# its offset to the new length instead, so nothing is replayed.
#
# Trade-off: if the other side does rewrite the file to something shorter, that
# rewrite's content is skipped. That is deliberate - losing one message beats
# replaying twenty. The real fix is for both sides to only ever append with `>>`.
#
# Usage:
#   ./watch-mailbox.sh <mailbox>/<peer>-to-<me>.md [more files ...]
#   WATCH_INTERVAL=5 ./watch-mailbox.sh <mailbox>/<peer>-to-<me>.md
#
# Claude-to-Claude does not need this: anything worth a wake-up goes through
# SendMessage. This is for peers that cannot receive it, such as a non-Claude
# agent writing into a shared file.
#
# Portable POSIX sh: works with macOS's stock /bin/sh and bash 3.2, Linux dash
# and bash, and busybox. On native Windows use watch-mailbox.ps1 instead.

set -u

if [ $# -lt 1 ]; then
  echo "usage: $0 <mailbox-file> [more files ...]" >&2
  exit 1
fi

INTERVAL=${WATCH_INTERVAL:-2}

# GNU coreutils uses -c%s, BSD/macOS uses -f%z. Missing file counts as 0.
fsize() {
  stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0
}

# Offsets live in a temp dir, one file per argument index, because POSIX sh has
# no associative arrays (and macOS ships bash 3.2, which has none either).
state=$(mktemp -d "${TMPDIR:-/tmp}/watch-mailbox.XXXXXX") || exit 1
cleanup() { rm -rf "$state"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

i=0
for f in "$@"; do
  i=$((i + 1))
  fsize "$f" > "$state/$i"
done

while :; do
  i=0
  for f in "$@"; do
    i=$((i + 1))
    size=$(fsize "$f")
    off=$(cat "$state/$i")

    if [ "$size" -gt "$off" ]; then
      # Read only the new region, keep message lines, drop FYI.
      tail -c "+$((off + 1))" "$f" 2>/dev/null | head -c "$((size - off))" \
        | grep -E '^\[' \
        | grep -vE '^\[[A-Za-z0-9_-]+ [0-9:]+\][[:space:]]*FYI'
      echo "$size" > "$state/$i"
    elif [ "$size" -lt "$off" ]; then
      # Truncated or replaced: realign, do not replay.
      echo "$size" > "$state/$i"
    fi
  done
  sleep "$INTERVAL"
done
