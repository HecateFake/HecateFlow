---
name: hf-doc-discipline
description: >
  文档即真相源:三层分级文档省上下文(纲领→各 target PROJECT.md→场景规则,按需下钻),代码改动→必同步文档
  矩阵(自动进化同源),跨 target 共享库版本登记 + 多工程关键词映射/同名异义登记,与 lessons 经验记忆衔接。
  规则/文档治理按自主性优先编排契约做主动只读复核与 Git 确认门。
  代码改了文档没跟 = 漂移,禁止累积。MCU 无关。触发:文档同步 / PROJECT.md / 更新文档 / 版本登记 /
  分级文档 / 多工程 / 文档漂移 / 模块清单 / 高危文件语义 / 通信协议表 / PINOUT /
  doc sync / tiered docs / library version registry / update docs / project documentation。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-doc-discipline — 文档即真相源 / Docs-as-Source-of-Truth

无上下文的 agent(或半年后的你)进入一个 target 时,第一手依据是它的 PROJECT.md,不是把全部源码读一遍。所以 PROJECT.md 必须**准确且与代码同步**。文档漂移(代码变了文档没跟)比没有文档更危险——它会骗下一个 agent 按失效语义改代码。本 skill 维护"代码改动 → 文档同步"的纪律。文档/规则治理会影响所有后续 agent,默认遵守 `../hecateflow/references/orchestration-contract.md`:多文件规则同步至少 L1,新增/删除规则、镜像入口、instructions 或全包方法论重构按 L2/L3,需要只读复核触发表、引用和注入闭环。

## 适用 / 不适用

- 适用:新增/删除/重命名模块文件、变更高危文件语义、新增/删除构建变体、改边界约定(ISR 时序/关键参数/硬件接口)、改动跨 target 共享库。
- 不适用:改 bug 但不改对外语义、纯内部重构且接口/参数不变(此时只需确认 PROJECT.md 无失效描述)。

## 触发关键词

文档同步 / PROJECT.md / 版本登记 / 文档漂移 / doc sync / library version registry。

## 第一性原则

**文档是代码的投影,必须与代码同一次提交更新。** 三条推论:

- **分级省上下文**:上下文稀缺,不能把全部工程知识塞一个大文件每会话全量加载。三层分级 + 按需下钻——冷启动只读纲领,定位 target 后才下钻其 PROJECT.md,命中场景才读对应规则(完整模型见 `../references/tiered-docs.md`)。
- **同源同提交**:PROJECT.md 是该 target 的单一真相源,分散但交叉引用;代码改了文档没跟 = 漂移,会骗下个 agent 按失效语义改代码。规则/skill/术语同受此约束。
- **多工程可路由**:共享库在多 target 各有副本独立演进时版本差异必须登记;同名异义高危文件、关键词→target 映射让无上下文 agent 能正确路由,不误改邻核。

## 分级文档体系(省上下文,点 4 — 详见 `../references/tiered-docs.md`)

| 层 | 文件 | 何时读 |
|----|------|--------|
| ① 纲领 | `CLAUDE.md`/`AGENTS.md`、`docs/README.md`、`docs/*`(PINOUT/GLOSSARY/LIBRARY_VERSIONS) | **每次冷启动**(harness 自动注入纲领入口) |
| ② 核内真相源 | 各 target `PROJECT.md` | **定位到某 target 后下钻** |
| ③ 场景规则 | `.claude/rules/*.md` + 临时 `INTEGRATION_PLAN.md` | **命中具体场景时** |

**冷启动下钻路径**:读纲领 → 关键词/路径定位 target → 读该 target `PROJECT.md` → 命中场景读对应 rule。`docs/README.md` 做"我想做 X 看哪份"导航表,避免盲目全量读。维护文档时,本 skill **既维护②核内真相源,也维护①纲领的导航/映射表与③规则的同源校准**;细节不在此复述,以 `../references/tiered-docs.md` 为基线。

## PROJECT.md 六段(模板 `../hecateflow/templates/PROJECT.md.tmpl`)

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

## 协作编排

- 多文件文档同步:至少 L1,用只读视角查漏项和交叉引用。
- 规则/skill/注入变更:按 L2/L3,复审子代理检查证据、矛盾、过度推断和遗漏 Git 确认门。
- 主 agent 降级自审只允许在平台/多代理工具不可用或宿主策略限制时使用,且必须声明限制;不得作为常规替代主动只读派发。
- 主 agent 最终亲自核对新增规则的四处同步(rule 文件 + instructions + 触发表 + 镜像入口),并只输出 Git 建议,等待用户确认。

## 自动进化同源矩阵(点 3 — 代码改动 → 必同步文档)

代码改动后按类型在**同次提交**内同步对应文档(缺失同步 = 漂移,禁止累积)。简表如下,**完整矩阵见 `../references/tiered-docs.md`**:

