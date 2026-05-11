# 标准 AI 开发团队增强设计

**日期**：2026-05-11  
**状态**：已确认，待实施  
**基于**：claude-standard-dev-team v1.0（13 agents + 11 阶段工作流）

---

## 背景

现有系统已具备：13 个 agent 的完整团队、11 阶段工作流、任务级 Dev-QA Loop（最多 3 次重试）、需求自动拆解。

本次设计补齐 4 个实际缺口，不改变现有工作流结构。

---

## 需求

| # | 需求 | 当前缺口 |
|---|---|---|
| 1 | 跨项目知识库 | 每个项目从零开始，历史错误无法复用 |
| 2 | 按角色分配 Claude 模型 | 除 orchestrator 外，其余 agent 未指定模型 |
| 3 | 项目内智能迭代重试 | 重试是机械式"再做一次"，没有注入新信息 |
| 4 | 安装脚本 + 项目模板 | 依赖手工 cp，新项目无快速初始化机制 |

---

## 设计方案

### 1. 跨项目知识库

**存储位置**：`~/.claude/team-memory/`

```
~/.claude/team-memory/
├── MEMORY_INDEX.md
└── patterns/
    ├── backend-patterns.md
    ├── frontend-patterns.md
    ├── contract-patterns.md
    ├── qa-patterns.md
    ├── security-patterns.md
    └── deployment-patterns.md
```

**每条记录格式**：

```markdown
## [错误类型简称]
- 触发场景: [什么操作导致了这个错误]
- 错误表现: [QA/测试看到了什么]
- 解决方案: [有效的修复思路]
- 技术栈: [Express / FastAPI / Vue / ...]
- 出现次数: 1
- 最后更新: YYYY-MM-DD
```

**读取时机**：

| 阶段 | 读取文件 | 注入目标 |
|---|---|---|
| Phase 5 开始前 | `backend-patterns.md` + `contract-patterns.md` | backend-architect 任务指令头部 |
| Phase 6 开始前 | `frontend-patterns.md` + `deployment-patterns.md` | frontend-developer 任务指令头部 |
| Phase 7 开始前 | `security-patterns.md` | security-engineer 任务指令头部 |

**写入时机**：Phase 11 完成后，且 reality-checker 判决为 READY 时，orchestrator 扫描本项目的 `BACKEND_STATUS.md`、QA 失败记录、重试次数，提炼新模式追加到对应文件。若项目中途放弃或 reality-checker 未判决 READY，不写入。

**注入格式**：

```
[来自团队记忆库的警示]
⚠️ 本项目技术栈历史高频错误：
1. [错误简述] — 解决方案：[一句话]（出现N次）
---
[正式任务指令开始]
```

**裁剪规则**：orchestrator 读取项目 `CLAUDE.md` 中"技术栈"字段，与 patterns 文件中每条记录的 `技术栈:` 标签做字符串匹配，只注入匹配的条目。知识库超过 50 条时，取出现频次最高的 5 条 + 最近 15 条。

---

### 2. 按角色分配 Claude 模型

在每个 agent `.md` 文件的 frontmatter 加 `model:` 字段。

| 模型 | Agent | 理由 |
|---|---|---|
| `opus` | orchestrator | 多阶段调度，需要最强推理 |
| `opus` | software-architect | API/DB 契约是一切基础，出错代价最高 |
| `opus` | reality-checker | 最终验收官，判断需要严格 |
| `sonnet` | product-manager | 需求拆解，结构化写作 |
| `sonnet` | backend-architect | 复杂实现逻辑 |
| `sonnet` | frontend-developer | UI 实现 + 环境变量规范 |
| `sonnet` | database-optimizer | Schema 设计 + 索引推理 |
| `sonnet` | security-engineer | OWASP 扫描，需要专业判断 |
| `sonnet` | code-reviewer | 代码质量分析 |
| `sonnet` | devops-automator | Docker/CI 配置 |
| `sonnet` | ui-designer | 设计系统生成 |
| `haiku` | testing-evidence-collector | 按固定模板核查，结构已定义 |
| `haiku` | technical-writer | README/文档，格式化输出 |

实现：每个文件 frontmatter 新增一行 `model: <opus|sonnet|haiku>`，无逻辑改动。

---

### 3. 智能重试逻辑

替换 orchestrator Phase 5/6 中的 STEP 3 决策逻辑。

**三级重试树**：

