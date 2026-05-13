# API/DB 契约设计陷阱库

orchestrator 在 Phase 5 和 Phase 6 前读取本文件，按技术栈过滤后注入给实现 agent。
契约类问题通常由 software-architect 在第 2 次重试时复查。

每条记录必须使用以下格式：

```markdown
## 分页参数类型不一致
- 触发场景: API_CONTRACT 定义 page 为 string，但实现中按 number 处理
- 错误表现: QA 发现 GET /api/items?page=2 返回全量数据，分页失效
- 解决方案: API_CONTRACT 明确 page 类型为 integer，并在请求示例中演示
- 技术栈: 通用
- 出现次数: 1
- 最后更新: 2026-05-12
```
