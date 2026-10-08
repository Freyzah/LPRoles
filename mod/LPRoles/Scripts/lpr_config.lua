-- LPRoles - settings: defaults, load/save of config.txt, list shown in the menu
local U = require("lpr_util")

local C = {}

-- Groups, in the order shown in the menu.
-- C.GROUPS, the groups of settings in the order they first appear below, is drawn from the
-- settings themselves (after C.DEFS): a group cannot be forgotten in it.

local CAMPS = { "any", "employee", "dissident" }

-- What a role can consume to get a use back: nothing, a jar holding one of the five plants, or
-- one of the four fish of the fish machine. The position in this list, minus one, is the
-- item's number (0 = none, then the plants, then the fish: see lpr_game.lua, PLANT_KINDS).
local ITEMS = { "none", "g3m", "y8z", "bo4", "wx2", "ru2", "salmon", "tuna", "cod", "shrimp" }
C.ITEMS = ITEMS

-- Groups every player sets for themselves (the others are the host's game settings).
C.PERSONAL_GROUPS = { ["MES RÉGLAGES"] = true }

-- Keys used neither by the game (read from its input mappings) nor by UE4SS's own tools
-- (Ctrl+J, Ctrl+O, Ctrl+H, Ctrl+R): eight letters, and the two side buttons of the mouse.
C.FREE_KEYS = { "G", "B", "N", "L", "M", "Y", "I", "P", "mouse4", "mouse5" }

-- UE4SS's name for a key, when it is not the value itself.
C.KEY_NAME = { mouse4 = "XBUTTON_ONE", mouse5 = "XBUTTON_TWO" }

-- Each entry: key, group, default, kind ("bool" | "int" | "num" | "choice"), min, max, step, label.
-- Keys never change (they are what config.txt stores), even when a role is renamed.
C.DEFS = {
    { key = "power_key",               group = "MES RÉGLAGES", default = "B", kind = "choice", choices = C.FREE_KEYS, label = "Touche : activer le pouvoir" },
    { key = "use_key",                 group = "MES RÉGLAGES", default = "G", kind = "choice", choices = C.FREE_KEYS, label = "Touche : consommer l'objet en main" },
    { key = "tablet_page",             group = "MES RÉGLAGES", default = true, kind = "bool", label = "Page du rôle sur la tablette" },
    -- read by lpr_update.lua straight from config.txt, before the settings are loaded
    { key = "auto_update",             group = "MES RÉGLAGES", default = true, kind = "bool", label = "Mise à jour automatique au lancement" },
    { key = "sound_volume",            group = "MES RÉGLAGES", default = 100,  kind = "int",  min = 10, max = 200, step = 10, label = "Volume des sons du mod (%)" },
    { key = "consume_sound",           group = "MES RÉGLAGES", default = true, kind = "bool", label = "Son à la consommation" },
    { key = "fairy_sound",             group = "MES RÉGLAGES", default = true, kind = "bool", label = "Son de l'envol des Fées" },
    { key = "start_sound",             group = "MES RÉGLAGES", default = true, kind = "bool", label = "Son d'un pouvoir qui démarre" },
    { key = "fail_sound",              group = "MES RÉGLAGES", default = true, kind = "bool", label = "Son d'un pouvoir qui échoue" },
    { key = "swap_sound",              group = "MES RÉGLAGES", default = true, kind = "bool", label = "Son des échanges de place" },

    { key = "enabled",                 group = "GÉNÉRAL", default = true,  kind = "bool",  label = "Mod actif" },
    { key = "max_roles",               group = "GÉNÉRAL", default = 4,     kind = "int",   min = 1, max = 16, step = 1, label = "Rôles spéciaux par partie (max)" },
    { key = "announce_delay",          group = "GÉNÉRAL", default = 7,     kind = "num",   min = 2, max = 20, step = 1, label = "Annonce des rôles après (s)" },
    { key = "recharge_limit",          group = "GÉNÉRAL", default = 0,     kind = "int",   min = 0, max = 10, step = 1, label = "Recharges par partie (0 = illimité)" },
    { key = "reveal_roles_at_end",     group = "GÉNÉRAL", default = true,  kind = "bool",  label = "Révéler les rôles à la fin" },
    { key = "menu_tab",                group = "GÉNÉRAL", default = true,  kind = "bool",  label = "Onglet dans le menu Échap" },

    { key = "sheriff_enabled",         group = "SHÉRIF", default = true,  kind = "bool",  label = "Shérif" },
    { key = "sheriff_min_players",     group = "SHÉRIF", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "sheriff_card",            group = "SHÉRIF", default = true,  kind = "bool",  label = "Une carte d'accès en surbrillance" },
    { key = "sheriff_card_extra",      group = "SHÉRIF", default = true,  kind = "bool",  label = "Carte posée en plus de celles du jeu" },
    { key = "sheriff_card_walls",      group = "SHÉRIF", default = true,  kind = "bool",  label = "Surbrillance vue à travers les murs" },
    { key = "sheriff_safe_info",       group = "SHÉRIF", default = true,  kind = "bool",  label = "Connaît une personne sûre" },
    { key = "sheriff_marker_seconds",  group = "SHÉRIF", default = 20,    kind = "int",   min = 0, max = 120, step = 5, label = "Durée du marqueur (s)" },
    { key = "sheriff_immune",          group = "SHÉRIF", default = true,  kind = "bool",  label = "Ne peut pas être recruté" },

    { key = "infector_enabled",        group = "RECRUTEUR", default = true,  kind = "bool",  label = "Recruteur" },
    { key = "infector_min_players",    group = "RECRUTEUR", default = 5,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "infect_charges",          group = "RECRUTEUR", default = 1,     kind = "int",   min = 1, max = 5, step = 1, label = "Recrutements par partie" },
    { key = "infect_range",            group = "RECRUTEUR", default = 250,   kind = "int",   min = 100, max = 800, step = 50, label = "Portée (cm)" },
    { key = "infect_hold_seconds",     group = "RECRUTEUR", default = 4,     kind = "num",   min = 1, max = 15, step = 0.5, label = "Durée du geste (s)" },
    { key = "infect_delay_seconds",    group = "RECRUTEUR", default = 45,    kind = "int",   min = 0, max = 300, step = 5, label = "Délai avant conversion (s)" },
    { key = "infect_min_game_seconds", group = "RECRUTEUR", default = 60,    kind = "int",   min = 0, max = 600, step = 10, label = "Pas avant (s de jeu)" },
    { key = "infector_item",           group = "RECRUTEUR", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "dreamer_enabled",         group = "RÊVEUR", default = true,  kind = "bool",  label = "Rêveur" },
    { key = "dreamer_min_players",     group = "RÊVEUR", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "dreamer_camp",            group = "RÊVEUR", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "dream_hold_seconds",      group = "RÊVEUR", default = 3,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Yeux fermés pour s'endormir (s)" },
    { key = "recharge_by_eyes",        group = "RÊVEUR", default = false, kind = "bool",  label = "Recharger aussi en fermant les yeux" },
    { key = "dream_duration",          group = "RÊVEUR", default = 18,    kind = "num",   min = 5, max = 60, step = 1, label = "Durée du rêve (s)" },
    { key = "dream_start_charges",     group = "RÊVEUR", default = 1,     kind = "int",   min = 0, max = 1, step = 1, label = "Charge au départ" },
    { key = "dreamer_item",            group = "RÊVEUR", default = "g3m", kind = "choice", choices = ITEMS, label = "Objet de recharge" },
    { key = "ghost_fx",                group = "RÊVEUR", default = true,  kind = "bool",  label = "Effet visuel à l'endormissement" },

    { key = "fairy_enabled",           group = "FÉE", default = true,  kind = "bool",  label = "Fée" },
    { key = "fairy_min_players",       group = "FÉE", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "fairy_camp",              group = "FÉE", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "fairy_duration",          group = "FÉE", default = 5,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Durée (s)" },
    { key = "fairy_start_charges",     group = "FÉE", default = 1,     kind = "int",   min = 0, max = 1, step = 1, label = "Charge au départ" },
    { key = "fairy_item",              group = "FÉE", default = "wx2", kind = "choice", choices = ITEMS, label = "Objet de recharge" },
    { key = "fairy_ball",              group = "FÉE", default = true,  kind = "bool",  label = "Boule violette à sa place" },
    { key = "fairy_light",             group = "FÉE", default = true,  kind = "bool",  label = "Lumière visible" },

    { key = "medium_enabled",          group = "MÉDIUM", default = true,  kind = "bool",  label = "Médium" },
    { key = "medium_min_players",      group = "MÉDIUM", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "medium_camp",             group = "MÉDIUM", default = "employee", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "medium_charges",          group = "MÉDIUM", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Visions par partie" },
    { key = "medium_duration",         group = "MÉDIUM", default = 10,    kind = "num",   min = 3, max = 30, step = 1, label = "Durée d'une vision (s)" },
    { key = "medium_item",             group = "MÉDIUM", default = "bo4", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "angel_enabled",           group = "ANGE GARDIEN", default = true,  kind = "bool",  label = "Ange gardien" },
    { key = "angel_min_players",       group = "ANGE GARDIEN", default = 5,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "angel_camp",              group = "ANGE GARDIEN", default = "employee", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "angel_range",             group = "ANGE GARDIEN", default = 1500,  kind = "int",   min = 300, max = 3000, step = 100, label = "Portée de visée (cm)" },
    { key = "aim_hold_seconds",        group = "ANGE GARDIEN", default = 1.5,   kind = "num",   min = 0, max = 6, step = 0.5, label = "Protégé à garder en vue (s)" },

    { key = "mole_enabled",            group = "TAUPE", default = true,  kind = "bool",  label = "Taupe" },
    { key = "mole_min_players",        group = "TAUPE", default = 6,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },

    { key = "tracker_enabled",         group = "TRAQUEUR", default = true,  kind = "bool",  label = "Traqueur" },
    { key = "tracker_min_players",     group = "TRAQUEUR", default = 5,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "tracker_charges",         group = "TRAQUEUR", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Traques par partie" },
    { key = "tracker_duration",        group = "TRAQUEUR", default = 15,    kind = "num",   min = 5, max = 60, step = 1, label = "Durée d'une traque (s)" },
    { key = "tracker_range",           group = "TRAQUEUR", default = 3000,  kind = "int",   min = 500, max = 6000, step = 250, label = "Portée de visée (cm)" },
    { key = "tracker_item",            group = "TRAQUEUR", default = "tuna", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "hypno_enabled",           group = "HYPNOTISEUR", default = true,  kind = "bool",  label = "Hypnotiseur" },
    { key = "hypno_min_players",       group = "HYPNOTISEUR", default = 5,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "hypno_charges",           group = "HYPNOTISEUR", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Hypnoses par partie" },
    { key = "hypno_duration",          group = "HYPNOTISEUR", default = 3,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Yeux fermés pendant (s)" },
    { key = "hypno_range",             group = "HYPNOTISEUR", default = 600,   kind = "int",   min = 200, max = 2000, step = 100, label = "Portée de visée (cm)" },
    { key = "hypno_item",              group = "HYPNOTISEUR", default = "salmon", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "mimic_enabled",           group = "MÉTAMORPHE", default = true,  kind = "bool",  label = "Métamorphe" },
    { key = "mimic_min_players",       group = "MÉTAMORPHE", default = 5,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "mimic_charges",           group = "MÉTAMORPHE", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Métamorphoses par partie" },
    { key = "mimic_duration",          group = "MÉTAMORPHE", default = 15,    kind = "num",   min = 5, max = 60, step = 1, label = "Durée d'une métamorphose (s)" },
    { key = "mimic_range",             group = "MÉTAMORPHE", default = 2000,  kind = "int",   min = 300, max = 5000, step = 100, label = "Portée de visée (cm)" },
    { key = "mimic_keep_list_color",   group = "MÉTAMORPHE", default = true,  kind = "bool",  label = "Garde sa couleur dans la liste" },
    { key = "mimic_item",              group = "MÉTAMORPHE", default = "shrimp", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "cleaner_enabled",         group = "NETTOYEUR", default = true,  kind = "bool",  label = "Nettoyeur" },
    { key = "cleaner_min_players",     group = "NETTOYEUR", default = 5,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "cleaner_charges",         group = "NETTOYEUR", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Nettoyages par partie" },
    { key = "cleaner_range",           group = "NETTOYEUR", default = 250,   kind = "int",   min = 100, max = 600, step = 50, label = "Portée (cm)" },
    { key = "cleaner_hold",            group = "NETTOYEUR", default = 3,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Durée du geste (s)" },
    { key = "cleaner_item",            group = "NETTOYEUR", default = "cod", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "stowaway_enabled",        group = "CLANDESTIN", default = true,  kind = "bool",  label = "Clandestin" },
    { key = "stowaway_min_players",    group = "CLANDESTIN", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "stowaway_camp",           group = "CLANDESTIN", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "stowaway_charges",        group = "CLANDESTIN", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Cachettes par partie" },
    { key = "stowaway_duration",       group = "CLANDESTIN", default = 20,    kind = "num",   min = 5, max = 60, step = 1, label = "Durée d'une cachette (s)" },
    { key = "stowaway_range",          group = "CLANDESTIN", default = 250,   kind = "int",   min = 100, max = 600, step = 50, label = "Distance de la bouche (cm)" },
    { key = "stowaway_item",           group = "CLANDESTIN", default = "y8z", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "linked_enabled",          group = "LIÉS", default = true,  kind = "bool",  label = "Liés" },
    { key = "linked_min_players",      group = "LIÉS", default = 6,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "linked_mode",             group = "LIÉS", default = "random", kind = "choice", choices = { "random", "mixed", "same" }, label = "Camps des deux liés" },

    { key = "swapper_enabled",         group = "ÉCHANGEUR", default = true,  kind = "bool",  label = "Échangeur" },
    { key = "swapper_min_players",     group = "ÉCHANGEUR", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "swapper_camp",            group = "ÉCHANGEUR", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "swapper_charges",         group = "ÉCHANGEUR", default = 1,     kind = "int",   min = 1, max = 3, step = 1, label = "Échanges par partie" },
    { key = "swapper_range",           group = "ÉCHANGEUR", default = 2000,  kind = "int",   min = 300, max = 5000, step = 100, label = "Portée de visée (cm)" },
    { key = "swapper_item",            group = "ÉCHANGEUR", default = "ru2", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "martyr_enabled",          group = "MARTYR", default = true,  kind = "bool",  label = "Martyr" },
    { key = "martyr_min_players",      group = "MARTYR", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "martyr_camp",             group = "MARTYR", default = "employee", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "martyr_reveal",           group = "MARTYR", default = "camp", kind = "choice", choices = { "camp", "name" }, label = "Ce qui est révélé" },

    { key = "revenant_enabled",        group = "REVENANT", default = true,  kind = "bool",  label = "Revenant" },
    { key = "revenant_min_players",    group = "REVENANT", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "revenant_camp",           group = "REVENANT", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "revenant_charges",        group = "REVENANT", default = 1,     kind = "int",   min = 1, max = 3, step = 1, label = "Apparitions à chaque mort" },
    { key = "revenant_duration",       group = "REVENANT", default = 20,    kind = "num",   min = 1, max = 60, step = 1, label = "Durée d'une apparition (s)" },

    { key = "poisoner_enabled",        group = "EMPOISONNEUR", default = true,  kind = "bool",  label = "Empoisonneur" },
    { key = "poisoner_min_players",    group = "EMPOISONNEUR", default = 5,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "poisoner_charges",        group = "EMPOISONNEUR", default = 1,     kind = "int",   min = 1, max = 3, step = 1, label = "Empoisonnements par partie" },
    { key = "poisoner_range",          group = "EMPOISONNEUR", default = 400,   kind = "int",   min = 200, max = 2000, step = 100, label = "Portée de visée (cm)" },
    { key = "poison_delay",            group = "EMPOISONNEUR", default = 180,   kind = "int",   min = 10, max = 600, step = 10, label = "Mort après (s)" },
    { key = "poison_warning",          group = "EMPOISONNEUR", default = 120,   kind = "int",   min = 0, max = 600, step = 10, label = "Prévenu avant sa mort (s, 0 = non)" },
    { key = "poison_cure",             group = "EMPOISONNEUR", default = true,  kind = "bool",  label = "Antidote : un échantillon raffiné" },
    { key = "poisoner_item",           group = "EMPOISONNEUR", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "gagger_enabled",          group = "BÂILLONNEUR", default = true,  kind = "bool",  label = "Bâillonneur" },
    { key = "gagger_min_players",      group = "BÂILLONNEUR", default = 5,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "gagger_charges",          group = "BÂILLONNEUR", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Bâillons par partie" },
    { key = "gag_duration",            group = "BÂILLONNEUR", default = 20,    kind = "num",   min = 5, max = 60, step = 1, label = "Durée d'un bâillon (s)" },
    { key = "gagger_range",            group = "BÂILLONNEUR", default = 1000,  kind = "int",   min = 200, max = 3000, step = 100, label = "Portée de visée (cm)" },
    { key = "gagger_item",             group = "BÂILLONNEUR", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "thief_enabled",           group = "VOLEUR", default = true,  kind = "bool",  label = "Voleur" },
    { key = "thief_min_players",       group = "VOLEUR", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "thief_camp",              group = "VOLEUR", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "thief_charges",           group = "VOLEUR", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Vols par partie" },
    { key = "thief_range",             group = "VOLEUR", default = 600,   kind = "int",   min = 100, max = 1000, step = 50, label = "Portée (cm)" },
    { key = "thief_item",              group = "VOLEUR", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "echo_enabled",            group = "ÉCHO", default = true,  kind = "bool",  label = "Écho" },
    { key = "echo_min_players",        group = "ÉCHO", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "echo_camp",               group = "ÉCHO", default = "any", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "echo_charges",            group = "ÉCHO", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Retours par partie" },
    { key = "echo_seconds",            group = "ÉCHO", default = 5,     kind = "int",   min = 2, max = 15, step = 1, label = "Retour en arrière de (s)" },
    { key = "echo_item",               group = "ÉCHO", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "amnesiac_enabled",        group = "AMNÉSIQUE", default = true,  kind = "bool",  label = "Amnésique" },
    { key = "amnesiac_min_players",    group = "AMNÉSIQUE", default = 6,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "amnesiac_range",          group = "AMNÉSIQUE", default = 1000,  kind = "int",   min = 300, max = 3000, step = 100, label = "Portée de visée (cm)" },

    { key = "jester_enabled",          group = "BOUFFON", default = true,  kind = "bool",  label = "Bouffon" },
    { key = "jester_min_players",      group = "BOUFFON", default = 6,     kind = "int",   min = 4, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "jester_ends_game",        group = "BOUFFON", default = true,  kind = "bool",  label = "Sa victoire termine la partie" },

    { key = "vampire_enabled",         group = "VAMPIRE", default = true,  kind = "bool",  label = "Vampire" },
    { key = "vampire_min_players",     group = "VAMPIRE", default = 5,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "vampire_hp",              group = "VAMPIRE", default = 10,    kind = "int",   min = 5, max = 50, step = 5, label = "PV max gagnés par cadavre" },
    { key = "vampire_own_kills",       group = "VAMPIRE", default = true,  kind = "bool",  label = "Seulement ses propres victimes" },
    { key = "vampire_range",           group = "VAMPIRE", default = 250,   kind = "int",   min = 100, max = 600, step = 50, label = "Portée (cm)" },
    { key = "vampire_hold",            group = "VAMPIRE", default = 3,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Durée du geste (s)" },

    { key = "werewolf_enabled",        group = "LOUP-GAROU", default = true,  kind = "bool",  label = "Loup-garou" },
    { key = "werewolf_min_players",    group = "LOUP-GAROU", default = 5,     kind = "int",   min = 3, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "werewolf_camp",           group = "LOUP-GAROU", default = "employee", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "werewolf_percent",        group = "LOUP-GAROU", default = 10,    kind = "int",   min = 5, max = 50, step = 5, label = "Régénération par cadavre (%)" },
    { key = "werewolf_range",          group = "LOUP-GAROU", default = 250,   kind = "int",   min = 100, max = 600, step = 50, label = "Portée (cm)" },
    { key = "werewolf_hold",           group = "LOUP-GAROU", default = 3,     kind = "num",   min = 1, max = 10, step = 0.5, label = "Durée du geste (s)" },

    { key = "medic_enabled",           group = "MÉDECIN", default = true,  kind = "bool",  label = "Médecin" },
    { key = "medic_min_players",       group = "MÉDECIN", default = 4,     kind = "int",   min = 2, max = 16, step = 1, label = "Joueurs minimum" },
    { key = "medic_camp",              group = "MÉDECIN", default = "employee", kind = "choice", choices = CAMPS, label = "Camp" },
    { key = "medic_vitals",            group = "MÉDECIN", default = true,  kind = "bool",  label = "Voit la vie au-dessus des têtes" },
    { key = "medic_charges",           group = "MÉDECIN", default = 2,     kind = "int",   min = 1, max = 5, step = 1, label = "Soins par partie" },
    { key = "medic_range",             group = "MÉDECIN", default = 600,   kind = "int",   min = 200, max = 3000, step = 100, label = "Portée de visée (cm)" },
    { key = "medic_item",              group = "MÉDECIN", default = "none", kind = "choice", choices = ITEMS, label = "Objet de recharge" },

    { key = "force_host_role",         group = "TEST", default = "none", kind = "choice",
      -- in the alphabetical order of the names shown (C.CHOICE_LABEL): easier to find among so many
      choices = { "none", "amnesiac", "angel", "gagger", "jester", "stowaway", "swapper", "echo", "poisoner",
                  "fairy", "hypnotist", "linked", "werewolf", "martyr", "medic", "medium", "mimic", "cleaner", "infector",
                  "revenant", "dreamer", "sheriff", "mole", "tracker", "vampire", "thief" },
      label = "Rôle forcé pour l'hôte" },
    { key = "ignore_min_players",      group = "TEST", default = false, kind = "bool",  label = "Ignorer les joueurs minimum" },
    { key = "debug",                   group = "TEST", default = false, kind = "bool",  label = "Journal détaillé" },
}

C.GROUPS = {}
do
    local seen = {}
    for _, d in ipairs(C.DEFS) do
        if not seen[d.group] then
            seen[d.group] = true
            C.GROUPS[#C.GROUPS + 1] = d.group
        end
    end
end

-- How choice values are written on screen.
C.CHOICE_LABEL = {
    any = "LES DEUX", employee = "EMPLOYÉ", dissident = "DISSIDENT",
    random = "AU HASARD", mixed = "CAMPS OPPOSÉS", same = "MÊME CAMP",
    camp = "SON CAMP", name = "SON NOM",
    none = "AUCUN", sheriff = "SHÉRIF", infector = "RECRUTEUR", dreamer = "RÊVEUR", fairy = "FÉE",
    medium = "MÉDIUM", angel = "ANGE GARDIEN", mole = "TAUPE", tracker = "TRAQUEUR",
    hypnotist = "HYPNOTISEUR", mimic = "MÉTAMORPHE", cleaner = "NETTOYEUR", stowaway = "CLANDESTIN", linked = "LIÉ", swapper = "ÉCHANGEUR", martyr = "MARTYR", revenant = "REVENANT",
    poisoner = "EMPOISONNEUR", gagger = "BÂILLONNEUR", thief = "VOLEUR", echo = "ÉCHO", amnesiac = "AMNÉSIQUE", jester = "BOUFFON",
    vampire = "VAMPIRE", werewolf = "LOUP-GAROU",
    medic = "MÉDECIN",
    -- plants by the code written on their jar, fish by the word the fish machine shows
    g3m = "PLANTE G3M", y8z = "PLANTE Y8Z", bo4 = "PLANTE BO4", wx2 = "PLANTE WX2", ru2 = "PLANTE RU2",
    salmon = "POISSON SALMON", tuna = "POISSON TUNA", cod = "POISSON COD", shrimp = "POISSON SHRIMP",
    -- the mouse's side buttons, numbered as games do (4: the rear one, 5: the front one)
    mouse4 = "SOURIS 4", mouse5 = "SOURIS 5",
}

-- Settings that no longer exist, and the one that replaced each: the plant number (1 to 5) of
-- the Rêveur and of the Fée, from before the other roles had an item.
local LEGACY_PLANT = { dream_plant = "dreamer_item", fairy_plant = "fairy_item" }

-- The two keys each player chooses: they cannot be the same one.
local KEY_TWIN = { use_key = "power_key", power_key = "use_key" }

C.values = {}
C.revision = 0      -- grows at every change, so the menu knows when to show the values again
C.path = U.MOD_DIR .. "/config.txt"

local by_key = {}
for _, d in ipairs(C.DEFS) do
    by_key[d.key] = d
    C.values[d.key] = d.default
end

function C.def(key)
    return by_key[key]
end

function C.get(key)
    return C.values[key]
end

-- Number of an item setting's value (0 = none, 1-5 plants, 6-9 fish).
function C.item_code(value)
    for i, name in ipairs(ITEMS) do
        if name == value then return i - 1 end
    end
    return 0
end

local function clamp(def, n)
    if def.min and n < def.min then n = def.min end
    if def.max and n > def.max then n = def.max end
    if def.kind == "int" then return math.floor(n + 0.5) end
    -- The menu hands over single-precision numbers (0.7 arrives as 0.699999988): keep two decimals.
    return math.floor(n * 100 + 0.5) / 100
end

local function parse(def, text)
    if def.kind == "bool" then
        text = text:lower()
        if text == "true" or text == "1" or text == "oui" or text == "on" then return true end
        if text == "false" or text == "0" or text == "non" or text == "off" then return false end
        return nil
    elseif def.kind == "choice" then
        -- the value itself, or what the menu shows for it; capitals do not matter
        local wanted = text:upper()
        for _, c in ipairs(def.choices) do
            local label = C.CHOICE_LABEL[c]
            if c:upper() == wanted or (label and label:upper() == wanted) then return c end
        end
        return nil
    else
        local n = tonumber(text)
        if n == nil then return nil end
        return clamp(def, n)
    end
end

function C.format(key)
    local v = C.values[key]
    if type(v) == "boolean" then return v and "OUI" or "NON" end
    if type(v) == "string" then return C.CHOICE_LABEL[v] or v end
    if type(v) == "number" and v ~= math.floor(v) then return string.format("%.1f", v) end
    return tostring(v)
end

function C.load()
    local f = io.open(C.path, "r")
    if not f then
        U.log("Pas de config.txt, valeurs par défaut utilisées (%s)", C.path)
        C.save()
        return
    end
    local seen, old = {}, {}
    for line in f:lines() do
        local k, v = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
        local def = k and by_key[k]
        if def then
            seen[k] = true
            local parsed = parse(def, v)
            if parsed ~= nil then
                C.values[k] = parsed
            else
                U.log("config.txt : valeur refusée pour %s (%s), %s gardé", k, v, tostring(C.values[k]))
            end
        elseif k and LEGACY_PLANT[k] then
            old[k] = tonumber(v)
        end
    end
    f:close()
    -- settings of an older version: taken over when the new one is not in the file
    local stale = false
    for k, n in pairs(old) do
        stale = true
        local new = LEGACY_PLANT[k]
        if not seen[new] and n == math.floor(n) and n >= 1 and n <= 5 then C.values[new] = ITEMS[n + 1] end
    end
    for _, d in ipairs(C.DEFS) do
        if not seen[d.key] then stale = true end
    end
    -- one letter for both personal keys: the one the file does not name takes another letter
    -- (an older file whose "consume" key is the power key's default), else the "consume" key
    if C.values.use_key == C.values.power_key then
        local moved = seen.power_key and "use_key" or "power_key"
        for _, letter in ipairs(C.FREE_KEYS) do
            if letter ~= C.values[KEY_TWIN[moved]] then
                U.log("config.txt : use_key et power_key avaient la même touche (%s), %s devient %s",
                    C.values[moved], moved, letter)
                C.values[moved] = letter
                stale = true
                break
            end
        end
    end
    U.debug_enabled = C.values.debug == true
    U.log("Réglages chargés depuis %s", C.path)
    -- the file is written again when it lacks a setting, so that every setting can be edited
    if stale then C.save() end
end

function C.save()
    local f = io.open(C.path, "w")
    if not f then
        U.log("Impossible d'écrire %s", C.path)
        return false
    end
    f:write("# LPRoles - réglages. Modifiable ici ou dans le menu Échap, onglet LPROLES.\n")
    for _, d in ipairs(C.DEFS) do
        local choices = d.kind == "choice" and (" (" .. table.concat(d.choices, ", ") .. ")") or ""
        f:write(string.format("# %s - %s%s\n%s = %s\n", d.group, d.label, choices, d.key, tostring(C.values[d.key])))
    end
    f:close()
    return true
end

-- Sets one setting (the value is validated against its definition).
function C.set(key, value, save)
    local d = by_key[key]
    if not d then return false end
    if d.kind == "bool" then
        value = value == true
    elseif d.kind == "choice" then
        local found = false
        for _, c in ipairs(d.choices) do
            if c == value then found = true end
        end
        if not found then return false end
    else
        if type(value) ~= "number" then return false end
        value = clamp(d, value)
    end
    -- the two personal keys never share a letter: the other one takes the letter just left
    local twin, before = KEY_TWIN[key], C.values[key]
    if twin and C.values[twin] == value and before ~= value then C.values[twin] = before end
    C.values[key] = value
    C.revision = C.revision + 1
    U.debug_enabled = C.values.debug == true
    if save then C.save() end
    return true
end

-- Moves a setting one step up (dir = 1) or down (dir = -1); returns the new formatted value.
function C.step(key, dir)
    local d = by_key[key]
    if not d then return nil end
    local v = C.values[key]
    if d.kind == "bool" then
        v = not v
    elseif d.kind == "choice" then
        local idx = 1
        for i, c in ipairs(d.choices) do
            if c == v then idx = i end
        end
        idx = ((idx - 1 + dir) % #d.choices) + 1
        v = d.choices[idx]
    else
        v = v + dir * (d.step or 1)
    end
    C.set(key, v, true)
    return C.format(key)
end

return C
