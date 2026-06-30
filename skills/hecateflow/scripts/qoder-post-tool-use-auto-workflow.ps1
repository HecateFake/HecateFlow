param()

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$raw = [Console]::In.ReadToEnd()
if ([string]::IsNullOrWhiteSpace($raw) -and $env:QODER_TOOL_INPUT_FILE_PATH) {
    if (Test-Path -LiteralPath $env:QODER_TOOL_INPUT_FILE_PATH) {
        $raw = Get-Content -LiteralPath $env:QODER_TOOL_INPUT_FILE_PATH -Raw
    }
}
if ([string]::IsNullOrWhiteSpace($raw)) {
    exit 0
}

try {
    $event = $raw | ConvertFrom-Json -ErrorAction Stop
} catch {
    exit 0
}

$toolName = [string]$event.tool_name
if ($toolName -notin @('Write', 'Edit', 'MultiEdit', 'create_file', 'search_replace')) {
    exit 0
}

$paths = [System.Collections.Generic.List[string]]::new()

function Add-PathCandidate {
    param([object]$Value)

    if ($null -eq $Value) { return }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return }
    if (-not $paths.Contains($text)) {
        $paths.Add($text) | Out-Null
    }
}

if ($event.cwd) {
    Add-PathCandidate ("cwd: " + [string]$event.cwd)
}

if ($event.tool_input) {
    foreach ($field in @('file_path', 'path', 'notebook_path', 'target_file', 'targetPath')) {
        if ($event.tool_input.PSObject.Properties.Name -contains $field) {
            Add-PathCandidate $event.tool_input.$field
        }
    }
}

$pathText = if ($paths.Count -gt 0) {
    ($paths | ForEach-Object { "- $_" }) -join "`n"
} else {
    "- <path unavailable from hook input>"
}

$context = @"
HecateFlow Qoder PostToolUse hook fired after $toolName.

Changed path(s):
$pathText

If the edit touched embedded source, headers, build config, linker config, hardware mapping, config headers, or target documentation, immediately run or explicitly account for `hf-auto-workflow` before continuing:
- confirm target and file semantics;
- scan ISR/volatile/numeric safety/actuator clamps;
- check relative paths and build registration;
- check polarity, magnitude, IO ownership, driver owner, fact confirmation, and lessons triggers when relevant;
- summarize as `HecateFlow Auto`.

If the changed file is outside HecateFlow's scope, state that the hook is a no-op for this edit.
"@

$output = [ordered]@{
    hookSpecificOutput = [ordered]@{
        hookEventName = 'PostToolUse'
        additionalContext = $context
    }
}

$output | ConvertTo-Json -Depth 8 -Compress
