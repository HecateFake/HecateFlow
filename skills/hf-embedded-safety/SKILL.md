---
name: hf-embedded-safety
description: >
  通用嵌入式安全审查:ISR/volatile 共享数据、ISR 轻量性、数值钳位与除零/溢出/积分饱和、
  最内环失控锁定(必落所有模式必经输出关口)、独占外设白名单门控、驱动代码级 owner、驱动配置 setter 惰性语义、
  链接脚本注释 ASCII 安全。MCU 无关,适用裸机/RTOS 的 Cortex-M、RISC-V 等。高风险安全改动
  按自主性优先编排契约做主动只读复核、复审链和主 agent 亲验。
  触发:ISR 安全 / volatile / 中断安全 / 钳位 / clamp / 除零 / 溢出 / PID 积分限幅 / 失控保护 /
  外设占用 / 抢外设 / 驱动 owner / 驱动所有者 / 惰性 set / lazy setter / set_dir / IPS114 / ICF / 链接脚本 ASCII /
  Li005 / 电机失控 / 堵转 / PWM 限幅 / 中断里 printf / 屏幕乱码 / 总线抢占 /
  SDK 也可能错 / 厂商库 / 不可能出现 / 事实二次确认 /
  embedded safety / interrupt safety / shared data race / actuator clamp / runaway protection。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-embedded-safety — 嵌入式安全审查 / Embedded Safety Review

裸机/实时嵌入式最常见的 bug 不在算法,而在**并发共享、中断时序、数值边界、外设争用**。本 skill 把这四类固化成可逐项判定的审查清单,被 `hf-auto-workflow`/`hf-review`/`hf-refactor` 引用,也可单独调用("帮我看这段 ISR 安不安全")。跨 ISR/volatile/执行器/驱动 owner 的高风险结论遵守 `../hecateflow/references/orchestration-contract.md`:先自主求证,主动派只读子代理复核证据,复审链查矛盾和过度推断,主 agent 亲验后才裁决。

## 适用 / 不适用

- 适用:写或改 ISR、共享变量、电机/执行器输出、ADC 采样、控制环、占用独占外设(SPI 屏/总线)的代码;初始化/配置驱动(显示/外设 setter 顺序、代码级 owner);改链接脚本(`.icf`/`.ld`/分散加载)。
- 不适用:纯算法正确性(用普通 review)、纯风格(见 `../references/embedded-c-style.md`)、极性/数量级/IO 归属**设计期放置**(去 `hf-hw-mapping`,本 skill 只管运行时门控机制)。

## 触发关键词

ISR 安全 / volatile / 中断优先级 / 钳位 / 除零 / 溢出 / 积分限幅 / 失控保护 / 外设占用 / 驱动 owner / 硬件驱动归属 / 惰性 set / set_dir / IPS114 / ICF / 链接脚本 ASCII / Li005 / interrupt safety / shared-data race。

## 第一性原则

**ISR 是特权而危险的执行上下文,共享数据是隐形竞争源,执行器输出是物理危险的出口。** 三者各有不可妥协的纪律:
- ISR 只做"采样 + 置标志 + 极简算术",耗时操作交主循环。
- 跨上下文(ISR↔主循环、核↔核)共享的数据一律 `volatile`,且窄临界区保护读改写。
- 任何驱动物理执行器(PWM/DAC/电流)的值必须有硬边界,最内环持续饱和视为失控信号。

## 红线(最易翻车)

- **漏 `volatile`**:被 ISR 写、主循环读的全局缺 `volatile` → 编译器缓存进寄存器,主循环永远读到旧值。**最高频且最难查**。
- **ISR 里调阻塞/重函数**:`printf`、LCD 刷屏、`while` 等待、`malloc` → 抖动、死锁、优先级反转。
- **执行器输出无钳位**:PWM/电流命令直接出,溢出或 NaN → 烧电机/炸驱动。
- **增量式累加器无抗饱和**:堵转/目标不可达时增量 PI 累加器无限 windup,反向命令需从溢出值逐拍退回,恢复迟缓 —— 大电流电机危险。
- **极性藏进 PID Kp 负号**:Kp 兼增益+极性,误改符号即正反馈跑飞 —— 物理伤害级红线。本 skill 不展开,**极性单一真相源/辨识/数量级细节全在 `hf-hw-mapping`**;此处仅作安全红线点名:执行器/反馈翻转只许在 §极性段三组 `*_DIR`,Kp 恒正。
- **同一硬件驱动多头 owner**:多个模块各自保存同一驱动状态、重复 init/set/update,或绕过 owner API 直接摸寄存器/引脚 → 初始化顺序、惰性 setter、缓存状态、并发门控和竞态边界互相覆盖。安全侧按 HIGH 处理,归属设计细节交 `hf-hw-mapping`。
- **盲信 SDK/provider 或用户断言**:厂商库、用户现场描述、历史注释、agent 直觉都可能错。遇到"这不可能出现""SDK 不会错"时,先二次确认复现条件并读真实实现/日志/寄存器路径;未证实前不得把该断言当安全结论。

