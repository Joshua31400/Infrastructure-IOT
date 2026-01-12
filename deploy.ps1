# Deployment Infrastructure IoT Securisee - Windows

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "DEPLOIEMENT INFRASTRUCTURE IoT SECURISEE" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

# Verifier Docker installe
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] Docker n'est pas installe !" -ForegroundColor Red
    Write-Host "Telecharger Docker Desktop: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
    exit 1
}

# Verifier Docker est en cours d'execution
try {
    docker ps | Out-Null
} catch {
    Write-Host "[ERREUR] Docker Desktop n'est pas demarre !" -ForegroundColor Red
    Write-Host "Lancer Docker Desktop et reessayer" -ForegroundColor Yellow
    exit 1
}

# 1. Generer certificats
Write-Host "[1/7] Generation des certificats mTLS..." -ForegroundColor Cyan
Set-Location certificates
.\generate-certs.ps1
Set-Location ..

# 2. Creer les reseaux Docker
Write-Host "[2/7] Creation des reseaux Docker..." -ForegroundColor Cyan

$networks = @(
    @{Name="zone-a-iot"; Subnet="192.168.10.0/24"; Gateway="192.168.10.1"},
    @{Name="zone-b-admin"; Subnet="192.168.20.0/24"; Gateway="192.168.20.1"},
    @{Name="zone-c-bureautique"; Subnet="192.168.30.0/24"; Gateway="192.168.30.1"},
    @{Name="zone-d-dmz"; Subnet="10.0.0.0/24"; Gateway="10.0.0.1"}
)

foreach ($net in $networks) {
    $exists = docker network ls --format "{{.Name}}" | Select-String -Pattern "^$($net.Name)$"
    if ($exists) {
        Write-Host "  [ATTENTION] Reseau $($net.Name) existe deja" -ForegroundColor Yellow
    } else {
        docker network create --subnet=$($net.Subnet) --gateway=$($net.Gateway) $($net.Name)
        Write-Host "  [OK] Reseau $($net.Name) cree" -ForegroundColor Green
    }
}

# 3. Deployer DMZ (services core)
Write-Host "[3/7] Deploiement Zone D (DMZ)..." -ForegroundColor Cyan
Set-Location zone-d-dmz
docker-compose up -d
Set-Location ..

Write-Host "Attente services DMZ (30s)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# 4. Deployer Firewall
Write-Host "[4/7] Deploiement Firewall..." -ForegroundColor Cyan
Set-Location firewall
docker-compose up -d
Set-Location ..

# 5. Deployer Zone A (IoT)
Write-Host "[5/7] Deploiement Zone A (Capteurs IoT)..." -ForegroundColor Cyan
Set-Location zone-a-iot
docker-compose up -d
Set-Location ..

# 6. Deployer Zone B (Admin)
Write-Host "[6/7] Deploiement Zone B (Admin)..." -ForegroundColor Cyan
Set-Location zone-b-admin
docker-compose up -d
Set-Location ..

# 7. Deployer Zone C (Bureautique)
Write-Host "[7/7] Deploiement Zone C (Bureautique)..." -ForegroundColor Cyan
Set-Location zone-c-bureautique
docker-compose up -d
Set-Location ..

Write-Host ""
Write-Host "[OK] DEPLOIEMENT TERMINE !" -ForegroundColor Green
Write-Host ""
Write-Host "ACCES AUX SERVICES :" -ForegroundColor Cyan
Write-Host "  - Grafana    : http://localhost:3000 (admin/admin123)"
Write-Host "  - InfluxDB   : http://localhost:8086 (admin/adminpass123)"
Write-Host "  - MQTT Broker: mqtts://localhost:8883 (avec certificats)"
Write-Host ""
Write-Host "TESTS RECOMMANDES :" -ForegroundColor Cyan
Write-Host "  1. Verifier capteurs : docker logs capteur-t1"
Write-Host "  2. Verifier firewall : docker logs firewall"
Write-Host "  3. Voir donnees MQTT : docker logs telegraf"
Write-Host "  4. Tester blocage    : docker exec client1 curl http://10.0.0.20:8883"
Write-Host ""
Write-Host "DOCUMENTATION : README.md" -ForegroundColor Cyan