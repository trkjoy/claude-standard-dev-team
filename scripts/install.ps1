#Requires -Version 5.1
# 安装标准 AI 开发团队（Windows PowerShell / PowerShell 7+）
# 支持多平台：Claude Code / Hermes / OpenClaw / Codex CLI / Gemini CLI
# 版本相同则幂等跳过，版本不同则覆盖更新
$ErrorActionPreference = 'Stop'

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir     = Split-Path -Parent $ScriptDir
$AgentsSrc   = Join-Path $RepoDir 'agents'
$TplSrc      = Join-Path $RepoDir 'templates\memory'
$CommandsSrc = Join-Path $RepoDir '.claude\commands'
$VersionFile = Join-Path $RepoDir 'VERSION'
$RepoVersion = (Get-Content $VersionFile -Raw).Trim()

if (-not (Test-Path $AgentsSrc)) {
    Write-Host ''
    Write-Host "❌ 找不到 agents 目录：$AgentsSrc" -ForegroundColor Red
    Write-Host '   请在 claude-standard-dev-team 克隆目录中运行此脚本。'
    exit 1
}

# ─── 平台选择 ─────────────────────────────────────────────────────────────────

$Platform = if ($args.Count -gt 0) { $args[0] } else { '' }

if (-not $Platform) {
    Write-Host ''
    Write-Host "┌──────────────────────────────────────────────────────────┐"
    Write-Host "│   AI 标准开发团队 v${RepoVersion}  ·  安装程序              │"
    Write-Host "└──────────────────────────────────────────────────────────┘"
    Write-Host ''
    Write-Host '请选择目标平台：'
    Write-Host ''
    Write-Host '  1) Claude Code  — ~/.claude/agents/        (推荐，多 Agent 并行)'
    Write-Host '  2) Hermes       — ~/.hermes/skills/         (Nous Research)'
    Write-Host '  3) OpenClaw     — ~/.openclaw/skills/       (agentskills.io)'
    Write-Host '  4) Codex CLI    — ~/.codex/AGENTS.md        (OpenAI)'
    Write-Host '  5) Gemini CLI   — ~/.gemini/GEMINI.md       (Google)'
    Write-Host ''
    $choice = Read-Host '输入序号 [1-5]，按 Enter 确认（默认 1）'
    if (-not $choice) { $choice = '1' }
    switch ($choice) {
        '1' { $Platform = 'claude'   }
        '2' { $Platform = 'hermes'   }
        '3' { $Platform = 'openclaw' }
        '4' { $Platform = 'codex'    }
        '5' { $Platform = 'gemini'   }
        default { Write-Host "❌ 无效选择，请输入 1-5" -ForegroundColor Red; exit 1 }
    }
}

# ─── 版本文件（每平台独立）────────────────────────────────────────────────────

$VerFile = switch ($Platform) {
    'claude'   { Join-Path $HOME '.claude\team-version'   }
    'hermes'   { Join-Path $HOME '.hermes\team-version'   }
    'openclaw' { Join-Path $HOME '.openclaw\team-version' }
    'codex'    { Join-Path $HOME '.codex\team-version'    }
    'gemini'   { Join-Path $HOME '.gemini\team-version'   }
    default    { Write-Host "❌ 不支持的平台：$Platform" -ForegroundColor Red; exit 1 }
}

$InstalledVersion = if (Test-Path $VerFile) { (Get-Content $VerFile -Raw).Trim() } else { '' }

if ($RepoVersion -eq $InstalledVersion) {
    Write-Host ''
    Write-Host "✅ [$Platform] 已是最新版本 v$RepoVersion，无需重新安装" -ForegroundColor Green
    Write-Host ''
    exit 0
}

Write-Host ''
if ($InstalledVersion) {
    Write-Host "🔄 [$Platform] 版本更新：v$InstalledVersion → v$RepoVersion" -ForegroundColor Yellow
} else {
    Write-Host "📦 正在安装标准 AI 开发团队 v$RepoVersion → $Platform..." -ForegroundColor Cyan
}
Write-Host ''

# ─── 工具函数 ─────────────────────────────────────────────────────────────────

function Get-AgentName([string]$FilePath) {
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    if ($content -match '(?m)^name:\s*(.+)$') { return $Matches[1].Trim() }
    return ''
}

function Get-AgentDescription([string]$FilePath) {
    $content = Get-Content $FilePath -Raw -Encoding UTF8
    # Block scalar（description: |）：取第一个有内容的缩进行
    if ($content -match '(?ms)^description:\s*\|\r?\n((?:[ \t]+[^\r\n]*\r?\n?)+)') {
        $lines = $Matches[1] -split '\r?\n' |
                 ForEach-Object { $_.Trim() } |
                 Where-Object   { $_ -ne '' }
        if ($lines.Count -gt 0) { return $lines[0] }
    }
    # 单行
    if ($content -match '(?m)^description:\s*(.+)$') { return $Matches[1].Trim() }
    return ''
}

