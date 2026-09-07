# multi-session-protocol

A Claude Code skill for **parallel agent sessions on one machine: which message goes down which
channel.**

[繁體中文說明](README.zh-TW.md)

Official cross-session messaging (`ListAgents` / `SendMessage`) always wakes the other session. It
has no level for "leave a note without waking anyone", and an agent that is not a Claude Code session
cannot receive it at all. This skill routes around both gaps.

| What you are sending | Which channel |
|---|---|
| **ASK** — the peer must decide or act | `SendMessage` |
| **DONE** — you finished something it waits on | `SendMessage` |
| **FYI** — it should know, but must not be interrupted | append with `>>` to a shared mailbox file |
| "What are you doing, which files, until when" | read its state file; do not ask |
| Claiming a shared resource (a GPU, an inference server) | atomic `noclobber` lock |
| Waiting on a long job | `notify_when_idle: true` |
| A peer that is not Claude Code (Codex, another CLI agent) | file mailbox + offset watcher |

Full rules, one example per row, the opening checklist and the common mistakes:
[`SKILL.md`](skills/multi-session-protocol/SKILL.md).

**What it buys you**

- **Fewer turns spent on the peer.** FYI in a file, state files instead of asking,
  `notify_when_idle` instead of polling, and never replying "got it".
- **No clobbered work.** An atomic lock, and a stated end time for heavy jobs.
- **Nothing to install.** No MCP server, no daemon, no `jq`, no background process between two
  Claude sessions.
- **Reach to peers official messaging cannot see.**

## Parallel sessions, not subagents

A subagent answers its caller and ends. A teammate belongs to the lead that spawned it. Both are
shapes where one session owns the work. This skill assumes peers that nobody is coordinating — each
with its own task, permission mode and next move — so what they need is a convention, not an
orchestrator.

|  | Subagents | Agent teams | Independent sessions (this skill) |
|---|---|---|---|
| Who starts it | the main agent, mid-task | a lead spawns teammates | you, in your own terminal |
| Who it answers to | its caller, then ends | the lead; teammates also message each other | nobody; each picks its own next move |
| Lifetime | one task | ends with the lead session | independent of any one task |
| Permission mode | the parent's | the lead's, fixed at spawn | each session's own |
| How you steer it | through the parent | the agent panel, or a message | you sit at it |
| Learning what a peer is doing | you cannot — it reports when finished | shared task list | read its state file, free to the peer |
| A peer that is not Claude Code | no | no | yes, through the file mailbox |
| Setup | none | experimental flag | none |

Use the lighter shape when it fits: [subagents](https://code.claude.com/docs/en/sub-agents) for a
helper that only reports back, [agent teams](https://code.claude.com/docs/en/agent-teams) when one
session should own and supervise the work (experimental,
`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, scoped to the session that created it). Neither can include
an agent that is not a Claude Code session.

## Install

As a plugin:

```
/plugin marketplace add Yuru778/multi-session-protocol
/plugin install multi-session-protocol@multi-session-protocol
```

Add `@v0.1.0` to the marketplace line to pin a version. The same two steps work from a shell as
`claude plugin marketplace add …` / `claude plugin install …`.

By hand:

```bash
git clone https://github.com/Yuru778/multi-session-protocol.git
cp -r multi-session-protocol/skills/multi-session-protocol ~/.claude/skills/
```

**Restart Claude Code afterwards** — plugin skills load at session start, so a freshly installed
skill will not resolve in the session that installed it.

## Contents

```
.claude-plugin/                    plugin and marketplace manifests
skills/multi-session-protocol/
  SKILL.md                         the protocol
  scripts/watch-mailbox.sh         offset-based mailbox watcher, POSIX sh
```

The watcher never replays history when the other side rewrites the file, which `tail -F` does. You
need it only for a peer that cannot receive `SendMessage`.

## Platform

Needs Claude Code v2.1.224+; `notify_when_idle` needs v2.1.236 on both sides.

| | Status |
|---|---|
| **Linux** | developed and tested here |
| **macOS, WSL 2** | have a POSIX shell, so everything should work — unverified |
| **Native Windows** | messaging, FYI appends, state files and `notes/` work. The `noclobber` lock and the watcher do not: no POSIX shell. `SKILL.md` carries a `FileMode.CreateNew` lock recipe, unshipped and unrun — do not substitute `Test-Path` then write, which is the race the lock prevents. PowerShell 5.1 also writes UTF-16LE through `>>`; pass `-Encoding utf8`. |

## Non-Claude peers

They will never load this skill. `SKILL.md` §7 carries a contract to paste into
[`AGENTS.md`](https://agents.md), the convention 30+ agents read at session start — plus the limit no
convention removes: **you cannot wake a peer that has no `SendMessage`**. It reads your line when
something else makes it read the file.

## Prior art

Each of these builds a transport of its own; this skill routes over what Claude Code already
provides.

- **[claude-code-session-bridge](https://github.com/PatilShreyas/claude-code-session-bridge)** — file
  mailbox, scripts and a skill. Predates official messaging and polls JSON inboxes, so it has no
  wake / no-wake distinction.
- **[agent-peers-mcp](https://github.com/Co-Messi/agent-peers-mcp)** and
  **[claude-peers-mcp](https://github.com/jamditis/claude-peers-mcp)** — MCP servers with a local
  broker daemon (HTTP + SQLite) replacing the official tools. agent-peers does separate wake signals
  from quiet notes and does reach a non-Claude CLI agent: closest in intent, opposite in
  implementation.
- **[agent-bridge](https://github.com/EthanSK/agent-bridge)** — agent-to-agent messaging across
  machines, over SSH.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Most wanted: a Windows lock helper and watcher, and anyone
who can say whether the watcher actually runs on macOS.

## License

[MIT](LICENSE) © Yuru778
