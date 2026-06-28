# HecateFlow installer (Windows / PowerShell)
# 把 skills/ 安装到 ~/.claude/skills 与 ~/.codex/skills,模板随 hecateflow 入口捆绑。幂等。
# 用法: pwsh -File install.ps1   或   ./install.ps1

param(
    [switch]$SkipClaudeHook
)

$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path $repo "skills"
$tmplSrc   = Join-Path $repo "templates"

$targets = @(
    (Join-Path $env:USERPROFILE ".claude\skills"),
    (Join-Path $env:USERPROFILE ".codex\skills")
)

$installed = @()

function ConvertTo-Hashtable($Value) {
    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $out[$key] = ConvertTo-Hashtable $Value[$key]
        }
        return $out
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return @($Value | ForEach-Object { ConvertTo-Hashtable $_ })
    }

    if ($Value -is [pscustomobject]) {
        $out = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) {
            $out[$prop.Name] = ConvertTo-Hashtable $prop.Value
        }
        return $out
    }

    return $Value
}

function Test-HecateFlowHook($Hook) {
    if ($null -eq $Hook) { return $false }

    $parts = @()
    if ($Hook -is [System.Collections.IDictionary]) {
        if ($Hook.Contains('command')) { $parts += [string]$Hook['command'] }
        if ($Hook.Contains('args')) { $parts += @($Hook['args'] | ForEach-Object { [string]$_ }) }
    }

    $joined = ($parts -join ' ')
    return ($joined -match 'claude-post-tool-use-auto-workflow' -or
            $joined -match 'hf-auto-workflow' -or
            $joined -match 'HecateFlow')
}

function Install-ClaudeHook {
    param([string]$HookScript)

    $claudeDir = Join-Path $env:USERPROFILE ".claude"
    $settingsPath = Join-Path $claudeDir "settings.json"
    New-Item -ItemType Directory -Force -Path $claudeDir | Out-Null

    $settings = [ordered]@{}
    if (Test-Path -LiteralPath $settingsPath) {
        Copy-Item -LiteralPath $settingsPath -Destination ($settingsPath + ".hecateflow-hook.bak") -Force
        $raw = Get-Content -LiteralPath $settingsPath -Raw
        if (-not [string]::IsNullOrWhiteSpace($raw)) {
            $settings = ConvertTo-Hashtable ($raw | ConvertFrom-Json -ErrorAction Stop)
        }
    }

    if (-not ($settings -is [System.Collections.IDictionary])) {
        $settings = [ordered]@{}
    }
    if (-not $settings.Contains('hooks') -or $null -eq $settings['hooks'] -or
        -not ($settings['hooks'] -is [System.Collections.IDictionary])) {
        $settings['hooks'] = [ordered]@{}
    }

    $postToolUse = @()
    if ($settings['hooks'].Contains('PostToolUse') -and $null -ne $settings['hooks']['PostToolUse']) {
        $postToolUse = @($settings['hooks']['PostToolUse'])
    }

    $clean = @()
    foreach ($entry in $postToolUse) {
        if ($entry -isnot [System.Collections.IDictionary]) {
            $clean += $entry
            continue
        }

        $hooks = @()
        if ($entry.Contains('hooks') -and $null -ne $entry['hooks']) {
            $hooks = @($entry['hooks']) | Where-Object { -not (Test-HecateFlowHook $_) }
        }

        if ($hooks.Count -gt 0) {
            $entry['hooks'] = @($hooks)
            $clean += $entry
        }
    }

    $hookEntry = [ordered]@{
        matcher = 'Write|Edit|MultiEdit'
        hooks = @(
            [ordered]@{
                type = 'command'
                command = 'powershell.exe'
                args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $HookScript)
                timeout = 10
            }
        )
    }

    $settings['hooks']['PostToolUse'] = @($clean + $hookEntry)
    $settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $settingsPath -Encoding utf8

    Write-Output "[HecateFlow] Claude Code hook installed -> $settingsPath"
}

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

if (-not $SkipClaudeHook) {
    $hookScript = Join-Path $env:USERPROFILE ".claude\skills\hecateflow\scripts\claude-post-tool-use-auto-workflow.ps1"
    Install-ClaudeHook $hookScript
} else {
    Write-Output "[HecateFlow] Claude Code hook skipped"
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
