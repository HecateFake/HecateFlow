# Git 纪律 / Git discipline (reference)

> 被 `hecateflow`(全局红线)、`hf-implement`(收尾)、`hf-init-workspace`(写入目标工程 git 约定)引用的基线。非独立 skill。
> 对应经验点 8。配套 manifest 字段:`git{commitFormat,remotes[],defaultBranch,neverAddAll,confirmationRequired,autoCommitPush}` 与 `interaction.gitConfirmationGate`。

## 第一性原则

嵌入式多核/多人/多 agent 工程里,工作区常同时存在**多方未提交改动**(其它 agent 改了别的核、用户手调了参数/接线)。粗放的 `git add .` + 武断回退会吞掉别人的工作、丢失辨识好的极性/增益。git 纪律的核心是**显式、可溯、不误伤**,且 Git 写权限永远不下放给子代理/worker。

## 红线

1. **禁 `git add .` / `git add -A`**:只 `git add` 本次明确编辑的文件(逐个列)。manifest `git.neverAddAll=true`。
2. **Git 确认门**:实现和验证完成后,主 agent 只能先报告摘要、验证结果、建议提交说明和待暂存文件;必须等用户明确确认后才 stage / commit / push。manifest `git.confirmationRequired=true`,`git.autoCommitPush=false`。
3. **子代理/worker 永不操作 Git**:只读子代理只产证据;写入 worker 即便获准改文件,也不得 stage / commit / push,不得改 `.git` 状态。
4. **不回退非本次改动**:`git status`/`git diff` 发现 agent 本次未编辑的文件被改(尤其参数/配置/`*_DIR` 极性/PID 增益/`*_MODE` 宏)——
   - 落在**别的 target/模块** → 优先视为**其它 agent 并行改动**:不纳入本次提交、不回退,交对应 agent/用户处理。
   - 落在**调参/配置/硬件映射**(极性系数、增益、模式宏、引脚) → 优先视为**用户有意调整**:原样保留、一并提交、不质疑。
   - 两类都**禁 `git checkout` 擅自丢弃**;仅当归因不确定且与本次任务直接冲突时才问用户。
5. **多远端必须全推**:`remotes[]` 列了几个就推几个(双推 gitee+origin 之类),不得只推一端;当前分支与目标分支一致。
6. **默认在工作分支直接做**:除非用户要求,不擅自开新分支;开分支前先 `git fetch` 再基于最新基线 `checkout -b`。
7. **NTFS 改文件名大小写两步法**:`git mv old TMP && git mv TMP NEW`,直接改大小写会丢历史。

## 提交格式

按 manifest `git.commitFormat`(如 `<type>: <desc>` 或 `AIG_<scope>_<中文>`)。提交说明语言随项目。一组连贯改动通过静态审查后再提交;**默认不替用户加 AI 署名/Co-Authored-By**(除非用户全局配置要求)。

## 进 git 的内容注意(编码/链接陷阱与 git 的关系)

- **编码恢复靠 git 溯源**:源文件被 GBK 误存为 UTF-8 会产生 U+FFFD(合法 UTF-8,文本扫描漏判)→ 乱码无法就地还原。**用 `git log -p`/`git show <rev>:<path>` 逐版本回溯找最后一次干净版本**恢复。所以编码统一要在项目初期做、并尽早入 git,留下干净基线。
- **行尾/编码一致性入 `.gitattributes`**:`* text=auto eol=lf`、必要时对 `.icf`/`.ld` 标 `text`,避免跨机检出污染。
- **ICF/链接脚本注释禁非 ASCII**(见 `embedded-c-style.md`)——这类文件一旦带中文注释提交,换人检出编译即崩;提交前 `LC_ALL=C grep -nP '[^\x00-\x7F]' <link-script>` 校验为空。

## 相对路径(横切点 12)与 git

提交进仓库的构建配置/脚本/LSP 配置一律**相对路径**(`$PROJ_DIR$\..`、`-I./src`、`./tools/...`),不写绝对机器路径(`<盘符>:\...`、`/home/foo/...` 这类)。绝对路径入库 = 换机/换人即坏。提交前可 grep 扫描新增/改动文件无绝对路径泄漏。

## PASS / FAIL 自查(提交前)

- [ ] 已先向用户报告摘要、验证结果、建议提交说明和待暂存文件,并取得本次 Git 写流程确认。
- [ ] 只 `git add` 了本次编辑的文件(无 `git add .`)。
- [ ] 子代理/worker 未 stage / commit / push。
- [ ] `git status` 里 agent 本次未碰的改动已按"归因优先级"保留/隔离,无擅自 `checkout` 丢弃。
- [ ] 提交说明符合 `git.commitFormat`。
- [ ] 改动若涉文档同步(模块增删/高危语义/协议)→ 文档已在**同次提交**内更新(见 `hf-doc-discipline`)。
- [ ] 链接脚本/ICF 无非 ASCII;新增构建配置无绝对机器路径。
- [ ] 提交后推送了 `remotes[]` 全部远端,分支一致。

## 反面教训

- `git add .` 把另一 agent 半成品/用户调参一锅端进提交,污染历史、难回溯。
- 子代理修完小文件后顺手 commit/push,主 agent 尚未核验证据链,把错误结论固化进历史。
- 看到"莫名其妙"的极性/增益改动就 `git checkout` 还原——那往往是用户辛苦辨识的结果,丢了要重做且可能伤设备。
- 只推一个远端,另一端协作者拉不到,以为没改。
- 中文注释混进 `.icf` 提交,自己机器侥幸过了,换人 ILINK 直接 Access Violation。

## 参考

- 编码/ICF/inline 细节:`embedded-c-style.md`
- 编排契约:`../hecateflow/references/orchestration-contract.md`
- 文档同次提交:`hf-doc-discipline`、`tiered-docs.md`
- manifest:`../hecateflow/references/manifest-schema.md` 的 `git`
