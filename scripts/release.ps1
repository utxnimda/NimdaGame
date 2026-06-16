param(
    [string]$Command = "plan",
    [string]$Version = "0.1.0",
    [string[]]$Target = @(),
    [switch]$Strict,
    [switch]$Execute
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Pipeline = Join-Path $RepoRoot "tools\mygame_tools\release_pipeline.py"

$ArgsList = @($Pipeline, $Command)

if ($Target.Count -gt 0) {
    $ArgsList += $Target
}

if ($Command -in @("export", "package", "notes", "publish", "all")) {
    $ArgsList += @("--version", $Version)
}

if ($Strict -and $Command -eq "check") {
    $ArgsList += "--strict"
}

if ($Execute -and $Command -eq "publish") {
    $ArgsList += "--execute"
}

Push-Location $RepoRoot
try {
    python @ArgsList
}
finally {
    Pop-Location
}
