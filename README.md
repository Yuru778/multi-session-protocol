# multi-session-protocol

A Claude Code skill: **when several agent sessions share one machine, which sentence goes down which
channel.**

[繁體中文說明](README.zh-TW.md)

Claude Code has official cross-session messaging (`ListAgents` / `SendMessage`). It is delivered
unconditionally and wakes the other session — but it has no level for "leave a note without waking
anyone", and an agent that is not a Claude Code session cannot receive it at all.

This skill mixes the two channels:

| What you are sending | Which channel |
|---|---|
| The peer must decide or act (ASK), or is waiting on something you finished (DONE) | `SendMessage` |
| The peer should just know (FYI) | append with `>>` to a shared mailbox file |
| What the peer is doing and which files it will touch | read its state file, do not ask |
| Claiming a shared resource (a GPU, an inference server) | an atomic `noclobber` lock |
| Waiting for a long job to finish | `notify_when_idle: true` |
| Talking to a non-Claude agent | file mailbox plus the offset watcher |

The full rules, a minimal example for each row, the opening checklist and the common mistakes are in
[`SKILL.md`](SKILL.md).

## Install

```bash
git clone https://github.com/Yuru778/multi-session-protocol.git \
  ~/.claude/skills/multi-session-protocol
```

Put it under `~/.claude/skills/` for every project, or under a project's `.claude/skills/` for just
that one. Claude loads it when the situation matches the description.

## Contents

```
SKILL.md                     the protocol itself
scripts/watch-mailbox.sh     mailbox watcher, POSIX sh (Linux, macOS, WSL 2)
scripts/watch-mailbox.ps1    mailbox watcher, PowerShell 5.1+ (native Windows)
```

Both watchers are offset-based, so a whole-file rewrite on the other side never replays the history
into your context. You only need one if you are talking to an agent that cannot receive
`SendMessage` — Claude-to-Claude needs no watcher process at all.

## Requirements

Cross-session messaging needs Claude Code v2.1.224 or later (v2.1.234 on native Windows), and
`notify_when_idle` needs v2.1.236 on both sides. Run `/list-agents` to check a session.