## 执行流程

1. 锁定 target(读 manifest `targets[]`;同名高危文件先公告 target)。
2. 列出本次改动触及的全局变量,逐个判断是否跨 ISR/核共享 → 该 `volatile` 的标出。
3. 若改了 ISR(`pitProcessX`/中断处理函数),逐行查是否引入阻塞/重函数。
4. 找出所有执行器输出点,确认钳位 + 除零保护 + 溢出边界。
5. 跑下方 PASS/FAIL 清单,CRITICAL/HIGH 立即修(交回 `hf-implement`/`hf-auto-workflow` 落地)。
6. 关键并发/边界改动按 `../hecateflow/references/orchestration-contract.md` 分档;L1 自动派至少一个只读 reviewer,L2/L3 无论能否编译都必须多路只读对抗复核 + 复审链 + 主 agent 亲验。编译通过只是额外证据,不能替代复审。

## 失控锁定:必落"所有模式必经的输出关口"

最内环输出持续饱和是控制发散/失控的信号。锁定检测**不是放哪条路径都行**——必须落在**所有控制模式都流经的那一个输出关口**,否则某些模式绕过它就失去保护。

- 反例:把饱和锁定放进电流环 `currentTick`。开环/直驱模式不经电流环 → 开环失控**不被捕获**。
- 正解:放 `motorControlOutput` 这类**闭环/开环/直驱全都必经**的最终输出关口;任一执行器 `motorOutput` 持续饱和(≥阈值,如 0.999)达 N 拍 → **持久锁定**全部执行器为 0 + 高频告警,仅复位(重新 init)解锁。
- 判据:问"有没有哪种构建模式/控制路径能产出 PWM 却不经过这个检测点?"有 → 检测点选错。
- 此关口独立于可恢复的急停/链路丢失软停,是更高级别的兜底。

## 驱动 / 独占外设陷阱

### 代码级驱动 owner 单一

同一物理驱动实例(屏、IMU、总线、电机驱动、ADC 前端等)在代码层面应尽量只有一个对象式 owner:

- owner 以 `xxxDriverStruct` 或模块私有对象负责 `init/config/static state/update` 和硬件命令发出时机;其它模块通过 owner API、接口结构或 init 期函数指针绑定访问。
- 禁止多个 `.c` 文件各自维护同一驱动的缓存/状态位/方向配置;这会让 setter 惰性语义、初始化顺序、并发门控和竞态边界变成隐形共享状态。
- 若必须跨上下文共享,先设计仲裁/锁/消息通道和白名单门控,再编码;不要把"谁最后写硬件"留给调用顺序。
- 设计期 owner/manifest 登记属 `hf-hw-mapping`;本 skill 在安全审查中拦截多头 owner 带来的运行时混乱。

### 驱动配置 setter 的惰性语义

许多显示/外设驱动的 `setXxx` 配置函数(方向/字体/前景背景色)**只写软件全局,不立即把状态推到硬件**;真正发硬件命令往往**只在 `init()` 里按当时的全局值发一次**。误判其时序会得到"设了不生效"的诡异现象。

- 典型(IPS114 类 SPI 屏):`set_dir`/`set_font`/`set_color` 仅赋值软件全局(`display_dir`/`font`/`pencolor`/`bgcolor`);**方向硬件命令(MADCTL)只在 `init()` 内按 `display_dir` 发出**。`set_dir` 单独调用**不补发 MADCTL**,只改 `width/height` 上限。背景色/字体只影响其后的绘制,要铺满全屏须靠一次清屏/绘制。
- 两个正确做法(任选):
  1. **set 放在 `init()` 之前** —— init 读这些全局并应用(含 MADCTL 硬件方向)。
  2. **set 在 `init()` 之后改了,则调一次 `clear()`/全屏重绘**强制按当前全局生效。**注意**:纯方向变更**仍须走做法 1**——`clear` 不补发 MADCTL,init 后单独 `set_dir` 改方向无效。
- 易误判:看到"init 在先"就报"setter 顺序是 bug"是错的——init-在先且**不调 set_dir**(用编译期默认方向)的写法完全正确。结论靠读驱动源确认"硬件命令在哪发",别凭直觉。

### SDK / 厂商库也要当成待验证代码

SDK/厂商库不是免审真相源,只是当前项目通常不直接修改的外部代码。排查安全 bug 时:

