#!/usr/bin/env bash
# 安装标准 AI 开发团队（Mac / Linux / WSL）
# 幂等：重复运行安全，已有记忆库内容不会被覆盖
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_SRC="$REPO_DIR/agents"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
AGENTS_DEST="$HOME/.claude/agents"
MEMORY_DEST="$HOME/.claude/team-memory/patterns"
COMMANDS_SRC="$REPO_DIR/.claude/commands"
COMMANDS_DEST="$HOME/.claude/commands"

if [ ! -d "$AGENTS_SRC" ]; then
  echo "❌ 找不到 agents 目录：$AGENTS_SRC" >&2
  echo "   请在 claude-standard-dev-team 克隆目录中运行此脚本。" >&2
  exit 1
fi

echo ""
echo "📦 正在安装标准 AI 开发团队..."
echo ""

# 1. 安装 agent 文件到 ~/.claude/agents/
mkdir -p "$AGENTS_DEST"
cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
agent_count="$(find "$AGENTS_SRC" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
echo "✅ 已安装 $agent_count 个 agent -> $AGENTS_DEST"

# 2. 初始化用户级知识库（已存在则跳过，保留历史积累）
mkdir -p "$MEMORY_DEST"
for pattern in backend frontend contract qa security deployment; do
  src="$TEMPLATES_SRC/${pattern}-patterns.md"
  dest="$MEMORY_DEST/${pattern}-patterns.md"
  if [ ! -f "$src" ]; then
    echo "❌ 模板文件缺失：$src" >&2
    exit 1
  fi
  if [ -f "$dest" ]; then
    echo "  ⏭  跳过（已存在）：${pattern}-patterns.md"
  else
    cp "$src" "$dest"
    echo "  ✅ 初始化：${pattern}-patterns.md"
  fi
done

# 3. 注册全局 Claude Code 命令（让 /team-install 和 /team-init 全局可用）
if [ -d "$COMMANDS_SRC" ]; then
  mkdir -p "$COMMANDS_DEST"
  cp "$COMMANDS_SRC/team-install.md" "$COMMANDS_DEST/"
  cp "$COMMANDS_SRC/team-init.md" "$COMMANDS_DEST/"
  echo "✅ 已注册全局命令 -> $COMMANDS_DEST"
else
  echo "  ⚠  跳过命令注册（.claude/commands/ 目录不存在）"
fi

echo ""
echo "✅ 安装完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "后续操作全在 Claude Code 内完成："
echo ""
echo "  进入项目目录，打开 Claude Code，运行："
echo "    /team-init"
echo ""
echo "  初始化后说："
echo "    使用标准团队开发 你的需求"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
