#!/usr/bin/env sh
set -eu

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"

python3 - "$tmp" <<'PY'
import json
import sys

raw = open(sys.argv[1], "r", encoding="utf-8", errors="replace").read()
if not raw.strip():
    raise SystemExit(0)

try:
    event = json.loads(raw)
except Exception:
    raise SystemExit(0)

tool_name = str(event.get("tool_name") or "")
if tool_name not in {"Write", "Edit", "MultiEdit"}:
    raise SystemExit(0)

tool_input = event.get("tool_input") or {}
paths = []
for field in ("file_path", "path", "notebook_path"):
    value = tool_input.get(field)
    if isinstance(value, str) and value.strip() and value not in paths:
        paths.append(value)

path_text = "\n".join(f"- {path}" for path in paths) if paths else "- <path unavailable from hook input>"
context = f"""HecateFlow Claude Code PostToolUse hook fired after {tool_name}.

Changed path(s):
{path_text}

If the edit touched embedded source, headers, build config, linker config, hardware mapping, config headers, or target documentation, immediately run or explicitly account for `hf-auto-workflow` before continuing:
- confirm target and file semantics;
- scan ISR/volatile/numeric safety/actuator clamps;
- check relative paths and build registration;
- check polarity, magnitude, IO ownership, driver owner, fact confirmation, and lessons triggers when relevant;
- summarize as `HecateFlow Auto`.

If the changed file is outside HecateFlow's scope, state that the hook is a no-op for this edit.
"""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PostToolUse",
        "additionalContext": context,
    }
}, ensure_ascii=False, separators=(",", ":")))
PY
