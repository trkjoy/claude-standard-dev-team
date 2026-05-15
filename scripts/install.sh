#!/usr/bin/env bash
# 安装标准 AI 开发团队（Mac / Linux / WSL）
# 支持多平台：Claude Code / Hermes / OpenClaw / Codex CLI / Gemini CLI
# 版本相同则幂等跳过，版本不同则覆盖更新
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_SRC="$REPO_DIR/agents"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
COMMANDS_SRC="$REPO_DIR/.claude/commands"
VERSION_FILE="$REPO_DIR/VERSION"
REPO_VERSION="$(cat "$VERSION_FILE" | tr -d '[:space:]')"

if [ ! -d "$AGENTS_SRC" ]; then
  echo "❌ 找不到 agents 目录：$AGENTS_SRC" >&2
  echo "   请在 claude-standard-dev-team 克隆目录中运行此脚本。" >&2
  exit 1
fi

# ─── 参数解析 ────────────────────────────────────────────────────────────────
# 位置参数：
#   $1 = PLATFORM  (claude / hermes / openclaw / codex / gemini)
#   $2 = KB_MODE   (1=跳过 / 2=合并 / 3=覆盖，默认 1)

PLATFORM="${1:-}"
KB_MODE="${2:-1}"

case "$KB_MODE" in
  1|2|3) ;;
  *) echo "❌ 无效的 KB_MODE：$KB_MODE（仅允许 1/2/3）" >&2; exit 1 ;;
esac

# ─── 平台选择 ─────────────────────────────────────────────────────────────────

if [ -z "$PLATFORM" ]; then
  echo ""
  echo "┌──────────────────────────────────────────────────────────┐"
  echo "│   AI 标准开发团队 v${REPO_VERSION}  ·  安装程序              │"
  echo "└──────────────────────────────────────────────────────────┘"
  echo ""
  echo "请选择目标平台："
  echo ""
  echo "  1) Claude Code  — ~/.claude/agents/        (推荐，多 Agent 并行)"
  echo "  2) Hermes       — ~/.hermes/skills/         (Nous Research)"
  echo "  3) OpenClaw     — ~/.openclaw/skills/       (agentskills.io)"
  echo "  4) Codex CLI    — ~/.codex/AGENTS.md        (OpenAI)"
  echo "  5) Gemini CLI   — ~/.gemini/GEMINI.md       (Google)"
  echo ""
  printf "输入序号 [1-5]，按 Enter 确认（默认 1）："; read -r _choice
  _choice="${_choice:-1}"
  case "$_choice" in
    1) PLATFORM="claude"   ;;
    2) PLATFORM="hermes"   ;;
    3) PLATFORM="openclaw" ;;
    4) PLATFORM="codex"    ;;
    5) PLATFORM="gemini"   ;;
    *) echo "❌ 无效选择，请输入 1-5" >&2; exit 1 ;;
  esac
fi

# ─── 版本文件（每平台独立）────────────────────────────────────────────────────

case "$PLATFORM" in
  claude)   VER_FILE="$HOME/.claude/team-version"         ;;
  hermes)   VER_FILE="$HOME/.hermes/team-version"         ;;
  openclaw) VER_FILE="$HOME/.openclaw/team-version"       ;;
  codex)    VER_FILE="$HOME/.codex/team-version"          ;;
  gemini)   VER_FILE="$HOME/.gemini/team-version"         ;;
  *)        echo "❌ 不支持的平台：$PLATFORM" >&2; exit 1  ;;
esac

INSTALLED_VERSION=""
[ -f "$VER_FILE" ] && INSTALLED_VERSION="$(cat "$VER_FILE" | tr -d '[:space:]')"

# KB_MODE 2/3 时强制重跑知识库处理，不因版本相同而短路
if [ "$REPO_VERSION" = "$INSTALLED_VERSION" ] && [ "$KB_MODE" = "1" ]; then
  echo ""
  echo "✅ [$PLATFORM] 已是最新版本 v$REPO_VERSION，无需重新安装"
  echo ""
  exit 0
fi

