# 嵌入式 C 编码风格 / Embedded C Style (reference)

> 被 `hf-auto-workflow` 第 4 步与 `hf-implement` 内联引用的风格基线。非独立 skill。
> 默认面向裸机 / RTOS 嵌入式 C(ARM Cortex-M、RISC-V MCU 等),按 manifest `workspace.language` 调整。

## 文件编码

- 源文件与文档统一 **UTF-8(无 BOM)**;除非工具链强制,否则不用 GBK/Latin-1。
- 行尾 LF;缩进按 manifest 约定(默认 4 空格,不用 Tab)。
- 从第三方/厂商库(常为 GBK/CP1252)同步文件时,先按原编码识别再以 UTF-8 无 BOM 写回。
- **编码统一在项目初期做**并尽早入 git,留下干净基线。
- **乱码恢复靠 git 溯源**:GBK 被误按 UTF-8 读会产生 U+FFFD(本身是合法 UTF-8,纯文本扫描**漏判**为"正常")→ 就地无法还原。用 `git log -p` / `git show <rev>:<path>` 逐版本回溯,找最后一次干净版本恢复。这是编码尽早入 git 的理由。

## 链接 / 构建文件陷阱

- **ICF / 链接脚本(`.icf`/`.ld`/分散加载)注释禁非 ASCII**:中文/特殊符号会让链接器崩溃(IAR ILINK 报 Access Violation,并伴随误导性的伪 `Li005 no definition`)。这类文件只写 ASCII;改后用 `LC_ALL=C grep -nP '[^\x00-\x7F]' <脚本>` 校验输出为空。
- **`inline` → 链接 undefined**:头文件里裸 `inline` 函数被多个编译单元 include,易触发"重复定义"或"无外部定义"链接错误。要么放 `.c` 显式链接,要么用 `static inline`;**不靠手工展开规避**。
- **多层编译期模式守卫必须三处对齐**:多层模式宏(如 `BUILD_MODE` + `TUNE_MODE`)下,函数的**定义守卫 / 调用守卫 / ISR 路由守卫**三处条件必须一致;漏一处 → 某构建分支被编译却无定义(链接 undefined),或反之调用了被裁掉的函数。切换/新增模式见 `hf-design-module` 切点清单。

## 路径纪律(横切点 12)

- 构建配置(`$PROJ_DIR$\..`)、`#include`、LSP `-I`、脚本一律**相对路径**,不写绝对机器路径(`<盘符>:\...`、`/home/...` 这类)——绝对路径入库即不可跨机/跨人移植。
- `#include` 用相对头路径时,对应目录必须进构建系统 include 搜索路径与 LSP `-I`(见 `hf-build-sync`),不靠 `../../` 深回溯硬编码。

## 数据类型

- 用固定宽度类型:`uint8_t` / `int16_t` / `uint32_t` / `float`;**不用**裸 `int` / `unsigned`(平台宽度歧义)。
- 布尔用 `uint8_t`(`0u`/`1u`),除非项目已统一 `stdbool.h`。
- 浮点字面量带 `f` 后缀:`0.0f`、`-18.0f`(避免隐式 double 运算拖慢 FPU 单精度路径)。

## 命名(可被 manifest 覆盖)

| 元素 | 默认风格 | 示例 |
|------|---------|------|
| 函数 | `camelCase` + 模块前缀 | `motorControlInit()` |
| 全局变量 | `camelCase` + 模块前缀 | `chassisData` |
| 结构体类型 | `camelCase` + `Struct` 后缀 | `motorControlDataStruct` |
| 宏/常量 | `UPPER_SNAKE_CASE` + 模块前缀 | `MOTOR_OUTPUT_LIMIT` |
| 头文件守卫 | `_MODULE_NAME_H_` | `_MOTOR_CONTROL_H_` |
| 枚举值 | `UPPER_SNAKE_CASE` | `STATE_IDLE` |

> 项目若用 snake_case(Linux 内核风格)等其它约定,以 manifest/既有代码为准 —— **匹配周围代码胜过本表**。

## 文件组织

- 多个小文件优于少数大文件:单文件典型 200–400 行,800 行为软上限。
- 每模块一对 `.c/.h`;头文件只暴露外部接口(声明/`extern`/`typedef`/`#define`),实现进 `.c`。
- 文件作用域的函数/变量加 `static`。
- 按功能/领域分目录,不按文件类型分。新增源目录须同步构建系统 include 路径与 LSP `-I`(见 `hf-build-sync`)。

## 抽象分层与可移植封装(最小侵入 / 算法与底层分离 / 多硬件兼容 API)

> 头引用、封装、调用三者共同遵循:**最小侵入、可复用、算法与底层抽象分离**,接口为**多硬件设计兼容 API**,方便用户试错与后续开发。这是"为复用而设计"的写法,不是事后补救。

