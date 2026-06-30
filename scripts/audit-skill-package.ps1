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

function Get-StaleStringFiles($Root) {
    $files = @()
    $files += @(Get-HecateFlowFiles $Root)

    foreach ($rel in @('README.md','install.ps1','install.sh','hecateflow\README.md')) {
        $path = Join-Path $Root $rel
        if (Test-Path -LiteralPath $path) {
            $files += Get-Item -LiteralPath $path
        }
    }

    foreach ($dirName in @('docs','templates','.codex-plugin','.claude-plugin','hecateflow\templates','hecateflow\docs')) {
        $dir = Join-Path $Root $dirName
        if (Test-Path -LiteralPath $dir) {
            $files += Get-ChildItem -LiteralPath $dir -Recurse -File -Include '*.md','*.tmpl','*.json'
        }
    }

    foreach ($scriptDirName in @('skills\hecateflow\scripts','hecateflow\scripts')) {
        $scriptDir = Join-Path $Root $scriptDirName
        if (Test-Path -LiteralPath $scriptDir) {
            $files += Get-ChildItem -LiteralPath $scriptDir -Recurse -File -Include '*.ps1','*.sh'
        }
    }

    return $files | Sort-Object FullName -Unique
}

function Test-TextContainsPatterns($Path, $Label, $Patterns) {
    if (-not (Test-Path -LiteralPath $Path)) {
        Fail "$Label missing: $Path"
    }

    $text = Get-Content -LiteralPath $Path -Raw
    foreach ($pattern in $Patterns) {
        if ($text -notmatch $pattern) {
            Fail "$Label missing required orchestration semantic '$pattern': $Path"
        }
    }
}

function Test-OrchestrationExactGate($Path, $Label, $Options) {
    Test-TextContainsPatterns $Path $Label $Options.Required
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
            if ($raw -in @('PROJECT.md','INDEX.md','INTEGRATION_PLAN.md','LIBRARY_VERSIONS.md','compile_commands.json','opencode.json','settings.json','.vscode/c_cpp_properties.json')) { continue }
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
        '≥0 targets',
        ('多代理工具可用且' + '用户明确授权'),
        ('用户明确授权' + '时使用'),
        ('只读' + '子代理.*' + '用户' + '授权'),
        ('只读子代理需要' + '用户确认'),
        ('用户' + '确认.*' + '只读'),
        ('explicit user ' + 'authorization')
    )

    $files = Get-StaleStringFiles $Root
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

