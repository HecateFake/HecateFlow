---
name: hf-init-project
description: >
  为工作区里的一个 target(核/芯片/固件)做初始化:确定职责、脚手架非扁平功能子目录布局,
  生成硬件映射头 pinMap.h + 参数调节头 configXxx.h(含 §极性方向系数表),登记独占 IO 外设所有权
  并做跨 target 冲突检查 + 主动提示分核任务规划,标记代码级驱动 owner 与同名高危文件,生成 PROJECT.md 并追加到 targets[]。
  每个 target 一次。触发:初始化工程 / 登记核 / 加 target / 新建 PROJECT.md / 非扁平布局 / pinMap /
  外设归属 / 分核规划 / 驱动所有者 / 硬件驱动归属 / 新增固件 / 新增芯片 / 新增 core / 生成 config 头 / 生成引脚表 /
  init project / register target / scaffold core / add firmware target / create PROJECT.md。
license: MIT
argument-hint: "[target-id]"
metadata:
  compatibility: claude-code codex
  version: 1.1.0
  layer: lifecycle
---

# hf-init-project — Target 初始化 / Per-Target Init

为单个可独立构建的 target(一个核、一个芯片、一份固件)建立它的真相源 PROJECT.md + 物理脚手架(非扁平布局 + 硬件映射头 + 参数头 + 极性表 + 外设归属 + 驱动 owner),并登记进 manifest `targets[]`。`hf-init-workspace` 之后,每个 target 跑一次。本次(v1.1)在原"职责+外设+高危文件+PROJECT.md"上,新增**脚手架与硬件契约奠基**:非扁平布局(点 6)、pinMap/config 头(点 6)、极性表入硬件映射头(点 11)、IO 外设归属冲突检查 + 分核规划提示(点 13)。

## 适用 / 不适用

- 适用:新增一个 target/核;为已有但未登记的 target 补 PROJECT.md + manifest 项 + 头脚手架。
- 不适用:在已登记 target 内加模块(那是 `hf-design-module`/`hf-implement`)。

## 触发关键词

初始化工程 / 登记核 / 加 target / 新建 PROJECT.md / 非扁平布局 / pinMap / 外设归属 / 分核规划 / 驱动所有者 / 硬件驱动归属 / init project / register target。

## 第一性原则

**每个 target 是独立的认知单元,且它的"硬件契约"必须在第一天就被抽离集中。** 一个无上下文的 agent 应能只读该 target 的 PROJECT.md 就在其内独立工作;而引脚、极性、量纲、代码级驱动 owner 这类"硬件契约"若不在初始化时就抽进集中头/清单,后续每个模块都会就地硬编码或多头管理同一驱动状态,换接线/换车体/换驱动即全工程翻找,还会引入竞态、生命周期混乱,并可能在大电流执行器上酿成物理事故。所以初始化时必须同时明确:它是谁、它怎么摆、硬件契约在哪、外设归谁、驱动 owner 谁管、哪些文件高危,以及本 target 内多 agent 协作如何遵守 `../hecateflow/references/orchestration-contract.md`:先自主求证、主动只读复审、最小提问、Git 确认门。

## 红线

- **极性写进 PID Kp 负号或散落各 `.c`**:极性方向系数必须初始化在 `configHeader` 的 **§极性段**(`headers.polaritySource`),`*_DIR` 每路通道一个,Kp 全正号。藏 Kp 是头号杀手(误改一符号即正反馈跑飞,见 `hf-hw-mapping` / `hf-embedded-safety`)。
- **引脚硬编码不进 pinMap**:引脚必须在零依赖纯 `#define` 的 `pinMap.h` 唯一定义,不散落驱动 `.c`。
- **极性表照抄旧值当固定常量**:`*_DIR` 的 ±1 是**本台硬件开环实测辨识**结果,脚手架只生成占位 `+1`,**必须提示用户上板辨识**,不替用户假定。
- **两个 target 占同一 IO 外设不指 owner/门控**:运行期抢占(屏乱码/总线冲突)。新 target 的独占外设 owner 必须与已登记 target 无冲突,且**带 IO 的外设须主动提示分核任务规划**。
- **硬件驱动 owner 不落 PROJECT.md**:同一驱动实例后续会被多个模块各自管理状态,init/set/update 生命周期混乱并产生竞态。初始化时至少在 PROJECT.md 留出"代码级驱动 owner"清单。
- **整体覆盖 targets[]**:写 manifest 时只追加本项,绝不整体覆盖(抹掉其他 agent 并行登记的 target)。

