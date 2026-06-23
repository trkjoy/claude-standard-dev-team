/**
 * 夜间 Audit 巡检 workflow（P1-2 / P1-4 实现）
 *
 * 用途：
 *   无人值守、只读不改地并行跑 code-reviewer + security-engineer，
 *   把 Blocker 与安全问题结构化汇总后返回给调用方。
 *   调用方（orchestrator 或 GitHub Actions 脚本）负责把返回值
 *   写入 docs/NIGHTLY_AUDIT.md，本脚本本身不写任何文件。
 *
 * ┌──────────────── 产物约定 ──────────────────────────────────┐
 * │ 返回值：{ timestamp, blockerCount, findings[], budget }     │
 * │   - timestamp   取自 args.timestamp（调用方注入，本脚本不  │
 * │                 调用 Date.now()，以保证 resume 安全）       │
 * │   - blockerCount 含 critical + high severity 总数           │
 * │   - findings[]  完整结构化发现列表（含文件/行号/severity）  │
 * │   - budget      本次实际耗用情况快照                        │
 * │ 写文件由调用方负责，本脚本 return 对象 + log() 摘要即止。  │
 * └─────────────────────────────────────────────────────────────┘
 *
 * ┌──────────────── 红线约束 ─────────────────────────────────┐
 * │ 1. 只读不改：禁止写代码文件、修改配置、执行部署动作       │
 * │ 2. 禁止任何 push / merge / deploy / delete 操作           │
 * │ 3. 禁止触发任何需要人工确认的安全卡点动作                  │
 * │ 4. 产物只汇总不落危险操作，高危问题等待人工次日处置        │
 * └─────────────────────────────────────────────────────────────┘
 *
 * args 格式（调用方传入）：
 * {
 *   // 扫描目标路径列表（文件或目录）
 *   targets: ["src/", "controllers/"],
 *
 *   // 时间戳字符串（ISO 格式），调用方注入，不在脚本内调用 Date.now()
 *   timestamp: "2026-06-23T02:00:00Z",
 *
 *   // 可选：契约文件路径，默认 docs/API_CONTRACT.md
 *   contractPath: "docs/API_CONTRACT.md",
 *
 *   // 可选：预算配置（P1-4 成本闸）
 *   budget: {
 *     maxRounds: 3,              // 最大巡检轮次（默认 3）
 *     maxMinutes: 60,            // 最大允许分钟数（默认 60；依赖 args 传入的 startedAt）
 *     noProgressThreshold: 2,   // 连续无新增发现轮次阈值（默认 2）
 *   },
 *
 *   // 可选：调用方注入的 startedAt（ISO 格式），用于时间预算判断
 *   startedAt: "2026-06-23T02:00:00Z",
 * }
 *
 * GitHub Actions 示例（仅供文档参考，不落成激活文件）：
 *   # .github/workflows/nightly-audit.yml（在项目自身 repo 内创建，非本模板 repo）
 *   # on:
 *   #   schedule:
 *   #     - cron: '0 2 * * *'   # 每天 UTC 02:00
 *   # jobs:
 *   #   audit:
 *   #     runs-on: ubuntu-latest
 *   #     steps:
 *   #       - uses: actions/checkout@v4
 *   #       - name: Run nightly audit
 *   #         run: |
 *   #           claude -p "run workflow nightly-audit with args: $(cat <<'EOF'
 *   #           { \"targets\": [\"src/\"], \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
 *   #             \"startedAt\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
 *   #             \"budget\": { \"maxRounds\": 3, \"maxMinutes\": 60, \"noProgressThreshold\": 2 } }
 *   #           EOF
 *   #           )"
 *   # 注意：无 TTY 环境下 claude -p 模式才可用；凭据通过 secrets.ANTHROPIC_API_KEY 注入。
 */

export const meta = {
  name: "nightly-audit",
  description:
    "夜间无人值守只读巡检：并行派发 code-reviewer + security-engineer，结构化汇总 Blocker/安全问题；" +
    "内置 P1-4 成本闸（轮次/时间/无进展三维熔断）；只返回报告对象，写文件由调用方负责。",
  phases: ["预算初始化", "并行扫描", "汇总与熔断检测"],
};

