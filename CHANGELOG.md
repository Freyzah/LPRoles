# Versions de LPRoles

La section d'une version est reprise telle quelle sur sa page GitHub.

## 0.9.0

- Le mod **se met à jour tout seul** à chaque lancement du jeu : il télécharge la dernière version publiée ici, la vérifie et l'installe avant de se charger. Réglages, journal et sons personnels sont gardés.
- `mettre-a-jour.bat`, dans le dossier du mod, fait la même chose à la main (jeu fermé) et remet en état une installation abîmée.
- Nouveau réglage dans MES RÉGLAGES : « Mise à jour automatique au lancement » (OUI par défaut).
- Aucun changement dans le jeu lui-même par rapport à la 0.8.15.
- **Dernière installation à la main :** les versions précédentes n'ont pas ce mécanisme.

## Avant le dépôt GitHub

État des versions tel qu'il était tenu dans `docs/LISEZ-MOI-LPRoles.md` ; le détail de chaque choix est dans `docs/decisions-mod.md`.

- **0.1.0** : testée en solo par l'hôte (chargement, rêve, recharge, envol, carte du Shérif).
- **0.2.1** et **0.2.2** : plantaient le jeu au chargement, en construisant l'onglet LPROLES.
- **0.2.3** : testée en jeu le 3 octobre 2026. Tout fonctionne d'après l'utilisateur, onglet LPROLES compris.
- **0.3.0** : ajoute neuf rôles et renomme l'Infecteur en Recruteur. Pas encore lancée en jeu.
- **0.3.1** : ajoute la touche « consommer l'objet en main ». Testée en jeu par l'utilisateur : elle fonctionne.
- **0.3.2** : le Rêveur et la Fée ne voient plus leurs mains ni l'objet tenu pendant qu'ils sont fantômes.
- **0.3.3** : l'onglet LPROLES est placé juste après « Règles » dans la colonne des onglets. Pas encore lancée en jeu.
- **0.3.4** : après consommation, le bocal devient sale (à nettoyer dans la machine prévue), au lieu de redevenir propre. Pas encore lancée en jeu.
- **0.4.0** : nouveau rôle Métamorphe, et page du rôle sur la tablette. La page ne s'affichait pas.
- **0.4.1** : la page trouve la tablette par la tablette en main. Testée en jeu : elle fonctionne.
- **0.4.2** : l'onglet LPROLES et la page de la tablette montrent où en est le rôle (utilisations, effet en cours, temps restant, cible) et comment l'utiliser, avec les valeurs réglées par l'hôte. Testée en jeu : les textes s'affichent.
- **0.4.3** : page de la tablette mise en forme. Testée : couleurs déformées par l'écran de la tablette.
- **0.5.0** : page de la tablette refaite avec les « encres » de l'écran, son de consommation personnalisé, rôles Nettoyeur et Clandestin. Testée : page de la tablette nette, test des couleurs fait.
- **0.5.1** : noms de plantes dans la couleur de la plante sur la tablette ; test des couleurs retiré. Testée à deux : le jeu plantait à la fin de la session (défaut présent depuis la 0.5.0).
- **0.5.2** : correction de ce plantage. Pas encore lancée en jeu.
- **0.5.3** : le son de consommation n'est plus coupé à la fin ; les mises à jour ne touchent plus au dossier `sounds`. Testée : le son se joue en entier. À deux joueurs, le second n'a reçu aucun rôle (réglages « Joueurs minimum » à 4 ou plus).
- **0.5.4** : l'hôte est prévenu quand des rôles activés ne sont pas attribués faute de joueurs ; réglage de test « Ignorer les joueurs minimum » ; journal du mod conservé d'un lancement à l'autre. Pas encore lancée en jeu.
- **0.6.0** : corrige ces cinq défauts ; les Liés deviennent un lien qui s'ajoute aux rôles ; le rappel « détails » disparaît de l'annonce des rôles. Testée à deux : chez la joueuse invitée, plus d'onglet, de bandeau ni de page de tablette après avoir rejoint la partie.
- **0.6.1** : l'horloge du mod tourne dans le fil du jeu et se relance si elle s'arrête ; la sécurité anti-plantage ne coupe plus l'onglet ni la page pour de bon ; F10 remet tout en route ; le mod signale une installation incomplète. Pas encore lancée en jeu.
- **0.7.0** : chaque rôle à utilisations limitées a un objet de recharge, plante ou poisson. Retour de l'utilisateur : le Médium garde les yeux fermés quand sa vision commence.
- **0.7.1** : les yeux se rouvrent tout seuls dès qu'un pouvoir est lancé en fermant les deux yeux (Rêveur, Médium, Clandestin, Revenant, recharge par les yeux). Testée à deux : Métamorphe et recharge par un poisson fonctionnent. Retour de l'utilisateur : des descriptions de la tablette semblent boguées ou incomplètes.
- **0.7.2** : toutes les descriptions relues et corrigées ; la tablette ne garde plus de lignes de la page précédente. Pas encore lancée en jeu.
- **0.7.3** : les descriptions ne parlent plus des joueurs sans le mod (tous l'auront). Pas encore lancée en jeu.
- **0.7.4** : pendant l'envol de la Fée, les autres voient une boule violette à la place de son corps. Testée à deux : la boule apparaît, mais le corps reste visible.
- **0.7.5** : le corps de la Fée est réellement caché pendant l'envol ; boule de 25 cm ; envol de 5 s. Le journal note comment chaque réglage est changé ; un lien est révélé en une ligne à la fin. Testée à deux : tout fonctionne.
- **0.7.6** : le Métamorphe garde sa propre couleur dans la liste des joueurs pendant le déguisement. Jouée à cinq le 6 octobre ; ce correctif n'est pas confirmé (le journal de l'hôte dit n'avoir pas trouvé sa propre ligne). Un blocage du jeu au lancement d'une partie, cause non établie (D72).
- **0.8.0** : une touche lance tous les pouvoirs (les yeux fermés ne servent plus qu'au Rêveur) ; le Métamorphe peut prendre l'apparence d'un cadavre ; le Shérif n'a plus de carte dans son sac, une carte d'accès posée dans le bâtiment lui est montrée en surbrillance. Installée avec la 0.8.3 ; pas encore lancée en jeu.
- **0.8.1** : le protégé de l'Ange gardien se relève même s'il était le dernier employé en vie, sans que la partie se termine. Installée avec la 0.8.3 ; pas encore lancée en jeu.
- **0.8.2** : le lien des Liés ne joue plus qu'une fois : un lié relevé (par un Ange gardien, par exemple) n'est pas retué si l'autre meurt de nouveau. Installée avec la 0.8.3 ; pas encore lancée en jeu.
- **0.8.3** : l'apparition du Revenant dure 20 s par défaut (réglable jusqu'à 60 s) ; il retrouve ses apparitions à chaque mort, donc un Revenant réanimé qui meurt de nouveau peut se manifester encore. Installée avec la 0.8.3 ; pas encore lancée en jeu.
- **0.8.4** : son de l'envol de la Fée (le son fait par une amie de l'utilisateur), entendu par la Fée elle-même, coupé en fondu à la durée exacte de l'envol. Lancée seul par l'utilisateur le 7 octobre : la touche de pouvoir lance bien l'envol, et la copie du son à la durée de l'envol est écrite.
- **0.8.5** : les joueurs proches d'une Fée entendent aussi son envol, là où elle se trouve, de moins en moins fort avec la distance. Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.6** : Traqueur, Hypnotiseur, Métamorphe et Échangeur agissent dès l'appui sur la touche, sans cible à garder en vue ; seul l'Ange gardien garde sa confirmation. Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.7** : deux sons courts faits par un ami de l'utilisateur répondent à chaque tentative d'utiliser un pouvoir : un quand il démarre (deux variantes au choix), un quand il échoue. Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.8** : un seul son de démarrage (la variante longue), joué aussi au départ de la Fée ; le son de son envol arrive en fondu. Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.9** : l'Échangeur a son propre son, à la place du son de démarrage : entendu par lui, par le joueur échangé, et autour des deux par les joueurs proches. Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.10** : nouveau son de l'échange (une meilleure version, de la même autrice). Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.11** : les pouvoirs à cible atteignent enfin la portée réglée (ils étaient tous plafonnés à environ 6 m, quel que soit le réglage). Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.12** : son de l'échange remplacé une nouvelle fois (troisième version de la même autrice). Installée le 7 octobre ; pas encore lancée en jeu.
- **0.8.13** : les cinq sons du mod sont mis au même niveau d'écoute (ils différaient de 14 dB), et chaque joueur a un réglage « Volume des sons du mod ». Essayée par l'utilisateur : les sons suivent le curseur de volume du jeu, le réglage du mod fonctionne, les niveaux conviennent.
- **0.8.14** : son de l'envol de la Fée baissé de 3 dB, à la demande de l'utilisateur. Installée le 7 octobre.
- **0.8.15** : les deux boutons latéraux de la souris (SOURIS 4, SOURIS 5) s'ajoutent aux touches proposées pour « activer le pouvoir » et « consommer l'objet en main ». Essayée par l'utilisateur : les boutons fonctionnent.
