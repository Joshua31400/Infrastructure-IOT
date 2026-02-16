# Zone A - Capteurs IoT

## Présentation

La Zone A représente le réseau des équipements IoT industriels. Elle simule des capteurs de production (température, consommation électrique, vibration) qui transmettent leurs données au broker MQTT central situé en DMZ.

Cette zone est volontairement isolée du reste de l'infrastructure : les capteurs ne peuvent communiquer qu'avec le broker MQTT via le protocole MQTTS (MQTT sur TLS), garantissant ainsi la confidentialité et l'intégrité des données.

---

## Caractéristiques techniques

| Paramètre | Valeur |
|-----------|--------|
| **Sous-réseau** | `192.168.10.0/24` |
| **Passerelle** | `192.168.10.254` (Firewall) |
| **Protocole autorisé** | MQTTS (TCP 8883) vers DMZ uniquement |
| **Image Docker** | `alpine:latest` |
| **Authentification** | Certificats TLS client (mTLS) |

---

## Capteurs déployés

L'infrastructure simule 3 types de capteurs industriels :

| Conteneur | Adresse IP | Type de mesure | Topic MQTT | Unité |
|-----------|------------|----------------|------------|-------|
| `capteur-t1` | `192.168.10.10` | Température | `iot/temperature` | °C |
| `capteur-c1` | `192.168.10.11` | Consommation électrique | `iot/power` | W |
| `capteur-v1` | `192.168.10.12` | Vibration | `iot/vibration` | Hz |

Chaque capteur publie des données toutes les 5 secondes au format JSON :

```json
{
  "sensor": "T1",
  "value": 25,
  "unit": "C",
  "timestamp": 1708099200
}
```

---

## Sécurité et authentification

### Certificats TLS

Les capteurs s'authentifient auprès du broker MQTT via des certificats clients signés par l'autorité de certification interne.

| Fichier | Emplacement dans le conteneur | Description |
|---------|------------------------------|-------------|
| `ca.crt` | `/certs/ca.crt` | Certificat de l'autorité de certification |
| `client-capteur.crt` | `/certs/client-capteur.crt` | Certificat client du capteur |
| `client-capteur.key` | `/certs/client-capteur.key` | Clé privée du capteur |

### Politique de filtrage

Le pare-feu applique les règles suivantes pour la Zone A :

| Source | Destination | Port | Action | Description |
|--------|-------------|------|--------|-------------|
| `192.168.10.0/24` | `10.0.0.0/24` | TCP 8883 | **ACCEPT** | Capteurs → Broker MQTT |
| `192.168.10.0/24` | Toute autre | Tous | **DROP** | Tout autre trafic bloqué |

Les capteurs n'ont donc aucun accès à :
- Grafana (10.0.0.30:3000)
- InfluxDB (10.0.0.40:8086)
- Internet
- Autres zones (Admin, Bureautique)

---

## Routage forcé

Par défaut, Docker attribue une passerelle (`.1`) à chaque conteneur. Pour garantir que tout le trafic passe par le pare-feu, chaque capteur exécute au démarrage :

```bash
# Suppression de la passerelle Docker par défaut
ip route del default

# Ajout du pare-feu comme unique passerelle
ip route add default via 192.168.10.254
```

Cette configuration assure que :
- Tout le trafic sortant est filtré par le pare-feu
- Aucune communication directe n'est possible entre zones
- Si le pare-feu est arrêté, les capteurs perdent leur connectivité réseau

---

## Configuration Docker Compose

Fichier de configuration : [`zone-a-iot/docker-compose.yml`](../zone-a-iot/docker-compose.yml)

Points clés de la configuration :

```yaml
services:
  capteur-t1:
    image: alpine:latest
    cap_add:
      - NET_ADMIN          # Requis pour modifier la table de routage
    networks:
      zone-a-iot:
        ipv4_address: 192.168.10.10
    volumes:
      - ../certificates/certs:/certs:ro    # Certificats en lecture seule
```

---

## Procédures de test

### Vérifier la publication MQTT

Depuis le conteneur d'un capteur :

```bash
# Accéder au conteneur
docker exec -it capteur-t1 sh

# Publication manuelle d'un message de test
mosquitto_pub \
  --cafile /certs/ca.crt \
  --cert /certs/client-capteur.crt \
  --key /certs/client-capteur.key \
  -h 10.0.0.20 \
  -p 8883 \
  -t "iot/temperature" \
  -m '{"sensor":"T1","value":25,"unit":"C"}' \
  --tls-version tlsv1.2
```

### Vérifier la réception des données

Depuis le conteneur admin (Zone B) :

```bash
# Souscription au topic iot/#
mosquitto_sub \
  --cafile /certs/ca.crt \
  --cert /certs/client-capteur.crt \
  --key /certs/client-capteur.key \
  -h 10.0.0.20 \
  -p 8883 \
  -t "iot/#" \
  --tls-version tlsv1.2
```

### Vérifier l'isolation réseau

Ces tests doivent échouer (connexion refusée ou timeout) :

```bash
# Depuis un conteneur capteur
docker exec -it capteur-t1 sh

# Tentative d'accès à Grafana (doit échouer)
curl -v http://10.0.0.30:3000 --connect-timeout 5

# Tentative d'accès à InfluxDB (doit échouer)
curl -v http://10.0.0.40:8086 --connect-timeout 5
```

### Vérifier le routage

```bash
docker exec capteur-t1 ip route
# Résultat attendu : default via 192.168.10.254
```

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Démarrer la zone | `docker compose -f zone-a-iot/docker-compose.yml up -d` |
| Arrêter la zone | `docker compose -f zone-a-iot/docker-compose.yml down` |
| Voir les logs d'un capteur | `docker logs -f capteur-t1` |
| Accéder à un capteur | `docker exec -it capteur-t1 sh` |
| Vérifier le routage | `docker exec capteur-t1 ip route` |
| Voir l'adresse IP | `docker exec capteur-t1 ip addr` |

---

## Dépannage

### Le capteur ne publie pas de données

1. Vérifier que le pare-feu est démarré :
   ```bash
   docker ps | grep firewall
   ```

2. Vérifier la route par défaut :
   ```bash
   docker exec capteur-t1 ip route
   ```

3. Vérifier la connectivité vers le broker :
   ```bash
   docker exec capteur-t1 ping -c 3 10.0.0.20
   ```

### Erreur de certificat TLS

1. Vérifier que les certificats sont montés :
   ```bash
   docker exec capteur-t1 ls -la /certs/
   ```

2. Vérifier la validité du certificat :
   ```bash
   docker exec capteur-t1 openssl x509 -in /certs/client-capteur.crt -text -noout
   ```

---

## Références

- [Documentation Mosquitto](https://mosquitto.org/documentation/)
- [MQTT Version 5.0 Specification](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)
- [Configuration Docker Compose](../zone-a-iot/docker-compose.yml)
- [Documentation Zone D - DMZ](zone-d-dmz.md)
- [Retour au README principal](../README.md)
