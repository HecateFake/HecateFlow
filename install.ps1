# HecateFlow installer (Windows / PowerShell)
# 把 skills/ 安装到 Claude Code / Reasonix(.agents) / Qoder 个人 skill 目录,模板随 hecateflow 入口捆绑。幂等。
# Codex Desktop 会同时索引 ~/.codex/skills 与 ~/.agents/skills;默认只通过 ~/.agents/skills 提供 HecateFlow,避免重复显示。
# 用法: pwsh -File install.ps1

param(
    [switch]$SkipClaudeHook,
    [switch]$SkipReasonix,
    [switch]$SkipQoder,
    [switch]$SkipQoderHook,
    [switch]$InstallCodex
)

$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) {
        throw "HecateFlow install.ps1 requires PowerShell 7+ (pwsh) to preserve JSON hook array shapes. Install PowerShell 7, then run: pwsh -NoProfile -ExecutionPolicy Bypass -File install.ps1"
    }

    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }
    $forwardArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File',$scriptPath)
    if ($SkipClaudeHook) { $forwardArgs += '-SkipClaudeHook' }
    if ($SkipReasonix) { $forwardArgs += '-SkipReasonix' }
    if ($SkipQoder) { $forwardArgs += '-SkipQoder' }
    if ($SkipQoderHook) { $forwardArgs += '-SkipQoderHook' }
    if ($InstallCodex) { $forwardArgs += '-InstallCodex' }
    & $pwsh.Source @forwardArgs
    exit $LASTEXITCODE
}

$repo = Split-Path -Parent $MyInvocation.MyCommand.Path
$skillsSrc = Join-Path $repo "skills"
$tmplSrc   = Join-Path $repo "templates"

$targets = @(
    (Join-Path $env:USERPROFILE ".claude\skills")
)
$codexRoot = Join-Path $env:USERPROFILE ".codex\skills"
if ($InstallCodex) {
    $targets += $codexRoot
}
$reasonixRoot = Join-Path $env:USERPROFILE ".agents\skills"
if (-not $SkipReasonix) {
    $targets += $reasonixRoot
}

function Test-QoderRootInitialized {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return $false }
    foreach ($signal in @('settings.json','argv.json','extensions','memories','session-env','skills')) {
        if (Test-Path -LiteralPath (Join-Path $Root $signal)) { return $true }
    }
    return $false
}

$qoderRoots = @()
if (-not $SkipQoder) {
    $qoderRoots = @(
        (Join-Path $env:USERPROFILE ".qoder-cn"),
        (Join-Path $env:USERPROFILE ".qoder")
    ) | Where-Object { Test-QoderRootInitialized $_ }
    $targets += @($qoderRoots | ForEach-Object { Join-Path $_ "skills" })
}

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
        $items = @()
        foreach ($item in $Value) {
            $items += ,(ConvertTo-Hashtable $item)
        }
        # PowerShell enumerates function return arrays by default; unary comma preserves JSON array shape on PS 5.1 and 7+.
        return ,$items
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
        $command = ''
        if ($Hook.Contains('command')) {
            $command = [string]$Hook['command']
            $parts += $command
        }
        if ($Hook.Contains('args')) {
            foreach ($arg in @($Hook['args'])) {
                if ($arg -isnot [string] -and $command -match '(^|\\|/)powershell(\.exe)?($|\s)') {
                    return $true
                }
                $parts += [string]$arg
            }
        }
    }

    $joined = ($parts -join ' ')
    return ($joined -match 'claude-post-tool-use-auto-workflow' -or
            $joined -match 'qoder-post-tool-use-auto-workflow' -or
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

    $hookCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $HookScript + '"'
    $hookEntry = [ordered]@{
        matcher = 'Write|Edit|MultiEdit'
        hooks = @(
            [ordered]@{
                type = 'command'
                command = $hookCommand
                timeout = 10
            }
        )
    }

    $settings['hooks']['PostToolUse'] = @($clean + $hookEntry)
    $settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $settingsPath -Encoding utf8

    Write-Output "[HecateFlow] Claude Code hook installed -> $settingsPath"
}