- **先读真实语义**:不要凭函数名、厂商文档或"常识"推断中断/临界区/缓存/外设 setter 行为;读对应实现、头注释、寄存器写入点和调用时序。
- **不轻易改 SDK**:除非用户明确要求,不要直接改 vendor 源;优先在项目层用 wrapper、owner API、调用顺序或隔离验证规避,并把 SDK 语义/缺陷记录为 lesson。
- **二次确认不可能断言**:若用户或你认为"SDK 不可能导致这个 bug",先要求复现条件/观测证据二次确认,再找反例路径。安全审查里"没看见证据"不等于"不可能"。
- **典型红线**:全局中断 disable/enable、临界区计数器、缓存/MPU 配置、DMA buffer 属性、外设 setter 惰性语义、ISR callback 上下文,都必须读源码或官方寄存器路径确认。

### 独占外设白名单门控(机制)

单实例外设(SPI 屏/共享总线/共享 ADC)同一时刻只能一个核/上下文占用,**门控机制**用白名单 `#if`:

- **白名单**`#if (MODE==A) || (MODE==B)`:新增模式默认**不**占用,须显式入名单才占。
- **禁黑名单**`#if (MODE!=X)`:新增模式 Y 默认打开 → 两上下文同写一外设 → 乱码/总线竞争/死锁。
- 让出:要让另一上下文占屏,反向把本上下文的 display 代码也 `#if` 关掉。
- **边界**:外设**归属权设计、per-core 分核规划、manifest `ownedPeripherals` 登记 + 主动提醒**属 `hf-hw-mapping`;本 skill 只负责运行时**门控机制写法**(白名单 `#if` + volatile 共享态)。

## 链接配置稳定性(ICF / 分散加载脚本)

链接器配置脚本(IAR `.icf` / GCC `.ld` / Keil 分散加载)的**注释禁非 ASCII**:中文/特殊符号会让链接器崩溃。IAR ILINK 表现为 **Access Violation,且伴随误导性的伪 `Li005 no definition for ...`**——看似"符号未定义"(易误诊为 `hf-build-sync` 的漏登记),实为脚本编码问题。

- 这类文件只写 ASCII;改后用 `LC_ALL=C grep -nP '[^\x00-\x7F]' <脚本>` 校验输出为空(详见 `../references/embedded-c-style.md`)。
- 排错启发:出现伪 Li005 / 链接器 Access Violation 时,**先验链接脚本 ASCII**,再查源文件登记,可省大量误诊时间。

## PASS/FAIL 对抗审查清单

逐项给 PASS/FAIL + 依据,任一 FAIL 先修再交付:

- [ ] **共享变量 volatile**:被 ISR 写/读且主循环也访问的全局,声明含 `volatile`。
- [ ] **核间共享 volatile**:被另一核访问的共享内存结构,声明含 `volatile`。
- [ ] **ISR 轻量**:ISR 内无 `printf`/`sprintf`、无 LCD/串口输出、无阻塞 `while`、无动态内存、无不可预测耗时函数。
- [ ] **中断优先级有序**:高频采样中断优先级高于控制中断,采样不被抢占。
- [ ] **init 守卫**:ISR 首行 `if (!initReadyFlag) return;`,初始化未完成不跑控制逻辑。
- [ ] **执行器钳位**:PWM/输出钳到 `[-LIMIT, +LIMIT]`(对称限幅用 `clampSym`/`range`)。
- [ ] **除零保护**:浮点除法的除数(物理常量、半径、增益)在可能为零时有保护。
- [ ] **整型溢出**:累加/计数(如 `int16_t` 编码器增量)在最坏工况不溢出;长期累加值在状态切换时清零。
- [ ] **积分抗饱和**:PID 积分项有 `integralMax`;增量式累加器在饱和时把内部累加量钳回自身(anti-windup),不只是钳输出。
- [ ] **失控锁定**:最内环输出持续饱和(≥阈值)达 N 拍 → 持久锁定全部执行器为 0 + 告警,仅复位解锁。检测须放**所有控制模式必经的输出关口**(不是只在某条路径上)。
- [ ] **独占外设白名单门控**:单实例外设(SPI 屏/总线)只被一个核/上下文占用,用**白名单** `#if (MODE==A)||(MODE==B)` 门控,不用黑名单 `#if (MODE!=X)`(新增模式默认关闭,防误抢)。归属/分核规划登记见 `hf-hw-mapping`。
- [ ] **驱动 owner 单一**:同一硬件驱动实例只有一个代码级对象式 owner 负责 init/config/static state/update;其它模块未重复维护驱动状态、制造竞态,未绕过 owner API 直接访问底层。
- [ ] **驱动 setter 时序正确**:依赖硬件命令的配置(如屏方向 MADCTL)按驱动惰性语义放置——set-before-init 或 init 后补 `clear`/重绘;纯方向变更走 set-before-init。
- [ ] **链接脚本 ASCII**:改过的 `.icf`/`.ld`/分散加载脚本注释纯 ASCII(`LC_ALL=C grep -nP '[^\x00-\x7F]'` 为空),无中文/特殊符号致 ILINK 崩溃 + 伪 Li005。
- [ ] **极性主动确认(交叉 `hf-hw-mapping`)**:本次若触及执行器/反馈极性或闭环整定——已主动提问让用户**标定"代码符号↔现实方向"映射**(落头里可调方向系数宏)、并基于用户确定的映射**核查闭环为负反馈**(Kp 全正、Kp×反馈斜率<0),未静默假定极性。
- [ ] **事实来源二次确认**:本次安全结论没有盲信用户描述、SDK/provider 承诺、历史注释或函数名;涉及"不可能出现"的断言已二次确认并读真实实现/证据。

