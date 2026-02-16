# Zone D - DMZ (Zone Démilitarisée)

## Présentation

La Zone D constitue la DMZ (Zone Démilitarisée) de l'infrastructure. Elle héberge les services critiques accessibles depuis les autres zones tout en maintenant une isolation stricte pour limiter l'impact d'une éventuelle compromission.

Cette zone fait office de tampon entre les équipements IoT, les postes utilisateurs et le réseau d'administration. Tous les services partagés y sont centralisés : broker MQTT, base de données, supervision et authentification.

---

## Caractéristiques techniques

| Paramètre | Valeur |
|-----------|--------|
| **Sous-réseau** | `10.0.0.0/24` |
| **Passerelle** | `10.0.0.254` (Firewall) |
| **Nombre de services** | 4 |
| **Volumes persistants** | 6 |
| **Ports exposés** | 389, 636, 3000, 8086, 8883 |

---

## Services déployés

| Service | Conteneur | Adresse IP | Port(s) | Fonction |
|---------|-----------|------------|---------|----------|
| **Mosquitto** | `broker-mqtt` | `10.0.0.20` | 8883 | Broker MQTT sécurisé (mTLS) |
| **Grafana** | `grafana` | `10.0.0.30` | 3000 | Visualisation et tableaux de bord |
| **InfluxDB** | `influxdb` | `10.0.0.40` | 8086 | Base de données time-series |
| **OpenLDAP** | `ldap` | `10.0.0.10` | 389, 636 | Annuaire et authentification |

---

## Broker MQTT (Mosquitto)

### Configuration

Le broker Mosquitto est configuré pour n'accepter que des connexions TLS authentifiées par certificat (mTLS).

| Paramètre | Valeur |
|-----------|--------|
| **Port** | 8883 (MQTTS) |
| **Version TLS minimum** | 1.2 |
| **Authentification** | Certificat client obligatoire |
| **Accès anonyme** | Désactivé |

### Fichiers de configuration

| Fichier | Emplacement | Description |
|---------|-------------|-------------|
| `mosquitto.conf` | `/mosquitto/config/` | Configuration principale |
| `acl.conf` | `/mosquitto/config/` | Règles de contrôle d'accès |
| `ca.crt` | `/mosquitto/config/certs/` | Certificat CA |
| `server.crt` | `/mosquitto/config/certs/` | Certificat serveur |
| `server.key` | `/mosquitto/config/certs/` | Clé privée serveur |

### Contrôle d'accès (ACL)

Les permissions sont attribuées selon le CN (Common Name) du certificat client :

| Utilisateur (CN) | Topic | Permission |
|------------------|-------|------------|
| `capteur-iot` | `iot/#` | Écriture |
| `grafana_dashboards` | `iot/#`, `#` | Lecture |
| `admin` | `#` | Lecture/Écriture |

### Exemple de publication

```bash
mosquitto_pub \
  --cafile /certs/ca.crt \
  --cert /certs/client-capteur.crt \
  --key /certs/client-capteur.key \
  -h 10.0.0.20 -p 8883 \
  -t "iot/temperature" \
  -m '{"sensor":"T1","value":25}' \
  --tls-version tlsv1.2
```

---

## Grafana

### Configuration

Grafana est configuré avec l'authentification LDAP pour permettre aux utilisateurs de se connecter avec leurs identifiants centralisés.

| Paramètre | Valeur |
|-----------|--------|
| **Port** | 3000 |
| **URL** | http://10.0.0.30:3000 |
| **Admin par défaut** | `admin` / `admin123` |
| **Authentification** | LDAP activé |
| **Plugin MQTT** | `grafana-mqtt-datasource` |

### Sources de données

| Source | Type | Description |
|--------|------|-------------|
| MQTT | Plugin | Données temps réel des capteurs IoT |
| InfluxDB | Natif | Logs du pare-feu |

### Tableaux de bord

Deux tableaux de bord sont provisionnés automatiquement :

| Dashboard | Fichier | Description |
|-----------|---------|-------------|
| IoT Dashboard | `iot-dashboard.json` | Visualisation des données capteurs |
| Firewall Dashboard | `firewall-dashboard.json` | Analyse des logs réseau |

