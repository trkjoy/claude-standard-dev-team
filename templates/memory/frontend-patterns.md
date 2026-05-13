# 前端实现错误模式库

orchestrator 在 Phase 6 开始前读取本文件，按技术栈过滤后注入到 frontend-developer 的任务指令。
项目最终 READY 后，orchestrator 才能把已经验证有效的前端修复模式写回本文件。

每条记录必须使用以下格式：

```markdown
## API 路径硬编码
- 触发场景: frontend-developer 直接写 fetch('/api/v1/users') 而非使用环境变量
- 错误表现: QA 发现代码中存在硬编码 /api/ 路径，子路径部署会失败
- 解决方案: 所有 API 调用必须通过统一 HTTP 客户端，并使用 import.meta.env.VITE_API_BASE
- 技术栈: React, Vite
- 出现次数: 1
- 最后更新: 2026-05-12
```
