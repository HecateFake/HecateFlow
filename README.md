# HecateFlow

> 可复用、与具体 MCU 无关的**嵌入式开发生命周期 skill 系统**,从一个真实的多核裸机 C 工程的成熟开发流程中蒸馏而来。同时支持 **Claude Code** 与 **Codex**。
>
> A reusable, MCU-agnostic **embedded-development lifecycle skill system**, distilled from the hard-won workflow of a real multi-core bare-metal C project. Works in both **Claude Code** and **Codex**.

---

## 这是什么 / What it is

HecateFlow 把嵌入式开发从"工作区初始化"到"提交前审查"的完整生命周期,组织成一组**可交互调用、使用时自定义**的 skill。它不绑定任何芯片或工具链——你的 MCU 家族、工具链、构建系统、各核职责都记在一份持久化工程清单 `.hecateflow/project.json` 里,skill 读它做默认值,只问你没填的。

HecateFlow organizes the full embedded lifecycle — from workspace bootstrap to pre-commit review — into a set of **interactive, customize-at-use-time** skills. It binds to no specific chip or toolchain: your MCU family, toolchain, build system, and per-core roles live in a persistent manifest (`.hecateflow/project.json`); skills read it for defaults and only ask for what's missing.

## 为什么 / Why

裸机/实时嵌入式的真正成本不在算法,而在反复踩的坑:漏 `volatile` 的幽灵 bug、ISR 里的阻塞、执行器无钳位、**极性藏进 PID Kp 负号致正反馈跑飞**、新文件忘登记进 IAR/Keil 工程导致链接错误、文档与代码漂移、构建变体改一处漏五处、ICF 注释混中文崩链接器、绝对机器路径入库换机即坏,以及排查 bug 时把"用户结论"或"SDK/provider 不会错"直接当事实。HecateFlow 把这些经验固化成**可逐项判定的清单**和**带交互的工作流**,让它们可复用到任意嵌入式工程。

v1.1 深化的工程纪律(均 MCU 无关):**固化场景**(把赛规/安全约束写进 manifest 常驻贯穿)、**单工作区多工程管理**(关键词→target 路由 + 同名异义登记 + 共享库版本登记)、**分级分布式文档**(三层按需下钻省上下文)、**自动进化学习**(代码改动→必同步文档矩阵)、**经验记忆不再犯**(本地 `.hecateflow/lessons/` 跨平台 record→recall→avoid→promote)、**事实来源二次确认**(用户/SDK/历史注释/既有代码都只是证据来源,"不可能出现"须复核后才采信)、**硬件映射头 + 参数头 + 极性单一真相源**(三组方向系数 + 开环辨识 + 禁藏 Kp 负号 + 闭环轴向对齐 + 数量级理智检查)、**硬件驱动代码级单一 owner**(面向对象式实例/API 管理,避免竞态和多头管理混乱)、**自动注入**(规则/skill 在各 CLI 被自动加载发现)、**clangd 配置管理**(初始化先问是否用 + 六条同步经验)、**IO 外设多核归属 + 分核任务规划**、**相对路径优先**。详见 [`docs/methodology.md`](docs/methodology.md)。

## Skill 一览 / The skills

共 **13 个 skill**(总入口 + 12 个 `hf-`):

| Skill | 作用 |
|-------|------|
| `hecateflow` | **总入口**:读/初始化工程清单,展示生命周期地图并路由,注入全局红线(目标识别/场景/Git/相对路径/极性/IO 归属/驱动 owner/lessons)。 |
| `hf-init-workspace` | 交互式初始化工作区,生成 `.hecateflow/project.json` + 开发纲领 + 自动注入(询问是否用 clangd / 采集固化场景)。 |
| `hf-init-project` | 为一个核/芯片/固件建 PROJECT.md + 非扁平脚手架 + 生成 pinMap/config 头 + 极性表 + 登记独占外设 + 驱动 owner 清单。 |
| `hf-design-module` | 增量模块设计(只读):复用调研 + 切点清单 + 仿真判定 + 极性/数量级/IO 归属/驱动 owner 检查点。 |
| `hf-implement` | 增量实施:写码 + 登记 + 每编辑审查 + 文档同步 + 计划文件 + lessons 记录 + Git 收尾。 |
| `hf-review` | 提交前深度审查(多维 + 子代理对抗 + 场景合规 + 多工程一致性 + lessons 覆盖)。 |
| `hf-auto-workflow` | **always-on** 每次编辑后的核心 6 步 + 扩展检查(极性/相对路径/IO 归属/驱动 owner/lessons)审查门。 |
| `hf-embedded-safety` | ISR/volatile/数值/外设所有权/驱动 owner/失控锁定/惰性 set 语义/ICF ASCII 安全审查。 |
| `hf-hw-mapping` | **硬件映射头 + 参数头 + 极性单一真相源**(三组 DIR/禁藏 Kp 负号/开环辨识)+ 数量级理智检查 + IO 归属 + 驱动单一 owner。 |
| `hf-build-sync` | 新文件登记进构建系统(IAR/Keil/CMake/Make)+ LSP/clangd(先问是否用 + 六条经验)。 |
| `hf-doc-discipline` | 文档即真相源:分级文档省上下文 + 同步矩阵 + 版本登记 + 多工程路由 + lessons 衔接。 |
| `hf-lessons` | **工程经验记忆 / 不再犯回路**:本地 `.hecateflow/lessons/`(跨平台)record→recall→avoid→promote。 |
| `hf-refactor` | 行为保持重构:机械等价变换 + 子代理对抗审查代替编译。 |

