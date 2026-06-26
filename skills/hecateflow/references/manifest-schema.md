# 工程清单 schema:`.hecateflow/project.json` v1

HecateFlow 的"持久化交互记忆"。放在**目标工作区根目录**的 `.hecateflow/project.json`。所有 skill 启动先读它做默认值,只问缺失项,用完写回。

## 设计原则

- **读多写少**:业务 skill(design/implement/review/refactor/safety...)默认只读;写集中在 `hf-init-workspace`(创建)与 `hf-init-project`(追加 target)。
- **字段级独立**:每个 target 一项,多 agent 并行时各改各的 `targets[]` 项,降低写竞争。
- **读-改-写 + 校验**:任何写操作先读全量、只改自己负责的字段、按本 schema 校验后写回;不 `git add .` 式整体覆盖。
- **MCU 无关**:所有字段都是自由文本/枚举,不假设具体芯片;CYT4BB7/IAR 只是 `mcuFamily`/`toolchain` 的一种取值。
- **相对路径优先**(横切点 12):manifest 内所有路径字段一律填**工作区相对路径**(`config/pinMap.h`、`.hecateflow/lessons/`),不写绝对机器路径(`<盘符>:\...`、`/home/...` 这类),保证 manifest 跨机/跨人可移植。

## 字段

```jsonc
{
  "$schema": "hecateflow/manifest-v1",
  "version": 1,

  "workspace": {
    "name": "string",            // 工程名
    "mcuFamily": "string",       // 自由文本:"cyt4bb7" / "stm32f4" / "esp32" / "rp2040" ...
    "arch": "string",            // "cortex-m7" / "cortex-m4f" / "riscv32" ...
    "toolchain": "string",       // "iar" / "keil" / "gcc-arm" / "cmake-ninja" / "platformio" ...
    "language": "c",             // 默认源语言
    "encoding": "utf-8-no-bom",  // 源文件编码约定
    "indent": "4-spaces",

    "scenario": {                // 固化的工程应用场景(点 1)。hf-init-workspace 采集,业务 skill 只读;
                                 // 作"为什么这样设计"的常驻上下文,避免每会话重述。
      "domain": "string",        // 自由文本:"智能车麦轮底盘 + 悬停飞机" / "BLDC 电机驱动器" / "四旋翼飞控"
      "constraints": ["string"], // 硬约束:"飞机↔车模禁无线、仅有线链路" / "车不可离地" / "桨驱动受安全检查"
      "safetyRules": ["string"], // 安全规则:"PWM 必须钳幅 ±LIMIT" / "ISR 禁阻塞/禁浮点密集" / "饱和持续→失控锁定"
      "forbidden": ["string"]    // 禁止项:"禁动态内存/递归" / "禁 git add ." / "禁跨核同步相机分辨率"
    },

    "lsp": {                     // 语言服务器(点 10)。hf-init-workspace **主动询问**是否用 clangd。
      "clangd": false,           // 是否用 clangd 补全/索引(true 才需维护 .clangd / -I,见 hf-build-sync)
      "configStyle": "string"    // "compile_commands.json"(优先,免手维护 -I) / ".clangd-manual-I" / "none"
    }
  },

  "paths": {                     // 路径纪律(横切点 12)
    "preferRelative": true       // 目标工程构建(IAR `$PROJ_DIR$\..`)/include/LSP -I/脚本一律相对路径
  },

  "buildSystem": {
    "type": "string",            // "iar-ewp" / "keil-uvprojx" / "cmake" / "make" / "platformio"
    "autoDiscover": false,       // 是否 glob 自动发现源文件(决定 hf-build-sync 是否必跑)
    "registration": {            // 新增源文件如何登记(hf-build-sync 用)
      "projectFile": "string",   // glob/路径,如 "**/project_config/*.ewp" 或 "CMakeLists.txt"
      "sourceNode": "string",    // 源文件登记位置,如 ".ewp <file> 节点" / "target_sources()"
      "includePathField": "string", // 工程 include 搜索路径写在哪
      "lspConfig": "string"      // LSP 配置,如 ".clangd 的 -I" / "compile_commands.json"
    }
  },

  "targets": [                   // 每个可独立构建的核/芯片/固件一项
    {
      "id": "string",            // "core0" / "mcu-main" / "app"
      "role": "string",          // 自由文本职责描述
      "subCores": ["string"],    // 可选:多核 MCU 的子核,如 ["cm_7_0","cm_7_1"]
      "language": "c",

      "layout": {                // 非扁平布局(点 6)。hf-init-project 据此脚手架,hf-design-module 据此放置新模块。
        "style": "feature-subdirs", // "feature-subdirs"(按功能分子目录,推荐) / "flat"
        "subdirs": ["string"]    // 如 ["app","control","sensor","comm","config","util"];各子目录自给自足
      },
      "headers": {               // 集中头(点 6 & 11)
        "pinMap": "string",      // 硬件映射头路径,如 "config/pinMap.h"(零依赖纯 #define,引脚单一真相源)
        "configHeaders": ["string"], // 参数调节头,如 ["config/configMotor.h"](分节编译期宏单一真相源)
        "polaritySource": "string"   // 极性/方向系数单一真相源(点 11),通常 = 某 configHeader 的 §极性段;
                                     // 执行器/传感器/闭环极性**独立列此**,改前必核实物理接线
      },

      "ownedPeripherals": [      // 独占外设白名单(点 7 & 13)。hf-embedded-safety / hf-design-module 用
        {
          "device": "string",    // "IPS114-SPI" / "UART0-debug" / "shared-ADC" / "I2C0-bus" ...
          "owner": "string",     // 占用的核/子核/上下文,如 "core2.cm_7_0"
          "io": true,            // 是否带 IO 操作(true → 多核归属敏感,**须主动提醒用户做分核任务规划**)
          "gate": "whitelist-#if", // 门控方式:白名单 #if(非黑名单,防新增模式默认抢占)
          "planNote": "string"   // 分核规划备注:谁拥有 / 其它核如何让出 / 冲突时怎么仲裁
        }
      ],
      "hazardFiles": ["string"], // 跨 target 同名不同义的高危文件,如 ["motor.c","IMU.c","PID.c"]
      "docPath": "string",       // 该 target 的 PROJECT.md 路径(相对)
      "buildTarget": "string"    // 对应 .ewp/cmake target 名
    }
  ],

  "docs": {
    "rootGuide": "string",       // 跨 target 纲领,如 "CLAUDE.md"/"AGENTS.md"/"docs/README.md"
    "sharedLibVersions": "string", // 共享库版本登记表路径(可空)
    "glossary": "string",        // 术语表(可空)
    "pinout": "string"           // 跨核引脚冲突矩阵(可空;与各 target headers.pinMap 配对,先改 pinMap 再更新)
  },

  "lessons": {                   // 工程经验记忆(点 3 & 7)。hf-lessons 维护,**本地存储跨平台**(Codex 也能读)
    "dir": ".hecateflow/lessons/",       // 单条 lesson 目录(frontmatter type/trigger + 症状/根因/如何避免)
    "index": ".hecateflow/lessons/INDEX.md" // lessons 索引;相关编辑前先检索命中→规避"不再犯"
  },

  "autoInjection": {             // 规则/skill 自动注入(点 9)。hf-init-workspace 搭建,保证规则被自动加载
    "instructionsFiles": ["string"], // 各 CLI 入口自动加载的规则列表,如 opencode.json 的 instructions[]
    "mirrorPairs": [             // 须保持内容一致的镜像入口对(改一处须同步另一处)
      { "a": "CLAUDE.md", "b": "AGENTS.md" }
    ],
    "hooks": ["string"]          // 可选 harness hook 片段(如 PostToolUse 触发 auto-workflow 审查)
  },

  "planFile": {                  // plan→build 工作流约定
    "convention": "INTEGRATION_PLAN.md",
    "location": "贴近被改 target 的目录",
    "deleteOnComplete": true
  },

  "simulation": {                // 先仿真后上板(可选)
    "enabled": false,
    "tools": [
      { "kind": "string", "path": "string", "alignsWith": "string" }
    ]
  },

  "activeChecks": {              // hf-auto-workflow 激活哪些检查项
    "targetConfirm": true,
    "volatile": true,
    "isrSafety": true,
    "numericSafety": true,
    "style": true,
    "docSync": true,
    "polarityMagnitude": true,   // 极性/数量级主动提醒确认(点 11)
    "relativePaths": true,       // 相对路径检查(点 12)
    "ioOwnership": true,         // IO 外设归属确认(点 7 & 13)
    "lessonsCapture": true       // 踩坑/被纠正时触发 lessons 记录(点 7)
  },

  "git": {
    "commitFormat": "string",    // 如 "<scope>: <desc>" 或 "AIG_<scope>_<desc>"
    "remotes": ["origin"],       // 多远端则多项(双推等);提交后须推全部远端
    "defaultBranch": "main",
    "neverAddAll": true          // 只 add 本次编辑文件,禁止 git add .(见 references/git-discipline.md)
  },

  "interaction": {
    "askUserQuestionSchema": "questions[]{question,header,options}"
  }
}
```