| 代码改动 | 必同步 |
|----------|--------|
| 新增/删除/重命名模块文件 | 该 target `PROJECT.md` 模块清单 + 构建工程文件 + LSP 配置(`hf-build-sync`) |
| 高危文件语义变更 | `PROJECT.md` + 纲领 `CLAUDE.md`/`AGENTS.md` + 对应 rule |
| 新增/切换编译期模式 | `PROJECT.md` 模式段 + rule 切点清单 |
| 改跨 target 通信协议/帧格式 | 纲领通信表 + `docs/PINOUT.md` + 两端 target PROJECT.md |
| 改半双工/共享总线或跨核快照 | PROJECT.md 通信/共享快照段 + 协议表(master/request-response/timeout/valid frame/`magic`/`seq`/freshness) |
| 改引脚/硬件映射 | `pinMap.h` → `docs/PINOUT.md` 冲突矩阵(先改头再更新矩阵,见 `hf-hw-mapping`) |
| 改极性/方向系数 | `configHeader` §极性段注释 + 提醒用户核实接线(`hf-hw-mapping`) |
| 改运行时参数持久化 blob | 参数持久化表(`magic/version/payloadBytes/CRC`/迁移/写回门) + PROJECT.md 关键参数段 |
| 改/同步共享库 | `docs/LIBRARY_VERSIONS.md`(见下版本登记) |
| 新增规则 | rule 文件 + `instructions[]` + rules/README 触发表 + 镜像入口(`../hecateflow/references/auto-injection.md`) |

**规则/skill/术语与代码同源**:代码改动使某 rule/skill/术语描述失效 → 同次提交校准,与 PROJECT.md 同等约束。

## 多工程管理(点 2 — 纲领层必备)

单工作区多个独立可构建 target 时,**纲领层**(本 skill 维护)须提供三件路由资产:

- **关键词 → target 映射表**:用户措辞(如"麦轮/底盘/编码器"→某核)直接路由,免逐个翻。新增 target/职责须更新此表。
- **同名异义高危文件登记**:`motor.c`/`IMU.c`/`PID.c` 等跨 target 语义不同,各 target 的 PROJECT.md 高危段写"本 target 含义",编辑前公告 `目标:<target>/<file>(<语义>)`。manifest `targets[].hazardFiles`。
- **共享库版本登记 + `_legacy/` 隔离**:见下"判定口径";归档代码进 `_legacy/`,纲领标注"仅供参考、不复用",防误用旧版本。

## 与 lessons 经验记忆的衔接(点 7,引 `hf-lessons`)

doc-discipline 管"**当下同步**"(代码改→文档跟),`hf-lessons` 管"**跨会话记忆**"(踩坑→下次别犯),职责不重叠(完整边界表见 `hf-lessons`)。衔接点:**lesson 反复出现或多 target 相关 → 升级为 `.claude/rules` 段**,此后该规则的"代码改动→规则校准"重新归本 skill 的同步矩阵管。`../references/tiered-docs.md` 的"不再犯回路"是两者共同索引,`hf-lessons` 是主实现,本 skill 只引用、不复述记录/检索细节。

## PASS/FAIL 清单

- [ ] 冷启动按需读路径成立:纲领有导航表 + 关键词→target 映射 + 同名高危登记,未把全部知识塞一个巨文件。
- [ ] 新增/删除/重命名的模块文件,已在 PROJECT.md 模块清单同步增删。
- [ ] 变更了高危文件语义,PROJECT.md 高危文件段"本 target 含义"已更新。
- [ ] 新增/删除构建变体,状态卡 + 边界段已更新。
- [ ] 改了边界约定(ISR 周期/关键参数/硬件接口),对应表已改值。
- [ ] 改了通信协议/共享快照,master/request-response/timeout/valid frame/`magic`/`seq`/freshness gate/失链降级文档已同步。
- [ ] 改了参数持久化,blob `magic/version/payloadBytes/CRC`、迁移范围、写回门、CRC/magic/payloadBytes 错不自动覆盖 flash、先加载默认值和 flash 写入时机已同步。
- [ ] 改了跨 target 共享库,版本登记表已更新(差异/推荐版/待对齐)。
- [ ] 多工程路由资产已随改动更新:关键词→target 映射、同名异义高危登记、`_legacy/` 隔离标注。
- [ ] 规则/skill 自身描述若被代码改动证伪,已同次校准(规则与代码同源)。
- [ ] 新增规则已按 `../hecateflow/references/auto-injection.md` 四处同步(rule 文件 + instructions + 触发表 + 镜像入口)。
- [ ] 文档/规则治理已按 `../hecateflow/references/orchestration-contract.md` 分档;L1+ 已主动只读复核。仅在平台/工具不可用或宿主策略限制时,主 agent 才可降级自审并已声明限制。
- [ ] 反复出现/多 target 相关的 lesson 已提示升级为规则(衔接 `hf-lessons`)。
- [ ] 临时计划文件(INTEGRATION_PLAN.md)在任务完成后已删除,经验沉淀进 PROJECT.md / lesson。

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

- `../references/tiered-docs.md`(三层分级 + 完整同步矩阵 + 多工程 + 不再犯回路索引,本 skill 的基线)。
- `../hecateflow/references/auto-injection.md`(新增规则的四处注入)、`../references/git-discipline.md`(同次提交纪律)。
- `../hecateflow/references/orchestration-contract.md`(规则治理分档 / 复审链 / Git 确认门)。
- `hf-lessons`(经验记忆衔接 / 升级阶梯)、`hf-hw-mapping`(引脚/极性/PINOUT 同步)、`hf-build-sync`(源文件→构建图+LSP 同步)。
- `../hecateflow/templates/PROJECT.md.tmpl`、`hf-init-project`(建初版 PROJECT.md + 纲领路由资产)、`hf-implement`(改代码时同步)、`hf-auto-workflow`(第 5 步文档同步检查)。
