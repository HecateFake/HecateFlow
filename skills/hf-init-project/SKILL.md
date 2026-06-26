---
name: hf-init-project
description: >
  为工作区里的一个 target(核/芯片/固件)做初始化:确定职责、独占外设所有权、跨 target 同名高危文件,
  生成该 target 的 PROJECT.md(状态卡/模块清单/边界/参数/ISR 表/验证清单),并追加到工程清单 targets[]。
  每个 target 一次。触发:初始化工程 / 登记核 / 加 target / 新建 PROJECT.md / init project /
  register target / scaffold core。
license: MIT
argument-hint: "[target-id]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-init-project — Target 初始化 / Per-Target Init

为单个可独立构建的 target(一个核、一个芯片、一份固件)建立它的真相源 PROJECT.md,并登记进 manifest `targets[]`。`hf-init-workspace` 之后,每个 target 跑一次。

## 适用 / 不适用

- 适用:新增一个 target/核;为已有但未登记的 target 补 PROJECT.md + manifest 项。
- 不适用:在已登记 target 内加模块(那是 `hf-design-module`/`hf-implement`)。

## 触发关键词

初始化工程 / 登记核 / 加 target / 新建 PROJECT.md / init project / register target。

## 第一性原则

**每个 target 是独立的认知单元。** 一个无上下文的 agent 应能只读该 target 的 PROJECT.md 就在其内独立工作。所以初始化时必须明确:它是谁(职责)、它独占什么(外设所有权)、它有哪些与别的 target 同名却不同义的高危文件。

## 执行流程

1. 读 manifest 的 `workspace`/`buildSystem` 做默认(MCU/工具链/语言继承)。
2. AskUserQuestion 收集该 target 特有信息(只问缺失):
   - target id / 职责描述。
   - 是否多核 MCU(subCores)。
   - **独占外设**:占用哪些单实例外设(SPI 屏/总线/DAC),owner 是哪个子核,门控方式(白名单 #if)。
   - **高危同名文件**:与其它 target 同名但语义不同的文件(motor.c/IMU.c/PID.c 类),列出"本 target 含义"。
   - 对应 buildTarget(.ewp/cmake target 名)。
3. 用 `templates/PROJECT.md.tmpl` 生成该 target 的 PROJECT.md(填状态卡/身份/模块清单骨架/高危文件/边界/ISR/参数/验证清单)。
4. 追加 manifest `targets[]` 一项(读-改-写,只改这一项,降低多 agent 写竞争)。
5. **外设冲突检查**:新 target 的独占外设 owner 不得与已登记 target 冲突(同一物理外设两个 owner = 抢占风险)。

## PASS/FAIL 清单

- [ ] PROJECT.md 六段齐全(状态卡/身份/模块清单/高危文件/边界/验证清单)。
- [ ] 高危同名文件已列"本 target 含义"。
- [ ] 独占外设 owner 与已登记 target 无冲突。
- [ ] manifest `targets[]` 仅追加本项,未动其它项。
- [ ] `docPath`/`buildTarget` 与实际路径一致。

## 验证

- agent 能做:生成 PROJECT.md、追加 manifest、查外设冲突。
- 交用户:确认职责与外设所有权(关系到后续安全门控)。

## 反面教训

- 不列高危同名文件 → 后续 agent 跨 target 误用同名文件的错误语义。
- 两个 target 都声明占同一块 SPI 屏却没指明 owner/门控 → 运行期抢屏乱码。
- 写 manifest 时整体覆盖 targets[] → 抹掉其他 agent 并行登记的 target。

## 平台差异

- AskUserQuestion:Claude 原生;Codex 文字编号选项。

## 参考

- `templates/PROJECT.md.tmpl`、`hf-doc-discipline`(PROJECT.md 维护)、`hf-embedded-safety`(外设所有权门控)、`hf-init-workspace`。
