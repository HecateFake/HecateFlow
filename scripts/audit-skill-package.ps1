param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string[]]$InstalledRoots = @(
        (Join-Path $env:USERPROFILE '.codex\skills'),
        (Join-Path $env:USERPROFILE '.claude\skills'),
        (Join-Path $env:USERPROFILE '.agents\skills')
    ),
    [switch]$SkipInstalled
)

$ErrorActionPreference = 'Stop'

function Fail($Message) {
    Write-Error $Message
    exit 1
}

function Get-BacktickRefs($Path) {
    $text = Get-Content -LiteralPath $Path -Raw
    [regex]::Matches($text, '`([^`]+\.(?:md|json|tmpl))`') | ForEach-Object {
        $_.Groups[1].Value
    }
}

function Get-HecateFlowFiles($Root) {
    $sourceSkills = Join-Path $Root 'skills'
    if (Test-Path -LiteralPath $sourceSkills) {
        return Get-ChildItem -LiteralPath $sourceSkills -Recurse -File -Include '*.md','SKILL.md','README.md'
    }

    $packageDirs = @(
        'hecateflow',
        'hf-init-workspace',
        'hf-init-project',
        'hf-design-module',
        'hf-implement',
        'hf-review',
        'hf-refactor',
        'hf-auto-workflow',
        'hf-embedded-safety',
        'hf-hw-mapping',
        'hf-build-sync',
        'hf-doc-discipline',
        'hf-lessons',
        'references'
    )

    $files = @()
    foreach ($dirName in $packageDirs) {
        $dir = Join-Path $Root $dirName
        if (Test-Path -LiteralPath $dir) {
            $files += Get-ChildItem -LiteralPath $dir -Recurse -File -Include '*.md','SKILL.md','README.md'
        }
    }
    return $files
}

