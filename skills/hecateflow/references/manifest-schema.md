# 工程清单 schema:`.hecateflow/project.json` v1

HecateFlow 的"持久化交互记忆"。放在**目标工作区根目录**的 `.hecateflow/project.json`。所有 skill 启动先读它做默认值,只问缺失项,用完写回。

## 设计原则

- **读多写少**:业务 skill(design/implement/review/refactor/safety...)默认只读;写集中在 `hf-init-workspace`(创建)与 `hf-init-project`(追加 target)。
- **字段级独立**:每个 target 一项,多 agent 并行时各改各的 `targets[]` 项,降低写竞争。
- **读-改-写 + 校验**:任何写操作先读全量、只改自己负责的字段、按本 schema 校验后写回;不 `git add .` 式整体覆盖。
- **MCU 无关**:所有字段都是自由文本/枚举,不假设具体芯片;CYT4BB7/IAR 只是 `mcuFamily`/`toolchain` 的一种取值。

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
    "indent": "4-spaces"
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
      "ownedPeripherals": [      // 独占外设白名单(hf-embedded-safety 用)
        { "device": "string", "owner": "string", "gate": "whitelist-#if" }
      ],
      "hazardFiles": ["string"], // 跨 target 同名不同义的高危文件,如 ["motor.c","IMU.c","PID.c"]
      "docPath": "string",       // 该 target 的 PROJECT.md 路径
      "buildTarget": "string"    // 对应 .ewp/cmake target 名
    }
  ],

  "docs": {
    "rootGuide": "string",       // 跨 target 纲领,如 "CLAUDE.md"/"AGENTS.md"/"docs/README.md"
    "sharedLibVersions": "string", // 共享库版本登记表路径(可空)
    "glossary": "string",        // 术语表(可空)
    "pinout": "string"           // 引脚表(可空)
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
    "docSync": true
  },

  "git": {
    "commitFormat": "string",    // 如 "<scope>: <desc>" 或 "AIG_<scope>_<desc>"
    "remotes": ["origin"],       // 多远端则多项(双推等)
    "defaultBranch": "main",
    "neverAddAll": true          // 只 add 本次编辑文件,禁止 git add .
  },

  "interaction": {
    "askUserQuestionSchema": "questions[]{question,header,options}"
  }
}
```

## 最小可用清单

只有 `version` + `workspace` + 至少一个 `targets[]` 项即可工作。其余字段缺失时 skill 用内置默认值并在需要时 AskUserQuestion 补全。
