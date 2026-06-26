---
name: hf-init-workspace
description: >
  交互式初始化一个嵌入式开发工作区:探测/询问 MCU 家族、架构、工具链、构建系统及其文件登记方式、
  源语言/编码、文档位置;采集固化工程应用场景(domain/约束/安全规则/禁止项),询问是否用 clangd,
  搭建规则/skill 自动注入(入口文件 + instructions 列表 + 可选 hook),生成持久化工程清单
  .hecateflow/project.json + 开发纲领 workspace-guide。MCU 无关,一次性,路径默认相对。
  触发:初始化工作区 / 新建 hecateflow / 工程脚手架 / 第一次用 hecateflow / 固化场景 / 自动注入 /
  init workspace / bootstrap embedded workspace。
license: MIT
argument-hint: "[workspace-path]"
metadata:
  compatibility: claude-code codex
  version: 1.1.0
  layer: lifecycle
---

# hf-init-workspace — 交互式工作区初始化 / Interactive Workspace Init

为一个嵌入式工作区建立 HecateFlow 的"交互记忆基座":持久化工程清单 `.hecateflow/project.json` + 一份开发纲领 + 自动注入入口。一个工作区只跑一次;之后所有 skill 靠这份 manifest 做默认值。本次(v1.1)在原"探测+询问+生成 manifest"基础上,新增四件**奠基性**采集/搭建:**固化场景**(点 1)、**clangd 询问**(点 10)、**自动注入搭建**(点 9)、**相对路径默认**(点 12)。

## 适用 / 不适用

- 适用:工作区还没有 `.hecateflow/project.json`、第一次接入 HecateFlow。
- 不适用:已有 manifest(改配置直接编辑 manifest 或跑 `hf-init-project` 加 target)。

## 触发关键词

初始化工作区 / 工程脚手架 / 第一次用 / 固化场景 / 自动注入 / init workspace / bootstrap。

## 第一性原则

**先探测,再询问,只问探测不到的;一次把"常驻上下文"奠基好。** 工作区里的工程文件(`.ewp`/`CMakeLists.txt`/`Makefile`/`.uvprojx`/`platformio.ini`)已经透露了构建系统与目录结构;agent 应主动读出来预填,把用户的交互负担降到最低。探测结果必须经用户确认再写入,不擅自定论。除构建事实外,还有三类**写一次、常驻受益**的信息必须在初始化时奠基,否则后续每个无上下文 agent 都要重新摸索:① **场景**(为什么这样设计,免每会话重述)、② **注入通道**(规则/skill 怎么被自动加载,否则规则形同虚设)、③ **路径纪律**(相对路径,否则换机即坏)。

## 红线

- **不搭自动注入就交付**:只生成 manifest 不写入口文件/不登记 instructions → 规则与 skill 没有任何 CLI 会自动加载,等于白写(见 `skills/hecateflow/references/auto-injection.md`)。
- **覆盖用户已有纲领**:工作区已有 `CLAUDE.md`/`AGENTS.md` 时**只补 manifest 与镜像登记,不覆盖正文**,丢失既有约定。
- **场景全靠猜**:`workspace.scenario` 的约束/安全规则/禁止项是**用户领域知识**,探测不到就必须问,不自行编造(编出来的"安全规则"比没有更危险)。
- **clangd 默认开**:未问就假定用 clangd → 后续 `hf-build-sync` 维护一堆 `.clangd -I` 而用户根本不用,徒增噪声;反之假定不用则虚假红线无人管。**必须显式问**。
- **manifest 写绝对机器路径**:任何路径字段(headers/docPath/lessons/instructionsFiles)写 `<盘符>:\...` → manifest 不可跨机移植。`paths.preferRelative` 恒 true,全部相对。

## 执行流程

### 第一阶段:探测(只读,不问)

