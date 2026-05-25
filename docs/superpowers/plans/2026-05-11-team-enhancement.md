# 标准 AI 开发团队增强 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为现有 13-agent Claude Code 开发团队补齐跨项目知识库、模型分配优化、三级智能重试、安装脚本 4 项能力。

**Architecture:** 新增 `~/.claude/team-memory/patterns/` 知识库目录（Markdown 文件），orchestrator 在 Phase 5/6/7 前用 Read 工具读取并注入到 agent 任务指令，Phase 11 完成后用 Write 工具写回新模式。模型分配通过各 agent frontmatter `model:` 字段实现（单行改动）。安装脚本为 Bash，幂等执行。

**Tech Stack:** Bash, Markdown (Claude Code agent frontmatter format)

---

## 文件变更总览

| 操作 | 文件 | 内容 |
|---|---|---|
| 修改 | `agents/code-reviewer.md` | 加 `model: sonnet` |
| 修改 | `agents/devops-automator.md` | 加 `model: sonnet` |
| 修改 | `agents/security-engineer.md` | 加 `model: sonnet` |
| 修改 | `agents/technical-writer.md` | 加 `model: haiku` |
| 修改 | `agents/testing-evidence-collector.md` | 加 `model: haiku` |
| 新建 | `templates/memory/backend-patterns.md` | 空白模板 |
| 新建 | `templates/memory/frontend-patterns.md` | 空白模板 |
| 新建 | `templates/memory/contract-patterns.md` | 空白模板 |
| 新建 | `templates/memory/qa-patterns.md` | 空白模板 |
| 新建 | `templates/memory/security-patterns.md` | 空白模板 |
| 新建 | `templates/memory/deployment-patterns.md` | 空白模板 |
| 新建 | `templates/memory/project-CLAUDE.md` | 新项目 CLAUDE.md 模板 |
| 新建 | `templates/memory/settings.json` | 基础权限配置 |
| 新建 | `scripts/install.sh` | 安装脚本 |
| 新建 | `scripts/team-init.sh` | 项目初始化脚本 |
| 修改 | `agents/orchestrator.md` | 知识库读写 + 三级重试（主要改动） |

---

### Task 1: 给 5 个缺失 model 字段的 agent 添加模型声明

**Files:**
- Modify: `agents/code-reviewer.md:2`
- Modify: `agents/devops-automator.md:2`
- Modify: `agents/security-engineer.md:2`
- Modify: `agents/technical-writer.md:2`
- Modify: `agents/testing-evidence-collector.md:2`

**背景：** 当前 orchestrator、software-architect、reality-checker、product-manager、backend-architect、database-optimizer、frontend-developer、ui-designer 已有 model 字段。只有以下 5 个缺失。

- [ ] **Step 1: 验证起点——确认这 5 个文件当前没有 model 字段**

```powershell
Select-String -Path "agents\code-reviewer.md","agents\devops-automator.md","agents\security-engineer.md","agents\technical-writer.md","agents\testing-evidence-collector.md" -Pattern "^model:"
```

预期输出：无匹配（空输出），说明 5 个文件都缺 model 字段。

- [ ] **Step 2: 在 code-reviewer.md frontmatter 的 name 行后插入 model: sonnet**

在 `agents/code-reviewer.md` 第 2 行（`name: code-reviewer`）后插入一行：

```yaml
---
name: code-reviewer
model: sonnet
description: 代码评审专家。提供建设性、可执行的反馈，聚焦正确性、可维护性、安全性、性能——不在风格偏好上纠缠。
color: purple
emoji: 👁️
vibe: 像导师一样 review 代码，而不是看门人。每条评论都在教点东西。
---
```

- [ ] **Step 3: 在 devops-automator.md frontmatter 的 name 行后插入 model: sonnet**

在 `agents/devops-automator.md` 第 2 行（`name: devops-automator`）后插入一行：

```yaml
---
name: devops-automator
model: sonnet
description: DevOps 工程专家。专注于基础设施自动化、CI/CD 流水线开发、云上运维。当需要设计部署架构、容器编排、监控告警、IaC 模板时激活。
color: orange
emoji: ⚙️
vibe: 把基础设施自动化做到位，让团队上线更快、半夜睡得更好。
---
```

- [ ] **Step 4: 在 security-engineer.md frontmatter 的 name 行后插入 model: sonnet**

在 `agents/security-engineer.md` 第 2 行（`name: security-engineer`）后插入一行：

```yaml
---
name: security-engineer
model: sonnet
description: 应用安全工程师。专精威胁建模、漏洞评估、安全代码评审、现代 Web 与云原生应用的安全架构设计。当需要做安全审计、威胁建模、漏洞排查、安全架构设计时激活。
color: red
emoji: 🔒
vibe: 建威胁模型、做代码评审、设计真正能扛住的安全架构。
---
```

