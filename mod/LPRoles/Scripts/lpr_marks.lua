-- LPRoles - what the mod draws in the building for one player: the Traqueur's silhouette
-- seen through walls, the Shérif's green sphere over the safe person and the access card
-- shown to the Shérif, and the random events' marks and lights (lpr_ev.lua). Each is drawn on
-- that player's machine only.
local U = require("lpr_util")
local G = require("lpr_game")

local K = {}

-- ---------------------------------------------------------------- Traqueur: seen through walls
-- The game has nothing that shows through walls, but the engine ships a material drawn over
-- everything (the one its editor uses for control handles). Three stretched balls with that
-- material are attached to the tracked player, on the tracker's machine only: legs, chest and
-- head. They follow the player and are removed when the tracking ends.
-- Heights above the character's position, which is at its feet.
local XRAY_PARTS = {
    { z = 42.0,  scale = { X = 0.26, Y = 0.34, Z = 0.84 } },      -- legs
    { z = 112.0, scale = { X = 0.30, Y = 0.46, Z = 0.62 } },      -- chest (wider across the shoulders)
    { z = 158.0, scale = { X = 0.27, Y = 0.27, Z = 0.29 } },      -- head
}
local tracked = nil          -- { mec, parts = { components } }

local function track_off()
    local t = tracked
    tracked = nil
    if not t then return end
    for _, c in ipairs(t.parts) do
        if U.valid(c) and U.valid(t.mec) then
            U.try("fin de traque", function() c:K2_DestroyComponent(t.mec) end)
        end
    end
end

