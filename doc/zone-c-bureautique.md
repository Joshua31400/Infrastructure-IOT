# Zone C - Bureautique

## Présentation

La Zone C simule le réseau des postes de travail utilisateurs dans un environnement industriel : comptabilité, opérateurs de production, ressources humaines, etc.

Ces conteneurs représentent des machines clientes sans aucun service serveur. Leur rôle principal est de valider l'efficacité des règles de filtrage du pare-feu en simulant des utilisateurs légitimes qui tentent d'accéder aux ressources de l'entreprise.

---

## Caractéristiques techniques

| Paramètre | Valeur |
|-----------|--------|
| **Sous-réseau** | `192.168.30.0/24` |
| **Passerelle** | `192.168.30.254` (Firewall) |
| **Protocoles autorisés** | HTTP vers Grafana uniquement |
| **Image Docker** | `alpine:latest` |
| **Accès externe** | Aucun |

---

## Postes déployés

| Conteneur | Adresse IP | Description |
|-----------|------------|-------------|
| `client1` | `192.168.30.10` | Poste utilisateur standard |
| `client2` | `192.168.30.20` | Poste utilisateur secondaire |

Ces conteneurs sont configurés de manière identique et disposent des outils suivants :
- `curl` : Requêtes HTTP
- `wget` : Téléchargement de fichiers
- `iproute2` : Gestion réseau

---

## Politique de filtrage

Le pare-feu applique des règles restrictives pour la Zone C. Seul l'accès aux tableaux de bord Grafana est autorisé :

| Source | Destination | Port | Action | Description |
|--------|-------------|------|--------|-------------|
| `192.168.30.0/24` | `10.0.0.0/24` | TCP 443 | **ACCEPT** | Accès HTTPS générique (non utilisé) |
| `192.168.30.0/24` | `10.0.0.30` | TCP 3000 | **ACCEPT** | Accès aux dashboards Grafana |
| `192.168.30.0/24` | Toute autre | Tous | **DROP** | Tout autre trafic bloqué |

### Ce que les utilisateurs bureautique peuvent faire :
- Consulter les tableaux de bord Grafana (visualisation des données IoT)

### Ce que les utilisateurs bureautique ne peuvent PAS faire :
- Accéder à InfluxDB (10.0.0.40:8086)
- Accéder au broker MQTT (10.0.0.20:8883)
- Accéder au serveur LDAP (10.0.0.10:389/636)
- Communiquer avec les capteurs IoT
- Accéder à la zone Admin
- Accéder à Internet

---

## Routage forcé

Par défaut, Docker attribue une passerelle (`.1`) permettant aux conteneurs de contourner l'architecture réseau. Pour garantir que tout le trafic passe par le pare-feu, chaque client exécute au démarrage :

```bash
# Suppression de la passerelle Docker par défaut
ip route del default

# Ajout du pare-feu comme unique passerelle
ip route add default via 192.168.30.254
```

Cette configuration est essentielle pour :
- Valider les règles de filtrage du pare-feu
- Assurer que le trafic est bien journalisé
- Reproduire un environnement réseau réaliste

**Important :** Si le conteneur `firewall` est arrêté, les clients bureautique perdent totalement leur connectivité réseau. C'est le comportement attendu dans une architecture sécurisée.

---

## Configuration Docker Compose

Fichier de configuration : [`zone-c-bureautique/docker-compose.yml`](../zone-c-bureautique/docker-compose.yml)

```yaml
services:
  client1:
    image: alpine:latest
    container_name: client1
    hostname: client1
    cap_add:
      - NET_ADMIN          # Requis pour modifier la table de routage
    command: |
      sh -c "
      apk add --no-cache curl bash wget iproute2
      ip route del default
      ip route add default via 192.168.30.254
      tail -f /dev/null
      "
    networks:
      zone-c-bureautique:
        ipv4_address: 192.168.30.10
```

Points clés :
- `cap_add: NET_ADMIN` : Permet de modifier la table de routage
- `tail -f /dev/null` : Maintient le conteneur en vie
- IP statique assignée dans le sous-réseau bureautique

---

## Procédures de test

Ces tests permettent de valider que le pare-feu filtre correctement le trafic.

### Test d'accès autorisé : Grafana

