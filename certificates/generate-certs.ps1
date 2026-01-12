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

# 2. Creer certificat SERVEUR (Broker MQTT)
Write-Host "[2/4] Creation certificat serveur Mosquitto..." -ForegroundColor Cyan
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=broker-mqtt"
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out server.crt -days 365

# 3. Creer certificat CLIENT (Capteurs)
Write-Host "[3/4] Creation certificat client capteur..." -ForegroundColor Cyan
openssl genrsa -out client-capteur.key 2048
openssl req -new -key client-capteur.key -out client-capteur.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=capteur-iot"
openssl x509 -req -in client-capteur.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-capteur.crt -days 365

# 4. Creer certificat CLIENT (Telegraf)
Write-Host "[4/4] Creation certificat client Telegraf..." -ForegroundColor Cyan
openssl genrsa -out client-telegraf.key 2048
openssl req -new -key client-telegraf.key -out client-telegraf.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=telegraf"
openssl x509 -req -in client-telegraf.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-telegraf.crt -days 365

# Nettoyage
Remove-Item *.csr, *.srl -ErrorAction SilentlyContinue

Write-Host "[OK] Certificats generes dans $CERT_DIR" -ForegroundColor Green
Get-ChildItem -File

Set-Location ..\..