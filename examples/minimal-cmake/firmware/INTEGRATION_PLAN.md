# Integration Plan

- Collaboration level: L0 for this tiny sample unless the change touches build registration, hardware polarity, or behavior-preserving refactor boundaries.
- Main agent starts with autonomous read-only discovery and keeps code and Git authority; subagents are read-only and proactively used for risky work when available.
- Ask the user only for external unverifiable facts, safety boundaries, hardware/physical risk, write-worker scope escalation risk, or Git/remote history changes.
- Write workers require the user to have explicitly asked to implement/modify/land/apply a patch (用户已明确要求实现/修改/落地/应用补丁), a determined plan, disjoint file scopes, explicit worker boundaries, and a stated validation command; read-only planning/review never enables write workers merely because research is sufficient.
- Report summary/tests/suggested commit message/files-to-stage first; stage/commit/push only after explicit user confirmation for the current change set.

- [ ] Add a new module under `firmware/code/app/`.
- [ ] Register new `.c` files in `CMakeLists.txt`.
- [ ] Update `firmware/PROJECT.md` module list.
- [ ] Run `hf-auto-workflow` and record `HecateFlow Check`.
