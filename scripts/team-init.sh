#!/usr/bin/env bash
# 在当前目录初始化标准团队项目（Mac / Linux / WSL）
# 交互式收集项目配置，生成即用的 CLAUDE.md，无需手动编辑
# 幂等：已存在的文件不会被覆盖
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
STATE_TEMPLATES_SRC="$TEMPLATES_SRC/team-state"
PROJECT_NAME="$(basename "$PWD")"

if [ ! -d "$TEMPLATES_SRC" ]; then
  echo "❌ templates 目录不存在：$TEMPLATES_SRC" >&2
  echo "   请先运行 install.sh，或指定正确的仓库路径。" >&2
  exit 1
fi

echo ""
echo "🚀 正在初始化项目：$PROJECT_NAME"
echo ""

# ── 已有 CLAUDE.md：跳过交互，直接处理其余文件 ─────────────────────
if [ -f "CLAUDE.md" ]; then
  echo "⏭  CLAUDE.md 已存在，跳过（如需更新请手动编辑）"
else
  # ── 交互式收集项目配置 ───────────────────────────────────────────
  echo "请回答以下两个问题（直接回车使用括号内的示例值）："
  echo ""

  printf "  技术栈（例：Express.js, React, PostgreSQL）：  "
  read -r TECH_STACK
  [ -z "$TECH_STACK" ] && TECH_STACK="Express.js, React, PostgreSQL"

  printf "  部署环境（例：Docker + Nginx，或 Vercel）：    "
  read -r DEPLOY_ENV
  [ -z "$DEPLOY_ENV" ] && DEPLOY_ENV="Docker + Nginx"

  echo ""

  # ── 生成 CLAUDE.md（值已填入，无需再编辑）────────────────────────
  cat > CLAUDE.md << CLAUDEEOF
# ${PROJECT_NAME}

## 团队配置

本项目使用标准 AI 开发团队（13 agents）。
在 Claude Code 中说"使用标准团队开发 你的需求"即可启动 orchestrator。

## 项目上下文

- 技术栈: ${TECH_STACK}
- 部署环境: ${DEPLOY_ENV}

## 团队运行机制

- 项目状态记录在 \`.claude/team-state/STATE.md\`
- 失败重试记录在 \`.claude/team-state/RETRY_LOG.md\`
- 用户确认过的关键决策记录在 \`.claude/team-state/DECISIONS.md\`
- 项目内经验记录在 \`.claude/team-state/LEARNINGS.md\`
- 用户级长期记忆位于 \`~/.claude/team-memory/patterns/\`
CLAUDEEOF

  echo "✅ 已生成 CLAUDE.md"
fi

# ── .claude/settings.json ────────────────────────────────────────────
mkdir -p .claude
if [ -f ".claude/settings.json" ]; then
  echo "⏭  .claude/settings.json 已存在，跳过"
else
  cp "$TEMPLATES_SRC/settings.json" .claude/settings.json
  echo "✅ 已生成 .claude/settings.json"
fi

# ── .claude/team-state/ ──────────────────────────────────────────────
mkdir -p .claude/team-state
for state_file in STATE.md RETRY_LOG.md DECISIONS.md LEARNINGS.md; do
  src="$STATE_TEMPLATES_SRC/$state_file"
  dest=".claude/team-state/$state_file"
  if [ ! -f "$src" ]; then
    echo "❌ 状态模板缺失：$src" >&2
    exit 1
  fi
  if [ -f "$dest" ]; then
    echo "⏭  $dest 已存在，跳过"
  else
    cp "$src" "$dest"
    echo "✅ 已生成 $dest"
  fi
done

echo ""
echo "✅ 初始化完成！"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "现在打开 Claude Code，在这个目录里输入："
echo ""
echo "  使用标准团队开发 你的需求"
echo ""
if [ -n "${TECH_STACK+x}" ]; then
  echo "  技术栈：$TECH_STACK"
  echo "  部署环境：$DEPLOY_ENV"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
