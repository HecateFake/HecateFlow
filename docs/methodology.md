# HecateFlow 方法论 / The HecateFlow Methodology

> 本文是 HecateFlow 各 skill 背后的方法论长文。它把一个真实多核裸机 C 工程的开发经验,蒸馏为与具体 MCU 无关的原则。每条原则都标注了出处与具体案例,避免通用化稀释成"正确的废话"。
>
> This document is the long-form rationale behind HecateFlow's skills — the hard-won experience of a real multi-core bare-metal C project, distilled into MCU-agnostic principles. Each principle carries its provenance and a concrete case so it doesn't dissolve into truisms.

出处 / Provenance:第 21 届全国大学生智能汽车竞赛飞跃雷区组,三块 CYT4BB7(每块双 Cortex-M7)分布在悬停飞机(飞控 + 视觉)与麦轮车(底盘 + 遥控)之间,有线链路通信,IAR 工具链。下文称"源工程"。

---

## 一、为什么嵌入式需要专门的工作流 / Why embedded needs its own workflow

通用软件工作流(写测试、跑 CI、重构)在裸机/实时嵌入式上水土不服:

- **agent 通常不能编译**:目标工具链(IAR/Keil)在 agent 环境外,"行为正确"无法靠编译+运行验证 → 必须用**子代理对抗审查**代替。
- **并发是隐形的**:ISR 与主循环、核与核之间共享数据,竞争不报错,只在运行时偶发。
- **输出是物理的**:PWM/电流直接驱动电机,一个没钳位的值能烧硬件。
- **构建系统不自动发现文件**:IAR/Keil 工程文件是手维护的,漏登 = 链接错误。

HecateFlow 的每个 skill 都是对这些约束的直接回应。

---

## 二、核心原则 / Core principles

### 1. 编辑前先确认目标 / Identify the target before editing

多核/多芯片工程里,同名文件(`motor.c`/`IMU.c`/`PID.c`)在不同核语义**完全不同**:源工程里 `motor.c` 在飞控核是"四旋翼 400Hz Servo PWM 百分比 API",在麦轮车核是"单轮速度控制"。改错核 = 灾难。

→ 落地:`hecateflow` 注入"目标识别"红线;判定顺序 = 用户指定 → 路径匹配 → 关键词 → **否则必须问,绝不猜**。高危同名文件编辑前公告 `目标:<target>/<file>(<语义>)`。

### 2. 文件在磁盘 ≠ 文件在构建图 / On-disk ≠ in the build graph

源工程用 IAR,`.ewp` 不 glob。曾经新增 `uartLinkProto.c/h` 漏同步 `.ewp`,链接期 `undefined reference` 才发现。新增源文件是**双写动作**:写文件 + 登记构建图(+ LSP)。

→ 落地:`hf-build-sync`,覆盖 IAR/Keil/CMake/Make/PlatformIO 各自登记法;`hf-implement` 每加文件即委派登记。

### 3. 一处改动,N 个切点 / One change, N touchpoints

源工程新增一个编译期构建变体(模式宏)要同步:宏定义、ISR 路由、外设占用门控、工程文件、文档——漏一处症状各异(链接错误 / 抢屏 / 收不到中断 / 下个 agent 按旧语义误改)。

→ 落地:`hf-design-module` 在写第一行代码前列全 6 类切点(源登记/宏/ISR/外设/volatile/文档)。

### 4. 共享数据一律 volatile,ISR 保持轻量 / Shared data is volatile; ISRs stay light

漏 `volatile` 是最高频且最难查的 bug:编译器把共享变量缓存进寄存器,主循环永远读旧值。ISR 里放 `printf`/LCD/阻塞 = 抖动、死锁、优先级反转。源工程用 `initReadyFlag` 模式(ISR 首行 `if(!ready)return;`)+ 高频采样中断优先级高于控制中断。

→ 落地:`hf-embedded-safety` 的 volatile/ISR 清单;`hf-auto-workflow` 第 1-2 步每编辑必扫。

### 5. 执行器输出必有边界,失控必锁定 / Clamp actuators; lock on runaway

源工程的教训:① PWM 钳到 `[-1,+1]`、电流限幅、PID 积分限幅;② 增量式电流环必须**抗饱和**(饱和时把累加器钳回自身,否则堵转后反向命令要从溢出值逐拍退回,大电流电机危险);③ 最内环持续饱和达 N 拍 = 失控信号 → 持久锁定全车 + 蜂鸣,仅复位解锁。关键:失控检测要放**所有控制模式必经的输出关口**(源工程曾误放在电流环 tick,而开环模式不经它 → 漏检)。

→ 落地:`hf-embedded-safety` 数值安全 + 失控锁定项。

### 6. 独占外设用白名单门控 / Gate shared peripherals with a whitelist

源工程的 IPS114 屏是单 SPI 设备,只能一个核占用。用**黑名单** `#if (MODE!=X)` 门控会在新增模式时默认打开 → 两核抢屏乱码。必须用**白名单** `#if (MODE==A)||(MODE==B)`,新增模式默认关闭。

→ 落地:`hf-init-project` 登记外设 owner + 冲突检查;`hf-embedded-safety` 白名单门控项。