function Get-AgentBody([string]$FilePath) {
    $lines   = Get-Content $FilePath -Encoding UTF8
    $fmCount = 0
    $body    = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        # 只跳过前两个 --- 分隔符，正文内的 --- 原样保留
        if ($fmCount -lt 2 -and $line -eq '---') { $fmCount++; continue }
        if ($fmCount -ge 2) { $body.Add($line) }
    }
    return $body -join "`n"
}

function Write-VersionFile {
    New-Item -ItemType Directory -Force -Path (Split-Path $VerFile) | Out-Null
    $RepoVersion | Out-File -FilePath $VerFile -Encoding utf8 -NoNewline
}

# ─── Claude Code 安装 ────────────────────────────────────────────────────────

function Install-Claude {
    $AgentsDest   = Join-Path $HOME '.claude\agents'
    $MemDest      = Join-Path $HOME '.claude\team-memory\patterns'
    $CommandsDest = Join-Path $HOME '.claude\commands'

    # 1. Agent 文件
    New-Item -ItemType Directory -Force -Path $AgentsDest | Out-Null
    Get-ChildItem "$AgentsSrc\*.md" | Copy-Item -Destination $AgentsDest -Force
    $cnt = (Get-ChildItem "$AgentsDest\*.md").Count
    Write-Host "✅ 已安装 $cnt 个 agent -> $AgentsDest" -ForegroundColor Green

    # 2. 用户级知识库（已存在则跳过，保留历史积累）
    New-Item -ItemType Directory -Force -Path $MemDest | Out-Null
    foreach ($p in 'backend','frontend','contract','qa','security','deployment') {
        $src  = Join-Path $TplSrc  "${p}-patterns.md"
        $dest = Join-Path $MemDest "${p}-patterns.md"
        if (-not (Test-Path $src)) {
            Write-Host "❌ 模板文件缺失：$src" -ForegroundColor Red; exit 1
        }
        if (Test-Path $dest) {
            Write-Host "  ⏭  跳过（已存在）：${p}-patterns.md"
        } else {
            Copy-Item $src $dest
            Write-Host "  ✅ 初始化：${p}-patterns.md" -ForegroundColor Green
        }
    }

    # 3. 全局命令
    if (Test-Path $CommandsSrc) {
        New-Item -ItemType Directory -Force -Path $CommandsDest | Out-Null
        Copy-Item "$CommandsSrc\team-install.md" "$CommandsDest\" -Force
        Copy-Item "$CommandsSrc\team-init.md"    "$CommandsDest\" -Force
        Write-Host "✅ 已注册全局命令 -> $CommandsDest" -ForegroundColor Green
    } else {
        Write-Host '  ⚠  跳过命令注册（.claude\commands\ 目录不存在）'
    }

    Write-VersionFile
    Write-Host ''
    Write-Host "✅ 安装完成！版本 v$RepoVersion (Claude Code)" -ForegroundColor Green
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
}

# ─── Hermes / OpenClaw Skills 安装（共用格式逻辑）────────────────────────────

function Install-SkillsPlatform([string]$PlatformName, [string]$SkillsBase) {
    $teamDir = Join-Path $SkillsBase 'standard-dev-team'
    New-Item -ItemType Directory -Force -Path $teamDir | Out-Null
    Write-Host "  目标目录：$teamDir"
    Write-Host ''

    $count = 0
    foreach ($f in (Get-ChildItem "$AgentsSrc\*.md")) {
        $name        = Get-AgentName $f.FullName
        $desc        = Get-AgentDescription $f.FullName
        $body        = Get-AgentBody $f.FullName
        $escapedDesc = $desc -replace '"', '\"'

        $skillDir  = Join-Path $teamDir $name
        New-Item -ItemType Directory -Force -Path $skillDir | Out-Null
        $skillFile = Join-Path $skillDir 'SKILL.md'

        # 构建 frontmatter（变量均为简单字符串，可安全插值）
        $fm  = "---`n"
        $fm += "name: $name`n"
        $fm += "description: `"$escapedDesc`"`n"
        $fm += "version: $RepoVersion`n"
        $fm += "metadata:`n"
        $fm += "  hermes:`n"
        $fm += "    tags: [development, ai-team, standard-dev-team]`n"
        $fm += "    category: development`n"
        $fm += "---`n`n"

        # 写入文件：frontmatter + 正文（正文直接拼接，不经过 PS 插值）
        [System.IO.File]::WriteAllText($skillFile, $fm + $body, [System.Text.Encoding]::UTF8)

        Write-Host "  ✅ $name" -ForegroundColor Green
        $count++
    }

    Write-VersionFile
    Write-Host ''
    Write-Host "✅ 已安装 $count 个 skill -> $teamDir" -ForegroundColor Green
    Write-Host ''
    Write-Host "================================================================"
    Write-Host "使用方法（${PlatformName} CLI）："
    Write-Host ''
    Write-Host "  1. 启动 ${PlatformName}："
    Write-Host "       $PlatformName" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  2. 激活总指挥，开始开发任务：'
    Write-Host '       /orchestrator' -ForegroundColor Yellow
    Write-Host '       → 然后描述你的需求，例如：'
    Write-Host '         使用标准团队开发 一个待办事项 Web App'
    Write-Host ''
    Write-Host '  3. 也可直接调用单个角色：'
    Write-Host '       /product-manager      产品需求分析' -ForegroundColor Yellow
    Write-Host '       /software-architect   技术架构设计' -ForegroundColor Yellow
    Write-Host '       /code-reviewer        代码评审' -ForegroundColor Yellow
    Write-Host '       /security-engineer    安全审查' -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  4. 查看所有已安装 skill：'
    Write-Host '       /skills' -ForegroundColor Yellow
    Write-Host "================================================================"
    Write-Host ''
}

