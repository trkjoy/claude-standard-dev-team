# 把 Loop Engineering（循环工程）落进标准 AI 开发团队 —— 改造蓝图

> 版本: 1.0 | 日期: 2026-06-23
> 输入依据: `docs/LOOP_ENGINEERING_RESEARCH.md`（调研报告）+ `CLAUDE.md` + `~/.claude/agents/orchestrator.md` + 团队 15 名 agent 定义 + `~/.claude/team-memory/patterns/` 知识库
> 本文档只产出蓝图，不改动任何现有文件。遵循项目 CLAUDE.md 的「化繁为简 / 手术式改变」原则——优先用现有角色 + skill/hook 实现，最小化新增。

---

## 0. 一句话结论

当前标准团队**已经是一套相当成熟的早期 Loop Engineering 实践**：它天然具备 goal 循环、maker/checker 分离、确定性契约、有界重试和自我改进环的雏形。真正缺的不是"循环"本身，而是：**非人触发的循环类型（cron/hook/heartbeat）、把"确定性验证优先"显式写进流程的硬 gate、自动循环的成本闸、以及把 trace 分析自动化的闭环**。本蓝图给出 **14 项可落地改造**，其中 P0 共 6 项均为"改文档/加配置"级低成本动作。

---

# 第一部分：现状映射 —— 当前团队 ≈ 早期 Loop Engineering

## 1.1 与调研报告"五件套 + 记忆层"逐项映射

| Osmani 五件套 + 记忆 | 作用 | 当前团队对应物 | 成熟度 |
|---|---|---|---|
| Scheduled Automations（定时触发分诊） | 发现工作、决定何时交给谁 | **无定时**；目前 100% 由用户在主会话手动触发，orchestrator Step 1 分类 ≈ 分诊（但仅人触发那一刻） | **缺失（定时）/ 部分（分诊）** |
| Git Worktrees（并行隔离） | 并行 agent 互不污染 | 无 worktree；并行靠 `/dispatching-parallel-agents` + Workflow 引擎在同一仓内分任务，subagent 各持独立上下文 | **部分**（上下文隔离有，文件级隔离无） |
| Skills（项目知识库） | 跨轮复用项目知识 | `~/.claude/team-memory/patterns/`（6 类 patterns）+ `MEMORY_HINT` 注入 Phase 4.9/5.9/6.5 等 | **已具备** |
| Plugins / MCP Connectors | 接入真实外部工具 | Bash/Read/Write/Glob/Grep + testing-evidence-collector 的 curl/Playwright；MCP 已接入（如 pencil） | **部分** |
| Sub-agents（maker/checker 分离） | 生产者与验收者不可合并 | **完全具备**：实现 agent（maker）与 `testing-evidence-collector`（checker）严格分离，且 checker"对幻想式汇报过敏、默认 FAIL" | **已具备（强项）** |
| External State（外部状态/检查点） | 跨轮进度持久化 | `.claude/team-state/`：STATE.md / RETRY_LOG.md / DECISIONS.md / LEARNINGS.md / GOAL.md，有断点续跑规则 | **已具备** |

## 1.2 与"四类循环"映射

| 循环类型 | 触发方式 | 当前团队对应物 | 成熟度 |
|---|---|---|---|
| **Goal（目标循环）** | 迭代至成功条件 | Dev-QA Loop（实现→QA→打回，最多 3 次）+ `/goal` 锚定 + reality-checker 终验 | **已具备（核心强项）** |
| **Hook（事件钩子）** | PR push / CI 失败 触发 | **无**。修复全靠用户手动发起 Hotfix 模板 | **缺失** |
| **Cron（定时循环）** | 固定时间跑 | **无**。无任何定时巡检/夜间跑 | **缺失** |
| **Heartbeat（心跳循环）** | 短间隔持续运行 | **无**。长任务无心跳，靠 STATE.md 断点续跑（被动恢复，非主动心跳） | **缺失** |

## 1.3 与"验证器即承重墙 / 验证器是瓶颈"映射

