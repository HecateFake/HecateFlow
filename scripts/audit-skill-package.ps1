param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string[]]$InstalledRoots = @(
        (Join-Path $env:USERPROFILE '.codex\skills'),
        (Join-Path $env:USERPROFILE '.claude\skills')
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

$skillsRoot = Join-Path $RepoRoot 'skills'
$manifestTemplate = Join-Path $RepoRoot 'templates\manifest.json'

Get-Content -LiteralPath $manifestTemplate -Raw | ConvertFrom-Json | Out-Null
Write-Output 'Manifest template JSON OK'

Test-Frontmatter $skillsRoot
Test-PackageRefs $RepoRoot -SourceLayout
Test-StaleStrings $RepoRoot
Write-Output 'Source package checks OK'

if (-not $SkipInstalled) {
    foreach ($installedRoot in $InstalledRoots) {
        if (-not (Test-Path -LiteralPath $installedRoot)) {
            Fail "Installed root missing: $installedRoot"
        }
        Test-PackageRefs $installedRoot
        Test-StaleStrings $installedRoot
        Test-InstalledHashes $skillsRoot $installedRoot
        Write-Output "Installed package checks OK: $installedRoot"
    }
}

Write-Output 'HecateFlow skill package audit passed.'
