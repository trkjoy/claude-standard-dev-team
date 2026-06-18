# 变更日志

本文件记录每个版本的关键变更，方便团队成员判断是否需要升级、以及升级带来的行为差异。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

---

## [1.5.0] - 2026-06-17

> 新增 go-zero Go 后端工程师角色，与现有 Node/TS 后端并存，由 orchestrator 按技术栈自动二选一路由。整条链路（架构师声明技术栈 → 路由 → 翻译契约 → goctl 生成 → 编译通过）已端到端实跑验证。

### 新增（Added）

- **`go-zero-engineer` 角色**：单体 goctl api HTTP 服务工程师。读技术栈中立的 `API_CONTRACT.md` 翻译成 go-zero 原生 `.api` 契约，用 `goctl api go` / `goctl model mysql` 生成骨架与 model 层，只在 logic 填业务逻辑。内嵌官方规范（`.api` 语法、目录结构、`httpx`/`errorx` 统一错误处理、5 项生产规范），附官方 `ai-context` 链接兜底。翻译环节用「.api 逐字对照 API_CONTRACT 一致性自查 + `GOZERO_STATUS.md` 翻译差异登记 + code-reviewer Phase 8 把关」三重兜底。

### 改进（Changed）

- **`orchestrator` 按技术栈路由后端 agent**：Phase 5 读 `TECH_SPEC.md`「后端框架」字段，以 `go-zero` **开头**则派 `go-zero-engineer`（额外传入 DB_SCHEMA 建表 DDL 供 goctl model），否则派 `backend-architect`（Node/TS 链路行为零变化）。失败分流规则对两者一致。
- **`orchestrator` Phase 4 边界收口**：go-zero 栈下 `database-optimizer` 只产出 migrations DDL、不产 model 文件（model 层由 go-zero-engineer 用 goctl 生成），消除孤儿产物。
- **`software-architect` 强制声明后端技术栈**：`TECH_SPEC.md` 技术栈选型表「后端框架」行须用受控标识开头（如 `go-zero（Go 1.24）` / `Node-Express` / `Node-Koa` / `FastAPI`），供 Phase 5 路由判定。
- **文档团队数量同步**：`README.md`（成员表新增 go-zero-engineer + 4 处计数）与 `orchestrator.md`（description 等 3 处「下游 agent」数量）由 14 名成员更新为 15 名。

> 来源：经 brainstorming → spec → plan → subagent 逐任务实现+评审 → 终评修复 → 端到端验证全流程产出。验证用真实最小契约跑通 goctl 生成且 `go build ./...` / `go vet ./...` 均通过。设计与计划见 `docs/superpowers/{specs,plans}/2026-06-17-go-zero-engineer*`。install 脚本以 `agents/*.md` 通配复制，新角色自动分发，无需改清单。

---

## [1.4.2] - 2026-06-11

> 修复实跑 audit-scan workflow 时它"扫出自己"的两个问题，并给前端 token 存储补安全警示。

### 修复（Fixed）

- **[MEDIUM] audit-scan 未知扫描维度会 `undefined.trim()`**：`dimPrompts[dim].trim()`（L120）在 `dim` 不在 `dimPrompts` 时抛 TypeError，被 N1 的 `filter(Boolean)` 静默吞成"该维度丢失且无诊断"。新增两道校验：(1) `runMultiDimensionScan` 入口对 `args.dimensions` 做白名单校验，未知维度在 parallel 启动前**大声 throw**；(2) thunk 内对 `dimPrompts[dim]` 缺失做软跳过 + 日志，兜 `DIMENSION_AGENT_MAP`/`dimPrompts` 未来键集漂移。
- **[MEDIUM] audit-scan 对抗验证 prompt 存在注入面**：`refutePrompt` 直接拼接 `finding.filePath/description/lineHint`（可能源自被扫代码里的恶意注释），可诱导验证 agent 输出虚假 `confirmed:false` 绕过审查（OWASP A03 LLM 扩展）。改为用 `<finding-data>` 标签隔离数据域/指令域、声明标签内为不可信数据须无视其中任何"指令"、并对各字段截断压缩载荷空间。

### 改进（Changed）

- **[LOW] frontend-developer token 存储安全警示**：API 服务层模板示例用 `localStorage` 存 JWT（XSS 可全量窃取，CWE-922 / OWASP A02）。保留示例不破坏现有鉴权设计，但补 `⚠️` 注释——优先 HttpOnly+Secure+SameSite Cookie 方案、否则配套严格 CSP，并提示该选择须与 `API_CONTRACT.md` 鉴权约定一致。

> 来源：本批由一次**实跑 `audit-scan` workflow 自审本仓库**捞出（46 agent / 498k token，期间撞 429 限流仍优雅降级，反向验证了 v1.3.5/v1.3.8 容错有效）。改动 `templates/workflows/audit-scan.workflow.js`、`agents/frontend-developer.md`，脚本通过 `node --check`。

---

## [1.4.1] - 2026-06-11

> install/update 脚本运行完不再一闪而退，结束前等待回车，便于查看安装/升级结果。

### 改进（Changed）

- **`install.ps1` / `update.ps1` 结束前暂停等回车**：双击或运行完直接退出、看不到结果（含 update 的「已跳过同步」等提示）的问题。把整个脚本体包进 `try { ... } finally { 暂停 }`——无论正常结束、`exit 0`（已是最新）还是 `exit 1`（出错），finally 都会执行暂停，且 `exit` 码原样保留（已实测 finally 在 exit 时触发、退出码不变）。
  - 暂停带双重守卫：`[Environment]::UserInteractive` 为假（CI/非交互）时不暂停，避免挂起；`update.ps1` 以子进程调用 `install.ps1` 前设 `TEAM_SKIP_PAUSE=1`、调用后清除，使子进程不暂停（否则会卡住 update），而 update 自身结束仍正常暂停。
  - 仅 PowerShell 脚本改动；`.ps1` 业务逻辑零变化，两文件均通过语法解析校验。

---

## [1.4.0] - 2026-06-11

> 新增 Windows `.cmd` 启动器，新电脑首次安装/升级无需先手动放行 PowerShell 执行策略。

### 新增（Added）

- **`scripts/install.cmd` / `scripts/update.cmd` 启动器**：解决新电脑首次运行 `.\scripts\install.ps1` 报 "无法加载文件……禁止运行脚本"（PowerShell 默认 ExecutionPolicy=Restricted 在脚本**加载前**就拦截，脚本内部任何 `Set-ExecutionPolicy` 都来不及执行、无法自救）。`.cmd` / `.bat` 不受 PowerShell 执行策略管辖，启动器内部以 `powershell.exe -NoProfile -ExecutionPolicy Bypass -File <同级 .ps1>` 调用，`%*` 透传全部参数（`update.cmd` 可带项目目录）。`Bypass` 仅作用于该次进程，**不修改系统全局策略**。
  - 用法：`.\scripts\install.cmd`、`.\scripts\update.cmd [项目目录]`。
  - `.ps1` 本体逻辑零改动，直接复用；仍可按原方式手动设执行策略后跑 `.ps1`。
  - 仅 Windows 需要——Mac/Linux/WSL 无执行策略限制，继续用 `bash scripts/*.sh`，不新增 `.sh` 启动器。
