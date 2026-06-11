# 安装指南

## 前置条件

- 已安装 [Claude Code](https://docs.claude.com/en/docs/claude-code/quickstart)，验证：`claude --version`

---

## 安装方式

> ⚠️ **安装与升级都在本地脚本完成，不在 Claude Code 内运行。**
> 请先下载并解压对应版本的发布包，再到解压目录运行脚本。

### 方式一：脚本安装（推荐）

**Mac / Linux / WSL：**

```bash
# 进入解压后的发布包目录
cd claude-dev-ai-team
bash scripts/install.sh
```

**Windows（PowerShell）：**

```powershell
cd claude-dev-ai-team
pwsh .\scripts\install.ps1
# 或旧版 PowerShell（RemoteSigned 已足够运行本地脚本，不建议用 Bypass 全量绕过）：
powershell -ExecutionPolicy RemoteSigned -File .\scripts\install.ps1
```

`install` 脚本会自动完成：
- 安装 15 个 agent → `~/.claude/agents/`
- 初始化知识库 → `~/.claude/team-memory/patterns/`
- 分发 workflow 模板 → `~/.claude/team-workflows/`
- 注册全局命令 → `~/.claude/commands/`（`/team-init`、`/team-kb-save`、`/team-version` 在所有项目可用）

**安装后，后续流程全在 Claude Code 内完成：**

```
# 进入你的项目目录，打开 Claude Code，运行：
/team-init

# 回答两个问题（技术栈 + 部署环境），然后说：
使用标准团队开发 你的需求
```

> **之后不再需要解压目录**（升级时才会再次用到）。`/team-init` 已注册为全局命令，在任何项目里都可以直接用。

---

### 方式二：只装部分 agent（高级用法）

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

## 升级（版本更新）

### 1. 什么时候需要升级

作者持续迭代新版本（agent 规则调整、新增 agent、bug 修复、知识库模板优化）。当你拿到新版本的发布包时，下载解压后在本地运行升级脚本同步。

### 2. 查看当前版本

```bash
# 在解压目录查看发布包版本号
cat VERSION                       # Mac/Linux/WSL
Get-Content VERSION               # Windows

# 查看已安装的全局版本
cat ~/.claude/team-version        # Mac/Linux/WSL
Get-Content $HOME\.claude\team-version   # Windows
```

> 也可以在 Claude Code 内运行 `/team-version` 直接查看当前已安装的版本号，判断是否需要升级。

### 3. 升级方式：`update` 脚本（推荐，唯一会同步项目 CLAUDE.md 的方式）

下载并解压**目标版本**的发布包，**进入你要升级的项目目录**，运行解压目录里的 update 脚本：

```bash
# Mac / Linux / WSL（在项目目录下）
bash /path/to/解压目录/scripts/update.sh
```

```powershell
# Windows（在项目目录下）
pwsh C:\path\to\解压目录\scripts\update.ps1
```

> 也可显式指定项目目录：`bash .../scripts/update.sh /path/to/your-project`。

它会一次性完成两件事：
1. **刷新全局**：更新 `~/.claude/` 下的 15 个 agent、命令、知识库（已存在不覆盖）、workflow 模板
2. **同步项目**：把**当前项目** CLAUDE.md 的「## 团队配置」段落同步到发布包版本（保留你的技术栈/部署环境字段）

> 若只想刷新全局、不动任何项目 CLAUDE.md，直接重跑 `scripts/install.sh` / `scripts/install.ps1` 即可。

### 4. 升级不影响什么（幂等保证）

以下内容**不会**被升级流程覆盖或清空：

- 项目目录里的 `CLAUDE.md`（`/team-init` 生成的项目配置）
- 项目目录里的 `.claude/team-state/`（`STATE.md`、`RETRY_LOG.md`、`DECISIONS.md`、`LEARNINGS.md`）
- 知识库已有内容（`~/.claude/team-memory/patterns/` 下的累积条目）

`update` 脚本只刷新 `~/.claude/agents/`、`~/.claude/commands/`、`~/.claude/team-workflows/` 里的 agent 规则、全局命令与 workflow 模板，并按需同步当前项目 CLAUDE.md 的团队配置段落。

### 5. 升级后验证生效

1. 重启 Claude Code（关闭后重新 `claude .`），确保命令列表重新加载
2. 在 Claude Code 里输入 `/`，确认 `/team-init`、`/team-kb-save`、`/team-version` 在命令列表中
3. （可选）确认 agent 文件已更新：

```bash
# Mac/Linux/WSL
cat ~/.claude/agents/orchestrator.md | head -5
```

```powershell
# Windows
Get-Content "$HOME\.claude\agents\orchestrator.md" -TotalCount 5
```

---

## 卸载

```bash
# Mac/Linux/WSL
rm -f ~/.claude/agents/orchestrator.md \
   ~/.claude/agents/product-manager.md \
   ~/.claude/agents/software-architect.md \
   ~/.claude/agents/ui-designer.md \
   ~/.claude/agents/database-optimizer.md \
   ~/.claude/agents/backend-architect.md \
   ~/.claude/agents/frontend-developer.md \
   ~/.claude/agents/devops-automator.md \
   ~/.claude/agents/testing-evidence-collector.md \
   ~/.claude/agents/qa-automator.md \
   ~/.claude/agents/security-engineer.md \
   ~/.claude/agents/code-reviewer.md \
   ~/.claude/agents/reality-checker.md \
   ~/.claude/agents/technical-writer.md \
   ~/.claude/agents/kb-curator.md
rm -f ~/.claude/commands/team-init.md \
   ~/.claude/commands/team-kb-save.md \
   ~/.claude/commands/team-version.md
```

```powershell
# Windows
$a = "$HOME\.claude\agents"
'orchestrator','product-manager','software-architect','ui-designer','database-optimizer',
'backend-architect','frontend-developer','devops-automator','testing-evidence-collector',
'qa-automator','security-engineer','code-reviewer','reality-checker','technical-writer',
'kb-curator' | ForEach-Object {
    Remove-Item "$a\$_.md" -Force -ErrorAction SilentlyContinue
}
Remove-Item "$HOME\.claude\commands\team-init.md","$HOME\.claude\commands\team-kb-save.md","$HOME\.claude\commands\team-version.md" -Force -ErrorAction SilentlyContinue
```

---

## 常见问题

### Q: Claude Code 里找不到 /team-init 或 /team-kb-save 命令

A: 先确认 `install` 脚本已成功运行、`~/.claude/commands/team-init.md` 与 `team-kb-save.md` 已生成，再重启 Claude Code 让它重新加载命令列表。注意：`/team-install`、`/team-update` 自 v1.2.0 起已移除，安装与升级请在本地运行 `scripts/install.*` / `scripts/update.*`。

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

### Q: 升级后 agent 行为变了，如何回滚到旧版本？

A: 下载并解压**旧版本**的发布包，在项目目录运行该旧包里的 `scripts/update.sh` / `scripts/update.ps1` 即可切回（脚本是幂等的，会用旧包内容覆盖全局 agents 与命令）。
