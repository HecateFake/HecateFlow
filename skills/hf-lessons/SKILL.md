---
name: hf-lessons
description: >
  工程经验记忆与"不再犯"回路:踩坑/被纠正/确认的好做法 → 写 lesson 到本地 .hecateflow/lessons/
  (frontmatter type/trigger + 症状/根因/如何避免)+ 维护 INDEX;相关编辑前先检索命中→规避;
  反复出现升级为规则,可机械检查的并入 auto-workflow。本地存储跨平台(Claude Code / Codex 都能读),
  区别于 harness 私有 memory。MCU 无关。触发:经验记录 / 踩坑 / 教训 / 不再犯 / lesson / 复盘 /
  被纠正 / 好做法沉淀 / lessons learned / pitfall / postmortem / don't repeat / record mistake。
license: MIT
argument-hint: "[record|recall|promote|prune] [slug]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-lessons — 工程经验记忆 / 不再犯回路 / Lessons & Never-Repeat Loop

无上下文的 agent 每次会话都从零开始,**最贵的代价是反复踩同一个坑**:这次会话学到"GBK 误读产生 U+FFFD 扫描漏判""极性藏 Kp 负号致失控""ICF 注释中文崩链接器",下次清空上下文换个 agent 又从头犯一遍。本 skill 把这些硬经验固化为**本地、跨平台、可检索的 lesson 文件**,并定义一条**升级阶梯**:从"记一条"到"编辑前检索规避",再到"升为规则/并入自动检查",让经验真正"不再犯",而不是停在一句口头总结。被 `hf-implement`(修 bug 时触发记录)、`hf-auto-workflow`(编辑后检索/记录)、`hf-doc-discipline`(衔接同步矩阵)引用,也可单独调用("把这个坑记下来""有没有相关教训")。

## 与 hf-doc-discipline 的边界(必读,勿重复)

两者都"管文档",但维度不同,职责不重叠:

| | hf-doc-discipline | **hf-lessons(本 skill)** |
|--|-------------------|--------------------------|
| 管什么 | **当下这次提交**:代码改了 → PROJECT.md / 版本登记 / 通信表跟上(同步矩阵) | **跨会话记忆**:这次踩的坑/被纠正/好做法 → 下次别再犯(经验沉淀与复用) |
| 文档对象 | `PROJECT.md`、`docs/*`、`LIBRARY_VERSIONS.md`(真相源投影) | `.hecateflow/lessons/<slug>.md` + `INDEX.md`(经验记忆) |
| 时机 | 改代码的同次提交 | 踩坑/被纠正时记录;**相关编辑前**检索 |
| 一句话 | 文档跟上代码(**同步**) | 坑别再踩(**记忆**) |

衔接点:lesson **反复出现或多 target 相关 → 升级为 `.claude/rules` 段**,此后该规则的"代码改动→规则校准"重新归 `hf-doc-discipline` 的同步矩阵管。`references/tiered-docs.md` 的"不再犯回路"是两者共同的索引,本 skill 是它的**主实现**;doc-discipline 只引用、不复述。

## 适用 / 不适用

- 适用:踩了非显而易见的坑、被用户纠正了做法、确认了一个有效的好做法、修复了一个会复发的 bug、发现某经验多 target 通用值得升级。
- 不适用:一次性会话细节(排查过程/临时调试)、代码结构本身已记录的事实(进 PROJECT.md 而非 lesson)、纯个人偏好(进 manifest 或 rule)。**lesson 记"机制级、会复发、规避动作明确"的经验,不记流水账。**

## 触发关键词

经验记录 / 踩坑 / 教训 / 不再犯 / 复盘 / 被纠正 / 好做法沉淀 / lesson / lessons learned / pitfall / postmortem / don't repeat / record mistake / recall lesson。

## 第一性原则

**经验若不落成可检索、可复用的本地工件,就等于没学到。** 三条推论:

- **记忆要跨平台、跟工作区走,不绑 harness。** 经验存**工作区本地** `.hecateflow/lessons/`,Claude Code、Codex 及任何 agent 都能读;不依赖某个 harness 的私有 memory(那是单平台、单机、易丢)。工作区换人/换机/换工具,经验仍在仓库里。
- **"不再犯"是回路不是记录。** 光记不查 = 白记。回路闭合需要:记录 → **编辑前主动检索** → 命中则规避 → 反复出现则升级到更强约束(规则/自动检查)。缺任一环,同类坑必复发。
- **一条 lesson 必须能被未来的自己/他人凭关键词命中并立即规避。** 所以 frontmatter 的 `trigger`(中英关键词)和"如何避免"的可执行动作是 lesson 的核心,症状要具体到可搜索。

