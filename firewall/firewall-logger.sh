#!/bin/bash

INFLUXDB_URL="http://10.0.0.40:8086"
INFLUXDB_TOKEN="mytoken123456"
INFLUXDB_ORG="usine-iot"
INFLUXDB_BUCKET="firewall-logs"

echo "🔥 Firewall Logger démarré - envoi vers InfluxDB..."

# Créer bucket si n'existe pas
curl -s -X POST "$INFLUXDB_URL/api/v2/buckets" \
  -H "Authorization: Token $INFLUXDB_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"orgID\":\"$INFLUXDB_ORG\",\"name\":\"$INFLUXDB_BUCKET\",\"retentionRules\":[]}" 2>/dev/null

echo "📊 Monitoring des logs du firewall..."

# Monitorar logs do kernel (iptables)
dmesg -w | while read line; do
  # Verificar se é log do firewall
  if echo "$line" | grep -q '\[FW-'; then

    # Extrair informações
    TIMESTAMP=$(date +%s)
    PREFIX=$(echo "$line" | grep -o '\[FW-[^]]*\]' | tr -d '[]')
    SRC=$(echo "$line" | grep -o 'SRC=[^ ]*' | cut -d= -f2)
    DST=$(echo "$line" | grep -o 'DST=[^ ]*' | cut -d= -f2)
    PROTO=$(echo "$line" | grep -o 'PROTO=[^ ]*' | cut -d= -f2)
    SPT=$(echo "$line" | grep -o 'SPT=[^ ]*' | cut -d= -f2)
    DPT=$(echo "$line" | grep -o 'DPT=[^ ]*' | cut -d= -f2)

    # Determinar ação (ACCEPT ou BLOCK)
    if echo "$PREFIX" | grep -q 'BLOCKED'; then
      ACTION="BLOCKED"
    else
      ACTION="ACCEPTED"
    fi

    # Determinar zona de origem
    case "$SRC" in
      192.168.10.*) ZONE_SRC="IoT" ;;
      192.168.20.*) ZONE_SRC="Admin" ;;
      192.168.30.*) ZONE_SRC="Bureautique" ;;
      10.0.0.*) ZONE_SRC="DMZ" ;;
      *) ZONE_SRC="Unknown" ;;
    esac

    # Determinar zona de destino
    case "$DST" in
      192.168.10.*) ZONE_DST="IoT" ;;
      192.168.20.*) ZONE_DST="Admin" ;;
      192.168.30.*) ZONE_DST="Bureautique" ;;
      10.0.0.*) ZONE_DST="DMZ" ;;
      *) ZONE_DST="WAN" ;;
    esac

    # Criar payload InfluxDB (Line Protocol)
    PAYLOAD="firewall_logs,action=$ACTION,proto=$PROTO,zone_src=$ZONE_SRC,zone_dst=$ZONE_DST src=\"$SRC\",dst=\"$DST\",sport=$SPT,dport=$DPT $TIMESTAMP"

    # Enviar para InfluxDB
    curl -s -X POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=s" \
      -H "Authorization: Token $INFLUXDB_TOKEN" \
      -H "Content-Type: text/plain" \
      --data-raw "$PAYLOAD" &

    echo "📊 Log envoyé: $ACTION | $ZONE_SRC → $ZONE_DST | $SRC:$SPT → $DST:$DPT ($PROTO)"
  fi
done