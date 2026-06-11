#Requires -Version 5.1
# 安装标准 AI 开发团队（Windows PowerShell / PowerShell 7+）
# 支持多平台：Claude Code / Hermes / OpenClaw / Codex CLI / Gemini CLI
# 版本相同则幂等跳过，版本不同则覆盖更新
$ErrorActionPreference = 'Stop'

# 全脚本包一层 try/finally：无论正常结束、已是最新(exit 0)还是出错(exit 1)，
# finally 都会执行暂停，避免窗口一闪而过看不到信息。exit 码原样保留。
# 被 update.ps1 以子进程调用时会设 TEAM_SKIP_PAUSE=1，此时不暂停（否则会卡住 update）。
try {

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir     = Split-Path -Parent $ScriptDir
$AgentsSrc    = Join-Path $RepoDir 'agents'
$TplSrc       = Join-Path $RepoDir 'templates\memory'
$WorkflowsSrc = Join-Path $RepoDir 'templates\workflows'
$CommandsSrc  = Join-Path $RepoDir '.claude\commands'
$VersionFile = Join-Path $RepoDir 'VERSION'
$RepoVersion = (Get-Content $VersionFile -Raw).Trim()

if (-not (Test-Path $AgentsSrc)) {
    Write-Host ''
    Write-Host "找不到 agents 目录：$AgentsSrc" -ForegroundColor Red
    Write-Host '   请在 claude-dev-ai-team 克隆目录中运行此脚本。'
    exit 1
}

# ─── 参数解析 ────────────────────────────────────────────────────────────────
# 位置参数：
#   $args[0] = Platform     (claude / hermes / openclaw / codex / gemini)
#   $args[1] = KbMode       (1=跳过 / 2=合并 / 3=覆盖，默认 1)

$Platform = if ($args.Count -gt 0) { $args[0] } else { '' }
$KbMode   = if ($args.Count -gt 1) { [string]$args[1] } else { '1' }

if ($KbMode -notin @('1','2','3')) {
    Write-Host "无效的 KbMode：$KbMode（仅允许 1/2/3）" -ForegroundColor Red
    exit 1
}

# ─── 平台选择 ─────────────────────────────────────────────────────────────────

if (-not $Platform) {
    Write-Host ''
    Write-Host '+---------------------------------------------------------+'
    Write-Host "|   AI 标准开发团队 v${RepoVersion}  ·  安装程序              |"
    Write-Host '+---------------------------------------------------------+'
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
        default {
            Write-Host "无效选择，请输入 1-5" -ForegroundColor Red
            exit 1
        }
    }
}

# ─── 版本文件（每平台独立）────────────────────────────────────────────────────

$VerFile = ''
if     ($Platform -eq 'claude')   { $VerFile = Join-Path $HOME '.claude\team-version'   }
elseif ($Platform -eq 'hermes')   { $VerFile = Join-Path $HOME '.hermes\team-version'   }
elseif ($Platform -eq 'openclaw') { $VerFile = Join-Path $HOME '.openclaw\team-version' }
elseif ($Platform -eq 'codex')    { $VerFile = Join-Path $HOME '.codex\team-version'    }
elseif ($Platform -eq 'gemini')   { $VerFile = Join-Path $HOME '.gemini\team-version'   }
else {
    Write-Host "不支持的平台：$Platform" -ForegroundColor Red
    exit 1
}

$InstalledVersion = if (Test-Path $VerFile) { (Get-Content $VerFile -Raw).Trim() } else { '' }

# KbMode 2/3 时强制重跑知识库处理，不因版本相同而短路
if ($RepoVersion -eq $InstalledVersion -and $KbMode -eq '1') {
    Write-Host ''
    Write-Host "[$Platform] 已是最新版本 v$RepoVersion，无需重新安装" -ForegroundColor Green
    Write-Host ''
    exit 0
}

Write-Host ''
if ($InstalledVersion) {
    Write-Host "[$Platform] 版本更新：v$InstalledVersion -> v$RepoVersion" -ForegroundColor Yellow
} else {
    Write-Host "正在安装标准 AI 开发团队 v$RepoVersion -> $Platform..." -ForegroundColor Cyan
}

