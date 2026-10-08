-- LPRoles - everything that knows the game's own names (classes, functions, properties).
-- All names below were read from the game's Blueprints (see analysis/NOTES.md).
local U = require("lpr_util")

local G = {}

-- Blueprint classes
G.CLASS_MEC = "Mec_C"
G.CLASS_GM = "GM_C"
G.PATH_MEC = "/Game/Character/Mec.Mec_C"
G.PATH_GM = "/Game/Gameplay/GM.GM_C"

-- E_PlayerRole
G.ROLE_NONE, G.ROLE_NOT_READY, G.ROLE_READY = 0, 1, 2
G.ROLE_EMPLOYEE, G.ROLE_DISSIDENT, G.ROLE_DEAD = 3, 4, 5

-- E_EyeState
G.EYE_OPEN, G.EYE_LEFT, G.EYE_RIGHT, G.EYE_CLOSED, G.EYE_LOCK = 0, 1, 2, 3, 4

-- Enum_Stance
G.STANCE_STAND, G.STANCE_SIT = 0, 4

-- Struct field names (Blueprint user structs carry a generated suffix)
G.F_ALIVE = "Alive_1_FD4B56084F2C8B7E0C61E289ED8A12E8"
G.F_ALIVE_LOCATION = "Location_6_3846B1B5464EC1C009D1039EC345EE21"
G.F_ALIVE_ORIENTATION = "Orientation_9_CABC5B924EC7C54F522C87A43A8B161B"
G.F_ITEM_DATA = "Data_18_5511228644AD6F4D6D0589BD4438C32F"
G.F_ITEM_STATE = "State_19_AFBBFC834F820A0E18A707A477B6D3FE"
G.F_STATE_VALUE = "Value_8_5511228644AD6F4D6D0589BD4438C32F"
G.F_STATE_TIME = "Time_15_AFBBFC834F820A0E18A707A477B6D3FE"

-- Assets
G.ASSET_ACCESS_CARD = "/Game/Items/Melee/AccessCard/DA_AccessCard.DA_AccessCard"
G.ASSET_CONTAINER = "/Game/Items/Melee/SampleContainer/DA_Container.DA_Container"
G.ASSET_FISH = "/Game/Items/Melee/Fish/DA_Fish.DA_Fish"

