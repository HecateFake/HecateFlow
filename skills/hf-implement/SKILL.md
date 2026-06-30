---
name: hf-implement
description: >
  增量实施一个模块设计/计划(build 阶段):按计划分阶段写源码,每次编辑后触发 hf-auto-workflow 审查,
  新文件委派 hf-build-sync 登记,改动委派 hf-doc-discipline 同步 PROJECT.md,修 bug/被纠正时触发
  hf-lessons 记录"不再犯",按自主性优先编排契约自动调研/主动只读复审/限制 worker/Git 等待确认,路径用相对、维护计划文件进度。
  触发:实现 / 写代码 / 改代码 / 进 build / 执行计划 / 修 bug 收尾 / 按计划落地 / 开始开发 /
  新增功能实现 / 修改源码 / 排查 bug / 不可能出现 / SDK 也可能错 / 事实二次确认 /
  implement / build feature / execute plan / code changes / develop feature。
license: MIT
argument-hint: "[plan-or-target]"
metadata:
  compatibility: claude-code codex
  version: 1.1.0
  layer: lifecycle
---

# hf-implement — 增量实施 / Incremental Implementation

把 `hf-design-module` 的设计/计划落成代码。本 skill 是生命周期的"执行枢纽",内部串起 build-sync(登记)、auto-workflow(每编辑审查)、doc-discipline(文档同步)、lessons(踩坑记录),并维护 plan→build 工作流。协作与 Git 遵守 `../hecateflow/references/orchestration-contract.md`:先自主求证,主 agent 自动吸收只读调研并持最终裁决;写入 worker 后置且受限;Git 只建议,等待用户确认。

## 适用 / 不适用

- 适用:有设计卡/计划文件要落地、增量加模块、按阶段实现特性、修复会复发的 bug。
- 不适用:只读规划(去 `hf-design-module`)、行为保持重构(去 `hf-refactor`)。

## 触发关键词

实现 / 写代码 / 进 build / 执行计划 / 修 bug 收尾 / implement / build feature / execute plan。

## Quick Path(最小执行版)

1. 读 manifest + 计划文件,自动搜索路径/关键词确认 target;仍无法判定且会编辑源文件时才问。
2. 按编排契约自动调研并吸收设计卡里的只读调研/复审结论;高风险结论主 agent 亲验后再写。
3. 编辑前扫 `.hecateflow/lessons/INDEX.md`;命中则按 lesson 规避。
4. 修 bug 前列"现象 / 已证实事实 / 未证实假设",用户与 SDK/厂商说法都需证据确认;"不可能出现"类断言先二次确认。
5. 写代码前检查目标自写文件行数:>650 行先做分文件评估;>1000 行默认先拆层/拆模块,特殊长文件需用户确认例外。
6. 每新增 `.c/.h` 或目录,立即执行 `hf-build-sync` 的登记清单,不能只写"见 hf-build-sync"。
7. 每次编辑后执行 `hf-auto-workflow`;Codex 无 hook 时,最终交付前必须补跑一次本次变更聚合版。
8. 若改了模块清单/边界/参数/协议,直接同步 PROJECT.md,不能只写"见 hf-doc-discipline"。
9. 结束时输出下方 `HecateFlow Check` + Git 建议;等待用户确认后才 stage/commit/push。

```text
HecateFlow Check:
- target:
- files touched:
- build sync:
- auto-workflow:
- doc sync:
- polarity/io:
- lessons:
- git:
- orchestration:
- remaining risks:
```

## 第一性原则

**每次编辑都是一次完整的小循环:写 → 登记 → 审查 → 同步 →(踩坑则)记忆。** 嵌入式的麻烦在于一处改动牵连构建图、并发安全、文档;再加上无上下文 agent 会反复踩同一个坑。把这五件事绑成每次编辑的固定收尾,才不会攒下技术债、也不会重复犯错。计划文件是跨会话的进度锚;路径一律相对,保证产物跨机可移植。

