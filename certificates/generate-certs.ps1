# Script de Generation des certificats mTLS pour MQTT + LDAPS
Write-Host ""
Write-Host "GENERATION DES CERTIFICATS (MQTT + LDAPS) ->" -ForegroundColor Cyan

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
Write-Host ""
Write-Host "[1/6] Creation de l'Autorite de Certification COMMUNE..." -ForegroundColor Cyan
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=CA-IoT"

# 2. Creer certificat serveur Mosquitto avec SAN
Write-Host ""
Write-Host "[2/6] Creation certificat serveur Mosquitto avec IP SAN..." -ForegroundColor Cyan

# Creer fichier de config OpenSSL pour MQTT
$mqttSanConfig = @"
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

Set-Content -Path "mqtt-server.cnf" -Value $mqttSanConfig

# Generer certificat serveur MQTT avec SAN
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config mqtt-server.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile mqtt-server.cnf

# 3. Creer certificat CLIENT (Capteurs)
Write-Host ""
Write-Host "[3/6] Creation certificat client capteur..." -ForegroundColor Cyan
openssl genrsa -out client-capteur.key 2048
openssl req -new -key client-capteur.key -out client-capteur.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=capteur-iot"
openssl x509 -req -in client-capteur.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-capteur.crt -days 365

# 4. Creer certificat CLIENT (Grafana pour MQTT)
Write-Host ""
Write-Host "[4/6] Creation certificat client Grafana (MQTT)..." -ForegroundColor Cyan
openssl genrsa -out client-grafana.key 2048
openssl req -new -key client-grafana.key -out client-grafana.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=grafana_dashboards"
openssl x509 -req -in client-grafana.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-grafana.crt -days 365

# 5. Creer certificat serveur LDAP avec SAN
Write-Host ""
Write-Host "[5/6] Creation certificat serveur LDAP (LDAPS)..." -ForegroundColor Cyan

# Creer fichier de config OpenSSL pour LDAP
$ldapSanConfig = @"
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = FR
ST = IDF
L = Paris
O = UsineIoT
CN = ldap

[v3_req]
keyUsage = digitalSignature, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ldap
DNS.2 = ldap.usine.local
DNS.3 = localhost
IP.1 = 10.0.0.10
"@

Set-Content -Path "ldap-server.cnf" -Value $ldapSanConfig

# Generer certificat serveur LDAP avec SAN
openssl genrsa -out ldap-server.key 2048
openssl req -new -key ldap-server.key -out ldap-server.csr -config ldap-server.cnf
openssl x509 -req -in ldap-server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out ldap-server.crt -days 365 -extensions v3_req -extfile ldap-server.cnf

# 6. Creer certificat CLIENT Grafana pour LDAPS (optionnel mais recommande)
Write-Host ""
Write-Host "[6/6] Creation certificat client Grafana (LDAPS)..." -ForegroundColor Cyan
openssl genrsa -out client-grafana-ldap.key 2048
openssl req -new -key client-grafana-ldap.key -out client-grafana-ldap.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=grafana-ldap-client"
openssl x509 -req -in client-grafana-ldap.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-grafana-ldap.crt -days 365

# Nettoyage des fichiers temporaires
Remove-Item *.csr, *.srl, *.cnf -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "[OK] Certificats generes dans $CERT_DIR" -ForegroundColor Green
Write-Host ""
Write-Host "Certificats MQTT :" -ForegroundColor Yellow
Write-Host "  - ca.crt / ca.key (CA commune)" -ForegroundColor White
Write-Host "  - server.crt / server.key (Broker MQTT)" -ForegroundColor White
Write-Host "  - client-capteur.crt / client-capteur.key" -ForegroundColor White
Write-Host "  - client-grafana.crt / client-grafana.key" -ForegroundColor White
Write-Host ""
Write-Host "Certificats LDAPS :" -ForegroundColor Yellow
Write-Host "  - ldap-server.crt / ldap-server.key (Serveur LDAP)" -ForegroundColor White
Write-Host "  - client-grafana-ldap.crt / client-grafana-ldap.key (Client Grafana)" -ForegroundColor White
Write-Host ""

Get-ChildItem -File | Format-Table Name, Length -AutoSize

Set-Location ..\..
Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""