---
name: hecateflow
description: >
  HecateFlow 总入口:可复用的嵌入式开发生命周期编排。读/初始化工程清单 .hecateflow/project.json,
  展示生命周期地图并路由到子 skill(工作区初始化/工程初始化/模块设计/实施/审查/重构),注入全局红线。
  MCU/工具链无关。触发:hecateflow / hf / 嵌入式开发流程 / 开始嵌入式工程 / embedded dev workflow /
  start embedded project / 我要做嵌入式 / 接入 HecateFlow / 用 HecateFlow 管这个工程 /
  embedded project setup / embedded workflow router / which hf skill / 多模型编排 / 子代理 / Git 确认门 /
  不可能出现 / SDK 也可能错 / 事实二次确认。
license: MIT
argument-hint: "[init|design|implement|review|refactor]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: entry
---

# HecateFlow — 嵌入式开发生命周期编排(总入口)

把一套从真实嵌入式工程蒸馏的开发方法论,组织成可交互、可自定义的生命周期 skill。本入口**只做三件事:管 manifest、路由、注入全局红线**,不自己执行业务检查。多模型/子代理使用统一遵守 `references/orchestration-contract.md`:先自主求证,主 agent 持权,主动派发只读子代理,复审链闭合,实施 worker 后置,Git 永不下放。

## 何时用本入口

用户说"开始嵌入式开发流程""我要做这个 MCU 工程""hecateflow""不知道该用哪个 hf- skill"时,从这里进。已经明确阶段(如"重构这段")可直接调对应子 skill。

## Quick Path(入口必须输出)

每次从本入口路由时,先给出这 5 行,再进入子 skill:

```text
HecateFlow Route:
- manifest: found|missing
- target: <id|unknown>
- scenario: known|missing
- next skill: <hf-*>
- reason: <one sentence>
```

若 `manifest: missing`,只引导 `hf-init-workspace`,不做业务设计/实现。若 `target: unknown` 且用户要编辑代码,先问目标 target,不猜。

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
| 提交前审查、深度 review、场景合规、多模型复审 | `hf-review` |
| 重构、去重、精简、复用已有库(不改行为) | `hf-refactor` |
| 查 ISR/数值/外设安全 | `hf-embedded-safety` |
| 引脚/硬件映射头、参数头、**极性/方向系数**、数量级/增益/步长、IO 归属、驱动 owner | `hf-hw-mapping` |
| 新文件登记、undefined reference、clangd 报错 | `hf-build-sync` |
| 文档同步、PROJECT.md、版本登记、分级文档 | `hf-doc-discipline` |
| **经验记录/踩坑/教训/不再犯**、复盘、被纠正、好做法沉淀 | `hf-lessons` |
| 每次编辑后的自动审查 | `hf-auto-workflow` |

典型生命周期:`hf-init-workspace`(一次)→ `hf-init-project`(每 target 一次)→ `hf-design-module`(只读出计划)→ `hf-implement`(执行,内部串 build-sync/doc-discipline/auto-workflow)→ `hf-review`(收尾)。`hf-refactor` 与知识层(`hf-embedded-safety`/`hf-hw-mapping`/`hf-build-sync`/`hf-doc-discipline`/`hf-lessons`)可在任意阶段按需唤起。共 **13 个 skill**(本入口 + 12 个 `hf-`)。

## 第三步:注入全局红线(所有子 skill 公共前置)

路由前确认这些 always-on 约束已就位:

