---@class CUF
local CUF = select(2, ...)

local LibDispel = LibStub("LibDispel", true)
local Util = CUF.Util

---@class CUF.Mixin
local Mixin = CUF.Mixin

local const = CUF.constants

local GetAuraDataByAuraInstanceID = C_UnitAuras.GetAuraDataByAuraInstanceID
local GetAuraDataBySlot = C_UnitAuras.GetAuraDataBySlot
local GetAuraSlots = C_UnitAuras.GetAuraSlots
local IsAuraFilteredOutByInstanceID = C_UnitAuras.IsAuraFilteredOutByInstanceID
local ForEachAura = AuraUtil.ForEachAura
local wipe = table.wipe

---@class CUFUnitButton
local AurasMixin = {}
Mixin.AurasMixin = AurasMixin

AurasMixin._auraBuffCache = {}
AurasMixin._auraDebuffCache = {}
AurasMixin._auraBuffCallbacks = {}
AurasMixin._auraDebuffCallbacks = {}

AurasMixin._ignoreBuffs = true
AurasMixin._ignoreDebuffs = true

---@param dispelName string?
---@param spellID number
---@return string
local function CheckDebuffType(dispelName, spellID)
    if not LibDispel then
        return dispelName or "none"
    end

    return LibDispel:GetDispelType(spellID, dispelName)
end

local HELPFUL_FILTER = AuraUtil.AuraFilters.Helpful or "HELPFUL"
local HARMFUL_FILTER = AuraUtil.AuraFilters.Harmful or "HARMFUL"

---@param value any
---@return boolean?
local function GetSafeBoolean(value)
    if type(value) == "boolean" and Util.IsValueNonSecret(value) then
        return value
    end
end

---@param value any
---@return number?
local function GetSafeNumber(value)
    if type(value) == "number" and Util.IsValueNonSecret(value) then
        return value
    end
end

---@param value any
---@return string?
local function GetSafeString(value)
    if type(value) == "string" and Util.IsValueNonSecret(value) and value ~= "" then
        return value
    end
end

---@param aura AuraData
---@param field string
---@param previousAura AuraData?
---@return boolean
local function GetAuraBoolean(aura, field, previousAura)
    local value = GetSafeBoolean(aura[field])
    if value ~= nil then
        return value
    end

    if previousAura ~= nil and type(previousAura[field]) == "boolean" then
        return previousAura[field]
    end

    return false
end

---@param aura AuraData
---@param field string
---@param previousAura AuraData?
---@return number?
local function GetAuraNumber(aura, field, previousAura)
    local value = GetSafeNumber(aura[field])
    if value ~= nil then
        return value
    end

    if previousAura ~= nil and type(previousAura[field]) == "number" then
        return previousAura[field]
    end
end

---@param aura AuraData
---@param field string
---@param previousAura AuraData?
---@return string?
local function GetAuraString(aura, field, previousAura)
    local value = GetSafeString(aura[field])
    if value ~= nil then
        return value
    end

    if previousAura ~= nil and type(previousAura[field]) == "string" and previousAura[field] ~= "" then
        return previousAura[field]
    end
end

---@param unit UnitToken
---@param filter string
---@param callback fun(aura: AuraData)
local function IterateAurasByFilter(unit, filter, callback)
    if unit == nil then
        return
    end

    if GetAuraSlots and GetAuraDataBySlot then
        local continuationToken

        repeat
            local results = { GetAuraSlots(unit, filter, nil, continuationToken) }
            continuationToken = results[1]

            for i = 2, #results do
                local aura = GetAuraDataBySlot(unit, results[i])
                if aura then
                    callback(aura)
                end
            end
        until continuationToken == nil

        return
    end

    ForEachAura(unit, filter, nil, callback, true)
end

---@param unit UnitToken
---@param auraInstanceID number?
---@param filter string
---@return boolean?
local function MatchesAuraFilter(unit, auraInstanceID, filter)
    if not IsAuraFilteredOutByInstanceID or auraInstanceID == nil or unit == nil then
        return nil
    end

    local isFiltered = IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter)
    if not Util.IsValueNonSecret(isFiltered) then
        return nil
    end

    return not isFiltered
