#!/usr/bin/env bash
# contract-diff.sh — 契约一致性确定性 gate（P1-1 实现）
#
# 本脚本是项目级脚本，由 team-init 放入目标项目的 scripts/ 目录。
# 不随 install.sh 的 *.workflow.js 通道分发；team-init 负责按项目铺设。
#
# ┌──────────────── 用途 ────────────────────────────────────────┐
# │ 把「契约一致性」从 LLM 肉眼比对升级为机器 diff（确定性 gate）│
# │ 解析 docs/API_CONTRACT.md 中声明的 "METHOD /path" 形式接口,  │
# │ 在实现源码目录 grep 路径，输出差异清单；有差异则退出码非 0。 │
# └──────────────────────────────────────────────────────────────┘
#
# ┌──────────────── 假设与局限（诚实标注）─────────────────────┐
# │ 1. 契约格式假设：API_CONTRACT.md 中每行以 "METHOD /path" 形 │
# │    式声明接口（如 "GET /api/users"、"POST /api/login"）。   │
# │    表格形式也支持（只要行内含 METHOD /path 子串）。         │
# │ 2. 路由解析因技术栈而异：本脚本用字符串 grep，能覆盖大多数  │
# │    Express/Fastify/Flask/FastAPI/gin 等把路径写成字符串字面  │
# │    量的框架；对用变量/常量拼装路径的情况无法覆盖，需手工校。│
# │ 3. 本脚本是最大努力版，不设计成万能解析器。复杂路由（如    │
# │    装饰器 @Get("/path")）可通过 --ext 参数追加扩展名来提升  │
# │    覆盖率，但不保证 100%。                                  │
# │ 4. "代码中有但契约未声明" 的检测依赖 grep 能从源码中提取  │
# │    路径字符串，准确率因代码风格而异。                       │
# └──────────────────────────────────────────────────────────────┘
#
# 用法：
#   bash scripts/contract-diff.sh [OPTIONS]
#
# 选项：
#   --contract <path>   契约文件路径（默认 docs/API_CONTRACT.md）
#   --src <dir>         源码目录（默认 src/）
#   --ext <exts>        源码文件扩展名，逗号分隔（默认 js,ts,py,go）
#   --strict            严格模式：双向差异都报错（默认只报契约有但代码无）
#   -h, --help          显示帮助
#
# 退出码：
#   0  无差异（gate 通过）
#   1  发现差异（gate 失败）
#   2  使用错误或依赖缺失

set -euo pipefail

# ── 默认参数 ──────────────────────────────────────────────────

CONTRACT_FILE="docs/API_CONTRACT.md"
SRC_DIR="src/"
EXTS="js,ts,py,go"
STRICT_MODE=0

# ── 参数解析 ──────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
  case "$1" in
    --contract) CONTRACT_FILE="$2"; shift 2 ;;
    --src)      SRC_DIR="$2";       shift 2 ;;
    --ext)      EXTS="$2";          shift 2 ;;
    --strict)   STRICT_MODE=1;      shift   ;;
    -h|--help)
      sed -n '/^# 用法/,/^$/p' "$0"
      exit 0
      ;;
    *) echo "[contract-diff] 未知参数：$1" >&2; exit 2 ;;
  esac
done

# ── 依赖检查 ──────────────────────────────────────────────────

for cmd in grep awk sort comm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "[contract-diff] 依赖缺失：$cmd" >&2
    exit 2
  fi
done

# ── 文件/目录检查 ─────────────────────────────────────────────

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "[contract-diff] 契约文件不存在：$CONTRACT_FILE" >&2
  echo "  提示：请确认 docs/API_CONTRACT.md 已创建，或用 --contract 指定路径。" >&2
  exit 2
fi

if [[ ! -d "$SRC_DIR" ]]; then
  echo "[contract-diff] 源码目录不存在：$SRC_DIR" >&2
  echo "  提示：用 --src 指定正确的源码目录。" >&2
  exit 2
fi

# ── 临时文件（退出时清理）────────────────────────────────────

TMP_CONTRACT="$(mktemp)"
TMP_CODE="$(mktemp)"
TMP_DIFF_A="$(mktemp)"  # 契约有但代码无
TMP_DIFF_B="$(mktemp)"  # 代码有但契约无
trap 'rm -f "$TMP_CONTRACT" "$TMP_CODE" "$TMP_DIFF_A" "$TMP_DIFF_B"' EXIT

# ── 步骤1：从契约文件提取 "METHOD /path" ─────────────────────

echo "[contract-diff] 读取契约：$CONTRACT_FILE"

# 匹配形如 "GET /api/xxx"、"POST /users" 的行（不区分大小写方法名）
# 表格行（含 | GET | /api/... |）也能命中，因为 awk 只关心子串
awk '
  match($0, /(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)[[:space:]]+\/[^[:space:]"'"'"'|>)]+/, arr) {
    # 规范化：方法名大写，路径保留原始大小写
    method = arr[0]
    split(method, parts, /[[:space:]]+/)
    m = toupper(parts[1])
    p = parts[2]
    # 去掉路径末尾的标点（逗号/句号/括号等 markdown 标记）
    sub(/[,.)>|]+$/, "", p)
    if (p != "") print m " " p
  }
' "$CONTRACT_FILE" | sort -u > "$TMP_CONTRACT"

CONTRACT_COUNT="$(wc -l < "$TMP_CONTRACT" | tr -d ' ')"
echo "[contract-diff] 契约中识别到 ${CONTRACT_COUNT} 条接口声明"