1. **目标 target 识别(多工程路由,点 2)**:编辑任何源文件前先确认改的是哪个核/芯片/构建。判定顺序:用户指定 → 路径匹配 manifest `targets[].buildTarget` → **关键词命中纲领"关键词→target 映射表"** → **都无法判断则必须问用户,绝不默认猜**。编辑高危同名文件(manifest `hazardFiles`,如 `motor.c`/`IMU.c`/`PID.c` 跨 target 语义不同)前公告 `目标:<target>/<file>(<语义>)`;`_legacy/` 归档代码仅供参考、不复用、默认不编辑。
2. **场景约束(点 1)**:读 manifest `workspace.scenario`,把 `constraints`/`safetyRules`/`forbidden` 当**常驻硬约束**贯穿全程(如禁某类通信、禁某外设、安全合规);任何设计/实现/审查不得违反 `forbidden`/`safetyRules`(违反即 CRITICAL,见 `hf-review`)。
3. **事实来源可错(点 25)**:用户描述、SDK/厂商实现、既有注释、历史代码、agent 先验都只是证据来源,不是绝对事实。Bug 排查中若出现"这不可能出现""SDK 不会这样""用户已确认就是 X"这类断言,必须先二次确认:请用户复述复现条件/观测证据,agent 亲自读代码/SDK/日志/寄存器路径;矛盾处标为"未证实假设",不得直接当事实落修复。
4. **AskUserQuestion schema**:`questions` 为数组,每项含 `question`/`header`/`options`(2–4 个 `{label,description}`);校验失败最多重试一次,再失败改纯文字询问。Codex 无此工具 → 用文字编号选项。
5. **自主性优先多模型编排(点 26)**:所有子 skill 继承 `references/orchestration-contract.md`。先自主求证,能从代码/manifest/docs/diff/命令发现的事实不问用户;L1+ 自动主动派发只读子代理查证据;L2/L3 高风险必须复审子代理查证据/矛盾/过度推断后,主 agent 亲验再裁决;派发前清理完成代理、分批派发并防止占满并发上限;写入 worker 仅在用户已明确要求实现/修改/落地/应用补丁、方案完整、文件范围互斥且边界清楚后使用,且不得提交/推送。
6. **Git 纪律 + 确认门**:提交格式见 manifest `git.commitFormat`;只显式 add 本次编辑文件,**禁止 `git add .`**;禁止自动提交/自动推送。完成实现和验证后只报告摘要、验证结果、建议提交说明和待暂存文件;等待用户明确确认后才进入 Git 写流程。细则见 `../references/git-discipline.md` 与 `references/orchestration-contract.md`。
7. **相对路径(点 12,横切)**:目标工程的构建配置(`$PROJ_DIR$\..`)/include/LSP `-I`/脚本一律**优先相对路径**,绝对机器路径(`<盘符>:\...`)入库换机即坏(`paths.preferRelative`)。
8. **文件分割与三层封装(点 27)**:复杂功能按硬件底层 / 硬件顶层 / 软件实现分开;自写业务 `.c/.h` 超过 650 行先评估分文件,超过 1000 行默认拆分或封装管理。vendor/generated/table 或用户明确确认的特殊长文件可例外但须记录理由;小于 650 行但高频复用的模块可提前封为公共库/公共头。
9. **通信/共享快照/参数持久化安全(点 28/30)**:半双工/共享总线优先唯一 master + request-response + timeout + valid frame;通信 ISR 只收字节/入缓冲并由前台限额解析;跨核/跨 ISR 快照用 `magic`/`seq`/freshness gate,失链不消费旧命令;参数持久化用 `magic/version/payloadBytes/CRC`,先 load defaults,CRC/magic 错不自动覆盖,flash 写入不进热路径。
10. **极性/IO/驱动 owner 主动确认(点 11/13/24)**:触及执行器/传感器/闭环极性、增益数量级、单实例 IO 外设归属或同一硬件驱动代码级 owner 时,**主动提醒用户并请确认物理事实/分核规划/owner 边界,不自行假定极性或多头管理驱动**(细节 `hf-hw-mapping`)。
11. **经验不再犯(点 7)**:相关编辑前先检索 `.hecateflow/lessons/INDEX.md` 命中规避;踩坑/被纠正后记 lesson(`hf-lessons`)。
12. **交互自定义**:每个 skill 读 manifest 做默认值,只问缺失项,用完写回(读-改-写 + 校验,各 agent 只改自己的 `targets[]` 项降低写竞争)。

## 路由门(任一不满足先补)

- [ ] manifest 存在(否则先 `hf-init-workspace`)。
- [ ] 目标 target 可判定(否则 AskUserQuestion)。
- [ ] 场景约束 `workspace.scenario` 已知(为空则 `hf-init-workspace` 采集;不阻塞但提醒)。

## 平台差异

- 调用子 skill:Claude Code 用 `Skill` 工具;Codex 原生加载、按其指令执行。
- 工具名映射见 `references/claude-code-tools.md` / `references/codex-tools.md`。Codex 安装时关键映射已内联进各 SKILL.md 末尾"平台差异"段。

## 参考

- `references/manifest-schema.md`、`references/{claude-code,codex}-tools.md`、`references/auto-injection.md`、`references/orchestration-contract.md`。
- 横切基线:`../references/git-discipline.md`、`../references/tiered-docs.md`、`../references/embedded-c-style.md`。
- 子 skill(12 个):`hf-init-workspace`/`hf-init-project`/`hf-design-module`/`hf-implement`/`hf-review`/`hf-refactor`/`hf-auto-workflow`/`hf-embedded-safety`/`hf-hw-mapping`/`hf-build-sync`/`hf-doc-discipline`/`hf-lessons`。
