---
name: hf-init-workspace
description: >
  交互式初始化一个嵌入式开发工作区:探测/询问 MCU 家族、架构、工具链、构建系统及其文件登记方式、
  源语言/编码、文档位置,生成持久化工程清单 .hecateflow/project.json + 开发纲领 workspace-guide。
  MCU 无关,一次性。触发:初始化工作区 / 新建 hecateflow / 工程脚手架 / 第一次用 hecateflow /
  init workspace / bootstrap embedded workspace。
license: MIT
argument-hint: "[workspace-path]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-init-workspace — 交互式工作区初始化 / Interactive Workspace Init

为一个嵌入式工作区建立 HecateFlow 的"交互记忆基座":持久化工程清单 `.hecateflow/project.json` + 一份开发纲领。一个工作区只跑一次;之后所有 skill 靠这份 manifest 做默认值。

## 适用 / 不适用

- 适用:工作区还没有 `.hecateflow/project.json`、第一次接入 HecateFlow。
- 不适用:已有 manifest(改配置直接编辑 manifest 或跑 `hf-init-project` 加 target)。

## 触发关键词

初始化工作区 / 工程脚手架 / 第一次用 / init workspace / bootstrap。

## 第一性原则

**先探测,再询问,只问探测不到的。** 工作区里的工程文件(`.ewp`/`CMakeLists.txt`/`Makefile`/`.uvprojx`/`platformio.ini`)已经透露了构建系统与目录结构;agent 应主动读出来预填,把用户的交互负担降到最低。探测结果必须经用户确认再写入,不擅自定论。

## 执行流程

1. 扫工作区根:用 Glob 找 `**/*.ewp`、`CMakeLists.txt`、`Makefile`、`*.uvprojx`、`platformio.ini` → 推断 `buildSystem.type` 与 `autoDiscover`。
2. 扫已有源目录与可能的多核结构(子目录命名、芯片型号串),预填候选 `targets`。
3. 用 AskUserQuestion 补缺失项(每问 ≤3 项,给探测到的值作推荐选项):
   - MCU 家族 / 架构 / 工具链(探测到则确认)。
   - 源语言 / 编码约定(默认 C / UTF-8 无 BOM)。
   - 构建系统的**文件登记方式**(`registration.*`:工程文件、源节点、include 字段、LSP 配置)。
   - 文档纲领位置、共享库版本表/术语/引脚表(可空)。
   - Git 提交格式、远端、默认分支。
   - 激活哪些自动检查(默认全开)。
4. 用 `templates/manifest.json` 为骨架,填好后写 `.hecateflow/project.json`(读-改-写 + schema 校验)。
5. 用 `templates/workspace-guide.md.tmpl` 生成开发纲领(若工作区已有 CLAUDE.md/AGENTS.md 则只补 manifest,不覆盖既有纲领)。
6. 提示下一步:对每个核/芯片跑 `hf-init-project`。

## 交互要点

- targets 可先留空或只填一个;后续用 `hf-init-project` 增量补。
- 探测不确定的字段宁可问,不要猜(尤其构建系统是否 autoDiscover、登记入口在哪)。

## PASS/FAIL 清单

- [ ] `.hecateflow/project.json` 通过 schema 校验(`version`+`workspace`+≥0 targets)。
- [ ] `buildSystem.type` 与 `autoDiscover` 经用户确认。
- [ ] 探测到的值都以"推荐选项"呈现而非默认写入。
- [ ] 未覆盖工作区已有的开发纲领文件。
- [ ] `encoding` 等写入项符合目标工具链(默认 UTF-8 无 BOM)。

## 验证

- agent 能做:探测、生成 manifest 与纲领。
- 交用户:确认 MCU/工具链/登记方式正确(关系到后续所有 skill 的默认值)。

## 反面教训

- 不探测直接问一堆问题 → 用户烦,且容易和工程文件实际不符。
- 猜 `autoDiscover` → 猜错则 `hf-build-sync` 要么白跑要么漏登。
- 覆盖用户已有 CLAUDE.md → 丢失既有约定。

## 平台差异

- AskUserQuestion:Claude 原生;Codex 用文字编号选项。
- 探测:两端用 Glob/Grep。

## 参考

- `templates/manifest.json`、`templates/workspace-guide.md.tmpl`、`skills/hecateflow/references/manifest-schema.md`、`hf-init-project`。
