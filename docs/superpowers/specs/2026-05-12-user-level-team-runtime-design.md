# 用户级 AI 团队运行机制增强设计

**日期**：2026-05-12  
**状态**：已确认，待实施计划  
**方案选择**：A2 增强版（纯 Claude Code / Markdown / Bash）  
**基于**：`2026-05-11-team-enhancement-design.md`

---

## 背景

现有标准 AI 开发团队已经具备 13 个 agent、11 阶段工作流、任务级 Dev-QA Loop、需求拆解与基础打回机制。2026-05-11 的设计进一步规划了跨项目记忆库、模型分配、智能重试和安装脚本。

本次增强把目标扩展为用户级团队运行机制：

- 在系统用户级别安装整套 AI 团队，新项目自动加载团队机制。
- 支持较长开发流程中断后恢复，而不是依赖单次会话完整跑完。
- 自动拆解需求、开发、验证、失败打回、再次验证。
- 多 agent / 多模型按角色协作，并在失败时拉对应专家介入。
- 建立项目级日志和用户级长期记忆，避免相同错误反复出现。

---

## 设计原则

1. **不引入后台服务**：第一版不做 daemon、数据库、队列或 Web 控制台。
2. **文件即状态**：用 Markdown 文件记录 Phase、任务、失败、决策和经验。
3. **Markdown 即协议**：orchestrator 和各 agent 通过固定文档结构传递上下文。
4. **成功后再沉淀**：只有最终验收 READY 的项目经验才能写入用户级长期记忆。
5. **有限自动化**：自动重试有上限，避免长时间运行变成无限消耗。
6. **一次初始化后自动加载**：新项目仍需执行一次 `team-init.sh`；之后 Claude Code 会通过项目 `CLAUDE.md` 和用户级 agents 自动获得团队机制。

---

## 总体架构

系统分三层：

| 层级 | 位置 | 职责 |
|---|---|---|
| 用户级团队层 | `~/.claude/agents/`、`~/.claude/team-memory/` | 跨项目共享 agent 和长期错误模式 |
| 项目级运行层 | 当前项目 `CLAUDE.md`、`.claude/settings.json`、`.claude/team-state/` | 保存项目上下文、运行状态、失败日志、临时经验 |
| orchestrator 控制层 | `agents/orchestrator.md` | 调度 Phase、读取状态、调用 agent、执行重试、写回记忆 |

“长时间运行”定义为可恢复的工作流状态机：会话中断后，orchestrator 通过 `.claude/team-state/STATE.md` 和项目文档恢复到下一步动作。

---

## 核心组件

### 1. 用户级团队安装

新增或完善 `scripts/install.sh`：

1. 将 `agents/*.md` 安装到 `~/.claude/agents/`。
2. 初始化 `~/.claude/team-memory/patterns/`。
3. 从 `templates/memory/*-patterns.md` 复制 6 类记忆模板。
4. 已存在的记忆文件不覆盖，保护历史经验。
5. agent 文件允许覆盖，用于升级团队 prompt。

### 2. 项目初始化

新增或完善 `scripts/team-init.sh`：

1. 若当前目录没有 `CLAUDE.md`，从模板生成。
2. 若当前目录没有 `.claude/settings.json`，从模板生成。
3. 创建 `.claude/team-state/`，并补齐缺失状态文件。
4. 重复运行不覆盖已有项目上下文和状态。

项目状态文件：

```
.claude/team-state/
├── STATE.md
├── RETRY_LOG.md
├── DECISIONS.md
└── LEARNINGS.md
```

文件职责：

| 文件 | 职责 |
|---|---|
| `STATE.md` | 当前 Phase、当前任务、上次 agent、上次结果、下一步动作 |
| `RETRY_LOG.md` | 每次 FAIL 的原因、重试次数、打回目标、最终结果 |
| `DECISIONS.md` | 用户确认过的 PRD 范围、API 契约、关键取舍 |
| `LEARNINGS.md` | 项目内临时经验，最终 READY 后再沉淀到用户级记忆 |

### 3. 用户级记忆库

用户级记忆库继续采用 6 类 Markdown 文件：