### 7. 先复用,再抽象,最后才新写 / Reuse first, abstract second, write last

源工程反复出现"为复用而设计却被手写绕过"的抽象(如手写 6 组 `while(x>PI)x-=2PI` 而非调已有 `wrapToPi`)。优先级严格递减:本仓已有库 → 现成外部库 → 才新建对象式 `Init/Update/Reset` 库。

→ 落地:`hf-design-module` 的复用调研表;`hf-refactor` 的 5 类等价变换。

### 8. 行为保持重构靠对抗审查,不靠编译 / Prove refactors by adversarial review

agent 不能编译,所以"零行为变化"靠**子代理对抗审查**:用 `git show HEAD:<path>` 与工作区逐函数比对,逐项 PASS/FAIL。头号红线:**符号/极性不能被通用助手吃掉**(取反 `clamp(-x,..)` 不能换成无取反助手)。还要**亲验**子代理结论——源工程实测有"Explore 报某宏零用,亲验实为 2 处真调用"的自相矛盾,轻信则误删致编译断裂。

→ 落地:`hf-refactor` 的 9 项对抗审查清单 + 亲验要求。

### 9. 文档是代码的投影,同提交更新 / Docs are a projection of code

源工程每个核一份 PROJECT.md(状态卡/模块清单/边界/参数/ISR 表/验证清单),是无上下文 agent 的真相源。代码改了文档没跟 = 漂移,会骗下个 agent。共享库多副本演进时必须登记版本差异。

→ 落地:`hf-doc-discipline`;`hf-auto-workflow` 第 6 步同步检查。

### 10. 能在 PC 验证的,先仿真后上板 / Simulate before flashing

源工程有 PC 侧仿真(视觉 Canny/轮廓、麦轮运动学、RS-485 协议),板上调参成本远高于 PC,几何/协议/算法先在 PC 验证再上板。

→ 落地:`hf-design-module` 的"先仿真判定"。

### 11. plan→build:计划文件是跨会话的锚 / Plan files anchor across sessions

源工程约定:进 build 第一步把多阶段计划写进计划文件,会话恢复先读它确认进度,**完成后删除**(临时产物,不与 PROJECT.md 争真相源)。

→ 落地:`hf-implement` 的 plan→build 工作流 + `templates/integration-plan.md.tmpl`。

### 12. 每次编辑当下审查最便宜 / Review at edit time

源工程的 `auto-workflow` 规则:每次编辑 `.c/.h` 后立即 6 步审查(目标确认→volatile→ISR→数值→风格→文档),CRITICAL/HIGH 自动修。离开编辑上下文后定位"哪次改动引入"成本陡增。

→ 落地:`hf-auto-workflow`(Claude 可挂 PostToolUse hook;Codex 靠自律)。

### 13. Git 纪律:只 add 自己的改动 / Only stage your own changes

多 agent 并行时,工作区里非本次任务的改动默认视为用户/其他 agent 有意为之,**原样保留不回退**;只显式 add 本次编辑文件,**禁止 `git add .`**。

→ 落地:`hecateflow` 注入 + `hf-implement` 收尾。

### 14. 交互要结构化、可退化 / Structured, degradable interaction

询问用户用结构化提问(每问含 question/header/2-4 个 options);Codex 无此工具则退化为文字编号选项。校验失败最多重试一次,再退文字。

→ 落地:`hecateflow` 注入 AskUserQuestion schema 红线。

---

## 三、持久化交互记忆 / The persistent manifest

把"使用时自定义"做成可复用,关键是**记住选择**。`.hecateflow/project.json` 记录工作区的 MCU/工具链/构建系统/各核角色/默认项;每个 skill 读它做默认值,只问缺失项,用完写回(读-改-写 + 校验,各 agent 只改自己的 `targets[]` 项以降低写竞争)。这让同一套 skill 在不同工程里各自"记得"上下文,无需每次重问。

---

## 四、跨平台设计 / Cross-platform design

- **单一源树**:`skills/<name>/SKILL.md`,两端共用。
- **工具名映射**:正文用 Claude 工具名,每个 SKILL.md 末尾"平台差异"段内联 Codex 等价(因为 Codex 不支持外部 reference 的渐进披露)。
- **frontmatter 并集**:`name`+`description` 必填(Codex 靠 description 关键词发现 skill),其余字段两端忽略不认的。
- **命名隔离**:`hf-` 前缀避免与他人 skill 全局冲突。

---

## 五、把它用到你自己的工程 / Applying it to your project

HecateFlow 不假设你用 CYT4BB7 或 IAR。跑 `hf-init-workspace` 时它探测你的构建系统、问你的 MCU/工具链,写进 manifest;之后所有原则都按你的工程参数实例化。上面的 CYT4BB7 案例只是"为什么这条原则存在"的证据,不是约束。

HecateFlow assumes neither CYT4BB7 nor IAR. `hf-init-workspace` probes your build system and asks your MCU/toolchain into the manifest; every principle is then instantiated with your project's parameters. The CYT4BB7 cases above are evidence for *why* each principle exists — not a constraint.
