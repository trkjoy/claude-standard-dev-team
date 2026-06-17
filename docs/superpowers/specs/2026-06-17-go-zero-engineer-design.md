# go-zero-engineer 角色接入设计

- 日期：2026-06-17
- 状态：待用户评审
- 作者：头脑风暴产出（Claude）

## 1. 背景与目标

在现有「标准 AI 开发团队」（14 个自包含 agent + orchestrator 契约驱动闭环）中，新增一名 **go-zero Go 后端工程师** 角色 `go-zero-engineer`，严格遵守 go-zero 官方开发规范（`.api` 契约语法、`goctl` 代码生成、`handler/logic/svc/types` 分层）。

**核心约束**：纯增量接入，不改动现有 Node/TS 后端链路；新角色与现有 `backend-architect` 并存，按项目技术栈二选一。

## 2. 已确认的设计决策

| # | 决策点 | 选择 |
|---|--------|------|
| 1 | 角色定位 | **并存**：新增 `go-zero-engineer`，与 `backend-architect`(Node/TS) 并列，orchestrator 按技术栈二选一派发 |
| 2 | 契约管线 | `software-architect` 保持技术栈中立，只出 `API_CONTRACT.md`(markdown)；**`go-zero-engineer` 负责翻译 `API_CONTRACT.md → .api`**，再跑 goctl、填 logic |
| 3 | 能力边界 | **仅单体 goctl api HTTP 服务**；不做 zrpc / gateway / kq，超范围写 ISSUES 上报 |
| 4 | Model 层归属 | `database-optimizer` 出 `DB_SCHEMA.md` + 建表 DDL（中立）→ `go-zero-engineer` 用 `goctl model mysql` 生成 model 层并在 svc 注入 |
| 5 | 官方规范来源 | **方案 A**：核心规范精炼内嵌进 agent.md（自包含、离线可靠），附官方 `ai-context` 链接做权威兜底 |
| 6 | 技术栈声明 | **要做**：`software-architect` 的 `TECH_SPEC.md` 产出强制包含「后端技术栈」字段，供 orchestrator Phase 5 路由 |

## 3. 契约管线（核心数据流）

```
software-architect (Phase 2)
  └─ API_CONTRACT.md（markdown，技术栈中立）
  └─ TECH_SPEC.md（含「后端技术栈: go-zero」字段）  ← 新增字段
        │
orchestrator (Phase 5) 读 TECH_SPEC 后端技术栈：
   = go-zero → 派 go-zero-engineer
   = 其他    → 派 backend-architect（现状不变）
        │
go-zero-engineer 逐任务执行：
   ① 翻译 API_CONTRACT.md → xxx.api（go-zero 契约语法）
   ② 一致性自查：.api 的 路径/方法/请求·响应字段 逐项对照 API_CONTRACT.md（一字不差）
   ③ goctl api go -api xxx.api -dir .  → 生成 handler/logic/svc/types 骨架
   ④ 只在 logic/ 填业务逻辑；handler/types 不手改
   ⑤ Model：取 database-optimizer 的 DDL → goctl model mysql → svc/servicecontext.go 注入
   ⑥ 写 GOZERO_STATUS.md（已实现接口表 + 翻译差异登记 + ISSUES）
        │
code-reviewer (Phase 8) 把关 .api ↔ API_CONTRACT.md 一致性
```

**翻译偏差风险控制**（本设计新引入翻译环节，必须显式兜底）：
- 强制 ② 一致性自查 + ⑥ 显式登记「翻译差异」章节。
- 契约歧义只写 ISSUES 上报，不自决——完全沿用 `backend-architect` 的「契约是命令」纪律。

## 4. 能力边界（收敛）

- **只做**：`goctl api` 单体 HTTP 服务 —— `.api` 契约、`handler/logic/svc/types` 分层、中间件鉴权、go-zero 内建参数校验、`goctl model mysql` 生成 model 层。
- **不做**：zrpc 微服务、gateway、kq(kafka)、定时任务。超范围一律写 ISSUES 上报，由人决定是否升级角色。

