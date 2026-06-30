#!/usr/bin/env sh
# HecateFlow installer (POSIX / macOS / Linux / Git Bash)
# 把 skills/ 安装到 Claude Code / Codex / Reasonix / Qoder 个人 skill 目录,模板随 hecateflow 入口捆绑。幂等。
# 用法: sh install.sh   或   ./install.sh
set -eu

SKIP_CLAUDE_HOOK=0
SKIP_REASONIX=0
SKIP_QODER=0
SKIP_QODER_HOOK=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --skip-claude-hook) SKIP_CLAUDE_HOOK=1 ;;
        --skip-reasonix) SKIP_REASONIX=1 ;;
        --skip-qoder) SKIP_QODER=1 ;;
        --skip-qoder-hook) SKIP_QODER_HOOK=1 ;;
        *)
            echo "[HecateFlow] ERROR unknown option: $1" >&2
            exit 1
            ;;
    esac
    shift
done

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
        or "qoder-post-tool-use-auto-workflow" in joined
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

install_skills_root() {
    root="$1"
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
}

qoder_root_initialized() {
    root="$1"
    [ -d "$root" ] || return 1
    for signal in settings.json argv.json extensions memories session-env skills; do
        [ -e "$root/$signal" ] && return 0
    done
    return 1
}

install_qoder_hook() {
    [ "$SKIP_QODER_HOOK" -eq 0 ] || {
        echo "[HecateFlow] Qoder hook skipped"
        return
    }

    if ! command -v python3 >/dev/null 2>&1; then
        echo "[HecateFlow] WARN python3 not found; Qoder hook not installed"
        return
    fi

    qoder_root="$1"
    settings="$qoder_root/settings.json"
    hook_script="$qoder_root/skills/hecateflow/scripts/qoder-post-tool-use-auto-workflow.sh"
    mkdir -p "$qoder_root"
    [ ! -f "$settings" ] || cp "$settings" "$settings.hecateflow-hook.bak"

    python3 - "$settings" "$hook_script" <<'PY'
import json
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
        parts.extend(str(item) for item in args)
    joined = " ".join(parts)
    return (
        "claude-post-tool-use-auto-workflow" in joined
        or "qoder-post-tool-use-auto-workflow" in joined
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
    "matcher": "Write|Edit|MultiEdit|create_file|search_replace",
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
    echo "[HecateFlow] Qoder hook installed -> $settings"
}

toml_string() {
    printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"
}

install_reasonix_config() {
    [ "$SKIP_REASONIX" -eq 0 ] || {
        echo "[HecateFlow] Reasonix install skipped"
        return
    }

    config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
    reasonix_dir="$config_home/reasonix"
    config="$reasonix_dir/config.toml"
    skill_path="~/.agents/skills"
    mkdir -p "$reasonix_dir"

    if [ ! -f "$config" ]; then
        {
            echo "[skills]"
            printf 'paths = [%s]\n' "$(toml_string "$skill_path")"
        } > "$config"
        echo "[HecateFlow] Reasonix skills path registered -> $config"
        return
    fi

    cp "$config" "$config.hecateflow-skills.bak"
    python3 - "$config" "$skill_path" <<'PY'
import re
import sys

path, skill_path = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    lines = f.read().splitlines()

def toml_string(value):
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'

section_start = -1
section_end = len(lines)
for index, line in enumerate(lines):
    if re.match(r"^\s*\[skills\]\s*$", line):
        section_start = index
        for end in range(index + 1, len(lines)):
            if re.match(r"^\s*\[", lines[end]):
                section_end = end
                break
        break

if section_start < 0:
    if lines and lines[-1].strip():
        lines.append("")
    lines.extend(["[skills]", f"paths = [{toml_string(skill_path)}]"])
else:
    paths_line = -1
    for index in range(section_start + 1, section_end):
        if re.match(r"^\s*paths\s*=", lines[index]):
            paths_line = index
            break

    if paths_line < 0:
        lines.insert(section_start + 1, f"paths = [{toml_string(skill_path)}]")
    elif skill_path not in lines[paths_line]:
        match = re.search(r"\]\s*(#.*)?$", lines[paths_line])
        if not match:
            raise SystemExit(f"[HecateFlow] ERROR unsupported Reasonix paths format in {path}")
        comment = match.group(1)
        prefix = lines[paths_line][: lines[paths_line].rfind("]")]
        suffix = f" {comment}" if comment else ""
        lines[paths_line] = f"{prefix}, {toml_string(skill_path)}]{suffix}"

with open(path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
PY

    echo "[HecateFlow] Reasonix skills path registered -> $config"
}

install_skills_root "$HOME/.claude/skills"
install_skills_root "$HOME/.codex/skills"
if [ "$SKIP_REASONIX" -eq 0 ]; then
    install_skills_root "$HOME/.agents/skills"
fi
if [ "$SKIP_QODER" -eq 0 ]; then
    qoder_any=0
    for qoder_root in "$HOME/.qoder-cn" "$HOME/.qoder"; do
        if qoder_root_initialized "$qoder_root"; then
            qoder_any=1
            install_skills_root "$qoder_root/skills"
            install_qoder_hook "$qoder_root"
        fi
    done
    [ "$qoder_any" -eq 1 ] || echo "[HecateFlow] Qoder install skipped: no initialized .qoder-cn/.qoder root found"
else
    echo "[HecateFlow] Qoder install skipped"
fi

install_claude_hook
install_reasonix_config

# frontmatter name 唯一性自查(仅本包内)
names="$(grep -rhoE '^name:[[:space:]]*[A-Za-z0-9_-]+' "$SKILLS_SRC" 2>/dev/null | sed -E 's/^name:[[:space:]]*//' | sort)"
dupes="$(printf '%s\n' "$names" | uniq -d || true)"
[ -n "$dupes" ] && echo "[HecateFlow] WARN duplicate skill names: $dupes"

echo "[HecateFlow] skills: $(printf '%s ' $names)"
echo "[HecateFlow] done. 在 Claude Code / Codex / Reasonix / Qoder 新会话里调用 'hecateflow' 开始。"