- **最小侵入引用**:模块只 `#include` 它真正用到的头;新模块接入不应迫使已有模块改动。硬件映射头(`pinMap.h`)**零依赖纯 `#define`**,可被任意模块安全 include 而不引入耦合。新增能力优先**加新文件/新接口**,而非在热点文件里塞分支。
- **算法层与底层(HAL/驱动)分离**:算法/控制逻辑依赖**抽象接口**,不直接摸具体驱动、引脚或寄存器。引脚走 `pinMap.h`、参数走 `configHeader`、外设访问走薄 HAL 封装。换芯片/换传感器/换接线时,**只动底层实现,算法层不改**。
- **硬件驱动单一 owner**:同一物理驱动实例的 `init/config/static state/update` 尽量归一个 owner 模块负责,用面向对象思路封成 `xxxDriverStruct` 或模块私有对象;其它模块通过 owner API、接口结构或 init 期绑定访问。`static` 用来隐藏 owner 内部状态,不是让多个 `.c` 文件各自保存同一硬件状态副本,否则会引入竞态和管理混乱。
- **可复用的对象式封装**:通用能力(滤波器、PID、状态估计、触发器、数学工具)封成 `xxxStruct` + `xxxInit`/`xxxUpdate`/`xxxReset`,**与调用方解耦**、可被多模块/多 target 复用。优先复用已有库(本仓/外部通用库),无现成实现再新建,不重写(见 `hf-design-module`、`hf-refactor`)。
- **多硬件兼容 API**:为同一类能力定义**稳定接口**,具体实现按硬件分版本;运行期可用**函数指针 / init 绑定**注入具体实现(如不同 ToF/IMU/电机驱动绑同一套控制 API)。接口契约(单位、量纲、极性约定、返回语义)写在头注释里,作为跨实现的"合同"。
- **方便试错与后续开发**:清晰的接口缝隙让用户低成本换实现、A/B 对比、调参,而**爆炸半径**局限在底层一处。调用点用接口而非内联展开重复逻辑;发现"为复用而设计却被手工展开"的抽象(如参数结构对应 `xxxInit` 入参)要**用起来**。
- **不变量**:封装/分层**不得改变行为**;为复用做的抽象若改了运算/极性/顺序,就不再是封装而是改行为(零行为变化的去重见 `hf-refactor`)。

## 嵌入式 C 的面向对象写法(无 C++,纯 C 模拟 OOP)

> 裸机纯 C 不能用类/模板/虚函数,但"面向对象"的**封装、实例、方法、多态**可用结构体 + 函数指针落地。这是上节"可复用对象式封装"的具体范式。目标:多实例隔离状态、接口稳定、可换实现——**全程不引入动态内存**。

- **对象 = 结构体实例 + `self`/`this` 指针**:状态封进 `xxxStruct`,方法把实例指针作首参传入。同一类型可有**多个独立实例**(如四轮各持一个 PID 实例,状态互不串)。
  ```c
  typedef struct { float kp, ki, integral, lastErr; float outLimit; } pidStruct;
  void  pidInit  (pidStruct *self, float kp, float ki, float outLimit);
  float pidUpdate(pidStruct *self, float target, float feedback); /* 方法:self 即 this */
  void  pidReset (pidStruct *self);
  ```
- **方法 = 模块前缀函数**:生命周期方法 `Init`/`Update`/`Reset`/`Deinit` + 必要的 getter/setter。头只声明这套接口,实现进 `.c`。
- **封装 = `static` + 头只暴露接口**:文件私有状态/助手加 `static`;字段需真正隐藏时用**不透明指针**(头里 `typedef struct xxx xxxStruct;` 仅前置声明,字段藏 `.c`)——但实例须由模块内静态分配(RAM 受限工程慎用,常直接暴露结构体换取栈/静态分配)。
- **多态 = 结构体内函数指针 / init 绑定(轻量 vtable)**:同一套上层 API 绑不同底层实现 = **多硬件兼容 API**。如统一控制接口在 `init` 时把具体 ToF/IMU/电机驱动的函数指针绑入,上层只调接口、不知具体型号;换硬件只换绑定。
  ```c
  typedef struct { uint8_t (*read)(void *dev, float *out); void *dev; } rangeSensorIface;
  /* init 期:iface.read = vl53l1xRead; iface.dev = &vl53l1x; 换传感器只改这两行 */
  ```
- **组合优于继承**:把"基类"结构体作为成员**嵌入**(has-a);确需"继承"语义时把 base 作为**第一个成员**(可受控向上转型,谨慎用、注释清楚)。不做深继承层级。
- **`volatile` 实例**:被 ISR 与主循环/另一核共享的对象实例须 `volatile`(见 `hf-embedded-safety`)。
- **禁止**:为 OOP 引入 `malloc`(实例用静态/全局/调用方提供的存储);函数指针滥用(每个指针耗 RAM + 间接调用开销,只在真需多态处用);把单实例无状态逻辑硬塞成"对象"(过度设计,见 `hf-refactor` 克制原则)。

## 禁止(资源受限裸机)

- C++ 特性、模板、异常、RAII(纯 C 工程)。
- 动态内存:`malloc`/`calloc`/`realloc`/`free`(碎片 + 不确定性)。
- 递归、`alloca`、VLA(栈深不可控)。
- ISR 内 `printf`/`sprintf`(见 `hf-embedded-safety`)。

## 条件编译

编译期构建变体/调试模式用 `#define` + `#if`/`#elif`,不用运行时 `switch`(省 flash、便于裁剪):

```c
#define BUILD_MODE BUILD_PRODUCTION
#if   (BUILD_MODE == BUILD_PRODUCTION)
    // ...
#elif (BUILD_MODE == BUILD_TUNE)
    // ...
#endif
```

新增/切换构建变体须走 `hf-design-module` 的切点清单(漏改一处 → 链接期 undefined 或抢外设)。

## 注释

- 仅在必要处加简洁注释(说明"为什么",不复述"是什么")。
- 不给显而易见的代码加注释;默认不加 Doxygen 块注释(除非项目要求)。
- 注释语言随项目;HecateFlow 自身蒸馏自中文工程,但生成的代码注释跟随目标工程惯例。