## 红线

- **攒一堆编辑最后统一审查**:CRITICAL 漏网且难定位。每次 Write/Edit 后立即跑 `hf-auto-workflow`。
- **新文件忘登记构建系统**:自以为实现了,链接期 `undefined reference` 才发现(委派 `hf-build-sync`)。
- **继续把复杂功能塞进大文件**:自写业务文件超过 650 行先评估分文件;超过 1000 行默认拆成硬件底层/硬件顶层/软件实现或其它清晰模块。vendor/generated/table 可例外;自写特殊长文件只有用户明确确认并记录理由后才可保留不拆。
- **该封库的复用点留在私有文件里**:不足 650 行但后续会高频复用的 PID、滤波、协议解析、数学工具、设备 facade,应考虑单独封成公共库或公共头,不要等复制扩散后再补救。
- **`git add .`**:把其它 agent/用户的工作区改动一锅端,污染提交、破坏并行协作。只显式 add 本次编辑文件(见 `../references/git-discipline.md`)。
- **回退非本次改动**:`git status` 里 agent 本次没碰的极性/增益/模式宏改动,往往是用户辛苦辨识的结果或其它 agent 的并行工作——原样保留,禁 `git checkout` 擅自丢弃。
- **踩了会复发的坑却不记**:修了非显而易见的 bug / 被用户纠正了做法,不写 lesson → 换个 agent 又踩(触发 `hf-lessons`)。
- **写绝对机器路径**:源码 `#include`、构建配置、计划文件引用一律相对路径,不写 `<盘符>:\...`。
- **把来源断言当事实**:用户描述、SDK/厂商承诺、历史注释、既有代码都可能错。修 bug 时遇到"这不可能出现""SDK 不会错"这类断言,先二次确认复现条件与证据,再读代码/SDK/日志验证;矛盾处标"未证实假设",不据此直接改。
- **把 worker 当探索者或 Git 执行者**:实施 worker 只能在用户已明确要求实现/修改/落地/应用补丁、方案完整、文件范围互斥且边界清楚后按指定范围写;不得跨范围、改规则边界、stage/commit/push。主 agent 必须读 diff 并亲验关键证据。
- **自动提交/推送**:完成实现和验证后只报告摘要、验证结果、建议提交说明和待暂存文件;等待用户明确确认才进入 Git 写流程。

## plan→build 工作流

1. 进 build 第一步:若有多阶段计划,把它写进计划文件(manifest `planFile.convention`,默认 `INTEGRATION_PLAN.md`,放贴近被改 target 处,路径相对)。
2. 会话恢复/上下文压缩后:先读计划文件确认当前阶段与进度,再继续。
3. 每阶段完成:勾选计划文件复选框。
4. 全部完成并提交后:**删除计划文件**(临时产物,经验沉淀进 PROJECT.md 或 lessons)。

## 执行流程(每个阶段)

