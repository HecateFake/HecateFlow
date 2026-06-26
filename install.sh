#!/usr/bin/env sh
# HecateFlow installer (POSIX / macOS / Linux / Git Bash)
# 把 skills/ 安装到 ~/.claude/skills 与 ~/.codex/skills,模板随 hecateflow 入口捆绑。幂等。
# 用法: sh install.sh   或   ./install.sh
set -eu

REPO="$(cd "$(dirname "$0")" && pwd)"
SKILLS_SRC="$REPO/skills"
TMPL_SRC="$REPO/templates"

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

# frontmatter name 唯一性自查(仅本包内)
names="$(grep -rhoE '^name:[[:space:]]*[A-Za-z0-9_-]+' "$SKILLS_SRC" 2>/dev/null | sed -E 's/^name:[[:space:]]*//' | sort)"
dupes="$(printf '%s\n' "$names" | uniq -d || true)"
[ -n "$dupes" ] && echo "[HecateFlow] WARN duplicate skill names: $dupes"

echo "[HecateFlow] skills: $(printf '%s ' $names)"
echo "[HecateFlow] done. 在 Claude Code / Codex 新会话里调用 'hecateflow' 开始。"