| 调研论断 | 当前团队对应物 | 成熟度 |
|---|---|---|
| maker/checker 必须分离 | 实现 agent vs testing-evidence-collector 物理分离，模型不同（opus 实现 / sonnet 取证） | **已具备** |
| 确定性验证优先于 LLM 判断 | **部分**：已有 `/verification-before-completion`（要求跑真实命令）、`/test-driven-development`（RED 先行）、Phase 9 部署路径硬 gate、契约 diff（QA 比对字段/错误码）。但**"确定性优先"未作为一条贯穿全流程的显式总则写出**，散落在各 Phase | **部分** |
| 退出条件靠确定性检查而非 LLM 自评 | reality-checker 的 READY 条件含"npm test/pytest 全绿""所有 tasklist [x]"（确定性）+ 截图（取证 LLM） | **已具备** |
| 防 maker/checker 合谋 | checker 默认 FAIL、要求证据、独立上下文，天然抗合谋 | **已具备（强项）** |

## 1.4 与"成本/失控护栏"映射

| 调研风险 | 当前团队对应物 | 成熟度 |
|---|---|---|
| Loopmaxxing（无限循环烧钱） | 重试上限（任务级 3 次 / 安全·Review 2 次 / reality-checker 1 次）+ 超限即转人工卡点 | **部分**（有轮次上限，无 token/时间预算上限） |
| Token 成本失控 | `/goal` 的 Token 预算字段（默认不限，用户主动才设）；Workflow 启用前有成本提示 | **部分**（有提示无强制熔断） |
| Slop machine（松标准开放循环） | 契约驱动（API_CONTRACT/DB_SCHEMA 是确定性紧标准）+ 人工确认点 | **已具备** |

## 1.5 与"最外层自我改进环"映射

| 调研论断 | 当前团队对应物 | 成熟度 |
|---|---|---|
| 分析 agent 读 trace、提炼模式、回写 harness | Phase 11.5 / 11.5-F 派发 `kb-curator` 把 RETRY_LOG/LEARNINGS 写回 patterns | **部分** |
| 反向修订 prompt/工具/评分标准 | **无**：当前只回写"知识条目"供 MEMORY_HINT 读取，**从不反向修改 agent 提示词或验收标准** | **缺失** |
| trace 分析自动化 | **无**：kb-curator 仅在 READY/终态被 orchestrator 手动派发，且筛选逻辑是规则化提炼，不做"反复出现的失败模式"统计 | **缺失（自动化）/ 部分（写回）** |

## 1.6 成熟度总览

- **已具备（强项，可作为卖点）**：goal 循环、maker/checker 分离、外部状态持久化、契约驱动紧标准、确定性退出条件、知识写回。
- **部分**：确定性验证优先（未成总则）、并行隔离、成本护栏、自我改进写回。
- **缺失**：cron 循环、hook 循环、heartbeat、trace 分析自动化、反向修订 harness。

> 诚实标注：上述"已具备"判断基于文档定义；其在真实长链路项目中的稳定性属**待验证假设**，建议 P0 落地后用一个真实项目跑通验证。

---

# 第二部分：缺口与改造方案（蓝图重点）

> 设计取向：**最小改动**。能用"现有角色 + 一段 skill/hook + 一个状态字段"解决的，绝不新增 agent。下文每项标注【确定可行】或【待验证假设】。

## 改造一：循环类型补全（cron / hook / heartbeat）

当前只有人触发的 goal 循环。补全另外三类，全部落在 **orchestrator 之外**（用 Claude Code 原生能力 + 一个极薄的 workflow 脚本触发），避免污染"orchestrator 必须 top-level"的铁律。

### 1A. Cron 循环（定时巡检 / 夜间跑）【确定可行（机制）/ 待验证（CronCreate API 细节）】

- **接入点**：调研 §6.1 的 Cron 定时 / GitHub Actions 无 TTY 一次性进程。
- **做什么**：新增一个"夜间 Audit 巡检"定时任务，每天固定时间以无 TTY 方式跑 Audit 模板（code-reviewer + security-engineer），把 Blocker 写入 `docs/NIGHTLY_AUDIT.md`，**不自动修复**，第二天人来看。
- **改哪个文件 / 加什么机制**：
  - 新增 `~/.claude/team-workflows/nightly-audit.workflow.js`（复用现有 audit-scan 逻辑，只加"无确认、只读不改、输出报告"约束）。
  - 新增 `.github/workflows/nightly-audit.yml`（cron 表达式触发，`claude -p` 无交互模式跑上面脚本）。
  - orchestrator.md 新增一节「定时循环约定」：声明 cron 循环**只读不改、不触发任何安全确认点动作、产物只写 docs/NIGHTLY_AUDIT.md**。
