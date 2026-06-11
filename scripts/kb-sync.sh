#!/usr/bin/env bash
set -euo pipefail

# kb-sync.sh
# 用户级知识库手动同步脚本（当前阶段：仅本地状态查看 + 备份）
#
# 用法:
#   ./kb-sync.sh             默认执行 --status + --backup
#   ./kb-sync.sh --status    显示 6 个 *-patterns.md 文件的状态
#   ./kb-sync.sh --backup    备份 patterns 目录到 backups/YYYY-MM-DD_HHMMSS/
#   ./kb-sync.sh --help      显示帮助
#
# FUTURE: 后端接入后在此处添加 push/pull 逻辑
# FUTURE: pull_from_remote() - 拉取远端最新版本（团队共享模式）
# FUTURE: push_to_remote() - 增量上传本地变更（sha256 哈希驱动，last-write-wins）
# FUTURE: 团队共享模式下需要在 push 前先 pull（避免覆盖他人变更）

# ------------- 路径常量 -------------
KB_ROOT="${HOME}/.claude/team-memory"
PATTERNS_DIR="${KB_ROOT}/patterns"
BACKUPS_DIR="${KB_ROOT}/backups"

PATTERN_FILES=(
  "backend-patterns.md"
  "frontend-patterns.md"
  "contract-patterns.md"
  "qa-patterns.md"
  "security-patterns.md"
  "deployment-patterns.md"
)

# ------------- 工具函数 -------------
print_help() {
  cat <<'EOF'
kb-sync.sh - 用户级知识库手动同步脚本

用法:
  ./kb-sync.sh             默认执行 --status + --backup
  ./kb-sync.sh --status    显示 6 个 *-patterns.md 文件的状态
  ./kb-sync.sh --backup    备份 patterns 目录到 backups/YYYY-MM-DD_HHMMSS/
  ./kb-sync.sh --help      显示帮助

文件位置:
  ~/.claude/team-memory/patterns/   知识库主目录
  ~/.claude/team-memory/backups/    备份目录
EOF
}

# 跨平台获取文件大小（macOS 用 stat -f%z，Linux 用 stat -c%s）
file_size() {
  local f="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f%z "$f" 2>/dev/null || echo 0
  else
    stat -c%s "$f" 2>/dev/null || echo 0
  fi
}

# 跨平台获取文件最后修改时间
file_mtime() {
  local f="$1"
  if [[ "$(uname -s)" == "Darwin" ]]; then
    stat -f"%Sm" -t"%Y-%m-%d %H:%M:%S" "$f" 2>/dev/null || echo "unknown"
  else
    stat -c"%y" "$f" 2>/dev/null | cut -d'.' -f1 || echo "unknown"
  fi
}

# 统计条目数：以 "## " 开头的行
entry_count() {
  local f="$1"
  if [[ -f "$f" ]]; then
    grep -c "^## " "$f" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# ------------- 命令实现 -------------
do_status() {
  echo "============================================================"
  echo " 知识库状态  (${PATTERNS_DIR})"
  echo "============================================================"

  if [[ ! -d "${PATTERNS_DIR}" ]]; then
    echo "[警告] patterns 目录不存在：${PATTERNS_DIR}"
    echo "       请先运行 scripts/install.sh 初始化知识库"
    return 0
  fi

  printf "%-26s %10s %10s   %s\n" "文件名" "大小(B)" "条目数" "最后修改"
  printf "%-26s %10s %10s   %s\n" "--------------------------" "----------" "----------" "-------------------"

  local total_entries=0
  local total_size=0

  for f in "${PATTERN_FILES[@]}"; do
    local path="${PATTERNS_DIR}/${f}"
    if [[ -f "${path}" ]]; then
      local sz
      sz=$(file_size "${path}")
      local cnt
      cnt=$(entry_count "${path}")
      local mt
      mt=$(file_mtime "${path}")
      printf "%-26s %10s %10s   %s\n" "${f}" "${sz}" "${cnt}" "${mt}"
      total_size=$(( total_size + sz ))
      total_entries=$(( total_entries + cnt ))
    else
      printf "%-26s %10s %10s   %s\n" "${f}" "—" "—" "(文件不存在)"
    fi
  done

  echo "------------------------------------------------------------"
  printf "%-26s %10s %10s\n" "合计" "${total_size}" "${total_entries}"
  echo
}

do_backup() {
  echo "============================================================"
  echo " 备份知识库"
  echo "============================================================"

  if [[ ! -d "${PATTERNS_DIR}" ]]; then
    echo "[错误] patterns 目录不存在：${PATTERNS_DIR}"
    echo "       无内容可备份，请先运行 scripts/install.sh"
    return 1
  fi

  local ts
  ts="$(date +%Y-%m-%d_%H%M%S)"
  local target="${BACKUPS_DIR}/${ts}"

  if [[ -d "${target}" ]]; then
    echo "[跳过] 已存在备份：${target}"
    return 0
  fi

  mkdir -p "${target}"
  cp -R "${PATTERNS_DIR}/." "${target}/"

  local copied
  copied=$(find "${target}" -maxdepth 1 -type f -name '*.md' | wc -l | tr -d ' ')

  echo "[完成] 备份目录：${target}"
  echo "[完成] 已复制 ${copied} 个 .md 文件"
  echo
}

# ------------- 参数解析 -------------
main() {
  if [[ $# -eq 0 ]]; then
    do_status
    do_backup
    exit 0
  fi

  for arg in "$@"; do
    case "${arg}" in
      --status)
        do_status
        ;;
      --backup)
        do_backup
        ;;
      --help|-h)
        print_help
        ;;
      *)
        echo "[错误] 未知参数：${arg}"
        echo
        print_help
        exit 1
        ;;
    esac
  done
}

main "$@"