## 执行流程

1. 读 manifest 的 `workspace`/`buildSystem`/`scenario` 做默认(MCU/工具链/语言/场景约束继承)。
2. AskUserQuestion 收集该 target 特有信息(只问缺失):
   - target id / 职责描述 / 是否多核 MCU(subCores)。
   - **布局风格**(点 6):`feature-subdirs`(按功能分子目录,推荐)还是 `flat`;子目录集(默认 `app/control/sensor/comm/config/util`,按 domain 调整)。
   - **独占 IO 外设**(点 13):占用哪些单实例外设(SPI 屏/总线/共享 ADC/调试 UART),owner 是哪个子核,是否带 IO,门控方式(白名单 `#if`)。
   - **代码级驱动 owner**(点 24):本 target 内哪些硬件驱动实例需要单一 owner(如 display/IMU/motor/ADC/bus),owner 模块是谁,如何按对象式方式持有实例状态,其它模块如何访问(API/接口/注入绑定)。
   - **高危同名文件**:与其它 target 同名但语义不同的文件(motor.c/IMU.c/PID.c 类),列"本 target 含义"。
   - 对应 buildTarget(.ewp/cmake target 名)。
3. **脚手架非扁平布局(点 6)**:按 `layout.subdirs` 建功能子目录骨架(`config/` 必建,放两类集中头);新增子目录须同步构建系统 include 搜索路径 + LSP `-I`(委派 `hf-build-sync`,`workspace.lsp.clangd=false` 时跳过 LSP)。
4. **生成硬件映射头 + 参数调节头(点 6 & 11)**:
   - 用 `../hecateflow/templates/pinMap.h.tmpl` 生成 `config/pinMap.h`(零依赖纯 `#define`,按功能 `/* ===== 块 ===== */` 分组,命名 `{功能}_{通道}_{类型}`)。
   - 用 `../hecateflow/templates/config-header.h.tmpl` 生成 `config/configXxx.h`(分节 §A 时序/模式、§B/C/D 各环 PID 多实例独立增益、§E 几何+限幅+滤波、**§极性**、§F 故障/通信),头注写量纲约定。
   - **初始化极性表入硬件映射(点 11)**:在 configHeader §极性段为每路执行器/传感器通道生成方向系数宏(`*_OUTPUT_DIR`/`ENCODER_*_DIR`/`CURRENT_SENSE_*_DIR`/轴映射符号),占位 `+1`,并注释"开环实测辨识、换硬件重辨识、改前核实接线"。登记 `headers.polaritySource` = 该 configHeader 的 §极性段。**提示用户:这些 ±1 须上板辨识**(细节交 `hf-hw-mapping`,本 skill 只奠基占位)。
5. **生成 PROJECT.md**:用 `../hecateflow/templates/PROJECT.md.tmpl` 填状态卡/身份/模块清单骨架/代码级驱动 owner 清单/高危文件/引脚总览(指向 `config/pinMap.h` + `docs/PINOUT`)/协作边界/边界/ISR/参数/验证清单。
6. **登记 manifest `targets[]`**(读-改-写,只追加本项):`layout{style,subdirs}`、`headers{pinMap,configHeaders,polaritySource}`、`ownedPeripherals[]`、`hazardFiles`、`docPath`、`buildTarget`。
7. **IO 外设冲突检查 + 分核规划提示(点 13)**:
   - 扫已登记 targets 的 `ownedPeripherals`,新 target 的独占外设 `device` 不得与他者 owner 冲突(同一物理外设两个 owner = 抢占风险)。
   - 对 `io:true` 的外设**主动提醒该外设的多核归属权,促用户做分核任务规划**:哪个核/上下文拥有、其它核如何让出(白名单 `#if` 门控)、冲突如何仲裁,填入 `planNote`。门控机制细节交 `hf-embedded-safety`,本 skill 负责登记 + 提示。