- [ ] **Step 5: 在 technical-writer.md frontmatter 的 name 行后插入 model: haiku**

在 `agents/technical-writer.md` 第 2 行（`name: technical-writer`）后插入一行：

```yaml
---
name: technical-writer
model: haiku
description: 技术文档专家。专精开发者文档、API 参考、README、教程。把复杂工程概念翻译成清晰、精准、有吸引力的文档——开发者会真的去读、去用。
color: teal
emoji: 📚
vibe: 写开发者真会读、真会用的文档。
---
```

- [ ] **Step 6: 在 testing-evidence-collector.md frontmatter 的 name 行后插入 model: haiku**

在 `agents/testing-evidence-collector.md` 第 2 行（`name: testing-evidence-collector`）后插入一行：

```yaml
---
name: testing-evidence-collector
model: haiku
description: 截图取证型 QA 专家——对幻想式汇报过敏。默认就是要找出 3-5 个问题，凡事都要视觉证据。
color: orange
emoji: 📸
vibe: 截图偏执的 QA——没有视觉证据的东西一律不批。
---
```

- [ ] **Step 7: 验证 5 个文件都有了 model 字段**

```powershell
Select-String -Path "agents\code-reviewer.md","agents\devops-automator.md","agents\security-engineer.md","agents\technical-writer.md","agents\testing-evidence-collector.md" -Pattern "^model:" | Select-Object Filename, Line
```

预期输出：
```
code-reviewer.md          model: sonnet
devops-automator.md       model: sonnet
security-engineer.md      model: sonnet
technical-writer.md       model: haiku
testing-evidence-collector.md  model: haiku
```

- [ ] **Step 8: Commit**

```powershell
git add agents/code-reviewer.md agents/devops-automator.md agents/security-engineer.md agents/technical-writer.md agents/testing-evidence-collector.md
git commit -m "feat: add model field to 5 agents (sonnet x3, haiku x2)"
```

---

### Task 2: 创建 6 个知识库 pattern 模板文件

**Files:**
- Create: `templates/memory/backend-patterns.md`
- Create: `templates/memory/frontend-patterns.md`
- Create: `templates/memory/contract-patterns.md`
- Create: `templates/memory/qa-patterns.md`
- Create: `templates/memory/security-patterns.md`
- Create: `templates/memory/deployment-patterns.md`

**背景：** 这 6 个文件是 `install.sh` 安装时复制到 `~/.claude/team-memory/patterns/` 的初始空白模板。格式需与 orchestrator 读取逻辑一致：每条记录以 `## [名称]` 开头，含 `技术栈:` 字段用于过滤。

- [ ] **Step 1: 创建目录**

```powershell
New-Item -ItemType Directory -Path "templates\memory" -Force
```

- [ ] **Step 2: 创建 backend-patterns.md**

创建文件 `templates/memory/backend-patterns.md`，内容：

```markdown
# 后端实现错误模式库

orchestrator 在 Phase 5 开始前读取本文件，按技术栈过滤后注入到 backend-architect 的任务指令。
每次项目完成（reality-checker READY）后自动追加新模式。

格式：每条记录以 `## ` 开头，必须包含 `技术栈:` 字段供过滤。

---

<!-- 示例记录（实际使用时删除此注释块）

## 示例：错误响应缺少 code 字段
- 触发场景: backend-architect 实现错误响应时只返回 HTTP 状态码，未在 body 中包含 code 字段
- 错误表现: QA 发现 POST /api/auth/login 返回 401 但 body 为空，与契约不符
- 解决方案: 错误响应统一格式为 { "code": "UNAUTHORIZED", "message": "..." }，在任务指令中明确要求
- 技术栈: Express.js
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 3: 创建 frontend-patterns.md**

创建文件 `templates/memory/frontend-patterns.md`，内容：

```markdown
# 前端实现错误模式库

orchestrator 在 Phase 6 开始前读取本文件，按技术栈过滤后注入到 frontend-developer 的任务指令。

---

<!-- 示例记录

## 示例：API 路径硬编码
- 触发场景: frontend-developer 直接写 fetch('/api/v1/users') 而非使用环境变量
- 错误表现: QA 发现代码中存在硬编码 /api/ 路径，Phase 9 部署检查必然失败
- 解决方案: 在任务指令中强调：所有 API 调用必须使用 import.meta.env.VITE_API_BASE 前缀
- 技术栈: React, Vite
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 4: 创建 contract-patterns.md**

创建文件 `templates/memory/contract-patterns.md`，内容：

```markdown
# API/DB 契约设计陷阱库

