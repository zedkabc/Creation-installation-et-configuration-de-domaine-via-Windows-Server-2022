# 🚀 Procédure : Installation et Configuration d’un Domaine Windows Server 2022 (VM)

## 📌 Objectif
Déployer un domaine Active Directory sur **Windows Server 2022** installé dans une machine virtuelle, avec gestion des utilisateurs, groupes, ressources partagées et services réseau (DNS, DHCP).

---

## 🧩 Prérequis
- 💿 ISO **Windows Server 2022** 
- 🖥️ Une **VM** avec ressources minimales :  
  - CPU : 2 cœurs  
  - RAM : 4 Go (minimum recommandé)  
  - Disque : 50 Go  
- 🌐 Accès administrateur sur la VM  
- 📡 Configuration réseau fonctionnelle (IP statique, DNS interne)  
- 🔑 Mot de passe administrateur fort  
- 🖥️ Un poste client sous **Windows 10 vierge** pour tester la connexion au domaine  

---

## 🛠️ Ressources
- **Serveur** : Windows Server 2022 (VM)  
- **Client** : Windows 10 vierge  
- **Outils** : Gestionnaire de serveur, Active Directory, Services Windows  

---

## 🔑 Étapes principales

### 1. Configuration du serveur
- Renommer le serveur  
- Configurer une **adresse IP statique**  
- Définir le DNS préféré sur la même IP 

### 2. Installation des rôles
Via le **Gestionnaire de serveur** :
- Active Directory Domain Services (**AD DS**)  
- **DNS Server**  
- **DHCP Server**  
- Services de fichiers et stockage  

### 3. Configuration Active Directory
- Promouvoir le serveur en **contrôleur de domaine**  
- Créer une **nouvelle forêt** : `abc.lan`  
- Définir le mot de passe DSRM  
- Vérifier le nom **NetBIOS** (`ABC`)  
- Valider les chemins par défaut :  
  - Base AD DS → `C:\Windows\NTDS`  
  - SYSVOL → `C:\Windows\SYSVOL`  

### 4. Gestion des objets AD
- Créer des **Unités d’Organisation (UO)**  
- Ajouter des **utilisateurs et groupes**  
- Appliquer des **stratégies de sécurité et droits d’accès**  

### 5. Ressources partagées
- Créer un **dossier partagé** sur le serveur  
- Configurer les **permissions NTFS** et les droits de partage  

### 6. Service DHCP
- Définir une **plage d’adresses IP** (scope)  
- Configurer la passerelle et le DNS pour les clients  
- Activer et valider le service  


---

## ✅ Résultat attendu
- Domaine fonctionnel : `abc.lan`  
- Utilisateurs et groupes gérés via Active Directory  
- Ressources partagées accessibles selon droits  
- DHCP distribuant automatiquement les IP aux clients  

---

👨‍💻 Auteur : Louka Lavenir 
📅 Date : 25/04/2025  
🏫 Mediaschool Nice – BTS SIO SISR

