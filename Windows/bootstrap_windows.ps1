# bootstrap_windows.ps1
# Führt unter Windows automatisch:
#  - Admin-Check
#  - Installation von Chocolatey (falls nötig)
#  - Installation von OpenSSL, Git, Docker Desktop
#  - Ausführung von setup_pki_nginx.ps1

Param(
    [string]$ProjectRoot = $(Get-Location).Path
)

Write-Host "=== OpenSSL-PKI-Docker-Automation Windows Bootstrap ===" -ForegroundColor Cyan

# ------------------------------
# 1. Admin-Check
# ------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Bitte PowerShell als Administrator starten (Rechtsklick → 'Als Administrator ausführen')." -ForegroundColor Red
    exit 1
}

Write-Host "PowerShell läuft mit Administratorrechten." -ForegroundColor Green

# ------------------------------
# 2. Chocolatey installieren (falls nicht vorhanden)
# ------------------------------
$chocoExe = Join-Path $env:ProgramData "chocolatey\bin\choco.exe"

if (-not (Test-Path $chocoExe)) {
    Write-Host "Chocolatey ist nicht installiert. Installation wird gestartet..." -ForegroundColor Yellow

    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12

    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "Chocolatey wurde installiert." -ForegroundColor Green
    } catch {
        Write-Error "Fehler bei der Installation von Chocolatey: $_"
        exit 1
    }
} else {
    Write-Host "Chocolatey ist bereits installiert." -ForegroundColor Green
}

# Sicherstellen, dass choco im PATH ist
$env:Path += ";$env:ProgramData\chocolatey\bin"

# ------------------------------
# 3. Tools installieren: OpenSSL, Git, Docker Desktop
# ------------------------------

$packages = @("openssl", "git", "docker-desktop")

foreach ($pkg in $packages) {
    Write-Host "Prüfe Paket: $pkg ..." -ForegroundColor Cyan
    $pkgInfo = choco list --local-only $pkg 2>$null | Select-String "^$pkg "
    if (-not $pkgInfo) {
        Write-Host "Installiere $pkg ..." -ForegroundColor Yellow
        choco install -y $pkg
    } else {
        Write-Host "$pkg ist bereits installiert." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Hinweis: Docker Desktop erfordert normalerweise einen Logout/Reboot nach der Installation." -ForegroundColor Yellow
Write-Host "Wenn Docker noch nicht gestartet ist, bitte Docker Desktop einmal manuell öffnen." -ForegroundColor Yellow
Write-Host ""

# ------------------------------
# 4. OpenSSL Pfad ermitteln
# ------------------------------
$OpenSslDefaultPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

if (Test-Path $OpenSslDefaultPath) {
    $OpenSslPath = $OpenSslDefaultPath
} elseif (Get-Command openssl -ErrorAction SilentlyContinue) {
    $OpenSslPath = (Get-Command openssl).Source
} else {
    Write-Error "OpenSSL wurde nicht gefunden, obwohl die Installation durchlaufen ist. Bitte Pfad manuell anpassen."
    exit 1
}

Write-Host "Verwende OpenSSL unter: $OpenSslPath" -ForegroundColor Green

# ------------------------------
# 5. setup_pki_nginx.ps1 ausführen
# ------------------------------

$SetupScript = Join-Path $ProjectRoot "setup_pki_nginx.ps1"

if (-not (Test-Path $SetupScript)) {
    Write-Error "setup_pki_nginx.ps1 wurde im Projektordner nicht gefunden: $ProjectRoot"
    Write-Host "Bitte stelle sicher, dass setup_pki_nginx.ps1 im selben Ordner liegt wie bootstrap_windows.ps1."
    exit 1
}

Write-Host "Starte PKI-Setup via setup_pki_nginx.ps1 ..." -ForegroundColor Cyan
Write-Host ""

# setup_pki_nginx.ps1 wurde so gebaut, dass es ein OpenSslPath-Parameter hat
& $SetupScript -ProjectRoot $ProjectRoot -OpenSslPath $OpenSslPath

Write-Host ""
Write-Host "=== Bootstrap & PKI-Setup unter Windows abgeschlossen. ===" -ForegroundColor Green
Write-Host "Wechsle in den docker-Ordner und starte Nginx mit:" -ForegroundColor Yellow
Write-Host "  cd `"$ProjectRoot\docker`""
Write-Host "  docker compose up --build"
Write-Host ""
