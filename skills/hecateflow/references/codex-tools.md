# 工具映射:Codex / Codex Tool Map (reference)

HecateFlow skill 正文用 Claude Code 工具名书写。在 Codex 上按下表换成原生等价能力。若本文件与当前会话暴露的工具名不一致,以当前会话工具为准,并在执行前用 tool discovery 确认。

| skill 正文写的 | Codex 等价 |
|----------------|-----------|
| `Task`(派子代理) | 有多代理工具且用户明确授权时:`multi_agent_v1.spawn_agent`(派) → `multi_agent_v1.wait_agent`(取结果) → `multi_agent_v1.close_agent`(释放槽位);否则主会话自审并声明验证限制 |
| 多个 `Task` 并行 | 有多代理工具且用户明确授权时多次 `multi_agent_v1.spawn_agent`;否则顺序主会话执行 |
| `Read` / `Write` / `Edit` | 原生文件工具 |
| `Bash` / `PowerShell` | 原生 shell 工具 |
| `Grep` / `Glob` | 原生检索工具 |
| `TodoWrite` / `TaskCreate` | `update_plan` |
| `Skill`(调用 skill) | Codex 原生加载 skill —— 按其指令执行即可 |
| `AskUserQuestion` | Codex 无结构化提问工具 → 用纯文字向用户提问,给编号选项 |
| plan mode / `ExitPlanMode` | 无对应 —— 留在主会话,只读阶段靠自律不写文件 |

## 关键差异(影响 skill 行为)

1. **无 PostToolUse hook**:Claude 端 `hf-auto-workflow` 可挂 hook 自动触发;Codex 端无此机制 → 正文已写明"每次 Write/Edit 后你必须立即自跑审查",靠 prompt 自律。
2. **skill 发现靠 frontmatter `description`**:Codex 按关键词匹配 description 加载 skill,所以每个 skill 的 description 必须塞满中英触发词。
3. **目录扁平偏好**:Codex skill 以 `<name>/SKILL.md` 为主;共享资料通过相对路径读取。相对引用必须按安装后布局解析,例如 `../references/...`、`../hecateflow/references/...`、`../hecateflow/templates/...`。
