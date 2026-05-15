# 部署问题模式库

**文件说明**：orchestrator 在 Phase 6 和 Phase 9 前读取本文件，按技术栈过滤后注入给 frontend-developer 或 devops-automator；项目最终 READY 后，orchestrator 才能把已验证有效的部署修复模式写回本文件。
**格式说明**：每条记录以 `## [错误标题]` 开头，包含触发场景、错误表现、解决方案、技术栈、出现次数和最后更新时间。

## 记录示例

```markdown
## Nginx 子路径缺少 try_files
- 触发场景: devops-automator 生成的 nginx.conf 在子路径部署时缺少 try_files 配置
- 错误表现: SPA 刷新子页面返回 404
- 解决方案: nginx location 块必须包含 try_files $uri $uri/ /index.html
- 技术栈: Nginx, React SPA
- 项目来源: 通用
- 出现次数: 1
- 最后更新: 2026-05-12
```
