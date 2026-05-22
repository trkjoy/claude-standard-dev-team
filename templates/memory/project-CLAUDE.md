# {{PROJECT_NAME}}

**文件说明**：本文件是项目级 CLAUDE.md 模板，部署到各项目根目录后作为 orchestrator 的启动入口，提供项目上下文和团队运行机制的快速索引。
**格式说明**：顶部占位符 `{{PROJECT_NAME}}` 替换为实际项目名；`## 项目上下文` 中各字段按实际技术栈和部署环境填写；`## 团队运行机制` 中的路径为约定路径，不应修改。

## 团队配置

本项目使用标准 AI 开发团队（13 agents）。

**启动方式（重要）**：当用户说"使用标准团队开发 你的需求"时，**你（top-level 主会话）亲自担任 orchestrator 总指挥**：
1. 读取 `~/.claude/agents/orchestrator.md` 作为调度操作手册
2. 按其中的流程，用 `Task` 工具派发 product-manager、software-architect、backend-architect 等**下游专业 agent**
3. **不要**用 `Task` 启动 `subagent_type="orchestrator"`——Claude Code 不支持 subagent 嵌套派发，那样 orchestrator 将无法派发下游、整个团队瘫痪

一句话：**你就是 orchestrator 本人；只有下游 12 个 agent 才用 Task 派发。**

## 项目上下文

- 技术栈: 请填写，例如 Express.js, React, PostgreSQL
- 部署环境: 请填写，例如 Docker + Nginx，或 Vercel

## 团队运行机制

- 项目状态记录在 `.claude/team-state/STATE.md`
- 失败重试记录在 `.claude/team-state/RETRY_LOG.md`
- 用户确认过的关键决策记录在 `.claude/team-state/DECISIONS.md`
- 项目内经验记录在 `.claude/team-state/LEARNINGS.md`
- 用户级长期记忆位于 `~/.claude/team-memory/patterns/`
