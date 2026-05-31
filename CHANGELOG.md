# 变更日志

本文件记录每个版本的关键变更，方便团队成员判断是否需要升级、以及升级带来的行为差异。

格式遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

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
