# 🏢 Zone C - Bureautique (Simulation Clients)

## 📌 Description
Cette zone simule le réseau des postes de travail utilisateurs (ex: Service Comptabilité, Opérateurs, RH).
Ces conteneurs ne contiennent **aucun service serveur**. Ce sont des machines "clientes" (basées sur Alpine Linux) utilisées pour **valider l'efficacité et la sécurité du Firewall**.

### Objectifs de la zone
1.  **Simuler un trafic légitime :** Accéder aux dashboards Grafana (Port 3000).
2.  **Tester les interdictions :** Tenter d'accéder aux bases de données ou au broker MQTT (doit être bloqué).
3.  **Validation du routage :** Prouver que le trafic passe réellement par le Firewall et non par la passerelle par défaut de Docker.

---

## 📂 Configuration

Le déploiement de cette zone est défini dans le fichier Docker Compose situé dans ce répertoire.

👉 **[Voir fichier docker-compose.yml](../zone-c-bureautique/docker-compose.yml)**

---

## ⚙️ Spécificité Technique : Le Routage Force

C'est la partie critique de cette configuration. Par défaut, Docker fournit une passerelle (`.1`) qui permet aux conteneurs de contourner notre architecture réseau. Pour valider notre sécurité, nous devons forcer les clients à passer par notre conteneur Firewall (`.254`).

### 1. Prérequis Docker (`cap_add`)
Pour modifier les routes réseaux, les conteneurs clients doivent posséder les droits d'administration réseau.
* **Directive :** `cap_add: - NET_ADMIN`

### 2. Script de Démarrage (Boot Script)
Au lancement, chaque client exécute automatiquement les commandes suivantes pour modifier sa table de routage :

```bash
# 1. Installation des outils nécessaires (curl, iproute2)
apk add --no-cache curl bash wget iproute2

# 2. Suppression de la passerelle par défaut Docker (la "porte dérobée")
ip route del default

# 3. Ajout du Firewall comme SEULE porte de sortie
ip route add default via 192.168.30.254
```
**Note**: Si le conteneur Firewall est éteint, ces machines perdent totalement leur accès au réseau (y compris Internet). C'est le comportement attendu.

---

## Procédure de test
Pour vérifier que le Firewall filtre correctement le trafic venant de la bureautique :

```bash
# 1. Se connecter à un client
docker exec -it client1 sh

# 2. Test d'accès autorisé (Grafana)
# Le flux HTTP vers le port 3000 doit être autorisé (Règle ACCEPT).
curl -v [http://10.0.0.30:3000](http://10.0.0.30:3000)

# 3. Test d'accès interdit (InfluxDB / Base de données)
# Le flux vers le port 8086 n'est pas explicitement autorisé, il doit être bloqué par la politique par défaut.
curl -v [http://10.0.0.40:8086](http://10.0.0.40:8086)
```

## 🛠 Commandes Utiles
| Action | Command |
| --- | --- |
| Démarrer la zone | `docker compose up -d` |
| Vérifier le routage | `docker exec client1 ip route` |
| Voir les logs de config | `docker compose logs client1` |
| Arrêter la zone | `docker compose down` |


