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

## 這個 skill 幫你換到什麼

- **少花對方的 token。** 每一則訊息都會在對方那邊開一個回合。FYI 改走檔案、讀狀態檔取代問答、
  用 `notify_when_idle` 訂閱取代輪詢、不回「收到」—— 這幾條拿掉的都是本來就不值得付錢的回合。
- **不會互相弄壞東西。** 共用的 GPU 或推理伺服器用原子鎖，狀態檔第三行寫明自己的重量級工作跑到幾點，
  兩個 session 就不會再互相砍掉對方的測試。
- **零安裝。** 不用 MCP server、不用 broker daemon、不用 `jq`，兩個 Claude session 之間連一個常駐行程
  都不需要。clone 一個目錄，情境符合時規則會自己載入。
- **非 Claude Code session 的對象一樣通得到。** 官方訊息看不見它們，協定的檔案那一半可以。

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
scripts/watch-mailbox.sh     信箱監看器，POSIX sh
```

監看器是 offset 版，所以對方整檔重寫時不會把歷史重播進你的 context。
只有在跟收不到 `SendMessage` 的 agent 通訊時才需要它 —— Claude 對 Claude 完全不需要監看行程。

## 平台

**Linux。** 這是它被寫出來、也被實測過的環境。協定的檔案那一半 —— 用 `>>` 追加、`noclobber` 上鎖、
監看器 —— 都預設你有一個 POSIX shell。

macOS 與 WSL 2 有 POSIX shell，理論上可以跑，但兩者都未經驗證。**原生 Windows 不支援**：
PowerShell 與 `cmd` 沒有 `noclobber`，也沒有對應的監看器。移植過來會是很受歡迎的貢獻。

訊息那一半不受影響 —— `ListAgents` 與 `SendMessage` 是 Claude Code 的功能，
Claude Code 跑得動的地方它們就跑得動。

## 需求

跨 session 訊息需要 Claude Code v2.1.224 以上，`notify_when_idle` 需要雙方都在 v2.1.236 以上。
用 `/list-agents` 確認某個 session 有沒有這個功能。

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

## 歡迎貢獻

歡迎開 issue 與 pull request。特別有幫助的是：

- **Windows 支援。** 目前完全沒有。`noclobber` 在 PowerShell 沒有 shell 層的等價物
  （對應的原語是 `[System.IO.File]::Open(path, 'CreateNew', ...)`），也沒有對應的監看器。
  做一份移植，或回報「WSL 2 在實務上就夠用了」，都能補掉這裡最大的缺口。
- **macOS 驗證。** `watch-mailbox.sh` 只在 Linux 上以 `sh`、`dash`、`bash` 跑過。
  裡面有一段給 macOS 的 BSD `stat` 退路，但沒有人真的跑過。
- **值得補進去的坑。** 如果這裡某條規則讓你付出過代價，或你踩到的錯誤不在表上，
  開個 issue 描述發生了什麼。那張表的價值來自夠具體。
- **勘誤。** 規格速查跟著 Claude Code 的官方行為走，產品一改就會過時。
  指出是哪個版本讓某句話不再成立，就能修掉。

請維持通用性：不要出現專案名稱或個人路徑，一律用 `<me>` ／ `<peer>` ／ `<mailbox>`。
`SKILL.md` 與腳本只用英文；`README.zh-TW.md` 與 `README.md` 互為鏡像，改一邊就要改另一邊。

## 授權

[MIT](LICENSE) © Yuru778
