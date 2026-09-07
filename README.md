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
[`SKILL.md`](skills/multi-session-protocol/SKILL.md).

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

## Parallel sessions, not subagents

A subagent exists to answer the session that spawned it: it runs one task, returns a result, and
ends. A teammate in an agent team has its own context window but still belongs to the lead that
spawned it, and the team ends when that session does. Both are shapes where one session owns the
work and the others report into it.

This skill is for the other shape — the two or three Claude Code sessions you started yourself, in
their own terminals, each with its own task, its own permission mode, and its own idea of what to do
next. They are peers, not workers, and no one is coordinating them. What they need is not an
orchestrator but a convention: what is worth interrupting a peer for, what is worth only leaving on
disk, and how to find out what someone else is doing without asking them.

|  | Subagents | Agent teams | Independent sessions (this skill) |
|---|---|---|---|
| Who starts it | the main agent, mid-task | a lead session spawns teammates | you, in your own terminal |
| Who it answers to | its caller — returns a result, then ends | the lead coordinates; teammates also message each other | nobody; each session picks its own next move |
| Lifetime | one task | ends with the lead session | independent of any one task |
| Permission mode | the parent's | the lead's, fixed at spawn | each session's own |
| How you steer it | through the parent | select it in the agent panel, or message it | you sit at it |
| Finding out what a peer is doing | you cannot — it reports when finished | shared task list | read its state file, costing the peer nothing |
| A peer that is not a Claude Code session | no | no | yes, through the file mailbox |
| Setup | none | experimental flag | none |

If a lighter shape fits the work, use it. [Subagents](https://code.claude.com/docs/en/sub-agents)
are right for a helper that only has to report back.
[Agent teams](https://code.claude.com/docs/en/agent-teams) are right when one session should own and
supervise the work — they are experimental and off by default
(`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`), and a team is scoped to the session that created it.
Neither can include an agent that is not a Claude Code session. This skill starts where both stop.

## Install

**As a plugin** — installs and updates through Claude Code:

```
/plugin marketplace add Yuru778/multi-session-protocol
/plugin install multi-session-protocol@multi-session-protocol
```

The same two steps work from a shell with `claude plugin marketplace add …` and
`claude plugin install …`. Pin a version with `@v0.1.0` on the marketplace line.

**By hand**, if you would rather not add a marketplace:

```bash
git clone https://github.com/Yuru778/multi-session-protocol.git
cp -r multi-session-protocol/skills/multi-session-protocol ~/.claude/skills/
```

`~/.claude/skills/` makes it available in every project; a project's own `.claude/skills/` scopes it
to that one. Either way, Claude loads it when the situation matches the description.

**Plugin skills load at session start**, so restart Claude Code after installing — a freshly
installed skill will not resolve in the session that installed it.

## Contents

```
.claude-plugin/                    plugin and marketplace manifests
skills/multi-session-protocol/
  SKILL.md                         the protocol itself
  scripts/watch-mailbox.sh         mailbox watcher, POSIX sh
```

The watcher is offset-based, so a whole-file rewrite on the other side never replays the history into
your context. You only need it if you are talking to an agent that cannot receive `SendMessage` —
Claude-to-Claude needs no watcher process at all.

## Platform

Developed and tested on **Linux**. Most of the protocol is either a Claude Code feature or plain file
I/O and travels anywhere; two pieces need a POSIX shell.

On native Windows, messaging (`SendMessage`, `notify_when_idle`), appending FYI, state files and
`notes/` all work. What does not:

- **The `noclobber` lock.** `noclobber` is a POSIX shell option and PowerShell and `cmd` have none.
  `[System.IO.File]::Open(path, 'CreateNew', ...)` is the primitive that matches it — `SKILL.md`
  carries the recipe, unshipped and unrun. Do not substitute `Test-Path` then write: that is the same
  race the lock exists to avoid.
- **`skills/multi-session-protocol/scripts/watch-mailbox.sh`**, which needs a POSIX shell. You only need it for a non-Claude peer.

Windows PowerShell 5.1 also writes UTF-16LE through `>>`; pass `-Encoding utf8` or use PowerShell 7+.

macOS and WSL 2 have a POSIX shell, so everything should work; neither has been verified.

## Requirements

Cross-session messaging needs Claude Code v2.1.224 or later, and `notify_when_idle` needs v2.1.236 on
both sides. Run `/list-agents` to check a session.

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

Issues and pull requests are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The two gaps that
help most right now: a Windows lock helper and watcher, and anyone who can say whether
the watcher script actually runs on macOS.

## License

[MIT](LICENSE) © Yuru778
