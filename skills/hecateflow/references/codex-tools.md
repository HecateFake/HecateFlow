# 工具映射:Codex / Codex Tool Map (reference)

HecateFlow skill 正文用 Claude Code 工具名书写。在 Codex 上按下表换成原生等价能力。若本文件与当前会话暴露的工具名不一致,以当前会话工具为准,并在执行前用 tool discovery 确认。所有多代理使用都必须继承 `orchestration-contract.md`:主 agent 持权,先自主求证,主动派发只读子代理,写入 worker 后置受限,Git 永不下放。

Reasonix 也可复用同一套 skill 正文,但本文件不声明固定 Reasonix 工具名映射。执行时以 Reasonix 当前会话实际暴露的读写、shell、计划、提问等工具为准;没有等价工具时,按 Codex 的降级原则在主会话内完成并说明验证限制。

Qoder/QoderCN 也可复用同一套 skill 正文。Qoder 可能同时暴露 Claude Code 兼容工具名(`Write`/`Edit`/`MultiEdit`)与 native 工具名(如 `create_file`/`search_replace`);执行时以当前会话实际工具为准。安装器会把 skill 安装到 `~/.qoder-cn/skills` 或 `~/.qoder/skills`,并在支持 hook 的 `settings.json` 中覆盖两类写文件 matcher。

| skill 正文写的 | Codex 等价 |
|----------------|-----------|
| `Task`(派子代理) | 有多代理工具时主动派只读 explorer / architect / reviewer;高风险结论再派复审子代理查证据/矛盾/过度推断,不需要用户额外确认。派发前关闭已完成/不再需要的代理,`wait_agent` 后及时 `close_agent`,防止占满并发上限。写入 worker 仅在用户已明确要求实现/修改/落地/应用补丁、方案已定、文件范围互斥且边界清楚时使用;否则主会话自审并声明验证限制 |
| 多个 `Task` 并行 | 有多代理工具时主动多路只读并行,但按批次派发并保留复审槽位;写入 worker 不并行改重叠文件;无工具或宿主策略限制时顺序主会话执行 |
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
4. **主动只读派发不可写成用户负担**:HecateFlow 策略是按复杂度自动派只读子代理;若当前宿主工具规则禁止无显式请求派代理,必须声明是平台限制,不得写成 HecateFlow 需要用户确认。
5. **并发槽位不可耗尽**:多代理可用时要主动派发,同时清理完成代理、分批派发、保留复审槽位;并发上限是调度约束,不是少派只读复核或把只读派发转嫁给用户确认的理由。
6. **Git 确认门不可降级**:无论 Codex 是否有多代理工具,子代理/worker 都不得 stage / commit / push;主 agent 完成验证后只先报告建议提交说明和待暂存文件,等待用户确认。
