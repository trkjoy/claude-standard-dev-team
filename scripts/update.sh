#!/usr/bin/env bash
# 升级标准 AI 开发团队（Mac / Linux / WSL）
#
# 与 install.sh 的区别：本脚本面向「已安装过、想升级」的用户，做两件事：
#   1. 刷新全局：复用 install.sh 的 Claude Code 安装分支，更新 ~/.claude 下
#      agents / 命令 / 知识库 / workflow 模板
#   2. 同步项目：把「当前项目目录」CLAUDE.md 的「## 团队配置」段落升级到本包版本，
#      保留用户填写的技术栈 / 部署环境字段
#
# 全程不联网。用法：
#   先下载并解压对应版本的发布包，进入你的项目目录后运行：
#     bash <解压目录>/scripts/update.sh
#   或显式指定项目目录：
#     bash <解压目录>/scripts/update.sh /path/to/your-project
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
REPO_VERSION="$(cat "$REPO_DIR/VERSION" | tr -d '[:space:]')"
TPL_FILE="$REPO_DIR/templates/memory/project-CLAUDE.md"

# 参数：$1 = 项目目录（可选，默认当前工作目录）
PROJECT_DIR="${1:-$(pwd)}"
if [ ! -d "$PROJECT_DIR" ]; then
  echo "❌ 指定的项目目录不存在：$PROJECT_DIR" >&2
  exit 1
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

echo ""
echo "┌──────────────────────────────────────────────────────────┐"
echo "│   AI 标准开发团队 v${REPO_VERSION}  ·  升级程序              │"
echo "└──────────────────────────────────────────────────────────┘"
echo ""
echo "项目目录：$PROJECT_DIR"
echo ""

# ─── Step 1：刷新全局 agents / 命令 / 知识库 / workflow ────────────────────────
# 用子进程调用 install.sh（其内部 exit 只影响子 shell，不会终止本脚本）。
# 传 claude 1 = Claude Code 平台 + 知识库「跳过已存在」模式（不覆盖用户历史）。
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
if [ ! -f "$INSTALL_SCRIPT" ]; then
  echo "❌ 找不到 install.sh：$INSTALL_SCRIPT" >&2
  exit 1
fi
echo "[1/2] 刷新全局（~/.claude/agents、命令、知识库、workflow）..."
bash "$INSTALL_SCRIPT" claude 1

# ─── Step 2：同步项目 CLAUDE.md 的「## 团队配置」段落 ─────────────────────────
echo ""
echo "[2/2] 同步项目 CLAUDE.md 团队配置段落..."

CLAUDE_MD="$PROJECT_DIR/CLAUDE.md"
PROJECT_MSG=""

# awk 提取「## 团队配置」到下一个 `## ` 二级标题之前的整段（含起始标题；
# `### ` 子标题不算二级标题，会被纳入）。从 $1 文件读取。
_extract_block() {
  awk '
    state==0 && /^##[[:space:]]+团队配置[[:space:]]*$/ { state=1; print; next }
    state==1 && /^## / { state=2 }
    state==1 { print }
  ' "$1"
}

if [ ! -f "$CLAUDE_MD" ]; then
  echo "  ⚠  当前项目目录未找到 CLAUDE.md（尚未初始化）"
  echo "     请在 Claude Code 内于该项目运行 /team-init 后再升级。"
  PROJECT_MSG="当前项目未初始化（已跳过）"
elif ! grep -qE '^##[[:space:]]+团队配置[[:space:]]*$' "$CLAUDE_MD"; then
  echo "  ⚠  当前 CLAUDE.md 找不到 '## 团队配置' 标题，结构异常，已跳过同步。"
  echo "     请手动核对该文件后再升级团队配置段落。"
  PROJECT_MSG="结构异常（已跳过）"
else
  tpl_block="$(_extract_block "$TPL_FILE")"
  if [ -z "$tpl_block" ]; then
    echo "  ❌ 模板缺少 ## 团队配置 段落：$TPL_FILE" >&2
    exit 1
  fi
  dst_block="$(_extract_block "$CLAUDE_MD")"

  if [ "$dst_block" = "$tpl_block" ]; then
    echo "  ✅ CLAUDE.md 团队配置段落已是最新，无需更新"
    PROJECT_MSG="已是最新"
  else
    tmp="$(mktemp)"
    # print block 后补一个空行：命令替换会吃掉 tpl_block 末尾空行，
    # 这里补回，保证与 `## 项目上下文` 之间有空行分隔（与模板一致）
    awk -v block="$tpl_block" '
      state==0 && /^##[[:space:]]+团队配置[[:space:]]*$/ { print block; print ""; state=1; next }
      state==1 && /^## / { state=2 }
      state==1 { next }
      { print }
    ' "$CLAUDE_MD" > "$tmp"
    mv "$tmp" "$CLAUDE_MD"
    echo "  ✅ 已同步 CLAUDE.md 团队配置段落（保留技术栈/部署环境字段）"
    PROJECT_MSG="已更新团队配置段落"
  fi
fi

# ─── 报告 ────────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "✅ 团队升级完成"
echo ""
echo "   目标版本      → v$REPO_VERSION"
echo "   全局 agents   → 已刷新（~/.claude/agents/）"
echo "   项目 CLAUDE.md → $PROJECT_MSG"
echo ""
echo "⚠️ 重启 Claude Code 让新 agent 与命令生效。"
echo "========================================="
echo ""