## 红线(最易翻车)

- **记了从不升级**:lesson 写完就躺在目录里,从不在编辑前检索、反复出现也不升为规则 → "不再犯"沦为空话,换个 agent 又踩。**记录的同时必须判断升级路径**(见"升级阶梯")。
- **当流水账写**:把一次性排查过程、会话细节、显而易见的代码事实塞进 lesson → 索引膨胀、检索噪声大、真正的硬经验被淹没。lesson 只记**机制级、会复发**的经验。
- **症状写得检索不到**:"出了个 bug 修好了"这种 lesson 未来没人能凭关键词命中。**症状必须具体**(报什么错/什么现象),`trigger` 必须含未来会触发的中英关键词。
- **同类坑反复新建文件**:同一机制的坑每次新建一条 → 经验碎片化。**先检索同类,有则更新该文件**(去重),不新建。
- **存进 harness 私有 memory 当唯一副本**:绑死单平台,换工具/换机即丢,Codex 读不到 Claude 的 memory。**本地 lessons 为唯一权威副本**,harness memory 至多是可选镜像。

## 一、何时记录(record)

满足任一即记一条 lesson:

- **踩坑(pitfall)**:遇到非显而易见的失败——编译/链接报错、运行失控、屏幕乱码、行为不符预期,且根因有复用价值(机制级、换场景会再遇)。`type: pitfall`。
- **被纠正(correction)**:用户纠正了你的做法(用错抽象、违反某约定、方向反了)。把"被纠正的点 + 正确做法"记下。`type: correction`。
- **确认的好做法(good-practice)**:验证了一个有效模式(某重构手法、某调试切入点、某安全门控放置),值得下次复用。`type: good-practice`。

判据:**这条经验下次相关编辑时若不想起来,会重新犯错或重新摸索吗?** 是 → 记;否(一次性/显而易见)→ 不记。

## 二、lesson 文件结构 + 维护 INDEX

### 单条 lesson(模板 `templates/lesson.md.tmpl`)

放 `.hecateflow/lessons/<slug>.md`,`<slug>` 用 kebab-case 概括(如 `gbk-utf8-fffd-scan-miss`、`icf-ascii-only`)。frontmatter + 三段正文:

- **frontmatter**:`name`(=slug)、`type`(pitfall/correction/good-practice)、`trigger`(**何种编辑/操作前应想起本条,中英关键词**,检索靠它)、`target`(某 target ID 或 `all`)、`severity`(critical/high/medium)、`status`(active/superseded)、`created`(YYYY-MM-DD)。
- **症状(怎么暴露的)**:具体到可被搜索命中的现象。
- **根因(为什么会这样)**:第一性机制,不停在表象。
- **如何避免(下次怎么不再犯)**:可执行规避动作 + **升级路径**(仅留 lesson / 升为 rule 段 / 并入 auto-workflow)。

### 索引 INDEX.md(模板 `templates/lessons-index.md.tmpl`)

`.hecateflow/lessons/INDEX.md` 是全部 lesson 的速查表,**相关编辑前先扫它**。每条 lesson 在"索引"表加一行(slug/type/target/trigger 命中场景);升级为规则的另列入"已升级为规则的"表。manifest `lessons.dir` / `lessons.index` 指向这两处。

> 与 harness 私有 memory 的"MEMORY.md 索引"形态相似,但本 INDEX 在**工作区仓库内**、跨平台、随 git 走。

## 三、不再犯回路(核心)— 编号流程

```
record → recall → avoid → promote
 记录  → 检索  → 规避  → 升级
```