- **INSTALL.md**：Windows 安装/升级首推 `.cmd` 启动器；FAQ「脚本被禁止运行」给出三档处理（`.cmd` 启动器 / Process 级临时放行 / CurrentUser 级长期放行）。

---

## [1.3.9] - 2026-06-11

> 砍掉设计就别扭的 `DYNAMIC_CONTENT_MAP.md`，把它唯一有用的内核收敛为前端的一条反内容硬编码规则（YAGNI / 化繁为简）。

### 移除（Removed）

- **删除 `DYNAMIC_CONTENT_MAP.md` 产线**：该文件本意是告诉前端"哪些内容必须绑接口、哪些可写死"，但存在双重设计缺陷——(1) 它的主键列是「设计稿占位文字」，而产出它的 `software-architect` 在 Phase 2 **根本看不到设计稿**（Figma 是 frontend-developer 的输入、DESIGN_SYSTEM 是视觉 token 且更晚），最有价值的"稿子文字→字段"映射列填不了；(2) 它唯一能可靠产出的"绑定字段/来源接口"两列，与同时在写的 `API_CONTRACT.md` 完全冗余。叠加它**从未被任何下游 agent 读取**（前端必读清单、orchestrator Phase 6 投递、reality-checker 终验都没有它），属于"产出即孤儿"。已删除 `software-architect.md` 的「输出文件四」整段与执行步骤第 6 步、`orchestrator.md` Phase 0 占位清单中的该文件。

### 新增（Added）

- **frontend-developer 新增「内容数据规范（防内容硬编码，零容忍）」**：把被删文件唯一不冗余的内核——动态/静态判断口诀 + 四类必绑内容（文字/图片/列表/条件显示）+ 静态内容白名单——收敛为前端的一条自检规则，字段来源指向 `API_CONTRACT.md`，并规定"拿不准默认按动态绑接口"。此前团队的"零容忍硬编码"只挡得住 API 路径（Phase 6/9 有强制检查），**内容硬编码无人防**；现由前端在真正持有设计稿的环节自检堵上，且不再依赖一份没人读的冗余文档。

> 本批改动：`agents/software-architect.md`、`agents/orchestrator.md`、`agents/frontend-developer.md`。历史 `docs/superpowers/` 下的 plan/spec 仍提及该文件，属历史设计记录，按"手术式改动不碰无关"保留不动。

---

## [1.3.8] - 2026-06-11

> 第四轮编排逻辑审计：补 audit-scan 扫描侧的 null 崩溃（1.3.5 只加固了验证侧），并接通两处被吞掉的信号。

### 修复（Fixed）

- **[HIGH] audit-scan 扫描侧 null 不容错，单个扫描 agent 死亡会崩溃整条审计**：`runMultiDimensionScan` 的 thunk 在 `agent()` 返回 null 时 `findings.findings` 抛错 → `parallel` 把该维度降为 null；`runAdversarialVerification` 又未 `filter(Boolean)` 直接迭代 → `scanResult.findings` 在 parallel 屏障之外二次抛错、无 catch、整个 workflow 崩。1.3.5 的"全程容错"只覆盖了对抗验证侧，扫描侧三处（thunk 返回、展平迭代、summary reduce）漏网。已全部补 `?.` / `filter(Boolean)`。
- **[MEDIUM] audit-scan 的 `needsHumanReview` 信号在 Audit 汇报格式里无处安放**：workflow 对 critical/high 采"任一票确认即保留"并标记未全票的高危项，但 orchestrator 模板 B 汇报格式没有对应栏，信号默认被吞。汇报格式新增「⚠️ 高危待人工复核」栏，并强制 orchestrator 单列、不得并入"未发现问题"。
- **[MEDIUM] STATE.md 单 `Retry Count` 标量无法表达并行批次各任务独立计数**：与 1.3.1「并行失败任务各自维护独立重试计数」自相矛盾，断点续跑在并行场景失真。新增 `Batch Retry Counts` 字段（形如 `TASK-B01:2, TASK-B03:1`），恢复规则 #4 改为"任一任务 >=3 即就该任务卡点、其余照常推进"；init 模板 STATE.md 同步加该字段。

### 已验证为干净（无需改动）

- **model 字段体检（上轮 L3）**：14 个 agent 全为 `opus`（orchestrator / software-architect / reality-checker）或 `sonnet`，1.3.4/1.3.5 修掉两个 haiku 倒挂后无新增残留。

> 本批改动：`templates/workflows/audit-scan.workflow.js`、`agents/orchestrator.md`、`templates/memory/team-state/STATE.md`。脚本已通过 `node --check`。M3（功能新增增量拆解范围）仍为待实跑验证的推断项，本批未动。

---

## [1.3.7] - 2026-06-11

> 第三轮编排逻辑审计：补两条「读取端有、写入端没有」的断层，并对齐串行/并行两条 Dev-QA 路径的纪律。

### 修复（Fixed）

- **[HIGH] `LEARNINGS.md` 只读不写（与 1.3.1 同类断层，漏网一条）**：Phase 11.5 `kb-curator` 把 `LEARNINGS.md` 当输入消费，但 orchestrator 全文无任何写入触发点——「状态写入时机」章节只强制写 `STATE.md`，该文件恒为空，知识写回实际只剩 `RETRY_LOG`。已在写入义务中新增：任务由 FAIL 经重试转 PASS 时，必须把「失败原因 + 解法 + 文件」追加一条到 `LEARNINGS.md`。
- **[HIGH] 并行 Dev-QA Loop 静默丢失串行路径的失败升级分流**：`team-dev-loop.workflow.js` 失败后固定派回**同一个**实现 agent，契约/字段类失败永远到不了 software-architect（串行路径 STEP 4 会按关键词升级）。已补 `resolveFixAgentType`——第 2 次起按失败原因关键词升级（字段/契约→software-architect、连接/数据库→devops-automator、鉴权/token→security-engineer）。同时在 orchestrator Phase 5/6 下沉说明中**诚实标注**：并行模式不强制 STEP 0 TDD（RED 先行）与 STEP 2 自验证，以吞吐换纪律，复杂/契约未定的批次宁可走串行。
- **[MEDIUM] 知识闭环只在成功时关闭**：Phase 11.5 限定「仅 READY 后执行」，导致卡死/判 NEEDS WORK（踩坑最多）的项目里 `RETRY_LOG`/`LEARNINGS` 教训全部白扔。新增 Phase 11.5-F——长链路任务进入终态失败时，追加派 `kb-curator` 只收割已验证有效的失败→解法条目（不要求项目整体 READY）。
- **[MEDIUM] `team-dev-loop` 脚本无前后端混传屏障**：脚本用无屏障 `pipeline`，若同次调用混入 backend+frontend 任务，前端会在后端 API 实现前并行跑，违背「前端须等后端跑通再联调」。入口新增单 layer 断言，混传即抛错，强制按 Phase 5/6 分两次调用。

