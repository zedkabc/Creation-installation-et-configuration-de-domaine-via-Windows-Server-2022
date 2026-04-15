L2 - Documentation GPO deployees (alignement ANSSI)
====================================================

Reference dossier : IRIS-NICE-2024-RP02
Objectif          : Standardiser la securite Windows via GPO sur le domaine AD

References de securite utilisees
--------------------------------
- ANSSI - Guide de securisation d'un annuaire Active Directory Microsoft
- ANSSI - Guide d'hygiene informatique
- Durcissement poste Windows en environnement domaine
- ANSSI DAT-NT-017 - Journalisation et supervision de securite

Nota : Les references ci-dessus servent de cadre. Les parametres appliques
respectent les exigences RP-02 imposant les valeurs numeriques ci-dessous.

Plan GPO
--------
1) GPO-DOMAIN-PASSWORD-LOCKOUT
   Portee : Domaine (racine)
   Cible  : Tous les comptes domaine

   Parametres principaux :
   - Minimum password length                : 12
   - Password must meet complexity          : Enabled
   - Maximum password age                   : 90 days
   - Minimum password age                   : 1 day
   - Enforce password history               : 12
   - Account lockout threshold              : 5 invalid attempts
   - Account lockout duration               : 30 minutes
   - Reset account lockout counter after    : 30 minutes

   Justification securite :
   - Renforcement de la robustesse des secrets.
   - Limitation des attaques par bruteforce.

2) GPO-USERS-STUDENTS-RESTRICTIONS
   Portee : OU=Utilisateurs\OU=SISR + OU=Utilisateurs\OU=SLAM
   Filtrage securite : GG_SISR_ETUDIANTS, GG_SLAM_ETUDIANTS

   Parametres principaux :
   - Hide/disable Control Panel and Settings              : Enabled
   - Prohibit access to administrative tools              : Enabled
   - Deny all access to removable storage classes         : Enabled
   - Prevent registry editing tools                       : Enabled
   - Block command prompt (option selon cours)            : Enabled

   Justification securite :
   - Reduction de la surface d'attaque.
   - Prevention des modifications non autorisees.

3) GPO-LOGON-SCRIPTS-AND-WALLPAPER
   Portee : OU=Utilisateurs
   Cible  : Utilisateurs domaine (filtrage par groupes dans le script)

   Parametres principaux :
   - Logon Script : Map-NetworkDrivesByGroup.ps1
   - Script path  : \\mediaschool.lan\NETLOGON\Map-NetworkDrivesByGroup.ps1
   - Config JSON  : \\mediaschool.lan\NETLOGON\DriveMappings.sample.json
   - Wallpaper    : \\SRV-FICHIERS\Branding\iris-wallpaper.jpg

   Justification securite :
   - Attribution des acces reseau selon groupe AD.
   - Standardisation experience utilisateur.

4) GPO-WINDOWS-FIREWALL-BASELINE
   Portee : OU=Ordinateurs
   Cible  : Parc Windows 10/11

   Parametres principaux :
   - Domain profile firewall state          : On
   - Private profile firewall state         : On
   - Public profile firewall state          : On
   - Inbound connections                    : Block (except allowed rules)
   - Outbound connections                   : Allow (default)
   - Local firewall rule merge              : Disabled (recommended)
   - Logging dropped packets                : Enabled

   Justification securite :
   - Protection standardisee des postes.
   - Tracabilite des evenements de filtrage.

5) GPO-AUDIT-ANSSI
   Portee : OU=Ordinateurs
   Cible  : Parc Windows 10/11

   Parametres principaux :
   - Advanced Audit Policy (Success + Failure) :
     * Logon (evt 4624, 4625)
     * Logoff (evt 4634)
     * User Account Management (evt 4720)
     * Special Logon (evt 4672)
   - Journal Security (Maximum log size)       : 512 MB minimum (524288 KB)
   - Retention journaux securite               : 1 an (archivage centralise)

   Justification securite :
   - Conformite aux exigences de tracabilite ANSSI.
   - Capacite d'investigation en cas d'incident.
   - Reference normative : DAT-NT-017.

Ordre de liaison recommande
---------------------------
1. GPO-DOMAIN-PASSWORD-LOCKOUT (domaine)
2. GPO-WINDOWS-FIREWALL-BASELINE (OU=Ordinateurs)
3. GPO-USERS-STUDENTS-RESTRICTIONS (OU etudiants)
4. GPO-LOGON-SCRIPTS-AND-WALLPAPER (OU=Utilisateurs)
5. GPO-AUDIT-ANSSI (OU=Ordinateurs)

Validation / recette GPO
------------------------
- gpupdate /force sur poste de test
- gpresult /h C:\Temp\gpresult.html
- Verification lockout policy via secpol.msc (poste) et GPMC (domaine)
- Verification restrictions etudiants (panneau conf, stockage USB)
- Verification logon script (lecteurs mappes par groupe)
- Verification firewall profiles actifs

Points d'exploitation
---------------------
- Toute exception doit passer par groupe dedie (pas de desactivation globale).
- Toute nouvelle GPO doit avoir une fiche : objet, cible, risque, rollback.
- Sauvegarde des GPO avant modification majeure (Backup-GPO).
