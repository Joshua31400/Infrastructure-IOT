# Politique de Sécurité

## Introduction

Ce document décrit les mesures de sécurité mises en œuvre dans l'infrastructure IoT industrielle. L'architecture suit les principes du Zero Trust : aucune confiance implicite n'est accordée, chaque flux doit être explicitement autorisé et authentifié.

---

## Principes fondamentaux

### Defense in Depth (Défense en profondeur)

L'infrastructure implémente plusieurs couches de sécurité complémentaires :

1. **Segmentation réseau** : Isolation des zones via des sous-réseaux dédiés
2. **Filtrage périmétrique** : Pare-feu central avec politique "deny by default"
3. **Authentification mutuelle** : mTLS pour les communications MQTT
4. **Authentification centralisée** : LDAP pour la gestion des identités
5. **Chiffrement des communications** : TLS 1.2 minimum partout
6. **Journalisation** : Traçabilité complète des flux réseau

### Principe du moindre privilège

Chaque composant dispose uniquement des accès nécessaires à son fonctionnement :

| Zone | Accès autorisés | Accès refusés |
|------|-----------------|---------------|
| IoT (A) | MQTT vers DMZ uniquement | Tout le reste |
| Admin (B) | DMZ complète | Accès direct IoT/Bureau |
| Bureau (C) | Grafana uniquement | InfluxDB, MQTT, LDAP |
| DMZ (D) | Intra-DMZ + Internet | Zones internes |

---

## Infrastructure à Clé Publique (PKI)

### Autorité de Certification

Une CA (Certificate Authority) interne signe tous les certificats de l'infrastructure.

| Fichier | Description | Validité |
|---------|-------------|----------|
| `ca.crt` | Certificat racine de la CA | 10 ans |
| `ca.key` | Clé privée de la CA | - |

**Génération :**

```bash
openssl genrsa -out ca.key 2048
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt \
  -subj "/C=FR/ST=IDF/L=Paris/O=UsineIoT/CN=CA-IoT"
```

### Certificats serveur

| Service | Fichiers | CN | SAN |
|---------|----------|------|-----|
| MQTT Broker | `server.crt`, `server.key` | broker-mqtt | DNS:broker-mqtt, IP:10.0.0.20 |
| LDAP | `ldap-server.crt`, `ldap-server.key` | ldap | DNS:ldap, IP:10.0.0.10 |
| VPN | `vpn-server.crt`, `vpn-server.key` | vpn-server | DNS:vpn-server, IP:192.168.20.20 |

### Certificats client

| Client | Fichiers | CN | Utilisation |
|--------|----------|------|-------------|
| Capteurs IoT | `client-capteur.crt`, `client-capteur.key` | capteur-iot | Publication MQTT |
| Grafana (MQTT) | `client-grafana.crt`, `client-grafana.key` | grafana_dashboards | Souscription MQTT |
| Client VPN | `vpn-client.crt`, `vpn-client.key` | admin-vpn-client | Connexion VPN |

### Paramètres Diffie-Hellman

Pour OpenVPN, des paramètres DH de 2048 bits sont générés :

```bash
openssl dhparam -out dh2048.pem 2048
```

---

## Authentification et Contrôle d'Accès

### MQTT - Authentification par certificat (mTLS)

Le broker Mosquitto est configuré pour exiger un certificat client valide :

```
require_certificate true
use_identity_as_username true
allow_anonymous false
```

Le CN (Common Name) du certificat devient l'identifiant utilisateur pour les ACL.

### MQTT - Contrôle d'accès (ACL)

| Utilisateur (CN) | Topic | Permission |
|------------------|-------|------------|
| `capteur-iot` | `iot/#` | Écriture seule |
| `grafana_dashboards` | `iot/#`, `#` | Lecture seule |
| `admin` | `#` | Lecture/Écriture |

### LDAP - Authentification centralisée

L'annuaire OpenLDAP centralise les identités utilisateurs :

| Paramètre | Valeur |
|-----------|--------|
| Base DN | `dc=usine,dc=local` |
| Users OU | `ou=People,dc=usine,dc=local` |
| Bind DN | `cn=admin,dc=usine,dc=local` |

**Structure :**

```
dc=usine,dc=local
├── cn=admin
└── ou=People
    └── cn=<utilisateur>
```

### Grafana - Authentification LDAP

Grafana utilise LDAPS (port 636) pour authentifier les utilisateurs :

```toml
[[servers]]
host = "10.0.0.10"
port = 636
use_ssl = true
```

---

## Chiffrement des Communications

### TLS 1.2 minimum

Tous les services sont configurés pour refuser les versions TLS inférieures à 1.2 :

| Service | Configuration |
|---------|---------------|
| MQTT | `tls_version tlsv1.2` |
| OpenVPN | `tls-version-min 1.2` |
| LDAP | Port 636 (LDAPS) |

### Algorithmes de chiffrement

| Service | Chiffrement | Authentification |
|---------|-------------|------------------|
| MQTT | TLS_AES_256_GCM | Certificat |
| OpenVPN | AES-256-GCM | SHA256 + Certificat |
| LDAPS | TLS auto-négocié | Bind DN + Password |

