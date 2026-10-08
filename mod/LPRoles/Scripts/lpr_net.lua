-- LPRoles - messages between the host and the players' machines.
--
-- Host -> one player : the engine's own "ClientMessage" RPC on that player's controller.
--                      It reaches only that player; without the mod it prints nowhere.
-- Player -> host     : the game's "Net Eye State" RPC with a spare value used as an opcode.
--                      The engine sends this enum on 3 bits, so only 0-7 cross the network;
--                      the game uses 0-4, which leaves 5, 6 and 7. The real eye state is sent
--                      again right after, so a host without the mod is left in a normal state.
--                      It says "something happened", not how much: for a number, the game's
--                      "Request Net Interaction" RPC is used (see N.report below).
-- Every argument is text made of ASCII letters and integers.
local U = require("lpr_util")
local G = require("lpr_game")

local N = {}

N.PREFIX = "LPR"
N.OP_MIN = 5              -- anything from here up is not a real eye state
N.OP_USE = 5              -- "consume the item in my hand"
N.OP_HELLO = 6            -- "this machine has the mod"
-- The last free value says two things, which the host tells apart from what the player is
-- doing: "I pressed my power key", and from a sleeping Rêveur's machine "my dream ended on my
-- side" (the Rêveur's power is the only one that is not on that key).
N.OP_ACT = 7
N.OP_WAKE = N.OP_ACT

local handlers = {}
local tag = nil

function N.on(cmd, fn)
    handlers[cmd] = fn
end

-- Host: send a command to the owner of `mec`.
function N.send(mec, cmd, ...)
    local pc = G.controller_of(mec)
    if not pc then
        U.dbg("pas de contrôleur pour envoyer %s", cmd)
        return false
    end
    local parts = { N.PREFIX, cmd }
    for _, v in ipairs({ ... }) do parts[#parts + 1] = tostring(v) end
    local msg = table.concat(parts, "|")
    tag = tag or FName(N.PREFIX)
    U.dbg("envoi -> %s : %s", G.player_name(mec), msg)
    return U.try("ClientMessage", function()
        pc:ClientMessage(msg, tag, 0.0)
        return true
    end) == true
end

-- Player: send an opcode to the host.
function N.to_host(op)
    local mec = G.local_mec()
    if not mec then return false end
    local eye = U.get(mec, "EyesState", 0)
    U.dbg("envoi -> hôte : op %d", op)
    U.tcall(mec, "Net Eye State", op)
    U.tcall(mec, "Net Eye State", eye)
    return true
end

-- Player: send a number (0 to N.REPORT_MAX) to the host. The game's "interaction" RPC, given
-- an actor that cannot be interacted with (the player's own PlayerState), does nothing at all;
-- its index carries the number, above a base no real interaction reaches. The host reads it in
-- a hook (lpr_server.lua). For what only a player's machine knows: its character's life.
N.REPORT = 1296000000
N.REPORT_MAX = 999

function N.report(value)
    local mec = G.local_mec()
    local state = mec and U.get(mec, "PlayerState", nil)
    if not U.valid(state) then return false end
    local n = math.max(0, math.min(N.REPORT_MAX, math.floor(value + 0.5)))
    U.tcall(mec, "Request Net Interaction", state, N.REPORT + n, G.item_state(0))
    return true
end

local function to_lua_string(v)
    if type(v) == "string" then return v end
    local ok, s = pcall(function() return v:ToString() end)
    if ok and type(s) == "string" then return s end
    return nil
end

-- Registered on every machine; only fires where the RPC body actually runs,
-- i.e. on the machine of the player the message was addressed to.
function N.install_receiver()
    U.hook("/Script/Engine.PlayerController:ClientMessage", function(ctx, text)
        local s = to_lua_string(text:get())
        if not s or s:sub(1, #N.PREFIX + 1) ~= N.PREFIX .. "|" then return end
        local pc = ctx:get()
        local mine = G.local_pc()
        if mine and U.valid(pc) and pc:GetAddress() ~= mine:GetAddress() then return end
        local parts = U.split(s, "|")
        local cmd = parts[2]
        local fn = handlers[cmd]
        U.dbg("reçu : %s", s)
        if fn then
            U.try("message " .. tostring(cmd), fn, table.unpack(parts, 3))
        end
    end)
end

return N
