# Zone Z - Firewall (Routeur Central)

## Présentation

La Zone Z représente le cœur de l'architecture réseau : un pare-feu logiciel basé sur Alpine Linux qui assure le routage inter-VLAN et le filtrage du trafic entre toutes les zones de l'infrastructure.

Ce composant implémente une politique de sécurité "deny by default" (tout est bloqué par défaut) avec des exceptions explicites pour les flux autorisés. Chaque paquet transitant par le pare-feu est analysé, filtré selon les règles iptables, et journalisé vers InfluxDB pour audit et supervision.

---

## Caractéristiques techniques

| Paramètre | Valeur |
|-----------|--------|
| **Image Docker** | `alpine:latest` |
| **Mode** | `privileged: true` |
| **Capability** | `NET_ADMIN` |
| **Outil de filtrage** | `iptables` |
| **Journalisation** | `tcpdump` → InfluxDB |

---

## Interfaces réseau

Le pare-feu dispose d'une interface sur chaque zone avec l'adresse `.254` :

| Zone | Sous-réseau | Adresse IP Firewall | Fonction |
|------|-------------|---------------------|----------|
| Zone A - IoT | `192.168.10.0/24` | `192.168.10.254` | Capteurs industriels |
| Zone B - Admin | `192.168.20.0/24` | `192.168.20.254` | Administration et VPN |
| Zone C - Bureautique | `192.168.30.0/24` | `192.168.30.254` | Postes utilisateurs |
| Zone D - DMZ | `10.0.0.0/24` | `10.0.0.254` | Services critiques |

---

## Politique de sécurité

### Politique par défaut

Toutes les chaînes sont configurées en mode restrictif :

| Chaîne | Politique | Description |
|--------|-----------|-------------|
| `INPUT` | DROP | Bloque tout trafic entrant vers le firewall |
| `FORWARD` | DROP | Bloque tout trafic transitant entre zones |
| `OUTPUT` | ACCEPT | Autorise le trafic sortant du firewall |

### Matrice des flux autorisés

| # | Source | Destination | Port(s) | Action | Préfixe Log |
|---|--------|-------------|---------|--------|-------------|
| 1 | `*` | `192.168.20.20` | UDP 1194 | ACCEPT | `[FW-VPN-IN]` |
| 2 | `192.168.20.0/24` | `10.0.0.0/24` | TCP 22,443,3000,8086,8883 | ACCEPT | `[FW-VPN-DMZ]` |
| 3 | `192.168.10.0/24` | `10.0.0.0/24` | TCP 8883 | ACCEPT | `[FW-IOT-MQTT]` |
| 4 | `192.168.20.0/24` | `10.0.0.0/24` | TCP 22,443,3000,8086 | ACCEPT | `[FW-ADMIN-DMZ]` |
| 5 | `192.168.30.0/24` | `10.0.0.0/24` | TCP 443 | ACCEPT | `[FW-BUREAU-DMZ]` |
| 6 | `192.168.30.0/24` | `10.0.0.30` | TCP 3000 | ACCEPT | `[FW-BUREAU-GRAFANA]` |
| 7 | `10.0.0.0/24` | WAN (eth0) | `*` | ACCEPT | `[FW-DMZ-WAN]` |
| 8 | `10.0.0.0/24` | `10.0.0.0/24` | `*` | ACCEPT | - |
| 9 | `*` | `*` | `*` | DROP | `[FW-BLOCKED]` |

### Description des règles

**Règle 1 - VPN Entrantes**
Autorise les connexions OpenVPN entrantes vers le serveur VPN.

**Règle 2 - VPN vers DMZ**
Les clients VPN connectés ont un accès complet aux services de la DMZ.

**Règle 3 - IoT vers MQTT**
Les capteurs peuvent uniquement publier vers le broker MQTT (port 8883).

**Règle 4 - Admin vers DMZ**
Les administrateurs (Zone B) ont accès aux services de gestion en DMZ.

**Règle 5/6 - Bureautique vers Grafana**
Les utilisateurs bureautique peuvent uniquement consulter les dashboards Grafana.

