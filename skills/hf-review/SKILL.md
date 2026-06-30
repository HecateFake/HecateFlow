---
name: hf-review
description: >
  提交前的深度工程审查:比每次编辑的 auto-workflow 更深,跨范围聚合 ISR/数值/外设安全、死代码(复用感知)、
  文档同步、跨 target 一致性、硬件驱动 owner、事实来源二次确认、场景约束合规、lessons 覆盖,
  必要时按自主性优先编排契约主动派只读子代理分维度对抗审查 + 复审子代理核证据链,产出分级问题报告
  (CRITICAL/HIGH/MEDIUM)。触发:审查 / 审查工程 / 提交前检查 / 深度 review / 场景合规 / 多工程一致性 /
  安全审查 / 代码审查 / 帮我检查 / 提交前 review / 合并前检查 / 质量检查 /
  不可能出现 / SDK 也可能错 / 事实二次确认 /
  review / pre-commit review / audit codebase / code audit / safety review。
license: MIT
argument-hint: "[scope]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-review — 工程深度审查 / Deep Project Review

`hf-auto-workflow` 是每次编辑的轻量门;`hf-review` 是提交前/阶段末的深度审查:跨整块改动或整个模块聚合问题,按 `../hecateflow/references/orchestration-contract.md` 先自主求证并主动派只读子代理分维度对抗审查,高风险结论再由复审子代理核证据链,最后主 agent 亲验裁决。

## 适用 / 不适用

- 适用:提交前、阶段收尾、合并前、"帮我审查这个模块/这批改动"。
- 不适用:单次编辑(那是 `hf-auto-workflow`)、纯重构等价性证明(那是 `hf-refactor` 的对抗审查)。

## 触发关键词

审查 / 审查工程 / 提交前检查 / 深度 review / audit。

## 第一性原则

**深度审查 = 聚合 + 多维 + 对抗 + 复审闭环。** 单次编辑看不到的问题(跨函数的死代码、跨 target 不一致、整体文档漂移)只有在更大范围聚合时才显形;关键发现要用独立子代理从不同维度对抗验证,再由复审子代理检查证据、矛盾和过度推断,不能自证。

## 审查维度

1. **安全**(调 `hf-embedded-safety`):ISR/volatile/数值/外设所有权全清单;**极性单一真相源**(无 Kp 藏极性、`*_DIR` 集中)、**数量级量纲**(增益/步长不混)与**硬件驱动代码级 owner**(无多头状态管理/竞态/重复 init/绕过 owner API)调 `hf-hw-mapping` 视角。
2. **死代码**(复用感知):零引用的 static 函数/变量、孤立废注释——但**排除**库对外 API、待接入链路、调试 gated 分支、对称储备符号(见 `hf-refactor` 的"有意保留")。
3. **文档同步**(调 `hf-doc-discipline`):PROJECT.md 六段、共享库版本登记、规则自身是否随代码失效、分级文档导航是否更新(`../references/tiered-docs.md`)。
4. **跨 target / 多工程一致性**(点 2):高危同名文件语义未串(各 target 的"本 target 含义"已登记)、共享库副本差异已登记(真落后 vs 有意裁剪)、`_legacy/` 归档未被复用、关键词→target 映射表覆盖本次新增。
5. **场景约束合规**(点 1,读 manifest `workspace.scenario`):本批改动是否违反工程**固化场景**的 `constraints`/`safetyRules`/`forbidden`(如赛规禁某类通信、安全规则禁某外设、禁离地等)→ 触犯 `forbidden`/`safetyRules` 即 CRITICAL。场景是"为什么"的常驻约束,审查须对照。
6. **事实来源 / 假设链**(点 25):本批 bug 修复是否把用户描述、SDK/厂商文档或实现、历史注释、既有代码、agent 推断分清为"已证实事实 / 未证实假设";若修复依据包含"这不可能出现""SDK 不会这样"等断言,是否有用户二次确认和代码/日志/SDK 实现证据。发现未证实断言直接驱动修复 → HIGH;若导致安全相关根因被排除 → CRITICAL。
7. **相对路径**(点 12,`activeChecks.relativePaths`):构建/include/LSP/脚本无绝对机器路径(见 `../references/git-discipline.md`)。
8. **lessons 覆盖**(点 7,引 `hf-lessons`):本批改动相关的 `.hecateflow/lessons/INDEX.md` 命中条目,其"如何避免"动作是否已落实;本次新踩的会复发的坑是否已记 lesson;反复/多 target 的 lesson 是否该升级为规则。
9. **风格**(`../references/embedded-c-style.md`):命名/类型/编码/条件编译。

## 执行流程

