L6 - Procedure d'exploitation : creation d'un nouveau compte utilisateur
========================================================================

Objectif
--------
Creer un compte utilisateur domaine de facon standardisee, avec droits et ressources
associees (groupes, home directory, acces Wi-Fi), en moins de quelques minutes.

Acteurs
-------
- Responsable technique (administrateur AD)
- Equipe pedagogique (validation population SISR/SLAM/enseignant/admin)

Donnees minimales a collecter
-----------------------------
- NOM
- Prenom
- Population cible : SISR / SLAM / Enseignants / Administration
- Adresse e-mail institutionnelle
- Date de debut (et date de fin si compte temporaire)

Etape A - Methode automatisee (recommandee)
-------------------------------------------
1. Ajouter l'utilisateur dans le CSV standard (ImportUsers.sample.csv).
2. Lancer la commande :
   .\Import-ADUsersFromCsv.ps1 `
     -CsvPath .\ImportUsers.sample.csv `
     -DefaultDomainSuffix "mediaschool.lan" `
     -DefaultOU "OU=SISR,OU=Utilisateurs,DC=mediaschool,DC=lan" `
     -DefaultGroup "GG_SISR_ETUDIANTS" `
     -DefaultPassword "Iris!2026"
3. Lire le rapport genere (dossier reports).
4. Traiter les lignes en erreur, puis relancer.

Etape B - Methode manuelle (secours)
------------------------------------
1. Creer le compte dans ADUC:
   - OU correspondant au profil (SISR, SLAM, Enseignants, Administration).
   - Login : prenom.nom
   - Password initial conforme politique.
   - Cocher "User must change password at next logon".
2. Ajouter l'utilisateur au groupe metier principal :
   - SISR -> GG_SISR_ETUDIANTS
   - SLAM -> GG_SLAM_ETUDIANTS
   - Enseignant -> GG_ENSEIGNANTS
   - Administration -> GG_ADMINISTRATION
3. Ajouter au groupe Wi-Fi 802.1X correspondant (GG_WIFI_*).

Provisionnement ressources
--------------------------
1. Home directory :
   - Creer D:\Shares\Homes\%USERNAME%
   - ACL : utilisateur = Modify, admins/system = Full
2. Verifier mappage lecteur H: via logon script.
3. Verifier acces partage de promotion (SISR-Commun ou SLAM-Commun).

Verification de fin de creation
-------------------------------
- Connexion poste domaine : OK
- Changement du mot de passe initial : OK
- GPO appliquees au profil : OK
- Lecteurs reseau corrects : OK
- Authentification Wi-Fi 802.1X : OK

Tracabilite
-----------
- Conserver rapport script d'import.
- Journaliser ticket de creation (demandeur, date, admin executant).