### OpenVPN - Sécurité renforcée

- **TLS-Auth** : Clé HMAC pour prévenir les attaques DoS
- **Compression** : LZ4 (sécurisée contre VORACLE)
- **Réseau dédié** : `10.8.0.0/24` pour les clients VPN

---

## Filtrage Réseau

### Politique par défaut

```bash
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT
```

### Règles de filtrage

Voir la documentation complète du pare-feu : [Zone Z - Firewall](zone-z-firewall.md)

### Journalisation

Tous les paquets sont journalisés avec un préfixe identifiant la règle :

| Préfixe | Description |
|---------|-------------|
| `[FW-VPN-IN]` | Connexions VPN entrantes |
| `[FW-IOT-MQTT]` | Capteurs → Broker |
| `[FW-ADMIN-DMZ]` | Admin → DMZ |
| `[FW-BUREAU-GRAFANA]` | Bureau → Grafana |
| `[FW-BLOCKED]` | Trafic bloqué |

---

## Isolation des Conteneurs

### Capabilities Docker

Les conteneurs fonctionnent avec les privilèges minimaux nécessaires :

| Conteneur | Capabilities | Justification |
|-----------|--------------|---------------|
| Firewall | `NET_ADMIN` + `privileged` | Manipulation iptables |
| Capteurs | `NET_ADMIN` | Modification des routes |
| Clients | `NET_ADMIN` | Modification des routes |
| Services DMZ | Aucune | Fonctionnement standard |

### Volumes en lecture seule

Les certificats et configurations sensibles sont montés en lecture seule :

```yaml
volumes:
  - ../certificates/certs:/certs:ro
  - ./mosquitto.conf:/mosquitto/config/mosquitto.conf:ro
```

### Réseaux isolés

Chaque zone dispose de son propre réseau Docker :

```yaml
networks:
  zone-a-iot:
    driver: bridge
    ipam:
      config:
        - subnet: 192.168.10.0/24
```

---

## Gestion des Secrets

### Mots de passe par défaut

**Ces mots de passe sont à usage de démonstration uniquement :**

| Service | Utilisateur | Mot de passe |
|---------|-------------|--------------|
| Grafana | admin | admin123 |
| InfluxDB | admin | adminpass123 |
| LDAP | admin | adminldap |
| SSH Admin | root | admin123 |
| LDAP User | pedro | pedroldap |

### Tokens API

| Service | Token |
|---------|-------|
| InfluxDB | mytoken123456 |

### Recommandations pour la production

1. **Changer tous les mots de passe par défaut**
2. **Utiliser un gestionnaire de secrets** (Vault, Docker Secrets)
3. **Générer des tokens aléatoires** de longueur suffisante
4. **Mettre en place une rotation des secrets**
5. **Ne jamais commiter de secrets** dans le contrôle de version

---

## Audit et Traçabilité

### Logs du pare-feu

Tous les flux réseau sont capturés et envoyés vers InfluxDB :

| Champ | Description |
|-------|-------------|
| action | ACCEPTED ou BLOCKED |
| zone_src | Zone source |
| zone_dst | Zone destination |
| src | IP source |
| dst | IP destination |
| sport | Port source |
| dport | Port destination |

### Visualisation dans Grafana

Le dashboard "Firewall" permet de visualiser :
- Nombre de connexions par zone
- Tentatives de connexion bloquées
- Ports les plus utilisés
- Historique des événements

### Alertes recommandées

En production, configurer des alertes pour :
- Nombre élevé de `[FW-BLOCKED]`
- Tentatives de connexion depuis des IP inconnues
- Échecs d'authentification LDAP
- Anomalies de volume de trafic

---

## Recommandations de Production

### Infrastructure

- [ ] Déployer sur des serveurs dédiés (pas de desktop)
- [ ] Mettre en place une redondance du pare-feu
- [ ] Configurer des backups automatiques des volumes
- [ ] Utiliser un orchestrateur (Kubernetes, Swarm) pour la haute disponibilité

### Réseau

- [ ] Utiliser de vrais VLANs physiques
- [ ] Configurer des IDS/IPS (Snort, Suricata)
- [ ] Mettre en place un reverse proxy avec WAF
- [ ] Activer HTTPS partout (Grafana, InfluxDB)

### Authentification

- [ ] Intégrer avec un IdP existant (Active Directory, FreeIPA)
- [ ] Activer l'authentification multi-facteur (MFA)
- [ ] Implémenter une politique de mots de passe forts
- [ ] Configurer le verrouillage de compte après échecs

### Surveillance

- [ ] Centraliser les logs (ELK Stack, Loki)
- [ ] Mettre en place une solution SIEM
- [ ] Configurer des scans de vulnérabilités réguliers
- [ ] Réaliser des tests de pénétration périodiques

---

## Références

- [OWASP IoT Security Guidelines](https://owasp.org/www-project-internet-of-things/)
- [NIST Cybersecurity Framework](https://www.nist.gov/cyberframework)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)
- [Documentation Zone Z - Firewall](zone-z-firewall.md)
- [Retour au README principal](../README.md)
