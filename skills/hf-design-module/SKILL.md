---
name: hf-design-module
description: >
  增量设计一个新模块(只读规划,不写源码):先做复用调研(找现成库/抽象),设计对象式接口并定好
  非扁平子目录放置,列出全部切点(源文件登记/构建变体宏/ISR 路由/外设门控/volatile/极性数量级/文档),
  涉执行器/传感器/闭环则标极性数量级检查点,涉独占 IO 外设或硬件驱动则标归属/单一 owner 与分核规划,判定是否先仿真后上板,
  产出模块设计卡 + 实施计划文件交接 hf-implement。触发:设计模块 / 加功能 / 新模块 / 切点 /
  要不要先仿真 / 极性 / IO 归属 / 驱动所有者 / 硬件驱动归属 / 功能方案 / 模块方案 / 先规划 / 接外设前设计 /
  design module / plan feature / incremental design / feature plan / integration plan。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.1.0
  layer: lifecycle
---

# hf-design-module — 增量模块设计(只读规划)/ Incremental Module Design

在动手写代码前,把"要加的模块"想清楚:能不能复用现成的、接口长什么样、放在哪个功能子目录、会触及哪些容易漏的切点、涉不涉及极性/数量级/独占 IO 外设/硬件驱动 owner、要不要先在 PC 仿真。本 skill **只产出设计卡 + 计划文件,不写源码**(适合在 plan mode 跑);落地交 `hf-implement`。

## 适用 / 不适用

- 适用:新增模块/功能、接入新算法或外设、改动会牵涉多个切点的特性。
- 不适用:已有清晰计划直接实现(去 `hf-implement`)、纯 bug 修复。

## 触发关键词

设计模块 / 加功能 / 新模块 / 切点 / 要不要先仿真 / 极性 / IO 归属 / 驱动所有者 / 硬件驱动归属 / design module / plan feature。

## 第一性原则

**先复用,再抽象,最后才新写;接口对象式、放置遵布局、改动范围在写第一行代码前就框定。** 嵌入式新模块的隐性成本不在主逻辑,而在"散落各处必须同步的切点"——漏一处就是链接错误、抢外设、极性失控或文档漂移。设计阶段的价值就是把这些切点提前列全,并把"为复用而设计"的对象式接口与非扁平放置一次定好(对齐 `../references/embedded-c-style.md` 的抽象分层)。

## 红线

- **跳过复用调研直接手写**:重复造轮子,且与已有库行为微妙不一致。优先级严格递减:本仓已有抽象 → 现成外部库 → 才新建。
- **新模块塞进热点文件而非加新文件**:接口应对象式、新增能力优先加新文件/新接口(最小侵入),不在热点 `.c` 塞分支。
- **涉极性/增益却不标检查点**:模块碰执行器/传感器/闭环/增益数量级,设计卡必须标"极性数量级检查点"并引 `hf-hw-mapping`,提示上板辨识 + 闭环核查,不在设计期替用户假定极性。
- **占独占 IO 外设不标归属**:涉 SPI 屏/总线/共享 ADC 的模块,切点必含外设归属门控(白名单 `#if`)+ 分核规划提示。
- **硬件驱动无单一 owner**:同一硬件实例若会被多个模块调用,设计卡必须点名代码级 owner(用对象式实例负责 init/config/static state/update)和其它模块的访问方式(API/接口/注入绑定),不允许多个 `.c` 文件各管一套驱动状态制造竞态。
- **计划文件/设计卡写绝对机器路径**:引用工程文件一律工作区相对路径(`config/configMotor.h`、`control/...`),不写 `<盘符>:\...`。

## 执行流程

1. 锁定 target(读 manifest;高危同名文件先公告 `目标:<target>/<file>(<语义>)`)。
2. **复用调研**(优先级严格递减):① 本仓已有库/抽象(clamp/wrap/PID/低通/数学工具)→ ② 现成外部库 → ③ 才新建。重点找"为复用而设计却被手写绕过"的抽象。结论填进设计卡的复用表。
3. **接口设计(对象式,点 5)**:通用能力封成 `xxxStruct` + `Init`/`Update`/`Reset`,把实例指针作首参(`self`/`this`),多实例隔离状态(如四轮各持一 PID 实例);换硬件用函数指针/init 绑定注入具体驱动(多硬件兼容 API)。若接口背后对应同一物理驱动实例,同时点名**代码级 owner**:谁以对象式实例负责 init/config/static state/update,其它模块只通过 owner API/接口/注入绑定访问,避免竞态和管理混乱。接口契约(单位/量纲/极性/返回语义/owner 边界)写头注释。详见 `../references/embedded-c-style.md` 嵌入式 OOP 段。
4. **放置(非扁平,点 6)**:据 manifest `targets[].layout.subdirs` 决定新模块落哪个功能子目录(控制→`control/`、驱动→`sensor/comm/`、参数→`config/`);引脚从 `config/pinMap.h` 取、参数从 `configHeader` 取,不硬编码。新增子目录须同步构建 include 路径 + LSP `-I`(切点见步 5)。
5. **切点清单**(用 `../hecateflow/templates/module-design.md.tmpl`),逐项列全:
   - 源文件登记(构建系统 + LSP,见 `hf-build-sync`;路径相对)。
   - 构建变体宏(若引入新模式 → 定义/调用/ISR 路由三处守卫对齐)。
   - ISR 路由 / 周期(若挂中断)。
   - **外设/驱动所有权门控**(若占独占 IO 外设或同一硬件驱动实例 → 白名单 `#if` + 分核规划 + 代码级 owner,见步 6)。
   - 共享数据 volatile(若跨 ISR/核)。
   - **极性 / 数量级**(若碰执行器/传感器/闭环/增益 → 见步 7)。
   - 文档同步(PROJECT.md 模块清单 + 边界)。
