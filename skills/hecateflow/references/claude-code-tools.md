# 工具映射:Claude Code / Claude Code Tool Map (reference)

HecateFlow 所有 skill 正文用 Claude Code 的工具名书写。在 Claude Code 上它们就是原生工具,直接使用即可。

| skill 正文写的 | Claude Code 实际工具 |
|----------------|---------------------|
| 派子代理 / dispatch subagent | `Task`(`subagent_type: "Explore"` 只读探查 / `"code-reviewer"` 审查 / `"general-purpose"`) |
| 多个子代理并行 | 单条消息里多个 `Task` 调用 |
| 读文件 | `Read` |
| 写文件 | `Write` |
| 编辑文件 | `Edit` |
| 跑命令 | `Bash`(POSIX) / `PowerShell`(Windows 原生) |
| 内容检索 | `Grep` |
| 文件名匹配 | `Glob` |
| 询问用户 | `AskUserQuestion`(schema 见下) |
| 调用另一个 skill | `Skill` 工具 |
| 进度跟踪 | `TodoWrite` / `TaskCreate` |

## AskUserQuestion schema(两端通用约束)

`questions` 必须是数组,每个元素必须同时含 `question` / `header` / `options`,`options` 为 2–4 个 `{label, description}`。禁止把 questions 当 JSON 字符串传;校验失败最多重试一次,仍失败改用纯文字询问。

## 计划/审查模式

- Claude Code 有 plan mode:只读规划阶段不要写文件。`hf-design-module` 属只读规划,适合在 plan mode 跑。
- `hf-implement` 属 build 阶段,需要写权限。