echo ""
if [ -n "$INSTALLED_VERSION" ]; then
  echo "🔄 [$PLATFORM] 版本更新：v$INSTALLED_VERSION → v$REPO_VERSION"
else
  echo "📦 正在安装标准 AI 开发团队 v$REPO_VERSION → $PLATFORM..."
fi

# 输出 KB_MODE 提示
case "$KB_MODE" in
  1) echo "📚 知识库模式：跳过（已存在则保留历史，默认）" ;;
  2) echo "📚 知识库模式：合并（新内容追加到历史末尾）"   ;;
  3) echo "📚 知识库模式：覆盖（用模板完全替换已有文件）" ;;
esac
echo ""

# ─── 工具函数 ─────────────────────────────────────────────────────────────────

# 从 agent .md 文件提取 frontmatter 中的 name 字段
_get_name() {
  awk 'BEGIN{n=0} /^---/{n++; next} n==1 && /^name:/{sub(/^name:[[:space:]]*/,""); print; exit}' "$1"
}

# 从 frontmatter 提取 description（支持单行和 YAML block scalar "|"）
_get_description() {
  awk '
    BEGIN { n=0; block=0; done=0 }
    /^---/   { n++; next }
    n==1 && /^description:[[:space:]]*\|/ { block=1; next }
    n==1 && block && /^[[:space:]]/ && !done {
      sub(/^[[:space:]]+/, "")
      if ($0 != "") { print; done=1 }
      next
    }
    n==1 && block && !/^[[:space:]]/ { block=0 }
    n==1 && !block && /^description:/ {
      sub(/^description:[[:space:]]*/,"")
      print; exit
    }
  ' "$1"
}

# 提取 frontmatter 之后的正文（只跳过前两个 ---，正文内的 --- 原样保留）
_get_body() {
  awk 'BEGIN{n=0} n<2 && /^---/{n++; next} n>=2{print}' "$1"
}

_write_version() {
  mkdir -p "$(dirname "$VER_FILE")"
  printf '%s' "$REPO_VERSION" > "$VER_FILE"
}

# 提取模板中 "## 记录示例" 之后的整段（含该标题）
_extract_example_section() {
  awk '
    BEGIN { found=0 }
    /^##[[:space:]]+记录示例[[:space:]]*$/ { found=1 }
    found { print }
  ' "$1"
}

# 提取一段 markdown 中所有 `^## 标题`（去掉 "##" 和首尾空白），跳过 "## 记录示例"
# 用法： _extract_titles <file>
_extract_titles() {
  awk '
    /^##[[:space:]]+/ {
      line=$0
      sub(/^##[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      if (line != "记录示例") print line
    }
  ' "$1"
}

# 合并：将模板示例条目追加到已有文件末尾（按标题去重）
_merge_pattern_file() {
  local src="$1"
  local dest="$2"
  local base
  base="$(basename "$dest")"

  local tmp_section tmp_template_titles tmp_existing_titles
  tmp_section="$(mktemp)"
  tmp_template_titles="$(mktemp)"
  tmp_existing_titles="$(mktemp)"
  trap 'rm -f "$tmp_section" "$tmp_template_titles" "$tmp_existing_titles"' RETURN

  _extract_example_section "$src" > "$tmp_section"

  if [ ! -s "$tmp_section" ]; then
    echo "  ⚠  合并跳过（模板无 ## 记录示例 章节）：$base"
    return
  fi

  _extract_titles "$tmp_section" > "$tmp_template_titles"
  _extract_titles "$dest"        > "$tmp_existing_titles"

  # 计算模板中存在但目标中不存在的标题数量
  local new_count
  new_count="$(grep -Fxv -f "$tmp_existing_titles" "$tmp_template_titles" 2>/dev/null | grep -c . || true)"

  if [ -z "$new_count" ] || [ "$new_count" -eq 0 ]; then
    echo "  ⚠  合并跳过（条目已存在）：$base"
    return
  fi

  # 在追加前确保目标文件末尾有空行分隔
  if [ -s "$dest" ]; then
    # 若目标文件末尾不是换行，先补一个
    [ -z "$(tail -c1 "$dest")" ] || printf '\n' >> "$dest"
    printf '\n' >> "$dest"
  fi
  cat "$tmp_section" >> "$dest"
  # 确保文件以换行结束
  [ -z "$(tail -c1 "$dest")" ] || printf '\n' >> "$dest"

  echo "  ✅ 合并：$base（新增 $new_count 条标题）"
}