6. **IO 外设 / 驱动 owner 检查(点 13/24)**:模块若占用单实例 IO 外设——核对 manifest `targets[].ownedPeripherals`:本 target 是否 owner?门控是否白名单 `#if`(非黑名单,防新增模式默认抢占)?**主动提示该外设多核归属与分核规划**(其它核如何让出)。模块若接管同一硬件驱动实例——设计卡必须写明代码级 owner 模块、owner 负责的 `init/config/static state/update`、其它模块访问方式(API/接口/注入绑定),并检查是否已有其它 `.c` 文件维护同一驱动状态而造成竞态。门控机制细节归 `hf-embedded-safety`,本步只在设计期标注切点。
7. **极性 / 数量级检查点(点 11,引 `hf-hw-mapping`)**:模块若碰执行器命令、传感器反馈、闭环控制或增益/步长——设计卡标注:
   - 涉及的方向系数在哪(`headers.polaritySource` 的 §极性段),**新增执行器/传感器须在该段加方向系数宏**(每路一个,占位待辨识),不藏 Kp、不散落 `.c`。
   - 提示"上板开环辨识 ±1 + 闭环须传感器正向=被控量正向(手动转动确认)"。
   - 增益作用于哪个量纲(不跨环照搬)、菜单步长须与范围/钳位同量级。
   - 细节方法论交 `hf-hw-mapping`,本步只把它列为必经检查点 + 生成提醒文案。
8. **先仿真后上板判定**:模块是否含可在 PC 验证的算法/几何/协议?是 → 标注先用仿真工具(manifest `simulation.tools`)验证再上板。
9. **安全预检**:调 `hf-embedded-safety` 视角过一遍(新模块有无并发/数值/外设/极性风险)。
10. 产出设计卡 + 初始化实施计划文件(`../hecateflow/templates/integration-plan.md.tmpl`,路径引用相对),交 `hf-implement`。

## PASS/FAIL 清单

- [ ] 复用调研做过:已确认没有现成库可用才决定新写。
- [ ] 接口是对象式(`xxxStruct`+Init/Update/Reset)、与调用方解耦、多实例隔离。
- [ ] 放置遵 `layout.subdirs`,引脚/参数从 `config/` 取,不硬编码。
- [ ] 切点清单覆盖全部类(源登记/宏/ISR/外设/volatile/极性数量级/文档),无遗漏。
- [ ] 涉极性/增益的已标 `hf-hw-mapping` 检查点 + 上板辨识/闭环核查提示,未替用户假定极性。
- [ ] 涉独占 IO 外设的已标归属门控(白名单 `#if`)+ 分核规划提示。
- [ ] 涉硬件驱动实例的已标代码级 owner + 其它模块访问方式,无多头状态管理/竞态计划。
- [ ] 先仿真判定明确(是/否 + 用哪个工具)。
- [ ] 安全预检过一遍。
- [ ] 设计卡/计划文件引用工程文件用相对路径,无绝对机器路径。
- [ ] 只产出文档,未写源码(只读规划)。

## 验证

- agent 能做:复用调研、对象式接口草案、放置决策、切点清单、极性/IO 检查点标注、计划文件。
- 交用户:确认复用决策与切点完整性;**极性/数量级的物理事实(±1 辨识、闭环轴向、增益整定)留待 `hf-implement`/上板**,再进实施。

## 反面教训

- 跳过复用调研直接手写 → 重复造轮子,且与已有库行为微妙不一致。
- 切点漏列构建变体宏 → 实施时新模式默认不启用或抢外设,排查半天。
- **碰极性却不标检查点** → 实施时把方向翻转随手写进 Kp 负号或某 `.c`,埋下失控隐患。
- **占共享屏/总线不标归属门控** → 实施时两个核同时写,运行期抢占乱码。
- **接硬件驱动不定 owner** → 实施时 A 模块 init、B 模块 set、C 模块保存缓存,配置被覆盖且竞态边界不清,没人知道谁管生命周期。
- 该先仿真的几何/协议直接上板 → 板上调参成本远高于 PC 验证。

## 平台差异

- 只读规划:Claude 可在 plan mode 跑;Codex 无 plan mode,靠自律不写源码。
- AskUserQuestion:Codex 用文字编号选项。

## 参考

- `../hecateflow/templates/module-design.md.tmpl`、`../hecateflow/templates/integration-plan.md.tmpl`。
- `../references/embedded-c-style.md`(抽象分层 / 嵌入式 OOP / 路径纪律)。
- `hf-hw-mapping`(极性/数量级/头组织/IO 归属/代码级驱动 owner 完整方法论,本 skill 把它列为检查点)。
- `hf-build-sync`(源登记/LSP)、`hf-embedded-safety`(安全预检 + 外设门控机制)、`hf-implement`(落地)、`hf-refactor`(复用方法论)。
- manifest 字段:`targets[].layout`/`headers`/`ownedPeripherals[]`(见 `../hecateflow/references/manifest-schema.md`)。