function Test-OrchestrationContractCoverage($Root) {
    $sourceLayout = Test-Path -LiteralPath (Join-Path $Root 'skills\hecateflow\references\orchestration-contract.md')
    $base = if ($sourceLayout) { Join-Path $Root 'skills' } else { $Root }
    $contractPath = Join-Path $base 'hecateflow\references\orchestration-contract.md'

    if (-not (Test-Path -LiteralPath $contractPath)) {
        Fail "Orchestration contract missing: $contractPath"
    }

    $contractText = Get-Content -LiteralPath $contractPath -Raw
    foreach ($needle in @('主 agent 持权','只读子代理','复审链','Git 确认门','L0','L1','L2','L3','先自主求证','最小提问','主动派发只读子代理','并发槽位','防止占满并发上限')) {
        if ($contractText -notmatch [regex]::Escape($needle)) {
            Fail "Orchestration contract missing required phrase '$needle': $contractPath"
        }
    }
    Test-OrchestrationExactGate `
        $contractPath `
        'orchestration contract exact gate' `
        @{ Required = @('安全边界','用户已明确要求实现/修改/落地/应用补丁','L2/L3 多路只读调研 \+ 复审子代理 \+ 主 agent 亲验','子代理并发槽位纪律','关闭已完成','保留至少一个可用槽位','不能把并发上限写成把只读派发转嫁给用户确认的理由') }

    $skillDirs = @(
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
        'hf-lessons'
    )

    $missing = @()
    foreach ($dir in $skillDirs) {
        $path = Join-Path $base (Join-Path $dir 'SKILL.md')
        if (-not (Test-Path -LiteralPath $path)) {
            $missing += [pscustomobject]@{ File = $path.Replace($Root + '\', ''); Problem = 'missing SKILL.md' }
            continue
        }
        $text = Get-Content -LiteralPath $path -Raw
        if ($text -notmatch 'orchestration-contract') {
            $missing += [pscustomobject]@{ File = $path.Replace($Root + '\', ''); Problem = 'missing orchestration-contract reference' }
        }
    }

    if ($missing) {
        $missing | Format-Table -AutoSize
        Fail "Orchestration contract SKILL coverage failed for $Root"
    }

    if ($sourceLayout) {
        foreach ($exactCheck in @(
            [pscustomobject]@{
                Path = Join-Path $Root 'docs\methodology.md'
                Label = 'methodology exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁','主动只读并行,但管理并发槽位','防止占满并发上限')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hecateflow\SKILL.md'
                Label = 'hecateflow entry exact gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁','防止占满并发上限')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hecateflow\references\orchestration-contract.md'
                Label = 'orchestration concurrency slot gate'
                Required = @('子代理并发槽位纪律','关闭已完成','保留至少一个可用槽位','防止占满并发上限')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hf-design-module\SKILL.md'
                Label = 'hf-design-module exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hf-implement\SKILL.md'
                Label = 'hf-implement exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hf-hw-mapping\SKILL.md'
                Label = 'hf-hw-mapping exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hf-build-sync\SKILL.md'
                Label = 'hf-build-sync L3 orchestration gate'
                Required = @('L1-L3 分档','L3:构建图、LSP、文档矩阵同时变化','L1/L2/L3')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hf-review\SKILL.md'
                Label = 'hf-review concurrency slot gate'
                Required = @('防止占满并发上限','保留复审槽位')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hecateflow\references\claude-code-tools.md'
                Label = 'claude tools exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁','并发槽位','防止占满并发上限')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'skills\hecateflow\references\codex-tools.md'
                Label = 'codex tools exact worker gate'
                Required = @('用户已明确要求实现/修改/落地/应用补丁','wait_agent','close_agent','防止占满并发上限')
            }
        )) {
            Test-OrchestrationExactGate $exactCheck.Path $exactCheck.Label @{ Required = $exactCheck.Required }
        }

        $manifestPath = Join-Path $Root 'templates\manifest.json'
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -ErrorAction Stop
        if ($manifest.git.confirmationRequired -ne $true) {
            Fail "manifest template must set git.confirmationRequired=true"
        }
        if ($manifest.git.autoCommitPush -ne $false) {
            Fail "manifest template must set git.autoCommitPush=false"
        }
        foreach ($field in @('defaultMode','subagentDelegation','batchImplementationGate','gitConfirmationGate')) {
            if (-not $manifest.interaction -or
                -not ($manifest.interaction.PSObject.Properties.Name -contains $field) -or
                [string]::IsNullOrWhiteSpace([string]$manifest.interaction.$field)) {
                Fail "manifest template missing interaction.$field"
            }
        }
        if ($manifest.interaction.subagentDelegation -notmatch 'proactively delegate read-only') {
            Fail "manifest template interaction.subagentDelegation must proactively delegate read-only subagents"
        }
        if ($manifest.interaction.defaultMode -notmatch 'safety boundaries' -or
            $manifest.interaction.defaultMode -notmatch 'write-worker scope escalation risk' -or
            $manifest.interaction.defaultMode -notmatch 'user explicitly asks to implement/modify/land/apply a patch') {
            Fail "manifest template interaction.defaultMode must include all minimal-question categories and explicit write-mode request wording"
        }
        if ($manifest.interaction.batchImplementationGate -notmatch 'user has explicitly asked to implement/modify/land/apply a patch') {
            Fail "manifest template interaction.batchImplementationGate must require an explicit implementation/modify/land/patch request"
        }
        if ($manifest.interaction.gitConfirmationGate -notmatch 'summary/tests/suggested commit message/files-to-stage' -or
            $manifest.interaction.gitConfirmationGate -notmatch 'current change set') {
            Fail "manifest template interaction.gitConfirmationGate must require summary/tests/files-to-stage and current change-set confirmation"
        }

        $schemaPath = Join-Path $Root 'skills\hecateflow\references\manifest-schema.md'
        $schemaText = Get-Content -LiteralPath $schemaPath -Raw
        foreach ($field in @('git.confirmationRequired','git.autoCommitPush','interaction.defaultMode','interaction.subagentDelegation','interaction.batchImplementationGate','interaction.gitConfirmationGate')) {
            if ($schemaText -notmatch [regex]::Escape($field)) {
                Fail "manifest schema missing $field"
            }
        }

        foreach ($pluginPath in @(
            (Join-Path $Root '.codex-plugin\plugin.json'),
            (Join-Path $Root '.claude-plugin\plugin.json')
        )) {
            $plugin = Get-Content -LiteralPath $pluginPath -Raw | ConvertFrom-Json -ErrorAction Stop
            if ($plugin.version -ne '1.2.0') {
                Fail "plugin version must be 1.2.0: $pluginPath"
            }
            $pluginText = Get-Content -LiteralPath $pluginPath -Raw
            if ($pluginText -notmatch 'orchestration' -or $pluginText -notmatch 'git-confirmation' -or $pluginText -notmatch 'autonomy-first') {
                Fail "plugin metadata must mention autonomy-first orchestration and git-confirmation: $pluginPath"
            }
        }

        $readmePath = Join-Path $Root 'README.md'
        $readmeText = Get-Content -LiteralPath $readmePath -Raw
        if ($readmeText -notmatch 'v1\.2' -or $readmeText -notmatch 'orchestration-contract\.md' -or $readmeText -notmatch 'Git 确认门' -or $readmeText -notmatch '先自主求证') {
            Fail "README must advertise v1.2 autonomy-first orchestration contract and Git confirmation gate"
        }

        Test-TextContainsPatterns `
            (Join-Path $Root 'docs\methodology.md') `
            'methodology doc' `
            @('先自主求证','主动.*只读.*子代理','最小提问','安全边界','Git 确认门')

        foreach ($templateCheck in @(
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\workspace-guide.md.tmpl'
                Label = 'workspace-guide template'
                Patterns = @('先自主求证','只读子代理.*主动派发','最小提问','安全边界','Git 确认门')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\module-design.md.tmpl'
                Label = 'module-design template'
                Patterns = @('自主性分档','只读调研计划.*主动派发','最小提问','安全边界','不得 stage / commit / push')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\integration-plan.md.tmpl'
                Label = 'integration-plan template'
                Patterns = @('先自主求证','主动派发只读子代理','最小提问','安全边界','Git 确认门')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\PROJECT.md.tmpl'
                Label = 'PROJECT template'
                Patterns = @('默认自主探索','主动派发.*只读','最小提问','安全边界','Git 确认门')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\lesson.md.tmpl'
                Label = 'lesson template'
                Patterns = @('协作事故','未自主查证','越权 worker','Git 确认门','复审链')
            },
            [pscustomobject]@{
                Path = Join-Path $Root 'templates\lessons-index.md.tmpl'
                Label = 'lessons-index template'
                Patterns = @('协作事故','未自主查证','worker 越权','Git 确认门','复审链')
            }
        )) {
            Test-TextContainsPatterns $templateCheck.Path $templateCheck.Label $templateCheck.Patterns
        }

        foreach ($hookPath in @(
            (Join-Path $Root 'skills\hecateflow\scripts\claude-post-tool-use-auto-workflow.ps1'),
            (Join-Path $Root 'skills\hecateflow\scripts\claude-post-tool-use-auto-workflow.sh'),
            (Join-Path $Root 'skills\hecateflow\scripts\qoder-post-tool-use-auto-workflow.ps1'),
            (Join-Path $Root 'skills\hecateflow\scripts\qoder-post-tool-use-auto-workflow.sh')
        )) {
            $hookText = Get-Content -LiteralPath $hookPath -Raw
            if ($hookText -notmatch 'orchestration contract' -or $hookText -notmatch 'never stage, commit, or push automatically' -or $hookText -notmatch 'autonomously inspect available evidence') {
                Fail "hook must mention autonomous inspection, orchestration escalation, and no automatic Git: $hookPath"
            }
        }
    }
}