# ─── Claude Code 安装 ────────────────────────────────────────────────────────

install_claude() {
  local AGENTS_DEST="$HOME/.claude/agents"
  local MEMORY_DEST="$HOME/.claude/team-memory/patterns"
  local COMMANDS_DEST="$HOME/.claude/commands"

  # 1. Agent 文件
  mkdir -p "$AGENTS_DEST"
  cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
  local cnt
  cnt="$(find "$AGENTS_SRC" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
  echo "✅ 已安装 $cnt 个 agent -> $AGENTS_DEST"

  # 2. 用户级知识库（行为由 KB_MODE 决定）
  mkdir -p "$MEMORY_DEST"
  for p in backend frontend contract qa security deployment; do
    local src="$TEMPLATES_SRC/${p}-patterns.md"
    local dest="$MEMORY_DEST/${p}-patterns.md"
    if [ ! -f "$src" ]; then echo "❌ 模板文件缺失：$src" >&2; exit 1; fi

    case "$KB_MODE" in
      1)
        if [ -f "$dest" ]; then
          echo "  ⏭  跳过（已存在）：${p}-patterns.md"
        else
          cp "$src" "$dest"
          echo "  ✅ 初始化：${p}-patterns.md"
        fi
        ;;
      2)
        if [ -f "$dest" ]; then
          _merge_pattern_file "$src" "$dest"
        else
          cp "$src" "$dest"
          echo "  ✅ 初始化：${p}-patterns.md"
        fi
        ;;
      3)
        cp "$src" "$dest"
        echo "  ✅ 覆盖：${p}-patterns.md"
        ;;
    esac
  done

  # 3. 全局命令
  if [ -d "$COMMANDS_SRC" ]; then
    mkdir -p "$COMMANDS_DEST"
    cp "$COMMANDS_SRC/team-install.md" "$COMMANDS_DEST/"
    cp "$COMMANDS_SRC/team-init.md"    "$COMMANDS_DEST/"
    echo "✅ 已注册全局命令 -> $COMMANDS_DEST"
  else
    echo "  ⚠  跳过命令注册（.claude/commands/ 目录不存在）"
  fi

  _write_version

  echo ""
  echo "✅ 安装完成！版本 v$REPO_VERSION (Claude Code)"
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
}

# ─── Hermes / OpenClaw Skills 安装（共用格式逻辑）────────────────────────────

