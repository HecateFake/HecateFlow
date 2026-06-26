---
name: hf-auto-workflow
description: >
  每次编辑源文件后立即自动跑的 6 步轻量审查门:目标确认 → volatile 扫描 → ISR 安全 → 数值安全 →
  风格 → 文档同步。CRITICAL/HIGH 自动修,MEDIUM 列给用户。是 HecateFlow 的 always-on 核心。
  Claude 端可挂 PostToolUse hook,Codex 端编辑后自律调用。触发:自动审查 / 编辑后检查 /
  auto workflow / post-edit review / 每次改完代码。
license: MIT
argument-hint: "[changed-path]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: lifecycle
---

# hf-auto-workflow — 每次编辑自动审查门 / Per-Edit Auto-Review Gate

HecateFlow 的 always-on 核心。每次编辑嵌入式源文件(`project code` 下的 `.c/.h` 等)后**立即、自动、无需用户提示**地跑 6 步审查。轻量、快、即时修——把问题挡在编辑当下,不攒到 review。

## 适用 / 不适用

- 适用:刚 Write/Edit 了源文件之后。
- 不适用:SDK/第三方库文件、文档/脚本/仿真 PC 代码(`tools/` 下)、提交时(编辑阶段已审,提交不重复)。

## 触发

- Claude Code:可配置为 PostToolUse hook(matcher `Write|Edit`),编辑后自动调起(配置片段见 README,opt-in)。
- Codex:无 hook 机制 → 正文约定"每次 Write/Edit 后你必须立即自跑下列 6 步"。
- 关键词:自动审查 / 编辑后检查 / post-edit review。

## 第一性原则

**问题在编辑当下最便宜。** 离开编辑上下文后,定位"哪次改动引入的"成本陡增。所以审查必须紧贴每次编辑,且对 CRITICAL/HIGH 自动修不打断节奏,只对需要决策的 MEDIUM 才打扰用户。

## 6 步审查流程

按序执行,读 manifest `activeChecks` 决定哪几步激活(默认全开):

0. **目标确认**:从文件路径/manifest 提取所属 target;高危同名文件(`hazardFiles`)输出公告;用户上下文与文件所属 target 不符 → 停止并询问。
1. **volatile 扫描**:本次涉及的全局变量,若被 ISR 读写或被另一核访问而缺 `volatile` → CRITICAL,自动加。
2. **ISR 安全**:若改了 ISR,禁止新增 `printf`/LCD/串口/阻塞 `while`/动态内存/不可预测耗时函数 → CRITICAL,自动修。
3. **数值安全**:除零保护缺失、整型可能溢出、PID 无积分限幅、执行器输出无钳位 → HIGH,自动修(委派 `hf-embedded-safety` 视角)。
4. **风格**:命名/固定宽度类型/浮点 `f` 后缀/UTF-8 无 BOM/条件编译(见 `references/embedded-c-style.md`)→ MEDIUM,提示不自动改。
5. **文档同步**:触发同步的改动(模块增删/语义/参数/边界/共享库)而 PROJECT.md 没跟 → HIGH,提示补(委派 `hf-doc-discipline`)。

## 严重级别与行动

| 级别 | 行动 |
|------|------|
| CRITICAL | 立即自动修,不询问 |
| HIGH | 立即自动修,不询问 |
| MEDIUM | 列出,由用户决定 |
| LOW | 静默忽略 |

## 输出(一行摘要)

- 全过:`✓ 审查通过,无问题`
- 有修:`✓ 审查完成,自动修复 N 个(CRITICAL×a, HIGH×b)`
- 待决:`⚠ 审查完成,N 个 MEDIUM 待确认:...`

## PASS/FAIL 清单

- [ ] 6 步按激活项全跑过(未跳过激活的步)。
- [ ] CRITICAL/HIGH 已自动修,无遗留。
- [ ] 目标 target 与用户上下文一致(不符已停并问)。
- [ ] 未审查 SDK/第三方/仿真 PC 代码。
- [ ] 输出了一行摘要。

## 不做的事

- 不触发 planner/architect 类重流程(轻量门)。
- 不在 `git commit` 时重复(编辑阶段已审)。
- 不审 SDK/第三方库;不加 Doxygen 注释。

## 反面教训

- 跳过目标确认 → 在错误 target 改了同名文件,语义全错。
- 把"漏 volatile"当 MEDIUM 拖着 → 偶发读旧值的幽灵 bug,极难复现。
- 编辑后不审、攒到提交 → 一次提交里多个 CRITICAL,定位困难。

## 平台差异

- 自动触发:Claude PostToolUse hook(harness 强制);Codex 靠 prompt 自律(无 hook)。
- 委派安全/文档检查:Claude `Skill`/`Task`;Codex 原生加载/`spawn_agent`。

## 参考

- `hf-embedded-safety`、`hf-doc-discipline`、`references/embedded-c-style.md`、`hf-implement`(每编辑后调本 skill)、`hf-review`(深度版)。
