param(
    [ValidateSet("check", "import")]
    [string]$Mode = "import"
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$GodotExe = "D:\Games\Godot_v4.6.2-stable_win64.exe\Godot_v4.6.2-stable_win64_console.exe"
$GodotSandboxRoot = Join-Path $ProjectRoot "tmp\godot_sandbox"

if (-not (Test-Path -LiteralPath $GodotExe)) {
    throw "Godot console executable was not found: $GodotExe"
}

foreach ($Dir in @(
    $GodotSandboxRoot,
    (Join-Path $GodotSandboxRoot "appdata"),
    (Join-Path $GodotSandboxRoot "localappdata"),
    (Join-Path $GodotSandboxRoot "temp"),
    (Join-Path $GodotSandboxRoot "xdg_data"),
    (Join-Path $GodotSandboxRoot "xdg_config"),
    (Join-Path $GodotSandboxRoot "xdg_cache")
)) {
    New-Item -ItemType Directory -Force -Path $Dir | Out-Null
}

$env:APPDATA = Join-Path $GodotSandboxRoot "appdata"
$env:LOCALAPPDATA = Join-Path $GodotSandboxRoot "localappdata"
$env:TEMP = Join-Path $GodotSandboxRoot "temp"
$env:TMP = Join-Path $GodotSandboxRoot "temp"
$env:XDG_DATA_HOME = Join-Path $GodotSandboxRoot "xdg_data"
$env:XDG_CONFIG_HOME = Join-Path $GodotSandboxRoot "xdg_config"
$env:XDG_CACHE_HOME = Join-Path $GodotSandboxRoot "xdg_cache"

$Args = @(
    "--headless",
    "--path", $ProjectRoot
)

if ($Mode -eq "import") {
    $Args += "--import"
} else {
    $Args += "--quit"
}

Write-Host "Running Godot in headless mode..."
Write-Host $GodotExe
Write-Host "Godot sandbox root: $GodotSandboxRoot"
Write-Host ($Args -join " ")

& $GodotExe @Args
exit $LASTEXITCODE