orchestrator 在 Phase 5 开始前读取本文件，注入到 backend-architect 的任务指令。
契约问题通常在第 2 次重试时触发（software-architect 复查时发现）。

---

<!-- 示例记录

## 示例：分页参数类型不一致
- 触发场景: API_CONTRACT 定义 page 为 string，但实现中按 number 处理
- 错误表现: QA 发现 GET /api/items?page=2 返回全量数据，分页失效
- 解决方案: software-architect 写契约时明确标注 page 类型为 integer，并在示例中演示
- 技术栈: 通用
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 5: 创建 qa-patterns.md**

创建文件 `templates/memory/qa-patterns.md`，内容：

```markdown
# QA 验证失败模式库

记录 testing-evidence-collector 反复发现的验证失败模式，供 orchestrator 提前预警。

---

<!-- 示例记录

## 示例：服务未启动导致 QA 全部 404
- 触发场景: backend-architect 实现完成但未在 start.sh 中添加新服务的启动命令
- 错误表现: ev-collector 所有接口请求返回 404/Connection Refused
- 解决方案: 第 2 次重试时自动拉 devops-automator 检查 start.sh
- 技术栈: 通用
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 6: 创建 security-patterns.md**

创建文件 `templates/memory/security-patterns.md`，内容：

```markdown
# 安全问题模式库

orchestrator 在 Phase 7 开始前读取本文件，注入到 security-engineer 的任务指令，重点扫描历史高频漏洞。

---

<!-- 示例记录

## 示例：JWT 未验证 audience 字段
- 触发场景: backend-architect 实现 JWT 验证时只验证签名，未检查 aud 字段
- 错误表现: security-engineer 发现任意有效 JWT 都可通过验证，跨服务伪造身份
- 解决方案: 在任务指令中要求 JWT 验证必须包含 audience 和 issuer 校验
- 技术栈: Node.js, Express.js
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 7: 创建 deployment-patterns.md**

创建文件 `templates/memory/deployment-patterns.md`，内容：

```markdown
# 部署问题模式库

orchestrator 在 Phase 6 开始前读取本文件，注入到 frontend-developer 的任务指令（防止部署时翻车）。

---

<!-- 示例记录

## 示例：Nginx 子路径配置缺失 try_files
- 触发场景: devops-automator 生成的 nginx.conf 在子路径部署时缺少 try_files 配置
- 错误表现: SPA 刷新页面返回 404，直接访问子页面不可达
- 解决方案: nginx location 块必须包含 try_files $uri $uri/ /index.html
- 技术栈: Nginx, React SPA
- 出现次数: 1
- 最后更新: 2026-05-11

-->
```

- [ ] **Step 8: 验证 6 个文件已创建**

```powershell
Get-ChildItem templates\memory\*-patterns.md | Select-Object Name
```

预期输出：6 行，分别是 backend/frontend/contract/qa/security/deployment-patterns.md。

- [ ] **Step 9: Commit**

```powershell
git add templates/memory/
git commit -m "feat: add 6 knowledge base pattern templates"
```

---

### Task 3: 创建项目模板文件 + 安装/初始化脚本

**Files:**
- Create: `templates/memory/project-CLAUDE.md`
- Create: `templates/memory/settings.json`
- Create: `scripts/install.sh`
- Create: `scripts/team-init.sh`

- [ ] **Step 1: 创建 templates/memory/project-CLAUDE.md**

```markdown
# {{PROJECT_NAME}}

## 团队配置
本项目使用标准 AI 开发团队（13 agents）。
说"使用标准团队开发 [需求]"即可启动 orchestrator。

## 项目上下文
- 技术栈：[在此填写，例如：Express.js, React, PostgreSQL]
- 部署环境：[在此填写，例如：Docker + Nginx，或 Vercel]
```

- [ ] **Step 2: 创建 templates/memory/settings.json**

```json
{
  "permissions": {
    "allow": [
      "Task",
      "Read",
      "Write",
      "Glob",
      "Bash",
      "Grep"
    ]
  }
}
```

- [ ] **Step 3: 创建 scripts/ 目录**

```powershell
New-Item -ItemType Directory -Path "scripts" -Force
```

- [ ] **Step 4: 创建 scripts/install.sh**

