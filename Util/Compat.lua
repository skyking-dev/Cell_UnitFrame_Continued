---@class CUF
local CUF = select(2, ...)

---@class CUF.Compat
local Compat = CUF.Compat

local C_Timer = C_Timer
local InCombatLockdown = InCombatLockdown

local dummyAnchors = {}
local activeDummyAnchors = {}
local refreshDelays = { 0, 0.2, 1 }
local DUMMY_WATCH_INTERVAL = 1.5

---@param frame Frame
---@param parent Frame
local function RepointDummy(frame, parent)
    if not frame or not parent or frame == parent then return end
    frame:ClearAllPoints()
    frame:SetAllPoints(parent)
end

---@param frame any
---@return boolean
local function IsFrameLike(frame)
    return type(frame) == "table" and type(frame.SetAllPoints) == "function"
end

---@param name string
---@param quiet boolean?
function Compat:ReleaseDummyAnchor(name, quiet)
    local dummy = dummyAnchors[name]
    if not dummy or not dummy.frame then return end

    if _G[name] == dummy.frame then
        _G[name] = dummy.original
    end

    if dummy.frame.Hide then
        dummy.frame:Hide()
    end

    if not quiet then
        CUF:Log("Released dummy anchor:", "'" .. name .. "'")
    end
end

---@param name string
---@param parent string
---@param quiet boolean?
function Compat:CreateDummyAnchor(name, parent, quiet)
    if type(name) ~= "string" or name == "" then
        if not quiet then
            CUF:Warn("Invalid dummy anchor name:", "'" .. name .. "'")
        end
        return
    end

    if type(parent) ~= "string" or parent == "" then
        if not quiet then
            CUF:Warn("Invalid dummy anchor parent:", "'" .. parent .. "'")
        end
        return
    end
    local parentFrame = _G[parent]
    if not parentFrame then
        if not quiet then
            CUF:Warn("Parent frame with name:", "'" .. parent .. "'", "does not exist! Unable to create dummy anchor.")
        end
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self._dummyAnchorsPendingRefresh = true
        return
    end

    local dummy = dummyAnchors[name]
    local currentGlobal = _G[name]

    if dummy and dummy.frame then
        if currentGlobal and currentGlobal ~= dummy.frame and IsFrameLike(currentGlobal) then
            dummy.original = currentGlobal
        end

        RepointDummy(dummy.frame, parentFrame)
        dummy.parent = parent
        _G[name] = dummy.frame
        dummy.frame:Show()

        if not quiet then
            CUF:Log("Updated dummy anchor:", "'" .. name .. "'")
        end

        return dummy.frame
    end

    if currentGlobal then
        if currentGlobal == parentFrame or not IsFrameLike(currentGlobal) then
            if not quiet then
                CUF:Warn("Frame with name:", "'" .. name .. "'", "already exists but cannot be reused as a dummy anchor.")
            end
            return
        end

        local shadow = CreateFrame("Frame", nil, parentFrame)
        shadow:Hide()
        RepointDummy(shadow, parentFrame)
        shadow:Show()

        dummyAnchors[name] = {
            frame = shadow,
            original = currentGlobal,
            parent = parent,
        }
        _G[name] = shadow

        if not quiet then
            CUF:Log("Shadowed existing frame with dummy anchor:", "'" .. name .. "'")
        end

        return shadow
    end

    dummy = CreateFrame("Frame", name, parentFrame)
    dummy:Hide()
    RepointDummy(dummy, parentFrame)
    dummy:Show()

    if not quiet then
        CUF:Log("Created dummy anchor:", "'" .. name .. "'")
    end

    dummyAnchors[name] = {
        frame = dummy,
        original = nil,
        parent = parent,
    }

    return dummy
end

function Compat:HasEnabledDummyAnchors()
    if not CUF_DB or not CUF_DB.dummyAnchors then return end

    for parent, anchor in pairs(CUF_DB.dummyAnchors) do
        if anchor.enabled and anchor.dummyName and anchor.dummyName ~= "" then
            return true
        end
    end

    return false
end

function Compat:RefreshEnabledDummyAnchors(quiet)
    if not CUF_DB or not CUF_DB.dummyAnchors then return end

    if InCombatLockdown and InCombatLockdown() then
        self._dummyAnchorsPendingRefresh = true
        return
    end

    self._dummyAnchorsPendingRefresh = nil

    local desiredAnchors = {}

    for parent, anchor in pairs(CUF_DB.dummyAnchors) do
        if anchor.enabled and anchor.dummyName and anchor.dummyName ~= "" then
            desiredAnchors[parent] = anchor.dummyName
        end
    end

    for parent, activeName in pairs(activeDummyAnchors) do
        if desiredAnchors[parent] ~= activeName then
            self:ReleaseDummyAnchor(activeName, quiet)
            activeDummyAnchors[parent] = nil
        end
    end

    for parent, name in pairs(desiredAnchors) do
        if activeDummyAnchors[parent] and activeDummyAnchors[parent] ~= name then
            self:ReleaseDummyAnchor(activeDummyAnchors[parent], quiet)
        end

        if name and name ~= "" then
            local dummy = self:CreateDummyAnchor(name, parent, quiet)
            if dummy then
                activeDummyAnchors[parent] = name
            else
                activeDummyAnchors[parent] = nil
            end
        end
    end
end

function Compat:UpdateDummyAnchorWatcher()
    if not C_Timer or not C_Timer.NewTicker then return end

    if self:HasEnabledDummyAnchors() then
        if not self._dummyAnchorTicker then
            self._dummyAnchorTicker = C_Timer.NewTicker(DUMMY_WATCH_INTERVAL, function()
                self:RefreshEnabledDummyAnchors(true)
            end)
        end
        return
    end

    if self._dummyAnchorTicker then
        self._dummyAnchorTicker:Cancel()
        self._dummyAnchorTicker = nil
    end
end

function Compat:InitDummyAnchors()
    if not self._dummyAnchorRegenListener then
        self._dummyAnchorRegenListener = CUF:AddEventListener("PLAYER_REGEN_ENABLED", function()
            if not self._dummyAnchorsPendingRefresh then return end
            self._dummyAnchorsPendingRefresh = nil
            self:QueueDummyAnchorRefresh()
        end)
    end

    self:RefreshEnabledDummyAnchors(true)
    self:UpdateDummyAnchorWatcher()
end

function Compat:QueueDummyAnchorRefresh()
    self:UpdateDummyAnchorWatcher()

    if InCombatLockdown and InCombatLockdown() then
        self._dummyAnchorsPendingRefresh = true
        return
    end

    if not C_Timer or not C_Timer.After then
        self:RefreshEnabledDummyAnchors(true)
        return
    end

    self._dummyAnchorRefreshToken = (self._dummyAnchorRefreshToken or 0) + 1
    local token = self._dummyAnchorRefreshToken

    for _, delay in ipairs(refreshDelays) do
        C_Timer.After(delay, function()
            if self._dummyAnchorRefreshToken ~= token then return end
            self:RefreshEnabledDummyAnchors(true)
        end)
    end
end