local function on_track(idx, tenths)
    track_off()
    idx = tonumber(idx) or -1
    local secs = (tonumber(tenths) or 0) / 10
    if idx < 0 or secs <= 0 then return end
    local mec = G.mec_by_index(idx)
    local cls = StaticFindObject("/Script/Engine.StaticMeshComponent")
    local ball, mat = G.asset(G.BALL_MESH), G.asset(G.XRAY_MATERIAL)
    if not mec or not U.valid(cls) or not ball or not mat then
        U.log("Traqueur : silhouette impossible (%s)", (not mat) and "matériau introuvable" or "élément introuvable")
        return
    end
    local rec = { mec = mec, parts = {} }
    tracked = rec
    -- the part of the character that turns with the player (its position never turns)
    local turning = U.get(mec, "Orientation", nil)
    for _, part in ipairs(XRAY_PARTS) do
        U.try("silhouette", function()
            -- put where the player stands, then tied to the turning part: place kept, direction
            -- taken from it (wherever that part itself sits inside the character)
            local at = U.valid(turning) and G.location(mec) or nil
            local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                        Translation = at and { X = at.X, Y = at.Y, Z = at.Z + part.z } or { X = 0.0, Y = 0.0, Z = part.z },
                        Scale3D = part.scale }
            local c = mec:AddComponentByClass(cls, at ~= nil, t, false)
            if not U.valid(c) then return end
            rec.parts[#rec.parts + 1] = c         -- noted first: always removed with the others
            c:SetCollisionEnabled(0)              -- before it has a shape: never in anybody's way
            if at then
                pcall(function() c:SetMobility(2) end)
                local ok, attached = pcall(function()
                    return c:K2_AttachToComponent(turning, FName("None"), 1, 2, 1, false)
                end)
                if not ok or attached == false then
                    rec.parts[#rec.parts] = nil
                    c:K2_DestroyComponent(mec)    -- never a still shape left where the target stood
                    return
                end
            end
            pcall(function() c:SetCastShadow(false) end)
            c:SetStaticMesh(ball)
            local mid = c:CreateDynamicMaterialInstance(0, mat, FName("None"))
            if U.valid(mid) then
                mid:SetVectorParameterValue(FName("Color"), { R = 1.0, G = 0.25, B = 0.1, A = 1.0 })
                mid:SetScalarParameterValue(FName("Opacity"), 0.45)
            else
                c:SetMaterial(0, mat)
            end
        end)
    end
    U.after(secs + 0.5, "fin de traque", function()
        if tracked == rec then track_off() end
    end)
    U.log("Traqueur : silhouette posée sur %s (%d éléments)", G.player_name(mec), #rec.parts)
end

-- ---------------------------------------------------------------- Shérif: a green sphere
-- The safe person is marked with the game's own sphere, red like the one dissidents see over
-- each other. On the Shérif's machine it gets a green copy of its material for as long as the
-- marker lasts, then its own material back.
local safe_orb = nil         -- { orb, original }

local function orb_restore()
    local rec = safe_orb
    safe_orb = nil
    if rec and U.valid(rec.orb) and U.valid(rec.original) then
        U.try("sphère", function() rec.orb:SetMaterial(0, rec.original) end)
    end
end

local function orb_green(mec, secs)
    orb_restore()
    local orb = U.get(mec, "HackerSphere", nil)
    if not U.valid(orb) then return end
    U.try("sphère verte", function()
        local original = orb:GetMaterial(0)
        if not U.valid(original) then return end
        local mid = orb:CreateDynamicMaterialInstance(0, original, FName("None"))
        if not U.valid(mid) then return end
        local rec = { orb = orb, original = original }
        safe_orb = rec
        U.after(secs + 1, "sphère verte", function()
            if safe_orb == rec then orb_restore() end
        end)
        for _, name in ipairs({ "Color", "eColor" }) do
            local param = FName(name)
            local v = mid:K2_GetVectorParameterValue(param)
            local strength = math.max(v.R + 0.0, v.G + 0.0, v.B + 0.0)
            if strength > 0.001 then
                mid:SetVectorParameterValue(param, { R = 0.08 * strength, G = strength, B = 0.2 * strength, A = v.A + 0.0 })
            end
        end
    end)
end

-- ---------------------------------------------------------------- marks seen from afar
-- A ball and/or a column, drawn on this machine only, in one of a few colours: the Shérif's
-- access card (slot "card"), and the random events' marks (slots "e1" to "e4", lpr_ev.lua). With
-- the engine's material drawn over everything (the Traqueur's silhouette is made of it) when
-- they are to be seen through the walls, else with the glowing material of the game's spheres.
-- The shapes belong to this player's character but are tied to nothing, so they stay where they
-- are put. A mark on an item lying in the building follows it: the item (a WorldItem_C of that
-- data, near the spot given) is looked for, and the shapes are put back on it a few times a
-- second (never tied to it: an item rolls, and a column tied to it would lie down); while it
-- cannot be seen (picked up), the shapes are hidden until the host says more.
-- Never red: it is the dissidents' colour.
K.COLORS = {
    yellow = { 1.0, 0.78, 0.08 }, cyan = { 0.1, 0.85, 1.0 }, green = { 0.15, 1.0, 0.3 }, white = { 1.0, 1.0, 1.0 },
    violet = { 0.6, 0.2, 1.0 }, orange = { 1.0, 0.45, 0.05 }, blue = { 0.15, 0.35, 1.0 },
}
local SHAPE_PARTS = {
    ball = { { z = 0.0,   scale = { X = 0.40, Y = 0.40, Z = 0.40 } } },      -- around the spot
    col  = { { z = 160.0, scale = { X = 0.12, Y = 0.12, Z = 3.0 } } },       -- a column above it, to be found from afar
}
SHAPE_PARTS.both = { SHAPE_PARTS.ball[1], SHAPE_PARTS.col[1] }
local FOLLOW_STEP, FIND_STEP, FIND_RADIUS = 0.25, 0.5, 150
local marks = {}             -- slot -> { mec, parts = { { c, z } }, follow = { name, at, actor, found_at, moved_at } }

local function parts_off(rec)
    for _, p in ipairs(rec.parts) do
        local c = p.c
        if U.valid(c) and U.valid(rec.mec) then
            pcall(function() c:SetVisibility(false, false) end)   -- unseen even if it cannot be removed
            U.try("marque : retrait", function() c:K2_DestroyComponent(rec.mec) end)
        end
    end
end

local function mark_off(slot)
    local rec = marks[slot]
    marks[slot] = nil
    if rec then parts_off(rec) end
end

-- slot: "card", "e1".."e4"; color: a name of K.COLORS; walls: seen through the walls; shape:
-- "ball", "col" or "both"; follow: the short name of an item's data (its WorldItem_C near the
-- spot is followed), or nil. Returns how many shapes were drawn.
local function mark(slot, on, x, y, z, color, walls, shape, follow)
    mark_off(slot)
    if not on then return 0 end
    local mec = G.local_mec()
    local cls = StaticFindObject("/Script/Engine.StaticMeshComponent")
    local ball, mat = G.asset(G.BALL_MESH), G.asset(walls and G.XRAY_MATERIAL or G.ORB_MATERIAL)
    if not mec or not U.valid(cls) or not ball or not mat then
        U.log("Marque %s impossible (%s)", tostring(slot), (not mat) and "matériau introuvable" or "élément introuvable")
        return 0
    end
    local rgb = K.COLORS[color] or K.COLORS.white
    local at = { X = (tonumber(x) or 0) + 0.0, Y = (tonumber(y) or 0) + 0.0, Z = (tonumber(z) or 0) + 0.0 }
    local rec = { mec = mec, parts = {}, visible = true }
    marks[slot] = rec
    if follow then rec.follow = { name = follow, at = at, found_at = -10, moved_at = -10 } end
    for _, part in ipairs(SHAPE_PARTS[shape] or SHAPE_PARTS.both) do
        local c = nil
        local dressed = U.try("marque", function()
            local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 },
                        Translation = { X = at.X, Y = at.Y, Z = at.Z + part.z },
                        Scale3D = part.scale }
            -- "true": tied to nothing, so placed in the building and left there
            c = mec:AddComponentByClass(cls, true, t, false)
            if not U.valid(c) then return false end
            c:SetCollisionEnabled(0)              -- before it has a shape: never in anybody's way
            pcall(function() c:SetCastShadow(false) end)
            pcall(function() c:SetMobility(2) end)                    -- it may be moved (an item followed)
            if c:SetStaticMesh(ball) == false then error("forme refusée") end
            local mid = c:CreateDynamicMaterialInstance(0, mat, FName("None"))
            if not U.valid(mid) then error("matière non modifiable") end
            if walls then
                mid:SetVectorParameterValue(FName("Color"), { R = rgb[1], G = rgb[2], B = rgb[3], A = 1.0 })
                mid:SetScalarParameterValue(FName("Opacity"), 0.55)
            else
                -- the material's own brightness is kept, only the hue changes
                for _, name in ipairs({ "Color", "eColor" }) do
                    local param = FName(name)
                    local v = mid:K2_GetVectorParameterValue(param)
                    local strength = math.max(v.R + 0.0, v.G + 0.0, v.B + 0.0)
                    if strength > 0.001 then
                        mid:SetVectorParameterValue(param, { R = rgb[1] * strength, G = rgb[2] * strength,
                                                             B = rgb[3] * strength, A = v.A + 0.0 })
                    end
                end
            end
            return true
        end)
        if dressed then
            rec.parts[#rec.parts + 1] = { c = c, z = part.z }
        elseif U.valid(c) then
            -- no shape rather than one in the material's own colour (red: the dissidents')
            pcall(function() c:SetVisibility(false, false) end)
            U.try("marque : retrait", function() c:K2_DestroyComponent(mec) end)
        end
    end
    return #rec.parts
