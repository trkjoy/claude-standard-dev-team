# 安装指南

把"标准团队"装进你自己的 Claude Code，3 分钟搞定。

## 前置条件

- 已安装 [Claude Code CLI](https://docs.claude.com/en/docs/claude-code/quickstart)
- 在终端执行 `claude --version` 能显示版本号

如果还没装，先去官方装好再回来。

---

## 安装

### 方式零：安装脚本（推荐，含用户级记忆库）

```bash
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team
bash scripts/install.sh
```

这会完成两件事：

1. 将 13 个 agent 安装到 `~/.claude/agents/`
2. 初始化用户级长期记忆库 `~/.claude/team-memory/patterns/`

安装后，在每个新项目目录执行一次初始化：

```bash
bash /path/to/claude-standard-dev-team/scripts/team-init.sh
```

这会在当前项目生成：

- `CLAUDE.md`
- `.claude/settings.json`
- `.claude/team-state/STATE.md`
- `.claude/team-state/RETRY_LOG.md`
- `.claude/team-state/DECISIONS.md`
- `.claude/team-state/LEARNINGS.md`

填写 `CLAUDE.md` 中的技术栈和部署环境后，在 Claude Code 中说：

```text
使用标准团队开发 你的需求
```

orchestrator 会读取项目状态和用户级记忆库，按阶段自动拆解、开发、验证、失败打回和恢复。

---

### 方式一：克隆仓库后批量复制（推荐）

```bash
# 1. 克隆仓库到任意位置
git clone https://github.com/xuanbingbingo/claude-standard-dev-team.git
cd claude-standard-dev-team

# 2. 确保 ~/.claude/agents 目录存在
mkdir -p ~/.claude/agents

# 3. 复制全部 agent 到 Claude Code agent 目录（12 个团队成员 + 1 个总指挥）
cp agents/*.md ~/.claude/agents/

# 4. 验证
ls ~/.claude/agents/ | grep -E "orchestrator|product-manager|software-architect"
```

看到 3 个文件名就装成功了。

### 方式二：只装部分 agent

如果你只想用其中几个（比如只要 product-manager 帮你写 PRD），可以只复制对应文件：

```bash
cp agents/product-manager.md ~/.claude/agents/
cp agents/software-architect.md ~/.claude/agents/
```

但 **orchestrator 必须配合至少另外 2-3 个 agent 才有意义**——它自己不写代码，只是调度。

---

## 验证安装

打开 Claude Code，新开一个对话窗口，输入：

```
使用标准团队帮我做一个简单的 todo 应用
```

如果看到主对话回复类似下面的内容，就装成功了：

> 收到。我现在派 orchestrator 接管这个项目，会按 11 阶段流程跑：先让 product-manager 写 PRD，等你确认范围后再进入 API 契约设计...

如果没有任何反应，或者主对话直接开始写代码（没调 orchestrator），检查：

1. 文件确实在 `~/.claude/agents/` 下（不是 `~/Claude/agents/` 或别的地方）
2. 文件后缀是 `.md`，不是 `.md.txt`
3. 重启 Claude Code 让它重新加载 agent 列表

---

## 卸载

```bash
cd ~/.claude/agents/
rm orchestrator.md product-manager.md software-architect.md ui-designer.md \
   database-optimizer.md backend-architect.md frontend-developer.md \
   devops-automator.md testing-evidence-collector.md security-engineer.md \
   code-reviewer.md reality-checker.md technical-writer.md
```

---

## 与你已有的 agent 冲突？

如果 `~/.claude/agents/` 里已经有同名文件（比如你自己写过 `product-manager.md`），`cp` 会覆盖。

**安全做法**：先备份你自己的版本

```bash
mkdir -p ~/.claude/agents/_backup_$(date +%Y%m%d)
cp ~/.claude/agents/*.md ~/.claude/agents/_backup_$(date +%Y%m%d)/
```

然后再 `cp agents/*.md ~/.claude/agents/`。不满意了可以从 backup 还原。

---

## 升级到新版本

```bash
cd /your/clone/path/claude-standard-dev-team
git pull
bash scripts/install.sh
```

---

## 常见问题

### Q: 我必须把全部 13 个 .md 都装吗？

A: 不必。但 `orchestrator`（总指挥）+ 规划层 2 + 实现层至少 1 个，是最小可用集合。完整 13 个 .md（12 团队成员 + 1 总指挥）能跑通完整 11 阶段。

### Q: 这套 agent 会修改我的代码吗？

A: 它们只在 Claude Code 的 agent 沙箱里跑。所有写文件操作都受 Claude Code 自身的权限模型约束——和你直接用 Claude Code 一样。

### Q: 我可以改这些 agent 的 prompt 吗？

A: 当然，复制过去就是你的了。建议改之前先理解每个 agent 的职责边界（看 [WORKFLOW.md](WORKFLOW.md)），不要随便删除"打回机制"和"零容忍硬编码"那部分——那是踩过的坑总结出来的。

### Q: 在 Claude Code 之外（比如 Cursor / Cline）能用吗？

A: 不能。这套配置依赖 Claude Code 的 [Subagents 机制](https://docs.claude.com/en/docs/claude-code/sub-agents)，其他 IDE 没有这个能力。

### Q: 跑一次大概多少 token？

A: 主对话本身消耗很低（几千 token），但 orchestrator 内部会派多个 agent，每个 agent 在独立 session 里跑，加起来一个完整中型项目大约 **50-200k token**（取决于复杂度）。具体看 Claude Code 的用量统计。

---

有其他问题欢迎开 [Issue](https://github.com/xuanbingbingo/claude-standard-dev-team/issues)。
