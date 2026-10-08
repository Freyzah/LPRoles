-- LPRoles - texts shown to players (edit here to rename a role)
-- The on-screen banner uses a very large font: keep each line under about 30 characters.
-- Internal role ids never change (config.txt uses them); only the names below are shown.
local S = {}

S.ROLE_NAME = {
    sheriff   = "SHÉRIF",
    infector  = "RECRUTEUR",
    dreamer   = "RÊVEUR",
    fairy     = "FÉE",
    medium    = "MÉDIUM",
    angel     = "ANGE GARDIEN",
    mole      = "TAUPE",
    tracker   = "TRAQUEUR",
    hypnotist = "HYPNOTISEUR",
    mimic     = "MÉTAMORPHE",
    cleaner   = "NETTOYEUR",
    stowaway  = "CLANDESTIN",
    linked    = "LIÉ",
    swapper   = "ÉCHANGEUR",
    martyr    = "MARTYR",
    revenant  = "REVENANT",
    poisoner  = "EMPOISONNEUR",
    gagger    = "BÂILLONNEUR",
    thief     = "VOLEUR",
    echo      = "ÉCHO",
    amnesiac  = "AMNÉSIQUE",
    jester    = "BOUFFON",
}

-- Shown one after the other when the role is announced (how the role works is on the tablet
-- page and in the LPROLES tab; no reminder of that here, at the user's request).
S.ROLE_BANNER = {
    sheriff   = { "TU ES SHÉRIF" },           -- the card is announced once it is really shown
    infector  = { "TU ES RECRUTEUR" },
    dreamer   = { "TU ES RÊVEUR" },
    fairy     = { "TU ES FÉE" },
    medium    = { "TU ES MÉDIUM" },
    angel     = { "TU ES ANGE GARDIEN" },
    mole      = { "TU ES LA TAUPE", "INVISIBLE DES DISSIDENTS" },
    tracker   = { "TU ES TRAQUEUR" },
    hypnotist = { "TU ES HYPNOTISEUR" },
    mimic     = { "TU ES MÉTAMORPHE" },
    cleaner   = { "TU ES NETTOYEUR" },
    stowaway  = { "TU ES CLANDESTIN" },
    swapper   = { "TU ES ÉCHANGEUR" },
    martyr    = { "TU ES MARTYR" },
    revenant  = { "TU ES REVENANT" },
    poisoner  = { "TU ES EMPOISONNEUR" },
    gagger    = { "TU ES BÂILLONNEUR" },
    thief     = { "TU ES VOLEUR" },
    echo      = { "TU ES ÉCHO" },
    amnesiac  = { "TU ES AMNÉSIQUE", "TROUVE UN CADAVRE" },
    jester    = { "TU ES LE BOUFFON", "FAIS-TOI TUER PAR UN EMPLOYÉ" },
}

-- How each role works, shown in the LPROLES tab and on the tablet. Every line is a whole
-- sentence (the tablet writes each one after a bullet and wraps it; the menu cuts long ones
-- into several rows).
-- {name} is replaced by a value: the host's settings (hold, aim, dur, range, ...) or this
-- player's own keys ({pkey}: the power key, {key}: the "consume" key). A line starting with
-- "?name " is shown only if that value is set (not 0), "!name " only if it is not.
-- Every power starts with the power key, except the Rêveur's (both eyes closed).
-- On the tablet, values and words between *stars* are written in bold and in colour.
-- How a role gets a use back is not written here: see S.RECHARGE below.
-- Nothing is said of players without the mod: the user only plays with friends who all have
-- it (D67).
local AIMED = "*Regarde* un joueur à moins de {range} m et appuie sur {pkey}."
-- The Ange gardien only: the other aimed powers act as soon as the key is pressed.
local HELD = "?aim Garde-le *en vue* {aim} s : le pouvoir agit ensuite."
S.ROLE_HOWTO = {
    sheriff   = { "?card Une *carte d'accès* est *en surbrillance* quelque part, pour toi seul : va la chercher.",
                  "?walls Tu la vois *à travers les murs*.",
                  "?taken La *carte d'accès* en surbrillance a été *ramassée*.",
                  "?info Tu connais une *personne sûre* : elle était *employée* au début de la partie.",
                  "?marker Elle est marquée d'une *sphère verte* pendant les {marker} premières secondes.",
                  "?imm Le Recruteur *ne peut pas* te recruter." },
    infector  = { "À moins de {range} m d'un *employé*, appuie sur {pkey} et *reste près de lui* {ihold} s.",
                  "?delay Il devient *dissident* {delay} s plus tard, s'il est encore en vie.",
                  "!delay Il devient *dissident* aussitôt.",
                  "?early Pas de recrutement pendant les {early} premières secondes de la partie.",
                  "?imm Le Shérif *ne peut pas* être recruté : la tentative est *perdue*." },
    dreamer   = { "Ferme *les deux yeux* {hold} s : tu deviens *fantôme* pendant {dur} s.",
                  "Ton *corps* reste assis, les yeux fermés ; s'il est *attaqué*, tu te réveilles aussitôt.",
                  "Referme *les deux yeux* pour te réveiller plus tôt." },
    fairy     = { "Appuie sur {pkey} : *envol* de {dur} s.",
                  "Tu es *intouchable* ; ton corps réapparaît là où tu te poses.",
                  "?ball Les autres voient une *boule violette* à ta place.",
                  "?glow Les autres voient une *petite lumière* à ta place.",
                  "?unseen Les autres *ne te voient plus*.",
                  "Les joueurs proches *entendent* ton envol." },
    medium    = { "Appuie sur {pkey} : tu as une *vision* de {dur} s.",
                  "Pendant la vision, tu *vois et entends les morts*." },
    angel     = { AIMED, HELD,
                  "Il devient ton *protégé* : un seul par partie, et le choix est *définitif*.",
                  "S'il meurt, il *se relève aussitôt*, une seule fois.",
                  "S'il était le *dernier employé* en vie, la partie *continue* quand même." },
    mole      = { "Tu es *dissident*, mais *invisible* des autres dissidents : ni sphère, ni liste des joueurs.",
                  "Toi non plus, tu *ne les vois pas*.",
                  "Le jeu t'affiche comme *employé* : c'est voulu." },
    tracker   = { AIMED,
                  "Sa *silhouette* se voit *à travers les murs* pendant {dur} s, sur ton écran seulement.",
                  "Une seule traque à la fois." },
    hypnotist = { AIMED,
                  "Ses yeux *se ferment de force* pendant {dur} s." },
    mimic     = { AIMED,
                  "Tu prends son *apparence exacte* pendant {dur} s.",
                  "Un *cadavre* convient aussi : vise-le, ou appuie à moins de {reach} m de lui.",
                  "?keep Ta *voix* ne change pas ; ton *nom* et ta *couleur* dans la liste des joueurs non plus.",
                  "!keep Ta *voix* et ton *nom* dans la liste ne changent pas, mais ta *couleur* dans la liste change." },
    cleaner   = { "À moins de {range} m d'un *cadavre*, appuie sur {pkey} et *reste près de lui* {chold} s.",
                  "Le corps *disparaît* et ne peut plus être *réanimé*." },
    stowaway  = { "À moins de {range} m d'une *bouche d'aération*, appuie sur {pkey}.",
                  "Tu t'y *caches* pendant {dur} s : *invisible et intouchable*, mais immobile.",
                  "Appuie de nouveau sur {pkey} pour sortir plus tôt." },
    swapper   = { AIMED,
                  "Vous *échangez vos places* aussitôt.",
                  "L'échange *s'entend* : par vous deux, et par les joueurs proches de l'un ou de l'autre." },
    martyr    = { "?reveal Si un joueur te tue, *son nom* est annoncé à tous.",
                  "!reveal Si un joueur te tue, *son camp* est annoncé à tous.",
                  "Rien n'est annoncé pour une mort par *explosion*, *poison* ou *chute*." },
    revenant  = { "Une fois *mort*, appuie sur {pkey}.",
                  "Ton *fantôme* devient *visible et audible* de tous pendant {dur} s.",
                  "Si l'on te *réanime* et que tu meurs de nouveau, tu peux *recommencer*." },
    poisoner  = { AIMED,
                  "Il est *empoisonné* : il mourra {delay} s plus tard, sans que rien ne te désigne.",
                  "?warn Il en est *prévenu* {warn} s avant sa mort.",
                  "?wnow Il en est *prévenu aussitôt*.",
                  "?never Il n'en est *jamais prévenu*.",
                  "?cure Une fois prévenu, il peut se *sauver* en consommant {cure}.",
                  "!cure Il n'existe *aucun antidote*." },
    gagger    = { AIMED,
                  "Son *micro est coupé* pendant {dur} s : plus personne ne l'entend.",
                  "Il en est *prévenu*." },
    thief     = { AIMED,
                  "Tu lui prends *l'objet qu'il tient* : il passe dans ta main.",
                  "Il faut que ta *main soit vide*.",
                  "Il sait qu'on l'a *volé*, mais pas par qui." },
    echo      = { "Appuie sur {pkey} : tu reviens *là où tu étais* {back} s plus tôt.",
                  "Le retour est *instantané*." },
    amnesiac  = { "Tu es *neutre* : ni rôle, ni pouvoir pour l'instant.",
                  "*Regarde* un *cadavre* à moins de {range} m et appuie sur {pkey}.",
                  "À moins de {reach} m du corps, inutile de le viser.",
                  "Tu prends le *rôle* et le *camp* du mort : le choix est *définitif*.",
                  "Un mort *sans rôle* ne te donne rien.",
                  "Tant que tu n'as rien pris, tu comptes comme un *employé*." },
    jester    = { "Tu es *neutre* : tu gagnes *seul* si un *employé* te tue.",
                  "Tué par un *dissident*, ou mort autrement, tu as *perdu*.",
                  "?ends Ta victoire *termine la partie*.",
                  "!ends Ta victoire est *annoncée à tous* ; la partie continue sans toi.",
                  "Pour le reste du jeu, tu comptes comme un *employé*." },
    none      = { "Aucun rôle spécial pour cette partie." },
}

-- How a role gets a use back, added after the lines above when the host gave the role an
-- item ({item}: its name, from S.ITEM_NAME). one: roles with a single charge; more: roles
-- with several uses; limit: added when the host limits the recharges of a game; spent: when
-- that limit is reached; eyes: the Rêveur, when the host allows the eye gesture.
S.RECHARGE = {
    one   = "*Recharge* : {item} en main, touche {key}",
    more  = "*+1 utilisation* : {item} en main, touche {key}",
    limit = " (encore {rleft} fois)",
    spent = "*Recharges* épuisées pour cette partie.",
    eyes  = "Ou objet en main, *les deux yeux* fermés {hold} s.",
}

-- Recharge items, by number: 1-5 a jar holding the plant with that code, 6-9 a fish, named
-- by the word the fish machine shows on its screen (the game is in English).
S.ITEM_NAME = {
    [1] = "un bocal de *G3M*", [2] = "un bocal de *Y8Z*", [3] = "un bocal de *BO4*",
    [4] = "un bocal de *WX2*", [5] = "un bocal de *RU2*",
    [6] = "un poisson *SALMON* (saumon)", [7] = "un poisson *TUNA* (thon)",
    [8] = "un poisson *COD* (cabillaud)", [9] = "un poisson *SHRIMP* (crevette)",
}
-- The same, for the banner (short, capitals).
S.ITEM_SHORT = {
    [1] = "BOCAL DE G3M", [2] = "BOCAL DE Y8Z", [3] = "BOCAL DE BO4", [4] = "BOCAL DE WX2", [5] = "BOCAL DE RU2",
    [6] = "POISSON SALMON", [7] = "POISSON TUNA", [8] = "POISSON COD", [9] = "POISSON SHRIMP",
}

-- What cures the Empoisonneur's poison, by the antidote's number (lpr_config.lua, C.cure_code):
-- one of the items above, or any fish, or any plant.
S.CURE_NAME = { [10] = "n'importe quel *poisson*", [11] = "un bocal de n'importe quelle *plante*" }
S.CURE_SHORT = { [10] = "UN POISSON", [11] = "UN BOCAL DE PLANTE" }
for i, name in pairs(S.ITEM_NAME) do S.CURE_NAME[i] = name end
for i, name in pairs(S.ITEM_SHORT) do S.CURE_SHORT[i] = name end

-- Liés: not a role but a bond between two players, whatever their roles. Shown right under
-- the status line of the role (or alone, for a player without a role).
S.LINK_LINE = "*Lié* à {link} : au premier de vous deux qui *meurt*, l'autre *meurt aussi*."
-- Once the bond has acted (it does only once).
S.LINK_OVER = "Ton *lien* avec {exlink} est *rompu* : il a déjà joué."

-- Where the role stands (first line under the role's name).
S.STATUS = {
    uses            = "Utilisations restantes : {n} sur {m}",
    uses_too        = " - utilisations : {n} sur {m}",      -- added to a running effect's line
    dream_on        = "Tu rêves : encore {act} s",
    fly_on          = "En vol : encore {act} s",
    charge_ready    = "Charge : prête",
    charge_empty    = "Charge : vide, à recharger",
    charge_gone     = "Charge : utilisée",
    vision_on       = "Vision en cours : encore {act} s",
    protege         = "Protégé : {tgt}",
    protege_saved   = "Protégé : {tgt} (déjà sauvé une fois)",
    no_protege      = "Aucun protégé choisi",
    track_on        = "Traque de {tgt} : encore {act} s",
    disguise_on     = "Déguisé : encore {act} s",
    hide_on         = "Caché : encore {act} s",
    recruit_pending = "Recrutement de {tgt} : conversion dans {conv} s",
    recruit_wait    = "Recrutement possible dans {wait} s",
    recruits        = "Recrutements restants : {n} sur {m}",
    safe            = "Personne sûre : {safe}",
    no_safe         = "Personne sûre : elle a quitté la partie",
    no_safe_info    = "Pas de personne sûre dans cette partie",
    martyr_camp     = "À ta mort : le camp de ton tueur est annoncé",
    martyr_name     = "À ta mort : le nom de ton tueur est annoncé",
    mole            = "Invisible des autres dissidents",
    spirit_on       = "Tu te manifestes : encore {act} s",
    spirit_later    = "Après ta mort : {n} apparition(s)",
    spirit_left     = "Apparitions restantes : {n} sur {m}",
    poison_on       = "{tgt} est empoisonné : mort dans {act} s",
    amnesiac        = "Sans rôle : cherche un cadavre",
    jester          = "But : être tué par un employé",
    waiting         = "En attente des informations de l'hôte",
}

-- Colours of the tablet page. The tablet's screen does not show colours as they are (D52):
-- red is its dark ink, green its glowing white, and blue takes the colour of the map room
-- under the pixel (grey outside the rooms); anything in between gets mixed into blocks. So
-- only pure values are used.
S.TABLET = {
    ink    = { 1, 0, 0 },                      -- the game's dark text
    paper  = { 0, 0, 0 },                      -- the screen's background
    title  = { 1, 0, 0 },                      -- role name (bold, larger)
    accent = { 1, 0, 0 },                      -- values and words between stars (bold)
    bullet = { 1, 0, 0 },
    -- status line: dark band, light text (the look of a game button under the cursor)
    band   = { 1, 0, 0 },
    band_text = { 0, 0, 0 },
    room_ink = { 0, 0, 1 },                    -- the colour of the map rooms
    glow_ink = { 0, 1, 0 },                    -- the glowing white
    -- Plant names, by plant number. While the role page is shown (map hidden), the screen's
    -- seven room colours are all set to the plant's: its name, in the room ink, comes out in
    -- that colour. The values are the screen's own room colours ("Color n", "Emissive n").
    -- White: the glowing white ink, nothing to set.
    plant  = {
        [1] = { color = { 0.665, 0.885, 0.605 }, glow = { 1.205, 2.5, 0.0 } },     -- G3M, green
        [2] = { color = { 1.0, 0.895, 0.409 },   glow = { 3.5, 2.601, 0.0 } },     -- Y8Z, yellow
        [3] = { color = { 0.587, 0.930, 1.0 },   glow = { 0.0, 3.0, 2.451 } },     -- BO4, cyan
        [4] = { white = true },                                                    -- WX2, white
        [5] = { color = { 1.0, 0.634, 0.614 },   glow = { 3.5, 0.0, 0.542 } },     -- RU2, red
    },
}

-- Notification colours (R, G, B)
S.COLOR = {
    info    = { 0.10, 0.45, 0.80 },
    good    = { 0.10, 0.60, 0.25 },
    warn    = { 0.80, 0.50, 0.05 },
    bad     = { 0.75, 0.10, 0.10 },
    role    = { 0.45, 0.15, 0.70 },
}

S.SAFE_PERSON        = "PERSONNE SÛRE : %s"
S.CARD_SHOWN         = "CARTE D'ACCÈS EN SURBRILLANCE"
S.CARD_TAKEN         = "LA CARTE A ÉTÉ RAMASSÉE"
S.CARD_NONE          = "PAS DE CARTE D'ACCÈS À MONTRER"
S.DREAM_START        = "TU RÊVES (%d S)"
S.DREAM_END          = "TU TE RÉVEILLES"
S.DREAM_ATTACKED     = "ON T'ATTAQUE : RÉVEIL"
S.FAIRY_START        = "ENVOL"
S.NO_CHARGE          = "PAS DE CHARGE : %s"
S.NEED_ITEM          = "IL FAUT : %s"
S.USE_HINT           = "RECHARGE : TOUCHE %s"
S.RECHARGED          = "CHARGE RÉCUPÉRÉE"
S.USE_BACK           = "UTILISATION RÉCUPÉRÉE"
S.CHARGE_FULL        = "CHARGE DÉJÀ PLEINE"
S.USES_FULL          = "UTILISATIONS DÉJÀ AU MAXIMUM"
S.NO_RECHARGE_LEFT   = "PLUS DE RECHARGE POSSIBLE"
S.NO_USE_LEFT        = "PLUS D'UTILISATION"
S.TARGET             = "CIBLE : %s"
S.NO_TARGET          = "PERSONNE EN VUE"
S.TARGET_LOST        = "CIBLE PERDUE"
S.NO_ONE_NEAR        = "PERSONNE À PORTÉE"
S.NO_BODY            = "AUCUN CADAVRE À PORTÉE"
S.POWER_EYES         = "RÊVEUR : FERME LES DEUX YEUX"
S.INFECT_PROGRESS    = "RECRUTEMENT EN COURS"
S.INFECT_DONE        = "CIBLE RECRUTÉE (%d S)"
S.INFECT_FAILED      = "RECRUTEMENT ÉCHOUÉ"
S.INFECT_CONVERTED   = "%s EST DISSIDENT"
S.INFECT_TOO_EARLY   = "TROP TÔT POUR RECRUTER"
S.INFECT_NO_CHARGE   = "PLUS DE RECRUTEMENT"
S.YOU_ARE_INFECTED   = "RECRUTÉ : TU ES DISSIDENT"
S.MEDIUM_START       = "VISION (%d S)"
S.MEDIUM_END         = "FIN DE LA VISION"
S.ANGEL_SET          = "PROTÉGÉ : %s"
S.ANGEL_SAVED        = "TON PROTÉGÉ EST SAUVÉ"
S.ANGEL_SAVED_YOU    = "UN ANGE T'A SAUVÉ"
S.ANGEL_TOO_LATE     = "TROP TARD : PARTIE TERMINÉE"
S.TRACK_START        = "TRAQUE : %s"
S.TRACK_END          = "FIN DE LA TRAQUE"
S.HYPNO_DONE         = "%s EST HYPNOTISÉ"
S.HYPNO_IMMUNE       = "CIBLE INSENSIBLE"
S.HYPNO_YOU          = "TU ES HYPNOTISÉ"
S.MIMIC_START        = "TU AS LA PEAU DE %s"
S.MIMIC_BUSY         = "DÉJÀ DÉGUISÉ"
S.TRACK_BUSY         = "UNE TRAQUE EST EN COURS"
S.MIMIC_END          = "TU REPRENDS TA PEAU"
S.MIMIC_FAILED       = "MÉTAMORPHOSE IMPOSSIBLE"
S.LINKED_TO          = "LIÉ À : %s"
S.HIDE_START         = "TU TE CACHES (%d S)"
S.HIDE_END           = "TU SORS DE TA CACHETTE"
S.NO_VENT            = "AUCUNE BOUCHE À PROXIMITÉ"
S.CLEAN_DONE         = "CORPS DE %s NETTOYÉ"
S.LINK_DEAD          = "TON LIEN EST MORT"
S.SWAP_DONE          = "ÉCHANGE AVEC %s"
S.SWAP_FAILED        = "ÉCHANGE IMPOSSIBLE"
S.SWAP_YOU           = "QUELQU'UN A PRIS TA PLACE"
S.MARTYR_CAMP_DISSIDENT = "MARTYR : TUÉ PAR UN DISSIDENT"
S.MARTYR_CAMP_EMPLOYEE  = "MARTYR : TUÉ PAR UN EMPLOYÉ"
S.MARTYR_NAME        = "MARTYR : TUÉ PAR %s"
S.SPIRIT_READY       = "MORT : TOUCHE %s POUR TE MONTRER"
S.SPIRIT_START       = "TU TE MANIFESTES"
S.POISON_DONE        = "%s EST EMPOISONNÉ"
S.POISON_ALREADY     = "IL EST DÉJÀ EMPOISONNÉ"
S.POISON_YOU         = "EMPOISONNÉ : MORT DANS %d S"
S.POISON_CURE        = "ANTIDOTE : %s"
S.POISON_CURED       = "POISON SOIGNÉ"
S.POISON_LOST        = "TON POISON A ÉTÉ SOIGNÉ"
S.POISON_DEAD        = "LE POISON T'A TUÉ"
S.GAG_DONE           = "%s EST BÂILLONNÉ"
S.GAG_YOU            = "BÂILLONNÉ : MICRO COUPÉ (%d S)"
S.GAG_END            = "TON MICRO REMARCHE"
S.STEAL_DONE         = "OBJET VOLÉ À %s"
S.STEAL_NOTHING      = "IL NE TIENT RIEN"
S.STEAL_HANDS_FULL   = "TA MAIN DOIT ÊTRE VIDE"
S.STEAL_FAILED       = "VOL IMPOSSIBLE"
S.STEAL_YOU          = "ON T'A VOLÉ TON OBJET"
S.ECHO_DONE          = "RETOUR EN ARRIÈRE"
S.ECHO_NOTHING       = "PAS ENCORE DE TRAJET À REJOUER"
S.AMNESIA_DONE       = "TU HÉRITES DE %s"
S.AMNESIA_NO_ROLE    = "CE MORT N'AVAIT PAS DE RÔLE"
S.AMNESIA_DISSIDENT  = "TU DEVIENS DISSIDENT"
S.JESTER_WIN         = "LE BOUFFON GAGNE : %s"
S.JESTER_LOST        = "TUÉ PAR UN DISSIDENT : PERDU"
S.HOST_SHORT         = "%d RÔLE(S) NON ATTRIBUÉ(S) : RÉGLAGE JOUEURS MINIMUM"
S.HOST_NO_MOD        = "%d JOUEUR(S) SANS LE MOD"
S.MOD_ACK            = "LPROLES ACTIF (HÔTE %s)"
S.VERSION_DIFF       = "VERSIONS DIFFÉRENTES : HÔTE %s, TOI %s"
S.REVEAL             = "%s : %s"
S.REVEAL_LINK        = "LIÉS : %s ET %s"
S.MENU_TAB_OFF       = "ONGLET LPROLES EN PAUSE APRÈS UN ARRÊT DU JEU : F10 POUR LE REMETTRE"
S.TABLET_OFF         = "PAGE TABLETTE EN PAUSE APRÈS UN ARRÊT DU JEU : F10 POUR LA REMETTRE"
S.DIAG_OK            = "LPROLES %s OK"
S.DIAG_BACK          = "LPROLES %s : ONGLET ET PAGE REMIS"
S.INSTALL_BROKEN     = "LPROLES : INSTALLATION INCOMPLÈTE, RECOPIER LE MOD"
S.UPDATED            = "LPROLES MIS À JOUR : VERSION %s"

S.MENU_TAB           = "LPROLES"
S.MENU_ROLE          = "TON RÔLE"
S.MENU_NO_ROLE       = "AUCUN"
S.MENU_HOST_ONLY     = "Les réglages de la partie sont modifiables par l'hôte."

S.PLANT_CODE = { [1] = "G3M", [2] = "Y8Z", [3] = "BO4", [4] = "WX2", [5] = "RU2" }

return S
