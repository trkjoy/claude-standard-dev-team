#!/usr/bin/env bash
# collect-ci-failure.sh — CI 失败日志收集 hook（P1-3 轻量层）
#
# 本脚本是项目级 hook，由 team-init 放入目标项目的 .claude/hooks/ 目录。
# 不随 install.sh 的 *.workflow.js 通道分发；需用户手动注册到 settings.json。
# 注册示例见同目录 settings-hook-snippet.json。
#
# ┌──────────────── 用途 ────────────────────────────────────────┐
# │ CI 失败时，提取可定位的失败摘要写入                          │
# │ .claude/team-state/CI_FAILURE.md（追加，带时间戳）。         │
# │ 下次 Claude 会话开场时，orchestrator 可读取此文件作为        │
# │ Hotfix 输入提示（半自动，需人工确认才开始修复）。            │
# └──────────────────────────────────────────────────────────────┘
#
# ┌──────────────── 待验证假设 ──────────────────────────────────┐
# │ - CI→回灌 Claude 的端到端触发链属待验证假设：               │
# │   本脚本只负责"写文件"这一步；CI 系统如何调用本脚本、       │
# │   写完后如何让 Claude 下次会话感知，需项目方自行配置。      │
# │ - 失败日志格式因 CI 系统（GitHub Actions/Jenkins/GitLab CI）│
# │   而异，本脚本做最大努力提取，可能有遗漏。                  │
# └──────────────────────────────────────────────────────────────┘
#
# 用法（两种输入模式）：
#
#   模式1：从文件读取日志
#     bash .claude/hooks/collect-ci-failure.sh --file /path/to/ci.log --ts "2026-06-23T10:00:00Z"
#
#   模式2：从 stdin 读取日志（管道）
#     cat ci.log | bash .claude/hooks/collect-ci-failure.sh --ts "2026-06-23T10:00:00Z"
#
# 选项：
#   --file <path>    CI 日志文件路径（与 stdin 二选一）
#   --ts <timestamp> 时间戳字符串（调用方注入，避免脚本内调用 date）
#   --out <path>     输出文件路径（默认 .claude/team-state/CI_FAILURE.md）
#   --max-lines <n>  摘要最大行数（默认 50，避免文件过大）
#   -h, --help       显示帮助
#
# 退出码：
#   0  成功写入摘要
#   1  无有效日志输入
#   2  参数错误

set -euo pipefail

# ── 默认参数 ──────────────────────────────────────────────────

LOG_FILE=""
TIMESTAMP="unknown"
OUT_FILE=".claude/team-state/CI_FAILURE.md"
MAX_LINES=50

# ── 参数解析 ──────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)      LOG_FILE="$2";   shift 2 ;;
    --ts)        TIMESTAMP="$2";  shift 2 ;;
    --out)       OUT_FILE="$2";   shift 2 ;;
    --max-lines) MAX_LINES="$2";  shift 2 ;;
    -h|--help)
      sed -n '/^# 用法/,/^# 退出码/p' "$0"
      exit 0
      ;;
    *) echo "[collect-ci-failure] 未知参数：$1" >&2; exit 2 ;;
  esac
done

# ── 读取日志内容 ──────────────────────────────────────────────

LOG_CONTENT=""

if [[ -n "$LOG_FILE" ]]; then
  if [[ ! -f "$LOG_FILE" ]]; then
    echo "[collect-ci-failure] 日志文件不存在：$LOG_FILE" >&2
    exit 1
  fi
  LOG_CONTENT="$(cat "$LOG_FILE")"
elif [[ ! -t 0 ]]; then
  # stdin 有内容（非终端）
  LOG_CONTENT="$(cat)"
else
  echo "[collect-ci-failure] 错误：需通过 --file 或 stdin 提供日志内容" >&2
  exit 1
fi

if [[ -z "$LOG_CONTENT" ]]; then
  echo "[collect-ci-failure] 警告：日志内容为空，跳过写入" >&2
  exit 1
fi

# ── 提取失败摘要 ──────────────────────────────────────────────

# 提取含失败关键词的行（覆盖常见 CI 系统的输出格式）
FAILURE_SUMMARY="$(echo "$LOG_CONTENT" | grep -iE \
  'FAIL|ERROR|error:|failed|FAILED|✗|✘|AssertionError|TypeError|Exception|at line|undefined|null pointer|panic:|fatal:' \
  2>/dev/null | head -n "$MAX_LINES" || true)"

# 提取测试用例名（Jest/pytest/go test 常见格式）
TEST_NAMES="$(echo "$LOG_CONTENT" | grep -oE \
  '(FAIL|FAILED|✗)\s+[a-zA-Z0-9_./: -]+' \
  2>/dev/null | head -n 20 || true)"

# ── 确保输出目录存在 ──────────────────────────────────────────

OUT_DIR="$(dirname "$OUT_FILE")"
mkdir -p "$OUT_DIR"

# ── 追加写入 CI_FAILURE.md ────────────────────────────────────

cat >> "$OUT_FILE" << EOF

---
## CI 失败记录 — ${TIMESTAMP}

**时间戳（调用方注入）**: ${TIMESTAMP}

### 失败测试用例（最多 20 条）

\`\`\`
${TEST_NAMES:-（未识别到测试用例名，请查阅完整摘要）}
\`\`\`

### 失败日志摘要（最多 ${MAX_LINES} 行）

\`\`\`
${FAILURE_SUMMARY:-（未识别到失败关键词，原始日志可能需要手工查阅）}
\`\`\`

> 自动提取，可能有遗漏。下次会话开场时 orchestrator 可读取本文件作为 Hotfix 输入。
> 待验证假设：CI→Claude 端到端触发链需项目方自行配置。
EOF

echo "[collect-ci-failure] 已追加写入：$OUT_FILE（时间戳：$TIMESTAMP）"
exit 0
