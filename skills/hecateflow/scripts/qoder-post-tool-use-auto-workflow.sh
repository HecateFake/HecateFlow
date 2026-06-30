#!/usr/bin/env sh
set -eu

if ! command -v python3 >/dev/null 2>&1; then
    exit 0
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
cat > "$tmp"

if [ ! -s "$tmp" ] && [ -n "${QODER_TOOL_INPUT_FILE_PATH:-}" ] && [ -f "$QODER_TOOL_INPUT_FILE_PATH" ]; then
    cp "$QODER_TOOL_INPUT_FILE_PATH" "$tmp"
fi

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
if tool_name not in {"Write", "Edit", "MultiEdit", "create_file", "search_replace"}:
    raise SystemExit(0)

tool_input = event.get("tool_input") or {}
paths = []
cwd = event.get("cwd")
if isinstance(cwd, str) and cwd.strip():
    paths.append("cwd: " + cwd)

for field in ("file_path", "path", "notebook_path", "target_file", "targetPath"):
    value = tool_input.get(field)
    if isinstance(value, str) and value.strip() and value not in paths:
        paths.append(value)

path_text = "\n".join(f"- {path}" for path in paths) if paths else "- <path unavailable from hook input>"
context = f"""HecateFlow Qoder PostToolUse hook fired after {tool_name}.

Changed path(s):
{path_text}

If the edit touched embedded source, headers, build config, linker config, hardware mapping, config headers, or target documentation, immediately run or explicitly account for `hf-auto-workflow` before continuing:
- autonomously inspect available evidence first; do not ask the user for facts discoverable from files, manifest, docs, diff, or commands;
- confirm target and file semantics;
- scan ISR/volatile/numeric safety/actuator clamps;
- check relative paths and build registration;
- check polarity, magnitude, IO ownership, driver owner, fact confirmation, and lessons triggers when relevant;
- if risk is L1-L3, follow the HecateFlow orchestration contract: proactively use read-only review or hf-review when available, then have the main agent verify key evidence;
- never stage, commit, or push automatically; report Git suggestions first and wait for user confirmation;
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