# 输出 KbMode 提示
switch ($KbMode) {
    '1' { Write-Host "知识库模式：跳过（已存在则保留历史，默认）" -ForegroundColor Cyan }
    '2' { Write-Host "知识库模式：合并（新内容追加到历史末尾）"   -ForegroundColor Cyan }
    '3' { Write-Host "知识库模式：覆盖（用模板完全替换已有文件）" -ForegroundColor Cyan }
}
Write-Host ''

# ─── 工具函数 ─────────────────────────────────────────────────────────────────

function Get-AgentName([string]$FilePath) {
    # 仅在 frontmatter（前两个 --- 之间）内匹配 name:，避免误取正文里的 name: 行
    $fmCount = 0
    foreach ($line in (Get-Content $FilePath -Encoding UTF8)) {
        if ($line -eq '---') { $fmCount++; if ($fmCount -ge 2) { break }; continue }
        if ($fmCount -eq 1 -and $line -match '^name:\s*(.+)$') { return $Matches[1].Trim() }
    }
    return ''
}

# 支持单行和 YAML block scalar (description: |) 两种格式
function Get-AgentDescription([string]$FilePath) {
    $fmCount = 0
    $inBlock = $false
    foreach ($line in (Get-Content $FilePath -Encoding UTF8)) {
        if ($line -eq '---') {
            $fmCount++
            if ($fmCount -ge 2) { break }
            continue
        }
        if ($fmCount -eq 1 -and $line -match '^description:\s*\|') {
            $inBlock = $true
            continue
        }
        if ($fmCount -eq 1 -and $inBlock -and $line -match '^[ \t]+(.+)') {
            return $Matches[1].Trim()
        }
        if ($fmCount -eq 1 -and $inBlock -and $line -notmatch '^[ \t]') {
            $inBlock = $false
        }
        if ($fmCount -eq 1 -and (-not $inBlock) -and $line -match '^description:\s*(.+)$') {
            return $Matches[1].Trim()
        }
    }
    return ''
}

# 只跳过前两个 --- 分隔符，正文内的 --- 原样保留
function Get-AgentBody([string]$FilePath) {
    $fmCount = 0
    $body    = [System.Collections.Generic.List[string]]::new()
    foreach ($line in (Get-Content $FilePath -Encoding UTF8)) {
        if ($fmCount -lt 2 -and $line -eq '---') { $fmCount++; continue }
        if ($fmCount -ge 2) { $body.Add($line) }
    }
    return $body -join "`n"
}

function Write-VersionFile {
    New-Item -ItemType Directory -Force -Path (Split-Path $VerFile) | Out-Null
    # 用无 BOM UTF-8 写出，避免 PS 5.1 的 Out-File -Encoding utf8 写入 BOM
    # 导致 install.sh 读取版本号时 BOM 残留、版本比较永不相等（每次全量重装）
    [System.IO.File]::WriteAllText($VerFile, $RepoVersion, [System.Text.UTF8Encoding]::new($false))
}

# 提取模板文件中 "## 记录示例" 之后的全部内容（含该标题）
function Get-TemplateExampleSection([string]$TemplatePath) {
    $lines   = Get-Content $TemplatePath -Encoding UTF8
    $idx     = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^##\s+记录示例\s*$') { $idx = $i; break }
    }
    if ($idx -lt 0) { return '' }
    return ($lines[$idx..($lines.Count - 1)] -join "`n")
}

# 从一段 markdown 文本中提取所有 `^## 标题` 行（去掉 "##" 和首尾空白）
# 用于判断条目是否已存在
function Get-EntryTitles([string]$Text) {
    $titles = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ($Text -split "`r?`n")) {
        # 跳过模板自身的 "## 记录示例" 元标题
        if ($line -match '^##\s+(.+?)\s*$' -and $line -notmatch '^##\s+记录示例\s*$') {
            $titles.Add($Matches[1].Trim())
        }
    }
    return ,$titles
}

