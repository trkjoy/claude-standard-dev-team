# QA 验证失败模式库

**文件说明**：记录 testing-evidence-collector 反复发现的验证失败模式，供 orchestrator 提前预警；项目最终 READY 后，orchestrator 才能把已验证有效的 QA 失败模式写回本文件。
**格式说明**：每条记录以 `## [错误标题]` 开头，包含触发场景、错误表现、解决方案、技术栈、出现次数和最后更新时间。

## 记录示例

```markdown
## 服务未启动导致全部 404
- 触发场景: 后端实现完成但 start.sh 未启动对应服务
- 错误表现: testing-evidence-collector 所有接口请求返回 404 或 Connection Refused
- 解决方案: 第 2 次重试时拉 devops-automator 检查启动脚本和服务端口
- 技术栈: 通用
- 项目来源: 通用
- 出现次数: 1
- 最后更新: 2026-05-12
```
