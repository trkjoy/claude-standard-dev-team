/**
 * Audit 多维并行 + 对抗式验证模板
 *
 * 用途：
 *   在「模板 B Audit 全仓审查」或「Phase 7 安全审计」阶段，
 *   当扫描范围 ≥50 个文件 或 需要对抗式独立验证时，
 *   由 orchestrator 提示用户确认后调用本脚本。
 *
 * 调用方式：
 *   orchestrator 确认后传入 args（见下方格式），跑完后将返回的
 *   已确认问题清单写入 team-state/STATE.md / docs/AUDIT_REPORT.md 并继续验收。
 *
 * 安全约束（必须遵守）：
 *   - 本脚本仅做「发现 + 确认」，不执行任何修复、删除、部署动作。
 *   - 高危问题的修复决策 永远由 orchestrator 串行把关，不在此并行下放。
 *   - 安全确认点（如发现严重漏洞后是否立即停止部署）由 orchestrator 决定。
 *
 * args 格式：
 * {
 *   // 扫描目标路径列表（文件或目录）
 *   targets: ["src/", "controllers/", "..."],
 *
 *   // 可选：启用的扫描维度，默认全部开启
 *   // 可选值："bug" | "performance" | "security" | "contract"
 *   dimensions: ["bug", "performance", "security", "contract"],
 *
 *   // 可选：对抗式验证所需的最低确认票数（默认 2）
 *   // 即：需要 confirmThreshold 个独立 agent 同意才算真问题
 *   confirmThreshold: 2,
 *
 *   // TODO（接入时填写）：项目契约文件路径，供 contract 维度使用
 *   contractPath: "docs/API_CONTRACT.md",
 * }
 */

export const meta = {
  name: "audit-scan",
  description: "Audit 多维并行扫描 + 对抗式验证：bug/性能/安全/契约四维度并行，每个发现由独立 agent 对抗确认，多票才算真问题",
  phases: ["多维扫描", "对抗式验证", "去重汇总"],
};

// ─────────────────────────────────────────────
// 常量与默认值
// ─────────────────────────────────────────────

// 支持的扫描维度及其使用的 agent
const DIMENSION_AGENT_MAP = {
  bug:         "code-reviewer",      // bug 与正确性审查
  performance: "code-reviewer",      // 性能问题（code-reviewer 兼顾）
  security:    "security-engineer",  // 安全漏洞、威胁建模
  contract:    "code-reviewer",      // 契约一致性（字段/路径/状态码）
};

// 对抗式验证使用的 agent —— 两票都必须与「扫描 agent」不同，保证独立性。
// 第1票：安全维度由 code-reviewer 反驳，其余维度由 security-engineer 反驳（均 ≠ 扫描者）。
// 第2票：固定用 reality-checker —— 它从不参与扫描，天然独立，且本职就是怀疑式验证，
//         避免此前"第2票投回扫描 agent 自己"导致独立性形同虚设的问题。
function resolveRefuteAgentType(dimension) {
  return dimension === "security" ? "code-reviewer" : "security-engineer";
}
const SECOND_VOTE_AGENT = "reality-checker";

// ─────────────────────────────────────────────
// 阶段1：多维度并行扫描
// 每个维度独立派发 agent，互不等待（parallel 有屏障，全部完成后继续）
// ─────────────────────────────────────────────

