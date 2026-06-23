# collect-ci-failure.ps1 — CI 失败日志收集 hook（P1-3 轻量层，Windows/PowerShell 版）
#
# 本脚本是项目级 hook，由 team-init 放入目标项目的 .claude\hooks\ 目录。
# 不随 install.sh 的 *.workflow.js 通道分发；需用户手动注册到 settings.json。
# 注册示例见同目录 settings-hook-snippet.json。
#
# 待验证假设：CI→回灌 Claude 的端到端触发链属待验证假设；
# 本脚本只负责"提取失败摘要并写文件"这一步。
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File .claude\hooks\collect-ci-failure.ps1 `
#     -LogFile "C:\path\to\ci.log" -Timestamp "2026-06-23T10:00:00Z"
#
# 或管道模式：
#   Get-Content ci.log | powershell -ExecutionPolicy Bypass `
#     -File .claude\hooks\collect-ci-failure.ps1 -Timestamp "2026-06-23T10:00:00Z"
#
# 退出码：
#   0  成功写入
#   1  无有效日志
#   2  参数错误

param(
    [string]$LogFile   = "",
    [string]$Timestamp = "unknown",
    [string]$OutFile   = ".claude\team-state\CI_FAILURE.md",
    [int]   $MaxLines  = 50
)

$ErrorActionPreference = "Stop"

# ── 读取日志内容 ──────────────────────────────────────────────

$logContent = ""

if ($LogFile -ne "") {
    if (-not (Test-Path $LogFile)) {
        Write-Error "[collect-ci-failure] 日志文件不存在：$LogFile"
        exit 1
    }
    $logContent = Get-Content $LogFile -Raw -Encoding UTF8
} elseif (-not [Console]::IsInputRedirected) {
    Write-Error "[collect-ci-failure] 错误：需通过 -LogFile 或 stdin 管道提供日志内容"
    exit 1
} else {
    # 从 stdin 读取
    $logContent = $input | Out-String
}

if ([string]::IsNullOrWhiteSpace($logContent)) {
    Write-Warning "[collect-ci-failure] 日志内容为空，跳过写入"
    exit 1
}

# ── 提取失败摘要 ──────────────────────────────────────────────

# 失败关键词过滤（覆盖 Jest/pytest/go test/MSTest 等常见格式）
$failurePattern = 'FAIL|ERROR|error:|failed|FAILED|AssertionError|TypeError|Exception|at line|undefined|null pointer|panic:|fatal:'

$failureLines = $logContent -split "`n" |
    Where-Object { $_ -match $failurePattern } |
    Select-Object -First $MaxLines

$failureSummary = if ($failureLines) { $failureLines -join "`n" } else { "（未识别到失败关键词，请手工查阅原始日志）" }

# 提取失败测试用例名
$testNamePattern = '(FAIL|FAILED)\s+[a-zA-Z0-9_./ :-]+'
$testNames = [regex]::Matches($logContent, $testNamePattern) |
    Select-Object -First 20 |
    ForEach-Object { $_.Value }

$testNameStr = if ($testNames) { $testNames -join "`n" } else { "（未识别到测试用例名）" }

# ── 确保输出目录存在 ──────────────────────────────────────────

$outDir = Split-Path $OutFile -Parent
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Force -Path $outDir | Out-Null
}

# ── 追加写入 CI_FAILURE.md ────────────────────────────────────

$record = @"

---
## CI 失败记录 — $Timestamp

**时间戳（调用方注入）**: $Timestamp

### 失败测试用例（最多 20 条）

``````
$testNameStr
``````

### 失败日志摘要（最多 $MaxLines 行）

``````
$failureSummary
``````

> 自动提取，可能有遗漏。下次会话开场时 orchestrator 可读取本文件作为 Hotfix 输入。
> 待验证假设：CI→Claude 端到端触发链需项目方自行配置。
"@

Add-Content -Path $OutFile -Value $record -Encoding UTF8

Write-Host "[collect-ci-failure] 已追加写入：$OutFile（时间戳：$Timestamp）"
exit 0