> 本批改动：`agents/orchestrator.md`、`templates/workflows/team-dev-loop.workflow.js`。脚本已通过 `node --check`。来源为用户发起的第三轮编排审计，4 条均有 `文件:行号` 实证（M3 功能新增增量拆解范围、L3 model 字段体检为推断/待验项，本批未动）。

---

## [1.3.6] - 2026-06-11

> 收尾：清掉两轮审计剩下的两个纯文案 LOW。

### 修复（Fixed）

- **[LOW] product-manager 非功能模板假量化**：性能/兼容性/可用性等示例值此前像"已确认硬指标"，易被原样抄进 PRD。加 `[假设]` 标注 + 表头警示，明确须与业务确认后定稿。
- **[LOW] update 脚本提示措辞**：原"保留技术栈/部署环境字段"易让人误以为这些字段在被替换的团队配置段内。改为"仅替换团队配置段；项目上下文等其它段落（含技术栈/部署环境）原样保留"，与实际行为对齐。

> 至此，两轮编排逻辑审计发现的 HIGH/MEDIUM/LOW 全部修复完毕。

---

## [1.3.5] - 2026-06-11

> 第五批修复：workflow 脚本对抗式验证的设计缺陷、重试空转、agent 权限收口与路由空隙。

### 修复（Fixed）

- **[HIGH] audit-scan 对抗式验证会漏报高危**：原 `confirmThreshold=2` 是 AND 逻辑（两票全过才算真问题），任一 refute agent 对真 critical 投 false 就被**静默丢弃**；且第 2 票投回扫描 agent 自己、独立性形同虚设；传 `confirmThreshold=3` 还会全丢。已改为：第 2 票固定用 **reality-checker**（从不参与扫描）；**severity 感知**——critical/high 任一票确认即保留并标记 `needsHumanReview`，medium/low 才需阈值票；`confirmThreshold` 钳制到 [1,2]；agent 返回 null/抛错全程容错（`filter(Boolean)` + 兜底），不再炸整条 pipeline；去重 key 加入 lineHint 防误并。
- **[HIGH] team-dev-loop 重试空转**：原 FAIL 后只是重验**同一份未改代码**，3 次必然同结论。改为 FAIL 后**先派实现 agent 按失败原因真正修复**、用修复后的结果再验；并加 null 容错与异常任务降级统计（`dropped`）。
- **[MEDIUM] 审查类 agent 权限全开**：`code-reviewer` / `security-engineer` / `technical-writer` 此前 frontmatter 无 `tools`，继承全工具（含 Edit/Task）。按最小权限收口——审查/安全只给 `Read, Glob, Grep, Bash, Write`（不给 Edit/Task，不改业务代码）；并在两者正文显式声明产出 `docs/REVIEW_REPORT.md` / `docs/SECURITY_REPORT.md`。
- **[MEDIUM] technical-writer 模型倒挂**：要跑代码核对契约写 API_DOC 却是 `haiku`，升 `sonnet`，补 `tools`。
- **[MEDIUM] 路由空隙补齐**：Step 1.D 新增「功能新增」去向（走完整模板 Phase 2→11 子集做增量、不跳质量门）、「看完再改」明确归 Audit→Audit-Fix；Step C 验证补「纯测试→qa-automator / 纯部署→testing-evidence-collector」归属。
- **[LOW] ui-designer 自相矛盾**：description 暗示"重构样式层"但正文说"只出规范"、却带 Edit 工具。去掉 Edit、description 改为"只产出规范+报告，实际重构由 frontend-developer 执行"。
- **[LOW] GOAL.md 创建归属**：team-init Step 6 注明 GOAL.md 由 orchestrator 长链路启动时按需创建、init 不预置（YAGNI）。
- **[LOW] devops nginx.conf 归属表述自相矛盾**：明确由 frontend-developer 生成、devops 只规定内容要求并在部署时核对。

> 本批改动：两个 `templates/workflows/*.workflow.js`、`code-reviewer.md`、`security-engineer.md`、`technical-writer.md`、`ui-designer.md`、`devops-automator.md`、`orchestrator.md`、`.claude/commands/team-init.md`。两 workflow 脚本已通过 `node --check`。仍余少量纯文案项（product-manager 模板示例值、update.ps1 措辞）未动。

---

## [1.3.4] - 2026-06-11

> 第四批修复：修好"坏掉的验收闸口"，统一技术栈占位串，收紧 team-init 生成的安全门。

### 修复（Fixed）

- **[HIGH] testing-evidence-collector 是未本地化的外部模板，验收闸口实际失效**：该 agent（orchestrator 多个 Phase 的 QA 验收闸口）残留了 Laravel + 营销落地页套路：强制流程第一条命令调用**全仓不存在的** `./qa-playwright-capture.sh`、`ls resources/views/*.blade.php`、`grep "luxury\|premium\|glass\|morphism"`、端口写死 8000、末尾指向不存在的 `ai/agents/qa.md`，且 `model: haiku` 做视觉判断、frontmatter 无 `tools`。已整体本地化到本团队技术栈：现实核查命令改为 curl `/api/health`(端口取 TECH_SPEC)+ 实际产出检查 + 接口/测试取证；明确"无截图工具时做功能性取证并如实标注、缺证据倾向 NEEDS WORK 而非凭空 PASS"；去掉营销词与 Laravel 残留；`model` 升 sonnet；补 `tools: Read, Write, Bash, Glob, Grep`（不给 Edit，QA 不改代码）。
- **[HIGH] 技术栈占位串三处不一致（v1.3.0 引入的回归）**：team-init 写 `待 software-architect 在 Phase 2 按 PRD 选型`，而 software-architect / orchestrator 识别的是 `待 Phase 2 选型`——前者不含后者子串，架构师会把整条占位串误当"用户已指定的技术栈"、不主动选型，Phase 2 自动选型失效。三处统一为确切字符串 `待 Phase 2 选型`（TECH_STACK 与 DEPLOY_ENV 同串）。
- **[MEDIUM] team-init 生成的 settings.json 绕过安全门**：原为整体放行 `"Bash"`，比 `templates/memory/settings.json` 的命令前缀白名单宽松得多（等于放行 `git push`/`rm`/`docker`/`sudo`）。改为内嵌与模板一致的细粒度白名单，并注明不可逆/对外动作故意不放行、由 orchestrator 安全确认点逐次把关。

> 本批改动：`agents/testing-evidence-collector.md`、`.claude/commands/team-init.md`。两文件「团队配置」块仍字节一致。

---

## [1.3.3] - 2026-06-11

> 第三批修复：消费断层、文档一致性、Workflow 集成边界。把"文档说有、实际没有"的断点对齐到真实行为。

### 修复（Fixed）