_install_skills_platform() {
  local platform="$1"
  local skills_base="$2"
  local team_dir="$skills_base/standard-dev-team"

  mkdir -p "$team_dir"
  echo "  目标目录：$team_dir"
  echo ""

  local count=0
  for f in "$AGENTS_SRC"/*.md; do
    local name desc body escaped_desc
    name="$(_get_name "$f")"
    desc="$(_get_description "$f")"
    body="$(_get_body "$f")"
    # 对 YAML inline 字符串转义双引号
    escaped_desc="${desc//\"/\\\"}"

    local skill_dir="$team_dir/$name"
    mkdir -p "$skill_dir"
    local skill_file="$skill_dir/SKILL.md"

    {
      printf -- '---\n'
      printf 'name: %s\n' "$name"
      printf 'description: "%s"\n' "$escaped_desc"
      printf 'version: %s\n' "$REPO_VERSION"
      printf 'metadata:\n'
      printf '  hermes:\n'
      printf '    tags: [development, ai-team, standard-dev-team]\n'
      printf '    category: development\n'
      printf -- '---\n\n'
      printf '%s\n' "$body"
    } > "$skill_file"

    echo "  ✅ $name"
    count=$((count + 1))
  done

  _write_version

  echo ""
  echo "✅ 已安装 $count 个 skill -> $team_dir"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "使用方法（${platform} CLI）："
  echo ""
  echo "  1. 启动 ${platform}："
  echo "       $platform"
  echo ""
  echo "  2. 激活总指挥，开始开发任务："
  echo "       /orchestrator"
  echo "       → 然后描述你的需求，例如："
  echo "         使用标准团队开发 一个待办事项 Web App"
  echo ""
  echo "  3. 也可直接调用单个角色："
  echo "       /product-manager      产品需求分析"
  echo "       /software-architect   技术架构设计"
  echo "       /code-reviewer        代码评审"
  echo "       /security-engineer    安全审查"
  echo ""
  echo "  4. 查看所有已安装 skill："
  echo "       /skills"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

install_hermes()   { _install_skills_platform "hermes"   "$HOME/.hermes/skills";   }
install_openclaw() { _install_skills_platform "openclaw" "$HOME/.openclaw/skills"; }

# ─── 生成合并团队文档（Codex / Gemini 共用）──────────────────────────────────

_gen_team_doc() {
  local out_file="$1"
  local platform="$2"

  mkdir -p "$(dirname "$out_file")"

  {
    printf '# 标准 AI 开发团队 (Standard AI Development Team)\n\n'
    printf '> 版本：%s  |  生成工具：claude-standard-dev-team\n' "$REPO_VERSION"
    printf '> 请勿手动编辑，重新运行 install.sh 可升级。\n\n'
    printf -- '---\n\n'
    printf '## 使用方式\n\n'
    printf '当用户要求开发软件时，以 **orchestrator（总指挥）** 角色协调整个团队，\n'
    printf '按以下协作链路推进：需求分析 → 架构设计 → 实现 → QA → 安全 → 上线。\n\n'
    printf -- '---\n\n'
    printf '## 团队成员\n\n'
    printf '| 角色 | 职责摘要 |\n'
    printf '|------|----------|\n'

    for f in "$AGENTS_SRC"/*.md; do
      local name desc
      name="$(_get_name "$f")"
      desc="$(_get_description "$f")"
      printf '| `%s` | %s |\n' "$name" "$desc"
    done

    printf '\n---\n\n'
    printf '## 角色详细定义\n\n'

    for f in "$AGENTS_SRC"/*.md; do
      local name desc body
      name="$(_get_name "$f")"
      desc="$(_get_description "$f")"
      body="$(_get_body "$f")"
      printf '### %s\n\n' "$name"
      printf '> %s\n\n' "$desc"
      printf '%s\n\n' "$body"
      printf -- '---\n\n'
    done
  } > "$out_file"
}

install_codex() {
  local out_file="$HOME/.codex/AGENTS.md"
  _gen_team_doc "$out_file" "codex"
  _write_version

  echo "✅ 已生成团队定义 -> $out_file"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "使用方法（Codex CLI）："
  echo ""
  echo "  Codex CLI 会自动加载 ~/.codex/AGENTS.md 作为全局指令。"
  echo ""
  echo "  命令行直接调用："
  echo "    codex '以 orchestrator 角色，使用标准团队开发 <你的需求>'"
  echo ""
  echo "  交互模式中说："
  echo "    请以 orchestrator 角色，带领团队开发 <你的需求>"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

install_gemini() {
  local out_file="$HOME/.gemini/GEMINI.md"
  _gen_team_doc "$out_file" "gemini"
  _write_version

  echo "✅ 已生成团队定义 -> $out_file"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "使用方法（Gemini CLI）："
  echo ""
  echo "  Gemini CLI 会自动加载 ~/.gemini/GEMINI.md 作为全局指令。"
  echo ""
  echo "  命令行直接调用："
  echo "    gemini '以 orchestrator 角色，使用标准团队开发 <你的需求>'"
  echo ""
  echo "  交互模式中说："
  echo "    请以 orchestrator 角色，带领团队开发 <你的需求>"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

# ─── 主流程 ──────────────────────────────────────────────────────────────────

echo "🎯 目标平台：$PLATFORM"
echo ""

case "$PLATFORM" in
  claude)   install_claude   ;;
  hermes)   install_hermes   ;;
  openclaw) install_openclaw ;;
  codex)    install_codex    ;;
  gemini)   install_gemini   ;;
esac
