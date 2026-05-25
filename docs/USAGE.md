# 使用指南：在三大 AI CLI 工具中使用标准团队

本文档介绍如何在 **Claude Code**、**OpenAI Codex CLI** 和 **Gemini CLI** 中安装并使用这套 13-agent 标准 AI 开发团队。

---

## 目录

- [Claude Code（原生支持）](#claude-code原生支持)
  - [Mac / Linux / WSL 安装](#mac--linux--wsl-安装)
  - [Windows 原生安装](#windows-原生安装powershell)
  - [完整流程与常用操作](#完整流程与常用操作)
- [OpenAI Codex CLI（仅部分兼容）](#openai-codex-cli仅部分兼容)
- [Gemini CLI（仅部分兼容）](#gemini-cli仅部分兼容)
- [兼容性对比](#兼容性对比)

---

## Claude Code（原生支持）

> 这套团队是专为 Claude Code 设计的。所有功能完整支持。

### 前置条件

- 安装 [Claude Code](https://docs.claude.com/en/docs/claude-code/quickstart)，验证：`claude --version`

---

### Mac / Linux / WSL 安装

**第一步：全局安装（一次性）**

```bash
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

`install.sh` 自动完成：
- 将 13 个 agent 复制到 `~/.claude/agents/`
- 初始化用户级知识库 `~/.claude/team-memory/patterns/`（已存在则跳过）

**第二步：在项目目录初始化（每个新项目做一次）**

```bash
cd 你的项目目录
bash /path/to/claude-standard-dev-team/scripts/team-init.sh
```

脚本会交互式问两个问题：

```
请回答以下两个问题（直接回车使用括号内的示例值）：

  技术栈（例：Express.js, React, PostgreSQL）：  Express.js, React, PostgreSQL
  部署环境（例：Docker + Nginx，或 Vercel）：    Docker + Nginx
```

填完即生成配置文件，**无需手动编辑任何文件**。

**第三步：开始使用**

在项目目录打开 Claude Code，输入：

```
使用标准团队开发 你的需求
```

---

### Windows 原生安装（PowerShell）

> 要求：Windows PowerShell 5.1+ 或 PowerShell 7+，推荐以 PowerShell 运行。

**第一步：全局安装（一次性）**

```powershell
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
pwsh .\scripts\install.ps1
```

或 Windows PowerShell：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

`install.ps1` 自动完成：
- 将 13 个 agent 复制到 `%USERPROFILE%\.claude\agents\`
- 初始化用户级知识库 `%USERPROFILE%\.claude\team-memory\patterns\`（已存在则跳过）

**第二步：在项目目录初始化（每个新项目做一次）**

```powershell
cd 你的项目目录
pwsh "C:\path\to\claude-standard-dev-team\scripts\team-init.ps1"
```

脚本会交互式问两个问题：

```
请回答以下两个问题（直接回车使用括号内的示例值）：

  技术栈（例：Express.js, React, PostgreSQL）：  Express.js, React, PostgreSQL
  部署环境（例：Docker + Nginx，或 Vercel）：    Docker + Nginx
```

填完即生成配置文件，**无需手动编辑任何文件**。

> **ExecutionPolicy 报错？** 用管理员 PowerShell 运行一次：
> ```powershell
> Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
> ```

**第三步：开始使用**

在项目目录打开 Claude Code，输入：

```
使用标准团队开发 你的需求
```

---

### 完整流程与常用操作

**orchestrator 自动执行的 11 阶段：**

```
Phase 0    初始化目录 + 状态文件
Phase 1    product-manager 生成 PRD
  ⏸ 等你确认功能范围
Phase 2    software-architect 生成 API 契约 / DB Schema / 技术规范
  ⏸ 等你确认接口列表
Phase 2.5  ui-designer 生成设计规范 + CSS 变量
Phase 3    orchestrator 拆任务清单
Phase 4    database-optimizer 创建迁移文件
Phase 4.9  读取后端历史错误模式，注入 backend-architect 指令
Phase 5    backend-architect 逐任务实现 + testing-evidence-collector 逐任务验证
           （三级智能重试：失败 → 查知识库 → 分流 software-architect/devops-automator → 暂停）
Phase 5.9  读取前端历史错误模式，注入 frontend-developer 指令
Phase 6    frontend-developer 逐任务实现 + testing-evidence-collector 逐任务验证
           （同上，三级智能重试）
Phase 7    security-engineer 安全扫描
Phase 8    code-reviewer 代码评审
Phase 9    devops-automator 生成 Dockerfile + CI/CD
Phase 10   reality-checker 最终验收（READY 才放行）
Phase 11   technical-writer 生成 README + API 文档
Phase 11.5 知识写回（本次验证有效的修复方案存入记忆库，下次自动避坑）
```

**只有 Phase 1 / Phase 2 两次暂停等你确认，其余全自动。**

**查看当前运行状态：**

```bash
cat .claude/team-state/STATE.md
```

**中断后恢复（再次打开 Claude Code 输入）：**

```
继续上次的开发
```

orchestrator 读取 `STATE.md` 从中断点恢复，已完成的阶段不会重跑。

**审查已有代码（Audit 模式）：**

```
审查当前项目代码
```

只走 Audit 模式（code-reviewer + security-engineer），不执行完整 11 阶段。

**升级 agent：**

```bash
# Mac/Linux/WSL
cd /path/to/claude-standard-dev-team && git pull && bash scripts/install.sh

# Windows
cd C:\path\to\claude-standard-dev-team; git pull; pwsh .\scripts\install.ps1
```

升级不影响已有的知识库内容（幂等）。

**卸载：**

```bash
# Mac/Linux/WSL
cd ~/.claude/agents
rm orchestrator.md product-manager.md software-architect.md ui-designer.md \
   database-optimizer.md backend-architect.md frontend-developer.md \
   devops-automator.md testing-evidence-collector.md security-engineer.md \
   code-reviewer.md reality-checker.md technical-writer.md
```

```powershell
# Windows
$agents = "$HOME\.claude\agents"
'orchestrator','product-manager','software-architect','ui-designer',
'database-optimizer','backend-architect','frontend-developer',
'devops-automator','testing-evidence-collector','security-engineer',
'code-reviewer','reality-checker','technical-writer' | ForEach-Object {
    Remove-Item "$agents\$_.md" -Force -ErrorAction SilentlyContinue
}
```

---

**故障排除：**

| 现象 | 原因 | 解决 |
|---|---|---|
| Claude Code 没有调用 orchestrator，直接开始写代码 | agent 文件未被加载 | 确认文件在 `~/.claude/agents/`，重启 Claude Code |
| 报错 `orchestrator ran as a subagent and can't dispatch further agents` | orchestrator 被错误地用 Task 启动为 subagent；Claude Code 不支持 subagent 嵌套派发 | 这是正确行为：主会话应**亲自担任 orchestrator**（读取 `~/.claude/agents/orchestrator.md` 作为手册，自己用 Task 派发下游），而不是 Task 启动 orchestrator 本身。确认已升级到 v1.0.7+ 并重启 Claude Code |
| orchestrator 自己读代码/写文件，从不派发下游 agent | 同上——它作为 subagent 无法派发，于是退化成自己硬扛 | 升级到 v1.0.7+；让主会话亲自担任 orchestrator |
| PowerShell 报"脚本被禁止运行" | ExecutionPolicy 限制 | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| 某 Phase 卡住超过 3 次重试 | 需要人工介入 | orchestrator 会暂停并展示卡点报告，处理后输入"继续" |
| 记忆库没有内容（patterns 文件为空） | 正常，首次使用 | 记忆库只在 Phase 11.5 写回（reality-checker READY 后） |
| CLAUDE.md 里的技术栈想改 | 需要更新 | 直接编辑 `CLAUDE.md` 中的"技术栈:"字段即可 |

---

## OpenAI Codex CLI（仅部分兼容）

> Codex CLI 没有原生 multi-agent / subagent 机制，无法自动运行 orchestrator。
> 可以把单个 agent 的 prompt 当作系统提示手动调用，适合专项任务。

### 兼容性说明

| 功能 | 支持情况 |
|---|---|
| 单个 agent prompt 内容 | ✅ 可复制到 `--instructions` 参数使用 |
| orchestrator 自动调度 | ❌ 需要手动逐步调用 |
| `Task` 工具（subagent 并发） | ❌ 不支持 |
| 自动 Dev-QA Loop | ❌ 需要手动触发 |
| 知识库注入 / 记忆写回 | ❌ 需要手动维护 |

### 安装

```bash
npm install -g @openai/codex
# 设置 API Key
export OPENAI_API_KEY="your-key"
```

只需克隆仓库获取 agent prompt 文件：

```bash
git clone https://github.com/trkjoy/claude-standard-dev-team.git
```

### 手动多步调用（示例）

**Step 1：生成 PRD（product-manager）**

```bash
codex --model gpt-4o \
  --instructions "$(cat claude-standard-dev-team/agents/product-manager.md)" \
  "帮我分析以下需求并生成 PRD：用户管理系统，支持注册/登录/角色权限"
```

**Step 2：生成 API 契约（software-architect）**

```bash
codex --model gpt-4o \
  --instructions "$(cat claude-standard-dev-team/agents/software-architect.md)" \
  "根据以下 PRD 生成 API_CONTRACT、DB_SCHEMA、TECH_SPEC：$(cat PRD.md)"
```

**Step 3：安全扫描（security-engineer）**

```bash
codex --model gpt-4o \
  --instructions "$(cat claude-standard-dev-team/agents/security-engineer.md)" \
  "扫描当前项目 src/ 目录，输出 SECURITY_REPORT"
```

### 脚本化多步流程

```bash
#!/usr/bin/env bash
AGENTS="./claude-standard-dev-team/agents"

# Phase 1
codex --model gpt-4o --instructions "$(cat $AGENTS/product-manager.md)" "需求：$1" > PRD.md
echo "PRD 生成完成，请确认 PRD.md 后按回车继续..."
read -r

# Phase 2
codex --model gpt-4o --instructions "$(cat $AGENTS/software-architect.md)" \
  "根据 PRD 生成契约：$(cat PRD.md)" > API_CONTRACT.md
```

### 注意事项

- 缺少 Dev-QA Loop，需手动在每个接口实现后运行测试
- 适合专项任务（"只要 security-engineer 扫一下"），不适合全流程
- `--instructions` 有长度限制，agent prompt 太长时需截取关键部分

---

## Gemini CLI（仅部分兼容）

> Gemini 有百万 token 上下文，可以把整个项目传给单个 agent 做评审/验收，但同样缺乏自动调度能力。

### 兼容性说明

| 功能 | 支持情况 |
|---|---|
| 单个 agent prompt | ✅ 通过 `--system-prompt` 传入 |
| 多文件/目录上下文 | ✅ `-f <目录>` 自动扫描目录内所有文件 |
| orchestrator 自动调度 | ❌ 需要手动逐步调用 |
| `Task` 工具（subagent） | ❌ 不支持 |
| 知识库注入 / 记忆写回 | ❌ 需要手动维护 |

### 安装

```bash
npm install -g @google/generative-ai-cli
export GOOGLE_API_KEY="your-key"
```

### 单 agent 专项调用

**代码评审（code-reviewer）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/code-reviewer.md)" \
  -f src/ \
  "评审 src/ 目录的代码"
```

**安全扫描（security-engineer）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/security-engineer.md)" \
  -f src/ \
  "扫描安全问题，输出 SECURITY_REPORT"
```

**最终验收（reality-checker）**

```bash
# 大上下文优势：传入整个项目做验收
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/reality-checker.md)" \
  -f docs/ -f src/ -f project-tasks/ \
  "对整个项目做最终验收，判决 READY 或 NEEDS WORK"
```

**架构设计（software-architect）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/software-architect.md)" \
  -f PRD.md \
  "生成 API_CONTRACT、DB_SCHEMA、TECH_SPEC"
```

### Gemini CLI 特有技巧

- **`-f <目录>`**：自动递归扫描目录所有文件，非常适合代码评审和安全扫描
- **模型选择**：`gemini-2.5-pro` 用于复杂任务；`gemini-2.5-flash` 用于快速文档生成
- **传多个目录**：`-f docs/ -f src/` 同时传多个上下文

---

## 兼容性对比

| 功能 | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| 原生 subagent 调度 | ✅ | ❌ | ❌ |
| 完整 11 阶段自动流程 | ✅ | ❌ 需手动 | ❌ 需手动 |
| 交互式安装 + 即用 | ✅ | ❌ | ❌ |
| 三级智能重试 | ✅ | ❌ | ❌ |
| 断点恢复 | ✅ | ❌ | ❌ |
| 跨项目知识库 | ✅ | ❌ | ❌ |
| 单 agent 专项调用 | ✅ | ✅ | ✅ |
| 大文件/目录上下文 | ✅ | ✅（有限） | ✅（100 万 token） |
| Windows 原生支持 | ✅ PowerShell | ✅ | ✅ |
| **推荐用途** | **完整项目开发** | **单步专项任务** | **代码评审/安全扫描** |

### 选择建议

- **有 Claude Code**：首选，完整体验 11 阶段自动流程 + 知识库积累
- **只有 Gemini CLI**：用 `gemini-2.5-pro` + 大上下文做 code-reviewer、security-engineer、reality-checker 这三个专项任务，价值最高
- **只有 Codex CLI**：可以做单步，但建议升级到 Claude Code 获得完整体验
- **三个都有**：主流程用 Claude Code，需要第二意见时用 Gemini 独立验收