// ──────────────────────────────────────────────
// 常量
// ──────────────────────────────────────────────

// 严重程度优先级（排序用）
const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };

// ──────────────────────────────────────────────
// P1-4 预算治理辅助
// ──────────────────────────────────────────────

/**
 * 判断时间预算是否已耗尽。
 * 注意：本脚本不调用 Date.now()（禁止，会破坏 resume）；
 * 时间戳由调用方通过 args.startedAt / args.timestamp 注入。
 * 若调用方未传入 startedAt，则无法做时间判断，降级跳过时间闸。
 *
 * @param {string|undefined} startedAt  ISO 时间戳，调用方注入
 * @param {string|undefined} nowTs      ISO 时间戳（当前时刻），调用方注入
 * @param {number} maxMinutes           最大允许分钟数
 * @returns {boolean}
 */
function isTimeBudgetExceeded(startedAt, nowTs, maxMinutes) {
  if (!startedAt || !nowTs) {
    // 待验证假设：若调用方未注入时间戳，时间闸不可用，降级跳过
    return false;
  }
  const elapsedMs = new Date(nowTs).getTime() - new Date(startedAt).getTime();
  return elapsedMs > maxMinutes * 60 * 1000;
}

/**
 * 判断 token 预算是否已耗尽。
 * Workflow 引擎的 budget 对象提供 remaining()；
 * 若 budget.total 为 null（未设置 token 目标），则跳过 token 闸，
 * 降级用轮次+时间+无进展三维兜底。
 *
 * 待验证假设：token 实时计量依赖运行环境暴露用量；
 * 若 budget.total === null，则 budget.remaining() === Infinity，
 * 本函数恒返回 false，即 token 闸不生效。
 *
 * @returns {boolean}
 */
function isTokenBudgetExceeded() {
  // budget 是 workflow 引擎注入的全局对象
  if (budget.total === null) {
    return false; // token 计量不可得，降级跳过
  }
  return budget.remaining() <= 0;
}

// ──────────────────────────────────────────────
// 扫描 agent prompt 构造
// ──────────────────────────────────────────────

function buildCodeReviewerPrompt(targets, contractPath) {
  return `
你是团队 code-reviewer，对以下路径执行只读代码审查，寻找 bug、逻辑错误和契约不一致。

【只读约束】：只阅读和分析代码，禁止写文件、禁止执行部署/删除操作。

【扫描目标】
${targets.join("\n")}

【契约文件参考】${contractPath}（如可读，请对照检查 API 路径/字段/状态码一致性）

重点检查：
- Blocker 级 bug（空指针/越界/未处理异常/数据竞争）
- 契约字段名、路径、HTTP 方法与实现不一致
- 不安全的类型转换或明显逻辑错误

每个发现必须包含：文件路径、行号（估计）、问题描述、severity（critical/high/medium/low）。
  `.trim();
}

function buildSecurityEngineerPrompt(targets) {
  return `
你是团队 security-engineer，对以下路径执行只读安全审查。

【只读约束】：只阅读和分析代码，禁止写文件、禁止执行任何变更操作。

【扫描目标】
${targets.join("\n")}

重点检查（OWASP Top 10 优先）：
- SQL 注入、XSS、CSRF
- 硬编码密钥或敏感信息泄露
- 不当权限校验或越权访问
- 不安全的依赖或配置

每个发现必须包含：文件路径、行号（估计）、问题描述、severity（critical/high/medium/low）、
OWASP 分类（如适用）。
  `.trim();
}

// ──────────────────────────────────────────────
// 结构化发现 schema（两个 agent 共用）
// ──────────────────────────────────────────────