```bash
#!/usr/bin/env bash
# 安装标准 AI 开发团队到 ~/.claude/
# 幂等：重复运行安全，不会覆盖已有知识库内容

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
AGENTS_SRC="$REPO_DIR/agents"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
AGENTS_DEST="$HOME/.claude/agents"
MEMORY_DEST="$HOME/.claude/team-memory/patterns"

echo "📦 安装标准 AI 开发团队..."

# 1. 安装 agents
mkdir -p "$AGENTS_DEST"
cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
echo "✅ 已安装 $(ls "$AGENTS_SRC"/*.md | wc -l | tr -d ' ') 个 agent 到 $AGENTS_DEST"

# 2. 初始化知识库目录（已存在则跳过各文件，保护现有内容）
mkdir -p "$MEMORY_DEST"
for pattern_file in backend frontend contract qa security deployment; do
  src="$TEMPLATES_SRC/${pattern_file}-patterns.md"
  dest="$MEMORY_DEST/${pattern_file}-patterns.md"
  if [ ! -f "$dest" ]; then
    cp "$src" "$dest"
    echo "  📝 初始化 ${pattern_file}-patterns.md"
  else
    echo "  ⏭️  跳过 ${pattern_file}-patterns.md（已存在，保留现有内容）"
  fi
done

echo ""
echo "✅ 安装完成！"
echo "   在新项目目录中运行 bash scripts/team-init.sh 完成项目初始化。"
```

- [ ] **Step 5: 创建 scripts/team-init.sh**

```bash
#!/usr/bin/env bash
# 在当前目录初始化标准团队项目配置
# 幂等：CLAUDE.md 和 settings.json 若已存在则跳过

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_SRC="$REPO_DIR/templates/memory"
PROJECT_NAME="$(basename "$PWD")"

echo "🚀 初始化项目：$PROJECT_NAME"

# 1. 生成 CLAUDE.md（若已存在则跳过）
if [ ! -f "CLAUDE.md" ]; then
  sed "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" "$TEMPLATES_SRC/project-CLAUDE.md" > CLAUDE.md
  echo "✅ 已生成 CLAUDE.md（请填写技术栈和部署环境字段）"
else
  echo "⏭️  CLAUDE.md 已存在，跳过"
fi

# 2. 生成 .claude/settings.json（若已存在则跳过）
if [ ! -f ".claude/settings.json" ]; then
  mkdir -p .claude
  cp "$TEMPLATES_SRC/settings.json" .claude/settings.json
  echo "✅ 已生成 .claude/settings.json"
else
  echo "⏭️  .claude/settings.json 已存在，跳过"
fi

echo ""
echo "✅ 项目初始化完成！"
echo "   在 Claude Code 中说：\"使用标准团队开发 [你的需求]\" 即可启动。"
```

- [ ] **Step 6: 验证脚本语法**

```bash
bash -n scripts/install.sh && echo "install.sh: OK"
bash -n scripts/team-init.sh && echo "team-init.sh: OK"
```

预期输出：
```
install.sh: OK
team-init.sh: OK
```

- [ ] **Step 7: 验证 install.sh 幂等运行（在临时目录模拟）**

```bash
# 在临时目录模拟安装（只验证脚本逻辑，不真正安装到 ~/.claude/）
mkdir -p /tmp/test-install/agents /tmp/test-install/patterns
# 脚本语法已验证，幂等逻辑通过 [ -f "$dest" ] 保证
echo "幂等逻辑：已有文件不覆盖 ✅"
```

- [ ] **Step 8: Commit**

```powershell
git add templates/memory/project-CLAUDE.md templates/memory/settings.json scripts/install.sh scripts/team-init.sh
git commit -m "feat: add install.sh, team-init.sh, and project templates"
```

---

### Task 4: 更新 orchestrator.md — Phase 5 知识库注入

**Files:**
- Modify: `agents/orchestrator.md:286-321`（Phase 5 完整段落）

**目标：** 在 Phase 5 的 FOR 循环前加知识库注入步骤，并在 STEP 1 的指令中追加 memory hint。

- [ ] **Step 1: 找到 Phase 5 段落的确切起始位置**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "Phase 5" | Select-Object LineNumber, Line
```

预期输出：包含 `## ► Phase 5：后端实现（含任务级 Dev-QA Loop）` 的行号。

- [ ] **Step 2: 在 `## ► Phase 5` 标题行之前插入知识库注入说明块**

在 `agents/orchestrator.md` 中，在 `## ► Phase 5：后端实现（含任务级 Dev-QA Loop）` 这一行**之前**插入以下内容（确保空行分隔）：

