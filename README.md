# 🚀 Installation et Configuration d’un Domaine Windows Server 2022 (VM)

 ## 1) Compréhension du contexte et des enjeux

  Le contexte décrit une coexistence entre un environnement Microsoft 365 Éducation déjà opérationnel et une absence d’annuaire centralisé local.

  Les risques actuels identifiés sont clairs : hétérogénéité des comptes locaux, absence de GPO communes, droits d’accès non standardisés, comptes
  inactifs non traités, et charge d’administration non maîtrisée.

  L’enjeu principal est donc de mettre en place une infrastructure d’identité fiable, sécurisée, documentée et durable, permettant une exploitation
  autonome par l’établissement, avec une logique industrialisée pour les rentrées et les fins d’année scolaires.

  ## 2) Réalisation

  Contenu : Windows Server 2022 + AD DS + DNS intégré, avec gouvernance des accès, automatisation PowerShell
  idempotente, sécurité alignée ANSSI, intégration NPS/RADIUS 802.1X et documentation d’exploitation complète.

  Mon approche vise la robustesse opérationnelle : standardisation, traçabilité, rejouabilité des procédures et validation de recette sur des cas
  d’usage concrets du campus.

  ## 3) Réponse détaillée aux exigences obligatoires

  ### 3.1 AD DS + DNS intégré + structure OU

  Déploiement d'Active Directory Domain Services sur Windows Server 2022 avec promotion en contrôleur de domaine principal et configuration DNS
  complète.

  Le périmètre couvre : installation des rôles, création du domaine AD, zones DNS directe et inverse, validation des enregistrements SRV, tests de
  résolution interne et validation de jointure de postes Windows 10/11.

  Paramètres d’infrastructure retenus :

   - Domaine : mediaschool.lan
   - NetBIOS : MEDIASCHOOL
   - Contrôleur principal : SRV-DC01
   - IP du DC : 192.168.40.5 (VLAN 40)

  Mise en place l’arborescence OU demandée :

   - SISR (utilisateurs + ordinateurs SISR)
   - SLAM (utilisateurs + ordinateurs SLAM)
   - Enseignants
   - Administration
   - Ordinateurs
   - Groupes de sécurité

  Cette structuration est accompagnée d’une convention de nommage et de règles d’administration pour garantir la maintenabilité.

  ### 3.2 GPO conformes ANSSI

  Application des GPO alignées avec les recommandations ANSSI pour AD/Windows, avec documentation paramètre par paramètre et référence de
  conformité.

  Les règles minimales intégrées sont :

   - Politique mot de passe : longueur min 12, complexité activée, validité max 90 jours, historique 12, durée minimale 1 jour.
   - Verrouillage : seuil 5 tentatives échouées, verrouillage 30 minutes.
   - Restrictions étudiants : blocage outils d’administration, limitation panneau de configuration, restriction des périphériques de stockage amovibles.
   - Scripts de connexion : mappage lecteurs réseau selon groupes AD, fond d’écran institutionnel, configuration automatique du pare-feu Windows.

  Ajout de sécurité/audit :

   - GPO GPO-AUDIT-ANSSI sur OU=Ordinateurs
   - Événements : 4624, 4625, 4634, 4720, 4672
   - Journal Security : 512 Mo minimum
   - Rétention : 1 an
   - Référence ANSSI : DAT-NT-017

  ### 3.3 Scripts PowerShell idempotents et commentés

  Script 1 — Import CSV en masse :

   - Prend en entrée un CSV structuré (NOM, Prénom, OU cible, Groupe de sécurité, Adresse e-mail).
   - Contrôle des doublons.
   - Création/mise à jour idempotente.
   - Rapport d’exécution complet (créés, mis à jour, ignorés, erreurs).

  Script 2 — Fin d’année scolaire :

   - Désactivation des comptes ciblés.
   - Déplacement dans OU Archive.
   - Gestion de la rétention RGPD avec suppression programmée à échéance.

  Script 3 — Mappage lecteurs réseau :

   - Attribution dynamique selon appartenance aux groupes AD.
   - Idempotence (pas de remappage inutile).
   - Journalisation d’exécution.

  L’ensemble est livré avec exemples de fichiers d’entrée et procédures d’exécution.

  ### 3.4 Intégration NPS / RADIUS 802.1X

  Mise en place la chaîne d’authentification NPS ↔ AD pour le Wi-Fi 802.1X.

  Le périmètre couvre : installation NPS, enregistrement dans AD, création des stratégies réseau, autorisation par groupes AD, tests d’authentification
  nominative.

  Objectif opérationnel : suppression du mot de passe Wi-Fi partagé et passage à une authentification par compte individuel.

  Compléments intégrés :

   - SSID RP-01 : IRIS-SIO, IRIS-PROF, IRIS-ADMIN
   - Attributs Tunnel RFC 2868 :
    - Tunnel-Type (64) = VLAN (13)
    - Tunnel-Medium-Type (65) = 802 (6)
    - Tunnel-Private-Group-ID (81) = VLAN cible
   - Mapping groupes/VLAN :
    - GG_WIFI_SISR + GG_WIFI_SLAM → VLAN 30
    - GG_WIFI_ENSEIGNANTS → VLAN 20
    - GG_WIFI_ADMINISTRATION → VLAN 10

  ### 3.5 Partages de fichiers et matrice de droits

   - Dossiers personnels (home directories) : un dossier par utilisateur, accès utilisateur + administrateur uniquement, droits NTFS Modification.
   - Espaces de promotion : SISR-Commun et SLAM-Commun, Lecture/Écriture pour le groupe concerné, Lecture seule pour enseignants, refus pour autres
  populations.

  ### 3.6 Documentation technique complète

  Livrables :

   - L1 Schéma arborescence AD (OUs, groupes, comptes types).
   - L2 Documentation GPO (paramètres, périmètre, référence ANSSI).
   - L3 Matrice des droits d’accès (NTFS/SMB).
   - L4 Scripts PowerShell commentés et idempotents.
   - L5 Documentation NPS/RADIUS
    802.1X (incluant attributs RFC2868 et mapping VLAN/SSID).
   - L6 Procédure création d’un nouveau compte.
   - L7 Procédure de fin d’année (désactivation/archivage/purge RGPD).
   - L8 PV de recette (connexion domaine, GPO, lecteurs,
    802.1X).

  Lavenir Louka
  BTS SIO — Option SISR
  IRIS Nice — Mediaschool