- **[HIGH] frontend-developer 不读 DESIGN_SYSTEM.md**：orchestrator Phase 6 传入 ui-designer 产出的 `DESIGN_SYSTEM.md`，但 frontend-developer 必读清单只列 API_CONTRACT/TECH_SPEC，导致设计规范无消费入口。已补入 `DESIGN_SYSTEM.md` + `variables.css`/`tailwind.config`，并明确"orchestrator 流程内以 DESIGN_SYSTEM 为准，仅用户给 Figma 时才走 Figma"。
- **[MEDIUM] reality-checker 漏校验 test-tasklist**：qa-automator（Phase 6.5）产出的 `test-tasklist.md` 未进 reality-checker 的读取清单与 READY 条件，已补入。
- **[MEDIUM] WORKFLOW.md 调度全图漏画新成员**：补上 Phase 6.5（qa-automator）与 Phase 11.5（kb-curator），并加注 `.5` 子阶段与 4.9/5.9 内部注入步说明；团队成员数 12 → 14。
- **[MEDIUM] WORKFLOW.md「只 2 处暂停」与安全确认点冲突**：补充"不可逆/对外动作（Phase 9 部署、git push、删库等）执行前必须单独安全确认"，与 orchestrator 红线一致。
- **[MEDIUM] Workflow 启用后跑什么没定义**：orchestrator Step 1.6 补明确——用户点头 y → 加载 `~/.claude/team-workflows/` 脚本执行（自带重试，FAIL 不叠加 orchestrator 重试、直接转人工）；`/dispatching-parallel-agents` skill 仅用于未启用 Workflow 时的就地并行；二者互斥。
- **[MEDIUM] GOAL 终止条件虚假承诺**：orchestrator 与 first-run checklist 原称"workflow 脚本把 GOAL 当硬性终止条件"，但脚本里根本不读 GOAL。改为"脚本不读 GOAL；由 orchestrator 在回流后对照 GOAL 完成条件复核"，并同步修正 checklist 的可恢复性项（当前脚本无续跑能力，中断从头重跑可接受）。

> 本批改动：`frontend-developer.md`、`reality-checker.md`、`orchestrator.md`、`WORKFLOW.md`、`docs/WORKFLOW_FIRST_RUN_CHECKLIST.md`。仍有少量低优先项（功能新增类型无专属模板、audit-scan 投票独立性、GOAL.md 未在 init 预建）留待后续。

---

## [1.3.2] - 2026-06-11

> 第二批修复：消除跨 agent 的契约常量漂移（这些漂移会让生成的项目运行期 404 / 容器启动失败）。把散落常量上收到 TECH_SPEC 全局规范，作为单一真值。

### 修复（Fixed）

- **[HIGH] 健康检查路径三处不一致**：backend-architect 规则要 `/api/health` 却给了 `/health` 的 Koa 示例；reality-checker 验收脚本 curl 的是 `/health` 和 `/api/v1/health`。全部统一为 `/api/health`。
- **[HIGH] 错误响应格式冲突**：backend-architect 小程序鉴权中间件返回 `{ code: 4010/4011 }`（数字 code），与契约 `{ error, message }`（字符串码）冲突，qa-automator 又断言 `error` 字段。改为 `{ error: 'unauthorized', message }`，状态码保持 401。
- **[HIGH] `start.sh` 落点不一致**：database-optimizer 写 `scripts/start.sh`、devops 一处 `CMD ["sh","scripts/start.sh"]` 一处 `CMD ["sh","start.sh"]`，容器会找不到脚本。统一为**项目根 `start.sh`**（迁移脚本仍可在 `scripts/` 下）。
- **[HIGH] 前端 base 环境变量名不一致**：架构/前端用 `VITE_BASE_URL`，devops 注入 `VITE_BASE_PATH`，子路径部署静态资源 404。devops 全部改为 `VITE_BASE_URL`。
- **[MEDIUM] Phase 2.5 产出与技术栈不符**：orchestrator 把 `variables.css` 当 ui-designer 无条件产出，但默认 shadcn/Tailwind 栈产的是 `tailwind.config.ts + globals.css`。改为依技术栈二选一。
- **[LOW] qa-automator 示例断言违反成功响应包裹层**：示例断言 `res.body.token`（顶层），与统一成功格式 `{ data, message }` 不符。改为 `res.body.data.token`。

### 改进（Changed）

- **TECH_SPEC 全局规范表新增「单一真值」行**：健康检查端点、统一成功/错误格式、前端 base 环境变量名、容器启动脚本落点，全部固化进 `software-architect.md` 的全局规范表，并声明所有 agent 涉及这些常量必须引用本表、不得各自取值——从源头防止再次漂移。

> 本批改动文件：`software-architect.md`、`backend-architect.md`、`reality-checker.md`、`devops-automator.md`、`database-optimizer.md`、`qa-automator.md`、`orchestrator.md`。未改任何接口语义，只统一常量取值。

---

## [1.3.1] - 2026-06-11

> 多 agent 编排逻辑审计后的第一批修复：补齐状态机写入闭环、统一重试升级、修好知识库读写闭环。

### 修复（Fixed）

- **[HIGH] 状态机写入闭环缺失**：`orchestrator.md` 此前只有 STATE.md 的「读规则 + 格式」，没有任何执行点真正写它，断点续跑恒读到初始值。新增「状态写入时机（义务）」——每个 Phase 开始 / 每次 STEP D 决策后 / 确认点暂停 / 卡点暂停 都必须写回 STATE.md；STEP D 决策步也补上"立即写回 STATE.md"。
- **[HIGH] 知识写回绕过 kb-curator 且 orchestrator 越权**：Phase 11.5 与 Hotfix-5 原为 orchestrator **自己**写用户级 `~/.claude/team-memory/patterns/`，与 `/team-kb-save` 两条路径口径冲突、且超出 orchestrator 权限。改为**派发 `kb-curator`（dry_run=false）**统一写回；红线「禁止做的事」新增第 5 条：orchestrator 禁止自写用户级知识库。
- **[HIGH] 前端知识库注入读错文件**：Phase 5.9 原写"同 Phase 4.9"，导致前端阶段注入的是 `backend-patterns.md`、`frontend-patterns.md` 从无人读。改为显式读取 `frontend-patterns.md` + `contract-patterns.md`。
- **[MEDIUM] 并行批次失败无隔离协议**：Step 3 补「并行批次失败隔离」——失败任务各自独立重试、不阻塞同批 PASS 任务；下游须等整批到达终态再启动。
- **[MEDIUM] Dev-QA Loop 升级路径不一致**：通用 Step 3 / STEP D 补上与 Phase 5 一致的「第 2 次失败按关键词分流（字段→architect / 连接→devops / 鉴权→security）」升级步（重试上限仍为 3 次/任务，二者本就一致）。
- **[MEDIUM] qa / deployment 经验只进不出**：Phase 6.5、Phase 9 分别补上读取 `qa-patterns.md`、`deployment-patterns.md` 生成 HINT 注入 qa-automator / devops-automator，与 Phase 4.9/5.9 对称，闭合注入侧。

> 本批仅改 `agents/orchestrator.md`（编排手册），不动任何 agent 契约。其余审计发现的契约常量漂移（health 路径 / 错误格式 / start.sh / VITE_BASE / variables.css）等留待后续批次。

---

## [1.3.0] - 2026-06-11

> 新建项目时可按需求推荐技术栈，并打通 init 声明 → 架构师选型 → 用户确认的链路。

### 新增（Added）

