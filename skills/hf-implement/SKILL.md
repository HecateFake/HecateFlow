---
name: hf-implement
description: >
  增量实施一个模块设计/计划(build 阶段):按计划分阶段写源码,每次编辑后触发 hf-auto-workflow 审查,
  新文件委派 hf-build-sync 登记,改动委派 hf-doc-discipline 同步 PROJECT.md,修 bug/被纠正时触发
  hf-lessons 记录"不再犯",路径用相对、维护计划文件进度,完成后删计划并按 git-discipline 收尾。
  触发:实现 / 写代码 / 进 build / 执行计划 / 修 bug 收尾 / implement / build feature / execute plan。
license: MIT
argument-hint: "[plan-or-target]"
metadata:
  compatibility: claude-code codex
  version: 1.1.0
  layer: lifecycle
---

# hf-implement — 增量实施 / Incremental Implementation

把 `hf-design-module` 的设计/计划落成代码。本 skill 是生命周期的"执行枢纽",内部串起 build-sync(登记)、auto-workflow(每编辑审查)、doc-discipline(文档同步)、lessons(踩坑记录),并维护 plan→build 工作流,按 git 纪律收尾。

## 适用 / 不适用

- 适用:有设计卡/计划文件要落地、增量加模块、按阶段实现特性、修复会复发的 bug。
- 不适用:只读规划(去 `hf-design-module`)、行为保持重构(去 `hf-refactor`)。

## 触发关键词

实现 / 写代码 / 进 build / 执行计划 / 修 bug 收尾 / implement / build feature / execute plan。

## Quick Path(最小执行版)

1. 读 manifest + 计划文件,确认 target;不明确就先问。
2. 编辑前扫 `.hecateflow/lessons/INDEX.md`;命中则按 lesson 规避。
3. 每新增 `.c/.h` 或目录,立即执行 `hf-build-sync` 的登记清单,不能只写"见 hf-build-sync"。
4. 每次编辑后执行 `hf-auto-workflow`;Codex 无 hook 时,最终交付前必须补跑一次本次变更聚合版。
5. 若改了模块清单/边界/参数/协议,直接同步 PROJECT.md,不能只写"见 hf-doc-discipline"。
6. 结束时输出下方 `HecateFlow Check`,再提交/交付。

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
- remaining risks:
```

## 第一性原则

**每次编辑都是一次完整的小循环:写 → 登记 → 审查 → 同步 →(踩坑则)记忆。** 嵌入式的麻烦在于一处改动牵连构建图、并发安全、文档;再加上无上下文 agent 会反复踩同一个坑。把这五件事绑成每次编辑的固定收尾,才不会攒下技术债、也不会重复犯错。计划文件是跨会话的进度锚;路径一律相对,保证产物跨机可移植。

## 红线

- **攒一堆编辑最后统一审查**:CRITICAL 漏网且难定位。每次 Write/Edit 后立即跑 `hf-auto-workflow`。
- **新文件忘登记构建系统**:自以为实现了,链接期 `undefined reference` 才发现(委派 `hf-build-sync`)。
- **`git add .`**:把其它 agent/用户的工作区改动一锅端,污染提交、破坏并行协作。只显式 add 本次编辑文件(见 `../references/git-discipline.md`)。
- **回退非本次改动**:`git status` 里 agent 本次没碰的极性/增益/模式宏改动,往往是用户辛苦辨识的结果或其它 agent 的并行工作——原样保留,禁 `git checkout` 擅自丢弃。
- **踩了会复发的坑却不记**:修了非显而易见的 bug / 被用户纠正了做法,不写 lesson → 换个 agent 又踩(触发 `hf-lessons`)。
- **写绝对机器路径**:源码 `#include`、构建配置、计划文件引用一律相对路径,不写 `<盘符>:\...`。

## plan→build 工作流

1. 进 build 第一步:若有多阶段计划,把它写进计划文件(manifest `planFile.convention`,默认 `INTEGRATION_PLAN.md`,放贴近被改 target 处,路径相对)。
2. 会话恢复/上下文压缩后:先读计划文件确认当前阶段与进度,再继续。
3. 每阶段完成:勾选计划文件复选框。
4. 全部完成并提交后:**删除计划文件**(临时产物,经验沉淀进 PROJECT.md 或 lessons)。

## 执行流程(每个阶段)

