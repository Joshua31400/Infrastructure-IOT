# Generation des certificats mTLS pour MQTT

Write-Host "Generation des certificats mTLS pour MQTT" -ForegroundColor Green

$CERT_DIR = ".\certs"
New-Item -ItemType Directory -Force -Path $CERT_DIR | Out-Null
Set-Location $CERT_DIR

# Verifier si OpenSSL est installe
if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] OpenSSL n'est pas installe!" -ForegroundColor Red
    Write-Host "Telecharger depuis: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    exit 1
}

# 1. Creer l'Autorite de Certification (CA)
Write-Host "[1/4] Creation de l'Autorite de Certification..." -ForegroundColor Cyan
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=CA-IoT"

# 2. Creer fichier de configuration pour SAN
Write-Host "[2/4] Creation certificat serveur Mosquitto avec IP SAN..." -ForegroundColor Cyan

# Creer fichier de config OpenSSL
$sanConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = IDF
L = Paris
O = UsineIoT
CN = broker-mqtt

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = broker-mqtt
DNS.2 = localhost
IP.1 = 10.0.0.20
"@

Set-Content -Path "server.cnf" -Value $sanConfig

# Generer certificat serveur avec SAN
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config server.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile server.cnf

# 3. Creer certificat CLIENT (Capteurs)
Write-Host "[3/4] Creation certificat client capteur..." -ForegroundColor Cyan
openssl genrsa -out client-capteur.key 2048
openssl req -new -key client-capteur.key -out client-capteur.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=capteur-iot"
openssl x509 -req -in client-capteur.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-capteur.crt -days 365

# 4. Creer certificat CLIENT (Grafana)
Write-Host "[4/4] Creation certificat client Grafana..." -ForegroundColor Cyan
openssl genrsa -out client-grafana.key 2048
openssl req -new -key client-grafana.key -out client-grafana.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=grafana"
openssl x509 -req -in client-grafana.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-grafana.crt -days 365

# Nettoyage
Remove-Item *.csr, *.srl, server.cnf -ErrorAction SilentlyContinue

Write-Host "[OK] Certificats generes dans $CERT_DIR" -ForegroundColor Green
Get-ChildItem -File

Set-Location ..\..