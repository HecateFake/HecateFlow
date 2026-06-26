---
name: hf-review
description: >
  提交前的深度工程审查:比每次编辑的 auto-workflow 更深,跨范围聚合 ISR/数值/外设安全、死代码(复用感知)、
  文档同步、跨 target 一致性,必要时派子代理分维度对抗审查,产出分级问题报告(CRITICAL/HIGH/MEDIUM)。
  触发:审查 / 审查工程 / 提交前检查 / 深度 review / review / pre-commit review / audit codebase。
license: MIT
argument-hint: "[scope]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-review — 工程深度审查 / Deep Project Review

`hf-auto-workflow` 是每次编辑的轻量门;`hf-review` 是提交前/阶段末的深度审查:跨整块改动或整个模块聚合问题,可派子代理分维度对抗审查。

## 适用 / 不适用

- 适用:提交前、阶段收尾、合并前、"帮我审查这个模块/这批改动"。
- 不适用:单次编辑(那是 `hf-auto-workflow`)、纯重构等价性证明(那是 `hf-refactor` 的对抗审查)。

## 触发关键词

审查 / 审查工程 / 提交前检查 / 深度 review / audit。

## 第一性原则

**深度审查 = 聚合 + 多维 + 对抗。** 单次编辑看不到的问题(跨函数的死代码、跨 target 不一致、整体文档漂移)只有在更大范围聚合时才显形;关键发现要用独立子代理从不同维度对抗验证,而非自证。

## 审查维度

1. **安全**(调 `hf-embedded-safety`):ISR/volatile/数值/外设所有权全清单。
2. **死代码**(复用感知):零引用的 static 函数/变量、孤立废注释——但**排除**库对外 API、待接入链路、调试 gated 分支、对称储备符号(见 `hf-refactor` 的"有意保留")。
3. **文档同步**(调 `hf-doc-discipline`):PROJECT.md 六段、共享库版本登记、规则自身是否随代码失效。
4. **跨 target 一致性**:高危同名文件语义未串、共享库副本差异已登记。
5. **风格**(`references/embedded-c-style.md`):命名/类型/编码/条件编译。

## 执行流程

1. 确定 scope(本次改动 / 整模块 / 整 target),读 manifest `activeChecks`。
2. 逐维度扫描;复杂/高价值发现派子代理对抗复核(不同维度不同子代理)。
3. 亲自 grep/读码复核子代理结论中"涉及删除/改行为"的关键点(不轻信转述)。
4. 汇总分级报告:CRITICAL(安全/数据风险,阻塞)/ HIGH(bug/重大质量,应修)/ MEDIUM(可维护性,考虑)。
5. CRITICAL/HIGH 给修复建议或直接修(交 `hf-implement`);静默忽略 LOW。

## PASS/FAIL 清单(报告须覆盖)

- [ ] 安全维度全清单跑过(`hf-embedded-safety`)。
- [ ] 死代码判定是复用感知的(未误报库 API/待接入/储备符号)。
- [ ] 文档同步缺口已列(`hf-doc-discipline`)。
- [ ] 跨 target 高危文件/共享库一致性核过。
- [ ] 关键发现经子代理对抗复核 + 亲验,非单方面判定。
- [ ] 问题按 CRITICAL/HIGH/MEDIUM 分级,各带依据与位置。

## 验证

- agent 能做:静态聚合审查、派子代理、分级报告。
- 交用户:CRITICAL/HIGH 是否在本次修,以及需上板验证的项。

## 反面教训

- 把库储备 API 当死代码报删 → 破坏库完整性。
- 不分级,一股脑列 50 条 → 用户抓不住重点,CRITICAL 被淹没。
- 轻信子代理"零引用/等价"结论不亲验 → 误删致编译断裂(实测有此教训)。

## 平台差异

- 派子代理:Claude `Task`(可并行多维度);Codex `spawn_agent`(需 `multi_agent=true`)→`wait_agent`→`close_agent`。

## 参考

- `hf-embedded-safety`、`hf-doc-discipline`、`hf-refactor`(死代码/有意保留判定)、`references/embedded-c-style.md`、`hf-auto-workflow`(轻量版)。