end

---@param aura AuraData
---@param unit UnitToken
---@param filterHint? string
---@return boolean isHelpful
---@return boolean isHarmful
local function ResolveAuraFlags(aura, unit, filterHint)
    if filterHint == HELPFUL_FILTER then
        return true, false
    elseif filterHint == HARMFUL_FILTER then
        return false, true
    end

    if aura.isHelpful then
        return true, false
    elseif aura.isHarmful then
        return false, true
    end

    local auraInstanceID = aura.auraInstanceID
    local isHarmful = MatchesAuraFilter(unit, auraInstanceID, HARMFUL_FILTER)
    if isHarmful then
        return false, true
    end

    local isHelpful = MatchesAuraFilter(unit, auraInstanceID, HELPFUL_FILTER)
    if isHelpful then
        return true, false
    end

    return false, false
end

---@param aura AuraData?
---@param unit UnitToken
---@param previousAura AuraData?
---@return AuraData?
local function PrepareAura(aura, unit, previousAura)
    if aura == nil or not Util.IsValueNonSecret(aura.auraInstanceID) then
        return nil
    end

    aura.name = GetAuraString(aura, "name", previousAura)
    aura.spellId = GetAuraNumber(aura, "spellId", previousAura)
    aura.sourceUnit = GetAuraString(aura, "sourceUnit", previousAura)
    aura.icon = GetAuraNumber(aura, "icon", previousAura) or aura.icon
    aura.applications = GetAuraNumber(aura, "applications", previousAura) or aura.applications

    local spellID = aura.spellId
    aura.isNameplateOnly = GetAuraBoolean(aura, "isNameplateOnly", previousAura)
    aura.isHarmful = GetAuraBoolean(aura, "isHarmful", previousAura)
    aura.isHelpful = GetAuraBoolean(aura, "isHelpful", previousAura)
    aura.isBossAura = GetAuraBoolean(aura, "isBossAura", previousAura)
    aura.isRaid = GetAuraBoolean(aura, "isRaid", previousAura)
    aura.isFromPlayerOrPlayerPet = GetAuraBoolean(aura, "isFromPlayerOrPlayerPet", previousAura)

    if Util.IsValueNonSecret(spellID) then
        local dispelName = Util.IsValueNonSecret(aura.dispelName) and aura.dispelName or nil
        aura.dispelName = CheckDebuffType(dispelName, spellID)
        aura.isDispellable = LibDispel and LibDispel:IsDispelable(unit, spellID, aura.dispelName, aura.isHarmful) or false
    elseif previousAura then
        aura.dispelName = previousAura.dispelName
        aura.isDispellable = previousAura.isDispellable
    else
        aura.dispelName = Util.IsValueNonSecret(aura.dispelName) and aura.dispelName or nil
        aura.isDispellable = false
    end

    if aura.isFromPlayerOrPlayerPet == false then
        local sourceUnit = aura.sourceUnit
        if sourceUnit == "player" or sourceUnit == "pet" then
            aura.isFromPlayerOrPlayerPet = true
        end
    end

    return aura
end

---@param aura AuraData?
---@return boolean
local function HasDispelState(aura)
    if aura == nil then
        return false
    end

    return aura.isDispellable == true or (aura.dispelName ~= nil and aura.dispelName ~= "" and aura.dispelName ~= "none")
end

function AurasMixin:ResetAuraTables()
    wipe(self._auraBuffCache)
    wipe(self._auraDebuffCache)

    if not self:HasWidget(const.WIDGET_KIND.BUFFS) then return end
    wipe(self.widgets.buffs._auraCache)
    wipe(self.widgets.debuffs._auraCache)
end

