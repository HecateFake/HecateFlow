# HecateFlow installer (Windows / PowerShell)
# 把 skills/ 安装到 ~/.claude/skills 与 ~/.codex/skills,模板随 hecateflow 入口捆绑。幂等。
# 用法: pwsh -File install.ps1   或   ./install.ps1

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path $repo "skills"
$tmplSrc   = Join-Path $repo "templates"

$targets = @(
    (Join-Path $env:USERPROFILE ".claude\skills"),
    (Join-Path $env:USERPROFILE ".codex\skills")
)

$installed = @()

foreach ($root in $targets) {
    New-Item -ItemType Directory -Force -Path $root | Out-Null

    # 复制 skills/ 下每个目录(含带 SKILL.md 的 skill 与共享 references/)
    Get-ChildItem -Path $skillsSrc -Directory | ForEach-Object {
        $name = $_.Name
        $dest = Join-Path $root $name
        if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
        Copy-Item -Recurse -Force $_.FullName $dest
        if (Test-Path (Join-Path $_.FullName "SKILL.md")) { $installed += $name }
    }

    # 模板捆绑到 hecateflow 入口下
    $tmplDest = Join-Path $root "hecateflow\templates"
    if (Test-Path $tmplDest) { Remove-Item -Recurse -Force $tmplDest }
    New-Item -ItemType Directory -Force -Path (Split-Path $tmplDest) | Out-Null
    Copy-Item -Recurse -Force $tmplSrc $tmplDest

    Write-Output "[HecateFlow] installed -> $root"
}

# frontmatter name 唯一性自查(仅本包内)
$names = Get-ChildItem -Path $skillsSrc -Directory -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue |
    ForEach-Object {
        $line = Select-String -Path $_.FullName -Pattern '^name:\s*(\S+)' | Select-Object -First 1
        if ($line) { $line.Matches[0].Groups[1].Value }
    }
$dupes = $names | Group-Object | Where-Object { $_.Count -gt 1 }
if ($dupes) { Write-Warning "duplicate skill names: $($dupes.Name -join ', ')" }

$uniqueInstalled = $installed | Sort-Object -Unique
Write-Output "[HecateFlow] skills: $($uniqueInstalled -join ', ')"
Write-Output "[HecateFlow] done. Start a new Claude Code / Codex session and invoke 'hecateflow'."
