# Zone B - Administration

## Présentation

La Zone B constitue le réseau d'administration sécurisé de l'infrastructure. Elle permet aux administrateurs d'accéder aux services critiques hébergés en DMZ, de superviser l'ensemble du système et d'effectuer les opérations de maintenance.

L'accès à cette zone peut s'effectuer de deux manières :
- **SSH** : Connexion directe au conteneur admin via le port 2222
- **OpenVPN** : Tunnel chiffré permettant un accès distant sécurisé à l'ensemble de l'infrastructure

---

## Caractéristiques techniques

| Paramètre | Valeur |
|-----------|--------|
| **Sous-réseau** | `192.168.20.0/24` |
| **Passerelle** | `192.168.20.254` (Firewall) |
| **Protocoles autorisés** | SSH, HTTP/HTTPS, MQTT vers DMZ |
| **Image Docker** | `alpine:latest` |
| **Accès externe** | SSH (port 2222), OpenVPN (UDP 1194) |

---

## Services déployés

| Conteneur | Adresse IP | Port exposé | Fonction |
|-----------|------------|-------------|----------|
| `admin` | `192.168.20.10` | `2222` → `22` | Machine d'administration SSH |
| `openvpn-server` | `192.168.20.20` | `1194/UDP` | Serveur VPN pour accès distant |

---

## Machine d'administration (SSH)

### Accès et authentification

| Paramètre | Valeur |
|-----------|--------|
| **Hôte** | `localhost` |
| **Port** | `2222` |
| **Utilisateur** | `root` |
| **Mot de passe** | `admin123` |

**Connexion SSH :**

```bash
ssh root@localhost -p 2222
```

### Renouvellement de la clé SSH

Si le conteneur est recréé, la clé SSH change. Vous devrez supprimer l'ancienne clé connue :

```bash
ssh-keygen -R [localhost]:2222
```

### Outils disponibles

Le conteneur admin dispose des outils suivants :
- `openssh` : Accès SSH
- `curl` : Requêtes HTTP
- `mosquitto-clients` : Publication/souscription MQTT
- `iproute2` : Gestion réseau

---

## Serveur OpenVPN

### Configuration du serveur

Le serveur OpenVPN est configuré pour fournir un accès sécurisé à l'ensemble de l'infrastructure.

| Paramètre | Valeur |
|-----------|--------|
| **Port** | UDP 1194 |
| **Réseau VPN** | `10.8.0.0/24` |
| **Chiffrement** | AES-256-GCM |
| **Authentification** | SHA256 |
| **TLS minimum** | 1.2 |
| **Compression** | LZ4 |

### Routes poussées aux clients VPN

Une fois connecté, le client VPN a accès aux réseaux suivants :

| Réseau | Description |
|--------|-------------|
| `10.0.0.0/24` | Zone D - DMZ (services critiques) |
| `192.168.10.0/24` | Zone A - IoT (capteurs) |
| `192.168.20.0/24` | Zone B - Admin (auto) |
| `192.168.30.0/24` | Zone C - Bureautique |

### Fichier client OpenVPN

Le script `generate-client-config.ps1` génère automatiquement un fichier `.ovpn` contenant tous les certificats nécessaires.

```powershell
.\generate-client-config.ps1
```

Le fichier généré (`admin-vpn.ovpn`) peut être importé dans :
- **Windows** : OpenVPN GUI
- **Linux** : `openvpn --config admin-vpn.ovpn`
- **macOS** : Tunnelblick ou OpenVPN Connect

### Certificats VPN

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| `ca.crt` | `/etc/openvpn/certs/` | Autorité de certification |
| `vpn-server.crt` | `/etc/openvpn/certs/` | Certificat du serveur VPN |
| `vpn-server.key` | `/etc/openvpn/certs/` | Clé privée du serveur VPN |
| `dh2048.pem` | `/etc/openvpn/certs/` | Paramètres Diffie-Hellman |
| `ta.key` | `/etc/openvpn/certs/` | Clé TLS-Auth (protection DoS) |

---

## Politique de filtrage

Le pare-feu accorde à la Zone B un accès privilégié aux services de la DMZ :

| Source | Destination | Ports | Action | Description |
|--------|-------------|-------|--------|-------------|
| `192.168.20.0/24` | `10.0.0.0/24` | TCP 22, 443, 3000, 8086, 8883 | **ACCEPT** | Accès complet admin vers DMZ |
| `*` | `192.168.20.20` | UDP 1194 | **ACCEPT** | Connexions VPN entrantes |
| `192.168.20.0/24` | Autres zones | Tous | **DROP** | Pas d'accès direct aux autres zones |