-- Recharge items are numbered: the plants first (1 to PLANT_KINDS, the plant's own number in
-- the game), then the fish (the fish machine's number, after the plants). lpr_config.lua
-- (ITEMS) and lpr_strings.lua (ITEM_NAME, ITEM_SHORT) list them in that order.
G.PLANT_KINDS, G.FISH_KINDS = 5, 4
G.DIRTY_JAR = -1          -- content of a jar left dirty (the game's centrifuge leaves it so)

-- The banner on the HUD uses a very large font: about this many characters fit.
G.BANNER_WIDTH = 30

function G.fn_path(class_path, fname)
    return class_path .. ":" .. fname
end

function G.gm()
    local gm = FindFirstOf(G.CLASS_GM)
    if U.valid(gm) then return gm end
    return nil
end

-- The game mode only exists on the host (or in solo play).
function G.is_host()
    return G.gm() ~= nil
end

function G.in_game()
    local gm = G.gm()
    return gm ~= nil and U.get(gm, "In Game", false) == true
end

function G.all_mecs()
    local out = {}
    local list = FindAllOf(G.CLASS_MEC)
    if list then
        for _, m in ipairs(list) do
            if U.valid(m) then out[#out + 1] = m end
        end
    end
    return out
end

function G.role_of(mec)
    return U.get(mec, "Player Role", G.ROLE_NONE)
end

-- Players taking part in the current game (same rule as GM "Get Valid Players").
function G.valid_players()
    local out = {}
    for _, m in ipairs(G.all_mecs()) do
        if G.role_of(m) ~= G.ROLE_NONE then out[#out + 1] = m end
    end
    return out
end

function G.is_alive(mec)
    local st = U.get(mec, "Net Alive State", nil)
    if st == nil then return false end
    local ok, v = pcall(function() return st[G.F_ALIVE] end)
    return ok and v == true
end

-- Where and facing which way a player died (kept by the game in its replicated alive state).
function G.death_spot(mec)
    local st = U.get(mec, "Net Alive State", nil)
    if st == nil then return nil, 0.0 end
    local ok, loc, yaw = pcall(function()
        return U.vec_copy(st[G.F_ALIVE_LOCATION]), st[G.F_ALIVE_ORIENTATION]
    end)
    if not ok or not loc then return nil, 0.0 end
    return loc, (tonumber(yaw) or 0.0) + 0.0
end

function G.player_name(mec)
    local name = U.get(mec, "PlayerName", nil)
    if name == nil then return "?" end
    local ok, s = pcall(function() return name:ToString() end)
    if ok and type(s) == "string" and s ~= "" then return s end
    if type(name) == "string" and name ~= "" then return name end
    return "?"
end

function G.player_index(mec)
    return U.get(mec, "Player Index", -1)
end

function G.mec_by_index(idx)
    for _, m in ipairs(G.all_mecs()) do
        if G.player_index(m) == idx then return m end
    end
    return nil
end

-- Where the vents are (the vent filter task's vents).
function G.vent_spots()
    local out = {}
    local list = FindAllOf("Vent_C")
    if list then
        for _, v in ipairs(list) do
            local at = U.valid(v) and G.location(v) or nil
            if at then out[#out + 1] = at end
        end
    end
    return out
end

function G.location(mec)
    local ok, v = pcall(function() return mec:K2_GetActorLocation() end)
    if ok and v then return U.vec_copy(v) end
    return nil
end

function G.controller_of(mec)
    local pc = U.get(mec, "Controller", nil)
    if U.valid(pc) then return pc end
    return nil
end

-- Local player (the machine running this script). On the host there is one controller
-- per player, so the local one has to be picked explicitly.
local cached_pc = nil
function G.local_pc()
    if U.valid(cached_pc) then return cached_pc end
    cached_pc = nil
    local list = FindAllOf("PlayerController")
    if list then
        for _, pc in ipairs(list) do
            if U.valid(pc) then
                local ok, is_local = pcall(function() return pc:IsLocalPlayerController() end)
                if ok and is_local == true then
                    cached_pc = pc
                    return pc
                end
            end
        end
    end
    return nil
end

function G.local_mec()
    local pc = G.local_pc()
    if not pc then return nil end
    local pawn = U.get(pc, "Pawn", nil)
    if U.valid(pawn) then
        local ok, is = pcall(function() return pawn:IsA(G.PATH_MEC) end)
        if not ok or is then return pawn end
    end
    return nil
end

-- ---------------------------------------------------------------- items
-- Reads a Str_Item property: returns the item's asset name (or nil) and its state value.
local function read_item(mec, prop)
    local item = U.get(mec, prop, nil)
    if item == nil then return nil, 0 end
    local ok, name, value = pcall(function()
        local data = item[G.F_ITEM_DATA]
        if not U.valid(data) then return nil, 0 end
        return data:GetFullName(), item[G.F_ITEM_STATE][G.F_STATE_VALUE]
    end)
    if not ok then return nil, 0 end
    return name, value or 0
end

-- Hand item as seen by the host.
function G.hand_item(mec)
    return read_item(mec, "Net Hand ItemNew")
end

function G.bag_item(mec)
    return read_item(mec, "Net Bag ItemNew")
end

-- An item as a recharge item number: a sample container holding a plant, or a fish (salmon,
-- tuna, cod, shrimp: the fish machine's order); 0 for anything else.
-- name: full name of the item's data asset; value: its state value.
function G.item_number(name, value)
    if type(name) ~= "string" or type(value) ~= "number" then return 0 end
    if name:find(G.ASSET_CONTAINER, 1, true) then
        return (value >= 1 and value <= G.PLANT_KINDS) and math.floor(value) or 0
    end
    if name:find(G.ASSET_FISH, 1, true) then
        return (value >= 1 and value <= G.FISH_KINDS) and (G.PLANT_KINDS + math.floor(value)) or 0
    end
    return 0
end

-- Recharge item held in hand, as the host sees it (0 when none).
function G.held_item(mec)
    return G.item_number(G.hand_item(mec))
end

-- Host: the hand holds a jar left dirty.
function G.holds_dirty_jar(mec)
    local name, value = G.hand_item(mec)
    return name ~= nil and name:find(G.ASSET_CONTAINER, 1, true) ~= nil and value == G.DIRTY_JAR
end

function G.item_state(value)
    return { [G.F_STATE_VALUE] = value or 0, [G.F_STATE_TIME] = 0 }
end

-- An asset already in memory, else loaded (only from the game's own thread: a hook or a
-- message from the host). Whatever the loading call returns, the asset is looked up again.
local function find_asset(asset_path)
    local data = StaticFindObject(asset_path)
    if not U.valid(data) then
        pcall(LoadAsset, asset_path)
        data = StaticFindObject(asset_path)
    end
    if U.valid(data) then return data end
    U.log("Objet introuvable : %s", asset_path)
    return nil
end
G.asset = find_asset

-- Host: puts an item in a player's hand (same two calls the game makes on pickup).
local function give_in_hand(mec, data)
    U.tcall(mec, "Net Take Item", data, G.item_state(0), U.vec())
    U.tcall(mec, "Take Item", data, G.item_state(0), U.vec())
end

-- Host: gives an item discreetly, in the bag slot when it is free. The host must know the
-- bag content, because it checks it when the player later takes the item out.
-- Returns "bag", "hand", "busy" (the player is swapping items: try again shortly) or nil.
-- Only the direct bag write is silent; the fallbacks play the pick-up animation for the others.
function G.give_item_quietly(mec, asset_path)
    local data = find_asset(asset_path)
    if not data then return nil end
    if U.get(mec, "Net Item Switching", false) == true then return "busy" end
    local short = asset_path:match("([^./]+)$")
    local item = { [G.F_ITEM_DATA] = data, [G.F_ITEM_STATE] = G.item_state(0) }
    local function in_bag()
        local name = G.bag_item(mec)
        return name ~= nil and short ~= nil and name:find(short, 1, true) ~= nil
    end
    if G.bag_item(mec) == nil then
        -- 1) write the host's record of the bag directly: nothing visible happens
        pcall(function() mec["Net Bag ItemNew"] = item end)
        if in_bag() then
            U.tcall(mec, "Set Bag Item", item)
            return "bag"
        end
        -- 2) the game's own way: take in hand, then swap hand and (empty) bag
        if G.hand_item(mec) == nil then
            U.tcall(mec, "Net Take Item", data, G.item_state(0), U.vec())
            U.tcall(mec, "Net Switch Item", { [G.F_ITEM_STATE] = G.item_state(0) })
            if in_bag() then
                U.tcall(mec, "Set Bag Item", item)
                return "bag"
            end
            U.tcall(mec, "Take Item", data, G.item_state(0), U.vec())
            return "hand"
        end
        return nil
    end
    if G.hand_item(mec) == nil then
        give_in_hand(mec, data)
        return "hand"
    end
    return nil
end

-- ---------------------------------------------------------------- items lying in the building
-- An item on the ground or on a piece of furniture is a WorldItem_C actor; its "Data" says
-- what it is. The actor is destroyed when somebody picks the item up.
function G.world_items(asset_path)
    local out = {}
    local data = find_asset(asset_path)
    local list = data and FindAllOf("WorldItem_C") or nil
    if list then
        local want = data:GetAddress()
        for _, w in ipairs(list) do
            if U.valid(w) then
                local d = U.get(w, "Data", nil)
                if U.valid(d) and d:GetAddress() == want then out[#out + 1] = w end
            end
        end
    end
    return out
end

-- Host: puts one more item down, at one of the game's own item places still free (the call
-- the game's task manager makes for the cards and the weapons it spreads at the start).
-- Returns the new item, or nil.
function G.place_item(asset_path)
    local data = find_asset(asset_path)
    local spots = data and FindAllOf("Item_Spawner_C") or nil
    if not spots then return nil end
    local free = {}
    for _, s in ipairs(spots) do
        if U.valid(s) and U.get(s, "Used", true) == false then free[#free + 1] = s end
    end
    if #free == 0 then return nil end
    local before = {}
    for _, w in ipairs(G.world_items(asset_path)) do before[w:GetAddress()] = true end
    U.tcall(free[math.random(#free)], "Spawn Item", { [G.F_ITEM_DATA] = data, [G.F_ITEM_STATE] = G.item_state(0) })
    for _, w in ipairs(G.world_items(asset_path)) do
        if not before[w:GetAddress()] then return w end
    end
    return nil
end

-- ---------------------------------------------------------------- text and HUD banner
-- Engine texts. This UE4SS build crashes the game whenever a text (a function parameter or a
-- variable) receives anything other than a genuine engine text object, a plain Lua string
-- included. So texts are made by the engine itself (Conv_StringToText, which takes a plain
-- string), checked, and only then handed to the game; never written into a variable.
local text_lib, text_warned = nil, false

function G.is_text(v)
    if type(v) ~= "userdata" then return false end
    local ok, kind = pcall(function() return v:type() end)
    return ok and kind == "FText"
end

function G.text(s)
    text_lib = (U.valid(text_lib) and text_lib) or StaticFindObject("/Script/Engine.Default__KismetTextLibrary")
    if not U.valid(text_lib) then return nil end
    local ok, t = pcall(function() return text_lib:Conv_StringToText(tostring(s or "")) end)
    if ok and G.is_text(t) then return t end
    if not text_warned then
        text_warned = true
        U.log("Texte moteur indisponible (%s) : les libellés du menu resteront vides", ok and type(t) or tostring(t))
    end
    return nil
end

-- Calls obj:fname(text, ...) with an engine text made from the Lua string `s`. Every call to a
-- game function taking a text goes through here (tools/lp/verify_mod.py checks it).
function G.text_call(obj, fname, s, ...)
    if not U.valid(obj) then return false end
    local t = G.text(s)
    if t == nil then return false end
    local ok, err = pcall(U.call, obj, fname, t, ...)
    if not ok then U.log("ERREUR dans %s : %s", fname, tostring(err)) end
    return ok
end
local function banner(text, rgb)
    local mec = G.local_mec()
    local hud = mec and U.get(mec, "HUD", nil)
    local widget = U.valid(hud) and U.get(hud, "W_MainNotif", nil) or nil
    if not U.valid(widget) and U.valid(hud) then widget = U.get(hud, "W_UpperNotif", nil) end
    if not U.valid(widget) then
        U.log("(écran) %s", text)
        return
    end
    local c = rgb or { 0.1, 0.45, 0.8 }
    U.tcall(widget, "Show Message", text, { R = c[1], G = c[2], B = c[3], A = 1.0 })
end

-- The banner shows one short line at a time: texts are cut into lines and spaced out.
local queue, next_show = {}, 0
local SPACING = 2.6

function G.say(text, rgb)
    for _, line in ipairs(U.wrap(text, G.BANNER_WIDTH)) do
        queue[#queue + 1] = { text = line, rgb = rgb }
    end
    U.dbg("notif : %s", text)
end

-- Replaces whatever is waiting (used by the settings keys, where only the latest value matters).
function G.say_now(text, rgb)
    queue = {}
    next_show = 0
    G.say(text, rgb)
end

-- Drops what is still waiting (messages of a game that is over).
function G.clear_messages()
    queue = {}
end

function G.pump_messages(now)
    if #queue == 0 or now < next_show then return end
    local m = table.remove(queue, 1)
    next_show = now + SPACING
    banner(m.text, m.rgb)
end

-- ---------------------------------------------------------------- appearance (Métamorphe)
-- A character's look is one replicated value, "Appearance": a colour and a set of 17 parts
-- (models, materials, face, eyes, hair, patches, charm, light, skin tint). Every machine
-- draws it again when it changes. (The older "Skin Set" value is no longer what is drawn.)
G.F_LOOK_COLOR = "Color_2_BC286D734CE5B66D24EAAD8FC0A2F932"
G.F_LOOK_CUSTOM = "Custom_5_D7B1DF8B4ADBED24778DC6B5C3BC0F6A"
G.LOOK_PARTS = {
    "BodyModel_5_270C01124EB6741F9D56EC96E7646281", "BodyMaterial1_11_9E37A9534980030E97045B8AD7B87AE0",
    "BodyMaterial2_12_0F84899343D64242E1BFC7B7CEA80159", "BodyMaterial3_14_A9070D884EA2AFC896C02687BD0998CE",
    "BodyMaterialDetails_16_4D0675D04FC7CA49F259079D9E6BCF98", "MetalMeterial_19_F21CD69D46F00F393D13D8A33DF0899B",
    "HeadModel_22_DB057AD947AD09EDFB635C9EB5E12B13", "HoodMaterial_25_474CAA67420BE547A7AD6CA3A1D5243D",
    "MaskMaterial_28_C4BB6D7E46F685674E1AF78C255BC5C0", "Face_31_F348297E4D89FC1AD30AF9BE3C8EBCB7",
    "EyesColor_35_EDE8E47C40F7748B93FEBA873B43D7A3", "HairColor_38_9B88AF7244450E817D1829A3B23BCD49",
    "PatchRound_43_75D7B6D845B2A8E8703977A3535C1DDE", "PatchSquare_45_D9F5EB2B432C29E84983C789BD9E1F66",
    "Charm_48_4703AC154EE2F9E306B89D9EB1ABC57E", "Light_54_4EC705D24905F23A7BB856BAD8E52747",
    "SkinColor_57_381F1FB74CBAD28A249806B64D01E5E4",
}

-- The one part that is not an object: the skin tint, a pair of numbers (the game's structure
-- "Str_SkinCustom_Result": sixteen data objects and this "Vector2D").
G.LOOK_TINT = "SkinColor_57_381F1FB74CBAD28A249806B64D01E5E4"

-- Plain Lua copy of one part. The tint is copied as two numbers: kept as the value UE4SS
-- hands out, it crashed the game when written back (D56) - and that value answers "IsValid"
-- like an object, so the kind of each part is told from its name, never guessed. An object
-- (model, material) is kept with its full name, so that it can be found again if the handle
-- kept is no longer valid when the look is put back (D53). An empty part stays as is.
local function copy_part(field, v)
    if field == G.LOOK_TINT then
        return { X = v.X + 0.0, Y = v.Y + 0.0 }
    end
    if type(v) ~= "userdata" or not U.valid(v) then return v end           -- none
    local full = v:GetFullName()
    return { obj = v, full = full, path = full:match("^%S+%s+(.+)$") }
end

-- The value to write back for one part: the object kept if it is still the same one, else the
-- same asset found again by name; an error if it cannot be found (the look is then left alone).
local function part_value(p)
    if type(p) ~= "table" or p.obj == nil then return p end
    local okv, same = pcall(function() return U.valid(p.obj) and p.obj:GetFullName() == p.full end)
    if okv and same then return p.obj end
    local found = p.path and StaticFindObject(p.path) or nil
    if U.valid(found) then return found end
    error("pièce d'apparence introuvable : " .. tostring(p.path))
end

-- A copy made of plain Lua values: what the game hands out is a view on live memory, which
-- would change along with the character. Returns { color, custom }.
function G.copy_look(look)
    if look == nil then return nil end
    local ok, out = pcall(function()
        local custom = {}
        local src = look[G.F_LOOK_CUSTOM]
        for _, f in ipairs(G.LOOK_PARTS) do custom[f] = copy_part(f, src[f]) end
        return { color = look[G.F_LOOK_COLOR], custom = custom }
    end)
    if ok then return out end
    U.log("Apparence illisible : %s", tostring(out))
    return nil
end

function G.copy_skin(mec)
    return G.copy_look(U.get(mec, "Appearance", nil))
end

-- The look as the game's structure (raises an error if a part cannot be found again).
function G.look_value(look)
    local custom = {}
    for f, p in pairs(look.custom or {}) do custom[f] = part_value(p) end
    return { [G.F_LOOK_COLOR] = look.color or 0, [G.F_LOOK_CUSTOM] = custom }
end

-- Host: gives a character an appearance. The game replicates it to everybody, players
-- without the mod included. Same steps as the game's own "Net Set Appearance", minus its
-- colour rule (it would give the copy a free colour instead of the exact one).
local push_helpers = nil
function G.apply_skin(mec, look)
    if not U.valid(mec) or not look then return end
    push_helpers = (U.valid(push_helpers) and push_helpers) or StaticFindObject("/Script/Engine.Default__NetPushModelHelpers")
    local ok, value = pcall(G.look_value, look)
    if not ok then
        U.log("Apparence non appliquée : %s", tostring(value))
        return
    end
    pcall(function() mec:FlushNetDormancy() end)
    if not U.set(mec, "Appearance", value) then return end
    if U.valid(push_helpers) then
        pcall(function() push_helpers:MarkPropertyDirty(mec, FName("Appearance")) end)
    end
    U.tcall(mec, "OnRep_Appearance")
end

-- ---------------------------------------------------------------- object arrays
-- The Lua API has no "add" or "remove" for arrays; these work with what exists.
function G.array_remove(owner, prop, obj)
    local arr = U.get(owner, prop, nil)
    if arr == nil then return false end
    return U.try("array_remove " .. prop, function()
        local n = #arr
        local at, other = nil, nil
        for i = 1, n do
            local e = arr[i]
            if U.valid(e) and e:GetAddress() == obj:GetAddress() then at = i else other = other or i end
        end
        if not at then return true end
        if other then
            arr[at] = arr[other]      -- duplicate another entry: harmless for the game's checks
        else
            arr:Empty()
        end
        return true
    end) == true
end

local function array_has(arr, obj)
    for i = 1, #arr do
        local e = arr[i]
        if U.valid(e) and e:GetAddress() == obj:GetAddress() then return true end
    end
    return false
end

function G.array_add(owner, prop, obj)
    local arr = U.get(owner, prop, nil)
    if arr == nil then return false end
    local ok, done = pcall(function()
        if array_has(arr, obj) then return true end
        arr[#arr + 1] = obj
        return array_has(owner[prop], obj)
    end)
    if ok and done then return true end
    -- Fallback: rebuild the whole array from a Lua table.
    return U.try("array_add " .. prop, function()
        local items = {}
        local cur = owner[prop]
        for i = 1, #cur do
            if U.valid(cur[i]) then items[#items + 1] = cur[i] end
        end
        items[#items + 1] = obj
        owner[prop] = items
        return array_has(owner[prop], obj)
    end) == true
end

-- Takes several objects out of an object array at once: each of their entries (an object may
-- be there more than once) is overwritten with an entry that stays, as in array_remove; the
-- array is emptied when nothing stays.
function G.array_drop(owner, prop, objs)
    local arr = U.get(owner, prop, nil)
    if arr == nil then return false end
    return U.try("array_drop " .. prop, function()
        local out = {}
        for _, o in ipairs(objs) do
            if U.valid(o) then out[o:GetAddress()] = true end
        end
        local keep = nil
        for i = 1, #arr do
            local e = arr[i]
            if not keep and U.valid(e) and not out[e:GetAddress()] then keep = i end
        end
        if not keep then
            arr:Empty()
            return true
        end
        for i = 1, #arr do
            local e = arr[i]
            if U.valid(e) and out[e:GetAddress()] then arr[i] = arr[keep] end
        end
        return true
    end) == true
end

return G
