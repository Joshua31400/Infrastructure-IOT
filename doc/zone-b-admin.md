# 🛡️ Zone B - Administration (Réseau Admin)

## 📌 Description
Cette zone représente le réseau sécurisé dédié à l'administration de l'infrastructure. Elle permet aux administrateurs d'accéder aux interfaces de gestion, de superviser les services critiques et d'assurer la maintenance du système.

### Objectifs de la zone
1. **Accès sécurisé** aux interfaces d'administration (SSH, InfluxDB, Grafana).
2. **Gestion centralisée** des services et supervision des logs.
3. **Isolation stricte** du reste du réseau pour limiter la surface d'attaque.

---

## 📂 Configuration
Le déploiement de cette zone est défini dans le fichier Docker Compose suivant :

👉 **[Voir fichier docker-compose.yml](../zone-b-admin/docker-compose.yml)**

- **Image de base :** Alpine Linux
- **Adresse IP :** `192.168.20.10`
- **Accès SSH :** Port 2222 (redirigé vers le port 22 du conteneur)
- **Routage :** Passage obligatoire par le firewall (`192.168.20.254`)

---

## ⚙️ Spécificités Techniques

- **Routage forcé :**
  - Suppression de la passerelle Docker par défaut.
  - Ajout du firewall comme unique passerelle de sortie.
- **Accès SSH :**
  - Authentification par mot de passe (`root:admin123`) à la première connexion.
  - **Renouvellement de la clé SSH** obligatoire si le conteneur est recréé :
    ```bash
    ssh-keygen -R [localhost]:2222
    ```
- **Outils installés :** openssh, curl, bash, mosquitto-clients, iproute2

---

## 🧪 Procédure de test
Pour valider la sécurité et la connectivité de la zone admin, exécutez les tests suivants :

```bash
# 1. Connexion à l'interface d'administration (SSH)
ssh root@localhost -p 2222

# 2. Tester l'accès à Grafana (autorisé)
curl -v http://10.0.0.30:3000

# 3. Tester l'accès à InfluxDB (autorisé uniquement pour l'admin)
curl -v http://10.0.0.40:8086

# 4. Tester l'accès à l'IOT (doit être interdit)
curl -v telnet://10.0.0.20:8883
```

> **Remarque :**
> - L'accès SSH nécessite de régénérer la clé locale si le conteneur est redéployé.
> - Seul l'admin peut accéder à InfluxDB, les autres zones sont bloquées.

---

## 🛠 Commandes Utiles
| Action | Commande |
| --- | --- |
| Démarrer la zone | `docker compose up -d` |
| Se connecter en SSH | `ssh root@localhost -p 2222` |
| Vérifier le routage | `docker exec admin ip route` |
| Voir les logs de config | `docker compose logs admin` |
| Arrêter la zone | `docker compose down` |
| Renouveler la clé SSH | `ssh-keygen -R [localhost]:2222` |

---

## 🔗 Références
- [README principal](../README.md)
- [Configuration Docker Compose](../zone-b-admin/docker-compose.yml)
