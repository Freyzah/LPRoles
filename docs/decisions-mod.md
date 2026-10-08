# Journal des décisions — mod LOCKDOWN Protocol

Décisions prises en autonomie pendant la réalisation du mod, avec les options envisagées.
Les plus récentes sont en bas.

## D1 — Versions des outils téléchargés

- **Décision :** UE4SS `experimental-latest` (v3.0.1-1152, mis à jour le 29/09/2026) et FModel « Aug 2026 », tous deux depuis leurs dépôts GitHub officiels (`UE4SS-RE/RE-UE4SS`, `4sval/FModel`).
- **Options :**
  - UE4SS stable v3.0.1 (février 2024) — écartée : antérieure à UE 5.5.
  - Le paquet UE4SS de Nexus déjà présent dans Téléchargements (mars 2025) — écartée pour les binaires : build ancienne, source moins sûre qu'un dépôt officiel.
- **Emplacement :** archives et FModel dans `tools/` du dossier de la session.

## D2 — Signature GUObjectArray reprise de l'ancien paquet Nexus

- **Constat :** en mars 2025, UE4SS avait besoin d'une signature personnalisée (`UE4SS_Signatures/GUObjectArray.lua`) pour ce jeu. J'ai vérifié que ce motif d'octets existe toujours, une seule fois, dans l'exe actuel et qu'il pointe bien vers la section de données.
- **Décision :** installer ce petit fichier texte (393 octets, relu) avec l'UE4SS officiel.
- **Options :** ne pas l'inclure et laisser UE4SS chercher seul — écartée : risque d'échec au démarrage alors que la signature est vérifiée valide.

## D3 — Je ne lance pas le jeu moi-même

- **Décision :** je n'exécute pas `LockdownProtocol.exe`. Tout test en jeu est laissé à l'utilisateur.
- **Raison :** l'exécutable vient d'une source non vérifiée ; je n'exécute pas ce type de fichier.
- **Conséquence :** l'analyse du jeu se fait en lisant ses fichiers, sans le faire tourner, et le mod est livré non testé en jeu.

## D4 — Pas d'autres téléchargements que ceux autorisés

- **Décision :** seuls UE4SS et FModel sont téléchargés. Pas d'éditeur Unreal Engine 5.5, pas d'outils tiers supplémentaires.
- **Conséquence :** le mod est écrit en **Lua pour UE4SS** (aucun éditeur requis) plutôt qu'en Blueprint.
- **Options :**
  - Mod Blueprint (comme ReviveLP) — écartée pour l'instant : demande l'éditeur UE 5.5 (dizaines de Go, compte Epic).
  - Mod C++ UE4SS — écartée : demande une chaîne de compilation.

## D5 — FModel : deux versions téléchargées

- **Constat :** FModel « Aug 2026 » exige .NET 10, absent de la machine (seul .NET 8 est installé).
- **Décision :** télécharger aussi FModel « Dec 2025 » (même dépôt officiel), qui fonctionne avec .NET 8, et le préconfigurer pour le jeu (dossier `Paks`, UE 5.5).
- **Options :** installer .NET 10 — écartée : installation système non demandée.

## D6 — Lire les fichiers du jeu avec mes propres outils

- **Constat :** FModel ne se pilote qu'à la souris et il lui faut un fichier de « mappings » qui ne s'obtient qu'en lançant le jeu.
- **Décision :** écrire un lecteur en Python (`tools/lp/`) qui ouvre les conteneurs du jeu, décode les Blueprints et produit leur pseudo-code (`analysis/bp/`, 262 Blueprints).
- **Détail :** la décompression utilise la bibliothèque Oodle que FModel télécharge lui-même à son premier lancement.
- **Options :** utiliser la bibliothèque Oodle trouvée dans un autre jeu du disque — écartée : provenance non vérifiée.

## D7 — Le mod doit être installé chez l'hôte ET chez les joueurs

- **Constat :** le Shérif et l'Infecteur peuvent être gérés par l'hôte seul. Le Rêveur et la Fée ont besoin d'un mode fantôme *local* et de textes à l'écran, que seul un mod présent sur la machine du joueur peut produire. Le jeu n'a aucun moyen d'envoyer un texte libre à un joueur.
- **Décision :** un seul mod, identique pour tous. L'hôte décide de tout ; les joueurs qui l'ont installé reçoivent les annonces et peuvent recevoir les rôles Rêveur et Fée. Un joueur sans le mod peut jouer normalement et peut être Shérif, Infecteur ou cible d'infection.
- **Options :**
  - Hôte seul (comme ReviveLP) — écartée : oblige à tuer puis réanimer réellement le Rêveur (cadavre au sol, vie remise à 20, risque de fin de partie prématurée).
  - Mod obligatoire pour tous, sinon exclusion — écartée : inutilement strict.

## D8 — Nom du rôle : « Rêveur »

