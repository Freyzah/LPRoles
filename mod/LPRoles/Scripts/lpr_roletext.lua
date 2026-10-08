-- LPRoles - the text describing the local player's role: its name, where it stands (uses
-- left, effect running, target) and how it works, with the values the host plays with.
-- Used by the LPROLES tab and by the tablet page.
local C = require("lpr_config")
local G = require("lpr_game")
local S = require("lpr_strings")

local RT = {}

-- Values the host sends in tenths of a second (the messages carry integers only).
RT.TENTHS = { hold = true, aim = true, dur = true, delay = true, marker = true,
              ihold = true, chold = true, act = true, wait = true, conv = true, range = true,
              reach = true }

-- "2.5" is written "2,5", "3.0" is written "3".
local function number(v)
    if v == math.floor(v) then return string.format("%d", v) end
    return (string.format("%.1f", v):gsub("%.", ","))
end

-- Players come as their index + 1 (0 means "nobody").
local function name_of(idx)
    local mec = G.mec_by_index((tonumber(idx) or 0) - 1)
    return mec and (tostring(G.player_name(mec)):gsub("%*", "")) or "?"
end

-- Replaces {name} with the value; players are given by index, recharge items by number;
-- {key} and {pkey} are this player's own keys ("consume" and power).
-- Values come out between *stars* (written in bold and colour on the tablet); an item's name
-- carries its own.
local function fill(template, v)
    return (template:gsub("{(%w+)}", function(k)
        local out
        if k == "item" then
            return S.ITEM_NAME[v[k]] or "?"
        elseif k == "pplant" then
            out = S.PLANT_CODE[v[k]] or "?"
        elseif k == "key" then
            out = C.format("use_key")
        elseif k == "pkey" then
            out = C.format("power_key")
        elseif v[k] == nil then
            out = "?"
        elseif k == "tgt" or k == "safe" or k == "link" or k == "exlink" then
            out = name_of(v[k])
        elseif type(v[k]) == "number" then
            out = number(v[k])
        else
            out = tostring(v[k])
        end
        return "*" .. out .. "*"
    end))
end

local function set(v, k)
    return v[k] ~= nil and v[k] ~= 0
end

-- A use can still be got back with the role's item (the host may limit the recharges).
local function can_recharge(v)
    return set(v, "item") and (v.rmax == nil or set(v, "rleft"))
end

local status_line   -- defined below

-- What the status line is about: "active" (an effect is running), "empty" (nothing left, or
-- something to do first) or "normal".
local function status_kind(role, v)
    if set(v, "act") or set(v, "conv") or set(v, "pleft") then return "active" end
    if role == "dreamer" or role == "fairy" then return set(v, "n") and "normal" or "empty" end
    if role == "angel" then return set(v, "tgt") and "normal" or "empty" end
    if role == "revenant" and not set(v, "dead") then return "normal" end
    if v.m and not set(v, "n") then return "empty" end
    return "normal"
end

-- A player who knows it is poisoned: the time left and the antidote, before anything else.
local function poison_line(v)
    if not set(v, "pleft") then return nil end
    return fill(S.STATUS.poisoned .. (set(v, "pplant") and S.STATUS.poisoned_cure or ""), v)
end

status_line = function(role, v)
    local st = S.STATUS
    local poisoned = poison_line(v)
    if poisoned then return poisoned end
    if role == "dreamer" or role == "fairy" then
        if set(v, "act") then return fill(role == "dreamer" and st.dream_on or st.fly_on, v) end
        if set(v, "n") then return st.charge_ready end
        return can_recharge(v) and st.charge_empty or st.charge_gone
    elseif role == "medium" then
        if set(v, "act") then return fill(st.vision_on .. st.uses_too, v) end
    elseif role == "angel" then
        if not set(v, "tgt") then return st.no_protege end
        return fill(set(v, "saved") and st.protege_saved or st.protege, v)
    elseif role == "tracker" then
        if set(v, "act") then return fill(st.track_on .. st.uses_too, v) end
    elseif role == "mimic" then
        if set(v, "act") then return fill(st.disguise_on .. st.uses_too, v) end
    elseif role == "stowaway" then
        if set(v, "act") then return fill(st.hide_on .. st.uses_too, v) end
    elseif role == "infector" then
        if set(v, "conv") then return fill(st.recruit_pending, v) end
        if set(v, "wait") then return fill(st.recruit_wait, v) end
        return fill(st.recruits, v)
    elseif role == "sheriff" then
        if set(v, "safe") then return fill(st.safe, v) end
        return set(v, "info") and st.no_safe or st.no_safe_info
    elseif role == "martyr" then
        return set(v, "reveal") and st.martyr_name or st.martyr_camp
    elseif role == "mole" then
        return st.mole
    elseif role == "revenant" then
        if set(v, "act") then return fill(st.spirit_on, v) end
        return fill(set(v, "dead") and st.spirit_left or st.spirit_later, v)
    elseif role == "poisoner" then
        if set(v, "act") then return fill(st.poison_on .. st.uses_too, v) end
    elseif role == "vampire" then
        return set(v, "bonus") and fill(st.vamp_on, v) or st.vamp_none
    elseif role == "werewolf" then
        return set(v, "pct") and fill(st.wolf_on, v) or st.wolf_none
    elseif role == "amnesiac" then
        return st.amnesiac
    elseif role == "jester" then
        return st.jester
    end
    if v.m then return fill(st.uses, v) end
    return nil
end