async function runMultiDimensionScan(targets, dimensions, contractPath) {
  phase("多维扫描");
  log(`扫描目标：${targets.join(", ")}`);
  log(`启用维度：${dimensions.join(", ")}`);

  // 为每个维度构造扫描 thunk
  const scanThunks = dimensions.map((dim) => async () => {
    const agentType = DIMENSION_AGENT_MAP[dim];
    log(`[扫描] 维度=${dim} agent=${agentType}`);

    // TODO（接入时填写）：根据项目实际调整 prompt，补充框架/技术栈背景
    const dimPrompts = {
      bug: `
你是团队 code-reviewer，请对以下代码路径执行 bug 与正确性审查。

【扫描目标】
${targets.join("\n")}

请重点检查：空指针/越界、逻辑错误、未处理异常、不安全的类型转换。
输出发现的问题列表，每项包含：文件路径、行号（估计）、问题描述、严重程度(high/medium/low)。
      `,
      performance: `
你是团队 code-reviewer，请对以下代码路径执行性能审查。

【扫描目标】
${targets.join("\n")}

请重点检查：N+1 查询、无索引大表扫描、同步阻塞 I/O、内存泄漏风险、无限循环风险。
输出发现的问题列表，每项包含：文件路径、行号（估计）、问题描述、严重程度(high/medium/low)。
      `,
      security: `
你是团队 security-engineer，请对以下代码路径执行安全审查。

【扫描目标】
${targets.join("\n")}

请重点检查：SQL 注入、XSS、CSRF、不安全反序列化、硬编码密钥、权限绕过、不当的 CORS 配置。
输出发现的问题列表，每项包含：文件路径、行号（估计）、问题描述、CVE/OWASP 分类（如适用）、严重程度(critical/high/medium/low)。
      `,
      contract: `
你是团队 code-reviewer，请对以下代码路径执行契约一致性审查。

【扫描目标】
${targets.join("\n")}

【契约文件路径】${contractPath ?? "docs/API_CONTRACT.md"}（请读取后对照检查）

请重点检查：API 路径拼写、HTTP 方法、请求/响应字段名、状态码是否与契约一致。
输出发现的问题列表，每项包含：文件路径、具体不一致描述、严重程度(high/medium/low)。
      `,
    };

    const findings = await agent(dimPrompts[dim].trim(), {
      label: `扫描-${dim}`,
      phase: "多维扫描",
      agentType,
      schema: {
        type: "object",
        properties: {
          dimension: { type: "string" },
          findings: {
            type: "array",
            items: {
              type: "object",
              properties: {
                filePath:    { type: "string" },
                lineHint:    { type: "string", description: "行号或代码片段提示" },
                description: { type: "string" },
                severity:    { type: "string", enum: ["critical", "high", "medium", "low"] },
                category:    { type: "string", description: "分类标签，如 sql-injection / n+1 / field-mismatch 等" },
              },
              required: ["filePath", "description", "severity"],
            },
          },
        },
        required: ["dimension", "findings"],
      },
    });

    // 明确取 findings.findings 数组，避免 spread 整个返回对象时
    // agent 自填的 dimension 字段覆盖外层硬编码的 dim（控制字段污染）
    return { dimension: dim, findings: findings.findings ?? [] };
  });

  // parallel 有屏障：全部维度扫描完成后才进入下一阶段
  const scanResults = await parallel(scanThunks);
  return scanResults;
}

// ─────────────────────────────────────────────
// 阶段2：对抗式验证
// 对每个发现，派独立 agent 从"refute（反驳）"视角审查，
// 需要 confirmThreshold 个 agent 同意才算真问题。
// ─────────────────────────────────────────────

