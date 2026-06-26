# 嵌入式 C 编码风格 / Embedded C Style (reference)

> 被 `hf-auto-workflow` 第 4 步与 `hf-implement` 内联引用的风格基线。非独立 skill。
> 默认面向裸机 / RTOS 嵌入式 C(ARM Cortex-M、RISC-V MCU 等),按 manifest `workspace.language` 调整。

## 文件编码

- 源文件与文档统一 **UTF-8(无 BOM)**;除非工具链强制,否则不用 GBK/Latin-1。
- 行尾 LF;缩进按 manifest 约定(默认 4 空格,不用 Tab)。
- 从第三方/厂商库(常为 GBK/CP1252)同步文件时,先按原编码识别再以 UTF-8 无 BOM 写回。

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
