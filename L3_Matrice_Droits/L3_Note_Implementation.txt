L3 - Note d'implementation matrice des droits
=============================================

Principes
---------
- Les droits sont attribues via groupes AD, jamais en direct sur des utilisateurs.
- Les droits SMB restent simples (Read / Change / Full).
- Le controle fin est porte par NTFS.
- Le principe du moindre privilege est applique.

Rappels home directories
------------------------
- Creation d'un dossier par utilisateur au format D:\Shares\Homes\%USERNAME%.
- ACL NTFS type :
  * SYSTEM : Full
  * Domain Admins : Full
  * Utilisateur proprietaire : Modify
- ACL heritees desactivees sur chaque dossier utilisateur.

Verification recette
--------------------
- Utilisateur SISR :
  * acces lecture/ecriture sur SISR-Commun
  * refus sur SLAM-Commun et Administration
- Utilisateur SLAM :
  * acces lecture/ecriture sur SLAM-Commun
  * refus sur SISR-Commun et Administration
- Enseignant :
  * lecture seule SISR-Commun + SLAM-Commun
  * acces ecriture sur Pedagogie
- Administration :
  * acces ecriture sur Administration
  * pas d'acces metier sur partages etudiants