function Test-PackageRefs($Root, [switch]$SourceLayout) {
    $files = Get-HecateFlowFiles $Root

    $missing = @()
    foreach ($file in $files) {
        $dir = Split-Path -Parent $file.FullName
        foreach ($raw in (Get-BacktickRefs $file.FullName)) {
            if ($raw -match '^https?://' -or
                $raw -match '^[A-Za-z]:\\' -or
                $raw -match '^~/' -or
                $raw -match '^\.hecateflow/' -or
                $raw -match '^\.claude/' -or
                $raw -match '^CLAUDE\.md$|^AGENTS\.md$|^README\.md$') { continue }
            if ($raw -match '[{}*<>]') { continue }
            if ($raw -in @('PROJECT.md','INDEX.md','INTEGRATION_PLAN.md','LIBRARY_VERSIONS.md','compile_commands.json','opencode.json','settings.json')) { continue }
            if ($raw -match '^docs/' -and $file.Name -ne 'README.md') { continue }

            $candidate = Join-Path $dir $raw
            if (Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue) { continue }

            if ($SourceLayout) {
                $alt = $null
                if ($raw -match '^\.\./hecateflow/templates/(.+)$') {
                    $alt = Join-Path $RepoRoot ('templates\' + $Matches[1])
                } elseif ($raw -match '^\.\./templates/(.+)$' -and $file.FullName -match '\\skills\\hecateflow\\references\\') {
                    $alt = Join-Path $RepoRoot ('templates\' + $Matches[1])
                }
                if ($alt -and (Test-Path -LiteralPath $alt)) { continue }
            }

            $missing += [pscustomobject]@{
                File = $file.FullName.Replace($Root + '\', '')
                Ref = $raw
                Expected = $candidate.Replace($Root + '\', '')
            }
        }
    }

    if ($missing) {
        $missing | Sort-Object File, Ref -Unique | Format-Table -AutoSize
        Fail "Package reference check failed for $Root"
    }
}

function Test-Frontmatter($SkillsRoot) {
    $files = Get-ChildItem -LiteralPath $SkillsRoot -Directory |
        ForEach-Object { Join-Path $_.FullName 'SKILL.md' } |
        Where-Object { Test-Path -LiteralPath $_ }

    $rows = foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file -Raw
        $fm = [regex]::Match($text, '(?s)^---\s*(.*?)\s*---')
        $name = if ($fm.Success -and $fm.Groups[1].Value -match '(?m)^name:\s*(.+)$') { $Matches[1].Trim() } else { '' }
        $desc = if ($fm.Success -and $fm.Groups[1].Value -match '(?m)^description:\s*(.+)$') { $Matches[1].Trim() } else { '' }
        [pscustomobject]@{
            Path = $file
            Name = $name
            HasFrontmatter = $fm.Success
            HasDescription = ($desc.Length -gt 0)
        }
    }

    $bad = $rows | Where-Object { -not $_.HasFrontmatter -or -not $_.Name -or -not $_.HasDescription }
    $dupes = $rows | Group-Object Name | Where-Object { $_.Name -and $_.Count -gt 1 }
    if ($bad -or $dupes) {
        $bad | Format-Table -AutoSize
        $dupes | Format-Table -AutoSize
        Fail 'Frontmatter check failed'
    }

    Write-Output "Frontmatter OK: $($rows.Count) skills"
}

function Test-StaleStrings($Root) {
    $patterns = @(
        'skills/references',
        'Task→spawn_agent',
        'multi_agent=true',
        '不支持外部 reference',
        'install 脚本会把 .*内联',
        '≥0 targets'
    )

    $files = Get-HecateFlowFiles $Root
    $hits = @()
    foreach ($file in $files) {
        $text = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($pattern in $patterns) {
            if ($text -match $pattern) {
                $hits += [pscustomobject]@{ File = $file.FullName.Replace($Root + '\', ''); Pattern = $pattern }
            }
        }
    }

    if ($hits) {
        $hits | Format-Table -AutoSize
        Fail "Stale string check failed for $Root"
    }
}

function Test-InstalledHashes($SourceSkills, $InstalledRoot) {
    $items = @(
        'hecateflow\SKILL.md',
        'hf-init-workspace\SKILL.md',
        'hf-lessons\SKILL.md',
        'hf-review\SKILL.md',
        'hf-refactor\SKILL.md',
        'hf-auto-workflow\SKILL.md',
        'hf-embedded-safety\SKILL.md',
        'hf-hw-mapping\SKILL.md',
        'references\tiered-docs.md',
        'hecateflow\scripts\claude-post-tool-use-auto-workflow.ps1',
        'hecateflow\scripts\claude-post-tool-use-auto-workflow.sh',
        'hecateflow\scripts\qoder-post-tool-use-auto-workflow.ps1',
        'hecateflow\scripts\qoder-post-tool-use-auto-workflow.sh',
        'hecateflow\references\codex-tools.md',
        'hecateflow\references\auto-injection.md',
        'hecateflow\references\manifest-schema.md'
    )

    $diff = @()
    foreach ($rel in $items) {
        $src = Join-Path $SourceSkills $rel
        $dst = Join-Path $InstalledRoot $rel
        $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
        $dstHash = if (Test-Path -LiteralPath $dst) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { 'MISSING' }
        if ($srcHash -ne $dstHash) {
            $diff += [pscustomobject]@{ Rel = $rel; SourceHash = $srcHash; InstalledHash = $dstHash }
        }
    }

    if ($diff) {
        $diff | Format-Table -AutoSize
        Fail "Installed root differs from source: $InstalledRoot"
    }
}

function Test-ReasonixConfig {
    $configPath = Join-Path $env:APPDATA 'reasonix\config.toml'
    if (-not (Test-Path -LiteralPath $configPath)) {
        Fail "Reasonix config missing: $configPath"
    }

    $lines = Get-Content -LiteralPath $configPath
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
        Fail "Reasonix [skills] section missing: $configPath"
    }

    $section = ($lines[$sectionStart..($sectionEnd - 1)] -join "`n")
    $expected = @(
        '~/.agents/skills',
        '~\.agents\skills',
        (Join-Path $env:USERPROFILE '.agents\skills')
    )

    $matched = $false
    foreach ($path in $expected) {
        if ($section -match [regex]::Escape($path)) {
            $matched = $true
            break
        }
    }

    if (-not $matched) {
        Fail "Reasonix [skills].paths does not include .agents skills root: $configPath"
    }

    Write-Output "Reasonix config OK: $configPath"
}

function Test-QoderRootInitialized {
    param([string]$Root)

    if (-not (Test-Path -LiteralPath $Root)) { return $false }
    foreach ($signal in @('settings.json','argv.json','extensions','memories','session-env','skills')) {
        if (Test-Path -LiteralPath (Join-Path $Root $signal)) { return $true }
    }
    return $false
}

function Get-QoderInstalledRoots {
    foreach ($root in @(
        (Join-Path $env:USERPROFILE '.qoder-cn'),
        (Join-Path $env:USERPROFILE '.qoder')
    )) {
        if (Test-QoderRootInitialized $root) {
            Join-Path $root 'skills'
        }
    }
}

function Test-HecateFlowHookObject {
    param([object]$Hook)

    if ($null -eq $Hook) { return $false }
    $command = ''
    if ($Hook.PSObject.Properties.Name -contains 'command') {
        $command = [string]$Hook.command
    }
    $joined = $command
    if ($Hook.PSObject.Properties.Name -contains 'args' -and $null -ne $Hook.args) {
        foreach ($arg in @($Hook.args)) {
            $joined += " $arg"
        }
    }
    return ($joined -match 'qoder-post-tool-use-auto-workflow' -or
            $joined -match 'hf-auto-workflow' -or
            $joined -match 'HecateFlow')
}

function Test-QoderHookConfig {
    $qoderRoots = @(
        (Join-Path $env:USERPROFILE '.qoder-cn'),
        (Join-Path $env:USERPROFILE '.qoder')
    ) | Where-Object { Test-QoderRootInitialized $_ }

    foreach ($root in $qoderRoots) {
        $settingsPath = Join-Path $root 'settings.json'
        if (-not (Test-Path -LiteralPath $settingsPath)) {
            Fail "Qoder settings missing: $settingsPath"
        }

        $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if (-not $settings.hooks -or -not $settings.hooks.PostToolUse) {
            Fail "Qoder PostToolUse hook missing: $settingsPath"
        }

        $found = $false
        foreach ($entry in @($settings.hooks.PostToolUse)) {
            $matcher = [string]$entry.matcher
            $hasClaudeWrite = $matcher -match 'Write|Edit|MultiEdit'
            $hasQoderWrite = $matcher -match 'create_file|search_replace'
            foreach ($hook in @($entry.hooks)) {
                if (-not (Test-HecateFlowHookObject $hook)) { continue }
                if ($hook.command -isnot [string] -or [string]::IsNullOrWhiteSpace($hook.command)) {
                    Fail "Qoder HecateFlow hook command must be a string: $settingsPath"
                }
                if ($hook.PSObject.Properties.Name -contains 'args' -and $null -ne $hook.args) {
                    foreach ($arg in @($hook.args)) {
                        if ($arg -isnot [string]) {
                            Fail "Qoder HecateFlow hook args must be strings: $settingsPath"
                        }
                    }
                }
                if (-not $hasClaudeWrite -or -not $hasQoderWrite) {
                    Fail "Qoder HecateFlow matcher must cover Claude and native write tools: $settingsPath"
                }
                $found = $true
            }
        }

        if (-not $found) {
            Fail "Qoder HecateFlow hook missing: $settingsPath"
        }
        Write-Output "Qoder hook config OK: $settingsPath"
    }
}

$skillsRoot = Join-Path $RepoRoot 'skills'
$manifestTemplate = Join-Path $RepoRoot 'templates\manifest.json'

Get-Content -LiteralPath $manifestTemplate -Raw | ConvertFrom-Json | Out-Null
Write-Output 'Manifest template JSON OK'

Test-Frontmatter $skillsRoot
Test-PackageRefs $RepoRoot -SourceLayout
Test-StaleStrings $RepoRoot
Write-Output 'Source package checks OK'

if (-not $SkipInstalled) {
    $rootsToCheck = @($InstalledRoots)
    if (-not $PSBoundParameters.ContainsKey('InstalledRoots')) {
        $rootsToCheck += @(Get-QoderInstalledRoots)
    }

    foreach ($installedRoot in ($rootsToCheck | Sort-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $installedRoot)) {
            Fail "Installed root missing: $installedRoot"
        }
        Test-PackageRefs $installedRoot
        Test-StaleStrings $installedRoot
        Test-InstalledHashes $skillsRoot $installedRoot
        Write-Output "Installed package checks OK: $installedRoot"
    }

    Test-ReasonixConfig
    Test-QoderHookConfig
}

Write-Output 'HecateFlow skill package audit passed.'
