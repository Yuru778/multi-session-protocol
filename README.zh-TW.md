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