**Règle 7 - DMZ vers Internet**
Les services DMZ peuvent accéder à Internet (mises à jour, etc.).

**Règle 8 - Intra-DMZ**
Les services de la DMZ peuvent communiquer entre eux librement.

**Règle 9 - Blocage par défaut**
Tout autre trafic est bloqué et journalisé.

---

## Journalisation des flux

### Script de journalisation

Le script `firewall-logger.sh` capture le trafic réseau en temps réel via `tcpdump` et l'envoie vers InfluxDB pour analyse dans Grafana.

Fichier : [`firewall/firewall-logger.sh`](../firewall/firewall-logger.sh)

### Fonctionnement

1. **Capture** : `tcpdump` écoute sur toutes les interfaces
2. **Parsing** : Extraction des IP et ports source/destination
3. **Classification** : Identification des zones impliquées
4. **Envoi** : Transmission vers InfluxDB via l'API HTTP

### Configuration InfluxDB

| Paramètre | Valeur |
|-----------|--------|
| URL | `http://10.0.0.40:8086` |
| Token | `mytoken123456` |
| Organisation | `usine-iot` |
| Bucket | `firewall-logs` |

### Classification des zones

Le script identifie automatiquement les zones source et destination :

| Plage IP | Zone |
|----------|------|
| `192.168.10.*` | IoT |
| `192.168.20.*` | Admin |
| `192.168.30.*` | Bureautique |
| `10.0.0.*` | DMZ |
| Autre | Unknown / WAN |

### Protection anti-boucle

Pour éviter que le script ne capture et journalise ses propres envois vers InfluxDB (ce qui créerait une boucle infinie), les ports 22 (SSH) et 8086 (InfluxDB) sont exclus :

```bash
tcpdump -i any -n -l -tt 'tcp port not 22 and port not 8086'
```

---

## Configuration Docker Compose

Fichier : [`firewall/docker-compose.yml`](../firewall/docker-compose.yml)

### Réseaux créés

Le conteneur firewall crée les 4 réseaux Docker de l'infrastructure :

| Réseau | Sous-réseau | Gateway Docker | Gateway Firewall |
|--------|-------------|----------------|------------------|
| `zone-a-iot` | `192.168.10.0/24` | `192.168.10.1` | `192.168.10.254` |
| `zone-b-admin` | `192.168.20.0/24` | `192.168.20.1` | `192.168.20.254` |
| `zone-c-bureautique` | `192.168.30.0/24` | `192.168.30.1` | `192.168.30.254` |
| `zone-d-dmz` | `10.0.0.0/24` | `10.0.0.1` | `10.0.0.254` |

### Prérequis techniques

```yaml
services:
  firewall:
    image: alpine:latest
    privileged: true      # Requis pour iptables
    cap_add:
      - NET_ADMIN         # Manipulation des routes/interfaces
```

### Activation du routage IP

Le routage entre les interfaces est activé au démarrage :

```bash
sysctl -w net.ipv4.ip_forward=1
```

### NAT (Masquerading)

Le NAT permet aux zones internes d'accéder à Internet via l'interface WAN :

```bash
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
```

---

## Procédures de test

### Démarrer le firewall

```bash
cd firewall
docker compose up -d
```

### Vérifier les règles iptables

```bash
# Règles de filtrage
docker exec firewall iptables -L -v -n

# Règles NAT
docker exec firewall iptables -t nat -L -v -n
```

### Tester la connectivité inter-zones

**Depuis Zone C (Bureautique) vers Grafana - Doit réussir :**

```bash
docker exec client1 curl -v http://10.0.0.30:3000
# Attendu : HTTP 200 ou 302 (redirection vers /login)
```

**Depuis Zone C (Bureautique) vers InfluxDB - Doit échouer :**

```bash
docker exec client1 curl -v http://10.0.0.40:8086 --connect-timeout 5
# Attendu : Timeout ou connexion refusée
```

**Depuis Zone A (IoT) vers Broker MQTT - Doit réussir :**

