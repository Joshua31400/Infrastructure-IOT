#!/bin/bash

INFLUXDB_URL="http://10.0.0.40:8086"
INFLUXDB_TOKEN="mytoken123456"
INFLUXDB_ORG="usine-iot"
INFLUXDB_BUCKET="firewall-logs"

echo "🔥 Firewall Logger démarré..."

# 1. Filtre TCPDUMP stricte :
# -i any : écoute partout
# -n : pas de DNS
# -l : buffer ligne par ligne
# 'tcp port not 22 and port not 8086' : Si on écoute le port 8086, le script voit son propre envoi vers InfluxDB, le logue, tente de l'envoyer, le re-voit, le re-logue... C'est la boucle infinie qui faisait planter ton PC.
tcpdump -i any -n -l -tt 'tcp port not 22 and port not 8086' 2>/dev/null | while read -r line; do

      # Si la ligne ne contient pas de flèche de trafic, on ignore
      if [[ "$line" != *" > "* ]]; then continue; fi

      # 2. Parsing Intelligent (Basé sur la position de ">")
      # On cherche les champs autour du ">" au lieu de compter les colonnes fixes
      SRC_FULL=$(echo "$line" | awk -F' > ' '{print $1}' | awk '{print $NF}')
      DST_FULL=$(echo "$line" | awk -F' > ' '{print $2}' | awk '{print $1}' | tr -d ':')
      TIMESTAMP=$(echo "$line" | awk '{print $1}' | cut -d. -f1)

      # 3. Nettoyage IP et Port
      SRC_IP=$(echo "$SRC_FULL" | rev | cut -d. -f2- | rev)
      SRC_PORT=$(echo "$SRC_FULL" | rev | cut -d. -f1 | rev)
      DST_IP=$(echo "$DST_FULL" | rev | cut -d. -f2- | rev)
      DST_PORT=$(echo "$DST_FULL" | rev | cut -d. -f1 | rev)

      # Sécurité : Si le parsing a échoué (ex: ARP ou IPV6 malformé), on saute
      if [[ -z "$SRC_IP" || -z "$DST_IP" || "$SRC_PORT" == "$SRC_IP" ]]; then continue; fi

      # 4. Identification des Zones
      case "$SRC_IP" in
        192.168.10.*) ZONE_SRC="IoT" ;;
        192.168.20.*) ZONE_SRC="Admin" ;;
        192.168.30.*) ZONE_SRC="Bureautique" ;;
        10.0.0.*)     ZONE_SRC="DMZ" ;;
        *)            ZONE_SRC="Unknown" ;;
      esac

      case "$DST_IP" in
        10.0.0.*)     ZONE_DST="DMZ" ;;
        192.168.*)    ZONE_DST="Interne" ;;
        *)            ZONE_DST="WAN" ;;
      esac

      # 5. Simulation Firewall (Logique d'affichage)
      ACTION="BLOCKED"
      # Règles permissives (reproduction de tes iptables)
      if [ "$ZONE_SRC" == "Bureautique" ] && [ "$DST_PORT" == "3000" ]; then ACTION="ACCEPTED"; fi
      if [ "$ZONE_SRC" == "IoT" ] && [ "$DST_PORT" == "8883" ]; then ACTION="ACCEPTED"; fi
      if [ "$ZONE_SRC" == "Admin" ]; then ACTION="ACCEPTED"; fi
      if [ "$ZONE_SRC" == "DMZ" ] && [ "$ZONE_DST" == "WAN" ]; then ACTION="ACCEPTED"; fi

      # 6. Envoi InfluxDB
      PAYLOAD="firewall_logs,action=$ACTION,proto=TCP,zone_src=$ZONE_SRC,zone_dst=$ZONE_DST src=\"$SRC_IP\",dst=\"$DST_IP\",sport=$SRC_PORT,dport=$DST_PORT $TIMESTAMP"

      HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$INFLUXDB_URL/api/v2/write?org=$INFLUXDB_ORG&bucket=$INFLUXDB_BUCKET&precision=s" \
        -H "Authorization: Token $INFLUXDB_TOKEN" \
        -H "Content-Type: text/plain" \
        --data-raw "$PAYLOAD")

      # Log console propre
      if [ "$HTTP_CODE" -eq 204 ]; then
        echo "✅ OK | $ACTION | $ZONE_SRC -> $ZONE_DST ($DST_PORT)"
      elif [ "$HTTP_CODE" -ne 000 ]; then
        # On n'affiche l'erreur que si ce n'est pas un timeout réseau
        echo "⚠️  Influx Refus ($HTTP_CODE)"
      fi
done