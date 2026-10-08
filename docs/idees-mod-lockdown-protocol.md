# Mod LOCKDOWN Protocol — idées

Objectif : ajouter des rôles supplémentaires au jeu.

Principes retenus :
- **Un seul pouvoir par rôle.**
- **Paramètres configurables dans le lobby** (camps possibles, durées, utilisations de départ, cumul, etc.) ; les valeurs notées ci-dessous sont les réglages par défaut.

## Rôles envisagés

### Dissident « infecteur »
- Peut « infecter » un autre joueur pour le transformer en dissident.
- **Contrainte :** l'infection ne doit **pas** reposer sur une plante (voir « Système de plantes »).
- **À définir :** la façon dont il infecte (voir pistes ci-dessous).

### Shérif (côté gentils)
- Commence la partie avec une carte d'accès.
- Connaît dès le début l'identité d'une personne sûre.

### Onironaute / Rêveur (nom à choisir entre les deux)
- Pouvoir : se transformer en fantôme pendant quelques instants (15-20 s, à tester en jeu).
- Sous forme de fantôme :
  - ne voit pas et n'entend pas les autres fantômes (les morts) ;
  - entend toujours ce que disent les joueurs en vie.
- Le fantôme se comporte **exactement comme un fantôme de joueur mort** : il ne peut interagir avec rien (ni portes, ni objets, ni terminaux).
- Le fantôme **ne traverse ni les portes ni les murs**.
- Pendant le pouvoir, son corps reste sur place, endormi (assis), et **toujours vulnérable**.
- Si son corps est attaqué, il est **réveillé** (fin immédiate du pouvoir).
- Camp : peut être **gentil ou dissident**.
- **Activation :** fermer les deux yeux en même temps pendant 3 s.
- **Sortie anticipée :** fermer les deux yeux à nouveau (instantané).
- **Recharge :** pas de temps de recharge ; il récupère une utilisation en consommant une plante **G3M** (récoltée dans un bocal). Les utilisations **ne se cumulent pas** (une seule en réserve au maximum).
- Il **commence la partie avec une utilisation**.
- **À définir :**
  - consommation de la plante instantanée ou avec un temps d'action ?
  - voix pendant le pouvoir : a priori inaudible pour les vivants (comme un mort) et pour les morts — à confirmer.

### Fée (nom provisoire)
- Pouvoir : se transformer en petite fée pendant 2-3 s.
- Mêmes propriétés que le fantôme de l'Onironaute / Rêveur (aucune interaction, ne traverse ni portes ni murs, ne voit ni n'entend les morts, entend les vivants), **sauf** :
  - son corps **disparaît** pendant le pouvoir et **réapparaît à l'endroit où se trouve la fée** à la fin de la transformation ;
  - les vivants voient une **petite lumière** représentant la fée pendant la transformation.
- **Activation :** par un moyen différent de celui de l'Onironaute / Rêveur (à définir).
- La fée est **intouchable** pendant la transformation.
- **Vitesse :** identique à celle des fantômes du jeu, donc très rapide en sprint — c'est ce qui justifie la durée courte de 2-3 s.
- **Recharge :** en consommant une plante **WX2**.
- Elle **commence la partie avec une utilisation** ; les utilisations **ne se cumulent pas**.
- Camp : peut être **gentille ou dissidente**.
- **À définir :** le moyen d'activation.

## Système de plantes

- Les plantes récoltées en bocal servent de ressource pour recharger certains pouvoirs, **une plante par rôle** :
  - **G3M** → Onironaute / Rêveur ;
  - **WX2** → Fée.
- **Ne pas faire dépendre tous les rôles des plantes**, pour éviter que tout le monde se rue vers la salle botanique. L'infection, notamment, passe par autre chose.
- Idée écartée pour l'instant : un rôle unique dont le pouvoir change selon la plante consommée (éventuellement à garder pour un rôle à part plus tard).

## Pistes pour le mécanisme d'infection

Contrainte : pas de plante.

1. **Contact prolongé** — maintenir une interaction sur la cible pendant quelques secondes, à courte distance. Risqué si quelqu'un regarde.
2. **Objet à usage unique** — une seringue (ou autre) à aller chercher sur la carte, ailleurs que dans la salle botanique, puis à utiliser sur un joueur. Laisse une chance aux autres de voir l'objet disparaître ou de surprendre l'infecteur.
3. **Piège sur une tâche** — l'infecteur contamine un terminal ; le prochain joueur qui l'utilise est infecté. Pas de contact direct, mais cible non choisie.
4. **Infection différée** — quelle que soit la méthode, la cible ne bascule qu'après un délai (ex. 60 s), pour qu'on ne puisse pas remonter facilement à l'infecteur.

## Garde-fous possibles (équilibrage)

