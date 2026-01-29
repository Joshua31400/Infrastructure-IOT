#!/bin/bash

GRAFANA_URL="http://admin:admin123@localhost:3000"

echo "🔧 [Script] Démarrage de l'initialisation..."

# 1. Attente active de Grafana
echo "⏳ [Script] Attente de l'API Grafana..."
until curl -s -f -o /dev/null "$GRAFANA_URL/api/health"; do
  echo "   ... Grafana n'est pas encore prêt (Sleep 2s)"
  sleep 2
done
echo "✅ [Script] Grafana est en ligne !"

# 2. Variables Certificats (Nettoyage des sauts de ligne pour JSON)
CA_CERT=$(awk '{printf "%s\\n", $0}' /etc/grafana/certs/ca.crt)
CLIENT_CERT=$(awk '{printf "%s\\n", $0}' /etc/grafana/certs/client-grafana.crt)
CLIENT_KEY=$(awk '{printf "%s\\n", $0}' /etc/grafana/certs/client-grafana.key)

# 3. Config INFLUXDB
echo "📊 [Script] Configuration InfluxDB..."
curl -s -X POST "$GRAFANA_URL/api/datasources" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "InfluxDB",
    "type": "influxdb",
    "access": "proxy",
    "url": "http://10.0.0.40:8086",
    "isDefault": true,
    "uid": "influxdb-logs",
    "jsonData": {
      "version": "Flux",
      "organization": "usine-iot",
      "defaultBucket": "firewall-logs",
      "tlsSkipVerify": true
    },
    "secureJsonData": {
      "token": "mytoken123456"
    }
  }'

# 4. Config MQTT (CORRECTION CRITIQUE ICI)
echo "🔌 [Script] Configuration MQTT..."
cat > /tmp/mqtt_payload.json <<EOF
{
  "name": "MQTT Broker IoT",
  "type": "grafana-mqtt-datasource",
  "uid": "mqtt-iot",
  "access": "proxy",
  "jsonData": {
    "uri": "mqtts://10.0.0.20:8883",
    "tlsAuth": true,
    "tlsAuthWithCACert": true,
    "tlsSkipVerify": true
  },
  "secureJsonData": {
    "tlsCACert": "$CA_CERT",
    "tlsClientCert": "$CLIENT_CERT",
    "tlsClientKey": "$CLIENT_KEY"
  }
}
EOF

# Envoi de la config
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$GRAFANA_URL/api/datasources" -H "Content-Type: application/json" -d @/tmp/mqtt_payload.json)

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 409 ]; then
    echo "✅ [Script] MQTT configuré (Code: $HTTP_CODE)"
else
    echo "❌ [Script] ERREUR MQTT (Code: $HTTP_CODE)"
fi