---
description: 在当前目录初始化标准团队项目（交互式收集配置，生成即用的 CLAUDE.md）
---

你是项目初始化向导，在当前目录为标准 AI 开发团队配置项目。**本命令完全自包含，任何目录均可运行。**

## 执行步骤

### Step 1 — 获取项目名

用 Bash 获取当前目录名（`basename "$PWD"` 或 PowerShell `Split-Path -Leaf (Get-Location).Path`）作为 PROJECT_NAME。

---

### Step 2 — 检查 CLAUDE.md

- 若 `CLAUDE.md` **已存在**：告知用户已跳过，直接进入 Step 4
- 若 **不存在**：继续 Step 3

---

### Step 3 — 交互式收集项目配置（含按需求推荐技术栈）

向用户提问（使用 AskUserQuestion 工具或直接对话）：

**问题 1（先问，用于推荐）：** 这个项目大概要做什么？用一两句话描述即可（可留空）。
> 例：`一个多人协作的待办事项 SaaS，要登录、团队空间、实时同步` / `内部数据看板，读多写少`
> 记录为 PROJECT_BRIEF。

**问题 2：** 技术栈想用什么？**如果还没想好，回答"让团队推荐"或直接留空。**
> 已确定 → 例：`Express.js, React, PostgreSQL` / `FastAPI, Next.js, MySQL` / `Django, Vue, Redis`

**问题 3：** 部署环境是什么？同样可回答"让团队推荐"或留空。
> 例：`Docker + Nginx` / `Vercel` / `AWS ECS` / `Railway`

**技术栈推荐逻辑（关键）**：
- 用户**已明确给出**技术栈 → 直接记为 TECH_STACK，**不擅自更改**。
- 用户回答"让团队推荐 / 不确定 / 留空"：
  - 若 **PROJECT_BRIEF 有内容** → 依据它**推荐 1 个主选方案 + 1 个备选方案**，每项一句话理由（结合规模、读写特征、团队上手成本、部署目标），用 AskUserQuestion 让用户**确认主选 / 改用备选 / 自定义**。确认后记为 TECH_STACK。
  - 若 **PROJECT_BRIEF 也为空**（用户什么都没说）→ **不要瞎猜**。把 TECH_STACK 记为占位串 `待 Phase 2 选型`（**必须用这个确切字符串**，software-architect 据此识别并在 Phase 2 按 PRD 主动选型），告知用户"等进入完整开发、产出 PRD 后由架构师按需求选型，你届时可确认"。
- DEPLOY_ENV 同理：给了就用；让推荐则结合技术栈给 1 个建议供确认；都没有则同样记为确切占位串 `待 Phase 2 选型`。

收到/确认后，记录为 TECH_STACK 和 DEPLOY_ENV。

---

### Step 4 — 生成 CLAUDE.md

若 CLAUDE.md 不存在，用 Write 工具生成（将 PROJECT_NAME、TECH_STACK、DEPLOY_ENV 替换为实际值）：

