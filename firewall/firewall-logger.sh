#!/bin/bash

INFLUXDB_URL="http://10.0.0.40:8086"
INFLUXDB_TOKEN="mytoken123456"
INFLUXDB_ORG="usine-iot"
INFLUXDB_BUCKET="firewall-logs"

echo "🔥 Firewall Logger démarré - envoi vers InfluxDB..."
echo "📊 Monitoring des logs du firewall..."

LAST_LINE_COUNT=0

while true; do
  CURRENT_LOGS=$(dmesg 2>/dev/null | grep '\[FW-')
  CURRENT_LINE_COUNT=$(echo "$CURRENT_LOGS" | wc -l)

  if [ "$CURRENT_LINE_COUNT" -gt "$LAST_LINE_COUNT" ]; then
    echo "$CURRENT_LOGS" | tail -n $(($CURRENT_LINE_COUNT - $LAST_LINE_COUNT)) | while read line; do

      TIMESTAMP=$(date +%s)
      PREFIX=$(echo "$line" | grep -o '\[FW-[^]]*\]' | tr -d '[]')
      SRC=$(echo "$line" | grep -o 'SRC=[^ ]*' | cut -d= -f2)
      DST=$(echo "$line" | grep -o 'DST=[^ ]*' | cut -d= -f2)
      PROTO=$(echo "$line" | grep -o 'PROTO=[^ ]*' | cut -d= -f2)
      SPT=$(echo "$line" | grep -o 'SPT=[^ ]*' | cut -d= -f2)
      DPT=$(echo "$line" | grep -o 'DPT=[^ ]*' | cut -d= -f2)

      SRC=${SRC:-"0.0.0.0"}
      DST=${DST:-"0.0.0.0"}
      PROTO=${PROTO:-"UNKNOWN"}
      SPT=${SPT:-"0"}
      DPT=${DPT:-"0"}

      if echo "$PREFIX" | grep -q 'BLOCKED'; then
        ACTION="BLOCKED"
      else
        ACTION="ACCEPTED"
      fi

      case "$SRC" in
        192.168.10.*) ZONE_SRC="IoT" ;;
        192.168.20.*) ZONE_SRC="Admin" ;;
        192.168.30.*) ZONE_SRC="Bureautique" ;;
        10.0.0.*) ZONE_SRC="DMZ" ;;
        *) ZONE_SRC="Unknown" ;;
      esac

      case "$DST" in
        192.168.10.*) ZONE_DST="IoT" ;;
        192.168.20.*) ZONE_DST="Admin" ;;
        192.168.30.*) ZONE_DST="Bureautique" ;;
        10.0.0.*) ZONE_DST="DMZ" ;;
        *) ZONE_DST="WAN" ;;
      esac

      PAYLOAD="firewall_logs,action=$ACTION,proto=$PROTO,zone_src=$ZONE_SRC,zone_dst=$ZONE_DST src=\"$SRC\",dst=\"$DST\",sport=$SPT,dport=$DPT $TIMESTAMP"

      curl -s -X POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=s" \
        -H "Authorization: Token $INFLUXDB_TOKEN" \
        -H "Content-Type: text/plain" \
        --data-raw "$PAYLOAD" 2>/dev/null

      echo "📊 Log: $ACTION | $ZONE_SRC → $ZONE_DST | $SRC:$SPT → $DST:$DPT ($PROTO)"
    done

    LAST_LINE_COUNT=$CURRENT_LINE_COUNT
  fi

  sleep 2
done