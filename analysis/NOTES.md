# Notes d'analyse — fonctionnement interne de LOCKDOWN Protocol

Établi en lisant les fichiers du jeu (build de mi-septembre 2026, UE 5.5), sans lancer le jeu.
Outils : `tools/lp/` (`iostore.py`, `zen.py`, `bp.py`, `trace.py`). Pseudo-code complet : `analysis/bp/`.

## Classes principales

| Classe | Chemin | Rôle |
|---|---|---|
| `GM_C` | `/Game/Gameplay/GM` | GameMode (hôte uniquement) |
| `Mec_C` | `/Game/Character/Mec` | Personnage du joueur (pion). Sert aussi de fantôme quand il est mort |
| `PC_C` | `/Game/Gameplay/PC` | PlayerController |
| `MainGI_C` | `/Game/Gameplay/MainGI` | GameInstance |
| `FunctionLibrary_C` | `/Game/Other/FunctionLibrary` | Fonctions statiques (`Get Rule`…) |
| `Plant_C` | `/Game/World/Tasks/Task_Plants/plant` | Plante récoltable |
| `DeadBody_C` | `/Game/Character/Ghost/DeadBody` | Cadavre (acteur local) |

## Énumérations (valeurs réelles)

- `E_PlayerRole` : 0 None, 1 Not Ready, 2 Ready, 3 Innocent (employé), 4 Impostor (dissident), 5 Dead.
- `E_EyeState` : 0 Open, 1 Left, 2 Right, 3 Closed, 4 Lock (les deux yeux fermés et verrouillés).
- `E_Difficulty` : 0 Training, 1 Beginner, 2 Normal, 3 Custom.
- `E_Logic` (type d'objet) : 1 Container (bocal), 2 Sample, 3 Seringe, 15 Card…
- `Enum_Stance` : 0 Stand, 1 Walk, 2 Jog, 3 Air, 4 Sit, 5 Run.
- Type de plante (`Plant_C.Type`) : 1 verte, 2 jaune, 3 bleue, 4 blanche, 5 rouge.
- Codes affichés : G3M, WX2, BO4, Y8Z, RU2 (G3M = verte, WX2 = blanche, par les initiales de couleur).

## Structures

- `Str_ItemState` : `Value_8_5511228644AD6F4D6D0589BD4438C32F` (int), `Time_15_AFBBFC834F820A0E18A707A477B6D3FE` (int).
- `Str_Item` : `Data_18_5511228644AD6F4D6D0589BD4438C32F` (Data_Item_C*), `State_19_AFBBFC834F820A0E18A707A477B6D3FE` (Str_ItemState).
- `Str_AliveState` (`Mec.Net Alive State`) : `Alive_1_FD4B56084F2C8B7E0C61E289ED8A12E8` (bool), `Front_3_…`, `Location_6_3846B1B5464EC1C009D1039EC345EE21`, `Orientation_9_CABC5B924EC7C54F522C87A43A8B161B`.

## GameMode (`GM_C`)

- Variables : `Players`, `Innocents`, `Hackers` (tableaux de Mec), `In Game`, `Difficulty`, `Rules` (Map nom→int), `Game Time`, `Modded`.
- `Start Game()` : `In Game = true`, `Set inGame(true)` sur chacun, puis `Select Game Roles(n)` ; 1 s plus tard : `TP Players on Start`, `Set HackerSphere(false)`, génération des tâches, minuteur.
- `Select Game Roles(n)` : mélange les joueurs valides ; les `n` premiers → rôle 4 + `Game Start Message(true)`, les autres → rôle 3 + `Game Start Message(false)` ; remplit `Hackers` / `Innocents`.
- Nombre de dissidents : Training 0 ; Beginner 1 si > 2 joueurs ; Normal 2 si > 6, 1 si > 2 ; Custom = règle `DissidentCount`.
- `End on Death()` → `Check Deaths` : si tous les `Innocents` ont `Net Alive State.Alive == false` → 0,5 s plus tard `End Game(false,false)`.
- `End Game(InnocentWin, Force)` : `End Message(InnocentWin, estEmployé)` à chacun (estEmployé = pas dans `Hackers`), puis retour lobby, `Reset Player`, rôle 1.
- `Set HackerSphere(false)` : appelle `Set Hacker Sphere(Hackers)` sur chaque joueur.
- Règles lues par `FunctionLibrary.Get Rule(nom, contexte, out valeur)` : `DissidentCount`, `SessionTimer`, `SpawnType`…

## Personnage (`Mec_C`)

- Variables répliquées utiles : `Player Role`, `Net Alive State`, `Net EyesState`, `Net Stance`, `Net Hand ItemNew`, `Net Bag ItemNew`, `PlayerName`, `Player Index`.
- Variables locales utiles : `Alive`, `Health`, `Stamina`, `Can Talk`, `Me` (Mec du joueur local), `Mecs` (tous les Mec), `HUD` (W_inGame), `Hand Item`, `Hand State`.
- `Alive` (local) pilote tout le comportement local : mouvement fantôme (`Dead Velocity`), interactions interdites, caméra.
- Position : le client envoie `Net Update Locomotion(Location, Velocity, Aim, Orientation)` → l'hôte rediffuse `All Update Locomotion` → chacun stocke `Net Location`. La position est donc décidée par le client.
- Yeux : `Net Eye State(état)` (RPC serveur) → `Net EyesState` répliqué. Non bloqué quand on est mort.
- Dégâts : l'attaquant appelle `Net Deal Damage(Victim, …)` (serveur) → `Victim.Take Damage(…)` (RPC client) → `Hit Health` baisse `Health` côté victime ; à 0 → `Death()` puis `Net Death()`. La vie n'est connue que du client.
- Mort : `Death(Orientation, Body)` (RPC client) : `Alive = false`, collision du corps coupée, cadavre créé, objets lâchés, puis `Net Death(...)` (serveur) qui met `Net Alive State.Alive = false`.
- Réanimation : `Rez Effect(Location, Orientation)` (RPC client) remet `Alive = true`, vie 20, puis `Net Rez()` et téléportation au cadavre.
- `Death Update()` (sur chaque Mec, local) : si ce Mec est mort et que le joueur local est vivant → fantôme caché et voix coupée (`SteamUtilities.MuteRemoteTalker`) ; si le joueur local est mort → fantôme visible et voix rétablie.
- `Set Hacker Sphere(Hackers)` (RPC client) : affiche la sphère sur chaque Mec présent dans `Hackers`, seulement si le destinataire est lui-même dans `Hackers`.
- `Game Start Message(bool Hacker)` (RPC client) : écran d'annonce du rôle.
- `Game Count Message(int)` (RPC client) : `HUD.W_UpperNotif.Show Message(texte, couleur)`.
- Téléportation : `All TP(Location, Orientation)` (multicast).
- Aucune RPC client du jeu ne transporte de texte libre.

## Plantes

- Bocal = objet `DA_Container` (`/Game/Items/Melee/SampleContainer/DA_Container`), logique 1.
- Récolte : bocal vide en main + interaction avec une plante → `Set Sample(Type)` (local) → `Hand State.Value = Type` → `Net Set Item State`. L'hôte voit donc `Net Hand ItemNew.State.Value` = type de plante.

## Limites de l'outil UE4SS (Lua)

- Les accroches (`RegisterHook`) sur les fonctions Blueprint s'exécutent **après** la fonction : impossible de modifier ses paramètres avant ou de l'annuler.
- Les accroches sur les fonctions natives (`/Script/...`) peuvent s'exécuter avant.
- Une accroche ne se déclenche que sur la machine où le corps de la fonction s'exécute.
- Les tableaux n'ont pas de méthode d'ajout, mais on peut affecter une table Lua à une propriété tableau ou la passer en paramètre.

## Constats ajoutés après le premier test (2026-10-02)

- Les paramètres d'énumération des RPC sont transmis sur le nombre de bits strictement nécessaire : `E_EyeState` (0 à 4, MAX 5) tient sur 3 bits, donc seules les valeurs 0 à 7 traversent le réseau.
- Le bandeau `W_MainNotif` utilise une très grande police : environ 38 caractères sur toute la largeur de l'écran.
- `Game Start Message` verrouille les commandes du joueur environ 6 s (mode d'entrée « Locked »).
- Fermer les deux yeux passe à l'état 4 (Lock) : ils restent fermés au relâchement des touches.
- Menu Échap : `Mec.New Menu` (`W_NewMenu_C`) contient `MainTab` (colonne d'onglets : `Buttons`, `VerticalBox_50`) et `MainSwitcher` (une page par onglet, l'`ID` du bouton est l'indice de la page). Widgets de réglage réutilisables : `W_Settings_Selection_C`, `W_Settings_Value_C`, `W_Settings_Text_C`, `W_Settings_Title_C`.
- Le dossier de travail du jeu n'est pas celui d'UE4SS : les chemins relatifs `Mods/...` ne s'ouvrent pas.
- UE4SS trouve bien `ProcessLocalScriptFunction` sur ce jeu : les accroches Lua sur fonctions Blueprint fonctionnent.
- **UE4SS (build utilisée) : donner une chaîne Lua à un texte (`FText`) fait planter le jeu, que ce soit une variable ou un paramètre de fonction.** La branche « écriture » de `push_textproperty` suppose un objet texte d'UE4SS (texte rangé à l'octet 0x70 de l'objet) sans le vérifier. Il faut un vrai objet texte : par exemple le résultat de `KismetTextLibrary:Conv_StringToText(chaîne)`, ou le constructeur global `FText(...)`. Les écritures de structures, tableaux et objets vérifient leur type. `Show Message` (bandeaux) prend une simple chaîne (`str`), pas un texte.
- Le rapport de plantage du jeu (`%LOCALAPPDATA%\LockdownProtocol\Saved\Crashes\UECC-*\CrashContext.runtime-xml`) donne la pile avec l'adresse de base de chaque module. `tools/lp/pe_funcs.py <dll> <adresses relatives…>` rattache ces adresses aux fonctions d'UE4SS grâce à la table `.pdata` et aux chaînes que chaque fonction référence.
- **Apparence des joueurs :** la valeur dessinée est `Mec.Appearance` (`Str_PlayerAppearance` : `Color_2_…`, octet, et `Custom_5_…`, 17 éléments). Elle est répliquée et redessinée par `OnRep_Appearance`. Sur la machine du joueur, celle-ci l'enregistre aussi dans `Saved Appearance` (préréglage courant + couleur, emplacement `Save_Appearance2`). `Net Set Appearance` (serveur) passe par `GM.Switch Player Color`, la règle d'unicité des couleurs. L'ancienne valeur `Skin Set` n'est plus dessinée.
- **Tablette :** les boutons (`W_Tablet_ButtonText` → `W_Tablet_Trigger`) font leur propre test de survol, avec la position du curseur virtuel (0..2000 × 0..1500), et s'abonnent au clic de la tablette en la trouvant par le personnage du joueur. L'écran de partie est le panneau `GameMenu` du sélecteur `Switcher`.

## Écran de la tablette : comment il colore (2026-10-03, test de la 0.5.0)

- Matériau `Mat_WorldTabletScreen`, instance `M_WorldTabletScreen` (surcharge `Color 4` = 0,635 gris, `Cursor Color` = 10, `Emissive 4`), posée sur le WidgetComponent `Hand Widget` de `Tablet_C` ; `Set Screen Shader(Video)` bascule vers `M_TabletVideo` et retour (nouvelle MID).
- Paramètres vecteurs, dans l'ordre des valeurs en cache : Color A (1, 0,951, 0,854) fond ; Color B (0,25) encre sombre ; eColor (1,573, 1,814, 2) blanc lumineux ; Cursor Color ; Color 1..7 et Emissive 1..7 = couleurs des pièces.
- Pièces : texture `MiniMap_V3_SectorsColors2` (128×128 BGRA, gris 38/63/89/114/140/165/191 = pièces 1..7) : 1 caméras rouge, 2 bureaux jaune, 3 botanique vert, 4 restaurant gris, 5 hôpital cyan, 6 stockage orange, 7 machines bleu. Placée sur la zone de la carte, répétée au-delà.
- Canaux de l'interface : R = encre sombre, G = blanc lumineux (halo), B = couleur de la pièce sous le pixel (gris hors pièces). G domine B qui domine R.
- Vérifié sur la capture de la 0.4.3 : les taches rose / vert / kaki tombent sur les pièces caméras / botanique / bureaux.
- Outils : `scratchpad`-style scripts reading the export (names at offset ~505, vector values at offset 1178 of the export).
