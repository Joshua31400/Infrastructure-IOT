# Script de Generation des certificats OpenVPN (ajout au script existant)
Write-Host ""
Write-Host "GENERATION DES CERTIFICATS OPENVPN ->" -ForegroundColor Cyan

$CERT_DIR = ".\certs"
Set-Location $CERT_DIR

# Verifier si la CA existe deja (elle doit avoir ete creee par generate-certs.ps1)
if (-not (Test-Path "ca.crt") -or -not (Test-Path "ca.key")) {
    Write-Host "[ERREUR] La CA commune n'existe pas!" -ForegroundColor Red
    Write-Host "Veuillez d'abord executer generate-certs.ps1" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[1/4] Creation de la cle DH (Diffie-Hellman) - CELA PEUT PRENDRE 1-2 MIN..." -ForegroundColor Yellow
# La cle DH est utilisee pour l'echange de cles securise
openssl dhparam -out dh2048.pem 2048

Write-Host ""
Write-Host "[2/4] Creation du certificat SERVEUR OpenVPN..." -ForegroundColor Cyan

# Configuration OpenSSL pour le serveur VPN avec SAN
$vpnServerConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = IDF
L = Paris
O = UsineIoT
CN = vpn-server

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = vpn-server
DNS.2 = openvpn-server
IP.1 = 192.168.20.20
"@

Set-Content -Path "vpn-server.cnf" -Value $vpnServerConfig

# Generer le certificat serveur VPN
openssl genrsa -out vpn-server.key 2048
openssl req -new -key vpn-server.key -out vpn-server.csr -config vpn-server.cnf
openssl x509 -req -in vpn-server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out vpn-server.crt -days 365 -extensions v3_req -extfile vpn-server.cnf

Write-Host ""
Write-Host "[3/4] Creation du certificat CLIENT OpenVPN (admin)..." -ForegroundColor Cyan

# Configuration pour le client VPN
$vpnClientConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = IDF
L = Paris
O = UsineIoT
CN = admin-vpn-client

[v3_req]
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = clientAuth
"@

Set-Content -Path "vpn-client.cnf" -Value $vpnClientConfig

# Generer le certificat client VPN
openssl genrsa -out vpn-client.key 2048
openssl req -new -key vpn-client.key -out vpn-client.csr -config vpn-client.cnf
openssl x509 -req -in vpn-client.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out vpn-client.crt -days 365 -extensions v3_req -extfile vpn-client.cnf

Write-Host ""
Write-Host "[4/4] Generation de la cle TLS-AUTH (securite supplementaire)..." -ForegroundColor Cyan

# Generer une cle TLS-Auth valide au format OpenVPN
# Chaque ligne doit contenir exactement 32 caracteres hexa (16 octets)
$lines = @()
$lines += "#"
$lines += "# 2048 bit OpenVPN static key"
$lines += "#"
$lines += "-----BEGIN OpenVPN Static key V1-----"
for ($i = 0; $i -lt 16; $i++) {
    $hexLine = ""
    for ($j = 0; $j -lt 16; $j++) {
        $hexLine += "{0:x2}" -f (Get-Random -Maximum 256)
    }
    $lines += $hexLine
}
$lines += "-----END OpenVPN Static key V1-----"
Set-Content -Path "ta.key" -Value ($lines -join "`n") -Encoding ASCII


if (-not (Test-Path "ta.key")) {
    Write-Host "[ERREUR] Impossible de generer ta.key" -ForegroundColor Red
    exit 1
}


# Nettoyage des fichiers temporaires
Remove-Item *.csr, *.srl, *.cnf -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[OK] Certificats OpenVPN generes !" -ForegroundColor Green
Write-Host ""
Write-Host "Nouveaux fichiers crees :" -ForegroundColor Yellow
Write-Host "  - vpn-server.crt / vpn-server.key (Serveur VPN)" -ForegroundColor White
Write-Host "  - vpn-client.crt / vpn-client.key (Client Admin)" -ForegroundColor White
Write-Host "  - dh2048.pem (Diffie-Hellman)" -ForegroundColor White
Write-Host "  - ta.key (TLS-Auth)" -ForegroundColor White
Write-Host ""

Set-Location ..\..