## 验证

- agent 能做:静态判定上述清单、自动加 `volatile`/钳位/守卫、按编排契约派只读子代理复核并发/安全边界。
- 必须交用户:实际中断时序、堵转/饱和工况、物理执行器极性,需上板示波器/实测确认;agent 给出"上板须验证 X"的明确交接。

## 反面教训(具体案例）

- **漏 volatile 案例**:某工程共享内存结构未标 volatile,主循环读到陈旧视觉误差,定位漂移 —— 加 `volatile` 后即修。
- **失控检测放错位置**:把饱和锁定放在 `currentTick`(电流环),而开环模式不经电流环 → 开环失控不被捕获。正解:放 `motorControlOutput` 这种**所有模式必经**的关口。
- **黑名单抢屏**:`#if (MODE != X)` 门控 LCD,新增模式 Y 时默认打开,两个核同时写同一 SPI 屏 → 乱码/死锁。改白名单根治。
- **驱动多头 owner**:屏/总线/传感器驱动被多个模块各自保存配置并重复 init/set,一次配置被另一路初始化覆盖,竞态边界也不清,症状像"偶发不生效"。根治:单一对象式 owner + API/接口访问。
- **驱动惰性 set 误判**:把"非默认方向"的 `set_dir` 改到 `init()` 之后,硬件停在默认方向(set_dir 不补发 MADCTL)→ 屏方向错乱;反过来,曾据"init 应在先"误报一段 set-before-init 的正确代码是 bug。两边都是没读驱动源、凭直觉判惰性语义所致。
- **盲信 SDK 临界区封装**:曾把整机卡死先归因到 cache/MPU/外设,默认 SDK 中断封装不会错;真实根因是 SDK 全局 disable/enable 计数语义在 ISR 与前后台临界区交错后漂移,中断永久关闭。教训:SDK/provider 也可能错,安全结论要读实现和证据。
- **链接脚本非 ASCII**:`.icf` 注释写了中文 → IAR ILINK Access Violation + 伪 `Li005 no definition`,误诊为源文件漏登记排查半天。先验脚本 ASCII 即定位。
- **极性藏进 Kp 负号**(细节见 `hf-hw-mapping`):极性翻转藏 PID Kp 符号,误改即正反馈失控。此处只记安全后果,辨识/三组 DIR/数量级在 `hf-hw-mapping`。

## 平台差异

- 派子代理:Claude Code 用 `Task`(`subagent_type: "code-reviewer"`);Codex 在多代理工具可用时主动用 `multi_agent_v1.spawn_agent`→`multi_agent_v1.wait_agent`→`multi_agent_v1.close_agent` 派只读安全复核,无工具或宿主策略限制时主会话逐项复核并声明平台限制导致未做子代理复核。子代理只读且不得 Git,遵守 `../hecateflow/references/orchestration-contract.md`。
- 自动触发:Claude 端由安装器写入的 PostToolUse hook 提醒运行 `hf-auto-workflow`,再按需触发本 skill;Codex 端无 hook,编辑后须自律调用。

## 参考

- `hf-hw-mapping`(极性单一真相源/三组 DIR/开环辨识/数量级/IO 外设归属与代码级驱动 owner——本 skill 的极性与归属设计细节全部委派到此,不重复)。
- `../references/embedded-c-style.md`(类型/编码/ICF ASCII 完整校验/`inline`→undefined)、`hf-build-sync`(新文件登记;伪 Li005 先排 ICF 再排登记)、`hf-doc-discipline`(参数表同步)、`hf-auto-workflow`(每次编辑自动审查,触发极性/数量级提醒)。
- `../hecateflow/references/orchestration-contract.md`(安全类 L2/L3 只读复核、复审链、Git 确认门)。