--- Processes an aura and returns the type of aura
--- Returns None if the aura should be be ignored
---@param aura AuraData
---@param ignoreBuffs boolean
---@param ignoreDebuffs boolean
---@param unit UnitToken
---@param filterHint? string
---@return AuraUtil.AuraUpdateChangedType
local function ProcessAura(aura, ignoreBuffs, ignoreDebuffs, unit, filterHint)
    aura = PrepareAura(aura, unit)
    if aura == nil then
        return AuraUtil.AuraUpdateChangedType.None;
    end

    if aura.isNameplateOnly then
        return AuraUtil.AuraUpdateChangedType.None;
    end

    local isHelpful, isHarmful = ResolveAuraFlags(aura, unit, filterHint)
    aura.isHelpful = isHelpful
    aura.isHarmful = isHarmful

    if aura.auraInstanceID ~= nil and not aura.isRaid then
        local raidFilter
        if isHarmful then
            raidFilter = "HARMFUL|RAID"
        elseif isHelpful then
            raidFilter = "HELPFUL|RAID"
        end

        if raidFilter ~= nil then
            local isRaid = MatchesAuraFilter(unit, aura.auraInstanceID, raidFilter)
            if isRaid ~= nil then
                aura.isRaid = isRaid
            end
        end
    end

    local spellID = aura.spellId
    if isHarmful and aura.auraInstanceID ~= nil then
        local serverDispel = MatchesAuraFilter(unit, aura.auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        if serverDispel ~= nil then
            aura.isDispellable = serverDispel
        elseif Util.IsValueNonSecret(spellID) then
            aura.isDispellable = LibDispel and LibDispel:IsDispelable(unit, spellID, aura.dispelName, true) or false
        end
    elseif Util.IsValueNonSecret(spellID) then
        aura.isDispellable = LibDispel and LibDispel:IsDispelable(unit, spellID, aura.dispelName, isHarmful) or false
    end

    if isHarmful and not ignoreDebuffs then
        if HasDispelState(aura) then
            return AuraUtil.AuraUpdateChangedType.Dispel
        end

        return AuraUtil.AuraUpdateChangedType.Debuff
    elseif isHelpful and not ignoreBuffs then
        return AuraUtil.AuraUpdateChangedType.Buff
    end

    return AuraUtil.AuraUpdateChangedType.None;
end

--- Perform a full aura update for a unit
---@param ignoreBuffs boolean
---@param ignoreDebuffs boolean
---@param unit UnitToken
function AurasMixin:ParseAllAuras(ignoreBuffs, ignoreDebuffs, unit)
    wipe(self._auraBuffCache)
    wipe(self._auraDebuffCache)

    ---@param aura AuraData
    ---@param filter string
    local function HandleAura(aura, filter)
        local type = ProcessAura(aura, ignoreBuffs, ignoreDebuffs, unit, filter)
        if type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel then
            self._auraDebuffCache[aura.auraInstanceID] = aura
        elseif type == AuraUtil.AuraUpdateChangedType.Buff then
            self._auraBuffCache[aura.auraInstanceID] = aura
        end
    end

    if not ignoreDebuffs then
        IterateAurasByFilter(unit, HARMFUL_FILTER, function(aura)
            HandleAura(aura, HARMFUL_FILTER)
        end)
    end
    if not ignoreBuffs then
        IterateAurasByFilter(unit, HELPFUL_FILTER, function(aura)
            HandleAura(aura, HELPFUL_FILTER)
        end)
    end
end

--- Process UNIT_AURA events and update aura caches
--- This function is called either on UNIT_AURA event or from UnitFrame_UpdateAll
--- Will only trigger if auras are not ignored
---@param event "UNIT_AURA"?
---@param unit UnitToken?
---@param unitAuraUpdateInfo UnitAuraUpdateInfo?
function AurasMixin:UpdateAurasInternal(event, unit, unitAuraUpdateInfo)
    self._auraUpdateRequired = nil
    if self._ignoreBuffs and self._ignoreDebuffs then return end
    unit = unit or self.states.unit

    local debuffsChanged = false
    local buffsChanged = false
    local dispelsChanged = false
    local stealableChanged = false
    local fullUpdate = false

    if unitAuraUpdateInfo == nil or unitAuraUpdateInfo.isFullUpdate then
        self:ParseAllAuras(self._ignoreBuffs, self._ignoreDebuffs, unit)
        debuffsChanged = true
        buffsChanged = true
        dispelsChanged = true
        stealableChanged = true
        fullUpdate = true
    else
        if unitAuraUpdateInfo.addedAuras ~= nil then
            for _, aura in ipairs(unitAuraUpdateInfo.addedAuras) do
                local type = ProcessAura(aura, self._ignoreBuffs, self._ignoreDebuffs, unit)

                if type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel then
                    self._auraDebuffCache[aura.auraInstanceID] = aura
                    debuffsChanged = true
                    dispelsChanged = dispelsChanged or type == AuraUtil.AuraUpdateChangedType.Dispel
                elseif type == AuraUtil.AuraUpdateChangedType.Buff then
                    self._auraBuffCache[aura.auraInstanceID] = aura
                    buffsChanged = true
                    stealableChanged = stealableChanged or aura.isDispellable
                end
            end
        end

        if unitAuraUpdateInfo.updatedAuraInstanceIDs ~= nil then
            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.updatedAuraInstanceIDs) do
                if self._auraDebuffCache[auraInstanceID] ~= nil then
                    local previousAura = self._auraDebuffCache[auraInstanceID]
                    local newAura = GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                    newAura = PrepareAura(newAura, unit, previousAura)
                    dispelsChanged = dispelsChanged or HasDispelState(newAura) or HasDispelState(previousAura)
                    self._auraDebuffCache[auraInstanceID] = newAura
                    debuffsChanged = true
                elseif self._auraBuffCache[auraInstanceID] ~= nil then
                    local previousAura = self._auraBuffCache[auraInstanceID]
                    local newAura = GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                    newAura = PrepareAura(newAura, unit, previousAura)
                    if newAura then
                        stealableChanged = stealableChanged or newAura.isDispellable
                    else
                        stealableChanged = stealableChanged or previousAura.isDispellable
                    end
                    self._auraBuffCache[auraInstanceID] = newAura
                    buffsChanged = true
                else
                    local aura = GetAuraDataByAuraInstanceID(unit, auraInstanceID)
                    local type = ProcessAura(aura, self._ignoreBuffs, self._ignoreDebuffs, unit)

                    if type == AuraUtil.AuraUpdateChangedType.Debuff or type == AuraUtil.AuraUpdateChangedType.Dispel then
                        self._auraDebuffCache[auraInstanceID] = aura
                        debuffsChanged = true
                        dispelsChanged = dispelsChanged or type == AuraUtil.AuraUpdateChangedType.Dispel
                    elseif type == AuraUtil.AuraUpdateChangedType.Buff then
                        self._auraBuffCache[auraInstanceID] = aura
                        buffsChanged = true
                        stealableChanged = stealableChanged or aura.isDispellable
                    end
                end
            end
        end

        if unitAuraUpdateInfo.removedAuraInstanceIDs ~= nil then
            for _, auraInstanceID in ipairs(unitAuraUpdateInfo.removedAuraInstanceIDs) do
                if self._auraDebuffCache[auraInstanceID] ~= nil then
                    dispelsChanged = dispelsChanged or HasDispelState(self._auraDebuffCache[auraInstanceID])
                    self._auraDebuffCache[auraInstanceID] = nil
                    debuffsChanged = true
                elseif self._auraBuffCache[auraInstanceID] ~= nil then
                    stealableChanged = stealableChanged or self._auraBuffCache[auraInstanceID].isDispellable
                    self._auraBuffCache[auraInstanceID] = nil
                    buffsChanged = true
                end
            end
        end
    end

    self:TriggerAuraCallbacks(buffsChanged, debuffsChanged, dispelsChanged, fullUpdate, stealableChanged)