生命周期典型路径 / typical lifecycle:
`hf-init-workspace` → `hf-init-project` → `hf-design-module` → `hf-implement` → `hf-review`,`hf-refactor` 与知识层(`hf-embedded-safety`/`hf-hw-mapping`/`hf-build-sync`/`hf-doc-discipline`/`hf-lessons`)按需唤起。

## 安装 / Install

把 `skills/` 安装到 `~/.claude/skills` 与 `~/.codex/skills`(模板随 `hecateflow` 入口捆绑)。幂等,可重复运行升级。

**Windows (PowerShell 7 / `pwsh`):**
```powershell
git clone https://github.com/HecateFake/HecateFlow.git
cd HecateFlow
pwsh -NoProfile -ExecutionPolicy Bypass -File ./install.ps1
```

默认会同时把 Claude Code `PostToolUse` hook 写入 `~/.claude/settings.json`,在 `Write`/`Edit`/`MultiEdit` 后注入 `hf-auto-workflow` 提醒。若只想安装 skill、不改 Claude Code hook:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./install.ps1 -SkipClaudeHook
```

**macOS / Linux / Git Bash:**
```sh
git clone https://github.com/HecateFake/HecateFlow.git
cd HecateFlow
sh install.sh
```

跳过 Claude Code hook:

```sh
sh install.sh --skip-claude-hook
```

安装后验证 / verify after install:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/audit-skill-package.ps1
```

只审源码包、不比对已安装副本:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./scripts/audit-skill-package.ps1 -SkipInstalled
```

装好后,在 Claude Code 或 Codex 新会话里说 **`hecateflow`** 或"初始化这个嵌入式工作区"即可开始。

## 快速开始 / Quick start

1. `hecateflow` —— 入口检测到没有 `.hecateflow/project.json`,引导你跑 `hf-init-workspace`。
2. `hf-init-workspace` —— 探测 `.ewp`/`CMakeLists.txt` 等,交互确认 MCU/工具链/构建系统,写工程清单。
3. `hf-init-project` —— 为每个核/芯片建 PROJECT.md。
4. `hf-design-module` —— 设计新模块,产出切点清单 + 计划文件。
5. `hf-implement` —— 按计划落地,每次编辑自动审查、登记、同步文档。

## 最小样例 / Minimal example

`examples/minimal-cmake/` 是一个小型 CMake 风格工作区,用于回归测试 HecateFlow 的 manifest、PROJECT.md、pinMap/config 头、lessons 和计划文件协同。可用它验证 agent 是否能按 `hecateflow` → `hf-implement` → `hf-build-sync` → `hf-auto-workflow` 的链路输出 `HecateFlow Check`。

## 工程清单 / The manifest

`.hecateflow/project.json` 是 HecateFlow 的交互记忆,记录 `workspace`(MCU/工具链/编码 + `scenario` 固化场景 + `lsp` 是否用 clangd)、`buildSystem`(类型 + 文件登记方式)、`targets[]`(各核职责/`layout` 非扁平布局/`headers` 硬件映射头与极性源/`ownedPeripherals` 独占外设/高危同名文件)、`docs`、`git`、`lessons`(本地经验记忆目录)、`autoInjection`(规则注入)、`paths.preferRelative`、`activeChecks`(含 `polarityMagnitude`/`relativePaths`/`ioOwnership`/`factConfirmation`/`lessonsCapture`)等。schema 见 [`skills/hecateflow/references/manifest-schema.md`](skills/hecateflow/references/manifest-schema.md)。

## Claude Code 自动审查 hook / Auto-review hook

`install.ps1` / `install.sh` 默认会安装这个 hook。它不会直接修改代码,只在 Claude Code `Write`/`Edit`/`MultiEdit` 后给 Claude 注入上下文,要求立即运行或说明跳过 `hf-auto-workflow`。

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "powershell.exe -NoProfile -ExecutionPolicy Bypass -File \"C:\\Users\\<you>\\.claude\\skills\\hecateflow\\scripts\\claude-post-tool-use-auto-workflow.ps1\"",
            "timeout": 10
          }
        ]
      }
    ]
  }
}
```

Codex 无标准 hook 机制,`hf-auto-workflow` 靠 skill 正文约定"编辑后立即自审"。

## 跨平台说明 / Cross-platform

- skill 正文用 Claude Code 工具名书写;每个 SKILL.md 末尾"平台差异"段已内联 Codex 等价。Codex 多代理仅在工具可用且用户明确授权时使用 `multi_agent_v1.spawn_agent` 等,否则主会话降级执行。完整映射见 [`skills/hecateflow/references/`](skills/hecateflow/references/)。
- 两端都读 frontmatter `name`+`description`,忽略不认识的字段。
- skill 名加 `hf-` 前缀(入口除外)以避免全局命名冲突。

## 出处 / Provenance

蒸馏自第 21 届全国大学生智能汽车竞赛飞跃雷区组的三核 CYT4BB7 工程(飞控 + 视觉 + 麦轮车)。方法论长文与案例见 [`docs/methodology.md`](docs/methodology.md)。CYT4BB7/IAR 仅作案例,HecateFlow 本身不依赖它们。

## License

MIT © 2026 Hecate ([HecateFake](https://github.com/HecateFake))
