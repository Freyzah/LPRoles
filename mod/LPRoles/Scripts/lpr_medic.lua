-- LPRoles - the Médecin, on every machine: each machine tells the host its character's life
-- while a Médecin plays, the Médecin's machine writes everyone's life above their heads, and
-- the machine of a player healed gives the life back.
-- What it needs to know of the rest of the player's side comes through MD.setup.
local U = require("lpr_util")
local G = require("lpr_game")
local N = require("lpr_net")

local MD = {}

local vitals = nil           -- a Médecin plays: this machine tells the host its character's life: { last, at }
local tags = {}              -- player index -> { life, mec, comp, shown, visible, yaw }: the life written above a head
-- ghost(): the local ghost mode ({ kind, health, ... }) or nil; reserve(): a Vampire's life
-- above the game's maximum (0 otherwise); role(): the local role and the host's values about it.
local env = {
    ghost = function() return nil end,
    reserve = function() return 0 end,
    role = function() return nil, nil end,
}

-- ---------------------------------------------------------------- Médecin
-- Every machine: while the host asks for it, tells its character's life each time it changes
-- (and every few seconds, for a Médecin who came late). A Vampire's reserve counts.
local function on_vitals(on)
    if on == "1" then vitals = vitals or { at = 0 } else vitals = nil end
end

local function my_life()
    local mec = G.local_mec()
    if not mec then return nil end
    local ghost = env.ghost()
    if ghost then return ghost.health end              -- flying or dreaming: the life it had on leaving
    if U.get(mec, "Alive", true) ~= true then return 0 end
    local health = U.get(mec, "Health", nil)
    if type(health) ~= "number" then return nil end
    return math.max(0, health) + env.reserve()
end

local function tick_vitals(now)
    if not vitals then return end
    local life = my_life()
    if not life then return end
    local since = now - vitals.at
    if (life ~= vitals.last and since >= 0.25) or since >= 3 then
        vitals.last, vitals.at = life, now
        N.report(life)
    end
end

-- The Médecin's power, on the machine of the player healed: the whole life back, through the
-- game's own healing (the call its regeneration makes, for one point at a time).
local function on_heal()
    local mec = G.local_mec()
    if not mec then return end
    local ghost = env.ghost()
    if ghost then
        ghost.health = 100                             -- given back on landing or on waking up
        if ghost.kind == "dream" then U.set(mec, "Health", 100) end
    elseif U.get(mec, "Alive", true) == true then
        U.tcall(mec, "Hit Health", -100, 0.0, 1000.0)
    end
    if vitals then vitals.at = 0 end                   -- told to the host at once
end

-- The Médecin's machine: the life of each player, written above its head. A text standing in
-- the building like any object: a wall hides it. It is turned towards the Médecin at every
-- tick, and coloured by how much life is left.
local TAG = { class = "/Script/Engine.TextRenderComponent", height = 215.0, size = 30.0 }

local function tag_drop(rec)
    local c = rec.comp
    rec.comp, rec.shown, rec.visible, rec.yaw = nil, nil, nil, nil
    if not U.valid(c) then return end
    pcall(function() c:SetVisibility(false, false) end)        -- unseen even if it cannot be removed
    if U.valid(rec.mec) then U.try("vie affichée : retrait", function() c:K2_DestroyComponent(rec.mec) end) end
end

local function tags_clear()
    for _, rec in pairs(tags) do tag_drop(rec) end
    tags = {}
end

local function tag_make(mec)
    local cls = StaticFindObject(TAG.class)
    if not U.valid(cls) then return nil end
    local c = mec:AddComponentByClass(cls, false, { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
        Translation = { X = 0.0, Y = 0.0, Z = TAG.height }, Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }, false)
    if not U.valid(c) then return nil end
    U.try("vie affichée : aspect", function()
        c:SetCollisionEnabled(0)                       -- never in anybody's way
        pcall(function() c:SetCastShadow(false) end)
        c:SetHorizontalAlignment(1)                    -- centred on the head
        c:SetWorldSize(TAG.size)
    end)
    return c
end

local function tag_color(life)
    if life >= 70 then return { R = 60, G = 230, B = 90, A = 255 } end
    if life >= 30 then return { R = 255, G = 170, B = 30, A = 255 } end
    return { R = 255, G = 50, B = 40, A = 255 }
end

local function on_hp(idx, life)
    local i, n = tonumber(idx), tonumber(life)
    if not i or not n then return end
    tags[i] = tags[i] or {}
    tags[i].life = n
end

local tags_failed = false
local function tick_tags()
    local role, status = env.role()
    if role ~= "medic" or not status or (status.vitals or 0) == 0 then
        if next(tags) then tags_clear() end
        return
    end
    local me = G.local_mec()
    local eye = me and G.location(me)
    if not eye then return end
    for _, mec in ipairs(G.all_mecs()) do
        local rec = mec:GetAddress() ~= me:GetAddress() and tags[G.player_index(mec)] or nil
        if rec and rec.life then
            if rec.comp and (not U.valid(rec.comp) or not U.valid(rec.mec) or rec.mec:GetAddress() ~= mec:GetAddress()) then
                tag_drop(rec)                          -- another character for this player: made again
            end
            local shown = rec.life > 0 and G.is_alive(mec)
            if shown and not rec.comp and not tags_failed then
                rec.comp, rec.mec = U.try("vie affichée", tag_make, mec), mec
                if not rec.comp then
                    tags_failed = true                 -- said once, not at every tick
                    U.log("Médecin : la vie ne peut pas être écrite au-dessus des têtes")
                end
            end
            local c = rec.comp
            if c then
                if rec.visible ~= shown then
                    pcall(function() c:SetVisibility(shown, false) end)
                    rec.visible = shown
                end
                if shown then
                    if rec.shown ~= rec.life then
                        G.text_call(c, "K2_SetText", tostring(rec.life))
                        pcall(function() c:SetTextRenderColor(tag_color(rec.life)) end)
                        rec.shown = rec.life
                    end
                    local at = G.location(mec)
                    if at then
                        local yaw = math.deg(math.atan(eye.Y - at.Y, eye.X - at.X))
                        if not rec.yaw or math.abs(yaw - rec.yaw) > 0.5 then
                            pcall(function() c:K2_SetWorldRotation({ Pitch = 0.0, Yaw = yaw, Roll = 0.0 }, false, {}, false) end)
                            rec.yaw = yaw
                        end
                    end
                end
            end
        end
    end
end

function MD.setup(e)
    for k, fn in pairs(e) do env[k] = fn end
end

-- End of a game, or no character any more: nothing told, nothing written above heads.
function MD.reset()
    vitals = nil
    tags_clear()
    tags_failed = false
end

MD.on_vitals = on_vitals           -- host's "VITALS 1/0"
MD.on_hp = on_hp                   -- host's "HP idx life"
MD.on_heal = on_heal               -- host's "HEAL"
MD.tick_vitals = tick_vitals
MD.tick_tags = tick_tags

return MD
