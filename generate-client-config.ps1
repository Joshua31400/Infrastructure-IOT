# Script de generation du fichier client OpenVPN (.ovpn)
# Ce fichier combine tous les certificats en UN SEUL fichier portable

param(
    [string]$ClientName = "admin",
    [string]$ServerIP = "localhost"  # Remplacer par l'IP publique/domaine si necessaire
)

$ErrorActionPreference = "Stop"
$CERT_DIR = ".\certificates\certs"

Write-Host ""
Write-Host "====================================" -ForegroundColor Cyan
Write-Host "GENERATION FICHIER CLIENT OPENVPN" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Verification de l'existence des certificats
$requiredFiles = @(
    "$CERT_DIR\ca.crt",
    "$CERT_DIR\vpn-client.crt",
    "$CERT_DIR\vpn-client.key",
    "$CERT_DIR\ta.key"
)

foreach ($file in $requiredFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "[ERREUR] Fichier manquant : $file" -ForegroundColor Red
        Write-Host "Veuillez d'abord executer generate-certs.ps1 puis generate-certs-openvpn.ps1" -ForegroundColor Yellow
        exit 1
    }
}

# Lecture des certificats
$caCrt = Get-Content "$CERT_DIR\ca.crt" -Raw
$clientCrt = Get-Content "$CERT_DIR\vpn-client.crt" -Raw
$clientKey = Get-Content "$CERT_DIR\vpn-client.key" -Raw
$taKey = Get-Content "$CERT_DIR\ta.key" -Raw

# Creation du fichier .ovpn (format OpenVPN unifie)
$ovpnContent = @"
# Configuration client OpenVPN pour UsineIoT
# Generee automatiquement le $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

client
dev tun
proto udp

# Adresse du serveur OpenVPN (MODIFIER CETTE LIGNE avec votre IP publique si necessaire)
remote $ServerIP 1194

# Resoudre le hostname une seule fois au demarrage
resolv-retry infinite

# Ne pas binder de port local specifique
nobind

# Garder le tunnel actif lors des redemarrages
persist-key
persist-tun

# Chiffrement et authentification (doit correspondre au serveur)
cipher AES-256-GCM
auth SHA256

# Compression
compress lz4-v2

# Niveau de verbosité des logs (3 = normal)
verb 3

# Empecher les fuites DNS (Windows uniquement)
block-outside-dns

# Cle TLS-Auth (direction 1 pour le client)
key-direction 1

# === CERTIFICATS EMBARQUES ===
<ca>
$caCrt
</ca>

<cert>
$clientCrt
</cert>

<key>
$clientKey
</key>

<tls-auth>
$taKey
</tls-auth>
"@

# Sauvegarder le fichier .ovpn
$outputFile = ".\$ClientName-vpn.ovpn"
Set-Content -Path $outputFile -Value $ovpnContent -Encoding ASCII

Write-Host "[OK] Fichier client genere : $outputFile" -ForegroundColor Green
Write-Host ""
Write-Host "INSTRUCTIONS D'UTILISATION :" -ForegroundColor Yellow
Write-Host "----------------------------" -ForegroundColor Yellow
Write-Host "1. Installer OpenVPN GUI (Windows) ou openvpn (Linux/Mac)" -ForegroundColor White
Write-Host "   Windows : https://openvpn.net/community-downloads/" -ForegroundColor Gray
Write-Host "   Linux   : sudo apt install openvpn" -ForegroundColor Gray
Write-Host "   Mac     : brew install openvpn" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Importer le fichier $outputFile dans OpenVPN GUI" -ForegroundColor White
Write-Host "   OU lancer en ligne de commande :" -ForegroundColor White
Write-Host "   openvpn --config $outputFile" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Une fois connecte, vous aurez acces a :" -ForegroundColor White
Write-Host "   - SSH vers DMZ : ssh root@10.0.0.X" -ForegroundColor Gray
Write-Host "   - Grafana      : http://10.0.0.30:3000" -ForegroundColor Gray
Write-Host "   - InfluxDB     : http://10.0.0.40:8086" -ForegroundColor Gray
Write-Host "   - LDAP         : ldap://10.0.0.10:389" -ForegroundColor Gray
Write-Host "   - MQTT         : mqtts://10.0.0.20:8883" -ForegroundColor Gray
Write-Host ""
Write-Host "[NOTE] Si vous deployez sur un serveur distant, modifiez la ligne" -ForegroundColor Yellow
Write-Host "       'remote $ServerIP 1194' dans le fichier .ovpn avec l'IP publique du serveur" -ForegroundColor Yellow
Write-Host ""