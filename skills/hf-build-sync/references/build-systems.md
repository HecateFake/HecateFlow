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

## LSP(clangd)经验(对应 S3 六条,点 10)

**前置**:`hf-init-workspace` 先从 manifest、`compile_commands.json`、`.clangd`、`.vscode/c_cpp_properties.json`、构建工程文件中自主发现是否使用 clangd 补全/索引;只有仓库外 IDE 状态不可证且会改变同步风险边界时才最小提问。用则把配置方式记入 manifest `workspace.lsp{clangd:true,configStyle}`;不用则跳过本节(无虚假红线困扰,也无需维护 `-I`)。

无论构建系统如何,clangd 报"找不到头文件"的虚假红线或漏报时,六条经验:

1. **`.ewp`/构建工程文件 与 `.clangd` 是一对,同步改两处**:任何源文件路径/include 目录改动,既要进构建工程文件(否则链接 undefined),又要进 LSP 配置(否则索引虚报)。漏一个 → "一个过一个报错"。这是头号同步项。
2. **子目录化后按源文件深度分块 `-I`**:`project/code/` 拆子目录后,`.clangd` 里写死的相对回溯级数(`../../`)会因不同深度文件而失效。要么用 `If/PathMatch` 按目录分块给各自的 `-I`,要么改用 `compile_commands.json`(下条)免手算级数。
3. **优先 `compile_commands.json`,免手维护 `-I`**:CMake(`-DCMAKE_EXPORT_COMPILE_COMMANDS=ON`)/ Make(`bear -- make`)/ PlatformIO 都能生成;clangd 直接吃,新增文件/目录无需手改 `.clangd`。手维护 `-I` 是退路。
4. **SDK/第三方噪声诊断用 `Diagnostics.Suppress` 屏蔽,不改 SDK 头**:厂商库(常 GBK、非标扩展)的诊断刷屏时,在 `.clangd` 用 `Diagnostics.Suppress: ["*"]`(配 `PathMatch` 限定到 SDK 目录)消声,而非修改 SDK 源。
5. **跨 target 分叉的 LSP 配置禁跨核同步**:不同 target 的编译期常量分叉(如相机分辨率 94×60 vs 188×120、不同 `-D` 宏)会让 clangd 对入口保护代码的求值不同;把一个 target 的 `.clangd`/`-D` 抄给另一个 → 入口保护误判致功能段被索引器当死代码。每 target 独立配置。
6. **PC 仿真子项目用独立 x86 `.clangd`**:`tools/` 下的 PC 端仿真(对齐板端算法)用本地 `.clangd`,`--target` 留空 + `-xc -std=gnu11`,**不复用** MCU 的 `--target=arm-none-eabi`,否则标准头解析全错。

> 路径纪律(点 12):`.clangd` 的 `-I`、`compile_commands.json` 里的 include 一律**相对路径**,不写绝对机器路径,保证跨机/跨人可索引。