end

--- Queues an aura update
--- Used to prevent aura update spam
--- Mostly relevant when full updating widgets since they will all ask for aura update
function AurasMixin:QueueAuraUpdate()
    if not self:IsVisible() then return end
    if self._ignoreBuffs and self._ignoreDebuffs then return end
    self._auraUpdateRequired = true
end

--- Triggers aura callbacks
---@param buffsChanged boolean
---@param debuffsChanged boolean
---@param dispelsChanged boolean
---@param fullUpdate boolean
---@param stealableChanged boolean
function AurasMixin:TriggerAuraCallbacks(buffsChanged, debuffsChanged, dispelsChanged, fullUpdate, stealableChanged)
    --CUF:Log("TriggerAuraCallbacks", self.states.unit, buffsChanged, debuffsChanged, fullUpdate)
    if not buffsChanged and not debuffsChanged and not fullUpdate then
        return
    end

    if buffsChanged then
        for _, callback in pairs(self._auraBuffCallbacks) do
            callback(self, buffsChanged, debuffsChanged, dispelsChanged, fullUpdate, stealableChanged)
        end
    end
    if debuffsChanged then
        for _, callback in pairs(self._auraDebuffCallbacks) do
            callback(self, buffsChanged, debuffsChanged, dispelsChanged, fullUpdate, stealableChanged)
        end
    end