```
~/.claude/team-memory/patterns/
├── backend-patterns.md
├── frontend-patterns.md
├── contract-patterns.md
├── qa-patterns.md
├── security-patterns.md
└── deployment-patterns.md
```

每条记录格式：

```markdown
## [错误类型简称]
- 触发场景: [什么操作导致了错误]
- 错误表现: [QA/测试/审查看到了什么]
- 解决方案: [最终验证有效的修复思路]
- 技术栈: [Express / FastAPI / React / Vue / ...]
- 出现次数: 1
- 最后更新: YYYY-MM-DD
```

### 4. orchestrator 状态机

orchestrator 增强点：

1. 每个 Phase 开始和结束时更新 `.claude/team-state/STATE.md`。
2. Phase 1 / Phase 2 人工确认点写入 `DECISIONS.md`。
3. Phase 5 / Phase 6 的 QA FAIL 写入 `RETRY_LOG.md`。
4. Phase 4.9 / Phase 5.9 / Phase 7 前读取用户级记忆并注入任务指令。
5. Phase 10 READY 后进入 Phase 11.5，把有效经验写回用户级记忆库。
6. 启动时优先读取 `STATE.md`，根据 `Next Action` 恢复运行。

### 5. agent 模型分配

所有 agent frontmatter 必须包含 `model:`：

| 模型 | agent |
|---|---|
| `opus` | orchestrator、software-architect、reality-checker |
| `sonnet` | product-manager、backend-architect、frontend-developer、database-optimizer、security-engineer、code-reviewer、devops-automator、ui-designer |
| `haiku` | testing-evidence-collector、technical-writer |

---

## 数据流

### 安装流

1. 用户克隆仓库。
2. 在仓库根目录执行 `bash scripts/install.sh`。
3. agents 安装到 `~/.claude/agents/`。
4. 记忆模板初始化到 `~/.claude/team-memory/patterns/`。

### 新项目初始化流

1. 用户进入新项目目录。
2. 执行 `bash /path/to/claude-standard-dev-team/scripts/team-init.sh`。
3. 生成项目 `CLAUDE.md`、`.claude/settings.json`、`.claude/team-state/`。
4. 用户填写 `CLAUDE.md` 中的技术栈和部署环境。
5. 用户在 Claude Code 中说“使用标准团队开发 [需求]”。

### 开发验证流

1. Phase 1：product-manager 生成 PRD，用户确认后写入 `DECISIONS.md`。
2. Phase 2：software-architect 生成 API / DB / TECH_SPEC，用户确认后写入 `DECISIONS.md`。
3. Phase 3：orchestrator 拆分任务。
4. Phase 5 / Phase 6：实现 agent 开发，testing-evidence-collector 验证。
5. PASS：任务标记完成，更新 `STATE.md`。
6. FAIL：记录到 `RETRY_LOG.md`，进入三级重试。

### 自动迭代闭环

Phase 5 / Phase 6 的 FAIL 处理：

| 失败次数 | 动作 |
|---|---|
| 第 1 次 | 查用户级记忆库，匹配技术栈和错误关键词，把历史解决方案注入给开发 agent |
| 第 2 次 | 按失败类型拉专业 agent 协助澄清，再打回开发 agent |
| 第 3 次 | 暂停，生成卡点报告，等待用户介入 |

第 2 次失败的分流规则：

| 失败类型 | 协作 agent |
|---|---|
| 字段缺失、字段名不符、契约不一致 | software-architect |
| 路径硬编码、部署前缀、服务启动失败 | devops-automator / frontend-developer |
| 安全漏洞、鉴权问题、敏感信息泄露 | security-engineer |
| UI 视觉、设计系统、动态内容绑定 | ui-designer / frontend-developer |
| 其他 | 原开发 agent，附完整 QA 反馈 |

### 经验沉淀流

1. Phase 10 reality-checker 判定 READY。
2. Phase 11 technical-writer 生成文档。
3. Phase 11.5 读取 `RETRY_LOG.md`、`LEARNINGS.md`。
4. 提炼已经验证有效的错误模式。
5. 写入对应的用户级 pattern 文件。
6. 若同名条目已存在，只更新出现次数和最后更新时间。

若 Phase 10 为 NEEDS WORK、用户中止、项目未完成，不写入用户级记忆库。