function Install-QoderHook {
    param(
        [string]$QoderRoot,
        [string]$HookScript
    )

    $settingsPath = Join-Path $QoderRoot "settings.json"
    New-Item -ItemType Directory -Force -Path $QoderRoot | Out-Null

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

    $hookCommand = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File "' + $HookScript + '"'
    $hookEntry = [ordered]@{
        matcher = 'Write|Edit|MultiEdit|create_file|search_replace'
        hooks = @(
            [ordered]@{
                type = 'command'
                command = $hookCommand
                timeout = 10
            }
        )
    }

    $settings['hooks']['PostToolUse'] = @($clean + $hookEntry)
    $settings | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $settingsPath -Encoding utf8

    Write-Output "[HecateFlow] Qoder hook installed -> $settingsPath"
}

function ConvertTo-TomlString($Value) {
    return '"' + (($Value -replace '\\', '\\') -replace '"', '\"') + '"'
}

function Install-ReasonixConfig {
    param([string]$SkillsRoot)

    $reasonixDir = Join-Path $env:APPDATA "reasonix"
    $configPath = Join-Path $reasonixDir "config.toml"
    $skillPath = "~/.agents/skills"
    New-Item -ItemType Directory -Force -Path $reasonixDir | Out-Null

    if (-not (Test-Path -LiteralPath $configPath)) {
        @(
            "[skills]",
            "paths = [$((ConvertTo-TomlString $skillPath))]"
        ) | Set-Content -LiteralPath $configPath -Encoding utf8
        Write-Output "[HecateFlow] Reasonix skills path registered -> $configPath"
        return
    }

    Copy-Item -LiteralPath $configPath -Destination ($configPath + ".hecateflow-skills.bak") -Force
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.AddRange([string[]](Get-Content -LiteralPath $configPath))

    $sectionStart = -1
    $sectionEnd = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\[skills\]\s*$') {
            $sectionStart = $i
            for ($j = $i + 1; $j -lt $lines.Count; $j++) {
                if ($lines[$j] -match '^\s*\[') {
                    $sectionEnd = $j
                    break
                }
            }
            break
        }
    }

    if ($sectionStart -lt 0) {
        if ($lines.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($lines[$lines.Count - 1])) {
            $lines.Add("")
        }
        $lines.Add("[skills]")
        $lines.Add("paths = [$((ConvertTo-TomlString $skillPath))]")
        Set-Content -LiteralPath $configPath -Value $lines -Encoding utf8
        Write-Output "[HecateFlow] Reasonix skills path registered -> $configPath"
        return
    }

    $pathsLine = -1
    for ($i = $sectionStart + 1; $i -lt $sectionEnd; $i++) {
        if ($lines[$i] -match '^\s*paths\s*=') {
            $pathsLine = $i
            break
        }
    }

    if ($pathsLine -lt 0) {
        $lines.Insert($sectionStart + 1, "paths = [$((ConvertTo-TomlString $skillPath))]")
    } elseif ($lines[$pathsLine] -notmatch [regex]::Escape($skillPath) -and
              $lines[$pathsLine] -notmatch [regex]::Escape($SkillsRoot)) {
        $line = $lines[$pathsLine]
        if ($line -match '\]\s*(#.*)?$') {
            $comment = $Matches[1]
            $prefix = $line.Substring(0, $line.LastIndexOf(']'))
            $suffix = if ($comment) { " $comment" } else { "" }
            $lines[$pathsLine] = "$prefix, $((ConvertTo-TomlString $skillPath))]$suffix"
        } else {
            throw "Unsupported Reasonix paths format in $configPath"
        }
    }

    Set-Content -LiteralPath $configPath -Value $lines -Encoding utf8
    Write-Output "[HecateFlow] Reasonix skills path registered -> $configPath"
}