1. 锁定 target(读 manifest;高危同名文件先公告 `目标:<target>/<file>(<语义>)`)。
2. **编辑前检索 lessons(recall)**:按 target / 关键词扫 `.hecateflow/lessons/INDEX.md`,命中则读对应 lesson 规避已知坑(见 `hf-lessons`;不查 = 白记)。
3. **修 bug 的事实门**:把用户描述、SDK/厂商文档、历史注释、代码现状分别列为"已证实事实 / 未证实假设 / 待用户二次确认"。若用户提出"理论上不可能出现",先请其二次确认复现条件/观测证据;同时读真实代码、SDK 源/文档、日志或寄存器路径找反证。未证实前不把任何来源结论当修复依据。
4. **自主性编排门(点 26)**:读计划文件的协作分档,缺失则主 agent 自动分档。A0 先自主求证;L1+ 自动主动派发只读调研;L2/L3 的子代理结论须经过复审链并由主 agent grep/读码亲验。复审若 FAIL,先修可证问题再重派复审,直到当前 change set PASS 或只剩 A3 用户确认/物理验证/平台限制。若使用实施 worker,必须限定互斥文件范围、接口/行为预期、验证方式和禁止事项。
5. **文件分层/行数门**:按设计卡执行硬件底层/硬件顶层/软件实现分文件;缺失设计卡时本地补判。编辑目标自写 `.c/.h` 前统计行数:>650 行写明继续编辑还是拆分的理由;>1000 行默认先行为保持拆分或新建模块承接新增逻辑。若属于 vendor/generated/register map/buffer table 或用户明确确认的特殊长文件例外,记录例外理由与后续增长边界。
6. 按计划写/改源码,遵循 `../references/embedded-c-style.md`;**`#include` 用相对头路径,对应目录须进构建 include 搜索路径 + LSP `-I`**(路径纪律,见 `../references/git-discipline.md` / `hf-build-sync`)。
7. **新增文件** → 执行 `hf-build-sync` 的登记清单:登记进构建系统 + LSP(漏登 = 链接期 undefined);工程/LSP 路径用相对(`$PROJ_DIR$\..` 类)。禁止只口头说"应登记"。
8. **每次 Write/Edit 后** → 触发 `hf-auto-workflow` 的审查,CRITICAL/HIGH 立即修;Codex 无 hook 时,最终交付前必须补跑一次本次变更聚合版;涉极性/数量级/IO 归属时按其提醒请用户确认物理事实。
9. **改了模块清单/语义/参数/边界** → 执行 `hf-doc-discipline` 的同步动作,直接更新 PROJECT.md 或说明项目尚无 PROJECT.md(同次提交,见同步矩阵)。禁止只口头说"见文档纪律"。
10. **修 bug / 被纠正 / 确认好做法 → 触发 `hf-lessons` 记录(record)**:机制级、会复发的经验写 `.hecateflow/lessons/<slug>.md` + 登记 INDEX,并判升级路径(仅 lesson / 升 rule / 并入 auto-workflow);`activeChecks.lessonsCapture:true` 时由 `hf-auto-workflow` 在踩坑后提示。一次性排查细节不记(避免流水账)。
11. 勾选计划文件;阶段间不积压未审查代码。
12. 全部完成:删计划文件 → 输出 Git 建议(见下);未经用户确认不 stage/commit/push。

## Git 收尾(遵 `../references/git-discipline.md` + Git 确认门)

- 提交格式按 manifest `git.commitFormat`;默认不替用户加 AI 署名(除非全局配置要求)。
- **只显式 add 本次编辑文件,禁 `git add .`**;工作区里非本次任务的改动按"归因优先级"(落别的 target → 其它 agent;落调参/极性/模式宏 → 用户有意)原样保留,不回退。
- 文档同步改动(模块增删/高危语义/协议)须在**同次提交**内一并 add(见 `hf-doc-discipline`)。
- 链接脚本/ICF 提交前 `LC_ALL=C grep -nP '[^\x00-\x7F]'` 校验无非 ASCII;新增构建配置无绝对机器路径。
- 完成实现和验证后先输出变更摘要、验证结果、建议提交说明和待暂存文件清单;只有用户明确确认提交/推送这一组改动后,才按 manifest `git.remotes` 推送(多远端则全推,分支一致)。
- 高危/结构性改动在交付时给"上板编译验证"提示(agent 无法跑目标工具链)。

## PASS/FAIL 清单

