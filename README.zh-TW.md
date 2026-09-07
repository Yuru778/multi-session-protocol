# multi-session-protocol

一個 Claude Code skill，處理**同一台機器上平行運作的 agent session：哪句話該走哪條通道。**

[English](README.md)

官方的跨 session 訊息（`ListAgents` ／ `SendMessage`）送出去一定會叫醒對方。它沒有「留言但不吵醒對方」
這一級，而不是 Claude Code session 的 agent 根本收不到它。這個 skill 繞開這兩個缺口。

| 要傳的東西 | 走哪條 |
|---|---|
| **ASK** —— 要對方決定或動手 | `SendMessage` |
| **DONE** —— 完成了對方在等的事 | `SendMessage` |
| **FYI** —— 讓對方知道，但不該打斷它 | 用 `>>` 追加到共享信箱檔 |
| 「你在做什麼、會碰哪些檔、到幾點」 | 讀它的狀態檔，不要問 |
| 占用共享資源（GPU、推理伺服器） | `noclobber` 原子鎖 |
| 等一件長工作 | `notify_when_idle: true` |
| 對象不是 Claude Code（Codex 等 CLI agent） | 檔案信箱 ＋ offset 監看器 |

完整規則、每一列的最小範例、開場檢查清單與常見錯誤：
[`SKILL.md`](skills/multi-session-protocol/SKILL.md)（英文）。

**你換到什麼**

- **少花對方的回合。** FYI 走檔案、狀態檔取代問答、`notify_when_idle` 取代輪詢、不回「收到」。
- **不會互相弄壞東西。** 原子鎖，加上重量級工作寫明跑到幾點。
- **零安裝。** 不用 MCP server、不用 daemon、不用 `jq`，兩個 Claude session 之間連常駐行程都沒有。
- **通得到官方訊息看不見的對象。**

## 平行的 session，不是 subagent

subagent 回答呼叫它的人然後結束。teammate 隸屬於生出它的 lead。兩者都是「一個 session 擁有這份工作」
的形狀。這個 skill 假設的是**沒有人在統籌的對等同事** —— 各自有自己的任務、權限模式與下一步判斷 ——
它們需要的是一套共識，不是一個指揮者。

|  | Subagent | Agent teams | 各自獨立的 session（這個 skill） |
|---|---|---|---|
| 誰生出它 | 主 agent，做到一半時 | lead 生出 teammate | 你，在自己的終端機裡 |
| 對誰負責 | 呼叫它的人，然後結束 | lead；teammate 之間也能互傳 | 沒有人；各自決定下一步 |
| 生命週期 | 一件任務 | 隨 lead session 結束 | 不依附於任何單一任務 |
| 權限模式 | 跟隨父層 | 跟隨 lead，生成時固定 | 每個 session 各自的 |
| 你怎麼指揮它 | 透過父層 | agent 面板，或傳訊息 | 你就坐在它前面 |
| 怎麼知道對方在做什麼 | 沒辦法 —— 做完才回報 | 共享任務清單 | 讀它的狀態檔，不花對方成本 |
| 對象不是 Claude Code | 不行 | 不行 | 可以，走檔案信箱 |
| 前置設定 | 不用 | 要開實驗旗標 | 不用 |

有更輕的形狀合用就用那個：[subagent](https://code.claude.com/docs/en/sub-agents)
適合只要回報結果的幫手，[agent teams](https://code.claude.com/docs/en/agent-teams)
適合該由某個 session 擁有並監督的工作（實驗性、預設關閉 `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`、
一個 team 只屬於建立它的 session）。兩者都納不進非 Claude Code session 的 agent。

## 安裝

用 plugin 裝：

```
/plugin marketplace add Yuru778/multi-session-protocol
/plugin install multi-session-protocol@multi-session-protocol
```

在 marketplace 那行後面加 `@v0.1.0` 可以鎖版本。在 shell 裡是
`claude plugin marketplace add …` ／ `claude plugin install …`。

手動裝：

```bash
git clone https://github.com/Yuru778/multi-session-protocol.git
cp -r multi-session-protocol/skills/multi-session-protocol ~/.claude/skills/
```

**裝完要重開 Claude Code** —— plugin 的 skill 只在 session 啟動時載入，在裝它的那個 session 裡叫不出來。

## 內容

```
.claude-plugin/                    plugin 與 marketplace 的 manifest
skills/multi-session-protocol/
  SKILL.md                         協定本體
  scripts/watch-mailbox.sh         offset 版信箱監看器，POSIX sh
```

對方整檔重寫時，這支監看器不會把歷史重播進你的 context（`tail -F` 會）。
只有對象收不到 `SendMessage` 時才需要它。

## 平台

需要 Claude Code v2.1.224 以上；`notify_when_idle` 需要雙方都在 v2.1.236 以上。

| | 狀態 |
|---|---|
| **Linux** | 在這上面開發與實測 |
| **macOS、WSL 2** | 有 POSIX shell，理論上全部可跑 —— 未驗證 |
| **原生 Windows** | 訊息、FYI 追加、狀態檔、`notes/` 都能用。`noclobber` 鎖與監看器不行：沒有 POSIX shell。`SKILL.md` 有 `FileMode.CreateNew` 的上鎖寫法，但沒隨附也沒人跑過 —— 不要改用「`Test-Path` 檢查再寫入」，那正是這個鎖要避開的 race。另外 PowerShell 5.1 的 `>>` 會寫成 UTF-16LE，要加 `-Encoding utf8`。 |

## 非 Claude 的對象

它們永遠不會載入這個 skill。`SKILL.md` §7 附了一份可以直接貼進
[`AGENTS.md`](https://agents.md) 的約定（30 多種 agent 會在 session 啟動時讀那個檔），
以及一件任何約定都解決不了的事：**你沒辦法喚醒一個沒有 `SendMessage` 的對象。**
它要等到某件事讓它去讀那個檔，才會看到你的訊息。

## 相關作品

以下每一個都自己做了一套傳輸層；這個 skill 是走 Claude Code 本來就有的通道。

- **[claude-code-session-bridge](https://github.com/PatilShreyas/claude-code-session-bridge)** ——
  檔案信箱、腳本與一個 skill。早於官方訊息，以輪詢 JSON 信箱運作，所以沒有喚醒／不喚醒的分級。
- **[agent-peers-mcp](https://github.com/Co-Messi/agent-peers-mcp)** 與
  **[claude-peers-mcp](https://github.com/jamditis/claude-peers-mcp)** —— MCP server，
  背後跑本機 broker daemon（HTTP + SQLite）取代官方工具。agent-peers 確實有區分喚醒訊號與不打擾的留言，
  也確實接得到非 Claude 的 CLI agent：意圖上最接近，實作路線相反。
- **[agent-bridge](https://github.com/EthanSK/agent-bridge)** —— 跨機器、走 SSH 的 agent 之間訊息。

## 歡迎貢獻

見 [CONTRIBUTING.md](CONTRIBUTING.md)（英文）。最需要的：Windows 的上鎖工具與監看器，
以及有人能回報監看器在 macOS 上到底跑不跑得動。

## 授權

[MIT](LICENSE) © Yuru778
