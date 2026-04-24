L1 - Schema arborescence Active Directory
=========================================

Reference dossier : IRIS-NICE-2024-RP02
Objet             : Centralisation de l'authentification (RP-02)

Hypotheses techniques
---------------------
- Domaine AD : mediaschool.lan
- NetBIOS    : MEDIASCHOOL
- Controleur : SRV-DC01 (Windows Server 2022)
- IP DC      : 192.168.40.5 (VLAN 40)

Arborescence OU cible
---------------------
DC=mediaschool,DC=lan
|
+-- OU=Utilisateurs
|   |
|   +-- OU=SISR
|   +-- OU=SLAM
|   +-- OU=Enseignants
|   +-- OU=Administration
|   +-- OU=Archive
|
+-- OU=Ordinateurs
|   |
|   +-- OU=SISR
|   +-- OU=SLAM
|   +-- OU=Enseignants
|   +-- OU=Administration
|   +-- OU=Campus
|
+-- OU=Groupes de securite
    |
    +-- OU=Promotions
    |   +-- GG_SISR_ETUDIANTS
    |   +-- GG_SLAM_ETUDIANTS
    |
    +-- OU=Roles
    |   +-- GG_ENSEIGNANTS
    |   +-- GG_ADMINISTRATION
    |
    +-- OU=Acces_Fichiers
    |   +-- GG_SHARE_SISR_RW
    |   +-- GG_SHARE_SLAM_RW
    |   +-- GG_SHARE_SISR_RO_ENSEIGNANTS
    |   +-- GG_SHARE_SLAM_RO_ENSEIGNANTS
    |
    +-- OU=Acces_Wifi_8021X
        +-- GG_WIFI_SISR
        +-- GG_WIFI_SLAM
        +-- GG_WIFI_ENSEIGNANTS
        +-- GG_WIFI_ADMINISTRATION

Comptes types
-------------
- Etudiants SISR : OU=Utilisateurs\OU=SISR
- Etudiants SLAM : OU=Utilisateurs\OU=SLAM
- Enseignants    : OU=Utilisateurs\OU=Enseignants
- Administration : OU=Utilisateurs\OU=Administration
- Comptes archives fin d'annee : OU=Utilisateurs\OU=Archive

Conventions de nommage
----------------------
- Utilisateur : prenom.nom (SamAccountName <= 20 caracteres)
- Ordinateur  : PC-[SISR|SLAM|ENS|ADM]-NN
- Groupe      : GG_<PERIMETRE>_<DROIT>
- GPO         : GPO-<ZONE>-<OBJET>-<VERSION>

Principes d'administration
--------------------------
- Separation stricte utilisateurs / ordinateurs / groupes.
- Attribution des droits via groupes AD (pas de droits directs sur comptes users).
- Gestion des partages selon AGDLP :
  Accounts -> Global Groups -> Domain Local Groups -> Permissions.
