# 用户级 AI 团队运行机制 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the confirmed A2 pure Claude Code / Markdown / Bash runtime so the standard AI team can be installed at user level, initialized per project, recover long-running workflows, retry with memory, and write back proven learnings.

**Architecture:** Keep the system file-based: user-level agents live in `~/.claude/agents/`, long-term patterns live in `~/.claude/team-memory/patterns/`, and each project stores runtime state in `.claude/team-state/`. `orchestrator.md` remains the control plane and is extended with state recovery, memory injection, tiered retry, and READY-only memory write-back rules.

**Tech Stack:** Markdown, Bash, Claude Code subagent frontmatter.

---

## File Structure

| Path | Operation | Responsibility |
|---|---|---|
| `agents/code-reviewer.md` | Modify | Add `model: sonnet` frontmatter |
| `agents/devops-automator.md` | Modify | Add `model: sonnet` frontmatter |
| `agents/security-engineer.md` | Modify | Add `model: sonnet` frontmatter |
| `agents/technical-writer.md` | Modify | Add `model: haiku` frontmatter |
| `agents/testing-evidence-collector.md` | Modify | Add `model: haiku` frontmatter |
| `templates/memory/backend-patterns.md` | Create | Backend error pattern template |
| `templates/memory/frontend-patterns.md` | Create | Frontend error pattern template |
| `templates/memory/contract-patterns.md` | Create | API and DB contract pattern template |
| `templates/memory/qa-patterns.md` | Create | QA failure pattern template |
| `templates/memory/security-patterns.md` | Create | Security failure pattern template |
| `templates/memory/deployment-patterns.md` | Create | Deployment failure pattern template |
| `templates/memory/project-CLAUDE.md` | Create | New project `CLAUDE.md` template |
| `templates/memory/settings.json` | Create | New project Claude settings template |
| `templates/memory/team-state/STATE.md` | Create | Runtime state template |
| `templates/memory/team-state/RETRY_LOG.md` | Create | Retry log template |
| `templates/memory/team-state/DECISIONS.md` | Create | Decision log template |
| `templates/memory/team-state/LEARNINGS.md` | Create | Project learning template |
| `scripts/install.sh` | Create | User-level team installer |
| `scripts/team-init.sh` | Create | Per-project team initializer |
| `agents/orchestrator.md` | Modify | Add state recovery, memory injection, tiered retry, READY-only write-back |
| `INSTALL.md` | Modify | Document `install.sh` and `team-init.sh` workflows |

---

### Task 1: Add Missing Agent Model Declarations

**Files:**
- Modify: `agents/code-reviewer.md`
- Modify: `agents/devops-automator.md`
- Modify: `agents/security-engineer.md`
- Modify: `agents/technical-writer.md`
- Modify: `agents/testing-evidence-collector.md`

- [ ] **Step 1: Verify the five target agents are missing `model:`**

```bash
for f in \
  agents/code-reviewer.md \
  agents/devops-automator.md \
  agents/security-engineer.md \
  agents/technical-writer.md \
  agents/testing-evidence-collector.md
do
  if rg -n '^model:' "$f" >/dev/null; then
    echo "HAS model: $f"
  else
    echo "MISSING model: $f"
  fi
done
```

Expected output:

```text
MISSING model: agents/code-reviewer.md
MISSING model: agents/devops-automator.md
MISSING model: agents/security-engineer.md
MISSING model: agents/technical-writer.md
MISSING model: agents/testing-evidence-collector.md
```

- [ ] **Step 2: Insert the model fields**

Use `apply_patch`:

```diff
*** Begin Patch
*** Update File: agents/code-reviewer.md
@@
 name: code-reviewer
+model: sonnet
 description: 代码评审专家。提供建设性、可执行的反馈，聚焦正确性、可维护性、安全性、性能——不在风格偏好上纠缠。
*** Update File: agents/devops-automator.md
@@
 name: devops-automator
+model: sonnet
 description: DevOps 工程专家。专注于基础设施自动化、CI/CD 流水线开发、云上运维。当需要设计部署架构、容器编排、监控告警、IaC 模板时激活。
*** Update File: agents/security-engineer.md
@@
 name: security-engineer
+model: sonnet
 description: 应用安全工程师。专精威胁建模、漏洞评估、安全代码评审、现代 Web 与云原生应用的安全架构设计。当需要做安全审计、威胁建模、漏洞排查、安全架构设计时激活。
*** Update File: agents/technical-writer.md
@@
 name: technical-writer
+model: haiku
 description: 技术文档专家。专精开发者文档、API 参考、README、教程。把复杂工程概念翻译成清晰、精准、有吸引力的文档——开发者会真的去读、去用。
*** Update File: agents/testing-evidence-collector.md
@@
 name: testing-evidence-collector
+model: haiku
 description: 截图取证型 QA 专家——对幻想式汇报过敏。默认就是要找出 3-5 个问题，凡事都要视觉证据。
*** End Patch
```

- [ ] **Step 3: Verify all agents now have a `model:` field**

```bash
missing=0
for f in agents/*.md; do
  if rg -n '^model:' "$f" >/dev/null; then
    echo "OK model: $f"
  else
    echo "MISSING model: $f"
    missing=1
  fi
done
exit "$missing"
```

Expected output: 13 `OK model:` lines and exit code `0`.

- [ ] **Step 4: Commit**

