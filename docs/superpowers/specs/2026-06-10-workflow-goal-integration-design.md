# Workflow & /goal 能力集成设计

> **状态**：已确认待实施
> **日期**：2026-06-10
> **关联会话**：brainstorming(808db5c0)
> **作者**：software-architect

---

## 背景与目标

给现有 AI 团队（13 agent + orchestrator）接入两项 Claude Opus 4.8 新能力：

- **Workflows**：确定性 JS 脚本化的多智能体并行编排引擎。支持并行子代理、独立验证、可恢复执行，解决"单上下文溢出"问题。
- **/goal**：目标锚定能力，防止长任务出现"目标漂移"。

### 核心方针：互补挂载 + 规则提示

orchestrator 仍是总指挥和默认路径，**只在特定高并发 / 大规模环节"下沉"到 workflow 引擎**，跑完结果回 orchestrator 继续验收。

- **不重写**任何现有 agent。
- **不改**13 个 agent 的契约。
- 全程契合项目 CLAUDE.md 的「化繁为简 / 手术式改动 / 安全确认点」原则。

### 铁律：subagent 不能嵌套派发

workflow 由**主会话（orchestrator 所在上下文）**调用，subagent 自身不派发 workflow，因此不违反此铁律。

---

## 第 1 段 · 触发识别规则与默认阈值

在 `agents/orchestrator.md` 的 **Step 1（需求理解与分类）之后**新增「Workflow 适用性扫描」小节。命中任一条件即**暂停并提示用户是否启用**。

### 默认阈值表（可调）

| 触发条件 | 默认阈值 | 典型场景 |
|---|---|---|
| 独立可并行任务数 | ≥5 个 | Phase5 多接口、Phase6 多页面 |
| 全仓扫描范围 | ≥50 个文件 | Audit、安全审计 |
| 同质重复操作 | ≥20 处 | 批量迁移 / 改名 / 加注释 |
| 需对抗式独立验证 | 任意命中 | 高风险发现多 agent 投票确认 |
| 预估时长 | >30 分钟 / 单上下文可能溢出 | 数百文件迁移 |

### 统一提示话术

```
🔍 检测到此任务适合启用 Workflow 并行引擎：
   命中条件：{条件}
   预计派发：~{N} 个并行 agent（复用现有团队成员）
   ⚠️ 成本提示：token 消耗显著高于常规串行模式
   是否启用？(y / N，默认 N 走常规 orchestrator 流程)
```

### 底线

用户不点头则**完全走原有 markdown 流程，零行为变化**。

---

## 第 2 段 · Workflow 下沉挂载点（仅 5 处）

每处都遵循统一闭环：**orchestrator 提示 → 用户确认 → 跑 workflow → 结果回 orchestrator 继续验收**。

| 挂载点 | 现状（串行） | 下沉后（并行） | 复用 agent |
|---|---|---|---|
| 完整项目 Phase5 后端实现 | 逐接口 Dev-QA Loop | pipeline：每接口独立穿过「实现→验证」 | backend-architect + testing-evidence-collector |
| 完整项目 Phase6 前端实现 | 逐页面 Loop | 每页面一条流水线 | frontend-developer + testing-evidence-collector |
| 模板 B Audit 全仓审查 | 单 agent 顺序 | 多维度并行（bug / 性能 / 安全 / 契约）→ 每发现对抗式验证 | code-reviewer + security-engineer |
| Phase7 安全审计 | 单次扫描 | 按模块 / 认证 / 输入校验并行 → 投票确认高危 | security-engineer |
| 大规模迁移 / 重构（新增场景） | 无专门模板 | 发现改动点 → 每处独立 worktree 改 → 验证 | 对应实现 agent |

### 关键约束（必须落实于实现）

1. **保留 Dev-QA Loop 语义**：workflow 脚本强制保留「实现 → verification → testing-evidence PASS/FAIL → 重试 ≤2」语义，只是把串行变并行。
2. **复用现有 agent**：workflow 用 `agentType` 指向现有 13 个 agent，**不新建 agent、不改契约**。
3. **安全确认点不下放**：部署 / 热部署 / 删除 / push 等不可逆操作**永远不进 workflow 并行**，仍由 orchestrator 串行把关。
4. **状态机仍归 orchestrator**：workflow 结果（PASS/FAIL 清单）回 orchestrator，由它写 `team-state/STATE.md` 并最终验收。

