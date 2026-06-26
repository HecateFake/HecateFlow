---
name: hf-auto-workflow
description: >
  每次编辑源文件后立即自动跑的轻量审查门:核心 6 步(目标确认 → volatile 扫描 → ISR 安全 → 数值安全 →
  风格 → 文档同步)+ 按 manifest activeChecks 激活的扩展检查(极性/数量级提醒确认、相对路径、IO 外设归属、
  lessons 记录触发)。CRITICAL/HIGH 自动修,MEDIUM 列给用户,物理/归属类显式请用户确认。是 HecateFlow 的
  always-on 核心。Claude 端可挂 PostToolUse hook,Codex 端编辑后自律调用。触发:自动审查 / 编辑后检查 /
  auto workflow / post-edit review / 每次改完代码 / 极性提醒 / 相对路径检查 / IO 归属 / lessons 记录。
license: MIT
argument-hint: "[changed-path]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-auto-workflow — 每次编辑自动审查门 / Per-Edit Auto-Review Gate

HecateFlow 的 always-on 核心。每次编辑嵌入式源文件(`project code` 下的 `.c/.h` 等)后**立即、自动、无需用户提示**地跑 6 步审查。轻量、快、即时修——把问题挡在编辑当下,不攒到 review。

## 适用 / 不适用

- 适用:刚 Write/Edit 了源文件之后。
- 不适用:SDK/第三方库文件、文档/脚本/仿真 PC 代码(`tools/` 下)、提交时(编辑阶段已审,提交不重复)。

## 触发

- Claude Code:可配置为 PostToolUse hook(matcher `Write|Edit`),编辑后自动调起(配置片段见 README,opt-in)。
- Codex:无 hook 机制 → 正文约定"每次 Write/Edit 后你必须立即自跑下列 6 步"。
- 关键词:自动审查 / 编辑后检查 / post-edit review。

## 第一性原则

**问题在编辑当下最便宜。** 离开编辑上下文后,定位"哪次改动引入的"成本陡增。所以审查必须紧贴每次编辑,且对 CRITICAL/HIGH 自动修不打断节奏,只对需要决策的 MEDIUM 才打扰用户。

## 审查流程

按序执行,读 manifest `activeChecks` 决定哪几项激活。**核心 6 步默认全开**;**扩展检查按对应 `activeChecks` 开关激活**(默认 true)。

### 核心 6 步(always-on)

0. **目标确认**:从文件路径/manifest 提取所属 target;高危同名文件(`hazardFiles`)输出公告;用户上下文与文件所属 target 不符 → 停止并询问。
1. **volatile 扫描**:本次涉及的全局变量,若被 ISR 读写或被另一核访问而缺 `volatile` → CRITICAL,自动加。
2. **ISR 安全**:若改了 ISR,禁止新增 `printf`/LCD/串口/阻塞 `while`/动态内存/不可预测耗时函数 → CRITICAL,自动修。
3. **数值安全**:除零保护缺失、整型可能溢出、PID 无积分限幅、执行器输出无钳位 → HIGH,自动修(委派 `hf-embedded-safety` 视角)。
4. **风格**:命名/固定宽度类型/浮点 `f` 后缀/UTF-8 无 BOM/条件编译(见 `../references/embedded-c-style.md`)→ MEDIUM,提示不自动改。
5. **文档同步**:触发同步的改动(模块增删/语义/参数/边界/共享库)而 PROJECT.md 没跟 → HIGH,提示补(委派 `hf-doc-discipline`)。

### 扩展检查(按 `activeChecks` 激活)

这些检查**物理/归属/记忆类**问题 agent 无法靠静态分析独断,核心动作是**主动提醒并请用户确认**,不静默改。

6. **极性/数量级提醒-确认**(`activeChecks.polarityMagnitude`):本次改动**触及执行器/传感器/闭环极性或增益数量级**时(改 `*_DIR` 方向系数、新增驱动接线、整定 PID Kp、改菜单步长、上 yaw/航向闭环)→ **不静默改、不自行假定极性**,在回复里显式请用户核实物理事实:此 `*_DIR` 是本台硬件标定结果需开环辨识、闭环轴向须手动转车确认、增益作用量纲与步长须同量级。**红线就地拦截:发现极性翻转藏进 PID Kp 负号 → CRITICAL**(Kp 兼增益+极性,误改即正反馈跑飞),提示搬回 §极性段方向系数宏(细节委派 `hf-hw-mapping`,搬迁属改行为走 `hf-refactor`)。
7. **相对路径检查**(`activeChecks.relativePaths`):本次新增/改动的**构建配置、include、LSP `-I`、脚本**中若出现**绝对机器路径**(`<盘符>:\...`、`/home/...` 等)→ HIGH,提示改相对(`$PROJ_DIR$\..`、`-I./src`、`./tools/...`);绝对路径入库换机即坏(见 `../references/git-discipline.md`、`../references/embedded-c-style.md` 路径纪律)。
8. **IO 外设归属确认**(`activeChecks.ioOwnership`):本次改动**触及单实例 IO 外设**(SPI 屏/共享总线/共享 ADC/调试 UART 等)时 → 核对该外设在 manifest `targets[].ownedPeripherals[]` 的 `owner` 是否与当前 target 一致;**门控须白名单 `#if`(非黑名单)**否则新增模式默认抢占 → HIGH;跨核归属敏感(`io:true`)→ 提醒用户该外设归属并促分核任务规划(细节委派 `hf-hw-mapping`/`hf-embedded-safety`)。
9. **lessons 记录触发**(`activeChecks.lessonsCapture`):本次若**踩了非显而易见的坑 / 被用户纠正 / 确认了一个会复发的好做法** → 提示按 `hf-lessons` 记一条到 `.hecateflow/lessons/`。**反向**:编辑前已由 `hf-implement`/`hf-design-module` 检索过 `INDEX.md` 命中的 lesson,本步确认其"如何避免"动作已落实(recall→avoid 闭环,见 `hf-lessons`)。