## 新增字段说明(v1 增量)

| 字段 | 经验点 | 谁写 | 谁读 |
|------|--------|------|------|
| `workspace.scenario` | 1 固化场景 | hf-init-workspace | 全部业务 skill(常驻"为什么") |
| `workspace.lsp` | 10 clangd | hf-init-workspace(询问) | hf-build-sync |
| `paths.preferRelative` | 12 相对路径 | hf-init-workspace | 全部(横切) |
| `targets[].layout` | 6 非扁平 | hf-init-project | hf-design-module / hf-build-sync |
| `targets[].headers` | 6 & 11 头组织/极性 | hf-init-project | hf-hw-mapping / hf-design-module |
| `targets[].ownedPeripherals[].io / planNote` | 7 & 13 IO 归属/分核 | hf-init-project | hf-embedded-safety / hf-design-module |
| `lessons` | 3 & 7 自进化/不再犯 | hf-lessons | 全部(编辑前检索) |
| `autoInjection` | 9 自动注入 | hf-init-workspace | hf-doc-discipline |

> 详细机制见 `auto-injection.md`(注入)、`../../references/git-discipline.md`(git)、`../../references/tiered-docs.md`(分级文档)。

## 最小可用清单

工作区初始化阶段只需要 `version` + `workspace`(含 `name`) 即可写出最小 manifest,`targets[]` 可为空;进入实现/审查/重构等业务阶段前,必须已有可判定的 target,否则先用 `hf-init-project` 追加至少一个 `targets[]` 项。其余字段缺失时 skill 用内置默认值并在需要时 AskUserQuestion 补全。`scenario` / `lessons` / `autoInjection` 为空时,对应 skill 退化为"每次询问"而非"读默认",不阻塞。