- Une seule infection par partie.
- Infection impossible avant X minutes de jeu.
- La cible est prévenue en privé qu'elle a changé de camp.
- Infecter le shérif échoue (et éventuellement révèle l'infecteur au shérif).

## Questions ouvertes

- La personne « sûre » sait-elle que le shérif la connaît ?
- Que se passe-t-il si la personne sûre du shérif est infectée plus tard ?
- Quel niveau de carte d'accès pour le shérif ?
- L'infecteur remplace-t-il un dissident normal ou s'ajoute-t-il ?

## Faisabilité technique (vérifiée le 2026-10-02)

**Verdict : faisable en principe.** Reste à lire les Blueprints du jeu pour confirmer rôle par rôle.

### Ce qui est établi

- **Moteur :** Unreal Engine 5.5 (version lue sur l'exe du jeu installé ; build datée de mi-septembre 2026).
- **Logique du jeu en Blueprint :** l'exe est le binaire générique « UnrealGame » et le manifeste liste `GM`, `GS`, `PC`, `MainGI`, `Mec` (le personnage), `TaskManager`… comme assets. C'est le cas le plus favorable pour modder.
- **Méthode des mods existants :** UE4SS (chargeur) + mod Blueprint déposé dans `LockdownProtocol\Content\Paks\LogicMods` (3 fichiers). C'est ce que fait ReviveLP.
- **ReviveLP** est installé par l'hôte seul, ajoute des réglages au lobby, ranime des joueurs et rend les dissidents visibles : preuve qu'un mod peut modifier les règles et le lobby côté hôte.
- **RiceMod :** outils d'hôte (anti-grief, admin, construction, couronnes). Méthode de fabrication non confirmée (page Nexus illisible automatiquement).
- **UE4SS** gère UE 5.5 dans sa version expérimentale. Il n'est pas encore installé dans le jeu.

### Briques déjà présentes dans le jeu (noms d'assets)

| Besoin du mod | Asset existant |
|---|---|
| Rôles | `Gameplay/E_PlayerRole` |
| Fermer les yeux | `Gameplay/E_EyeState`, `Inputs/Character/IA_EyeL`, `IA_EyeR`, `MatPP_EyeClosed` |
| Fantôme | `Character/Ghost/…`, `Skins/Default/Ghost/…` |
| Règles du lobby | `World/Tasks/DT_GameRules`, `E_RuleType`, `Str_gamerule`, `UI/Menu2/W_Menu_Rules`, `W_Settings_Rule`, `Gameplay/RuleSave` |
| Carte d'accès | `Items/Melee/AccessCard/DA_AccessCard` |
| Plantes et bocal | `Items/TaskPlants/Plant_{Blue,Green,Red,White,Yellow}_Sample`, `Items/Melee/SampleContainer` |
| Effets consommables | `Character/Buff`, `Items/Sample/…` (heal, speed, poison, blind…) |

Les plantes sont nommées par couleur dans les fichiers : il faudra retrouver lesquelles correspondent à G3M et WX2.

### Difficulté estimée par rôle (avant lecture des Blueprints)

- **Shérif — facile :** donner un objet existant au départ et envoyer une info à un seul joueur.
- **Réglages dans le lobby — facile à moyen :** ReviveLP le fait déjà.
- **Infecteur — moyen :** changer le rôle d'un joueur en cours de partie et s'assurer que les conditions de victoire suivent.
- **Onironaute / Rêveur — moyen à difficile :** fantôme et yeux existent déjà ; le point délicat est le chat vocal (ne pas entendre les morts, ne pas être entendu).
- **Fée — moyen à difficile :** comme le Rêveur, plus la lumière visible par les vivants et le corps masqué puis déplacé.

### Inconnues

- **Hôte seul ou tous les joueurs ?** Tant que le mod réutilise des éléments existants du jeu, l'hôte seul peut suffire. Tout élément nouveau (interface, modèle, effet visuel) oblige chaque joueur à installer le mod.
- **Chat vocal :** fonctionnement interne à examiner.
- **Position des développeurs sur les mods :** pas de réponse officielle trouvée.
- **Mises à jour du jeu :** chaque mise à jour peut casser le mod.

### Outils nécessaires

- **UE4SS** (version expérimentale) : charge les mods et permet d'inspecter le jeu en direct.
- **FModel** : pour lire les Blueprints du jeu.
- **Unreal Engine 5.5** (éditeur) : pour fabriquer le mod Blueprint.

### Prochaine étape

Installer UE4SS et FModel, puis lire `GM`, `GS`, `PC`, `Mec` et le fantôme pour confirmer comment les rôles, la mort et le chat vocal sont gérés.


---

## Rôles ajoutés en version 0.3.0 (3 octobre 2026)

Retenus par l'utilisateur parmi mes propositions : **Médium**, **Ange gardien**, **Taupe**, **Traqueur**, **Hypnotiseur**, **Liés**, **Échangeur**, **Martyr**, **Revenant**. L'Infecteur s'appelle désormais **Recruteur**. Fonctionnement détaillé : `LISEZ-MOI-LPRoles.md` ; décisions : `decisions-mod.md` (D31 à D36).

Pistes proposées mais non retenues : Légiste (camp du tueur près d'un cadavre), Réanimateur (ranimer un mort une fois).

---

## Rôles ajoutés en version 0.10.0 (8 octobre 2026)

Retenus par l'utilisateur parmi mes dix propositions : **Empoisonneur**, **Bâillonneur**, **Voleur**, **Écho**, **Amnésique**, **Bouffon**. Fonctionnement détaillé : `LISEZ-MOI-LPRoles.md` ; décisions : `decisions-mod.md` (D96 à D102).

Pistes proposées mais non retenues : Détective (apprend si le joueur visé a frappé quelqu'un dans la dernière minute), Vigile (balise invisible qui prévient quand quelqu'un passe), Vengeur (à sa mort, son tueur meurt aussi, ou est montré à tous), Médecin (rend sa vie à un joueur visé).