### Configuration LDAP

Le fichier `ldap.toml` configure la connexion à l'annuaire :

```toml
[[servers]]
host = "10.0.0.10"
port = 636
use_ssl = true
bind_dn = "cn=admin,dc=usine,dc=local"
bind_password = "adminldap"
search_filter = "(cn=%s)"
search_base_dns = ["ou=People,dc=usine,dc=local"]
```

---

## InfluxDB

### Configuration

InfluxDB stocke les logs réseau envoyés par le pare-feu pour audit et analyse.

| Paramètre | Valeur |
|-----------|--------|
| **Port** | 8086 |
| **URL** | http://10.0.0.40:8086 |
| **Organisation** | `usine-iot` |
| **Bucket** | `firewall-logs` |
| **Admin** | `admin` / `adminpass123` |
| **Token API** | `mytoken123456` |

### Schéma des données

Les logs du pare-feu sont stockés dans le format suivant :

| Champ | Type | Description |
|-------|------|-------------|
| `action` | Tag | ACCEPTED ou BLOCKED |
| `proto` | Tag | Protocole (TCP, UDP) |
| `zone_src` | Tag | Zone source (IoT, Admin, etc.) |
| `zone_dst` | Tag | Zone destination |
| `src` | Field | Adresse IP source |
| `dst` | Field | Adresse IP destination |
| `sport` | Field | Port source |
| `dport` | Field | Port destination |

### Requête exemple (Flux)

```flux
from(bucket: "firewall-logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r.action == "BLOCKED")
  |> group(columns: ["zone_src"])
  |> count()
```

---

## OpenLDAP

### Configuration

L'annuaire LDAP centralise l'authentification pour Grafana et potentiellement d'autres services.

| Paramètre | Valeur |
|-----------|--------|
| **Port LDAP** | 389 |
| **Port LDAPS** | 636 |
| **Domaine** | `usine.local` |
| **Base DN** | `dc=usine,dc=local` |
| **Admin DN** | `cn=admin,dc=usine,dc=local` |
| **Admin Password** | `adminldap` |

### Structure de l'annuaire

```
dc=usine,dc=local
├── cn=admin                    # Compte administrateur
└── ou=People                   # Unité organisationnelle
    └── cn=pedro                # Utilisateur exemple
```

### Utilisateurs préconfigurés

| Utilisateur | DN | Mot de passe | Email |
|-------------|------|--------------|-------|
| `pedro` | `cn=pedro,ou=People,dc=usine,dc=local` | `pedroldap` | `pedro@usine.local` |

### Ajouter un utilisateur

Créer un fichier LDIF (ex: `nouvel-utilisateur.ldif`) :

```ldif
dn: cn=alice,ou=People,dc=usine,dc=local
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
cn: alice
sn: Dupont
givenName: Alice
uid: alice
uidNumber: 1001
gidNumber: 1000
homeDirectory: /home/alice
loginShell: /bin/bash
userPassword: motdepasse
mail: alice@usine.local
```

Puis l'ajouter à l'annuaire :

```bash
docker exec ldap ldapadd -x -D "cn=admin,dc=usine,dc=local" -w adminldap -f /tmp/nouvel-utilisateur.ldif
```

---

## Configuration Docker Compose

Fichier de configuration : [`zone-d-dmz/docker-compose.yml`](../zone-d-dmz/docker-compose.yml)

### Volumes persistants

| Volume | Service | Description |
|--------|---------|-------------|
| `mosquitto-data` | broker-mqtt | Messages persistants MQTT |
| `mosquitto-log` | broker-mqtt | Logs Mosquitto |
| `influxdb-data` | influxdb | Données time-series |
| `grafana-data` | grafana | Configuration et dashboards |
| `ldap-data` | ldap | Base de données LDAP |
| `ldap-config` | ldap | Configuration LDAP |

### Dépendances

Le service Grafana dépend de :
- `influxdb` : Source de données pour les logs
- `ldap` : Authentification des utilisateurs

