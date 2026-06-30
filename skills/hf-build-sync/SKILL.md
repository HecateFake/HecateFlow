---
name: hf-build-sync
description: >
  新增源文件后,把它登记进不自动发现文件的构建系统(IAR .ewp、Keil .uvprojx、显式列源的
  CMake/Make)与 LSP(clangd -I / compile_commands;先从 manifest/compile_commands/.vscode/build config 自主发现是否使用 clangd)。漏登 → 链接期
  undefined reference 或编辑器虚假红线。构建/LSP 路径优先相对($PROJ_DIR$\.. 类),禁绝对机器路径。
  MCU/工具链无关。构建图/LSP/多 target 同步属于高误判成本改动时,按自主性优先编排契约做主动只读复核。
  触发:新增文件 / 加文件到工程 / undefined reference / 链接期未定义 /
  clangd 报错找不到头 / inline 重复定义 / 构建同步 / 相对路径 / IAR 加文件 / Keil 加文件 /
  CMake target_sources / 头文件找不到 / 没编进去 / build sync / register source file / add file to project。
license: MIT
argument-hint: "[buildTarget]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-build-sync — 构建系统与 LSP 文件登记 / Build & LSP Registration

很多嵌入式构建系统(IAR、Keil、显式列源的 CMake/Make)**不会自动发现**新源文件。只把 `.c/.h` 放进目录而不登记,会导致:调用新函数链接期 `undefined reference`;或根本没编译(调用点也没编),运行时功能静默缺失;或编辑器 clangd 找不到头文件报虚假红线。本 skill 在新增文件后立即补齐登记。构建图/LSP 同步一旦跨 target、跨模式或牵涉链接脚本,按 `../hecateflow/references/orchestration-contract.md` 做 L1-L3 分档:只读复核工程文件路径、include 路径、宏守卫和目标归属后再写;构建图/LSP/文档矩阵同时变化按 L3 闭合复审链。

## 适用 / 不适用

- 适用:新建 `.c/.h`、迁入源文件、新增源码目录、`undefined reference`/clangd 红线排查。
- 不适用:改现有文件内容、改 SDK/第三方库、`buildSystem.autoDiscover=true` 且无需 reconfigure 的工程(此时只提醒可能要 reconfigure)。

## 触发关键词

新增文件 / 加进工程 / undefined reference / 链接期未定义 / clangd 找不到头 / 构建同步 / register source。

## Quick Path(登记判定树)

1. `buildSystem.autoDiscover=true` → 不改工程文件;若 CMake `file(GLOB)` 提醒 reconfigure / `CONFIGURE_DEPENDS`。
2. `autoDiscover=false` 且新增 `.c` → 必须登记到链接单元(`.ewp` / `.uvprojx` / `target_sources` / `SRCS`)。
3. 新增 `.h` 或新目录 → 必须登记 include 搜索路径;IAR/Keil 工程树也列头文件以便审阅。
4. `workspace.lsp.clangd=true` → 构建 include 与 LSP `-I` / `compile_commands.json` 成对同步。
5. 所有工程/LSP 路径必须相对;发现绝对路径即 HIGH。

输出:

```text
HecateFlow Build Sync:
- build system:
- autoDiscover:
- source registration:
- include paths:
- clangd:
- relative paths:
- user rebuild step:
```

## 第一性原则

**"文件在磁盘上"不等于"文件在构建图里"。** 构建系统的真相源是工程文件/CMakeLists,不是目录。新增源文件是一个**双写动作**:写文件 + 登记到构建图(+ LSP 索引图)。两者必须同一次完成,不得推迟到"功能写完再说"。

**路径优先相对(点 12)。** 工程文件、include 搜索路径、LSP `-I`、`compile_commands.json` 一律用**相对/工程锚定路径**(IAR `$PROJ_DIR$\..`、CMake `${CMAKE_SOURCE_DIR}`/相对 `src/`),**禁绝对机器路径**(`D:\...`、`/home/...`)。绝对路径换机/换人即断,跨机不可移植。

## 红线