- **`/team-init` 按需求推荐技术栈**：Step 3 先问"这个项目大概要做什么"（PROJECT_BRIEF），技术栈/部署环境允许回答"让团队推荐 / 不确定 / 留空"。
  - 用户已明确给出 → 原样采用，不擅自更改。
  - 让推荐且有项目描述 → 依描述**推荐 1 主选 + 1 备选**（各附理由）供用户确认/改/自定义。
  - 让推荐但什么都没说 → 不瞎猜，记为占位"待 software-architect 在 Phase 2 按 PRD 选型"。

### 修复 / 改进（Changed）

- **架构师选型与 init 声明打通（修此前脱节）**：`software-architect` Phase 2 现在会先读项目 `CLAUDE.md`「项目上下文」的技术栈声明——用户已指定则以其为约束（硬冲突时在 TECH_SPEC「选型说明」写明冲突+备选、交确认点裁决），标注"待选型"则按 PRD 主动推荐并写清理由。此前 Phase 2 只吃 `PRD.md`、完全忽略用户在 init 填的栈，二者会静默打架。
- **Phase 2 确认点显式展示技术栈选型**：`orchestrator` Phase 2 输入补上 CLAUDE.md 项目上下文，人工确认点改为**先展示技术栈选型表（含理由/冲突裁决）再展示接口与表结构**，让选型成为一个明确的用户决策点。

---

## [1.2.4] - 2026-06-11

> 未用触发语发来复杂需求时，团队先"反问一句"是否启用，避免漏接；保持显式 opt-in，不自动接管。

### 新增（Added）

- **未用触发语时的轻量反问**：在 `templates/memory/project-CLAUDE.md` 与 `.claude/commands/team-init.md` 的「团队配置」段新增一条规则——当用户**没说**触发语、但需求明显需要多 agent / 多步骤协调时，主会话**先用一句话反问**是否要用标准团队来做，得到确认后才担任 orchestrator。
  - **边界明确**：反问 ≠ 自动接管。用户点头前绝不擅自启动团队流程、绝不擅自跑 Workflow；简单/单步需求不反问、直接做。
  - 与既有三层门禁（L1 团队激活 / L2 Workflow 适用性提示 / L3 Workflow 运行）兼容：本规则只是把 L1 的进入方式从"必须念口令"放宽为"也可被反问后点头"，L2/L3 原样不变，默认行为不被改写。
  - 两处「团队配置」块保持字节一致，`/team-init` 生成的项目不会被 `/team-update` 误判为需更新。

---

## [1.2.3] - 2026-06-11

> 修复 Workflow 适用性提示的逻辑漏洞：复杂多任务需求不再漏掉「是否启用 Workflow」的提示。

### 修复（Fixed）

- **[HIGH] `agents/orchestrator.md` Workflow 适用性扫描时机错位**：原 Step 1.6 在「Step 1 分类后」一次性扫描全部阈值，但其中最常命中的「独立可并行任务数 ≥5」此时**任务清单尚未生成、根本数不出来**；Step 2 产出清单后又没有复扫，Step 3 的并行派发也不回头提示。导致复杂多任务需求虽然实际可并行，却**整条漏掉**"是否启用 Workflow"的提示——用户感觉"任务明明很复杂，团队却没问"。
  - 修复：Step 1.6 改为**两次时机扫描**——时机 A（分类后）只判断凭范围即可确定的条件（≥50 文件 / ≥20 处重复 / 对抗式验证 / >30 分钟）；时机 B（Step 2 执行计划产出后）补判「独立可并行任务数 ≥5」等需要清单才知的条件。
  - Step 2 末尾新增「🔁 Workflow 再扫描（必做）」；Step 3 并行派发前新增兜底检查（若此刻才发现 ≥5 可并行任务且从未提示过，则补一次启用确认）；收尾检查单第 6 条同步说明两次时机。
  - **保持零行为变化底线**：默认仍为 N，用户不点头则完全走原有串行流程，不影响既有团队用法。

---

## [1.2.2] - 2026-06-11

> 统一团队人数口径，并把 orchestrator 的 description 改写为面向使用者的视角。

### 变更（Changed）

- **团队人数口径统一为「15 个 agent = 1 位总指挥 + 14 名成员」**：`agents/` 目录实际已有 15 个 agent（新增的 `qa-automator` 自动化测试、`kb-curator` 知识沉淀此前未计入）。全面修订 `README.md`（标语、版本说明、架构图、成员表）、`INSTALL.md`、`docs/USAGE.md`、`templates/memory/project-CLAUDE.md`、`.claude/commands/team-init.md`、`docs/WORKFLOW_FIRST_RUN_CHECKLIST.md` 中过时的「13 agents / 12 人 / 下游 12 个」表述。README 架构图补上 `qa-automator`（质量层）与 `kb-curator`（支撑层）。
- **`agents/orchestrator.md` 的 description 改写为使用者视角**：从内部"操作手册"口吻改为一眼说明"能解决什么"——从需求到上线的全流程开发、契约驱动、自动闭环；保留触发语"使用标准团队开发"与关键安全约束（必须由 top-level 主会话亲自担任、禁止以 subagent 启动），不影响团队调度行为。
- **`/team-init` 与 `/team-update` 产出对齐**：`team-init` 命令生成的 CLAUDE.md 团队配置段落补上 `### 全局执行准则` 子段并同步人数，使其与 `templates/memory/project-CLAUDE.md` 模板完全一致（避免刚初始化的项目立即被 `update` 判定为需更新）。

---

## [1.2.1] - 2026-06-11

> 在 v1.2.0 基础上的小迭代：新增版本查看命令，清理无用脚本。

### 新增（Added）

- **`/team-version` 命令**：在 Claude Code 内一键查看当前已安装的团队版本号（读取 `~/.claude/team-version`）与全局 agents 数量，方便判断是否需要升级。`install` 脚本已将其纳入全局命令注册（Claude Code 内现共 `/team-init`、`/team-kb-save`、`/team-version` 三个命令）。

### 移除（Removed）

- **删除 `scripts/kb-sync.sh`**：该脚本是早期「知识库远端同步」设想的占位实现（实际只做本地 status/backup），未被任何安装/升级流程引用，远端同步能力也从未落地。知识库的沉淀与去重已由 `kb-curator` agent 和 `/team-kb-save` 负责，故移除以减少冗余。

### 文案（Docs）

- 安装/升级说明不再强调「仓库是否公开」，统一表述为「下载发布包后在本地运行脚本」。

---

## [1.2.0] - 2026-06-11

> 安装/升级改为本地脚本，不再依赖 Claude Code 内联网下载。把「升级」逻辑从 AI 命令迁移为本地脚本，精简 Claude Code 内命令集。

### 变更（Changed）

- **安装/升级迁移到本地脚本**：移除 `.claude/commands/team-install.md` 与 `.claude/commands/team-update.md` 两个 Claude Code 命令（它们原先会从 GitHub 克隆/下载，现统一改为本地发布包脚本）。
  - 新增 `scripts/update.ps1` / `scripts/update.sh`：从解压后的本地发布包运行，**不联网**。复用 `install` 刷新全局 agents/命令/知识库/workflow，并同步「运行时所在项目目录」CLAUDE.md 的「## 团队配置」段落（保留用户技术栈/部署环境字段）。可选传入项目目录参数。
  - 首次安装继续用 `scripts/install.ps1` / `scripts/install.sh`。
