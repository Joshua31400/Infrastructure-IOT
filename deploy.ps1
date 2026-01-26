# Deployment Infrastructure IoT Securisee - Windows

$Root = $PSScriptRoot
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "DEPLOIEMENT INFRASTRUCTURE IoT SECURISEE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Verifier Docker installe
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] Docker n'est pas installe !" -ForegroundColor Red
    exit 1
}

# Verifier Docker est en cours d'execution
try {
    docker ps | Out-Null
} catch {
    Write-Host "[ERREUR] Docker Desktop n'est pas demarre !" -ForegroundColor Red
    exit 1
}

# 1. Generer certificats
Write-Host "[1/6] Generation des certificats mTLS..." -ForegroundColor Cyan
Set-Location "$Root\certificates"
.\generate-certs.ps1
Set-Location "$Root"

# 2. Deployer Firewall FIRST (cree les 4 reseaux)
Write-Host "[2/6] Deploiement Firewall..." -ForegroundColor Cyan
Set-Location "$Root\firewall"
docker-compose up -d
Set-Location "$Root"

Write-Host "Attente firewall (10s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# 3. Deployer DMZ (utilise reseau zone-d-dmz)
Write-Host "[3/6] Deploiement Zone D (DMZ)..." -ForegroundColor Cyan
Set-Location "$Root\zone-d-dmz"
docker-compose up -d
Set-Location "$Root"

Write-Host "Attente services DMZ (20s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# 4. Deployer Zone A (IoT)
Write-Host "[4/6] Deploiement Zone A (Capteurs IoT)..." -ForegroundColor Cyan
Set-Location "$Root\zone-a-iot"
docker-compose up -d
Set-Location "$Root"

# 5. Deployer Zone B (Admin)
Write-Host "[5/6] Deploiement Zone B (Admin)..." -ForegroundColor Cyan
Set-Location "$Root\zone-b-admin"
docker-compose up -d
Set-Location "$Root"

# 6. Deployer Zone C (Bureautique)
Write-Host "[6/6] Deploiement Zone C (Bureautique)..." -ForegroundColor Cyan
Set-Location "$Root\zone-c-bureautique"
docker-compose up -d
Set-Location "$Root"

Write-Host ""
Write-Host "[OK] DEPLOIEMENT TERMINE !" -ForegroundColor Green
Write-Host ""
Write-Host "ACCES AUX SERVICES :" -ForegroundColor Cyan
Write-Host "  - Grafana    : http://localhost:3000 (admin/admin123)"
Write-Host "  - InfluxDB   : http://localhost:8086 (admin/adminpass123)"
Write-Host "  - MQTT Broker: mqtts://localhost:8883 (avec certificats)"
Write-Host ""
Write-Host "VERIFICATION :" -ForegroundColor Cyan
Write-Host "  docker ps"
Write-Host ""