end

-- The item a mark follows: a WorldItem_C whose data has that name, the nearest to `at` within
-- FIND_RADIUS cm.
local function find_item(name, at)
    local best, best_d = nil, FIND_RADIUS
    for _, w in ipairs(FindAllOf("WorldItem_C") or {}) do
        local d = U.valid(w) and U.get(w, "Data", nil) or nil
        local ok, n = pcall(function() return d:GetFName():ToString() end)
        if ok and n == name then
            local p = G.location(w)
            local dist = p and U.dist(p, at) or math.huge
            if dist <= best_d then best, best_d = w, dist end
        end
    end
    return best
end

local function show_parts(rec, visible)
    if rec.visible == visible then return end
    rec.visible = visible
    for _, p in ipairs(rec.parts) do
        local c = p.c
        if U.valid(c) then pcall(function() c:SetVisibility(visible, false) end) end
    end
end

-- Ten times a second (lpr_ev.lua): the marks that follow an item are put back on it.
local function follow_tick(now)
    for _, rec in pairs(marks) do
        local f = rec.follow
        if f and now - f.moved_at >= FOLLOW_STEP then
            f.moved_at = now
            if not U.valid(f.actor) then
                if f.actor ~= nil then
                    f.actor = nil
                    show_parts(rec, false)        -- picked up: out of sight until the host says more
                elseif now - f.found_at >= FIND_STEP then
                    f.found_at = now
                    f.actor = find_item(f.name, f.at)
                end
            end
            local p = U.valid(f.actor) and G.location(f.actor) or nil
            if p then
                f.at = p
                show_parts(rec, true)
                for _, part in ipairs(rec.parts) do
                    local c = part.c
                    if U.valid(c) then
                        pcall(function() c:K2_SetWorldLocation({ X = p.X, Y = p.Y, Z = p.Z + part.z }, false, {}, false) end)
                    end
                end
            end
        end
    end