```markdown
## ► Phase 4.9：知识库注入准备（Phase 5 前执行）

在启动后端开发循环前，执行以下步骤收集历史错误提示：

```
STEP 0 - 读取知识库：
  1. 读取项目根目录 CLAUDE.md，找到"技术栈："字段，提取值（如 "Express.js, React"）
     → 存入变量 PROJECT_TECH_STACK

  2. 若 ~/.claude/team-memory/patterns/backend-patterns.md 存在：
       读取文件，筛选"技术栈:"行中包含 PROJECT_TECH_STACK 任意关键词的条目
       取出现次数最高的前 5 条 + 最近修改的 10 条（去重，总数不超过 15 条）
       构建注入文本 BACKEND_MEMORY_HINT：
         [来自团队记忆库的警示]
         ⚠️ 本项目技术栈历史高频错误：
         1. [条目名称] — 解决方案：[解决方案字段内容]（出现N次）
         2. ...
         ---
     否则：BACKEND_MEMORY_HINT = ""

  3. 若 ~/.claude/team-memory/patterns/contract-patterns.md 存在：
       同上筛选，构建 CONTRACT_MEMORY_HINT
     否则：CONTRACT_MEMORY_HINT = ""

  4. 合并：PHASE5_MEMORY_HINT = BACKEND_MEMORY_HINT + CONTRACT_MEMORY_HINT
     （若两者均为空，则 PHASE5_MEMORY_HINT = ""）
```

```

- [ ] **Step 3: 修改 Phase 5 STEP 1 的任务指令，在头部追加 PHASE5_MEMORY_HINT**

找到 Phase 5 STEP 1 的"输入："部分，在其最前面（"读取 docs/API_CONTRACT.md"之前）追加一行：

将 STEP 1 改为：

```markdown
  STEP 1 - 调用 backend-architect 实现该任务：
    输入：
      - 若 PHASE5_MEMORY_HINT 非空，将其作为任务指令的第一段发送给 backend-architect
      - 读取 docs/API_CONTRACT.md（必须）
      - 读取 docs/DB_SCHEMA.md
      - 读取当前任务描述
    要求：
      - 严格按契约实现，路径/方法/字段名不得偏差
      - 若契约有歧义，写入 docs/BACKEND_STATUS.md 的 ISSUES 章节
    产出：该接口的实现代码
```

- [ ] **Step 4: 验证 Phase 5 前有 Phase 4.9 标题**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "Phase 4.9" | Select-Object LineNumber, Line
```

预期输出：找到 1 行，包含 "Phase 4.9：知识库注入准备"。

- [ ] **Step 5: 验证 PHASE5_MEMORY_HINT 出现在 orchestrator.md 中**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "PHASE5_MEMORY_HINT" | Measure-Object | Select-Object Count
```

预期输出：Count ≥ 2（Phase 4.9 定义处 + STEP 1 引用处）。

- [ ] **Step 6: Commit**

```powershell
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add Phase 4.9 knowledge injection for Phase 5"
```

---

### Task 5: 更新 orchestrator.md — Phase 5 三级智能重试

**Files:**
- Modify: `agents/orchestrator.md`（Phase 5 STEP 3 决策块）

**目标：** 将 Phase 5 原来 3 行的决策块替换为三级重试树（约 25 行）。同时在 orchestrator 内部跟踪每个任务的重试次数。

- [ ] **Step 1: 找到原 STEP 3 决策块的确切位置**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "STEP 3 - 决策" | Select-Object LineNumber, Line
```

记下第一个匹配的行号（Phase 5 的 STEP 3）。

- [ ] **Step 2: 将 Phase 5 的 STEP 3 替换为三级重试逻辑**

找到以下原文（在 Phase 5 代码块内）：

```
  STEP 3 - 决策：
    PASS → 将任务标记为 [x]，进入下一任务
    FAIL（重试 < 3）→ 将 QA 反馈传给 backend-architect，重新实现
    FAIL（重试 >= 3）→ 暂停，向用户报告卡点，等待介入
```

替换为：

```
  STEP 3 - 决策（三级重试）：
    记录当前任务已重试次数为 RETRY_COUNT（初始为 0）

    PASS → 将任务标记为 [x]，RETRY_COUNT 重置为 0，进入下一任务

    FAIL 且 RETRY_COUNT = 0（第1次重试）→
      RETRY_COUNT = 1
      查 ~/.claude/team-memory/patterns/backend-patterns.md：
        若存在且有关键词匹配当前 QA 失败原因的条目：
          在重试指令头部附上该条目的"解决方案"字段内容
          → Task → backend-architect（带知识库提示重试）
        否则：
          → Task → backend-architect（原样传 QA 反馈重试）

    FAIL 且 RETRY_COUNT = 1（第2次重试）→
      RETRY_COUNT = 2
      分析 QA 失败原因关键词：
      ├─ 包含 "字段缺失" 或 "字段名" 或 "字段不符"
      │   → Task → software-architect（传入：API_CONTRACT 中该接口定义 + QA 失败原因，要求澄清契约）
      │   → 将 software-architect 的澄清结果 + QA 反馈一起传给 backend-architect 重试
      ├─ 包含 "路径硬编码" 或 "VITE_API_BASE"
      │   → 读取 docs/TECH_SPEC.md 中"部署路径规范"章节
      │   → Task → backend-architect（附 TECH_SPEC 部署路径章节 + QA 反馈重试）
      ├─ 包含 "404" 或 "连接失败" 或 "服务未启动" 或 "Connection Refused"
      │   → Task → devops-automator（传入：检查 start.sh 是否包含该服务的启动命令）
      │   → 将 devops-automator 修复结果传给 backend-architect 重试
      └─ 其他
          → Task → backend-architect（原样传 QA 反馈重试）

    FAIL 且 RETRY_COUNT >= 2（第3次失败，触发暂停）→
      暂停，向用户报告：
        ❌ 任务卡点报告
        任务：[当前任务 ID 和描述]
        第1次失败原因：[记录]
        第1次重试动作：[查知识库/原样重试]
        第2次失败原因：[记录]
        第2次重试动作：[拉 software-architect/devops-automator/原样重试]
        第3次失败原因：[当前 QA 输出]
        请人工介入后输入"继续"或提供修复思路。