async function runAdversarialVerification(allFindings, confirmThreshold) {
  phase("对抗式验证");

  // 将所有维度的发现展平为一个列表，附加维度标签
  const flatFindings = [];
  for (const scanResult of allFindings) {
    for (const finding of scanResult.findings ?? []) {
      flatFindings.push({ ...finding, dimension: scanResult.dimension });
    }
  }

  log(`待对抗验证的发现总数：${flatFindings.length}（确认阈值：${confirmThreshold} 票）`);

  if (flatFindings.length === 0) {
    log("无发现，跳过对抗验证");
    return [];
  }

  // 为每个发现构造对抗验证 thunk（pipeline 无屏障，最优并行）
  // 注意：每个发现独立验证，互不阻塞
  const verifiedFindings = await pipeline(
    flatFindings,

    // 投票轮次1：第一个独立 agent 审查
    async (finding) => {
      return runSingleVote(finding, 1);
    },

    // 投票轮次2：第二个独立 agent（reality-checker）审查
    async (voteContext) => {
      if (!voteContext) return null; // 上一阶段异常被降为 null，安全跳过
      const vote2 = await runSingleVote(voteContext.finding, 2);
      const votes = [voteContext.vote, vote2.vote].filter(Boolean);
      const confirmedCount = votes.filter((v) => v.confirmed).length;

      // 严重程度感知的确认规则（安全审计：宁可误报勿漏报）：
      //   critical / high → 任一票确认即保留，并标记 needsHumanReview（不被单票误判静默丢弃）
      //   medium / low    → 需达到 confirmThreshold 票（默认 2，降噪）
      const sev = voteContext.finding.severity;
      const isHigh = sev === "critical" || sev === "high";
      const isConfirmed = isHigh ? confirmedCount >= 1 : confirmedCount >= confirmThreshold;
      const needsHumanReview = isHigh && confirmedCount < 2; // 高危但非全票 → 提请人工复核

      return {
        finding: voteContext.finding,
        votes,
        confirmedCount,
        isConfirmed,
        needsHumanReview,
        suggestions: votes.flatMap((v) => v.suggestions ?? []),
      };
    },
  );

  const confirmed = verifiedFindings.filter(Boolean).filter((r) => r.isConfirmed);
  log(`对抗验证完成 — 确认真问题：${confirmed.length} / 总发现：${flatFindings.length}`);
  return verifiedFindings;
}

/**
 * 单次投票：派一个独立 agent 以"反驳"视角审查某个发现，
 * 判断是真问题还是误报。
 * @param {object} finding - 单条发现
 * @param {number} round   - 投票轮次（1 或 2），用于切换 agentType 保证独立性
 */
async function runSingleVote(finding, round) {
  // 两轮使用不同 agentType，确保独立视角
  const agentType = round === 1
    ? resolveRefuteAgentType(finding.dimension)
    : SECOND_VOTE_AGENT;

  log(`[对抗] 第${round}票 维度=${finding.dimension} 严重程度=${finding.severity} agent=${agentType}`);

  // TODO（接入时填写）：可补充项目技术栈背景提升投票准确性
  const refutePrompt = `
你是独立审查员（${agentType}），请以"反驳"视角审查以下发现，判断它是真实问题还是误报。

【发现文件】${finding.filePath}
【代码位置】${finding.lineHint ?? "未提供"}
【问题描述】${finding.description}
【严重程度】${finding.severity}
【扫描维度】${finding.dimension}

请仔细分析：
1. 这个问题在实际运行中是否真的会触发？
2. 是否存在已有的防御措施（中间件、校验等）？
3. 是否是扫描工具/agent 的误报？

返回你的判断：
- confirmed: true（确认是真问题）或 false（误报/不成立）
- reason: 判断理由（1-2 句）
- suggestions: 若确认，提供修复建议（可为空数组）
  `.trim();

  const voteResult = await agent(refutePrompt, {
    label: `投票-${finding.filePath}-round${round}`,
    phase: "对抗式验证",
    agentType,
    schema: {
      type: "object",
      properties: {
        confirmed:   { type: "boolean" },
        reason:      { type: "string" },
        suggestions: { type: "array", items: { type: "string" } },
      },
      required: ["confirmed", "reason"],
    },
  });

  // 容错：agent 无响应 / schema 校验失败返回 null 时，不让整条 pipeline 崩。
  // 记为 confirmed=false，但严重程度判定在上层做（critical/high 任一票确认即保留）。
  if (!voteResult) {
    return { finding, vote: { confirmed: false, reason: "验证 agent 无响应（已容错）", suggestions: [] } };
  }
  return { finding, vote: voteResult };
}

// ─────────────────────────────────────────────
// 阶段3：去重汇总
// 相同文件+相似描述的问题合并，输出最终清单
// ─────────────────────────────────────────────

