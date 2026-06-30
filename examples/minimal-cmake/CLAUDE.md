# Minimal HecateFlow Example

Mirror of `AGENTS.md` for Claude Code. Keep target routing and rules in sync.

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
- Investigation, planning, review, and explanation start with autonomous read-only discovery: inspect files, manifests, docs, diffs, and commands before asking.
- Ask the user only for external unverifiable facts, safety boundaries, hardware/physical risk, write-worker scope escalation risk, or Git/remote history changes.
- For risky changes, proactively use read-only subagents when available, review their evidence, then have the main agent verify key facts locally.
- Use write workers only after the user has explicitly asked to implement/modify/land/apply a patch (用户已明确要求实现/修改/落地/应用补丁), the plan is determined, file scopes are disjoint, and worker boundaries are explicit; read-only planning/review never escalates to write workers merely because research is sufficient.
- Subagents and workers never stage, commit, or push. Report summary/tests/suggested commit message/files-to-stage first; stage/commit/push only after explicit user confirmation for the current change set by the main agent.