# 合并：将模板示例条目追加到已有文件末尾（跳过已存在的标题）
# 模板中代码块包裹的示例条目（```markdown ... ```）也会被解析其中的 `## 标题`
function Merge-PatternFile([string]$SrcTemplate, [string]$DestFile) {
    $section = Get-TemplateExampleSection $SrcTemplate
    if (-not $section) {
        Write-Host "  合并跳过（模板无 ## 记录示例 章节）：$(Split-Path $DestFile -Leaf)" -ForegroundColor Yellow
        return
    }

    $destContent = Get-Content $DestFile -Raw -Encoding UTF8
    if ($null -eq $destContent) { $destContent = '' }

    # 提取目标文件已存在的所有 `## 标题`（包括代码块内的示例，避免重复合并）
    $existingTitles = Get-EntryTitles $destContent
    # 提取模板示例段中所有 `## 标题`（不含 "## 记录示例" 元标题）
    $templateTitles = Get-EntryTitles $section

    # 判断是否所有模板条目都已存在
    $newTitles = @($templateTitles | Where-Object { $existingTitles -notcontains $_ })

    if ($newTitles.Count -eq 0) {
        Write-Host "  合并跳过（条目已存在）：$(Split-Path $DestFile -Leaf)" -ForegroundColor Yellow
        return
    }

    # 追加模板的 "## 记录示例" 整段到目标文件末尾
    # （目标文件可能已经包含或不含 "## 记录示例" 标题，统一以模板段落整体追加，
    #   PowerShell 端简化实现：以模板示例整段为追加单元，靠标题去重避免重复运行造成累积）
    $separator = if ($destContent.TrimEnd().Length -gt 0) { "`n`n" } else { '' }
    $newContent = $destContent.TrimEnd() + $separator + $section.TrimEnd() + "`n"

    [System.IO.File]::WriteAllText($DestFile, $newContent, [System.Text.UTF8Encoding]::new($false))
    Write-Host "  合并：$(Split-Path $DestFile -Leaf)（新增 $($newTitles.Count) 条标题）" -ForegroundColor Green
}

# ─── Claude Code 安装 ────────────────────────────────────────────────────────

