# 安装指南

## 前置条件

- 已安装 [Claude Code](https://docs.claude.com/en/docs/claude-code/quickstart)，验证：`claude --version`

---

## 安装方式

### 方式一：在 Claude Code 内用 Slash Command（推荐，全程不用离开 Claude Code）

```bash
# 1. 克隆仓库（仅首次）
git clone https://github.com/trkjoy/claude-standard-dev-team.git

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
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

**Windows（PowerShell）：**

```powershell
git clone https://github.com/trkjoy/claude-standard-dev-team.git
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

## 升级（版本更新）

### 1. 什么时候需要升级

作者在 GitHub 持续迭代推送新版本（agent 规则调整、新增 agent、bug 修复、知识库模板优化）。当你看到仓库有新 commit 或新 tag 时，建议同步本地。

### 2. 查看当前版本

```bash
# 在仓库目录查看版本号
cat VERSION

# 或查看最近 5 次提交
git log --oneline -5
```

### 3. 升级方式

**方式零：`/team-update`（推荐，唯一会同步项目 CLAUDE.md 的方式）**

进入要升级的项目目录，在 Claude Code 内运行：

```
/team-update            # 升级到仓库最新版
/team-update 1.0.7      # 升级到指定版本（也可用于回滚）
```

它会一次性刷新全局 13 个 agent，并把**当前项目** CLAUDE.md 的团队配置段落同步到目标版本（保留你的技术栈/部署环境字段）。

> 首次使用前，需先用下面任一方式 `git pull && /team-install`，把 `/team-update` 注册到全局命令。

下面三种方式只刷新全局 agents，**不会**更新项目 CLAUDE.md：

#### 三种全局升级方式（与安装方式对应）

**方式一：Claude Code 内升级（推荐）**

```bash
# 1. 进入克隆的仓库目录
cd /path/to/claude-standard-dev-team    # Mac/Linux/WSL
cd C:\path\to\claude-standard-dev-team  # Windows

# 2. 拉取最新代码
git pull

# 3. 在当前目录打开 Claude Code
claude .

# 4. 在 Claude Code 内运行
/team-install
```

**方式二：脚本升级**

```bash
# Mac/Linux/WSL
cd /path/to/claude-standard-dev-team && git pull && bash scripts/install.sh
```

```powershell
# Windows
cd C:\path\to\claude-standard-dev-team; git pull; pwsh .\scripts\install.ps1
```

**方式三：手动升级（只更新部分 agent）**

```bash
git pull
cp agents/orchestrator.md ~/.claude/agents/
# 只复制你需要更新的 agent，其他保持不变
```

### 4. 升级不影响什么（幂等保证）

以下内容**不会**被升级流程覆盖或清空：

- 项目目录里的 `CLAUDE.md`（`/team-init` 生成的项目配置）
- 项目目录里的 `.claude/team-state/`（`STATE.md`、`RETRY_LOG.md`、`DECISIONS.md`、`LEARNINGS.md`）
- 知识库已有内容（`~/.claude/team-memory/patterns/` 下的累积条目）

升级只刷新 `~/.claude/agents/` 和 `~/.claude/commands/` 里的 agent 规则与全局命令。

### 5. 升级后验证生效

1. 重启 Claude Code（关闭后重新 `claude .`），确保命令列表重新加载
2. 在 Claude Code 里输入 `/`，确认 `/team-install`、`/team-init` 在命令列表中
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

### Q: 忘了仓库克隆在哪，怎么重新拉取更新？

A: 重新克隆后直接运行安装命令，效果等同于升级（幂等）：
```bash
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh  # 或在 Claude Code 内运行 /team-install
```

### Q: 升级后 agent 行为变了，如何回滚到旧版本？

A: 用 git checkout 切到指定 tag 或 commit，再重新安装：
```bash
git log --oneline    # 找到旧版本的 commit hash 或 tag
git checkout v1.0.2  # 换成你要回滚的版本号
bash scripts/install.sh
```

### Q: git pull 时提示冲突怎么办？

A: 本地一般不应该修改仓库里的文件。直接强制重置为远端最新版本：
```bash
git fetch origin
git reset --hard origin/main
bash scripts/install.sh
```

---

有问题欢迎开 [Issue](https://github.com/trkjoy/claude-standard-dev-team/issues)。
