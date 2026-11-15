<#
.SYNOPSIS
    Creates the release (upload) keystore for Upsy Flip. Run this ONCE, yourself.

.DESCRIPTION
    keytool asks you for the password and your name interactively, so the
    password is never written to a file, a script or the terminal history.

    The keystore is created OUTSIDE the repository. Never commit it.
    If you lose the keystore or its password you cannot publish updates
    without asking Google to reset your upload key, so back it up
    (see docs/RELEASE_CHECKLIST.md).

.EXAMPLE
    .\tools\create_release_keystore.ps1
#>
param(
    [string]$KeystorePath = (Join-Path $env:USERPROFILE ".keystores\upsyflip-upload.jks"),
    [string]$Alias = "upsyflip-upload"
)

$ErrorActionPreference = "Stop"

if (Test-Path $KeystorePath) {
    Write-Host "A keystore already exists at $KeystorePath" -ForegroundColor Yellow
    Write-Host "Refusing to overwrite it. Delete or move it yourself if you really want a new one."
    exit 1
}

$keytool = Join-Path $env:JAVA_HOME "bin\keytool.exe"
if (-not (Test-Path $keytool)) {
    Write-Host "keytool not found. JAVA_HOME must point to JDK 17." -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force (Split-Path $KeystorePath) | Out-Null

Write-Host "Creating $KeystorePath (alias: $Alias)"
Write-Host "keytool will now ask for a password (twice) and your name/organization."
Write-Host "Choose a strong password and store it in a password manager." -ForegroundColor Cyan

& $keytool -genkeypair -v `
    -keystore $KeystorePath `
    -alias $Alias `
    -keyalg RSA -keysize 2048 -validity 10000 `
    -storetype PKCS12

if ($LASTEXITCODE -ne 0 -or -not (Test-Path $KeystorePath)) {
    Write-Host "Keystore was not created." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Done. Keystore: $KeystorePath" -ForegroundColor Green
Write-Host "Alias:    $Alias"
Write-Host "Next: back up this file and its password in two separate places,"
Write-Host "then build with .\tools\build_release.ps1"
