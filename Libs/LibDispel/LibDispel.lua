local MAJOR, MINOR = "LibDispel", 1
local LibDispel = LibStub:NewLibrary(MAJOR, MINOR)
if not LibDispel then return end

LibDispel.bleed = LibDispel.bleed or {}
LibDispel.enrage = LibDispel.enrage or {}

local lower = string.lower
local type = type
local UnitCanAssist = UnitCanAssist
local IsSpellKnownOrOverridesKnown = IsSpellKnownOrOverridesKnown or IsSpellKnown

local dispelTypes = {
    curse = "Curse",
    disease = "Disease",
    magic = "Magic",
    poison = "Poison",
    bleed = "Bleed",
    enrage = "Enrage",
}

local offensiveMagicSpells = {
    370,    -- Purge
    528,    -- Dispel Magic
    19801,  -- Tranquilizing Shot
    30449,  -- Spellsteal
    278326, -- Consume Magic
}

local offensiveEnrageSpells = {
    2908,   -- Soothe
    19801,  -- Tranquilizing Shot
    5938,   -- Shiv
}

local function NormalizeDispelType(dispelName)
    if type(dispelName) ~= "string" or dispelName == "" then
        return
    end

    return dispelTypes[lower(dispelName)] or dispelName
end

local function IsAnySpellKnown(spellIDs)
    if not IsSpellKnownOrOverridesKnown then
        return false
    end

    for i = 1, #spellIDs do
        if IsSpellKnownOrOverridesKnown(spellIDs[i]) then
            return true
        end
    end

    return false
end

function LibDispel:GetDispelType(spellID, dispelName)
    if type(spellID) == "number" then
        if self.bleed[spellID] then
            return "Bleed"
        end

        if self.enrage[spellID] then
            return "Enrage"
        end
    end

    return NormalizeDispelType(dispelName) or "none"
end

function LibDispel:IsDispelable(unit, spellID, dispelName, isDebuff)
    local dispelType = self:GetDispelType(spellID, dispelName)
    if dispelType == "none" then
        return false
    end

    if isDebuff then
        local Cell = rawget(_G, "Cell")
        local I = Cell and Cell.iFuncs
        if I and type(I.CanDispel) == "function" then
            return not not I.CanDispel(dispelType)
        end

        return true
    end

    if unit and UnitCanAssist and UnitCanAssist("player", unit) then
        return false
    end

    if dispelType == "Magic" then
        return IsAnySpellKnown(offensiveMagicSpells)
    end

    if dispelType == "Enrage" then
        return IsAnySpellKnown(offensiveEnrageSpells)
    end

    return false
end
