# Script de nettoyage et restauration de l'infrastructure Docker
$ErrorActionPreference = "SilentlyContinue" # On masque les erreurs non critiques (automatique de docker)
Write-Host ""
Write-Host "--- NETTOYAGE DE L'INFRASTRUCTURE ---" -ForegroundColor Yellow

# 1. ARRET ET SUPPRESSION DES CONTENEURS
Write-Host "1. Nettoyage des conteneurs..." -NoNewline
$containers = docker ps -aq
if ($containers) {
    docker stop $containers | Out-Null
    docker rm $containers | Out-Null
    Write-Host " [OK] ($( ($containers | Measure-Object).Count ) supprimes)" -ForegroundColor Green
} else {
    Write-Host " [RIEN A FAIRE]" -ForegroundColor DarkGray
}

# 2. SUPPRESSION DES RESEAUX
Write-Host "2. Nettoyage des reseaux......" -NoNewline
$networks = "zone-a-iot", "zone-b-admin", "zone-c-bureautique", "zone-d-dmz"
foreach ($net in $networks) {
    docker network rm $net | Out-Null
}
Write-Host " [OK]" -ForegroundColor Green

# 3. SUPPRESSION DES VOLUMES
Write-Host "3. Nettoyage des volumes......" -NoNewline
$volumes = docker volume ls -q
if ($volumes) {
    docker volume rm $volumes | Out-Null
    docker volume prune -f | Out-Null
    Write-Host " [OK]" -ForegroundColor Green
} else {
    Write-Host " [RIEN A FAIRE]" -ForegroundColor DarkGray
}

Write-Host "--- NETTOYAGE TERMINE ---" -ForegroundColor Green
Write-Host ""