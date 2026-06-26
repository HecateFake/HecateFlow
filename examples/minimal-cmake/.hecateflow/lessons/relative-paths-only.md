---
name: relative-paths-only
type: good-practice
trigger: "CMake include path / source registration / absolute path"
target: all
severity: medium
status: active
created: 2026-06-26
---

# Relative Paths Only

## Symptom

Build or LSP configuration works on one machine but fails after checkout elsewhere.

## Root Cause

Absolute machine paths were written into project metadata.

## How To Avoid

Use paths relative to the workspace or build file. Before committing, scan CMake/LSP/project files for drive-letter or home-directory paths.
