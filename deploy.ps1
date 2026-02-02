# Ce script deploye l'infrastructure complète automatiquement
Clear-Host
# Initialisation des variables
$Root = $PSScriptRoot
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "+----------------------------------------+" -ForegroundColor Cyan
Write-Host "|DEPLOIEMENT INFRASTRUCTURE IoT SECURISEE|" -ForegroundColor Cyan
Write-Host "+----------------------------------------+" -ForegroundColor Cyan
Write-Host "> LDAPS - MQTT mTLS - GRAFANA - OPENVPN <" -ForegroundColor DarkGray
Write-Host ""

# Verifier si Docker est installé
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] Docker n'est pas installe !" -ForegroundColor Red
    exit 1
}

# Verifier si Docker est en cours d'execution
try {
    docker ps | Out-Null
} catch {
    Write-Host "[ERREUR] Docker Desktop n'est pas demarre !" -ForegroundColor Red
    exit 1
}

# 1. Generer certificats MQTT + LDAPS
Write-Host "==========================================" -ForegroundColor Green
Write-Host "[1/7] Generation des certificats mTLS..." -ForegroundColor Cyan
Set-Location "$Root\certificates"
.\generate-certs.ps1
Set-Location "$Root"

# 1.5 Generer certificats OpenVPN
Write-Host ""
Write-Host "[1.5/7] Generation des certificats OpenVPN..." -ForegroundColor Cyan
Set-Location "$Root\certificates"
.\generate-certs-openvpn.ps1
Set-Location "$Root"

# 2. Deployer Firewall FIRST (cree les 4 reseaux)
Write-Host "[2/7] Deploiement Firewall (avec regles OpenVPN)..." -ForegroundColor Cyan
Set-Location "$Root\firewall"
docker-compose up -d
Set-Location "$Root"
Write-Host ""
Write-Host "Lancement du Firewall ... ~10 sec" -ForegroundColor Yellow
Start-Sleep -Seconds 10
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green

# 3. Deployer DMZ (utilise reseau zone-d-dmz)
Write-Host ""
Write-Host "[3/7] Deploiement Zone D (DMZ)..." -ForegroundColor Cyan
Set-Location "$Root\zone-d-dmz"
docker-compose up -d
Set-Location "$Root"
Write-Host ""
Write-Host "Lancement de la DMZ ... ~10 sec" -ForegroundColor Yellow
Start-Sleep -Seconds 10
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green

# 4. Deployer Zone A (IoT)
Write-Host ""
Write-Host "[4/7] Deploiement Zone A (Capteurs IoT)..." -ForegroundColor Cyan
Set-Location "$Root\zone-a-iot"
docker-compose up -d
Set-Location "$Root"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green

# 5. Deployer Zone B (Admin + OpenVPN)
Write-Host ""
Write-Host "[5/7] Deploiement Zone B (Admin + OpenVPN)..." -ForegroundColor Cyan
Set-Location "$Root\zone-b-admin"
docker-compose up -d
Set-Location "$Root"
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green

# 6. Deployer Zone C (Bureautique)
Write-Host ""
Write-Host "[6/7] Deploiement Zone C (Bureautique)..." -ForegroundColor Cyan
Set-Location "$Root\zone-c-bureautique"
docker-compose up -d
Set-Location "$Root"
Write-Host "==========================================" -ForegroundColor Green

# 7. Generer le fichier client OpenVPN
Write-Host ""
Write-Host "[7/7] Generation du fichier client OpenVPN..." -ForegroundColor Cyan
.\generate-client-config.ps1
Write-Host "==========================================" -ForegroundColor Green

Write-Host ""
Write-Host "[OK] DEPLOIEMENT TERMINE AVEC SUCCES !" -ForegroundColor Green -BackgroundColor Black
Write-Host ""

# Affichage du resume des services deployes avec $summary tableau
$summary = @()
$summary += [PSCustomObject]@{ Service="Grafana"; URL="http://localhost:3000"; Creds="admin/admin123"; Status="ONLINE" }
$summary += [PSCustomObject]@{ Service="InfluxDB"; URL="http://localhost:8086"; Creds="admin/adminpass123"; Status="ONLINE" }
$summary += [PSCustomObject]@{ Service="MQTT (Secured)"; URL="mqtts://localhost:8883"; Creds="Certificats mTLS"; Status="ONLINE" }
$summary += [PSCustomObject]@{ Service="OpenVPN Server"; URL="udp://localhost:1194"; Creds="admin-vpn.ovpn"; Status="ONLINE" }

# Affichage sous forme de joli tableau
$summary | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }

Write-Host "Commande utile : " -ForegroundColor DarkGray
Write-Host " - docker stats" -ForegroundColor DarkGray
Write-Host " - docker-compose ps" -ForegroundColor DarkGray
Write-Host " - docker-compose logs openvpn-server" -ForegroundColor DarkGray
Write-Host ""