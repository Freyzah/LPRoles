# LPRoles

Des rôles supplémentaires pour **LOCKDOWN Protocol** : un mod en Lua pour [UE4SS](https://github.com/UE4SS-RE/RE-UE4SS).

Chaque joueur peut recevoir, en plus de son camp, un rôle avec un pouvoir : Shérif, Recruteur, Rêveur, Fée, Médium, Ange gardien, Taupe, Traqueur, Hypnotiseur, Métamorphe, Nettoyeur, Clandestin, Échangeur, Martyr, Revenant, Empoisonneur, Bâillonneur, Voleur, Écho, Amnésique, Bouffon, Vampire, Loup-garou, Médecin, ainsi que le lien des Liés. L'hôte choisit les rôles en jeu et règle chacun d'eux dans le menu Échap, onglet **LPROLES**.

**Tous les joueurs de la partie doivent avoir le mod, à la même version.**

## Mettre à jour

Rien à faire : à chaque lancement du jeu, le mod regarde si une version plus récente est [publiée ici](../../releases/latest), la télécharge, la vérifie et l'installe avant de se charger. Un bandeau « LPROLES MIS À JOUR » le signale. Vos réglages, votre journal et les sons que vous avez remplacés par les vôtres sont gardés.

- **À la main :** double-clic sur `mettre-a-jour.bat` dans le dossier du mod (`LockdownProtocol\Binaries\Win64\ue4ss\Mods\LPRoles\`), jeu fermé. Il remet aussi en état une installation abîmée.
- **Pour couper la mise à jour automatique :** menu Échap, onglet LPROLES, MES RÉGLAGES, « Mise à jour automatique au lancement ».

Ce mécanisme existe depuis la version 0.9.0 : depuis une version plus ancienne, il faut installer une dernière fois à la main.

## Installer la première fois

Il faut UE4SS et le mod. L'hôte fournit une archive complète, `LPRoles-<version>-pour-les-joueurs.zip` : coller son contenu (le dossier `LockdownProtocol`) dans le dossier du jeu, celui qui contient `LockdownProtocol.exe`, en acceptant la fusion des dossiers. Puis lancer le jeu.

- Pour tout désactiver : renommer `LockdownProtocol\Binaries\Win64\dwmapi.dll` en `dwmapi.dll.off`.
- Pour désactiver seulement LPRoles : supprimer `ue4ss\Mods\LPRoles\enabled.txt`.

## En cas de souci

Le mod tient un journal, `ue4ss\Mods\LPRoles\journal.txt`, conservé d'un lancement à l'autre. C'est le premier fichier à joindre à un [signalement](../../issues).

## Documents

- [CHANGELOG.md](CHANGELOG.md) : les versions.
- [docs/LISEZ-MOI-LPRoles.md](docs/LISEZ-MOI-LPRoles.md) : le manuel complet (rôles, touches, réglages, limites connues).
- [docs/decisions-mod.md](docs/decisions-mod.md) : chaque décision prise, avec les options écartées.
- [analysis/NOTES.md](analysis/NOTES.md) : ce qu'on sait du fonctionnement interne du jeu.

## Développer

| Dossier | Contenu |
|---|---|
| `mod/LPRoles/` | Le mod tel qu'il est installé : `Scripts/` (Lua), `sounds/`, `update.ps1`, `mettre-a-jour.bat` |
| `tools/deploy.py` | Installe le mod dans le jeu, construit les archives |
| `tools/lp/` | Vérifications (`luacheck.py`, `verify_mod.py`, `pages.py`, `banners.py`) et outils d'analyse du jeu |
| `tools/test_update.py` | Essais de la mise à jour contre un serveur local |
| `.github/workflows/release.yml` | Publication d'une version |

Les outils qui lisent le jeu ont besoin de son dossier : l'écrire sur la première ligne de `tools/dossier-du-jeu.txt` (fichier local, hors du dépôt). Les données tirées du jeu ne sont pas dans le dépôt ; `python tools/lp/bp.py --all analysis/bp` les refabrique.

Avant toute version :

```
python tools/lp/luacheck.py mod/LPRoles/Scripts/*.lua
python tools/lp/verify_mod.py
python tools/lp/pages.py
python tools/lp/banners.py
python tools/test_update.py
```

### Publier une version

1. Changer `U.VERSION` dans `mod/LPRoles/Scripts/lpr_util.lua` et ajouter une section `## X.Y.Z` en tête de `CHANGELOG.md`.
2. `python tools/deploy.py` (installe dans le jeu et met `manifest.txt` à jour), puis essayer en jeu.
3. Valider, étiqueter, pousser :

```
git commit -am "Version X.Y.Z"
git tag vX.Y.Z
git push origin main vX.Y.Z
```

GitHub construit alors `LPRoles.zip` et `version.txt` et crée la page de la version. Au lancement suivant du jeu, chaque joueur la reçoit.

`main.lua` ne doit pas changer d'une version à l'autre : c'est le seul script déjà chargé quand la mise à jour remplace les autres.
