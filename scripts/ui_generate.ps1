param(
    [string]$Style = "neon_arcade",
    [string[]]$Slot = @(),
    [switch]$DryRun,
    [switch]$WriteSkin,
    [string]$Model = "",
    [string]$Size = "",
    [string]$Quality = "",
    [string]$OutputFormat = "",
    [string]$Background = "",
    [string]$Provider = "",
    [string]$AspectRatio = "",
    [string]$ImageSize = "",
    [string]$PersonGeneration = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Tool = Join-Path $RepoRoot "tools\mygame_tools\ui_ai_provider.py"

$Command = if ($DryRun) { "dry-run" } else { "generate" }
$ArgsList = @($Tool)

if ($Provider -ne "") {
    $ArgsList += @("--provider", $Provider)
}

$ArgsList += @($Command, "--style", $Style)

foreach ($SlotId in $Slot) {
    $ArgsList += @("--slot", $SlotId)
}

if ($WriteSkin) {
    $ArgsList += "--write-skin"
}

if ($Model -ne "") {
    $ArgsList += @("--model", $Model)
}

if ($Size -ne "") {
    $ArgsList += @("--size", $Size)
}

if ($Quality -ne "") {
    $ArgsList += @("--quality", $Quality)
}

if ($OutputFormat -ne "") {
    $ArgsList += @("--output-format", $OutputFormat)
}

if ($Background -ne "") {
    $ArgsList += @("--background", $Background)
}

if ($AspectRatio -ne "") {
    $ArgsList += @("--aspect-ratio", $AspectRatio)
}

if ($ImageSize -ne "") {
    $ArgsList += @("--image-size", $ImageSize)
}

if ($PersonGeneration -ne "") {
    $ArgsList += @("--person-generation", $PersonGeneration)
}

Push-Location $RepoRoot
try {
    python @ArgsList
}
finally {
    Pop-Location
}
