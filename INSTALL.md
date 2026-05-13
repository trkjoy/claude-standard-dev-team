# 安装指南

## 前置条件

- 已安装 [Claude Code](https://docs.claude.com/en/docs/claude-code/quickstart)，验证：`claude --version`

---

## 安装方式

### 方式一：在 Claude Code 内用 Slash Command（推荐，全程不用离开 Claude Code）

```bash
# 1. 克隆仓库（仅首次）
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git

# 2. 在仓库目录打开 Claude Code
cd claude-standard-dev-team
claude .

# 3. 在 Claude Code 里运行安装命令
/team-install
```

`/team-install` 会自动完成：
- 安装 13 个 agent → `~/.claude/agents/`
- 初始化知识库 → `~/.claude/team-memory/patterns/`
- 注册全局命令 → `~/.claude/commands/`（之后 `/team-install` 和 `/team-init` 在所有项目可用）

**安装后，后续流程全在 Claude Code 内完成：**

```
# 进入你的项目目录，打开 Claude Code，运行：
/team-init

# 回答两个问题（技术栈 + 部署环境），然后说：
使用标准团队开发 你的需求
```

> **之后不再需要仓库目录。** `/team-install` 和 `/team-init` 已注册为全局命令，在任何项目里都可以直接用。

---

### 方式二：脚本安装（安装后同样用 /team-init 初始化）

**Mac / Linux / WSL：**

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

**Windows（PowerShell）：**

```powershell
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team
pwsh .\scripts\install.ps1
# 或旧版 PowerShell：
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1
```

脚本与 `/team-install` 效果相同，额外将全局命令注册到 `~/.claude/commands/`。

**安装完成后，进入项目目录，在 Claude Code 里运行：**

```
/team-init
```

交互式问两个问题（技术栈 + 部署环境），自动生成所有配置文件，无需手动编辑。

---

### 方式三：只装部分 agent（高级用法）

```bash
# 只需要 product-manager 帮你写 PRD？
cp agents/product-manager.md ~/.claude/agents/
```

注意：**orchestrator 必须配合至少 2-3 个 agent 才有意义**——它自己不写代码，只负责调度。

---

## /team-init 生成的文件

```
你的项目目录/
  CLAUDE.md                      ← 技术栈、部署环境已填入，无需再编辑
  .claude/
    settings.json                ← Claude Code 权限配置
    team-state/
      STATE.md                   ← 运行状态（中断恢复用）
      RETRY_LOG.md               ← 失败重试历史
      DECISIONS.md               ← 用户确认过的决策
      LEARNINGS.md               ← 项目内临时经验
```

---

## 升级

```bash
# Mac/Linux/WSL
cd /path/to/claude-standard-dev-team && git pull && bash scripts/install.sh

# Windows
cd C:\path\to\claude-standard-dev-team; git pull; pwsh .\scripts\install.ps1

# 或在 Claude Code 内（进入仓库目录后）
/team-install
```

升级不影响已有知识库内容（幂等）。

---

## 卸载

```bash
# Mac/Linux/WSL
rm ~/.claude/agents/orchestrator.md \
   ~/.claude/agents/product-manager.md \
   ~/.claude/agents/software-architect.md \
   ~/.claude/agents/ui-designer.md \
   ~/.claude/agents/database-optimizer.md \
   ~/.claude/agents/backend-architect.md \
   ~/.claude/agents/frontend-developer.md \
   ~/.claude/agents/devops-automator.md \
   ~/.claude/agents/testing-evidence-collector.md \
   ~/.claude/agents/security-engineer.md \
   ~/.claude/agents/code-reviewer.md \
   ~/.claude/agents/reality-checker.md \
   ~/.claude/agents/technical-writer.md
rm -f ~/.claude/commands/team-install.md ~/.claude/commands/team-init.md
```

```powershell
# Windows
$a = "$HOME\.claude\agents"
'orchestrator','product-manager','software-architect','ui-designer','database-optimizer',
'backend-architect','frontend-developer','devops-automator','testing-evidence-collector',
'security-engineer','code-reviewer','reality-checker','technical-writer' | ForEach-Object {
    Remove-Item "$a\$_.md" -Force -ErrorAction SilentlyContinue
}
Remove-Item "$HOME\.claude\commands\team-install.md","$HOME\.claude\commands\team-init.md" -Force -ErrorAction SilentlyContinue
```

---

## 常见问题

### Q: 运行 /team-install 没反应，或 Claude Code 找不到命令

A: 先确认 `.claude/commands/team-install.md` 文件在仓库目录内存在，重启 Claude Code 让它重新加载命令列表。

### Q: PowerShell 报"脚本被禁止运行"

A: 管理员 PowerShell 执行：`Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

### Q: 我已经有自己的 agent，会被覆盖吗？

A: 同名文件会被覆盖。安装前先备份：
```bash
cp ~/.claude/agents/*.md ~/.claude/agents/_backup/
```

### Q: 在 Claude Code 之外（Cursor / Cline）能用吗？

A: 不能。这套配置依赖 Claude Code 的 [Subagents 机制](https://docs.claude.com/en/docs/claude-code/sub-agents)，其他工具没有此能力。

### Q: 跑一次大概多少 token？

A: 主对话消耗很低（几千 token）。orchestrator 派的子 agent 各自独立 session，完整中型项目合计约 **50-200k token**。

---

有问题欢迎开 [Issue](https://github.com/xuanbingbingo/claude-standard-dev-team/issues)。
