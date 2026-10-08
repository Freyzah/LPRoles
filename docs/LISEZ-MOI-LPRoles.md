# LPRoles — rôles supplémentaires pour LOCKDOWN Protocol

Version 0.10.0, installée le 8 octobre 2026. **Pas encore publiée** : la dernière version publiée sur GitHub (https://github.com/Freyzah/LPRoles) est la 0.9.0, c'est elle que vos amis reçoivent. Ce document décrit la 0.10.0.

À partir de la 0.9.0, le mod se met à jour tout seul au lancement du jeu (voir « Mise à jour automatique »). Vos amis installent la 0.9.0 une dernière fois à la main, avec l'archive complète `LPRoles-0.10.0-pour-les-joueurs.zip` (ou celle de la 0.9.0, qui se mettra à jour seule).

**État des tests :**
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
- **Test à deux du 3 octobre (version 0.5.3)** : Recruteur, Médium, Clandestin, Martyr et Liés fonctionnent. Défauts relevés : plantage du Métamorphe, Traqueur sans vue à travers les murs, Revenant réduit à une faible lumière, sphère rouge pour la personne sûre du Shérif, sphères restées au-dessus des têtes dans le lobby.
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
- **0.9.0** : le projet devient un dépôt GitHub ; le mod se met à jour tout seul au lancement du jeu (et par `mettre-a-jour.bat`). Aucun changement de jeu. Publiée et installée le 8 octobre. Mise à jour vérifiée hors du jeu, contre la vraie page GitHub. Premier lancement en jeu par l'utilisateur le 8 octobre : la vérification passe, le mod se charge normalement. Une vraie mise à jour depuis le jeu reste à voir.
- **0.10.0** : six rôles de plus, Empoisonneur, Bâillonneur, Voleur, Écho, Amnésique et Bouffon (les deux derniers sont neutres). **Aucun n'a encore été lancé en jeu.** Installée le 8 octobre, pas publiée.

## Ce qui est installé

Dans le dossier du jeu, sous `LockdownProtocol\Binaries\Win64\` :

| Élément | Rôle |
|---|---|
| `dwmapi.dll` | Chargeur UE4SS (build officielle `experimental-latest`) |
| `ue4ss\` | UE4SS et ses mods |
| `ue4ss\Mods\LPRoles\` | Le mod |
| `ue4ss\Mods\LPRoles\config.txt` | Réglages (créé au premier lancement) |
| `ue4ss\UE4SS_Signatures\GUObjectArray.lua` | Signature nécessaire à UE4SS pour ce jeu |
| `ue4ss\UE4SS.log` | Journal d'UE4SS, recommencé à chaque lancement du jeu |
| `ue4ss\Mods\LPRoles\journal.txt` | Journal du mod, conservé d'un lancement à l'autre : c'est là qu'il faut regarder en cas de souci (chaque joueur a le sien) |

Le jeu doit être **relancé** pour charger une nouvelle version du mod.

## Mise à jour automatique

- **À chaque lancement du jeu**, avant de charger ses scripts, le mod regarde sur sa page GitHub si une version plus récente est publiée. Si oui, il la télécharge, la vérifie et l'installe : elle sert dès ce lancement. Un bandeau « LPROLES MIS À JOUR : VERSION … » le signale.
- **Ce qui est gardé :** `config.txt` (vos réglages), les journaux, et tout son que vous avez remplacé par le vôtre.
- **Sans réseau**, ou si GitHub ne répond pas : le lancement attend quelques secondes au plus, puis continue avec la version en place.
- **À la main :** double-clic sur `mettre-a-jour.bat` dans `ue4ss\Mods\LPRoles\`, jeu fermé. Même mise à jour, avec un message qui dit ce qui a été fait. Il remet aussi en état une installation abîmée.
- **Pour la couper :** MES RÉGLAGES, « Mise à jour automatique au lancement » sur NON (ou `auto_update = false` dans `config.txt`).
- **Le journal** (`journal.txt`) note à chaque lancement ce que la mise à jour a fait et le temps qu'elle a pris.
- Le mod ne revient jamais à une version plus ancienne que celle installée.
- **Lancée depuis le jeu le 8 octobre** (0.9.0, rien de nouveau à installer) : la vérification a pris 4,8 s, pendant que le jeu chargeait ; le mod s'est mis en place au même moment qu'avant, sans erreur. **Pas encore vu :** une vraie mise à jour faite depuis le jeu (ce sera la prochaine version). L'utilisateur n'a vu aucune fenêtre noire au démarrage.

**Pour tout désactiver :** renommer `dwmapi.dll` en `dwmapi.dll.off`.
**Pour désactiver seulement LPRoles :** supprimer `ue4ss\Mods\LPRoles\enabled.txt`.

## Qui doit l'installer

**Tous les joueurs.** L'hôte attribue les rôles et applique les règles ; la machine de chaque joueur affiche son rôle et fait fonctionner ses pouvoirs. Ce document suppose que tout le monde a le mod.

Pour un joueur : ouvrir `LPRoles-pour-les-joueurs.zip` (UE4SS + le mod, 8,5 Mo) et coller son contenu (le dossier `LockdownProtocol`) dans le dossier racine du jeu, celui qui contient `LockdownProtocol.exe`. Accepter la fusion des dossiers : les fichiers arrivent dans `LockdownProtocol\Binaries\Win64\`. Tout le monde doit avoir la **même version** : renvoyez l'archive après chaque mise à jour.

## Les touches

Chaque joueur a au plus un rôle spécial, donc la même touche sert à tous les rôles. Les clins d'œil ne servent plus à rien dans le mod.

| Touche ou geste | Sert à |
|---|---|
| **Touche B** (réglable) : activer le pouvoir | Tous les pouvoirs, sauf celui du Rêveur (détail ci-dessous) |
| **Touche G** (réglable) : consommer l'objet en main | Récupérer une utilisation du pouvoir avec un bocal de plante ou un poisson |
| **Deux yeux fermés 3 s** | Rêveur seulement : rêver, puis se réveiller plus tôt. Les yeux se rouvrent tout seuls quand le rêve commence |

Ce que fait la touche de pouvoir selon le rôle :

| Rôle | Effet de la touche |
|---|---|
| **Fée**, **Médium** | Le pouvoir part aussitôt |
| **Clandestin** | Se cache, près d'une bouche d'aération ; un nouvel appui (après 1 s) le fait sortir |
| **Revenant** | Se manifeste, une fois mort |
| **Écho** | Le retour en arrière part aussitôt |
| **Empoisonneur, Bâillonneur, Voleur** | Comme le Traqueur : appuyer en regardant un joueur, le pouvoir agit aussitôt (le Voleur doit être à 2,5 m au plus) |
| **Amnésique** | Appuyer en regardant un cadavre, ou à moins de 2,5 m de lui |
| **Bouffon** | Rien : il n'a pas de pouvoir à lancer |
| **Traqueur, Hypnotiseur, Métamorphe, Échangeur** | Appuyer en regardant un joueur : le pouvoir agit **aussitôt** sur lui. Sans personne en vue, rien ne se passe et rien n'est dépensé (« PERSONNE EN VUE ») |
| **Ange gardien** | Appuyer en regardant un joueur : son nom s'affiche (« CIBLE : … »), puis il faut le garder en vue 1,5 s (réglage « Protégé à garder en vue », groupe ANGE GARDIEN ; 0 = choix immédiat). Sans personne en vue, le mod cherche pendant 2,5 s |
| **Recruteur** | Appuyer près d'un employé, puis rester près de lui 4 s |
| **Nettoyeur** | Appuyer près d'un cadavre, puis rester près de lui 3 s |
| **Rêveur** | Rien : le bandeau rappelle de fermer les deux yeux |

## Les rôles

| Rôle | Camp par défaut | Pouvoir |
|---|---|---|
| **Shérif** | Employé | Une carte d'accès posée dans le bâtiment lui est montrée en surbrillance (lui seul la voit ainsi) ; connaît une personne sûre, marquée 20 s d'une sphère verte |
| **Recruteur** | Dissident | Convertit un employé en dissident, 45 s après le geste. Une fois par partie, pas pendant la première minute |
| **Rêveur** | Les deux | Fantôme 18 s ; son corps reste assis, yeux fermés, vulnérable. Une charge |
| **Fée** | Les deux | Fantôme rapide et intouchable 5 s ; les autres voient une boule violette et une lumière à la place de son corps, qui réapparaît là où elle se pose. Une charge |
| **Médium** | Employé | Vision de 10 s : voit et entend les morts. 2 visions par partie |
| **Ange gardien** | Employé | Choisit un protégé une fois par partie ; à sa première mort, le protégé se relève aussitôt, même s'il était le dernier employé en vie |
| **Taupe** | Dissident | Invisible des autres dissidents (sphère et liste des joueurs), et ne les voit pas. Le jeu l'affiche comme employé. Seulement s'il y a au moins 2 dissidents |
| **Traqueur** | Dissident | Voit la silhouette de sa cible à travers les murs pendant 15 s. 2 traques par partie |
| **Hypnotiseur** | Dissident | Ferme de force les yeux d'un joueur proche pendant 3 s. 2 hypnoses par partie |
| **Métamorphe** | Dissident | Prend l'apparence exacte du joueur visé pendant 15 s (vue par tous). Marche aussi sur un cadavre, visé ou à moins de 2,5 m. 2 fois par partie |
| **Nettoyeur** | Dissident | Fait disparaître un cadavre, qui ne peut plus être réanimé. 2 fois par partie |
| **Clandestin** | Les deux | Se cache dans une bouche d'aération 20 s : invisible et intouchable pour tous, mais immobile. 2 fois par partie |
| **Échangeur** | Les deux | Échange sa place avec le joueur visé. 1 fois par partie |
| **Martyr** | Employé | S'il est tué par un joueur, tout le monde apprend le camp de son tueur (ou son nom, selon le réglage) |
| **Revenant** | Les deux | Une fois mort, son fantôme devient visible et audible de tous pendant 20 s. 1 fois à chaque mort : réanimé puis mort de nouveau, il peut recommencer |
| **Empoisonneur** | Dissident | Empoisonne le joueur visé : il meurt 60 s plus tard, sans coup de personne. Prévenu 40 s avant, il peut se sauver en consommant un poisson. 1 fois par partie |
| **Bâillonneur** | Dissident | Coupe le micro du joueur visé pendant 20 s : plus personne ne l'entend. 2 fois par partie |
| **Voleur** | Les deux | À 2,5 m au plus, prend l'objet que tient le joueur visé. 2 fois par partie |
| **Écho** | Les deux | Revient aussitôt là où il était 5 s plus tôt. 2 fois par partie |
| **Amnésique** | Neutre | Sans pouvoir au départ. Prend, une fois pour toutes, le rôle et le camp d'un mort |
| **Bouffon** | Neutre | Gagne seul s'il est tué par un employé ; sa victoire termine la partie |

**Liés** n'est pas un rôle mais un lien entre deux joueurs, qui s'ajoute à leurs rôles éventuels : au premier des deux qui meurt, l'autre meurt aussi. Le lien ne joue qu'une fois : ensuite il est rompu, même si l'un des deux revient (défibrillateur, Ange gardien). Un lié sauvé par un Ange gardien d'une mort ordinaire ne déclenche pas le lien. Chacun connaît le nom de l'autre. Le lien ne compte pas dans le nombre de rôles par partie. Réglages dans le groupe LIÉS (activé ou non, joueurs minimum, camps des deux liés).

- **Nombre de rôles par partie :** chaque partie tire au hasard, parmi les rôles actifs, au plus **4** rôles spéciaux (réglage « Rôles spéciaux par partie »). Mettre 16 pour avoir tous les rôles possibles à chaque partie.
- Les rôles sont annoncés 7 s après le début, par le seul nom du rôle. Le mode d'emploi est sur la page de la tablette et dans l'onglet LPROLES.
- Pendant qu'ils sont fantômes, le Rêveur et la Fée ne voient ni leurs mains ni l'objet tenu. Ils les retrouvent au retour dans leur corps.
- Le Rêveur rouvre les yeux tout seul au début et à la fin du rêve. Il n'entend que les vivants, ne voit pas les morts et ne peut rien toucher. S'il est attaqué, il se réveille aussitôt dans son corps.
- Le Shérif ne peut pas être recruté (réglable).

## Les six rôles de la 0.10.0

**Aucun n'a encore été lancé en jeu.** Tous se règlent dans l'onglet LPROLES, chacun dans son groupe.

### Empoisonneur (dissident)

- Il vise un joueur à 4 m au plus et appuie : la victime mourra **60 s** plus tard (« Mort après »). Rien ne se voit ni ne s'entend.
- La victime est prévenue **40 s avant sa mort** (« Prévenu avant sa mort » ; 0 = jamais, une valeur au moins égale au délai = aussitôt) : « EMPOISONNÉ : MORT DANS 40 S », puis le nom de l'antidote.
- **Antidote** (réglage « Antidote ») : par défaut **n'importe quel poisson**. Une fois prévenue, la victime le tient en main et appuie sur la touche de consommation. Autres choix : n'importe quelle plante en bocal, un objet précis, ou aucun antidote.
- L'Empoisonneur lit sur sa page « … est empoisonné : mort dans … s », et apprend si son poison a été soigné.
- La mort par poison n'a pas de tueur : le Martyr n'annonce rien, le Bouffon ne gagne pas. Un protégé de l'Ange gardien se relève comme d'habitude ; un Lié entraîne l'autre.
- Le poison disparaît si la victime meurt autrement entre-temps. Il agit même si l'Empoisonneur est mort.

### Bâillonneur (dissident)

- Il vise un joueur à 10 m au plus et appuie : le **micro de la victime est coupé 20 s**. Personne ne l'entend, vivants ou morts.
- La victime lit « BÂILLONNÉ : MICRO COUPÉ (20 S) » ; l'icône de micro du jeu passe à l'état coupé. À la fin : « TON MICRO REMARCHE ».
- C'est la machine de la victime qui coupe son propre micro, par le même réglage que le jeu utilise pour un Rêveur endormi.
- La mort de la victime met fin au bâillon.

### Voleur (les deux camps)

- Il vise un joueur à **2,5 m** au plus et appuie : l'objet que la victime **tient en main** passe dans la main du Voleur, dans le même état (munitions, plante du bocal…).
- Il faut que la main du Voleur soit vide (« TA MAIN DOIT ÊTRE VIDE ») et que la victime tienne quelque chose (« IL NE TIENT RIEN »). Dans ces deux cas rien n'est dépensé.
- La victime lit « ON T'A VOLÉ TON OBJET », sans le nom du Voleur.
- Le sac n'est pas touché. On ne vole pas un Rêveur endormi.

### Écho (les deux camps)

- Il appuie : il est renvoyé aussitôt là où il se tenait **5 s** plus tôt (« Retour en arrière de »), tourné comme il l'était.
- Le trajet repart de zéro après chaque retour, après un envol, un rêve ou une cachette : pendant la première seconde, « PAS ENCORE DE TRAJET À REJOUER ».

### Amnésique (neutre)

- Il n'a ni rôle ni pouvoir au départ. Il vise un **cadavre** à 10 m au plus (ou se tient à moins de 2,5 m de lui) et appuie : il prend **le rôle et le camp du mort**, avec toutes ses utilisations. Le choix est définitif.
- Si le mort était dissident, l'Amnésique devient dissident (« TU DEVIENS DISSIDENT ») ; le jeu le compte alors parmi les dissidents.
- Un mort sans rôle ne donne rien, et l'Amnésique peut essayer un autre corps. Le lien des Liés ne se transmet pas.
- **Tant qu'il n'a rien pris, il compte comme un employé** pour la fin de partie.

### Bouffon (neutre)

- Il n'a pas de pouvoir. Il **gagne seul si un employé le tue**. Tué par un dissident, par le poison, une explosion ou une chute, il a perdu.
- Sa victoire est annoncée à tous (« LE BOUFFON GAGNE : … »), puis la partie s'arrête 3 s plus tard, comme quand l'hôte l'arrête lui-même : le jeu n'affiche ni victoire ni défaite. L'annonce est répétée au retour dans le lobby.
- Réglage « Sa victoire termine la partie » sur NON : la victoire est seulement annoncée, la partie continue sans lui.
- Pour le reste du jeu, il compte comme un employé : les dissidents doivent aussi l'éliminer pour gagner.
- Le tueur est celui qui l'a frappé dans les 3 s avant sa mort, comme pour le Martyr.

### Les rôles neutres et le jeu

Le jeu ne connaît que deux camps. L'Amnésique et le Bouffon sont donc tirés parmi les employés, et le jeu continue de les compter comme tels : la partie ne se termine par « tous les employés sont morts » qu'une fois eux aussi morts (ou l'Amnésique passé dissident).

## Recharger un pouvoir

Un rôle dont les utilisations sont comptées peut en récupérer une en consommant un objet : le bon objet en main, puis la touche de consommation (G par défaut).

| Rôle | Objet par défaut | Où le trouver |
|---|---|---|
| **Rêveur** | Bocal de plante G3M (verte) | Plante récoltée dans un bocal |
| **Fée** | Bocal de plante WX2 (blanche) | idem |
| **Médium** | Bocal de plante BO4 (bleue) | idem |
| **Clandestin** | Bocal de plante Y8Z (jaune) | idem |
| **Échangeur** | Bocal de plante RU2 (rouge) | idem |
| **Traqueur** | Poisson TUNA (thon) | Machine à poissons |
| **Hypnotiseur** | Poisson SALMON (saumon) | idem |
| **Métamorphe** | Poisson SHRIMP (crevette) | idem |
| **Nettoyeur** | Poisson COD (cabillaud) | idem |
| **Recruteur** | Aucun | |

- Les poissons portent le nom affiché sur l'écran de la machine à poissons (le jeu est en anglais). On choisit le poisson avec les boutons de la machine ; son nom s'affiche sur l'écran.
- Un objet rend **une** utilisation, sans dépasser le maximum du rôle. Le bandeau affiche « UTILISATION RÉCUPÉRÉE » (« CHARGE RÉCUPÉRÉE » pour le Rêveur et la Fée).
- L'utilisation n'est rendue qu'une fois l'objet réellement consommé. Lâcher le bocal au moment d'appuyer ne donne rien : on garde la plante, et le bandeau redemande l'objet 3 s plus tard.
- Le bocal devient **sale**, comme après la centrifugeuse : il faut le passer au nettoyeur de bocaux avant de récolter à nouveau. Le poisson disparaît de la main.
- Quand il ne reste plus d'utilisation, le bandeau nomme l'objet à trouver (« PAS DE CHARGE : POISSON TUNA »). La page de la tablette et l'onglet LPROLES le rappellent aussi.
- **Réglages de l'hôte :**
  - « Objet de recharge », dans le groupe de chaque rôle : aucun, une des cinq plantes ou un des quatre poissons. Deux rôles peuvent avoir le même objet.
  - « Recharges par partie (0 = illimité) », dans GÉNÉRAL : nombre de recharges permis à chaque joueur.
  - Rêveur et Fée sans objet (« AUCUN ») : ils commencent toujours avec leur charge, quel que soit « Charge au départ ».
  - Dans `config.txt`, chaque réglage à choix liste ses valeurs possibles ; le libellé du menu est accepté aussi.
- Pas de recharge pour le Shérif, l'Ange gardien, la Taupe et le Martyr (rien à récupérer), ni pour le Revenant (ses apparitions ne servent qu'une fois mort).

## Touche « activer le pouvoir »

- Par défaut **B**. Chaque joueur la choisit pour lui-même dans l'onglet LPROLES, groupe **MES RÉGLAGES**, parmi les touches que le jeu n'utilise pas : les lettres G, B, N, L, M, Y, I, P et les deux boutons latéraux de la souris, **SOURIS 4** (celui de l'arrière) et **SOURIS 5** (celui de l'avant).
- Elle ne peut pas être la même touche que celle de consommation : si on choisit celle de l'autre, les deux réglages échangent leurs touches.
- Boutons de souris (depuis la 0.8.15) : essayés en jeu par l'utilisateur, ils fonctionnent. Deux limites connues : si un joueur a lui-même mis une action du jeu sur l'un de ces boutons (réglages de touches du jeu), le bouton fera les deux à la fois ; et une souris dont le logiciel (Logitech, Razer...) a donné un autre rôle à ces boutons n'envoie plus « bouton 4 / 5 », le mod ne la verra donc pas.
- Elle ne fait rien quand le menu Échap est ouvert, pendant un envol ou un rêve, ni pour un joueur hypnotisé.
- La page du rôle sur la tablette et l'onglet LPROLES écrivent la touche choisie.
- Le Rêveur garde son geste (les deux yeux fermés) : pour lui, la touche affiche seulement « RÊVEUR : FERME LES DEUX YEUX ».

## Carte d'accès du Shérif

- Le Shérif ne reçoit plus de carte. Sept secondes après le début (à l'annonce des rôles), l'hôte pose **une carte d'accès de plus** à l'un des emplacements d'objets du jeu, au hasard, comme le jeu pose les siennes.
- Sur l'écran du Shérif seulement, cette carte est entourée d'une **boule jaune** surmontée d'une **colonne jaune** de 3 m. Par défaut, elles se voient **à travers les murs**.
- Les autres joueurs voient une carte ordinaire et peuvent la ramasser. Dès que quelqu'un la prend, la surbrillance disparaît et le Shérif lit « LA CARTE A ÉTÉ RAMASSÉE ».
- **Réglages de l'hôte**, groupe SHÉRIF :
  - « Une carte d'accès en surbrillance » : NON = ni carte ni surbrillance.
  - « Carte posée en plus de celles du jeu » : NON = le mod ne pose rien et met en surbrillance une des cartes que le jeu a posées (s'il n'y en a aucune, le Shérif lit « PAS DE CARTE D'ACCÈS À MONTRER »).
  - « Surbrillance vue à travers les murs » : NON = une boule lumineuse visible seulement en vue directe.

## Touche « consommer l'objet en main »

- Par défaut **G**. Chaque joueur la choisit pour lui-même dans l'onglet LPROLES, groupe **MES RÉGLAGES**, parmi les touches que le jeu n'utilise pas : les lettres G, B, N, L, M, Y, I, P et les deux boutons latéraux de la souris, **SOURIS 4** (celui de l'arrière) et **SOURIS 5** (celui de l'avant).
- Elle consomme l'objet tenu en main pour rendre une utilisation du pouvoir (voir « Recharger un pouvoir »).
- Elle ne fait rien quand le menu Échap ou la tablette est ouvert, quand les mains sont occupées (échange entre la main et le sac, objet tout juste pris ou posé), pour un Clandestin caché, ni pour un rôle qui n'a pas d'objet de recharge.
- L'ancienne recharge en fermant les yeux est désactivée par défaut. L'hôte peut la remettre pour le Rêveur (groupe RÊVEUR, « Recharger aussi en fermant les yeux »).
- Elle n'apparaît pas dans le menu des touches du jeu (voir `decisions-mod.md`, D38).

## Volume des sons du mod

- Les cinq sons (`consume`, `fail`, `success`, `swap`, `fairy`) sont réglés au **même niveau d'écoute**, -23 LUFS, mesuré comme le fait la radiodiffusion (ITU-R BS.1770) sur les 0,4 s les plus fortes de chaque son. C'est le niveau qu'avaient déjà le son de l'envol et le son de consommation, ceux que l'utilisateur avait entendus en jeu sans les trouver déplacés.
- Exception : le son de l'envol de la Fée est 3 dB plus bas (-26 LUFS), l'utilisateur le trouvant un peu fort à l'écoute en jeu.
- Chaque joueur règle le tout dans MES RÉGLAGES, « Volume des sons du mod (%) », de 10 à 200 % (100 par défaut). Essayé en jeu : il fonctionne.
- Les sons du mod suivent le curseur de volume du jeu (vérifié en jeu par l'utilisateur le 7 octobre) : le réglage ci-dessus s'y ajoute.
- Les sons du jeu lui-même n'ont pas pu être mesurés (ils sont dans un format que rien ici ne sait lire) : le niveau par rapport au jeu se juge à l'oreille, avec ce réglage.
- Pour mesurer ou remettre à niveau un son : `python tools\lp\loudness.py fichier.wav`, ou `python tools\lp\loudness.py --set -23 fichier.wav`.

## Sons des pouvoirs

- **Quand un pouvoir démarre**, celui qui l'a lancé entend `sounds\success.wav` (1 s ; c'est la variante longue, que l'utilisateur a retenue). Il se coupe dans MES RÉGLAGES, « Son d'un pouvoir qui démarre ».
- **Quand il ne démarre pas**, quelle que soit la raison (personne en vue, plus d'utilisation, pas de bouche d'aération, joueur hypnotisé ou mort, pouvoir déjà en cours…), il entend `sounds\fail.wav` (0,2 s). Réglage « Son d'un pouvoir qui échoue ».
- Les autres joueurs n'entendent ni l'un ni l'autre.
- La Fée l'entend aussi à son départ, en même temps que le son de son envol qui monte en fondu. Le Rêveur, qui s'endort en fermant les yeux, a les deux sons comme les autres.
- La touche de consommation garde son propre son et n'a pas de son d'échec.
- Les trois fichiers viennent des OGG fournis, convertis en WAV 16 bits stéréo et mis au même niveau d'écoute que les autres (voir « Volume des sons du mod »). Pour en changer un, remplacer le fichier du même nom.

## Son de l'échange (Échangeur)

- Quand un Échangeur échange sa place, `sounds\swap.wav` (1,0 s) est joué à la place du son de démarrage habituel.
- L'Échangeur et le joueur échangé l'entendent tel quel. Les autres l'entendent **autour de chacun des deux**, de moins en moins fort avec la distance (même portée que l'envol de la Fée : plein volume à moins de 3 m, plus rien au-delà de 21 m).
- Il se coupe dans MES RÉGLAGES, « Son des échanges de place », pour ses propres échanges comme pour ceux des autres.
- Un échange raté garde le son d'échec ordinaire.
- Chez les autres joueurs, le son placé dans l'espace repose sur le même mécanisme que l'envol de la Fée, **jamais essayé en jeu**.

## Son de l'envol de la Fée

- Quand une Fée s'envole, le fichier `ue4ss\Mods\LPRoles\sounds\fairy.wav` est joué sur sa machine, et sur celle de chaque autre joueur **à l'endroit où elle se trouve** : on l'entend à plein volume à moins de 3 m d'elle, de moins en moins fort ensuite, plus du tout au-delà de 21 m. Le son la suit pendant son vol et traverse les murs.
- Chaque machine joue son propre exemplaire du fichier : un joueur qui a remplacé `fairy.wav` entend le sien.
- **Le son suit la durée de l'envol** réglée par l'hôte : le mod en joue une copie coupée à cette durée, qui arrive en fondu (1 s) et se termine en fondu (0,4 s). Pour un envol très court, le fondu d'entrée ne prend pas plus de la moitié de la durée. Si le son est plus court que l'envol, il est répété. Une copie est écrite par durée utilisée (`LPRoles-son-…-50b.wav` pour 5 s) ; elles se refont toutes seules.
- Le son fourni dure 12,3 s : c'est celui qu'une amie a composé, converti de l'OGG au WAV (le lecteur du jeu ne lit pas l'OGG), en mono (ses deux canaux étaient identiques) et monté en volume. Rien d'autre n'a été changé.
- Pour le remplacer : un autre `fairy.wav` en **WAV 16 bits**, ou convertir un fichier avec `python tools\lp\sound.py entrée.ogg fairy.wav`. Un `fairy.mp3` est prioritaire mais n'est pas coupé en fondu : il est simplement arrêté à la fin de l'envol.
- Si l'envol s'arrête plus tôt que prévu (fin de partie), le son est coupé net.
- Il se coupe dans MES RÉGLAGES (« Son de l'envol des Fées ») : pour soi-même et pour les envols des autres.
- **Chez les autres joueurs, jamais essayé en jeu.** Si le moteur refuse les réglages de distance, le mod ne joue pas le son chez eux plutôt que de le faire entendre partout ; le journal de chaque joueur dit ce qui a été fait (ligne « Son fairy autour de … »).

## Son de consommation

- Quand une plante ou un poisson est consommé, le fichier `ue4ss\Mods\LPRoles\sounds\consume.wav` est joué, sur la machine de celui qui consomme seulement.
- Pour mettre votre propre son, remplacez ce fichier par un autre `consume.wav`, ou ajoutez un `consume.mp3` (prioritaire).
- Le son fourni est provisoire (deux « glouglous » et un carillon), généré pour l'occasion.
- Le lecteur du jeu coupait la fin des sons. Le mod joue donc une copie du fichier suivie d'une seconde de silence, écrite dans le dossier du mod (`LPRoles-son-….wav`). Elle est refaite toute seule si vous changez le fichier ; vous pouvez la supprimer sans risque.
- Les mises à jour du mod ne remplacent ni ne suppriment rien dans le dossier `sounds` du jeu : votre son reste. L'archive pour les joueurs reprend les sons de votre dossier du jeu.
- Il se coupe dans MES RÉGLAGES (« Son à la consommation »).

## Page du rôle sur la tablette

- Pendant la partie, deux flèches **<** et **>** apparaissent dans le bandeau du haut de la tablette.
- **>** affiche la page du rôle à la place de la liste des tâches et de la carte ; **<** revient aux tâches.
- La page (comme l'onglet LPROLES) donne le nom du rôle, où il en est (utilisations restantes, effet en cours et temps restant, protégé, cible, personne sûre…) et comment l'utiliser, avec les durées, portées et gestes réglés par l'hôte et votre propre touche de consommation. Elle se met à jour chaque seconde.
- Juste après l'annonce du rôle, elle affiche « En attente des informations de l'hôte » le temps de recevoir ses réglages (moins d'une seconde).
- Pour relire toutes les pages sans lancer le jeu : `python tools\lp\pages.py` (ou `python tools\lp\pages.py chemin\vers\config.txt` pour vos réglages).
- Mise en forme : le nom du rôle en grand et en gras ; la ligne d'état en texte clair dans un bandeau sombre ; les explications en lignes à puces, avec les valeurs et les mots-clés en gras.
- Le nom de la plante qui recharge le pouvoir est écrit dans la couleur de la plante : G3M vert, Y8Z jaune, BO4 cyan, RU2 rouge, WX2 blanc lumineux. Le nom d'un poisson est en gras, sans couleur.
- L'écran de la tablette ne montre pas les couleurs telles quelles. Il n'a que trois « encres » : une encre sombre (le texte du jeu), un blanc lumineux, et une encre qui prend la couleur de la pièce de la carte située à cet endroit de l'écran (gris hors des pièces). D'où les couleurs qui changeaient d'un endroit à l'autre dans la version 0.4.3.
- Pour les plantes, le mod change les couleurs des pièces de la carte pendant que la page du rôle est affichée (la carte est alors cachée) et les remet dès qu'on revient aux tâches. Cela ne touche que votre tablette.
- La page revient aux tâches dès que la tablette quitte l'écran de partie (lobby, vidéo, tutoriel).
- Elle se désactive dans MES RÉGLAGES (« Page du rôle sur la tablette »).
- Si le jeu s'arrête pendant sa construction, elle est mise en pause au lancement suivant seulement ; après deux arrêts de suite, jusqu'à ce qu'on appuie sur **F10**. Même règle pour l'onglet LPROLES.

## Menu Échap, onglet LPROLES

Un onglet **LPROLES** s'ajoute au menu Échap du jeu, juste après l'onglet « Règles ».

- **Pour tous :** le rôle du joueur et le rappel de son fonctionnement (les mêmes lignes que sur la tablette ; une ligne longue continue sur la rangée suivante).
- **Pour tous :** le groupe MES RÉGLAGES (touche de pouvoir, touche de consommation, page de la tablette), enregistré sur sa propre machine.
- **Pour l'hôte :** tous les réglages de la partie, groupés par rôle. Les flèches changent les choix (oui/non, camp) et bouclent du dernier au premier ; les champs numériques se saisissent ou se font glisser. Chaque changement est enregistré aussitôt dans `config.txt`.

Tout est réglable : rôles actifs, nombre de rôles par partie, nombre minimum de joueurs, camps, durées, portées, nombre d'utilisations, durée des gestes.

**Attention au premier clic :** à chaque ouverture du menu Échap, le jeu replace le curseur au centre de l'écran. Si l'onglet LPROLES est resté affiché, le curseur se trouve sur une ligne de réglage, et un clic la change. Le journal du mod (`journal.txt`) note chaque changement de réglage et par où il est passé.

Si le jeu s'arrête pendant la construction de l'onglet, l'onglet est mis en pause au lancement suivant seulement ; après deux arrêts de suite, jusqu'à ce qu'on appuie sur **F10**. Un bandeau le signale. Pour le couper à la main : `menu_tab = false` dans `ue4ss\Mods\LPRoles\config.txt` (F10 le remet). Le reste du mod fonctionne sans lui.

### Touches de secours

Si l'onglet n'apparaît pas (le journal contient alors « Onglet LPROLES incomplet »), les réglages restent accessibles à l'hôte :

| Touche | Action |
|---|---|
| F5 / F6 | Réglage précédent / suivant |
| F7 / F8 | Diminuer / augmenter (ou oui/non) |
| F9 | Nombre de joueurs dont le mod a répondu à l'hôte (pour repérer une installation qui ne marche pas) |
| F10 | Diagnostic (tout joueur), détail dans le journal. Remet aussi en route l'onglet LPROLES et la page de la tablette s'ils étaient coupés |

## Tester les nouveaux rôles

**À deux ou trois joueurs :** chaque rôle a un réglage « Joueurs minimum » (4 à 6 par défaut). En dessous, le rôle n'est donné à personne, même activé. Pour tester à peu de joueurs, baissez ce réglage rôle par rôle, ou activez « Ignorer les joueurs minimum » dans le groupe TEST. L'hôte voit le message « N RÔLE(S) NON ATTRIBUÉ(S) : RÉGLAGE JOUEURS MINIMUM » au début de la partie quand c'est le cas.

**Si le mod d'un joueur ne répond pas** (installation incomplète, version différente), l'hôte voit « N JOUEUR(S) SANS LE MOD » au début de la partie. C'est le signal qu'il faut lui renvoyer l'archive ; lui-même peut appuyer sur F10 et envoyer son `journal.txt`.

**À deux joueurs, le jeu ne désigne aucun dissident**, sauf en difficulté Custom avec la règle du nombre de dissidents à 1. Les rôles réservés aux dissidents (Recruteur, Taupe, Traqueur, Hypnotiseur, Métamorphe, Nettoyeur) ne peuvent donc être donnés à personne. Les rôles « Les deux » ou « Employé » (Rêveur, Fée, Médium, Ange gardien, Clandestin, Échangeur, Martyr, Revenant, Shérif) fonctionnent. Le réglage « Joueurs minimum » du Recruteur, de la Taupe et des Liés ne descend pas sous 3 : seul « Ignorer les joueurs minimum » les autorise à deux.

Le réglage `Rôle forcé pour l'hôte` (groupe TEST) donne à l'hôte le rôle choisi, même en difficulté Training. Mais presque tous les nouveaux rôles ont besoin d'un deuxième joueur : une cible à viser, un mort à voir, un partenaire lié ou un tueur.

**Testable seul :** la touche de consommation.
- *Avec une plante :* mettre « Rôle forcé pour l'hôte » sur Rêveur, rêver une fois pour vider la charge, récolter une plante verte G3M dans un bocal, puis appuyer sur G, bocal en main. On doit voir « CHARGE RÉCUPÉRÉE » et le bocal se vider.
- *Avec un poisson :* mettre « Rôle forcé pour l'hôte » sur Médium et, dans le groupe MÉDIUM, « Objet de recharge » sur POISSON SALMON. Avoir une vision (touche B), sortir un SALMON de la machine à poissons, puis appuyer sur G, poisson en main. On doit voir « UTILISATION RÉCUPÉRÉE », le poisson disparaître de la main, et la page de la tablette revenir à « 2 sur 2 ».
- Avec toutes ses utilisations, le même geste doit afficher « UTILISATIONS DÉJÀ AU MAXIMUM » et laisser l'objet en main.

Ce qu'il faut regarder en priorité, à plusieurs :
1. **Médium** : les fantômes apparaissent-ils et s'entendent-ils pendant 10 s, puis disparaissent-ils ?
2. **Hypnotiseur** : l'écran de la cible devient-il noir 3 s, et ses yeux se rouvrent-ils ensuite ?
3. **Ange gardien** : le protégé se relève-t-il bien à l'endroit de sa mort ?
4. **Revenant** : son fantôme est-il vu et entendu de tous pendant la durée réglée, et ses yeux se rouvrent-ils ?
5. **Échangeur**, **Traqueur**, **Taupe**, **Liés**, **Martyr** : effet attendu, et messages affichés.

## Limites connues

- **Métamorphe :** sa voix, son nom et sa couleur dans la liste des joueurs, et sa sphère de dissident ne changent pas (la couleur de la liste se règle : « Garde sa couleur dans la liste »). À sa mort, il reprend aussitôt sa vraie apparence.
- **Métamorphe et cadavres :** le corps d'un mort est repéré par l'endroit de sa mort, pas par son dessin exact : viser le sol à côté du corps peut suffire. Un corps nettoyé par le Nettoyeur ne peut plus être copié.
- **Carte du Shérif :** jamais essayée en jeu. La carte posée tombe au sol pendant la première seconde ; la surbrillance la suit. Si la carte ne peut pas être posée, le mod se rabat sur une carte du jeu et le note dans le journal. Un Shérif mort garde la surbrillance jusqu'à ce que la carte soit prise.
- **Touche de pouvoir :** jamais essayée en jeu. Un joueur qui garde une ancienne version du mod n'a pas cette touche : tout le monde doit passer à la 0.8.3 en même temps.
- **Traqueur :** la silhouette est faite de trois formes arrondies (jambes, buste, tête) posées sur la cible, pas de son vrai corps : elle reste debout même si la cible s'accroupit. Elle n'existe que sur l'écran du Traqueur.
- **Revenant :** la durée par défaut (20 s) ne remplace pas celle déjà enregistrée dans vos réglages (3 s) : elle se change dans le groupe REVENANT, jusqu'à 60 s. Un Revenant réanimé pendant qu'il se manifeste cesse aussitôt d'être montré.
- **Tablette :** la place des flèches et de la page est calculée d'après la disposition de la tablette, mesurée en jeu. Le premier essai peut demander un ajustement ; le journal `UE4SS.log` note les mesures (lignes « Tablette : »).
- **Recharge :** un poisson posé dans un emplacement dans le dixième de seconde qui suit la touche rend l'utilisation et reste dans l'emplacement (le jeu ne consulte pas l'hôte). « Recharges par partie » borne l'abus.
- **Clandestin :** pendant la cachette, son corps est envoyé 40 m sous la bouche pour tout le monde. Il ne peut ni marcher, ni utiliser ou frapper quoi que ce soit, et sa voix n'est probablement plus entendue (elle part de son corps). Il peut encore sauter sur place, sans effet visible pour les autres.
- **Visée :** un joueur derrière un mur n'est pas visé. Jusqu'à 5 m, le mod se fie au point que le jeu calcule pour le regard de chaque joueur (un joueur juste derrière un obstacle bas ou fin, à moins de 80 cm du point regardé, peut être visé). Au-delà, l'hôte fait tracer par le moteur une ligne entre les yeux du joueur et sa cible ; un autre joueur placé entre les deux arrête la ligne. Ce tracé n'a jamais été essayé en jeu : s'il échoue, les murs situés à plus de 5 m ne sont plus vérifiés et le journal de l'hôte le dit (« Visée : le tracé de visibilité… »).
- **Ange gardien :**
  - Le protégé meurt réellement avant de se relever : il lâche ses objets, qui restent à ses pieds, et revient avec peu de vie.
  - La résurrection du jeu efface aussi les cadavres affichés chez lui.
  - Si le protégé était le dernier employé en vie, il se relève et la partie continue : tant qu'un employé est protégé, le mod inscrit les dissidents dans la liste que le jeu consulte pour décider de sa fin, puis les en retire. Jamais essayé en jeu.
  - Seul cas où la partie se termine quand même : plus aucun dissident n'est en vie non plus au moment où il meurt. L'ange lit alors « TROP TARD : PARTIE TERMINÉE ».
- **Martyr :** une mort par grenade, poison ou chute ne révèle rien. Le tueur n'est révélé que si son coup date de moins de 3 s.
- **Rêveur :** une explosion est calculée à l'endroit où se trouve son fantôme, pas son corps.
- **Amnésique déjà recruté :** un Amnésique que le Recruteur a converti reste dissident, même s'il prend ensuite le rôle d'un employé mort.
- **Bouffon et grenades :** une mort par explosion n'a pas de tueur connu du mod ; un employé qui tue le Bouffon à la grenade ne le fait pas gagner.
- **Voleur :** l'objet volé arrive dans la main avec l'animation de ramassage du jeu.
- **Mise à jour du jeu :** elle peut casser le mod. `python tools\lp\bp.py --all analysis\bp` puis `python tools\lp\verify_mod.py` revérifient tout le code contre les nouveaux fichiers du jeu.

## Autres fichiers du projet

- `README.md` et `CHANGELOG.md`, à la racine : présentation du projet et liste des versions.
- `decisions-mod.md` : toutes les décisions prises et les options écartées.
- `idees-mod-lockdown-protocol.md` : les notes d'idées d'origine.
- `analysis\NOTES.md` : fonctionnement interne du jeu ; `analysis\bp\` : pseudo-code des 262 Blueprints (hors du dépôt, refait par `tools\lp\bp.py`).
- `mod\LPRoles\` : source du mod ; `tools\` : outils d'analyse, de vérification et d'installation (`python tools\deploy.py --package` réinstalle le mod et reconstruit l'archive ; `--package-only` construit l'archive de la version des sources sans rien installer).
- `tools\FModel-dec2025\FModel.exe` : FModel, déjà configuré pour le jeu (hors du dépôt).
- `tools\dossier-du-jeu.txt` : le dossier du jeu sur cette machine (hors du dépôt), lu par les outils.

Deux éléments ont été créés hors de ce dossier : `%APPDATA%\FModel\AppSettings.json` (configuration de FModel) et `%LOCALAPPDATA%\Temp\lp\` (bibliothèque de décompression et cache de mes outils).