1. **record(记录)**:命中"何时记录"任一条 → 用 `templates/lesson.md.tmpl` 新建 `<slug>.md`,在 `INDEX.md` 加一行。修 bug 场景由 `hf-implement` 收尾时触发;`activeChecks.lessonsCapture:true` 时 `hf-auto-workflow` 在踩坑/被纠正后提示记录。
2. **recall(检索)**:**相关编辑前先按 target / trigger 关键词扫 `INDEX.md`** → 命中则读对应 lesson。这是回路最易被省略、却最关键的一环:不查 = 白记。
3. **avoid(规避)**:按命中 lesson 的"如何避免"动作执行,绕开已知坑。
4. **promote(升级)**:判断该经验是否该升到更强约束:
   - **多 target 相关 / 反复出现** → 升为 `.claude/rules/<name>.md` 的"禁止/反面教训"段(并按 `auto-injection.md` 登记到 instructions 列表 + rules/README 触发表 + 镜像入口)。升级后在 INDEX"已升级"表记一行,原 lesson 标 `status: superseded`(或保留并注明已入规则)。
   - **可机械检查**(如"ICF 改后跑 `LC_ALL=C grep` 验 ASCII""新源文件须进构建工程 + LSP") → 并入 `hf-auto-workflow` 的审查步骤,自动拦截,不再仅靠人工检索。
   - **仅单点、低频** → 留作 lesson 即可,不强行升级(避免规则膨胀)。

升级阶梯本质:**检索靠人(易漏)→ 规则靠注入(每次加载)→ 自动检查靠工具(机械拦截)**,越往上越可靠。能升则升,是"不再犯"从口号变机制的关键。

## 四、去重与删除失效(prune)

- **去重**:记录前先检索同类。同一机制已有 lesson → **更新该文件**(补症状/收紧规避/改 severity),**不新建**。同一坑两条文件 = 经验碎片化,检索命中其一漏其二。
- **删除/废弃失效**:代码演进使某 lesson 不再成立(坑已根治、机制已变)→ 标 `status: superseded` 并在正文注明被谁取代,或直接删除并从 INDEX 移除。**失效 lesson 留着会误导**(下个 agent 按已不存在的坑规避,做无用功)。
- **升级后的处置**:已升为 rule/auto-workflow 的 lesson,原文件标 superseded 或保留作溯源,INDEX 主表移到"已升级"表,避免"既靠检索又靠规则"的双轨混乱。

## 五、与 Claude 原生 memory 的关系(本地为主、跨平台、可选导出)

- **本地 lessons 为唯一权威副本**:`.hecateflow/lessons/` 在工作区仓库内,随 git 走,Claude Code / Codex / 任何 agent 都能读。这是经验的**真相源**。
- **harness 私有 memory 是可选镜像,不是替代**:Claude Code 的 `~/.claude/.../memory/` 是单平台、单机、不随仓库走的;它适合存"跨工程的用户偏好/工作习惯",**不适合**存"本工作区的工程坑"(Codex 读不到、换机即丢)。
- **可选导出(说明,不强制)**:若希望某条工程 lesson 也在 Claude 原生 memory 出现(便于跨工程联想),可**手动**把它摘成一条 memory 并在 MEMORY.md 索引登记——但**以本地 lessons 为准**,memory 仅作便捷镜像,二者冲突时信本地 lessons。反向(把通用用户偏好塞进工作区 lessons)不推荐:那不是工程经验。

## PASS/FAIL 对抗审查清单

逐项 PASS/FAIL + 依据,任一 FAIL 先修再交付:

- [ ] **该记的记了**:本次会话的踩坑/被纠正/确认好做法,机制级且会复发的,已落成 lesson。
- [ ] **症状可检索**:症状具体到现象级(报什么错/什么表现),未来能凭关键词命中。
- [ ] **trigger 含中英关键词**:frontmatter `trigger` 覆盖未来相关编辑会用到的措辞。
- [ ] **根因到机制**:根因说清第一性机制,没停在"改一下就好了"的表象。
- [ ] **规避可执行**:"如何避免"是具体动作(编辑前确认什么/改后跑什么),不是空泛原则。
- [ ] **升级路径已判**:每条标明"仅 lesson / 升 rule / 并入 auto-workflow",反复/多 target 的已升级并登记。
- [ ] **去重**:同类已有 lesson 时更新而非新建;无重复文件。
- [ ] **失效已清**:不再成立的 lesson 已标 superseded 或删除,未留误导。
- [ ] **INDEX 同步**:新增/升级/废弃均已在 `INDEX.md` 反映(含"已升级"表)。
- [ ] **本地为权威**:经验存 `.hecateflow/lessons/`,未把唯一副本只放进 harness 私有 memory。
- [ ] **相对路径**:lesson 内引用工程文件用工作区相对路径(`config/configMotor.h`);绝对机器路径仅出现在标注的"源工程案例出处"。

