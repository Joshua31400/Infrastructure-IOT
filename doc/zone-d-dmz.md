# 🛡️ Zone D - DMZ (Zone DéMilitarisée)

## 📌 Description
La zone D (DMZ) héberge les services critiques accessibles depuis d'autres zones du réseau, tout en étant isolée pour limiter les risques en cas de compromission. Elle sert de tampon entre les zones internes (IoT, Admin, Bureautique) et l'extérieur ou les zones à risque.

### Objectifs de la zone
1. **Centraliser les services partagés :** Héberger les services nécessaires à l'ensemble de l'infrastructure (broker MQTT, InfluxDB, Grafana, LDAP).
2. **Sécuriser l'accès :** Limiter les flux entrants/sortants grâce à des règles strictes et à l'isolation réseau.
3. **Surveiller et tracer :** Collecter les logs et métriques pour l'audit et la supervision.

---

## 📂 Configuration

Le déploiement de cette zone est défini dans le fichier Docker Compose situé dans ce répertoire.

👉 **[Voir fichier docker-compose.yml](../zone-d-dmz/docker-compose.yml)**

---

## ⚙️ Services Déployés

| Service         | Rôle principal                                 | Port(s) exposé(s) | Sécurité |
|-----------------|------------------------------------------------|-------------------|----------|
| broker-mqtt     | Broker MQTT sécurisé (mTLS)                    | 8883              | Certificats, ACL, pas d'anonymous |
| influxdb        | Base de données time-series pour logs/metrics  | 8086              | Authentification, volume persistant |
| grafana         | Visualisation et supervision                   | 3000              | Authentification LDAP, HTTPS possible |
| ldap            | Annuaire LDAP pour l'authentification          | 389, 636          | Accès restreint, volume persistant |

---

## 🔒 Sécurité & Bonnes Pratiques

- **MQTT (Mosquitto)** :
  - Authentification forte par certificats (mTLS).
  - Contrôle d'accès fin via ACL ([voir acl.conf](../zone-d-dmz/mosquitto/acl.conf)).
  - Pas d'accès anonyme.
- **Grafana** :
  - Authentification centralisée via LDAP ([voir ldap.toml](../zone-d-dmz/grafana_config/ldap.toml)).
  - Possibilité d'ajouter HTTPS avec les certificats fournis.
- **LDAP** :
  - Utilisé uniquement sur le réseau interne Docker.
  - Les mots de passe sont définis dans les variables d'environnement et le fichier users.ldif ([voir users.ldif](../zone-d-dmz/ldap-bootstrap/users.ldif)).
- **Volumes persistants** pour toutes les données critiques (InfluxDB, LDAP, Mosquitto, Grafana).

---

## 🗂️ Fichiers de configuration clés

- **docker-compose.yml** : Orchestration des services et réseaux.
- **mosquitto.conf** : Configuration du broker MQTT ([voir mosquitto.conf](../zone-d-dmz/mosquitto/mosquitto.conf)).
- **acl.conf** : Règles d'accès MQTT ([voir acl.conf](../zone-d-dmz/mosquitto/acl.conf)).
- **ldap.toml** : Configuration LDAP pour Grafana ([voir ldap.toml](../zone-d-dmz/grafana_config/ldap.toml)).
- **users.ldif** : Utilisateurs LDAP ([voir users.ldif](../zone-d-dmz/ldap-bootstrap/users.ldif)).
- **dashboard-config** : Exemple de dashboard Grafana ([voir dashboard-config](../zone-d-dmz/grafana/dashboard-config)).

---

## 🚦 Procédure de test

1. **Démarrer la zone**
   ```bash
   docker compose up -d
   ```
2. **Vérifier l'état des services**
   ```bash
   docker compose ps
   ```
3. **Tester l'accès MQTT (avec certificat)**
   - Utiliser un client MQTT avec les certificats du dossier `certificates/certs`.
   - Vérifier que seuls les utilisateurs autorisés (voir ACL) peuvent publier/s'abonner.
4. **Tester l'accès Grafana**
   - Accéder à [http://10.0.0.30:3000](http://10.0.0.30:3000)
   - Se connecter avec un utilisateur LDAP (ex: pedro/pedroldap)
5. **Tester l'accès InfluxDB**
   - Accéder à [http://10.0.0.40:8086](http://10.0.0.40:8086)
   - Utiliser les identifiants admin/adminpass123
6. **Vérifier les logs**
   ```bash
   docker compose logs grafana
   docker compose logs broker-mqtt
   docker compose logs influxdb
   docker compose logs ldap
   ```

---

## 🛠 Commandes Utiles
| Action | Commande |
| --- | --- |
| Démarrer la zone | `docker compose up -d` |
| Arrêter la zone | `docker compose down` |
| Voir les logs d'un service | `docker compose logs <service>` |
| Inspecter un conteneur | `docker exec -it <service> sh` |
| Vérifier les volumes | `docker volume ls` |

---

## 📝 Notes
> ℹ️ **Astuce :** Pour tester l'authentification LDAP, modifiez/ajoutez des utilisateurs dans le fichier [users.ldif](../zone-d-dmz/ldap-bootstrap/users.ldif) puis redémarrez le service LDAP.

> ⚠️ **Sécurité :** En production, activez SSL/TLS pour LDAP (port 636) et Grafana, et changez tous les mots de passe par défaut.

---

## 📚 Références
- [Documentation Mosquitto](https://mosquitto.org/documentation/)
- [Documentation InfluxDB](https://docs.influxdata.com/influxdb/)
- [Documentation Grafana](https://grafana.com/docs/)
- [Documentation OpenLDAP](https://www.openldap.org/doc/)

---

## 📊 Scripts Grafana (Flux/InfluxQL)

Cet espace est dédié à la documentation et au partage des scripts utilisés dans les dashboards Grafana pour l'analyse des logs et métriques de la zone DMZ.

### Exemple de script Flux pour l'analyse des logs du firewall

```flux
from(bucket: "firewall-logs")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "firewall_logs")
  |> filter(fn: (r) => r["_field"] == "dport" or r["_field"] == "src" or r["_field"] == "dst")
  |> pivot(rowKey:["_time"], columnKey: ["_field"], valueColumn: "_value")
  |> keep(columns: ["_time", "action", "src", "dst", "dport", "zone_src", "zone_dst", "proto"])
  |> sort(columns: ["_time"], desc: true)
```

> Ajoutez ici d'autres scripts utiles pour Grafana (requêtes Flux, InfluxQL, SQL, etc.) afin de faciliter la supervision et l'audit de la zone D.