end

-- The Shérif's access card: the host says where one access card lies ("CARD on x y z walls"),
-- and the Shérif's machine draws a yellow ball and column there; the host says when the card
-- has been picked up.
local function on_card(on, x, y, z, walls)
    local through = walls == "1"
    local n = mark("card", on == "1", x, y, z, "yellow", through, "both")
    if on == "1" then
        U.log("Shérif : carte d'accès en surbrillance (%d éléments, %s)", n,
            through and "vue à travers les murs" or "sans traverser les murs")
    end
end

local function card_off()
    mark_off("card")
end

-- ---------------------------------------------------------------- lights (random events)
-- A light on a player's character (what the Fée's light is made of: lpr_client.lua), or at a
-- spot, on this machine only. Intensity on the engine's scale: the Fée's light is 8000 for a
-- reach of 350 cm; a value under 50 is taken in thousands (8 is 8000).
local lights = {}            -- slot -> { owner, comp, base }

local function light_off(slot)
    local rec = lights[slot]
    lights[slot] = nil
    if rec and U.valid(rec.comp) and U.valid(rec.owner) then
        local c = rec.comp
        U.try("lumière : retrait", function() c:K2_DestroyComponent(rec.owner) end)
    end
end

local function make_light(slot, owner, loose, translation, color, radius, intensity)
    light_off(slot)
    local cls = StaticFindObject("/Script/Engine.PointLightComponent")
    if not (U.valid(owner) and U.valid(cls)) then return nil end
    local level = tonumber(intensity) or 5000
    if level < 50 then level = level * 1000 end
    local rgb = K.COLORS[color] or K.COLORS.white
    local light = nil
    U.try("lumière", function()
        local t = { Rotation = { X = 0.0, Y = 0.0, Z = 0.0, W = 1.0 }, Translation = translation,
                    Scale3D = { X = 1.0, Y = 1.0, Z = 1.0 } }
        light = owner:AddComponentByClass(cls, loose, t, false)
        if not U.valid(light) then return end
        pcall(function() light:SetMobility(2) end)
        pcall(function() light:SetAttenuationRadius((tonumber(radius) or 350) + 0.0) end)
        pcall(function() light:SetIntensity(level + 0.0) end)
        pcall(function() light:SetLightColor({ R = rgb[1], G = rgb[2], B = rgb[3], A = 1.0 }, true) end)
    end)
    if not U.valid(light) then return nil end
    lights[slot] = { owner = owner, comp = light, base = level }
    return light
end

-- On a character (it follows it), 60 cm above its feet.
local function light_on(slot, mec, color, radius, intensity)
    return make_light(slot, mec, false, { X = 0.0, Y = 0.0, Z = 60.0 }, color, radius, intensity) ~= nil
end

-- At a spot of the building (it stays there; it belongs to the local character).
local function light_at(slot, x, y, z, color, radius, intensity)
    local mec = G.local_mec()
    if not mec then return false end
    return make_light(slot, mec, true, { X = (tonumber(x) or 0) + 0.0, Y = (tonumber(y) or 0) + 0.0,
                                         Z = (tonumber(z) or 0) + 0.0 }, color, radius, intensity) ~= nil
end

-- A light's strength, as a share of the one it was made with (a pulse: 0 to 1).
local function light_level(slot, share)
    local rec = lights[slot]
    if not rec or not U.valid(rec.comp) then return end
    local c = rec.comp
    pcall(function() c:SetIntensity(rec.base * share + 0.0) end)
end

-- Every mark of the random events and every light: off (the Shérif's card stays).
local function events_off()
    for slot in pairs(marks) do
        if slot ~= "card" then mark_off(slot) end
    end
    for slot in pairs(lights) do light_off(slot) end
end

K.track = on_track                 -- host's "TRACK idx tenths"
K.track_off = track_off
K.orb_green = orb_green            -- (mec, seconds)
K.orb_restore = orb_restore
K.card = on_card                   -- host's "CARD on x y z walls"
K.card_off = card_off
K.mark = mark                      -- (slot, on, x, y, z, color, walls, shape, follow): shapes drawn
K.mark_off = mark_off              -- (slot)
K.tick = follow_tick               -- (now)
K.light = light_on                 -- (slot, mec, color, radius, intensity): true when made
K.light_at = light_at              -- (slot, x, y, z, color, radius, intensity)
K.light_level = light_level        -- (slot, share 0..1)
K.light_off = light_off            -- (slot)
K.events_off = events_off

return K
