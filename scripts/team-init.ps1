#Requires -Version 5.1
# 在当前目录初始化标准团队项目（Windows PowerShell / PowerShell 7+）
# 交互式收集项目配置，生成即用的 CLAUDE.md，无需手动编辑
# 幂等：已存在的文件不会被覆盖
$ErrorActionPreference = 'Stop'

$ScriptDir       = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir         = Split-Path -Parent $ScriptDir
$TplSrc          = Join-Path $RepoDir 'templates\memory'
$StateTplSrc     = Join-Path $TplSrc  'team-state'
$ProjectName     = Split-Path -Leaf (Get-Location).Path

if (-not (Test-Path $TplSrc)) {
    Write-Host ''
    Write-Host "❌ templates 目录不存在：$TplSrc" -ForegroundColor Red
    Write-Host '   请先运行 install.ps1，或指定正确的仓库路径。'
    exit 1
}

Write-Host ''
Write-Host "🚀 正在初始化项目：$ProjectName" -ForegroundColor Cyan
Write-Host ''

# ── CLAUDE.md ────────────────────────────────────────────────────────
if (Test-Path 'CLAUDE.md') {
    Write-Host '⏭  CLAUDE.md 已存在，跳过（如需更新请手动编辑）'
    $TechStack = $null
    $DeployEnv = $null
} else {
    # 交互式收集项目配置
    Write-Host '请回答以下两个问题（直接回车使用括号内的示例值）：'
    Write-Host ''

    $TechStack = Read-Host '  技术栈（例：Express.js, React, PostgreSQL）'
    if ([string]::IsNullOrWhiteSpace($TechStack)) { $TechStack = 'Express.js, React, PostgreSQL' }

    $DeployEnv = Read-Host '  部署环境（例：Docker + Nginx，或 Vercel）'
    if ([string]::IsNullOrWhiteSpace($DeployEnv)) { $DeployEnv = 'Docker + Nginx' }

    Write-Host ''

    # 生成 CLAUDE.md（值已填入，无需再编辑）
    $claudeMd = @"
# $ProjectName

## 团队配置

本项目使用标准 AI 开发团队（13 agents）。
在 Claude Code 中说"使用标准团队开发 你的需求"即可启动 orchestrator。

## 项目上下文

- 技术栈: $TechStack
- 部署环境: $DeployEnv

## 团队运行机制

- 项目状态记录在 ``.claude/team-state/STATE.md``
- 失败重试记录在 ``.claude/team-state/RETRY_LOG.md``
- 用户确认过的关键决策记录在 ``.claude/team-state/DECISIONS.md``
- 项目内经验记录在 ``.claude/team-state/LEARNINGS.md``
- 用户级长期记忆位于 ``~/.claude/team-memory/patterns/``
"@
    Set-Content -Path 'CLAUDE.md' -Value $claudeMd -Encoding UTF8NoBOM
    Write-Host '✅ 已生成 CLAUDE.md' -ForegroundColor Green
}

# ── .claude\settings.json ────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path '.claude' | Out-Null
if (Test-Path '.claude\settings.json') {
    Write-Host '⏭  .claude\settings.json 已存在，跳过'
} else {
    Copy-Item (Join-Path $TplSrc 'settings.json') '.claude\settings.json'
    Write-Host '✅ 已生成 .claude\settings.json' -ForegroundColor Green
}

# ── .claude\team-state\ ──────────────────────────────────────────────
New-Item -ItemType Directory -Force -Path '.claude\team-state' | Out-Null
foreach ($f in 'STATE.md','RETRY_LOG.md','DECISIONS.md','LEARNINGS.md') {
    $src  = Join-Path $StateTplSrc $f
    $dest = ".claude\team-state\$f"
    if (-not (Test-Path $src)) {
        Write-Host "❌ 状态模板缺失：$src" -ForegroundColor Red
        exit 1
    }
    if (Test-Path $dest) {
        Write-Host "⏭  $dest 已存在，跳过"
    } else {
        Copy-Item $src $dest
        Write-Host "✅ 已生成 $dest" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '✅ 初始化完成！' -ForegroundColor Green
Write-Host ''
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host '现在打开 Claude Code，在这个目录里输入：'
Write-Host ''
Write-Host '  使用标准团队开发 你的需求' -ForegroundColor Yellow
Write-Host ''
if ($TechStack) {
    Write-Host "  技术栈：$TechStack"
    Write-Host "  部署环境：$DeployEnv"
}
Write-Host '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
Write-Host ''
