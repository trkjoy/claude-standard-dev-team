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

### Step 3 — 交互式收集项目配置

向用户提问（使用 AskUserQuestion 工具或直接对话）：

**问题 1：** 项目的技术栈是什么？
> 例：`Express.js, React, PostgreSQL` / `FastAPI, Next.js, MySQL` / `Django, Vue, Redis`

**问题 2：** 部署环境是什么？
> 例：`Docker + Nginx` / `Vercel` / `AWS ECS` / `Railway`

收到答案后，记录为 TECH_STACK 和 DEPLOY_ENV。

---

### Step 4 — 生成 CLAUDE.md

若 CLAUDE.md 不存在，用 Write 工具生成（将 PROJECT_NAME、TECH_STACK、DEPLOY_ENV 替换为实际值）：

```markdown
# {PROJECT_NAME}

## 团队配置

本项目使用标准 AI 开发团队（13 agents）。
在 Claude Code 中说"使用标准团队开发 你的需求"即可启动 orchestrator。

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

若 `.claude/settings.json` 不存在，用 Write 工具生成：

```json
{
  "permissions": {
    "allow": [
      "Task",
      "Read",
      "Write",
      "Glob",
      "Bash",
      "Grep"
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