- **命令重命名**：`.claude/commands/kb-save.md` → `team-kb-save.md`，使 Claude Code 内团队命令以 `team-` 前缀排列在一起。同步更新 `agents/kb-curator.md` 中的 `/kb-save` 触发引用为 `/team-kb-save`。
- **Claude Code 内仅保留两个命令**：`/team-init`（初始化项目）、`/team-kb-save`（沉淀知识库）。`install` 脚本的全局命令注册同步改为注册这两个。
- 同步更新 `README.md`、`INSTALL.md`：安装/升级改为本地脚本流程，移除对已删命令与 `git clone`/`git pull` 升级方式的引用。
- **删除冗余的 `scripts/team-init.ps1` / `scripts/team-init.sh`**：项目初始化统一在 Claude Code 内用 `/team-init` 命令完成。这两个脚本会生成**旧格式**的 `CLAUDE.md` 团队配置段落（缺少 v1.0.7 的 orchestrator 启动方式引导），属于有害冗余。`docs/USAGE.md` 中的对应引用同步改为 `/team-init`。
- **install 脚本自动清理废弃命令**：`install.ps1` / `install.sh` 注册全局命令时，会移除老用户 `~/.claude/commands/` 下遗留的 `team-install.md`、`team-update.md`，避免误触已失效命令。

### 升级方式

下载并解压 v1.2.0 发布包，进入你的项目目录后运行解压目录里的升级脚本：

```bash
bash /path/to/解压目录/scripts/update.sh        # Mac/Linux/WSL
pwsh C:\path\to\解压目录\scripts\update.ps1      # Windows
```

> 老用户的 `/team-update` 命令在升级后会被移除；之后升级一律走本地 `scripts/update.*`。

---

## [1.1.2] - 2026-06-11

> 修复 v1.1.x 经首次 audit-scan workflow 实战体检暴露的 3 个问题。

### 修复（Fixed）

- **[HIGH] `templates/workflows/audit-scan.workflow.js`**：扫描阶段 `return { dimension: dim, ...findings }` 用对象展开会被 agent 自填的 `dimension` 字段覆盖外层硬编码值，导致下游对抗式验证选错 agentType / 维度标签错乱。改为明确取 `findings.findings`。
- **[LOW] `templates/workflows/audit-scan.workflow.js`**：删除从未使用且注释语义倒置的孤立常量 `REFUTE_AGENT_TYPE`。
- **[LOW] `scripts/install.ps1`**：`Write-VersionFile` 由 `Out-File -Encoding utf8`（PS 5.1 下写入 BOM）改为无 BOM 的 `[System.IO.File]::WriteAllText`，避免 `install.sh` 读取版本号时 BOM 残留导致版本比较永不相等、每次全量重装。

---

## [1.1.1] - 2026-06-10

> 仓库地址迁移至 `https://github.com/trkjoy/claude-dev-ai-team`，同步更新所有安装/升级下载源、README/INSTALL/USAGE 中的 clone 地址与目录名。

### 变更（Changed）

- **仓库迁移**：仓库地址从 `https://github.com/trkjoy/claude-standard-dev-team` 迁移至 `https://github.com/trkjoy/claude-dev-ai-team`（仓库名从 `claude-standard-dev-team` 变更为 `claude-dev-ai-team`）。
- 同步更新 `.claude/commands/team-install.md` 和 `.claude/commands/team-update.md` 中的下载源 URL 及解压后目录名。
- 同步更新 `README.md`、`INSTALL.md`、`docs/USAGE.md` 中所有 `git clone` 示例 URL 及 `cd`/路径引用。
- 同步更新 `scripts/install.sh` 与 `scripts/install.ps1` 中面向用户的提示字符串。
- 同步更新 `package-lock.json` 中的 `name` 字段。

### 升级方式

老用户运行 `/team-update` 即可拉取最新命令与 agents，无其他行为变更。

---

## [1.1.0] - 2026-06-10

> 接入 Workflow 并行编排引擎与 /goal 目标锚定能力，属 feature 级新增，无破坏性行为变更。

### 新增（Added）

- **Workflow 并行编排引擎（互补挂载 + 规则提示）**：在 `agents/orchestrator.md` 的需求分类环节后新增「Workflow 适用性扫描」——命中阈值（并行任务 ≥5 / 全仓扫描 ≥50 文件 / 同质操作 ≥20 处 / 需对抗验证 / 预估 >30 分钟）时**提示用户是否启用**，用户不点头则零行为变化，完全走原有 markdown 流程。
  - **5 个下沉挂载点**：Phase5 后端多接口并行、Phase6 前端多页面并行、模板 B Audit 多维并行（bug/性能/安全/契约）+ 对抗验证、Phase7 安全审计按模块并行投票、大规模迁移/重构场景。
  - 复用现有 13 个 agent（`agentType` 指向现有团队成员），**不新增 agent，不改任何 agent 契约**。
  - 部署/删除/git push 等不可逆操作永远不进 workflow，仍由 orchestrator 串行把关。
- **Workflow 脚本模板**：新增 `templates/workflows/team-dev-loop.workflow.js`（后端/前端 Dev-QA Loop 并行化，保留实现→验证→重试 ≤2 语义）与 `templates/workflows/audit-scan.workflow.js`（Audit 多维并行 + 对抗式验证），**随 `install.sh` / `install.ps1` 分发到用户级 `~/.claude/team-workflows/`**。
- **install 分发 workflow 模板**：`scripts/install.sh` 与 `scripts/install.ps1` 的 Claude Code 安装分支新增第 3 步——将 `templates/workflows/*.workflow.js` 复制到 `~/.claude/team-workflows/`（目录命名与 `team-memory` 风格一致，幂等：重复运行不报错）。
- **/goal 目标锚定**：`agents/orchestrator.md` 新增「/goal 锚定」小节——长链路任务（完整项目/大规模迁移/多轮 Audit-Fix）启动时把用户原始需求固化为一句话锚定目标，写入 `team-state/GOAL.md`；每个 Phase 边界自检是否偏离；workflow 下沉时把锚定目标作为硬性终止条件。**仅对长链路任务启用，单任务/Hotfix/纯文档不引入**。

### 升级方式

```bash
git pull
/team-install   # 刷新全局 agents + 分发 workflow 模板到 ~/.claude/team-workflows/
```

升级后**重启 Claude Code** 让新 agent 与 workflow 模板生效。

---

## [1.0.11] - 2026-06-03

> 在团队系统提示词层固化两条全局执行准则，解决「回答语言漂移」与「Windows 命令行反复出错」两类稳定性问题。

### 新增 / 变更（Added / Changed）— 含行为变更，升级后请留意

- **全局准则①｜强制简体中文输出**：15 个 agent（`agents/*.md`）顶部统一新增「🌐 全局执行准则」段落，要求始终用简体中文思考、回答与产出（分析、汇报、代码注释、文档、`*_STATUS.md` 等状态文件、提交信息均中文），即使被英文/日文提问也用中文，仅代码标识符、API 字段名、命令、专有名词保留英文。同步写入 `templates/memory/project-CLAUDE.md` 的「团队配置」段落，覆盖顶层 orchestrator 主会话。
  - ⚠️ **行为变更**：此前 agent 偶尔会漂移成日语/英语回答，升级后输出语言固定为中文。
