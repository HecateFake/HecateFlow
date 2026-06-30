# 工具映射:Codex / Codex Tool Map (reference)

HecateFlow skill 正文用 Claude Code 工具名书写。在 Codex 上按下表换成原生等价能力。若本文件与当前会话暴露的工具名不一致,以当前会话工具为准,并在执行前用 tool discovery 确认。

Reasonix 也可复用同一套 skill 正文,但本文件不声明固定 Reasonix 工具名映射。执行时以 Reasonix 当前会话实际暴露的读写、shell、计划、提问等工具为准;没有等价工具时,按 Codex 的降级原则在主会话内完成并说明验证限制。

Qoder/QoderCN 也可复用同一套 skill 正文。Qoder 可能同时暴露 Claude Code 兼容工具名(`Write`/`Edit`/`MultiEdit`)与 native 工具名(如 `create_file`/`search_replace`);执行时以当前会话实际工具为准。安装器会把 skill 安装到 `~/.qoder-cn/skills` 或 `~/.qoder/skills`,并在支持 hook 的 `settings.json` 中覆盖两类写文件 matcher。

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

1. **PostToolUse hook 差异**:Claude Code 与 Qoder/QoderCN 可挂 hook 自动触发 `hf-auto-workflow` 提醒;Codex 与 Reasonix 当前无标准 hook → 正文已写明"每次 Write/Edit 后你必须立即自跑审查",靠 prompt 自律。
2. **skill 发现靠 frontmatter `description`**:Codex 按关键词匹配 description 加载 skill,所以每个 skill 的 description 必须塞满中英触发词。
3. **目录扁平偏好**:Codex skill 以 `<name>/SKILL.md` 为主;共享资料通过相对路径读取。相对引用必须按安装后布局解析,例如 `../references/...`、`../hecateflow/references/...`、`../hecateflow/templates/...`。
