# 安全问题模式库

**文件说明**：orchestrator 在 Phase 7 开始前读取本文件，按技术栈过滤后注入到 security-engineer 的任务指令；项目最终 READY 后，orchestrator 才能把已验证有效的安全修复模式写回本文件。
**格式说明**：每条记录以 `## [错误标题]` 开头，包含触发场景、错误表现、解决方案、技术栈、出现次数和最后更新时间。

## 记录示例

```markdown
## JWT 未验证 audience 字段
- 触发场景: backend-architect 实现 JWT 验证时只验证签名
- 错误表现: security-engineer 发现跨服务 token 可被错误接受
- 解决方案: JWT 验证必须同时校验 signature、issuer、audience 和过期时间
- 技术栈: Node.js, Express.js
- 出现次数: 1
- 最后更新: 2026-05-12
```