- **Décision :** « Rêveur » (court, lisible à l'écran). Le nom est une simple chaîne dans `strings.lua`.
- **Options :** « Onironaute » — non retenu par défaut, changeable en une ligne.

## D9 — Comment le Rêveur devient fantôme

- **Décision :** le joueur reste *vivant* pour le jeu. Son écran passe en mode fantôme (même déplacement et mêmes restrictions qu'un mort), et l'hôte fige son corps à l'endroit où il s'est endormi : assis, yeux fermés, pour tous les autres joueurs.
- **Conséquences utiles :** le corps reste un joueur vivant normal, donc on peut le frapper et le tuer ; les conditions de victoire ne sont pas faussées ; il n'y a pas de cadavre.
- **Voix :** le Rêveur est muet pendant le rêve (point laissé « à confirmer » dans les notes d'idées).
- **Options :**
  - Vraie mort puis réanimation — écartée (voir D7).
  - Caméra libre séparée du personnage — écartée : ne se comporterait pas « exactement comme un fantôme mort ».

## D10 — Gestes d'activation

- **Rêveur :** deux yeux fermés pendant 3 s (demande de l'utilisateur). Pour sortir : rouvrir puis refermer les deux yeux.
- **Fée :** double clin d'œil de l'œil droit en moins de 0,7 s (l'utilisateur voulait un moyen différent, rapide à faire en fuite).
- **Infecteur :** voir D12.
- **Raison :** l'hôte reçoit déjà l'état des yeux de chaque joueur ; aucun nouveau bouton à créer.
- **Options pour la Fée :** lever les mains deux fois, double saut — écartées : trop de déclenchements accidentels.

## D11 — Recharge par les plantes

- **Constat :** G3M est la plante verte et WX2 la plante blanche. Le jeu n'a pas d'action « manger une plante ».
- **Décision :** pour recharger, tenir en main un bocal contenant la bonne plante et fermer les deux yeux 3 s. Le bocal est vidé et la charge revient. Pas de cumul : impossible si la charge est déjà pleine.
- **Cas du Rêveur :** s'il a déjà sa charge, le même geste déclenche le rêve et le bocal n'est pas consommé.

## D12 — Mécanique d'infection

- **Décision :** l'Infecteur maintient un clin d'œil gauche en restant à moins de 2,5 m de sa cible pendant 4 s. La cible ne bascule dissidente que 45 s plus tard, et voit alors l'écran d'annonce « dissident » du jeu.
- **Garde-fous par défaut :** 1 infection par partie ; impossible pendant la première minute ; le Shérif est immunisé (la tentative échoue et la charge est perdue).
- **Raison :** pas de plante (demande de l'utilisateur), pas d'objet à créer, et un signe visible (œil fermé, proximité) qui laisse une chance de repérer l'Infecteur.
- **Options :**
  - Seringue à trouver sur la carte — écartée : il faudrait créer un nouvel objet.
  - Frapper la cible avec un objet précis — écartée : trop voyant et lié aux dégâts.
  - Terminal piégé — écartée : cible non choisie, plus complexe.

## D13 — Shérif

- **Carte d'accès :** donnée en main 7 s après le début (une fois l'écran d'annonce passé). Les cartes du jeu n'ont pas de niveau : une carte ouvre une porte verrouillée, une fois.
- **Personne sûre :** un employé tiré au hasard. Le Shérif voit son nom à l'écran et, pendant 20 s, le marqueur que le jeu utilise entre dissidents s'affiche sur cette personne (repli visuel pour un Shérif sans le mod).
- **Si la personne sûre est infectée ensuite :** le Shérif n'est pas prévenu ; l'information était vraie au début.
- **La personne sûre ne sait pas** que le Shérif la connaît.

## D14 — Fée : lumière et invulnérabilité

- **Décision :** pendant la transformation, les joueurs équipés du mod ne voient plus le corps mais un petit point lumineux ; les coups reçus sont annulés sur la machine de la Fée.
- **Limite :** un joueur sans le mod voit encore le corps se déplacer très vite pendant 2-3 s.

## D15 — Réglages dans le lobby

- **Constat :** le menu des règles du jeu est une liste fixe de widgets ; y ajouter des lignes demanderait de créer des widgets et des lignes de table à l'aveugle.
- **Décision :** réglages dans un fichier (`LPRoles-config.txt`), modifiables par l'hôte dans le lobby avec des touches (F6 option suivante, F7/F8 valeur, F9 résumé), avec affichage à l'écran et sauvegarde automatique.
- **Options :** intégration au menu des règles — reportée à une version ultérieure, une fois le mod testé.

## D16 — Un rôle spécial par joueur

- **Décision :** un joueur reçoit au plus un rôle spécial. L'Infecteur est pris parmi les dissidents, le Shérif parmi les employés ; Rêveur et Fée dans le camp choisi par les réglages (par défaut : n'importe lequel).
- **L'Infecteur remplace** un dissident normal (il ne s'ajoute pas au nombre de dissidents).

## D17 — Mods fournis avec UE4SS désactivés

- **Décision :** désactiver `CheatManagerEnablerMod`, `ConsoleCommandsMod` et `ConsoleEnablerMod` dans `mods.txt`. Ils ajoutent un gestionnaire de triche et une console développeur, inutiles au mod.
- **Conservés :** `BPModLoaderMod` (requis par les mods Blueprint comme ReviveLP) et `Keybinds` (raccourcis de dump, utiles pour FModel).
- **Options :** laisser la configuration d'origine — écartée : moins de surface inutile dans un jeu multijoueur.

## D18 — Aides au test

- **Constat :** le mod n'a jamais tourné ; tester un rôle demanderait plusieurs joueurs et de la chance au tirage.
- **Décision :** réglage `force_host_role` (donne à l'hôte le rôle choisi, sans tenir compte du nombre de joueurs) et touche F10 de diagnostic. Les deux sont inoffensifs en partie normale (`force_host_role = none` par défaut).

## D19 — Filets de sécurité

- **Décision :** aucun état spécial ne dépend d'un seul message réseau.
  - Le mode fantôme d'un joueur se termine de lui-même 3 s après la durée annoncée si l'ordre de fin n'arrive pas.
  - L'effet de la Fée chez les observateurs se retire seul après la durée + 2 s.
  - Le corps du Rêveur reste figé jusqu'à 1,5 s après le réveil, le temps que le joueur y soit revenu, pour éviter qu'on voie le corps « sauter » vers l'endroit où était le fantôme.
  - Si le jeu ne détecte pas la fin de partie après une infection (tous les employés convertis ou morts), le mod la déclenche.

## D20 — Coup mortel sur le corps du Rêveur

- **Constat :** la mort du jeu démarre 0,1 s après le coup et s'annule si le joueur n'est pas « vivant » localement — ce qui est le cas en mode fantôme.
- **Décision :** au moindre dégât, le Rêveur est ramené dans son corps immédiatement ; la séquence de mort du jeu, déjà en attente, s'exécute alors normalement à l'emplacement du corps.
- **Fée :** le même mécanisme la rend intouchable, et sa vie est remise à sa valeur d'avant la transformation.

---

# Après le premier test en jeu et la relecture indépendante (version 0.2.0)

## D21 — Protocole joueur → hôte : valeurs 6 et 7

- **Constat (relecture indépendante) :** le jeu transmet l'état des yeux sur 3 bits. Les codes 100 et plus que j'utilisais n'auraient jamais traversé le réseau : aucun joueur distant n'aurait été reconnu comme ayant le mod. Invisible en test solo, où rien ne passe par le réseau.
- **Décision :** n'utiliser que 6 (« j'ai le mod ») et 7 (« je me suis réveillé »), seules valeurs libres qui tiennent sur 3 bits.
- **Conséquence :** le numéro de version n'est plus dans le message ; tous les joueurs doivent avoir la même archive.

## D22 — Réglages dans le menu Échap (remplace D15)

- **Constat (test) :** le bandeau du jeu utilise une très grande police ; les lignes de réglage dépassaient de l'écran.
- **Décision :** ajouter un onglet LPROLES au menu Échap, assemblé à partir des widgets de réglage du jeu lui-même. L'hôte y voit tous les réglages ; chaque joueur y voit son rôle et son mode d'emploi.
- **Bandeaux :** réservés à des messages courts (30 caractères au plus par ligne, découpage automatique).
- **Touches F5 à F9 :** conservées en secours, au cas où l'onglet ne se construirait pas.
- **Options :**
  - Raccourcir seulement les bandeaux — écartée : 34 réglages à faire défiler restent pénibles.
  - Insérer les réglages dans l'onglet « Règles » du jeu — écartée : sa liste n'est visible qu'en difficulté Custom.

## D23 — Yeux du Rêveur

- **Constat (test) :** fermer les deux yeux les verrouille ; le joueur commençait son rêve dans le noir.
- **Décision :** rouvrir les yeux du joueur à l'entrée en fantôme, avec la même séquence que le jeu utilise après une réapparition. Idem au réveil. Le corps, lui, garde les yeux fermés pour les autres.

## D24 — Fée : suppression de l'effet de mort

- **Constat (test) :** le flash et l'étouffement sonore que je déclenchais durent plus longtemps que l'envol.
- **Décision :** aucun effet pour la Fée ; l'effet reste pour le Rêveur (réglable). La durée reste 2,5 s.
- **Options :** allonger l'envol à 5 s — non retenu par défaut puisque l'effet est supprimé ; réglable dans l'onglet (1 à 10 s).

## D25 — Carte du Shérif dans le sac

- **Constat (test) :** la carte en main trahissait le Shérif immédiatement.
- **Décision :** l'hôte inscrit la carte dans l'emplacement « sac » du joueur, sans animation. Si l'écriture directe échoue, repli sur la manière du jeu (prise en main puis échange main/sac) ; si le sac est occupé, en main.
- **Limite :** l'hôte doit connaître le contenu du sac, car il le vérifie quand le joueur sort l'objet ; c'est pourquoi la carte n'est pas seulement ajoutée côté joueur.

## D26 — Annonce d'une infection

- **Constat (relecture) :** l'écran « dissident » du jeu bloque les commandes et coupe le micro environ 6 s.
- **Décision :** un joueur équipé du mod reçoit seulement un message ; l'écran du jeu n'est utilisé que pour un joueur sans le mod, faute d'autre moyen de le prévenir.
- **Infecteur :** choisi de préférence parmi les dissidents équipés du mod, sinon il ne saurait jamais qu'il l'est.

## D27 — Autres corrections issues de la relecture

- **Fin de partie de secours :** ne s'active qu'après une infection réussie. Avant, avec le mod désactivé, la première mort aurait terminé la partie.
- **Réglages non enregistrés :** le chemin du fichier était relatif au mauvais dossier ; il est maintenant déterminé en testant l'ouverture d'un fichier du mod.
- **Nombres dans les messages :** entiers uniquement, pour ne pas dépendre du séparateur décimal de chaque machine.
- **Posture au réveil :** celle d'avant le rêve est rétablie.
- **Bocal :** n'est vidé que s'il est encore en main à l'arrivée de l'ordre.
- **Fée :** un coup mortel reçu dans le dernier dixième de seconde de l'envol ne tue plus.
- **Non corrigé, documenté :** une explosion est calculée à la position du fantôme du Rêveur, pas de son corps.

## D28 — Onglet LPROLES : corrections de la seconde relecture (version 0.2.1)

- **Constat (relecture, vérifié dans le pseudo-code) :** les widgets de réglage du jeu recopient leurs propres variables (nom, bornes, valeur par défaut) à l'écran au moment où on les ajoute à la page. Ce que j'écrivais avant l'ajout était donc écrasé : champs numériques remis à la valeur par défaut du jeu, titres et libellés vides.
- **Décision :** chaque ligne est préparée deux fois, en remplissant ses variables avant l'ajout puis en réécrivant son contenu après. L'une des deux écritures suffit, quel que soit le moment où le jeu dessine la ligne.
- **Flèches des choix :** la liste de valeurs du widget reste vide (c'est le mod qui la tient), ce qui cachait la flèche gauche. L'indice du widget est maintenu à 1 pour garder les deux flèches allumées, et le choix boucle.
  - Option écartée : remplir la liste de textes du widget depuis Lua. Je ne peux pas vérifier que l'outil initialise correctement un tableau de textes ; une erreur là ferait planter le jeu.
- **Textes :** passés comme simples chaînes, la forme déjà éprouvée en jeu par les bandeaux ; la valeur « texte » fabriquée par le moteur ne sert plus que de second essai. *(Remplacé par D29 : l'écriture d'une variable texte faisait planter le jeu.)*
- **Changement de partie :** l'onglet est considéré comme construit tant que le menu contient sa page, et non plus d'après l'adresse du menu, qui peut être réutilisée. Les clics ne sont pris en compte que pour les lignes de la page courante.
- **Construction :** une ligne en échec n'empêche plus les suivantes ni le bouton de l'onglet.
- **Nombres :** arrondis à deux décimales (le champ du jeu rend 0,7 sous la forme 0,699999988). Les lignes se remettent à jour quand un réglage change par les touches de secours.
- **Carte du Shérif :** si le joueur est en train d'échanger main et sac, nouvel essai une seconde plus tard (cinq essais).
- **Non retenu :** signaler au moteur la modification du sac pour la réplication. Sans effet utile (personne ne lit cette valeur côté joueurs) et cela imposerait un numéro interne susceptible de changer à chaque mise à jour du jeu.
- **Limite documentée :** si le sac ne peut pas être écrit directement, le repli passe par la main et joue l'animation de ramassage chez les autres joueurs.

## D29 — Plantage de la 0.2.1 : jamais d'écriture dans une variable texte (version 0.2.2)

- **Constat (test) :** le jeu plantait environ 30 ms après la mise en place des accroches du mod (« EXCEPTION_ACCESS_VIOLATION reading address 0x70 »).
- **Diagnostic :** le rapport de plantage du jeu donne l'adresse de chargement d'UE4SS. J'ai rattaché chaque adresse de la pile à une fonction d'UE4SS grâce à sa table de fonctions et aux messages qu'elles contiennent.
  - Le plantage est dans `push_textproperty`, la fonction d'UE4SS qui écrit une variable texte.
  - Décodée à la main, sa branche « écriture » traite toujours la valeur comme un objet texte du moteur, sans vérifier son type. Une chaîne Lua lui donne un pointeur nul, d'où la lecture à l'adresse 0x70.
  - La première ligne de l'onglet écrivait justement une chaîne dans la variable `Name` d'un widget.
  - Passer une chaîne **en paramètre** d'une fonction fonctionne : les bandeaux de la 0.1.0 le font et s'affichaient. *(Faux, voir D30 : le paramètre des bandeaux est une simple chaîne, pas un texte.)*
  - Les écritures de structures, tableaux et objets vérifient le type et renvoient une erreur au lieu de planter. Les nombres et booléens passent par le même mécanisme que les écritures déjà éprouvées en 0.1.0.
- **Décision :**
  - Le mod n'écrit plus aucune variable texte. Les textes ne passent plus que comme paramètres de fonction (`SetText`, `Rename`), appelés après l'ajout de chaque ligne à la page.
  - Le titre de page, que le jeu prend dans une variable texte du bouton, est réécrit juste après le changement d'onglet (accroche sur `Select Tab`).
- **Options :**
  - Écrire les variables texte avec un objet texte du moteur (le chemin prévu par UE4SS) — écartée : non éprouvé, et une erreur fait planter le jeu.
  - Abandonner l'onglet pour revenir aux seules touches — écartée tant que le chemin corrigé n'a pas échoué en jeu.
- **Garde-fous :**
  - `verify_mod.py` refuse désormais toute écriture dans une variable de type texte. Je l'ai vérifié sur une copie piégée du mod : les trois formes d'écriture sont signalées.
  - Le réglage `menu_tab` (dans `config.txt`) désactive l'onglet sans toucher au reste du mod.

## D30 — Plantage de la 0.2.2 : les textes passent par de vrais objets texte du moteur (version 0.2.3)

- **Constat (test) :** même plantage, même fonction d'UE4SS (`push_textproperty`). Elle était appelée cette fois par le code qui prépare les paramètres d'une fonction (`SetText`), et non plus par l'écriture d'une variable.
- **Erreur de raisonnement corrigée :** j'avais pris les bandeaux de la 0.1.0 pour la preuve qu'une chaîne était acceptée en paramètre texte. Or le paramètre de `Show Message` est une simple chaîne (`str`), pas un texte. Rien n'avait donc jamais prouvé qu'on pouvait passer une chaîne là où le jeu attend un texte.
- **Diagnostic complet :** dans cette build d'UE4SS, tout texte reçu (variable **ou** paramètre) doit être un objet texte d'UE4SS ; une chaîne donne un pointeur nul. UE4SS fournit ces objets lui-même : un constructeur global `FText` et les textes renvoyés par les fonctions du moteur. Vérifié dans son code : à la création, il range le texte à l'octet 0x70 de l'objet, et c'est là que son écriture le relit.
- **Décision :**
  - Chaque texte est fabriqué par le moteur avec `KismetTextLibrary.Conv_StringToText`, qui reçoit une simple chaîne (forme éprouvée par les bandeaux).
  - Son type est contrôlé (`FText`) avant tout usage. S'il n'est pas bon, l'appel n'a pas lieu : le libellé reste vide, mais le jeu ne plante pas.
  - Tous les appels passent par une seule fonction, `G.text_call`.
- **Options :**
  - Le constructeur `FText(...)` d'UE4SS — écarté : il passe par du code d'UE4SS propre à chaque version du moteur, alors que `Conv_StringToText` fait faire le travail au moteur lui-même.
  - Des widgets du jeu qui prennent des chaînes (`W_Settings_CustomSelection`) — écartés : il n'en existe pas pour tous les besoins (titres, valeurs, choix).
  - Abandonner l'onglet — gardé en réserve si cette version plante encore.
- **Garde-fous :**
  - `verify_mod.py` refuse tout appel à une fonction prenant un texte qui ne passe pas par `G.text_call`. Testé sur une copie piégée : `SetText("x")`, `Rename("x")` et l'écriture d'une variable texte sont tous signalés. Le code de la 0.2.2 aurait été refusé.
  - **Désactivation automatique :** le mod note dans `menu_guard.txt` qu'il construit ou met à jour l'onglet. Si le jeu s'arrête à ce moment-là, l'onglet est désactivé au lancement suivant (`menu_tab = false`) et un bandeau le signale. Un nouveau plantage dans l'onglet ne peut donc se produire qu'une fois.

---

# Neuf nouveaux rôles (version 0.3.0)

L'utilisateur a retenu, parmi mes propositions : Médium, Ange gardien, Taupe, Traqueur, Hypnotiseur, Liés, Échangeur, Martyr et Revenant. Il a aussi demandé un autre nom pour l'Infecteur. Les décisions de détail ci-dessous sont les miennes.

## D31 — L'Infecteur devient le Recruteur

- **Décision :** « Recruteur ». Il convertit un employé à la cause des dissidents, ce qui correspond à la mécanique (une conversion, pas une maladie).
- **Options :** Agitateur, Corrupteur, Instigateur, Endoctrineur. Le nom se change en une ligne dans `lpr_strings.lua`.
- **Identifiant interne :** `infector` est conservé, ainsi que les clés de réglage (`infector_*`, `infect_*`), pour ne pas effacer les réglages déjà enregistrés dans `config.txt`.

## D32 — Gestes : réutiliser les trois existants

- **Décision :** un joueur n'a qu'un rôle, donc les nouveaux rôles reprennent les gestes connus :
  - deux yeux fermés 3 s pour les pouvoirs sur soi (Médium, Revenant) ;
  - clin d'œil gauche maintenu pour les pouvoirs sur un autre joueur.
- **Visée :** les pouvoirs ciblés (Ange gardien, Traqueur, Hypnotiseur, Échangeur) visent le joueur **regardé**, et non le plus proche.
  - Le jeu envoie, avec chaque position, le point que regarde le joueur (`Net Aim Target`). La cible est le joueur le plus proche de cet axe (à 18° au plus), dans la portée du rôle.
  - Le nom de la cible s'affiche dès qu'elle est visée, puis le geste doit être tenu 2 s (réglable).
- **Recruteur :** inchangé (le plus proche à 2,5 m, 4 s), pour ne pas modifier ce qui existait.
- **Options :** de nouveaux gestes (double clin d'œil gauche, triple clin d'œil…) — écartés, plus de choses à retenir pour les joueurs. Un tir de rayon pour tenir compte des murs — écarté pour l'instant : il passe par des structures de retour que je ne peux pas tester sans le jeu ; documenté comme limite.

## D33 — Nombre de rôles par partie

- **Constat :** avec 13 rôles et un seul rôle par joueur, presque tout le monde aurait un rôle dans une partie à 6.
- **Décision :** réglage « Rôles spéciaux par partie (max) », 4 par défaut. Chaque partie tire les rôles dans un ordre aléatoire parmi ceux qui sont actifs et dont le minimum de joueurs est atteint.
- **Options :** une priorité fixe (Shérif et Recruteur toujours d'abord) — écartée, les parties seraient toujours les mêmes ; on peut désactiver les rôles dont on ne veut pas.

## D34 — Joueurs sans le mod

- **Décision :** les nouveaux rôles ne sont donnés qu'à des joueurs qui ont le mod (sinon ils ne sauraient pas qu'ils l'ont). Exceptions :
  - Martyr et Liés vont de préférence à des joueurs équipés, mais peuvent aller aux autres, car leur effet fonctionne sans le mod ;
  - Shérif et Recruteur sont inchangés.

## D35 — Choix de mécanismes par rôle

- **Médium :**
  - La fonction du jeu `Death Update` montre ou cache le fantôme et la voix d'un mort, selon que le joueur local est mort ou vivant.
  - Pendant la vision, le mod déclare le joueur local mort le temps d'appeler cette fonction sur chaque mort, puis le remet vivant dans le même instant. L'opération est refaite chaque seconde, pour ceux qui meurent pendant la vision.
  - 2 visions de 10 s par partie, sans plante. La salle botanique reste réservée au Rêveur et à la Fée (règle de l'utilisateur).
- **Ange gardien :**
  - La résurrection du jeu lui-même (`Rez Effect` + `All Rez Effect`, utilisée par son objet de réanimation) relève le protégé 0,1 s après sa mort, à l'endroit de sa mort.
  - Elle marche pour tous, y compris les joueurs sans le mod.
  - Option écartée : annuler le coup mortel avant la mort. Le jeu ne revérifie pas la vie avant de lancer la mort, il faudrait déclarer le joueur mort localement pendant un instant : risqué, et impossible sans le mod.
  - Si le protégé meurt de son lien (Liés), il est aussi relevé, et le lien ne se propage pas.
- **Taupe et Traqueur :**
  - La fonction du jeu qui affiche les sphères remplace, sur l'écran d'un joueur, toutes les sphères par une liste donnée.
  - Après chaque affichage du jeu, l'hôte renvoie une liste corrigée : les dissidents sans la Taupe, la Taupe seule, plus la cible traquée ou la personne sûre du Shérif.
  - La Taupe n'est donnée que s'il y a au moins 2 dissidents.
- **Hypnotiseur :**
  - Fermer les yeux est un état propre à chaque machine : il faut le mod chez la cible. Sans lui, « CIBLE INSENSIBLE » et l'utilisation n'est pas perdue.
  - Pendant l'hypnose, l'hôte ignore les gestes de la cible, pour qu'elle ne déclenche pas son propre pouvoir les yeux fermés.
- **Liés :**
  - L'hôte appelle la mort du jeu (`Death`) sur le partenaire. Si le partenaire rêve ou vole, il est d'abord ramené dans son corps (0,6 s), sinon le jeu ignorerait la mort.
  - Camps des deux liés : au hasard (par défaut), opposés ou identiques.
- **Échangeur :** la téléportation du jeu (`Request TP`), déjà utilisée par la Fée, est envoyée aux deux joueurs. Elle marche même sans le mod.
- **Martyr :**
  - L'hôte retient le dernier attaquant de chaque joueur. Il est révélé si le coup date de moins de 3 s à la mort. Ce délai est court parce que les grenades, le poison et les chutes tuent sans passer par l'enregistrement des attaquants ; avec un délai long, un ancien attaquant serait accusé à tort (voir D37).
  - Seuls les joueurs équipés du mod voient l'annonce : aucune fonction du jeu ne permet d'afficher du texte libre chez les autres.
- **Revenant :**
  - Une lumière est attachée à la partie du personnage qui porte la position du fantôme (`Ghost Root`), et non au corps. Elle suit donc le fantôme.
  - Visible des joueurs équipés du mod. 1 apparition de 3 s.

## D36 — Vérification

- `verify_mod.py` couvre les nouvelles fonctions du jeu : `Death`, `Rez Effect`, `All Rez Effect` et `K2_AttachToComponent`, ainsi que les champs de position et d'orientation de l'état de vie.
- Relecture indépendante faite avant installation ; ses constats sont traités en D37.

## D37 — Corrections issues de la relecture de la 0.3.0

- **Ange gardien et fin de partie :**
  - Quand le dernier employé en vie meurt, le jeu programme sa fin de partie 0,5 s plus tard et ne revérifie pas ensuite. Une résurrection arriverait trop tard.
  - Décision : dans ce cas précis, l'ange ne sauve pas et reçoit « TROP TARD : DERNIER EMPLOYÉ » ; sa protection reste disponible.
  - Le test reprend celui du jeu (`Check Deaths` sur sa liste d'employés) ; il ne s'applique pas en Training, où le jeu ne termine jamais une partie sur les morts.
  - Option écartée : suspendre l'état « en partie » du jeu pendant la résurrection. Trop de fonctions du jeu (coups, fin au chronomètre) l'ignoreraient pendant ce temps.
- **Taupe et liste des joueurs :**
  - La liste des joueurs du jeu marque « DISSIDENT » les autres dissidents, d'après leur rôle affiché. La Taupe y aurait été visible.
  - Décision : la Taupe est affichée comme employée (`Set Player Role`). Elle reste dans la liste des dissidents du jeu, qui décide de la victoire et du message de fin.
  - D'après le code du jeu, ce rôle affiché ne sert qu'à l'interface et au tri des joueurs participants.
  - Sur la machine de la Taupe, les lignes de la liste sont rafraîchies pour retirer les marques déjà affichées.
  - Conséquence : l'écran du jeu dit « employé » à la Taupe ; son aide dans l'onglet LPROLES le signale.
- **Visée :**
  - Le point regardé, envoyé par le jeu, est l'endroit où la vue touche un obstacle. Une cible plus éloignée que ce point est derrière un mur et n'est plus retenue.
  - Une cible déjà visée est gardée dans un cône plus large (25°) et malgré une perte de moins de 0,3 s.
  - Chaque cible n'est nommée qu'une fois par clin d'œil, pour ne pas remplir la file des bandeaux.
- **Hypnotiseur :** les yeux sont refermés dès qu'une touche d'œil est pressée ou relâchée, et quand le jeu les rouvre lui-même (à chaque mort). Avant, on pouvait entrevoir pendant un dixième de seconde.
- **Médium :** quand quelqu'un meurt ou revient pendant la vision, le jeu recache les fantômes ; la vision les réaffiche au dixième de seconde suivant, au lieu de la seconde suivante.
- **Revenant :**
  - Le jeu recache le fantôme, et ce qui y est attaché, à chaque mort ou retour ; la lumière est rallumée aussitôt après.
  - Un geste commencé juste avant la mort ne compte plus.
  - La lumière est placée plus bas : la partie « fantôme » est 1,6 m au-dessus du sol.
- **Divers :**
  - Un recrutement en attente n'est plus annulé si le joueur est relevé par l'ange.
  - La mort d'un lié est redemandée 1,8 s plus tard si le jeu l'a ignorée.
  - Rien ne se déclenche plus après la fin de partie : un message « END » arrête visions, hypnoses et lumières.
  - Les sphères sont aussi corrigées après un recrutement.
  - Le rôle forcé pour l'hôte n'est exclu du tirage que s'il a vraiment été donné.
- **Non corrigé, documenté :** si une traque ou un marqueur du Shérif commence pendant l'envol d'une Fée, sa sphère peut s'éteindre à la fin de l'envol (fenêtre de 2,5 s).

## D38 — Touche « consommer l'objet en main » (version 0.3.1)

- **Demande :** une touche pour consommer l'objet tenu en main, utilisée par les pouvoirs à la place de « fermer les yeux », idéalement configurable dans le menu des touches du jeu ou dans LPROLES.
- **Décision :**
  - Touche lue par UE4SS, **G** par défaut. Chaque joueur la choisit dans l'onglet LPROLES, nouveau groupe **TOUCHES**, visible de tous (les autres réglages restent à l'hôte).
  - Choix limité aux lettres que le jeu n'utilise pas. Je les ai lues dans ses quatre tables de touches : il utilise A C D E F H K Q R S T U V W X Z, les flèches et la souris. J et O sont aussi écartées, car UE4SS s'en sert avec Ctrl pour ses outils.
  - La touche est envoyée à l'hôte avec un code libre du canal joueur → hôte (5). L'hôte vérifie l'objet en main, recharge et vide le bocal, avec les mêmes contrôles qu'avant.
  - La recharge en fermant les yeux est désactivée par défaut, comme demandé (« à la place »), mais l'hôte peut la réactiver. Un rappel « RECHARGE : TOUCHE G » s'affiche quand un joueur manque de charge.
  - La touche est ignorée menu Échap ou tablette ouverts, et pour les rôles sans objet. Les rôles concernés sont dans une table, pour en ajouter d'autres plus tard.
- **Le menu des touches du jeu, écarté pour l'instant :**
  - Ce menu se construit à partir des « actions » du système de saisie du moteur, déclarées dans les tables de touches du jeu.
  - Y ajouter une entrée demanderait de créer une nouvelle action, de l'insérer dans la table du joueur, de la déclarer modifiable, et que l'interface du jeu la reprenne. Il faudrait ensuite réagir à cette action depuis Lua.
  - Tout cela touche à l'enregistrement des touches du joueur : une erreur pourrait abîmer ses réglages de touches. Et rien ne peut être essayé sans lancer le jeu.
- **Limite UE4SS :** une touche enregistrée ne peut pas être changée ensuite. Toutes les lettres autorisées sont donc enregistrées, et seule celle choisie agit.

## D39 — Pas de mains pour le fantôme (version 0.3.2)

- **Demande :** que le Rêveur ne voie ni sa main ni l'objet tenu pendant qu'il est fantôme.
- **Constat :** les mains à la première personne sont un composant à part du personnage (`SkM Hands`). L'objet tenu, la tablette et l'effet d'arme sont des acteurs attachés (`HandMesh`, `Hand Tablet`, `Hand FX`), plus une breloque et un poisson (`Charm Mesh`, `FishMesh`). Le jeu ne les cache jamais lui-même : un vrai mort a lâché ses objets.
- **Décision :**
  - À l'entrée en fantôme, le mod cache ces éléments sur la machine du joueur seulement. Les autres joueurs ne voient de toute façon jamais les mains à la première personne.
  - Seuls les éléments visibles sont cachés, et seuls ceux-là sont réaffichés au retour : par exemple, une tablette rangée n'est pas montrée par erreur.
  - Appliqué aussi à la Fée, dont le fantôme a, selon le cahier des charges d'origine, les mêmes propriétés que celui du Rêveur. Il suffit de retirer une ligne pour la Fée si ce n'est pas souhaité.
- **Option écartée :** cacher les mains en masquant tout ce qui dépend d'elles d'un seul coup. Cela réafficherait au retour des éléments que le jeu avait volontairement cachés.

## D40 — Onglet LPROLES placé après « Règles » (version 0.3.3)

- **Demande :** placer l'onglet juste après « Règles », avant l'espace qui sépare les onglets de partie des onglets de réglages.
- **Contraintes :**
  - Les fonctions du moteur qui insèrent un élément au milieu d'une colonne (`InsertChildAt`, `ShiftChild`) n'existent pas dans ce jeu.
  - Une colonne déjà affichée ne redessine que ce qu'on ajoute à sa fin.
- **Décision :**
  - Le bouton est ajouté en fin de colonne comme avant. Puis les éléments qui suivent « Règles » (l'espace et les onglets de réglages) sont retirés et remis après lui, chacun avec ses marges, sa taille et son alignement.
  - Un élément retiré est toujours remis, même si un autre échoue.
  - La page ouverte par chaque onglet ne change pas : le jeu numérote ses onglets une fois pour toutes à la construction du menu, et non selon leur place.
  - « Règles » est reconnu par le nom de son bouton dans le menu du jeu (`TabButton_Rules`). S'il est introuvable, l'onglet reste en bas, comme avant.
- **Options écartées :** reconstruire toute la colonne. La disposition de la colonne dans le menu serait perdue, et le jeu ajouterait ses onglets une seconde fois à sa liste.

## D41 — Bocal sale après consommation (version 0.3.4)

- **Demande :** après avoir mangé la plante, le bocal doit être sale, pas propre.
- **Constat (code du jeu) :**
  - Le contenu d'un bocal est un nombre : 0 pour un bocal propre, 1 à 6 pour les contenus, et un nombre négatif pour un bocal sale, dessiné avec le matériau `M_SampleContainer_Neutral`.
  - La centrifugeuse laisse le bocal à -1 après en avoir extrait l'échantillon ; le nettoyeur de bocaux le remet à 0.
- **Décision :** le mod met le bocal à -1, avec la même fonction du jeu qu'avant (`Set Sample`), qui met à jour l'objet en main et prévient l'hôte. Le joueur doit donc passer par le nettoyeur, comme pour un bocal utilisé normalement.

## D42 — Métamorphe (version 0.4.0)

- **Idée de l'utilisateur :** un rôle de dissident qui prend la peau exacte de quelqu'un d'autre pendant quelques instants.
- **Nom :** « Métamorphe ». Autres possibilités : Caméléon, Usurpateur, Imitateur. « Imposteur » est écarté, car le jeu appelle déjà ainsi les dissidents.
- **Constat (code du jeu) :**
  - L'apparence complète tient dans une valeur répliquée, `Appearance` : une couleur, et 17 éléments (modèles et matériaux du corps, tête, capuche, masque, visage, yeux, cheveux, deux écussons, breloque, lumière, teinte de peau).
  - Chaque machine redessine le personnage dès que cette valeur change.
  - Une ancienne valeur, `Skin Set`, existe encore mais n'est plus ce qui est dessiné. Ma première version la copiait par erreur ; la relecture l'a relevé avant l'installation.
- **Décision :**
  - L'hôte copie `Appearance` du joueur visé sur le Métamorphe et la signale au moteur pour la réplication (`MarkPropertyDirty`, par nom, pour ne pas dépendre d'un numéro interne). Ce sont les mêmes étapes que la fonction du jeu `Net Set Appearance`, sauf sa règle de couleur : appliquée ici, elle donnerait à la copie une couleur libre au lieu de celle de la cible.
  - Tout le monde voit le déguisement, y compris les joueurs sans le mod.
  - Retour à la vraie apparence au bout de 15 s (réglable), à la mort et en fin de partie. À la mort, le retour part dans le même instant que la mort, pour que le corps vu par les autres montre en principe qui c'était vraiment.
  - Geste : le même que les autres rôles ciblés (regarder + clin d'œil gauche maintenu). 2 utilisations par partie.
- **Risque traité :**
  - Quand l'apparence d'un joueur change, sa propre machine l'enregistre sur le disque comme sa personnalisation. Sans précaution, le déguisement remplacerait pour de bon le skin du Métamorphe.
  - Son mod garde une copie de sa vraie apparence, prise à l'annonce du rôle. Pendant le déguisement, juste après chaque enregistrement du jeu (emplacement `Save_Appearance2`), il réécrit cette apparence dans le préréglage courant, avec la couleur, et réenregistre.
  - Un compteur empêche une ancienne minuterie d'arrêter la protection pendant un déguisement suivant. Les copies sont effacées en fin de partie.
  - L'hôte prévient la machine du Métamorphe 0,5 s avant de changer l'apparence.
- **Limites :** la voix, le nom dans la liste des joueurs et la sphère vue par les autres dissidents ne changent pas. C'est voulu : ce sont des indices pour les autres joueurs.

## D43 — Page du rôle sur la tablette (version 0.4.0)

- **Demande :** une page de la tablette avec les détails du rôle, et des flèches aux deux bouts du bandeau du haut pour changer de page.
- **Constat (code du jeu) :**
  - Les boutons de la tablette ne reçoivent pas de vrais clics. Leur « déclencheur » compare la position du curseur virtuel à sa propre zone, et s'abonne au clic de la tablette en trouvant celle-ci par le personnage du joueur. Un bouton ajouté par le mod fonctionne donc comme ceux du jeu.
  - Le jeu ne change jamais la visibilité des éléments de l'écran de partie (il ne bouge que le curseur).
- **Décision :**
  - Deux boutons du jeu, « < » et « > », sont ajoutés à l'écran de partie de la tablette, avec le style de « Retourner au lobby », ainsi qu'un panneau de texte (police et couleur de ce même bouton).
  - « > » cache la liste des tâches et la carte et montre le panneau ; « < » rétablit l'état exact d'avant.
  - La tablette est dessinée dans le monde, donc les positions sont mesurées une fois l'écran affiché, d'après la liste des tâches et le bandeau du haut. Le bandeau est cherché parmi les éléments de l'écran ; s'il n'y est pas, sa place est déduite des proportions de la capture d'écran envoyée par l'utilisateur.
  - Toutes les mesures sont écrites dans `UE4SS.log`, pour ajuster après le premier essai.
  - Mêmes protections que l'onglet du menu : textes par `G.text_call`, construction tout ou rien, désactivation automatique après un plantage, réglage personnel pour la couper.
- **Options écartées :**
  - Une page séparée dans le sélecteur d'écrans de la tablette : le jeu y revient de lui-même à certains moments, et il aurait fallu recréer le bandeau.
  - Réutiliser les pages du tutoriel : réservées à son propre contenu (images).

## D44 — Page de la tablette : diagnostic (version 0.4.1)

- **Constat (test) :** rien sur la tablette, et aucune ligne « Tablette » dans le journal. La construction n'a jamais été tentée : soit l'écran de la tablette n'était pas trouvé, soit il n'était jamais jugé prêt. Ces vérifications échouaient sans rien écrire.
- **Décision :**
  - L'écran est maintenant trouvé par la tablette en main (`Hand Tablet` → `Screen`), le lien que le jeu lui-même utilise. La recherche par propriétaire reste en secours.
  - Chaque raison de ne pas construire est écrite dans le journal quand elle change (« Tablette : … »).
  - Si la mesure de l'écran dessiné échoue, les positions sont prises dans la disposition prévue par le jeu (position et taille de chaque élément), quand il est ancré en un seul point.

## D45 — État du rôle et explications chiffrées (version 0.4.2)

- **Demande :** que la page du rôle dise où en sont les utilisations et comment activer le pouvoir, avec les détails (par exemple les 3 s du Rêveur).
- **Constat :** les compteurs et les réglages n'existent que chez l'hôte. La machine d'un joueur ne connaît ni ses utilisations restantes, ni les durées et portées choisies par l'hôte (son propre `config.txt` peut être différent).
- **Décision :**
  - Chaque seconde, l'hôte calcule pour chaque joueur équipé du mod l'état de son rôle et le lui envoie seulement s'il a changé. L'état contient les utilisations, l'effet en cours et son temps restant, la cible et les réglages utiles.
  - Le message ne contient que des nombres (secondes en dixièmes, distances en mètres, joueurs par numéro), pour ne dépendre ni des accents ni du séparateur décimal.
  - Le texte est composé sur la machine du joueur, à partir de modèles dans `lpr_strings.lua` : une ligne d'état, puis jusqu'à cinq lignes d'explication avec les valeurs, la touche de consommation du joueur et le code de la plante.
  - Un même module (`lpr_roletext.lua`) sert l'onglet du menu et la page de la tablette.
- **Vérification :** un script croise les modèles de texte et les valeurs envoyées par l'hôte, pour chaque rôle : aucune valeur manquante.

## D46 — Mise en forme de la page de la tablette (version 0.4.3)

- **Demande :** mettre la ligne d'état en évidence, et éviter le bloc de texte uniforme (gras, couleur sur certains mots).
- **Options :**
  - Texte enrichi du moteur avec la table de styles du jeu (`DT_RichText_Custom` : Bold, Default, Purple, Purple_Big) — écarté. Ces styles sont faits pour les panneaux du décor, et leurs tailles et couleurs ne sont pas lisibles sans lancer le jeu.
  - Créer une table de styles depuis Lua — écarté, trop fragile.
- **Décision :**
  - Chaque ligne est découpée en mots. Chaque mot est un texte du moteur, rangé dans une boîte qui passe à la ligne au bord.
  - Les mots mis en avant (valeurs, et mots entre étoiles dans les modèles) passent en gras et en couleur. Le gras est la graisse « Bold » de la police des boutons de la tablette, celle que le jeu utilise déjà.
  - Le titre est plus grand et en couleur. La ligne d'état est en gras dans un bandeau (cadre coloré) : vert si un effet est en cours, orange si le pouvoir est épuisé ou à recharger, bleu sinon.
  - Seules les lignes qui ont changé sont redessinées.
- **Sécurité :**
  - La police et la couleur de référence (celles du bouton « Retourner au lobby ») ne sont jamais modifiées : chaque texte en reçoit une copie, modifiée sur place.
  - Le nom de la graisse est un vrai nom moteur (`FName`), jamais une chaîne : comme pour les textes, UE4SS ne vérifie pas le type à l'écriture.
- L'onglet du menu Échap garde un texte simple, sans les étoiles.

## D47 — L'écran de la tablette et ses « encres » (version 0.5.0)

- **Constat (test) :** sur la page de la 0.4.3, le même violet ressortait en rouge, gris ou vert selon l'endroit. Le bandeau translucide se découpait en blocs de couleurs, et des morceaux de lettres étaient gris.
- **Diagnostic (fichiers du jeu) :**
  - Le matériau de l'écran (`Mat_WorldTabletScreen`) a 7 couleurs de palette (`Color 1` à `Color 7`).
  - Les boutons du jeu ont un texte rouge pur (1,0,0), qu'on voit pourtant sombre à l'écran, et leurs quatre styles n'utilisent que des valeurs pures : (1,0,0), (0,1,0), (0,0,0), (1,1,1).
  - L'écran lit donc chaque pixel comme une combinaison de canaux allumés ou éteints (7 combinaisons, 7 couleurs) et trame les valeurs intermédiaires.
- **Décision :**
  - Uniquement des valeurs pures. Le texte et le gras utilisent l'encre (1,0,0) du jeu.
  - La ligne d'état est en (0,0,0) sur un bandeau plein (1,0,0), soit l'aspect d'un bouton du jeu survolé.
  - Couleur des noms de plantes : faute de pouvoir lire la palette sans lancer le jeu, un test en mode débogage affiche les 8 combinaisons, numérotées. Les couleurs seront choisies d'après la capture de l'utilisateur.
- **Option écartée :** deviner la palette d'après les couleurs des salles sur la carte. Je ne sais pas quelle combinaison donne quelle couleur, et une erreur redonnerait les mêmes défauts.

## D48 — Son personnalisé à la consommation (version 0.5.0)

- **Demande :** un son personnalisé, pas un son du jeu, quand on consomme une plante.
- **Constat :** le jeu intègre le lecteur multimédia du moteur avec Windows Media Foundation (qui lit WAV et MP3), celui des vidéos de la tablette.
- **Décision :**
  - Le fichier `sounds/consume.mp3`, sinon `sounds/consume.wav`, du dossier du mod est lu par ce lecteur : un composant sonore ajouté au personnage local, un lecteur qu'il garde en vie, et une source « fichier » neuve à chaque lecture.
  - Joué seulement sur la machine de celui qui consomme, pour ne pas trahir son rôle.
  - Son provisoire généré par mes outils (aucun téléchargement), à remplacer par l'utilisateur.
  - Coupure dans MES RÉGLAGES.
- **Options écartées :**
  - Lancer un lecteur Windows externe : une fenêtre de console pourrait apparaître par-dessus le jeu.
  - Empaqueter un son dans les fichiers du jeu : il faudrait l'éditeur Unreal, que je n'installe pas (D4).

## D49 — Clandestin (version 0.5.0)

- **Idée de l'utilisateur :** un rôle des deux camps qui se cache dans les bouches d'aération une vingtaine de secondes.
- **Constat :** les bouches sont de vrais objets du jeu (`Vent`, la tâche des filtres).
- **Décision :**
  - Près d'une bouche (2,5 m), deux yeux fermés 3 s : cachette de 20 s, 2 fois par partie (réglable). On sort plus tôt en refermant les deux yeux.
  - L'hôte envoie le corps du joueur 300 m sous la bouche, avec le même mécanisme que le corps endormi du Rêveur. Il disparaît donc pour tous, joueurs sans le mod compris, et devient intouchable. À la sortie, il réapparaît là où il s'était caché.
  - Sur sa machine, le joueur ne peut plus bouger (`Lock Movements`, réimposé car le jeu le change lui-même) et ne voit plus ses mains.
- **Options écartées :**
  - Faire de lui un fantôme mobile : ce serait un rôle d'espion, pas une cachette.
  - Voyager de bouche en bouche : possible plus tard.
- **Nom :** « Clandestin ». Autres possibilités : Rôdeur, Furtif.

## D50 — Nettoyeur (version 0.5.0)

- **Idée de l'utilisateur :** un rôle dissident qui fait disparaître un cadavre, rendant la réanimation impossible.
- **Constat (code du jeu) :**
  - Sur la machine du mort, le cadavre est un objet à part (`DeadBody`).
  - Ailleurs, le corps est celui du personnage mort lui-même.
  - La réanimation passe par le défibrillateur, qui doit toucher le corps.
- **Décision :**
  - Clin d'œil gauche maintenu 3 s près d'un cadavre (2,5 m), 2 fois par partie.
  - Sur chaque machine équipée du mod, le corps est caché, il ne peut plus être touché, et l'objet cadavre est détruit.
  - Si une réanimation a lieu quand même (par un joueur sans le mod, qui voit encore le corps), l'hôte refait mourir le joueur aussitôt et cache de nouveau le corps.
- **Limite :** le corps reste visible des joueurs sans le mod. Aucune fonction du jeu ne permet de le retirer chez eux.

## D51 — Corrections issues de la relecture de la 0.5.0

- **Clandestin :**
  - Il pouvait encore frapper et interagir : `Lock Movements` n'empêche que de marcher. Le mod coupe aussi `Local Can Interact` (le contrôle que le jeu fait avant chaque action) et le réimpose.
  - En sortant par les yeux fermés, une nouvelle cachette partait 3 s plus tard (le jeu renvoie l'état « yeux fermés » au relâchement des touches). Les yeux sont rouverts à la sortie, et l'hôte attend de les voir ouverts avant de compter un nouveau geste.
  - Le corps était envoyé 300 m plus bas, au risque de sortir de la zone que le moteur transmet aux autres joueurs. Il est maintenant à 40 m, et l'hôte force sa transmission pendant la cachette (`bAlwaysRelevant`).
  - Un joueur caché ne peut plus être visé par les autres pouvoirs (utile quand l'hôte est lui-même caché).
  - La tablette est rangée avant de se cacher.
  - À la sortie, la tête regarde droit devant.
  - Si le joueur meurt caché (dégâts de zone), les machines équipées du mod remettent le corps à l'endroit de la mort.
- **Nettoyeur :**
  - Les collisions coupées n'étaient jamais rendues ; or le personnage est réutilisé d'une partie à l'autre. Elles sont notées pièce par pièce et rendues si le joueur revit plus de 2 s ou en fin de partie.
  - Toutes les pièces du personnage sont rendues intouchables, pas seulement le corps et la tête.
  - Refaire mourir un joueur réanimé n'est plus traité comme une nouvelle mort : pas de nouveau lien tué, pas d'annonce de Martyr.
- **Son :** le lecteur n'était tenu que par une référence faible, et le ramasse-miettes du moteur l'aurait libéré. Il est maintenant tenu par la propriété du composant. Un échec d'ouverture du fichier est noté dans le journal.
- **Tablette :**
  - La couleur de référence était lue en direct sur le bouton « Retourner au lobby », qui change de couleur quand le curseur le survole. Elle est copiée une fois dans un modèle propre au mod, avec l'encre sombre.
  - Bandeau vide caché pour les joueurs sans rôle.
  - Puce « - » au lieu de « • », dont la police n'a peut-être pas le dessin.
  - Le test de palette suit tout de suite le réglage de débogage.

## D52 — Couleur des noms de plantes sur la tablette (version 0.5.1)

- **Test de l'utilisateur (0.5.0) :**
  - Le texte sombre est net partout.
  - Les pastilles avec du vert (2, 4, 6, 7) sont d'un blanc lumineux. Leur halo grisait le texte juste au-dessus : ce n'était pas un défaut d'encre.
  - Le rouge seul est sombre. Le bleu, seul ou avec du rouge, est gris.
  - Aucune couleur n'apparaît. L'hypothèse de D47 (une couleur de palette par combinaison) était fausse.
- **Analyse des fichiers du jeu :**
  - Le matériau de l'écran contient une image des pièces de la station : chaque pièce y a son niveau de gris, de 1 à 7.
  - Les paramètres `Color 1` à `Color 7` et `Emissive 1` à `Emissive 7` donnent la couleur de chaque pièce sur la carte : rouge (caméras), jaune (bureaux), vert (botanique), gris (restaurant), cyan (hôpital), orange (stockage), bleu (machines).
  - Le bleu de l'interface est donc l'encre « couleur de la carte » : il prend la couleur de la pièce située à cet endroit de l'écran.
  - En plaçant cette image sur la zone de la carte (et en la répétant hors de celle-ci), on retrouve exactement les taches de la version 0.4.3 : rose sur la pièce des caméras, vert sur la botanique, kaki sur les bureaux, gris ailleurs.
  - Les autres paramètres : `Color A` est le fond de l'écran, `Color B` l'encre sombre (le rapport de luminosité mesuré correspond), `eColor` le blanc lumineux.
- **Décision :**
  - Pendant que la page du rôle est affichée, la carte est cachée. Le mod règle alors les 7 couleurs de pièces (et leurs versions lumineuses) sur la couleur de la plante citée sur la page, et écrit son nom à l'encre bleue.
  - Hors des pièces, l'encre bleue donne un gris très proche de celui de la pièce n° 4 (restaurant), sans doute le même paramètre : le nom sortirait alors dans la couleur de la plante où qu'il soit. Sinon, il resterait gris hors des pièces : c'est ce que la capture de la 0.5.1 dira.
  - Les valeurs d'origine sont lues avant et remises dès qu'on revient aux tâches, quand la tablette quitte l'écran de partie, ou quand la page change de tablette. Si la lecture échoue, rien n'est changé et le nom reste en gras sombre.
  - Les couleurs sont celles de l'écran lui-même : G3M = vert de la botanique, Y8Z = jaune des bureaux, BO4 = cyan de l'hôpital, RU2 = rouge des caméras. WX2 (blanc) prend le blanc lumineux, sans rien régler.
  - Chaque rôle ne cite qu'une plante : une seule couleur à la fois suffit.
  - Le réglage ne concerne que la copie du matériau propre à la tablette en main du joueur local. Il est refait toutes les 2 s, car le jeu recrée le matériau après une vidéo.
  - Le test des pastilles est retiré : il a rempli son rôle.
- **Options écartées :**
  - Placer chaque nom de plante au-dessus d'une pièce de la bonne couleur : la mise en page dépendrait de la carte, au pixel près.
  - Remplacer le matériau de l'écran par un matériau neutre pendant la page : toute la tablette (boutons du jeu compris) s'afficherait en rouge sur noir.
  - Changer `Color B` (couleur hors des pièces) : c'est en fait l'encre sombre de tous les textes.
- **Relecture indépendante (aucun défaut grave) :**
  - Changement de plante sur le même écran : les couleurs de la carte déjà notées sont gardées, au lieu d'être relues après une remise qui aurait pu échouer.
  - Les couleurs ne sont réglées que si l'écran en main est bien celui qui affiche la page.
  - La page s'affiche même si son remplissage échoue : jamais d'écran vide.
  - Après une vidéo, les couleurs sont remises aussitôt, sans attendre 2 s.
  - Un échec de lecture n'est tenté et noté qu'une fois par écran. Le rafraîchissement n'écrit plus le fichier de garde.
  - Quand la page est abandonnée (nouvelle tablette), la carte et la liste des tâches sont réaffichées.

## D53 — Plantage en fin de session (version 0.5.2)

- **Constat (test à deux de la 0.5.1) :** le jeu de l'hôte plante quand il termine la session. Au redémarrage, le mod indique que le jeu s'est arrêté pendant une opération de la page de la tablette (garde déclenchée), et a désactivé la page.
- **Rapport de plantage :**
  - Écriture à une adresse invalide (0x0000008000000008), sur l'instruction qui augmente le compteur d'un pointeur partagé du moteur (`lock inc [rax+8]`).
  - Elle venait de la copie d'une police (`FSlateFontInfo`, dont la police composite partagée est à +0x30), lancée par UE4SS pour un appel de fonction fait depuis le Lua.
- **Cause :**
  - En 0.5.0, la page créait un texte « modèle » invisible pour garder la police et la couleur des boutons de la tablette. Ce modèle n'était rattaché à rien.
  - Le mod gardait la police et la couleur lues sur ce modèle. Avec UE4SS, une telle valeur n'est pas une copie : elle pointe dans la mémoire de l'objet.
  - Le nettoyage automatique du moteur a supprimé le modèle (rien ne le référençait). À la fin de la partie, le texte de la page a changé (plus de rôle), et le mod a copié la police depuis la mémoire libérée.
  - En solo, les lignes de la page ne changeaient pas après ce nettoyage : d'où l'absence de plantage jusque-là.
- **Correction :**
  - Le modèle est placé dans la page elle-même, replié (invisible, sans place) : il vit aussi longtemps qu'elle.
  - La police et la couleur ne sont plus gardées : elles sont relues sur le modèle à chaque texte, après avoir vérifié qu'il existe encore.
  - La taille de police est gardée sous forme de simple nombre.
  - Vérification du reste du mod : les positions, apparences et visées étaient déjà copiées en valeurs simples ; aucun autre objet créé n'est laissé sans rattachement.
- **Règle retenue :** ne jamais garder une valeur lue sur un objet du jeu (structure, tableau) au-delà de l'instruction qui la lit ; copier les nombres, ou relire l'objet au moment voulu. Tout objet créé par le mod doit être rattaché à un objet du jeu.
- **Page désactivée :** la garde a mis `tablet_page = false` dans le `config.txt` de l'hôte. Elle se réactive dans MES RÉGLAGES (« Page du rôle sur la tablette »).
- **Relecture indépendante (correction approuvée) :** trois points mineurs corrigés en plus.
  - Métamorphe : l'apparence d'origine gardait les modèles et matériaux sous forme de liens vers les objets du jeu. Ils sont maintenant gardés avec leur nom complet, et retrouvés par ce nom si le lien n'est plus valable. Si une pièce est introuvable, l'apparence n'est pas écrite (message dans le journal) au lieu de risquer un plantage.
  - Si le texte modèle disparaissait quand même, le journal le signale une fois.
  - Quand la page est reconstruite sur le même écran, l'ancienne page et ses flèches sont retirées.

## D54 — Fin du son de consommation coupée (version 0.5.3)

- **Constat (utilisateur) :** son propre son (0,56 s, WAV 48 kHz stéréo) est coupé un peu avant la fin.
- **Cause :**
  - Le composant sonore du lecteur multimédia du moteur (`MediaSoundComponent`) ne lit les échantillons que tant que le lecteur « joue ».
  - Dès que le lecteur a lu la fin du fichier, il s'arrête et le composant jette ce qui restait en attente. Le décodage ayant de l'avance sur l'écoute, ce reste est la fin du son.
- **Décision :**
  - Le mod joue une copie du fichier suivie d'une seconde de silence : c'est le silence qui est coupé, pas le son.
  - WAV : le bloc des échantillons est allongé (zéros, ou 128 pour du 8 bits) et les tailles du fichier sont corrigées. MP3 : des trames muettes sont ajoutées (même en-tête, contenu vide), et le nombre de trames de l'en-tête Xing/Info est mis à jour.
  - La copie est écrite dans le dossier du mod, sous un nom tiré du contenu du fichier (`LPRoles-son-<empreinte>.wav`) : le même son donne toujours la même copie, un son modifié en donne une nouvelle (le lecteur peut garder l'ancienne ouverte). En cas d'échec, le fichier est lu tel quel, comme avant. Fichiers de plus de 16 Mo lus tels quels.
  - Vérifié hors du jeu : le WAV de l'utilisateur passe de 0,562 s à 1,562 s, échantillons d'origine intacts ; deux MP3 sont lus par Windows avec 1 s de plus.
- **Options écartées :**
  - Lecture en boucle arrêtée au bon moment : le retard entre décodage et écoute n'est pas connu, le début du son se ferait entendre.
  - Demander aux joueurs d'ajouter du silence eux-mêmes : piège invisible pour qui change le son.
- **Mises à jour :** l'installation ne remplace plus un son déjà présent dans le dossier du jeu, et ne supprime plus rien dans `sounds`. L'archive des joueurs prend les sons du dossier du jeu, donc le son choisi par l'hôte.
- **Relecture indépendante :**
  - Point moyen corrigé : la première version écrivait la copie dans le dossier temporaire de Windows. Avec un nom d'utilisateur accentué, ce chemin arrive mal au lecteur du jeu (codage des caractères) et aucun son n'aurait été joué. La copie va maintenant dans le dossier du mod, dont le chemin sert déjà au son d'origine.
  - Points mineurs corrigés :
    - En-tête Xing cherché au bon endroit quand le MP3 a des sommes de contrôle.
    - Blocs après les échantillons d'un WAV supprimés (un WAV mal formé pouvait les abîmer).
    - Nombre d'échantillons du bloc `fact` mis à jour. WAV vide refusé.
    - Première trame MP3 confirmée par la trame suivante.
    - Échec d'écriture détecté jusqu'à la fermeture du fichier. Copie supprimée entre-temps refaite.
    - L'archive des joueurs ne prend que les `.wav` et `.mp3` du dossier `sounds`. L'installation supprime les anciennes copies (refaites au besoin).
  - Tests hors du jeu, sur une copie Python ligne à ligne du code Lua : son de l'utilisateur, WAV 8 bits impair suivi d'un bloc LIST, WAV flottant avec `fact`, WAV 24 bits, WAV vide, deux MP3. Tous corrects ; Windows lit chaque copie avec 1 s de plus.

## D55 — Aucun rôle pour le second joueur (version 0.5.4)

- **Constat (utilisateur) :** à deux joueurs, l'ami ne reçoit aucun rôle, même avec beaucoup de rôles activés.
- **Cause établie :** dans les réglages de l'hôte, tous les rôles activés ont « Joueurs minimum » à 4 ou 5 (valeurs par défaut). À deux joueurs, aucun n'atteint son minimum. Seul le « Rôle forcé pour l'hôte » passe outre, d'où un rôle pour l'hôte et rien pour l'ami. Le mod ne disait rien de cette raison, ni à l'écran ni dans le journal.
- **Ce que je n'ai pas pu vérifier :** si la machine de l'ami est bien reconnue comme ayant le mod. Le journal de cette partie n'existe plus : UE4SS recommence son journal à chaque lancement du jeu, et le dernier lancement était une partie solo.
- **Décisions :**
  - L'hôte reçoit, avec l'annonce des rôles, « N RÔLE(S) NON ATTRIBUÉ(S) : RÉGLAGE JOUEURS MINIMUM » et, si c'est le cas, « N JOUEUR(S) SANS LE MOD ».
  - Le journal note chaque joueur (camp, avec ou sans le mod) et, pour chaque rôle activé que personne ne reçoit, la raison : minimum de joueurs, pas assez de dissidents, pas de joueur libre du bon camp ou avec le mod.
  - Nouveau réglage de test « Ignorer les joueurs minimum » (groupe TEST, désactivé par défaut), pour les essais à deux.
  - Le mod tient son propre journal, `journal.txt` dans son dossier, conservé d'un lancement à l'autre (lignes détaillées exclues ; archivé au-delà de 300 Ko). Chaque joueur a le sien : celui de l'ami dira si l'hôte l'a reconnu et quel rôle il a reçu.
  - Chaque joueur est prévenu si sa version du mod diffère de celle de l'hôte.
- **Options écartées :**
  - Baisser les minimums par défaut à 2 : ils existent pour l'équilibre des parties normales (un Recruteur à trois joueurs décide de la partie).
  - Ignorer les minimums dès qu'il y a moins de 4 joueurs : comportement caché, différent de ce qu'affichent les réglages.
- **Vérifié dans le code du jeu :** à deux joueurs, le jeu ne désigne aucun dissident (difficultés normales : un dissident seulement au-delà de 2 joueurs ; Custom : selon la règle `DissidentCount`). Les six rôles réservés aux dissidents sont donc impossibles à deux, quels que soient les réglages du mod.
- **Relecture indépendante (aucun défaut grave) :**
  - L'avertissement « rôles non attribués » ne s'affiche que si des places sont restées libres. Sinon il serait apparu dans presque toutes les parties normales : le maximum de rôles est atteint avant d'avoir passé tous les rôles en revue.
  - Reconnaissance du mod : les rôles étaient fixés 0,5 s après la question de l'hôte ; une réponse plus lente privait le joueur des rôles qui demandent le mod. L'hôte attend maintenant que tous aient répondu, 1,5 s au plus. Le nombre de joueurs sans le mod est recompté au moment de l'annonce.
  - Côté joueur : l'annonce du mod à l'hôte est répétée toutes les 2 s tant que l'hôte n'a pas répondu (dix fois au plus), et refaite tout de suite pour un nouveau personnage.
  - Le journal note l'annonce du mod, la question de l'hôte et sa réponse : le journal de l'ami suffira à savoir ce qui s'est passé.
  - Journal : une ligne répétée n'est écrite qu'une fois puis comptée ; 1 Mo au plus par session ; un message si le fichier ne peut pas être écrit.
  - Le message d'activation précise que la version affichée est celle de l'hôte.

## D56 — Plantage du Métamorphe (version 0.6.0)

- **Constat (test à deux) :** erreur fatale au moment où le Métamorphe prend l'apparence de sa cible.
- **Rapport de plantage :** lecture à l'adresse 0x70 dans UE4SS, dans l'écriture d'une structure imbriquée au troisième niveau : apparence, puis pièces, puis une pièce qui est elle-même une structure.
- **Cause :**
  - L'apparence a 17 pièces. D'après les fichiers du jeu (`Str_SkinCustom_Result`), 16 sont des objets et la dernière, la teinte de peau, est une paire de nombres (`Vector2D`).
  - Pour distinguer un objet d'une structure, la copie appelait `IsValid`. Or la valeur qu'UE4SS donne pour une structure répond aussi à `IsValid` : la teinte était donc gardée telle quelle, comme un objet.
  - À l'écriture, UE4SS ne sait pas recopier cette valeur dans une structure et lit une adresse nulle.
  - C'était le premier vrai essai du Métamorphe : le défaut date de la 0.4.0.
- **Correction :** le type de chaque pièce est donné par son nom, plus deviné. La teinte est copiée en deux nombres ; les 16 autres sont des objets.
- **Règle retenue :** ne jamais deviner le type d'une valeur du jeu par ses méthodes. Le lire dans la définition de la structure.

## D57 — Sphères rouges dans le lobby (version 0.6.0)

- **Constat :** après un recrutement, les joueurs gardent une sphère rouge au-dessus de la tête dans le lobby.
- **Cause :** à la fin de la partie, le jeu efface les sphères par la même fonction qui les affiche (`Set HackerSphere`, avec un paramètre « effacer »). Le mod corrigeait les sphères après chaque appel de cette fonction, sans regarder le paramètre : il les réaffichait donc juste après l'effacement.
- **Correction :** le mod ne corrige plus rien quand le jeu efface, ni quand la partie n'est plus en cours. À la fin de partie, il efface aussi lui-même les sphères de chaque joueur.

## D58 — Sphère verte pour la personne sûre du Shérif (version 0.6.0)

- **Demande :** la sphère de la personne sûre est rouge, comme celle des dissidents : cela prête à confusion.
- **Constat :** la sphère a un matériau (`M_HackerSphere`) dont la couleur tient en deux paramètres, `Color` et `eColor`.
- **Décision :** sur la machine du Shérif, la sphère de la personne sûre reçoit une copie verte de son matériau pendant la durée du marqueur, puis reprend son matériau d'origine. L'intensité d'origine est gardée.
- **Option écartée :** créer une seconde sphère verte à côté : la sphère du jeu est déjà placée et affichée par le jeu.

## D59 — Revenant : fantôme visible et audible de tous (version 0.6.0)

- **Demande :** la lumière du Revenant se voit à peine. Son fantôme doit devenir visible et audible de tous, et ses yeux doivent se rouvrir quand le pouvoir s'active.
- **Décision :**
  - Même mécanisme que le Médium, limité à un personnage : chaque machine demande au jeu de décider à nouveau si le fantôme de ce joueur est affiché et entendu, en se déclarant « morte » le temps de cette seule décision.
  - Le jeu refait cette décision à chaque mort ou réanimation : le mod la redemande donc chaque seconde pendant l'apparition, puis fait cacher le fantôme à la fin.
  - Un Rêveur en plein rêve voit aussi le Revenant qui se manifeste, alors qu'il ne voit pas les autres morts.
  - Sur la machine du Revenant, les yeux sont rouverts à l'activation, comme pour le Rêveur.
  - Durée par défaut portée de 3 à 8 s, maximum de 10 à 30 s. Un réglage déjà enregistré n'est pas modifié.
- **Limite :** les joueurs sans le mod ne voient ni n'entendent rien.

## D60 — Traqueur : silhouette à travers les murs (version 0.6.0)

- **Constat (test) :** le Traqueur ne voit que la sphère au-dessus de la tête, et pas à travers les murs.
- **Recherche dans les fichiers du jeu :**
  - Le jeu n'a aucun matériau à lui qui se dessine à travers les murs. Son contour de dessin animé (`MatPP_OutlinesV3`) ne peut pas être modifié sans l'éditeur.
  - Le moteur fournit un matériau dessiné par-dessus tout, celui de ses poignées de contrôle (`ControlRigXRayMaterial`). Il est présent dans les fichiers du jeu, avec une couleur et une opacité réglables. Il ne s'applique qu'aux objets rigides, pas au corps animé d'un personnage.
- **Décision :** sur la machine du Traqueur, trois formes arrondies avec ce matériau (jambes, buste, tête) sont attachées à la cible pour la durée de la traque : une silhouette rouge translucide, visible à travers les murs. La sphère du jeu reste affichée.
- **Ce qui n'est pas vérifié :** que ce matériau s'affiche bien dans le jeu tel qu'il est livré. S'il ne peut pas être chargé, le journal le note et le Traqueur garde seulement la sphère.
- **Options écartées :**
  - Appliquer le matériau au vrai corps : il n'est pas prévu pour un corps animé, le jeu afficherait son matériau de secours.
  - Agrandir la sphère : elle n'est pas visible à travers les murs.

## D61 — Liés : un lien, plus un rôle ; annonce des rôles allégée (version 0.6.0)

- **Demande :** les deux Liés doivent pouvoir avoir chacun un rôle ; le rappel « détails » doit disparaître de l'annonce des rôles.
- **Décision :**
  - Le lien est tiré après les rôles, parmi tous les joueurs, et ne compte pas dans le nombre de rôles par partie. Ses réglages (activé, joueurs minimum, camps) ne changent pas.
  - Chaque lié est prévenu par « LIÉ À : nom ». La page du rôle et l'onglet LPROLES ajoutent une ligne sous l'état du rôle ; un lié sans rôle voit cette ligne seule. Une ligne d'aide de plus est affichée pour lui faire de la place.
  - « Rôle forcé pour l'hôte » sur Liés lie l'hôte à un autre joueur ; l'hôte reçoit par ailleurs un rôle comme tout le monde.
  - À la fin de la partie, les liés sont révélés en plus des rôles.
  - L'annonce d'un rôle ne montre plus que son nom (deux lignes pour le Shérif et la Taupe, qui disent autre chose que le rappel).

## D62 — Relecture indépendante de la 0.6.0

- **Un défaut important, corrigé :** la silhouette du Traqueur était placée 90 cm trop bas. Je croyais la position d'un personnage au milieu de son corps ; le code du jeu montre qu'elle est à ses pieds (le fantôme est placé 1,5 m au-dessus, la caméra environ 1,6 m). Les trois formes sont maintenant à 42, 112 et 158 cm, et suivent l'orientation du joueur.
- **Même erreur, plus ancienne, dans la visée des pouvoirs :** l'hôte calculait le regard depuis 60 cm de haut et visait la cible à 30 cm. Regarder le visage d'un joueur proche ne le désignait donc pas toujours. Le regard part maintenant de 1,6 m et la cible est testée à trois hauteurs (jambes, buste, tête). Cela concerne l'Ange gardien, le Traqueur, l'Hypnotiseur, le Métamorphe et l'Échangeur.
- **Autres corrections :**
  - Revenant : un Rêveur ou une Fée en plein vol le voient aussi, comme annoncé en D59. La décision d'affichage n'est plus redemandée chaque seconde, seulement quand le jeu vient de recacher les fantômes, et toutes les 3 s par sécurité.
  - Liés : quand un lié meurt, la mort de l'autre était demandée deux fois par précaution. La seconde demande pouvait tuer pour de bon un protégé que l'Ange gardien venait de relever. Elle n'est plus faite si la première a abouti.
  - Liés : si le premier joueur tiré n'a pas de partenaire possible (camps imposés), les autres sont essayés. « Joueurs minimum » descend à 2. L'hôte est prévenu quand le lien n'est pas attribué faute de joueurs.
  - Chargement du matériau « rayons X » : il est recherché à nouveau après le chargement, quelle que soit la réponse d'UE4SS.
  - Sphère verte : le retour au matériau d'origine est programmé avant le changement de couleur.
- **Ce qui reste à vérifier en jeu :** l'affichage du matériau « rayons X », la hauteur de la silhouette, et la place de la ligne « Lié à » sur la tablette pour un rôle qui a déjà cinq lignes.
- **Seconde relecture, après corrections : approuvé.** Trois points mineurs corrigés en plus :
  - une apparition du Revenant réglée à moins de 3 s restait affichée jusqu'à 2 s de trop ;
  - si le moteur refuse d'attacher une forme de la silhouette, elle est supprimée au lieu de rester immobile là où se tenait la cible ;
  - le Clandestin qui sort de sa cachette regardait vers le bas (encore une hauteur d'yeux à 60 cm).

## D63 — Le mod « disparaît » chez une joueuse invitée (version 0.6.1)

- **Constat (utilisateur) :** après avoir collé la 0.6.0, son amie ne voit plus rien du mod en jeu : ni onglet, ni bandeau, ni page de tablette. Il soupçonnait le remplacement des fichiers.
- **Ce que disent les journaux :**
  - Chez l'hôte : le mod de l'amie répond « j'ai le mod » au début de la partie, et elle reçoit un rôle. Les fichiers sont donc bien en place.
  - Chez l'amie (son `journal.txt`, version 0.6.0) : chargement normal, onglet construit dans le menu principal. Puis plus aucune ligne pendant près de trois minutes après avoir rejoint la partie, sauf les réponses aux messages de l'hôte.
  - Une ligne de son journal est abîmée (« Accroche posée : %s ») : une opération sur du texte, qui ne peut pas échouer normalement, a échoué une fois chez elle.
- **Cause :**
  - Tout l'affichage du mod dépend d'une « horloge » qui bat dix fois par seconde. Elle était entretenue par une boucle sur un fil d'exécution séparé, qui demandait chaque battement au fil du jeu.
  - Chez l'amie, cette chaîne s'est interrompue en rejoignant la partie, et rien ne la relançait : les accroches (réponses à l'hôte) marchaient encore, mais plus rien de ce qui dépend de l'horloge.
  - Le langage du mod n'est pas fait pour tourner sur deux fils à la fois. La boucle faisait tourner du code du mod sur un second fil dix fois par seconde ; la ligne abîmée du journal va dans le même sens.
  - Chez l'hôte, cela ne s'est jamais produit : il ne change pas de carte en rejoignant quelqu'un.
- **Décision :**
  - L'horloge est maintenant entretenue par une boucle qu'UE4SS fait tourner lui-même dans le fil du jeu (`LoopInGameThreadWithDelay`, présente dans cette version d'UE4SS).
  - Deux surveillances, qui ne font rien tant que la boucle bat :
    - chaque accroche du mod, déjà dans le fil du jeu : si la boucle se tait depuis 5 s, elle demande un battement de secours ; si rien ne répond pendant 30 s, elle fait battre le mod elle-même ;
    - le fil séparé, une fois par seconde, qui ne fait que comparer des nombres : il n'intervient qu'après 60 s de silence, plus qu'un chargement de carte, pour ne plus gêner le fil du jeu.
  - La boucle est relancée après deux constats de silence espacés de 2 s, puis de moins en moins souvent si elle ne repart pas. Le journal le note.
  - Sans cette fonction (autre version d'UE4SS), l'ancienne méthode est gardée, avec la même surveillance.
- **Défaut voisin corrigé en même temps, la sécurité anti-plantage :**
  - Elle écrivait un fichier témoin à chaque mise à jour de l'onglet et de la page, plusieurs fois par seconde en partie. Une seule écriture ratée (un antivirus qui examine le fichier suffit) faisait croire à un plantage au lancement suivant : l'onglet et la page étaient alors coupés dans les réglages, pour de bon, sans moyen de les remettre en jeu pour un joueur qui n'est pas l'hôte.
  - Maintenant : seule la construction est surveillée ; une écriture ratée est retentée ; un arrêt met en pause pour un lancement, deux arrêts de suite jusqu'à F10 ; les réglages ne sont plus modifiés.
  - Au premier lancement de la 0.6.1, l'onglet et la page sont remis en route une fois, au cas où l'ancienne sécurité les aurait coupés à tort.
- **Remplacement des fichiers :** le soupçon de l'utilisateur était faux cette fois, mais invérifiable sans journal. L'installation écrit maintenant la liste des scripts et leur taille (`manifest.txt`) ; au chargement, le mod la compare à ce qui est réellement là et prévient si des fichiers de deux versions sont mélangés.
- **Ce qui n'est pas prouvé :** que l'arrêt venait bien du second fil. Le journal de l'amie montre l'arrêt, pas sa cause. La nouvelle horloge supprime cette cause possible et relance l'horloge dans tous les cas.
- **Relecture indépendante de la 0.6.1 (avec désassemblage d'UE4SS) :**
  - Faits établis : UE4SS ignore ce que renvoie la fonction de la boucle (elle ne s'arrête qu'avec `CancelDelayedAction`) ; la boucle peut être créée au chargement du mod ; les actions différées survivent à un changement de carte ; une erreur dans la fonction n'arrête pas la boucle.
  - Faits établis sur l'ancienne méthode : le fil séparé et le fil du jeu utilisaient le même état Lua, sans verrou. Dix fois par seconde, le fil séparé y déposait une fonction pendant que le fil du jeu pouvait y travailler. C'est l'explication la plus probable de la ligne abîmée et de l'arrêt, sans en être une preuve.
  - Corrections faites : une boucle remplacée est annulée par son identifiant ; l'horloge n'est déclarée muette qu'après deux constats espacés de 2 s (un long chargement n'est plus pris pour un arrêt) ; les touches (G, F5 à F10) ne font plus que lever un indicateur, traité au battement suivant.
  - Deuxième et troisième relectures : jamais de battement à l'intérieur d'un autre ; avec l'ancienne méthode (autre UE4SS), dix battements par seconde et non deux ; le battement fait par les accroches en dernier recours est réellement atteint quand plus rien ne répond ; F10 n'est jamais oubliée, même après un long silence ; l'avis « en pause » attend qu'un écran existe pour s'afficher.
  - Reste hors du fil du jeu : la surveillance (une comparaison de nombres par seconde) et l'indicateur des touches. Plus aucune fonction n'y est créée en fonctionnement normal.
  - Autres corrections : le blocage après deux arrêts est annoncé à chaque lancement ; F10 relance aussi un onglet ou une page abandonnés après des erreurs, et écrit l'état de l'horloge dans le journal.

## D64 — Un objet de recharge par rôle : plantes et poissons (version 0.7.0)

- **Demande :** seuls le Rêveur et la Fée pouvaient consommer quelque chose pour récupérer une utilisation. L'utilisateur veut que les plantes et les poissons soient répartis entre les rôles.
- **Ce que le jeu offre :**
  - cinq plantes (G3M, Y8Z, BO4, WX2, RU2), récoltées dans un bocal ;
  - quatre poissons, sortis de la machine à poissons : SALMON, TUNA, COD, SHRIMP sur son écran (le jeu n'existe qu'en anglais) ;
  - les plantes et la machine sont posées dans la carte elle-même : elles sont là à chaque partie, que la tâche correspondante soit tirée ou non.
- **Décision, la répartition par défaut :** neuf objets, neuf rôles à utilisations limitées, un objet chacun.

  | Rôle | Objet | Rôle | Objet |
  |---|---|---|---|
  | Rêveur | bocal de G3M (inchangé) | Traqueur | poisson TUNA |
  | Fée | bocal de WX2 (inchangé) | Hypnotiseur | poisson SALMON |
  | Médium | bocal de BO4 | Métamorphe | poisson SHRIMP |
  | Clandestin | bocal de Y8Z | Nettoyeur | poisson COD |
  | Échangeur | bocal de RU2 | Recruteur | aucun |

  - La règle : les plantes pour les rôles qui ne sont pas réservés aux dissidents, les poissons pour les quatre rôles dissidents.
  - Recruteur : aucun objet par défaut. À l'origine l'utilisateur ne voulait pas qu'il dépende d'une plante, et un second recrutement pèse lourd. L'hôte peut lui en donner un.
  - Pas de recharge pour le Shérif, l'Ange gardien, la Taupe et le Martyr (rien à récupérer), ni pour le Revenant (ses apparitions ne servent qu'une fois mort, et un mort ne tient rien).
- **Règles de la recharge :**
  - objet en main, touche de consommation : une utilisation de plus, sans dépasser le maximum du rôle ;
  - le bocal devient sale, comme avant ; le poisson disparaît de la main ;
  - chaque rôle a son réglage « Objet de recharge » (aucun, une des cinq plantes, un des quatre poissons) ; deux rôles peuvent avoir le même objet ;
  - nouveau réglage général « Recharges par partie (0 = illimité) », compté par joueur. Il est à 0 par défaut : le Rêveur et la Fée n'avaient déjà aucune limite ;
  - quand il ne reste plus d'utilisation, le bandeau nomme l'objet à consommer. Le rappel de la touche n'apparaît plus qu'une fois par partie ;
  - les anciens réglages « Plante » du Rêveur et de la Fée sont repris tels quels.
- **Options écartées :**
  - *N'importe quelle plante ou n'importe quel poisson pour un rôle* : plus simple à jouer, mais les objets ne seraient plus répartis et tout le monde irait au plus proche.
  - *Mélanger plantes et poissons sans règle de camp*, pour qu'un poisson en main ne désigne pas un dissident. Je garde la règle par défaut : elle se retient, tenir un poisson est banal (tâche Pizzushi), et la consommation ne se voit pas chez les autres, sauf l'objet qui disparaît. L'hôte peut mélanger à sa guise.
  - *Toutes les utilisations rendues par un seul objet* : trop généreux pour les rôles à deux utilisations ou plus.
  - *Utiliser aussi le riz, le pizzushi, les cookies…* : la demande porte sur les plantes et les poissons.
  - *Faire retirer le poisson par la machine du joueur, comme pour le bocal* : j'ai repris les deux appels que le jeu fait lui-même quand un emplacement prend l'objet d'une main (un vers la machine du joueur, un pour l'hôte). L'hôte sait aussitôt que la main est vide, et cela marche même si le joueur a une version plus ancienne du mod.
- **L'utilisation n'est comptée qu'une fois l'objet réellement consommé** (ajouté après la première relecture) :
  - poisson : l'hôte le retire de la main, vérifie que la main est vide, puis rend l'utilisation ;
  - bocal : l'hôte demande à la machine du joueur de le vider. Elle ne vide que le bocal contenant la plante attendue. L'utilisation est rendue quand le jeu annonce à l'hôte que le bocal est sale ; sans cela, après 3 s, rien n'est donné et le joueur garde sa plante ;
  - 1,5 s au moins entre deux recharges d'un même joueur ;
  - la touche ne fait rien pendant que les mains sont occupées (échange entre la main et le sac, objet tout juste pris ou posé) : même règle que pour utiliser un objet dans le jeu.
- **Ce qui n'est pas vérifié en jeu :** tout. À regarder d'abord : une recharge par bocal faite par l'hôte (trois accroches du mod s'y enchaînent pour la première fois), le poisson qui disparaît de la main chez un joueur invité, et la place du texte « POISSON SHRIMP » dans le menu.
- **Première relecture indépendante : approuvé avec corrections.** Un défaut moyen, huit mineurs, tous corrigés :
  - *Moyen :* l'utilisation était rendue avant que le bocal soit vidé. Un joueur invité qui lâchait le bocal au même instant gardait la plante et l'utilisation, et pouvait recommencer. Ce défaut existait déjà pour le Rêveur et la Fée ; d'où la règle ci-dessus.
  - Un poisson que le jeu n'aurait pas retiré de la main donnait quand même l'utilisation.
  - L'hôte refusait la recharge pendant un échange main/sac d'après un indicateur du jeu qui peut rester bloqué : la touche serait devenue muette. Ce contrôle est retiré ; c'est la machine du joueur qui refuse, d'après ses propres mains.
  - Un Clandestin caché pouvait recharger. Plus maintenant.
  - Rêveur ou Fée avec « Charge au départ » à 0 et aucun objet : le rôle ne pouvait jamais servir. Il commence alors avec sa charge.
  - Fée : fermer les deux yeux affichait un message de recharge alors que ce geste ne lui sert à rien quand la recharge par les yeux est coupée.
  - `config.txt` : les nouveaux réglages n'y apparaissaient qu'après un premier changement, et une valeur écrite comme dans le menu (« AUCUN ») était refusée sans rien dire. Le fichier est complété au chargement, liste les valeurs possibles, accepte aussi les libellés du menu, et le journal note les valeurs refusées.
  - Tablette : le point final d'une ligne se terminant par un mot en gras était dessiné seul (« G . »). La ponctuation reste maintenant collée au mot. Cela corrige aussi des lignes plus anciennes.
  - Les numéros des objets étaient écrits en dur à plusieurs endroits.
- **Seconde relecture, après corrections : approuvé.** Cinq points mineurs, corrigés aussi :
  - poser le bocal dans un emplacement juste après la touche rendait l'utilisation en laissant la plante dans l'emplacement : l'attente est annulée quand le jeu retire l'objet de la main ;
  - avec une très mauvaise connexion, un autre bocal sorti du sac pouvait être vidé à la place du bon : d'où le contrôle de la plante ;
  - la recharge par bocal ne dépend plus d'une seule accroche : l'hôte regarde aussi la main à chaque battement pendant l'attente ;
  - l'attente est annulée à la mort du joueur, et un refus de dernière minute (réglages changés par l'hôte) est dit au joueur ;
  - Clandestin (défaut de la 0.6.1) : en sortant de sa cachette, il pouvait rester incapable d'utiliser quoi que ce soit si un délai du jeu courait quand il s'est caché.
- **Vérification séparée de ces cinq dernières retouches : validée.** Version installée et archive reconstruite le 5 octobre 2026.
- **Ce que le mod ne peut pas empêcher :** poser un poisson dans un emplacement dans le dixième de seconde qui suit la touche rend l'utilisation et laisse le poisson dans l'emplacement. L'emplacement prend l'objet tel que la machine du joueur le décrit, sans consulter l'hôte. Le réglage « Recharges par partie » borne l'abus.

## D65 — Les yeux se rouvrent pour tout pouvoir lancé en fermant les deux yeux (version 0.7.1)

- **Constat (utilisateur) :** le Médium garde les yeux fermés quand sa vision commence, comme le Rêveur et le Revenant avant lui. Il demande la même correction pour tous les pouvoirs lancés en fermant les deux yeux.
- **Cause :** fermer les deux yeux les verrouille dans le jeu. Jusqu'ici, chaque rôle rouvrait les yeux de son côté, dans son propre code ; le Médium avait été oublié, et la recharge par les yeux aussi.
- **Décision :** la règle est écrite une seule fois, chez l'hôte. Dès que le geste « deux yeux fermés » lance quelque chose, l'hôte demande à la machine du joueur de rouvrir ses yeux. Cela couvre le Rêveur, le Médium, le Clandestin, le Revenant et la recharge par les yeux (Rêveur, Fée), et couvrira d'office un futur rôle qui utiliserait ce geste.
- **Options écartées :**
  - *Ajouter la réouverture au seul Médium* : c'est ce qui avait été fait pour les autres, et c'est ainsi qu'un rôle a été oublié.
  - *Rouvrir aussi quand le geste est refusé* (plus d'utilisation, pas de bouche d'aération à proximité) : le joueur n'a rien lancé ; il garde la main sur ses yeux. La demande porte sur les pouvoirs qui s'activent.
- Les réouvertures propres à chaque rôle sont gardées : les yeux reçoivent alors deux fois l'ordre de s'ouvrir, sans effet de plus.
- Un joueur hypnotisé n'est pas concerné : ses gestes ne comptent pas, et ses yeux restent fermés jusqu'à la fin de l'hypnose.

## D66 — Relecture de toutes les descriptions de la tablette (version 0.7.2)

- **Demande :** certaines descriptions de la tablette semblaient boguées ou incomplètes ; les reprendre une par une.
- **Méthode :** chaque phrase affichée a été comparée à ce que fait le code du rôle, par moi puis par un relecteur indépendant. Un nouvel outil, `tools/lp/pages.py`, écrit toutes les pages telles que le jeu les montre (15 rôles, tous leurs états, les réglages qui changent le texte) et refuse une valeur manquante, une ligne qui n'est pas une phrase entière ou une page trop longue.
- **Un vrai défaut d'affichage, trouvé par le relecteur :** la tablette gardait des lignes de la page précédente quand la nouvelle était plus courte et ne nommait pas la même plante. Exemple : après une partie en Médium, la page « aucun rôle » montrait encore « Pendant la vision… » et « +1 utilisation : un bocal de BO4… ». C'est très probablement ce que l'utilisateur a vu. Corrigé : les lignes inutilisées sont vidées.
- **Défauts de texte corrigés :**
  - *Phrases coupées en deux puces* (Taupe, Nettoyeur, Clandestin, Revenant) : la seconde puce commençait au milieu d'une phrase. Ces textes avaient été écrits pour les lignes courtes du menu. Chaque puce est maintenant une phrase entière.
  - *Distances arrondies au mètre* : 2,5 m s'affichait « 3 m » (Recruteur, Nettoyeur, Clandestin). L'hôte envoie maintenant les distances au dixième de mètre.
  - *Valeurs absentes* : pendant la seconde qui suit l'annonce du rôle, toutes les valeurs s'affichaient « ? ». La page n'affiche plus que « En attente des informations de l'hôte », et l'hôte envoie les valeurs aussitôt.
  - *Shérif* : la carte et la personne sûre étaient annoncées même quand l'hôte les avait coupées, ou quand la carte n'avait pas pu être donnée. La page dit maintenant ce qui a réellement été fait au début de la partie. Le bandeau « carte d'accès » n'est affiché qu'une fois la carte donnée, et dit si elle est dans le sac ou dans la main.
  - *Ponctuation* : un « s. », un « : » ou un « ; » pouvait se retrouver seul en début de rangée. Ils restent collés au mot qui précède.
  - *Métamorphe* : l'état pouvait annoncer une seconde de trop.
- **Informations ajoutées :**
  - Recruteur : pas de recrutement pendant les premières secondes ; une tentative sur le Shérif est perdue ; la cible doit être encore en vie au moment de la conversion.
  - Rêveur : attaqué, il se réveille aussitôt.
  - Fée : ce que voient les autres, avec et sans le mod, que la lumière soit activée ou non.
  - Traqueur : la silhouette n'existe que sur son écran ; une seule traque à la fois.
  - Martyr : rien n'est annoncé pour une mort par explosion, poison ou chute ; l'état dit si c'est le camp ou le nom qui sera annoncé.
  - Ange gardien : le choix du protégé est définitif.
  - État : les utilisations restantes sont rappelées pendant qu'un effet est en cours ; libellés propres au Recruteur (« recrutements ») et au Revenant (« apparitions »).
- **Menu Échap :** il affiche les mêmes lignes. Une ligne trop longue pour une rangée continue sur la suivante (72 caractères au plus, coupe équilibrée), et les rangées inutiles ne prennent plus de place.
- **Options écartées :**
  - *Garder les phrases courtes du menu et n'allonger que la tablette* : deux jeux de textes à tenir à jour, et c'est ainsi qu'ils divergent.
  - *Fusionner chaque rôle en une ou deux longues phrases* : moins lisible sur la tablette qu'une idée par puce.
  - *Mesurer la hauteur de la page en jeu* : une ancienne capture montre la place pour une quinzaine de rangées sous le bandeau d'état, et la page la plus longue en compte six.
- **Autre correction faite au passage :** un joueur dont le mod n'est reconnu qu'après l'annonce des rôles reçoit maintenant son rôle à ce moment-là (sa page restait vide).
- **Ce qui n'est pas vérifié en jeu :** tout l'affichage. À regarder d'abord : la page après un changement de rôle d'une partie à l'autre, et les lignes longues dans l'onglet LPROLES.
- **Relecture indépendante, deux passes : approuvé avec corrections, toutes faites.**
  - Première passe : le défaut des lignes restées de la page précédente (voir plus haut) ; des rangées du menu réduites à « s. » ; le Shérif décrit d'après les réglages et non d'après ce qui s'est passé ; précisions de fond pour la Fée, le Martyr, le Recruteur et le Shérif ; trois tournures.
  - Seconde passe : la personne sûre du Shérif qui a quitté la partie n'était jamais signalée, à cause d'un ancien repli ; un Shérif reconnu en retard ne recevait pas la personne sûre. Sur 4000 enchaînements de pages tirés au hasard, l'ancien affichage laissait une ligne fausse dans 3540 cas, le nouveau dans aucun.
  - Laissé de côté : les cas où un joueur quitte la partie en cours (cible d'une traque, protégé de l'Ange).
  - Vérification séparée des quatre dernières retouches : validée. Version installée et archive reconstruite le 6 octobre 2026.

## D67 — Plus de mention des joueurs sans le mod (version 0.7.3)

- **Demande :** l'utilisateur ne joue qu'avec des amis, qui auront tous le mod ; supprimer tout ce qui mentionne les joueurs qui ne l'ont pas.
- **Décision :**
  - Pages des rôles (tablette et onglet LPROLES) : les cinq phrases concernées sont retirées ou simplifiées (Fée, Hypnotiseur, Nettoyeur, Martyr, Revenant).
  - `LISEZ-MOI-LPRoles.md` : « Qui doit l'installer » devient « tous les joueurs » ; la liste des limites pour les joueurs sans le mod est retirée.
  - Ce journal de décisions n'est pas réécrit : les décisions passées restent telles qu'elles ont été prises.
- **Ce que je garde, et pourquoi :**
  - *Le code qui tolère un joueur sans le mod* (rôles réservés aux machines qui ont répondu, hypnose refusée sans coût, etc.). Il ne s'affiche nulle part et protège la partie le jour où le mod d'un ami ne se charge pas, ce qui est déjà arrivé (D63).
  - *L'avertissement de l'hôte « N JOUEUR(S) SANS LE MOD »* et le compte de la touche F9. Ils n'apparaissent que si une machine n'a pas répondu, donc jamais quand tout va bien ; c'est le seul signal d'une installation cassée.
- **Option écartée :** retirer aussi cet avertissement. La demande peut se lire ainsi ; je l'ai signalé à l'utilisateur, c'est une ligne à supprimer s'il le préfère.

## D68 — Fée : une boule violette à la place du corps (version 0.7.4)

- **Demande :** pendant l'envol, cacher le corps de la Fée aux autres et le remplacer par une boule violette, en réutilisant la boule que le jeu affiche au-dessus des dissidents (celle que le mod teinte en vert pour la personne sûre du Shérif). Garder la lumière actuelle, pour voir ce que ça donne.
- **Ce qui existait :** le corps était déjà caché chez les autres, remplacé par une lumière rose et, quand elle était libre, par la sphère du jeu réduite à 12 cm au-dessus de la tête.
- **Décision :**
  - Une boule de 45 cm, violette, à hauteur du buste, suit la Fée pendant tout l'envol. Elle a la forme et la matière de la sphère des dissidents (le jeu fabrique la sienne avec la sphère de base du moteur et la matière `M_HackerSphere`) ; seule la couleur change, comme pour le vert du Shérif.
  - La lumière est gardée telle quelle.
  - Deux réglages dans le groupe FÉE, pour essayer : « Boule violette à sa place » (nouveau, oui par défaut) et « Lumière visible » (inchangé). La page du rôle dit ce que voient les autres selon les deux.
- **Options écartées :**
  - *Utiliser la sphère du jeu elle-même*, comme suggéré. Trois défauts : elle est au-dessus de la tête et non à la place du corps ; c'est le jeu qui l'affiche et la cache (un autre pouvoir ou la fin de partie pouvait la faire disparaître en plein envol, ou la laisser visible ensuite, voir D57) ; les autres dissidents la voient déjà. Une boule à part, faite des mêmes éléments, donne le même aspect sans toucher à celle du jeu.
  - *Teindre aussi la lumière en violet* : l'utilisateur veut d'abord voir le résultat avec la lumière actuelle.
- **Ce qui n'est pas vérifié en jeu :** tout l'aspect. La taille (45 cm), la hauteur (1,10 m) et la teinte sont trois nombres au début de la partie « Fée » de `lpr_client.lua` (`FAIRY_BALL`), faciles à changer.
- **Relecture indépendante : approuvé avec corrections, faites.**
  - Faits vérifiés dans les fichiers du jeu : la sphère des dissidents est bien la sphère de base du moteur avec `M_HackerSphere`, à l'échelle 0,1 (10 cm) ; la boule de la Fée est donc la même, 4,5 fois plus grande. La pièce du personnage à laquelle elle est attachée se trouve exactement à sa position et se déplace avec lui chez les autres joueurs pendant l'envol.
  - La matière multiplie sa couleur lumineuse par 6 : la teinte pourra tirer sur le bleu. Elle a été rendue un peu plus rouge ; à ajuster après le premier essai.
  - Corrections : une boule qui n'a pas pu être créée ou colorée laisse maintenant une ligne dans le journal, et n'apparaît jamais en rouge (la couleur des dissidents) ; si l'attache est refusée, la boule est posée comme l'est la lumière ; chaque envol écrit une ligne « Fée : … masquée » dans le journal de ceux qui la voient ; la fin de partie retire tout ce qui resterait d'un envol.
  - Avec « Lumière visible » seule, une petite boule (12 cm) est gardée : une lumière sans rien au centre ne se voit que sur les murs.

## D69 — Fée : le corps restait visible ; boule de 25 cm ; envol de 5 s (version 0.7.5)

- **Retour de l'utilisateur (test à deux, 0.7.4) :** la boule violette apparaît bien, mais le corps de la Fée ne disparaît pas : la boule est dedans. Il demande aussi une boule de 25 cm et un envol de 5 s.
- **Cause du corps visible :** le journal de la partie dit « Fée : Joueur1 masquée (0 éléments, 2 objets) ». Pour cacher le corps, le mod demandait au moteur la liste des pièces du personnage (`K2_GetComponentsByClass`) ; à travers UE4SS cette demande ne rend rien, sans erreur. Le corps n'a donc jamais été caché, depuis la première version de la Fée : elle n'avait été essayée que seule, et personne ne peut se regarder voler.
- **Décision :**
  - Le corps est caché pièce par pièce, par leur nom : le corps, la tête (le jeu dessine toute l'apparence sur ces deux-là), le porte-bonheur et le poisson collé au visage. Les objets portés ne sont cachés que s'ils étaient visibles, pour ne pas en faire apparaître un à la fin.
  - Boule : 25 cm.
  - « Durée (s) » de la Fée : 5 par défaut. Le réglage déjà enregistré chez l'utilisateur (2,5) a été mis à 5 dans son `config.txt`, à sa demande.
- **Même défaut ailleurs, corrigé aussi :** le Nettoyeur utilisait la même demande pour rendre un cadavre impossible à toucher (au défibrillateur). Elle ne faisait donc rien. Les pièces concernées sont maintenant nommées elles aussi.
- **Leçon :** la ligne de journal ajoutée à la demande du relecteur en 0.7.4 (« … masquée (N éléments…) ») a donné la cause en une lecture. Plus aucune fonction du moteur qui rend une liste n'est utilisée par le mod.
- **Ce qui n'est pas vérifié en jeu :** que le corps disparaît bien cette fois, et l'aspect de la boule seule. Le journal de celui qui regarde doit maintenant dire « 2 éléments » ou plus.

## D70 — Liés : « réglage sur NON, et pourtant liés » (version 0.7.5)

- **Constat (utilisateur) :** le réglage des Liés était sur NON au lancement, et il a quand même été lié à son amie. Parfois aussi, à la fin d'une partie sans Liés, un message « lié à … » apparaît pendant le fondu noir.
- **Ce que montre le journal de la session du 6 octobre :**
  - 17:31:27 : Liés mis sur NON. Partie de 17:32 : aucun lien, comme attendu.
  - **17:37:11 : Liés remis sur OUI par un clic dans l'onglet LPROLES**, quatre secondes avant le début de la partie suivante.
  - Partie de 17:37:15 : les deux joueurs sont liés ; « LIÉ À : Joueur1 » à l'annonce des rôles ; partie arrêtée après 13 s ; « LIÉ : Joueur1 » et « LIÉ : Joueur2 » à la révélation de fin, pendant le fondu.
  - 17:37:39 : Liés remis sur NON. Parties suivantes : aucun lien.
  - Les deux anomalies décrites sont donc cette même partie. Sur toute la durée du journal (depuis le 4 octobre), un lien n'a été tiré que lorsque le réglage valait OUI.
- **Ce que je n'ai pas trouvé :** un chemin par lequel le mod changerait ce réglage tout seul, ou afficherait NON pour une valeur OUI. Le changement de 17:37:11 est passé par le même chemin qu'un clic sur la flèche de la ligne.
- **Cause du clic de 17:37:11 : non établie.** Le réglage n'a pas pu être changé autrement que par un appui sur la flèche de la ligne, dans l'onglet ouvert (à la souris, ou au clavier ou à la manette si le bouton avait gardé la main). Volontaire puis oublié, ou involontaire : le journal de la 0.7.4 ne permet pas de trancher. Une piste parmi d'autres, jugée peu probable par le relecteur (les lignes Fée et Liés sont à plusieurs écrans l'une de l'autre) : le jeu replace le curseur au centre de l'écran à chaque ouverture du menu, donc sur une ligne de réglage si l'onglet LPROLES est resté affiché, et les flèches réagissent dès l'appui.
- **Décision :**
  - Le journal dit maintenant comment chaque réglage a été changé : onglet (flèche gauche ou droite, souris dessus ou non, depuis combien de temps le menu est ouvert, position de la liste), saisie d'un nombre, ou touches F7/F8. Au début de chaque partie, il note aussi les réglages des Liés et le rôle forcé. Si cela se reproduit, on saura.
  - Un appui sur une ligne alors que le menu Échap est fermé est ignoré.
  - À chaque ouverture du menu et de l'onglet, chaque ligne est réécrite d'après le réglage réel : ce qui est affiché ne peut pas être périmé.
  - Messages : ce qui restait à afficher d'une partie est abandonné à sa fin, et au début de la suivante ; un lien est révélé en une seule ligne, « LIÉS : A ET B », au lieu de deux.
- **Relecture indépendante (journaux et code) : diagnostic confirmé, approuvé avec corrections, faites.**
  - Sur tout le journal, trois parties avec un lien, chaque fois avec le réglage sur OUI ; aucun message « LIÉ » dans une partie sans lien ; le changement de 17:37:11 est passé par l'onglet et non par les touches (97 %).
  - Seul autre moyen d'être lié avec le réglage sur NON : « Rôle forcé pour l'hôte » sur Liés. Ce n'était pas le cas ici ; le journal le signale désormais.
  - Corrections : un champ numérique quitté sans changement n'est plus enregistré ni noté ; rien d'une partie précédente ne survit à un nouveau départ, même mod coupé entre-temps ; un lien dont l'autre joueur est parti est encore révélé.
  - Écarté après la seconde passe : relire le texte affiché par chaque ligne pour noter les écarts dans le journal. Le mod n'a jamais lu un texte du moteur en jeu, et une erreur à cet endroit ferait planter le jeu à chaque ouverture du menu. Les lignes sont simplement réécrites.
- **Coût des relectures (remarque de l'utilisateur, 6 octobre) :** les agents de relecture, une fois leur rapport rendu, étaient réveillés en boucle par un message automatique « agent terminé » du greffon oh-my-claudecode ; chaque réveil relisait tout leur contexte pour répondre une ligne. Sur le dernier relecteur : 21 réveils inutiles, environ 8,5 millions de jetons relus. Les dernières retouches de cette version (réécriture simple des lignes, ligne de journal) n'ont donc pas été relues par un agent : vérifiées par les outils du dossier seulement.
- **Options écartées :**
  - *Demander une confirmation, ou un double clic, pour changer un réglage de l'hôte* : pénible à chaque réglage, pour un incident vu une fois.
  - *Annoncer à l'hôte, au début de chaque partie, ce qui est actif* : du bruit à l'écran à chaque partie.

## D71 — Métamorphe : sa ligne de la liste des joueurs garde sa couleur (version 0.7.6)

- **Retour de l'utilisateur :** la 0.7.5 fonctionne. Mais quand le Métamorphe prend le corps de quelqu'un, sa ligne dans la liste des pseudos (en haut à droite) prend la couleur du corps volé, ce qui le trahit. Peut-on l'éviter ?
- **Cause :** le jeu colore chaque ligne de la liste d'après l'apparence du personnage, et c'est cette apparence que le Métamorphe copie. La couleur du corps et celle de la ligne sont une seule et même valeur : on ne peut pas changer l'une sans l'autre chez l'hôte.
- **Décision :** la correction se fait sur l'affichage de chaque machine. Une demi-seconde avant le changement d'apparence, l'hôte prévient tout le monde ; chaque machine note la couleur que montre alors la ligne du Métamorphe et la remet chaque fois que le jeu redessine cette ligne, jusqu'à la fin du déguisement. Réglage de l'hôte « Garde sa couleur dans la liste » (groupe MÉTAMORPHE, oui par défaut) ; la page du rôle dit ce qu'il en est.
- **Options écartées :**
  - *Ne copier que les formes et pas la couleur* : le corps ne ressemblerait plus à celui de la cible, c'est la couleur de la combinaison qui se voit de loin.
  - *Recalculer la couleur à partir de l'apparence d'origine* : il faudrait appeler une fonction du jeu qui rend son résultat d'une façon que le mod n'a jamais utilisée en jeu ; relire la couleur déjà affichée est plus sûr.
- **Limite :** une machine qui n'a pas pu lire la ligne à temps (très forte latence) verra la couleur volée ; son journal le note.
- **Non relu par un agent** (voir D70, coût des relectures) : vérifié par les outils du dossier seulement. Pas encore lancé en jeu.

## D72 — Arrêt du jeu du 6 octobre à 21:54 et joueur sans rôle : analyse, aucun changement du mod

- **Demandes de l'utilisateur :** « je viens d'avoir un crash, regarde si c'est lié au mod ou pas », puis « dans ma game actuelle, quelqu'un n'a pas de rôle, dis moi pourquoi ».
- **Ce qui est établi pour 21:54 :**
  - Le journal du mod s'arrête à 21:54:16, juste après le tirage des rôles d'une partie à 5 ; l'annonce des rôles prévue 6 s plus tard n'a jamais eu lieu. L'horloge du mod tourne sur le fil principal du jeu : ce fil était donc bloqué.
  - Le journal de Steam (`logs/gameprocess_log.txt`) donne la fin du processus à 21:55:06, soit 50 s plus tard, avec le code de sortie 1. C'est le code d'une fermeture forcée (Gestionnaire des tâches ou équivalent), pas celui d'une faute : sur cette machine les fautes donnent 0xC0000005 (fichier de UE4SS) ou 3 (rapport du moteur).
  - Aucun fichier de crash : ni rapport du moteur, ni fichier de UE4SS, ni événement Windows. C'est donc un **blocage du jeu au lancement de la partie**, fermé ensuite, et non un crash.
- **Ce qui n'est pas établi :** la cause du blocage. Le mod travaille à ce moment-là (il vient de tirer les rôles) : il ne peut pas être écarté. Mais la même séquence a tourné dans huit autres parties de la soirée sans blocage, le chemin du mod à cet endroit ne contient aucune boucle sans fin, et rien n'est noté dans les journaux. Clandestin et Hypnotiseur étaient donnés pour la première fois de la soirée dans cette partie : simple coïncidence possible, à surveiller.
- **Les trois fichiers de crash de UE4SS du jour (18:07, 19:13, 20:37) ne viennent pas du mod.** Lus avec le nouvel outil `tools/lp/minidump.py` : les trois ont la même pile, à la fermeture du jeu (gestionnaires de sortie de la bibliothèque C, appelés par le fil principal de l'exécutable), où le code du jeu prend un verrou déjà détruit (écriture à l'adresse 0x24 dans ntdll). Ni UE4SS ni Lua n'apparaissent dans la pile. La même faute, à la même adresse, figure dans deux fichiers de Windows du 1er octobre, où UE4SS n'était pas chargé. Défaut du jeu, sans conséquence (le jeu se fermait).
- **Le crash de 20:32** est un manque de mémoire au lancement (rapport du moteur et événement Windows 2004, qui cite Aniimo.exe 7,4 Go et le jeu 6,2 Go).
- **Joueur sans rôle :** avec les réglages du moment (Shérif, Clandestin, Échangeur, Nettoyeur, Recruteur coupés), seuls trois rôles peuvent aller à un employé (Rêveur, Fée, Médium) alors qu'une partie à 5 compte quatre employés et un dissident. Les trois rôles réservés aux dissidents (Hypnotiseur, Traqueur, Métamorphe) se disputent le seul dissident. Le tirage se fait dans un ordre au hasard : quand Rêveur ou Fée (camp « any ») tombe sur le dissident, deux employés restent sans rôle (partie de 21:59).
- **Décision :** aucun changement du mod pendant la soirée. Une nouvelle version obligerait les cinq joueurs à la reprendre, et rien ne désigne une ligne à corriger.
- **Options envisagées, non faites :**
  - *Une « boîte noire »* : le mod garderait d'un lancement à l'autre la trace de ses dernières actions (aujourd'hui `UE4SS.log` est effacé à chaque lancement), pour savoir où il en était lors d'un prochain blocage. À faire si le blocage revient.
  - *Servir d'abord les rôles réservés à un camp* dans le tirage, pour qu'un rôle ouvert à tous ne prenne pas le seul dissident. À proposer à l'utilisateur.

## D73 — Une touche pour activer les pouvoirs ; les yeux fermés ne servent plus qu'au Rêveur (version 0.8.0)

- **Demande de l'utilisateur (6 octobre, en pleine partie) :** « Il faudrait ajouter une nouvelle touche pour activer les pouvoirs, on garde l'activation avec les yeux fermés que pour le rêveur ». Et : « Les changements qui suivent ne doivent pas être direct mis dans mon jeu car je suis en partie avec mes amis. »
- **Décision :** une touche de pouvoir, **B** par défaut, que chaque joueur choisit dans MES RÉGLAGES (les mêmes lettres libres que la touche de consommation). Elle remplace **tous** les gestes des yeux, clins d'œil compris : deux yeux fermés (Médium, Clandestin, Revenant), double clin d'œil droit (Fée), clin d'œil gauche maintenu (Ange gardien, Traqueur, Hypnotiseur, Métamorphe, Échangeur, Recruteur, Nettoyeur). Seul le Rêveur garde les deux yeux fermés.
  - *Interprétation de ma part :* la phrase ne cite que « les yeux fermés ». J'ai compris qu'aucun autre pouvoir ne devait rester sur les yeux, clins d'œil compris, puisque « une touche pour activer les pouvoirs » les vise tous.
- **Pouvoirs à cible :** on ne peut pas savoir si une touche reste enfoncée (UE4SS ne signale que l'appui). Un appui ouvre donc une tentative : la cible est cherchée pendant 2,5 s, nommée (« CIBLE : … »), puis doit rester en vue le temps du réglage « Cible à garder en vue » (1,5 s par défaut, 0 = immédiat). Même principe pour le Recruteur et le Nettoyeur : appuyer, puis rester près de la cible.
- **Retours ajoutés :** un appui qui ne donne rien le dit toujours (« PERSONNE EN VUE », « CIBLE PERDUE », « PERSONNE À PORTÉE », « AUCUN CADAVRE À PORTÉE », « DÉJÀ DÉGUISÉ », « UNE TRAQUE EST EN COURS »). Avec les clins d'œil, le silence passait ; avec une touche, il ferait croire à une panne.
- **Canal réseau :** il ne restait aucune valeur libre pour un nouveau message du joueur vers l'hôte (trois valeurs, toutes prises). La valeur 7, qui servait au seul Rêveur endormi (« mon rêve est fini de mon côté »), porte aussi « j'ai appuyé sur ma touche de pouvoir » : l'hôte les distingue selon que le joueur rêve ou non, et le pouvoir du Rêveur n'est justement pas sur la touche.
- **Les deux touches ne peuvent pas être la même lettre :** choisir la lettre de l'autre échange les deux.
- **Réglages :** « Délai du double clin d'œil » (Fée) supprimé ; « Geste deux yeux fermés » et « Recharger aussi en fermant les yeux » passent dans le groupe RÊVEUR (ils ne concernent plus que lui) ; « Geste de visée » devient « Cible à garder en vue », avec 0 permis.
- **Options écartées :**
  - *Touche maintenue pendant la visée* : demanderait de lire l'état du clavier par une fonction du moteur que le mod n'a jamais appelée en jeu.
  - *Effet immédiat sans confirmation* : un appui en passant devant quelqu'un gaspillerait une utilisation ; le réglage à 0 le permet à qui le veut.
  - *Garder les clins d'œil en plus de la touche* : deux façons de faire la même chose, et des pouvoirs lancés par erreur en clignant.
  - *Un bandeau qui rappelle la touche à l'annonce du rôle* : l'utilisateur a demandé de ne pas mettre de rappels dans les bandeaux ; la page du rôle l'écrit.
- **Non installée, non relue par un agent, jamais lancée en jeu.** Vérifiée par les outils du dossier (syntaxe, noms du jeu, 985 pages de rôle).

## D74 — Le Métamorphe peut prendre l'apparence d'un cadavre (version 0.8.0)

- **Demande :** « Il faudrait que le métamorphe puisse récupérer le skin d'un mort en activant le pouvoir sur un cadavre ».
- **Décision :** les cadavres comptent parmi les cibles du Métamorphe, de deux façons : le viser (comme un joueur), ou appuyer à moins de 2,5 m de lui sans viser personne. Un joueur vivant en vue passe avant le cadavre voisin.
- **Comment :** le personnage d'un mort garde son apparence ; l'endroit de sa mort et son orientation sont connus de l'hôte. Le corps est cherché en cinq points le long de cette orientation (il est tombé en avant ou en arrière).
- **Exclus :** un corps que le Nettoyeur a fait disparaître ; un personnage qui ne fait pas partie de la partie.
- **Option écartée :** *la proximité seule* (comme le Nettoyeur) : le Métamorphe est un rôle de visée, et pouvoir copier un mort de loin lui laisse le choix.

## D75 — Shérif : plus de carte dans le sac, une carte en surbrillance dans le bâtiment (version 0.8.0)

- **Demande :** « Pour le sheriff, on change, il n'aura plus de carte d'accès dans son sac, mais il faut lui en mettre une en surbrillance, pour que ce soit moins broken ».
- **Décision :** à l'annonce des rôles, l'hôte pose **une carte d'accès de plus** à un emplacement d'objets libre tiré au hasard, par l'appel que le jeu fait lui-même pour ses cartes et ses armes. La machine du Shérif dessine à cet endroit une boule jaune et une colonne jaune de 3 m, vues à travers les murs. Quand quelqu'un ramasse la carte, l'hôte le constate (l'objet n'existe plus) et la surbrillance s'éteint.
  - *Interprétation de ma part :* « lui en mettre une » peut vouloir dire poser une carte pour lui, ou mettre en avant une carte déjà là. J'ai pris la première lecture par défaut, parce que le jeu peut ne poser aucune carte (sa règle « CardSpawn » va de 0 à 3 cartes), et laissé la seconde en réglage.
- **Réglages (groupe SHÉRIF) :** « Une carte d'accès en surbrillance » ; « Carte posée en plus de celles du jeu » (NON = une des cartes du jeu est mise en surbrillance) ; « Surbrillance vue à travers les murs » (NON = boule lumineuse, vue directe seulement).
- **Pourquoi une boule et une colonne plutôt que le contour du jeu :** le jeu sait entourer un objet (quand on le vise de près), mais il rallume et éteint ce contour lui-même selon la distance, et il ne se voit pas de loin. La matière « vue à travers tout » sert déjà à la silhouette du Traqueur.
- **Pourquoi la surbrillance n'est pas accrochée à la carte :** un objet lointain peut ne pas exister sur la machine du Shérif. Les formes sont posées à l'endroit que donne l'hôte, qui le redit si la carte bouge (elle tombe au sol juste après avoir été posée).
- **Options écartées :**
  - *Mettre la carte dans sa main ou son sac avec un délai* : c'est toujours une carte gratuite.
  - *La montrer sur la carte de la tablette* : la page du rôle cache la carte, et le repère serait à refaire dans l'écran de la tablette.
  - *Remplacer la carte ramassée par une autre* : l'avantage redeviendrait permanent.
- **Risques connus :** l'appel qui pose la carte et la pose de formes « accrochées à rien » n'ont jamais été faits en jeu par le mod. Si la carte ne se pose pas, le mod prend une carte du jeu ; si aucune forme ne peut être dessinée, le journal du Shérif le dit.
- **Ce qui reste dans le code sans servir :** la fonction qui glissait la carte dans le sac (`G.give_item_quietly`), gardée au cas où l'utilisateur voudrait revenir en arrière.

## D76 — Ange gardien : la mort du dernier employé protégé ne termine plus la partie (version 0.8.1)

- **Demande de l'utilisateur :** « pour le pouvoir de l'ange gardien, si le protégé était le dernier gentil, quand il meurt et qu'il revive il ne faut pas que ça termine la game ».
- **Ce que fait le jeu :** à chaque mort, il regarde si tous les employés de sa liste (`Innocents`) sont morts. Si oui, il programme la fin 0,5 s plus tard et ne revérifie plus rien. Le mod n'est prévenu d'une mort qu'après ce test : relever le protégé arrive trop tard. C'est pourquoi, jusqu'ici, l'ange ne sauvait pas le dernier employé (« TROP TARD »).
- **Décision :** tant qu'un employé a une protection d'Ange gardien encore à venir, le mod inscrit les dissidents dans cette liste. Un dissident en vie suffit pour que le test du jeu réponde « pas tous morts » quand le protégé meurt. Dès que le protégé est relevé (ou 5 s après sa mort s'il ne l'a pas été), les dissidents sont retirés de la liste et le jeu refait son propre test.
- **Pourquoi c'est sans danger connu :** dans le code du jeu, cette liste n'est écrite qu'au tirage des rôles et lue que par ce test. Le mod y écrit déjà lors d'un recrutement.
- **Cas restant :** si plus aucun dissident n'est en vie quand le dernier employé protégé meurt, le test du jeu passe quand même et la partie se termine ; l'ange lit « TROP TARD : PARTIE TERMINÉE ».
- **Options écartées :**
  - *Mettre le jeu « hors partie » pendant la demi-seconde* : cette valeur est lue à une dizaine d'endroits (minuteur, arrivée d'un joueur, boutons « prêt »).
  - *Empêcher la mort elle-même sur la machine du protégé* : il ne tomberait plus et ne lâcherait plus ses objets ; l'utilisateur parle bien d'une mort suivie d'un retour.
  - *Relancer une partie après la fin* : rôles, tâches et objets seraient retirés.
- **Version :** numérotée 0.8.1 pour ne pas la confondre avec l'archive 0.8.0 construite une heure plus tôt, que j'ai supprimée. Toujours pas installée, non relue par un agent, jamais lancée en jeu.

## D77 — Liés : le lien ne joue qu'une fois (version 0.8.2)

- **Retour de l'utilisateur (partie de 23:38, version 0.7.6) :** « j'étais ange gardien lié, et j'ai protégé mon lié, sauf que quand je suis mort ça l'a tué, puis revive (normal), puis retué encore une fois, il faudrait pas qu'il se refasse tuer ».
- **Ce que montrent les journaux :** le jeu a enregistré **deux morts** de l'utilisateur, à 23:45:26 et 23:45:34. À la première, le lien tue Joueur3, que l'Ange gardien relève (23:45:27). À la seconde, le lien tue Joueur3 de nouveau, et la protection de l'ange est déjà utilisée.
- **Ce qui n'est pas établi :** pourquoi il y a eu une seconde mort. Dans le code du jeu, une mort n'est envoyée que par un joueur vivant : l'utilisateur a donc été relevé entre les deux (un défibrillateur est l'explication la plus simple), mais rien dans les journaux ne le dit. Le mod, lui, ne relève que le protégé.
- **Décision :** le lien joue une seule fois. Dès que l'un des deux liés meurt pour de bon, le lien est rompu pour les deux : aucune mort ultérieure de l'un ne tue plus l'autre. La page du rôle l'écrit (« Ton lien avec … est rompu : il a déjà joué. »), sans bandeau de plus.
- **Ce qui ne change pas :** un lié sauvé par un Ange gardien d'une mort ordinaire ne déclenche pas le lien, qui reste donc entier.
- **Options écartées :**
  - *Ne protéger que le lié sauvé par l'ange* : la même mésaventure arrive sans ange, dès qu'un défibrillateur relève les deux liés l'un après l'autre.
  - *Empêcher la seconde mort d'être comptée* : si le joueur a vraiment été relevé puis retué, c'est bien une mort.
- **Version :** 0.8.2, pour ne pas la confondre avec l'archive 0.8.1 construite peu avant, que j'ai supprimée. Toujours pas installée, non relue par un agent, jamais lancée en jeu.

## D78 — Quatre joueurs sur huit perdus en pleine partie (7 octobre, 00:15-00:19, version 0.7.6) : analyse côté hôte, aucun changement

- **Demande de l'utilisateur :** « je viens d'avoir un crash de la part de la moitié des joueurs, peux-tu regarder ce qu'il s'est passé ? »
- **Ce qui est établi (fichiers de l'hôte seulement) :**
  - Le jeu de l'hôte n'a pas planté pendant la partie. Son seul fichier de crash (00:23:02) est le défaut connu du jeu à la fermeture (D72), 3 s après que l'utilisateur a quitté (« Event loop end » à 00:22:59).
  - Partie à huit lancée à 00:11:02. À 00:19:46 (annonce du Martyr) et à la fin (00:22:44), l'hôte n'écrit plus qu'à quatre joueurs : Joueur2, Joueur4, Joueur3, Joueur5. Joueur6, Joueur7, Joueur8 et Joueur9 ont disparu entre 00:15:14 et 00:19:46.
  - La dernière action du mod avant cette disparition est le second déguisement du Métamorphe (Joueur9) : il prend l'apparence de **Joueur2, l'hôte**, à 00:14:43 et la rend à 00:15:14. Son premier déguisement de la partie (en Joueur7, 00:12:01-00:12:32) n'a fait partir personne. Entre 00:15:14 et 00:19:13 le mod n'envoie rien à personne.
  - Aucune erreur dans le journal de l'hôte.
- **Ce qui n'est pas établi :** l'instant exact (l'hôte continue d'« écrire » à un joueur planté jusqu'à ce que sa connexion expire), et la cause. Le rapprochement avec le déguisement n'est qu'une coïncidence de temps. C'était la première fois de la soirée qu'un joueur copiait l'apparence de l'hôte. Sur les machines des autres joueurs, le seul code du mod qui tourne autour d'un déguisement est celui de la 0.7.6 qui garde la couleur de la ligne du Métamorphe dans la liste des joueurs (D71), jamais confirmé en jeu.
- **Ce qu'il faut pour conclure :** d'un des quatre joueurs, son `ue4ss\Mods\LPRoles\journal.txt`, le fichier `ue4ss\crash_2026_10_07_*.dmp` s'il existe, et le dossier daté du 7 octobre dans `%LOCALAPPDATA%\LockdownProtocol\Saved\Crashes\`. `tools\lp\minidump.py` dira où le jeu s'est arrêté.
- **En attendant, proposé à l'utilisateur :** couper le Métamorphe pour la soirée, ou au moins son réglage « Garde sa couleur dans la liste » (l'hôte n'envoie alors plus le message qui met ce code en route chez les autres).
- **Suite, avec les fichiers d'un des quatre joueurs (Joueur7 : `journal.txt` et `UE4SS.log`) :**
  - **Ce n'était pas un crash.** Le jeu d'Joueur7 tourne sans interruption de 23:00:32 jusqu'à la copie du fichier (00:29) : aucun nouveau chargement du mod, aucune erreur. À 00:19:10, sa machine se retrouve dans son propre lobby (elle se reconnaît elle-même comme hôte, l'onglet LPROLES est reconstruit) : Joueur7 a été **déconnecté** de la partie.
  - Chez l'hôte, le personnage d'Joueur7 disparaît entre 00:19:12 et 00:19:13 (l'état de son lié, Joueur5, perd alors son lien). Les deux machines concordent : la coupure a eu lieu vers 00:19:10.
  - **Le Métamorphe est hors de cause** : son déguisement s'est terminé à 00:15:14, quatre minutes plus tôt, et le mod n'a rien fait entre-temps, ni chez l'hôte ni chez Joueur7. Mon soupçon de la première analyse était faux ; le conseil de couper le Métamorphe est retiré.
  - **Cause non établie.** Rien dans les journaux du mod, ni dans ceux de Windows chez l'hôte (aucun événement réseau à cette heure). Quatre joueurs sur sept coupés au même instant pendant que trois restent : cela ressemble à une coupure de liaison entre eux et l'hôte (relais de Steam ou code réseau du jeu). Les fichiers des trois autres joueurs n'ont pas été vus.
  - **Confirmé par l'utilisateur :** les quatre joueurs ont tous été renvoyés au lobby, aucun n'a eu de plantage.
  - **Idée non faite :** faire noter par l'hôte, dans son journal, l'heure à laquelle un joueur quitte une partie en cours (aujourd'hui il faut la déduire des messages envoyés aux autres).

## D79 — Revenant : 20 s par défaut, et de nouveau à chaque mort (version 0.8.3)

- **Demande de l'utilisateur :** « il faut allonger la durée du revenant de base, je pense qu'on peut mettre 20secondes, et aussi qu'il puisse le réutiliser s'il se fait revive puis remeurs ».
- **Décisions :**
  - Durée par défaut d'une apparition : 20 s (au lieu de 8), réglable de 1 à 60 s (au lieu de 30).
  - Les apparitions sont rendues à chaque mort : le réglage devient « Apparitions à chaque mort ». Un Revenant réanimé (défibrillateur, Ange gardien) qui meurt de nouveau peut donc se manifester encore.
  - Un Revenant réanimé pendant qu'il se manifeste cesse aussitôt d'être montré : sinon, mort de nouveau avant la fin du délai, son fantôme réapparaîtrait sans qu'il ait rien demandé.
- **Le réglage de l'utilisateur :** son `config.txt` contient encore 3 s, valeur par défaut d'une ancienne version. Un nouveau défaut ne remplace jamais une valeur enregistrée. Il peut la changer tout de suite dans l'onglet LPROLES (la 0.7.6 accepte déjà 20) ; sinon, à faire à la main dans son `config.txt` le jour de l'installation.
- **Option écartée :** *rendre les apparitions au moment de la réanimation* plutôt qu'à la mort : cela dépendrait de la façon dont le joueur revient ; à la mort, tous les cas sont couverts.
- **Version :** 0.8.3 ; l'archive 0.8.2 est supprimée. Toujours pas installée, non relue par un agent, jamais lancée en jeu.

## D80 — Installation de la 0.8.3 (7 octobre 2026, 01:40)

- **Demande de l'utilisateur :** « on a fini de jouer tu peux installer et faire l'archive ».
- **Fait :** jeu fermé vérifié ; contrôles du dossier repassés (syntaxe, noms du jeu, pages de rôle) ; mod installé (`python tools\deploy.py`) ; archive `LPRoles-0.8.3-pour-les-joueurs.zip` reconstruite (`--package-only`) ; copie installée et archive comparées aux sources, identiques.
- **Réglage de l'utilisateur :** `revenant_duration` passé de 3 à 20 dans son `config.txt`, comme annoncé en D79. Au prochain lancement, le mod complète ce fichier avec les nouveaux réglages (touche de pouvoir B, carte du Shérif) et en retire celui du double clin d'œil.
- **Ce que contient la 0.8.3 par rapport à la 0.7.6 :** D73 à D77 et D79 (touche de pouvoir, cadavres pour le Métamorphe, carte du Shérif en surbrillance, Ange gardien et dernier employé, lien des Liés une seule fois, Revenant). Rien de tout cela n'a tourné en jeu.
- **Laissé tel quel :** `LPRoles.zip`, l'archive de la 0.7.6 que l'utilisateur avait renommée.

## D81 — Son de l'envol de la Fée, à la durée de l'envol (version 0.8.4)

- **Demande de l'utilisateur :** un fichier `son flo mod et tout ye.ogg` fait par une amie pour le vol de la Fée ; « comment peut-on l'implémenter ? parce que la durée du pouvoir est configurable, donc la durée du son doit suivre aussi ».
- **Le fichier :** OGG Vorbis, 12,7 s (12,3 s audibles), stéréo aux deux canaux identiques, très faible (crête à 0,14). C'est une texture continue de scintillement, sans début ni fin marqués : elle peut être coupée n'importe où.
- **Décisions :**
  - **Conversion** en WAV 16 bits mono, silences des bouts retirés, crête montée à 0,89 (`tools/lp/sound.py`) : le lecteur du jeu lit le WAV et le MP3, pas l'OGG. Rien d'autre n'est modifié dans le son.
  - **Durée :** au début de l'envol, la machine de la Fée joue une copie du son coupée à la durée reçue de l'hôte, avec un fondu de sortie de 0,4 s (le son est répété d'abord s'il est plus court). La copie est faite par le mod lui-même, une par durée, comme la copie du son de consommation.
  - **Qui l'entend :** la Fée seulement, comme le son de consommation. Réglage personnel « Son de l'envol de la Fée ».
  - Si l'envol finit plus tôt, le lecteur est fermé (coupure nette).
- **Options écartées :**
  - *Étirer le son* à la durée voulue : de 1 à 10 s d'envol pour 12 s de son, la hauteur ou le grain changeraient beaucoup ; une texture continue n'a pas besoin d'être étirée.
  - *Baisser le volume du lecteur à la fin* plutôt que d'écrire une copie en fondu : c'est un appel au moteur que le mod n'a jamais fait ; écrire un fichier est déjà éprouvé.
  - *Le faire entendre aux joueurs proches* : il faudrait un son placé dans l'espace qui s'atténue avec la distance, réglage du moteur jamais essayé ici ; et cela signalerait la Fée à l'oreille. À proposer à l'utilisateur.
- **Vérifié :** la découpe, recopiée telle quelle en Python, donne sur le vrai fichier des WAV valides de la bonne durée, terminés à zéro (1, 5, 7,5, 10 et 20 s). Le code du mod lui-même n'a pas tourné en jeu ; fermer le lecteur (`Close`) est un appel nouveau.
- **Version :** 0.8.4, installée dans la foulée (jeu fermé) ; l'archive 0.8.3 est remplacée.

## D82 — Le son de l'envol de la Fée est entendu par les joueurs proches (version 0.8.5)

- **Demande de l'utilisateur :** « oui fais que les joueurs proches l'entendent aussi ».
- **Décision :** sur la machine de chaque autre joueur, pendant l'envol, un lecteur de son est accroché au personnage de la Fée (il la suit) et joue la même copie du son, coupée à la durée de l'envol. Il est réglé pour être entendu depuis l'endroit où elle est et s'éteindre avec la distance : plein volume à moins de 3 m, silence au-delà de 21 m. La Fée, elle, garde le son « à plat » de la 0.8.4.
- **Comment :** le composant sonore du lecteur multimédia a les mêmes réglages de distance que tout son du moteur. Le moteur les lit quand le composant démarre, et il démarre tout seul dès qu'il est créé : le mod l'arrête, écrit les réglages (sur le composant et sur la source sonore qu'il contient, pour couvrir les deux lectures possibles), puis le relance.
- **Garde-fou :** si aucun des deux n'accepte les réglages, le son n'est pas joué chez les autres. Mieux vaut pas de son qu'un son entendu dans tout le bâtiment.
- **Ce qui n'est pas vérifiable sans le jeu :** que le moteur applique bien ces réglages une fois écrits. S'il ne les appliquait pas, le son serait entendu partout à plein volume ; le journal de chaque joueur note ce qui a été écrit. Il faut deux joueurs pour l'essayer.
- **Conséquences de jeu, voulues ou non :** l'envol s'entend à travers les murs (pas d'obstacle dans le calcul) ; avec le réglage « ni boule ni lumière », la Fée reste invisible mais plus inaudible. La page du rôle le dit (« Les joueurs proches entendent ton envol. »).
- **Options écartées :**
  - *Un des réglages d'atténuation du jeu* (celui des pas, par exemple) : sa portée est celle que le jeu a choisie pour autre chose.
  - *Calculer soi-même le volume selon la distance* : demande de changer le volume du lecteur plusieurs fois par seconde, appel jamais fait ici.
- **Première nouvelle de la 0.8.4 en jeu** (journal du 7 octobre, 17:31, l'utilisateur seul, rôle forcé Fée) : l'envol part deux secondes après l'annonce du rôle, donc la touche de pouvoir fonctionne ; la copie du son à la durée de l'envol (10 s ce jour-là) est écrite. L'utilisateur a ensuite demandé cette suite, signe que le son se joue.
- **Version :** 0.8.5. Écrite pendant que le jeu tournait, donc installée seulement une fois le jeu fermé, à la demande de l'utilisateur (7 octobre, vers 17:50) ; archive `LPRoles-0.8.5-pour-les-joueurs.zip` refaite, celle de la 0.8.4 supprimée ; copie installée et archive comparées aux sources, identiques.

## D83 — Traqueur, Hypnotiseur, Métamorphe, Échangeur : effet immédiat à la touche (version 0.8.6)

- **Demande de l'utilisateur :** « pour le traqueur, hypnotiseur, métamorphe, échangeur il faut que l'activation du pouvoir soit instant après avoir appuyé sur la touche d'activation ».
- **Décision :** pour ces quatre rôles, le pouvoir agit dès l'appui sur le joueur visé à cet instant : plus de cible à garder en vue, plus de bandeau « CIBLE : … » (le message du pouvoir nomme déjà la cible). Sans personne en vue, rien ne se passe, aucune utilisation n'est dépensée, et le bandeau dit « PERSONNE EN VUE » (après 0,3 s, le temps que l'hôte ait la visée du joueur).
- **Ange gardien :** non cité par l'utilisateur, il garde sa confirmation (cible nommée, puis gardée en vue). Son choix est unique et définitif, une erreur ne se rattrape pas. Le réglage « Cible à garder en vue » ne concerne plus que lui : il passe dans le groupe ANGE GARDIEN sous le nom « Protégé à garder en vue » (0 = immédiat, pour qui le veut).
- **Métamorphe et cadavre :** immédiat aussi, cadavre visé ou à moins de 2,5 m.
- **Option écartée :** *garder 2,5 s de recherche quand personne n'est en vue* : le pouvoir partirait sur le premier joueur qui traverse le champ, sans que le joueur l'ait choisi.
- **Version :** 0.8.6. Installée (jeu fermé), archive refaite, celle de la 0.8.5 supprimée.

## D84 — Sons de démarrage et d'échec d'un pouvoir (version 0.8.7)

- **Demande de l'utilisateur :** trois nouveaux sons d'un ami. « Le fail sfx est pour quand le lancement d'un pouvoir est pas réussi pour n'importe quelle raison, et les deux autres sont des variantes du son d'activation d'un pouvoir, je sais pas encore lequel prendre entre les deux donc je pense les essayer un par un ».
- **Les fichiers :** `fail sfx.ogg` (0,2 s), `success sfx.ogg` (0,3 s), `success sfx long.ogg` (1 s), en vraie stéréo. Convertis en WAV 16 bits avec `tools/lp/sound.py`, chacun monté à la même crête que le son de la Fée (le long saturait légèrement, il est donc baissé).
- **Décisions :**
  - **Deux variantes à essayer :** réglage personnel « Son d'un pouvoir qui démarre » (VARIANTE COURTE, VARIANTE LONGUE, AUCUN), modifiable en jeu sans rien relancer. Les deux fichiers sont livrés ; celui qui ne sera pas retenu pourra être retiré ensuite.
  - **Démarrage :** joué sur la machine de celui qui lance le pouvoir, au moment où l'hôte confirme (message de réussite du pouvoir, ou début de la vision, de la cachette, du rêve).
  - **Échec « pour n'importe quelle raison » :** joué avec chaque message de refus (personne en vue, plus d'utilisation, pas de bouche, déjà déguisé, trop tôt pour recruter, cible insensible…). Les refus que l'hôte faisait en silence (joueur mort ou hypnotisé, vision ou apparition déjà en cours, Revenant encore vivant) envoient maintenant un message « SFX fail », sans bandeau. Le Rêveur qui appuie sur la touche l'entend aussi, avec le rappel de fermer les yeux.
  - **Qui entend :** le joueur seul. Réglage personnel « Son d'un pouvoir qui échoue ».
- **Choix de ma part :**
  - *La Fée n'a pas le son de démarrage* : son envol a déjà son propre son, et le mod n'a qu'un lecteur par machine (un nouveau son remplace celui qui joue).
  - *La touche de consommation n'a pas de son d'échec* : l'utilisateur parle du lancement d'un pouvoir ; la recharge a déjà son son de réussite.
  - *Même niveau maximal pour les trois* plutôt que l'équilibre d'origine (l'échec était trois fois plus faible que la réussite) : un retour sonore doit s'entendre par-dessus le jeu. À revoir à l'oreille.
- **Option écartée :** *un message de l'hôte pour chaque son* : le joueur reçoit déjà un message par issue ; seuls les refus muets en avaient besoin.
- **Version :** 0.8.7. Installée (jeu fermé), archive refaite, celle de la 0.8.6 supprimée.

## D85 — Un seul son de démarrage, la Fée l'a aussi, et son envol arrive en fondu (version 0.8.8)

- **Demande de l'utilisateur :** « je garde la variante longue, retire l'autre, il faut aussi qu'elle s'active au start de la fée, et que le début du son du vol de la fée arrive avec un fondu ».
- **Décisions :**
  - `sounds\success.wav` est désormais la variante longue ; la courte et le choix entre les deux sont retirés. Le réglage personnel devient un simple oui/non (« Son d'un pouvoir qui démarre », nouveau nom interne `start_sound`, pour que l'ancien choix enregistré ne soit pas relu de travers).
  - La Fée entend le son de démarrage à son départ, par-dessus le son de l'envol. Il fallait deux lecteurs sur sa machine (un lecteur ne joue qu'un son à la fois) : les sons courts en partagent un, l'envol a le sien.
  - Le son de l'envol monte en fondu pendant 1 s, à peu près la durée du son de démarrage, et garde son fondu de sortie de 0,4 s. Sur un envol très court, le fondu d'entrée prend au plus la moitié de la durée. Les joueurs proches entendent la même copie, donc le même fondu.
- **Détail technique :** les copies du son de l'envol changent de nom (`…-50b.wav`). Une copie d'une version précédente, de même taille mais sans fondu d'entrée, aurait sinon été prise pour bonne chez les joueurs qui mettent à jour en recopiant l'archive.
- **Fichiers déjà installés :** dans le dossier du jeu de l'utilisateur, `success.wav` (court) est remplacé et `success-long.wav` retiré, après vérification que ce sont bien ceux que le mod avait posés. Chez ses amis, l'archive remplace `success.wav` ; un `success-long.wav` resté d'une 0.8.7 ne sert plus à rien et ne gêne pas.
- **Vérifié :** la découpe avec les deux fondus, recopiée en Python, comparée échantillon par échantillon au calcul direct sur le vrai fichier (1, 2,5, 5, 10 et 20 s). Le code du mod lui-même n'a pas tourné en jeu.
- **Version :** 0.8.8. Installée (jeu fermé), archive refaite, celle de la 0.8.7 supprimée.

## D86 — Son propre à l'Échangeur (version 0.8.9)

- **Demande de l'utilisateur :** un fichier `swap.ogg` ; « remplace le son d'activation par celui-ci, il faut aussi qu'il soit joué à celui qui se fait échanger et autour des deux ».
- **Le fichier :** 0,5 s, deux canaux identiques. Converti en WAV 16 bits mono, crête montée comme les autres sons (`sounds\swap.wav`).
- **Décisions :**
  - Pour l'Échangeur, ce son remplace le son de démarrage ordinaire (un échange raté garde le son d'échec).
  - L'hôte annonce chaque échange à toutes les machines (nouveau message, avec les deux joueurs). L'Échangeur et le joueur échangé entendent le son tel quel ; les autres l'entendent autour de chacun des deux personnages, avec la même atténuation que l'envol de la Fée (D82). Le son est accroché aux personnages : il les suit dans leur téléportation.
  - Réglage personnel « Son des échanges de place ». La page de l'Échangeur dit que l'échange s'entend.
- **Choix de ma part :** les deux joueurs concernés n'ont pas, en plus, le son placé autour de l'autre : ils entendraient deux fois le même son avec un léger décalage.
- **Non vérifiable sans le jeu :** comme pour l'envol de la Fée, que le moteur applique l'atténuation avec la distance ; il faut au moins trois joueurs pour entendre un échange de l'extérieur. L'Échangeur est actuellement désactivé dans les réglages de l'utilisateur.
- **Version :** 0.8.9. Installée (jeu fermé), archive refaite, celle de la 0.8.8 supprimée.

## D87 — Nouveau son de l'échange (version 0.8.10)

- **Demande de l'utilisateur :** « elle en a fait un meilleur pour le swap » (`swap mieux.ogg`).
- **Fait :** converti comme les autres (`tools/lp/sound.py`), il remplace `sounds\swap.wav` (0.96 s). Aucun changement de code.
- **Fichier déjà installé :** les mises à jour ne remplacent jamais un son présent dans le dossier du jeu (il peut être celui du joueur). Celui de l'utilisateur est remplacé à la main, après vérification que c'était bien le son posé par la 0.8.9. Chez ses amis, l'archive le remplace.
- **Version :** 0.8.10, pour que l'archive ne se confonde pas avec celle de la 0.8.9. Installée (jeu fermé), archive refaite, celle de la 0.8.9 supprimée.

## D88 — Les pouvoirs à cible étaient plafonnés à 6 m : portée réglée enfin respectée (version 0.8.11)

- **Retour de l'utilisateur :** « il semble que le paramètre de distance de l'échangeur ne fonctionne pas, je l'ai modifié et en testant ingame c'est toujours la même distance, il faudrait que cette distance soit triplée ». Son journal le confirme : portée passée à 50 m, puis 3 m, puis 50 m entre quatre échanges, sans effet.
- **Cause (dans mon code) :** pour ne pas viser à travers les murs, le mod refusait toute cible plus lointaine que le point regardé par le joueur, à 80 cm près. Or le jeu ne calcule ce point que sur **5 m** : sans obstacle, le point regardé est simplement 5 m devant. Toute cible à plus de 5,8 m était donc prise pour « derrière un mur ». Le réglage de portée était bien lu, mais ne pouvait jamais dépasser ce plafond. Cela touchait tous les pouvoirs à cible : Échangeur, Métamorphe, Traqueur, Ange gardien (l'Hypnotiseur, réglé à 6 m, n'en souffrait pas).
- **Décision :** jusqu'à 5 m, même test qu'avant. Au-delà, quand le regard du joueur n'a rien rencontré, l'hôte fait tracer par le moteur une ligne entre les yeux du joueur et sa cible (l'appel que le jeu fait lui-même pour le point regardé, écrit comme dans l'exemple de tracé livré avec UE4SS), en ignorant les deux personnages.
- **Si le tracé échoue :** la cible est acceptée, les murs à plus de 5 m ne sont plus vérifiés, et le journal de l'hôte le note une fois. Mieux vaut une portée qui marche qu'un réglage sans effet.
- **« Triplée » :** la distance atteinte en pratique était d'environ 5,8 m ; le réglage de l'utilisateur (50 m, monté pendant ses essais) est ramené à 17 m. Il reste réglable de 3 à 50 m.
- **Conséquence pour les autres rôles :** ils atteignent maintenant leur portée réglée, soit chez l'utilisateur 30 m pour le Traqueur, 20 m pour le Métamorphe, 15 m pour l'Ange gardien. À lui de les réduire s'il les trouve trop longues.
- **Options écartées :**
  - *Supprimer le test des murs au-delà de 5 m* : l'Échangeur se téléporterait à travers les murs sur un joueur qu'il ne voit pas.
  - *La fonction de visibilité des contrôleurs du moteur* : elle choisit elle-même les points visés sur la cible (ses pieds), mal adaptés aux personnages de ce jeu.
- **Version :** 0.8.11. Installée (jeu fermé), archive refaite, celle de la 0.8.10 supprimée.

## D89 — Son de l'échange remplacé de nouveau (version 0.8.12)

- **Demande de l'utilisateur :** « change encore le son du swap pour celui-ci » (`swap mieux mieux mieux mieux.ogg`).
- **Fait :** même traitement que D87 : converti avec `tools/lp/sound.py`, il remplace `sounds\swap.wav` (0.96 s). Aucun changement de code. Le fichier du dossier du jeu est remplacé à la main après vérification que c'était bien le son posé par la version précédente.
- **Version :** 0.8.12. Installée (jeu fermé), archive refaite, celle de la 0.8.11 supprimée.

## D90 — Niveau des sons du mod (version 0.8.13)

- **Question de l'utilisateur :** « est-ce que les volumes des sons te paraissent bien normalisés avec les autres sons du jeu ? sinon normalise le tout ».
- **Ce que je ne peux pas faire :** écouter, ni mesurer les sons du jeu. Ils sont stockés en Bink Audio, un format que rien sur cette machine ne décode. La comparaison avec le jeu ne peut donc pas être chiffrée ici.
- **Ce que j'ai mesuré :** les sons du mod entre eux, à l'oreille de la mesure (ITU-R BS.1770, en LUFS, sur les 0,4 s les plus fortes). J'avais mis chaque son à la même *crête*, ce qui ne donne pas le même volume perçu. Résultat avant correction :
  - `success` -10,4 ; `swap` -15,9 ; `fail` -18,1 ; `fairy` -23,2 ; `consume` -24,3 (celui de l'utilisateur, inchangé jusque-là).
  - Soit 14 dB d'écart entre le plus fort et le plus faible : non, ils n'étaient pas au même niveau. Le son de démarrage était de loin le plus fort.
- **Décision :** les cinq sons sont mis à -23 LUFS. Ce niveau n'est pas choisi au hasard : c'est celui du son de l'envol et du son de consommation, les deux que l'utilisateur a entendus en jeu sans s'en plaindre. Le son de démarrage perd 12,6 dB, l'échange 7,1, l'échec 4,9 ; l'envol et la consommation ne bougent presque pas.
- **Réglage ajouté :** « Volume des sons du mod (%) », personnel, de 10 à 200. C'est le seul moyen d'ajuster par rapport au jeu sans nouvelle version, puisque je ne peux pas le mesurer. Il passe par un appel du moteur (`SetVolumeMultiplier`, celui que le jeu utilise pour ses propres sons), jamais fait par le mod : s'il échoue, le volume reste à 100 %.
- **Question ouverte :** les sons du mod suivent-ils le curseur de volume du jeu ? Le jeu règle son volume général sur son mixage principal (`Submix_Main`) ; si ce mixage n'est pas celui par lequel passent les sons du mod, ils resteraient au même niveau quand on baisse le jeu. Un essai de dix secondes en jeu le dira ; si ce n'est pas le cas, il faudra faire passer les sons du mod par ce mixage.
- **Réponse (essai de l'utilisateur, 7 octobre, version 0.8.13) :** « le son baisse bien avec le curseur du jeu ». Les sons du mod passent donc par le mixage principal du jeu et suivent son volume général : rien à changer de ce côté.
- **Outil :** `tools/lp/loudness.py` (mesure, et mise à un niveau donné sans dépasser une crête de 0,89).
- **Version :** 0.8.13. Écrite pendant que le jeu tournait ; installée ensuite, jeu fermé, à la demande de l'utilisateur qui veut essayer le curseur de volume. Archive refaite, celle de la 0.8.12 supprimée.

## D91 — Son de l'envol de la Fée un peu plus bas (version 0.8.14)

- **Retour de l'utilisateur sur la 0.8.13 :** « le réglage marche bien, et au niveau des sons c'est pas mal, juste baisser légèrement le son du vol de la fée ».
- **Acquis en jeu :** le réglage « Volume des sons du mod » fonctionne (l'appel `SetVolumeMultiplier` passe) ; les sons suivent le curseur de volume du jeu ; le niveau commun de -23 LUFS convient.
- **Décision :** l'envol passe de -23,2 à -26 LUFS, soit 3 dB de moins : la plus petite baisse qui s'entende franchement. C'est un son continu de plusieurs secondes, il paraît plus présent qu'un son bref de même niveau.
- **Version :** 0.8.14. Installée (jeu fermé), archive refaite, celle de la 0.8.13 supprimée.

## D92 — Les deux boutons latéraux de la souris parmi les touches (version 0.8.15)

- **Demande :** « est-ce qu'on peut ajouter dans la liste des keybinds les boutons supplémentaires de souris ? les deux boutons sur le côté que 90% des souris ont ».
- **Vérifié avant d'écrire :**
  - Le jeu ne s'en sert pas : aucun de ses cinq jeux de touches (`IMC_CharacterDefault`, `IMC_CharacterSettings`, `IMC_CharacterSave`, `IMC_Menu`, `IMC_Gamepad`) ne nomme `ThumbMouseButton` ni `ThumbMouseButton2`. Seul l'écran de réglage des touches du jeu (`W_Settings_Keybind`) les nomme : un joueur peut donc en avoir mis un lui-même sur une action du jeu.
  - UE4SS les connaît : `XBUTTON_ONE` et `XBUTTON_TWO` figurent dans la liste « Valid keys » de son propre mod `Keybinds` et dans `UE4SS.dll`. UE4SS lit les touches en interrogeant l'état des touches de Windows (`GetAsyncKeyState`), ce qui couvre les boutons de souris.
- **Options envisagées :**
  1. **Ajouter les deux boutons à la liste existante (retenu).** Deux choix de plus, `mouse4` et `mouse5` dans `config.txt`, écrits « SOURIS 4 » et « SOURIS 5 » dans le menu, sur la page du rôle et dans les bandeaux. Ce sont les noms que les jeux donnent d'ordinaire à ces boutons (4 = arrière, 5 = avant).
  2. Ajouter aussi le clic de molette. Le jeu ne s'en sert pas non plus, mais ce n'est pas demandé, et la molette sert à changer d'objet en main : un clic involontaire lancerait le pouvoir. Écarté.
  3. Une saisie libre « appuyez sur la touche voulue ». UE4SS ne sait ni retirer ni changer une touche enregistrée : il faudrait toutes les enregistrer, y compris celles du jeu. Écarté, comme en D73.
- **Détails :** la règle « les deux touches du mod ne sont jamais la même » vaut pour les boutons comme pour les lettres. Si UE4SS ne connaît pas un nom de touche, le journal l'écrit (« Touche … inconnue de UE4SS ») au lieu de l'ignorer en silence.
- **Affichage :** « SOURIS 4 » tient en deux mots ; la mise en lignes de la page du rôle et du menu les garde ensemble (le chiffre reste collé à « SOURIS », comme une unité reste collée à son nombre).
- **Limites connues :** une souris dont le logiciel du fabricant a donné un autre rôle à ces boutons n'envoie plus « bouton 4 / 5 » à Windows, le mod ne la verra pas ; un bouton déjà mis sur une action du jeu par le joueur fera les deux.
- **Contrôles :** syntaxe, noms du jeu, pages du rôle redessinées avec « SOURIS 4 » et « SOURIS 5 » (les noms les plus longs) : aucune ligne ne déborde. **Jamais essayé en jeu ; pas de relecture indépendante.**
- **Version :** 0.8.15. Installée (jeu fermé), archive refaite, celle de la 0.8.14 supprimée.

## D93 — Le projet devient un dépôt GitHub (version 0.9.0)

- **Demande :** « j'aimerais que tu transformes ça en un projet github, pour qu'on puisse avoir un suivi ».
- **Acquis en jeu juste avant :** les deux boutons latéraux de la souris (D92) fonctionnent, d'après l'utilisateur.
- **Ce qui entre dans le dépôt :** le mod (`mod/LPRoles/`, sons compris), les outils écrits pour lui (`tools/deploy.py`, `tools/lp/`), les documents (`docs/`, `analysis/NOTES.md`), `README.md`, `CHANGELOG.md`.
- **Ce qui n'y entre pas (`.gitignore`) :**
  - les données tirées du jeu (`analysis/bp/`, `analysis/traces/`, `analysis/functions-index.txt`) : elles appartiennent à son éditeur, et `tools/lp/bp.py` les refabrique ;
  - les logiciels téléchargés (FModel, UE4SS) et les archives construites ;
  - le dossier du jeu sur cette machine, qui devient un réglage local : `tools/dossier-du-jeu.txt` (lu par `tools/lp/gamedir.py`). Il était écrit en dur dans `deploy.py` et `iostore.py`.
- **Vie privée :** le dépôt doit être public (voir D95). Les pseudos des joueurs cités dans ce document (analyses de journaux, D72 à D78) sont remplacés par « Joueur1 » à « Joueur9 » ; le chemin du jeu sur la machine de l'utilisateur est retiré des documents. Les phrases de l'utilisateur citées ici restent.
- **Options envisagées pour les documents :**
  1. **Les publier après ce nettoyage (retenu).** Le suivi demandé, c'est aussi l'historique des décisions.
  2. Les garder hors du dépôt. Plus prudent, mais le dépôt perdrait ce qui explique le code.
- **Rangement :** les trois documents de travail passent dans `docs/` ; la racine garde `README.md` (présentation, installation, mise à jour) et `CHANGELOG.md` (une section par version, reprise telle quelle par la page de la version sur GitHub).
- **Fins de ligne :** `.gitattributes` impose LF partout (CRLF pour le `.bat`), pour que l'archive construite sur GitHub contienne exactement les fichiers testés ici (la liste `manifest.txt` compte les octets de chaque script).
- **Création du dépôt :** l'outil en ligne de commande de GitHub n'est pas installé sur cette machine et je ne manipule pas les identifiants de l'utilisateur : c'est lui qui crée le dépôt vide sur github.com (compte `Freyzah`, nom `LPRoles`), je pousse ensuite avec git.

## D94 — Publication d'une version par GitHub lui-même (version 0.9.0)

- **Besoin :** publier une version sans outil ni jeton GitHub sur la machine.
- **Options envisagées :**
  1. **Un flux GitHub Actions déclenché par une étiquette `vX.Y.Z` (retenu).** `.github/workflows/release.yml` vérifie la syntaxe des scripts, vérifie que l'étiquette est bien la version des sources et que `manifest.txt` est à jour, construit `LPRoles.zip` (le dossier du mod) et `version.txt` (version + empreinte SHA-256 de l'archive), puis crée la page de la version avec la section correspondante de `CHANGELOG.md`. Côté machine : `git push` et rien d'autre.
  2. Installer l'outil `gh` et publier depuis la machine. Demande un téléchargement et une connexion de l'utilisateur ; n'apporte rien de plus.
  3. Déposer les fichiers à la main sur la page GitHub. Pas automatisé.
- **Même code des deux côtés :** `python tools/deploy.py --release-assets <dossier>` construit ces fichiers ici comme sur GitHub ; dates fixes dans l'archive.
- **L'archive complète** (UE4SS + mod, pour une première installation) reste construite ici par `deploy.py --package-only` : UE4SS n'est pas dans le dépôt. L'utilisateur peut la déposer sur la page d'une version s'il veut la proposer en ligne.
- **Limite :** `verify_mod.py` (noms du jeu) et `pages.py` ne tournent pas sur GitHub, ils ont besoin des données tirées du jeu. Ils restent lancés ici avant chaque version.

## D95 — Mise à jour automatique du mod (version 0.9.0)

- **Demande :** « j'aimerais un moyen pour mes amis de mettre à jour facilement le mod, il faudrait quelque chose d'automatisé ».
- **Options envisagées :**
  1. **Le mod se met à jour lui-même à chaque lancement du jeu, avant de charger ses scripts (retenu).** Rien à faire pour les joueurs, et la nouvelle version sert dès ce lancement : tout le monde se retrouve sur la même version sans se concerter.
  2. **Un fichier à double-cliquer, `mettre-a-jour.bat` (retenu aussi, en secours).** Même script, pour qui a coupé la mise à jour automatique ou veut réparer une installation.
  3. Vérifier au lancement et seulement prévenir. Chacun devrait encore agir : moins automatisé.
  4. Un programme lanceur à la place du jeu. Change les habitudes de tout le monde pour rien.
- **Fonctionnement :**
  - `update.ps1` (dans le dossier du mod) lit `version.txt` sur la page de la dernière version (`https://github.com/Freyzah/LPRoles/releases/latest/download/`), compare avec `manifest.txt`, télécharge `LPRoles.zip`, vérifie son empreinte puis son contenu contre sa propre liste, et seulement alors copie les fichiers. `manifest.txt` est copié en dernier : une copie interrompue garde l'ancien numéro et sera reprise.
  - Jamais touchés : `config.txt`, les journaux, et un son que le joueur a remplacé par le sien. Pour distinguer ce dernier d'un ancien son du mod, `manifest.txt` porte désormais l'empreinte de chaque son : un son installé qui a l'empreinte annoncée par la version en place est celui du mod, et se remplace. (`deploy.py` applique la même règle, ce qui supprime la copie à la main des sons modifiés.)
  - Jamais de retour en arrière : une version installée plus récente que la dernière publiée (la machine de l'utilisateur, où j'installe avant de publier) est laissée telle quelle.
  - Même version mais un script à la mauvaise taille : remise en état.
  - Lancé à la main pendant que le jeu tourne : refus, avec un message.
- **Dans le mod :** `main.lua` ne fait plus que démarrer : il appelle `lpr_update.lua` (qui lance `update.ps1` par `os.execute` et lit sa réponse dans `update-result.txt`), puis `lpr_main.lua`, l'ancien `main.lua`. `main.lua` doit rester identique d'une version à l'autre : c'est le seul script déjà en mémoire quand les autres sont remplacés. Après une mise à jour, un bandeau « LPROLES MIS À JOUR : VERSION … » s'affiche ; le journal note à chaque lancement ce qui s'est passé et le temps pris.
- **Réglage :** MES RÉGLAGES, « Mise à jour automatique au lancement » (OUI par défaut). `lpr_update.lua` le lit directement dans `config.txt`, les réglages n'étant pas encore chargés.
- **Passage à ce système :** les versions jusqu'à 0.8.15 n'ont pas ce mécanisme. Chaque joueur installe la 0.9.0 une dernière fois à la main (l'archive habituelle) ; ensuite, plus rien.
- **Vérifié ici** (`tools/test_update.py`, contre un serveur local qui tient lieu de page GitHub) : passage 0.8.15 → 0.9.0, rien à faire, son du mod remplacé et son du joueur gardé, archive abîmée refusée sans rien changer, pas de retour en arrière, remise en état, refus quand le jeu tourne, absence de réseau (2,5 s) ou de page, et la commande exacte que le mod lance, avec un chemin contenant des espaces et un accent. Sans rien de nouveau, le script répond en une demi-seconde.
- **Pas vérifié :** le lancement depuis le jeu. `os.execute` existe dans cette version d'UE4SS (la bibliothèque `os` y est, le mod s'en sert déjà pour les dates), mais je ne peux pas lancer le jeu : je ne sais pas si une fenêtre de commande apparaît un instant au démarrage, ni combien de temps le démarrage s'allonge en vrai. À essayer par l'utilisateur avant de donner la version à ses amis. **Pas de relecture indépendante.**
- **Risques assumés :**
  - Qui peut publier une version sur le dépôt fait exécuter son code chez tous les joueurs au lancement suivant. C'est le propre de toute mise à jour automatique ; le compte GitHub doit être bien protégé (double authentification).
  - Un antivirus peut trouver suspect qu'un jeu lance PowerShell pour télécharger un fichier. En cas de blocage : couper le réglage et utiliser `mettre-a-jour.bat`.
  - Sans réseau, le lancement attend au plus quelques secondes puis continue avec la version en place.
- **Version :** 0.9.0. Préparée dans les sources en attendant que le dépôt GitHub existe.
- **Suite, le 8 octobre :** l'utilisateur a créé le dépôt public `Freyzah/LPRoles`. Projet poussé, étiquette `v0.9.0` : le flux GitHub a réussi du premier coup et publié `LPRoles.zip` et `version.txt`.
  - Essai contre la vraie page, dans une copie d'installation 0.8.15 : mise à jour en 1,9 s par la commande exacte du mod, tous les fichiers identiques aux sources, réglages et son personnel gardés ; relancée, elle répond « rien de nouveau » en 0,7 à 0,8 s.
  - L'archive construite par GitHub n'a pas la même empreinte que celle construite ici (compression différente d'un système à l'autre) ; son contenu, lui, est identique. Sans importance : `version.txt` est écrit à côté de l'archive qu'il décrit.
  - 0.9.0 installée dans le jeu (fermé), archive complète `LPRoles-0.9.0-pour-les-joueurs.zip` refaite, celle de la 0.8.15 supprimée. Reste à voir en jeu : le premier lancement.
  - **Premier lancement en jeu (utilisateur, 8 octobre, 18:04) :** `os.execute` fonctionne depuis le jeu, `update.ps1` a répondu « OK 0.9.0 », le journal note « rien de nouveau (4.8 s) », aucune erreur. La vérification est six fois plus lente que hors du jeu (le jeu charge en même temps), mais elle ne retarde rien : UE4SS démarre ses mods pendant que le jeu charge, et aux lancements précédents le mod attendait déjà 4 à 5 s que le jeu ait chargé ses classes. Du démarrage du mod à la pose des accroches : 5,2 s cette fois, contre 4 à 5 s avant. Pas encore vu : une vraie mise à jour faite depuis le jeu, L'utilisateur n'a vu aucune fenêtre de commande au démarrage.

## D96 — Six nouveaux rôles : cadre commun et rôles neutres (version 0.10.0)

- **Demande :** « ajoute l'empoisonneur, le bailloneur, le voleur, l'écho, l'amnésique et le bouffon », retenus parmi dix propositions (les quatre autres sont notés dans `idees-mod-lockdown-protocol.md`).
- **Acquis juste avant :** l'utilisateur n'a vu aucune fenêtre de commande au lancement du jeu avec la mise à jour automatique.
- **Cadre :** chaque rôle suit le moule des précédents : un groupe de réglages (actif, joueurs minimum, camp quand il est libre, utilisations, portée, objet de recharge), une page de tablette, la touche de pouvoir. Les quatre pouvoirs visés agissent aussitôt, comme ceux de D83. Aucun message nouveau du joueur vers l'hôte : la touche de pouvoir et la touche de consommation suffisent.
- **Objet de recharge :** « aucun » par défaut pour les quatre rôles qui comptent leurs utilisations. Les neuf objets sont déjà pris par d'autres rôles ; l'hôte peut en attribuer un.
- **Rôles neutres : comment les faire tenir dans un jeu à deux camps.**
  1. **Le rôle neutre est donné à un employé, que le jeu continue de compter comme tel (retenu).** Aucune manipulation des listes du jeu. Conséquence assumée et écrite sur la page du rôle : la partie ne finit par « tous les employés sont morts » qu'une fois les neutres morts aussi.
  2. Retirer les neutres de la liste des employés du jeu. Plus juste (un neutre ne retarderait pas la victoire des dissidents), mais c'est la manipulation de liste de D76, jamais confirmée en jeu : je n'empile pas un second mécanisme dessus.
  3. Les tirer dans les deux camps. Un Bouffon dissident n'a pas de sens : ses propres alliés devraient l'épargner.
- **Contrôles :** syntaxe et portées, noms du jeu (aucun nom nouveau : tout repose sur des appels déjà utilisés par le mod), pages des rôles (1314 pages, 7 lignes au plus sous l'état, avec les touches « SOURIS 4/5 » aussi), essais de la mise à jour. **Aucun des six rôles n'a été lancé en jeu ; pas de relecture indépendante.**
- **Publication :** la version est installée chez l'utilisateur mais **pas étiquetée** : avec la mise à jour automatique, une étiquette l'enverrait à tous ses amis. Elle sera publiée à sa demande.

## D97 — Empoisonneur (version 0.10.0)

- **Pouvoir :** le joueur visé (4 m) meurt 60 s plus tard, de la main de l'hôte (l'appel `Death` déjà utilisé pour les Liés, redemandé une fois si le joueur était encore fantôme).
- **Contre :** la victime est prévenue 40 s avant sa mort et peut consommer un antidote avec la touche de consommation.
- **Options pour l'antidote :**
  1. **N'importe quel poisson par défaut, réglable (retenu).** Choix du réglage : aucun, un poisson, une plante en bocal, ou l'un des neuf objets. Un poisson quelconque se trouve en 40 s ; un objet précis demande de la chance.
  2. Un objet précis par défaut. Trop dépendant de ce que la machine à poissons veut bien donner.
  3. Pas d'antidote. Un mort sans rien pouvoir y faire : frustrant, et je l'avais annoncé avec un contre.
- **Avertissement :** réglé en secondes avant la mort plutôt qu'après l'empoisonnement, parce que c'est le temps laissé à la victime qui compte. 0 = jamais ; au moins égal au délai = aussitôt.
- **Consommation :** la même mécanique que la recharge (poisson retiré par l'hôte, bocal vidé par la machine du joueur puis vu par l'hôte). L'antidote passe avant la recharge ; si l'objet en main n'est pas l'antidote et que le rôle du joueur a un objet de recharge, c'est la recharge qui est tentée.
- **Pas de tueur :** la mort ne passe pas par l'accroche des coups, donc ni Martyr, ni Bouffon, ni rien qui désigne l'Empoisonneur.
- **Un seul poison par victime :** viser un joueur déjà empoisonné ne dépense rien.

## D98 — Bâillonneur (version 0.10.0)

- **Pouvoir :** le micro du joueur visé (10 m) est coupé 20 s.
- **Options :**
  1. **La machine de la victime coupe son propre micro (retenu).** `Can Talk = false` puis `Apply Mic State`, exactement ce que le mod fait depuis la 0.1 pour un Rêveur endormi. Un seul endroit, l'icône de micro du jeu suit, et la voix n'est même pas envoyée. Le jeu remet parfois `Can Talk` à vrai (nouveau personnage) : la machine le revérifie deux fois par seconde.
  2. Chaque autre machine rend la victime muette (`MuteRemoteTalker`). Sept endroits au lieu d'un, et le jeu refait ses propres choix de muet à chaque mort.
  3. Le drapeau « Mute Pause » du jeu. Il appartient au joueur (son propre réglage de muet) : je n'y touche pas.
- **La victime est prévenue :** elle le verrait de toute façon à son icône de micro.

## D99 — Voleur (version 0.10.0)

- **Pouvoir :** prend l'objet tenu en main par un joueur à 2,5 m au plus.
- **Mécanisme :** l'hôte lit l'objet de la victime (objet, valeur d'état, temps d'état), le retire de sa main par les deux appels du jeu déjà employés pour le poisson consommé (`Let Item`, `Net Let Item`), vérifie que la main est vide, puis le met dans la main du Voleur par les deux appels du ramassage (`Net Take Item`, `Take Item`), dans le même état.
- **Options :**
  1. **Vrai vol, main vers main (retenu).**
  2. Faire tomber l'objet (désarmer). Plus simple, mais ce n'est pas un vol, et l'objet au sol profite à n'importe qui.
  3. Voler aussi le sac. Le sac ne se voit pas : le vol deviendrait un tirage au sort.
- **Garde-fous :** main du Voleur vide, victime qui tient quelque chose, aucun des deux en train d'échanger main et sac ; rien n'est dépensé si le vol ne se fait pas. Pas sur un Rêveur endormi (l'appel se ferait sur une machine en mode fantôme).

## D100 — Écho (version 0.10.0)

- **Pouvoir :** retour à l'endroit occupé 5 s plus tôt.
- **Mécanisme :** l'hôte note la position de chaque Écho quatre fois par seconde (il connaît déjà la position de tous) et garde les 6 dernières secondes ; le retour se fait par `Request TP`, comme pour l'Échangeur. Rien à faire côté joueur.
- **Options :**
  1. **Le trajet repart de zéro après un retour (retenu).** Sinon un second appui renverrait avant le premier saut, ce qui se lit mal.
  2. Trajet continu. Permettrait de remonter de 10 s en deux appuis : c'est un autre pouvoir.
- **Trajet trop court** (moins d'une seconde) : refus, rien n'est dépensé.

## D101 — Amnésique (version 0.10.0)

- **Pouvoir :** prend le rôle et le camp d'un mort, visé (10 m) ou tout proche (2,5 m), comme le Métamorphe sur un cadavre.
- **Options :**
  1. **Un mort sans rôle ne donne rien, et rien n'est perdu (retenu).** L'Amnésique apprend seulement que ce mort n'avait pas de rôle et peut en essayer un autre.
  2. Prendre le seul camp d'un mort sans rôle. Il perdrait son statut pour devenir un joueur ordinaire : décevant.
- **Camp :** si le mort était dissident, l'Amnésique est converti par la fonction du Recruteur (rôle du jeu, listes, sphères), avec son propre message.
- **Rôle :** attribué comme en début de partie (utilisations pleines). Pour un Shérif, la personne sûre et la carte sont préparées de nouveau ; pour une Taupe, les sphères sont corrigées. Le lien des Liés n'est pas un rôle : il ne se transmet pas.
- **Limite connue :** un Amnésique déjà converti par le Recruteur reste dissident quoi qu'il prenne ; rien dans le mod ne sait refaire un employé.

## D102 — Bouffon (version 0.10.0)

- **Règle :** il gagne seul si un employé le tue. Le tueur est connu comme pour le Martyr : le dernier joueur à l'avoir frappé, dans les 3 s. Un Amnésique qui n'a rien pris compte comme employé ; la Taupe, dissidente, non.
- **Fin de partie, options :**
  1. **Annonce du mod, puis fin de partie « forcée » du jeu (retenu).** `End Game(false, true)` : c'est le chemin que le jeu prend quand l'hôte arrête la partie, il n'affiche ni victoire ni défaite, ce qui est exact pour tous sauf le Bouffon. Le bandeau « LE BOUFFON GAGNE : … » est envoyé à la mort, puis de nouveau dans le lobby (les machines effacent les bandeaux en fin de partie).
  2. Fin normale avec victoire des dissidents ou des employés. L'écran du jeu mentirait à un des deux camps.
  3. Appeler l'écran de fin joueur par joueur. Possible, mais c'est refaire à la main ce que la fin de partie du jeu fait (retour au lobby, remise à zéro).
  4. Ne pas finir la partie. Proposé en réglage (« Sa victoire termine la partie » sur NON).
- **Délai de 3 s** entre l'annonce et la fin : le temps de lire le bandeau.
- **Limite connue :** une grenade tue sans tueur connu, donc ne fait pas gagner le Bouffon.
- **Version :** 0.10.0. Installée (jeu fermé), archive complète refaite. Pas publiée.

## D103 — Vampire (version 0.11.0)

- **Demande :** « un rôle "Vampire", il pourrait "vampiriser" les gens qu'il a tué (une fois par cadavre), lui donnait 10 hp max en plus à chaque fois (donc un rôle dissident) ».
- **Ce que dit le jeu :** la vie d'un personnage est tenue par la machine de son joueur, et la fonction qui applique un coup (`Hit Health`) la borne à 100 (`Clamp(vie - dégâts, 0, 100)`), puis déclenche la mort si elle tombe à 0. Les soins ne s'appliquent que sous 100. Le « Max HP » des données du joueur ne sert qu'à dessiner la barre de vie. Une accroche du mod sur cette fonction passe après elle.
- **Comment donner de la vie au-dessus de 100, options :**
  1. **Une réserve tenue par le mod, au-dessus des 100 du jeu (retenu).** Sur la machine du Vampire, après chaque coup reçu, la vie est remontée depuis la réserve (jusqu'à 100). Tant qu'il reste de la réserve, la vie reste donc pleine : la réserve est dépensée en premier, ce qui revient bien à 100 + réserve points de vie. Rien n'est écrit au-dessus de 100 : la barre de vie et les soins du jeu se comportent normalement.
  2. Écrire une vie supérieure à 100. Le coup suivant la rabattrait à 100 (la borne est dans la fonction du jeu), et la barre de vie n'est pas faite pour ça.
  3. Réduire les dégâts reçus à la place. Ce n'est pas ce qui est demandé, et l'effet serait proportionnel aux coups plutôt qu'un nombre de points.
- **Limite assumée :** un coup de 100 d'un seul coup tue, le jeu décidant de la mort avant le passage du mod. Écrit sur la page du rôle.
- **« HP max » et non simple bonus :** la réserve se régénère, au rythme de la vie du jeu (un point à chaque battement de `Regen HP Speed`, pendant que le jeu régénère et une fois la vie à 100). Chaque cadavre donne ses 10 PV tout de suite : un maximum qu'il faudrait d'abord remplir ne servirait à rien sur le moment.
- **« Les gens qu'il a tué » :** l'hôte note à chaque mort qui a porté le dernier coup dans les 3 s (le mécanisme du Martyr). Réglage « Seulement ses propres victimes », OUI par défaut ; sur NON, tout cadavre convient (utile aussi parce que grenades et poison ne désignent personne).
- **Le geste :** appui près du cadavre puis 3 s à rester près de lui, comme le Nettoyeur, plutôt qu'un effet immédiat : le temps passé sur le corps est ce qui expose le Vampire. Le corps reste en place.
- **Une fois par cadavre :** retenu par joueur mort et par mort ; un joueur réanimé puis tué de nouveau est un nouveau cadavre.
- **Qui sait quoi :** l'hôte ne connaît que le nombre de cadavres ; la réserve est tenue par la machine du joueur, qui l'ajoute à ce que la page du rôle affiche.
- **Contrôles :** syntaxe, noms du jeu, pages. **Jamais lancé en jeu ; pas de relecture indépendante.**

## D104 — Loup-garou (version 0.11.0)

- **Demande :** « en gentil, le Loup Garou, qui lui aussi pourrait interagir avec les cadavres, sauf que lui ça lui améliorerait sa régénération d'endurance/hp, de 10% à chaque fois ».
- **Ce que dit le jeu :** il a bien une régénération, réglée par les données du joueur (`Data_Player`, un seul objet par machine) : `Min Regen` et `Max Regen` (endurance récupérée par seconde au repos, selon la fatigue et la vie), `Regen HP Speed` (secondes entre deux points de vie rendus, tant que le jeu « régénère » et que la vie est sous 100).
- **Options :**
  1. **Multiplier ces trois valeurs sur la machine du Loup-garou (retenu).** `Min Regen` et `Max Regen` × (1 + 10 % par cadavre), `Regen HP Speed` divisé d'autant. C'est exactement « régénérer 10 % plus vite », calculé par le jeu lui-même.
  2. Ajouter de la vie et de l'endurance par le mod, à côté du jeu. Il faudrait recopier les formules du jeu (repos, délais après l'effort, fatigue) : fragile, et faux à la première mise à jour du jeu.
- **Précaution :** ces données survivent à la partie. Les valeurs d'origine sont lues une fois, tout est toujours recalculé à partir d'elles, et elles sont remises à la fin de la partie, au changement de rôle et quand le joueur quitte la partie. Un redémarrage du jeu les recharge de toute façon.
- **Effets cumulés par addition** (deux cadavres : +20 %), pas par multiplication : plus simple à lire sur la page du rôle.
- **N'importe quel cadavre**, puisque c'est un employé : il ne tue pas, en principe. Camp réglable, employé par défaut.
- **Même geste que le Vampire** (appui puis 3 s près du corps), même mécanisme côté hôte. Les deux rôles peuvent se servir du même corps, chacun une fois.
- **Détail :** pour la vie, le jeu ne relit le rythme qu'au début d'un repos ; le gain s'applique donc au repos suivant.
- **Version :** 0.11.0. Installée (jeu fermé), archive complète refaite. Pas publiée.

## D105 — Onglet LPROLES : un groupe de réglages à la fois (version 0.11.1)

- **Demande :** « est-ce possible d'améliorer le menu de réglages du mod car ça devient très long à scroll avec tout ces rôles, et du coup mettre de façon plus accessible la catégorie "Test" car actuellement je dois scroll tout en bas pour pouvoir changer le rôle forcé entre chaque test ».
- **Erreur de ma part, trouvée en relisant le menu :** la liste des groupes affichés (`C.GROUPS`) était écrite à la main et je n'y avais pas ajouté les huit nouveaux rôles. En 0.10.0 et 0.11.0, leurs réglages existaient (dans `config.txt`, et par les touches F5 à F8) mais **leurs groupes n'apparaissaient pas dans l'onglet**, contrairement à ce que j'avais écrit. Aucun contrôle ne reliait cette liste aux réglages. Corrigé à la racine : la liste est maintenant tirée des réglages eux-mêmes, un groupe ne peut plus y manquer.
- **Options pour raccourcir la page :**
  1. **Une rangée « Réglages affichés » qui choisit le groupe montré ; les autres sont repliés (retenu).** La page de l'hôte fait au plus une dizaine de rangées. Les rangées repliées le sont comme celles de l'aide du rôle le sont depuis longtemps (visibilité « repliée »), une technique déjà éprouvée en jeu. Rien n'est créé ni détruit en changeant de groupe.
  2. Seulement remonter TEST en haut. Règle la moitié de la demande ; la page resterait longue de 140 rangées.
  3. Des groupes qui se déplient au clic sur leur titre. Les titres du jeu ne sont pas cliquables ; il faudrait d'autres gadgets que ceux du menu.
  4. Plusieurs onglets. Chaque onglet déplace ceux du jeu dans la colonne (D-menu) : trop de manipulations pour un gain égal.
- **Ordre :** MES RÉGLAGES, TEST, GÉNÉRAL, RÔLES ACTIFS, puis les rôles par ordre alphabétique (sans tenir compte des accents) : avec 24 rôles, on sait de quel côté tourner, et la flèche gauche boucle vers la fin de l'alphabet. TEST est à un clic ; si un rôle est forcé pour l'hôte, l'onglet s'ouvre dessus.
- **RÔLES ACTIFS :** un groupe de plus, qui réunit les 24 interrupteurs. Sans lui, activer ou couper plusieurs rôles demanderait de visiter chaque groupe : ce serait pire qu'avant. Chaque interrupteur a donc deux rangées (ici et dans le groupe du rôle) ; un clic sur l'une réécrit l'autre.
- **« Rôle forcé pour l'hôte » :** ses 24 choix passent aussi en ordre alphabétique, puisque l'utilisateur le change à chaque essai.
- **Groupe retenu** d'un menu à l'autre pendant le lancement (le menu est reconstruit à chaque partie) ; pas enregistré dans `config.txt`.
- **Les joueurs qui ne sont pas hôtes** gardent leur page d'avant (leur rôle, puis MES RÉGLAGES) : elle est courte.
- **Notes de version :** une version jamais publiée est marquée « (non publiée) » dans `CHANGELOG.md` ; à la publication suivante, `deploy.py` joint ces sections aux notes, pour que la page GitHub dise tout ce qui arrive chez les joueurs.
- **Contrôles :** syntaxe, noms du jeu, pages, ordre alphabétique vérifié par un calcul à part. **Jamais lancé en jeu ; pas de relecture indépendante.**
- **Version :** 0.11.1. Installée (jeu fermé), archive complète refaite. Pas publiée.

## D106 — Empoisonneur : antidote raffiné tiré au hasard, 3 minutes (version 0.11.2)

- **Demande :** « Pour l'antidote, je pensais à l'item donné quand on "raffine" une ou deux plantes entre elles, et l'antidote serait choisi à chaque fois aléatoirement parmi toutes les plantes raffinées (hors raffinages de plusieurs plantes, seulement ceux d'une seule plante), et pour les timings, il faudrait que l'empoisonnement dure 3minutes, et qu'à 2 minutes restantes le joueur apprend qu'il est empoisonné et la plante de l'antidote ».
- **Ce que dit le jeu :**
  - La **centrifugeuse** prend un bocal contenant une plante (numéro 1 à 5), rend le bocal sale et sort un **échantillon** (`/Game/Items/Melee/ProcessedSample/DA_Sample`) dont l'état porte le numéro de la plante et un « temps » de 0 (1 pour la plante rouge).
  - Le **mélangeur** prend un échantillon d'une plante de 1 à 4 et un échantillon rouge, et sort un échantillon du numéro de la première avec un « temps » supérieur à 0. Il ne sort jamais de numéro 5.
  - Un échantillon d'une seule plante se reconnaît donc ainsi : numéro de la plante voulue, et temps nul (ou plante rouge).
  - Boire un échantillon appelle chez l'hôte `Add Buff(état, données)`, avec l'état de l'objet bu.
- **Décisions :**
  - L'antidote d'un empoisonnement est tiré parmi les cinq plantes au moment où le poison est donné, et gardé par l'hôte. L'Empoisonneur ne le connaît pas.
  - Délais par défaut : mort après 180 s, victime prévenue 120 s avant (les réglages restent ceux de D97, en secondes ; maximum porté à 600).
  - Les anciens choix d'antidote (poisson, plante en bocal, objet précis), que j'avais imaginés en D97, sont retirés : le réglage devient un simple OUI/NON.
- **Comment la victime se soigne, options :**
  1. **En buvant l'échantillon comme le jeu le prévoit, vu par une accroche sur `Add Buff` (retenu), avec en secours la touche de consommation du mod.** Boire est le geste que tout joueur fera spontanément ; s'il ne soignait pas, le joueur perdrait son antidote et mourrait sans comprendre. La touche du mod reste possible (l'échantillon est alors retiré de la main par les appels déjà utilisés pour le poisson, sans son effet).
  2. Seulement la touche du mod. Plus sûr techniquement (rien de nouveau), mais piégeux pour le joueur.
- **Risque noté :** c'est la première fois que le mod lit un paramètre de type structure dans une accroche (`état` de `Add Buff`). Si cette lecture échoue en jeu, le journal l'écrit (« état de l'objet bu … illisible ») et il reste la touche de consommation.
- **Où lire l'antidote :** deux bandeaux à l'avertissement, puis la première ligne de la page du rôle (tablette et onglet) tant que le poison court : « Empoisonné : mort dans … s - antidote : G3M raffiné, à boire ». Elle remplace la ligne d'état du rôle plutôt que de s'ajouter, la tablette n'affichant que sept lignes. Un joueur sans rôle a la même ligne.
- **Soin avant l'avertissement :** le bon échantillon bu par hasard soigne quand même.
- **Réglages de l'utilisateur :** son `config.txt` gardait les valeurs de la 0.10.0 (60 s et 40 s) ; je les ai mises à 180 et 120, comme demandé. L'ancien choix d'antidote (« fish ») n'est plus une valeur valable : le mod reprend la valeur par défaut, OUI.
- **Contrôle ajouté :** `pages.py` refuse désormais une apostrophe collée à un mot en gras (« l'*objet* »), que la tablette dessine en deux morceaux écartés ; j'avais fait la faute trois fois.
- **Contrôles :** syntaxe, noms du jeu (dont `Add Buff` et l'échantillon), pages. **Jamais lancé en jeu ; pas de relecture indépendante.**
- **Version :** 0.11.2. Installée (jeu fermé), archive complète refaite. Pas publiée.

## D107 — La ligne du poison sur la tablette (version 0.11.3)

- **Question de l'utilisateur :** « est-ce que la ligne d'empoisonnement est aussi sur la tablette du joueur ? »
- **Réponse, vérifiée dans le code de la tablette :** oui. La tablette et l'onglet LPROLES tirent leurs lignes de la même fonction (`RT.lines`). Avec un rôle, la ligne du poison prend la place de la ligne d'état, que la tablette écrit dans son bandeau sombre ; sans rôle, la tablette n'a pas de bandeau et la ligne est la première de la page.
- **Deux retouches faites en vérifiant :**
  - La ligne est raccourcie (« Poison : mort dans 118 s - antidote : G3M raffiné », 49 caractères), pour ne pas dépasser les lignes d'état déjà vues sur le bandeau en jeu (52 caractères pour une vision en cours). Le bandeau passe à la ligne s'il le faut, mais il pousserait alors les sept lignes d'explication vers le bas.
  - La tablette colore le nom de la plante de la page (l'objet de recharge du rôle). Elle cherchait ce nom dans toutes les lignes, bandeau compris : pendant un empoisonnement elle aurait pris la plante de l'antidote, et l'objet de recharge aurait perdu sa couleur. Elle ne regarde plus que les lignes sous le bandeau. Pour un joueur sans rôle, la plante de l'antidote est donc bien colorée.
- **Jamais lancé en jeu ; pas de relecture indépendante.**
- **Version :** 0.11.3. Installée (jeu fermé), archive complète refaite. Pas publiée.

## D108 — La vie en plus du Vampire sur le HUD (version 0.11.4)

- **Demande :** « est-ce possible d'améliorer le vampire pour qu'on puisse voir les hp en plus sur l'hud ? »
- **Ce que dit le jeu :** la partie du HUD qui montre la vie (`W_PlayerState`) a une barre et un nombre. La barre est recalculée à chaque image à partir de la vie du personnage et du « Max HP » des données du joueur. Le nombre, lui, n'est écrit que par la fonction `Set HP`, appelée quand la vie change : c'est la vie du personnage, 100 au plus. Sa couleur et sa position sont animées à chaque image.
- **Options :**
  1. **Ajouter la réserve au nombre, juste après que le jeu l'a écrit (retenu).** Une accroche sur `Set HP` réécrit le nombre avec vie + réserve : « 115 ». Le texte passe par la fabrication de texte du moteur, comme tous ceux que le mod écrit. Quand la réserve change sans que la vie change (elle se régénère, un cadavre est vampirisé), le mod demande au jeu de réécrire le nombre.
  2. Allonger la barre en montant le « Max HP » du jeu. La barre afficherait vie ÷ maximum : avec 100 de vie et un maximum de 120 elle ne serait jamais pleine, la vie du jeu ne dépassant pas 100. Trompeur.
  3. Dessiner une seconde barre. Des éléments nouveaux dans le HUD du jeu, pour une information que le nombre donne déjà.
  4. Écrire « 100 +15 ». Plus explicite, mais le nombre est posé sur la barre et se déplace avec elle : un texte deux fois plus long risquait de déborder.
- **Ce qui ne change pas :** la barre (pleine à 100), la couleur du nombre (animée par le jeu), la ligne de la page du rôle.
- **Contrôles :** syntaxe, noms du jeu (`Set HP`, `HPtext`, `Mec Ref` de `W_PlayerState`), pages. **Jamais lancé en jeu ; pas de relecture indépendante.**
- **Version :** 0.11.4. Pas installée : le jeu tournait. Pas publiée.

## D109 — Publication de la 0.11.4

- **Demande :** « publie la », après que j'ai expliqué que la mise à jour automatique ne distribue que les versions publiées, et que son amie, installée en 0.11.3 par l'archive, ne recevrait la 0.11.4 qu'à cette condition.
- **Fait :** étiquette `v0.11.4` poussée ; le flux GitHub a réussi et publié `LPRoles.zip` et `version.txt`. Les notes de la page reprennent les sections 0.11.3, 0.11.2, 0.11.1 et 0.11.0, jamais publiées séparément (marquées depuis « publiée avec la 0.11.4 » dans `CHANGELOG.md`, pour ne pas être reprises une seconde fois).
- **Vérifié contre la vraie page**, par la commande exacte que le mod lance : une copie exacte de la 0.11.3 (les fichiers de son commit, plus des réglages et un journal) passe en 0.11.4 en 1,9 s, tous les fichiers identiques aux sources, réglages et journal gardés ; même chose depuis une copie de la 0.9.0 (1,4 s). Relancée, la mise à jour répond « rien à faire » en 0,6 s.
- **Chez l'utilisateur :** son jeu tournait, je n'y ai rien installé. Il a la 0.11.3 et se mettra à jour tout seul au prochain lancement : ce sera la **première vraie mise à jour faite depuis le jeu** (bandeau « LPROLES MIS À JOUR : VERSION 0.11.4 », ligne « Mise à jour faite au lancement : 0.11.3 -> 0.11.4 » dans le journal).
- **Portée :** toute installation en 0.9.0 ou plus reçoit cette version, avec huit rôles, un onglet et un antidote qui n'ont jamais tourné en jeu. L'utilisateur le savait en demandant la publication.
- **Règle pour la suite :** inchangée tant qu'il n'a pas répondu à la question posée deux fois : je ne publie que sur sa demande.
- **Archive complète** refaite en 0.11.4 pour les premières installations ; une archive 0.11.3 déjà donnée se met à jour seule.

## D110 — Premier essai à deux des nouveaux rôles, première mise à jour depuis le jeu (constats)

- **Source :** le journal de l'utilisateur (hôte), session du 8 octobre de 20 h 13 à 20 h 54 en 0.11.3 avec une amie, puis relance à 20 h 58.
- **Mise à jour automatique :** « Mise à jour faite au lancement : 0.11.3 -> 0.11.4 (3.0 s) », puis chargement en 0.11.4 dans le même lancement ; les fichiers installés sont identiques aux sources de la 0.11.4. C'était le dernier point jamais vu du mécanisme (D95).
- **Rôles, d'après le journal de l'hôte, sans aucune ligne d'erreur :**
  - **Écho :** sept retours, de 4,8 à 4,9 s en arrière.
  - **Amnésique :** prend le rôle Écho d'une morte employée, puis s'en sert ; une autre fois, celui d'une morte dissidente, devient dissident, et la partie à deux se termine aussitôt (plus aucun employé en vie), ce qui est la règle.
  - **Empoisonneur :** premier poison soigné par l'antidote au bout de 2 min 23 (plante rouge) ; second poison mortel à 180 s exactement.
  - **Bâillonneur :** deux bâillons de 20 s lancés.
  - **Voleur :** un défibrillateur pris à l'autre joueur.
  - **Bouffon :** tué par une employée, victoire annoncée, fin de partie 3 s plus tard.
  - **Vampire :** un cadavre vampirisé, « vie maximale 100 + 10, réserve 10 ».
  - **Loup-garou :** valeurs du jeu lues (endurance 10 à 40 par seconde, 1 PV toutes les 2 s), +10 % puis +20 %.
  - **Ange gardien et Liés** (plus anciens) : protégé sauvé, lien joué.
- **Ce que le journal ne dit pas :** ce que les joueurs ont vu et entendu (micro réellement coupé, bandeaux, page de la tablette, objet volé dans le bon état, endurance plus rapide). À confirmer par l'utilisateur.
- **Trois points relevés pour lui demander :**
  1. Le Loup-garou a dévoré deux fois le même joueur à 58 s d'écart. C'est voulu si ce joueur a été réanimé puis tué de nouveau entre-temps (D103), une faute sinon.
  2. La portée du Voleur a été passée de 250 à 600 cm juste après le vol : la valeur par défaut est peut-être trop courte.
  3. Changer « Rôle forcé pour l'hôte » lui a demandé une vingtaine de clics à chaque essai.