```bash
git add agents/code-reviewer.md agents/devops-automator.md agents/security-engineer.md agents/technical-writer.md agents/testing-evidence-collector.md
git commit -m "feat: add model declarations to remaining agents"
```

---

### Task 2: Create User-Level Memory Pattern Templates

**Files:**
- Create: `templates/memory/backend-patterns.md`
- Create: `templates/memory/frontend-patterns.md`
- Create: `templates/memory/contract-patterns.md`
- Create: `templates/memory/qa-patterns.md`
- Create: `templates/memory/security-patterns.md`
- Create: `templates/memory/deployment-patterns.md`

- [ ] **Step 1: Create the template directory**

```bash
mkdir -p templates/memory
```

- [ ] **Step 2: Add the six pattern templates**

Use `apply_patch`:

````diff
*** Begin Patch
*** Add File: templates/memory/backend-patterns.md
+# 后端实现错误模式库
+
+orchestrator 在 Phase 5 开始前读取本文件，按技术栈过滤后注入到 backend-architect 的任务指令。
+项目最终 READY 后，orchestrator 才能把已经验证有效的后端修复模式写回本文件。
+
+每条记录必须使用以下格式：
+
+```markdown
+## 错误响应缺少 code 字段
+- 触发场景: backend-architect 实现错误响应时只返回 HTTP 状态码
+- 错误表现: QA 发现 POST /api/auth/login 返回 401 但 body 缺少 code 字段
+- 解决方案: 错误响应统一返回 code 和 message，并与 API_CONTRACT 保持一致
+- 技术栈: Express.js
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** Add File: templates/memory/frontend-patterns.md
+# 前端实现错误模式库
+
+orchestrator 在 Phase 6 开始前读取本文件，按技术栈过滤后注入到 frontend-developer 的任务指令。
+项目最终 READY 后，orchestrator 才能把已经验证有效的前端修复模式写回本文件。
+
+每条记录必须使用以下格式：
+
+```markdown
+## API 路径硬编码
+- 触发场景: frontend-developer 直接写 fetch('/api/v1/users') 而非使用环境变量
+- 错误表现: QA 发现代码中存在硬编码 /api/ 路径，子路径部署会失败
+- 解决方案: 所有 API 调用必须通过统一 HTTP 客户端，并使用 import.meta.env.VITE_API_BASE
+- 技术栈: React, Vite
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** Add File: templates/memory/contract-patterns.md
+# API/DB 契约设计陷阱库
+
+orchestrator 在 Phase 5 和 Phase 6 前读取本文件，按技术栈过滤后注入给实现 agent。
+契约类问题通常由 software-architect 在第 2 次重试时复查。
+
+每条记录必须使用以下格式：
+
+```markdown
+## 分页参数类型不一致
+- 触发场景: API_CONTRACT 定义 page 为 string，但实现中按 number 处理
+- 错误表现: QA 发现 GET /api/items?page=2 返回全量数据，分页失效
+- 解决方案: API_CONTRACT 明确 page 类型为 integer，并在请求示例中演示
+- 技术栈: 通用
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** Add File: templates/memory/qa-patterns.md
+# QA 验证失败模式库
+
+记录 testing-evidence-collector 反复发现的验证失败模式，供 orchestrator 提前预警。
+项目最终 READY 后，orchestrator 才能把已经验证有效的 QA 失败模式写回本文件。
+
+每条记录必须使用以下格式：
+
+```markdown
+## 服务未启动导致全部 404
+- 触发场景: 后端实现完成但 start.sh 未启动对应服务
+- 错误表现: testing-evidence-collector 所有接口请求返回 404 或 Connection Refused
+- 解决方案: 第 2 次重试时拉 devops-automator 检查启动脚本和服务端口
+- 技术栈: 通用
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** Add File: templates/memory/security-patterns.md
+# 安全问题模式库
+
+orchestrator 在 Phase 7 开始前读取本文件，按技术栈过滤后注入到 security-engineer 的任务指令。
+项目最终 READY 后，orchestrator 才能把已经验证有效的安全修复模式写回本文件。
+
+每条记录必须使用以下格式：
+
+```markdown
+## JWT 未验证 audience 字段
+- 触发场景: backend-architect 实现 JWT 验证时只验证签名
+- 错误表现: security-engineer 发现跨服务 token 可被错误接受
+- 解决方案: JWT 验证必须同时校验 signature、issuer、audience 和过期时间
+- 技术栈: Node.js, Express.js
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** Add File: templates/memory/deployment-patterns.md
+# 部署问题模式库
+
+orchestrator 在 Phase 6 和 Phase 9 前读取本文件，按技术栈过滤后注入给 frontend-developer 或 devops-automator。
+项目最终 READY 后，orchestrator 才能把已经验证有效的部署修复模式写回本文件。
+
+每条记录必须使用以下格式：
+
+```markdown
+## Nginx 子路径缺少 try_files
+- 触发场景: devops-automator 生成的 nginx.conf 在子路径部署时缺少 try_files 配置
+- 错误表现: SPA 刷新子页面返回 404
+- 解决方案: nginx location 块必须包含 try_files $uri $uri/ /index.html
+- 技术栈: Nginx, React SPA
+- 出现次数: 1
+- 最后更新: 2026-05-12
+```
*** End Patch
````

- [ ] **Step 3: Verify the six template files exist**

```bash
for f in backend frontend contract qa security deployment; do
  test -f "templates/memory/${f}-patterns.md" && echo "OK ${f}-patterns.md"
