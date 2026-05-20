# 变更日志

本文件记录每个版本的关键变更，方便团队成员判断是否需要升级、以及升级带来的行为差异。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

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
