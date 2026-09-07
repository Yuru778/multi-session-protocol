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

## What it buys you

- **Fewer tokens spent on the other session.** Every message starts a turn over there. Routing FYI
  into a file, reading a state file instead of asking, subscribing with `notify_when_idle` instead of
  polling, and never replying "got it" all remove turns that were never worth paying for.
- **Nobody's work gets clobbered.** An atomic lock for the shared GPU or inference server, and a
  state-file line saying how long your heavy job runs, so two sessions stop killing each other's test
  runs.
- **Nothing to install.** No MCP server, no broker daemon, no `jq`, no background process at all
  between two Claude sessions. Clone one directory and the routing rules load themselves when the
  situation matches.
- **Peers that are not Claude Code sessions still reach you.** Official messaging cannot see them;
  the file half of the protocol can.

## When not to use this

This skill is for **independent sessions you start and steer yourself**, in separate terminals, plus
agents that are not Claude Code sessions at all. Two lighter options cover the other shapes:

- **[Subagents](https://code.claude.com/docs/en/sub-agents)** work inside a single session and report
  their result back to the caller. Use them when you just need a helper, not a peer.
- **[Agent teams](https://code.claude.com/docs/en/agent-teams)** are the official way for one lead
  session to spawn and supervise teammates, with a shared task list, per-agent mailboxes,
  file-locked task claiming and automatic idle notifications. Use them when one session should own
  the coordination. They are experimental and off by default
  (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`), a team is scoped to the session that created it, and a
  team cannot include an agent that is not a Claude Code session.

If a team fits your work, use the team. This skill starts where teams stop: peers that no one
spawned, and peers that cannot receive `SendMessage` at all.

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

## Prior art

Several projects solve neighbouring problems. Each of them builds a transport of its own. This skill
builds none for Claude-to-Claude — it routes over what Claude Code already provides — and falls back
to plain appended files only where nothing official reaches.

- **[claude-code-session-bridge](https://github.com/PatilShreyas/claude-code-session-bridge)** — a
  file-based mailbox, bash scripts and a skill that teaches agents the protocol. It predates official
  cross-session messaging and polls JSON inbox/outbox directories, so it carries no distinction
  between a message that wakes the peer and a note that does not.
- **[agent-peers-mcp](https://github.com/Co-Messi/agent-peers-mcp)** and the related
  **[claude-peers-mcp](https://github.com/jamditis/claude-peers-mcp)** — MCP servers backed by a local
  broker daemon (HTTP + SQLite) that replace the official tools with their own protocol. agent-peers
  does separate wake signals from non-intrusive notes, and does reach a non-Claude CLI agent, which
  makes it the closest in intent to this skill despite the opposite implementation.
- **[agent-bridge](https://github.com/EthanSK/agent-bridge)** — peer-to-peer messaging between agent
  harnesses across machines, over SSH.

## Contributing

Issues and pull requests are welcome. Particularly useful:

- **Platform verification.** `watch-mailbox.sh` has been exercised under `sh`, `dash` and `bash` on
  Linux. `watch-mailbox.ps1` has **not been run on native Windows** — if you try it there, saying
  whether it worked is a real contribution.
- **Failure modes worth adding.** If a rule here cost you something in practice, or a mistake bit you
  that the table does not list, open an issue describing what happened. The table earns its place by
  being specific.
- **Corrections.** The specification summary tracks Claude Code's documented behavior and will drift
  as the product changes. Point at the version that broke a claim and it gets fixed.

Keep the skill generic: no project names, no personal paths, `<me>` / `<peer>` / `<mailbox>`
throughout. `SKILL.md` and the scripts are English-only; `README.zh-TW.md` mirrors `README.md`, so
changes to one belong in the other.

## License

[MIT](LICENSE) © Yuru778
