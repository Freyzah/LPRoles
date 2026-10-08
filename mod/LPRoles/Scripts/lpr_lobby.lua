-- LPRoles - backup way to change settings with function keys (the normal way is the
-- LPROLES tab of the pause menu). Messages are kept very short: the banner font is huge.
local U = require("lpr_util")
local C = require("lpr_config")
local G = require("lpr_game")
local S = require("lpr_strings")

local L = {}

-- Change the keys here if they clash with something else.
L.KEYS = {
    previous = Key.F5,
    next = Key.F6,
    decrease = Key.F7,
    increase = Key.F8,
    summary = Key.F9,
    diagnostic = Key.F10,
}

local cursor = 1
local server = nil
local retry = {}             -- modules with a retry() (menu tab, tablet page)

local function show(text, color)
    G.say_now(text, S.COLOR[color or "info"])
end

local function current()
    return C.DEFS[cursor]
end

local function show_current()
    local d = current()
    show(string.format("%s - %s : %s", d.group, d.label, C.format(d.key)), "info")
end

local function host_only(fn)
    return function()
        if G.is_host() then fn() end
    end
end

local function move(dir)
    cursor = ((cursor - 1 + dir) % #C.DEFS) + 1
    show_current()
end

local function change(dir)
    local d = current()
    C.step(d.key, dir)
    show(C.format(d.key), "good")
    U.log("Réglage %s = %s (touches F7/F8)", d.key, C.format(d.key))
end

local function summary()
    local modded, total = 0, 0
    if server then modded, total = server.modded_count() end
    show(string.format("LPROLES %s - MOD : %d/%d JOUEURS", U.VERSION, modded, total), "role")
end

-- Works for everyone (host or not): writes what the mod can see to the journal, and puts the
-- LPROLES tab and the tablet page back if they were off (a setting, or the crash guards).
local function diagnostic()
    local mec = G.local_mec()
    local hud = mec and U.get(mec, "HUD", nil)
    local back = false
    for _, key in ipairs({ "menu_tab", "tablet_page" }) do
        if C.get(key) ~= true then
            C.set(key, true, true)
            back = true
        end
    end
    local guards = {}
    for _, g in ipairs(U.guards) do
        guards[#guards + 1] = string.format("%s %d%s", g.name, g.strikes, g.blocked and " (en pause)" or "")
        if g.blocked or g.strikes > 0 then
            g.reset()
            back = true
        end
    end
    for _, m in ipairs(retry) do m.retry() end      -- a tab or a page given up after errors is tried again
    U.log("Diagnostic %s | hôte : %s | en partie : %s | personnage : %s | interface : %s | accroches en attente : %d | horloge : %s | gardes : %s | installation : %s | réglages : %s",
        U.VERSION, G.is_host() and "oui" or "non", G.in_game() and "oui" or "non",
        mec and "trouvé" or "absent", U.valid(hud) and "trouvée" or "absente", U.pending_hook_count(),
        U.clock_state(), table.concat(guards, ", "), U.install_problem or "complète", C.path)
    show(string.format(back and S.DIAG_BACK or S.DIAG_OK, U.VERSION), back and "good" or "info")
end

function L.install(server_module, retry_modules)
    server = server_module
    retry = retry_modules or {}
    local binds = {
        { L.KEYS.previous, "F5", function() move(-1) end },
        { L.KEYS.next, "F6", function() move(1) end },
        { L.KEYS.decrease, "F7", function() change(-1) end },
        { L.KEYS.increase, "F8", function() change(1) end },
        { L.KEYS.summary, "F9", summary },
    }
    for _, b in ipairs(binds) do
        local ok, err = U.on_key(b[1], b[2], host_only(b[3]))
        if not ok then U.log("Touche non enregistrée : %s", tostring(err)) end
    end
    local ok, err = U.on_key(L.KEYS.diagnostic, "F10", diagnostic)
    if not ok then U.log("Touche non enregistrée : %s", tostring(err)) end
    U.log("Touches de secours : F5/F6 choisir, F7/F8 modifier, F9 résumé (hôte) ; F10 diagnostic et remise en route")
end

return L