### Services accessibles depuis la Zone B

| Service | Adresse | Port | Protocole |
|---------|---------|------|-----------|
| SSH vers DMZ | `10.0.0.X` | 22 | TCP |
| Grafana | `10.0.0.30` | 3000 | HTTP |
| InfluxDB | `10.0.0.40` | 8086 | HTTP |
| MQTT Broker | `10.0.0.20` | 8883 | MQTTS |
| LDAP | `10.0.0.10` | 389/636 | LDAP/LDAPS |

---

## Configuration Docker Compose

Fichier de configuration : [`zone-b-admin/docker-compose.yml`](../zone-b-admin/docker-compose.yml)

### Machine admin

```yaml
admin:
  image: alpine:latest
  cap_add:
    - NET_ADMIN
  networks:
    zone-b-admin:
      ipv4_address: 192.168.20.10
  ports:
    - "2222:22"
```

### Serveur OpenVPN

```yaml
openvpn-server:
  image: alpine:latest
  cap_add:
    - NET_ADMIN
  devices:
    - /dev/net/tun
  sysctls:
    - net.ipv4.ip_forward=1
  networks:
    zone-b-admin:
      ipv4_address: 192.168.20.20
  ports:
    - "1194:1194/udp"
  volumes:
    - ./openvpn/server.conf:/etc/openvpn/server.conf:ro
    - ../certificates/certs:/etc/openvpn/certs:ro
```

---

## Procédures de test

### Tester l'accès SSH

```bash
# Connexion à la machine admin
ssh root@localhost -p 2222
# Mot de passe : admin123
```

### Tester l'accès aux services DMZ

Depuis la machine admin :

```bash
# Accès à Grafana
curl -v http://10.0.0.30:3000

# Accès à InfluxDB
curl -v http://10.0.0.40:8086

# Test MQTT (avec certificat)
mosquitto_sub --cafile /certs/ca.crt \
  --cert /certs/client-capteur.crt \
  --key /certs/client-capteur.key \
  -h 10.0.0.20 -p 8883 -t "iot/#" --tls-version tlsv1.2
```

### Vérifier la connexion VPN

1. Importer `admin-vpn.ovpn` dans votre client OpenVPN
2. Se connecter au VPN
3. Tester l'accès aux services :
   ```bash
   curl http://10.0.0.30:3000
   ping 10.0.0.40
   ```

### Vérifier le routage

```bash
docker exec admin ip route
# Résultat attendu : default via 192.168.20.254
```

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Démarrer la zone | `docker compose -f zone-b-admin/docker-compose.yml up -d` |
| Arrêter la zone | `docker compose -f zone-b-admin/docker-compose.yml down` |
| Connexion SSH | `ssh root@localhost -p 2222` |
| Renouveler clé SSH | `ssh-keygen -R [localhost]:2222` |
| Voir les logs admin | `docker logs -f admin` |
| Voir les logs VPN | `docker logs -f openvpn-server` |
| Générer fichier client VPN | `.\generate-client-config.ps1` |
| Vérifier le routage | `docker exec admin ip route` |

---

## Dépannage

### Connexion SSH refusée

1. Vérifier que le conteneur est démarré :
   ```bash
   docker ps | grep admin
   ```

2. Vérifier que le port 2222 est bien exposé :
   ```bash
   docker port admin
   ```

3. Supprimer l'ancienne clé SSH connue :
   ```bash
   ssh-keygen -R [localhost]:2222
   ```

### OpenVPN ne se connecte pas

1. Vérifier que le conteneur VPN est démarré :
   ```bash
   docker ps | grep openvpn
   ```

2. Vérifier les logs du serveur VPN :
   ```bash
   docker logs openvpn-server
   ```

3. Vérifier que le port UDP 1194 est accessible :
   ```bash
   netstat -an | findstr 1194
   ```

### Accès aux services DMZ impossible

1. Vérifier que le pare-feu est démarré :
   ```bash
   docker ps | grep firewall
   ```

2. Vérifier les règles iptables :
   ```bash
   docker exec firewall iptables -L -v -n | grep 192.168.20
   ```

---

## Références

- [Documentation OpenVPN](https://openvpn.net/community-resources/)
- [OpenSSH Manual](https://www.openssh.com/manual.html)
- [Configuration serveur VPN](../zone-b-admin/openvpn/server.conf)
- [Configuration Docker Compose](../zone-b-admin/docker-compose.yml)
- [Retour au README principal](../README.md)
