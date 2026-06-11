<p align="center">
  <img src="assets/cover.png" alt="Claude Standard Dev Team" width="100%" />
</p>

# Claude Standard Dev Team

> 让 Claude Code 拥有一支 14 人 AI 软件开发团队 + 1 位总指挥，从需求到上线全流程自动跑通。

> ⚙️ **版本说明**：D1 视频录制时是 11 人版本，现仓库已迭代到 **14 人 + 1 位总指挥（orchestrator），共 15 个 agent**——这套团队仍在进化。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Compatible-blue.svg)](https://claude.com/claude-code)
[![Version](https://img.shields.io/badge/Version-1.3.0-green.svg)](CHANGELOG.md)

> 📢 **v1.2.0 安装方式变更**：安装与升级改为在本地运行脚本——首次安装用 `scripts/install.ps1` / `scripts/install.sh`，升级用 `scripts/update.ps1` / `scripts/update.sh`（下载并解压对应版本的发布包后运行）。原先在 Claude Code 内运行的 `/team-install`、`/team-update` 已移除；Claude Code 内保留 `/team-init`（初始化项目）、`/team-kb-save`（沉淀知识库）、`/team-version`（查看版本）三个命令。详见 [INSTALL.md](INSTALL.md) 与 [CHANGELOG.md](CHANGELOG.md)。
>
> 🔐 **安全提示（信任边界）**：agent 会被安装为 `~/.claude/agents/` 下的**全局可信指令**。安装脚本只读取你本地解压的发布包，不联网拉取；安装前可自行 review 一遍 `agents/*.md` 内容。
>
> 📢 **v1.0.7 架构级修复**：orchestrator 被作为 subagent 启动时无法派发下游团队（"can't dispatch further agents"）。现已明确——orchestrator 必须由 top-level 主会话亲自担任，只有下游 agent 才用 Task 派发。详见 [CHANGELOG.md](CHANGELOG.md)。

---

## 这是什么

一套面向 [Claude Code](https://claude.com/claude-code) 的 **agent 团队配置**，把"软件开发"拆成 14 个专业岗位 + 1 位总指挥，按真实研发团队的协作链路串起来：

- **不再是 1 个 AI 一锅煮**：每个 agent 只干一件事，互不交叉
- **契约驱动**：先定 PRD/API/Schema，再让所有人照契约写
- **任务级 QA 闭环**：实现一个接口，立刻独立验证，FAIL 自动打回重做
- **零容忍硬编码**：API 路径硬编码必须打回——这是被部署翻车真实教训出来的

最适合用 Claude Code 做**中型应用**（前后端 + 数据库 + 部署）的人——不论你是独立开发者、一人公司还是小团队。

---

## 团队架构

```
                    ┌─────────────────────────┐
                    │     orchestrator        │
                    │   总指挥，不写代码        │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                        │                        │
┌───────▼─────┐         ┌────────▼────────┐      ┌────────▼─────┐
│  规划层 2   │         │   实现层 5      │      │  质量层 5     │
├──────────── │         ├─────────────────│      ├──────────────│
│ pm          │         │ db-optimizer    │      │ ev-collector │
│ sw-architect│         │ backend-arch    │      │ qa-automator │
│             │         │ ui-designer     │      │ sec-engineer │
│             │         │ frontend-dev    │      │ code-reviewer│
│             │         │ devops-automator│      │ reality-chk  │
└─────────────┘         └─────────────────┘      └──────────────┘
                                                  ┌──────────────┐
                                                  │  支撑层 2    │
                                                  │ tech-writer  │
                                                  │ kb-curator   │
                                                  └──────────────┘
```

**总指挥 1 + 团队成员 14 = 15 个 agent（不含总指挥则 14 人团队）**

| 层级 | Agent | 职责 |
|---|---|---|
| **总指挥** | orchestrator | 不写代码，只调度其他 agent，把控 11 个阶段（CEO 角色，不算"团队成员"） |
| **规划** | product-manager | 把模糊需求拆成结构化 PRD + 用户故事 + 验收标准 |
| **规划** | software-architect | 技术选型 + 生成 API_CONTRACT / DB_SCHEMA / TECH_SPEC（最关键） |
| **实现** | ui-designer | 视觉规范 / 设计系统 / variables.css |
| **实现** | database-optimizer | 数据库迁移文件 + Model 层 + 索引设计 |
| **实现** | backend-architect | 严格按 API 契约实现接口 |
| **实现** | frontend-developer | 前端实现，禁止硬编码 API 路径 |
| **实现** | devops-automator | Dockerfile / docker-compose / CI/CD / 部署路径前缀检查 |
| **质量** | testing-evidence-collector | 任务级 QA，独立验证每个接口字段路径 |
| **质量** | qa-automator | 把验收标准沉淀成可长期重跑的自动化测试套件（unit / integration / e2e） |
| **质量** | security-engineer | 威胁建模 + 漏洞扫描 + OWASP 检查 |
| **质量** | code-reviewer | 正确性 / 可维护性 / 性能复审 |
| **质量** | reality-checker | 最终验收官，默认"需要返工"，要压倒性证据才放行上线 |
| **支撑** | technical-writer | README / API 文档 / 教程，让别人能读懂 |
| **支撑** | kb-curator | 把已验证的修复经验沉淀进用户级知识库，供后续项目复用 |

---

## 工作流程（11 个阶段）

```
Phase 0   orchestrator 创建项目目录                       （10 秒）
Phase 1   → product-manager      → PRD.md
   ⏸ 人工检查点 #1：确认功能范围
Phase 2   → software-architect   → API_CONTRACT.md / DB_SCHEMA.md / TECH_SPEC.md
   ⏸ 人工检查点 #2：确认接口契约（最关键节点）
Phase 2.5 → ui-designer          → DESIGN_SYSTEM.md / variables.css
Phase 3   orchestrator 自己拆任务清单
Phase 4   → database-optimizer   → migrations/
Phase 5   → backend-architect    │ ┐ Dev-QA Loop
          → ev-collector         │ │ 逐任务循环
Phase 6   → frontend-developer   │ ┐ Dev-QA Loop
          → ev-collector         │ │ 逐任务循环
Phase 7   → security-engineer    → SECURITY_REPORT.md
Phase 8   → code-reviewer        → REVIEW_REPORT.md
Phase 9   → devops-automator     → Dockerfile + 部署
Phase 10  → reality-checker      → READY 或 NEEDS WORK
Phase 11  → technical-writer     → README + API_DOC
完工 ✅
```

> 详见 [WORKFLOW.md](WORKFLOW.md)：每个 Phase 在做什么、Dev-QA Loop 怎么转、打回机制怎么走。

---

## 5 分钟上手

### 1. 装入 Claude Code

下载并解压发布包后，在解压目录运行安装脚本（注册全局 agents、命令、知识库）：

```bash
# Mac / Linux / WSL
bash scripts/install.sh
```

```powershell
# Windows
pwsh .\scripts\install.ps1
```

### 2. 进项目目录初始化

打开 Claude Code，运行 `/team-init`。它会问"项目要做什么 + 技术栈 + 部署环境"。

> 💡 **不确定用什么技术栈？** 技术栈那问直接回答 **"让团队推荐"**（或留空）——只要你描述了项目要做什么，团队就会按需求给出主选 + 备选方案（附理由）让你确认；完全没头绪也行，会留到完整开发的架构阶段按 PRD 选型。

### 3. 在 Claude Code 里说一句话启动

```
使用标准团队帮我开发一个 todo app
```

orchestrator 会自动接管：扫描需求 → 调 product-manager 写 PRD → 给你看 PRD 让你确认 → 调 software-architect 选技术栈 + 写 API 契约（选型会让你拍板）→ ... → 一路跑到 Phase 11 出文档。

详细安装/卸载/排错见 [INSTALL.md](INSTALL.md)。

### 4. 看着它跑

整个过程**只在 Phase 1 / Phase 2 后两次暂停**让你确认（PRD 范围 + API 契约），其他全自动。一个中等复杂度的应用从需求到部署完整跑完大约 **30-90 分钟**（取决于规模），主对话 token 消耗很低。

---

## 适合谁用

✅ 你正在用 Claude Code 写**中型应用**（前后端 + DB + 部署）  
✅ 你想要**契约驱动 + QA 闭环**而不是 1 个 AI 一把梭  
✅ 你被 AI 写出"看起来对、跑起来错"的代码坑过  
✅ 你需要**真实可上线**的产物，不只是 demo

❌ **不适合**：纯前端原型 / 单文件脚本 / 一次性小工具——杀鸡用牛刀  
❌ **不适合**：你还在评估 Claude Code 是否值得用——先用裸 Claude Code 跑通一遍再说

---

## 设计哲学（为什么这么编排）

| 设计原则 | 体现在哪 |
|---|---|
| **契约第一** | Phase 2 是最关键节点，后面 9 个 Phase 全都依赖契约 |
| **评审者 ≠ 实现者** | ev-collector 独立验证 backend / frontend 的产出，不让一个 agent 自己写自己测 |
| **打回有上限** | 重试 3 次还不行就暂停问用户，不死循环 |
| **人工介入点要少** | 只在 Phase 1/2 暂停，避免每步都打扰 |
| **职责单一** | 每个 agent 只干一类事 |
| **质量 > 速度** | 宁可串行也不并行（前后端不能同时改代码） |
| **零容忍硬编码** | API 路径硬编码必须打回（来自部署翻车的真实教训） |

---

## 与"裸 Claude Code"的区别

| 维度 | 裸 Claude Code | 标准团队 |
|---|---|---|
| 角色边界 | 1 个 AI 全干 | 15 个 agent 各司其职 |
| 契约约束 | 无（边写边改） | 必须先定 PRD/API/Schema |
| QA 验证 | 写完了说"应该 OK"| 任务级 QA Agent 独立验证 |
| 打回机制 | 没有 | 4 类规则 + 重试上限 |
| 部署路径检查 | 容易硬编码翻车 | Phase 9 强制检查 basePath |
| 适用规模 | 单文件 / 小脚本 | 中型应用 |

---

## 致谢

这套配置来自我经营**玉枢云创科技**一人公司过程中真实踩过的坑：

- 被 AI 改了字段名前端不知道翻过车
- 被部署 basePath 硬编码翻过车
- 被"AI 说写完了实际没写完"翻过车
- 被"AI 自己写自己测说 OK"翻过车

每一条零容忍规则背后都是一次真实事故。希望分享出来能让更多独立开发者少踩这些坑。

---

## License

[MIT](LICENSE) © 2026 斌哥-一人公司

如果这套配置帮到你，欢迎在 GitHub 上给个 ⭐ —— 让更多 Claude Code 用户看见。

---

## 相关链接

- [Claude Code 官方](https://claude.com/claude-code)
- [Claude Code agent 文档](https://docs.claude.com/en/docs/claude-code/sub-agents)