const FINDING_SCHEMA = {
  type: "object",
  properties: {
    findings: {
      type: "array",
      items: {
        type: "object",
        properties: {
          file:     { type: "string", description: "发现问题的文件路径" },
          line:     { type: "string", description: "行号或代码位置提示" },
          severity: { type: "string", enum: ["critical", "high", "medium", "low"] },
          title:    { type: "string", description: "问题标题（一句话）" },
          detail:   { type: "string", description: "详细描述和修复建议" },
          category: { type: "string", description: "分类标签，如 sql-injection / null-deref / field-mismatch 等" },
        },
        required: ["file", "severity", "title", "detail"],
      },
    },
  },
  required: ["findings"],
};

// ──────────────────────────────────────────────
// 去重辅助：file + title 前 40 字 + line 组成 key
// ──────────────────────────────────────────────

function dedup(findings) {
  const seen = new Set();
  return findings.filter((f) => {
    const key = `${f.file}::${f.severity}::${f.title.slice(0, 40)}::${f.line ?? ""}`;
    if (seen.has(key)) return false;
    seen.add(key);
    return true;
  });
}

// ──────────────────────────────────────────────
// 主流程
// ──────────────────────────────────────────────

// 从 args 解构参数，提供安全默认值
const targets      = args.targets      ?? ["src/"];
const timestamp    = args.timestamp    ?? "unknown";
const contractPath = args.contractPath ?? "docs/API_CONTRACT.md";
const startedAt    = args.startedAt    ?? null;

// P1-4 预算配置（从 args.budget 读取，调用方可覆盖）
const budgetCfg = {
  maxRounds:           args.budget?.maxRounds           ?? 3,
  maxMinutes:          args.budget?.maxMinutes          ?? 60,
  noProgressThreshold: args.budget?.noProgressThreshold ?? 2,
};

phase("预算初始化");
log(`夜间 Audit 启动 — timestamp=${timestamp}`);
log(`扫描目标：${targets.join(", ")}`);
log(`预算配置：最大轮次=${budgetCfg.maxRounds} / 最大时间=${budgetCfg.maxMinutes}分钟 / 无进展阈值=${budgetCfg.noProgressThreshold}轮`);
log(
  budget.total === null
    ? "token 计量：不可得（降级为轮次+时间+无进展三维兜底）"
    : `token 预算：总量=${budget.total} / 剩余=${budget.remaining()}`
);

// 循环状态
let round = 0;                  // 当前轮次（从 1 开始）
let noProgressRounds = 0;       // 连续无进展轮次计数
let prevFindingCount = -1;      // 上一轮发现数（-1 表示首轮）
let allFindings = [];           // 累积发现（已去重）
let fuseReason = null;          // 熔断原因（null 表示未熔断）