- 新增 `.c` 没进链接单元 → 链接期 `undefined reference`(或更隐蔽:调用点也没编,无报错但功能缺失)。
- 新增 `.h` 所在**目录**没进 include 搜索路径 → 编译/索引找不到头。
- 跨 target 复制工程文件节点 → 同名文件跨核语义可能不同,引入错误依赖。
- **头里裸 `inline` 函数** 被多编译单元 include → "重复定义"或"无外部定义"链接错误。改 `.c` 显式链接或 `static inline`,**不靠手工展开规避**(详见 `../references/embedded-c-style.md`)。
- **工程/LSP 写绝对机器路径** → 跨机/跨人即断,工程不可移植。
- **多层模式宏守卫不对齐**:函数定义守卫与调用守卫(如 `BUILD_MODE` + `TUNE_MODE` 两层)若三处不一致,某构建分支会"编译却无定义"→ 链接错误。新增/切模式时定义/调用守卫必须同步对齐。

## 执行流程

1. 读 manifest `buildSystem`:`type` / `autoDiscover` / `registration.{projectFile,sourceNode,includePathField,lspConfig}`;并先从 `workspace.lsp.clangd`、`compile_commands.json`、`.clangd`、`.vscode/c_cpp_properties.json`、CMake/Make/IAR/Keil 工程配置里**自主发现**是否使用 clangd。`clangd:false` 或证据显示未用 → 只同步构建工程文件,跳过所有 `-I`/`.clangd` 步骤(无虚假红线困扰);`clangd:true` 或仓库内已有 clangd 配置 → 构建文件与 LSP 配置**成对同步**(见步 3 + `references/build-systems.md` clangd 六条)。只有仓库外 IDE 状态不可证、且会改变同步风险边界时,才最小提问。
2. `autoDiscover=true` → 一般免登记;若是 CMake `file(GLOB)`,提醒需重新 configure(或加 `CONFIGURE_DEPENDS`)。
3. `autoDiscover=false` → 按构建系统类型登记(详见 `references/build-systems.md`):
   - 把每个新 `.c`(和 `.h`)加进工程文件的源节点(IAR `<file>` / Keil `<File>` / CMake `target_sources` / Make `SRCS`)。
   - 新增**目录**时同步 include 搜索路径(工程文件)+ LSP `-I`(`.clangd` 或 `compile_commands.json`)。
4. 实际编辑工程文件这一步由 `hf-implement` 落地(本 skill 产出"登记动作清单");单独调用时可直接给出 diff。
5. **排"假未定义"**:遇 `undefined reference` / IAR 伪 `Li005 no definition` 时,除查登记,还要排两类**伪未定义**:① 链接脚本(`.icf`/`.ld`)注释含非 ASCII 致 ILINK 崩溃(看似缺符号,实为脚本编码;见 `hf-embedded-safety` + `../references/embedded-c-style.md`);② 多层模式宏守卫不对齐致该分支无定义(见红线)。
6. 跑下方清单核对。

## 协作编排

- L0:单 target 单个新文件,主 agent 按清单自查即可。
- L1:多文件或 include/LSP 同步,自动主动派至少一个只读 reviewer 核对路径和登记位置。
- L2:跨 target、链接脚本、模式宏守卫、伪 undefined 排查,必须自动多路只读分工(构建图/LSP/模式宏或链接脚本)并由复审子代理核证据链;主 agent 亲验后才改工程文件。
- L3:构建图、LSP、文档矩阵同时变化或多 target/多工具链同步时,必须先形成只读调研和计划,多路只读复核构建登记、索引配置、PROJECT/manifest 同步闭环,复审子代理查证据链后主 agent 才裁决。
- 主 agent 降级自审只允许在平台/多代理工具不可用或宿主策略限制时使用,且必须声明限制;不得作为常规替代主动只读派发。
- 任何子代理/worker 都不得 stage/commit/push;Git 走确认门。

## PASS/FAIL 清单

