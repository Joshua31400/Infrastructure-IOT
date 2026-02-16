# Glossaire

Ce glossaire définit les termes techniques utilisés dans la documentation de l'infrastructure IoT industrielle.

---

## A

### ACL (Access Control List)
Liste de contrôle d'accès. Ensemble de règles définissant qui peut accéder à quelles ressources. Dans ce projet, les ACL MQTT définissent quels certificats peuvent publier ou s'abonner à quels topics.

### Alpine Linux
Distribution Linux légère optimisée pour les conteneurs Docker. Taille de base d'environ 5 Mo, utilisée pour tous les conteneurs de l'infrastructure.

---

## B

### Broker MQTT
Serveur central qui reçoit les messages des publishers (éditeurs) et les redistribue aux subscribers (abonnés). Dans ce projet, Eclipse Mosquitto assure ce rôle.

### Bucket (InfluxDB)
Conteneur logique pour stocker des données time-series dans InfluxDB. Le bucket `firewall-logs` stocke les journaux du pare-feu.

---

## C

### CA (Certificate Authority)
Autorité de certification. Entité qui émet et signe les certificats numériques. Le fichier `ca.crt` représente la CA interne du projet.

### Capability (Docker)
Permission Linux spécifique accordée à un conteneur. `NET_ADMIN` permet de manipuler la configuration réseau (routes, iptables).

### CN (Common Name)
Champ du certificat X.509 identifiant le propriétaire. Utilisé comme nom d'utilisateur pour l'authentification MQTT.

---

## D

### DH (Diffie-Hellman)
Protocole d'échange de clés permettant à deux parties de créer un secret partagé sur un canal non sécurisé. Le fichier `dh2048.pem` contient les paramètres DH pour OpenVPN.

### DMZ (Zone Démilitarisée)
Segment réseau intermédiaire entre un réseau interne protégé et un réseau externe non fiable. Héberge les services accessibles depuis plusieurs zones.

### Docker Compose
Outil permettant de définir et exécuter des applications multi-conteneurs via un fichier YAML (`docker-compose.yml`).

---

## F

### Firewall (Pare-feu)
Système de sécurité réseau qui surveille et contrôle le trafic entrant et sortant selon des règles prédéfinies.

### Flux
Dans le contexte de Grafana/InfluxDB, langage de requête pour interroger les données time-series.

---

## G

### Gateway (Passerelle)
Point de passage obligé entre deux réseaux. Dans ce projet, l'adresse `.254` de chaque zone correspond au pare-feu.

### Grafana
Plateforme open-source de visualisation et d'analyse de données. Permet de créer des tableaux de bord interactifs.

---

## I

### IIoT (Industrial Internet of Things)
Internet des objets industriel. Application des technologies IoT dans les contextes de production industrielle.

### InfluxDB
Base de données time-series optimisée pour le stockage et l'interrogation de données horodatées (métriques, logs, événements).

### iptables
Outil Linux de filtrage de paquets et de NAT. Permet de configurer les règles du pare-feu Netfilter.

---

## L

### LDAP (Lightweight Directory Access Protocol)
Protocole d'accès aux annuaires. OpenLDAP implémente ce protocole pour la gestion centralisée des identités.

### LDAPS
LDAP sécurisé via TLS sur le port 636.

### LDIF (LDAP Data Interchange Format)
Format texte standard pour représenter les entrées d'annuaire LDAP.

---

## M

### Masquerading
Type de NAT où l'adresse IP source des paquets sortants est remplacée par l'adresse de l'interface de sortie. Permet aux réseaux internes d'accéder à Internet.

### MQTT (Message Queuing Telemetry Transport)
Protocole de messagerie léger conçu pour les connexions à faible bande passante et les appareils à ressources limitées.

### MQTTS
MQTT sécurisé par TLS. Utilise le port 8883 par convention.

### mTLS (Mutual TLS)
TLS avec authentification mutuelle. Le client et le serveur présentent chacun un certificat pour s'authentifier.

---

## N

### NAT (Network Address Translation)
Traduction d'adresses réseau. Technique permettant de modifier les adresses IP dans les en-têtes de paquets lors de leur passage par un routeur.

---

## O

### OpenLDAP
Implémentation open-source du protocole LDAP.

### OpenSSL
Bibliothèque cryptographique open-source utilisée pour la génération de certificats et le chiffrement TLS.

### OpenVPN
Solution VPN open-source permettant de créer des tunnels sécurisés point-à-point ou site-à-site.

---

## P

### PKI (Public Key Infrastructure)
Infrastructure à clé publique. Ensemble des composants nécessaires à la gestion des certificats numériques (CA, certificats, révocation).

### Privileged (Docker)
Mode d'exécution accordant à un conteneur tous les privilèges de l'hôte. Nécessaire pour manipuler iptables mais à éviter en production.

---

## S

### SAN (Subject Alternative Name)
Extension X.509 permettant de spécifier des noms alternatifs (DNS, IP) dans un certificat.

### Subnet (Sous-réseau)
Division logique d'un réseau IP. Chaque zone possède son propre sous-réseau (ex: `192.168.10.0/24`).

---

## T

### TLS (Transport Layer Security)
Protocole cryptographique assurant la confidentialité et l'intégrité des communications réseau.

### TLS-Auth
Fonctionnalité OpenVPN ajoutant une couche d'authentification HMAC avant l'établissement de la session TLS.

### Topic (MQTT)
Canal de communication hiérarchique dans MQTT. Les messages sont publiés sur des topics (ex: `iot/temperature`).

### tcpdump
Outil en ligne de commande pour capturer et analyser le trafic réseau.

---

## V

### VLAN (Virtual Local Area Network)
Réseau local virtuel. Technique de segmentation logique d'un réseau physique. Simulé par les réseaux Docker dans ce projet.

### VPN (Virtual Private Network)
Réseau privé virtuel. Tunnel chiffré permettant de connecter des réseaux ou des utilisateurs distants de manière sécurisée.

### Volume (Docker)
Mécanisme de persistance des données pour les conteneurs Docker.

---

## Z

### Zero Trust
Modèle de sécurité basé sur le principe "ne jamais faire confiance, toujours vérifier". Chaque accès doit être authentifié et autorisé explicitement.

---

## Références

- [RFC 5246 - TLS 1.2](https://tools.ietf.org/html/rfc5246)
- [RFC 4511 - LDAP](https://tools.ietf.org/html/rfc4511)
- [MQTT Version 5.0 Specification](https://docs.oasis-open.org/mqtt/mqtt/v5.0/mqtt-v5.0.html)
- [OpenVPN Manual](https://openvpn.net/community-resources/reference-manual-for-openvpn-2-4/)
- [Retour au README principal](../README.md)
