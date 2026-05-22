---
description: 把当前项目升级到指定版本（刷新全局 13 agents + 同步当前项目 CLAUDE.md 的团队配置段落）。用法：/team-update [版本号]，省略版本号则升级到仓库最新版。
---

你是团队升级向导，负责把标准 AI 开发团队升级到**指定版本**（或最新版），并同步**当前项目**的 CLAUDE.md。

## 输入

- `$ARGUMENTS` = 目标版本号（可选）。例如 `1.0.7`。
  - **为空** → 升级到仓库 `main` 分支最新版
  - **非空** → 升级到该指定版本（记为 `TARGET_VERSION`）

## 升级范围（两项都做）

1. 刷新全局 agents：`~/.claude/agents/` 下的 13 个 agent
2. 同步当前项目 CLAUDE.md 的「团队配置」段落到目标版本（保留用户的技术栈 / 部署环境字段）

---

## 执行步骤

### Step 1 — 检测操作系统

用 Bash 运行 `uname -s 2>/dev/null || echo Windows`：
- 含 `Darwin` → macOS；含 `Linux` → Linux/WSL；其他 → Windows（用 PowerShell）

### Step 2 — 定位仓库目录 REPO_DIR

检查**当前目录或任意父目录**是否存在 `agents/orchestrator.md`。
- **找到** → 记为 `REPO_DIR`
- **没找到** → 从 GitHub 克隆到临时目录（Mac/Linux 用 `/tmp/csd-update`，Windows 用 `$env:TEMP\csd-update`）：
  ```
  https://github.com/trkjoy/claude-standard-dev-team.git
  ```

### Step 3 — 切换到目标版本

**若 `$ARGUMENTS` 为空**（升级到最新）：
```bash
git -C "$REPO_DIR" fetch origin
git -C "$REPO_DIR" checkout main
git -C "$REPO_DIR" pull
```

**若指定了 `TARGET_VERSION`**：先 `git -C "$REPO_DIR" fetch origin --tags`，然后**按以下顺序三级尝试**切换，命中即停：
1. tag 形式：`git -C "$REPO_DIR" checkout "v$TARGET_VERSION"` 或 `git -C "$REPO_DIR" checkout "$TARGET_VERSION"`
2. commit message 搜索：`git -C "$REPO_DIR" log --all --oneline --grep="bump v$TARGET_VERSION"` 取到 commit hash 后 `git checkout <hash>`
3. 三级都失败 → **停止并报告**：`未找到版本 $TARGET_VERSION，请用 git tag / git log --oneline 确认可用版本号`，结束本命令

> ⚠️ 切换前若仓库有未提交改动，先提示用户，不要强制 `reset --hard` 覆盖用户本地修改。

### Step 4 — 读取目标版本号

读取 `$REPO_DIR/VERSION` 文件内容，记为 `RESOLVED_VERSION`，用于最终报告。

### Step 5 — 刷新全局 agents

Mac/Linux/WSL：
```bash
mkdir -p ~/.claude/agents
cp "$REPO_DIR/agents"/*.md ~/.claude/agents/
echo "已刷新 $(ls ~/.claude/agents/*.md | wc -l | tr -d ' ') 个 agent"
```

Windows：
```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\agents" | Out-Null
Copy-Item "$RepoDir\agents\*.md" "$HOME\.claude\agents\" -Force
$cnt = (Get-ChildItem "$HOME\.claude\agents\*.md").Count
Write-Host "已刷新 $cnt 个 agent"
```

### Step 6 — 同步当前项目 CLAUDE.md 的「团队配置」段落

> 目标：把旧项目 CLAUDE.md 里过时的启动说明，更新为目标版本的最新引导，**同时保留用户填写的技术栈 / 部署环境**。

1. 检查**当前工作目录**（不是 REPO_DIR）是否存在 `CLAUDE.md`：
   - **不存在** → 提示用户「当前项目尚未初始化，请先运行 `/team-init`」，跳过本步
   - **存在** → 继续

2. 用 Read 读取当前项目 `CLAUDE.md` 全文，并用 Read 读取 `$REPO_DIR/templates/memory/project-CLAUDE.md` 取得**最新的「## 团队配置」段落**。

3. 用 Edit 工具，把当前 `CLAUDE.md` 中从 `## 团队配置` 开始、到下一个二级标题（`## 项目上下文` 或其他 `## `）之前的整段内容，**替换为模板里的最新「## 团队配置」段落**。
   - **必须保留**：`## 项目上下文`（技术栈、部署环境）、`## 团队运行机制` 及用户自行添加的任何其他段落
   - **幂等**：若现有「团队配置」段落已与最新模板一致，报告「CLAUDE.md 已是最新，无需更新」，不做改动
   - 若现有 CLAUDE.md 结构异常（找不到 `## 团队配置` 标题），不要强行猜测，**展示现有内容并询问用户**如何处理

### Step 7 — 清理（仅当 Step 2 从 GitHub 临时克隆时）

- Mac/Linux：`rm -rf /tmp/csd-update`
- Windows：`Remove-Item -Recurse -Force "$env:TEMP\csd-update"`

### Step 8 — 报告完成

```
✅ 团队升级完成

   目标版本    → {RESOLVED_VERSION}
   全局 agents → 已刷新 13 个（~/.claude/agents/）
   项目 CLAUDE.md → {已更新团队配置段落 / 已是最新 / 当前项目未初始化}

⚠️ 重启 Claude Code 让新 agent 与命令生效。
```

---

## 注意事项

- **本命令只改两处**：全局 `~/.claude/agents/` 和当前项目 `CLAUDE.md` 的团队配置段落。**不动** `.claude/team-state/`、不动知识库 `~/.claude/team-memory/`、不动用户的技术栈/部署环境字段。
- 升级后必须**重启 Claude Code**，agent 与命令才会重新加载。
- 回滚：`/team-update <旧版本号>` 即可切回指定版本（前提是该版本有对应 tag 或 `bump vX.Y.Z` commit）。