---

## 恢复机制

`STATE.md` 建议格式：

```markdown
# Team State

- Current Phase: Phase 5
- Current Task: BE-003
- Last Agent: backend-architect
- Last Result: QA_FAIL
- Retry Count: 1
- Next Action: Retry backend-architect with memory hint
- Updated At: 2026-05-12
```

orchestrator 启动规则：

1. 没有 `STATE.md`：从 Phase 0 / Phase 1 开始。
2. Phase 未完成：读取 `Next Action` 继续。
3. 卡在人工确认点：提示用户确认继续。
4. Retry 已超限：先展示卡点报告，不自动继续。
5. 状态文件损坏或字段缺失：回退到项目 docs 和 tasklist 推断当前阶段，并提示用户确认。

---

## 错误处理

### 安装错误

- 找不到 `agents/` 或 `templates/memory/` 时，`install.sh` 失败并提示从仓库根目录运行。
- 已有记忆文件不覆盖。
- agent 文件可覆盖，用于升级用户级团队。

### 项目初始化错误

- 已有 `CLAUDE.md` 跳过。
- 已有 `.claude/settings.json` 跳过。
- 已有 `.claude/team-state/` 不清空，只补齐缺失文件。

### 记忆读取错误

- 记忆库不存在、为空或无法匹配技术栈时，不阻塞流程。
- 格式不完整的条目跳过。
- 注入条目数量限制为高频前 5 条 + 最近 10 条，总数不超过 15 条。

### 开发失败错误

- 单任务最多 3 次失败处理。
- 超限后暂停，报告任务 ID、3 次失败原因、已尝试修复思路、建议人工介入点。

### 记忆写回保护

- 只有 READY 项目写入用户级记忆。
- 写回内容必须包含最终验证有效的解决方案。
- 同名模式不重复追加，只更新出现次数和最后更新时间。

---

## 实施范围

本设计将在 2026-05-11 原计划基础上新增以下范围：

1. `team-init.sh` 额外生成 `.claude/team-state/` 4 个状态文件。
2. 新增 `templates/memory/team-state/*.md` 作为 4 个状态文件的模板。
3. `orchestrator.md` 增加状态更新、恢复入口、卡点报告和 Phase 11.5 写回规则。
4. `INSTALL.md` 说明用户级安装和新项目初始化流程。

仍然不做：

- 后台常驻进程。
- 本地数据库。
- Web 控制台。
- 自动调用真实外部 CI 服务。
- 无限自动重试。

---

## 验证标准

| 验证项 | 检查方式 |
|---|---|
| 脚本语法正确 | `bash -n scripts/install.sh scripts/team-init.sh` |
| 用户级记忆初始化 | `install.sh` 后存在 6 个 pattern 文件 |
| 安装幂等 | 重复运行 `install.sh` 不覆盖已有 pattern 内容 |
| 项目初始化 | `team-init.sh` 后存在 `CLAUDE.md`、`.claude/settings.json`、`.claude/team-state/*.md` |
| 初始化幂等 | 重复运行 `team-init.sh` 不覆盖已有项目状态 |
| 模型分配 | 所有 `agents/*.md` frontmatter 含 `model:` |
| 状态机规则 | `orchestrator.md` 包含状态读取、Phase 更新、恢复和卡点报告规则 |
| 智能重试 | `orchestrator.md` 包含 Phase 5 / Phase 6 三级重试 |
| 记忆注入 | `orchestrator.md` 包含 Phase 4.9 / Phase 5.9 / Phase 7 前读取记忆 |
| 记忆写回 | `orchestrator.md` 包含 Phase 11.5，且只在 READY 后写回 |

---

## 成功标准

1. 用户只需一次 `install.sh`，即可在用户级安装完整 AI 团队。
2. 任意新项目只需一次 `team-init.sh`，即可具备团队运行上下文。
3. orchestrator 能通过项目状态文件恢复未完成流程。
4. QA 失败会自动记录、自动打回、自动升级到对应专家协作。
5. 最终 READY 的项目能把有效经验沉淀到用户级记忆库。
6. 下一个项目能读取历史错误模式，减少重复犯错。
