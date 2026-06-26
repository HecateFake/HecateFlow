---
name: hf-design-module
description: >
  增量设计一个新模块(只读规划,不写源码):先做复用调研(找现成库/抽象),设计对象式接口,
  列出全部切点(源文件登记/构建变体宏/ISR 路由/外设门控/volatile/文档),判定是否先仿真后上板,
  产出模块设计卡 + 实施计划文件交接 hf-implement。触发:设计模块 / 加功能 / 新模块 / 切点 /
  要不要先仿真 / design module / plan feature / incremental design。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-design-module — 增量模块设计(只读规划)/ Incremental Module Design

在动手写代码前,把"要加的模块"想清楚:能不能复用现成的、接口长什么样、会触及哪些容易漏的切点、要不要先在 PC 仿真。本 skill **只产出设计卡 + 计划文件,不写源码**(适合在 plan mode 跑);落地交 `hf-implement`。

## 适用 / 不适用

- 适用:新增模块/功能、接入新算法或外设、改动会牵涉多个切点的特性。
- 不适用:已有清晰计划直接实现(去 `hf-implement`)、纯 bug 修复。

## 触发关键词

设计模块 / 加功能 / 新模块 / 切点 / 要不要先仿真 / design module / plan feature。

## 第一性原则

**先复用,再抽象,最后才新写;改动的范围在写第一行代码前就要框定。** 嵌入式新模块的隐性成本不在主逻辑,而在"散落各处必须同步的切点"——漏一处就是链接错误、抢外设或文档漂移。设计阶段的价值就是把这些切点提前列全。

## 执行流程

1. 锁定 target(读 manifest;高危同名文件先公告)。
2. **复用调研**(优先级严格递减):① 本仓已有库/抽象(clamp/wrap/PID/低通/数学工具)→ ② 现成外部库 → ③ 才新建。重点找"为复用而设计却被手写绕过"的抽象。结论填进设计卡的复用表。
3. **接口设计**:对象式 `xxxStruct` + `Init`/`Update`/`Reset`,与调用方解耦。
4. **切点清单**(用 `templates/module-design.md.tmpl`),逐项列全:
   - 源文件登记(构建系统 + LSP,见 `hf-build-sync`)。
   - 构建变体宏(若引入新模式 → 见各处 `#if` 触点)。
   - ISR 路由 / 周期(若挂中断)。
   - 外设所有权门控(若占独占外设,白名单 #if)。
   - 共享数据 volatile(若跨 ISR/核)。
   - 文档同步(PROJECT.md 模块清单 + 边界)。
5. **先仿真后上板判定**:模块是否含可在 PC 验证的算法/几何/协议?是 → 标注先用仿真工具(manifest `simulation.tools`)验证再上板。
6. **安全预检**:调 `hf-embedded-safety` 视角过一遍(新模块有无并发/数值/外设风险)。
7. 产出设计卡 + 初始化实施计划文件(`templates/integration-plan.md.tmpl`),交 `hf-implement`。

## PASS/FAIL 清单

- [ ] 复用调研做过:已确认没有现成库可用才决定新写。
- [ ] 接口是对象式、与调用方解耦。
- [ ] 切点清单覆盖全部 6 类(源登记/宏/ISR/外设/volatile/文档),无遗漏。
- [ ] 先仿真判定明确(是/否 + 用哪个工具)。
- [ ] 安全预检过一遍。
- [ ] 只产出文档,未写源码(只读规划)。

## 验证

- agent 能做:复用调研、接口草案、切点清单、计划文件。
- 交用户:确认复用决策与切点完整性,再进 `hf-implement`。

## 反面教训

- 跳过复用调研直接手写 → 重复造轮子,且与已有库行为微妙不一致。
- 切点漏列构建变体宏 → 实施时新模式默认不启用或抢外设,排查半天。
- 该先仿真的几何/协议直接上板 → 板上调参成本远高于 PC 验证。

## 平台差异

- 只读规划:Claude 可在 plan mode 跑;Codex 无 plan mode,靠自律不写源码。
- AskUserQuestion:Codex 用文字编号选项。

## 参考

- `templates/module-design.md.tmpl`、`templates/integration-plan.md.tmpl`、`hf-build-sync`、`hf-embedded-safety`、`hf-implement`、`hf-refactor`(复用方法论)。
