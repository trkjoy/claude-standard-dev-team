/**
 * 后端 / 前端 Dev-QA Loop 并行流水线模板
 *
 * 用途：
 *   在 Phase 5（后端接口实现）或 Phase 6（前端页面实现）中，
 *   当独立可并行任务数 ≥5 时，由 orchestrator 提示用户确认后调用本脚本。
 *
 * 调用方式：
 *   orchestrator 在用户确认启用 Workflow 引擎后，将任务清单作为 args 传入，
 *   跑完后将返回的 PASS/FAIL 清单写入 team-state/STATE.md 并继续常规验收流程。
 *
 * 安全约束（必须遵守）：
 *   - 部署 / 热部署 / 删除文件 / git push 等不可逆操作 永远不进此并行流程。
 *   - 安全确认点仍由 orchestrator 串行把关，本脚本不含任何不可逆动作。
 *
 * args 格式（数组，每项一个任务）：
 * [
 *   {
 *     id: "TASK-B01",               // 任务编号，用于标识结果
 *     layer: "backend" | "frontend", // 决定使用哪个实现 agent
 *     description: "...",            // 接口/页面描述
 *     acceptanceCriteria: "...",     // 验收标准（给 QA agent 用）
 *     contractSnippet: "...",        // 相关契约片段（路径/字段/状态码等）
 *   },
 *   ...
 * ]
 */

export const meta = {
  name: "team-dev-loop",
  description: "后端/前端 Dev-QA Loop 并行流水线：每个任务独立穿过「实现 → QA 验证」，保留重试语义，FAIL ≤2 次后标记失败",
  phases: ["实现阶段", "QA 验证阶段"],
};

// ─────────────────────────────────────────────
// 工具函数：根据 layer 决定使用哪个实现 agent
// ─────────────────────────────────────────────
function resolveImplementAgentType(layer) {
  if (layer === "frontend") return "frontend-developer";
  // 默认后端（layer === "backend" 或未指定）
  return "backend-architect";
}

// ─────────────────────────────────────────────
// 单任务流水线（实现 → QA，内置重试）
// pipeline 无屏障，每个任务项目独立流动。
// ─────────────────────────────────────────────

/**
 * 阶段1：实现
 * 派发给 backend-architect 或 frontend-developer，
 * 传入任务描述 + 契约片段，产出实现结果摘要。
 */
async function stageImplement(task) {
  phase("实现阶段");
  log(`[${task.id}] 开始实现 (${task.layer ?? "backend"})`);

  const agentTypeImpl = resolveImplementAgentType(task.layer ?? "backend");

  // TODO（接入时填写）：根据项目实际情况补充 prompt 中的项目路径、技术栈说明
  const implPrompt = `
你是团队 ${agentTypeImpl}，请实现以下任务。

【任务编号】${task.id}
【任务描述】
${task.description}

【相关契约片段】
${task.contractSnippet ?? "（无契约片段，请参考项目 docs/API_CONTRACT.md）"}

【验收标准】（实现时参考，QA 阶段将据此验证）
${task.acceptanceCriteria}

请按项目分层规范完成实现，并在输出结尾用以下格式汇报：
IMPL_SUMMARY: <一句话描述完成了什么，包含关键文件路径>
  `.trim();

  const implResult = await agent(implPrompt, {
    label: `实现-${task.id}`,
    phase: "实现阶段",
    agentType: agentTypeImpl,
    schema: {
      type: "object",
      properties: {
        implSummary: { type: "string", description: "实现结果摘要" },
        filesChanged: {
          type: "array",
          items: { type: "string" },
          description: "改动的文件路径列表",
        },
      },
      required: ["implSummary"],
    },
  });

  return { task, implResult };
}

/**
 * 阶段2：QA 验证（含重试逻辑，最多重试 2 次）
 * 派发给 testing-evidence-collector，
 * 返回 PASS 或 FAIL，并附带失败原因供重试使用。
 */