## 5. 与现有角色的边界

| 关注点 | 归属 |
|--------|------|
| `API_CONTRACT.md`（markdown 契约） | software-architect 产出，go-zero-engineer 只读不改 |
| `.api` 契约文件 | go-zero-engineer 翻译产出 |
| `DB_SCHEMA.md` + 建表 DDL | database-optimizer 产出（中立） |
| model 层代码（goctl model 生成） | go-zero-engineer |
| 索引/查询优化建议 | database-optimizer（写 DB_SCHEMA，go-zero-engineer 执行 goctl） |
| `.api ↔ API_CONTRACT` 一致性把关 | code-reviewer |

## 6. 生产级规范继承（不丢任何一条）

把 `backend-architect.md` 现有生产规范用 go-zero 写法重新表达：
- 健康检查端点（go-zero `rest` 注册 `/api/health`，免鉴权恒返回 200）
- DB 就绪等待（启动前探活 MySQL/Redis，等价 `waitForDB`）
- CORS 白名单（禁止 `*`）
- 基于身份（userId/openid）的限流，禁止仅基于 IP
- 内容安全审核（涉及用户上传时）

## 7. agent.md 内嵌的官方规范主体（方案 A）

`.api` 语法规范、标准目录结构、`goctl` 命令清单、handler 瘦/logic 厚分层原则、go-zero `httpx`/`errorx` 统一错误处理、中间件注册、配置(`etc/*.yaml`)写法，并附官方 `ai-context` 仓库链接作权威兜底。

## 8. 交付物（实现清单）

1. **新建 `agents/go-zero-engineer.md`**
   - frontmatter：`name/description/tools: Read,Write,Edit,Bash,Glob,Grep/model: sonnet`
   - 全局执行准则（中文 + Windows 优先 PowerShell）与现有 agent 对齐
   - 含第 3/4/6/7 节内容：契约管线纪律、能力边界、生产规范、官方规范主体、ISSUES/STATUS 模板

2. **改 `agents/orchestrator.md`**（3 处，纯增量分支）
   - 「实现层」成员清单：新增 `go-zero-engineer` 一行
   - 「路由参考」表：后端接口行补充「TECH_SPEC 后端技术栈=go-zero → go-zero-engineer」
   - Phase 5：在调用后端 agent 前，读 `TECH_SPEC.md` 后端技术栈字段决定派 `go-zero-engineer` 还是 `backend-architect`；失败分流（字段/契约→software-architect、连接→devops、鉴权→security）对两者一致

3. **改 `agents/software-architect.md`**
   - `TECH_SPEC.md` 产出要求强制包含「后端技术栈」字段（显式声明 go-zero / Node-Koa / Node-Express 等），Phase 2 人工确认点展示该字段

4. **（可选）Phase 4.9 知识库注入**
   - 若后续 `~/.claude/team-memory/patterns/` 出现 go-zero 专属经验，可加 `gozero-patterns` 筛选；本期不强制，留待经验沉淀后再加

## 9. 验证标准

- orchestrator 在 TECH_SPEC 后端技术栈=go-zero 的项目里，Phase 5 派发的是 `go-zero-engineer`（而非 backend-architect）。
- `go-zero-engineer` 产出的 `.api` 路径/方法/字段与 `API_CONTRACT.md` 完全一致（code-reviewer 校验通过）。
- 现有 Node 项目链路行为零变化（backend-architect 路径不受影响）。
- 生产规范 5 项在 go-zero 产物中均有对应实现。

## 10. 非目标（YAGNI）

- 不做 zrpc / 微服务编排 / 服务发现。
- 不引入运行时 MCP（mcp-zero）依赖。
- 不改造 `backend-architect` 为多技术栈。
- 不新增 `.api` 自动同步回 markdown 的双向工具。