---

## 第 3 段 · /goal 目标锚定接入

轻量、不改 agent。

| 环节 | 接入动作 |
|---|---|
| 任务启动时 | 若判定为长链路任务（完整项目 / 大规模迁移 / 多轮 Audit-Fix），把用户原始需求一句话固化为锚定目标，写入 `team-state/GOAL.md`（新增）+ 设定可选 token 预算 |
| 每个 Phase 边界 | 进入下一 Phase 前对照 `GOAL.md` 自检"当前产出是否仍服务于原始目标"，偏离→暂停报告 |
| workflow 下沉时 | 把锚定目标 + 完成条件作为 workflow 脚本的**硬性终止条件**，避免误判"已完成" |
| 重试 / 卡点时 | `RETRY_LOG` 卡点报告附带"距离锚定目标还差什么" |

### GOAL.md 极简格式

```markdown
# 锚定目标
- 原始需求: {用户一句话}
- 完成条件: {可验证硬性标准，如"所有 tasklist [x] 且 npm test 全绿"}
- Token 预算: {可选，默认不限}
- 设定于: {日期}
```

### YAGNI 边界

- `/goal` **仅对长链路任务启用**，单任务 / Hotfix / 纯文档不引入。
- token 预算**默认不限**，用户主动说才设。

---

## 第 4 段 · 落地改动清单（文件级，全部手术式增量）

| 文件 | 改动类型 | 内容 |
|---|---|---|
| `agents/orchestrator.md` | 编辑·增 | ① Step1 后新增「Workflow 适用性扫描」小节；② 5 个挂载点各加"可下沉 workflow"分支；③ 新增「/goal 锚定」小节；④ 人工确认点列表加一条"Workflow 启用确认" |
| `templates/workflows/team-dev-loop.workflow.js` | 新增 | 后端 / 前端 Dev-QA Loop 的 pipeline 脚本模板（保留实现→验证→重试语义） |
| `templates/workflows/audit-scan.workflow.js` | 新增 | Audit 多维并行 + 对抗式验证脚本模板 |
| `.claude/team-state/GOAL.md` + `templates/memory/team-state/GOAL.md` | 新增 | 锚定目标文件 + 模板占位 |
| `WORKFLOW.md` 或 `docs/USAGE.md` | 编辑·增 | 补一节"何时启用 Workflow/Goal、成本提示、如何手动触发" |
| `CHANGELOG.md` / `VERSION` | 编辑 | 记一个新版本 |

### ✅ 已确认：workflow 模板接入 install 分发

针对上表 `templates/workflows/` 这一行的分发策略：

- **决策（2026-06-10，用户确认）**：**接入 install 分发**，与现有 `templates/memory/*` 一致。
- **落地**：`scripts/install.sh` / `scripts/install.ps1` 通配复制 `templates/workflows/*.workflow.js` 到用户级目录 `~/.claude/team-workflows/`（幂等）。

### 明确不做（YAGNI）

1. **不做 ultracode 式全自动**——要的是提示版（命中阈值才提示，用户点头才跑）。
2. **不为简单任务 / Hotfix 引入** workflow 或 goal。
3. **不新增 agent、不改现有 agent 契约**。
4. **workflow 脚本只覆盖那 5 个挂载点**，不追求全流程脚本化。

---

## 总览：本设计的不变量

- orchestrator 是默认路径与总指挥，workflow 仅是可选的"并行下沉"。
- 13 个 agent 的契约零改动，workflow 仅以 `agentType` 复用它们。
- Dev-QA Loop 语义在并行化后完整保留。
- 所有不可逆操作 / 安全确认点不下放，永远由 orchestrator 串行把关。
- 状态机与最终验收始终归 orchestrator。
- 用户不点头则零行为变化。
