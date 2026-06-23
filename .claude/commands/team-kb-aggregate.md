---
description: 跨项目 trace 聚合——统计多个项目的高频失败模式，产出 ~/.claude/team-memory/HOTSPOTS.md 只读报告
---

你是跨项目失败模式聚合触发器，本次执行只做一件事：调用 `kb-curator` agent 以 `aggregate` 模式运行，产出 HOTSPOTS.md 统计报告。

## 与 /team-kb-save 的区别

| 维度 | /team-kb-save | /team-kb-aggregate |
|------|--------------|-------------------|
| 输入 | 当前单个会话的对话历史 | 多个项目的 RETRY_LOG.md + LEARNINGS.md |
| 产物 | `~/.claude/team-memory/patterns/*-patterns.md`（知识条目） | `~/.claude/team-memory/HOTSPOTS.md`（统计快照） |
| 写法 | Edit 追加 / 字段更新 | Write 整体覆盖（每次重新生成） |
| 触发时机 | 单个会话结束后沉淀 | 跨项目周期性聚合（手动或 cron） |
| 改 harness 吗 | 否 | 否（只读报告，绝不自动改 agent 定义） |

## 参数说明

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| project_paths | 字符串数组 | 必填 | 要聚合的项目根目录路径列表，例如 `["D:/proj/a", "D:/proj/b"]` |
| threshold | number | `3` | 同一错误模式出现次数达到此值才进入 top 列表 |

## 执行步骤

1. 解析用户在调用命令时提供的项目路径列表（`project_paths`）和可选阈值（`threshold`）
2. 若用户未提供 `project_paths`，输出以下提示后停止：
   ```
   请提供要聚合的项目路径列表，例如：
   /team-kb-aggregate project_paths=["D:/projects/proj-a","D:/projects/proj-b"] threshold=3
   ```
3. 调用 `kb-curator` agent，传入 `mode=aggregate`、`project_paths`、`threshold`
4. kb-curator 按 Aggregate 模式 4 步工作流执行，产出 HOTSPOTS.md
5. 返回 kb-curator 输出的完成报告，并告知用户产物路径

## 产物位置

```
~/.claude/team-memory/HOTSPOTS.md
```

## 注意事项

- HOTSPOTS.md 是**只读统计报告**，不会自动修改任何 agent 提示词或验收标准
- 若某个项目路径下缺少 RETRY_LOG.md 或 LEARNINGS.md，该项目会被跳过并在报告中注明
- 阈值越小，top 列表越长；建议先用默认值 3 观察，再按项目规模调整
- 如需定期自动运行，可在 cron / GitHub Actions 中调用 `claude -p /team-kb-aggregate project_paths=[...] threshold=3`

## 触发后给用户的提示

```
正在调用 kb-curator（aggregate 模式）聚合跨项目失败模式...
产物：~/.claude/team-memory/HOTSPOTS.md（只读统计报告，不改 agent 定义）
```