- **全局准则②｜Windows 命令行优先 PowerShell**：12 个含 Bash 工具的 agent 新增规则——Windows 环境执行 shell 一律优先用 PowerShell；**若 Bash 工具报错或返回空输出，立即改用 PowerShell 重试同一目的的命令，禁止对同一命令反复用 Bash 重试**（macOS/Linux/WSL 仍用 Bash）；文件读写与搜索优先用 Read/Glob/Grep 专用工具。无 Bash 的 3 个 agent（product-manager / software-architect / ui-designer）仅加语言规则。
  - ⚠️ **行为变更**：此前在 Windows 上 Bash 取数失败时会反复重试 Bash，升级后会及时切换 PowerShell，减少无效轮次。

### 升级方式

```bash
/team-update            # 刷新全局 13 agents + 同步当前项目 CLAUDE.md 团队配置段落
```

> 升级后请**重启 Claude Code** 让新 agent 生效。

---

## [1.0.10] - 2026-06-01

### 修复（Fixed）

- **安装脚本漏注册 `/team-update` 命令**：`scripts/install.ps1` 与 `scripts/install.sh` 的 Claude Code 安装分支此前只复制 `team-install.md`、`team-init.md` 两个命令，遗漏了 `team-update.md`。导致**仅通过脚本（`install.sh` / `install.ps1`）首次安装**的用户拿不到 `/team-update` 命令；通过 Claude Code 内 `/team-install`（AI 命令）安装的用户不受影响。现已补齐为三个命令一并注册。

### 升级方式

```bash
git pull && /team-install     # 或 bash scripts/install.sh / pwsh .\scripts\install.ps1
```

---

## [1.0.9] - 2026-06-01

> 一次安全加固发布：收紧默认权限、补强分发信任链、修复脚本健壮性与文档一致性问题。源于对仓库的一次完整安全审查。

### 安全 / 变更（Security / Changed）— 含行为变更，升级后请留意

- **H1｜收窄项目模板的 Bash 权限**：`templates/memory/settings.json` 与仓库 `.claude/settings.json` 不再无差别 `allow: ["Bash"]`（原配置等于静默自动执行任意 shell 命令）。改为：只读工具（Read/Glob/Grep）+ Task/Write + **Bash 安全前缀白名单**（`npm/npx/pnpm/yarn/node/python/pip/pytest/go/cargo`、`git status|diff|log|add|restore`、`mkdir/ls/cat/echo`）。
  - ⚠️ **行为变更**：白名单之外的命令（`rm`、`curl|bash`、`sudo` 等）升级后将**逐条弹确认**，不再静默放行。需要更高自动化的用户可自行在项目 `.claude/settings.json` 增补前缀。
- **H2｜停止跟踪本地配置**：`.claude/settings.local.json` 从版本库移除并加入 `.gitignore`。该文件含本机绝对路径、`git push` 等危险自动放行项及损坏编码，本不应入库。
- **M1｜分发信任边界提示**：`README.md`、`.claude/commands/team-install.md` 增加安全说明——远程安装/升级从 GitHub `main` 拉取且**不校验完整性**、本仓库为 fork，建议优先本地 clone 安装、升级锁定 tag、安装前自审 `agents/*.md`。
- **M3｜orchestrator 强制安全确认点**：`agents/orchestrator.md` 新增确认点——部署/热部署、删除文件或数据、`git push`/`reset --hard`、`sudo`/系统级、外发数据或对接生产凭据等**不可逆或对外操作前必须展示命令并等待用户确认**，即使 `settings.json` 已放行相关工具也生效（质量门 ≠ 安全门）。
  - ⚠️ **行为变更**：完整项目 Phase 9 部署、Hotfix 热部署等环节会新增一次人工确认暂停。

### 修复（Fixed）

- **M2**：`scripts/install.sh`、`scripts/install.ps1` 在写入 `~/.codex/AGENTS.md`、`~/.gemini/GEMINI.md` 前自动备份为 `*.bak.时间戳`，避免覆盖用户已有的全局指令文件。
- **L1**：`install.ps1` 的 `Get-AgentName` 限定在 frontmatter（前两个 `---` 之间）匹配 `name:`，与 `install.sh` 行为一致，避免误取正文中的 `name:` 行。
- **L2**：`INSTALL.md` 旧版 PowerShell 安装命令由 `-ExecutionPolicy Bypass` 改为 `RemoteSigned`（足够运行本地脚本，不全量绕过）。
- **L3**：`/team-update` 指定版本时，commit message 兜底搜索改为精确边界匹配；**0 条或多条命中时停止并列出候选**，要求用户用确切 commit hash 指定，不擅自猜选。
- **L5**：`INSTALL.md` 卸载清单补全遗漏的 `kb-curator`、`qa-automator` 两个 agent 及 `team-update.md` 命令，避免卸载残留。

### 升级方式

```bash
git pull            # 仓库目录
/team-install       # 在 Claude Code 内运行，刷新全局 agents 与命令
# 或在已初始化的项目目录：
/team-update        # 升到最新（1.0.9），并同步该项目 CLAUDE.md
```

升级后**重启 Claude Code** 让 agent 与命令重新加载。

> ⚠️ **已初始化项目的 `settings.json` 不会被自动更新**（`/team-init` 幂等、不覆盖已有文件）。如需让旧项目也享受 H1 的权限收窄，请手动用 `templates/memory/settings.json` 的新内容替换项目里的 `.claude/settings.json`。

---

## [1.0.8] - 2026-05-25

### 变更（Changed）

- **仓库迁移**：本仓库 fork 自上游 `xuanbingbingo/claude-standard-dev-team`，新地址为 `https://github.com/trkjoy/claude-standard-dev-team`。
  - 同步替换所有文档、安装命令、升级命令、Plan 文档中的 `git clone` / `curl` / `Invoke-WebRequest` 下载源。
  - 涉及文件：`.claude/commands/team-install.md`、`README.md`、`INSTALL.md`、`docs/USAGE.md`、`docs/superpowers/plans/2026-05-1*.md`。
  - `LICENSE` 中原作者署名按 MIT 协议要求保留不变。

### 升级方式

#### 已经用过老版本的同事（推荐 `/team-update`）

进入任一已经初始化过的项目目录，在 Claude Code 内运行：

```
/team-update          # 升到最新（1.0.8）
/team-update 1.0.8    # 升到指定版本
```

它会自动从新仓库地址刷新全局 13 个 agent，并同步当前项目 CLAUDE.md 的团队配置段落。

> ⚠️ 如果你的 `/team-update` 命令本身就是 v1.0.7 的旧版（指向老仓库），它无法升级自己。请先按下方"全新拉取覆盖"方式手动跑一次 `/team-install`，把命令本体替换为新仓库版本，之后 `/team-update` 才能正常工作。

#### 全新拉取覆盖（升级 `/team-update` 自身 或 首次安装）