## 严重级别与行动

| 级别 | 行动 |
|------|------|
| CRITICAL | 立即自动修,不询问 |
| HIGH | 立即自动修,不询问 |
| MEDIUM | 列出,由用户决定 |
| LOW | 静默忽略 |

## 输出(一行摘要)

- 全过:`✓ 审查通过,无问题`
- 有修:`✓ 审查完成,自动修复 N 个(CRITICAL×a, HIGH×b)`
- 待决:`⚠ 审查完成,N 个 MEDIUM 待确认:...`
- 待用户确认物理/归属事实:`⚠ 请确认:<极性/轴向/数量级/IO 归属 事实>`(扩展检查命中,不替用户假定)

## PASS/FAIL 清单

- [ ] 核心 6 步 + 激活的扩展检查全跑过(未跳过激活项)。
- [ ] CRITICAL/HIGH 已自动修,无遗留(含"极性藏 Kp 负号"这条 CRITICAL)。
- [ ] 目标 target 与用户上下文一致(不符已停并问)。
- [ ] 触及极性/轴向/数量级时已**显式请用户确认物理事实**,未自行假定极性。
- [ ] 新增构建/include/LSP/脚本无绝对机器路径(相对路径)。
- [ ] 触及单实例 IO 外设时已核对归属 + 门控为白名单 `#if`;跨核敏感已提醒分核规划。
- [ ] 本次踩坑/被纠正/好做法已提示按 `hf-lessons` 记录;编辑前命中的 lesson 规避动作已落实。
- [ ] 未审查 SDK/第三方/仿真 PC 代码。
- [ ] 输出了一行摘要。

## 不做的事

- 不触发 planner/architect 类重流程(轻量门)。
- 不在 `git commit` 时重复(编辑阶段已审)。
- 不审 SDK/第三方库;不加 Doxygen 注释。

## 反面教训

- 跳过目标确认 → 在错误 target 改了同名文件,语义全错。
- 把"漏 volatile"当 MEDIUM 拖着 → 偶发读旧值的幽灵 bug,极难复现。
- 编辑后不审、攒到提交 → 一次提交里多个 CRITICAL,定位困难。
- 改了 `*_DIR` 极性自行假定方向不提醒用户 → 在未标定映射上调正号 Kp,上板正反馈跑飞(极性属物理事实,agent 不能独断)。
- 新增 `.clangd`/`.ewp` 顺手写了绝对盘符路径 → 换机/换人检出即坏,本该相对路径。
- 编辑前不检索 lessons、编辑后也不记录 → 同类坑(GBK 编码、ICF ASCII)换会话又踩,"不再犯"沦为空话。

## 平台差异

- 自动触发:Claude PostToolUse hook(harness 强制);Codex 靠 prompt 自律(无 hook)。
- 委派安全/文档/极性/lessons 检查:Claude `Skill`/`Task`;Codex 原生加载相关 skill,仅在多代理工具可用且用户明确授权时使用 `multi_agent_v1.spawn_agent`,否则主会话顺序执行。
- 扩展检查的 hook 触发:`activeChecks.polarityMagnitude`/`ioOwnership`/`lessonsCapture` 为 true 时,Claude 端可在 PostToolUse hook 里提示这些主动确认;Codex 端编辑后自律执行(见 `../hecateflow/references/auto-injection.md`)。

## 参考

- `hf-embedded-safety`(安全门控/失控锁定/白名单 `#if`)、`hf-hw-mapping`(极性/数量级/IO 归属细节)、`hf-lessons`(记录/检索回路)、`hf-doc-discipline`(文档同步)。
- `../references/embedded-c-style.md`(风格 + 路径纪律)、`../references/git-discipline.md`(相对路径与提交)、`../hecateflow/references/auto-injection.md`(hook/自律触发)。
- `hf-implement`(每编辑后调本 skill)、`hf-review`(深度版)。