```
FAIL
│
├─ 第1次重试
│   ├─ 查 team-memory/patterns/[对应分类].md
│   ├─ 找到相似错误 → 把"解决方案"追加到重试指令头部
│   └─ 未找到 → 只把 QA 反馈传回（行为与现在相同）
│   → 重试对应实现 agent
│
├─ 第2次重试
│   根据 QA 失败关键词判断失败类型：
│   ├─ "字段缺失"/"字段名不符" → 拉 software-architect 复查 API_CONTRACT
│   ├─ "路径硬编码"/"VITE_API_BASE" → 打回 frontend-developer + 附 TECH_SPEC 部署章节
│   ├─ "404"/"连接失败"/"服务未启动" → 拉 devops-automator 检查 start.sh
│   └─ 其他 → 只带 QA 反馈重试
│   → 把澄清结果 + QA 反馈一起传回实现 agent
│
└─ 第3次重试失败
    → 暂停
    → 向用户报告：[任务ID] + [3次失败的 QA 原因] + [已尝试的修复思路]
    → 等待用户介入
```

**orchestrator.md 改动量**：约 +80 行，只改 Phase 5/6 的 STEP 3 决策段，其余不动。

---

### 4. 安装脚本 + 项目模板

**新增文件**：

```
scripts/
├── install.sh              ← 装一次，把团队装进 ~/.claude/ + 初始化知识库骨架
└── team-init.sh            ← 每个新项目装一次，生成 CLAUDE.md + .claude/settings.json

templates/memory/
├── backend-patterns.md     ← 空白模板（含格式说明）
├── frontend-patterns.md
├── contract-patterns.md
├── qa-patterns.md
├── security-patterns.md
├── deployment-patterns.md
├── project-CLAUDE.md       ← 新项目 CLAUDE.md 模板
└── settings.json           ← 基础权限配置模板
```

**`install.sh` 逻辑**：
1. `cp agents/*.md ~/.claude/agents/`
2. `mkdir -p ~/.claude/team-memory/patterns`
3. 对每个 pattern 文件：若不存在则从 templates 复制（已存在则跳过，保护现有知识库）

**`team-init.sh` 逻辑**：
1. 若当前目录无 `CLAUDE.md`，从模板生成并替换项目名占位符
2. 若无 `.claude/settings.json`，从模板生成

**生成的 CLAUDE.md 模板内容**：

```markdown
# {{PROJECT_NAME}}

## 团队配置
本项目使用标准 AI 开发团队（13 agents）。
说"使用标准团队开发 [需求]"即可启动 orchestrator。

## 项目上下文
- 技术栈：[在此填写，orchestrator 用来筛选知识库]
- 部署环境：[在此填写]
```

---

## 完整变更清单

**新增文件（10个）**：
- `scripts/install.sh`
- `scripts/team-init.sh`
- `templates/memory/backend-patterns.md`
- `templates/memory/frontend-patterns.md`
- `templates/memory/contract-patterns.md`
- `templates/memory/qa-patterns.md`
- `templates/memory/security-patterns.md`
- `templates/memory/deployment-patterns.md`
- `templates/memory/project-CLAUDE.md`
- `templates/memory/settings.json`

**修改文件（13个）**：
- `agents/orchestrator.md`：新增知识库读写逻辑 + 三级重试逻辑（约 +80 行）
- `agents/software-architect.md`：加 `model: opus`
- `agents/reality-checker.md`：加 `model: opus`
- `agents/product-manager.md`：加 `model: sonnet`
- `agents/backend-architect.md`：加 `model: sonnet`
- `agents/frontend-developer.md`：加 `model: sonnet`
- `agents/database-optimizer.md`：加 `model: sonnet`
- `agents/security-engineer.md`：加 `model: sonnet`
- `agents/code-reviewer.md`：加 `model: sonnet`
- `agents/devops-automator.md`：加 `model: sonnet`
- `agents/ui-designer.md`：加 `model: sonnet`
- `agents/testing-evidence-collector.md`：加 `model: haiku`
- `agents/technical-writer.md`：加 `model: haiku`

**不动文件**：`WORKFLOW.md`、`README.md`、`INSTALL.md`

---

## 成功标准

| 验证项 | 检查方式 |
|---|---|
| 知识库初始化 | `install.sh` 运行后 `~/.claude/team-memory/patterns/` 有 6 个文件 |
| 模型分配生效 | 各 agent frontmatter 有 `model:` 字段 |
| 重试注入知识 | Phase 5/6 FAIL 第1次时，orchestrator 日志显示已查询知识库 |
| 新项目初始化 | `team-init.sh` 运行后当前目录有 `CLAUDE.md` + `.claude/settings.json` |
| 知识写入 | 项目 Phase 11 完成后，`backend-patterns.md` 有新增条目 |