1. 锁定 target(读 manifest;高危同名文件先公告 `目标:<target>/<file>(<语义>)`)。
2. **编辑前检索 lessons(recall)**:按 target / 关键词扫 `.hecateflow/lessons/INDEX.md`,命中则读对应 lesson 规避已知坑(见 `hf-lessons`;不查 = 白记)。
3. 按计划写/改源码,遵循 `../references/embedded-c-style.md`;**`#include` 用相对头路径,对应目录须进构建 include 搜索路径 + LSP `-I`**(路径纪律,见 `../references/git-discipline.md` / `hf-build-sync`)。
4. **新增文件** → 执行 `hf-build-sync` 的登记清单:登记进构建系统 + LSP(漏登 = 链接期 undefined);工程/LSP 路径用相对(`$PROJ_DIR$\..` 类)。禁止只口头说"应登记"。
5. **每次 Write/Edit 后** → 触发 `hf-auto-workflow` 的审查,CRITICAL/HIGH 立即修;Codex 无 hook 时,最终交付前必须补跑一次本次变更聚合版;涉极性/数量级/IO 归属时按其提醒请用户确认物理事实。
6. **改了模块清单/语义/参数/边界** → 执行 `hf-doc-discipline` 的同步动作,直接更新 PROJECT.md 或说明项目尚无 PROJECT.md(同次提交,见同步矩阵)。禁止只口头说"见文档纪律"。
7. **修 bug / 被纠正 / 确认好做法 → 触发 `hf-lessons` 记录(record)**:机制级、会复发的经验写 `.hecateflow/lessons/<slug>.md` + 登记 INDEX,并判升级路径(仅 lesson / 升 rule / 并入 auto-workflow);`activeChecks.lessonsCapture:true` 时由 `hf-auto-workflow` 在踩坑后提示。一次性排查细节不记(避免流水账)。
8. 勾选计划文件;阶段间不积压未审查代码。
9. 全部完成:删计划文件 → Git 收尾(见下)。

## Git 收尾(遵 `../references/git-discipline.md`)

- 提交格式按 manifest `git.commitFormat`;默认不替用户加 AI 署名(除非全局配置要求)。
- **只显式 add 本次编辑文件,禁 `git add .`**;工作区里非本次任务的改动按"归因优先级"(落别的 target → 其它 agent;落调参/极性/模式宏 → 用户有意)原样保留,不回退。
- 文档同步改动(模块增删/高危语义/协议)须在**同次提交**内一并 add(见 `hf-doc-discipline`)。
- 链接脚本/ICF 提交前 `LC_ALL=C grep -nP '[^\x00-\x7F]'` 校验无非 ASCII;新增构建配置无绝对机器路径。
- 按 manifest `git.remotes` 推送(多远端则全推,分支一致)。
- 高危/结构性改动在交付时给"上板编译验证"提示(agent 无法跑目标工具链)。

## PASS/FAIL 清单

- [ ] 编辑前已检索 lessons(命中则规避)。
- [ ] 每个新增源文件已登记构建系统 + LSP(`hf-build-sync`),路径相对。
- [ ] 每次编辑后跑过 `hf-auto-workflow`,无未修的 CRITICAL/HIGH;极性/数量级/IO 已请用户确认。
- [ ] 触发文档同步的改动已更新 PROJECT.md(`hf-doc-discipline`)。
- [ ] 修了会复发的 bug / 被纠正 → 已写 lesson + 判升级路径(`hf-lessons`)。
- [ ] 计划文件进度已勾选;全部完成后已删除。
- [ ] Git 只 add 本次文件、未 `git add .`、未回退用户/他人改动;ICF 无非 ASCII;无绝对路径;已推全部远端。
- [ ] 高危改动给了上板验证交接。

## 验证

- agent 能做:写码、登记、审查、文档同步、记 lesson、提交。
- 必须交用户:**编译与上板由用户做**(agent 跑不了目标工具链);极性/增益的物理辨识由用户上板确认;给明确验证步骤。
- 最终回复必须含 `HecateFlow Check`;若某项未执行,写明原因和风险。

## 反面教训

- 攒一堆编辑最后统一审查 → CRITICAL 漏网,且难定位是哪次改动引入。
- 新文件忘登记 → 自以为实现了,链接期才发现没编进去。
- 完成后不删计划文件 → 与 PROJECT.md 争真相源。
- `git add .` 把其他 agent/用户的工作区改动一并提交 → 污染提交、破坏并行协作。
- **修好 bug 不记 lesson** → 同类坑(编码/ICF/极性)换会话又踩,白白浪费上次的排查。
- 计划文件/`#include` 写绝对路径 → 换机/换人即断。

## 平台差异

- 调子 skill:Claude `Skill` 工具;Codex 原生加载。
- 自动审查/lessons 记录:Claude 可挂 PostToolUse hook(`activeChecks` 驱动);Codex 编辑后须自律调 `hf-auto-workflow` / `hf-lessons`。

## 参考

- `../hecateflow/templates/integration-plan.md.tmpl`、`../references/embedded-c-style.md`、`../references/git-discipline.md`。
- `hf-build-sync`、`hf-auto-workflow`、`hf-doc-discipline`、`hf-lessons`(修 bug 触发记录)。
- `hf-design-module`(上游)、`hf-hw-mapping`(极性/数量级确认细节)。
- manifest 字段:`planFile`/`git`/`lessons`/`activeChecks.lessonsCapture`(见 `../hecateflow/references/manifest-schema.md`)。
