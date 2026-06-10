# Workflow 首次启用自检清单

本清单用于**首次实际启用 Workflow 并行引擎前的安全验证**。两个工作流模板（`team-dev-loop.workflow.js` 和 `audit-scan.workflow.js`）已通过设计评审但尚未在真实项目里完整跑过，因此需要这份清单在小范围内先验证语义、安全性和回退机制，确保上手无误。

**适用场景**：从决定"启用 Workflow"到第一次生产级别任务下沉之间，走一遍这个清单。完成后可确保：
- 环境与依赖正确配置
- 两个核心流程（Dev-QA Loop / Audit 扫描）行为符合设计
- 并行度与 token 消耗在可控范围
- 回退路径验证，任何异常都能安全回到串行流程

---

## 一、前置条件检查

- [ ] **install 已分发 workflow 模板**
  - 确认 `~/.claude/team-workflows/` 目录已创建且包含：
    - `team-dev-loop.workflow.js`
    - `audit-scan.workflow.js`
  - 若目录不存在，运行 `npm run install-team` 或 `./scripts/install.ps1` 重新触发分发

- [ ] **Claude 模型/套餐支持 Workflow**
  - 确认正在使用 Claude Opus 4.8（或更新版本）
  - 确认账户套餐为 Max / Team / Enterprise 或对应 API access level
  - Workflow 功能为 research preview，低于此版本/套餐无法调用

- [ ] **项目确实值得用 Workflow**
  - 当前任务是否命中触发阈值？（如 ≥5 个独立可并行接口、≥50 个审计文件、≥20 处重复操作）
  - 若只是 Hotfix 或单接口，回到常规 orchestrator 流程即可，无需 Workflow
  - 确认用户/orchestrator 已清楚 **token 消耗会显著高于串行模式**（预算 30-50% 增长）

---

## 二、首次小范围试跑

- [ ] **选定小批量验证集**
  - **Dev-QA Loop**：选 2~3 个独立接口/页面（勿贪图一次性处理全部）
  - **Audit 扫描**：用 `src/` 的某个单一模块（如 `src/controllers/`），勿扫全仓
  - 目标：验证流程，而非完成真实任务

- [ ] **确认并发上限符合预期**
  - Workflow 中设置的并发策略是否清晰？（通常 pipeline ~10-16 并行任务）
  - 首次试跑是否未见异常（token 消耗、LLM 响应时间、重试行为）？
  - 若并发度异常，立即停止并向 software-architect 反馈

- [ ] **观察 orchestrator 与 Workflow 的握手过程**
  - 用户收到提示信息时是否清晰地看到"启用 Workflow？(y/N)"？
  - 确认用户点头后 workflow 脚本才真正启动（没有自动启用的情况）
  - 脚本完成后结果是否正确回流给 orchestrator（不出现"结果丢失"情况）

---

## 三、语义正确性核对

- [ ] **Dev-QA Loop 语义保留**
  - 流程是否遵循"实现 → 验证 → 重试≤2"？
  - 每个任务是否正确穿过两阶段（stageImplement → stageVerify）？
  - FAIL 后是否正确重试（最多 3 次总尝试 = 1 初始 + 2 重试）？
  - 最终 PASS/FAIL 状态是否准确？

- [ ] **Workflow 复用的是现有 13 个 agent，不是新建 agent**
  - 检查 Workflow 日志中 `agentType` 的值是否都来自已有列表：
    - backend-architect / frontend-developer / testing-evidence-collector / 
    - code-reviewer / security-engineer / devops-automator 等
  - 确认没有出现陌生的 agent 名字

- [ ] **PASS/FAIL 结果正确回流**
  - Workflow 返回的结果结构是否符合预期格式？（含 summary / results / verdict 等）
  - Orchestrator 是否成功读取并写入 `team-state/STATE.md`？
  - 每个任务的 verdict / attempts / evidence 字段是否完整？

- [ ] **/goal 锚定工作正常（若启用）**
  - 长链路任务前是否生成了 `team-state/GOAL.md`（包含原始需求、完成条件）？
  - Workflow 脚本是否能读到锚定目标并用作终止条件？
  - 每个 Phase 边界是否有"对照 GOAL 自检"的暂停点（可选，取决于项目）？

---

## 四、安全红线确认

