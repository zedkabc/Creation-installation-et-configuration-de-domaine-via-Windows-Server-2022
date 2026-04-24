L5 - Documentation configuration NPS / RADIUS 802.1X
=====================================================

Reference dossier : IRIS-NICE-2024-RP02
Objectif          : Authentification Wi-Fi nominative via AD (suppression PSK partagee)

1) Architecture cible
---------------------
- Domaine AD   : mediaschool.lan
- AD DS / DNS  : SRV-DC01 (Windows Server 2022) - 192.168.40.5 (VLAN 40)
- NPS          : SRV-NPS01 (ou SRV-DC01 en maquette)
- Wi-Fi        : Controleur / bornes (perimetre RP-01)
- Clients      : Postes Windows 10/11 joints au domaine

Flux logique :
Client 802.1X -> Borne/controleur Wi-Fi -> RADIUS (NPS) -> Active Directory

2) Prerequis
------------
- Connectivite IP entre AP/controleur et serveur NPS (UDP 1812/1813).
- Horloge synchronisee (NTP) sur tous les equipements.
- Groupes AD existants :
  * GG_WIFI_SISR
  * GG_WIFI_SLAM
  * GG_WIFI_ENSEIGNANTS
  * GG_WIFI_ADMINISTRATION
- SSID cibles cote RP-01 :
  * IRIS-SIO
  * IRIS-PROF
  * IRIS-ADMIN
- Certificat serveur pour NPS (PEAP), emis par une autorite existante.
  Nota: RP-02 exclut le deploiement d'une PKI interne.

3) Installation et enregistrement NPS
-------------------------------------
1. Installer le role NPS :
   Install-WindowsFeature NPAS -IncludeManagementTools
2. Ouvrir la console "Network Policy Server".
3. Enregistrer NPS dans AD :
   NPS (local) -> clic droit -> Register server in Active Directory.

4) Declaration des clients RADIUS
---------------------------------
Pour chaque controleur / borne Wi-Fi :
- Friendly name : AP-01 / WLC-01
- Address (IP)  : IP de management
- Shared secret : secret fort unique, stocke dans coffre de secrets
- Vendor        : RADIUS Standard

5) Strategies NPS
-----------------
5.1 Connection Request Policy (CRP)
- Condition : NAS Port Type = Wireless - IEEE 802.11
- Action    : Authenticate requests on this server

5.2 Network Policies (NP)
Creer 3 policies alignees sur les SSID RP-01 :

NP-WIFI-IRIS-SIO-ETUDIANTS
- Conditions :
  * Windows Groups = GG_WIFI_SISR OR GG_WIFI_SLAM
  * NAS Port Type = Wireless - IEEE 802.11
  * SSID/NAS Identifier = IRIS-SIO (selon capacites controleur)
- Constraints :
  * Authentication Methods = Microsoft: Protected EAP (PEAP)
  * EAP Type = Secured password (EAP-MSCHAP v2)
- Settings :
  * Access Permission = Grant access
  * VLAN = 30

NP-WIFI-IRIS-PROF
- Conditions :
  * Windows Groups = GG_WIFI_ENSEIGNANTS
  * SSID/NAS Identifier = IRIS-PROF
- Constraints :
  * PEAP + MSCHAPv2
- Settings :
  * Access Permission = Grant access
  * VLAN = 20

NP-WIFI-IRIS-ADMIN
- Conditions :
  * Windows Groups = GG_WIFI_ADMINISTRATION
  * SSID/NAS Identifier = IRIS-ADMIN
- Constraints :
  * PEAP + MSCHAPv2
- Settings :
  * Access Permission = Grant access
  * VLAN = 10

6) Attributs Tunnel RFC 2868 (obligatoires)
--------------------------------------------
Pour chaque policy NPS ci-dessus, configurer les attributs RADIUS standards :

- Tunnel-Type (64)               = VLAN (13)
- Tunnel-Medium-Type (65)        = 802 (6)
- Tunnel-Private-Group-ID (81)   = ID VLAN cible

Mapping RP-01 :
- GG_WIFI_SISR + GG_WIFI_SLAM       -> VLAN 30 -> SSID IRIS-SIO
- GG_WIFI_ENSEIGNANTS               -> VLAN 20 -> SSID IRIS-PROF
- GG_WIFI_ADMINISTRATION            -> VLAN 10 -> SSID IRIS-ADMIN

7) Parametrage poste client (GPO recommande)
--------------------------------------------
- Deployer les profils Wi-Fi entreprise via GPO :
  Computer Configuration -> Policies -> Windows Settings -> Security Settings
  -> Wireless Network (IEEE 802.11) Policies
- Profils SSID :
  * IRIS-SIO
  * IRIS-PROF
  * IRIS-ADMIN
- Security type : WPA2-Enterprise / WPA3-Enterprise (selon infra RP-01)
- EAP : PEAP (MSCHAPv2)
- Validation certificat serveur NPS activee

8) Journalisation et supervision
--------------------------------
- Activer logs NPS :
  Event Viewer -> Custom Views -> Server Roles -> Network Policy and Access Services
- Optionnel : logs texte SQL-compatible dans %SystemRoot%\System32\LogFiles
- Supervision minimale :
  * taux de rejet auth
  * utilisateurs refuses (mauvais groupe)
  * indisponibilite NPS

9) Tests de validation
----------------------
- Test 1 : utilisateur SISR membre GG_WIFI_SISR -> connexion OK sur IRIS-SIO
- Test 2 : utilisateur hors groupe -> refus attendu
- Test 3 : compte desactive AD -> refus attendu
- Test 4 : compte archive -> refus attendu
- Test 5 : verification attribution VLAN via attributs RFC2868
- Test 6 : validation finale AP physiques a realiser avec l'infrastructure RP-01

10) Exploitation courante
-------------------------
- Ajout/retrait d'acces Wi-Fi par simple gestion des groupes AD.
- Rotation periodique des shared secrets RADIUS.
- Revue trimestrielle des membres des groupes GG_WIFI_*.
- Sauvegarde NPS export:
  netsh nps export filename="C:\Backup\nps-config.xml" exportPSK=YES
