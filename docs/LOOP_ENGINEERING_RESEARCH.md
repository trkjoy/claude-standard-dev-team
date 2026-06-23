# Loop Engineering（循环工程）深度调研报告

**调研日期**：2026-06-23
**信息来源**：公开网络多源交叉印证

---

## 目录

1. [定义与核心思想](#1-定义与核心思想)
2. [起源、关键人物与演进谱系](#2-起源关键人物与演进谱系)
3. [循环的解剖结构与四种类型](#3-循环的解剖结构与四种类型)
4. [验证器为何是瓶颈与最佳实践](#4-验证器为何是瓶颈与最佳实践)
5. [风险、成本与争议](#5-风险成本与争议)
6. [工具原生支持现状](#6-工具原生支持现状)
7. [信源与可信度说明](#7-信源与可信度说明)

---

## 1. 定义与核心思想

**Loop Engineering（循环工程）**的核心定义是：不再由人逐轮手动提示（prompt）AI agent，而是**设计一套自主系统，让该系统自动去提示 agent**——agent 按照"发现任务 → 执行 → 验证 → 记忆 → 循环"的流程持续运转，直到达成既定目标，全程无需人逐轮介入。

已经过多源核实的正式定义为：

> "building autonomous systems that find work, delegate it to agents, review outcomes, and decide what's next"

——其中**验证节点（verification）被视为承重墙**，不可省略。
（[来源：SonarSource](https://www.sonarsource.com/blog/loop-engineering-without-verification-is-just-automation/)、[来源：Tosea AI](https://tosea.ai/blog/loop-engineering-ai-agents-complete-guide-2026)）

### 1.1 与"自动化（Automation）"的本质区别

这是理解 Loop Engineering 最常见的混淆点：

| 维度 | 传统自动化（Automation） | 循环工程（Loop Engineering） |
|------|--------------------------|------------------------------|
| 执行模式 | 固定脚本：做第一步、第二步、第三步 | 状态感知：看状态 → 决定下一步 → 执行 → 检查 → 判断是否再来一轮 |
| 分支能力 | 路径预定义，无动态分支 | 根据验证结果动态决定下一动作 |
| 退出条件 | 脚本结束即退出 | 达成目标条件时退出（或超时/预算耗尽时强制退出） |
| 类比 | 流水线 | 微型工程流程 |

传统自动化是脚本；Loop Engineering 更像一个有反馈回路的工程过程。
（[来源：SonarSource](https://www.sonarsource.com/blog/loop-engineering-without-verification-is-just-automation/)）

---

## 2. 起源、关键人物与演进谱系

### 2.1 引爆点

2026 年 6 月 8 日，Peter Steinberger（OpenClaw 作者，后加入 OpenAI）发推：

> "你不该再手动 prompt 编码 agent，而该设计 prompt 它们的循环。"

该推文获约 **650 万浏览**，引爆技术社区讨论。
（[来源：BDTechTalks](https://bdtechtalks.com/2026/06/22/ai-loop-engineering/)）

### 2.2 关键人物与背书

**Boris Cherny**（Anthropic Claude Code 负责人）：

> "我不再 prompt Claude，我有正在运行的循环，由它们去 prompt Claude、决定做什么。"
> "我的工作就是写循环。"

**Addy Osmani**（Google Chrome 工程主管）：撰文《Loop Engineering》，为这一病毒式观点提供了可建设的系统词汇，定义了循环的解剖学组件（automations / worktrees / skills / connectors / sub-agents / external state）。
（[来源：Addy Osmani 博客](https://addyosmani.com/blog/loop-engineering/)）

### 2.3 前身与演进谱系

Loop Engineering 并非凭空出现，它有清晰的技术谱系：

1. **ReAct 范式**（2022，Princeton + Google）：Reason + Act 交替执行，是 agent 循环的学术起点。
2. **AutoGPT**（2023）：第一个广泛传播的"自主循环 agent"工程实践，验证了公众兴趣，也暴露了无约束循环的成本问题。
3. **Ralph 技术**（Geoffrey Huntley 命名，2025/2026 初）：名称源自辛普森一家角色 Ralph Wiggum；技术特征是在 `while` 循环里反复用同一 prompt 喂同一 spec，每轮创建新 agent 实例执行单一任务后提交，重复直至目标达成。
4. **Loop Engineering**（2026/6）：Osmani 等人将上述实践系统化为可复用框架。

（[来源：BDTechTalks](https://bdtechtalks.com/2026/06/22/ai-loop-engineering/)）

### 2.4 工程演进四层

社区形成了一种被广泛引用的四层演进模型：

| 层次 | 名称 | 关注点 |
|------|------|--------|
| 第一层 | Prompt 工程 | 用什么词提示模型 |
| 第二层 | Context 工程 | 模型该看到哪些信息 |
| 第三层 | Harness 工程 | agent 自主工作的执行环境 |
| 第四层 | Loop 工程 | 迭代循环本身的设计 |

**注意争议**：Osmani 将 Loop 工程视为 Harness 之上独立的新一层；另有工程师认为它只是 Harness 工程的子学科，并非独立范式。读者应留意这一定义边界尚未在社区达成共识。
（[来源：Addy Osmani 博客](https://addyosmani.com/blog/loop-engineering/)、[来源：Tosea AI](https://tosea.ai/blog/loop-engineering-ai-agents-complete-guide-2026)）

---

## 3. 循环的解剖结构与四种类型

### 3.1 实用循环的五件套 + 记忆层

Addy Osmani 的解剖学将一个生产可用的循环分解为以下组件：

| 组件 | 作用 |
|------|------|
| **Scheduled Automations（定时触发器）** | 发现工作并分诊，决定什么任务该在什么时机交给哪个 agent |
| **Git Worktrees（工作树）** | 并行 agent 各占独立工作树，互不冲突、不污染主分支 |
| **Skills（技能库）** | 沉淀项目专有知识，供 agent 跨轮复用，避免每轮重新"学习"项目上下文 |
| **Plugins / MCP Connectors（连接器）** | 接入真实外部工具（数据库、CI/CD、通知系统等） |
| **Sub-agents（子 agent）** | 拆分 maker（生产者）与 checker（验收者）职责，两个角色不能合并为一个模型 |
| **External State（外部状态）** | JSON 检查点、git 历史或外部数据库，保存跨轮进度，避免重复劳动 |

（[来源：Lenny's Newsletter](https://www.lennysnewsletter.com/p/how-to-design-ai-agent-loops-schedules)）

### 3.2 四种循环类型

| 类型 | 触发方式 | 典型用例 |
|------|----------|----------|
| **Heartbeat（心跳循环）** | 短间隔持续运行 | 监控、实时告警处理 |
| **Cron（定时循环）** | 固定时间（如每天 10:00）| 每日代码审查、报告生成 |
| **Hook（事件钩子）** | 事件触发（PR push、CI 失败）| 自动化代码审查、测试失败分析 |
| **Goal（目标循环）** | 迭代至成功条件后停止 | 复杂重构、多步骤功能开发 |

（[来源：Lenny's Newsletter](https://www.lennysnewsletter.com/p/how-to-design-ai-agent-loops-schedules)）

### 3.3 嵌套循环思想

单一循环只是起点。成熟的 Loop Engineering 实践会在核心循环之外**层层套循环**：

- **内层**：核心 agent 循环——喂上下文、循环调用工具、直到单次任务完成。
- **中层**：任务编排循环——将多个 agent 的产出汇总、分诊下一批工作。
- **外层（自我改进循环）**：分析 agent 定期读取每轮的执行 trace，发现反复出现的问题模式，回头修改 harness 本身（prompt、工具定义、评分标准），实现系统自我进化。

这种嵌套结构使系统具备可靠性、可扩展性与自我改进能力，而不只是"定时跑一遍"。
（[来源：Lenny's Newsletter](https://www.lennysnewsletter.com/p/how-to-design-ai-agent-loops-schedules)）

---

## 4. 验证器为何是瓶颈与最佳实践

### 4.1 核心洞察

已经过多源三票核实的核心论断：

> "The verifier is the bottleneck, not the model."

验证器（verifier）才是整个循环质量的瓶颈，而不是生成模型本身。这一观点并非新发明——它对应 Anthropic 2024 年底推广的 **evaluator-optimizer 模式**（也称 maker-checker 原则）。
（[来源：SonarSource，已获 3-0 验证票](https://www.sonarsource.com/blog/loop-engineering-without-verification-is-just-automation/)）

### 4.2 maker/checker 必须严格分离

写代码的 agent（maker）和验收代码的 agent（checker）**不能是同一个模型实例**。实践观察表明，模型给自己的输出评分时一贯过于宽松，容易产生"自我认可"偏差。

### 4.3 验证手段的优先级排序

| 优先级 | 验证类型 | 特点 |
|--------|----------|------|
| 最高 | **确定性验证**（测试套件、类型检查、编译器、linter）| 客观 pass/fail，模型无法狡辩，结果不可篡改 |
| 次级 | **LLM-as-judge**（另一个模型评分）| 更灵活，适用于无法机械检查的场景（如代码风格、需求符合度），但存在被钻空子或与 actor "合谋"的风险 |

**最佳实践**：能上确定性检查的地方一律优先使用确定性检查，只把真正无法量化的判断交给模型评估。

### 4.4 退出条件的设计原则

循环的退出条件**应当依赖确定性软件检查**（如"所有测试通过""编译零错误"），而非让 LLM 自我评估"我完成了"。LLM 自评退出条件是高风险设计——模型倾向于声称完成，即使结果存在缺陷。
（[来源：BDTechTalks](https://bdtechtalks.com/2026/06/22/ai-loop-engineering/)）

---

## 5. 风险、成本与争议

### 5.1 头号风险：Token 成本失控

Reddit 等开发者社区中最具代表性的批评是：

> "循环一夜烧掉几百美元。"

当前社区讨论中，"怎么不让循环掏空账户"是开发者最迫切想解决的问题，远超功能本身的讨论。

### 5.2 "Loopmaxxing"谬误

已核实的反模式，描述一种常见的错误假设：

> "把 agent 放进无限循环，最终就能得到正确解。"

实际结果是：在没有明确退出条件时，系统在没有进展的情况下持续消耗 API 预算，最终产生巨额账单而无有效产出。
（[来源：BDTechTalks，已核实](https://bdtechtalks.com/2026/06/22/ai-loop-engineering/)）

### 5.3 没有验证的循环 = Slop Machine

已获 3-0 验证票的核心论断：

> "Point an open-ended loop at a loose standard and it becomes a slop machine."

没有验证节点的开放式循环会源源不断地生产低质量输出，同时持续消耗成本。相比之下，**闭环/有界循环**因路径更紧，反而更省钱、更可靠。
（[来源：SonarSource，已获 3-0 验证票](https://www.sonarsource.com/blog/loop-engineering-without-verification-is-just-automation/)）

### 5.4 "这不就是套了壳的 Cron Job"——社区争议

开发者社区围绕 Loop Engineering 是否构成真正新抽象层，形成明显的两派：

**支持派**：认为 Loop Engineering 引入了真正新的设计层次——状态感知、动态路由、自我改进循环，这是传统 cron job 无法提供的。

**怀疑派**：认为本质上只是"戴帽子的 cron job"或"自动化的 prompt 包装"，在正式发布前不值得单独命名。

（[来源：Lenny's Newsletter](https://www.lennysnewsletter.com/p/how-to-design-ai-agent-loops-schedules)）

### 5.5 平衡结论

Loop Engineering 是真实可用的实践，但不是银弹：

- **不适用场景**：一次性任务、简单脚本——用循环是杀鸡用牛刀，成本高、收益低。
- **适用场景**：高价值、可重复、需要持续质量保证与自我改进的自主工作流（如持续代码审查、自动化测试修复、文档同步）。
- **根本约束**：LLM 只是更大软件系统里的一个组件。再多循环也救不了糟糕的目标定义和糟糕的系统架构。

---

## 6. 工具原生支持现状

### 6.1 Claude Code

Claude Code 目前已原生支持以下循环工程能力：

| 功能 | 说明 |
|------|------|
| `/loop` 命令 | 原生循环触发入口 |
| Cron 定时 | 支持定时调度 agent 执行 |
| **Hooks（钩子）** | 确定性脚本在 agent 生命周期各节点触发；`PreToolUse` 是主要安全检查点，在 agent 执行工具调用前拦截审查 |
| **Dynamic Workflows** | Claude 编写、后台运行的 JS 脚本，将"计划"移入代码，可编排 subagents，产物可读、可重跑、可应用 maker-checker/对抗式验证模式 |
| Subagents | 各自持有独立上下文，适合隔离并行任务 |
| Scheduled/Cron 执行 | 经 GitHub Actions 或系统定时任务，以无 TTY 一次性进程方式运行 |

**Auto Mode 的安全架构**：Claude Code Auto Mode 内置 maker-checker 式安全层——独立的 Sonnet 4.6 分类器在执行前审查每个 agent 动作，放行安全动作、拦截或上报危险动作。
（[来源：Claude Code 官方文档](https://code.claude.com/docs/en/workflows)、[来源：MarkTechPost](https://www.marktechpost.com/2026/06/14/claude-code-guide-2026-25-features-with-examples-demo/)）

### 6.2 OpenAI Codex

OpenAI Codex 通过 **Automations 标签**支持可配置的定时调度与 subagent 派生。到 2026 年，`/goal` 与 `/loop` 命令已同时内嵌于 Codex 与 Claude Code。两者都支持 skills、worktrees 与 MCP 集成。
（[来源：BDTechTalks](https://bdtechtalks.com/2026/06/22/ai-loop-engineering/)）

---

## 7. 信源与可信度说明

### 主要信源列表

| 信源 | URL | 类型 |
|------|-----|------|
| SonarSource 博客 | https://www.sonarsource.com/blog/loop-engineering-without-verification-is-just-automation/ | 技术博客，已核实 |
| Addy Osmani 博客 | https://addyosmani.com/blog/loop-engineering/ | 个人技术博客，Google Chrome 工程主管 |
| BDTechTalks | https://bdtechtalks.com/2026/06/22/ai-loop-engineering/ | 技术媒体报道 |
| Lenny's Newsletter | https://www.lennysnewsletter.com/p/how-to-design-ai-agent-loops-schedules | 技术通讯 |
| Tosea AI 博客 | https://tosea.ai/blog/loop-engineering-ai-agents-complete-guide-2026 | 技术博客 |
| Claude Code 官方文档 | https://code.claude.com/docs/en/workflows | 官方文档 |
| MarkTechPost | https://www.marktechpost.com/2026/06/14/claude-code-guide-2026-25-features-with-examples-demo/ | 技术媒体 |

### 验证说明与局限性

本次调研在对抗式验证阶段遭遇 **API 429 限流**，导致部分声明未能完成独立三票验证。验证状态说明如下：

- **已获 3-0 验证票（最高可信度）**：
  - "The verifier is the bottleneck, not the model"（SonarSource）
  - "building autonomous systems that find work, delegate it to agents, review outcomes, and decide what's next"（定义核心）
  - "Point an open-ended loop at a loose standard and it becomes a slop machine"（SonarSource）

- **多源出现但未完成完整对抗验证**：本报告其余内容均在多个来源中出现（2 个以上独立来源），但受限流影响未能完成本轮完整三票验证。**"vote 0-0"表示"未验证完成"而非"已被驳倒"**，不代表这些内容有误，仅代表独立核实链条尚未完整闭合。

**读者引用建议**：引用 SonarSource 的三条已验证核心论断时可信度较高；引用其他章节内容时，建议自行访问原始信源进行二次核实，尤其是涉及具体数字（如 650 万浏览量）和工具功能细节（如具体命令名称）的部分。

---

*本报告依据公开网络信息整理，不代表任何商业立场。所有引用论断均附有原始信源链接，读者可自行追溯核实。*
