#Requires -Version 5.1
# 升级标准 AI 开发团队（Windows PowerShell / PowerShell 7+）
#
# 与 install.ps1 的区别：本脚本面向「已安装过、想升级」的用户，做两件事：
#   1. 刷新全局：复用 install.ps1 的 Claude Code 安装分支，更新 ~/.claude 下
#      agents / 命令 / 知识库 / workflow 模板
#   2. 同步项目：把「当前项目目录」CLAUDE.md 的「## 团队配置」段落升级到本包版本，
#      保留用户填写的技术栈 / 部署环境字段
#
# 全程不联网。用法：
#   先下载并解压对应版本的发布包，进入你的项目目录后运行：
#     pwsh <解压目录>\scripts\update.ps1
#   或显式指定项目目录：
#     pwsh <解压目录>\scripts\update.ps1 D:\path\to\your-project
$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir     = Split-Path -Parent $ScriptDir
$VersionFile = Join-Path $RepoDir 'VERSION'
$RepoVersion = (Get-Content $VersionFile -Raw).Trim()
$TplFile     = Join-Path $RepoDir 'templates\memory\project-CLAUDE.md'

# 参数：$args[0] = 项目目录（可选，默认当前工作目录）
if ($args.Count -gt 0 -and $args[0]) {
    if (-not (Test-Path $args[0])) {
        Write-Host "指定的项目目录不存在：$($args[0])" -ForegroundColor Red
        exit 1
    }
    $ProjectDir = (Resolve-Path $args[0]).Path
} else {
    $ProjectDir = (Get-Location).Path
}

Write-Host ''
Write-Host '+---------------------------------------------------------+'
Write-Host "|   AI 标准开发团队 v${RepoVersion}  ·  升级程序              |"
Write-Host '+---------------------------------------------------------+'
Write-Host ''
Write-Host "项目目录：$ProjectDir" -ForegroundColor Cyan
Write-Host ''

# ─── Step 1：刷新全局 agents / 命令 / 知识库 / workflow ────────────────────────
# 用子进程调用 install.ps1，避免其内部 exit 直接终止本脚本。
# 传 claude 1 = Claude Code 平台 + 知识库「跳过已存在」模式（不覆盖用户历史）。
$InstallScript = Join-Path $ScriptDir 'install.ps1'
if (-not (Test-Path $InstallScript)) {
    Write-Host "找不到 install.ps1：$InstallScript" -ForegroundColor Red
    exit 1
}
Write-Host '[1/2] 刷新全局（~/.claude/agents、命令、知识库、workflow）...' -ForegroundColor Cyan
$psExe = (Get-Process -Id $PID).Path
& $psExe -NoProfile -ExecutionPolicy RemoteSigned -File $InstallScript claude 1
if ($LASTEXITCODE -ne 0) {
    Write-Host "全局刷新失败（install.ps1 退出码 $LASTEXITCODE）" -ForegroundColor Red
    exit 1
}

# ─── Step 2：同步项目 CLAUDE.md 的「## 团队配置」段落 ─────────────────────────
# 返回 @{Start;End}：[Start,End) 为 `## 团队配置` 到下一个 `## ` 标题之前的行区间；
# 找不到返回 $null。`### ` 子标题不算二级标题，会被纳入区间。
function Get-TeamConfigRange([string[]]$Lines) {
    $start = -1
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match '^##\s+团队配置\s*$') { $start = $i; break }
    }
    if ($start -lt 0) { return $null }
    $end = $Lines.Count
    for ($j = $start + 1; $j -lt $Lines.Count; $j++) {
        if ($Lines[$j] -match '^##\s+') { $end = $j; break }
    }
    return @{ Start = $start; End = $end }
}

Write-Host ''
Write-Host '[2/2] 同步项目 CLAUDE.md 团队配置段落...' -ForegroundColor Cyan

$claudeMd   = Join-Path $ProjectDir 'CLAUDE.md'
$projectMsg = ''

if (-not (Test-Path $claudeMd)) {
    Write-Host "  当前项目目录未找到 CLAUDE.md（尚未初始化）" -ForegroundColor Yellow
    Write-Host "  请在 Claude Code 内于该项目运行 /team-init 后再升级。"
    $projectMsg = '当前项目未初始化（已跳过）'
} else {
    $tplLines = Get-Content $TplFile -Encoding UTF8
    $tplRange = Get-TeamConfigRange $tplLines
    if (-not $tplRange) {
        Write-Host "  模板缺少 ## 团队配置 段落：$TplFile" -ForegroundColor Red
        exit 1
    }
    $tplBlock = $tplLines[$tplRange.Start..($tplRange.End - 1)]

    $dstLines = Get-Content $claudeMd -Encoding UTF8
    $dstRange = Get-TeamConfigRange $dstLines
    if (-not $dstRange) {
        Write-Host "  当前 CLAUDE.md 找不到 '## 团队配置' 标题，结构异常，已跳过同步。" -ForegroundColor Yellow
        Write-Host "  请手动核对该文件后再升级团队配置段落。"
        $projectMsg = '结构异常（已跳过）'
    } else {
        $dstBlock = $dstLines[$dstRange.Start..($dstRange.End - 1)]
        if ((($dstBlock -join "`n").TrimEnd()) -eq (($tplBlock -join "`n").TrimEnd())) {
            Write-Host "  CLAUDE.md 团队配置段落已是最新，无需更新" -ForegroundColor Green
            $projectMsg = '已是最新'
        } else {
            $before = if ($dstRange.Start -gt 0) { $dstLines[0..($dstRange.Start - 1)] } else { @() }
            $after  = if ($dstRange.End -lt $dstLines.Count) { $dstLines[$dstRange.End..($dstLines.Count - 1)] } else { @() }
            $new    = @($before) + @($tplBlock) + @($after)
            $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
            [System.IO.File]::WriteAllText($claudeMd, (($new -join "`n") + "`n"), $utf8NoBom)
            Write-Host "  已同步 CLAUDE.md 团队配置段落（仅替换此段；项目上下文等其它段落含技术栈/部署环境原样保留）" -ForegroundColor Green
            $projectMsg = '已更新团队配置段落'
        }
    }
}

# ─── 报告 ────────────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '========================================='
Write-Host "✅ 团队升级完成" -ForegroundColor Green
Write-Host ''
Write-Host "   目标版本      → v$RepoVersion"
Write-Host "   全局 agents   → 已刷新（~/.claude/agents/）"
Write-Host "   项目 CLAUDE.md → $projectMsg"
Write-Host ''
Write-Host '⚠️ 重启 Claude Code 让新 agent 与命令生效。' -ForegroundColor Yellow
Write-Host '========================================='
Write-Host ''
