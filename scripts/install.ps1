#Requires -Version 5.1
# 安装标准 AI 开发团队（Windows PowerShell / PowerShell 7+）
# 幂等：重复运行安全，已有记忆库内容不会被覆盖
$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir    = Split-Path -Parent $ScriptDir
$AgentsSrc  = Join-Path $RepoDir 'agents'
$TplSrc     = Join-Path $RepoDir 'templates\memory'
$AgentsDest  = Join-Path $HOME    '.claude\agents'
$MemDest     = Join-Path $HOME    '.claude\team-memory\patterns'
$CommandsSrc = Join-Path $RepoDir '.claude\commands'
$CommandsDest= Join-Path $HOME    '.claude\commands'

if (-not (Test-Path $AgentsSrc)) {
    Write-Host ''
    Write-Host '❌ 找不到 agents 目录：' $AgentsSrc -ForegroundColor Red
    Write-Host '   请在 claude-standard-dev-team 克隆目录中运行此脚本。'
    exit 1
}

Write-Host ''
Write-Host '📦 正在安装标准 AI 开发团队...' -ForegroundColor Cyan
Write-Host ''

# 1. 安装 agent 文件到 ~/.claude/agents/
New-Item -ItemType Directory -Force -Path $AgentsDest | Out-Null
Get-ChildItem "$AgentsSrc\*.md" | Copy-Item -Destination $AgentsDest -Force
$cnt = (Get-ChildItem "$AgentsDest\*.md").Count
Write-Host "✅ 已安装 $cnt 个 agent -> $AgentsDest" -ForegroundColor Green

# 2. 初始化用户级知识库（已存在则跳过，保留历史积累）
New-Item -ItemType Directory -Force -Path $MemDest | Out-Null
foreach ($p in 'backend','frontend','contract','qa','security','deployment') {
    $src  = Join-Path $TplSrc  "${p}-patterns.md"
    $dest = Join-Path $MemDest "${p}-patterns.md"
    if (-not (Test-Path $src)) {
        Write-Host "❌ 模板文件缺失：$src" -ForegroundColor Red
        exit 1
    }
    if (Test-Path $dest) {
        Write-Host "  ⏭  跳过（已存在）：${p}-patterns.md"
    } else {
        Copy-Item $src $dest
        Write-Host "  ✅ 初始化：${p}-patterns.md" -ForegroundColor Green
    }
}

# 3. 注册全局 Claude Code 命令（让 /team-install 和 /team-init 全局可用）
if (Test-Path $CommandsSrc) {
    New-Item -ItemType Directory -Force -Path $CommandsDest | Out-Null
    Copy-Item "$CommandsSrc\team-install.md" "$CommandsDest\" -Force
    Copy-Item "$CommandsSrc\team-init.md"    "$CommandsDest\" -Force
    Write-Host "✅ 已注册全局命令 -> $CommandsDest" -ForegroundColor Green
} else {
    Write-Host '  ⚠  跳过命令注册（.claude\commands\ 目录不存在）'
}

Write-Host ''
Write-Host '✅ 安装完成！' -ForegroundColor Green
Write-Host ''
Write-Host '========================================='
Write-Host '后续操作全在 Claude Code 内完成：'
Write-Host ''
Write-Host '  进入项目目录，打开 Claude Code，运行：'
Write-Host '    /team-init' -ForegroundColor Yellow
Write-Host ''
Write-Host '  初始化后说：'
Write-Host '    使用标准团队开发 你的需求' -ForegroundColor Yellow
Write-Host '========================================='
Write-Host ''
