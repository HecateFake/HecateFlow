---
name: hecateflow
description: >
  HecateFlow 总入口:可复用的嵌入式开发生命周期编排。读/初始化工程清单 .hecateflow/project.json,
  展示生命周期地图并路由到子 skill(工作区初始化/工程初始化/模块设计/实施/审查/重构),注入全局红线。
  MCU/工具链无关。触发:hecateflow / hf / 嵌入式开发流程 / 开始嵌入式工程 / embedded dev workflow /
  start embedded project / 我要做嵌入式。
license: MIT
argument-hint: "[init|design|implement|review|refactor]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: entry
---

# HecateFlow — 嵌入式开发生命周期编排(总入口)

把一套从真实嵌入式工程蒸馏的开发方法论,组织成可交互、可自定义的生命周期 skill。本入口**只做三件事:管 manifest、路由、注入全局红线**,不自己执行业务检查。

## 何时用本入口

用户说"开始嵌入式开发流程""我要做这个 MCU 工程""hecateflow""不知道该用哪个 hf- skill"时,从这里进。已经明确阶段(如"重构这段")可直接调对应子 skill。

## 第一步:工程清单(交互记忆)

1. 找目标工作区根目录的 `.hecateflow/project.json`。
2. **不存在** → 引导跑 `hf-init-workspace` 创建(先别做业务)。
3. **存在** → 读入,作为后续所有 skill 的默认值来源(MCU 家族/工具链/构建系统/targets/语言/激活检查项)。
   schema 见 `references/manifest-schema.md`。

## 第二步:路由(生命周期地图)

| 用户意图 / 关键词 | 路由到 |
|------------------|--------|
| 初始化工作区、新工程脚手架、第一次用 | `hf-init-workspace` |
| 登记一个核/芯片/固件、加 target、建 PROJECT.md | `hf-init-project` |
| 设计新模块、加功能、要不要先仿真、切点有哪些 | `hf-design-module`(只读规划) |
| 写代码、实现、进 build、执行计划 | `hf-implement` |
| 提交前审查、深度 review | `hf-review` |
| 重构、去重、精简、复用已有库(不改行为) | `hf-refactor` |
| 查 ISR/数值/外设安全 | `hf-embedded-safety` |
| 新文件登记、undefined reference、clangd 报错 | `hf-build-sync` |
| 文档同步、PROJECT.md、版本登记 | `hf-doc-discipline` |
| 每次编辑后的自动审查 | `hf-auto-workflow` |

典型生命周期:`hf-init-workspace`(一次)→ `hf-init-project`(每 target 一次)→ `hf-design-module`(只读出计划)→ `hf-implement`(执行,内部串 build-sync/doc-discipline/auto-workflow)→ `hf-review`(收尾)。`hf-refactor` 与知识层可在任意阶段按需唤起。

## 第三步:注入全局红线(所有子 skill 公共前置)

路由前确认这些 always-on 约束已就位:

1. **目标 target 识别**:编辑任何源文件前先确认改的是哪个核/芯片/构建。判定顺序:用户指定 → 路径匹配 manifest `targets[].buildTarget` → 关键词命中职责 → **都无法判断则必须问用户,绝不默认猜**。编辑高危同名文件(manifest `hazardFiles`)前公告 `目标:<target>/<file>(<语义>)`。
2. **AskUserQuestion schema**:`questions` 为数组,每项含 `question`/`header`/`options`(2–4 个 `{label,description}`);校验失败最多重试一次,再失败改纯文字询问。Codex 无此工具 → 用文字编号选项。
3. **Git 纪律**:提交格式见 manifest `git.commitFormat`;只显式 add 本次编辑文件,**禁止 `git add .`**;工作区里非本次任务产生的改动默认视为用户有意为之,原样保留不擅自回退。
4. **交互自定义**:每个 skill 读 manifest 做默认值,只问缺失项,用完写回(读-改-写 + 校验)。

## 路由门(任一不满足先补)

- [ ] manifest 存在(否则先 `hf-init-workspace`)。
- [ ] 目标 target 可判定(否则 AskUserQuestion)。

## 平台差异

- 调用子 skill:Claude Code 用 `Skill` 工具;Codex 原生加载、按其指令执行。
- 工具名映射见 `references/claude-code-tools.md` / `references/codex-tools.md`。Codex 安装时关键映射已内联进各 SKILL.md 末尾"平台差异"段。

## 参考

- `references/manifest-schema.md`、`references/{claude-code,codex}-tools.md`。
- 子 skill:`hf-init-workspace`/`hf-init-project`/`hf-design-module`/`hf-implement`/`hf-review`/`hf-refactor`/`hf-auto-workflow`/`hf-embedded-safety`/`hf-build-sync`/`hf-doc-discipline`。
