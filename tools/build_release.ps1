<#
.SYNOPSIS
    Builds the signed release AAB for Google Play.

.DESCRIPTION
    1. Sets the version name and version code in project.godot and export_presets.cfg.
    2. Runs the headless test suite and stops if anything fails.
    3. Asks for the keystore password (hidden) and passes it to Godot through
       environment variables for this process only. Nothing is written to disk.
    4. Exports build/upsyflip-<version>.aab with the "Android Release" preset.

    Version rules: VersionName is MAJOR.MINOR.PATCH (what players see).
    VersionCode is a whole number that must be HIGHER than every build ever
    uploaded to Play Console, even for the same VersionName.

.EXAMPLE
    .\tools\build_release.ps1 -VersionName 1.0.0 -VersionCode 1
#>
param(
    [Parameter(Mandatory = $true)][ValidatePattern('^\d+\.\d+\.\d+$')][string]$VersionName,
    [Parameter(Mandatory = $true)][ValidateRange(1, 2100000000)][int]$VersionCode,
    [string]$KeystorePath = (Join-Path $env:USERPROFILE ".keystores\upsyflip-upload.jks"),
    [string]$Alias = "upsyflip-upload",
    [string]$Godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe",
    # Password for unattended builds; when omitted you are asked for it.
    [securestring]$KeystorePassword,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot
Set-Location $root
$utf8 = New-Object System.Text.UTF8Encoding $false

if (-not (Test-Path $KeystorePath)) {
    Write-Host "Keystore not found: $KeystorePath" -ForegroundColor Red
    Write-Host "Create it first with .\tools\create_release_keystore.ps1"
    exit 1
}

# --- 1. Version numbers -----------------------------------------------------
$project = [IO.File]::ReadAllText("$root\project.godot")
$project = $project -replace 'config/version="[^"]*"', "config/version=`"$VersionName`""
[IO.File]::WriteAllText("$root\project.godot", $project, $utf8)

$presets = [IO.File]::ReadAllText("$root\export_presets.cfg")
$presets = $presets -replace 'version/code=\d+', "version/code=$VersionCode"
$presets = $presets -replace 'version/name="[^"]*"', "version/name=`"$VersionName`""
[IO.File]::WriteAllText("$root\export_presets.cfg", $presets, $utf8)
Write-Host "Version set to $VersionName (code $VersionCode)"

# --- 2. Tests ---------------------------------------------------------------
& $Godot --headless --path $root --import | Out-Null
if (-not $SkipTests) {
    Write-Host "Running tests..."
    $testOutput = & $Godot --headless --path $root res://tests/test_runner.tscn 2>&1
    $testExit = $LASTEXITCODE
    $testOutput | Select-String "FAIL|TESTS:" | ForEach-Object { Write-Host $_.Line }
    if ($testExit -ne 0) {
        Write-Host "Tests failed. Release build cancelled." -ForegroundColor Red
        exit 1
    }
}

# --- 3. Signing credentials (this process only) -----------------------------
if (-not $KeystorePassword) {
    $KeystorePassword = Read-Host "Keystore password" -AsSecureString
}
$pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($KeystorePassword)
try {
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $KeystorePath
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $Alias
    $env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)

    # --- 4. Export ----------------------------------------------------------
    New-Item -ItemType Directory -Force "$root\build" | Out-Null
    $output = "build/upsyflip-$VersionName.aab"
    if (Test-Path "$root\$output") { Remove-Item "$root\$output" }
    Write-Host "Exporting $output ... (log: build\release_export.log)"
    # Gradle normally leaves a background daemon running that keeps this
    # console's output stream open, which would make the script hang after a
    # successful build. Run it without the daemon and log to a file instead.
    $env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"
    $logPath = "$root\build\release_export.log"
    & $Godot --headless --path $root --export-release "Android Release" $output *> $logPath
    $exportExit = $LASTEXITCODE
    $exportOutput = Get-Content $logPath
}
finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:GRADLE_OPTS -ErrorAction SilentlyContinue
}

if ($exportExit -ne 0 -or -not (Test-Path "$root\$output")) {
    $exportOutput | Select-String "ERROR|FAILED|What went wrong|error:" | Select-Object -Last 20 | ForEach-Object { Write-Host $_.Line }
    Write-Host "Export failed." -ForegroundColor Red
    exit 1
}

$sizeMb = [math]::Round((Get-Item "$root\$output").Length / 1MB, 1)
Write-Host ""
Write-Host "Done: $output ($sizeMb MB)" -ForegroundColor Green
Write-Host "Upload this file in Play Console. Commit the version change in project.godot and export_presets.cfg."