1. 扫工作区根:用 Glob 找 `**/*.ewp`、`CMakeLists.txt`、`Makefile`、`*.uvprojx`、`platformio.ini` → 推断 `buildSystem.type` 与 `autoDiscover`。
2. 扫已有源目录与可能的多核结构(子目录命名、芯片型号串),预填候选 `targets`;若已存在 `CLAUDE.md`/`AGENTS.md`/`README` 读其架构段做场景预填素材。
3. 扫是否已有 `.clangd` / `compile_commands.json`(有 → clangd 询问的推荐项预设为"是")、是否有 `opencode.json`(有 → 自动注入已有半套)。

### 第二阶段:询问(AskUserQuestion,每问 ≤3 项,给探测值作推荐选项)

4. **构建与语言**:MCU 家族 / 架构 / 工具链(探测到则确认);源语言 / 编码(默认 C / UTF-8 无 BOM);构建系统**文件登记方式**(`registration.*`:工程文件 glob、源节点、include 字段、LSP 配置)。
5. **固化场景(点 1 → `workspace.scenario`)**:采集这四项,作"为什么这样设计"的常驻上下文——
   - `domain`:工程做什么(自由文本,如"智能车麦轮底盘 + 悬停飞机")。
   - `constraints[]`:硬约束(如"飞机↔车模禁无线、仅有线链路""车不可离地")。
   - `safetyRules[]`:安全规则(如"PWM 必须钳幅 ±LIMIT""ISR 禁阻塞/禁浮点密集""饱和持续→失控锁定")。
   - `forbidden[]`:禁止项(如"禁动态内存/递归""禁 `git add .`""禁跨核同步相机分辨率")。
   - 这些后续被**全部业务 skill 只读**;采集不全不阻塞(留空则对应 skill 退化为"每次问")。
6. **是否用 clangd(点 10 → `workspace.lsp`)**:显式问"本工作区是否用 clangd 做补全/索引?"
   - 是 → `clangd:true` + 追问 `configStyle`:优先 `compile_commands.json`(CMake/bear 自动生成,免手维护 `-I`)/ `.clangd-manual-I`(手维护 `-I`)/。`hf-build-sync` 据此决定是否成对维护 LSP 配置。
   - 否 → `clangd:false`,后续构建同步跳过所有 `-I`/`.clangd` 步骤。
7. **Git**:提交格式、远端(多远端则全列,提交后须全推)、默认分支;`neverAddAll` 恒 true。
8. **文档与检查**:文档纲领位置;共享库版本表/术语/引脚表(可空);激活哪些 `activeChecks`(默认全开,含 `polarityMagnitude`/`relativePaths`/`ioOwnership`/`lessonsCapture`)。

### 第三阶段:生成与搭建(写)

9. **写 manifest**:用 `templates/manifest.json` 为骨架,填好后写 `.hecateflow/project.json`(读-改-写 + 按 `skills/hecateflow/references/manifest-schema.md` 校验)。**`paths.preferRelative:true`、所有路径字段填工作区相对路径**。
10. **生成开发纲领**:用 `templates/workspace-guide.md.tmpl` 生成 `CLAUDE.md`(若已存在则只补 manifest 与镜像登记,不覆盖);填入第 5 步的场景作"架构总览/约束"段。
11. **搭建自动注入(点 9 → `autoInjection`,引 `skills/hecateflow/references/auto-injection.md`)**:
    - 写纲领入口 `CLAUDE.md` 与 `AGENTS.md`(同源镜像,含场景/target 识别/git 流程/相对路径纪律);登记 `mirrorPairs:[{a:"CLAUDE.md",b:"AGENTS.md"}]`。
    - 建 `.claude/rules/` 目录 + `README.md` 触发表(放场景化检查规则,分级见 `skills/references/tiered-docs.md`)。
    - 若用 OpenCode:生成/更新 `opencode.json`,把 `.claude/rules/*.md` 全列入 `instructions[]`;登记到 `autoInjection.instructionsFiles`。
    - 可选 hook:若 harness 支持(Claude Code `settings.json`),加 `PostToolUse` 在编辑 `.c/.h` 后触发 `hf-auto-workflow`;登记 `autoInjection.hooks`。无 hook 时退化为"纲领文档命令 agent 每次编辑后自律执行"。