end

--- Iterates over all auras of a specific type
--- Return true to stop iteration
---@param type "buffs" | "debuffs"
---@param fn fun(aura: AuraData, ...): true?
function AurasMixin:IterateAuras(type, fn, ...)
    if type == "buffs" then
        for _, aura in pairs(self._auraBuffCache) do
            if fn(aura, ...) then return end
        end
    elseif type == "debuffs" then
        for _, aura in pairs(self._auraDebuffCache) do
            if fn(aura, ...) then return end
        end
    end
end

--- Registers a callback for auras of a specific type
--- This function will automatically add UNIT_AURA event listener if it is not already added
---@param type "buffs" | "debuffs"
---@param callback UnitAuraCallbackFn
function AurasMixin:RegisterAuraCallback(type, callback)
    local listenerActive = #self._auraBuffCallbacks > 0 or #self._auraDebuffCallbacks > 0
    if not listenerActive then
        self:AddEventListener("UNIT_AURA", self.UpdateAurasInternal)
    end

    if type == "buffs" then
        table.insert(self._auraBuffCallbacks, callback)
        self._ignoreBuffs = false
    elseif type == "debuffs" then
        table.insert(self._auraDebuffCallbacks, callback)
        self._ignoreDebuffs = false
    end

    self:UpdateAurasInternal("UNIT_AURA", self.states.unit)
end

--- Unregister a callback for auras of a specific type
--- This function will automatically remove UNIT_AURA event listener if no more callbacks are registered
---@param type "buffs" | "debuffs"
---@param callback function
function AurasMixin:UnregisterAuraCallback(type, callback)
    if type == "buffs" then
        for i, cb in ipairs(self._auraBuffCallbacks) do
            if cb == callback then
                table.remove(self._auraBuffCallbacks, i)
                break
            end
        end
    elseif type == "debuffs" then
        for i, cb in ipairs(self._auraDebuffCallbacks) do
            if cb == callback then
                table.remove(self._auraDebuffCallbacks, i)
                break
            end
        end
    end

    self._ignoreBuffs = #self._auraBuffCallbacks == 0
    self._ignoreDebuffs = #self._auraDebuffCallbacks == 0

    if self._ignoreBuffs then
        wipe(self._auraBuffCache)
    end
    if self._ignoreDebuffs then
        wipe(self._auraDebuffCache)
    end

    -- If no more callbacks are registered, remove the event listener
    if self._ignoreBuffs and self._ignoreDebuffs then
        self:RemoveEventListener("UNIT_AURA", self.UpdateAurasInternal)
    end
end

---@alias UnitAuraCallbackFn fun(self: CUFUnitButton, buffsChanged: boolean, debuffsChanged: boolean, dispelsChanged: boolean, fullUpdate: boolean, stealableChanged: boolean)
