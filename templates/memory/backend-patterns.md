# 后端实现错误模式库

orchestrator 在 Phase 5 开始前读取本文件，按技术栈过滤后注入到 backend-architect 的任务指令。
项目最终 READY 后，orchestrator 才能把已经验证有效的后端修复模式写回本文件。

每条记录必须使用以下格式：

```markdown
## 错误响应缺少 code 字段
- 触发场景: backend-architect 实现错误响应时只返回 HTTP 状态码
- 错误表现: QA 发现 POST /api/auth/login 返回 401 但 body 缺少 code 字段
- 解决方案: 错误响应统一返回 code 和 message，并与 API_CONTRACT 保持一致
- 技术栈: Express.js
- 出现次数: 1
- 最后更新: 2026-05-12
```
