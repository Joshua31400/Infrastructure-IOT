# Audit de sécurité

**Projet :** Infrastructure-IOT  
**Branche examinée :** `security`  
**Date :** 12 novembre 2026  
**Type d'examen :** revue statique des configurations, scripts et documentation. Aucun fichier applicatif ou de configuration n'a été modifié dans le cadre de l'audit.

## Résumé exécutif

L'examen a relevé **deux problèmes de gravité élevée** et **un problème de gravité moyenne**. Les deux risques les plus importants sont l'exposition de la clé privée de l'autorité de certification aux conteneurs IoT et la publication de services sur toutes les interfaces de l'hôte, notamment SSH avec une connexion root par mot de passe par défaut. Ces défauts peuvent compromettre l'identité MQTT, l'accès d'administration et les frontières réseau attendues.

| # | Gravité | Fichiers et lignes | Constat | Confiance |
|---|---|---|---|---:|
| 1 | ÉLEVÉE | [`zone-a-iot/docker-compose.yml`](./zone-a-iot/docker-compose.yml) (35, 71, 107), [`certificates/generate-certs.ps1`](./certificates/generate-certs.ps1) (19, 57, 66), [`zone-d-dmz/mosquitto/mosquitto.conf`](./zone-d-dmz/mosquitto/mosquitto.conf) (8, 13-14), [`zone-d-dmz/mosquitto/acl.conf`](./zone-d-dmz/mosquitto/acl.conf) (12-14) | Les conteneurs IoT peuvent lire la clé privée de la CA et potentiellement forger un certificat MQTT `admin` autorisé sur tous les topics. | 10/10 |
| 2 | ÉLEVÉE | [`zone-d-dmz/docker-compose.yml`](./zone-d-dmz/docker-compose.yml) (11, 29, 51-52, 107-109), [`zone-b-admin/docker-compose.yml`](./zone-b-admin/docker-compose.yml) (17-20, 30-31), [`README.md`](./README.md) (105-110) | Les ports publiés sont exposés sur toutes les interfaces de l'hôte par défaut. Le port SSH 2222 permet l'accès root avec un mot de passe par défaut documenté. | 9/10 |
| 3 | MOYENNE | [`zone-d-dmz/docker-compose.yml`](./zone-d-dmz/docker-compose.yml) (51-63, 107-115), [`zone-d-dmz/grafana_config/ldap.toml`](./zone-d-dmz/grafana_config/ldap.toml) (14) | Grafana est configuré en HTTP et LDAP non chiffré est publié, ce qui expose les identifiants et sessions à l'interception réseau. | 9/10 |

## Détails des constats

### 1. Clé privée de la CA accessible aux conteneurs IoT — ÉLEVÉE

**Impact :** un attaquant qui compromet un capteur peut lire `ca.key`, émettre un certificat client portant l'identité `admin`, puis s'authentifier auprès du broker MQTT. La configuration Mosquitto mappe le nom commun du certificat à l'utilisateur et l'ACL accorde à `admin` les droits de lecture et d'écriture sur `#`. Une compromission d'un seul capteur peut donc permettre l'usurpation d'identité et l'accès à tous les topics MQTT.

**Éléments concernés :**

- Les services IoT montent le répertoire complet de certificats en lecture seule. La lecture reste possible même si l'écriture est interdite.
- Le script de génération place la clé privée de l'autorité de certification dans ce répertoire.
- Mosquitto fait confiance au certificat CA correspondant et utilise l'identité du certificat pour l'autorisation.

**Mesures recommandées :**

1. Conserver la clé privée de la CA hors des conteneurs et ne pas la distribuer aux clients.
2. Monter dans chaque conteneur uniquement son certificat client et sa clé privée dédiés, avec les permissions minimales.
3. Émettre des identités distinctes pour les équipements et limiter les ACL MQTT par client ou par topic.
4. Révoquer et renouveler les certificats qui auraient pu être exposés, puis vérifier les artefacts déjà générés et distribués.

### 2. Services publiés sur l'hôte et SSH root avec mot de passe par défaut — ÉLEVÉE

**Impact :** les mappings de ports Docker sans adresse hôte explicite sont généralement publiés sur toutes les interfaces. Ils peuvent ainsi rendre les services accessibles depuis les réseaux joignables par l'hôte et contourner le chemin de filtrage inter-zones décrit par l'architecture. Le port SSH `2222` est particulièrement sensible : le conteneur autorise la connexion root par mot de passe et le mot de passe par défaut est documenté. Une personne pouvant atteindre ce port peut obtenir l'accès root au conteneur d'administration.

**Éléments concernés :**

- Les fichiers Compose publient notamment SSH (`2222:22`), Grafana (`3000:3000`), InfluxDB (`8086:8086`) ainsi que des ports LDAP/MQTT, sans liaison explicite à `127.0.0.1`.
- Le conteneur d'administration active la connexion SSH root avec mot de passe.
- Le README documente des identifiants par défaut et la commande de connexion SSH.

**Mesures recommandées :**

1. Pour un environnement local, lier les ports nécessaires à `127.0.0.1`; sinon, supprimer les publications inutiles et n'exposer que les services derrière une entrée contrôlée.
2. Désactiver la connexion SSH directe de `root` et l'authentification par mot de passe; privilégier des clés SSH et un compte nominatif à privilèges limités.
3. Supprimer les mots de passe par défaut du dépôt, injecter les secrets par un mécanisme approprié et les renouveler avant tout déploiement.
4. Vérifier les règles du pare-feu de l'hôte et les ports réellement accessibles après déploiement, car les publications Docker peuvent interagir avec les règles de filtrage.

### 3. Chiffrement TLS absent sur Grafana et LDAP en clair — MOYENNE

**Impact :** Grafana est publié en HTTP, et le port LDAP 389 non chiffré est exposé en plus de LDAPS. Un observateur du réseau peut intercepter les identifiants, les sessions Grafana ou des échanges LDAP non chiffrés. Le fichier LDAP contient également un mot de passe de compte de liaison, ce qui aggrave l'impact si ce secret est divulgué.

**Mesures recommandées :**

1. Servir Grafana uniquement en HTTPS, avec certificats correctement validés, et rediriger ou désactiver HTTP.
2. Désactiver les binds LDAP en clair ou restreindre le port 389 aux cas explicitement nécessaires; imposer LDAPS ou StartTLS et vérifier les certificats serveur.
3. Déplacer le mot de passe de liaison LDAP hors de la configuration versionnée et le renouveler s'il s'agit d'un secret réel ou réutilisé.
4. Restreindre l'accès réseau à ces services au strict nécessaire.

## Périmètre et limites

La revue statique a porté sur les fichiers Compose des zones, les règles de pare-feu et leur journalisation, les scripts de déploiement et de génération de certificats, ainsi que les configurations OpenVPN, Mosquitto, LDAP, Grafana et InfluxDB et la documentation associée. Elle a notamment examiné les montages de clés privées, l'authentification et l'autorisation, les ports publiés et la cohérence des frontières réseau documentées.

Aucun déploiement, test d'intrusion, balayage réseau, examen des images Docker en exécution ni analyse automatisée des dépendances n'a été effectué. Les constats décrivent les risques visibles dans les configurations et doivent être validés dans l'environnement cible avant toute mise en production. Le dépôt semble destiné à une simulation pédagogique, mais ses secrets et paramètres par défaut ne doivent pas être réutilisés dans un environnement réel.