function deduplicateAndSummarize(verifiedFindings) {
  phase("去重汇总");

  const confirmed = verifiedFindings.filter(Boolean).filter((r) => r.isConfirmed);

  // 简单去重：filePath + dimension + 描述前 40 字 + 行号提示（加 lineHint，避免把同文件
  // 同维度下两个前 40 字相同、实际不同的问题误并）
  const seen = new Set();
  const unique = [];
  for (const item of confirmed) {
    const key = `${item.finding.filePath}::${item.finding.dimension}::${item.finding.description.slice(0, 40)}::${item.finding.lineHint ?? ""}`;
    if (!seen.has(key)) {
      seen.add(key);
      unique.push({
        filePath:        item.finding.filePath,
        lineHint:        item.finding.lineHint ?? "",
        description:     item.finding.description,
        severity:        item.finding.severity,
        dimension:       item.finding.dimension,
        category:        item.finding.category ?? "",
        confirmedBy:     item.confirmedCount,
        needsHumanReview: item.needsHumanReview ?? false,
        suggestions:     item.suggestions ?? [],
      });
    }
  }

  // 按严重程度排序：critical > high > medium > low
  const severityOrder = { critical: 0, high: 1, medium: 2, low: 3 };
  unique.sort((a, b) => (severityOrder[a.severity] ?? 9) - (severityOrder[b.severity] ?? 9));

  log(`去重后确认问题：${unique.length} 条`);
  return unique;
}

// ─────────────────────────────────────────────
// 主流程
// ─────────────────────────────────────────────

log("Audit 多维并行扫描启动");

// 从 args 解构参数，提供安全默认值
const targets           = args.targets           ?? ["src/"];
const dimensions        = args.dimensions        ?? ["bug", "performance", "security", "contract"];
const contractPath      = args.contractPath      ?? "docs/API_CONTRACT.md";

// 本脚本固定产生 2 票，confirmThreshold 只在 [1,2] 有意义。
// 钳制以消除"传 3 则 >=3 永远不成立、所有问题被静默全丢"的配置陷阱。
const rawThreshold      = args.confirmThreshold  ?? 2;
const confirmThreshold  = Math.max(1, Math.min(2, rawThreshold));
if (rawThreshold !== confirmThreshold) {
  log(`⚠️ confirmThreshold=${rawThreshold} 超出 [1,2]，已钳制为 ${confirmThreshold}（本脚本固定 2 票；注意 critical/high 恒为任一票确认即保留）`);
}

log(`目标路径：${targets.join(", ")}`);
log(`扫描维度：${dimensions.join(", ")}`);
log(`确认阈值：${confirmThreshold} 票`);

// 阶段1：多维度并行扫描
const scanResults = await runMultiDimensionScan(targets, dimensions, contractPath);

// 阶段2：对抗式验证
const verifiedFindings = await runAdversarialVerification(scanResults, confirmThreshold);

// 阶段3：去重汇总
const confirmedIssues = deduplicateAndSummarize(verifiedFindings);

// ─────────────────────────────────────────────
// 返回值：orchestrator 据此写 AUDIT_REPORT.md / STATE.md
// ─────────────────────────────────────────────
log(`Audit 完成 — 已确认问题 ${confirmedIssues.length} 条`);

return {
  summary: {
    totalFindingsBeforeVerification: scanResults.reduce((n, r) => n + (r.findings?.length ?? 0), 0),
    confirmedIssues: confirmedIssues.length,
    bySeverity: {
      critical: confirmedIssues.filter((i) => i.severity === "critical").length,
      high:     confirmedIssues.filter((i) => i.severity === "high").length,
      medium:   confirmedIssues.filter((i) => i.severity === "medium").length,
      low:      confirmedIssues.filter((i) => i.severity === "low").length,
    },
    // 高危但未获全票的项数 —— orchestrator 应提请用户人工复核
    needsHumanReview: confirmedIssues.filter((i) => i.needsHumanReview).length,
  },
  // 已去重、已排序的确认问题清单，供 orchestrator 写入报告
  issues: confirmedIssues,
};