function Install-Hermes   { Install-SkillsPlatform 'hermes'   (Join-Path $HOME '.hermes\skills')   }
function Install-OpenClaw { Install-SkillsPlatform 'openclaw' (Join-Path $HOME '.openclaw\skills') }

# ─── 生成合并团队文档（Codex / Gemini 共用）──────────────────────────────────

function New-TeamDoc([string]$OutFile, [string]$PlatformName) {
    New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# 标准 AI 开发团队 (Standard AI Development Team)')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine("> 版本：$RepoVersion  |  生成工具：claude-standard-dev-team")
    [void]$sb.AppendLine('> 请勿手动编辑，重新运行 install.ps1 可升级。')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 使用方式')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('当用户要求开发软件时，以 **orchestrator（总指挥）** 角色协调整个团队，')
    [void]$sb.AppendLine('按以下协作链路推进：需求分析 → 架构设计 → 实现 → QA → 安全 → 上线。')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 团队成员')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('| 角色 | 职责摘要 |')
    [void]$sb.AppendLine('|------|----------|')

    foreach ($f in (Get-ChildItem "$AgentsSrc\*.md")) {
        $name = Get-AgentName $f.FullName
        $desc = Get-AgentDescription $f.FullName
        [void]$sb.AppendLine("| ``$name`` | $desc |")
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## 角色详细定义')
    [void]$sb.AppendLine()

    foreach ($f in (Get-ChildItem "$AgentsSrc\*.md")) {
        $name = Get-AgentName $f.FullName
        $desc = Get-AgentDescription $f.FullName
        $body = Get-AgentBody $f.FullName
        [void]$sb.AppendLine("### $name")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> $desc")
        [void]$sb.AppendLine()
        [void]$sb.AppendLine($body)
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine()
    }

    # 写入文件（UTF-8，无 BOM）
    [System.IO.File]::WriteAllText($OutFile, $sb.ToString(), [System.Text.Encoding]::UTF8)
}

function Install-Codex {
    $outFile = Join-Path $HOME '.codex\AGENTS.md'
    New-TeamDoc $outFile 'codex'
    Write-VersionFile
    Write-Host "✅ 已生成团队定义 -> $outFile" -ForegroundColor Green
    Write-Host ''
    Write-Host "================================================================"
    Write-Host "使用方法（Codex CLI）："
    Write-Host ''
    Write-Host "  Codex CLI 会自动加载 ~/.codex/AGENTS.md 作为全局指令。"
    Write-Host ''
    Write-Host "  命令行直接调用："
    Write-Host "    codex '以 orchestrator 角色，使用标准团队开发 <你的需求>'" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  交互模式中说："
    Write-Host "    请以 orchestrator 角色，带领团队开发 <你的需求>" -ForegroundColor Yellow
    Write-Host "================================================================"
    Write-Host ''
}

function Install-Gemini {
    $outFile = Join-Path $HOME '.gemini\GEMINI.md'
    New-TeamDoc $outFile 'gemini'
    Write-VersionFile
    Write-Host "✅ 已生成团队定义 -> $outFile" -ForegroundColor Green
    Write-Host ''
    Write-Host "================================================================"
    Write-Host "使用方法（Gemini CLI）："
    Write-Host ''
    Write-Host "  Gemini CLI 会自动加载 ~/.gemini/GEMINI.md 作为全局指令。"
    Write-Host ''
    Write-Host "  命令行直接调用："
    Write-Host "    gemini '以 orchestrator 角色，使用标准团队开发 <你的需求>'" -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  交互模式中说："
    Write-Host "    请以 orchestrator 角色，带领团队开发 <你的需求>" -ForegroundColor Yellow
    Write-Host "================================================================"
    Write-Host ''
}

# ─── 主流程 ──────────────────────────────────────────────────────────────────

Write-Host "🎯 目标平台：$Platform" -ForegroundColor Cyan
Write-Host ''

switch ($Platform) {
    'claude'   { Install-Claude   }
    'hermes'   { Install-Hermes   }
    'openclaw' { Install-OpenClaw }
    'codex'    { Install-Codex    }
    'gemini'   { Install-Gemini   }
    default    { Write-Host "❌ 不支持的平台：$Platform" -ForegroundColor Red; exit 1 }
}