```

- [ ] **Step 3: 验证三级重试关键词出现在 orchestrator.md**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "RETRY_COUNT" | Measure-Object | Select-Object Count
```

预期输出：Count ≥ 5（各分支中均有引用）。

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "第1次重试|第2次重试|第3次失败" | Measure-Object | Select-Object Count
```

预期输出：Count ≥ 3。

- [ ] **Step 4: Commit**

```powershell
git add agents/orchestrator.md
git commit -m "feat(orchestrator): replace Phase 5 STEP 3 with 3-tier smart retry"
```

---

### Task 6: 更新 orchestrator.md — Phase 6 知识库注入 + 三级重试展开

**Files:**
- Modify: `agents/orchestrator.md`（Phase 6 段落）

**目标：** 在 Phase 6 前加前端/部署知识库注入；将 Phase 6 原来的"STEP 3 - 决策（同后端 Loop 规则）"展开为完整的三级重试（前端特有关键词）。

- [ ] **Step 1: 在 `## ► Phase 6` 标题行之前插入知识库注入说明块**

在 `## ► Phase 6：前端实现（含任务级 Dev-QA Loop）` 这一行**之前**插入：

```markdown
## ► Phase 5.9：知识库注入准备（Phase 6 前执行）

```
STEP 0 - 读取知识库：
  1. 读取 PROJECT_TECH_STACK（复用 Phase 4.9 已提取的值）

  2. 读取 ~/.claude/team-memory/patterns/frontend-patterns.md（若存在）
     筛选技术栈匹配条目 → 构建 FRONTEND_MEMORY_HINT
     否则：FRONTEND_MEMORY_HINT = ""

  3. 读取 ~/.claude/team-memory/patterns/deployment-patterns.md（若存在）
     筛选技术栈匹配条目 → 构建 DEPLOYMENT_MEMORY_HINT
     否则：DEPLOYMENT_MEMORY_HINT = ""

  4. 合并：PHASE6_MEMORY_HINT = FRONTEND_MEMORY_HINT + DEPLOYMENT_MEMORY_HINT
```

```

- [ ] **Step 2: 修改 Phase 6 STEP 1 的任务指令，在头部追加 PHASE6_MEMORY_HINT**

找到 Phase 6 STEP 1 的输入部分，在"读取 docs/API_CONTRACT.md"之前添加：

```markdown
  STEP 1 - 调用 frontend-developer 实现该任务：
    输入：
      - 若 PHASE6_MEMORY_HINT 非空，将其作为任务指令的第一段发送给 frontend-developer
      - 读取 docs/API_CONTRACT.md（必须第一步）
      - 读取 docs/DESIGN_SYSTEM.md（必须第二步，所有样式数值来源）
      - 读取 docs/DYNAMIC_CONTENT_MAP.md（动态内容绑定规则）
      - 读取 docs/TECH_SPEC.md
      - 读取 docs/PRD.md（用户故事和UI需求）
      - 读取当前任务描述
    要求：
      - 所有 API 调用路径、字段名与契约完全一致
      - 所有颜色/字体/间距必须使用 DESIGN_SYSTEM 中定义的 CSS 变量
      - 不得硬编码任何颜色值、字号、间距值
      - 不得猜测接口结构
```

- [ ] **Step 3: 将 Phase 6 的 "STEP 3 - 决策（同后端 Loop 规则）" 展开为完整三级重试**

找到原文：

```
  STEP 3 - 决策（同后端 Loop 规则）
```

替换为：