## 验证(agent 能做的 + 必须交给用户的)

- agent 能做:判定某经验是否够格记为 lesson、起草 lesson 文件、维护 INDEX、检索命中、判定去重/失效、提出升级建议(升 rule / 并入 auto-workflow)。
- **必须交用户**:① 把 lesson **正式升级为 `.claude/rules` 规则**前确认(规则影响所有 agent,且需同步注入列表/触发表/镜像入口,见 `auto-injection.md`);② 删除一条 lesson 前,若不确定坑是否真已根治,先标 `superseded` 并问用户,**不擅自删可能仍有效的经验**(对齐 git-discipline"不回退他人改动"精神);③ 导出到 harness 原生 memory 由用户决定,不自动写。

## 反面教训(具体案例)

- **记了从不查**:某工作区攒了十几条 lesson,但 agent 编辑前从不扫 INDEX,同类坑(GBK 编码、ICF ASCII)换会话又踩。教训:**recall 是回路的命脉**,记录的价值全在被检索到;auto-workflow 应把"编辑前检索 lessons"列为步骤。
- **lesson 当流水账**:把一次性排查过程("试了 A 不行,试了 B 才好")整段塞进 lesson → 索引噪声淹没真经验。教训:只记机制级根因 + 可执行规避,过程留在会话里。
- **同坑多文件**:"极性"相关经验散成三条 lesson,检索命中其一漏其二 → 改极性时只规避了部分。教训:**先检索后记录**,同机制更新单一文件。
- **失效 lesson 误导**:某坑早已被重构根治,lesson 没删,新 agent 仍按它绕路做无用功甚至引入新问题。教训:代码演进时同步清理/标记失效 lesson(与 doc-discipline 同次提交校准同理)。
- **只存 harness memory**:经验只写进 Claude 私有 memory,换到 Codex 后完全读不到,等于没记。教训:**本地 lessons 为唯一权威副本**,跨平台才是经验记忆的意义。

## 平台差异

- **存储位置统一**:`.hecateflow/lessons/` 在工作区内,Claude Code / Codex 用各自原生读写工具(Read/Write 或等价)操作 markdown,**无平台特异逻辑**——这正是选本地存储而非 harness memory 的原因。
- **触发记录**:`activeChecks.lessonsCapture:true` 时,Claude Code 可挂 PostToolUse hook 在踩坑/被纠正后提示记录;Codex 端编辑后由 agent 自律调用本 skill。两端均由 `hf-auto-workflow` 统一编排(见该 skill 审查步骤)。
- **升级为规则的注入**:升 rule 后的自动加载方式各 CLI 不同(Claude Code 靠 CLAUDE.md/skill description;OpenCode/Codex 靠 instructions 列表),详见 `../hecateflow/references/auto-injection.md`,本 skill 只负责"判定该升级",注入由该 reference 落地。
- **可选导出 memory**:仅 Claude Code 有原生 memory 概念;Codex 无,直接以本地 lessons 为准。导出是 Claude 端的可选便捷,不影响跨平台权威性。

## 参考

- 模板:`templates/lesson.md.tmpl`(frontmatter type/trigger + 症状/根因/如何避免)、`templates/lessons-index.md.tmpl`(INDEX + 已升级表)。
- `references/tiered-docs.md`(分级文档的"不再犯回路"索引,本 skill 是其主实现)。
- `hf-doc-discipline`(边界见上:doc 管同步、lessons 管记忆;升级后的规则校准归 doc-discipline 同步矩阵)。
- `hf-implement`(修 bug 收尾触发记录)、`hf-auto-workflow`(编辑前检索 + 编辑后记录,`activeChecks.lessonsCapture`)。
- `hf-hw-mapping`/`hf-embedded-safety`(极性/数量级/IO 归属类 lesson 的"升级去向"常落在这两个 skill 引用的规则段)。
- 升级注入:`../hecateflow/references/auto-injection.md`;同次提交纪律:`references/git-discipline.md`。
- manifest 字段:`lessons.dir` / `lessons.index` / `activeChecks.lessonsCapture`(见 `skills/hecateflow/references/manifest-schema.md`)。
- 源工程经验记忆形态参考(只读出处):`D:\car\iarCode\core` 工作区的 harness memory(`iar-icf-ascii-only`、`core2-motor-runaway-protection` 等条目即 type/trigger + 症状/根因/如何避免 的实际写法)。
