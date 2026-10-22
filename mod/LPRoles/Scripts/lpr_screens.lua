-- LPRoles - the game's own screens at the start and at the end of a game, completed on this
-- machine: the mod's role on the screen that opens a game, the Bouffon's victory on the
-- screen that ends one.
-- Both are texts of the in-game interface (W_inGame). The game writes them when it shows the
-- screen ("Game Start": camp and description; "Force End": "SESSION STOPPED", the way a game
-- ended by the host's own "stop" is shown); the mod writes its own in their place.
local U = require("lpr_util")
local G = require("lpr_game")
local N = require("lpr_net")
local S = require("lpr_strings")

local SC = {}

local HUD_CLASS = "/Game/UI/Game/W_inGame.W_inGame_C"
-- The host draws the roles a second or so after the start screen appears. For this long after
-- it appeared the role is written there (again every second: the game might write its own
-- description once more after a moment).
local START_SECONDS = 10
-- How long the host's word on how the game ends stays good: it comes 3 s before the end.
local END_SECONDS = 15

-- at, hud: when the start screen was last shown, and on which interface; role, role_at: the
-- role to write, and when the host said it. The two may come in either order.
local start = { at = nil, hud = nil, role = nil, role_at = 0, written = 0 }
local ending = { at = nil, hud = nil, kind = nil, said = nil }

local function write_role(now)
    if not start.role then return end
    if not (start.at and start.at >= start.role_at - START_SECONDS) then
        -- the start screen of this game has not been seen yet
        if now - start.role_at > START_SECONDS then start.role = nil end
        return
    end
    if now - start.at > START_SECONDS or not U.valid(start.hud) then
        start.role = nil
        return
    end
    if now - start.written < 1 then return end
    start.written = now
    local lines = S.ROLE_BANNER[start.role] or { S.ROLE_NAME[start.role] or start.role }
    local block = U.get(start.hud, "Black_Subtitle", nil)
    if G.text_call(block, "SetText", table.concat(lines, "\n")) and not start.logged then
        start.logged = true
        U.log("Écran de début : rôle %s écrit", start.role)
    end
end

local function write_end()
    if not (ending.kind and ending.said and ending.at and ending.hud) then return end
    if math.abs(ending.at - ending.said) > END_SECONDS then return end
    local title = S.END_TITLE[ending.kind]
    local block = U.valid(ending.hud) and U.get(ending.hud, "End_Title", nil) or nil
    if title and G.text_call(block, "SetText", title) then
        U.log("Écran de fin : « %s »", title)
    end
    ending.kind = nil                          -- once: a later stop of the host is a plain stop
end

-- The host has drawn this player's role ("START role").
local function on_start(role)
    if role == "none" then return end
    start.role, start.role_at, start.written, start.logged = role, U.now(), 0, false
    U.try("écran de début", write_role, U.now())
end

-- The host says how the game is about to end ("ENDTITLE kind").
local function on_end_title(kind)
    ending.kind, ending.said = kind, U.now()
    U.try("écran de fin", write_end)
end

-- A new game: nothing kept from the one before. (The start screen's time is kept: the game may
-- show it before the host's machine says a game starts.)
function SC.new_game()
    start.role = nil
    ending.kind = nil
end

function SC.install()
    N.on("START", on_start)
    N.on("ENDTITLE", on_end_title)
    U.hook(HUD_CLASS .. ":Game Start", function(ctx)
        start.at, start.hud, start.written = U.now(), ctx:get(), 0
        U.try("écran de début", write_role, start.at)
    end)
    U.hook(HUD_CLASS .. ":Force End", function(ctx)
        ending.at, ending.hud = U.now(), ctx:get()
        U.try("écran de fin", write_end)
    end)
    U.every_tick("écran de début", function(now)
        if start.role then write_role(now) end
    end)
end

return SC
