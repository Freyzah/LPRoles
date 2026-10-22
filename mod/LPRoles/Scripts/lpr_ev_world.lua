-- LPRoles - the ship as the random events see it (lpr_ev.lua and the lpr_evm_*.lua modules):
-- sectors and places, game items put down, followed and taken away, what a player holds,
-- weapons, the machines' item slots, alarm boxes and their sirens, radios, camera screens, the
-- game's clock, the line of sight between two players.
-- [H]: on the host only (the game's state lives there); [A]: on every machine.
-- Every game name below was read in analysis/bp (tools/lp/verify_mod.py checks them).
local U = require("lpr_util")
local G = require("lpr_game")

local W = {}

-- ---------------------------------------------------------------- game paths
W.PATH_RADIO = "/Game/World/Music/Music_Small.Music_Small_C"
W.PATH_ALARM = "/Game/World/MapCommunication/AlarmButton.AlarmButton_C"
W.PATH_SLOT = "/Game/World/ItemSlot/ItemSlot.ItemSlot_C"
W.PATH_EXPLOSION = "/Game/World/Explosion/Explosion.Explosion_C"
W.PATH_GUN = "/Game/Items/Data_Gun.Data_Gun_C"
W.PATH_GRENADE = "/Game/Items/Data_Grenade.Data_Grenade_C"

-- Items an event may put down (data assets). DA_Package is left out on purpose: it may count
-- for the Delivery task.
W.ASSET = {
    MUSIC     = "/Game/Items/Melee/Music/DA_Music.DA_Music",                   -- a radio's cassette
    JERRICAN  = "/Game/Items/FieldItems/Jerrican/DA_Jerrican.DA_Jerrican",     -- a heavy weapon too
    FOODCAN   = "/Game/Items/FieldItems/FoodCan/DA_FoodCan.DA_FoodCan",
    EASTEREGG = "/Game/Items/Melee/EasterEgg/DA_EasterEgg.DA_EasterEgg",       -- its state Value sets its colour
    MUG       = "/Game/Items/FieldItems/Mug/DA_Mug.DA_Mug",
    TAPEROLL  = "/Game/Items/FieldItems/TapeRoll/DA_TapeRoll.DA_TapeRoll",
    SCALPEL   = "/Game/Items/FieldItems/Scalpel/DA_Scalpel.DA_Scalpel",
}

-- Fields of Str_ItemSpawnLocation (an Item_Spawner_C's "Location"): the sector, and the room
-- inside it.
W.F_SPAWN_SECTOR = "Sector_2_8B5600644E18D428EE5FC28B79A33CE2"
W.F_SPAWN_ROOM = "Room_6_D4EE65BF49C6C2FFEF9852A991E2E55B"

-- The sectors (Enum_Sectors, FunctionLibrary "Sector Name" 0x03ba): 1 cameras, 2 offices,
-- 3 botany, 4 restaurant, 5 hospital, 6 storage, 7 machines. 0 is no sector: never drawn,
-- never named (S.SECTOR has no 0).
W.SECTORS = { 1, 2, 3, 4, 5, 6, 7 }

-- Item places never used for an item of an event, as "sector.room" (rooms closed by an access
-- card, once they are known from a game: none is known yet).
W.NO_ROOMS = {}

local cache = {}             -- actors read once per game (W.reset)
local marker = 7000          -- the last marker given
local switching = {}         -- mec address -> { since, last }: "Net Item Switching" seen set (W.switching)

-- A new game: everything read again (and the markers start somewhere else).
function W.reset()
    cache = {}
    switching = {}
    marker = 7000 + math.random(0, 899)
end

-- Every valid actor of a class (by its short name, "MapSpawn_C").
local function all_of(class)
    local out = {}
    local list = FindAllOf(class)
    if list then
        for _, a in ipairs(list) do
            if U.valid(a) then out[#out + 1] = a end
        end
    end
    return out
end
W.all_of = all_of

local function dist2d(a, b)
    local dx, dy = a.X - b.X, a.Y - b.Y
    return math.sqrt(dx * dx + dy * dy)
end
W.dist2d = dist2d

local function valid_sector(s)
    return type(s) == "number" and s >= 1 and s <= 7
end

-- ---------------------------------------------------------------- places [H]
-- The players' spawn points (MapSpawn_C, behind GM "Spawns"): on the floor, clear. Each:
-- { actor, sector, at, yaw }. Read only: never change these tables.
local function spawns()
    if cache.spawns then return cache.spawns end
    local out = {}
    for _, a in ipairs(all_of("MapSpawn_C")) do
        local s = U.get(a, "Room", 0)
        local at = G.location(a)
        if at and valid_sector(s) then
            local yaw = 0.0
            pcall(function() yaw = a:K2_GetActorRotation().Yaw + 0.0 end)
            out[#out + 1] = { actor = a, sector = s, at = at, yaw = yaw }
        end
    end
    cache.spawns = out
    return out
end

-- The spawn points of sector s (every sector when s is nil).
function W.spawn_spots(s)
    local out = {}
    for _, e in ipairs(spawns()) do
        if s == nil or e.sector == s then out[#out + 1] = e end
    end
    return out
end

-- One spawn point of sector s, at random: its position (a copy) and its yaw; nil when none.
function W.spawn_spot(s)
    local list = W.spawn_spots(s)
    if #list == 0 then return nil end
    local e = list[math.random(#list)]
    return U.vec_copy(e.at), e.yaw
end

-- The game's item places (Item_Spawner_C), each { actor, sector, room, at }.
local function spawner_list()
    if cache.spawners then return cache.spawners end
    local out = {}
    for _, a in ipairs(all_of("Item_Spawner_C")) do
        local loc = U.get(a, "Location", nil)
        local s, room = 0, 0
        pcall(function() s, room = loc[W.F_SPAWN_SECTOR] + 0, loc[W.F_SPAWN_ROOM] + 0 end)
        local at = G.location(a)
        if at and valid_sector(s) and not W.NO_ROOMS[s .. "." .. room] then
            out[#out + 1] = { actor = a, sector = s, room = room, at = at }
        end
    end
    cache.spawners = out
    return out
end

-- The item places of sector s (every sector when nil); free: only those no item uses yet
-- (Used is false: "Spawn Item" refuses the others).
function W.spawners(s, free)
    local out = {}
    for _, e in ipairs(spawner_list()) do
        if (s == nil or e.sector == s) and (not free or U.get(e.actor, "Used", true) == false) then
            out[#out + 1] = e
        end
    end
    return out
end

-- The middle of a sector: the mean of its spawn points (nil when it has none).
function W.sector_center(s)
    local list = W.spawn_spots(s)
    if #list == 0 then return nil end
    local x, y, z = 0, 0, 0
    for _, e in ipairs(list) do x, y, z = x + e.at.X, y + e.at.Y, z + e.at.Z end
    return { X = x / #list, Y = y / #list, Z = z / #list }
end

-- The sector a position is in: the one of the nearest item place or spawn point (nil without
-- a position or a place).
function W.sector_at(pos)
    if not pos then return nil end
    local best, best_d = nil, math.huge
    for _, list in ipairs({ spawner_list(), spawns() }) do
        for _, e in ipairs(list) do
            local d = U.dist(e.at, pos)
            if d < best_d then best, best_d = e.sector, d end
        end
    end
    return best
end

-- A sector drawn at random among those that have a spawn point or an item place and for
-- which filter(s) is true (every such sector without a filter); nil when none.
function W.random_sector(filter)
    local out = {}
    for _, s in ipairs(W.SECTORS) do
        local known = #W.spawn_spots(s) > 0 or #W.spawners(s) > 0
        if known and (not filter or filter(s)) then out[#out + 1] = s end
    end
    if #out == 0 then return nil end
    return out[math.random(#out)]
end

-- The n sectors whose middle is the furthest from sector s's, the furthest first.
function W.far_sectors(s, n)
    local from = W.sector_center(s)
    if not from then return {} end
    local list = {}
    for _, t in ipairs(W.SECTORS) do
        local c = (t ~= s) and W.sector_center(t) or nil
        if c then list[#list + 1] = { s = t, d = U.dist(c, from) } end
    end
    table.sort(list, function(a, b) return a.d > b.d end)
    local out = {}
    for i = 1, math.min(n or 1, #list) do out[i] = list[i].s end
    return out
end

function W.far_sector(s)
    return W.far_sectors(s, 1)[1]
end

-- [A] The actor of a class (short name) nearest to `at`, within tol cm; nil when none.
function W.find_near(class, at, tol)
    if not at then return nil end
    local best, best_d = nil, tol or 300
    for _, a in ipairs(all_of(class)) do
        local p = G.location(a)
        local d = p and U.dist(p, at) or math.huge
        if d <= best_d then best, best_d = a, d end
    end
    return best
end

-- ---------------------------------------------------------------- line of sight [H]
-- Whether nothing stands between two points, the two characters left out: the engine's line
-- trace (channel 1, the game's aim), as lpr_server.lua's clear_line does. Should the trace
-- fail, the answer is "seen", and the journal says so once.
local trace_lib, trace_warned = nil, false
local NO_COLOR = { R = 0.0, G = 0.0, B = 0.0, A = 0.0 }

function W.sees(from_mec, to_mec, from, to)
    trace_lib = (U.valid(trace_lib) and trace_lib) or StaticFindObject("/Script/Engine.Default__KismetSystemLibrary")
    local ok, hit = pcall(function()
        return trace_lib:LineTraceSingle(from_mec, from, to, 1, false, { from_mec, to_mec }, 0, {}, true, NO_COLOR, NO_COLOR, 0.0)
    end)
    if ok then return hit ~= true end
    if not trace_warned then
        trace_warned = true
        U.log("Évènements : tracé de vue impossible (%s), toute vue est acceptée", tostring(hit))
    end
    return true
end

-- ---------------------------------------------------------------- items [H]
-- An item put down by an event carries a marker in its state's Time, a number of 7000 to 7999
-- for this game: it travels with the item through hands, bags, the Voleur, a dead body and a
-- radio's reader, so the item is known wherever it goes. (The game reads Time for a few items
-- only: a gun's flag, the egg's, a battery's look. An item put down again with its own state
-- - a weapon taken away - carries no marker.)
function W.next_marker()
    marker = marker + 1
    if marker > 7999 then marker = 7000 end
    return marker
end

local function item_state(value, time)
    return { [G.F_STATE_VALUE] = math.floor(value or 0), [G.F_STATE_TIME] = math.floor(time or 0) }
end
W.item_state = item_state

-- A data asset from its path, or the object itself; nil when it cannot be found.
function W.data_of(what)
    if type(what) == "string" then return G.asset(what) end
    if U.valid(what) then return what end
    return nil
end

-- The short name of a data asset ("DA_FoodCan"), "" when it cannot be read.
function W.data_name(data)
    local ok, n = pcall(function() return data:GetFName():ToString() end)
    return (ok and type(n) == "string") and n or ""
end

local function addr(o)
    return U.valid(o) and o:GetAddress() or nil
end

-- The state of an item lying on the ground: value, time.
local function ground_state(w)
    local st = U.get(w, "Item State", nil)
    local ok, v, t = pcall(function() return st[G.F_STATE_VALUE], st[G.F_STATE_TIME] end)
    if not ok then return 0, 0 end
    return v or 0, t or 0
end

-- Whether an item of data `d`, with that state time, is the one of `rec`.
local function is_rec(rec, d, time)
    return d ~= nil and addr(d) == rec.addr and (rec.marker == nil or time == rec.marker)
end

-- Puts an item down at a free item place. what: an asset path (W.ASSET.X) or a data object;
-- opts: sector (nil: any), value (state Value), time (state Time: then no marker, the item is
-- known only by its actor), far_from (positions) with min_dist (cm), keep (left in the game when
-- the event stops: lpr_ev.lua). Returns { data, addr, name, value, marker, item (its
-- WorldItem_C), at, spawner, keep }, or nil (never an error).
function W.place(what, opts)
    opts = opts or {}
    local data = W.data_of(what)
    if not data then return nil end
    local list = {}
    for _, e in ipairs(W.spawners(opts.sector, true)) do
        local ok = true
        for _, p in ipairs(opts.far_from or {}) do
            if p and U.dist(p, e.at) < (opts.min_dist or 0) then ok = false end
        end
        if ok then list[#list + 1] = e end
    end
    if #list == 0 then return nil end
    local spot = list[math.random(#list)]
    local mark = nil
    local time = opts.time
    if time == nil then
        mark = W.next_marker()
        time = mark
    end
    local want = data:GetAddress()
    local before = {}
    for _, w in ipairs(all_of("WorldItem_C")) do
        if addr(U.get(w, "Data", nil)) == want then before[w:GetAddress()] = true end
    end
    local sp = spot.actor
    U.tcall(sp, "Spawn Item", { [G.F_ITEM_DATA] = data, [G.F_ITEM_STATE] = item_state(opts.value, time) })
    local item = nil
    for _, w in ipairs(all_of("WorldItem_C")) do
        if not before[w:GetAddress()] and addr(U.get(w, "Data", nil)) == want then
            local _, t = ground_state(w)
            if mark == nil or t == mark then item = w end
        end
    end
    if not item then
        U.log("Évènements : objet %s non posé (emplacement du secteur %d)", W.data_name(data), spot.sector)
        return nil
    end
    return { data = data, addr = want, name = W.data_name(data), value = opts.value or 0, marker = mark,
             item = item, at = G.location(item) or spot.at, spawner = sp, keep = opts.keep == true }
end

-- Where an item put down by W.place is now: { where = "ground"|"hand"|"bag"|"slot"|"gone",
-- P (hand, bag), actor (ground: its WorldItem_C; slot: the ItemSlot_C), at }. each(fn): the
-- players to look at (lpr_ev.lua gives every player). The hands and bags are read every time,
-- the item on the ground kept; the whole ground and the machines' slots are searched at most
-- twice a second (the last answer of that search is given in between).
function W.track(rec, each, now)
    if not rec or rec.removed then return { where = "gone" } end
    now = now or U.now()
    if rec.marker == nil then
        -- put down with a state of its own: known by its actor only, while it lies there
        local w = rec.item
        if U.valid(w) and addr(U.get(w, "Data", nil)) == rec.addr then
            return { where = "ground", actor = w, at = G.location(w) }
        end
        return { where = "gone" }
    end
    local found = nil
    each(function(P)
        if found or not U.valid(P.mec) then return end
        local d, _, t = G.hand_item_data(P.mec)
        if d and is_rec(rec, d, t) then
            found = { where = "hand", P = P, at = G.location(P.mec) }
            return
        end
        d, _, t = G.bag_item_data(P.mec)
        if d and is_rec(rec, d, t) then found = { where = "bag", P = P, at = G.location(P.mec) } end
    end)
    if found then
        rec.missed = nil
        return found
    end
    local w = rec.item
    if U.valid(w) then
        local _, t = ground_state(w)
        if is_rec(rec, U.get(w, "Data", nil), t) then
            rec.missed = nil
            return { where = "ground", actor = w, at = G.location(w) }
        end
    end
    rec.item = nil
    if rec.missed and now - rec.missed.at < 0.5 then return rec.missed.t end
    local t = { where = "gone" }
    for _, g in ipairs(all_of("WorldItem_C")) do
        local _, time = ground_state(g)
        if is_rec(rec, U.get(g, "Data", nil), time) then
            rec.item = g
            return { where = "ground", actor = g, at = G.location(g) }
        end
    end
    for _, slot in ipairs(all_of("ItemSlot_C")) do
        if U.get(slot, "Item In", false) == true then
            local st = U.get(slot, "Item State", nil)
            local ok, time = pcall(function() return st[G.F_STATE_TIME] end)
            if ok and is_rec(rec, U.get(slot, "Item Data", nil), time) then
                t = { where = "slot", actor = slot, at = G.location(slot) }
                break
            end
        end
    end
    rec.missed = { at = now, t = t }
    return t
end

-- Takes the item out of a player's hand the way an item put in a slot does (the Voleur's
-- way): the game's own two calls. True when the hand is empty after.
function W.let_go(mec)
    U.tcall(mec, "Let Item")
    U.tcall(mec, "Net Let Item")
    return G.hand_item_data(mec) == nil
end

-- Empties a player's bag: the game's own drop from the bag (Net Drop Item with Bag set, which
-- empties the host's record itself, 0xaf7b), the dropped item taken away at once, then the
-- player's machine told (Clear Bag: Set Bag Item with nothing). keep_item: the dropped item is
-- left at the feet (a search) and returned. True (and the item left, if kept) when the bag is
-- empty after.
function W.drop_bag(mec, keep_item)
    local data, value, time = G.bag_item_data(mec)
    if not data then return true end
    local feet = G.location(mec)
    if not feet then return false end
    local at = { X = feet.X, Y = feet.Y, Z = feet.Z + 50 }
    local want = data:GetAddress()
    local before = {}
    for _, w in ipairs(all_of("WorldItem_C")) do before[w:GetAddress()] = true end
    U.tcall(mec, "Net Drop Item", data, item_state(value, time), at, { Pitch = 0.0, Yaw = 0.0, Roll = 0.0 },
        U.vec(0, 0, 1), U.vec(), true)
    local dropped = nil
    for _, w in ipairs(all_of("WorldItem_C")) do
        if not before[w:GetAddress()] and addr(U.get(w, "Data", nil)) == want then dropped = w end
    end
    if G.bag_item_data(mec) ~= nil then return false end
    U.tcall(mec, "Clear Bag")
    if dropped and not keep_item then
        pcall(function() dropped:K2_DestroyActor() end)
        dropped = nil
    end
    return true, dropped
end

-- [H] Whether a player is swapping hand and bag ("Net Item Switching"): nothing is taken from it
-- meanwhile. The host's flag may stay stuck true (seen in game): set on every look for more than
-- SWITCH_STUCK s, it is taken as stuck and no longer counts. Looks further apart than SWITCH_GAP s
-- start the count again (a new swap, not the old one still going on).
local SWITCH_STUCK, SWITCH_GAP = 1.0, 1.5

function W.switching(mec)
    local key = U.key(mec)
    if not key then return false end
    if U.get(mec, "Net Item Switching", false) ~= true then
        switching[key] = nil
        return false
    end
    local now = U.now()
    local s = switching[key]
    if not s or now - s.last > SWITCH_GAP then
        s = { since = now }
        switching[key] = s
    end
    s.last = now
    return now - s.since < SWITCH_STUCK
end

-- Takes away what a player holds, without dropping it: where = "hand" or "bag". Returns
-- { data, value, time } (what was taken), or nil when there was nothing, when the player is
-- swapping hand and bag (W.switching: a call again a second later takes it from a player whose
-- flag is stuck), or when it could not be done.
function W.take(mec, where)
    if not U.valid(mec) or W.switching(mec) then return nil end
    if where == "bag" then
        local data, value, time = G.bag_item_data(mec)
        if not data then return nil end
        if not W.drop_bag(mec, false) then return nil end
        return { data = data, value = value, time = time }
    end
    local data, value, time = G.hand_item_data(mec)
    if not data then return nil end
    if not W.let_go(mec) then return nil end
    return { data = data, value = value, time = time }
end

-- Takes an item put down by W.place away, wherever it is (ground: destroyed; hand, bag: taken
-- from the player; a machine's slot: deleted, the slot's "take" told as when a player takes
-- it). Returns where it was.
function W.remove(rec, each)
    if not rec or rec.removed then return "gone" end
    local t = W.track(rec, each)
    if t.where == "ground" then
        local w = t.actor
        pcall(function() w:K2_DestroyActor() end)
    elseif t.where == "hand" then
        W.let_go(t.P.mec)
    elseif t.where == "bag" then
        W.drop_bag(t.P.mec, false)
    elseif t.where == "slot" then
        local slot = t.actor
        U.tcall(slot, "Delete Item", true)
    end
    rec.removed = true
    return t.where
end

-- ---------------------------------------------------------------- weapons
-- An item's data as a weapon code (S.WEAPON): 1 knife, 2 pistol, 3 revolver, 4 shorty,
-- 5 shotgun, 6 SMG, 7 rifle, 8 C4, 9 detonator, 10 grenade, 11 scalpel (it strikes as the knife
-- does); 0 for any other item; nil for no item. The training variants ("DA_PistolDefault"...)
-- count as their gun.
local WEAPON_CODE = { DA_Knife = 1, DA_Pistol = 2, DA_Revolver = 3, DA_Shorty = 4, DA_Shotgun = 5, DA_SMG = 6,
                      DA_Rifle = 7, DA_C4 = 8, DA_Detonator = 9, DA_Grenade = 10, DA_Scalpel = 11 }

function W.weapon_code(data)
    if not U.valid(data) then return nil end
    local name = (W.data_name(data):gsub("Default$", ""))
    if WEAPON_CODE[name] then return WEAPON_CODE[name] end
    local ok, gun = pcall(function() return data:IsA(W.PATH_GUN) end)
    if ok and gun then return 2 end                                     -- a gun of another name
    local ok2, grenade = pcall(function() return data:IsA(W.PATH_GRENADE) end)
    if ok2 and grenade then return 10 end
    return 0
end

-- ---------------------------------------------------------------- machines' item slots [H]
-- Locked by "ItemSlot_C:Lock(bool)", which the game replicates (Locked, then the multicast
-- Update): every machine refuses to place or take there, players without the mod included.
-- The slots belong to the machines (child actors): a slot is chosen by its machine's class.
local TASK_MACHINES = { "AlimBox_C", "BatteryCharger_C", "ContainerSlot_C", "SampleSlot_C", "Data_PC_C",
                        "Analysis_PC_C", "Scanner_PC_C", "Scanner_Screen_C", "DeliveryCase_C", "BottleSlot_C",
                        "Fish_Machine_C", "Rice_Machine_C", "Pizzushi_Machine_C", "Pizzushi_Table_C", "Mixer_C",
                        "FilterCleaner_C", "Vent_C", "PC_Cameras_C" }
W.SLOT_SETS = { task = {}, power = { RezCharger_C = true } }
for _, cls in ipairs(TASK_MACHINES) do
    W.SLOT_SETS.task[cls] = true
    W.SLOT_SETS.power[cls] = true
end
-- Never locked: door readers, weapon cases and loader, alarm boxes' fuses, radios, tutorials.

local locks = { held = {}, self = false }     -- slot address -> { slot, saved, n }

local function lock(slot, value)
    locks.self = true
    U.tcall(slot, "Lock", value == true)
    locks.self = false
end

-- The class of the machine a slot belongs to ("" when none).
function W.slot_machine(slot)
    local cls = ""
    pcall(function()
        local parent = slot:GetParentActor()
        if U.valid(parent) then cls = parent:GetClass():GetFName():ToString() end
    end)
    return cls
end

-- Locks the slots of the machines of a set ("task", "power", or a table class -> true);
-- keep(slot, class): false leaves a slot alone. Returns the hold, for W.unlock_slots. A slot
-- held twice is given back once both are let go, with the value it had (or the value its
-- machine set meanwhile: see W.on_slot_lock).
function W.lock_slots(set, keep)
    local wanted = W.SLOT_SETS[set] or set or {}
    local hold = {}
    for _, slot in ipairs(all_of("ItemSlot_C")) do
        local cls = W.slot_machine(slot)
        if wanted[cls] and (not keep or keep(slot, cls) ~= false) then
            local a = slot:GetAddress()
            local h = locks.held[a]
            if not h then
                h = { slot = slot, saved = U.get(slot, "Locked", false) == true, n = 0 }
                locks.held[a] = h
                lock(slot, true)
            end
            h.n = h.n + 1
            hold[#hold + 1] = a
        end
    end
    return hold
end

function W.unlock_slots(hold)
    for _, a in ipairs(hold or {}) do
        local h = locks.held[a]
        if h then
            h.n = h.n - 1
            if h.n <= 0 then
                locks.held[a] = nil
                if U.valid(h.slot) then lock(h.slot, h.saved) end
            end
        end
    end
end

-- After the game's own "Lock" on a slot (a machine ending its cycle locks or frees its slots):
-- a slot held keeps that value for afterwards, and stays locked meanwhile.
function W.on_slot_lock(slot)
    if locks.self or not U.valid(slot) then return end
    local h = locks.held[slot:GetAddress()]
    if not h then return end
    h.saved = U.get(slot, "Locked", false) == true
    lock(slot, true)
end

-- ---------------------------------------------------------------- alarm boxes
-- [H] The alarm boxes (AlarmButton_C), each { actor, sector, at, state }: the state (E_AlarmState:
-- 1 empty, 2 ready with a fuse, 3 ringing, 4 rung) is read at every call, never kept. Boxes of
-- no sector are left out. Never write "State": the game's machine runs on it (state 1 deletes
-- the fuse).
function W.alarms()
    if not cache.alarms then
        local out = {}
        for _, a in ipairs(all_of("AlarmButton_C")) do
            local s = U.get(a, "Sector", 0)
            local at = G.location(a)
            if at and valid_sector(s) then out[#out + 1] = { actor = a, sector = s, at = at } end
        end
        cache.alarms = out
    end
    local list = {}
    for _, e in ipairs(cache.alarms) do
        if U.valid(e.actor) then
            list[#list + 1] = { actor = e.actor, sector = e.sector, at = e.at, state = U.get(e.actor, "State", 0) }
        end
    end
    return list
end

-- [H] One alarm box of sector s, at random; nil when it has none.
function W.alarm_of(s)
    local out = {}
    for _, e in ipairs(W.alarms()) do
        if e.sector == s then out[#out + 1] = e end
    end
    if #out == 0 then return nil end
    return out[math.random(#out)]
end

local function light_up(cube)
    if U.valid(cube) then
        pcall(function() cube:SetScalarParameterValueOnMaterials(FName("AlarmLight"), 2.0) end)
    end
end

-- [A] A box's siren, on this machine only. On: every speaker of the box sounds ("Set Alarm",
-- local: Sound Path level 3, then its sounds), the lights of the box and of the speakers glow as
-- for a ringing box (OnRep_State 0x0298 / 0x04ab). Off: the box's own "OnRep_State", local,
-- which puts speakers and lights back as its real state wants (0x0154).
function W.siren(alarm, on)
    if not U.valid(alarm) then return end
    if not on then
        U.tcall(alarm, "OnRep_State")
        return
    end
    local speakers = U.get(alarm, "Speakers", nil)
    local n = 0
    pcall(function() n = #speakers end)
    for i = 1, n do
        local sp = nil
        pcall(function() sp = speakers[i] end)
        if U.valid(sp) then
            U.tcall(sp, "Set Alarm", true)
            light_up(U.get(sp, "Cube", nil))
        end
    end
    light_up(U.get(alarm, "Cube", nil))
end

-- ---------------------------------------------------------------- radios [H]
-- The radios (Music_Small_C), each { actor, music (the reader: an ItemSlot_C) }. "Is Playing"
-- is known to the host only; State (E_GenericMachine_State): 1 empty, 2 cassette in, 4 playing,
-- 5 paused.
function W.radios()
    if not cache.radios then
        cache.radios = all_of("Music_Small_C")
    end
    local out = {}
    for _, a in ipairs(cache.radios) do
        if U.valid(a) then out[#out + 1] = { actor = a, music = U.get(a, "Music", nil) } end
    end
    return out
end

-- What a radio is like now, in plain numbers: { item_in, value (the cassette's song), te (time
-- played), volume }.
function W.radio_state(a)
    local slot = U.get(a, "Music", nil)
    local inn = U.valid(slot) and U.get(slot, "Item In", false) == true
    local value = 0
    if inn then
        local st = U.get(slot, "Item State", nil)
        pcall(function() value = st[G.F_STATE_VALUE] + 0 end)
    end
    return { item_in = inn, value = value, te = (U.get(a, "Time Elapsed", 0.0) or 0.0) + 0.0,
             volume = U.get(a, "Volume", 4) }
end

-- A song of the game's list (index from 0, below #Musics) from `start` seconds, at a volume
-- of 1 to 10, on every machine (the game's multicasts).
function W.radio_play(a, index, start, vol)
    if not U.valid(a) then return end
    pcall(function() a:FlushNetDormancy() end)
    U.tcall(a, "All Set Song", math.floor(index or 0))
    U.tcall(a, "All Start Song", (start or 0.0) + 0.0, math.floor(vol or 10))
end

-- Silence, everywhere, `t` being the time shown.
function W.radio_cut(a, t)
    if not U.valid(a) then return end
    pcall(function() a:FlushNetDormancy() end)
    U.tcall(a, "All Pause Song", (t or 0.0) + 0.0)
end

-- A radio as W.radio_state saw it: stopped first (setting another song on a radio that plays
-- would start it), then its cassette's song and time back on its screen, or none, then its
-- volume. Nothing is started, nothing of the game's own (State, Is Playing, its timer) written.
function W.radio_restore(a, saved)
    if not (U.valid(a) and saved) then return end
    pcall(function() a:FlushNetDormancy() end)
    U.tcall(a, "All Pause Song", (saved.te or 0.0) + 0.0)
    if saved.item_in then
        U.tcall(a, "All Set Song", math.floor(saved.value or 0))
        U.tcall(a, "All Play Time", (saved.te or 0.0) + 0.0)
    else
        U.tcall(a, "All Remove Song")
    end
    U.tcall(a, "All Update Volume", math.floor(saved.volume or 4))
end

-- The radios playing now (host's "Is Playing").
function W.radios_playing()
    local out = {}
    for _, r in ipairs(W.radios()) do
        if U.get(r.actor, "Is Playing", false) == true then out[#out + 1] = r.actor end
    end
    return out
end

-- ---------------------------------------------------------------- camera screens [A]
-- The screens of the camera room draw only while the local player controller's "RealtimeCamera"
-- is on (CameraScreen "Capture Tick" 0x003a): off on this machine, then back to the player's
-- own saved choice.
function W.cameras(on)
    local pc = G.local_pc()
    if not pc then return end
    if on then
        local saved = U.get(pc, "Save Settings", nil)
        U.set(pc, "RealtimeCamera", U.get(saved, "RealtimeCamera", true) ~= false)
    else
        U.set(pc, "RealtimeCamera", false)
    end
end

-- ---------------------------------------------------------------- the clock [H]
-- GM "Game Time": the seconds left, an integer on the host only. The game takes one off every
-- second and sends it to every player ("Set Timer", shown as it is).
local clock = { holds = 0, value = nil }

function W.clock()
    local gm = G.gm()
    return gm and (U.get(gm, "Game Time", 0) or 0) or 0
end

local function set_clock(v)
    local gm = G.gm()
    if gm then U.set(gm, "Game Time", math.floor(v)) end
end

-- Adds secs (taken off when negative: never below floor, 30 by default, and never up). Returns
-- what was really added. Shown everywhere within a second.
function W.add_time(secs, floor)
    local t = W.clock()
    local new
    if secs >= 0 then
        new = t + secs
    else
        new = math.min(t, math.max(floor or 30, t + secs))
    end
    new = math.floor(new)
    if new == t then return 0 end
    set_clock(new)
    if clock.value then clock.value = clock.value + (new - t) end
    return new - t
end

-- Holds the clock where it is (written back ten times a second, W.tick_clock): the game's own
-- second then shows one less, and stays there. Refused under 2 s (the game would end on it).
-- True when held. Every hold is let go with W.release_clock.
function W.freeze_clock()
    if clock.holds == 0 then
        local t = W.clock()
        if t < 2 then return false end
        clock.value = t
    end
    clock.holds = clock.holds + 1
    return true
end

function W.release_clock()
    if clock.holds <= 0 then return end
    clock.holds = clock.holds - 1
    if clock.holds == 0 then clock.value = nil end
end

function W.tick_clock()
    if clock.holds > 0 and clock.value then set_clock(clock.value) end
end

-- A new game: no hold kept from the one before.
function W.release_all()
    clock.holds, clock.value = 0, nil
    for _, h in pairs(locks.held) do
        if U.valid(h.slot) then lock(h.slot, h.saved) end
    end
    locks.held = {}
end

return W