Ce test doit réussir (HTTP 200 ou redirection vers /login) :

```bash
# Accéder au conteneur client
docker exec -it client1 sh

# Tester l'accès à Grafana
curl -v http://10.0.0.30:3000
```

**Résultat attendu :** Réponse HTTP 200 ou 302 (redirection vers la page de connexion)

### Test d'accès interdit : InfluxDB

Ce test doit échouer (timeout ou connexion refusée) :

```bash
docker exec -it client1 sh

# Tenter d'accéder à InfluxDB
curl -v http://10.0.0.40:8086 --connect-timeout 5
```

**Résultat attendu :** Timeout ou "Connection refused"

### Test d'accès interdit : MQTT

Ce test doit échouer :

```bash
docker exec -it client1 sh

# Tenter de se connecter au broker MQTT
curl -v https://10.0.0.20:8883 --connect-timeout 5
```

**Résultat attendu :** Timeout ou "Connection refused"

### Vérifier le routage

```bash
docker exec client1 ip route
```

**Résultat attendu :**
```
default via 192.168.30.254 dev eth0
192.168.30.0/24 dev eth0 scope link src 192.168.30.10
```

---

## Scénarios de validation

### Scénario 1 : Utilisateur légitime

Un employé du service comptabilité souhaite consulter les statistiques de production.

1. Il accède à Grafana : `http://10.0.0.30:3000`
2. Il se connecte avec ses identifiants LDAP
3. Il visualise les dashboards IoT

**Résultat :** Accès autorisé, données visibles.

### Scénario 2 : Tentative d'accès non autorisé

Un utilisateur curieux tente d'accéder directement à la base de données.

1. Il tente d'accéder à InfluxDB : `http://10.0.0.40:8086`
2. La requête est bloquée par le pare-feu
3. L'événement est journalisé avec le préfixe `[FW-BLOCKED]`

**Résultat :** Accès refusé, tentative tracée.

### Scénario 3 : Pare-feu désactivé

Le pare-feu est arrêté pour maintenance.

1. Les clients bureautique perdent leur route par défaut
2. Aucune communication réseau n'est possible
3. L'accès reprend automatiquement au redémarrage du pare-feu

**Résultat :** Isolation totale (comportement de sécurité attendu).

---

## Commandes utiles

| Action | Commande |
|--------|----------|
| Démarrer la zone | `docker compose -f zone-c-bureautique/docker-compose.yml up -d` |
| Arrêter la zone | `docker compose -f zone-c-bureautique/docker-compose.yml down` |
| Accéder à client1 | `docker exec -it client1 sh` |
| Accéder à client2 | `docker exec -it client2 sh` |
| Vérifier le routage | `docker exec client1 ip route` |
| Voir les logs | `docker logs client1` |
| Tester Grafana | `docker exec client1 curl -s http://10.0.0.30:3000` |

---

## Dépannage

### Le client ne peut pas accéder à Grafana

1. Vérifier que le pare-feu est démarré :
   ```bash
   docker ps | grep firewall
   ```

2. Vérifier la route par défaut :
   ```bash
   docker exec client1 ip route
   ```

3. Vérifier les règles iptables :
   ```bash
   docker exec firewall iptables -L -v -n | grep "192.168.30"
   ```

4. Vérifier que Grafana est accessible :
   ```bash
   docker ps | grep grafana
   ```

### Le client a accès à des services interdits

1. Vérifier que la route par défaut pointe vers le pare-feu :
   ```bash
   docker exec client1 ip route
   ```
   La route doit être `default via 192.168.30.254`

2. Si la route pointe vers `.1`, redémarrer le conteneur :
   ```bash
   docker restart client1
   ```

### Pas de connectivité du tout

1. Vérifier l'état du pare-feu :
   ```bash
   docker ps | grep firewall
   ```

2. Si le pare-feu est arrêté, c'est le comportement attendu. Le redémarrer :
   ```bash
   docker compose -f firewall/docker-compose.yml up -d
   ```

---

## Références

- [Documentation Zone Z - Firewall](zone-z-firewall.md)
- [Documentation Zone D - DMZ](zone-d-dmz.md)
- [Configuration Docker Compose](../zone-c-bureautique/docker-compose.yml)
- [Retour au README principal](../README.md)
