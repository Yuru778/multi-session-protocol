# Contributing

Issues and pull requests are welcome. This is a small repository — one `SKILL.md`, one script, two
READMEs — so there is no process to learn beyond what is below.

## What helps most

**Windows support.** Two gaps, both in the file half of the protocol: there is no lock helper and no
watcher. `SKILL.md` sketches the `FileMode.CreateNew` lock that matches `noclobber`, but nobody has
shipped or run it. A port closes the bigger of the two. So does a report that WSL 2 is good enough in
practice — that is a real answer, not a consolation prize.

**macOS verification.** `scripts/watch-mailbox.sh` has been exercised under `sh`, `dash` and `bash`
on Linux only. It avoids bash 4 features and carries a BSD `stat` fallback for macOS, and neither has
been run on a Mac. Saying whether it works is a contribution; so is a patch if it does not.

**Failure modes worth adding.** If a rule here cost you something in practice, or a mistake bit you
that the table in `SKILL.md` does not list, open an issue describing what happened. That table earns
its place by being specific, so a concrete account of what broke beats a general suggestion.

**Corrections.** The specification summary tracks Claude Code's documented behavior and will drift as
the product changes. Name the version where a claim stopped being true and it gets fixed.

## House rules

**Keep the skill generic.** No project names, no personal paths, no real session names. Use `<me>`,
`<peer>` and `<mailbox>` throughout. A rule that only makes sense inside one team's setup belongs in
that team's notes, not here.

**Language.** `SKILL.md` and the scripts are English-only. `README.zh-TW.md` mirrors `README.md`, so
a change to one belongs in the other; the two are expected to carry the same sections in the same
order.

**Claims match evidence.** If you write that something works on a platform, say whether you ran it
there. "Should work, unverified" is an acceptable and useful statement in this repository — an
unmarked claim that turns out to be untested is not.

**Shell portability.** `scripts/watch-mailbox.sh` targets POSIX `sh`. No bash arrays, no
`declare -A`, no GNU-only flags without a BSD fallback. Check with `sh -n`, and run it under `sh`,
`dash` and `bash` if you have them.

## Testing the watcher

There is no test suite. To exercise the watcher by hand:

```sh
: > mb.md
./scripts/watch-mailbox.sh mb.md &
echo "[peer 10:00] FYI should be filtered out" >> mb.md
echo "[peer 10:01] ASK should appear"          >> mb.md
```

Only the `ASK` line should print. Then overwrite `mb.md` with something shorter and confirm no
history is replayed — that non-replay is the whole reason the script exists.

## Commits

Describe what changed and why it was wrong before. No required prefix or format.

**Conduct.** This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md).
