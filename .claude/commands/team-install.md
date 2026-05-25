---
description: 安装标准 AI 开发团队（13 agents + 知识库 + 全局命令）
---

你是安装向导，负责把标准 AI 开发团队一次性安装到用户的 Claude Code。

## 任务目标

1. 将 13 个 agent 文件安装到 `~/.claude/agents/`
2. 初始化用户级知识库 `~/.claude/team-memory/patterns/`（已有内容不覆盖）
3. 将 `/team-install` 和 `/team-init` 注册为全局命令（`~/.claude/commands/`）
4. 全程检测 Windows / Mac / Linux，自动选择对应命令

---

## 执行步骤

### Step 1 — 检测操作系统

用 Bash 运行：
```
uname -s 2>/dev/null || echo Windows
```
- 输出含 `Darwin` → macOS
- 输出含 `Linux` → Linux / WSL
- 其他 → Windows（用 PowerShell）

### Step 2 — 确定文件来源

用 Glob 或 Bash 检查：**当前目录或任意父目录**是否存在 `agents/orchestrator.md`。

- **找到了** → 记录该目录为 `REPO_DIR`，直接用本地文件（更快，跳过下载）
- **没找到** → 从 GitHub 下载：

  Mac/Linux/WSL：
  ```bash
  mkdir -p /tmp/csd-install
  curl -sL https://github.com/trkjoy/claude-standard-dev-team/archive/refs/heads/main.tar.gz \
    -o /tmp/csd-install/repo.tar.gz
  tar -xzf /tmp/csd-install/repo.tar.gz -C /tmp/csd-install/
  REPO_DIR="/tmp/csd-install/claude-standard-dev-team-main"
  ```

  Windows（PowerShell）：
  ```powershell
  $tmp = "$env:TEMP\csd-install"
  New-Item -ItemType Directory -Force $tmp | Out-Null
  Invoke-WebRequest "https://github.com/trkjoy/claude-standard-dev-team/archive/refs/heads/main.zip" `
    -OutFile "$tmp\repo.zip"
  Expand-Archive "$tmp\repo.zip" "$tmp" -Force
  $RepoDir = "$tmp\claude-standard-dev-team-main"
  ```

### Step 3 — 安装 agents

Mac/Linux/WSL：
```bash
mkdir -p ~/.claude/agents
cp "$REPO_DIR/agents"/*.md ~/.claude/agents/
echo "已安装 $(ls ~/.claude/agents/*.md | wc -l | tr -d ' ') 个 agent"
```

Windows：
```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\agents" | Out-Null
Copy-Item "$RepoDir\agents\*.md" "$HOME\.claude\agents\" -Force
$cnt = (Get-ChildItem "$HOME\.claude\agents\*.md").Count
Write-Host "已安装 $cnt 个 agent"
```

### Step 4 — 初始化知识库（幂等：已存在则跳过）

目标目录：`~/.claude/team-memory/patterns/`（Windows：`$HOME\.claude\team-memory\patterns\`）

需要复制的 6 个文件（来自 `$REPO_DIR/templates/memory/`）：
- `backend-patterns.md`
- `frontend-patterns.md`
- `contract-patterns.md`
- `qa-patterns.md`
- `security-patterns.md`
- `deployment-patterns.md`

Mac/Linux/WSL（逐文件检查）：
```bash
mkdir -p ~/.claude/team-memory/patterns
for f in backend frontend contract qa security deployment; do
  dest="$HOME/.claude/team-memory/patterns/${f}-patterns.md"
  if [ -f "$dest" ]; then
    echo "  ⏭ 跳过（已存在）：${f}-patterns.md"
  else
    cp "$REPO_DIR/templates/memory/${f}-patterns.md" "$dest"
    echo "  ✅ 初始化：${f}-patterns.md"
  fi
done
```

Windows：
```powershell
$patDest = "$HOME\.claude\team-memory\patterns"
New-Item -ItemType Directory -Force $patDest | Out-Null
foreach ($f in 'backend','frontend','contract','qa','security','deployment') {
  $dest = "$patDest\${f}-patterns.md"
  if (Test-Path $dest) { Write-Host "  ⏭ 跳过：${f}-patterns.md" }
  else { Copy-Item "$RepoDir\templates\memory\${f}-patterns.md" $dest; Write-Host "  ✅ 初始化：${f}-patterns.md" }
}
```

### Step 5 — 注册全局命令（让 /team-install、/team-init、/team-update 在所有项目可用）

Mac/Linux/WSL：
```bash
mkdir -p ~/.claude/commands
cp "$REPO_DIR/.claude/commands/team-install.md" ~/.claude/commands/
cp "$REPO_DIR/.claude/commands/team-init.md" ~/.claude/commands/
cp "$REPO_DIR/.claude/commands/team-update.md" ~/.claude/commands/
echo "✅ 全局命令已注册"
```

Windows：
```powershell
New-Item -ItemType Directory -Force "$HOME\.claude\commands" | Out-Null
Copy-Item "$RepoDir\.claude\commands\team-install.md" "$HOME\.claude\commands\" -Force
Copy-Item "$RepoDir\.claude\commands\team-init.md" "$HOME\.claude\commands\" -Force
Copy-Item "$RepoDir\.claude\commands\team-update.md" "$HOME\.claude\commands\" -Force
Write-Host "✅ 全局命令已注册"
```

### Step 6 — 清理（仅 GitHub 下载时）

若 Step 2 从 GitHub 下载了临时文件，删除临时目录：
- Mac/Linux：`rm -rf /tmp/csd-install`
- Windows：`Remove-Item -Recurse -Force "$env:TEMP\csd-install"`

### Step 7 — 报告完成

输出：

```
✅ 标准 AI 开发团队安装完成！

   已安装 agents  → ~/.claude/agents/
   已初始化知识库 → ~/.claude/team-memory/patterns/
   已注册全局命令 → ~/.claude/commands/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
现在进入你的项目目录，运行：
  /team-init

初始化完成后，说：
  使用标准团队开发 你的需求
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