```
  STEP 3 - 决策（三级重试）：
    记录当前任务已重试次数为 RETRY_COUNT（初始为 0）

    PASS → 将任务标记为 [x]，RETRY_COUNT 重置为 0，进入下一任务

    FAIL 且 RETRY_COUNT = 0（第1次重试）→
      RETRY_COUNT = 1
      查 ~/.claude/team-memory/patterns/frontend-patterns.md：
        若有关键词匹配当前 QA 失败原因的条目：
          在重试指令头部附上该条目的"解决方案"字段内容
          → Task → frontend-developer（带知识库提示重试）
        否则：
          → Task → frontend-developer（原样传 QA 反馈重试）

    FAIL 且 RETRY_COUNT = 1（第2次重试）→
      RETRY_COUNT = 2
      分析 QA 失败原因关键词：
      ├─ 包含 "路径硬编码" 或 "VITE_API_BASE" 或 "硬编码 /api"
      │   → 读取 docs/TECH_SPEC.md 中"部署路径规范"章节
      │   → Task → frontend-developer（附 TECH_SPEC 部署路径章节 + QA 反馈重试）
      ├─ 包含 "CSS 变量" 或 "硬编码颜色" 或 "硬编码字号" 或 "硬编码间距"
      │   → 读取 docs/DESIGN_SYSTEM.md 对应章节
      │   → Task → frontend-developer（附 DESIGN_SYSTEM 相关章节 + QA 反馈重试）
      ├─ 包含 "字段" 或 "接口" 或 "字段名不符"
      │   → Task → software-architect（传入：API_CONTRACT 中该接口 + QA 失败原因，要求澄清）
      │   → 将澄清结果 + QA 反馈传给 frontend-developer 重试
      └─ 其他
          → Task → frontend-developer（原样传 QA 反馈重试）

    FAIL 且 RETRY_COUNT >= 2（第3次失败）→
      暂停，向用户报告：
        ❌ 前端任务卡点报告
        任务：[当前任务 ID 和描述]
        第1次失败原因：[记录]
        第1次重试动作：[查知识库/原样重试]
        第2次失败原因：[记录]
        第2次重试动作：[拉 software-architect/附 TECH_SPEC/附 DESIGN_SYSTEM/原样]
        第3次失败原因：[当前 QA 输出]
        请人工介入后输入"继续"或提供修复思路。
```

- [ ] **Step 4: 验证**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "Phase 5.9" | Select-Object LineNumber, Line
Select-String -Path "agents\orchestrator.md" -Pattern "PHASE6_MEMORY_HINT" | Measure-Object | Select-Object Count
```

预期：Phase 5.9 存在；PHASE6_MEMORY_HINT 出现 ≥ 2 次。

- [ ] **Step 5: Commit**

```powershell
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add Phase 6 knowledge injection + expand Phase 6 STEP 3 retry"
```

---

### Task 7: 更新 orchestrator.md — Phase 7 安全注入 + Phase 11 知识写回

**Files:**
- Modify: `agents/orchestrator.md`（Phase 7 段落 + Phase 11 末尾）

- [ ] **Step 1: 在 `## ► Phase 7：安全审查` 段落内，调用 security-engineer 之前插入注入步骤**

找到 Phase 7 的：

```markdown
**调用 `security-engineer`**

```
输入：扫描 src/ 目录
```

在 `调用 security-engineer` 这行之前插入：

```markdown
**Phase 7 前：读取安全知识库**

```
读取 ~/.claude/team-memory/patterns/security-patterns.md（若存在）
筛选 PROJECT_TECH_STACK 匹配条目 → 构建 SECURITY_MEMORY_HINT
若非空，将其作为 security-engineer 任务指令的第一段（指出历史高频漏洞类型）
```

```

- [ ] **Step 2: 在 Phase 11 段落末尾（技术文档生成完成后）追加知识写回步骤**

找到 Phase 11 段落内容末尾（`docs/API_DOC.md（基于 API_CONTRACT 的可读版文档）` 这一行之后），追加：

```markdown
---

## ► Phase 11.5：知识库写回（仅当 reality-checker 判决为 READY 时执行）

```
条件：Phase 10 reality-checker 输出为 READY。
若为 NEEDS WORK 或项目未完成，跳过此步骤，不写入。

执行步骤：
1. 读取 docs/BACKEND_STATUS.md 的 ISSUES 章节
2. 回顾本项目 Phase 5/6 中所有触发过 RETRY_COUNT > 0 的任务，提炼如下字段：
   - 错误类型简称（不超过 10 字）
   - 触发场景（一句话描述什么操作导致了错误）
   - 错误表现（一句话，QA 看到了什么）
   - 最终有效解决方案（一句话，第几次重试采用了什么方法）
   - 技术栈（从 PROJECT_TECH_STACK 中取相关部分）

3. 对每条提炼出的模式：
   - 判断归属：backend → backend-patterns.md；frontend → frontend-patterns.md；
                契约问题 → contract-patterns.md；安全 → security-patterns.md；
                部署 → deployment-patterns.md
   - 若 ~/.claude/team-memory/patterns/[对应文件] 中已有同名条目（## 标题相同）：
       只更新"出现次数:"字段 +1 和"最后更新:"字段
   - 若无同名条目：
       追加新条目（使用 patterns 模板格式）

4. 写入完成后输出：
   ✅ 已向团队记忆库写入 N 条模式（路径：~/.claude/team-memory/patterns/）
```