- **验收标准**：定时任务能在无人值守下产出当日 Audit 报告；report 中 Blocker 计数与手动 Audit 一致（抽样核对）。
- **风险**：CronCreate / GitHub Actions 配额与凭据管理；无 TTY 下交互式确认点会卡死——故强制"只读不改"规避。

### 1B. Hook 循环（CI 失败 / PR push 触发自动修复）【确定可行（PreToolUse/事件 hook）/ 待验证（CI 回灌触发链）】

- **接入点**：调研 §6.1 Hooks（`PreToolUse` 等生命周期钩子）+ 事件触发。
- **做什么（两个层次，分阶段上）**：
  - **轻量层（P1）**：CI 失败时，hook 自动收集失败日志写入 `.claude/team-state/CI_FAILURE.md`，并在下次会话开场把它作为 Hotfix 输入提示给 orchestrator（半自动，人确认后才修）。
  - **重度层（P2）**：CI 失败直接触发 Hotfix workflow 自动修复（必须带成本闸 + 只在分支跑 + 修完发 PR 等人 review，绝不自动合并）。
- **改哪个文件 / 加什么机制**：
  - 新增 `~/.claude/hooks/`（若无）下的 hook 配置，或在 `settings.json` 注册 `PreToolUse`/事件 hook。
  - 重度层复用现有 Hotfix 模板，包装成 `ci-hotfix.workflow.js`。
- **验收标准**：CI 失败后 5 分钟内 `CI_FAILURE.md` 生成且含可定位的失败摘要；重度层修复产出的 PR 必通过原失败的那条 CI 检查（确定性 gate）。
- **风险**：自动修复可能"为了让 CI 绿而绕过测试"——必须用确定性 gate（原失败用例必须真 GREEN）+ code-reviewer 增量审查兜底。

### 1C. Heartbeat（长任务心跳）【确定可行（低成本）】

- **接入点**：调研 §3.2 心跳循环 + 现有 STATE.md 断点续跑。
- **做什么**：把"被动断点续跑"升级为"主动心跳"——长链路任务每个 Phase 边界写一次心跳时间戳，超过阈值（如 30 分钟无心跳）判定为"卡死/挂起"，自动转人工卡点而非静默空耗。
- **改哪个文件 / 加什么机制**：
  - `STATE.md` 写入格式新增一行 `- Heartbeat At: {时间戳}`，orchestrator「状态写入时机」一节补一条"每个 Phase 边界更新 Heartbeat At"。
  - 恢复规则新增一条：`恢复时若 (now - Heartbeat At) > 阈值 且 Last Result=RUNNING → 判定挂起，展示卡点报告不自动续跑`。
- **验收标准**：人为制造一次"中途中断"，恢复时能识别出心跳超时并提示，而非误以为仍在运行。
- **风险**：极低。纯状态字段，不改循环行为。

## 改造二：验证器强化 —— 把"确定性验证优先"写成总则【确定可行】

调研核心论断"verifier is the bottleneck"已被三票核实，是改造的最高优先方向之一。当前确定性验证散落各 Phase，需提升为贯穿全流程的**显式总则**，并明确哪些环节是**强制确定性 gate**、哪些保留取证型 LLM 验证。

- **做什么**：在 orchestrator.md 新增一节「验证器分层总则（确定性优先）」，列出验证手段优先级表，并标注每个环节的 gate 类型。