---

## Politique de filtrage

Le pare-feu autorise les flux suivants vers la DMZ :

| Source | Port | Service | Description |
|--------|------|---------|-------------|
| Zone A (IoT) | 8883 | MQTT | Capteurs → Broker |
| Zone B (Admin) | 22, 443, 3000, 8086, 8883 | Tous | Accès complet admin |
| Zone C (Bureau) | 3000 | Grafana | Consultation dashboards |
| DMZ | * | Intra-DMZ | Communication entre services |

---

## Procédures de test

### Tester l'accès MQTT

```bash
# Avec certificat client
mosquitto_sub \
  --cafile /certs/ca.crt \
  --cert /certs/client-capteur.crt \
  --key /certs/client-capteur.key \
  -h 10.0.0.20 -p 8883 \
  -t "iot/#" --tls-version tlsv1.2
```

### Tester l'accès Grafana

1. Accéder à http://localhost:3000 (ou http://10.0.0.30:3000 depuis un conteneur)
2. Se connecter avec `admin` / `admin123` ou un compte LDAP (`pedro` / `pedroldap`)
3. Vérifier les tableaux de bord

### Tester l'accès InfluxDB

1. Accéder à http://localhost:8086
2. Se connecter avec `admin` / `adminpass123`
3. Explorer le bucket `firewall-logs`

### Tester l'authentification LDAP

```bash
# Depuis un conteneur
docker exec ldap ldapsearch -x -H ldap://localhost \
  -D "cn=admin,dc=usine,dc=local" -w adminldap \
  -b "ou=People,dc=usine,dc=local"
```

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Démarrer la zone | `docker compose -f zone-d-dmz/docker-compose.yml up -d` |
| Arrêter la zone | `docker compose -f zone-d-dmz/docker-compose.yml down` |
| Voir les logs MQTT | `docker logs -f broker-mqtt` |
| Voir les logs Grafana | `docker logs -f grafana` |
| Voir les logs InfluxDB | `docker logs -f influxdb` |
| Voir les logs LDAP | `docker logs -f ldap` |
| Accéder à un conteneur | `docker exec -it <service> sh` |
| Vérifier les volumes | `docker volume ls` |

---

## Dépannage

### Grafana ne démarre pas

1. Vérifier les logs :
   ```bash
   docker logs grafana
   ```

2. Vérifier les dépendances :
   ```bash
   docker ps | grep -E "influxdb|ldap"
   ```

### Authentification LDAP échoue

1. Vérifier que le service LDAP est actif :
   ```bash
   docker ps | grep ldap
   ```

2. Tester la connexion LDAP :
   ```bash
   docker exec ldap ldapsearch -x -H ldap://localhost \
     -D "cn=admin,dc=usine,dc=local" -w adminldap -b "dc=usine,dc=local"
   ```

3. Vérifier la configuration `ldap.toml` dans Grafana

### Broker MQTT refuse les connexions

1. Vérifier que le certificat client est valide :
   ```bash
   openssl x509 -in client-capteur.crt -text -noout | grep "Subject:"
   ```

2. Vérifier les logs Mosquitto :
   ```bash
   docker logs broker-mqtt
   ```

3. Vérifier les ACL dans `acl.conf`

---

## Recommandations de sécurité

En environnement de production, il est recommandé de :

1. **Changer tous les mots de passe par défaut** (admin123, adminldap, etc.)
2. **Activer HTTPS pour Grafana** avec les certificats fournis
3. **Utiliser LDAPS (port 636)** pour les communications LDAP
4. **Restreindre l'accès aux tokens API** InfluxDB
5. **Mettre en place des sauvegardes** des volumes persistants
6. **Surveiller les logs** pour détecter les tentatives d'intrusion

---

## Références

- [Documentation Mosquitto](https://mosquitto.org/documentation/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Documentation InfluxDB](https://docs.influxdata.com/influxdb/)
- [Documentation OpenLDAP](https://www.openldap.org/doc/)
- [Configuration Docker Compose](../zone-d-dmz/docker-compose.yml)
- [Retour au README principal](../README.md)

