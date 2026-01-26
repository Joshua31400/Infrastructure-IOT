Write-Host "Generation des certificats mTLS (MQTT + LDAP)" -ForegroundColor Green

$CERT_DIR = ".\certs"
New-Item -ItemType Directory -Force -Path $CERT_DIR | Out-Null
Set-Location $CERT_DIR

if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] OpenSSL n'est pas installe!" -ForegroundColor Red
    Write-Host "Telecharger depuis: https://slproweb.com/products/Win32OpenSSL.html" -ForegroundColor Yellow
    exit 1
}


Write-Host "[1/5] Creation de l'Autorite de Certification..." -ForegroundColor Cyan
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=CA-IoT"

Write-Host "[2/5] Creation certificat serveur Mosquitto (MQTT)..." -ForegroundColor Cyan

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

Set-Content -Path "mqtt.cnf" -Value $mqttSanConfig

openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr -config mqtt.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile mqtt.cnf


Write-Host "[3/5] Creation certificat serveur LDAP..." -ForegroundColor Cyan

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
CN = ldap-server

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ldap
DNS.2 = localhost
IP.1 = 10.0.0.10
"@

Set-Content -Path "ldap.cnf" -Value $ldapSanConfig

openssl genrsa -out ldap.key 2048
openssl req -new -key ldap.key -out ldap.csr -config ldap.cnf
openssl x509 -req -in ldap.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out ldap.crt -days 365 -extensions v3_req -extfile ldap.cnf


Write-Host "[4/5] Creation certificat client capteur..." -ForegroundColor Cyan
openssl genrsa -out client-capteur.key 2048
openssl req -new -key client-capteur.key -out client-capteur.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=capteur-iot"
openssl x509 -req -in client-capteur.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-capteur.crt -days 365

Write-Host "[5/5] Creation certificat client Grafana..." -ForegroundColor Cyan
openssl genrsa -out client-grafana.key 2048
openssl req -new -key client-grafana.key -out client-grafana.csr `
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=grafana"
openssl x509 -req -in client-grafana.csr -CA ca.crt -CAkey ca.key `
  -CAcreateserial -out client-grafana.crt -days 365

Remove-Item *.csr, *.srl, mqtt.cnf, ldap.cnf -ErrorAction SilentlyContinue

Write-Host "[OK] Tous les certificats generes dans $CERT_DIR" -ForegroundColor Green
Get-ChildItem -File

Set-Location ..\..