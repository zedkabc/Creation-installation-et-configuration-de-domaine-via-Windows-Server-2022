L8 - PV de recette RP-02
========================

Reference dossier : IRIS-NICE-2024-RP02
Projet            : Centralisation authentification / AD
Date recette      : 2026-03-13
Version livrables : v1.1-corrigee
Participants      : Equipe RP-02 (SISR) + referent technique maquette

Environnement de test
---------------------
- Domaine AD : mediaschool.lan
- Serveur AD : SRV-DC01 (192.168.40.5 - VLAN 40)
- Serveur NPS: SRV-NPS01 (maquette NPS sur SRV-DC01 possible)

Resultats des tests
-------------------

[T1] Jointure domaine et connexion utilisateur
- Preconditions : poste Windows 10/11 joint au domaine
- Etapes        : login avec compte etudiant/enseignant/admin
- Resultat att. : connexion reussie, profil charge
- Resultat reel : jointure et connexions valides sur les 3 profils testes.
- Statut        : [X] OK  [ ] KO
- Commentaires  : ouverture de session conforme, profil charge sans erreur.

[T2] Application GPO mot de passe / verrouillage
- Preconditions : GPO domaine appliquee
- Etapes        : verifier politique locale effective
- Resultat att. : min 12, complexite ON, max 90j, historique 12, min 1j, lockout 5/30
- Resultat reel : parametres constates conformes via GPMC + gpresult.
- Statut        : [X] OK  [ ] KO
- Commentaires  : lockout teste par saisies invalides, deblocage automatique observe.

[T3] Restrictions profil etudiant
- Preconditions : compte membre GG_SISR_ETUDIANTS ou GG_SLAM_ETUDIANTS
- Etapes        : tenter outils admin, panneau config, cle USB
- Resultat att. : restrictions appliquees
- Resultat reel : restrictions appliquees (panneau config bloque, outils admin bloques, USB restreint).
- Statut        : [X] OK  [ ] KO
- Commentaires  : comportement conforme sur comptes etudiants SISR et SLAM.

[T4] Mappage lecteurs reseau
- Preconditions : groupes AD correctement affectes
- Etapes        : ouvrir session utilisateur
- Resultat att. : lecteurs mappes selon groupe (H:, S: ou L:, etc.)
- Resultat reel : H: + lecteur promotion mappes correctement selon groupe AD.
- Statut        : [X] OK  [ ] KO
- Commentaires  : script idempotent confirme sur reconnexions successives.

[T5] Partages fichiers / matrice droits
- Preconditions : ACL SMB + NTFS appliquees
- Etapes        : tests croises SISR/SLAM/enseignants/administration
- Resultat att. : conformite a la matrice L3
- Resultat reel : droits conformes; acces refuses/autorises selon matrice L3.
- Statut        : [X] OK  [ ] KO
- Commentaires  : home directory prive valide pour chaque utilisateur test.

[T6] Script import CSV idempotent
- Preconditions : CSV test
- Etapes        : lancer import 2 fois
- Resultat att. : 1er passage cree/maj, 2e passage sans duplication
- Resultat reel : 1er passage = creations/mises a jour; 2e passage = unchanged majoritaire.
- Statut        : [X] OK  [ ] KO
- Commentaires  : rapport CSV genere et exploitable.

[T7] Script fin d'annee (archive)
- Preconditions : comptes test sortants
- Etapes        : lancer Disable-AndArchive-ADUsers.ps1
- Resultat att. : comptes desactives, deplaces Archive, tag purge date
- Resultat reel : comptes desactives, OU Archive OK, tag PurgeAfter et expiration positionnes.
- Statut        : [X] OK  [ ] KO
- Commentaires  : mode -PurgeExpired valide sur compte de test arrive a echeance.

[T8] Authentification Wi-Fi 802.1X via NPS
- Preconditions : policy NPS active, groupe Wi-Fi configure
- Etapes        : connexion sur IRIS-SIO / IRIS-PROF / IRIS-ADMIN avec compte AD
- Resultat att. : acces accepte pour comptes autorises, refuse sinon
- Resultat reel : valide en simulation NPS avec client virtuel (accept/reject selon groupe AD).
- Statut        : [X] OK  [ ] KO
- Commentaires  : validation finale sur AP physiques conditionnee a la mise en place RP-01.

Anomalies relevees
------------------
ID | Description | Gravite | Correction | Statut
---|-------------|---------|------------|-------
A1 | Validation T8 sur AP physiques non jouee en maquette | Mineure | Prevoir test sur infra RP-01 (SSID + VLAN) | Ouverte
A2 | Neant | N/A | N/A | Clos

Decision de recette
-------------------
[ ] Recette acceptee sans reserve
[X] Recette acceptee avec reserves
[ ] Recette refusee

Signatures
----------
Representant client (IRIS Nice) : ____________________  Date : ____________
Equipe projet RP-02             : ____________________  Date : 2026-03-13
