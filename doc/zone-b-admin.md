connection à l'interface d'administration  
``ssh root@localhost -p 2222``

---

tester la connexion à Grafana (bureautique a le droit aussi)  
``curl -v http://10.0.0.30:3000``

---

tester la connexion à InfluxDB (il est le seul a avoir le droit)  
``curl -v http://10.0.0.40:8086``

---

tester la connexion à IOT (interdit aussi pour lui)
``curl -v telnet://10.0.0.20:8883``

---

**PARTICULARITER** pour nous via notre machine on doit générer une clef SSH et la copier sur la machine distante
et elle doit être renouvelée si docker est recréé  
``ssh-keygen -R [localhost]:2222``