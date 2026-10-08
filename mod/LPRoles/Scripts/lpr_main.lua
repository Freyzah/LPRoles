-- LPRoles - loading of the mod. Called by main.lua once the update at launch is done, with
-- what that update did (see lpr_update.lua).
local U = require("lpr_util")

return function(update)

U.log("LPRoles %s - chargement (dossier : %s)", U.VERSION, U.MOD_DIR)
if update then
    local seconds = update.seconds or 0
    if update.state == "updated" then
        U.log("Mise à jour faite au lancement : %s -> %s (%.1f s)", tostring(update.from), tostring(update.to), seconds)
    elseif update.state == "current" then
        U.log("Mise à jour au lancement : rien de nouveau (%.1f s)", seconds)
    elseif update.state == "off" then
        U.log("Mise à jour au lancement désactivée (réglage auto_update)")
    else
        U.log("Mise à jour au lancement non faite : %s (%.1f s)", tostring(update.detail), seconds)
    end
end
local checked, problem = pcall(U.check_install)
if not checked then problem = nil end
if problem then U.log("INSTALLATION INCOMPLÈTE : %s. Recopier tout le dossier du mod.", problem) end

local ok, err = pcall(function()
    local C = require("lpr_config")
    C.load()

    -- Before 0.6.1 the crash guards switched the tab and the tablet page off in the settings,
    -- sometimes wrongly, with no way to switch them back on in game. Once, at the first
    -- launch of this version, both are switched back on.
    local marker = U.MOD_DIR .. "/reprise-061.txt"
    local done = io.open(marker, "r")
    if done then
        done:close()
    else
        for _, key in ipairs({ "menu_tab", "tablet_page" }) do
            if C.get(key) ~= true then
                C.set(key, true, true)
                U.log("Réglage %s remis à OUI (il avait pu être coupé par l'ancienne sécurité anti-plantage)", key)
            end
        end
        local w = io.open(marker, "w")
        if w then
            w:write("fait\n")
            w:close()
        else
            U.log("Fichier %s non écrit : la remise en route sera refaite au prochain lancement", marker)
        end
    end

    local G = require("lpr_game")
    local S = require("lpr_strings")
    local Client = require("lpr_client")
    local Server = require("lpr_server")
    local Menu = require("lpr_menu")
    local Lobby = require("lpr_lobby")
    local Tablet = require("lpr_tablet")

    Client.install()
    Server.install()
    Menu.install(Client.role, Client.on_role_change, Client.status)
    Tablet.install(Client.role, Client.on_role_change, Client.status)
    Lobby.install(Server, { Menu, Tablet })
    if problem then
        U.after(20, "avis d'installation", function() G.say(S.INSTALL_BROKEN, S.COLOR.bad) end)
    end
    if update and update.state == "updated" then
        U.after(20, "avis de mise à jour", function() G.say(string.format(S.UPDATED, U.VERSION), S.COLOR.good) end)
    end
    U.log("LPRoles chargé. Les accroches se posent dès que le jeu a chargé ses classes.")
    U.start_scheduler(100)                -- last: nothing else runs here once ticks may start
end)

if not ok then U.log("ÉCHEC du chargement : %s", tostring(err)) end

end
