# 分级分布式文档 + 自动进化同源 / Tiered docs (reference)

> 被 `hf-doc-discipline`(主)、`hecateflow`(多工程管理)、`hf-init-workspace`/`hf-init-project`(生成文档骨架)引用的基线。非独立 skill。
> 对应经验点 2(多工程管理)、4(分级省上下文)、3+7(自动进化/不再犯)。

## 第一性原则

上下文是稀缺资源。把所有工程知识塞进一个大文件,每次会话全量加载 → 烧光上下文且找不到重点。解法是**三层分级 + 按需下钻**:冷启动只读纲领,定位到目标后才下钻该处的单一真相源,命中具体场景才读对应规则。文档不是写一次的静态档案,而是**随代码同次提交校准**的活系统。

## 三层分级

| 层 | 文件 | 内容 | 何时读 |
|----|------|------|--------|
| ① 纲领 | `CLAUDE.md`/`AGENTS.md`、`docs/README.md`、`docs/*`(PINOUT/GLOSSARY/LIBRARY_VERSIONS) | 行为规则 + 场景 + target 识别 + 跨 target 拓扑/通信表 + 导航 | **每次冷启动**(harness 自动注入纲领入口) |
| ② 核内真相源 | 各 target 的 `PROJECT.md` | 状态卡 / 模块清单 / 边界(ISR 时序、参数、物理常量、接口)/ 验证清单 | **定位到某 target 后下钻** |
| ③ 场景规则 | `.claude/rules/*.md` + 临时 `INTEGRATION_PLAN.md` | 场景化检查清单(安全/构建同步/外设归属/极性...) + 一次性多阶段计划 | **命中具体场景时** |

**冷启动下钻路径**:读纲领 → 关键词/路径定位 target → 读该 target 的 `PROJECT.md` → 命中场景读对应 rule。`docs/README.md` 做"我想做 X 看哪份"的导航表,避免盲目全量读,省上下文。

## 多工程(多 target)管理(点 2)

单工作区多个独立可构建 target 时,纲领层必须提供:

- **关键词 → target 映射表**:用户措辞(如"麦轮/底盘/编码器"→core2)直接路由到目标核,免逐个翻。
- **同名异义高危文件登记**:`motor.c`/`IMU.c`/`PID.c` 等在不同 target 语义完全不同,编辑前**公告所选 target**(`目标:<target>/<file>(<语义>)`)。manifest `targets[].hazardFiles`。
- **共享库版本登记**:同名通用库(滤波/PID/数学工具)在多 target 各有副本并独立演进时,登记到 `docs/LIBRARY_VERSIONS.md`。判定口径:**真落后**(该跟进没跟进 → 待对齐)vs **有意裁剪**(按需增删 → 标注保留),不一刀切按函数数量统一。
- **归档隔离**:下线代码进 `_legacy/`,纲领标注"仅供参考、不复用",防 agent 误用旧版本。

## 自动进化同源(点 3)— 代码改动 → 必同步文档矩阵

代码改动后,按类型在**同次提交**内同步对应文档(缺失同步 = 文档漂移,禁止累积):

| 代码改动 | 必同步 |
|----------|--------|
| 新增/删除/重命名模块文件 | 该 target `PROJECT.md` 模块清单 + 构建工程文件(.ewp/CMake)+ LSP 配置 |
| 高危文件语义变更 | `PROJECT.md` + 纲领 `CLAUDE.md`/`AGENTS.md` + 对应 rule |
| 新增/切换编译期模式 | `PROJECT.md` 模式段 + rule 切点清单(见 hf-design-module) |
| 改跨 target 通信协议/帧格式 | 纲领通信表 + `docs/PINOUT.md` + 两端 target PROJECT.md |
| 改引脚/硬件映射 | `pinMap.h` → `docs/PINOUT.md` 冲突矩阵(先改头再更新矩阵) |
| 改极性/方向系数 | `configHeader` §极性段注释 + 提醒用户核实接线(见 hf-hw-mapping) |
| 改/同步共享库 | `docs/LIBRARY_VERSIONS.md` |
| 新增规则 | rule 文件 + `instructions[]` + rules/README 触发表 + 镜像入口(见 auto-injection.md) |

**规则/skill/术语与代码同源**:代码改动使某 rule/skill/术语描述失效 → 同次提交校准,与 PROJECT.md 同等约束。

## 不再犯回路(点 7,与 hf-lessons 衔接)

经验沉淀的升级阶梯:

1. 踩坑/被纠正/确认好做法 → 写 lesson 到 `.hecateflow/lessons/<slug>.md`(frontmatter type/trigger + 症状/根因/如何避免)+ 登记 `INDEX.md`。
2. 相关编辑前先检索 lessons 命中 → 规避。
3. **多 target 相关或反复出现** → 升级为 `.claude/rules/` 的"禁止/反面教训"段(并按 auto-injection 登记注入)。
4. **可机械检查** → 并入 `hf-auto-workflow` 的审查步骤,自动拦截。

详见 `hf-lessons`。

## PASS / FAIL(文档健康度自查)

- [ ] 纲领层有 关键词→target 映射 + 同名高危文件登记 + 导航表。
- [ ] 每个 target 有 `PROJECT.md` 且是该核单一真相源(状态/模块/边界/验证)。
- [ ] 本次代码改动按"同步矩阵"在同次提交更新了对应文档/规则/术语。
- [ ] 新增规则已登记注入列表 + 触发表 + 镜像入口。
- [ ] 反复踩的坑已升级为 rule/auto-workflow 检查,不只停在 lesson。

## 反面教训

- 所有知识塞一个 `CLAUDE.md` 巨文件 → 每会话烧光上下文还抓不住重点。分级是为省上下文,不是为整齐。
- 改了协议只更新一端 PROJECT.md,纲领通信表不动 → 下个 agent 按旧帧格式改另一端,链路对不上。
- lesson 记了但从不升级为 rule → 同类坑换个 agent 又踩,"不再犯"沦为空话。
- 共享库强行"统一"把有意裁剪的版本覆盖回臃肿版 → 破坏按需演进。

## 参考

- 经验记忆:`hf-lessons`、`templates/lesson.md.tmpl`、`templates/lessons-index.md.tmpl`
- 注入:`../hecateflow/references/auto-injection.md`
- git 同次提交:`git-discipline.md`
- 文档纪律主 skill:`hf-doc-discipline`
