L4 - Scripts PowerShell commentes et idempotents
================================================

Contenu
-------
1) Import-ADUsersFromCsv.ps1
   - Import en masse des comptes depuis CSV
   - Controle des doublons dans le CSV
   - Creation/mise a jour idempotente
   - Ajout au groupe de securite cible
   - Rapport CSV de sortie

2) Disable-AndArchive-ADUsers.ps1
   - Desactivation et archivage des comptes en fin d'annee
   - Deplacement vers OU Archive
   - Tag PurgeAfter et date d'expiration pour retention RGPD
   - Mode purge pour suppression des comptes en fin de retention
   - Rapport CSV de sortie

3) Map-NetworkDrivesByGroup.ps1
   - Mappage dynamique des lecteurs reseau selon groupes AD
   - Fonctionnement idempotent
   - Option -Enforce pour demonter les lecteurs non autorises
   - Journal d'execution

4) DriveMappings.sample.json
   - Exemple de configuration des lecteurs reseau

5) ImportUsers.sample.csv
   - Exemple de CSV conforme RP-02

Prerequis
---------
- PowerShell 5.1
- Module ActiveDirectory (RSAT ou serveur AD)
- Droits d'administration AD pour scripts 1 et 2
- Acces aux partages reseau pour script 3

Exemples d'execution
--------------------
Import:
  .\Import-ADUsersFromCsv.ps1 `
    -CsvPath .\ImportUsers.sample.csv `
    -DefaultDomainSuffix "mediaschool.lan" `
    -DefaultOU "OU=SISR,OU=Utilisateurs,DC=mediaschool,DC=lan" `
    -DefaultGroup "GG_SISR_ETUDIANTS" `
    -DefaultPassword "Iris!2026"

Fin d'annee (archive depuis CSV):
  .\Disable-AndArchive-ADUsers.ps1 `
    -CsvPath .\ImportUsers.sample.csv `
    -ArchiveOU "OU=Archive,OU=Utilisateurs,DC=mediaschool,DC=lan" `
    -RetentionDays 365

Fin de retention (purge):
  .\Disable-AndArchive-ADUsers.ps1 `
    -ArchiveOU "OU=Archive,OU=Utilisateurs,DC=mediaschool,DC=lan" `
    -PurgeExpired

Mappage lecteurs:
  .\Map-NetworkDrivesByGroup.ps1 `
    -ConfigPath .\DriveMappings.sample.json `
    -Persistent `
    -Enforce

Notes exploitation
------------------
- Planifier la purge RGPD en tache planifiee mensuelle sur le serveur AD.
- Archiver les rapports (dossier reports) pour tracabilite.
- Tester les scripts avec -WhatIf avant mise en production.