## PASS/FAIL 清单

- [ ] PROJECT.md 六段齐全(状态卡/身份/模块清单/高危文件/边界/验证清单)。
- [ ] 非扁平布局已脚手架(`config/` 等子目录建成);新目录已同步构建 include 路径(+ LSP `-I` 若用 clangd)。
- [ ] 生成了 `config/pinMap.h`(零依赖纯 `#define`)+ `config/configXxx.h`(分节 + §极性段)。
- [ ] §极性段为每路通道生成了方向系数宏(占位 +1),注释"须开环辨识/换硬件重辨识/改前核实接线";`headers.polaritySource` 已登记;已提示用户上板辨识。
- [ ] 高危同名文件已列"本 target 含义"。
- [ ] PROJECT.md 已留出代码级驱动 owner 清单(硬件实例 / owner 模块 / 对象式实例 / 访问方式),避免后续多头状态管理和竞态。
- [ ] PROJECT.md 已写 target 内协作边界:先自主求证、主动只读复审、活跃任务记录、worker 范围互斥、Git 确认门。
- [ ] 独占 IO 外设 owner 与已登记 target 无冲突;`io:true` 外设已 `planNote` 且**已提示分核任务规划**。
- [ ] manifest `targets[]` 仅追加本项,未动其它项;路径全相对。
- [ ] `docPath`/`buildTarget`/`headers.*` 与实际路径一致。

## 验证

- agent 能做:脚手架布局、生成头/PROJECT.md、追加 manifest、查外设冲突、生成极性占位表与提醒、为 PROJECT.md 建代码级驱动 owner 清单骨架。
- 交用户:确认职责与 IO 外设所有权(关系到安全门控);**§极性段每个 `*_DIR` 的 ±1 须上板开环辨识**(agent 无法验证物理方向,见 `hf-hw-mapping`)。

## 反面教训

- 不列高危同名文件 → 后续 agent 跨 target 误用同名文件的错误语义。
- 两个 target 都声明占同一块 SPI 屏却没指明 owner/门控 → 运行期抢屏乱码。
- **极性表脚手架完就当真值**:占位 `+1` 未提示辨识,用户照用 → 接线一反即闭环失控。极性占位必须配"须辨识"提示。
- **引脚没建集中头,直接让各驱动 `.c` 硬编码** → 换接线全工程翻找,漏改一处行为诡异。
- 写 manifest 时整体覆盖 targets[] → 抹掉其他 agent 并行登记的 target。
- `io:true` 外设登记了 owner 却不提分核规划 → 其它核 agent 不知道要让出,新增模式默认抢占。
- PROJECT.md 没有驱动 owner 清单 → 后续模块各自管屏/总线/传感器状态,竞态边界、初始化和配置责任失去唯一答案。

## 平台差异

- AskUserQuestion:Claude 原生;Codex 文字编号选项。
- 脚手架写文件:两端用各自 Write/Edit;新目录的构建/LSP 同步委派 `hf-build-sync`。

## 参考

- `../hecateflow/templates/PROJECT.md.tmpl`、`../hecateflow/templates/pinMap.h.tmpl`、`../hecateflow/templates/config-header.h.tmpl`。
- `hf-hw-mapping`(头组织/极性单一真相源/数量级/IO 归属的完整方法论;本 skill 只做初始化奠基)。
- `hf-embedded-safety`(IO 外设门控机制 + 失控保护)、`hf-build-sync`(新子目录的构建/LSP 同步)。
- `hf-doc-discipline`(PROJECT.md 维护)、`hf-init-workspace`(上游;`workspace.lsp`/`scenario`/`layout` 默认来源)。
- `../hecateflow/references/orchestration-contract.md`(target 内协作边界 / worker 门 / Git 确认门)。
- manifest 字段:`targets[].layout`/`headers`/`ownedPeripherals[]`(见 `../hecateflow/references/manifest-schema.md`)。
