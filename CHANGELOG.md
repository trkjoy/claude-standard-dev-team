# 变更日志

本文件记录每个版本的关键变更，方便团队成员判断是否需要升级、以及升级带来的行为差异。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [1.0.7] - 2026-05-22

### 新增（Added）

- **`/team-update` 全局命令**：一条命令把当前项目升级到**指定版本**（或最新版），自动完成两件事：
  - 刷新全局 `~/.claude/agents/` 下的 13 个 agent
  - 同步当前项目 `CLAUDE.md` 的「团队配置」段落到目标版本（保留用户的技术栈 / 部署环境字段，幂等）
  - 用法：`/team-update`（升到最新）或 `/team-update 1.0.7`（升到指定版本，也可用于回滚）
  - 已加入 `/team-install` 的全局命令注册步骤，重新运行 `/team-install` 即可获得此命令

### 修复（Fixed）— 架构级

- **orchestrator 作为 subagent 无法派发下游团队**：修复 orchestrator 被 `Task` 启动为 subagent 后，整个团队流程瘫痪的问题。
  - 现象：团队开发过程中报错 `The orchestrator ran as a subagent and can't dispatch further agents — that's an environment limitation.`，orchestrator 无法派发任何下游 agent。
  - 根因：Claude Code **不支持 subagent 嵌套派发**——被 `Task` 启动的 subagent 内部 `Task` 工具不可用。而 orchestrator 的唯一职责就是用 `Task` 派发下游。orchestrator.md 被放在 `~/.claude/agents/` 注册为 subagent，且其 `description` 写着"当用户需要完成任何开发相关任务时激活"，强烈诱导主会话用 `Task` 启动 orchestrator subagent，恰好踩中嵌套派发限制。这也是 v1.0.6 "orchestrator 自己干活不派发"问题的真正根因——它不是不想派发，而是作为 subagent **无法**派发。
  - 修复（三层防御）：
    1. **`agents/orchestrator.md` 新增「运行模式声明」章节**（位于文件最顶部，凌驾于其余内容）：
       - 明确铁律——orchestrator 必须由 top-level 主会话亲自担任，禁止作为 subagent 用 Task 启动
       - 给出正确 vs 错误启动方式对照
       - 加入 subagent 自检 fallback：若发现自己作为 subagent 运行（Task 不可用），立即停止并输出"请主会话亲自接管"的指引，禁止伪装进度
    2. **修改 `description`**：从"当用户需要完成任何开发相关任务时激活"（诱导 Task 启动）改为"操作手册，由 top-level 主会话亲自担任，禁止作为 subagent 启动"
    3. **CLAUDE.md 引导**：`team-init` 命令生成的 CLAUDE.md 与 `templates/memory/project-CLAUDE.md` 模板均新增「启动方式」说明，明确"你就是 orchestrator 本人；只有下游 12 个 agent 才用 Task 派发"

### 升级方式

```bash
git pull
/team-install   # 刷新 ~/.claude/agents/orchestrator.md 与全局命令
```
升级后**重启 Claude Code**。

### 已有项目如何升级

如果你在 v1.0.7 之前已用 `/team-init` 初始化过项目，那些项目的 `CLAUDE.md` 缺少新的「启动方式」引导。**进入该项目目录，运行 `/team-update` 即可一键升级**（自动刷新全局 agents + 同步该项目 CLAUDE.md 的团队配置段落，保留你的技术栈/部署环境字段）。

> 首次使用 `/team-update` 前，需先 `git pull && /team-install` 一次，把该命令注册到全局。

### 验证升级是否生效

新开 Claude Code 会话说"使用标准团队开发 xxx"，观察：
- ✅ 主会话**自己**开始用 `Task` 派发 product-manager 等下游 agent（UI 上能看到嵌套的 Task 调用块）
- ❌ 不应再出现 "ran as a subagent and can't dispatch" 报错

---

## [1.0.6] - 2026-05-20

### 修复（Fixed）

- **orchestrator 防退化红线规则**：修复 orchestrator 在收到宽泛指令（如"使用标准团队开发"）时退化为"自己读项目代码、自己写契约文件"的问题。
  - 现象：用户报告 orchestrator 跑了 20 分钟、74 次工具调用、消耗 37.7k tokens，但全程未派发任何下游 agent，产出只有 `.claude/team-state/` 状态文件，没有 `docs/PRD.md` 等正常产出。
  - 根因：orchestrator.md 缺少强制的"派发优先"约束，遇到模糊需求时容易自己开始读代码"理解项目"，违背了"总指挥不写代码、只调度"的设计初衷。
  - 修复：在 `agents/orchestrator.md` 中新增「红线规则（最高优先级）」章节，凌驾于其他所有流程之上：
    - **4 条禁令**：禁止自己读业务代码、写契约文件、写业务代码、大范围扫描（>5 次）
    - **5 条允许清单**：白名单化允许操作（状态文件 / 已有契约读取 / 知识库 / 任务清单更新 / Task 派发）
    - **4 个自检红灯阈值**：连续 3 次非 Task / 读 >5 业务文件 / 累计 >10 次工具无派发 / 运行 >15 分钟无派发 —— 任一触发即自停并向用户报告
    - **模糊指令强制反问**：遇到"使用标准团队开发"这类宽泛指令必须先反问"新项目还是改造？走哪个模板？核心目标？"
    - **派发优先原则**：明确"派发是默认动作，自己动手是例外"

### 升级方式

仓库目录执行：
```bash
git pull
/team-install   # 在 Claude Code 内运行，刷新 ~/.claude/agents/orchestrator.md
```

升级后**重启 Claude Code** 让 agent 重新加载，新规则才会生效。

### 验证升级是否生效

新开一个 Claude Code 会话，对 orchestrator 说一句**模糊指令**：
```
使用 orchestrator agent，开始标准团队开发
```

**预期行为**：orchestrator 不应该立即开始读代码 / 写状态文件，而应该**先反问 3 个澄清问题**：
1. 这是新项目还是改造现有项目？
2. 走哪个模板（完整项目 / Audit / Hotfix）？
3. 核心目标是什么？

如果它仍然闷头干活、不反问，说明升级未生效 —— 检查 `~/.claude/agents/orchestrator.md` 是否真的被覆盖（看文件中是否包含"红线规则（最高优先级）"章节）。

---

## [1.0.5] - 历史版本

详见 git log：
```bash
git log --oneline
```

主要历史变更：
- 1.0.5 — 升级团队版本（AI 团队改造、新增 kb-curator、qa-automator、ui-designer）
- 1.0.3 — install 脚本新增 KB_MODE 参数
- 1.0.2 — 知识库新增项目源隔离
- 1.0.1 — templates/memory 文档添加文件/格式头说明