| 环节 | 验证类型 | gate 性质 |
|---|---|---|
| 编译 / 类型检查 / lint | 确定性 | **强制硬 gate**（不绿不准声明完成） |
| 单元/集成/E2E 测试（RED→GREEN） | 确定性 | **强制硬 gate** |
| 契约 diff（路径/字段名/错误码 vs API_CONTRACT） | 确定性（可脚本化 diff） | **强制硬 gate**，建议补一个 `contract-diff` 检查脚本把它从"QA 肉眼比对"升级为机器比对 |
| 部署路径前缀检查（Phase 9 四项） | 确定性 | **强制硬 gate**（已有） |
| UI 视觉 / 交互体验 / 需求符合度 | 取证型 LLM（testing-evidence-collector 截图） | 保留 LLM 验证，但**必须附确定性证据**（接口响应/测试输出），无证据倾向 FAIL（已有此约束） |
| 代码可维护性 / 风格 | LLM（code-reviewer） | 保留 LLM 验证 |

- **改哪个文件 / 加什么机制**：
  - orchestrator.md 新增「验证器分层总则」一节，并在 Step 3 STEP C 引用它。
  - 新增 `scripts/contract-diff.{sh,ps1}`（可选 P1）：对实现产出的路由表 vs API_CONTRACT.md 做机器 diff，把契约一致性从 LLM 比对降为确定性 gate。
- **防 maker/checker 合谋的补强**：在 testing-evidence-collector.md 已有"默认 FAIL/要证据"基础上，明确**checker 永远不得复用 maker 的自评结论作为证据**（只认它自己跑出来的命令输出）。这条目前隐含，建议显式写出。
- **验收标准**：任一硬 gate 未绿时，流程**不允许**进入下一 Phase（即使 LLM 声称完成）。
- **风险**：低。本质是把已有实践提炼成总则 + 补一个 diff 脚本。

## 改造三：成本闸（防 loopmaxxing）—— 把"重试上限"扩成"循环预算治理"【确定可行】

调研 §5 头号风险是 token 失控。当前有轮次上限但无 token/时间预算的强制熔断。

- **做什么**：把现有"重试上限"扩展为三维预算（轮次 / token / 时间），并定义退出条件、失控熔断、人工确认点。**仅对自动循环（cron/hook/无人值守 workflow）强制；人主导的串行流程沿用现有轮次上限即可。**

| 预算维度 | 默认上限（建议，可配） | 触发动作 |
|---|---|---|
| 轮次（per task） | 沿用现有：3 / 2 / 1 | 超限转人工卡点（已有） |
| Token（per 循环会话） | 自动循环必填，无默认；人主导默认不限 | 超 80% 预警写 STATE.md；超 100% 硬熔断停循环 |
| 时间（per 循环会话） | 自动循环默认 60 分钟 | 超时熔断 + 写卡点报告 |
| 无进展检测 | 连续 2 轮"同一错误/无 diff 进展" | 判 loopmaxxing，提前熔断（不等耗满预算） |

- **退出/熔断条件（显式）**：达成确定性完成条件（所有硬 gate 绿）→ 正常退出；任一预算维度耗尽 / 无进展检测命中 → 熔断退出并写 `RETRY_LOG.md` + `BUDGET_BURN.md`。
- **改哪个文件 / 加什么机制**：
  - `GOAL.md` 格式新增 `- Token 预算` 已有，**新增** `- 时间预算` 与 `- 无进展熔断: on/off`。
  - orchestrator.md「重试总规则」表下新增「循环预算治理」小节，自动循环的 workflow 脚本读取这些预算并自带熔断（与现有"workflow 自带重试不叠加 orchestrator 重试"一致）。
  - 自动循环（cron/hook）的 workflow 脚本里硬编码读取预算并在每轮检查。
- **验收标准**：构造一个"故意不收敛"的任务交给自动循环，能在 ≤2 轮无进展或时间/token 预算耗尽时熔断，不产生失控账单。
- **风险**：token 实时计量依赖运行环境是否暴露用量 —— **待验证假设**；若拿不到精确 token，用"轮次 + 时间 + 无进展检测"组合兜底（这三者确定可得）。

## 改造四：自我改进环升级 —— trace 分析自动化【部分确定 / 部分待验证】

当前 kb-curator 只在成功/终态被手动派发，且不做"反复出现模式"的统计，更不反向改 harness。调研 §3.3 外层环要求"分析 agent 定期读 trace、提炼模式、回头改 harness"。

