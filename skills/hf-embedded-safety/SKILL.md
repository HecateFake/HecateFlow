---
name: hf-embedded-safety
description: >
  通用嵌入式安全审查:ISR/volatile 共享数据、ISR 轻量性、数值钳位与除零/溢出/积分饱和、
  最内环失控锁定、独占外设白名单门控。MCU 无关,适用裸机/RTOS 的 Cortex-M、RISC-V 等。
  触发:ISR 安全 / volatile / 中断安全 / 钳位 / clamp / 除零 / 溢出 / PID 积分限幅 / 失控保护 /
  外设占用 / 抢外设 / embedded safety / interrupt safety / shared data race。
license: MIT
argument-hint: "[target]"
metadata:
  compatibility: claude-code codex
  version: 1.0.0
  layer: knowledge
---

# hf-embedded-safety — 嵌入式安全审查 / Embedded Safety Review

裸机/实时嵌入式最常见的 bug 不在算法,而在**并发共享、中断时序、数值边界、外设争用**。本 skill 把这四类固化成可逐项判定的审查清单,被 `hf-auto-workflow`/`hf-review`/`hf-refactor` 引用,也可单独调用("帮我看这段 ISR 安不安全")。

## 适用 / 不适用

- 适用:写或改 ISR、共享变量、电机/执行器输出、ADC 采样、控制环、占用独占外设(SPI 屏/总线)的代码。
- 不适用:纯算法正确性(用普通 review)、纯风格(见 `references/embedded-c-style.md`)。

## 触发关键词

ISR 安全 / volatile / 中断优先级 / 钳位 / 除零 / 溢出 / 积分限幅 / 失控保护 / 外设占用 / interrupt safety / shared-data race。

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

## 执行流程

1. 锁定 target(读 manifest `targets[]`;同名高危文件先公告 target)。
2. 列出本次改动触及的全局变量,逐个判断是否跨 ISR/核共享 → 该 `volatile` 的标出。
3. 若改了 ISR(`pitProcessX`/中断处理函数),逐行查是否引入阻塞/重函数。
4. 找出所有执行器输出点,确认钳位 + 除零保护 + 溢出边界。
5. 跑下方 PASS/FAIL 清单,CRITICAL/HIGH 立即修(交回 `hf-implement`/`hf-auto-workflow` 落地)。
6. 不能编译时,关键并发/边界改动派子代理对抗复核(见平台差异)。

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
- [ ] **独占外设白名单门控**:单实例外设(SPI 屏/总线)只被一个核/上下文占用,用**白名单** `#if (MODE==A)||(MODE==B)` 门控,不用黑名单 `#if (MODE!=X)`(新增模式默认关闭,防误抢)。

## 验证

- agent 能做:静态判定上述清单、自动加 `volatile`/钳位/守卫、派子代理复核并发。
- 必须交用户:实际中断时序、堵转/饱和工况、物理执行器极性,需上板示波器/实测确认;agent 给出"上板须验证 X"的明确交接。

## 反面教训(具体案例）

- **漏 volatile 案例**:某工程共享内存结构未标 volatile,主循环读到陈旧视觉误差,定位漂移 —— 加 `volatile` 后即修。
- **失控检测放错位置**:把饱和锁定放在 `currentTick`(电流环),而开环模式不经电流环 → 开环失控不被捕获。正解:放 `motorControlOutput` 这种**所有模式必经**的关口。
- **黑名单抢屏**:`#if (MODE != X)` 门控 LCD,新增模式 Y 时默认打开,两个核同时写同一 SPI 屏 → 乱码/死锁。改白名单根治。
- **极性藏进 Kp 负号**:把执行器极性翻转藏在 PID Kp 符号里,Kp 身兼增益+极性二职,误改即正反馈失控。极性应集中在方向系数,Kp 全正。

## 平台差异

- 派子代理:Claude Code 用 `Task`(`subagent_type: "code-reviewer"`);Codex 用 `spawn_agent`→`wait_agent`→`close_agent`。
- 自动触发:Claude 端本 skill 可被 `hf-auto-workflow` 的 PostToolUse hook 调起;Codex 端无 hook,编辑后须自律调用。

## 参考

- `references/embedded-c-style.md`(类型/编码)、`hf-build-sync`(新文件登记)、`hf-doc-discipline`(参数表同步)、`hf-auto-workflow`(每次编辑自动审查)。