function Install-Claude {
    $AgentsDest    = Join-Path $HOME '.claude\agents'
    $MemDest       = Join-Path $HOME '.claude\team-memory\patterns'
    # workflow 模板分发到 ~/.claude/team-workflows/，与 team-memory 风格一致
    $WorkflowsDest = Join-Path $HOME '.claude\team-workflows'
    $CommandsDest  = Join-Path $HOME '.claude\commands'

    # 1. Agent 文件
    New-Item -ItemType Directory -Force -Path $AgentsDest | Out-Null
    Get-ChildItem (Join-Path $AgentsSrc '*.md') | Copy-Item -Destination $AgentsDest -Force
    $cnt = (Get-ChildItem (Join-Path $AgentsDest '*.md')).Count
    Write-Host "已安装 $cnt 个 agent -> $AgentsDest" -ForegroundColor Green

    # 2. 用户级知识库（行为由 KbMode 决定）
    New-Item -ItemType Directory -Force -Path $MemDest | Out-Null
    foreach ($p in 'backend','frontend','contract','qa','security','deployment') {
        $src  = Join-Path $TplSrc  "${p}-patterns.md"
        $dest = Join-Path $MemDest "${p}-patterns.md"
        if (-not (Test-Path $src)) {
            Write-Host "模板文件缺失：$src" -ForegroundColor Red; exit 1
        }
        switch ($KbMode) {
            '1' {
                if (Test-Path $dest) {
                    Write-Host "  跳过（已存在）：${p}-patterns.md"
                } else {
                    Copy-Item $src $dest
                    Write-Host "  初始化：${p}-patterns.md" -ForegroundColor Green
                }
            }
            '2' {
                if (Test-Path $dest) {
                    Merge-PatternFile $src $dest
                } else {
                    Copy-Item $src $dest
                    Write-Host "  初始化：${p}-patterns.md" -ForegroundColor Green
                }
            }
            '3' {
                Copy-Item $src $dest -Force
                Write-Host "  覆盖：${p}-patterns.md" -ForegroundColor Green
            }
        }
    }

    # 3. Workflow 模板（复制所有 *.workflow.js 到用户级目录，幂等覆盖）
    # 分发路径：~/.claude/team-workflows/，与 team-memory 命名风格一致
    if (Test-Path $WorkflowsSrc) {
        New-Item -ItemType Directory -Force -Path $WorkflowsDest | Out-Null
        $wfFiles = @(Get-ChildItem (Join-Path $WorkflowsSrc '*.workflow.js') -ErrorAction SilentlyContinue)
        if ($wfFiles.Count -gt 0) {
            $wfFiles | Copy-Item -Destination $WorkflowsDest -Force
            Write-Host "已分发 $($wfFiles.Count) 个 workflow 模板 -> $WorkflowsDest" -ForegroundColor Green
        } else {
            Write-Host '  跳过 workflow 分发（templates\workflows\ 下暂无 *.workflow.js 文件）'
        }
    } else {
        Write-Host '  跳过 workflow 分发（templates\workflows\ 目录不存在）'
    }

    # 4. 全局命令
    if (Test-Path $CommandsSrc) {
        New-Item -ItemType Directory -Force -Path $CommandsDest | Out-Null
        Copy-Item (Join-Path $CommandsSrc 'team-init.md')    $CommandsDest -Force
        Copy-Item (Join-Path $CommandsSrc 'team-kb-save.md') $CommandsDest -Force
        Copy-Item (Join-Path $CommandsSrc 'team-version.md') $CommandsDest -Force
        # 清理 v1.2.0 已废弃的旧命令（老用户升级时自动移除孤立文件）
        foreach ($stale in 'team-install.md','team-update.md') {
            $sp = Join-Path $CommandsDest $stale
            if (Test-Path $sp) { Remove-Item $sp -Force; Write-Host "  已移除废弃命令：$stale" -ForegroundColor Yellow }
        }
        Write-Host "已注册全局命令 -> $CommandsDest" -ForegroundColor Green
    } else {
        Write-Host '  跳过命令注册（.claude\commands\ 目录不存在）'
    }

    Write-VersionFile
    Write-Host ''
    Write-Host "安装完成！版本 v$RepoVersion (Claude Code)" -ForegroundColor Green
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
    foreach ($f in (Get-ChildItem (Join-Path $AgentsSrc '*.md'))) {
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
        $fm += 'description: "' + $escapedDesc + '"' + "`n"
        $fm += "version: $RepoVersion`n"
        $fm += "metadata:`n"
        $fm += "  hermes:`n"
        $fm += "    tags: [development, ai-team, standard-dev-team]`n"
        $fm += "    category: development`n"
        $fm += "---`n`n"

        # 写入文件：frontmatter + 正文（正文通过变量拼接，不经过 PS 插值）
        [System.IO.File]::WriteAllText($skillFile, ($fm + $body), [System.Text.Encoding]::UTF8)

        Write-Host "  $name" -ForegroundColor Green
        $count++
    }

    Write-VersionFile
    Write-Host ''
    Write-Host "已安装 $count 个 skill -> $teamDir" -ForegroundColor Green
    Write-Host ''
    Write-Host '================================================================'
    Write-Host "使用方法（${PlatformName} CLI）："
    Write-Host ''
    Write-Host "  1. 启动 ${PlatformName}："
    Write-Host "       $PlatformName" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  2. 激活总指挥，开始开发任务：'
    Write-Host '       /orchestrator' -ForegroundColor Yellow
    Write-Host '       -> 然后描述你的需求，例如：'
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
    Write-Host '================================================================'
    Write-Host ''
}

function Install-Hermes   { Install-SkillsPlatform 'hermes'   (Join-Path $HOME '.hermes\skills')   }
function Install-OpenClaw { Install-SkillsPlatform 'openclaw' (Join-Path $HOME '.openclaw\skills') }

# ─── 生成合并团队文档（Codex / Gemini 共用）──────────────────────────────────