// 主巡检循环（最多 maxRounds 轮）
while (round < budgetCfg.maxRounds) {
  round++;

  // ── P1-4 成本闸：每轮前多维检查 ──────────────────────────────

  // 1. token 预算闸（若 budget.total 可得）
  if (isTokenBudgetExceeded()) {
    fuseReason = `token 预算耗尽（已用=${budget.spent()} / 总量=${budget.total}）`;
    log(`[成本闸] 熔断：${fuseReason}`);
    break;
  }

  // 2. 时间预算闸（依赖调用方注入 startedAt 和当前 nowTs）
  // nowTs 由调用方在每轮 args 中更新（首次调用后续轮次可通过 args.nowTs 覆盖）
  // 待验证假设：若调用方不注入 nowTs，时间闸降级跳过
  const nowTs = args.nowTs ?? null;
  if (isTimeBudgetExceeded(startedAt, nowTs, budgetCfg.maxMinutes)) {
    fuseReason = `时间预算耗尽（已超 ${budgetCfg.maxMinutes} 分钟）`;
    log(`[成本闸] 熔断：${fuseReason}`);
    break;
  }

  // 3. 无进展检测
  if (noProgressRounds >= budgetCfg.noProgressThreshold) {
    fuseReason = `无进展熔断：连续 ${noProgressRounds} 轮发现数无新增（阈值=${budgetCfg.noProgressThreshold}）`;
    log(`[成本闸] 熔断：${fuseReason}`);
    break;
  }

  phase(`并行扫描（第 ${round} / ${budgetCfg.maxRounds} 轮）`);
  log(`第 ${round} 轮扫描开始`);

  // ── 并行派发两个 agent ──────────────────────────────────────

  const [codeReviewResult, securityResult] = await parallel([
    async () =>
      agent(buildCodeReviewerPrompt(targets, contractPath), {
        label: `nightly-code-review-r${round}`,
        phase: `并行扫描第${round}轮`,
        agentType: "code-reviewer",
        schema: FINDING_SCHEMA,
      }),
    async () =>
      agent(buildSecurityEngineerPrompt(targets), {
        label: `nightly-security-r${round}`,
        phase: `并行扫描第${round}轮`,
        agentType: "security-engineer",
        schema: FINDING_SCHEMA,
      }),
  ]);

  // ── 合并本轮发现（filter(Boolean) 处理 agent 失败降为 null 的情况）──

  const thisRoundFindings = [
    ...(codeReviewResult?.findings ?? []),
    ...(securityResult?.findings   ?? []),
  ];

  // 追加到累积列表并去重
  const combined = dedup([...allFindings, ...thisRoundFindings]);
  const newCount = combined.length - allFindings.length;
  allFindings = combined;

  log(`第 ${round} 轮完成 — 本轮新增 ${newCount} 条发现 / 累积 ${allFindings.length} 条`);

  // ── 无进展检测更新 ───────────────────────────────────────────

  if (prevFindingCount === allFindings.length) {
    // 去重后总数与上轮相同 → 无新进展
    noProgressRounds++;
    log(`[无进展检测] 连续 ${noProgressRounds} 轮无新增`);
  } else {
    noProgressRounds = 0;
  }
  prevFindingCount = allFindings.length;
}

// ──────────────────────────────────────────────
// 汇总阶段
// ──────────────────────────────────────────────

phase("汇总与熔断检测");

// 按 severity 排序
allFindings.sort(
  (a, b) => (SEVERITY_ORDER[a.severity] ?? 9) - (SEVERITY_ORDER[b.severity] ?? 9)
);

const blockerCount = allFindings.filter(
  (f) => f.severity === "critical" || f.severity === "high"
).length;

const bySeverity = {
  critical: allFindings.filter((f) => f.severity === "critical").length,
  high:     allFindings.filter((f) => f.severity === "high").length,
  medium:   allFindings.filter((f) => f.severity === "medium").length,
  low:      allFindings.filter((f) => f.severity === "low").length,
};

// log 摘要（调用方可据此决定是否写文件/通知）
log(`═══ 夜间 Audit 摘要 ═══`);
log(`timestamp  : ${timestamp}`);
log(`总发现数   : ${allFindings.length}`);
log(`Blocker 数 : ${blockerCount}（critical=${bySeverity.critical} / high=${bySeverity.high}）`);
log(`medium     : ${bySeverity.medium} / low=${bySeverity.low}`);
log(`实际轮次   : ${round} / ${budgetCfg.maxRounds}`);
log(`熔断       : ${fuseReason ?? "未触发（正常完成）"}`);
log(
  budget.total === null
    ? "token 耗用  : 不可计量（降级模式）"
    : `token 耗用  : ${budget.spent()} / ${budget.total}`
);

// 返回结构化汇总对象（调用方写入 docs/NIGHTLY_AUDIT.md）
return {
  // 时间戳取自 args，不在脚本内生成
  timestamp,

  // Blocker 计数（critical + high）
  blockerCount,

  // 各级别计数
  bySeverity,

  // 完整发现列表（已去重、已排序）
  findings: allFindings,

  // 预算使用快照
  budget: {
    roundsUsed:   round,
    roundsMax:    budgetCfg.maxRounds,
    // token 计量：若 budget.total 为 null 则为 "N/A"（待验证假设）
    tokenSpent:   budget.total !== null ? budget.spent()     : "N/A",
    tokenTotal:   budget.total !== null ? budget.total        : "N/A",
    fuseTriggered: fuseReason !== null,
    fuseReason:   fuseReason ?? null,
  },
};
