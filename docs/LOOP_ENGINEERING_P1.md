# Loop Engineering P1 能力使用说明

> 版本: 1.0 | 日期: 2026-06-23
> 对应蓝图: `docs/LOOP_ENGINEERING_BLUEPRINT.md` P1 改造表

P1 给标准团队补上了"非人触发的自动循环 + 成本闸 + 契约硬 gate + 失败模式聚合"四类能力。**这些能力默认不激活，需要按下文步骤显式启用。** 不启用任何一项，现有串行流程完全不受影响。

---

## 目录

1. [P1-2 夜间 Audit 自动循环](#p1-2-夜间-audit-自动循环)
2. [P1-4 预算熔断与 BUDGET_BURN 记录](#p1-4-预算熔断与-budget_burn-记录)
3. [P1-1 contract-diff 契约硬 gate](#p1-1-contract-diff-契约硬-gate)
4. [P1-3 CI 失败收集 hook](#p1-3-ci-失败收集-hook)
5. [P1-5 跨项目 trace 聚合](#p1-5-跨项目-trace-聚合)
6. [已知限制](#已知限制)
7. [与 P0 的关系](#与-p0-的关系)

---

## P1-2 夜间 Audit 自动循环

### 它是什么

无人值守的只读巡检 workflow。每次运行时并行派发 `code-reviewer` 和 `security-engineer` 两个 agent 扫描指定目录，把 Blocker 与安全发现结构化汇总后返回给调用方。**本 workflow 自身不写任何文件**——写 `docs/NIGHTLY_AUDIT.md` 由调用方负责。

三条红线在代码中强制约束：
- 只读不改，禁止写代码文件或修改配置
- 禁止任何 push / merge / deploy / delete 操作
- 禁止触发需要人工确认的安全卡点动作

### 分发路径

workflow 文件位于本模板仓库：

```
templates/workflows/nightly-audit.workflow.js
```

将其复制到用户级 workflows 目录后方可被 Claude 识别：

```
~/.claude/team-workflows/nightly-audit.workflow.js
```

### 怎么触发

**方式一：手动单次触发（验证用）**

在 Claude 会话中执行：

```
run workflow nightly-audit with args: {
  "targets": ["src/"],
  "timestamp": "2026-06-23T02:00:00Z",
  "startedAt": "2026-06-23T02:00:00Z",
  "budget": { "maxRounds": 3, "maxMinutes": 60, "noProgressThreshold": 2 }
}
```

**方式二：cron 定时触发（在目标项目仓库内创建，不在本模板 repo 内）**

在目标项目 `.github/workflows/nightly-audit.yml` 中创建：

```yaml
on:
  schedule:
    - cron: '0 2 * * *'   # 每天 UTC 02:00
jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run nightly audit
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: |
          claude -p "run workflow nightly-audit with args: $(cat <<'EOF'
          { "targets": ["src/"], "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "startedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
            "budget": { "maxRounds": 3, "maxMinutes": 60, "noProgressThreshold": 2 } }
          EOF
          )"
```

注意：无 TTY 环境下必须用 `claude -p` 模式；凭据通过 `secrets.ANTHROPIC_API_KEY` 注入。

**调用方的完整 args 格式：**

| 字段 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `targets` | 字符串数组 | `["src/"]` | 扫描目标路径（文件或目录） |
| `timestamp` | ISO 字符串 | 必填 | 由调用方注入，脚本内不调用 Date.now() |
| `startedAt` | ISO 字符串 | null | 时间预算起点，不传则时间闸降级跳过 |
| `contractPath` | 字符串 | `docs/API_CONTRACT.md` | 契约文件路径 |
| `budget.maxRounds` | number | 3 | 最大巡检轮次 |
| `budget.maxMinutes` | number | 60 | 最大允许分钟数 |
| `budget.noProgressThreshold` | number | 2 | 连续无新增发现即熔断的轮次阈值 |

### 产出在哪

workflow 返回一个结构化对象，字段如下：

```json
{
  "timestamp": "调用方注入的时间戳",
  "blockerCount": 3,
  "bySeverity": { "critical": 1, "high": 2, "medium": 4, "low": 1 },
  "findings": [ { "file": "src/auth.ts", "line": "42", "severity": "critical", "title": "...", "detail": "...", "category": "..." } ],
  "budget": {
    "roundsUsed": 2,
    "roundsMax": 3,
    "tokenSpent": "N/A",
    "tokenTotal": "N/A",
    "fuseTriggered": false,
    "fuseReason": null
  }
}
```

**调用方（GitHub Actions 脚本或 orchestrator）负责**把该返回值写入 `docs/NIGHTLY_AUDIT.md`。

### 验收标准

蓝图 P1-2 的验收标准：无人值守环境下产出当日 Audit 报告；Blocker 计数与手动 Audit 抽样核对一致。

### 待验证假设

- GitHub Actions 无 TTY 环境下 `claude -p` 模式的凭据注入与命令形态需在实际 CI 环境实测
- `budget.total` 的 token 实时计量依赖运行环境暴露用量；若不可得，token 闸自动降级（`tokenSpent` 返回 `"N/A"`），由轮次 + 时间 + 无进展三维兜底

---

## P1-4 预算熔断与 BUDGET_BURN 记录

### 它是什么

`nightly-audit.workflow.js` 内置的三维成本闸，防止自动循环无限烧钱（loopmaxxing）。三个维度独立检测，任一触发即熔断：

| 维度 | 触发条件 | 熔断行为 |
|------|----------|----------|
| 轮次 | 达到 `maxRounds` | 退出循环，返回已累积发现 |
| 时间 | 运行超过 `maxMinutes` 分钟 | 退出循环，标注熔断原因 |
| 无进展 | 连续 `noProgressThreshold` 轮发现数无新增 | 提前熔断，不等耗满预算 |
| Token | `budget.total` 可得时，剩余 ≤ 0 | 立即熔断 |

**仅对自动循环强制**。人主导的串行流程沿用现有的轮次上限（3/2/1），不受此影响。

### 分发路径与配置

熔断逻辑内嵌于 `nightly-audit.workflow.js`，无需单独分发。通过 args 的 `budget` 字段配置：

```json
{
  "budget": {
    "maxRounds": 3,
    "maxMinutes": 60,
    "noProgressThreshold": 2
  }
}
```

### 产出在哪

每次自动循环结束后，**调用方**应将运行结果写入项目的 `.claude/team-state/BUDGET_BURN.md`（追加，不覆盖历史）。格式如下：

```
循环名称 : nightly-audit
触发方式 : cron
开始时间 : 2026-06-23T02:00:00Z
结束时间 : 2026-06-23T02:18:42Z
实际轮次 : 2 / 3
Token 耗用: N/A（token 计量待验证，本次降级模式）
Token 上限: N/A
是否熔断 : false
熔断原因 : （未熔断）
发现总数 : 5
Blocker数 : 2（critical=1 / high=1）
备注     : 首次夜间巡检，基线建立
---
```

模板文件位于：`templates/memory/team-state/BUDGET_BURN.md`，字段说明见其中的字段说明表。

### Token 计量降级说明

当运行环境不暴露 token 用量时（`budget.total === null`），`isTokenBudgetExceeded()` 恒返回 `false`，token 闸不生效。此时系统自动降级为"轮次 + 时间 + 无进展"三维兜底，这三个维度均确定可得。BUDGET_BURN.md 中对应字段填 `N/A`。

### 验收标准

构造一个"故意不收敛"的任务交给自动循环，能在 ≤ `noProgressThreshold` 轮无进展或时间预算耗尽时熔断，不产生失控账单。

### 待验证假设

- Token 实时计量是否可得，取决于运行环境（CI 容器、本地 Claude Code）是否暴露 `budget.total`

---

## P1-1 contract-diff 契约硬 gate

### 它是什么

把"契约一致性"从 LLM 肉眼比对升级为机器 diff 的确定性 gate。解析 `docs/API_CONTRACT.md` 中以 `METHOD /path` 形式声明的接口，在源码目录 grep 路径字符串，有差异则退出码非零（gate 失败）。

提供两个版本：
- `contract-diff.sh`：Linux/macOS/WSL 用
- `contract-diff.ps1`：Windows PowerShell 用

### 分发路径

这是**项目级脚本**，由 `team-init` 铺进目标项目，而不随 `install.sh` 的 `*.workflow.js` 通道分发。源文件位于：

```
templates/workflows/contract-diff.sh
templates/workflows/contract-diff.ps1
```

铺设到目标项目后的位置：

```
{项目根目录}/scripts/contract-diff.sh
{项目根目录}/scripts/contract-diff.ps1
```

### 怎么手动跑

**Linux/macOS/WSL：**

```bash
# 默认：契约 docs/API_CONTRACT.md，源码 src/，支持 js/ts/py/go
bash scripts/contract-diff.sh

# 指定路径
bash scripts/contract-diff.sh --contract docs/API_CONTRACT.md --src src/ --ext js,ts

# 严格模式（双向差异都报错，默认只报契约有但代码无）
bash scripts/contract-diff.sh --strict
```

**Windows PowerShell：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts\contract-diff.ps1

# 严格模式
powershell -ExecutionPolicy Bypass -File scripts\contract-diff.ps1 -Strict
```

### 退出码含义

| 退出码 | 含义 |
|--------|------|
| 0 | 无差异，gate 通过 |
| 1 | 发现差异，gate 失败（契约声明的路径在源码中未找到；严格模式下双向） |
| 2 | 使用错误（参数错误、依赖缺失、契约文件或源码目录不存在） |

### 接入 CI 示例

```yaml
# .github/workflows/contract-check.yml
- name: Contract diff gate
  run: bash scripts/contract-diff.sh --strict
```

任一差异存在时，`exit 1` 让 CI 步骤失败，阻断合并。

### 解析局限（诚实标注）

以下情况脚本无法覆盖，需手工校验：

1. **变量拼装路径**：如 `router.get(BASE_PATH + "/users", ...)` 中的 `BASE_PATH` 是变量，grep 拿不到完整路径
2. **装饰器风格路由**：如 `@Get("/path")` 能覆盖（grep 到字符串字面量），但与普通字符串混用时需确认扩展名覆盖全面
3. **契约格式要求**：`API_CONTRACT.md` 中每条接口必须包含 `METHOD /path` 子串（如 `GET /api/users`）；纯表格但没有这个子串格式的契约文件会被识别为 0 条声明

### 验收标准

字段/路径/HTTP 方法与实现不符时脚本退出码为 1；所有声明路径在源码中有对应字符串时退出码为 0。

### 待验证假设

路由解析覆盖率因技术栈而异。对变量拼装路径或动态路由的检测属于"最大努力"，不保证 100% 覆盖。

---

## P1-3 CI 失败收集 hook

### 它是什么

CI 失败时自动提取失败日志摘要，追加写入 `.claude/team-state/CI_FAILURE.md`。下次 Claude 会话开场时，orchestrator 可读取此文件作为 Hotfix 输入提示，由人确认后才开始修复（半自动，不自动执行修复）。

这是 P1-3 的**轻量层**。P2 的重度层（CI 失败直接触发 Hotfix workflow 自动修复）尚未落地，不在本文档范围内。

### 分发路径

这是**项目级 hook**，不随 `install.sh` 分发。源文件位于：

```
templates/hooks/collect-ci-failure.sh
templates/hooks/settings-hook-snippet.json
```

铺设到目标项目后的位置：

```
{项目根目录}/.claude/hooks/collect-ci-failure.sh
```

`settings-hook-snippet.json` 是需要**手动合并**进目标项目 `.claude/settings.json` 的片段，不是独立的 settings 文件。

### 注册步骤

1. 将 `collect-ci-failure.sh` 复制到项目 `.claude/hooks/` 目录
2. 打开（或创建）项目 `.claude/settings.json`
3. 参照 `settings-hook-snippet.json` 中的 `hooks` 数组，将其合并进 `settings.json` 的 `hooks` 字段
4. 根据项目实际 CI 日志路径调整 `--file` 参数
5. Windows 环境把 bash 命令替换为 PowerShell 调用

合并后的 settings.json hooks 片段示例：

```json
{
  "hooks": [
    {
      "event": "PostToolUse",
      "matcher": { "tool_name": "Bash" },
      "hooks": [
        {
          "type": "command",
          "command": "bash .claude/hooks/collect-ci-failure.sh --file /tmp/ci_last_output.log --ts \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        }
      ]
    }
  ]
}
```

### 手动调用方式

**模式一：从文件读取日志**

```bash
bash .claude/hooks/collect-ci-failure.sh \
  --file /path/to/ci.log \
  --ts "2026-06-23T10:00:00Z"
```

**模式二：从 stdin 读取（管道）**

```bash
cat ci.log | bash .claude/hooks/collect-ci-failure.sh --ts "2026-06-23T10:00:00Z"
```

**可选参数：**

| 参数 | 默认 | 说明 |
|------|------|------|
| `--file` | — | CI 日志文件路径，与 stdin 二选一 |
| `--ts` | `unknown` | 时间戳，调用方注入 |
| `--out` | `.claude/team-state/CI_FAILURE.md` | 输出文件路径 |
| `--max-lines` | 50 | 摘要最大行数，防止文件过大 |

### 产出在哪

`.claude/team-state/CI_FAILURE.md`（追加写入，带时间戳分隔）。格式：

```markdown
---
## CI 失败记录 — 2026-06-23T10:00:00Z

**时间戳（调用方注入）**: 2026-06-23T10:00:00Z

### 失败测试用例（最多 20 条）
...

### 失败日志摘要（最多 50 行）
...
```

### 验收标准

CI 失败后，`CI_FAILURE.md` 被正确追加写入，内容包含可定位的失败测试用例名和日志摘要。

### 待验证假设

**CI 到回灌 Claude 的端到端触发链属于待验证假设。** 本脚本只负责"写文件"这一步。CI 系统如何调用本脚本、写完后如何让 Claude 下次会话感知，需项目方根据自身 CI 系统（GitHub Actions / Jenkins / GitLab CI）自行配置。两个未验证环节：

1. CI 系统能否在失败后以正确的日志路径调用 `collect-ci-failure.sh`
2. Claude 会话开场是否能自动读取 `CI_FAILURE.md` 并提示 orchestrator（目前是"会话开场人工提示"，不是自动感知）

---

## P1-5 跨项目 trace 聚合

### 它是什么

通过 `/team-kb-aggregate` 命令触发 `kb-curator` agent 以 aggregate 模式运行，读取多个项目的 `RETRY_LOG.md` 和 `LEARNINGS.md`，统计出现次数达到阈值的高频失败模式，产出 `~/.claude/team-memory/HOTSPOTS.md` 只读报告。

**明确边界：只读统计，不自动改任何东西。** HOTSPOTS.md 不会被自动写回任何 agent 提示词、验收标准或 harness 规则。基于报告的反向修订是 P2 改造，且必须人工确认。

与 `/team-kb-save` 的区别：

| 维度 | /team-kb-save | /team-kb-aggregate |
|------|--------------|-------------------|
| 输入 | 当前单个会话对话历史 | 多个项目的 RETRY_LOG.md + LEARNINGS.md |
| 产物 | `~/.claude/team-memory/patterns/*-patterns.md` | `~/.claude/team-memory/HOTSPOTS.md` |
| 写法 | Edit 追加/字段更新 | Write 整体覆盖（每次重新生成） |
| 触发时机 | 单个会话结束后沉淀 | 跨项目周期性聚合（手动或 cron） |

### 分发路径

命令文件位于：

```
.claude/commands/team-kb-aggregate.md
```

`install.sh` 会把该文件分发到：

```
~/.claude/commands/team-kb-aggregate.md
```

### 怎么触发

在 Claude 会话中执行：

```
/team-kb-aggregate project_paths=["D:/projects/proj-a","D:/projects/proj-b"] threshold=3
```

**参数说明：**

| 参数 | 类型 | 默认 | 说明 |
|------|------|------|------|
| `project_paths` | 字符串数组 | 必填 | 要聚合的项目根目录路径列表（绝对路径） |
| `threshold` | number | 3 | 同一错误模式出现次数达到此值才进入 top 列表 |

不提供 `project_paths` 时，命令会输出使用提示并停止，不会执行任何操作。

**定期自动运行（cron 示例）：**

```bash
claude -p '/team-kb-aggregate project_paths=["D:/projects/proj-a","D:/projects/proj-b"] threshold=3'
```

### 产出在哪

```
~/.claude/team-memory/HOTSPOTS.md
```

文件结构：
- 头部元信息（生成时间、聚合来源数、阈值、高频模式总数）
- 高频失败模式 Top 列表（按出现次数降序），每条包含：模式描述、出现次数、涉及项目、归属 agent、建议预防方向
- 跳过项目列表（因文件缺失被跳过的项目及原因）

每次运行**整体覆盖**本文件（非追加），旧快照不保留。如需历史对比，请在运行前手动备份。

### 验收标准

聚合报告能正确识别出现次数达到阈值的高频失败模式 top 列表；跳过的项目在报告中有注明。

### 待验证假设

- 跨项目聚合依赖各项目统一使用 `.claude/team-state/` 路径存放 `RETRY_LOG.md` 和 `LEARNINGS.md`；若团队有多种路径约定，需在调用时提供完整绝对路径
- 长期指标（L2 写回后同类失败复现率下降）属 P2 改造范畴，不在 P1 验收范围内

---

## 已知限制

### 限制一：`team-kb-aggregate` 命令随版本升级分发（依赖 bump 版本号）

`/team-kb-aggregate` 是 P1-5 新增的命令文件（`.claude/commands/team-kb-aggregate.md`），已在 `install.sh`（L274）与 `install.ps1`（L293）布线分发。`update.sh` / `update.ps1` 会**委托调用 install 脚本**（`install.sh claude 1`）来刷新全局 agents/命令/知识库/workflow，因此升级时该命令会被一并刷新——**前提是仓库版本号与已安装版本号不同**。

- 新用户：执行 install 脚本后自动拥有该命令
- 老用户：执行 update 脚本即可获取（update 转调 install）；**但 install 有幂等短路——当「仓库版本 == 已装版本」且知识库模式为「跳过」时直接退出、不刷新任何文件**。所以新命令必须随一次版本号 bump 发布（本次为 `1.6.0`），老用户升级到新版本时才会触发完整刷新。
- 这是正确的幂等行为（同版本=无事可做），并非缺陷。

### 限制二：待验证假设汇总

| 编号 | 能力 | 假设内容 | 当前降级行为 |
|------|------|----------|-------------|
| VA-1 | P1-2 / P1-4 | Token 实时计量依赖运行环境暴露 `budget.total` | 若不可得，token 闸跳过，轮次+时间+无进展三维兜底 |
| VA-2 | P1-2 | GitHub Actions 无 TTY 下 `claude -p` 的凭据/配额/命令形态 | 需在实际 CI 环境实测，未验证前无法确认可用性 |
| VA-3 | P1-3 | CI 失败→回灌 Claude 的端到端触发链连通性 | 当前只落地"写文件"，CI 如何调用 hook 需项目方自行配置 |
| VA-4 | P1-3 | hook 触发时机与 CI 日志可用时机的对齐 | 需实测；`--file` 参数路径须与 CI 系统实际日志路径一致 |
| VA-5 | P1-5 | 跨项目 RETRY_LOG/LEARNINGS 路径约定统一性 | 路径不统一的项目会被跳过并在报告中注明 |
| VA-6 | P1-1 | 变量拼装/装饰器路由的 grep 覆盖率 | 最大努力，不保证 100%；需手工校验动态路由 |

---

## 与 P0 的关系

P0 建立了制度与约定：把"确定性验证优先"写成总则、把循环预算治理写进 GOAL.md 格式、把自动循环只读不改的红线写进 orchestrator 约定、把 LOOP_CONTEXT.md 边界约定落档。

P1 是这些约定的第一次真正落地执行：

| P0 约定 | P1 对应实现 |
|---------|------------|
| 确定性验证优先于 LLM 判断（验证器分层总则） | P1-1 contract-diff 把契约比对从 LLM 肉眼升级为机器 diff |
| 循环预算治理（轮次/token/时间/无进展四维） | P1-4 在 nightly-audit workflow 中实装三维熔断（token 计量降级兜底） |
| 自动循环只读不改、禁触安全确认点 | P1-2 在 workflow 代码中强制约束三条红线 |
| BUDGET_BURN.md 状态字段约定 | P1-4 定义记录格式，调用方写入 |
| trace 聚合自我改进环（L1）约定 | P1-5 通过 /team-kb-aggregate + kb-curator aggregate 模式实现 |

换句话说：P0 定义了规则，P1 给这些规则装上了能跑的机器。P2 的反向改 harness（L2 自我改进）和 CI 自动修复重度层，须在 P1 验证稳定后、经人工确认才推进。
