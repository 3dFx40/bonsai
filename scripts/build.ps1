param(
    [ValidateSet('Android', 'Windows Desktop')][string]$Target = 'Android',
    [switch]$Release,
    [string]$Godot = ''
)
$ErrorActionPreference = 'Stop'
$projectDir = Split-Path -Parent $PSScriptRoot
if (-not $Godot) {
    $binary = Get-ChildItem -LiteralPath (Join-Path $projectDir '.tools\godot') -Filter '*console.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($binary) { $Godot = $binary.FullName }
    else { $Godot = (Get-Command godot -ErrorAction Stop).Source }
}
$env:APPDATA = Join-Path $projectDir '.tools\userdata'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory -Force -Path (Join-Path $projectDir 'builds') | Out-Null
$mode = if ($Release) { '--export-release' } else { '--export-debug' }
$name = if ($Target -eq 'Android') { if ($Release) { 'Bonsai-release.apk' } else { 'Bonsai-debug.apk' } } else { 'Bonsai.exe' }
& $Godot --headless --path $projectDir $mode $Target (Join-Path $projectDir "builds\$name")
exit $LASTEXITCODE