- [ ] **不可逆操作确实未进 Workflow**
  - Workflow 脚本中不应包含：`git push` / `git delete` / `rm -rf` / 部署命令
  - 搜索脚本中是否存在危险关键字：`rm` / `push` / `deploy` / `delete` / `cleanup`
  - 所有这类操作应遗留在 orchestrator 的串行路径中

- [ ] **安全确认点不下放**
  - Phase 9（DevOps 部署）、Phase 11（发布）等不能下沉 Workflow
  - 任何"前置检查通过即自动执行"的逻辑都必须明确由用户或 orchestrator 把关

- [ ] **Workflow 启用前的用户确认真的发生了**
  - 检查 orchestrator 的日志或对话中是否有明确的"是否启用 Workflow"提示
  - 确认用户有清晰的 y / N 选择（默认 N）
  - 用户未点 y 或点 N 时是否完全回到原串行流程（零行为变化）

---

## 五、成本与中断恢复

- [ ] **Token 消耗在可控范围**
  - 首次试跑的 token 计数与预估是否相符？（通常 30-50% 高于串行）
  - 若严重超支（翻倍以上），停止并检查：
    - 是否有不必要的重试？
    - 是否 prompt 模板过长？
    - 是否误派发了太多并行任务？

- [ ] **Workflow 可恢复性验证**
  - 模拟"Workflow 执行中途网络中断"，检查是否能续跑（而非从头开始）
  - 确认 orchestrator 保存了中间状态（如 task IDs 与部分结果）
  - 续跑后是否能正确跳过已完成任务、继续处理未完成任务

- [ ] **日志与诊断信息清晰**
  - Workflow 的每个 phase / task 是否都有明确的 log 输出？
  - 若某任务失败，日志中是否能快速定位根本原因（agent 错误 / 验证失败 / 超时）？

---

## 六、/goal 协同（长链路任务）

- [ ] **GOAL.md 正确生成**（仅长链路任务）
  - 检查 `team-state/GOAL.md` 格式是否遵循设计：
    ```
    - 原始需求: {一句话}
    - 完成条件: {可验证硬性标准}
    - Token 预算: {可选}
    - 设定于: {日期}
    ```
  - 确认"完成条件"是可自动或手工验证的（而非模糊的"做完"）

- [ ] **Workflow 脚本绑定了目标完成条件**
  - 检查 `team-dev-loop` / `audit-scan` 中是否读取并应用了 GOAL？
  - GOAL 的完成条件是否真的作为硬性终止条件（不能无限重试）？

- [ ] **长链路任务的 RETRY_LOG 附带目标距离**
  - 若任务卡住需重试，log 中是否明确指出"距离 GOAL 还缺什么"？

---

## 七、异常与回退验证

- [ ] **任一步异常时能安全回退**
  - 模拟失败场景：强制 Workflow 某个 agent 返回异常
  - 检查 orchestrator 是否能正确捕获异常（不崩溃）
  - 确认用户有机会决定"继续重试"还是"放弃 Workflow，回到串行"
  - 确认选择回退后完全回到原 markdown 流程（零行为变化）

- [ ] **回退后状态一致性**
  - 任何已完成的部分任务（如已写入的代码）是否被保留？
  - 是否没有"幽灵状态"（如标记完成但代码未写）？
  - 用户重新开始时是否清楚哪些已做、哪些需重做？

- [ ] **错误信息对开发者友好**
  - Workflow 失败的 error message 是否清晰指出原因？
  - 是否给出了修复建议（如"检查 API_CONTRACT.md" / "运行 npm test 校验"）？

---

## 八、首次实战后的检验清单

**在完成本清单所有项、且小范围试跑通过后，团队得出的结论**：

- [ ] 设计与实现一致吗？（是否发现设计漏洞需补充）
- [ ] 模板是否需要微调？（Prompt、agent 分配、重试策略等）
- [ ] 团队对 Workflow 启用点的理解清晰吗？（是否需重新培训）
- [ ] 是否可以安心下沉到生产项目？

---

**清单项目总数**：54 项可勾选

**推荐检查周期**：
- 完全首次：预留 2-3 小时，逐项逐步验证
- 日常使用：重点关注第四/七节（安全红线和异常回退），其余可快速复查

**遇到问题**：
- 若任何项失败，立即停止，向 software-architect 报告缺陷
- 勿尝试"绕过"检查点——设计的每一项都来自真实教训
