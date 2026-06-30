# demo-app PROJECT

## Status Card

- Target: `demo-app`
- Build target: `demo_firmware`
- Toolchain: CMake
- Owned IO: `LED0-GPIO`

## Collaboration Boundary

- Investigation, planning, review, and explanation start with autonomous read-only discovery before asking.
- Ask the user only for external unverifiable facts, safety boundaries, hardware/physical risk, write-worker scope escalation risk, or Git/remote history changes.
- Risky changes proactively use read-only review when available; the main agent verifies key evidence before editing.
- Write workers require the user to have explicitly asked to implement/modify/land/apply a patch (用户已明确要求实现/修改/落地/应用补丁), a determined plan, disjoint file scopes, and explicit worker boundaries; read-only planning/review never enables write workers merely because research is sufficient.
- Subagents and workers never stage, commit, or push; report summary/tests/suggested commit message/files-to-stage first, then wait for explicit user confirmation for the current change set.

## Identity

Minimal host-buildable C firmware target used for HecateFlow regression.

## Module List

| Path | Purpose |
|------|---------|
| `firmware/code/app/main.c` | Demo entry point |
| `firmware/code/config/pinMap.h` | Hardware pin map |
| `firmware/code/config/configDemo.h` | Tunable constants and polarity |

## Hazard Files / Pins

- `main.c`: demo target entry point, not a cross-target reusable driver.
- Pin source: `firmware/code/config/pinMap.h`

## Boundaries And Parameters

- No ISR in this sample.
- No dynamic allocation.
- `DEMO_LED_OUTPUT_DIR` is a placeholder polarity macro; real hardware must be identified before use.

## Verification

- `cmake -S . -B build`
- `cmake --build build`
- HecateFlow audit script passes from repository root.
