# contract-diff.ps1 — 契约一致性确定性 gate（P1-1 实现，Windows/PowerShell 版）
#
# 本脚本是项目级脚本，由 team-init 放入目标项目的 scripts\ 目录。
# 不随 install.sh 的 *.workflow.js 通道分发；team-init 负责按项目铺设。
#
# ┌──────────────── 用途 ────────────────────────────────────────┐
# │ 把「契约一致性」从 LLM 肉眼比对升级为机器 diff（确定性 gate）│
# │ 解析 docs\API_CONTRACT.md 中声明的 "METHOD /path" 形式接口,  │
# │ 在实现源码目录 grep 路径，输出差异清单；有差异则退出码非 0。 │
# └──────────────────────────────────────────────────────────────┘
#
# ┌──────────────── 假设与局限（诚实标注）────────────────────┐
# │ 1. 契约格式假设：API_CONTRACT.md 中每行含 "METHOD /path"   │
# │    子串（如 "GET /api/users"）。表格行也可命中。           │
# │ 2. 路由解析因技术栈而异：字符串字面量的路径才能被 grep 到；│
# │    变量拼装路径无法覆盖，需手工校验。                      │
# │ 3. 本脚本是最大努力版，不设计成万能解析器。                │
# │ 4. PowerShell Select-String 性能在大仓库下可能较慢。       │
# └────────────────────────────────────────────────────────────┘
#
# 用法：
#   powershell -ExecutionPolicy Bypass -File scripts\contract-diff.ps1 [OPTIONS]
#
# 选项：
#   -ContractFile <path>   契约文件路径（默认 docs\API_CONTRACT.md）
#   -SrcDir <dir>          源码目录（默认 src\）
#   -Ext <exts>            源码扩展名，逗号分隔（默认 js,ts,py,go）
#   -Strict                严格模式：双向差异都报错
#
# 退出码：
#   0  无差异（gate 通过）
#   1  发现差异（gate 失败）
#   2  参数或依赖错误

param(
    [string]$ContractFile = "docs\API_CONTRACT.md",
    [string]$SrcDir       = "src\",
    [string]$Ext          = "js,ts,py,go",
    [switch]$Strict
)

# 确保退出码能正确传递给调用方
$ErrorActionPreference = "Stop"

# ── 文件/目录检查 ─────────────────────────────────────────────

if (-not (Test-Path $ContractFile)) {
    Write-Error "[contract-diff] 契约文件不存在：$ContractFile"
    Write-Host "  提示：请确认 docs\API_CONTRACT.md 已创建，或用 -ContractFile 指定路径。"
    exit 2
}

if (-not (Test-Path $SrcDir -PathType Container)) {
    Write-Error "[contract-diff] 源码目录不存在：$SrcDir"
    Write-Host "  提示：用 -SrcDir 指定正确的源码目录。"
    exit 2
}

# ── 步骤1：从契约文件提取 "METHOD /path" ─────────────────────

Write-Host "[contract-diff] 读取契约：$ContractFile"

$methodPattern = '(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\s+(/[a-zA-Z0-9_/:-]+)'
$contractContent = Get-Content $ContractFile -Encoding UTF8

$contractPaths = [System.Collections.Generic.SortedSet[string]]::new()
foreach ($line in $contractContent) {
    $m = [regex]::Match($line, $methodPattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($m.Success) {
        # 取路径部分（第2个捕获组），去掉末尾标点
        $path = $m.Groups[2].Value -replace '[,.)>|]+$', ''
        if ($path -ne '') {
            $null = $contractPaths.Add($path)
        }
    }
}

$contractCount = $contractPaths.Count
Write-Host "[contract-diff] 契约中识别到 $contractCount 条接口声明"

if ($contractCount -eq 0) {
    Write-Warning "[contract-diff] 契约文件中未识别到任何 'METHOD /path' 格式声明。"
    Write-Host "  假设：每个接口应有一行形如 'GET /api/users' 的声明（表格/列表均可）。"
    Write-Host "  若契约格式不符，请手工校验。"
    exit 0
}

# ── 步骤2：从源码中提取路径字符串 ───────────────────────────

Write-Host "[contract-diff] 扫描源码：$SrcDir（扩展名：$Ext）"

$extList = $Ext -split ',' | ForEach-Object { $_.Trim() }
$includeFilter = $extList | ForEach-Object { "*.$_" }

# 从源码提取双引号和单引号中的路径字符串
$pathPattern = '["''](/[a-zA-Z0-9_/:-]+)["'']'
$codePaths = [System.Collections.Generic.SortedSet[string]]::new()

Get-ChildItem -Path $SrcDir -Recurse -File -Include $includeFilter -ErrorAction SilentlyContinue |
    ForEach-Object {
        $content = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($content) {
            foreach ($line in $content) {
                $matches_found = [regex]::Matches($line, $pathPattern)
                foreach ($match in $matches_found) {
                    $null = $codePaths.Add($match.Groups[1].Value)
                }
            }
        }
    }

$codeCount = $codePaths.Count
Write-Host "[contract-diff] 源码中识别到 $codeCount 条路径字符串"

# ── 步骤3：计算差异 ──────────────────────────────────────────

# 契约有但代码无
$diffA = $contractPaths | Where-Object { -not $codePaths.Contains($_) }

# 代码有但契约无
$diffB = $codePaths | Where-Object { -not $contractPaths.Contains($_) }

$diffACount = @($diffA).Count
$diffBCount = @($diffB).Count

# ── 步骤4：输出结果 ──────────────────────────────────────────

Write-Host ""
Write-Host "══ contract-diff 结果 ════════════════════════════════════"
Write-Host "契约声明数 : $contractCount"
Write-Host "源码路径数 : $codeCount"
Write-Host ""

$exitCode = 0

if ($diffACount -gt 0) {
    Write-Host "[FAIL] 契约中声明但源码中未找到的路径（$diffACount 条）：" -ForegroundColor Red
    $diffA | ForEach-Object { Write-Host "  - $_" }
    Write-Host ""
    Write-Host "  → 可能原因：接口未实现、路径拼写不一致、或变量拼装路径无法被 grep 捕获（需手工校验）。"
    $exitCode = 1
} else {
    Write-Host "契约声明的路径均在源码中找到" -ForegroundColor Green
}

Write-Host ""

if ($diffBCount -gt 0) {
    if ($Strict) {
        Write-Host "[FAIL --Strict] 源码中存在但契约未声明的路径（$diffBCount 条）：" -ForegroundColor Red
        $diffB | ForEach-Object { Write-Host "  - $_" }
        Write-Host ""
        Write-Host "  → 请补充到 docs\API_CONTRACT.md，或确认为内部路径无需声明。"
        $exitCode = 1
    } else {
        Write-Host "[WARN] 源码中存在但契约未声明的路径（$diffBCount 条，-Strict 模式下会报错）：" -ForegroundColor Yellow
        $diffB | ForEach-Object { Write-Host "  - $_" }
        Write-Host "  → 建议补充到契约，或用 -Strict 把此项升级为硬 gate。"
    }
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════════════"

if ($exitCode -eq 0) {
    Write-Host "contract-diff gate 通过" -ForegroundColor Green
} else {
    Write-Host "contract-diff gate 失败（退出码 1）" -ForegroundColor Red
}

exit $exitCode