```bash
# Mac/Linux/WSL
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

```powershell
# Windows
git clone https://github.com/trkjoy/claude-standard-dev-team.git
cd claude-standard-dev-team
pwsh .\scripts\install.ps1
```

或在 Claude Code 内 `cd` 到仓库目录后运行 `/team-install`。

完成后**重启 Claude Code**。

### 验证升级是否生效

```bash
# Mac/Linux/WSL
grep -c trkjoy ~/.claude/commands/team-install.md   # 应输出 ≥ 2
cat ~/.claude/agents/orchestrator.md | head -1      # 文件存在即可
```

```powershell
# Windows
(Get-Content "$HOME\.claude\commands\team-install.md" | Select-String 'trkjoy').Count   # 应 ≥ 2
```

---

## [1.0.7] - 2026-05-22

### 新增（Added）

- **`/team-update` 全局命令**：一条命令把当前项目升级到**指定版本**（或最新版），自动完成两件事：
  - 刷新全局 `~/.claude/agents/` 下的 13 个 agent
  - 同步当前项目 `CLAUDE.md` 的「团队配置」段落到目标版本（保留用户的技术栈 / 部署环境字段，幂等）
  - 用法：`/team-update`（升到最新）或 `/team-update 1.0.7`（升到指定版本，也可用于回滚）
  - 已加入 `/team-install` 的全局命令注册步骤，重新运行 `/team-install` 即可获得此命令

### 修复（Fixed）— 架构级

- **orchestrator 作为 subagent 无法派发下游团队**：修复 orchestrator 被 `Task` 启动为 subagent 后，整个团队流程瘫痪的问题。
  - 现象：团队开发过程中报错 `The orchestrator ran as a subagent and can't dispatch further agents — that's an environment limitation.`，orchestrator 无法派发任何下游 agent。
  - 根因：Claude Code **不支持 subagent 嵌套派发**——被 `Task` 启动的 subagent 内部 `Task` 工具不可用。而 orchestrator 的唯一职责就是用 `Task` 派发下游。orchestrator.md 被放在 `~/.claude/agents/` 注册为 subagent，且其 `description` 写着"当用户需要完成任何开发相关任务时激活"，强烈诱导主会话用 `Task` 启动 orchestrator subagent，恰好踩中嵌套派发限制。这也是 v1.0.6 "orchestrator 自己干活不派发"问题的真正根因——它不是不想派发，而是作为 subagent **无法**派发。
  - 修复（三层防御）：
    1. **`agents/orchestrator.md` 新增「运行模式声明」章节**（位于文件最顶部，凌驾于其余内容）：
       - 明确铁律——orchestrator 必须由 top-level 主会话亲自担任，禁止作为 subagent 用 Task 启动
       - 给出正确 vs 错误启动方式对照
       - 加入 subagent 自检 fallback：若发现自己作为 subagent 运行（Task 不可用），立即停止并输出"请主会话亲自接管"的指引，禁止伪装进度
    2. **修改 `description`**：从"当用户需要完成任何开发相关任务时激活"（诱导 Task 启动）改为"操作手册，由 top-level 主会话亲自担任，禁止作为 subagent 启动"
    3. **CLAUDE.md 引导**：`team-init` 命令生成的 CLAUDE.md 与 `templates/memory/project-CLAUDE.md` 模板均新增「启动方式」说明，明确"你就是 orchestrator 本人；只有下游 12 个 agent 才用 Task 派发"

### 升级方式

```bash
git pull
/team-install   # 刷新 ~/.claude/agents/orchestrator.md 与全局命令
```
升级后**重启 Claude Code**。

### 已有项目如何升级

如果你在 v1.0.7 之前已用 `/team-init` 初始化过项目，那些项目的 `CLAUDE.md` 缺少新的「启动方式」引导。**进入该项目目录，运行 `/team-update` 即可一键升级**（自动刷新全局 agents + 同步该项目 CLAUDE.md 的团队配置段落，保留你的技术栈/部署环境字段）。

> 首次使用 `/team-update` 前，需先 `git pull && /team-install` 一次，把该命令注册到全局。

### 验证升级是否生效

新开 Claude Code 会话说"使用标准团队开发 xxx"，观察：
- ✅ 主会话**自己**开始用 `Task` 派发 product-manager 等下游 agent（UI 上能看到嵌套的 Task 调用块）
- ❌ 不应再出现 "ran as a subagent and can't dispatch" 报错

---

## [1.0.6] - 2026-05-20

### 修复（Fixed）

- **orchestrator 防退化红线规则**：修复 orchestrator 在收到宽泛指令（如"使用标准团队开发"）时退化为"自己读项目代码、自己写契约文件"的问题。
  - 现象：用户报告 orchestrator 跑了 20 分钟、74 次工具调用、消耗 37.7k tokens，但全程未派发任何下游 agent，产出只有 `.claude/team-state/` 状态文件，没有 `docs/PRD.md` 等正常产出。
  - 根因：orchestrator.md 缺少强制的"派发优先"约束，遇到模糊需求时容易自己开始读代码"理解项目"，违背了"总指挥不写代码、只调度"的设计初衷。
  - 修复：在 `agents/orchestrator.md` 中新增「红线规则（最高优先级）」章节，凌驾于其他所有流程之上：
    - **4 条禁令**：禁止自己读业务代码、写契约文件、写业务代码、大范围扫描（>5 次）
    - **5 条允许清单**：白名单化允许操作（状态文件 / 已有契约读取 / 知识库 / 任务清单更新 / Task 派发）
    - **4 个自检红灯阈值**：连续 3 次非 Task / 读 >5 业务文件 / 累计 >10 次工具无派发 / 运行 >15 分钟无派发 —— 任一触发即自停并向用户报告
    - **模糊指令强制反问**：遇到"使用标准团队开发"这类宽泛指令必须先反问"新项目还是改造？走哪个模板？核心目标？"
    - **派发优先原则**：明确"派发是默认动作，自己动手是例外"

### 升级方式

仓库目录执行：
```bash
git pull
/team-install   # 在 Claude Code 内运行，刷新 ~/.claude/agents/orchestrator.md
```

升级后**重启 Claude Code** 让 agent 重新加载，新规则才会生效。

### 验证升级是否生效

新开一个 Claude Code 会话，对 orchestrator 说一句**模糊指令**：
```
使用 orchestrator agent，开始标准团队开发
```

**预期行为**：orchestrator 不应该立即开始读代码 / 写状态文件，而应该**先反问 3 个澄清问题**：
1. 这是新项目还是改造现有项目？
2. 走哪个模板（完整项目 / Audit / Hotfix）？
3. 核心目标是什么？

如果它仍然闷头干活、不反问，说明升级未生效 —— 检查 `~/.claude/agents/orchestrator.md` 是否真的被覆盖（看文件中是否包含"红线规则（最高优先级）"章节）。

---

## [1.0.5] - 历史版本

详见 git log：
```bash
git log --oneline
```

主要历史变更：
- 1.0.5 — 升级团队版本（AI 团队改造、新增 kb-curator、qa-automator、ui-designer）
- 1.0.3 — install 脚本新增 KB_MODE 参数
- 1.0.2 — 知识库新增项目源隔离
- 1.0.1 — templates/memory 文档添加文件/格式头说明
