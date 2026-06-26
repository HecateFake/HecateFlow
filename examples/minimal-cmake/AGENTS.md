# Minimal HecateFlow Example

This example is a tiny MCU-agnostic workspace used to test HecateFlow skill behavior.

## Target Routing

| keyword | target |
|---------|--------|
| demo / app / led | demo-app |

Before editing `firmware/code/**`, read `firmware/PROJECT.md` and `.hecateflow/project.json`.

## Rules

- Use relative paths only.
- New source files must be registered in `CMakeLists.txt`.
- Pins live in `firmware/code/config/pinMap.h`.
- Tunable constants and polarity live in `firmware/code/config/configDemo.h`.
