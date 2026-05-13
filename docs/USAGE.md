# 使用指南：在三大 AI CLI 工具中使用标准团队

本文档介绍如何在 **Claude Code**、**OpenAI Codex CLI** 和 **Gemini CLI** 中安装并使用这套 13-agent 标准 AI 开发团队。

---

## 目录

- [Claude Code（原生支持）](#claude-code原生支持)
- [OpenAI Codex CLI（仅部分兼容）](#openai-codex-cli仅部分兼容)
- [Gemini CLI（仅部分兼容）](#gemini-cli仅部分兼容)
- [兼容性对比](#兼容性对比)

---

## Claude Code（原生支持）

> 这套团队是专为 Claude Code 设计的。所有功能完整支持。

### 前置条件

- 安装 [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/quickstart)
- 验证：`claude --version` 能输出版本号

### 安装

**方式一：安装脚本（推荐）**

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

`install.sh` 会自动：
1. 将 13 个 agent 复制到 `~/.claude/agents/`
2. 初始化用户级长期记忆库 `~/.claude/team-memory/patterns/`（若已存在则跳过，保留历史内容）

**方式二：手动复制**

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
mkdir -p ~/.claude/agents
cp claude-standard-dev-team/agents/*.md ~/.claude/agents/
```

### 初始化新项目

在每个新项目目录里运行一次：

```bash
bash /path/to/claude-standard-dev-team/scripts/team-init.sh
```

生成文件：
```
你的项目目录/
  CLAUDE.md                        ← 填写技术栈和部署环境
  .claude/
    settings.json                  ← 权限配置
    team-state/
      STATE.md                     ← 运行状态（断点恢复用）
      RETRY_LOG.md                 ← 重试历史
      DECISIONS.md                 ← 用户确认过的决策
      LEARNINGS.md                 ← 项目内临时经验
```

### 填写 CLAUDE.md

打开项目根目录的 `CLAUDE.md`，填写这两个字段：

```markdown
- 技术栈: Express.js, React, PostgreSQL
- 部署环境: Docker + Nginx
```

这让 orchestrator 在调用前过滤出匹配你技术栈的历史错误提示，减少重复踩坑。

### 启动

在项目目录里打开 Claude Code，输入一句话：

```
使用标准团队帮我开发一个 todo 应用
```

或者更具体的需求描述：

```
使用标准团队开发：用户管理系统，支持注册/登录/角色权限，技术栈 Express + React + PostgreSQL，需要 Docker 部署
```

### orchestrator 的自动流程

```
Phase 0   初始化目录 + 状态文件
Phase 1   product-manager 生成 PRD
  ⏸ 暂停等你确认功能范围
Phase 2   software-architect 生成 API 契约 / DB Schema / 技术规范
  ⏸ 暂停等你确认接口列表
Phase 2.5 ui-designer 生成设计规范 + CSS 变量
Phase 3   orchestrator 拆任务清单
Phase 4   database-optimizer 创建迁移文件
Phase 4.9 读取后端历史错误模式，注入 backend-architect 指令
Phase 5   backend-architect 逐任务实现 + testing-evidence-collector 逐任务验证（三级智能重试）
Phase 5.9 读取前端历史错误模式，注入 frontend-developer 指令
Phase 6   frontend-developer 逐任务实现 + testing-evidence-collector 逐任务验证（三级智能重试）
Phase 7   security-engineer 安全扫描
Phase 8   code-reviewer 代码评审
Phase 9   devops-automator 生成 Dockerfile + CI/CD
Phase 10  reality-checker 最终验收（READY 才放行）
Phase 11  technical-writer 生成 README + API 文档
Phase 11.5 知识写回：把本次验证有效的修复方案存入记忆库（下次避坑）
```

两次人工确认（Phase 1/2 后），其余全自动。

### 常用操作

**查看当前运行到哪**

```bash
cat .claude/team-state/STATE.md
```

**查看重试历史**

```bash
cat .claude/team-state/RETRY_LOG.md
```

**中断后恢复**

直接再输入"继续"或"使用标准团队继续上次的开发"，orchestrator 会读取 `STATE.md` 从中断点恢复。

**审查已有代码（不走完整流程）**

```
审查当前项目代码
```

orchestrator 进入 Audit 模式，调用 code-reviewer 和 security-engineer，输出 `REVIEW_REPORT.md` 和 `SECURITY_REPORT.md`。

**卸载**

```bash
cd ~/.claude/agents
rm orchestrator.md product-manager.md software-architect.md ui-designer.md \
   database-optimizer.md backend-architect.md frontend-developer.md \
   devops-automator.md testing-evidence-collector.md security-engineer.md \
   code-reviewer.md reality-checker.md technical-writer.md
```

### 故障排除

| 现象 | 原因 | 解决 |
|---|---|---|
| Claude Code 没有调用 orchestrator，直接开始写代码 | agent 文件未被加载 | 确认文件在 `~/.claude/agents/`，重启 Claude Code |
| 某个 Phase 卡住 3 次 | 任务超过重试上限 | orchestrator 会暂停并展示卡点报告，按提示人工介入后输入"继续" |
| 看不到 `.claude/team-state/` 目录 | 没有运行 `team-init.sh` | 在项目目录运行 `bash scripts/team-init.sh` |
| 记忆库没有内容 | 没有跑完过一次 READY 项目 | 正常，记忆库只在 Phase 11.5 写回（reality-checker READY 后） |

---

## OpenAI Codex CLI（仅部分兼容）

> Codex CLI 没有原生的 multi-agent / subagent 机制，无法直接运行 orchestrator。以下是退化使用方案，可以把单个 agent 的 prompt 当作系统提示手动调用。

### 前置条件

```bash
npm install -g @openai/codex
codex --version
```

### 兼容限制说明

| 功能 | 支持情况 |
|---|---|
| 单个 agent 的 prompt 内容 | ✅ 可以复制到 `--instructions` 参数使用 |
| orchestrator 自动调度 | ❌ 不支持，需要手动逐步调用 |
| `Task` 工具（subagent 并发） | ❌ Codex CLI 无此能力 |
| 自动 Dev-QA Loop | ❌ 需要手动触发 |
| 状态文件恢复 | ❌ 需要手动管理 |

### 安装

克隆仓库（只需要 `agents/` 目录）：

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
```

### 使用方式：手动多步调用

把 orchestrator 的 11 阶段流程拆成手动步骤，逐一调用对应 agent：

**Step 1：生成 PRD**

```bash
codex \
  --model gpt-4o \
  --instructions "$(sed -n '/^# /,/^---$/p' claude-standard-dev-team/agents/product-manager.md | head -80)" \
  "帮我分析以下需求并生成 PRD：用户管理系统，支持注册/登录/角色权限"
```

**Step 2：生成 API 契约**

```bash
codex \
  --model gpt-4o \
  --instructions "$(sed -n '/^# /,/^---$/p' claude-standard-dev-team/agents/software-architect.md | head -80)" \
  "根据以下 PRD 生成 API_CONTRACT 和 DB_SCHEMA：$(cat PRD.md)"
```

**Step 3：后端实现**

```bash
codex \
  --model gpt-4o \
  --instructions "$(sed -n '/^# /,/^---$/p' claude-standard-dev-team/agents/backend-architect.md | head -80)" \
  "按以下 API_CONTRACT 实现 POST /api/auth/login 接口：$(cat API_CONTRACT.md)"
```

**Step 4：安全扫描**

```bash
codex \
  --model gpt-4o \
  --instructions "$(sed -n '/^# /,/^---$/p' claude-standard-dev-team/agents/security-engineer.md | head -80)" \
  "扫描当前项目 src/ 目录，输出 SECURITY_REPORT"
```

### 脚本化多步流程（示例）

```bash
#!/usr/bin/env bash
AGENTS_DIR="./claude-standard-dev-team/agents"

# Phase 1
codex --model gpt-4o \
  --instructions "$(cat $AGENTS_DIR/product-manager.md)" \
  "需求：$1" > PRD.md

echo "PRD 生成完成，请检查 PRD.md 后按回车继续..."
read

# Phase 2
codex --model gpt-4o \
  --instructions "$(cat $AGENTS_DIR/software-architect.md)" \
  "根据 PRD 生成契约：$(cat PRD.md)" > API_CONTRACT.md
```

### 注意事项

- Codex CLI 的 `--instructions` 长度有限制，agent prompt 太长时需要截取关键部分
- 缺少 Dev-QA Loop，需要手动在每个接口实现后运行测试
- 知识库注入和记忆写回机制需要手动维护
- 适合只用单个 agent 做专项任务（如"只要 security-engineer 扫描一下"），不适合全流程

---

## Gemini CLI（仅部分兼容）

> Gemini CLI 有文件上下文能力，可以把 agent prompt 文件直接传入对话，但同样缺乏 orchestrator 的自动调度机制。

### 前置条件

```bash
npm install -g @google/generative-ai-cli
# 或通过 pip
pip install google-generativeai-cli

# 设置 API Key
export GOOGLE_API_KEY="your-key-here"
gemini --version
```

### 兼容限制说明

| 功能 | 支持情况 |
|---|---|
| 单个 agent 的 prompt | ✅ 可通过 `--system-prompt` 或文件引用传入 |
| 多文件上下文（CLAUDE.md + agent） | ✅ Gemini 支持大上下文窗口，可同时传多个文件 |
| orchestrator 自动调度 | ❌ 需要手动逐步调用 |
| `Task` 工具（subagent） | ❌ 不支持 |
| 自动 Dev-QA Loop | ❌ 需要手动触发 |

### 安装

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
```

### 使用方式：单 agent 专项调用

Gemini CLI 的 `-f` 参数可以直接引用文件作为上下文：

**生成 PRD（product-manager）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/product-manager.md)" \
  "帮我分析以下需求并生成 PRD：用户管理系统"
```

**安全扫描（security-engineer）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/security-engineer.md)" \
  -f src/ \
  "扫描 src/ 目录的安全问题，输出 SECURITY_REPORT"
```

**代码评审（code-reviewer）**

```bash
# 把待评审代码和 agent prompt 一起传入
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/code-reviewer.md)" \
  -f src/routes/auth.js \
  "评审这个文件"
```

**架构设计（software-architect）**

```bash
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/software-architect.md)" \
  -f PRD.md \
  "根据 PRD 生成 API_CONTRACT、DB_SCHEMA 和 TECH_SPEC"
```

### 利用大上下文窗口传入完整项目

Gemini 2.5 Pro 有 100 万 token 上下文，可以一次传入整个项目：

```bash
# 把所有相关文档和代码一起传给 reality-checker 做最终验收
gemini \
  --model gemini-2.5-pro \
  --system-prompt "$(cat claude-standard-dev-team/agents/reality-checker.md)" \
  -f docs/ \
  -f src/ \
  -f project-tasks/ \
  "对整个项目做最终验收，判决 READY 或 NEEDS WORK"
```

### 伪多步流程（shell 脚本）

```bash
#!/usr/bin/env bash
AGENTS_DIR="./claude-standard-dev-team/agents"

# Phase 1: PRD
gemini --model gemini-2.5-pro \
  --system-prompt "$(cat $AGENTS_DIR/product-manager.md)" \
  "需求：$1" > PRD.md
echo "PRD 生成完成，请确认后按回车继续..."
read

# Phase 2: 契约
gemini --model gemini-2.5-pro \
  --system-prompt "$(cat $AGENTS_DIR/software-architect.md)" \
  -f PRD.md \
  "生成 API_CONTRACT, DB_SCHEMA, TECH_SPEC" > API_CONTRACT.md

# Phase 7: 安全扫描（有代码后执行）
gemini --model gemini-2.5-pro \
  --system-prompt "$(cat $AGENTS_DIR/security-engineer.md)" \
  -f src/ \
  "扫描安全问题" > SECURITY_REPORT.md

echo "Done. 请查看 API_CONTRACT.md 和 SECURITY_REPORT.md"
```

### Gemini CLI 特有技巧

**利用 `-f` 传入目录**：Gemini CLI 支持 `-f <目录>` 自动扫描目录内所有文件，非常适合代码评审和安全扫描。

**模型选择**：
- `gemini-2.5-pro`：复杂任务（架构设计、安全扫描、最终验收）
- `gemini-2.5-flash`：快速任务（文档生成、简单代码评审）

---

## 兼容性对比

| 功能 | Claude Code | Codex CLI | Gemini CLI |
|---|---|---|---|
| 原生 subagent 调度 | ✅ | ❌ | ❌ |
| 完整 11 阶段自动流程 | ✅ | ❌ 需手动 | ❌ 需手动 |
| 三级智能重试 | ✅ | ❌ | ❌ |
| 状态文件断点恢复 | ✅ | ❌ | ❌ |
| 用户级长期记忆库 | ✅ | ❌ | ❌ |
| 知识库写回 | ✅ | ❌ | ❌ |
| 单 agent 专项调用 | ✅ | ✅ | ✅ |
| 大文件/目录上下文 | ✅ | ✅（有限） | ✅（100万 token） |
| 推荐用途 | 完整项目开发 | 单接口实现/扫描 | 代码评审/安全扫描 |

### 结论

- **Claude Code**：唯一能跑完整 11 阶段自动流程的工具，推荐首选。
- **Gemini CLI**：大上下文是优势，适合把单个 agent（尤其是 code-reviewer、security-engineer、reality-checker）当作"专项审查工具"来用。
- **Codex CLI**：可以用于单步骤任务，但需要自己手动管理流程，体验最差。

如果你只有 Codex CLI 或 Gemini CLI，建议仅把本仓库当作**高质量 prompt 库**来用——把你需要的那个 agent 文件内容复制为 system prompt，手动执行那一个步骤。完整的 13-agent 自动流程请使用 Claude Code。
