---
name: hf-doc-discipline
description: >
  文档即真相源:每个 target 一份 PROJECT.md 随代码同步(状态卡/模块清单/边界/参数/ISR 表/验证清单),
  跨 target 共享库版本登记,防文档漂移。代码改了文档没跟 = 漂移,禁止累积。MCU 无关。
  触发:文档同步 / PROJECT.md / 更新文档 / 版本登记 / 文档漂移 / doc sync / keep docs in sync /
  module docs / library version registry。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-doc-discipline — 文档即真相源 / Docs-as-Source-of-Truth

无上下文的 agent(或半年后的你)进入一个 target 时,第一手依据是它的 PROJECT.md,不是把全部源码读一遍。所以 PROJECT.md 必须**准确且与代码同步**。文档漂移(代码变了文档没跟)比没有文档更危险——它会骗下一个 agent 按失效语义改代码。本 skill 维护"代码改动 → 文档同步"的纪律。

## 适用 / 不适用

- 适用:新增/删除/重命名模块文件、变更高危文件语义、新增/删除构建变体、改边界约定(ISR 时序/关键参数/硬件接口)、改动跨 target 共享库。
- 不适用:改 bug 但不改对外语义、纯内部重构且接口/参数不变(此时只需确认 PROJECT.md 无失效描述)。

## 触发关键词

文档同步 / PROJECT.md / 版本登记 / 文档漂移 / doc sync / library version registry。

## 第一性原则

**文档是代码的投影,必须与代码同一次提交更新。** PROJECT.md 是该 target 的单一真相源,nginx 式分散但交叉引用。共享库在多 target 各有副本独立演进时,版本差异必须登记,否则复用时选错版本。

## PROJECT.md 六段(模板 `templates/PROJECT.md.tmpl`)

1. **状态卡**:分支/构建变体/外设所有权/活跃任务/已知坑——单页速览。
2. **身份与定位**:MCU/架构/工具链/职责。
3. **模块清单**:目录结构 + 文件→用途表。
4. **高危文件/引脚**:跨 target 同名不同义文件必须列"本 target 含义"。
5. **边界与约束 / ISR 时序 / 关键参数**:主题式条目(`- **主题**:`),搜索友好。
6. **验证清单**:至少 3 条可验证项。

## 执行流程

1. 锁定 target,定位其 PROJECT.md(manifest `targets[].docPath`)。
2. 对照本次代码改动,判断触发了哪类同步(模块增删/语义变更/变体/边界/共享库)。
3. 更新对应段落:模块清单加/删行;高危文件改语义;参数表改值;ISR 表改周期;状态卡更新已知坑。
4. 共享库改动 → 更新版本登记表(哪个 target 持最完善版/差异/待对齐项)。
5. 跑下方清单;缺同步 → HIGH,提示补文档后再提交。

## PASS/FAIL 清单

- [ ] 新增/删除/重命名的模块文件,已在 PROJECT.md 模块清单同步增删。
- [ ] 变更了高危文件语义,PROJECT.md 高危文件段"本 target 含义"已更新。
- [ ] 新增/删除构建变体,状态卡 + 边界段已更新。
- [ ] 改了边界约定(ISR 周期/关键参数/硬件接口),对应表已改值。
- [ ] 改了跨 target 共享库,版本登记表已更新(差异/推荐版/待对齐)。
- [ ] 规则/skill 自身描述若被代码改动证伪,已同次校准(规则与代码同源)。
- [ ] 临时计划文件(INTEGRATION_PLAN.md)在任务完成后已删除,经验沉淀进 PROJECT.md。

## 版本登记的判定口径

判"哪个副本最完善"时区分两类,不一刀切按函数数量:
- **真落后**:该有的能力没跟进(如缺 `Reset`)→ 列"待对齐",推荐版指向有该能力者。
- **有意裁剪/按需演进**:各 target 按需求增删(如飞控只留 6 轴融合、不要磁力计)→ 标注意图,不强行统一。

## 验证

- agent 能做:判定同步缺口、直接补 PROJECT.md/版本表。
- 必须交用户:对"是否有意裁剪"拿不准时,先登记差异、不擅自合并,问用户。

## 反面教训

- 删了模块文件没删 PROJECT.md 对应行 → 下个 agent 找不到文件,以为是缺失要重写。
- 高危同名文件改了语义没更新"本 target 含义" → 跨 target 误用,把 A 核的百分比 API 当 B 核的原始值。
- 临时计划文件留在仓库长期不删 → 与 PROJECT.md 争当真相源,信息冲突。

## 平台差异

- Claude Code / Codex:均用原生读写工具更新 markdown;无平台特异逻辑。

## 参考

- `templates/PROJECT.md.tmpl`、`hf-init-project`(建初版 PROJECT.md)、`hf-implement`(改代码时同步)、`hf-auto-workflow`(第 6 步文档同步检查)。
