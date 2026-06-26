---
name: hf-implement
description: >
  增量实施一个模块设计/计划(build 阶段):按计划分阶段写源码,每次编辑后触发 hf-auto-workflow 审查,
  新文件委派 hf-build-sync 登记,改动委派 hf-doc-discipline 同步 PROJECT.md,维护计划文件进度,
  完成后删计划并按 Git 纪律收尾。触发:实现 / 写代码 / 进 build / 执行计划 / implement /
  build feature / execute plan。
license: MIT
argument-hint: "[plan-or-target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-implement — 增量实施 / Incremental Implementation

把 `hf-design-module` 的设计/计划落成代码。本 skill 是生命周期的"执行枢纽",内部串起 build-sync(登记)、auto-workflow(每编辑审查)、doc-discipline(文档同步),并维护 plan→build 工作流。

## 适用 / 不适用

- 适用:有设计卡/计划文件要落地、增量加模块、按阶段实现特性。
- 不适用:只读规划(去 `hf-design-module`)、行为保持重构(去 `hf-refactor`)。

## 触发关键词

实现 / 写代码 / 进 build / 执行计划 / implement / build feature / execute plan。

## 第一性原则

**每次编辑都是一次完整的小循环:写 → 登记 → 审查 → 同步。** 嵌入式的麻烦在于一处改动牵连构建图、并发安全、文档。把这四件事绑成每次编辑的固定收尾,才不会攒下技术债。计划文件是跨会话的进度锚。

## plan→build 工作流

1. 进 build 第一步:若有多阶段计划,把它写进计划文件(manifest `planFile.convention`,默认 `INTEGRATION_PLAN.md`,放贴近被改 target 处)。
2. 会话恢复/上下文压缩后:先读计划文件确认当前阶段与进度,再继续。
3. 每阶段完成:勾选计划文件复选框。
4. 全部完成并提交后:**删除计划文件**(临时产物,经验沉淀进 PROJECT.md)。

## 执行流程(每个阶段)

1. 锁定 target(读 manifest;高危同名文件先公告 `目标:<target>/<file>(<语义>)`)。
2. 按计划写/改源码,遵循 `references/embedded-c-style.md`。
3. **新增文件** → 委派 `hf-build-sync`:登记进构建系统 + LSP(漏登 = 链接期 undefined)。
4. **每次 Write/Edit 后** → 触发 `hf-auto-workflow` 的 6 步审查,CRITICAL/HIGH 立即修。
5. **改了模块清单/语义/参数/边界** → 委派 `hf-doc-discipline` 同步 PROJECT.md。
6. 勾选计划文件;阶段间不积压未审查代码。
7. 全部完成:删计划文件 → Git 收尾(见下)。

## Git 收尾

- 提交格式按 manifest `git.commitFormat`。
- **只显式 add 本次编辑文件,禁止 `git add .`**;工作区里非本次任务的改动默认视为用户有意,原样保留不回退。
- 按 manifest `git.remotes` 推送(多远端则都推)。
- 高危/结构性改动在交付时给出"上板编译验证"提示(agent 无法跑目标工具链)。

## PASS/FAIL 清单

- [ ] 每个新增源文件已登记构建系统 + LSP(`hf-build-sync`)。
- [ ] 每次编辑后跑过 `hf-auto-workflow`,无未修的 CRITICAL/HIGH。
- [ ] 触发文档同步的改动已更新 PROJECT.md(`hf-doc-discipline`)。
- [ ] 计划文件进度已勾选;全部完成后已删除。
- [ ] Git 只 add 本次文件、未 `git add .`、未回退用户的工作区改动。
- [ ] 高危改动给了上板验证交接。

## 验证

- agent 能做:写码、登记、审查、文档同步、提交。
- 必须交用户:**编译与上板由用户做**(agent 跑不了目标工具链);给明确验证步骤。

## 反面教训

- 攒一堆编辑最后统一审查 → CRITICAL 漏网,且难定位是哪次改动引入。
- 新文件忘登记 → 自以为实现了,链接期才发现没编进去。
- 完成后不删计划文件 → 与 PROJECT.md 争真相源。
- `git add .` 把其他 agent/用户的工作区改动一并提交 → 污染提交、破坏并行协作。

## 平台差异

- 调子 skill:Claude `Skill` 工具;Codex 原生加载。
- 自动审查:Claude 可挂 PostToolUse hook;Codex 编辑后须自律调 `hf-auto-workflow`。

## 参考

- `templates/integration-plan.md.tmpl`、`hf-build-sync`、`hf-auto-workflow`、`hf-doc-discipline`、`references/embedded-c-style.md`、`hf-design-module`(上游)。