- [ ] 每个新增 `.c` 已进链接单元(工程源节点 / `target_sources` / `SRCS`)。
- [ ] 每个新增 `.h` 虽不编译,IAR/Keil 等也已列入工程树(否则人工审阅漏看)。
- [ ] 新增源目录已进工程 include 搜索路径。
- [ ] (仅 `workspace.lsp.clangd=true`)新增源目录已进 LSP `-I`(`.clangd`)或已由 `compile_commands.json` 覆盖;`.ewp`/构建文件与 `.clangd` 成对同步。
- [ ] 工程文件路径前缀/分隔符符合该工具链(IAR `$PROJ_DIR$\..\` 反斜杠等),且**为相对/工程锚定路径,无绝对机器路径**(`D:\`、`/home/`)。
- [ ] 未跨 target 复制节点(高危同名文件未误引)。
- [ ] (clangd)PC 侧仿真子项目用独立 x86 `.clangd`(不复用 MCU `--target`);跨 target 分叉的 `-D`/`-I` 未互抄。
- [ ] 头里无裸 `inline`(改 `static inline` 或移 `.c`),未靠手工展开规避。
- [ ] 多层模式宏的函数定义/调用守卫三处对齐,无某分支"编译却无定义"。
- [ ] 排 `undefined`/伪 `Li005` 时已附带核对链接脚本 ASCII(交叉 `hf-embedded-safety`)。
- [ ] 构建同步复杂度分档已完成;L1/L2/L3 的路径/目标归属、构建图/LSP/文档矩阵闭环经主动只读复核。仅在平台/工具不可用或宿主策略限制时,主 agent 才可降级自审并已声明限制。

## 验证

- agent 能做:判定 autoDiscover、给出工程文件/LSP 的精确 diff、核对清单。
- 必须交用户:**agent 通常无法编译**。给出"在 IAR/Keil/CMake 里 Rebuild 应无 undefined reference;clangd 重启后新文件无虚假红线"的交接,由用户上机验证。

## 反面教训

- IAR `.ewp` 不 glob:某工程加 `proto.c/h`+`test.c/h` 时漏同步 `.ewp`,链接期 `undefined reference` 才发现。新建即登记可避免。
- 只加 `.c` 忘加 `.h` 目录到 `-I`:`#include "../include/x.h"` 后 clangd 整片红线,误以为代码错。
- CMake `file(GLOB)` 改了源但没 reconfigure:新文件不进构建,纯靠"为什么没生效"排查浪费时间。
- 头里裸 `inline`:多个 `.c` include 同一头的 `inline` 函数,链接期"无外部定义"。误以为漏登记,实为应 `static inline` 或移 `.c`。
- 伪 `Li005` 误诊:`.icf` 注释写中文 → ILINK Access Violation + 伪"未定义",照"漏登记"方向排查半天。先验链接脚本 ASCII 即定位(归 `hf-embedded-safety`)。
- 子目录化后 `.clangd` 回溯级数失效:`project/code/` 拆子目录后,写死的 `../../` 因文件深度不同而错位,clangd 找不到头。按深度分块 `-I` 或转 `compile_commands.json`(见 `references/build-systems.md` clangd 六条)。

## 平台差异

- Claude Code:`Read`/`Edit` 工程文件,`Bash`/`PowerShell` 跑构建。
- Codex:原生文件工具 + shell;无 plan mode,直接改。

## 参考

- `references/build-systems.md`(IAR/Keil/CMake/Make/PlatformIO 逐个登记法 + **clangd 六条经验**:成对同步/深度分块 -I/优先 compile_commands/SDK 噪声 Suppress/跨 target 禁同步/PC 仿真独立 x86;先读 manifest / compile_commands / `.vscode` / build config 自主发现 clangd,仅外部不可证或风险边界变化时最小提问)。
- `../references/embedded-c-style.md`(`inline`→undefined 完整、ICF/链接脚本 ASCII 校验、相对路径优先)。
- `hf-embedded-safety`(链接脚本非 ASCII 致伪 Li005——排"假未定义"的另一面)。
- `hf-design-module`(切点清单含本步)、`hf-implement`(落地登记)、`hf-doc-discipline`(新文件登记到 PROJECT.md)、`hf-init-workspace`(初始化登记 clangd 使用状态 → `workspace.lsp`;缺失时本 skill 自主发现)。
- `../hecateflow/references/orchestration-contract.md`(构建图/LSP 高误判成本时的只读复核与 Git 确认门)。
