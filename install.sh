#!/usr/bin/env sh
# HecateFlow installer (POSIX / macOS / Linux / Git Bash)
# 把 skills/ 安装到 ~/.claude/skills 与 ~/.codex/skills,模板随 hecateflow 入口捆绑。幂等。
# 用法: sh install.sh   或   ./install.sh
set -eu

SKIP_CLAUDE_HOOK=0
if [ "${1:-}" = "--skip-claude-hook" ]; then
    SKIP_CLAUDE_HOOK=1
fi

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO/skills"
TMPL_SRC="$REPO/templates"

install_claude_hook() {
    [ "$SKIP_CLAUDE_HOOK" -eq 0 ] || {
        echo "[HecateFlow] Claude Code hook skipped"
        return
    }

    if ! command -v python3 >/dev/null 2>&1; then
        echo "[HecateFlow] WARN python3 not found; Claude Code hook not installed"
        return
    fi

    settings="$HOME/.claude/settings.json"
    hook_script="$HOME/.claude/skills/hecateflow/scripts/claude-post-tool-use-auto-workflow.sh"
    mkdir -p "$HOME/.claude"
    [ ! -f "$settings" ] || cp "$settings" "$settings.hecateflow-hook.bak"

    python3 - "$settings" "$hook_script" <<'PY'
import json
import os
import shlex
import sys

settings_path, hook_script = sys.argv[1], sys.argv[2]

try:
    with open(settings_path, "r", encoding="utf-8") as f:
        settings = json.load(f)
except FileNotFoundError:
    settings = {}
except json.JSONDecodeError:
    raise SystemExit(f"[HecateFlow] ERROR invalid JSON: {settings_path}")

if not isinstance(settings, dict):
    settings = {}

hooks_root = settings.setdefault("hooks", {})
if not isinstance(hooks_root, dict):
    settings["hooks"] = hooks_root = {}

post = hooks_root.get("PostToolUse") or []
if not isinstance(post, list):
    post = []

def is_hecateflow_hook(hook):
    if not isinstance(hook, dict):
        return False
    command = str(hook.get("command") or "")
    parts = [command]
    args = hook.get("args") or []
    if isinstance(args, list):
        for item in args:
            if not isinstance(item, str) and ("powershell" in command or command.endswith("/bin/sh")):
                return True
            parts.append(str(item))
    joined = " ".join(parts)
    return (
        "claude-post-tool-use-auto-workflow" in joined
        or "hf-auto-workflow" in joined
        or "HecateFlow" in joined
    )

clean = []
for entry in post:
    if not isinstance(entry, dict):
        clean.append(entry)
        continue
    entry_hooks = entry.get("hooks") or []
    if not isinstance(entry_hooks, list):
        clean.append(entry)
        continue
    kept = [hook for hook in entry_hooks if not is_hecateflow_hook(hook)]
    if kept:
        cloned = dict(entry)
        cloned["hooks"] = kept
        clean.append(cloned)

clean.append({
    "matcher": "Write|Edit|MultiEdit",
    "hooks": [{
        "type": "command",
        "command": "/bin/sh " + shlex.quote(hook_script),
        "timeout": 10,
    }],
})

hooks_root["PostToolUse"] = clean

with open(settings_path, "w", encoding="utf-8") as f:
    json.dump(settings, f, ensure_ascii=False, indent=2)
    f.write("\n")
PY

    chmod +x "$hook_script" 2>/dev/null || true
    echo "[HecateFlow] Claude Code hook installed -> $settings"
}

for root in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
    mkdir -p "$root"

    # 复制 skills/ 下每个目录(含带 SKILL.md 的 skill 与共享 references/)
    for d in "$SKILLS_SRC"/*/; do
        [ -d "$d" ] || continue
        name="$(basename "$d")"
        rm -rf "$root/$name"
        cp -R "$d" "$root/$name"
    done

    # 模板捆绑到 hecateflow 入口下
    mkdir -p "$root/hecateflow"
    rm -rf "$root/hecateflow/templates"
    cp -R "$TMPL_SRC" "$root/hecateflow/templates"

    echo "[HecateFlow] installed -> $root"
done

install_claude_hook

# frontmatter name 唯一性自查(仅本包内)
names="$(grep -rhoE '^name:[[:space:]]*[A-Za-z0-9_-]+' "$SKILLS_SRC" 2>/dev/null | sed -E 's/^name:[[:space:]]*//' | sort)"
dupes="$(printf '%s\n' "$names" | uniq -d || true)"
[ -n "$dupes" ] && echo "[HecateFlow] WARN duplicate skill names: $dupes"

echo "[HecateFlow] skills: $(printf '%s ' $names)"
echo "[HecateFlow] done. 在 Claude Code / Codex 新会话里调用 'hecateflow' 开始。"