12. **校验注入闭环**:验证新会话能否在不手动 `@` 的情况下命中规则(让 agent 复述"编辑某 `.c` 前要做什么",应自动复述 auto-workflow 步骤)。
13. 提示下一步:对每个核/芯片跑 `hf-init-project`。

## 交互要点

- targets 可先留空或只填一个;后续用 `hf-init-project` 增量补。
- 探测不确定的字段宁可问,不要猜(尤其构建是否 autoDiscover、登记入口在哪、是否用 clangd)。
- 场景的安全规则/禁止项是后续所有安全审查的依据,问清楚比问全更重要。

## PASS/FAIL 清单

- [ ] `.hecateflow/project.json` 通过 schema 校验(`version`+`workspace`+≥0 targets)。
- [ ] `buildSystem.type` 与 `autoDiscover` 经用户确认。
- [ ] `workspace.scenario` 四项(domain/constraints/safetyRules/forbidden)经用户提供,未自行编造。
- [ ] `workspace.lsp.clangd` 已**显式询问**并据答填 `configStyle`,未默认假定。
- [ ] `autoInjection` 已搭建:写了 `CLAUDE.md`+`AGENTS.md`(镜像登记)、建了 `.claude/rules/` + 触发表;用 OpenCode 则 `instructions[]` 已登记。
- [ ] `paths.preferRelative:true`;manifest 内所有路径为工作区相对,无绝对机器路径。
- [ ] 探测到的值都以"推荐选项"呈现而非默认写入。
- [ ] 未覆盖工作区已有的开发纲领正文(只补 manifest/镜像)。
- [ ] `encoding` 等写入项符合目标工具链(默认 UTF-8 无 BOM)。

## 验证

- agent 能做:探测、采集场景、生成 manifest/纲领、搭建注入入口、校验注入闭环。
- 交用户:确认 MCU/工具链/登记方式/场景约束/是否用 clangd 正确(关系到后续所有 skill 的默认值与自动加载)。

## 反面教训

- 不探测直接问一堆问题 → 用户烦,且容易和工程文件实际不符。
- 猜 `autoDiscover` → 猜错则 `hf-build-sync` 要么白跑要么漏登。
- **只生成 manifest 不搭注入** → 规则与 skill 没人自动加载,后续 agent 形同没规则,反复踩同一批坑。
- **未问 clangd 就默认开** → 不用 clangd 的用户被一堆 `.clangd -I` 维护噪声打扰;反之默认关则虚假红线无人管。
- **场景靠编** → 编出的"安全规则/禁止项"误导后续安全审查,比留空更糟。
- 覆盖用户已有 CLAUDE.md → 丢失既有约定。

## 平台差异

- AskUserQuestion:Claude 原生;Codex 用文字编号选项。
- 探测:两端用 Glob/Grep。
- 自动注入:Claude Code 靠 `CLAUDE.md` + skill `description` + 可选 `settings.json` hook;OpenCode 靠 `AGENTS.md` + `opencode.json` 的 `instructions[]`;Codex 靠 `AGENTS.md`。`AGENTS.md` 是跨 CLI 最大公约数(见 `auto-injection.md`)。

## 参考

- `templates/manifest.json`、`templates/workspace-guide.md.tmpl`、`skills/hecateflow/references/manifest-schema.md`。
- `skills/hecateflow/references/auto-injection.md`(自动注入搭建步骤 + 镜像约束 + 各 CLI 对照)。
- `skills/references/tiered-docs.md`(分级文档,决定 `.claude/rules/` 放什么)、`skills/references/git-discipline.md`(git 约定写入)。
- `hf-init-project`(下一步:每 target 跑一次)、`hf-build-sync`(读 `workspace.lsp.clangd`)、`hf-doc-discipline`(维护注入)。