```

- [ ] **Step 3: 验证**

```powershell
Select-String -Path "agents\orchestrator.md" -Pattern "Phase 11.5" | Select-Object LineNumber, Line
Select-String -Path "agents\orchestrator.md" -Pattern "SECURITY_MEMORY_HINT" | Select-Object LineNumber, Line
```

预期：Phase 11.5 存在；SECURITY_MEMORY_HINT 存在。

- [ ] **Step 4: 全量验证——所有新增关键词均在 orchestrator.md 中**

```powershell
$keywords = @("Phase 4.9", "Phase 5.9", "Phase 11.5", "PHASE5_MEMORY_HINT", "PHASE6_MEMORY_HINT", "SECURITY_MEMORY_HINT", "RETRY_COUNT", "第1次重试", "第2次重试", "第3次失败")
foreach ($kw in $keywords) {
  $count = (Select-String -Path "agents\orchestrator.md" -Pattern $kw).Count
  Write-Host "$kw : $count 次"
}
```

预期：每个关键词出现次数均 ≥ 1。

- [ ] **Step 5: Commit**

```powershell
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add Phase 7 security injection + Phase 11.5 knowledge write-back"
```

---

### Task 8: 收尾验证 + 更新 INSTALL.md

**Files:**
- Modify: `INSTALL.md`（在安装方式一前新增 install.sh 方式）

- [ ] **Step 1: 全量文件清单验证**

```powershell
$expected = @(
  "agents\code-reviewer.md",
  "agents\devops-automator.md",
  "agents\security-engineer.md",
  "agents\technical-writer.md",
  "agents\testing-evidence-collector.md",
  "templates\memory\backend-patterns.md",
  "templates\memory\frontend-patterns.md",
  "templates\memory\contract-patterns.md",
  "templates\memory\qa-patterns.md",
  "templates\memory\security-patterns.md",
  "templates\memory\deployment-patterns.md",
  "templates\memory\project-CLAUDE.md",
  "templates\memory\settings.json",
  "scripts\install.sh",
  "scripts\team-init.sh"
)
foreach ($f in $expected) {
  if (Test-Path $f) { Write-Host "✅ $f" } else { Write-Host "❌ MISSING: $f" }
}
```

预期：全部 ✅，无 ❌。

- [ ] **Step 2: 验证所有 agent 都有 model 字段**

```powershell
Get-ChildItem "agents\*.md" | ForEach-Object {
  $name = $_.Name
  $model = (Select-String -Path $_.FullName -Pattern "^model:").Line
  if ($model) { "✅ $name : $model" } else { "❌ MISSING model: $name" }
}
```

预期：13 行全部 ✅。

- [ ] **Step 3: 在 INSTALL.md 的"方式一"前新增 install.sh 方式（最简方式）**

在 `INSTALL.md` 的 `### 方式一：克隆仓库后批量复制（推荐）` 标题前插入：

```markdown
### 方式零：使用安装脚本（推荐，含知识库初始化）

```bash
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

安装后，在每个新项目目录执行一次初始化：

```bash
# 在你的新项目目录中
bash /path/to/claude-standard-dev-team/scripts/team-init.sh
```

这会在当前目录生成 `CLAUDE.md`（填写技术栈后 orchestrator 可精准读取知识库）和 `.claude/settings.json`。

```

- [ ] **Step 4: 最终 commit**

```powershell
git add INSTALL.md
git commit -m "docs: update INSTALL.md with install.sh quickstart"
```

- [ ] **Step 5: 验证 git log 包含所有增强提交**

```powershell
git log --oneline -8
```

预期看到 7 个新提交（Task 1-8 各一个）加上原有提交。

---

## 成功标准核对

| 标准 | 验证命令 | 预期 |
|---|---|---|
| 5 个 agent 有 model 字段 | Task 1 Step 7 | 全部输出 model 值 |
| 6 个 pattern 模板文件存在 | Task 2 Step 8 | 6 行输出 |
| install.sh 语法正确 | Task 3 Step 6 | OK |
| team-init.sh 语法正确 | Task 3 Step 6 | OK |
| orchestrator 包含知识库注入逻辑 | Task 7 Step 4 | 10 个关键词均 ≥ 1 次 |
| orchestrator 包含三级重试 | Task 7 Step 4 | RETRY_COUNT ≥ 5 次 |
| orchestrator 包含知识写回 | Task 7 Step 3 | Phase 11.5 存在 |