function New-TeamDoc([string]$OutFile, [string]$PlatformName) {
    New-Item -ItemType Directory -Force -Path (Split-Path $OutFile) | Out-Null

    # 该文件是用户的全局指令文件，可能已有自定义内容——覆盖前先备份
    if (Test-Path $OutFile) {
        $bak = "$OutFile.bak." + (Get-Date -Format 'yyyyMMdd_HHmmss')
        Copy-Item $OutFile $bak -Force
        Write-Host "  已备份原有文件 -> $bak" -ForegroundColor Yellow
    }

    $tick = [char]96   # backtick 字符，避免在字符串中直接使用引发 PS 解析歧义

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('# 标准 AI 开发团队 (Standard AI Development Team)')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('> 版本：' + $RepoVersion + '  |  生成工具：claude-dev-ai-team')
    [void]$sb.AppendLine('> 请勿手动编辑，重新运行 install.ps1 可升级。')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 使用方式')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('当用户要求开发软件时，以 **orchestrator（总指挥）** 角色协调整个团队，')
    [void]$sb.AppendLine('按以下协作链路推进：需求分析 -> 架构设计 -> 实现 -> QA -> 安全 -> 上线。')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 团队成员')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('| 角色 | 职责摘要 |')
    [void]$sb.AppendLine('|------|----------|')

    foreach ($f in (Get-ChildItem (Join-Path $AgentsSrc '*.md'))) {
        $name = Get-AgentName $f.FullName
        $desc = Get-AgentDescription $f.FullName
        # 使用字符变量拼接，避免反引号在双引号字符串中引发解析问题
        $row  = '| ' + $tick + $name + $tick + ' | ' + $desc + ' |'
        [void]$sb.AppendLine($row)
    }

    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## 角色详细定义')
    [void]$sb.AppendLine('')

    foreach ($f in (Get-ChildItem (Join-Path $AgentsSrc '*.md'))) {
        $name = Get-AgentName $f.FullName
        $desc = Get-AgentDescription $f.FullName
        $body = Get-AgentBody $f.FullName
        [void]$sb.AppendLine('### ' + $name)
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('> ' + $desc)
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine($body)
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('---')
        [void]$sb.AppendLine('')
    }

    # 写入 UTF-8（无 BOM）文件
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($OutFile, $sb.ToString(), $utf8NoBom)
}

function Install-Codex {
    $outFile = Join-Path $HOME '.codex\AGENTS.md'
    New-TeamDoc $outFile 'codex'
    Write-VersionFile
    Write-Host "已生成团队定义 -> $outFile" -ForegroundColor Green
    Write-Host ''
    Write-Host '================================================================'
    Write-Host '使用方法（Codex CLI）：'
    Write-Host ''
    Write-Host '  Codex CLI 会自动加载 ~/.codex/AGENTS.md 作为全局指令。'
    Write-Host ''
    Write-Host '  命令行直接调用：'
    Write-Host "    codex '以 orchestrator 角色，使用标准团队开发 <你的需求>'" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  交互模式中说：'
    Write-Host '    请以 orchestrator 角色，带领团队开发 <你的需求>' -ForegroundColor Yellow
    Write-Host '================================================================'
    Write-Host ''
}

function Install-Gemini {
    $outFile = Join-Path $HOME '.gemini\GEMINI.md'
    New-TeamDoc $outFile 'gemini'
    Write-VersionFile
    Write-Host "已生成团队定义 -> $outFile" -ForegroundColor Green
    Write-Host ''
    Write-Host '================================================================'
    Write-Host '使用方法（Gemini CLI）：'
    Write-Host ''
    Write-Host '  Gemini CLI 会自动加载 ~/.gemini/GEMINI.md 作为全局指令。'
    Write-Host ''
    Write-Host '  命令行直接调用：'
    Write-Host "    gemini '以 orchestrator 角色，使用标准团队开发 <你的需求>'" -ForegroundColor Yellow
    Write-Host ''
    Write-Host '  交互模式中说：'
    Write-Host '    请以 orchestrator 角色，带领团队开发 <你的需求>' -ForegroundColor Yellow
    Write-Host '================================================================'
    Write-Host ''
}

# ─── 主流程 ──────────────────────────────────────────────────────────────────

Write-Host "目标平台：$Platform" -ForegroundColor Cyan
Write-Host ''

switch ($Platform) {
    'claude'   { Install-Claude   }
    'hermes'   { Install-Hermes   }
    'openclaw' { Install-OpenClaw }
    'codex'    { Install-Codex    }
    'gemini'   { Install-Gemini   }
    default    {
        Write-Host "不支持的平台：$Platform" -ForegroundColor Red
        exit 1
    }
}

}
finally {
    if ($env:TEAM_SKIP_PAUSE -ne '1' -and [Environment]::UserInteractive) {
        Write-Host ''
        Read-Host '按回车键退出（窗口将关闭）' | Out-Null
    }
}