function Test-InstalledHashes($SourceSkills, $InstalledRoot) {
    $items = @()

    $sourceRoot = Split-Path -Parent $SourceSkills
    foreach ($sourceFile in (Get-ChildItem -LiteralPath $SourceSkills -Recurse -File)) {
        $skillRel = $sourceFile.FullName.Substring($SourceSkills.Length + 1)
        $items += [pscustomobject]@{
            Source = Join-Path 'skills' $skillRel
            Installed = $skillRel
        }
    }

    $templateRoot = Join-Path $sourceRoot 'templates'
    if (Test-Path -LiteralPath $templateRoot) {
        foreach ($template in (Get-ChildItem -LiteralPath $templateRoot -Recurse -File)) {
            $templateRel = $template.FullName.Substring($templateRoot.Length + 1)
            $items += [pscustomobject]@{
                Source = Join-Path 'templates' $templateRel
                Installed = Join-Path 'hecateflow\templates' $templateRel
            }
        }
    }

    $diff = @()
    foreach ($item in $items) {
        $srcRel = $item.Source
        $dstRel = $item.Installed
        $src = Join-Path $sourceRoot $srcRel
        $dst = Join-Path $InstalledRoot $dstRel
        $srcHash = (Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash
        $dstHash = if (Test-Path -LiteralPath $dst) { (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash } else { 'MISSING' }
        if ($srcHash -ne $dstHash) {
            $diff += [pscustomobject]@{ Rel = $dstRel; SourceHash = $srcHash; InstalledHash = $dstHash }
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
Test-OrchestrationContractCoverage $RepoRoot
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
        Test-OrchestrationContractCoverage $installedRoot
        Test-InstalledHashes $skillsRoot $installedRoot
        Write-Output "Installed package checks OK: $installedRoot"
    }

    Test-ReasonixConfig
    Test-QoderHookConfig
}

Write-Output 'HecateFlow skill package audit passed.'