1. 确定 scope(本次改动 / 整模块 / 整 target),读 manifest `activeChecks`。
2. 按 `orchestration-contract` 做 A0-A3 与 L0-L3 分档;L1+ 自动主动派只读子代理,L2/L3 派多个只读子代理分维度扫描。
3. 派发前清理已完成/不再需要的子代理,按批次派发并保留复审槽位;`wait` 后吸收结论并及时 `close`,防止占满并发上限。
4. 对 L2/L3 的关键 PASS/FAIL 结论、以及任何复杂/高价值发现,派复审子代理检查证据充分性、矛盾和过度推断;无发现也要复审抽查覆盖面。
5. 亲自 grep/读码复核子代理结论中"涉及删除/改行为"的关键点(不轻信转述)。
6. 汇总分级报告:CRITICAL(安全/数据风险,阻塞)/ HIGH(bug/重大质量,应修)/ MEDIUM(可维护性,考虑)。
7. CRITICAL/HIGH 给修复建议或直接修(交 `hf-implement`);静默忽略 LOW。

## PASS/FAIL 清单(报告须覆盖)

- [ ] 安全维度全清单跑过(`hf-embedded-safety`);极性/数量级/驱动 owner 维度核过(`hf-hw-mapping`:无 Kp 藏极性、量纲不混、同一硬件驱动无多头状态管理/竞态)。
- [ ] 死代码判定是复用感知的(未误报库 API/待接入/储备符号)。
- [ ] 文档同步缺口已列(`hf-doc-discipline`),含分级文档导航。
- [ ] 跨 target / 多工程一致性核过:高危文件语义、共享库差异登记、`_legacy/` 未复用、关键词映射覆盖。
- [ ] **场景约束合规**核过:无违反 `workspace.scenario` 的 `forbidden`/`safetyRules`/`constraints`(触犯即 CRITICAL)。
- [ ] **事实来源 / 假设链**核过:用户、SDK/厂商、历史注释、既有代码、agent 推断均按证据分级;"不可能出现"类断言已二次确认,未被直接当作事实。
- [ ] 构建/include/LSP/脚本无绝对机器路径。
- [ ] **lessons 覆盖**:相关 lesson 规避动作已落实;本次新坑已记;可升级的已提示升级。
- [ ] 关键发现经只读子代理对抗复核 + 复审子代理核证据链 + 主 agent 亲验,非单方面判定;若 L2/L3 无发现,也已由复审子代理抽查覆盖面。
- [ ] 子代理并发槽位已管理:完成/不再需要的代理已关闭,L2/L3 分批派发且保留复审槽位,未占满并发上限。
- [ ] 问题按 CRITICAL/HIGH/MEDIUM 分级,各带依据与位置。

## 验证

- agent 能做:静态聚合审查、派子代理、分级报告。
- 交用户:CRITICAL/HIGH 是否在本次修,以及需上板验证的项。

## 反面教训

- 把库储备 API 当死代码报删 → 破坏库完整性。
- 不分级,一股脑列 50 条 → 用户抓不住重点,CRITICAL 被淹没。
- 轻信子代理"零引用/等价"结论不亲验 → 误删致编译断裂(实测有此教训)。
- 只审代码不对照 `workspace.scenario` → 放过了违反赛规/安全规则的实现(如禁无线通信场景里加了无线链路),功能"对"但违规。
- 把用户结论或 SDK/provider 承诺直接当事实 → 排除真正根因;尤其当结论是"不可能出现"时,审查必须要求二次确认和代码/日志证据。
- 不审驱动 owner → 同一硬件实例被多个模块各自初始化/保存状态,review 看似无单点 bug,上板却出现配置被覆盖、竞态和生命周期混乱。
- review 发现的会复发坑只口头说一句不记 lesson → 下次换 agent 又踩,审查的经验白沉淀。

## 平台差异

- 派子代理:Claude `Task`(可并行多维度);Codex 在多代理工具可用时主动用 `multi_agent_v1.spawn_agent`→`multi_agent_v1.wait_agent`→`multi_agent_v1.close_agent` 派只读 reviewer / reviewer-of-review;无工具或宿主策略限制时主会话顺序审查并声明平台限制导致未做子代理对抗复核。子代理不得写文件或执行 Git,遵守 `../hecateflow/references/orchestration-contract.md`。

## 参考

- `hf-embedded-safety`(安全)、`hf-hw-mapping`(极性/数量级/IO 归属/驱动 owner)、`hf-doc-discipline`(文档/版本登记)、`hf-lessons`(lessons 覆盖/升级)、`hf-refactor`(死代码/有意保留判定)。
- `../references/embedded-c-style.md`、`../references/tiered-docs.md`(分级文档/多工程)、`../references/git-discipline.md`(相对路径)。
- `hf-auto-workflow`(轻量版);manifest `workspace.scenario` / `activeChecks`(见 `../hecateflow/references/manifest-schema.md`)。
- `../hecateflow/references/orchestration-contract.md`(分维度只读审查 / 复审链 / Git 确认门)。