function Test-DirectoryMatchesSource {
    param(
        [string]$Source,
        [string]$Destination
    )

    if (-not (Test-Path -LiteralPath $Source) -or -not (Test-Path -LiteralPath $Destination)) {
        return $false
    }

    $srcFiles = @(Get-ChildItem -LiteralPath $Source -Recurse -File | ForEach-Object {
        $_.FullName.Substring($Source.Length + 1)
    } | Sort-Object)
    $dstFiles = @(Get-ChildItem -LiteralPath $Destination -Recurse -File | ForEach-Object {
        $_.FullName.Substring($Destination.Length + 1)
    } | Sort-Object)

    if ($srcFiles.Count -ne $dstFiles.Count) { return $false }
    for ($i = 0; $i -lt $srcFiles.Count; $i++) {
        if ($srcFiles[$i] -ne $dstFiles[$i]) { return $false }
        $srcHash = (Get-FileHash -LiteralPath (Join-Path $Source $srcFiles[$i]) -Algorithm SHA256).Hash
        $dstHash = (Get-FileHash -LiteralPath (Join-Path $Destination $dstFiles[$i]) -Algorithm SHA256).Hash
        if ($srcHash -ne $dstHash) { return $false }
    }

    return $true
}

function Clear-CodexDuplicateInstall {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) {
        Write-Output "[HecateFlow] Codex install cleanup skipped: $Root not found"
        return
    }

    Get-ChildItem -LiteralPath $skillsSrc -Directory |
        Where-Object { $_.Name -eq 'hecateflow' -or $_.Name -like 'hf-*' } |
        ForEach-Object {
            $dest = Join-Path $Root $_.Name
            if (Test-Path -LiteralPath $dest) {
                Remove-Item -LiteralPath $dest -Recurse -Force
                Write-Output "[HecateFlow] removed duplicate Codex skill -> $dest"
            }
        }

    $srcReferences = Join-Path $skillsSrc 'references'
    $dstReferences = Join-Path $Root 'references'
    if (Test-Path -LiteralPath $dstReferences) {
        if (Test-DirectoryMatchesSource $srcReferences $dstReferences) {
            Remove-Item -LiteralPath $dstReferences -Recurse -Force
            Write-Output "[HecateFlow] removed duplicate Codex references -> $dstReferences"
        } else {
            Write-Warning "[HecateFlow] kept $dstReferences because it does not exactly match this package's skills\references"
        }
    }

    Write-Output "[HecateFlow] Codex uses ~/.agents/skills by default; use -InstallCodex only for legacy Codex-only installs"
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

if (-not $InstallCodex) {
    Clear-CodexDuplicateInstall $codexRoot
}

if (-not $SkipReasonix) {
    Install-ReasonixConfig $reasonixRoot
} else {
    Write-Output "[HecateFlow] Reasonix install skipped"
}

if (-not $SkipClaudeHook) {
    $hookScript = Join-Path $env:USERPROFILE ".claude\skills\hecateflow\scripts\claude-post-tool-use-auto-workflow.ps1"
    Install-ClaudeHook $hookScript
} else {
    Write-Output "[HecateFlow] Claude Code hook skipped"
}

if ($SkipQoder) {
    Write-Output "[HecateFlow] Qoder install skipped"
} elseif ($qoderRoots.Count -eq 0) {
    Write-Output "[HecateFlow] Qoder install skipped: no initialized .qoder-cn/.qoder root found"
} elseif ($SkipQoderHook) {
    Write-Output "[HecateFlow] Qoder hook skipped"
} else {
    foreach ($qoderRoot in $qoderRoots) {
        $hookScript = Join-Path $qoderRoot "skills\hecateflow\scripts\qoder-post-tool-use-auto-workflow.ps1"
        Install-QoderHook $qoderRoot $hookScript
    }
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
Write-Output "[HecateFlow] done. Start a new Claude Code / Codex / Reasonix / Qoder session and invoke 'hecateflow'."
