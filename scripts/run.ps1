param(
    [switch]$Editor,
    [switch]$Test,
    [switch]$Capture,
    [string]$Godot = ''
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $binary = Get-ChildItem -LiteralPath (Join-Path $projectDir '.tools\godot') -Filter '*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($binary) { $Godot = $binary.FullName }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
# Keep development saves and engine settings inside this project.
$env:APPDATA = Join-Path $projectDir '.tools\userdata'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
if ($Test) {
    & $Godot --headless --path $projectDir --editor --import --quit
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    foreach ($suite in @('tree_test', 'simulation_test', 'save_test', 'readiness_test', 'input_test', 'localization_test', 'experience_test')) {
        & $Godot --headless --path $projectDir --script "res://tests/$suite.gd" -- --integration
        if ($LASTEXITCODE) { exit $LASTEXITCODE }
    }
    & $Godot --headless --path $projectDir --script res://tests/relaunch_test.gd
    if ($LASTEXITCODE) { exit $LASTEXITCODE }
    & $Godot --headless --path $projectDir --quit-after 10 -- --smoke
} elseif ($Editor) {
    & $Godot --path $projectDir --editor
} elseif ($Capture) {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectDir 'builds') | Out-Null
    & $Godot --path $projectDir -- --capture
} else {
    & $Godot --path $projectDir
}
exit $LASTEXITCODE