- **做什么（分两层，倾向最小改动——复用 kb-curator + 加一个轻量分析触发，不急于新增 analysis-agent）**：
  - **L1（P1，确定可行）**：定时（cron）派发 kb-curator 做**跨项目 trace 聚合**——读取多个项目的 RETRY_LOG/LEARNINGS，统计"高频失败模式"（同一错误特征出现 ≥N 次），输出 `~/.claude/team-memory/HOTSPOTS.md`（只读报告，不改 prompt）。这是把"写回"升级为"统计 + 写回"。
  - **L2（P2，待验证假设）**：基于 HOTSPOTS.md，由人确认后，把高频失败对应的预防规则**反向写进对应 agent 的提示词或验收标准**（如某类字段错误反复出现 → 在 software-architect.md 契约校验清单加一条）。**反向改 harness 必须人确认，绝不自动改 agent 定义**（agent 定义是 harness 承重墙，自动改有失控风险）。
- **是否需要新增 analysis-agent**：**P1 不需要**，复用 kb-curator 加一个"聚合统计"模式即可（最小改动）。**仅当 L2 频繁触发、人工写回成为瓶颈时**，才考虑新增 `loop-analyst` 角色，定位为"只读 trace、产出改进建议、绝不直接改 harness"。当前蓝图建议先不新增。
- **改哪个文件 / 加什么机制**：
  - kb-curator.md 新增一个 `aggregate` 模式（输入多项目 RETRY_LOG，输出 HOTSPOTS.md），或新增一个 `/team-kb-aggregate` 命令。
  - cron 定时（如每周）触发该聚合。
- **验收标准**：聚合报告能正确识别出"出现次数 ≥N"的失败模式 top 列表；L2 写回后，同类失败在后续项目的复现率下降（**长期指标，待验证**）。
- **风险**：自动改 harness 是高风险（可能引入坏规则、与现有 prompt 冲突），故 L2 强制人确认；trace 跨项目聚合依赖各项目 team-state 路径规整 —— 待验证。

## 改造五：状态持久化评估【确定可行】

现有 `.claude/team-state/`（STATE/RETRY_LOG/DECISIONS/LEARNINGS/GOAL）对**人主导的 goal 循环**已足够支撑跨轮/跨会话。但要支撑**自动循环（cron/hook/无人值守）**，缺三样：

| 缺口 | 补什么 | 落点 |
|---|---|---|
| 心跳/挂起检测 | `STATE.md` 加 `Heartbeat At`（见改造 1C） | STATE.md 格式 |
| 预算消耗追踪 | 新增 `BUDGET_BURN.md`（记录本次循环已耗轮次/token/时间）（见改造三） | team-state/ |
| 自动循环的触发来源与边界 | 新增 `LOOP_CONTEXT.md`（记录本次循环由谁触发：cron/hook/人，允许做什么、禁止做什么——尤其禁止安全确认点动作） | team-state/ |
| 跨项目聚合源 | 约定各项目 team-state 路径可被聚合脚本枚举（HOTSPOTS 依赖） | 约定，非新文件 |

- **验收标准**：自动循环中断后恢复，能从 BUDGET_BURN + Heartbeat + LOOP_CONTEXT 完整还原"花了多少预算、是否挂起、本循环允许做什么"。
- **风险**：低。均为新增只读/追加状态文件，不动现有结构。

## 改造六：是否新增 agent 角色 —— 结论：P0/P1 阶段一个都不新增【确定可行】

| 候选新角色 | 是否需要 | 替代方案（最小改动） |
|---|---|---|
| `loop-orchestrator` | **不需要** | 现 orchestrator 已是循环编排核心；自动循环用极薄 workflow 脚本触发现有模板，不另设角色 |
| `verifier-gate` | **不需要** | 用改造二的"确定性 gate 总则" + 现有 testing-evidence-collector + 一个 contract-diff 脚本实现 |
| `cost-governor` | **不需要** | 用改造三的预算字段 + workflow 脚本内熔断实现，不需独立 agent |
| `loop-analyst` | **暂不需要**（仅 L2 成瓶颈时再议） | 复用 kb-curator 的 aggregate 模式 |

> 结论符合 CLAUDE.md「化繁为简」：**14 项改造全部用"现有角色 + skill/hook/workflow 脚本 + 状态字段/文档章节"实现，零新增 agent。** 仅在 P2 的 L2 自我改进成为实际瓶颈后，才把新增 loop-analyst 作为待验证选项重新评估。

