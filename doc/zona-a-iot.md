# 🌐 Zone A - Capteurs IOT

## 📌 Description
La zone A correspond au réseau des capteurs IOT. Elle est dédiée à la collecte de données issues des capteurs, à leur transmission sécurisée via MQTT, et à l’isolation stricte de ces équipements du reste de l’infrastructure.

### Objectifs de la zone
1. **Collecte sécurisée** des données des capteurs.
2. **Transmission via MQTT** vers le broker en DMZ.
3. **Isolation réseau** pour limiter les risques d’intrusion.

---

## 📂 Configuration
Le déploiement de la zone A est défini dans le fichier Docker Compose suivant :

👉 **[Voir fichier docker-compose.yml](../zone-a-iot/docker-compose.yml)**

- **Image de base :** Alpine Linux
- **Adresse IP :** `192.168.10.10`
- **Accès MQTT :** Port 8883 (TLS)
- **Routage :** Passage obligatoire par le firewall (`192.168.10.254`)

---

## ⚙️ Spécificités Techniques

- **Communication MQTT sécurisée :**
  - Utilisation de certificats TLS pour l’authentification et le chiffrement.
  - Les certificats sont générés et stockés dans `certificates/certs/`.
  - Connexion au broker Mosquitto situé en DMZ (`10.0.0.20:8883`).
- **Routage forcé :**
  - Suppression de la passerelle Docker par défaut.
  - Ajout du firewall comme unique passerelle de sortie.
- **Outils installés :** mosquitto-clients, openssl, bash, iproute2

---

## 🧪 Procédure de test
Pour valider la sécurité et la connectivité de la zone IOT, exécutez les tests suivants :

```bash
# 1. Connexion au conteneur capteur
# (depuis l’hôte)
docker exec -it capteur bash

# 2. Tester la publication MQTT (avec certificat)
mosquitto_pub --cafile /certs/ca.crt --cert /certs/client-capteur.crt --key /certs/client-capteur.key -h 10.0.0.20 -p 8883 -t "test/topic" -m "test message" --tls-version tlsv1.2

# 3. Tester la souscription MQTT (avec certificat)
mosquitto_sub --cafile /certs/ca.crt --cert /certs/client-capteur.crt --key /certs/client-capteur.key -h 10.0.0.20 -p 8883 -t "test/topic" --tls-version tlsv1.2

# 4. Vérifier l’absence d’accès direct aux autres zones (doit échouer)
curl -v http://10.0.0.30:3000 # Grafana (doit être bloqué)
curl -v http://10.0.0.40:8086 # InfluxDB (doit être bloqué)
```

> **Remarque :**
> - Seules les communications MQTT sortantes vers la DMZ sont autorisées.
> - Toute tentative d’accès HTTP/SSH vers d’autres zones doit échouer.

---

## 🛠 Commandes Utiles
| Action | Commande |
| --- | --- |
| Démarrer la zone | `docker compose up -d` |
| Accéder au conteneur capteur | `docker exec -it capteur bash` |
| Publier un message MQTT | `mosquitto_pub ...` |
| S’abonner à un topic MQTT | `mosquitto_sub ...` |
| Vérifier le routage | `docker exec capteur ip route` |
| Voir les logs | `docker compose logs capteur` |
| Arrêter la zone | `docker compose down` |

---

## 🔗 Références
- [README principal](../README.md)
- [Configuration Docker Compose](../zone-a-iot/docker-compose.yml)
- [Certificats TLS](../certificates/certs/)
- [Broker Mosquitto DMZ](../zone-d-dmz/docker-compose.yml)