done
```

Expected output:

```text
OK backend-patterns.md
OK frontend-patterns.md
OK contract-patterns.md
OK qa-patterns.md
OK security-patterns.md
OK deployment-patterns.md
```

- [ ] **Step 4: Verify each template contains the required fields**

```bash
for f in templates/memory/*-patterns.md; do
  echo "Checking $f"
  rg --quiet '触发场景:' "$f"
  rg --quiet '错误表现:' "$f"
  rg --quiet '解决方案:' "$f"
  rg --quiet '技术栈:' "$f"
  rg --quiet '出现次数:' "$f"
  rg --quiet '最后更新:' "$f"
done
echo "pattern templates OK"
```

Expected output ends with:

```text
pattern templates OK
```

- [ ] **Step 5: Commit**

```bash
git add templates/memory/backend-patterns.md templates/memory/frontend-patterns.md templates/memory/contract-patterns.md templates/memory/qa-patterns.md templates/memory/security-patterns.md templates/memory/deployment-patterns.md
git commit -m "feat: add team memory pattern templates"
```

---

### Task 3: Create Project Templates and Bootstrap Scripts

**Files:**
- Create: `templates/memory/project-CLAUDE.md`
- Create: `templates/memory/settings.json`
- Create: `templates/memory/team-state/STATE.md`
- Create: `templates/memory/team-state/RETRY_LOG.md`
- Create: `templates/memory/team-state/DECISIONS.md`
- Create: `templates/memory/team-state/LEARNINGS.md`
- Create: `scripts/install.sh`
- Create: `scripts/team-init.sh`

- [ ] **Step 1: Add project and state templates**

Use `apply_patch`:

````diff
*** Begin Patch
*** Add File: templates/memory/project-CLAUDE.md
+# {{PROJECT_NAME}}
+
+## 团队配置
+
+本项目使用标准 AI 开发团队（13 agents）。
+在 Claude Code 中说“使用标准团队开发 你的需求”即可启动 orchestrator。
+
+## 项目上下文
+
+- 技术栈: 请填写，例如 Express.js, React, PostgreSQL
+- 部署环境: 请填写，例如 Docker + Nginx，或 Vercel
+
+## 团队运行机制
+
+- 项目状态记录在 `.claude/team-state/STATE.md`
+- 失败重试记录在 `.claude/team-state/RETRY_LOG.md`
+- 用户确认过的关键决策记录在 `.claude/team-state/DECISIONS.md`
+- 项目内经验记录在 `.claude/team-state/LEARNINGS.md`
+- 用户级长期记忆位于 `~/.claude/team-memory/patterns/`
*** Add File: templates/memory/settings.json
+{
+  "permissions": {
+    "allow": [
+      "Task",
+      "Read",
+      "Write",
+      "Glob",
+      "Bash",
+      "Grep"
+    ]
+  }
+}
*** Add File: templates/memory/team-state/STATE.md
+# Team State
+
+- Current Phase: Not Started
+- Current Task: None
+- Last Agent: None
+- Last Result: None
+- Retry Count: 0
+- Next Action: Start Phase 1 requirement analysis
+- Updated At: Not Started
*** Add File: templates/memory/team-state/RETRY_LOG.md
+# Retry Log
+
+本文件由 orchestrator 在 Phase 5 / Phase 6 / Phase 7 / Phase 8 / Phase 10 失败打回时更新。
+
+## 记录格式
+
+```markdown
+### TASK-B01
+- Phase: Phase 5
+- Agent: backend-architect
+- Attempt: 1
+- Result: QA_FAIL
+- Failure Reason: 返回字段 user_id 与 API_CONTRACT 的 userId 不一致
+- Routed To: backend-architect
+- Retry Strategy: Inject contract memory and QA feedback
+- Final Outcome: PASS
+- Updated At: 2026-05-12
+```
+
+## 当前记录
+
+No retries recorded.
*** Add File: templates/memory/team-state/DECISIONS.md
+# Decisions
+
+本文件记录用户已经确认过的关键决策，orchestrator 恢复运行时必须优先读取。
+
+## Confirmed Decisions
+
+No decisions recorded.
*** Add File: templates/memory/team-state/LEARNINGS.md
+# Project Learnings
+
+本文件记录项目内临时经验。只有 reality-checker 判定 READY 后，orchestrator 才能从这里提炼内容写入用户级长期记忆库。
+
+## Candidate Learnings
+
+No learnings recorded.
*** End Patch
````

- [ ] **Step 2: Add `scripts/install.sh`**

Use `apply_patch`:

```diff
*** Begin Patch
*** Add File: scripts/install.sh
+#!/usr/bin/env bash
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+REPO_DIR="$(dirname "$SCRIPT_DIR")"
+AGENTS_SRC="$REPO_DIR/agents"
+TEMPLATES_SRC="$REPO_DIR/templates/memory"
+AGENTS_DEST="$HOME/.claude/agents"
+MEMORY_DEST="$HOME/.claude/team-memory/patterns"
+
+if [ ! -d "$AGENTS_SRC" ]; then
+  echo "ERROR: agents directory not found: $AGENTS_SRC" >&2
+  echo "Run this script from a clone of claude-standard-dev-team." >&2
+  exit 1
+fi
+
+if [ ! -d "$TEMPLATES_SRC" ]; then
+  echo "ERROR: memory templates directory not found: $TEMPLATES_SRC" >&2
+  echo "Run this script after templates/memory has been created." >&2
+  exit 1
+fi
+
+echo "Installing standard AI development team..."
+
+mkdir -p "$AGENTS_DEST"
+cp "$AGENTS_SRC"/*.md "$AGENTS_DEST/"
+agent_count="$(find "$AGENTS_SRC" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
+echo "Installed $agent_count agents to $AGENTS_DEST"
+
+mkdir -p "$MEMORY_DEST"
+for pattern in backend frontend contract qa security deployment; do
+  src="$TEMPLATES_SRC/${pattern}-patterns.md"
+  dest="$MEMORY_DEST/${pattern}-patterns.md"
+  if [ ! -f "$src" ]; then
+    echo "ERROR: missing template $src" >&2
+    exit 1
+  fi
+  if [ -f "$dest" ]; then
+    echo "Keeping existing memory file: $dest"
+  else
+    cp "$src" "$dest"
+    echo "Created memory file: $dest"
+  fi
+done
+
+echo "Install complete."
+echo "For each project, run: bash $REPO_DIR/scripts/team-init.sh"
*** End Patch
```

- [ ] **Step 3: Add `scripts/team-init.sh`**

Use `apply_patch`:

```diff
*** Begin Patch
*** Add File: scripts/team-init.sh
+#!/usr/bin/env bash
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+REPO_DIR="$(dirname "$SCRIPT_DIR")"
+TEMPLATES_SRC="$REPO_DIR/templates/memory"
+STATE_TEMPLATES_SRC="$TEMPLATES_SRC/team-state"
+PROJECT_NAME="$(basename "$PWD")"
+PROJECT_NAME_ESCAPED="$(printf '%s' "$PROJECT_NAME" | sed 's/[\/&]/\\&/g')"
+
+if [ ! -d "$TEMPLATES_SRC" ]; then
+  echo "ERROR: templates directory not found: $TEMPLATES_SRC" >&2
+  echo "Run this script from the installed claude-standard-dev-team clone." >&2
+  exit 1
+fi
+
+echo "Initializing project for standard AI team: $PROJECT_NAME"
+
+if [ -f "CLAUDE.md" ]; then
+  echo "Keeping existing CLAUDE.md"
+else
+  sed "s/{{PROJECT_NAME}}/${PROJECT_NAME_ESCAPED}/g" "$TEMPLATES_SRC/project-CLAUDE.md" > CLAUDE.md
+  echo "Created CLAUDE.md"
+fi
+
+mkdir -p .claude
+if [ -f ".claude/settings.json" ]; then
+  echo "Keeping existing .claude/settings.json"
+else
+  cp "$TEMPLATES_SRC/settings.json" .claude/settings.json
+  echo "Created .claude/settings.json"
+fi
+
+mkdir -p .claude/team-state
+for state_file in STATE.md RETRY_LOG.md DECISIONS.md LEARNINGS.md; do
+  src="$STATE_TEMPLATES_SRC/$state_file"
+  dest=".claude/team-state/$state_file"
+  if [ ! -f "$src" ]; then
+    echo "ERROR: missing state template $src" >&2
+    exit 1
+  fi
+  if [ -f "$dest" ]; then
+    echo "Keeping existing $dest"
+  else
+    cp "$src" "$dest"
+    echo "Created $dest"
+  fi
+done
+
+echo "Project initialization complete."
+echo "Fill in CLAUDE.md technology stack and deployment environment before starting orchestrator."
*** End Patch
```

- [ ] **Step 4: Mark scripts executable**

```bash
chmod +x scripts/install.sh scripts/team-init.sh
```

- [ ] **Step 5: Verify shell syntax**

```bash
bash -n scripts/install.sh
bash -n scripts/team-init.sh
echo "script syntax OK"
```

Expected output:

```text
script syntax OK
```

- [ ] **Step 6: Verify project initialization in a temporary directory**

```bash
tmpdir="$(mktemp -d)"
(
  cd "$tmpdir"
  bash /mnt/d/mcp/claude-standard-dev-team/scripts/team-init.sh
  test -f CLAUDE.md
  test -f .claude/settings.json
  test -f .claude/team-state/STATE.md
  test -f .claude/team-state/RETRY_LOG.md
  test -f .claude/team-state/DECISIONS.md
  test -f .claude/team-state/LEARNINGS.md
)
rm -rf "$tmpdir"
echo "team-init smoke test OK"
```

Expected output ends with:

```text
team-init smoke test OK
```

- [ ] **Step 7: Verify `team-init.sh` is idempotent**

```bash
tmpdir="$(mktemp -d)"
(
  cd "$tmpdir"
  bash /mnt/d/mcp/claude-standard-dev-team/scripts/team-init.sh
  printf '%s\n' 'custom state survives' > .claude/team-state/STATE.md
  bash /mnt/d/mcp/claude-standard-dev-team/scripts/team-init.sh
  rg --quiet 'custom state survives' .claude/team-state/STATE.md
)
rm -rf "$tmpdir"
echo "team-init idempotency OK"
```

Expected output ends with:

```text
team-init idempotency OK
```

- [ ] **Step 8: Commit**

```bash
git add templates/memory/project-CLAUDE.md templates/memory/settings.json templates/memory/team-state scripts/install.sh scripts/team-init.sh
git commit -m "feat: add project runtime templates and bootstrap scripts"
```

---

### Task 4: Add Orchestrator State Recovery and Memory Injection Rules

**Files:**
- Modify: `agents/orchestrator.md`

- [ ] **Step 1: Insert the runtime state section before `# 完整执行流程`**

Find this line:

```markdown
# 完整执行流程
```

Insert this block immediately before it:

````markdown
# 用户级团队运行状态

每次进入标准开发流程时，先读取项目级状态目录：

```
.claude/team-state/
  STATE.md
  RETRY_LOG.md
  DECISIONS.md
  LEARNINGS.md
```

## 状态恢复规则

1. 若 `.claude/team-state/STATE.md` 不存在：从 Phase 0 / Phase 1 开始，并创建状态目录。
2. 若 `STATE.md` 存在且 `Current Phase` 不是 `Complete`：读取 `Next Action`，从该动作继续。
3. 若 `Last Result` 为 `WAITING_USER_CONFIRMATION`：展示 `DECISIONS.md` 中相关摘要，等待用户输入“继续”。
4. 若 `Retry Count` 大于等于 3：先展示 `RETRY_LOG.md` 中该任务的卡点报告，不自动继续。
5. 若状态文件字段缺失：读取 docs 和 project-tasks 推断阶段，并向用户确认恢复点。

## 状态写入规则

每个 Phase 开始时更新：

```markdown
# Team State

- Current Phase: Phase N
- Current Task: 当前任务 ID 或 None
- Last Agent: 上一个被调用的 agent 或 None
- Last Result: RUNNING
- Retry Count: 当前任务重试次数
- Next Action: 当前 Phase 的下一步动作
- Updated At: 当前日期
```

每个 Phase 完成时更新 `Last Result` 和 `Next Action`。Phase 1 / Phase 2 的人工确认点必须写入 `.claude/team-state/DECISIONS.md`。
````

- [ ] **Step 2: Add Phase 0 state initialization requirement**

In `## ► Phase 0：初始化目录`, replace:

```bash
mkdir -p docs project-tasks
```

with:

```bash
mkdir -p docs project-tasks .claude/team-state
```

Then add this sentence after the code block:

```markdown
若 `.claude/team-state/STATE.md` 不存在，按模板创建 `STATE.md`、`RETRY_LOG.md`、`DECISIONS.md`、`LEARNINGS.md`，并将 `Next Action` 设置为 `Run Phase 1 requirement analysis`。
```

- [ ] **Step 3: Add Phase 4.9 memory injection before Phase 5**

Insert this block immediately before `## ► Phase 5：后端实现（含任务级 Dev-QA Loop）`:

````markdown
## ► Phase 4.9：后端知识库注入准备

在启动后端开发循环前执行：

```
STEP 0 - 读取用户级团队记忆：
  1. 读取项目根目录 CLAUDE.md 中的“技术栈:”字段，得到 PROJECT_TECH_STACK。
  2. 若 ~/.claude/team-memory/patterns/backend-patterns.md 存在：
       读取文件，筛选“技术栈:”与 PROJECT_TECH_STACK 任意关键词匹配的条目。
       取出现次数最高前 5 条 + 最近 10 条，去重后最多 15 条。
       生成 BACKEND_MEMORY_HINT。
  3. 若 ~/.claude/team-memory/patterns/contract-patterns.md 存在：
       按相同规则生成 CONTRACT_MEMORY_HINT。
  4. 合并 PHASE5_MEMORY_HINT = BACKEND_MEMORY_HINT + CONTRACT_MEMORY_HINT。
  5. 若无匹配条目，PHASE5_MEMORY_HINT 为空，不阻塞 Phase 5。
```
````

- [ ] **Step 4: Add Phase 5.9 memory injection before Phase 6**

Insert this block immediately before `## ► Phase 6：前端实现（含任务级 Dev-QA Loop）`:

````markdown
## ► Phase 5.9：前端知识库注入准备

在启动前端开发循环前执行：

```
STEP 0 - 读取用户级团队记忆：
  1. 复用 PROJECT_TECH_STACK。
  2. 若 ~/.claude/team-memory/patterns/frontend-patterns.md 存在：
       筛选技术栈匹配条目，生成 FRONTEND_MEMORY_HINT。
  3. 若 ~/.claude/team-memory/patterns/deployment-patterns.md 存在：
       筛选技术栈匹配条目，生成 DEPLOYMENT_MEMORY_HINT。
  4. 合并 PHASE6_MEMORY_HINT = FRONTEND_MEMORY_HINT + DEPLOYMENT_MEMORY_HINT。
  5. 若无匹配条目，PHASE6_MEMORY_HINT 为空，不阻塞 Phase 6。
```
````

- [ ] **Step 5: Add Phase 7 security memory injection**

In `## ► Phase 7：安全审查`, insert this block before `**调用 `security-engineer`**`:

````markdown
**Phase 7 前：读取安全知识库**

```
读取 ~/.claude/team-memory/patterns/security-patterns.md（若存在）。
按 PROJECT_TECH_STACK 筛选匹配条目，生成 SECURITY_MEMORY_HINT。
若 SECURITY_MEMORY_HINT 非空，将其作为 security-engineer 任务指令第一段。
若文件不存在或无匹配条目，不阻塞安全审查。
```
````

- [ ] **Step 6: Verify state and memory keywords**

```bash
for kw in \
  "用户级团队运行状态" \
  ".claude/team-state" \
  "Phase 4.9" \
  "PHASE5_MEMORY_HINT" \
  "Phase 5.9" \
  "PHASE6_MEMORY_HINT" \
  "SECURITY_MEMORY_HINT"
do
  rg --quiet "$kw" agents/orchestrator.md
  echo "OK $kw"
done
```

Expected output: 7 `OK` lines.

- [ ] **Step 7: Commit**

```bash
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add runtime state recovery and memory injection"
```

---

### Task 5: Add Tiered Retry and READY-Only Memory Write-Back

**Files:**
- Modify: `agents/orchestrator.md`

- [ ] **Step 1: Replace Phase 5 STEP 1 input with memory-aware input**

In the Phase 5 loop, replace the `STEP 1 - 调用 backend-architect 实现该任务` input list with:

```markdown
  STEP 1 - 调用 backend-architect 实现该任务：
    输入：
      - 若 PHASE5_MEMORY_HINT 非空，将其作为任务指令的第一段发送给 backend-architect
      - 读取 docs/API_CONTRACT.md（必须第一步）
      - 读取 docs/DB_SCHEMA.md
      - 读取当前任务描述
    要求：
      - 严格按契约实现，路径/方法/字段名不得偏差
      - 若契约有歧义，写入 docs/BACKEND_STATUS.md 的 ISSUES 章节
      - Phase 开始、PASS、FAIL、重试前后都更新 .claude/team-state/STATE.md
    产出：该接口的实现代码
```

- [ ] **Step 2: Replace Phase 5 STEP 3 with tiered retry**

Replace the old Phase 5 decision block with:

```markdown
  STEP 3 - 决策（三级智能重试）：
    记录当前任务重试次数 RETRY_COUNT，初始值为 0。

    PASS →
      - 将任务标记为 [x]
      - 将 RETRY_COUNT 重置为 0
      - 更新 .claude/team-state/STATE.md：Last Result = PASS，Next Action = Next backend task
      - 进入下一任务

    FAIL 且 RETRY_COUNT = 0（第1次重试）→
      - RETRY_COUNT = 1
      - 将失败原因追加到 .claude/team-state/RETRY_LOG.md
      - 查 ~/.claude/team-memory/patterns/backend-patterns.md 和 contract-patterns.md
      - 若有错误关键词匹配条目，将该条目的“解决方案”字段加入重试指令头部
      - 打回 backend-architect，附 QA 反馈和记忆提示

    FAIL 且 RETRY_COUNT = 1（第2次重试）→
      - RETRY_COUNT = 2
      - 将失败原因追加到 .claude/team-state/RETRY_LOG.md
      - 按 QA 失败关键词分流：
        * 包含“字段缺失”“字段名”“字段不符”“契约” → 调 software-architect 复查 API_CONTRACT，再把澄清结果打回 backend-architect
        * 包含“404”“连接失败”“服务未启动”“Connection Refused” → 调 devops-automator 检查启动脚本和端口，再把修复建议打回 backend-architect
        * 包含“鉴权”“权限”“token”“JWT” → 调 security-engineer 复查安全约束，再把修复建议打回 backend-architect
        * 其他 → 打回 backend-architect，附完整 QA 反馈

    FAIL 且 RETRY_COUNT >= 2（第3次失败）→
      - 更新 .claude/team-state/STATE.md：Last Result = BLOCKED，Retry Count = 3
      - 生成卡点报告，包含任务 ID、3 次失败原因、已尝试修复思路、建议人工介入点
      - 暂停，等待用户输入“继续”或提供修复思路
```

- [ ] **Step 3: Replace Phase 6 STEP 1 input with memory-aware input**

In the Phase 6 loop, replace the `STEP 1 - 调用 frontend-developer 实现该任务` input list with:

```markdown
  STEP 1 - 调用 frontend-developer 实现该任务：
    输入：
      - 若 PHASE6_MEMORY_HINT 非空，将其作为任务指令的第一段发送给 frontend-developer
      - 读取 docs/API_CONTRACT.md（必须第一步）
      - 读取 docs/DESIGN_SYSTEM.md（必须第二步，所有样式数值来源）
      - 读取 docs/DYNAMIC_CONTENT_MAP.md（动态内容绑定规则）
      - 读取 docs/TECH_SPEC.md
      - 读取 docs/PRD.md（用户故事和 UI 需求）
      - 读取当前任务描述
    要求：
      - 所有 API 调用路径、字段名与契约完全一致
      - 所有颜色/字体/间距必须使用 DESIGN_SYSTEM 中定义的 CSS 变量
      - 不得硬编码任何颜色值、字号、间距值
      - 不得猜测接口结构
      - Phase 开始、PASS、FAIL、重试前后都更新 .claude/team-state/STATE.md
```

- [ ] **Step 4: Replace Phase 6 STEP 3 with tiered retry**

Replace `STEP 3 - 决策（同后端 Loop 规则）` with:

```markdown
  STEP 3 - 决策（三级智能重试）：
    记录当前任务重试次数 RETRY_COUNT，初始值为 0。

    PASS →
      - 将任务标记为 [x]
      - 将 RETRY_COUNT 重置为 0
      - 更新 .claude/team-state/STATE.md：Last Result = PASS，Next Action = Next frontend task
      - 进入下一任务

    FAIL 且 RETRY_COUNT = 0（第1次重试）→
      - RETRY_COUNT = 1
      - 将失败原因追加到 .claude/team-state/RETRY_LOG.md
      - 查 ~/.claude/team-memory/patterns/frontend-patterns.md 和 deployment-patterns.md
      - 若有错误关键词匹配条目，将该条目的“解决方案”字段加入重试指令头部
      - 打回 frontend-developer，附 QA 反馈和记忆提示

    FAIL 且 RETRY_COUNT = 1（第2次重试）→
      - RETRY_COUNT = 2
      - 将失败原因追加到 .claude/team-state/RETRY_LOG.md
      - 按 QA 失败关键词分流：
        * 包含“路径硬编码”“VITE_API_BASE”“硬编码 /api” → 读取 TECH_SPEC 部署路径规范，打回 frontend-developer
        * 包含“CSS 变量”“硬编码颜色”“硬编码字号”“硬编码间距” → 读取 DESIGN_SYSTEM 对应章节，打回 frontend-developer
        * 包含“字段”“接口”“字段名不符”“契约” → 调 software-architect 复查 API_CONTRACT，再打回 frontend-developer
        * 包含“视觉”“布局”“间距”“颜色不符” → 调 ui-designer 复查 DESIGN_SYSTEM，再打回 frontend-developer
        * 其他 → 打回 frontend-developer，附完整 QA 反馈

    FAIL 且 RETRY_COUNT >= 2（第3次失败）→
      - 更新 .claude/team-state/STATE.md：Last Result = BLOCKED，Retry Count = 3
      - 生成卡点报告，包含任务 ID、3 次失败原因、已尝试修复思路、建议人工介入点
      - 暂停，等待用户输入“继续”或提供修复思路
```

- [ ] **Step 5: Add Phase 11.5 READY-only write-back after Phase 11**

Insert this block after the Phase 11 output code block:

````markdown
---

## ► Phase 11.5：知识库写回（仅 READY 后执行）

```
执行条件：
  - Phase 10 reality-checker 输出 READY。
  - 若输出 NEEDS WORK、项目中止、任务未完成，跳过写回。

写回来源：
  - .claude/team-state/RETRY_LOG.md
  - .claude/team-state/LEARNINGS.md
  - docs/BACKEND_STATUS.md 的已解决问题
  - docs/SECURITY_REPORT.md 中已修复的高危或中危问题
  - docs/REVIEW_REPORT.md 中已修复的 MUST FIX 问题

写回步骤：
  1. 提炼每个已验证有效的模式：
     - 错误类型简称
     - 触发场景
     - 错误表现
     - 最终有效解决方案
     - 技术栈
     - 出现次数
     - 最后更新
  2. 判断归属：
     - backend → backend-patterns.md
     - frontend → frontend-patterns.md
     - 契约问题 → contract-patterns.md
     - QA 验证问题 → qa-patterns.md
     - 安全问题 → security-patterns.md
     - 部署问题 → deployment-patterns.md
  3. 若对应文件存在同名标题：
     - 只更新“出现次数”和“最后更新”
  4. 若对应文件不存在同名标题：
     - 按模板格式追加新条目
  5. 写回后报告：
     - 写入条目数
     - 更新条目数
     - 跳过条目数
     - 目标路径 ~/.claude/team-memory/patterns/
```
````

- [ ] **Step 6: Verify retry and write-back keywords**

```bash
for kw in \
  "三级智能重试" \
  "RETRY_LOG.md" \
  "第1次重试" \
  "第2次重试" \
  "第3次失败" \
  "Phase 11.5" \
  "仅 READY 后执行"
do
  rg --quiet "$kw" agents/orchestrator.md
  echo "OK $kw"
done
```

Expected output: 7 `OK` lines.

- [ ] **Step 7: Commit**

```bash
git add agents/orchestrator.md
git commit -m "feat(orchestrator): add tiered retry and READY-only memory write-back"
```

---

### Task 6: Update Install Documentation

**Files:**
- Modify: `INSTALL.md`

- [ ] **Step 1: Insert the script-based install flow before current `方式一`**

In `INSTALL.md`, find:

```markdown
### 方式一：克隆仓库后批量复制（推荐）
```

Insert this block immediately before it:

````markdown
### 方式零：安装脚本（推荐，含用户级记忆库）

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

这会完成两件事：

1. 将 13 个 agent 安装到 `~/.claude/agents/`
2. 初始化用户级长期记忆库 `~/.claude/team-memory/patterns/`

安装后，在每个新项目目录执行一次初始化：

```bash
bash /path/to/claude-standard-dev-team/scripts/team-init.sh
```

这会在当前项目生成：

- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/team-state/STATE.md`
- `.claude/team-state/RETRY_LOG.md`
- `.claude/team-state/DECISIONS.md`
- `.claude/team-state/LEARNINGS.md`

填写 `CLAUDE.md` 中的技术栈和部署环境后，在 Claude Code 中说：

```text
使用标准团队开发 你的需求
```

orchestrator 会读取项目状态和用户级记忆库，按阶段自动拆解、开发、验证、失败打回和恢复。
````

- [ ] **Step 2: Update the upgrade section to use `install.sh`**

Replace the current upgrade command:

```bash
cd /your/clone/path/claude-standard-dev-team
git pull
cp agents/*.md ~/.claude/agents/
```

with:

```bash
cd /your/clone/path/claude-standard-dev-team
git pull
bash scripts/install.sh
```

- [ ] **Step 3: Verify documentation mentions both scripts**

```bash
rg --quiet 'scripts/install.sh' INSTALL.md
rg --quiet 'scripts/team-init.sh' INSTALL.md
rg --quiet '.claude/team-state/STATE.md' INSTALL.md
echo "install docs OK"
```

Expected output:

```text
install docs OK
```

- [ ] **Step 4: Commit**

```bash
git add INSTALL.md
git commit -m "docs: document user-level team install flow"
```

---

### Task 7: Final Verification

**Files:**
- Verify all files changed in Tasks 1-6.

- [ ] **Step 1: Verify expected files exist**

```bash
expected_files=(
  templates/memory/backend-patterns.md
  templates/memory/frontend-patterns.md
  templates/memory/contract-patterns.md
  templates/memory/qa-patterns.md
  templates/memory/security-patterns.md
  templates/memory/deployment-patterns.md
  templates/memory/project-CLAUDE.md
  templates/memory/settings.json
  templates/memory/team-state/STATE.md
  templates/memory/team-state/RETRY_LOG.md
  templates/memory/team-state/DECISIONS.md
  templates/memory/team-state/LEARNINGS.md
  scripts/install.sh
  scripts/team-init.sh
)

for f in "${expected_files[@]}"; do
  test -f "$f" && echo "OK $f"
done
```

Expected output: 14 `OK` lines.

- [ ] **Step 2: Verify every agent has a model declaration**

```bash
missing=0
for f in agents/*.md; do
  if rg -n '^model:' "$f" >/dev/null; then
    echo "OK model: $f"
  else
    echo "MISSING model: $f"
    missing=1
  fi
done
exit "$missing"
```

Expected output: 13 `OK model:` lines and exit code `0`.

- [ ] **Step 3: Verify scripts pass syntax checks**

```bash
bash -n scripts/install.sh
bash -n scripts/team-init.sh
echo "script syntax OK"
```

Expected output:

```text
script syntax OK
```

- [ ] **Step 4: Verify install script initializes memory without overwriting**

```bash
tmp_home="$(mktemp -d)"
HOME="$tmp_home" bash scripts/install.sh
printf '%s\n' 'custom memory survives' > "$tmp_home/.claude/team-memory/patterns/backend-patterns.md"
HOME="$tmp_home" bash scripts/install.sh
rg --quiet 'custom memory survives' "$tmp_home/.claude/team-memory/patterns/backend-patterns.md"
rm -rf "$tmp_home"
echo "install idempotency OK"
```

Expected output ends with:

```text
install idempotency OK
```

- [ ] **Step 5: Verify project init creates and preserves state**

```bash
tmp_project="$(mktemp -d)"
(
  cd "$tmp_project"
  bash /mnt/d/mcp/claude-standard-dev-team/scripts/team-init.sh
  test -f CLAUDE.md
  test -f .claude/settings.json
  test -f .claude/team-state/STATE.md
  printf '%s\n' 'custom decision survives' > .claude/team-state/DECISIONS.md
  bash /mnt/d/mcp/claude-standard-dev-team/scripts/team-init.sh
  rg --quiet 'custom decision survives' .claude/team-state/DECISIONS.md
)
rm -rf "$tmp_project"
echo "project init idempotency OK"
```

Expected output ends with:

```text
project init idempotency OK
```

- [ ] **Step 6: Verify orchestrator contains the runtime rules**

```bash
for kw in \
  "用户级团队运行状态" \
  "状态恢复规则" \
  "Phase 4.9" \
  "Phase 5.9" \
  "SECURITY_MEMORY_HINT" \
  "三级智能重试" \
  "Phase 11.5"
do
  rg --quiet "$kw" agents/orchestrator.md
  echo "OK orchestrator keyword: $kw"
done
```

Expected output: 7 `OK orchestrator keyword:` lines.

- [ ] **Step 7: Verify documentation contains the new install path**

```bash
rg --quiet '方式零：安装脚本' INSTALL.md
rg --quiet 'scripts/install.sh' INSTALL.md
rg --quiet 'scripts/team-init.sh' INSTALL.md
echo "documentation OK"
```

Expected output:

```text
documentation OK
```

- [ ] **Step 8: Inspect git status**

```bash
git status --short
```

Expected: only intentional files changed by the plan, plus any unrelated pre-existing user changes already present before execution.

- [ ] **Step 9: Final commit if verification required additional fixes**

If Step 8 shows only already committed Task 1-6 changes and no verification fixes, skip this step. If verification required edits, commit those edits:

```bash
git add agents templates scripts INSTALL.md
git commit -m "chore: finalize user-level team runtime verification"
```

---

## Self-Review Checklist

- Spec coverage: Tasks 1-7 cover user-level install, project init, state files, model routing, memory templates, state recovery, tiered retry, READY-only memory write-back, install docs, and verification.
- Placeholder scan: The plan uses concrete file paths, concrete script contents, concrete Markdown blocks, and exact verification commands. Template examples intentionally include sample pattern entries, not unresolved implementation placeholders.
- Type and name consistency: `STATE.md`, `RETRY_LOG.md`, `DECISIONS.md`, `LEARNINGS.md`, `PHASE5_MEMORY_HINT`, `PHASE6_MEMORY_HINT`, and `SECURITY_MEMORY_HINT` are named consistently across templates, scripts, orchestrator rules, and verification commands.