---

# 第三部分：分阶段落地路线图

> 优先级原则：P0 = 低成本、纯文档/配置、立刻能做、零行为破坏；P1 = 中等改动，新增脚本/hook；P2 = 较大改动或含失控风险，需谨慎验证。

## P0 —— 低成本立刻能做（纯文档/状态字段，零破坏）

| # | 改造项 | 做什么 | 改哪个文件 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| P0-1 | 验证器分层总则 | 把"确定性验证优先"写成贯穿全流程的总则 + 优先级表 | `orchestrator.md` 新增「验证器分层总则」节，Step 3 STEP C 引用 | 任一硬 gate 未绿则不进下一 Phase | 低 |
| P0-2 | 防合谋显式化 | 写明 checker 不得复用 maker 自评结论，只认自跑命令输出 | `testing-evidence-collector.md` 补一条 | checker 报告中证据均为自跑输出 | 低 |
| P0-3 | Heartbeat 字段 | STATE.md 加 `Heartbeat At` + 挂起恢复规则 | `orchestrator.md`（状态格式 + 恢复规则 + 写入时机） | 人为中断后恢复能识别心跳超时 | 极低 |
| P0-4 | 循环预算治理总则 | GOAL.md 加时间预算/无进展熔断字段 + 「循环预算治理」小节 | `orchestrator.md`（重试规则后）+ GOAL.md 格式 | 文档定义完整，字段可写 | 低 |
| P0-5 | 自动循环边界约定 | 新增 LOOP_CONTEXT.md 约定 + "自动循环只读不改、禁触安全确认点动作"红线 | `orchestrator.md` 新增「自动/定时循环约定」节 | 红线明确可引用 | 低 |
| P0-6 | 成熟度自评落档 | 把第一部分映射表作为团队"Loop Engineering 现状基线"固化 | 本蓝图即承担（可在 README 引用） | 团队对现状有共识 | 极低 |

**P0 清单摘要**：6 项全是"改 orchestrator.md / testing-evidence-collector.md + 加状态字段 + 写约定"，**不写任何业务代码、不新增 agent、不引入定时任务**，当天可完成，对现有串行流程零行为破坏（新增能力默认不激活）。

## P1 —— 需要中等改动（新增脚本/hook/聚合模式）

| # | 改造项 | 做什么 | 改哪个文件/加什么 | 验收标准 | 风险 |
|---|---|---|---|---|---|
| P1-1 | contract-diff 硬 gate | 契约一致性从 LLM 比对升级为机器 diff | 新增 `scripts/contract-diff.{sh,ps1}`；STEP C 调用 | 字段/路径/错误码不符时脚本红 | 中（解析路由表因栈而异） |
| P1-2 | Cron 夜间 Audit | 无人值守只读巡检，产出 NIGHTLY_AUDIT.md | 新增 `nightly-audit.workflow.js` + `.github/workflows/nightly-audit.yml` | 无人值守产出当日报告，Blocker 数与手动一致 | 中（配额/凭据/无 TTY） |
| P1-3 | Hook 轻量层 | CI 失败自动收集日志写 CI_FAILURE.md，下次开场提示 | `settings.json`/`hooks/` 注册 + 极薄收集脚本 | CI 失败后 5 分钟内生成可定位摘要 | 中 |
| P1-4 | 预算熔断实装 | 自动循环 workflow 读预算、每轮检查、无进展提前熔断 | 自动循环 workflow 脚本 + BUDGET_BURN.md | 不收敛任务能 ≤2 轮无进展熔断 | 中（token 计量待验证） |
| P1-5 | trace 聚合 L1 | kb-curator 加 aggregate 模式，cron 周聚合产出 HOTSPOTS.md | `kb-curator.md` 加模式 + `/team-kb-aggregate` | 正确识别出现 ≥N 的失败模式 top | 中 |

## P2 —— 较大改动 / 含失控风险（谨慎验证后才上）