if [[ "$CONTRACT_COUNT" -eq 0 ]]; then
  echo "[contract-diff] 警告：契约文件中未识别到任何 'METHOD /path' 格式声明。"
  echo "  假设：每个接口应有一行形如 'GET /api/users' 的声明（表格/列表均可）。"
  echo "  若契约格式不符，请手工校验。"
  # 无契约声明时视为"无差异"（避免误报），但打印警告
  exit 0
fi

# ── 步骤2：从源码中提取路径字符串 ───────────────────────────

echo "[contract-diff] 扫描源码：$SRC_DIR（扩展名：$EXTS）"

# 将逗号分隔的扩展名转为 find -name 参数
EXT_ARGS=()
IFS=',' read -ra EXT_LIST <<< "$EXTS"
for ext in "${EXT_LIST[@]}"; do
  EXT_ARGS+=(-o -name "*.${ext}")
done
# 移除首个 -o（find 语法需要）
EXT_ARGS=("${EXT_ARGS[@]:1}")

# 从源码中提取看起来像 API 路径的字符串（/api/、/v1/ 等开头的字符串字面量）
# 局限（见顶部注释）：变量拼装的路径无法被此 grep 捕获
find "$SRC_DIR" \( "${EXT_ARGS[@]}" \) -type f -print0 \
  | xargs -0 grep -ohE '"(/[a-zA-Z0-9_/:-]+)"' 2>/dev/null \
  | sed 's/"//g' \
  | sort -u > "$TMP_CODE" || true

# 同时尝试单引号格式（Python/Go 常见）
find "$SRC_DIR" \( "${EXT_ARGS[@]}" \) -type f -print0 \
  | xargs -0 grep -ohE "'(/[a-zA-Z0-9_/:-]+)'" 2>/dev/null \
  | sed "s/'//g" \
  | sort -u >> "$TMP_CODE" || true

sort -u "$TMP_CODE" -o "$TMP_CODE"

CODE_COUNT="$(wc -l < "$TMP_CODE" | tr -d ' ')"
echo "[contract-diff] 源码中识别到 ${CODE_COUNT} 条路径字符串"

# ── 步骤3：计算差异 ──────────────────────────────────────────

# 契约路径列表（只取路径部分，去掉方法名，用于与源码路径比对）
awk '{print $2}' "$TMP_CONTRACT" | sort -u > /tmp/_contract_paths.tmp

# 契约有但代码无（最关键：实现遗漏了声明的接口）
comm -23 \
  <(sort /tmp/_contract_paths.tmp) \
  <(sort "$TMP_CODE") \
  > "$TMP_DIFF_A"
rm -f /tmp/_contract_paths.tmp

# 代码有但契约未声明（仅 --strict 模式报错，默认只打印警告）
comm -13 \
  <(sort /tmp/_contract_paths.tmp 2>/dev/null || awk '{print $2}' "$TMP_CONTRACT" | sort -u) \
  <(sort "$TMP_CODE") \
  > "$TMP_DIFF_B" 2>/dev/null || true

# 重新计算（comm 不能复用已关闭的替换进程）
awk '{print $2}' "$TMP_CONTRACT" | sort -u > /tmp/_contract_paths2.tmp
comm -13 \
  <(sort /tmp/_contract_paths2.tmp) \
  <(sort "$TMP_CODE") \
  > "$TMP_DIFF_B"
rm -f /tmp/_contract_paths2.tmp

DIFF_A_COUNT="$(wc -l < "$TMP_DIFF_A" | tr -d ' ')"
DIFF_B_COUNT="$(wc -l < "$TMP_DIFF_B" | tr -d ' ')"

# ── 步骤4：输出结果 ──────────────────────────────────────────

echo ""
echo "══ contract-diff 结果 ════════════════════════════════════"
echo "契约声明数 : $CONTRACT_COUNT"
echo "源码路径数 : $CODE_COUNT"
echo ""

EXIT_CODE=0

if [[ "$DIFF_A_COUNT" -gt 0 ]]; then
  echo "❌ [FAIL] 契约中声明但源码中未找到的路径（${DIFF_A_COUNT} 条）："
  awk '{print "  - " $0}' "$TMP_DIFF_A"
  echo ""
  echo "  → 可能原因：接口未实现、路径拼写不一致、或变量拼装路径无法被 grep 捕获（需手工校验）。"
  EXIT_CODE=1
else
  echo "✅ 契约声明的路径均在源码中找到"
fi

echo ""

if [[ "$DIFF_B_COUNT" -gt 0 ]]; then
  if [[ "$STRICT_MODE" -eq 1 ]]; then
    echo "❌ [FAIL --strict] 源码中存在但契约未声明的路径（${DIFF_B_COUNT} 条）："
    awk '{print "  - " $0}' "$TMP_DIFF_B"
    echo ""
    echo "  → 请补充到 docs/API_CONTRACT.md，或确认为内部路径无需声明。"
    EXIT_CODE=1
  else
    echo "⚠  [WARN] 源码中存在但契约未声明的路径（${DIFF_B_COUNT} 条，--strict 模式下会报错）："
    awk '{print "  - " $0}' "$TMP_DIFF_B"
    echo "  → 建议补充到契约，或用 --strict 把此项升级为硬 gate。"
  fi
fi

echo ""
echo "══════════════════════════════════════════════════════════"

if [[ "$EXIT_CODE" -eq 0 ]]; then
  echo "✅ contract-diff gate 通过"
else
  echo "❌ contract-diff gate 失败（退出码 1）"
fi

exit "$EXIT_CODE"