```markdown
# {PROJECT_NAME}

## 团队配置

本项目使用标准 AI 开发团队（15 个 agent：1 位总指挥 + 14 名成员）。

**启动方式（重要）**：当用户说"使用标准团队开发 你的需求"时，**你（top-level 主会话）亲自担任 orchestrator 总指挥**：
1. 读取 `~/.claude/agents/orchestrator.md` 作为调度操作手册
2. 按其中的流程，用 `Task` 工具派发 product-manager、software-architect、backend-architect 等**下游专业 agent**
3. **不要**用 `Task` 启动 `subagent_type="orchestrator"`——Claude Code 不支持 subagent 嵌套派发，那样 orchestrator 将无法派发下游、整个团队瘫痪

一句话：**你就是 orchestrator 本人；只有下游 14 个 agent 才用 Task 派发。**

**未用触发语时的轻量反问（重要，且仅止于反问）**：如果用户**没有**说触发语，但发来的需求明显需要多个 agent / 多步骤协调（例如"做一个带前后端和数据库的 X""重构整个 Y 模块""批量改造 Z"），你**先用一句话反问**，而不是直接接管：
> 「这个需求看起来需要多角色协作，要不要用标准 AI 开发团队来做？（开跑后若检测到可大量并行，我会再单独问是否启用 Workflow）」
- 用户**确认后**才按上面的「启动方式」担任 orchestrator；用户说不用，就按普通方式直接处理，不再追问。
- **反问 ≠ 自动接管**：用户点头前，绝不擅自启动团队流程、绝不擅自跑 Workflow。简单/单步需求不要反问，直接做。

### 全局执行准则（最高优先级）

- **语言**：团队所有 agent 与你（orchestrator）始终用**简体中文**回答、汇报与产出文档；即使被英文/日文提问也用中文，仅代码标识符与命令保留英文。
- **命令行**：Windows 环境优先用 PowerShell；若 Bash 报错或拿不到输出，立即改用 PowerShell 重试，不要反复用 Bash 重试同一命令。

## 项目上下文

- 技术栈: {TECH_STACK}
- 部署环境: {DEPLOY_ENV}

## 团队运行机制

- 项目状态记录在 `.claude/team-state/STATE.md`
- 失败重试记录在 `.claude/team-state/RETRY_LOG.md`
- 用户确认过的关键决策记录在 `.claude/team-state/DECISIONS.md`
- 项目内经验记录在 `.claude/team-state/LEARNINGS.md`
- 用户级长期记忆位于 `~/.claude/team-memory/patterns/`
```

---

### Step 5 — 生成 .claude/settings.json

若 `.claude/settings.json` 不存在，用 Write 工具生成（**按命令前缀白名单，不要整体放行 `Bash`**——不可逆/对外动作如 `git push`、`rm`、`docker`、`sudo` 故意不在白名单，由 orchestrator 的安全确认点逐次把关）：

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Glob",
      "Grep",
      "Task",
      "Write",
      "Bash(npm *)",
      "Bash(npx *)",
      "Bash(pnpm *)",
      "Bash(yarn *)",
      "Bash(node *)",
      "Bash(python *)",
      "Bash(python3 *)",
      "Bash(pip *)",
      "Bash(pytest*)",
      "Bash(go *)",
      "Bash(cargo *)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git add*)",
      "Bash(git restore*)",
      "Bash(mkdir *)",
      "Bash(ls *)",
      "Bash(cat *)",
      "Bash(echo *)"
    ]
  }
}
```

---

### Step 6 — 创建 .claude/team-state/ 状态文件

创建目录 `.claude/team-state/`（若不存在）。

逐一检查以下文件，**已存在则跳过，不存在则用 Write 工具生成**：

**STATE.md：**
```markdown
# Team State

- Current Phase: Not Started
- Current Task: None
- Last Agent: None
- Last Result: None
- Retry Count: 0
- Next Action: Start Phase 1 requirement analysis
- Updated At: Not Started
```

**RETRY_LOG.md：**
```markdown
# Retry Log

本文件由 orchestrator 在 Phase 5 / Phase 6 / Phase 7 / Phase 8 / Phase 10 失败打回时更新。

## 记录格式

```
### TASK-B01
- Phase: Phase 5
- Agent: backend-architect
- Attempt: 1
- Result: QA_FAIL
- Failure Reason: 返回字段与 API_CONTRACT 不一致
- Retry Strategy: Inject memory hint and QA feedback
- Final Outcome: PASS
- Updated At: {today}
```

## 当前记录

No retries recorded.
```

**DECISIONS.md：**
```markdown
# Decisions

本文件记录用户已经确认过的关键决策，orchestrator 恢复运行时必须优先读取。

## Confirmed Decisions

No decisions recorded.
```

**LEARNINGS.md：**
```markdown
# Project Learnings

本文件记录项目内临时经验。只有 reality-checker 判定 READY 后，orchestrator 才能从这里提炼内容写入用户级长期记忆库。

## Candidate Learnings

No learnings recorded.
```

---

### Step 7 — 报告完成

输出（将实际值替换进去）：

```
✅ 项目初始化完成！

   项目名：{PROJECT_NAME}
   技术栈：{TECH_STACK}
   部署环境：{DEPLOY_ENV}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
现在在这个目录里说：

  使用标准团队开发 你的需求

orchestrator 会自动接管：PRD → 契约 → 实现 → QA → 上线
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