- [ ] 编辑前已检索 lessons(命中则规避)。
- [ ] 修 bug 时已完成事实门:用户/SDK/历史注释/既有代码的断言已按证据分级;"不可能出现"类说法已二次确认后才采信。
- [ ] 协作分档已执行:L1+ 吸收只读调研,L2/L3 有复审链 + 主 agent 亲验;worker 若使用,范围互斥且无 Git 权限。
- [ ] 复审迭代闭环已执行:FAIL/CRITICAL/HIGH/MEDIUM 覆盖缺口已修复并重新复审,当前 change set PASS 或剩余 A3 项已列明。
- [ ] 文件分层/行数门已执行:硬件底层/硬件顶层/软件实现边界清楚;>650 行已评估分文件;>1000 行已拆分或记录 vendor/generated/table/用户确认特殊长文件例外;高频复用小模块已考虑公共库/公共头。
- [ ] 通信/共享快照门已执行:半双工/共享总线有唯一 master + request-response + timeout + valid frame;RX ISR/前台解析有 budget;跨核/跨 ISR 快照有 `magic`/`seq`/freshness gate;失链/超时不消费旧命令。
- [ ] 参数持久化门已执行:blob 含 `magic/version/payloadBytes/CRC`;先 load defaults;只有 version 迁移/写回门允许才写 flash;CRC/magic/payloadBytes 错不自动覆盖;flash 写入不进 ISR/控制热路径。
- [ ] 每个新增源文件已登记构建系统 + LSP(`hf-build-sync`),路径相对。
- [ ] 每次编辑后跑过 `hf-auto-workflow`,无未修的 CRITICAL/HIGH;极性/数量级/IO 已请用户确认。
- [ ] 触发文档同步的改动已更新 PROJECT.md(`hf-doc-discipline`)。
- [ ] 修了会复发的 bug / 被纠正 → 已写 lesson + 判升级路径(`hf-lessons`)。
- [ ] 计划文件进度已勾选;全部完成后已删除。
- [ ] Git 只给建议并等待用户确认;若已获确认,只 add 本次文件、未 `git add .`、未回退用户/他人改动;ICF 无非 ASCII;无绝对路径;已推全部远端。
- [ ] 高危改动给了上板验证交接。

## 验证

- agent 能做:写码、登记、审查、文档同步、记 lesson、提交。
- 必须交用户:**编译与上板由用户做**(agent 跑不了目标工具链);极性/增益的物理辨识由用户上板确认;给明确验证步骤。
- 最终回复必须含 `HecateFlow Check`;若某项未执行,写明原因和风险。

## 反面教训

- 攒一堆编辑最后统一审查 → CRITICAL 漏网,且难定位是哪次改动引入。
- 新文件忘登记 → 自以为实现了,链接期才发现没编进去。
- 超过 650 行还继续塞功能 → 文件职责开始混杂,review 只能看局部;超过 1000 行仍不拆且无用户确认例外 → 维护边界失控。
- 完成后不删计划文件 → 与 PROJECT.md 争真相源。
- `git add .` 把其他 agent/用户的工作区改动一并提交 → 污染提交、破坏并行协作。
- **修好 bug 不记 lesson** → 同类坑(编码/ICF/极性)换会话又踩,白白浪费上次的排查。
- 计划文件/`#include` 写绝对路径 → 换机/换人即断。
- 轻信"SDK 不可能错"或"用户已经确定" → 把真实根因排除在搜索空间外;应把所有来源当证据而非事实,二次确认后再落修复。

## 平台差异

- 调子 skill:Claude `Skill` 工具;Codex 原生加载。
- 自动审查/lessons 记录:Claude 可挂 PostToolUse hook(`activeChecks` 驱动);Codex 编辑后须自律调 `hf-auto-workflow` / `hf-lessons`。

## 参考

- `../hecateflow/templates/integration-plan.md.tmpl`、`../references/embedded-c-style.md`、`../references/git-discipline.md`。
- `hf-build-sync`、`hf-auto-workflow`、`hf-doc-discipline`、`hf-lessons`(修 bug 触发记录)。
- `hf-design-module`(上游)、`hf-hw-mapping`(极性/数量级确认细节)。
- `../hecateflow/references/orchestration-contract.md`(协作分档 / worker 门 / Git 确认门)。
- manifest 字段:`planFile`/`git`/`interaction`/`lessons`/`activeChecks.factConfirmation`/`activeChecks.lessonsCapture`(见 `../hecateflow/references/manifest-schema.md`)。
