# 工具映射:Claude Code / Claude Code Tool Map (reference)

HecateFlow 所有 skill 正文用 Claude Code 的工具名书写。在 Claude Code 上它们就是原生工具,但必须同时遵循 `orchestration-contract.md`:主 agent 持权,先自主求证,主动派发只读子代理,写入 worker 后置受限,Git 永不下放。

| skill 正文写的 | Claude Code 实际工具 |
|----------------|---------------------|
| 派子代理 / dispatch subagent | `Task`(`subagent_type: "Explore"` 只读探查 / `"code-reviewer"` 审查 / `"general-purpose"` 只读规划或复核;按复杂度主动派发,不需要额外确认;派发前清理完成代理并防止占满并发上限;写入 worker 仅在用户已明确要求实现/修改/落地/应用补丁且互斥文件范围成立后使用) |
| 多个子代理并行 | 单条消息里多个 `Task` 调用;默认主动用于只读调研/复审,但按批次派发并保留复审槽位;不得让子代理 stage / commit / push |
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
- `hf-implement` 属 build 阶段,用户已明确要求实现/修改/落地/应用补丁时主 agent 可写;进入写入前先自主调研并明确 worker 文件范围、接口预期、验证方式和禁止事项。
- Git 收尾只报告摘要、验证结果、建议提交说明和待暂存文件;stage / commit / push 必须等用户确认。

## 编排契约

完整规则见 `orchestration-contract.md`。若某个会话没有可用子代理工具或宿主策略限制无显式请求派代理,主 agent 必须降级为本地只读命令亲验关键证据,并说明平台限制导致无法并行复核。

并发槽位也属于编排契约:派发前关闭完成/不再需要的代理,`wait` 后吸收结论并及时释放槽位;并发上限不能成为少做只读复核或把只读派发转嫁给用户确认的理由。
