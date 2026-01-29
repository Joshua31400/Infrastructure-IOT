#!/bin/bash

echo "🔧 Attente du démarrage de Grafana..."

# Attendre que Grafana soit prêt
until curl -s http://localhost:3000/api/health | grep -q "ok"; do
  echo "⏳ Grafana n'est pas encore prêt..."
  sleep 2
done

echo "✅ Grafana démarré!"

# Lire les certificats et échapper les newlines
CA_CERT=$(cat /etc/grafana/certs/ca.crt | awk '{printf "%s\\n", $0}')
CLIENT_CERT=$(cat /etc/grafana/certs/client-grafana.crt | awk '{printf "%s\\n", $0}')
CLIENT_KEY=$(cat /etc/grafana/certs/client-grafana.key | awk '{printf "%s\\n", $0}')

echo "📊 Création data source InfluxDB..."

# Créer data source InfluxDB
curl -X POST http://admin:admin123@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "InfluxDB",
    "type": "influxdb",
    "access": "proxy",
    "url": "http://10.0.0.40:8086",
    "isDefault": true,
    "jsonData": {
      "version": "Flux",
      "organization": "usine-iot",
      "defaultBucket": "firewall-logs",
      "tlsSkipVerify": true
    },
    "secureJsonData": {
      "token": "mytoken123456"
    }
  }' 2>/dev/null

echo "🔌 Création data source MQTT..."

# Créer data source MQTT avec certificats
curl -X POST http://admin:admin123@localhost:3000/api/datasources \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"MQTT Broker IoT\",
    \"type\": \"grafana-mqtt-datasource\",
    \"uid\": \"mqtt-iot\",
    \"access\": \"proxy\",
    \"url\": \"mqtts://10.0.0.20:8883\",
    \"jsonData\": {
      \"tlsAuth\": true,
      \"tlsAuthWithCACert\": true,
      \"tlsSkipVerify\": false
    },
    \"secureJsonData\": {
      \"tlsCACert\": \"$CA_CERT\",
      \"tlsClientCert\": \"$CLIENT_CERT\",
      \"tlsClientKey\": \"$CLIENT_KEY\"
    }
  }" 2>/dev/null

echo "✅ Data sources configurés!"