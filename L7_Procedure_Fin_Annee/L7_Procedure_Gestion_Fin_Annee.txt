L7 - Procedure d'exploitation : gestion de fin d'annee scolaire
================================================================

Objectif
--------
Traiter proprement les comptes sortants selon RGPD:
- desactivation immediate
- archivage en OU Archive
- suppression apres retention

Frequence
---------
- Campagne principale : fin d'annee scolaire
- Controle complementaire : mensuel pendant la retention

Entrees
-------
- CSV des comptes a sortir (SamAccountName ou UPN)
- OU Archive cible (ex: OU=Archive,OU=Utilisateurs,DC=mediaschool,DC=lan)
- Duree de retention RGPD (ex: 365 jours)

Etape 1 - Preparation
---------------------
1. Exporter la liste des comptes concernes depuis l'outil pedagogique.
2. Verifier la liste (comptes actifs uniquement, pas de comptes de service).
3. Sauvegarder la liste en CSV.

Etape 2 - Desactivation et archivage
------------------------------------
Commande :
.\Disable-AndArchive-ADUsers.ps1 `
  -CsvPath .\sortants.csv `
  -ArchiveOU "OU=Archive,OU=Utilisateurs,DC=mediaschool,DC=lan" `
  -RetentionDays 365

Effets attendus :
- Compte desactive
- Compte deplace dans OU Archive
- Date de purge calculee et taggee (PurgeAfter=YYYY-MM-DD)
- Date d'expiration de compte alignee sur retention
- Rapport CSV produit

Etape 3 - Verification post-operation
-------------------------------------
- Echantillon de comptes:
  * Enabled = False
  * DN dans OU Archive
  * Description contient PurgeAfter
  * AccountExpirationDate renseignee
- Verification de refus de connexion (domaine + Wi-Fi)

Etape 4 - Purge en fin de retention
-----------------------------------
Commande :
.\Disable-AndArchive-ADUsers.ps1 `
  -ArchiveOU "OU=Archive,OU=Utilisateurs,DC=mediaschool,DC=lan" `
  -PurgeExpired

Recommandation:
- Planifier cette commande en tache mensuelle.
- Conserver les rapports de purge pour preuve RGPD.

Plan de retour arriere (avant purge)
------------------------------------
Si un compte a ete archive par erreur:
1. Reactiver le compte (Enable-ADAccount).
2. Deplacer vers OU d'origine.
3. Retirer tag PurgeAfter.
4. Reassigner groupes metier/Wi-Fi.

Tracabilite et conformite
-------------------------
- Conserver rapports scripts + ticket de demande.
- Limiter les attributs personnels au strict necessaire.
- Appliquer la retention validee par la direction/RGPD.