-- Lines describing the role: the status first, then how it works; and what kind of status
-- it is ("active", "empty", "normal"). Lines carry *star* marks (see RT.plain, RT.segments).
-- status: values received from the host (nil until the first message arrives).
function RT.lines(role, status, safe_idx)
    local out = {}
    local v = {}
    for k, x in pairs(status or {}) do v[k] = x end
    if not role then
        -- no role, but perhaps a poison to know of, or a bond (Liés), still to act or over
        local poisoned = poison_line(v)
        if poisoned then out[#out + 1] = poisoned end
        if set(v, "link") then out[#out + 1] = fill(S.LINK_LINE, v) end
        if set(v, "exlink") then out[#out + 1] = fill(S.LINK_OVER, v) end
        for _, l in ipairs(S.ROLE_HOWTO.none) do out[#out + 1] = l end
        return out, "normal"
    end
    -- Nothing from the host yet: no explanation either, its values would all be missing.
    if not status then return { S.STATUS.waiting }, "normal" end
    -- the index this machine kept from the announcement only serves with a host that says
    -- nothing about the safe person (an older version)
    if safe_idx and v.safe == nil and v.info == nil then v.safe = safe_idx + 1 end
    local st = status_line(role, v)
    local kind = status_kind(role, v)
    if st then out[#out + 1] = st end
    if set(v, "link") then out[#out + 1] = fill(S.LINK_LINE, v) end
    if set(v, "exlink") then out[#out + 1] = fill(S.LINK_OVER, v) end
    for _, l in ipairs(S.ROLE_HOWTO[role] or {}) do
        local cond, key, rest = l:match("^([%?!])(%w+) (.*)$")
        if cond then
            if (cond == "?") == set(v, key) then out[#out + 1] = fill(rest, v) end
        else
            out[#out + 1] = fill(l, v)
        end
    end
    -- how the role gets a use back, when the host gave it an item
    if set(v, "item") then
        local r = S.RECHARGE
        if can_recharge(v) then
            local l = ((v.m or 1) > 1) and r.more or r.one
            if v.rmax then l = l .. r.limit end
            out[#out + 1] = fill(l .. ".", v)
            if set(v, "eyes") then out[#out + 1] = fill(r.eyes, v) end
        else
            out[#out + 1] = r.spent
        end
    end
    return out, kind
end

-- The line without its marks (for plain text, as in the pause menu).
function RT.plain(line)
    return (tostring(line or ""):gsub("%*", ""))
end

-- A word that must stay on the row of what comes before it: a punctuation mark written after
-- a space (" : ", " ; "), a unit after a number ("3 s.", "2,5 m),", "10 %"), or the number of
-- a mouse button ("SOURIS 4").
local function clings(word, before)
    if word:match("^[:;!?]$") then return true end
    if word:match("^%d[%.,%)]*$") and before:match("SOURIS$") then return true end
    return word:match("^[sm%%][%.,%)]*$") ~= nil and before:match("%d$") ~= nil
end

-- Number of characters of a text (accented letters take several bytes).
local function length(s)
    local _, n = s:gsub("[^\128-\191]", "")
    return n
end

-- Words put one after the other on rows of at most `width` characters.
local function pack(words, width, indent)
    local out, cur = {}, ""
    for _, word in ipairs(words) do
        if cur ~= "" and length(cur) + 1 + length(word) > width then
            out[#out + 1] = cur
            cur = (indent or "") .. word
        elseif cur == "" then
            cur = word
        else
            cur = cur .. " " .. word
        end
    end
    if cur ~= "" then out[#out + 1] = cur end
    return out
end

-- A plain line cut into pieces of at most `width` characters, at the spaces; the pieces after
-- the first start with `indent`. A last piece of a word or two is avoided: the line is then
-- cut more evenly, on the same number of rows.
local SHORT = 16
function RT.wrap(line, width, indent)
    local words = {}
    for word in tostring(line or ""):gmatch("%S+") do
        if #words > 0 and clings(word, words[#words]) then
            words[#words] = words[#words] .. " " .. word
        else
            words[#words + 1] = word
        end
    end
    local out = pack(words, width, indent)
    if #out > 1 and length(out[#out]) < SHORT then
        for narrower = width - 4, math.floor(width / 2), -4 do
            local even = pack(words, narrower, indent)
            if #even > #out then break end
            out = even
            if length(out[#out]) >= SHORT then break end
        end
    end
    return out
end

-- The line cut into words, each one marked as emphasised or not: { { text, em }, ... }.
-- A word that clings to the one before is kept in the same piece.
function RT.segments(line)
    local out, em = {}, false
    local s, i = tostring(line or ""), 1
    while i <= #s do
        local star = s:find("*", i, true)
        local chunk = s:sub(i, (star or (#s + 1)) - 1)
        if not em and #out > 0 and out[#out].em then
            -- punctuation right after a marked word stays stuck to it ("*G*." is one word)
            local lead = chunk:match("^[%.,;%)]+")
            if lead then
                out[#out].text = out[#out].text .. lead
                chunk = chunk:sub(#lead + 1)
            end
        end
        for word in chunk:gmatch("%S+") do
            if #out > 0 and clings(word, out[#out].text) then
                out[#out].text = out[#out].text .. " " .. word
            else
                out[#out + 1] = { text = word, em = em }
            end
        end
        if not star then break end
        em = not em
        i = star + 1
    end
    return out
end

function RT.title(role)
    return role and (S.ROLE_NAME[role] or role) or S.MENU_NO_ROLE
end

-- Reads "k=v,k=v" sent by the host; values in tenths are turned back into seconds.
function RT.parse(text)
    local v = {}
    for k, x in tostring(text or ""):gmatch("(%w+)=(-?%d+)") do
        local n = tonumber(x)
        v[k] = RT.TENTHS[k] and n / 10 or n
    end
    return v
end

return RT