async function stageVerify(context) {
  phase("QA 验证阶段");
  const { task, implResult } = context;

  // 最多执行 1 次初始验证 + 2 次重试 = 共 3 次机会
  const MAX_ATTEMPTS = 3;
  let lastVerifyResult = null;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
    log(`[${task.id}] QA 验证第 ${attempt} 次`);

    // TODO（接入时填写）：补充项目实际的测试命令、截图路径、验证方式
    const verifyPrompt = `
你是团队 testing-evidence-collector，请对以下任务的实现结果进行验证。

【任务编号】${task.id}
【验收标准】
${task.acceptanceCriteria}

【实现摘要】
${implResult?.implSummary ?? "（无摘要）"}

【改动文件】
${(implResult?.filesChanged ?? []).join("\n") || "（未提供）"}

${attempt > 1 ? `【上次失败原因】\n${lastVerifyResult?.failReason ?? "未知"}\n` : ""}

请执行验证（运行测试、检查响应结构、截图取证等），并返回判决：
- verdict: "PASS" 或 "FAIL"
- evidence: 验证证据摘要（通过用例列表 或 失败截图路径）
- failReason: 若 FAIL，简要说明失败原因（供重试参考）
    `.trim();

    const verifyResult = await agent(verifyPrompt, {
      label: `QA-${task.id}-attempt${attempt}`,
      phase: "QA 验证阶段",
      agentType: "testing-evidence-collector",
      schema: {
        type: "object",
        properties: {
          verdict: { type: "string", enum: ["PASS", "FAIL"] },
          evidence: { type: "string", description: "验证证据摘要" },
          failReason: { type: "string", description: "失败原因（FAIL 时填写）" },
        },
        required: ["verdict", "evidence"],
      },
    });

    lastVerifyResult = verifyResult;

    if (verifyResult.verdict === "PASS") {
      log(`[${task.id}] QA PASS（第 ${attempt} 次）`);
      return {
        taskId: task.id,
        verdict: "PASS",
        attempts: attempt,
        evidence: verifyResult.evidence,
        implSummary: implResult?.implSummary ?? "",
      };
    }

    // FAIL：若还有重试机会，继续循环；否则标记最终失败
    if (attempt < MAX_ATTEMPTS) {
      log(`[${task.id}] QA FAIL，准备第 ${attempt + 1} 次重试。原因：${verifyResult.failReason}`);
      // 重试前可在此补充：通知实现 agent 修复（TODO：如需自动修复可在此调用 agent）
    }
  }

  // 超过最大重试次数，标记最终失败
  log(`[${task.id}] QA 最终 FAIL（已重试 ${MAX_ATTEMPTS - 1} 次）`);
  return {
    taskId: task.id,
    verdict: "FAIL",
    attempts: MAX_ATTEMPTS,
    evidence: lastVerifyResult?.evidence ?? "",
    failReason: lastVerifyResult?.failReason ?? "超过最大重试次数",
    implSummary: implResult?.implSummary ?? "",
  };
}

// ─────────────────────────────────────────────
// 主流程：用 pipeline 让每个任务独立穿过两阶段
// pipeline(items, stage1, stage2) 无屏障，
// 任务之间互不等待，最优并行吞吐。
// ─────────────────────────────────────────────

log("Dev-QA Loop 并行流水线启动");
log(`任务总数：${args.length}`);

// args 即调用方传入的任务清单数组（格式见文件顶部注释）
const results = await pipeline(
  args,
  stageImplement, // 阶段1：实现
  stageVerify,    // 阶段2：QA 验证（含重试）
);

// ─────────────────────────────────────────────
// 汇总：输出 PASS/FAIL 清单供 orchestrator 写入 STATE.md
// ─────────────────────────────────────────────
const passed = results.filter((r) => r.verdict === "PASS");
const failed = results.filter((r) => r.verdict === "FAIL");

log(`流水线完成 — PASS: ${passed.length} / FAIL: ${failed.length} / 总计: ${results.length}`);

// 返回值结构由 orchestrator 接收并写入 team-state/STATE.md
return {
  summary: {
    total: results.length,
    passed: passed.length,
    failed: failed.length,
  },
  // 每项含 taskId / verdict / attempts / evidence / implSummary / failReason(可选)
  results,
};
