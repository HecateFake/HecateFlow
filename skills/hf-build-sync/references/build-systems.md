# 构建系统登记法速查 / Build-system registration cheatsheet (reference)

`hf-build-sync` 的扩展资料。覆盖常见嵌入式构建系统"新增源文件如何登记"。判断起点:**该构建系统是否 glob 自动发现源文件?**(manifest `buildSystem.autoDiscover`)。若否,新增 `.c/.h` 必须手动登记,否则链接期 `undefined reference` 或 LSP 索引虚报。

---

## IAR Embedded Workbench(`.ewp`,autoDiscover = false)

IAR **不**自动发现 `project/code/` 下的新文件。每次新建源文件后立即编辑对应 `.ewp`:

```xml
<file>
    <name>$PROJ_DIR$\..\..\code\newModule.c</name>
</file>
<file>
    <name>$PROJ_DIR$\..\..\code\newModule.h</name>
</file>
```

硬约束:
- 路径前缀 `$PROJ_DIR$\...`(相对 `.ewp` 的位置),用**反斜杠**(Windows)。
- `.h` 虽不编译也要列(否则 IAR 工程树缺失,人工审阅会漏)。
- 新增子目录时三处同步:① `.ewp` 的 include 搜索路径(`<state>$PROJ_DIR$\...\sub</state>`)② `.ewp` 的 `<file>` 物理节点 ③ LSP 的 `-I`。
- 相关模块一起放(`proto.c/h` + `test.c/h`),不散开。
- 不跨 target 复制 `.ewp` 节点(同名文件跨核语义可能不同)。

验证:打开 IAR 工程树能看到新文件 + Rebuild 无 `undefined reference`。

---

## Keil µVision(`.uvprojx`,autoDiscover = false)

新增源文件需加入 `<File>` 节点(挂在某个 `<Group>` 下):

```xml
<File>
  <FileName>newModule.c</FileName>
  <FileType>1</FileType>
  <FilePath>..\code\newModule.c</FilePath>
</File>
```

include 路径在 `<VariousControls><IncludePath>` 里以 `;` 追加。`.h` 不需列入但目录要进 IncludePath。

---

## CMake(autoDiscover 取决于写法)

- **若用 `file(GLOB ...)`** 收集源:autoDiscover = true,新增文件无需改 CMake,但**仍要重新 configure**(GLOB 不随构建自动刷新,加 `CONFIGURE_DEPENDS` 缓解)。GLOB 在嵌入式工程被广泛认为反模式。
- **若显式列源**(推荐):autoDiscover = false,新增文件加进 `target_sources()`:

```cmake
target_sources(my_firmware PRIVATE
    src/newModule.c
)
target_include_directories(my_firmware PRIVATE src/newdir)
```

LSP:CMake 可生成 `compile_commands.json`(`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`),clangd 直接吃,通常无需手维护 `-I`。

---

## Make(autoDiscover 取决于写法)

- 用 `$(wildcard src/*.c)`:autoDiscover = true。
- 显式 `SRCS = a.c b.c`:autoDiscover = false,新增文件追加到 `SRCS`;新增头目录追加到 `CFLAGS += -Inewdir`。
- LSP:无 compile_commands 时用 `bear -- make` 生成,或手维护 `.clangd` 的 `-I`。

---

## PlatformIO(autoDiscover = true)

默认递归收集 `src/`,新增文件一般无需登记。例外:`lib_deps`/自定义 `src_filter` 时需调整。LSP 由 PlatformIO 生成 `compile_commands.json`。

---

## LSP(clangd)单独说明

无论构建系统如何,clangd 报"找不到头文件"的虚假红线时:
- 优先生成/更新 `compile_commands.json`(CMake/Make/bear)。
- 退而手维护 `.clangd` 的 `CompileFlags.Add: [-Inewdir, ...]`。
- 第三方/SDK 路径的噪声诊断用 `.clangd` 的 `Diagnostics.Suppress` 屏蔽,不改 SDK 头。
- PC 侧仿真子项目(x86)用独立 `.clangd`,不复用 MCU 的 `--target=arm-none-eabi`。
