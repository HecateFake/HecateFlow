# demo-app PROJECT

## Status Card

- Target: `demo-app`
- Build target: `demo_firmware`
- Toolchain: CMake
- Owned IO: `LED0-GPIO`

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