```bash
docker exec capteur-t1 nc -zv 10.0.0.20 8883
# Attendu : Connection succeeded
```

### Vérifier les logs en temps réel

```bash
# Logs du conteneur firewall (incluant le logger)
docker logs -f firewall

# Filtrer sur les actions
docker logs -f firewall 2>&1 | grep -E "✅|⚠️"
```

### Vérifier les données dans InfluxDB

```bash
docker exec admin curl -s "http://10.0.0.40:8086/api/v2/query?org=usine-iot" \
  -H "Authorization: Token mytoken123456" \
  -H "Content-Type: application/vnd.flux" \
  --data 'from(bucket:"firewall-logs") |> range(start:-5m) |> limit(n:5)'
```

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Démarrer le firewall | `docker compose -f firewall/docker-compose.yml up -d` |
| Arrêter le firewall | `docker compose -f firewall/docker-compose.yml down` |
| Voir les règles FILTER | `docker exec firewall iptables -L -v -n` |
| Voir les règles NAT | `docker exec firewall iptables -t nat -L -v -n` |
| Voir les routes | `docker exec firewall ip route` |
| Voir les interfaces | `docker exec firewall ip addr` |
| Réinitialiser les règles | `docker exec firewall iptables -F` |
| Voir les logs | `docker logs -f firewall` |

---

## Dépannage

### Le trafic n'est pas filtré

1. Vérifier que le conteneur firewall est démarré :
   ```bash
   docker ps | grep firewall
   ```

2. Vérifier que les règles iptables sont chargées :
   ```bash
   docker exec firewall iptables -L -v -n | grep -c ACCEPT
   # Doit retourner > 0
   ```

3. Vérifier que le routage IP est activé :
   ```bash
   docker exec firewall sysctl net.ipv4.ip_forward
   # Doit retourner = 1
   ```

### Le logger ne fonctionne pas

1. Vérifier que `tcpdump` est installé :
   ```bash
   docker exec firewall which tcpdump
   ```

2. Vérifier la conversion des fins de ligne :
   ```bash
   docker exec firewall cat -A /tmp/logger.sh | head -1
   # Ne doit pas contenir ^M (retour chariot Windows)
   ```

3. Vérifier l'accès à InfluxDB :
   ```bash
   docker exec firewall curl -s http://10.0.0.40:8086/health
   ```

### Pas de connectivité vers Internet

1. Vérifier le NAT :
   ```bash
   docker exec firewall iptables -t nat -L -v -n | grep MASQUERADE
   ```

2. Vérifier que l'interface eth0 existe :
   ```bash
   docker exec firewall ip addr show eth0
   ```

---

## Notes importantes

**Mode privileged**
Le conteneur fonctionne en mode `privileged: true` pour pouvoir manipuler les règles iptables. En production, il est recommandé d'utiliser des capabilities plus restrictives si possible.

**Logs [FW-BLOCKED]**
Les tentatives de connexion non autorisées sont journalisées avec le préfixe `[FW-BLOCKED]`. Ces événements peuvent être analysés dans Grafana pour identifier des tentatives d'intrusion.

**Compatibilité Windows/Linux**
Le script `firewall-logger.sh` est converti automatiquement au format Unix via `dos2unix` pour éviter les erreurs liées aux fins de ligne Windows (CRLF).

**Visualisation Grafana**
Les données de logs sont disponibles dans le bucket `firewall-logs` d'InfluxDB. Utilisez les tags `action`, `zone_src`, `zone_dst` pour filtrer et créer des tableaux de bord.

---

## Références

- [Documentation iptables (Netfilter)](https://netfilter.org/documentation/)
- [Guide tcpdump](https://www.tcpdump.org/manpages/tcpdump.1.html)
- [Docker Networking](https://docs.docker.com/network/)
- [InfluxDB Line Protocol](https://docs.influxdata.com/influxdb/v2/write-data/developer-tools/line-protocol/)
- [Configuration Docker Compose](../firewall/docker-compose.yml)
- [Script de journalisation](../firewall/firewall-logger.sh)
- [Retour au README principal](../README.md)