| # | 改造项 | 做什么 | 验收标准 | 风险 |
|---|---|---|---|---|
| P2-1 | Hook 重度层（CI 失败自动修复） | CI 失败触发 Hotfix workflow，仅分支跑、修完发 PR、绝不自动合并 | 产出 PR 必通过原失败 CI 检查 | 高（可能绕测试求绿，需确定性 gate + code-reviewer 兜底） |
| P2-2 | 反向修订 harness（L2 自我改进） | 基于 HOTSPOTS，人确认后把预防规则写进对应 agent 提示词/验收标准 | 同类失败在后续项目复现率下降（长期） | 高（自动改 harness 失控；强制人确认，禁止自动改 agent 定义） |
| P2-3 | Heartbeat 真心跳 / Worktree 并行隔离 | 长任务主动心跳进程 + git worktree 文件级隔离并行 | 并行 agent 不互相污染文件 | 中高（环境依赖） |
| P2-4 | 新增 loop-analyst（仅 L2 成瓶颈时） | 只读 trace、产出改进建议、绝不直接改 harness | 建议被采纳率 / 误报率达标 | 中（违反"零新增"原则，需充分理由） |

---

# 第四部分：诚实的可行性标注

## 确定可行（基于现有机制直接扩展）
- 所有 P0 项（纯文档/状态字段）。
- 改造二（验证器总则）、改造三的轮次/时间/无进展三维熔断、改造五的状态文件扩展、改造六（零新增 agent 的结论）。

## 待验证假设（需真实环境/API 确认）
- **token 实时计量**：改造三依赖运行环境暴露 token 用量。若不可得，降级为"轮次+时间+无进展检测"组合兜底（这三者确定可得）。
- **CronCreate / GitHub Actions 无 TTY 跑 Claude 的具体接入**：调研 §6 称已支持，但本团队环境的凭据/配额/命令形态需实测（P1-2/P1-3）。
- **Hook 事件触发链**（CI 失败 → 回灌 Claude）的端到端连通性。
- **L2 反向修订 harness 的净收益**：可能引入坏规则，需长期 A/B 验证，故置于 P2 且强制人确认。
- **第一部分"已具备"判断在真实长链路项目中的稳定性**：建议 P0 落地后用一个真实项目跑通验证基线。

## 与项目 CLAUDE.md 原则的一致性核对
- **化繁为简**：14 项改造零新增 agent，绝大多数是"改文档 + 加状态字段 + 极薄脚本"。
- **手术式改变**：所有改动以"新增节/新增字段/新增文件"为主，不重写现有 Phase，不破坏现有串行流程（新能力默认不激活，与 Workflow"用户不点头零行为变化"同构）。
- **谨慎而非速度**：高风险项（自动修复、反向改 harness）一律下沉 P2 并强制人确认。

---

# 附录：改造项总览（14 项）

| 编号 | 改造项 | 阶段 | 类型 |
|---|---|---|---|
| 1A | Cron 夜间 Audit 巡检 | P1 | 循环补全 |
| 1B | Hook 自动修复（轻量/重度） | P1/P2 | 循环补全 |
| 1C | Heartbeat 心跳/挂起检测 | P0/P2 | 循环补全 |
| 2 | 验证器分层总则（确定性优先） | P0 | 验证强化 |
| 2b | contract-diff 机器 gate | P1 | 验证强化 |
| 2c | 防 maker/checker 合谋显式化 | P0 | 验证强化 |
| 3 | 循环预算治理（轮次/token/时间/无进展） | P0/P1 | 成本闸 |
| 4-L1 | trace 聚合产出 HOTSPOTS | P1 | 自我改进 |
| 4-L2 | 反向修订 harness（人确认） | P2 | 自我改进 |
| 5a | Heartbeat 字段 | P0 | 状态持久化 |
| 5b | BUDGET_BURN.md | P1 | 状态持久化 |
| 5c | LOOP_CONTEXT.md + 自动循环边界 | P0 | 状态持久化 |
| 6 | 零新增 agent 结论（loop-analyst 仅 P2 待议） | — | 角色决策 |
| 0 | 成熟度基线固化 | P0 | 现状落档 |

> 核心理念回扣调研报告：**没有验证的循环只是 slop machine；有界、确定性退出、maker/checker 分离的循环才省钱可靠。** 本团队的强项恰在后者——改造重点是把"非人触发"和"成本闸"补齐，而不是去追求更激进的全自动。
