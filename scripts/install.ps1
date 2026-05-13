#Requires -Version 5.1
# 安装标准 AI 开发团队（Windows PowerShell / PowerShell 7+）
# 幂等：重复运行安全，已有记忆库内容不会被覆盖
$ErrorActionPreference = 'Stop'

$ScriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir    = Split-Path -Parent $ScriptDir
$AgentsSrc  = Join-Path $RepoDir 'agents'
$TplSrc     = Join-Path $RepoDir 'templates\memory'
$AgentsDest = Join-Path $HOME    '.claude\agents'
$MemDest    = Join-Path $HOME    '.claude\team-memory\patterns'

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

Write-Host ''
Write-Host '✅ 安装完成！' -ForegroundColor Green
Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '下一步：在你的项目目录里运行初始化'
Write-Host ''
Write-Host "  cd 你的项目目录"
Write-Host "  pwsh `"$RepoDir\scripts\team-init.ps1`""
Write-Host ''
Write-Host '初始化完成后，在 Claude Code 里说：'
Write-Host '  使用标准团队开发 你的需求'
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host ''
