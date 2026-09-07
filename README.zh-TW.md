# multi-session-protocol

一個 Claude Code skill：**多個 agent session 共用同一台機器時，哪句話該走哪條通道。**

[English](README.md)

Claude Code 有官方的跨 session 訊息（`ListAgents` ／ `SendMessage`），無條件送達並喚醒對方；
但它沒有「留言但不要吵醒對方」這一級，而不是 Claude Code session 的 agent 根本收不到它。

這個 skill 把兩條通道混起來用：

| 要傳的東西 | 走哪條 |
|---|---|
| 要對方決定或動手（ASK）、對方正在等的完成通知（DONE） | `SendMessage` |
| 只是讓對方知道（FYI） | 用 `>>` 追加到共享信箱檔 |
| 對方在做什麼、會碰哪些檔 | 讀它的狀態檔，不要問 |
| 占用共享資源（GPU、推理伺服器） | `noclobber` 原子鎖 |
| 等一件長工作做完 | `notify_when_idle: true` |
| 跟非 Claude 的 agent 通訊 | 檔案信箱 ＋ offset 監看器 |

完整規則、每一列的最小範例、開場檢查清單與常見錯誤都在 [`SKILL.md`](SKILL.md)（內容為英文）。

## 什麼時候不該用這個

這個 skill 是給**你自己在不同 terminal 開的、各自獨立的 session**，以及根本不是 Claude Code session
的 agent 用的。其他形狀有兩個更輕的選項：

- **[Subagent](https://code.claude.com/docs/en/sub-agents)** 在單一 session 內運作，做完把結果回傳給呼叫者。
  你要的只是一個幫手而不是對等的同事時，用它。
- **[Agent teams](https://code.claude.com/docs/en/agent-teams)** 是官方做法：由一個 lead session
  spawn 出 teammate 並負責統籌，內建共享任務清單、每個 agent 各自的信箱、搶任務用 file lock、
  閒置自動通知。該由某一個 session 統籌時，用它。但它是實驗性功能、預設關閉
  （`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`），一個 team 只屬於建立它的那個 session，
  而且沒辦法把非 Claude Code session 的 agent 納進來。

合用 team 的工作就用 team。這個 skill 從 team 停下來的地方開始：**沒有人 spawn 出來的對等 session**，
以及**根本收不到 `SendMessage` 的對象**。

## 安裝

```bash
git clone https://github.com/Yuru778/multi-session-protocol.git \
  ~/.claude/skills/multi-session-protocol
```

放進 `~/.claude/skills/` 就是全域可用，放進某個專案的 `.claude/skills/` 則只在該專案生效。
情境符合 description 時 Claude 會自己載入。

## 內容

```
SKILL.md                     協定本體
scripts/watch-mailbox.sh     信箱監看器，POSIX sh（Linux、macOS、WSL 2）
scripts/watch-mailbox.ps1    信箱監看器，PowerShell 5.1+（原生 Windows）
```

兩支監看器都是 offset 版，所以對方整檔重寫時不會把歷史重播進你的 context。
只有在跟收不到 `SendMessage` 的 agent 通訊時才需要它 —— Claude 對 Claude 完全不需要監看行程。

## 需求

跨 session 訊息需要 Claude Code v2.1.224 以上（原生 Windows 為 v2.1.234），
`notify_when_idle` 需要雙方都在 v2.1.236 以上。用 `/list-agents` 確認某個 session 有沒有這個功能。

## 相關作品

有幾個專案在解相鄰的問題。它們各自都做了一套自己的傳輸層。這個 skill 在 Claude 對 Claude 的情況
不做任何傳輸層 —— 只負責決定訊息走 Claude Code 本來就有的哪一條路 —— 只有在官方管道到不了的地方，
才退回到單純的追加寫檔。

- **[claude-code-session-bridge](https://github.com/PatilShreyas/claude-code-session-bridge)** ——
  檔案信箱 ＋ 幾支 bash 腳本 ＋ 一個教 agent 協定的 skill。它早於官方的跨 session 訊息，
  以輪詢 JSON inbox/outbox 目錄運作，因此沒有「會喚醒對方」與「不會喚醒對方」的分級。
- **[agent-peers-mcp](https://github.com/Co-Messi/agent-peers-mcp)** 與性質相近的
  **[claude-peers-mcp](https://github.com/jamditis/claude-peers-mcp)** —— MCP server，
  背後跑一台本機 broker daemon（HTTP + SQLite），用自己的協定取代官方工具。
  agent-peers 確實有區分喚醒訊號與不打擾的留言，也確實能接到非 Claude 的 CLI agent，
  是意圖上跟這個 skill 最接近的一個，儘管實作路線完全相反。
- **[agent-bridge](https://github.com/EthanSK/agent-bridge)** —— 跨機器、走 SSH 的
  agent harness 之間的點對點訊息。

