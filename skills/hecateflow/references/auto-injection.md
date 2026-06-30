# 规则/skill 自动注入机制 / Auto-injection (reference)

> `hf-init-workspace` 搭建、`hf-doc-discipline` 维护的参考。目标:让目标工作区的**规则与 skill 在各 CLI 里被自动加载/发现/调用**,而不是靠人每次手动 `@` 引用。
> 对应经验点 9。配套 manifest 字段:`autoInjection{instructionsFiles[],mirrorPairs[],hooks}`。

## 第一性原则

agent 不会读它没被喂进上下文的规则。"规则写了但没人看"等于没写。所以每条须自动生效的规则,必须挂到某个**会被 harness 自动注入或被关键词自动发现**的入口上。三类注入通道:

1. **入口文件常驻注入**:`CLAUDE.md` / `AGENTS.md` 在每次会话开头进上下文(harness 原生)。纲领级行为规则放这里。
2. **instructions 列表注入**:OpenCode `opencode.json` 的 `instructions[]` 把列出的规则文件自动拼进系统提示。细分技术规则放 `.claude/rules/*.md` 并登记到此列表。
3. **skill description 关键词发现**:skill 的 frontmatter `description` 含触发关键词,agent 命中场景时自动调用。场景化能力做成 skill(本仓即 HecateFlow 自身)。

## 各 CLI 注入方式对照

| CLI | 常驻入口 | 列表注入 | skill 发现 | 自动化 hook |
|-----|---------|---------|-----------|------------|
| Claude Code | `CLAUDE.md`(+ `~/.claude/CLAUDE.md` 全局) | 无原生 list;靠 CLAUDE.md 正文引用 `.claude/rules/*` | `~/.claude/skills/*/SKILL.md` 的 `description` | `settings.json` 的 `PreToolUse`/`PostToolUse`/`Stop` |
| OpenCode | `AGENTS.md` | `opencode.json` 的 `instructions[]`(**核心通道**) | `.opencode/skills/*/SKILL.md` | 插件机制 |
| Codex | `AGENTS.md` | 无 list;靠 AGENTS.md 正文 | `~/.codex/skills/*/SKILL.md` | 无标准 hook |
| Reasonix | `AGENTS.md` | 无 list;靠 AGENTS.md 正文 | `~/.agents/skills/*/SKILL.md` 或 `reasonix.toml`/`config.toml` 的 `[skills].paths` | 当前按无稳定外部 hook 处理 |
| Qoder/QoderCN | `AGENTS.md` | 无 list;靠 AGENTS.md 正文 | `~/.qoder-cn/skills/*/SKILL.md` 或 `~/.qoder/skills/*/SKILL.md` | `settings.json` 的 `PostToolUse` |
| 其它 | 多读 `AGENTS.md` | 视实现 | 视实现 | 视实现 |

> 结论:**`AGENTS.md` 是跨 CLI 最大公约数**。纲领规则同时写入 `CLAUDE.md` 与 `AGENTS.md`(镜像),细分规则进 `.claude/rules/` 并登记 `opencode.json`。

## 镜像约束(mirrorPairs)

`CLAUDE.md` ↔ `AGENTS.md` 内容须一致(行为规则、场景、git 流程、核识别拓扑)。任一改动须同步另一处,否则不同 CLI 看到的规则分叉。manifest `autoInjection.mirrorPairs` 登记所有须镜像的入口对。

**新增一条规则时,四处同步**(缺一即"某 CLI 看不到"):
1. 规则正文写入 `.claude/rules/<name>.md`(细分)或 `CLAUDE.md`+`AGENTS.md`(纲领)。
2. 登记到 `opencode.json` 的 `instructions[]`。
3. 登记到规则索引(`.claude/rules/README.md` 触发表)。
4. 若改了纲领行为 → 同步镜像入口(CLAUDE ↔ AGENTS)。

## 搭建步骤(hf-init-workspace 执行)

1. **写纲领入口**:生成 `CLAUDE.md` 与 `AGENTS.md`(同源,见 `../templates/workspace-guide.md.tmpl`),含场景(`workspace.scenario`)、核识别、git 流程、相对路径纪律。登记 `mirrorPairs: [{a:"CLAUDE.md",b:"AGENTS.md"}]`。
2. **建规则目录**:`.claude/rules/`,放分级文档(见 `../../references/tiered-docs.md`)与场景化检查规则;建 `README.md` 触发表。
3. **建 instructions 列表**:若用 OpenCode,生成/更新 `opencode.json`,把 `.claude/rules/*.md` 全列入 `instructions[]`;登记到 `autoInjection.instructionsFiles`。
4. **Claude Code / Qoder hook**:HecateFlow 安装器默认把 `PostToolUse` hook 写入 `~/.claude/settings.json` 与已初始化的 `~/.qoder-cn/settings.json`/`~/.qoder/settings.json`,在 `Write`/`Edit`/`MultiEdit`/`create_file`/`search_replace` 后注入 `hf-auto-workflow` 提醒;登记到 `autoInjection.hooks`。无 hook 的 CLI 退化为"规则文档命令 agent 每次编辑后执行 auto-workflow"(Codex/Reasonix 即此模式,见 `hf-auto-workflow`)。QoderCN CLI 可用 `qodercncli --with-claude-config` 做 Claude Code 兼容层只读验证。
5. **校验注入闭环**:新会话能否在不手动 `@` 的情况下命中规则。验证法:让 agent 描述"编辑某 `.c` 前要做什么",应自动复述 auto-workflow 步骤。

## 反面教训

- **只写 `.claude/rules/x.md` 不登记 `instructions[]`** → OpenCode 永远看不到该规则,Claude Code 也只在 CLAUDE.md 引用它时才看到。规则形同虚设。
- **CLAUDE.md 改了不同步 AGENTS.md** → 换个 CLId 行为漂移,跨 agent 协作时一个 agent 守规则另一个不守。
- **只靠 hook 强约束** → 换到无 hook 的 CLI 规则落空。hook 是增强不是唯一依赖;核心约束必须同时存在于"文档命令"层(任何 CLI 都读文档)。
- **skill `description` 不含触发关键词** → 永不被自动发现,只能手动调。description 必须中英双语关键词覆盖典型用户措辞。

## 参考

- manifest 字段:`manifest-schema.md` 的 `autoInjection`
- 分级文档:`../../references/tiered-docs.md`
- git 纪律:`../../references/git-discipline.md`
- 维护责任:`hf-doc-discipline`、`hf-init-workspace`
